/*
SUMMARY: Module to deploy the Hub Network and it's components as per the Azure Landing Zone conceptual architecture 
DESCRIPTION: The following components will be options in this deployment
              Virtual Network (Vnet)
              Subnets
              VPN Gateway/ExpressRoute Gateway
              Azure Firewall
              Private DNS Zones - Details of all the Azure Private DNS zones can be found here --> https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns#azure-services-dns-zone-configuration
              DDos Standard Plan
              Bastion
AUTHOR/S: aultt, jtracey93, cloudchristoph
VERSION: 1.x.x
*/

@description('The Azure Region to deploy the resources into. Default: resourceGroup().location')
param parRegion string = resourceGroup().location

@description('Switch which allows Bastion deployment to be disabled. Default: true')
param parBastionEnabled bool = true

@description('Switch which allows DDOS deployment to be disabled. Default: true')
param parDDoSEnabled bool = true

@description('DDOS Plan Name. Default: {parCompanyPrefix}-DDos-Plan')
param parDDoSPlanName string = '${parCompanyPrefix}-DDoS-Plan'

@description('Switch which allows Azure Firewall deployment to be disabled. Default: true')
param parAzureFirewallEnabled bool = true

@description('Switch which enables DNS Proxy to be enabled on the Azure Firewall. Default: true')
param parNetworkDNSEnableProxy bool = true

@description('Switch which allows BGP Propagation to be disabled on the route tables: Default: false')
param parDisableBGPRoutePropagation bool = false

@description('Switch which allows and deploys Private DNS Zones in this resource group - use "privateDnsZones" module to deploy to zones to their own resource group. Default: false')
param parPrivateDNSZonesEnabled bool = false

//ASN must be 65515 if deploying VPN & ER for co-existence to work: https://docs.microsoft.com/en-us/azure/expressroute/expressroute-howto-coexist-resource-manager#limits-and-limitations
@description('''Configuration for VPN virtual network gateway to be deployed. If a VPN virtual network gateway is not desired an empty object should be used as the input parameter in the parameter file, i.e. 
"parVpnGatewayConfig": {
  "value": {}
}''')
param parVpnGatewayConfig object = {
  name: '${parCompanyPrefix}-Vpn-Gateway'
  gatewaytype: 'Vpn'
  sku: 'VpnGw1'
  vpntype: 'RouteBased'
  generation: 'Generation1'
  enableBgp: false
  activeActive: false
  enableBgpRouteTranslationForNat: false
  enableDnsForwarding: false
  asn: 65515
  bgpPeeringAddress: ''
  bgpsettings: {
    asn: 65515
    bgpPeeringAddress: ''
    peerWeight: 5
  }
}

@description('''Configuration for ExpressRoute virtual network gateway to be deployed. If a ExpressRoute virtual network gateway is not desired an empty object should be used as the input parameter in the parameter file, i.e. 
"parExpressRouteGatewayConfig": {
  "value": {}
}''')
param parExpressRouteGatewayConfig object = {
  name: '${parCompanyPrefix}-ExpressRoute-Gateway'
  gatewaytype: 'ExpressRoute'
  sku: 'ErGw1AZ'
  vpntype: 'RouteBased'
  vpnGatewayGeneration: 'None'
  enableBgp: false
  activeActive: false
  enableBgpRouteTranslationForNat: false
  enableDnsForwarding: false
  asn: '65515'
  bgpPeeringAddress: ''
  bgpsettings: {
    asn: '65515'
    bgpPeeringAddress: ''
    peerWeight: '5'
  }
}

@description('Prefix value which will be prepended to all resource names. Default: alz')
param parCompanyPrefix string = 'alz'

@description('Azure Bastion SKU or Tier to deploy.  Currently two options exist Basic and Standard. Default: Standard')
param parBastionSku string = 'Standard'

@description('Public IP Address SKU. Default: Standard')
@allowed([
  'Basic'
  'Standard'
])
param parPublicIPSku string = 'Standard'

@description('Tags you would like to be applied to all resources in this module. Default: empty array')
param parTags object = {}

@description('The IP address range for all virtual networks to use. Default: 10.10.0.0/16')
param parHubNetworkAddressPrefix string = '10.10.0.0/16'

@description('Prefix Used for Hub Network. Default: {parCompanyPrefix}-hub-{parRegion}')
param parHubNetworkName string = '${parCompanyPrefix}-hub-${parRegion}'

@description('Azure Firewall Name. Default: {parCompanyPrefix}-azure-firewall ')
param parAzureFirewallName string = '${parCompanyPrefix}-azure-firewall'

@description('Azure Firewall Tier associated with the Firewall to deploy. Default: Standard ')
@allowed([
  'Standard'
  'Premium'
])
param parAzureFirewallTier string = 'Standard'

@description('Name of Route table to create for the default route of Hub. Default: {parCompanyPrefix}-hub-routetable')
param parHubRouteTableName string = '${parCompanyPrefix}-hub-routetable'

@description('The name and IP address range for each subnet in the virtual networks. Default: AzureBastionSubnet, GatewaySubnet, AzureFirewall Subnet')
param parSubnets array = [
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

@description('Name Associated with Bastion Service:  Default: {parCompanyPrefix}-bastion')
param parBastionName string = '${parCompanyPrefix}-bastion'

@description('Custom Array of DNS Zones to provision in Hub Virtual Network. Default: empty array - All known Zones')
param parPrivateDnsZones array = []

@description('Array of DNS Server IP addresses for VNet. Default: Empty Array')
param parDNSServerIPArray array = []

@description('Set Parameter to true to Opt-out of deployment telemetry')
param parTelemetryOptOut bool = false

var varSubnetProperties = [for subnet in parSubnets: {
  name: subnet.name
  properties: {
    addressPrefix: subnet.ipAddressRange
  }
}]

var varVpnGWConfig = ((!empty(parVpnGatewayConfig)) ? parVpnGatewayConfig : json('{"name": "noconfigVpn"}'))

var varErGWConfig = ((!empty(parExpressRouteGatewayConfig)) ? parExpressRouteGatewayConfig : json('{"name": "noconfigEr"}'))

var varGwConfig = [
  varVpnGWConfig
  varErGWConfig
]

// Customer Usage Attribution Id
var varCuaid = '2686e846-5fdc-4d4f-b533-16dcb09d6e6c'

resource resDDoSProtectionPlan 'Microsoft.Network/ddosProtectionPlans@2021-02-01' = if (parDDoSEnabled) {
  name: parDDoSPlanName
  location: parRegion
  tags: parTags
}

//DDos Protection plan will only be enabled if parDDoSEnabled is true.  
resource resHubVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: parHubNetworkName
  location: parRegion
  tags: parTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        parHubNetworkAddressPrefix
      ]
    }
    dhcpOptions: {
      dnsServers: parDNSServerIPArray
    }
    subnets: varSubnetProperties
    enableDdosProtection: parDDoSEnabled
    ddosProtectionPlan: (parDDoSEnabled) ? {
      id: resDDoSProtectionPlan.id
    } : null
  }
}

module modBastionPublicIP '../publicIp/publicIp.bicep' = if (parBastionEnabled) {
  name: 'deploy-Bastion-Public-IP'
  params: {
    parLocation: parRegion
    parPublicIPName: '${parBastionName}-PublicIP'
    parPublicIPSku: {
      name: parPublicIPSku
    }
    parPublicIPProperties: {
      publicIPAddressVersion: 'IPv4'
      publicIPAllocationMethod: 'Static'
    }
    parTags: parTags
    parTelemetryOptOut: parTelemetryOptOut
  }
}

resource resBastionSubnetRef 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  parent: resHubVirtualNetwork
  name: 'AzureBastionSubnet'
}

// AzureBastionSubnet is required to deploy Bastion service. This subnet must exist in the parsubnets array if you enable Bastion Service.
// There is a minimum subnet requirement of /27 prefix.  
// If you are deploying standard this needs to be larger. https://docs.microsoft.com/en-us/azure/bastion/configuration-settings#subnet
resource resBastion 'Microsoft.Network/bastionHosts@2021-02-01' = if (parBastionEnabled) {
  location: parRegion
  name: parBastionName
  tags: parTags
  sku: {
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
            id: parBastionEnabled ? modBastionPublicIP.outputs.outPublicIPID : ''
          }
        }
      }
    ]
  }
}

resource resGatewaySubnetRef 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  parent: resHubVirtualNetwork
  name: 'GatewaySubnet'
}

module modGatewayPublicIP '../publicIp/publicIp.bicep' = [for (gateway, i) in varGwConfig: if ((gateway.name != 'noconfigVpn') && (gateway.name != 'noconfigEr')) {
  name: 'deploy-Gateway-Public-IP-${i}'
  params: {
    parLocation: parRegion
    parPublicIPName: '${gateway.name}-PublicIP'
    parPublicIPProperties: {
      publicIPAddressVersion: 'IPv4'
      publicIPAllocationMethod: 'Static'
    }
    parPublicIPSku: {
      name: parPublicIPSku
    }
    parTags: parTags
    parTelemetryOptOut: parTelemetryOptOut
  }
}]

//Minumum subnet size is /27 supporting documentation https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#gwsub
resource resGateway 'Microsoft.Network/virtualNetworkGateways@2021-02-01' = [for (gateway, i) in varGwConfig: if ((gateway.name != 'noconfigVpn') && (gateway.name != 'noconfigEr')) {
  name: gateway.name
  location: parRegion
  tags: parTags
  properties: {
    activeActive: gateway.activeActive
    enableBgp: gateway.enableBgp
    enableBgpRouteTranslationForNat: gateway.enableBgpRouteTranslationForNat
    enableDnsForwarding: gateway.enableDnsForwarding
    bgpSettings: (gateway.enableBgp) ? gateway.bgpSettings : null
    gatewayType: gateway.gatewayType
    vpnGatewayGeneration: (gateway.gatewayType == 'VPN') ? gateway.generation : 'None'
    vpnType: gateway.vpntype
    sku: {
      name: gateway.sku
      tier: gateway.sku
    }
    ipConfigurations: [
      {
        id: resHubVirtualNetwork.id
        name: 'vnetGatewayConfig'
        properties: {
          publicIPAddress: {
            id: (((gateway.name != 'noconfigVpn') && (gateway.name != 'noconfigEr')) ? modGatewayPublicIP[i].outputs.outPublicIPID : 'na')
          }
          subnet: {
            id: resGatewaySubnetRef.id
          }
        }
      }
    ]
  }
}]

resource resAzureFirewallSubnetRef 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  parent: resHubVirtualNetwork
  name: 'AzureFirewallSubnet'
}

module modAzureFirewallPublicIP '../publicIp/publicIp.bicep' = if (parAzureFirewallEnabled) {
  name: 'deploy-Firewall-Public-IP'
  params: {
    parLocation: parRegion
    parPublicIPName: '${parAzureFirewallName}-PublicIP'
    parPublicIPProperties: {
      publicIPAddressVersion: 'IPv4'
      publicIPAllocationMethod: 'Static'
    }
    parPublicIPSku: {
      name: parPublicIPSku
    }
    parTags: parTags
    parTelemetryOptOut: parTelemetryOptOut
  }
}

// AzureFirewallSubnet is required to deploy Azure Firewall . This subnet must exist in the parsubnets array if you deploy.
// There is a minimum subnet requirement of /26 prefix.  
resource resAzureFirewall 'Microsoft.Network/azureFirewalls@2021-02-01' = if (parAzureFirewallEnabled) {
  name: parAzureFirewallName
  location: parRegion
  tags: parTags
  properties: {
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
                parHubNetworkAddressPrefix
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
            id: parAzureFirewallEnabled ? modAzureFirewallPublicIP.outputs.outPublicIPID : ''
          }
        }
      }
    ]
    threatIntelMode: 'Alert'
    sku: {
      name: 'AZFW_VNet'
      tier: parAzureFirewallTier
    }
    additionalProperties: {
      'Network.DNS.EnableProxy': '${parNetworkDNSEnableProxy}'
    }
  }
}

//If Azure Firewall is enabled we will deploy a RouteTable to redirect Traffic to the Firewall.
resource resHubRouteTable 'Microsoft.Network/routeTables@2021-02-01' = if (parAzureFirewallEnabled) {
  name: parHubRouteTableName
  location: parRegion
  tags: parTags
  properties: {
    routes: [
      {
        name: 'udr-default-azfw'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: parAzureFirewallEnabled ? resAzureFirewall.properties.ipConfigurations[0].properties.privateIPAddress : ''
        }
      }
    ]
    disableBgpRoutePropagation: parDisableBGPRoutePropagation
  }
}

module modPrivateDnsZones '../privateDnsZones/privateDnsZones.bicep' = if (parPrivateDNSZonesEnabled) {
  name: 'deploy-Private-DNS-Zones'
  params: {
    parRegion: parRegion
    parTags: parTags
    parHubVirtualNetworkId: resHubVirtualNetwork.id
    parDeployAllZones: empty(parPrivateDnsZones)
    parPrivateDnsZones: parPrivateDnsZones
  }
}

// Optional Deployment for Customer Usage Attribution
module modCustomerUsageAttribution '../../CRML/customerUsageAttribution/cuaIdResourceGroup.bicep' = if (!parTelemetryOptOut) {
  #disable-next-line no-loc-expr-outside-params
  name: 'pid-${varCuaid}-${uniqueString(resourceGroup().location)}'
  params: {}
}

//If Azure Firewall is enabled we will deploy a RouteTable to redirect Traffic to the Firewall.
output outAzureFirewallPrivateIP string = parAzureFirewallEnabled ? resAzureFirewall.properties.ipConfigurations[0].properties.privateIPAddress : ''

//If Azure Firewall is enabled we will deploy a RouteTable to redirect Traffic to the Firewall.
output outAzureFirewallName string = parAzureFirewallEnabled ? parAzureFirewallName : ''

output outPrivateDnsZones array = (parPrivateDNSZonesEnabled ? modPrivateDnsZones.outputs.outPrivateDnsZones : []) 

output outDDoSPlanResourceID string = resDDoSProtectionPlan.id
output outHubVirtualNetworkName string = resHubVirtualNetwork.name
output outHubVirtualNetworkID string = resHubVirtualNetwork.id
