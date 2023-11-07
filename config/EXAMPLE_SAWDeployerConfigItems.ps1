######################################################
# SET YOUR PARAMETERS
# Resource group and location
$SAWResourceGroupName = 'saw_resource_group'
$SAWLocation = 'AustraliaEast'

# Host Pool config items
$SAWHostPoolName = 'saw_host_pool'
$SAWHostPoolType = 'Pooled'
$SAWLoadBalancerType = 'BreadthFirst'
$SAWPreferredAppGroupType = 'Desktop'
$SAWMaxSessionLimit = '2'

# Workspace and app config items
$SAWWorkspaceName = 'saw_workspace'
$SAWAppGroupName = 'saw_app_group'
$SAWUserGroupName = 'saw_user_group'
$SAWVDIGroupRole = 'Desktop Virtualization User'
$SAWAppGroupResourceType = 'Microsoft.DesktopVirtualization/applicationGroups'

# Network config
$SAWVnetName = 'SAWVnet'
$SAWVnetRange = "10.0.96.0/22"
$SAWSubNetName = 'SAWSubNet'
$SAWSubNetRange = "10.0.98.0/26"
$SAWFWRouteTableName = "SAWFW-RouteTable"
$SAWRouteName = "SAW-Route"
$AzureFWName = 'AzureSAWFW'
$AzureFWSubNetName = 'AzureFirewallSubnet'
$AzureFWRange = "10.0.99.0/26"
$AzureFWAllocationMethod = 'Static'
$AzureFWSKU = "Standard"
$AzureFWPublicIPName = "$AzureFWName-PubIP"
$SAWFWNetRuleCollName = "SAWFWNetColl01"
$SAWFWAppRuleCollName = "SAWFWAppColl01"
######################################################
# SAW HTTP/S outbound Allowed hosts for SAWs as hashtable, no s and a key that meaningfully describes the host
$SAWOutboundAllowedHostsHTTP = @{
    'google'           = 'google.com'
    'googleapis'       = 'googleapis.com'
    'microsoft'        = 'microsoft.com'
    'microsoft_online' = 'microsoftonline.com'
    'msftconnecttest'  = 'msftconnecttest.com'
    'MSTLD'            = 'ms'
    'azure'            = 'azure.com'
    'AzureDNS'         = 'azure-dns.net'
    'azureEdge'        = 'azureedge.net'
    'azureEndpoints'   = 'azure.net'
    'windows'          = 'windows.net'
    '1password'        = '1password.com'   
    'apple'            = 'apple.com'
    'atlassian'        = 'atlassian.com'
    'bitbucket'        = 'bitbucket.org'
    'digicert'         = 'digicert.com'
    'github'           = 'github.com'
}

$SAWOutboundAllowedIP80443 = @{
    'Azure Instance Metadata service' = "169.254.169.254/32"
    'Session host monitoring'         = "168.63.129.16/32"	
}

# Array of SAW users to add to the SAW User Group
$SAWAccessGroupMembers = @(
    'john.smith@zoak.solutions',
    'billy.bob@zoak.solutions'
)