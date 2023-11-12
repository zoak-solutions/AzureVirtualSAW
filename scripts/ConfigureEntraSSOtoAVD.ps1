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
    # if not Connect-AzureAD then connect
    Write-Host "Connecting to Azure AD"
    try {
        Get-AZTenant -ErrorAction STOP
        Write-Host "Already connected to Azure AD"
    }
    catch {
        Write-Host "Not connected to Azure AD. Connecting now."
        Connect-AZTenant
    }
    
    # https://learn.microsoft.com/en-us/azure/virtual-desktop/configure-single-sign-on?WT.mc_id=Portal-Microsoft_Azure_WVD#enable-microsoft-entra-authentication-for-rdp
    # Allow Microsoft Entra authentication for Windows in your Microsoft Entra tenant. This will enable issuing RDP access tokens allowing users to sign in to Azure Virtual Desktop session hosts. This is done by enabling the isRemoteDesktopProtocolEnabled property on the service principal's remoteDesktopSecurityConfiguration object for the apps listed above.
    # Use the Microsoft Graph API to create remoteDesktopSecurityConfiguration and set the property isRemoteDesktopProtocolEnabled to true to enable Microsoft Entra authentication.
    # https://docs.microsoft.com/en-us/graph/api/resources/remote-desktop-security-configuration?view=graph-rest-beta
    # https://docs.microsoft.com/en-us/graph/api/resources/remote-desktop-security-configuration?view=graph-rest-beta#properties
    # ObjectId = Group object ID    
    # Id = App role ID    
    # PrincipalId = Group object ID    
    # ResourceId = Enterprise Application object ID
    Write-Host "Assign SAW user + device group to AVD Enterprise Application roles required as per: https://learn.microsoft.com/en-us/azure/virtual-desktop/configure-single-sign-on"
    $userGroupId = (Get-AzADGroup -DisplayName $SAWUserGroupName).Id
    $deviceGroupId = (Get-AzADGroup -DisplayName $SAWDynamicDeviceGroupName).Id
    $AVDEnterpriseApplicationsAndRoles | ForEach-Object {
        $FilterString = "AppId eq '" + $_.AppID + "'"
        $AppSP = (Get-AzADServicePrincipal -Filter "$FilterString")
        if (Get-AzureADGroupAppRoleAssignment -ObjectId $userGroupId | Where-Object -Property ResourceDisplayName -eq $AppSP.DisplayName) {
            Write-Host "$SAWUserGroupName already has $($AppSP.DisplayName), $($AppSP.Id) role assigned"
        }
        else {
            Write-Host "Assigning group: $SAWUserGroupName role for $($AppSP.DisplayName) $($AppSP.AppId), ObjectId: $($AppSP.Id)"
            New-AzureADGroupAppRoleAssignment -ObjectId $userGroupId -PrincipalId $userGroupId -ResourceId $AppSP.Id -Id $_.AppRoleID
        }
        if (Get-AzureADGroupAppRoleAssignment -ObjectId $deviceGroupId | Where-Object -Property ResourceDisplayName -eq $AppSP.DisplayName) {
            Write-Host "$SAWDynamicDeviceGroupName already has role for $($AppSP.DisplayName) $($AppSP.AppId)"
        }
        else {
            Write-Host "Assigning group: $SAWDynamicDeviceGroupName role for $($AppSP.DisplayName) (AppID: $($AppSP.AppId), ObjectId: $($AppSP.Id))"
            New-AzureADGroupAppRoleAssignment -ObjectId $deviceGroupId -PrincipalId $deviceGroupId -ResourceId $AppSP.Id -Id $_.AppRoleID
        }
    }  
}
catch {
    Write-Error "Error in script: $_" -ErrorAction Stop
}
finally {
    Stop-Transcript
}
