######################################################
# Deploy a SAW environment in Azure
# Stop on errors
$ErrorActionPreference = 'Stop'
# Load config items
. .\SAWDeployerConfigItems.ps1
######################################################
# Consideration items
# Host pool -> RDP properties ->  Entra Single Sign on, Credential Security Provider, !!! Default is not entra single sign on
# Host pool -> Public network access -> Enable pulic access from all / ENable puclic access for end users / Use private access

# Deploy Network components
# Create an SAWVnet, AzureFirewallSubnet and SAWSubnet if they don't exist
if (!(Get-AzVirtualNetwork -Name $SAWVnetName -ResourceGroupName $SAWResourceGroupName -ErrorAction SilentlyContinue)) {
  Write-Host "Creating AzureFirewallSubnet..."
  $FWSubNet = New-AzVirtualNetworkSubnetConfig -Name $AzureFWSubNetName -AddressPrefix $AzureFWRange
  Write-Host "Creating SAWSubnet..."
  $SAWSubNet = New-AzVirtualNetworkSubnetConfig -Name $SAWSubNetName -AddressPrefix $SAWSubNetRange
  Write-Host "Creating SAWVnet..."
  $SAWVnet = New-AzVirtualNetwork -Name $SAWVnetName -ResourceGroupName $SAWResourceGroupName -Location $SAWLocation -AddressPrefix $SAWVnetRange -Subnet $SAWSubNet, $FWSubNet
}
else {
  Write-Host "SAWVnet already exists, skipping Vnet and subnet creation..."
  $SAWVnet = Get-AzVirtualNetwork -Name $SAWVnetName -ResourceGroupName $SAWResourceGroupName
}

# Get a Public IP for the firewall if it doesn't exist
if (!(Get-AzPublicIpAddress -Name $AzureFWPublicIPName -ResourceGroupName $SAWResourceGroupName -ErrorAction SilentlyContinue)) {
  Write-Host "Creating AzureFWPublicIP..."
  $FWpip = New-AzPublicIpAddress -Name $AzureFWPublicIPName -ResourceGroupName $SAWResourceGroupName -Location $SAWLocation -AllocationMethod $AzureFWAllocationMethod -Sku $AzureFWSKU
}
else {
  Write-Host "AzureFWPublicIP already exists, skipping..."
  $FWpip = Get-AzPublicIpAddress -Name $AzureFWPublicIPName -ResourceGroupName $SAWResourceGroupName
}

# Create the firewall if it doesn't exist
if (!(Get-AzFirewall -Name $AzureFWName -ResourceGroupName $SAWResourceGroupName -ErrorAction SilentlyContinue)) {
  Write-Host "Creating AzureFW..."
  $Azfw = New-AzFirewall -Name $AzureFWName -ResourceGroupName $SAWResourceGroupName -Location $SAWLocation -VirtualNetwork $SAWVnet -PublicIpAddress $FWpip
}
else {
  Write-Host "AzureFW already exists, skipping..."
  $Azfw = Get-AzFirewall -Name $AzureFWName -ResourceGroupName $SAWResourceGroupName
}

# Save the firewall private IP address for future use
$AzfwPrivateIP = $Azfw.IpConfigurations.privateipaddress
Write-host "Azure FW Private IP: $AzfwPrivateIP"

# Create a route table, with BGP route propagation disabled if it doesn't exist
if (!(Get-AzRouteTable -Name $SAWFWRouteTableName -ResourceGroupName $SAWResourceGroupName -ErrorAction SilentlyContinue)) {
  Write-Host "Creating route table..."
  $routeTableDG = New-AzRouteTable -Name $SAWFWRouteTableName -ResourceGroupName $SAWResourceGroupName -Location $SAWLocation -DisableBgpRoutePropagation
}
else {
  Write-Host "Route table already exists, skipping..."
  $routeTableDG = Get-AzRouteTable -Name $SAWFWRouteTableName -ResourceGroupName $SAWResourceGroupName
}

# Create a route if it doesn't exist
if (!(Get-AzRouteConfig -Name $SAWRouteName -RouteTable $routeTableDG -ErrorAction SilentlyContinue)) {
  Write-Host "Creating route..."
  Add-AzRouteConfig -Name $SAWRouteName -RouteTable $routeTableDG -AddressPrefix 0.0.0.0/0 -NextHopType "VirtualAppliance" -NextHopIpAddress $AzfwPrivateIP | Set-AzRouteTable
}
else {
  Write-Host "Route already exists, skipping..."
}

#Associate the route table to the subnet if it isn't already
if (!(Get-AzVirtualNetworkSubnetConfig -Name $SAWSubNetName -VirtualNetwork $SAWVnet -ErrorAction SilentlyContinue).RouteTable) {
  Write-Host "Associating route table to subnet..."
  Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $SAWVnet -Name $SAWSubNetName -AddressPrefix $SAWSubNetRange -RouteTable $routeTableDG | Set-AzVirtualNetwork
}
else {
  Write-Host "Route table already associated to subnet, skipping..."
}

# Allow outbound internet access for the SAWs, iterating through the $SAWOutboundAllowedHostsHTTP hashtable and creating an Application Rule for each, only if it doesn't already exist
$FWAppRuleArrayHTTPAllow = @()
$SAWOutboundAllowedHostsHTTP.GetEnumerator() | ForEach-Object {
  Write-Host "Creating Application Rule for $_"
  $AppRule = New-AzFirewallApplicationRule -Name $_.Key -SourceAddress $SAWSubNetRange -Protocol http, https -TargetFqdn $_.Value
  $FWAppRuleArrayHTTPAllow += $AppRule
}
# Create or replace the Application Rule Collection with the rules
# Check if the Application Rule Collection already exists, if it does, remove it
if ($Azfw.ApplicationRuleCollections.Name -contains $SAWFWAppRuleCollName) {
  Write-Host "Application Rule Collection already exists and associated, removing and replacing."
  $Azfw.RemoveApplicationRuleCollectionByName($SAWFWAppRuleCollName)
}
else {
  Write-Host "Application Rule Collection doesn't exist, creating."
}
# Remove-AzFirewallPolicyRuleCollectionGroup -Name $SAWFWAppRuleCollName -ResourceGroupName $SAWResourceGroupName -AzureFirewallPolicyName $AzureFWName -Force -ErrorAction Continue
$HTTPAppRuleCollection = New-AzFirewallApplicationRuleCollection -Name $SAWFWAppRuleCollName -Priority 200 -ActionType Allow -Rule $FWAppRuleArrayHTTPAllow
$Azfw.ApplicationRuleCollections.Add($HTTPAppRuleCollection)
Set-AzFirewall -AzureFirewall $Azfw

# Create Network Rules for the SAWs from SAWOutboundAllowedIP80443 hashtable
$FWNetworkRuleArray80443Allow = @()
$SAWOutboundAllowedIP80443.GetEnumerator() | ForEach-Object {
  Write-Host "Creating Network Rule for $_"
  $NetworkRule = New-AzFirewallNetworkRule -Name $_.Key -SourceAddress $SAWSubNetRange -Protocol TCP -DestinationAddress $_.Value -DestinationPort @("80", "443")
  $FWNetworkRuleArray80443Allow += $NetworkRule
}
# Check if the Network Rule Collection already exists, if it does, remove it
if ($Azfw.NetworkRuleCollections.Name -contains $SAWFWNetRuleCollName) {
  Write-Host "Network Rule Collection already exists, removing and replacing."
  $Azfw.RemoveNetworkRuleCollectionByName($SAWFWNetRuleCollName)
}
else {
  Write-Host "Network Rule Collection doesn't exist, creating."
}
#Remove-AzFirewallPolicyRuleCollectionGroup -Name $SAWFWNetRuleCollName -ResourceGroupName $SAWResourceGroupName -AzureFirewallPolicyName $AzureFWName -Force -ErrorAction Continue
$NetworkRuleCollection80443Allow = New-AzFirewallNetworkRuleCollection -Name $SAWFWNetRuleCollName -Priority 201 -ActionType Allow -Rule $FWNetworkRuleArray80443Allow
$Azfw.NetworkRuleCollections.Add($NetworkRuleCollection80443Allow)
Set-AzFirewall -AzureFirewall $Azfw
