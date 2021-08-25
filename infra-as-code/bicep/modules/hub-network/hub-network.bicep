/*
SUMMARY: Module to deploy ALZ Hub Network 
DESCRIPTION: The following components will be options in this deployment
              VNET
              Subnets
              VPN Gateway
              ExpressRoute Gateway
              Azure Firewall or 3rd Party NVA
              NSG
              Ddos Plan
              Bastion
AUTHOR/S: Troy Ault
VERSION: 1.0.0
*/

//@description('The Azure regions into which the resources should be deployed.')
//param parLocations array = [
//  'eastus2'
//]

@description('Switch which allows Bastion deployment to be disabled')
param parBastionEnabled bool = true

@description('Switch which allows DDOS deployment to be disabled')
param parDdosEnabled bool = true

@description('Switch which allows Azure Firewall deployment to be disabled')
param parAzureFirewallEnabled bool = true

@description('Switch which allows Virtual Network Gateway deployment to be disabled')
param parGatewayEnabled bool = true

@description('DDOS Plan Name')
param parDDOSPlanName string = 'MyDDosPlan'

@description('Azure SKU or Tier to deploy.  Currently two options exist Basic and Standard')
param parBastionSku string = 'Standard'

@description('Public Ip Address SKU')
@allowed([
  'Basic'
  'Standard'
])
param parPublicIPSku string = 'Standard'

@description('Tags you would like to be applied to all resources in this module')
param parTags object = {}

@description('Parameter to specify Type of Gateway to deploy')
@allowed([
  'Vpn'
  'ExpressRoute'
  'LocalGateway'
])
param parGatewayType string = 'Vpn'

@description('Name of the Express Route/VPN Gateway which will be created')
param parGatewayName string = 'MyGateway'

@description('Type of virtual Network Gateway')
@allowed([
  'PolicyBased'
  'RouteBased'
])
param parVpnType string ='RouteBased'

@description('Sku/Tier of Virtual Network Gateway to deploy')
param parVpnSku string = 'VpnGw1'

@description('The IP address range for all virtual networks to use.')
param parVirtualNetworkAddressPrefix string = '10.10.0.0/16'

@description('Prefix Used for Hub Network')
param parHubNetworkPrefix string = 'Hub'

@description('Azure Firewall Name')
param parAzureFirewallName string ='MyAzureFirewall'

@description('The name and IP address range for each subnet in the virtual networks.')
param parSubnets array = [
  {
    name: 'frontend'
    ipAddressRange: '10.10.5.0/24'
  }
  {
    name: 'backend'
    ipAddressRange: '10.10.10.0/24'
  }
  {
    name: 'AzureBastionSubnet'
    ipAddressRange: '10.10.15.0/24' 
  }
  {
    name: 'GatewaySubnet'
    ipAddressRange: '10.10.252.0/24'
  }
  {
    name: 'AzureFirewallSubnet'
    ipAddressRange: '10.10.254.0/24'
  }
]

var varSubnetProperties = [for subnet in parSubnets: {
  name: subnet.name
  properties: {
    addressPrefix: subnet.ipAddressRange
  }
}]

var varBastionName = 'bastion-${resourceGroup().location}'


resource resDdosProtectionPlan 'Microsoft.Network/ddosProtectionPlans@2021-02-01' = if(parDdosEnabled) {
  name: parDDOSPlanName
  location: resourceGroup().location
  tags: parTags 
}


resource resVirtualNetworks 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: '${parHubNetworkPrefix}-${resourceGroup().location}'
  location: resourceGroup().location
  properties:{
    addressSpace:{
      addressPrefixes:[
        parVirtualNetworkAddressPrefix
      ]
    }
    subnets: varSubnetProperties
    enableDdosProtection:parDdosEnabled
    ddosProtectionPlan: (parDdosEnabled) ? {
      id: resDdosProtectionPlan.id
      } : null
  }
}


resource resBastionPublicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = if(parBastionEnabled){
  location: resourceGroup().location
  name: '${varBastionName}-PublicIp'
  tags: parTags
  sku: {
      name: parPublicIPSku
  }
  properties: {
      publicIPAddressVersion: 'IPv4'
      publicIPAllocationMethod: 'Static'
  }
}


resource resBastionSubnetRef 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  parent: resVirtualNetworks
  name: 'AzureBastionSubnet'
} 


resource resBastion 'Microsoft.Network/bastionHosts@2021-02-01' = if(parBastionEnabled){
  location: resourceGroup().location
  name: varBastionName
  tags: parTags
  sku:{
    name: parBastionSku
  }
  properties: {
      dnsName: uniqueString(resourceGroup().id)
      ipConfigurations: [
          {
              name: 'IpConf'
              properties: {
                  subnet: {
                    id: resBastionSubnetRef.id
                  }
                  publicIPAddress: {
                      id: resBastionPublicIP.id
                  }
              }
          }
      ]
  }
}


resource resGatewaySubnetRef 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  parent: resVirtualNetworks
  name: 'GatewaySubnet'
} 


resource resGatewayPublicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = if(parGatewayEnabled){
  location: resourceGroup().location
  name: '${parGatewayName}-PublicIp'
  tags: parTags
  sku: {
      name: parPublicIPSku
  }
  properties: {
      publicIPAddressVersion: 'IPv4'
      publicIPAllocationMethod: 'Static'
  }
}


resource resVPNGateway 'Microsoft.Network/virtualNetworkGateways@2021-02-01' = if(parGatewayEnabled){
  name: parGatewayName
  location: resourceGroup().location
  tags: parTags
  properties:{
    activeActive: false
    enableBgp: false
    gatewayType: parGatewayType
    vpnType: parVpnType
    sku:{
      name: parVpnSku
      tier: parVpnSku
    }
    ipConfigurations:[
      {
        id: resVirtualNetworks.id
        name: 'vnetGatewayConfig'
        properties:{
          publicIPAddress:{
            id: resGatewayPublicIP.id
          }
          subnet:{
            id: resGatewaySubnetRef.id
          }
        }
      }
    ]
  }
}


resource resAzureFirewallSubnetRef 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  parent: resVirtualNetworks
  name: 'AzureFirewallSubnet'
} 


resource resAzureFirewallPublicIP 'Microsoft.Network/publicIPAddresses@2021-02-01' = if(parAzureFirewallEnabled){
  location: resourceGroup().location
  name: '${parAzureFirewallName}-PublicIp'
  tags: parTags
  sku: {
      name: parPublicIPSku
  }
  properties: {
      publicIPAddressVersion: 'IPv4'
      publicIPAllocationMethod: 'Static'
  }
}


resource resAzureFirewall 'Microsoft.Network/azureFirewalls@2021-02-01' = if(parAzureFirewallEnabled){
  name: parAzureFirewallName
  location: resourceGroup().location
  tags: parTags
  properties:{
    networkRuleCollections: [
      {
        name: 'VmInternetAccess'
        properties: {
          priority: 101
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'AllowVMAppAccess'
              description: 'Allows VM access to the web'
              protocols: [
                'TCP'
              ]
              sourceAddresses: [
                parVirtualNetworkAddressPrefix
              ]
              destinationAddresses: [
                '*'
              ]
              destinationPorts: [
                '80'
                '443'
              ]
            }
          ]
        }
      }
    ]
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resAzureFirewallSubnetRef.id
          }
          publicIPAddress: {
            id: resAzureFirewallPublicIP.id
          }
        }
      }
    ]
    threatIntelMode: 'Alert'
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    additionalProperties: {
       'Network.DNS.EnableProxy': 'true'
    }
  }
}

