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
    ######################################################
    # Add each UPN in $SAWAccessGroupMembers to the SAW User Group
    # Get the SAW User Group object
    $SAWUserGroup = Get-AzADGroup -DisplayName $SAWUserGroupName
    $SAWUserGroupExistingMembers = Get-AzADGroupMember -GroupObjectId $SAWUserGroup.Id
    # Add each UPN in $SAWAccessGroupMembers to the SAW User Group
    foreach ($UPN in $SAWAccessGroupMembers) {
        Write-Host "Adding user: $UPN to SAW User Group: $SAWUserGroupName"
        if ($SAWUserGroupExistingMembers.UserPrincipalName -contains $UPN) {
            Write-Host "User: $UPN already a member of SAW User Group: $SAWUserGroupName"
        }
        else {
            Add-AzADGroupMember -MemberUserPrincipalName $UPN -TargetGroupObjectId $SAWUserGroup.Id
            Write-Host "User: $UPN added to SAW User Group: $SAWUserGroupName"
        }
    }
    Write-Host "SAW User Group members:"
    Get-AzADGroupMember -GroupObjectId $SAWUserGroup.Id
    Write-Host "SAW User Group members added."
}
catch {
    Write-Error "Error in script: $_" -ErrorAction Stop
}
finally {
    Stop-Transcript
}
