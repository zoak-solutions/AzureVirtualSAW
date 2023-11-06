# DeploySAW.ps1 
# Check for -Destroy switch and -NoDeploy switch
# If -Destroy switch is present, destroy the SAW environment and then run DeployAzureVDISAWEnv.ps1 + DeploySAWNetwork.ps1
# If -NoDeploy switch is present, just destroy the SAW environment by its resource group name
# If neither switch is present, run DeployAzureVDISAWEnv.ps1 + DeploySAWNetwork.ps1
param (
    [switch]$Destroy,
    [switch]$NoDeploy,
    [switch]$SkipNetwork,
    [switch]$SkipVDIEnv,
    [switch]$SkipRegKey
)
$ErrorActionPreference = 'Stop'
Write-Host "### Start at: $(Get-Date) ###"
# Check for SAWDeployerConfigItems.ps1
if (!(Test-Path .\config\SAWDeployerConfigItems.ps1)) {
    Write-Error -Message ".\config\SAWDeployerConfigItems.ps1 not found. Exiting." -ErrorAction Stop
} else {
    . .\config\SAWDeployerConfigItems.ps1
}

function Destroy-SAWEnvironment {
    param (
        [Parameter(Mandatory)]
        [string]$RGToDestroy
    )
    Write-Host "Destroying resource group: $RGToDestroy"
    if (!(Get-AzResourceGroup -Name $RGToDestroy -ErrorAction SilentlyContinue)) {
        Write-Error -Message "Resource group: $RGToDestroy not found. Exiting." -ErrorAction Stop
    }
    else {
        Write-Host "Destroying Resource group: $RGToDestroy (this can take some time...)."
        Remove-AzResourceGroup -Name $RGToDestroy -Force 
        Write-Host "Resource group: $RGToDestroy destroyed."
    }
}

# Check for -Destroy switch and -NoDeploy switch
if ($Destroy) {
    Destroy-SAWEnvironment -RGToDestroy $SAWResourceGroupName
} if ($NoDeploy) {
    Write-Host "###############################################" 
    Write-Host "-NoDeploy switch present, skipping deployment and exiting." 
    Write-Host "###############################################"
    Exit
} if ($SkipVDIEnv) {
    Write-Host "Skipping VDIEnv deploy"
} else {
    Write-Host "Deploying SAW VDI environment..."
    .\scripts\CreateAzureVDIEnv.ps1
    Write-Host "SAW environment deployed."
} if ($SkipNetwork) {
    Write-Host "Skipping network deploy"
} else {
    Write-Host "Deploying SAW network..."
    .\scripts\CreateSAWNets.ps1
    Write-Host "SAW network deployed."
} if ($SkipRegKey) {
    Write-Host "Skipping Reg Key create"
} else {
    Write-Host "Creating session host Registration Key.."
    .\scripts\CreateRegKey.ps1
    Write-Host "SAW Registration Key Created"
}
Write-Host "### DONE at: $(Get-Date)  ###"
