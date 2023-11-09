######################################################
# Deploy a SAW environment in Azure
# Stop on errors
$ErrorActionPreference = 'Stop'
# Load config items
if (!(Test-Path .\config\SAWDeployerConfigItems.ps1)) {
  Write-Error -Message "..\config\SAWDeployerConfigItems.ps1 not found. Exiting." -ErrorAction Stop
}
else {
  . .\config\SAWDeployerConfigItems.ps1
}
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

# Enable DNS proxy
$azFw.DNSEnableProxy = $true
Set-AzFirewall -AzureFirewall $Azfw

# Save the firewall private IP address for future use
$AzfwPrivateIP = $Azfw.IpConfigurations.privateipaddress
Write-host "Azure FW Private IP: $AzfwPrivateIP"
# Update VNet to use Azure Firewall as DNS proxy
$dnsServers = @($AzfwPrivateIP)
$SAWVnet.DhcpOptions.DnsServers = $dnsServers
$SAWVnet | Set-AzVirtualNetwork

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

# Function to create a Firewall Policy 
function New-FirewallPolicy {
  param (
    [Parameter(Mandatory = $true)]
    [String] $PolicyName,
    [Parameter(Mandatory = $true)]
    [String] $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [String] $Location,
    [Parameter(Mandatory = $true)]
    [object] $ExistingSAWFW
  )
  Write-Host "Creating/Replacing $PolicyName Firewall Policy..."
  Write-Host "Ideally this should compare any existing and not replace if unchanged...but not at present"
  try {
    if (Get-AzFirewallPolicy -Name "$PolicyName" -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) {
      Write-Host "Found existing Firewall Policy named $PolicyName, removing..."
      Remove-AzFirewallPolicy -Name "$PolicyName" -ResourceGroupName $ResourceGroupName -Force
    }
    $NewAZFWPolicy = New-AzFirewallPolicy -Name "$PolicyName" -ResourceGroupName $ResourceGroupName -Location $Location -Force
    # FW Application rules
    $SAWFWAppRuleArray = $SAWFWAppRules | Foreach-Object { 
      Write-Host "Creating App Rule: $($_.Name)"
      try {
        $RULE = New-AzFirewallPolicyApplicationRule @_; $RULE 
      }
      catch {
        Write-Error "Error creating Firewall Policy Application Rule: $_" -ErrorAction Stop
      }
    }
    $SAWFWAppRuleColl = New-AzFirewallPolicyFilterRuleCollection -Name $SAWFWAppRuleCollName -Priority 100 -Rule $SAWFWAppRuleArray -ActionType Allow
    $SAWFWRCGroupApp = New-AzFirewallPolicyRuleCollectionGroup -Name "$SAWFWPolicyName-RCGroup-App" -Priority 100 -RuleCollection $SAWFWAppRuleColl -FirewallPolicyObject $NewAZFWPolicy
    # FW Network rules
    $SAWFWNetRuleArray = $SAWFWNetRules | Foreach-Object { 
      Write-Host "Creating Net Rule: $($_.Name)"
      try {
        $RULE = New-AzFirewallPolicyNetworkRule @_; $RULE 
      }
      catch {
        Write-Error "Error creating Firewall Policy Network Rule: $_" -ErrorAction Stop
      }
    }
    $SAWFWNetRuleColl = New-AzFirewallPolicyFilterRuleCollection -Name $SAWFWNetRuleCollName -Priority 200 -Rule $SAWFWNetRuleArray -ActionType Allow
    $SAWFWRCGroupNet = New-AzFirewallPolicyRuleCollectionGroup -Name "$SAWFWPolicyName-RCGroup-Net" -Priority 200 -RuleCollection $SAWFWNetRuleColl -FirewallPolicyObject $NewAZFWPolicy
    
    $ExistingSAWFW.Policy = $NewAZFWPolicy
    Set-AzFirewall -AzureFirewall $ExistingSAWFW
  }
  catch {
    Write-Error "Error creating Firewall Policy: $_" -ErrorAction Stop
  } 
}

# Create FW Policy deploying if required
New-FirewallPolicy -PolicyName $SAWFWPolicyName -ResourceGroupName $SAWResourceGroupName -Location $SAWLocation -ExistingSAWFW $Azfw