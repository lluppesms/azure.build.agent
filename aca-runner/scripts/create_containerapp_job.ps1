# ------------------------------------------------------------------------------------
# Create a Azure Devops Build Runner in Azure Container Apps
# ------------------------------------------------------------------------------------
# Reference: 
#   https://learn.microsoft.com/en-us/azure/container-apps/tutorial-ci-cd-runners-jobs?tabs=bash&pivots=container-apps-jobs-self-hosted-ci-cd-azure-pipelines
# ------------------------------------------------------------------------------------
# Steps:
#   1. Create a PAT Token in Azure DevOps with Agent Pool read/write permissions.
#   2. Create an Agent Pool in Azure DevOps
#   3. Run create_aca_environment.ps1 with your Unique Id to create the ACA environment and ACR registry.
#      (Tried to add the MI into the ACR with AcrPull rights, but that didn't help...)
#   4. Run create_containerapp_job.ps1 with your Unique Id and OrgName and Token to create the job.
# ------------------------------------------------------------------------------------
# Note: 
#   This solution using ACA does not support Windows Container Images
#   And - the example Linux Container Image only provides basic tools like CURL
#   So -- you may need to create your own DockerFile with the proper tools
# ------------------------------------------------------------------------------------
# You may need to run this first in PowerShell...
#   Connect-AzAccount
# ------------------------------------------------------------------------------------
# Run with only required parameters:
# ./create_containerapp_job.ps1 -UniqueId 'xxx' -AzdoOrgName 'mycompany' -AzdoToken ''
# ------------------------------------------------------------------------------------
# Run with all parameters:
# ./create_containerapp_job.ps1 `
#  -AzdoOrgUrl 'https://dev.azure.com/mycompany/' `
#  -AzdoAgentPoolName 'aca_build_runner' `
#  -AzdoToken '' `
#  -ResourceGroupName 'rg_aca_agent' `
#  -ContainerAppsEnvSuffix 'aca-agent-env' `
#  -ContainerRegistrySuffix 'acaagentacr' `
#  -ManagedIdentitySuffix 'aca-agent-mi'
#  -PlaceholderJobName 'placeholder-agent-job' `
#  -JobName 'azure-pipelines-agent-job' `
#  -ContainerImageName 'azure-pipelines-agent:1.0'
# ------------------------------------------------------------------------------------

param(
    [Parameter(Mandatory = $true)] [string] $UniqueId,
    [Parameter(Mandatory = $true)] [string] $AzdoToken,
    [Parameter(Mandatory = $true)] [string] $AzdoOrgName,
    [Parameter()] [string] $ResourceGroupName = 'rg_aca_build_agent',
    [Parameter()] [string] $AzdoAgentPoolName = 'aca_build_runner',
    [Parameter()] [string] $ManagedIdentitySuffix = 'aca-agent-mi',
    [Parameter()] [string] $ContainerAppsEnvSuffix  = 'aca-agent-env',
    [Parameter()] [string] $ContainerRegistrySuffix  = 'acaagentacr',
    [Parameter()] [string] $ContainerImageName = 'azure-pipelines-agent:1.0',
    [Parameter()] [string] $PlaceholderSuffix = 'placeholder-agent-job',
    [Parameter()] [string] $JobSuffix = 'azure-pipelines-agent-job'
)

$AzdoOrgUrl = 'https://dev.azure.com/' + $AzdoOrgName # Make sure no trailing / is present at the end of the URL.
$ManagedIdentityResourceName = $UniqueId + '-' + $ManagedIdentitySuffix
$ContainerRegistryName = $UniqueId + $ContainerRegistrySuffix
$ContainerAppsEnvName = $UniqueId + '-' + $ContainerAppsEnvSuffix
$JobName = $UniqueId + '-' + $JobSuffix
$PlaceholderJobName = $UniqueId + '-' + $PlaceholderSuffix

Write-Host "** Starting Container App Build with the following parameters:"
Write-Host "** ResourceGroupName: $ResourceGroupName"
Write-Host "** AzdoOrgUrl: $AzdoOrgUrl"
Write-Host "** AzdoToken: $AzdoToken"
Write-Host "** AzdoAgentPoolName: $AzdoAgentPoolName"
Write-Host "** ContainerAppsEnvName: $ContainerAppsEnvName"
Write-Host "** ContainerRegistryName: $ContainerRegistryName"
Write-Host "** ContainerImageName: $ContainerImageName"
Write-Host "** ManagedIdentityResourceName: $ManagedIdentityResourceName"
Write-Host "** PlaceholderJobName: $PlaceholderJobName"
Write-Host "** JobName: $JobName"
Write-Host "`n"

Write-Host "** Getting resource id for managed identity $ManagedIdentityResourceName..."
$ManagedIdentityResourceId = Get-AzUserAssignedIdentity -ResourceGroupName $ResourceGroupName -Name $ManagedIdentityResourceName | Select-Object -ExpandProperty Id
Write-Host "** Managed identity resource id: $ManagedIdentityResourceId"

Write-Host "** Creating placeholder job $PlaceholderJobName..."
az containerapp job create -n $PlaceholderJobName -g $ResourceGroupName --environment $ContainerAppsEnvName `
    --trigger-type Manual `
    --replica-timeout 300 `
    --replica-retry-limit 0 `
    --replica-completion-count 1 `
    --parallelism 1 `
    --image "$ContainerRegistryName.azurecr.io/$ContainerImageName" `
    --cpu "2.0" `
    --memory "4Gi" `
    --secrets "personal-access-token=$AzdoToken" "organization-url=$AzdoOrgUrl" `
    --env-vars "AZP_TOKEN=secretref:personal-access-token" "AZP_URL=secretref:organization-url" "AZP_POOL=$AzdoAgentPoolName" "AZP_PLACEHOLDER=1" "AZP_AGENT_NAME=placeholder-agent" `
    --registry-server "$ContainerRegistryName.azurecr.io" `
    --registry-identity $ManagedIdentityResourceId

Write-Host "** Starting placeholder job..."
az containerapp job start -n $PlaceholderJobName -g $ResourceGroupName

$STATUS = "Running"

while ($STATUS -eq "Running")
{
    Write-Host "Checking placeholder job status"
    Start-Sleep -Seconds 5  # Wait for 5 seconds before checking again
    $STATUS = az containerapp job execution list --name $PlaceholderJobName --resource-group $ResourceGroupName --output tsv --query '[].{Status: properties.status}'
    Write-Host "Status is: $STATUS"
}

Write-Host "** Creating pipeline agent job $JobName..."
Write-Host "**   Env: $ContainerAppsEnvName"
Write-Host "**   Image: $ContainerRegistryName.azurecr.io/$ContainerImageName" 
Write-Host "**   PoolName: $AzdoAgentPoolName"
Write-Host "**   AzdoOrgUrl: $AzdoOrgUrl"
# Note: set max-executions to be how many jobs are picked up each time the job polls
# Set the polling-interval to be how often it check for new jobs (in seconds)
az containerapp job create -n "$JobName" -g "$ResourceGroupName" --environment "$ContainerAppsEnvName" `
    --trigger-type Event `
    --replica-timeout 1800 `
    --replica-retry-limit 0 `
    --replica-completion-count 1 `
    --parallelism 1 `
    --image "$ContainerRegistryName.azurecr.io/$ContainerImageName" `
    --min-executions 0 `
    --max-executions 5 `
    --polling-interval 10 `
    --scale-rule-name "azure-pipelines" `
    --scale-rule-type "azure-pipelines" `
    --scale-rule-metadata "poolName=$AzdoAgentPoolName" "targetPipelinesQueueLength=1" `
    --scale-rule-auth "personalAccessToken=personal-access-token" "organizationURL=organization-url" `
    --cpu "2.0" `
    --memory "4Gi" `
    --secrets "personal-access-token=$AzdoToken" "organization-url=$AzdoOrgUrl" `
    --env-vars "AZP_TOKEN=secretref:personal-access-token" "AZP_URL=secretref:organization-url" "AZP_POOL=$AzdoAgentPoolName" `
    --registry-server "$ContainerRegistryName.azurecr.io" `
    --registry-identity $ManagedIdentityResourceId

Write-Host "** Deleting placeholder job..."
az containerapp job delete -n $PlaceholderJobName -g $ResourceGroupName --yes

Write-Host "`n"
Write-Host "** Pipeline agent job setup complete."