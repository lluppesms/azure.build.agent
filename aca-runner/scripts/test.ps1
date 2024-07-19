# # Run with only required parameters:
# ./test.ps1 -UniqueId 'xxx' -AzdoOrgName "luppesdemo" -ResourceGroupName "rg_aca_agent-xxx" -Location "northcentralus" -AzdoToken "guid"

param(
  [Parameter(Mandatory = $true)] [string] $UniqueId,
  [Parameter()] [string] $ResourceGroupName = 'rg_aca_build_agent',
  [Parameter()] [string] $Location = 'eastus',
  [Parameter(Mandatory = $true)] [string] $AzdoToken,
  [Parameter(Mandatory = $true)] [string] $AzdoOrgName,
  [Parameter()] [string] $AzdoAgentPoolName = 'aca_build_runner',
  [Parameter()] [string] $ManagedIdentitySuffix = 'aca-agent-mi',
  [Parameter()] [string] $ContainerAppsEnvSuffix  = 'aca-agent-env',
  [Parameter()] [string] $ContainerRegistrySuffix  = 'acaagentacr',
  [Parameter()] [string] $ContainerImageName = 'azure-pipelines-agent:1.0',
  [Parameter()] [string] $PlaceholderJobName = 'placeholder-agent-job',
  [Parameter()] [string] $JobName = 'azure-pipelines-agent-job'
)

$AzdoOrgUrl = "https://dev.azure.com/" + $AzdoOrgName + "/"
$ContainerRegistryName = $UniqueId + "-" + $ContainerRegistryNameSuffix
$ManagedIdentityResourceName = $UniqueId + "-" + $ManagedIdentitySuffix
$ContainerAppsEnvName = $UniqueId + "-" + $ContainerAppsEnvSuffix


Write-Host "** Starting Create Container App Build Job with the following parameters:"
Write-Host "** ResourceGroupName: $ResourceGroupName"
Write-Host "** Location: $Location"
Write-Host "** AzdoOrgUrl: $AzdoOrgUrl"
Write-Host "** AzdoToken: $AzdoToken"
Write-Host "** AzdoAgentPoolName: $AzdoAgentPoolName"
Write-Host "** ManagedIdentityResourceName: $ManagedIdentityResourceName"
Write-Host "** ContainerAppsEnvName: $ContainerAppsEnvName"
Write-Host "** ContainerRegistryName: $ContainerRegistryName"
Write-Host "** PlaceholderJobName: $PlaceholderJobName"
Write-Host "** JobName: $JobName"
Write-Host "** ContainerImageName: $ContainerImageName"
Write-Host "`n"

Write-Host "** Test job complete."
