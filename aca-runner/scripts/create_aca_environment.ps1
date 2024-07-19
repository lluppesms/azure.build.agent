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
# You may need to run this first in PowerShell...
#   Connect-AzAccount
# ------------------------------------------------------------------------------------
# Run with only required parameters:
# ./create_aca_environment.ps1 -UniqueId 'xxx'
# ------------------------------------------------------------------------------------
# Run with all parameters:
# ./create_aca_environment.ps1 `
# -UniqueId 'xxx' `
# -ResourceGroupName 'rg_aca_agent' `
# -Location 'northcentralus' `
# -ContainerAppsEnvSuffix 'aca-agent-env' `
# -ContainerRegistrySuffix 'acaagentacr' `
# -ManagedIdentitySuffix 'aca-agent-mi' `
# -ContainerImageName 'azure-pipelines-agent:1.0' `
# -DockerFile = "Dockerfile.pipelines"
# ------------------------------------------------------------------------------------

param(
    [Parameter(Mandatory = $true)] [string] $UniqueId,
    [Parameter()] [string] $ResourceGroupName = 'rg_aca_build_agent',
    [Parameter()] [string] $Location = 'eastus',
    [Parameter()] [string] $ManagedIdentitySuffix = 'aca-agent-mi',
    [Parameter()] [string] $ContainerAppsEnvSuffix  = 'aca-agent-env',
    [Parameter()] [string] $ContainerRegistrySuffix  = 'acaagentacr',
    [Parameter()] [string] $ContainerImageName = 'azure-pipelines-agent:1.0',
    [Parameter()] [string] $DockerFile = "Dockerfile.pipelines"
    )

$ManagedIdentityResourceName = $UniqueId + '-' + $ManagedIdentitySuffix
$ContainerRegistryName = $UniqueId + $ContainerRegistrySuffix
$ContainerAppsEnvName = $UniqueId + '-' + $ContainerAppsEnvSuffix
$DockerFilePath = "../docker/" + $DockerFile

Write-Host "** Starting ACR and CA deploy with the following parameters:"
Write-Host "** ResourceGroupName: $ResourceGroupName"
Write-Host "** Location: $Location"
Write-Host "** ContainerAppsEnvName: $ContainerAppsEnvName"
Write-Host "** ContainerRegistryName: $ContainerRegistryName"
Write-Host "** ContainerImageName: $ContainerImageName"
Write-Host "** ManagedIdentityResourceName: $ManagedIdentityResourceName"
Write-Host "`n"

Write-Host "** Creating Resource Group $ResourceGroupName..."
az group create --name $ResourceGroupName --location $LOCATION

Write-Host "** Creating Log Analytics Workspace $WorkspaceName..."
$WorkspaceName = $ContainerAppsEnvName+"-la"
az monitor log-analytics workspace create `
    --resource-group $ResourceGroupName `
    --workspace-name $WorkspaceName `
    --location $Location

Write-Host "** Getting Log Analytics Workspace ID..."
$workspace = az monitor log-analytics workspace show `
    --resource-group $ResourceGroupName `
    --workspace-name $WorkspaceName `
    --query "{workspaceId: customerId, workspaceKey: primaryKey}" `
    --output json | ConvertFrom-Json
$LogWorkspaceId = $workspace.workspaceId
Write-Host "   LogWorkspaceId: $LogWorkspaceId"

Write-Host "** Creating Container App Environment $ContainerAppsEnvName..."
az containerapp env create `
    --name $ContainerAppsEnvName `
    --resource-group $ResourceGroupName `
    --location $LOCATION `
    --logs-workspace-id $LogWorkspaceId `

Write-Host "** Creating Container Registry $ContainerRegistryName..."
az acr create `
    --name $ContainerRegistryName `
    --resource-group $ResourceGroupName `
    --location $LOCATION `
    --sku Basic `
    --admin-enabled true

# # If you use the default version from the example - it has almost no utilities installed....
Write-Host "** Building ACR Build Server Image from $DockerFilePath to $ContainerImageName..."
az acr build `
    --registry $ContainerRegistryName `
    --image $ContainerImageName `
    --file $DockerFilePath

## Note If you use the default docker file from the example -> that image has almost no utilities installed (Bicep, Powershell, etc.)....
# Write-Host "** Building ACR Build Server Image $ContainerImageName..."
# az acr build `
#     --registry $ContainerRegistryName `
#     --image $ContainerImageName `
#     --file "Dockerfile.azure-pipelines" `
#     "https://github.com/Azure-Samples/container-apps-ci-cd-runner-tutorial.git"

Write-Host "** Creating Managed Identity $ManagedIdentityResourceName..."
az identity create --name $ManagedIdentityResourceName --resource-group $ResourceGroupName

Write-Host "** Adding ACR Pull permissions to ACR for Managed Identity..."
az role assignment create `
    --assignee-object-id $(az identity show --name $ManagedIdentityResourceName --resource-group $ResourceGroupName --query principalId -o tsv) `
    --role acrpull `
    --scope $(az acr show --name $ContainerRegistryName --resource-group $ResourceGroupName --query id -o tsv)

Write-Host "`n"
Write-Host "** ACR Setup job setup complete."
