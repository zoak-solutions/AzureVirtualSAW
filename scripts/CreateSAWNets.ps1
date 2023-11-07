######################################################
# Deploy a SAW environment in Azure
# Stop on errors
$ErrorActionPreference = 'Stop'
$Priority = 200
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

# Function to deploy FW rule collection to Azure Firewall taking both the rule collection and the Azure Firewall object as parameters
function Set-ClassicFWRuleCollection {
  param (
    [Parameter(Mandatory = $true)]
    [Object] $NewRuleCollection,
    [Parameter(Mandatory = $false)]
    [Object] $ExistingRuleCollection,
    [Parameter(Mandatory = $true)]
    [PSAzureFirewall] $AzureFirewall,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Application', 'Network')]
    [String]$RuleTypeRule
  )
  # Check if the rule collection already exists, if it does, remove it
  if ($ExistingRuleCollection) {
    Write-Host "$RuleType Rule Collection already exists, checking if differs from local config file"
    if (Compare-Object $ExstingAppRule.Rules $NewRuleCollection.Rules) {
      Write-Host "Difference found:"
      Compare-Object $ExstingAppRules $RuleCollection.Rules
      Write-Host "Azfw $(ExitingRuleCollection.Name) differs from local $($NewRuleCollection.Name), removing and replacing."
      if ($RuleTypeRule -eq 'Application') {
        $AzureFirewall.RemoveApplicationRuleCollectionByName($ExistingRuleCollection.Name)
        $AzureFirewall.ApplicationRuleCollections.Add($NewRuleCollection)
      }
      elseif ($RuleTypeRule -eq 'Application') {
        $AzureFirewall.RemoveNetworkRuleCollectionByName($ExistingRuleCollection.Name)
        $AzureFirewall.NetworkRuleCollections.Add($NewRuleCollection)
      }
      else {
        Write-Error -Message "There is a bug inside...me!" -ErrorAction Stop
      }
    }
    else {
      Write-Host "$RuleType Rule Collection matches local config file, skipping."
    }
  }
  else {
    Write-Host "$RuleType Rule Collection doesn't exist, creating."
    if ($RuleTypeRule -eq 'Application') {
      $AzureFirewall.ApplicationRuleCollections.Add($NewRuleCollection)
    }
    elseif ($RuleTypeRule -eq 'Application') {
      $AzureFirewall.NetworkRuleCollections.Add($NewRuleCollection)
    }
    else {
      Write-Error -Message "There is a bug inside...me!" -ErrorAction Stop
    }
    Set-AzFirewall -AzureFirewall $AzureFirewall
  }
  Write-Host "Azure Firewall $RuleTypeRule Rule Collection updates completed."
}

# Funtion to build application rule collection from hashtable
function Set-RuleCollectionFromConfig {
  param (
    [Parameter(Mandatory = $true)]
    [array] $ConfigRules,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Application', 'Network')]
    [String]$RuleType
  )
  $Rules = @()
  if ($RuleType -eq 'Application') {
    $NewRuleFunction = "New-AzFirewallApplicationRule"
    $NewCollectionFunction = "New-AzFirewallApplicationRuleCollection -Name $SAWFWAppRuleCollName"
  }
  elseif ($RuleType -eq 'Network') {
    $NewRuleFunction = "New-AzFirewallNetworkRule"
    $NewCollectionFunction = "New-AzFirewallNetworkRuleCollection -Name $SAWFWNetRuleCollName"
  }
  else {
    Write-Error -Message "There is a bug inside...me!" -ErrorAction Stop
  }
  foreach ( $rule in $ConfigRules ) {
    Write-Host "Creating App Rule for $rule"
    $Rules += Invoke-Expression "$NewRuleFunction $rule"
  }
  $RuleCollection = Invoke-Expression "$NewRuleCollectionFunction -Priority $Priority -ActionType Allow -Rule $Rules"
  return $RuleCollection
}
# Create App Rules
$SAWFWConfigAppRules = Set-RuleCollectionFromConfig -ConfigRules $SAWFWAppRules -RuleType Application
if ($Azfw.ApplicationRuleCollections.Name -contains $SAWFWAppRuleCollName) {
  Set-ClassicFWRuleCollection -NewRuleCollection $SAWFWConfigAppRules -ExistingRuleCollection $Azfw.GetApplicationRuleCollectionByName($SAWFWAppRuleCollName) -AzureFirewall $Azfw -RuleType Application
}
else {
  Set-ClassicFWRuleCollection -NewRuleCollection $SAWFWConfigAppRules -AzureFirewall $Azfw -RuleType Application
}
# Create Network Rules
$SAWFWConfigNetRules = Set-RuleCollectionFromConfig -ConfigRules $SAWFWNetRules -RuleType Network
if ($Azfw.NetworkRuleCollections.Name -contains $SAWFWNetRuleCollName) {
  Set-ClassicFWRuleCollection -NewRuleCollection $SAWFWConfigNetRules -ExistingRuleCollection $Azfw.GetNetworkRuleCollectionByName($SAWFWNetRuleCollName) -AzureFirewall $Azfw -RuleType Network
}
else {
  Set-ClassicFWRuleCollection -NewRuleCollection $SAWFWConfigNetRules -AzureFirewall $Azfw -RuleType Network
}
# Enable DNS proxy
$azFw.DNSEnableProxy = $true
Set-AzFirewall -AzureFirewall $Azfw