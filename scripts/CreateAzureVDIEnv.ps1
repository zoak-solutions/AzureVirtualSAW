######################################################
# Deploy a SAW environment in Azure
# Stop on errors
[CmdletBinding()]
Param(
    [ValidateScript({ if ($_) { Test-Path $_ } })]
    [string]$ConfigFile = "$(( get-item $PSScriptRoot ).parent.FullName)\config\SAWDeployerConfigItems.ps1"
)
$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
$script_name = $MyInvocation.MyCommand.Name
$script_path = $PSScriptRoot
Start-Transcript -Append "$script_path\..\logs\$script_name-$timestamp.log"
try {
    Write-Debug -Message "Script name: $script_name"
    # Load config items
    if (!(Test-Path $ConfigFile)) {
        Write-Error -Message "$ConfigFile not found. Exiting." -ErrorAction Stop
    }
    else {
        . $ConfigFile
    }
    ################################################
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
    az group show --name $SAWResourceGroupName --query  "[?location=='''$SAWLocation''']"

    # Create a Host Pool

    # Create host pool if it doesn't exist
    if (!(Get-AzWvdHostPool -Name $SAWHostPoolName -ResourceGroupName $SAWResourceGroupName -ErrorAction SilentlyContinue)) {
        $parameters = @{
            Name                  = $SAWHostPoolName
            ResourceGroupName     = $SAWResourceGroupName
            HostPoolType          = $SAWHostPoolType
            LoadBalancerType      = $SAWLoadBalancerType
            PreferredAppGroupType = $SAWPreferredAppGroupType
            MaxSessionLimit       = $SAWMaxSessionLimit
            Location              = $SAWLocation
            CustomRdpProperty     = $SAWCustomRdpProperty
            #[-VMTemplate String]
        }
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
    else {
        Write-Host "User Group $SAWUserGroupName already exists, skipping"
    }

    # Assign Entra Group to an Application Group
    $userGroupId = (Get-AzADGroup -DisplayName $SAWUserGroupName).Id
    # Assign user group to application group if it isn't already assigned
    if (!(Get-AzRoleAssignment -ResourceGroupName $SAWResourceGroupName -ObjectID $userGroupId -RoleDefinitionName $SAWVDIGroupRole -ResourceName $SAWAppGroupName -ResourceType $SAWAppGroupResourceType -ErrorAction SilentlyContinue)) {
        $parameters = @{
            ObjectID           = $userGroupId
            ResourceName       = $SAWAppGroupName
            ResourceGroupName  = $SAWResourceGroupName
            RoleDefinitionName = $SAWVDIGroupRole
            ResourceType       = $SAWAppGroupResourceType
        }
        New-AzRoleAssignment @parameters
    }
    else {
        Write-Host "User Group $SAWUserGroupName already assigned to Application Group $SAWAppGroupName"
    }

    # Create a dynamic Entra device group for SAWS
    if (!(Get-AzADGroup -DisplayName $SAWDynamicDeviceGroupName -ErrorAction SilentlyContinue)) {
        $parameters = @{
            DisplayName                   = $SAWDynamicDeviceGroupName
            MailNickname                  = $SAWDynamicDeviceGroupName
            SecurityEnabled               = $true
            MailEnabled                   = $false
            GroupType                     = "DynamicMembership"
            MembershipRule                = $SAWDynamicDeviceGroupMembershipRule
            MembershipRuleProcessingState = "On"
        }
        New-AzADGroup @parameters
    }
    else {
        Write-Host "Device Group $SAWDeviceGroupName already exists, skipping"
    }
} # End try
catch {
    Write-Error "Error in script: $_" -ErrorAction Stop
}
finally {
    Stop-Transcript
}
