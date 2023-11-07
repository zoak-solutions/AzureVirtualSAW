######################################################
# Deploy a SAW environment in Azure
# Stop on errors
$ErrorActionPreference = 'Stop'
# Load config items
. .\SAWDeployerConfigItems.ps1
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
