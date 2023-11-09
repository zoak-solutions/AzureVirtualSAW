######################################################
# Deploy a SAW instance to a SAW environment
# Stop on errors
$ErrorActionPreference = 'Stop'
# Load config items
if (!(Test-Path .\config\SAWDeployerConfigItems.ps1)) {
    Write-Error -Message "..\config\SAWDeployerConfigItems.ps1 not found. Exiting." -ErrorAction Stop
} else {
    . .\config\SAWDeployerConfigItems.ps1
}
######################################################
# Create Azure VDI registration key
$parameters = @{
    HostPoolName = $SAWHostPoolName
    ResourceGroupName = $SAWResourceGroupName
    ExpirationTime = $((Get-Date).ToUniversalTime().AddDays(30).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
}
# Create Registration Key if it doesn't exist
if (!(Get-AzWvdRegistrationInfo -HostPoolName $SAWHostPoolName -ResourceGroupName $SAWResourceGroupName).Token) {
    New-AzWvdRegistrationInfo @parameters
} else {
    Write-Host "Registration Key already exists"
    Write-Host "Updating existing Registration Key!"
    New-AzWvdRegistrationInfo @parameters
}
$SAWAppGroupRegistrationKey = (Get-AzWvdHostPoolRegistrationToken -HostPoolName $SAWHostPoolName -ResourceGroupName $SAWResourceGroupName).Token
Write-Host "Registrartion Key:" $SAWAppGroupRegistrationKey

Write-Host "##################################"
Write-Host "If you want to create Microsoft Entra joined session hosts, we only support this using the Azure portal with the Azure Virtual Desktop service. You can't use PowerShell to create Microsoft Entra joined session hosts."
Write-Host "Create and register session hosts with the Azure Virtual Desktop service, see:"
Write-Host "https://learn.microsoft.com/en-us/azure/virtual-desktop/add-session-hosts-host-pool?tabs=powershell%2Ccmd#create-and-register-session-hosts-with-the-azure-virtual-desktop-service"
Write-Host "##################################"

