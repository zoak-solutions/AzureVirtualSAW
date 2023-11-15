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
$SAWDynamicDeviceGroup = 'saw_dynamic_device_group'
$SAWVMNamePrefix = 'saw-avd-vm'
$SAWVMTagName = 'AVD'
$SAWVMTag = @{$SAWVMTagName = $SAWVMNamePrefix }
$SAWDynamicDeviceGroupMembershipRule = "tags/$SAWVMTagName -eq '$SAWVMNamePrefix'"
$SAWCustomRdpProperties = "drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:1;enablerdsaadauth:i:1;" # https://learn.microsoft.com/en-us/azure/virtual-desktop/rdp-properties
$AVDEnterpriseApplicationsAndRoles = # https://learn.microsoft.com/en-us/azure/virtual-desktop/configure-single-sign-on?WT.mc_id=Portal-Microsoft_Azure_WVD#enable-microsoft-entra-authentication-for-rdp
@(
    @{ "AppID" = "a4a365df-50f1-4397-bc59-1a1564b8bb9c"; "AppRole" = "Default Access" }
    @{ "AppID" = "270efc09-cd0d-444b-a71f-39af4910ec45"; "AppRole" = "Default Access" }
)

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
$AzureDNSResolverIP = @("168.63.129.16")
$AzureFWAllocationMethod = 'Static'
$AzureFWSKU = "Standard"
$ThreatIntelMode = "Deny"
$AzureFWPublicIPName = "$AzureFWName-PubIP"
$SAWFWPolicyName = "SAWFWPolicy"
$SAWFWNetRuleCollName = "SAWFWNetColl01"
$SAWFWAppRuleCollName = "SAWFWAppColl01"
######################################################
# SAW HTTP/S outbound Allowed hosts for SAWs as hashtable, no s and a key that meaningfully describes the host
$SAWFWAppRules = @(
    @{Name = "AzureFQDNTagAllows"; FqdnTag = ("AppServiceEnvironment", "AzureBackup", "AzureKubernetesService", "HDInsight", "MicrosoftActiveProtectionService", "MicrosoftIntune", "Windows365", "WindowsDiagnostics", "WindowsUpdate", "WindowsVirtualDesktop", "Office365.Exchange.Optimize", "Office365.Exchange.Default.Required", "Office365.Exchange.Allow.Required", "Office365.SharePoint.Optimize", "Office365.SharePoint.Default.Required", "Office365.Common.Default.NotRequired", "Office365.Common.Allow.Required", "Office365.Common.Default.Required"); SourceAddress = $SAWSubNetRange }
    @{Name = "google"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "google.com" }
    @{Name = "googleapis"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "googleapis.com" }
    @{Name = "microsoft"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "microsoft.com" }
    @{Name = "microsoft_online"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "microsoftonline.com" }
    @{Name = "msftconnecttest"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "msftconnecttest.com" }
    @{Name = "MSTLD"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "ms" }
    @{Name = "azure"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "azure.com" }
    @{Name = "AzureDNS"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "azure-dns.net" }
    @{Name = "azureEdge"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "azureedge.net" }
    @{Name = "azureEndpoints"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "azure.net" }
    @{Name = "windows"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "windows.net" }
    @{Name = "1password"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "1password.com" }
    @{Name = "apple"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "apple.com" }
    @{Name = "atlassian"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "atlassian.com" }
    @{Name = "bitbucket"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "bitbucket.org" }
    @{Name = "digicert"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "digicert.com" }
    @{Name = "github"; SourceAddress = $SAWSubNetRange; Protocol = @("http", "https"); TargetFqdn = "github.com" }
)

# As per: https://learn.microsoft.com/en-us/azure/firewall/protect-azure-virtual-desktop?tabs=azure#create-network-rules
$SAWFWNetRules = @(
    @{Name = "Azure Instance Metadata service"; SourceAddress = $SAWSubNetRange; Protocol = "TCP"; DestinationAddress = @("169.254.169.254/32"); DestinationPort = @("80", "443") }
    @{Name = "Session host monitoring"; SourceAddress = $SAWSubNetRange; Protocol = "TCP"; DestinationAddress = @("168.63.129.16/32"); DestinationPort = @("80", "443") }
    @{Name = "DNS to AzureFW"; SourceAddress = $SAWSubNetRange; Protocol = @("TCP", "UDP"); DestinationAddress = $AzureFWRange; DestinationPort = @("53") }
    @{Name = "azkms.core.windows.net IPs"; SourceAddress = $SAWSubNetRange; Protocol = "TCP"; DestinationAddress = @("20.118.99.224", "40.83.235.53", "23.102.135.246"); DestinationPort = @("1688") }
)

# Array of SAW users to add to the SAW User Group
$SAWAccessGroupMembers = @(
    'john.smith@zoak.solutions',
    'billy.bob@zoak.solutions'
)