######################################################
# Deploy a SAW environment in Azure
# Stop on errors
$ErrorActionPreference = 'Stop'
# Load config items
if (!(Test-Path .\config\SAWDeployerConfigItems.ps1)) {
    Write-Error -Message "..\config\SAWDeployerConfigItems.ps1 not found. Exiting." -ErrorAction Stop
} else {
    . .\config\SAWDeployerConfigItems.ps1
}
######################################################
# Create a Resource Group
# Create resource group if it doesn't exist
if (!(Get-AzResourceGroup -Name $SAWResourceGroupName -ErrorAction SilentlyContinue)) {
    $parameters = @{
        Name     = $SAWResourceGroupName
        Location = $SAWLocation
    }
    New-AzResourceGroup @parameters
}
else {
    Write-Host "Resource Group $SAWResourceGroupName already exists"
}
az group show --name $SAWResourceGroupName

# Create a Host Pool
$parameters = @{
    Name                  = $SAWHostPoolName
    ResourceGroupName     = $SAWResourceGroupName
    HostPoolType          = $SAWHostPoolType
    LoadBalancerType      = $SAWLoadBalancerType
    PreferredAppGroupType = $SAWPreferredAppGroupType
    MaxSessionLimit       = $SAWMaxSessionLimit
    Location              = $SAWLocation
}
# Create host pool if it doesn't exist
if (!(Get-AzWvdHostPool -Name $SAWHostPoolName -ResourceGroupName $SAWResourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzWvdHostPool @parameters
}
else {
    Write-Host "Host Pool $SAWHostPoolName already exists"
}
Get-AzWvdHostPool -Name $SAWHostPoolName -ResourceGroupName $SAWResourceGroupName | FL *

# Create a workspace
$parameters = @{
    Name              = $SAWWorkspaceName
    ResourceGroupName = $SAWResourceGroupName
    Location          = $SAWLocation
}
# Create workspace if it doesn't exist
if (!(Get-AzWvdWorkspace -Name $SAWWorkspaceName -ResourceGroupName $SAWResourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzWvdWorkspace @parameters
}
else {
    Write-Host "Workspace $SAWWorkspaceName already exists"
}
Get-AzWvdWorkspace -Name $SAWWorkspaceName -ResourceGroupName $SAWResourceGroupName | FL *

# Create an Application Group
$HostPoolArmPath = (Get-AzWvdHostPool -Name $SAWHostPoolName -ResourceGroupName $SAWResourceGroupName).Id
$parameters = @{
    Name                 = $SAWAppGroupName
    ResourceGroupName    = $SAWResourceGroupName
    Location             = $SAWLocation
    HostPoolArmPath      = $HostPoolArmPath
    ApplicationGroupType = $SAWPreferredAppGroupType
}
# Create application group if it doesn't exist
if (!(Get-AzWvdApplicationGroup -Name $SAWAppGroupName -ResourceGroupName $SAWResourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzWvdApplicationGroup @parameters
}
else {
    Write-Host "Application Group $SAWAppGroupName already exists"
}
Get-AzWvdApplicationGroup -Name $SAWAppGroupName -ResourceGroupName $SAWResourceGroupName | FL *

# Add Application Group to Workspace
$AppGroupPath = (Get-AzWvdApplicationGroup -Name $SAWAppGroupName -ResourceGroupName $SAWResourceGroupName).Id

# If the workspace doesn't have the application group, add it
if (!(Get-AzWvdWorkspace -Name $SAWWorkspaceName -ResourceGroupName $SAWResourceGroupName -ErrorAction SilentlyContinue).ApplicationGroupReferences) {
    $parameters = @{
        Name                      = $SAWWorkspaceName
        ResourceGroupName         = $SAWResourceGroupName
        ApplicationGroupReference = $AppGroupPath
    }
    Update-AzWvdWorkspace @parameters
}
else {
    Write-Host "Application Group $SAWAppGroupName already exists in Workspace $SAWWorkspaceName"
}
Get-AzWvdWorkspace -Name $SAWWorkspaceName -ResourceGroupName $SAWResourceGroupName | FL *

# Create Entra User Group if it doesn't exist
if (!(Get-AzADGroup -DisplayName $SAWUserGroupName -ErrorAction SilentlyContinue)) {
    $parameters = @{
        DisplayName     = $SAWUserGroupName
        MailNickname    = $SAWUserGroupName
        SecurityEnabled = $true
        MailEnabled     = $false
    }
    New-AzADGroup @parameters
}

# Assign Entra Group to an Application Group
$userGroupId = (Get-AzADGroup -DisplayName $SAWUserGroupName).Id
$parameters = @{
    ObjectID           = $userGroupId
    ResourceName       = $SAWAppGroupName
    ResourceGroupName  = $SAWResourceGroupName
    RoleDefinitionName = $SAWVDIGroupRole
    ResourceType       = $SAWAppGroupResourceType
}
# Assign user group to application group if it isn't already assigned
if (!(Get-AzRoleAssignment -ResourceGroupName $SAWResourceGroupName -ObjectID $userGroupId -RoleDefinitionName $SAWVDIGroupRole -ResourceName $SAWAppGroupName -ResourceType $SAWAppGroupResourceType -ErrorAction SilentlyContinue)) {
    New-AzRoleAssignment @parameters
}
else {
    Write-Host "User Group $SAWUserGroupName already assigned to Application Group $SAWAppGroupName"
}
