# DeploySAW.ps1 
# Check for -Destroy switch and -NoDeploy switch
# If -Destroy switch is present, destroy the SAW environment and then run DeployAzureVDISAWEnv.ps1 + DeploySAWNetwork.ps1
# If -NoDeploy switch is present, just destroy the SAW environment by its resource group name
# If neither switch is present, run DeployAzureVDISAWEnv.ps1 + DeploySAWNetwork.ps1
$ErrorActionPreference = 'Stop'
# Check for SAWDeployerConfigItems.ps1
if (!(Test-Path .\SAWDeployerConfigItems.ps1)) {
    Write-Error -Message "SAWDeployerConfigItems.ps1 not found. Exiting." -ErrorAction Stop
}

function Destroy-SAWEnvironment {
    param (
        [Parameter(Mandatory)]
     [string]$RGToDestroy
    )
    Write-Host "Destroying resource group: $RGToDestroy"
    # if resource group exists, destroy it
    if (Get-AzResourceGroup -Name $RGToDestroy -ErrorAction SilentlyContinue) {
        Write-Host "Resource group: $RGToDestroy found."
    }
    else {
        Write-Error -Message "Resource group: $RGToDestroy not found. Exiting." -ErrorAction Stop
    }
    Remove-AzResourceGroup -Name $RGToDestroy -Force
    Write-Host "Resource group: $RGToDestroy destroyed."
}

# Check for -Destroy switch and -NoDeploy switch
if ($Destroy) {
    Destroy-SAWEnvironment -RGToDestroy $SAWResourceGroupName
} if ($NoDeploy) {
    Write-Host "###############################################" 
    Write-Host "NoDeploy switch present, skipping deployment and exiting." 
    Write-Host "###############################################"
    Exit
} else {
    # Run DeployAzureVDISAWEnv.ps1 + DeploySAWNetwork.ps1
    Write-Host "Deploying SAW environment..."
    .\DeployAzureVDISAWEnv.ps1
    Write-Host "SAW environment deployed."
    Write-Host "Deploying SAW network..."
    .\DeploySAWNetwork.ps1
    Write-Host "SAW network deployed."
}