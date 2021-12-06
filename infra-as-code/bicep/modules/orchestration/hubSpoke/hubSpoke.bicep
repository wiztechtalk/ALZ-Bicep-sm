/*

SUMMARY: This module provides orchestration of all the required module deployments to achevie a Azure Landing Zones Hub and Spoke network topology deployment (also known as Adventure Works)
DESCRIPTION: This module provides orchestration of all the required module deployments to achevie a Azure Landing Zones Hub and Spoke network topology deployment (also known as Adventure Works).
             It will handle the sequencing and ordering of the following modules:
             - Management Groups
             - Custom RBAC Role Definitions
             - Custom Policy Definitions
             - Logging
             - Policy Assignments
             - Subscription Placement
             - Hub Networking
             - Spoke Networking (corp connected)
             All as outlined in the Deployment Flow wiki page here: https://github.com/Azure/ALZ-Bicep/wiki/DeploymentFlow
AUTHOR/S: jtracey93
VERSION: 1.0.0

*/

// **Parameters**
// Generic Parameters - Used in multiple modules
@description('The region to deploy all resoruces into. DEFAULTS TO = northeurope')
param parLocation string = 'northeurope'

// Subscriptions Parameters
@description('The Subscription ID for the Management Subscription (must already exists)')
@maxLength(36)
param parManagementSubscriptionId string

@description('The Subscription ID for the Connectivity Subscription (must already exists)')
@maxLength(36)
param parConnectivitySubscriptionId string

@description('The Subscription ID for the Identity Subscription (must already exists)')
@maxLength(36)
param parIdentitySubscriptionId string

@description('An array of objects containing the Subscription IDs & CIDR VNET Address Spaces for Subscriptions to be placed into the Corp Management Group and peered back to the Hub Virtual Network (must already exists)')
@maxLength(36)
param parCorpSubscriptionIds array = [
  {
    subID: '10e57c4d-7898-4c89-8e1f-1faead70ae1a'
    vnetCIDR: '10.11.0.0/16'
  }
  {
    subID: '9dcbc13c-2604-4ecd-addb-1e92cfd653f6'
    vnetCIDR: '10.12.0.0/16'
  }
]

@description('The Subscription IDs for Subscriptions to be placed into the Online Management Group (must already exists)')
@maxLength(36)
param parOnlineSubscriptionIds array = []

// Resource Group Modules Parameters - Used multiple times
@description('Name of Resource Group to be created to contain management resources like the central log analytics workspace.  Default: {parTopLevelManagementGroupPrefix}-logging')
param parResourceGroupNameForLogging string = '${parTopLevelManagementGroupPrefix}-logging'

@description('Name of Resource Group to be created to contain hub networking resources like the virtual network and ddos standard plan.  Default: {parTopLevelManagementGroupPrefix}-{parLocation}-hub-networking')
param parResourceGroupNameForHubNetworking string = '${parTopLevelManagementGroupPrefix}-${parLocation}-hub-networking'

@description('Name of Resource Group to be created to contain spoke networking resources like the virtual network.  Default: {parTopLevelManagementGroupPrefix}-{parLocation}-spoke-networking')
param parResourceGroupNameForSpokeNetworking string = '${parTopLevelManagementGroupPrefix}-${parLocation}-spoke-networking'

// Management Group Module Parameters
@description('Prefix for the management group hierarchy.  This management group will be created as part of the deployment.')
@minLength(2)
@maxLength(10)
param parTopLevelManagementGroupPrefix string = 'alz'

@description('Display name for top level management group.  This name will be applied to the management group prefix defined in parTopLevelManagementGroupPrefix parameter.')
@minLength(2)
param parTopLevelManagementGroupDisplayName string = 'Azure Landing Zones'

// Logging Module Parameters
@description('Log Analytics Workspace name. - DEFAULT VALUE: alz-log-analytics')
param parLogAnalyticsWorkspaceName string = 'alz-log-analytics'

@minValue(30)
@maxValue(730)
@description('Number of days of log retention for Log Analytics Workspace. - DEFAULT VALUE: 365')
param parLogAnalyticsWorkspaceLogRetentionInDays int = 365

@allowed([
  'AgentHealthAssessment'
  'AntiMalware'
  'AzureActivity'
  'ChangeTracking'
  'Security'
  'SecurityInsights'
  'ServiceMap'
  'SQLAssessment'
  'Updates'
  'VMInsights'
])
@description('Solutions that will be added to the Log Analytics Workspace. - DEFAULT VALUE: [AgentHealthAssessment, AntiMalware, AzureActivity, ChangeTracking, Security, SecurityInsights, ServiceMap, SQLAssessment, Updates, VMInsights]')
param parLogAnalyticsWorkspaceSolutions array = [
  'AgentHealthAssessment'
  'AntiMalware'
  'AzureActivity'
  'ChangeTracking'
  'Security'
  'SecurityInsights'
  'ServiceMap'
  'SQLAssessment'
  'Updates'
  'VMInsights'
]

@description('Automation account name. - DEFAULT VALUE: alz-automation-account')
param parAutomationAccountName string = 'alz-automation-account'

// Hub Networking Module Parameters
@description('Switch which allows Bastion deployment to be disabled. Default: true')
param parBastionEnabled bool = true

@description('Switch which allows DDOS deployment to be disabled. Default: true')
param parDDoSEnabled bool = true

@description('DDOS Plan Name. Default: {parTopLevelManagementGroupPrefix}-DDos-Plan')
param parDDoSPlanName string = '${parTopLevelManagementGroupPrefix}-DDoS-Plan'

@description('Switch which allows Azure Firewall deployment to be disabled. Default: true')
param parAzureFirewallEnabled bool = true

@description('Switch which allos DNS Proxy to be enabled on the virtual network. Default: true')
param parNetworkDNSEnableProxy bool = true

@description('Switch which allows BGP Propagation to be disabled on the routes: Default: false')
param parDisableBGPRoutePropagation bool = false

@description('Switch which allows Private DNS Zones to be disabled. Default: true')
param parPrivateDNSZonesEnabled bool = true

//ASN must be 65515 if deploying VPN & ER for co-existence to work: https://docs.microsoft.com/en-us/azure/expressroute/expressroute-howto-coexist-resource-manager#limits-and-limitations
@description('Array of Gateways to be deployed. Array will consist of one or two items.  Specifically Vpn and/or ExpressRoute Default: Vpn')
param parGatewayArray array = [
  {
    name: '${parTopLevelManagementGroupPrefix}-vpn-gateway'
    gatewaytype: 'Vpn'
    sku: 'VpnGw1'
    vpntype: 'RouteBased'
    generation: 'Generation2'
    enableBgp: true
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
  {
    name: '${parTopLevelManagementGroupPrefix}-exr-gateway'
    gatewaytype: 'ExpressRoute'
    sku: 'ErGw1AZ'
    vpntype: 'RouteBased'
    generation: 'None'
    enableBgp: true
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
]

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

@description('Prefix Used for Hub Network. Default: {parTopLevelManagementGroupPrefix}-hub-{parLocation}')
param parHubNetworkName string = '${parTopLevelManagementGroupPrefix}-hub-${parLocation}'

@description('Azure Firewall Name. Default: {parTopLevelManagementGroupPrefix}-azure-firewall ')
param parAzureFirewallName string = '${parTopLevelManagementGroupPrefix}-azure-firewall'

@description('Azure Firewall Tier associated with the Firewall to deploy. Default: Standard ')
@allowed([
  'Standard'
  'Premium'
])
param parAzureFirewallTier string = 'Standard'

@description('Name of Route table to create for the default route of Hub. Default: {parTopLevelManagementGroupPrefix}-hub-routetable')
param parHubRouteTableName string = '${parTopLevelManagementGroupPrefix}-hub-routetable'

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

@description('Name Associated with Bastion Service:  Default: {parTopLevelManagementGroupPrefix}-bastion')
param parBastionName string = '${parTopLevelManagementGroupPrefix}-bastion'

@description('Array of DNS Zones to provision in Hub Virtual Network. Default: All known Azure Privatezones')
param parPrivateDnsZones array = [
  'privatelink.azure-automation.net'
  'privatelink.database.windows.net'
  'privatelink.sql.azuresynapse.net'
  'privatelink.azuresynapse.net'
  'privatelink.blob.core.windows.net'
  'privatelink.table.core.windows.net'
  'privatelink.queue.core.windows.net'
  'privatelink.file.core.windows.net'
  'privatelink.web.core.windows.net'
  'privatelink.dfs.core.windows.net'
  'privatelink.documents.azure.com'
  'privatelink.mongo.cosmos.azure.com'
  'privatelink.cassandra.cosmos.azure.com'
  'privatelink.gremlin.cosmos.azure.com'
  'privatelink.table.cosmos.azure.com'
  'privatelink.${parLocation}.batch.azure.com'
  'privatelink.postgres.database.azure.com'
  'privatelink.mysql.database.azure.com'
  'privatelink.mariadb.database.azure.com'
  'privatelink.vaultcore.azure.net'
  'privatelink.${parLocation}.azmk8s.io'
  '${parLocation}.privatelink.siterecovery.windowsazure.com'
  'privatelink.servicebus.windows.net'
  'privatelink.azure-devices.net'
  'privatelink.eventgrid.azure.net'
  'privatelink.azurewebsites.net'
  'privatelink.api.azureml.ms'
  'privatelink.notebooks.azure.net'
  'privatelink.service.signalr.net'
  'privatelink.afs.azure.net'
  'privatelink.datafactory.azure.net'
  'privatelink.adf.azure.com'
  'privatelink.redis.cache.windows.net'
  'privatelink.redisenterprise.cache.azure.net'
  'privatelink.purview.azure.com'
  'privatelink.digitaltwins.azure.net'
  'privatelink.azconfig.io'
  'privatelink.webpubsub.azure.com'
  'privatelink.azure-devices-provisioning.net'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.azurecr.io'
  'privatelink.search.windows.net'
]

@description('Array of DNS Server IP addresses for VNet. Default: Empty Array')
param parDNSServerIPArray array = []

// Policy Assignments Module Parameters
@description('An e-mail address that you want Azure Security Center alerts to be sent to.')
param parASCEmailSecurityContact string

// Spoke Networking Module Parameters
@description('Prefix Used for Naming Spoke Network')
param parSpokeNetworkPrefix string = 'corp-spoke'

@description('Switch which allows BGP Route Propogation to be disabled on the route table')
param parBGPRoutePropogation bool = false

@description('Name of Route table to create for the default route of Hub. Default: rtb-spoke-to-hub')
param parSpoketoHubRouteTableName string = 'rtb-spoke-to-hub'

// **Variables**
// Orchestration Module Variables
var varDeploymentNameWrappers = {
  basePrefix: 'ALZBicep'
  baseSuffixTenantAndManagementGroup: '${deployment().location}-${uniqueString(deployment().location, parTopLevelManagementGroupPrefix)}'
  baseSuffixManagementSubscription: '${deployment().location}-${uniqueString(deployment().location, parTopLevelManagementGroupPrefix)}-${parManagementSubscriptionId}'
  baseSuffixConnectivitySubscription: '${deployment().location}-${uniqueString(deployment().location, parTopLevelManagementGroupPrefix)}-${parConnectivitySubscriptionId}'
  baseSuffixIdentitySubscription: '${deployment().location}-${uniqueString(deployment().location, parTopLevelManagementGroupPrefix)}-${parIdentitySubscriptionId}'
  baseSuffixCorpSubscriptions: '${deployment().location}-${uniqueString(deployment().location, parTopLevelManagementGroupPrefix)}-corp-sub'
}

var varModuleDeploymentNames = {
  modManagementGroups: take('${varDeploymentNameWrappers.basePrefix}-mgs-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modCustomRBACRoleDefinitions: take('${varDeploymentNameWrappers.basePrefix}-rbacRoles-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modCustomPolicyDefinitions: take('${varDeploymentNameWrappers.basePrefix}-polDefs-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modResourceGroupForLogging: take('${varDeploymentNameWrappers.basePrefix}-rsgLogging-${varDeploymentNameWrappers.baseSuffixManagementSubscription}', 64)
  modLogging: take('${varDeploymentNameWrappers.basePrefix}-logging-${varDeploymentNameWrappers.baseSuffixManagementSubscription}', 64)
  modResourceGroupForHubNetworking: take('${varDeploymentNameWrappers.basePrefix}-rsgHubNetworking-${varDeploymentNameWrappers.baseSuffixConnectivitySubscription}', 64)
  modHubNetworking: take('${varDeploymentNameWrappers.basePrefix}-hubNetworking-${varDeploymentNameWrappers.baseSuffixConnectivitySubscription}', 64)
  modSubscriptionPlacementManagement: take('${varDeploymentNameWrappers.basePrefix}-sub-place-mgmt-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modSubscriptionPlacementConnectivity: take('${varDeploymentNameWrappers.basePrefix}-sub-place-conn-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modSubscriptionPlacementIdentity: take('${varDeploymentNameWrappers.basePrefix}-sub-place-idnt-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modSubscriptionPlacementCorp: take('${varDeploymentNameWrappers.basePrefix}-sub-place-corp-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modSubscriptionPlacementOnline: take('${varDeploymentNameWrappers.basePrefix}-sub-place-online-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentIntRootDeployASCDFConfig: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployASCDFConfig-intRoot-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentIntRootDeployAzActivityLog: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployAzActivityLog-intRoot-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentIntRootDeployASCMonitoring: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployASCMonitoring-intRoot-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentIntRootDeployResourceDiag: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployResoruceDiag-intRoot-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentIntRootDeployVMMonitoring: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployVMMonitoring-intRoot-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentIntRootDeployVMSSMonitoring: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployVMSSMonitoring-intRoot-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentConnEnableDDoSVNET: take('${varDeploymentNameWrappers.basePrefix}-polAssi-enableDDoSVNET-conn-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentIdentDenyPublicIP: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyPublicIP-ident-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentIdentDenyRDPFromInternet: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyRDPFromInet-ident-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentIdentDenySubnetWithoutNSG: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denySubnetNoNSG-ident-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentIdentDeployVMBackup: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployVMBackup-ident-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentMgmtDeployLogAnalytics: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployLAW-mgmt-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsDenyIPForwarding: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyIPForward-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsDenyPublicIP: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyPublicIP-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsDenyRDPFromInternet: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyRDPFromInet-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsDenySubnetWithoutNSG: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denySubnetNoNSG-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsDeployVMBackup: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployVMBackup-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsEnableDDoSVNET: take('${varDeploymentNameWrappers.basePrefix}-polAssi-enableDDoSVNET-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsDenyStorageHttp: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyStorageHttp-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsDenyPrivEscalationAKS: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyPrivEscAKS-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsDenyPrivContainersAKS: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyPrivConAKS-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsEnforceAKSHTTPS: take('${varDeploymentNameWrappers.basePrefix}-polAssi-enforceAKSHTTPS-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsEnforceTLSSSL: take('${varDeploymentNameWrappers.basePrefix}-polAssi-enforceTLSSSL-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsDeploySQLDBAuditing: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deploySQLDBAudit-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsDeploySQLThreat: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deploySQLThreat-lz-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsDenyPublicEndpoints: take('${varDeploymentNameWrappers.basePrefix}-polAssi-denyPublicEndpoints-corp-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modPolicyAssignmentLZsDeployPrivateDNSZones: take('${varDeploymentNameWrappers.basePrefix}-polAssi-deployPrivateDNS-corp-${varDeploymentNameWrappers.baseSuffixTenantAndManagementGroup}', 64)
  modResourceGroupForSpokeNetworking: take('${varDeploymentNameWrappers.basePrefix}-rsgSpokeNetworking-${varDeploymentNameWrappers.baseSuffixCorpSubscriptions}', 61)
  modSpokeNetworking: take('${varDeploymentNameWrappers.basePrefix}-modSpokeNetworking-${varDeploymentNameWrappers.baseSuffixCorpSubscriptions}', 61)
}

// Policy Assignments Modules Variables
var varPolicyAssignments = {
  'Deny-AppGW-Without-WAF': {
    definitionID: '${modManagementGroups.outputs.outTopLevelMGId}/providers/Microsoft.Authorization/policyDefinitions/Deny-AppGW-Without-WAF'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_appgw_without_waf.tmpl.json'))
  }
  'Enforce-AKS-HTTPS': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/1a5b4dca-0b6f-4cf5-907c-56316bc1bf3d'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_http_ingress_aks.tmpl.json'))
  }
  'Deny-IP-Forwarding': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/88c0b9da-ce96-4b03-9635-f29a937e2900'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_ip_forwarding.tmpl.json'))
  }
  'Deny-Priv-Containers-AKS': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/95edb821-ddaf-4404-9732-666045e056b4'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_priv_containers_aks.tmpl.json'))
  }
  'Deny-Priv-Escalation-AKS': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/1c6e92c9-99f0-4e55-9cf2-0c234dc48f99'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_priv_escalation_aks.tmpl.json'))
  }
  'Deny-Public-Endpoints': {
    definitionID: '${modManagementGroups.outputs.outTopLevelMGId}/providers/Microsoft.Authorization/policySetDefinitions/Deny-PublicPaaSEndpoints'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_public_endpoints.tmpl.json'))
  }
  'Deny-Public-IP': {
    definitionID: '${modManagementGroups.outputs.outTopLevelMGId}/providers/Microsoft.Authorization/policyDefinitions/Deny-PublicIP'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_public_ip.tmpl.json'))
  }
  'Deny-RDP-From-Internet': {
    definitionID: '${modManagementGroups.outputs.outTopLevelMGId}/providers/Microsoft.Authorization/policyDefinitions/Deny-RDP-From-Internet'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_rdp_from_internet.tmpl.json'))
  }
  'Deny-Resource-Locations': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_resource_locations.tmpl.json'))
  }
  'Deny-Resource-Types': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/6c112d4e-5bc7-47ae-a041-ea2d9dccd749'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_resource_types.tmpl.json'))
  }
  'Deny-RSG-Locations': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/e765b5de-1225-4ba3-bd56-1ac6695af988'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_rsg_locations.tmpl.json'))
  }
  'Deny-Storage-http': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_storage_http.tmpl.json'))
  }
  'Deny-Subnet-Without-Nsg': {
    definitionID: '${modManagementGroups.outputs.outTopLevelMGId}/providers/Microsoft.Authorization/policyDefinitions/Deny-Subnet-Without-Nsg'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_subnet_without_nsg.tmpl.json'))
  }
  'Deny-Subnet-Without-Udr': {
    definitionID: '${modManagementGroups.outputs.outTopLevelMGId}/providers/Microsoft.Authorization/policyDefinitions/Deny-Subnet-Without-Udr'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deny_subnet_without_udr.tmpl.json'))
  }
  'Deploy-AKS-Policy': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/a8eff44f-8c92-45c3-a3fb-9880802d67a7'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_aks_policy.tmpl.json'))
  }
  'Deploy-ASC-Monitoring': {
    definitionID: '/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_asc_monitoring.tmpl.json'))
  }
  'Deploy-ASCDF-Config': {
    definitionID: '${modManagementGroups.outputs.outTopLevelMGId}/providers/Microsoft.Authorization/policySetDefinitions/Deploy-ASCDF-Config'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_ascdf_config.tmpl.json'))
  }
  'Deploy-AzActivity-Log': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/2465583e-4e78-4c15-b6be-a36cbc7c8b0f'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_azactivity_log.tmpl.json'))
  }
  'Deploy-Log-Analytics': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/8e3e61b3-0b32-22d5-4edf-55f87fdb5955'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_log_analytics.tmpl.json'))
  }
  'Deploy-LX-Arc-Monitoring': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/9d2b61b4-1d14-4a63-be30-d4498e7ad2cf'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_lx_arc_monitoring.tmpl.json'))
  }
  'Deploy-Private-DNS-Zones': {
    definitionID: '${modManagementGroups.outputs.outTopLevelMGId}/providers/Microsoft.Authorization/policySetDefinitions/Deploy-Private-DNS-Zones'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_private_dns_zones.tmpl.json'))
  }
  'Deploy-Resource-Diag': {
    definitionID: '${modManagementGroups.outputs.outTopLevelMGId}/providers/Microsoft.Authorization/policySetDefinitions/Deploy-Diagnostics-LogAnalytics'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_resource_diag.tmpl.json'))
  }
  'Deploy-SQL-DB-Auditing': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/a6fb4358-5bf4-4ad7-ba82-2cd2f41ce5e9'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_sql_db_auditing.tmpl.json'))
  }
  'Deploy-SQL-Security': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/86a912f6-9a06-4e26-b447-11b16ba8659f'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_sql_security.tmpl.json'))
  }
  'Deploy-SQL-Threat': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/36d49e87-48c4-4f2e-beed-ba4ed02b71f5'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_sql_threat.tmpl.json'))
  }
  'Deploy-VM-Backup': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/98d0b9f8-fd90-49c9-88e2-d3baf3b0dd86'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_vm_backup.tmpl.json'))
  }
  'Deploy-VM-Monitoring': {
    definitionID: '/providers/Microsoft.Authorization/policySetDefinitions/55f3eceb-5573-4f18-9695-226972c6d74a'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_vm_monitoring.tmpl.json'))
  }
  'Deploy-VMSS-Monitoring': {
    definitionID: '/providers/Microsoft.Authorization/policySetDefinitions/75714362-cae7-409e-9b99-a8e5075b7fad'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_vmss_monitoring.tmpl.json'))
  }
  'Deploy-WS-Arc-Monitoring': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/69af7d4a-7b18-4044-93a9-2651498ef203'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_deploy_ws_arc_monitoring.tmpl.json'))
  }
  'Enable-DDoS-VNET': {
    definitionID: '/providers/Microsoft.Authorization/policyDefinitions/94de2ad3-e0c1-4caf-ad78-5d47bbc83d3d'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_enable_ddos_vnet.tmpl.json'))
  }
  'Enforce-TLS-SSL': {
    definitionID: '${modManagementGroups.outputs.outTopLevelMGId}/providers/Microsoft.Authorization/policySetDefinitions/Enforce-EncryptTransit'
    libDefinition: json(loadTextContent('../../policy/assignments/lib/policy_assignments/policy_assignment_es_enforce_tls_ssl.tmpl.json'))
  }
}

// RBAC Role Definitions Variables - Used For Policy Assignments
var varRBACRoleDefinitionIDs = {
  owner: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  networkContributor: '4d97b98b-1d4f-4787-a291-c67834d212e7'
}

// Managment Groups Varaibles - Used For Policy Assignments
var varManagementGroupIDs = {
  intRoot: parTopLevelManagementGroupPrefix
  platform: '${parTopLevelManagementGroupDisplayName}-platform'
  platformManagement: '${parTopLevelManagementGroupDisplayName}-platform-management'
  platformConnectivity: '${parTopLevelManagementGroupDisplayName}-platform-connectivity'
  platformIdentity: '${parTopLevelManagementGroupDisplayName}-platform-identity'
  landingZones: '${parTopLevelManagementGroupDisplayName}-landingzones'
  landingZonesCorp: '${parTopLevelManagementGroupDisplayName}-landingzones-corp'
  landingZonesOnline: '${parTopLevelManagementGroupDisplayName}-landingzones-online'
  decommissioned: '${parTopLevelManagementGroupDisplayName}-decommissioned'
  sandbox: '${parTopLevelManagementGroupDisplayName}-sandbox'
}

// **Scope**
targetScope = 'tenant'

// **Modules**
// Module - Management Groups
module modManagementGroups '../../managementGroups/managementGroups.bicep' = {
  scope: tenant()
  name: varModuleDeploymentNames.modManagementGroups
  params: {
    parTopLevelManagementGroupPrefix: parTopLevelManagementGroupPrefix
    parTopLevelManagementGroupDisplayName: parTopLevelManagementGroupDisplayName
  }
}

// Module - Custom RBAC Role Definitions - REMOVED AS ISSUES ON FRESH DEPLOYMENT ONLY AND NOT DONE IN ESLZ ARM TODAY
// ERROR: New-AzTenantDeployment: 17:25:33 - Error: Code=InvalidTemplate; Message=Deployment template validation failed: 'The deployment metadata 'MANAGEMENTGROUP' is not valid.'.
// module modCustomRBACRoleDefinitions '../../customRoleDefinitions/customRoleDefinitions.bicep' = {
//   dependsOn: [
//     modManagementGroups
//   ]
//   scope: managementGroup(varManagementGroupIDs.intRoot)
//   name: varModuleDeploymentNames.modCustomRBACRoleDefinitions
//   params: {
//     parAssignableScopeManagementGroupId: parTopLevelManagementGroupPrefix
//   }
// }

// Module - Custom Policy Definitions and Initiatives
module modCustomPolicyDefinitions '../../policy/definitions/custom-policy-definitions.bicep' = {
  scope: managementGroup(varManagementGroupIDs.intRoot)
  name: varModuleDeploymentNames.modCustomPolicyDefinitions
  params: {
    parTargetManagementGroupID: modManagementGroups.outputs.outTopLevelMGName
  }
}

// Resource - Resource Group - For Logging - https://github.com/Azure/bicep/issues/5151 & https://github.com/Azure/bicep/issues/4992
module modResourceGroupForLogging '../../resourceGroup/resourceGroup.bicep' = {
  scope: subscription(parManagementSubscriptionId)
  name: varModuleDeploymentNames.modResourceGroupForLogging
  params: {
    parResourceGroupLocation: parLocation
    parResourceGroupName: parResourceGroupNameForLogging
  }
}

// Module - Logging, Automation & Sentinel
module modLogging '../../logging/logging.bicep' = {
  dependsOn: [
    modResourceGroupForLogging
  ]
  scope: resourceGroup(parManagementSubscriptionId, parResourceGroupNameForLogging)
  name: varModuleDeploymentNames.modLogging
  params: {
    parAutomationAccountName: parAutomationAccountName
    parAutomationAccountRegion: parLocation
    parLogAnalyticsWorkspaceLogRetentionInDays: parLogAnalyticsWorkspaceLogRetentionInDays
    parLogAnalyticsWorkspaceName: parLogAnalyticsWorkspaceName
    parLogAnalyticsWorkspaceRegion: parLocation
    parLogAnalyticsWorkspaceSolutions: parLogAnalyticsWorkspaceSolutions
  }
}

// Resource - Resource Group - For Hub Networking - https://github.com/Azure/bicep/issues/5151
module modResourceGroupForHubNetworking '../../resourceGroup/resourceGroup.bicep' = {
  scope: subscription(parConnectivitySubscriptionId)
  name: varModuleDeploymentNames.modResourceGroupForHubNetworking
  params: {
    parResourceGroupLocation: parLocation
    parResourceGroupName: parResourceGroupNameForHubNetworking
  }
}

// Module - Hub Virtual Networking
module modHubNetworking '../../hubNetworking/hubNetworking.bicep' = {
  dependsOn: [
    modResourceGroupForHubNetworking
  ]
  scope: resourceGroup(parConnectivitySubscriptionId, parResourceGroupNameForHubNetworking)
  name: varModuleDeploymentNames.modHubNetworking
  params: {
    parBastionEnabled: parBastionEnabled
    parDDoSEnabled: parDDoSEnabled
    parDDoSPlanName: parDDoSPlanName
    parAzureFirewallEnabled: parAzureFirewallEnabled
    parNetworkDNSEnableProxy: parNetworkDNSEnableProxy
    parDisableBGPRoutePropagation: parDisableBGPRoutePropagation
    parPrivateDNSZonesEnabled: parPrivateDNSZonesEnabled
    parGatewayArray: parGatewayArray
    parCompanyPrefix: parTopLevelManagementGroupPrefix
    parBastionSku: parBastionSku
    parPublicIPSku: parPublicIPSku
    parTags: parTags
    parHubNetworkAddressPrefix: parHubNetworkAddressPrefix
    parHubNetworkName: parHubNetworkName
    parAzureFirewallName: parAzureFirewallName
    parAzureFirewallTier: parAzureFirewallTier
    parHubRouteTableName: parHubRouteTableName
    parSubnets: parSubnets
    parBastionName: parBastionName
    parPrivateDnsZones: parPrivateDnsZones
    parDNSServerIPArray: parDNSServerIPArray
  }
}

// Subscription Placements Into Management Group Hierarchy
// Module - Subscription Placement - Management
module modSubscriptionPlacementManagement '../../subscriptionPlacement/subscriptionPlacement.bicep' = {
  scope: managementGroup(varManagementGroupIDs.platformManagement)
  name: varModuleDeploymentNames.modSubscriptionPlacementManagement
  params: {
    parTargetManagementGroupId: modManagementGroups.outputs.outPlatformManagementMGName
    parSubscriptionIds: [
      parManagementSubscriptionId
    ]
  }
}

// Module - Subscription Placement - Connectivity
module modSubscriptionPlacementConnectivity '../../subscriptionPlacement/subscriptionPlacement.bicep' = {
  scope: managementGroup(varManagementGroupIDs.platformConnectivity)
  name: varModuleDeploymentNames.modSubscriptionPlacementConnectivity
  params: {
    parTargetManagementGroupId: modManagementGroups.outputs.outPlatformConnectivityMGName
    parSubscriptionIds: [
      parConnectivitySubscriptionId
    ]
  }
}

// Module - Subscription Placement - Identity
module modSubscriptionPlacementIdentity '../../subscriptionPlacement/subscriptionPlacement.bicep' = {
  scope: managementGroup(varManagementGroupIDs.platformIdentity)
  name: varModuleDeploymentNames.modSubscriptionPlacementIdentity
  params: {
    parTargetManagementGroupId: modManagementGroups.outputs.outPlatformIdentityMGName
    parSubscriptionIds: [
      parIdentitySubscriptionId
    ]
  }
}

// Module - Subscription Placement - Corp
module modSubscriptionPlacementCorp '../../subscriptionPlacement/subscriptionPlacement.bicep' = if (!empty(parCorpSubscriptionIds)) {
  scope: managementGroup(varManagementGroupIDs.landingZonesCorp)
  name: varModuleDeploymentNames.modSubscriptionPlacementCorp
  params: {
    parTargetManagementGroupId: modManagementGroups.outputs.outLandingZonesCorpMGName
    parSubscriptionIds: [
      parCorpSubscriptionIds
    ]
  }
}

// Module - Subscription Placement - Online
module modSubscriptionPlacementOnline '../../subscriptionPlacement/subscriptionPlacement.bicep' = if (!empty(parOnlineSubscriptionIds)) {
  scope: managementGroup(varManagementGroupIDs.landingZonesOnline)
  name: varModuleDeploymentNames.modSubscriptionPlacementOnline
  params: {
    parTargetManagementGroupId: modManagementGroups.outputs.outLandingZonesOnlineMGName
    parSubscriptionIds: [
      parOnlineSubscriptionIds
    ]
  }
}

// Modules - Policy Assignments - Intermediate Root Management Group
// Module - Policy Assignment - Deploy-ASCDF-Config
module modPolicyAssignmentIntRootDeployASCDFConfig '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.intRoot)
  name: varModuleDeploymentNames.modPolicyAssignmentIntRootDeployASCDFConfig
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deploy-ASCDF-Config'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deploy-ASCDF-Config'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deploy-ASCDF-Config'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deploy-ASCDF-Config'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deploy-ASCDF-Config'].libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      emailSecurityContact: {
        value: parASCEmailSecurityContact
      }
      ascExportResourceGroupLocation: {
        value: parLocation
      }
      logAnalytics: {
        value: modLogging.outputs.outLogAnalyticsWorkspaceId
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deploy-ASCDF-Config'].libDefinition.identity.type
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.owner
    ]
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deploy-ASCDF-Config'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Deploy-AzActivity-Log
module modPolicyAssignmentIntRootDeployAzActivityLog '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.intRoot)
  name: varModuleDeploymentNames.modPolicyAssignmentIntRootDeployAzActivityLog
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deploy-AzActivity-Log'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deploy-AzActivity-Log'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deploy-AzActivity-Log'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deploy-AzActivity-Log'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deploy-AzActivity-Log'].libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      logAnalytics: {
        value: modLogging.outputs.outLogAnalyticsWorkspaceId
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deploy-AzActivity-Log'].libDefinition.identity.type
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.owner
    ]
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deploy-AzActivity-Log'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Deploy-ASC-Monitoring
module modPolicyAssignmentIntRootDeployASCMonitoring '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.intRoot)
  name: varModuleDeploymentNames.modPolicyAssignmentIntRootDeployASCMonitoring
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deploy-ASC-Monitoring'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deploy-ASC-Monitoring'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deploy-ASC-Monitoring'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deploy-ASC-Monitoring'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deploy-ASC-Monitoring'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deploy-ASC-Monitoring'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deploy-ASC-Monitoring'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Deploy-Resource-Diag
module modPolicyAssignmentIntRootDeployResourceDiag '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.intRoot)
  name: varModuleDeploymentNames.modPolicyAssignmentIntRootDeployResourceDiag
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deploy-Resource-Diag'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deploy-Resource-Diag'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deploy-Resource-Diag'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deploy-Resource-Diag'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deploy-Resource-Diag'].libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      logAnalytics: {
        value: modLogging.outputs.outLogAnalyticsWorkspaceId
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deploy-Resource-Diag'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deploy-Resource-Diag'].libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.owner
    ]
  }
}

// Module - Policy Assignment - Deploy-VM-Monitoring
module modPolicyAssignmentIntRootDeployVMMonitoring '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.intRoot)
  name: varModuleDeploymentNames.modPolicyAssignmentIntRootDeployVMMonitoring
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deploy-VM-Monitoring'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deploy-VM-Monitoring'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deploy-VM-Monitoring'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deploy-VM-Monitoring'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deploy-VM-Monitoring'].libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      logAnalytics_1: {
        value: modLogging.outputs.outLogAnalyticsWorkspaceId
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deploy-VM-Monitoring'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deploy-VM-Monitoring'].libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.owner
    ]
  }
}

// Module - Policy Assignment - Deploy-VMSS-Monitoring
module modPolicyAssignmentIntRootDeployVMSSMonitoring '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.intRoot)
  name: varModuleDeploymentNames.modPolicyAssignmentIntRootDeployVMSSMonitoring
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deploy-VMSS-Monitoring'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deploy-VMSS-Monitoring'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deploy-VMSS-Monitoring'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deploy-VMSS-Monitoring'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deploy-VMSS-Monitoring'].libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      logAnalytics_1: {
        value: modLogging.outputs.outLogAnalyticsWorkspaceId
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deploy-VMSS-Monitoring'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deploy-VMSS-Monitoring'].libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.owner
    ]
  }
}

// Modules - Policy Assignments - Connectivity Management Group
// Module - Policy Assignment - Enable-DDoS-VNET
module modPolicyAssignmentConnEnableDDoSVNET '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.platformConnectivity)
  name: varModuleDeploymentNames.modPolicyAssignmentConnEnableDDoSVNET
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Enable-DDoS-VNET'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Enable-DDoS-VNET'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Enable-DDoS-VNET'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Enable-DDoS-VNET'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Enable-DDoS-VNET'].libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      ddosPlan: {
        value: modHubNetworking.outputs.outDDoSPlanResourceID
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignments['Enable-DDoS-VNET'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Enable-DDoS-VNET'].libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.networkContributor
    ]
  }
}

// Modules - Policy Assignments - Identity Management Group
// Module - Policy Assignment - Deny-Public-IP
module modPolicyAssignmentIdentDenyPublicIP '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.platformIdentity)
  name: varModuleDeploymentNames.modPolicyAssignmentIdentDenyPublicIP
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deny-Public-IP'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deny-Public-IP'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deny-Public-IP'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deny-Public-IP'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deny-Public-IP'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deny-Public-IP'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deny-Public-IP'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Deny-RDP-From-Internet
module modPolicyAssignmentIdentDenyRDPFromInternet '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.platformIdentity)
  name: varModuleDeploymentNames.modPolicyAssignmentIdentDenyRDPFromInternet
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deny-RDP-From-Internet'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deny-RDP-From-Internet'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deny-RDP-From-Internet'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deny-RDP-From-Internet'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deny-RDP-From-Internet'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deny-RDP-From-Internet'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deny-RDP-From-Internet'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Deny-Subnet-Without-Nsg
module modPolicyAssignmentIdentDenySubnetWithoutNSG '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.platformIdentity)
  name: varModuleDeploymentNames.modPolicyAssignmentIdentDenySubnetWithoutNSG
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deny-Subnet-Without-Nsg'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deny-Subnet-Without-Nsg'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deny-Subnet-Without-Nsg'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deny-Subnet-Without-Nsg'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deny-Subnet-Without-Nsg'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deny-Subnet-Without-Nsg'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deny-Subnet-Without-Nsg'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Deploy-VM-Backup
module modPolicyAssignmentIdentDeployVMBackup '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.platformIdentity)
  name: varModuleDeploymentNames.modPolicyAssignmentIdentDeployVMBackup
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deploy-VM-Backup'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deploy-VM-Backup'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deploy-VM-Backup'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deploy-VM-Backup'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deploy-VM-Backup'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deploy-VM-Backup'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deploy-VM-Backup'].libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.owner
    ]
  }
}

// Modules - Policy Assignments - Management Management Group
// Module - Policy Assignment - Deploy-Log-Analytics
module modPolicyAssignmentMgmtDeployLogAnalytics '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.platformIdentity)
  name: varModuleDeploymentNames.modPolicyAssignmentMgmtDeployLogAnalytics
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deploy-Log-Analytics'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deploy-Log-Analytics'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deploy-Log-Analytics'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deploy-Log-Analytics'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deploy-Log-Analytics'].libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      rgName: {
        value: parResourceGroupNameForLogging
      }
      workspaceName: {
        value: parLogAnalyticsWorkspaceName
      }
      workspaceRegion: {
        value: parLocation
      }
      dataRetention: {
        value: parLogAnalyticsWorkspaceLogRetentionInDays
      }
      automationAccountName: {
        value: parAutomationAccountName
      }
      automationRegion: {
        value: parLocation
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deploy-Log-Analytics'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deploy-Log-Analytics'].libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.owner
    ]
  }
}

// Modules - Policy Assignments - Landing Zones Management Group
// Module - Policy Assignment - Deny-IP-Forwarding
module modPolicyAssignmentLZsDenyIPForwarding '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsDenyIPForwarding
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deny-IP-Forwarding'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deny-IP-Forwarding'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deny-IP-Forwarding'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deny-IP-Forwarding'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deny-IP-Forwarding'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deny-IP-Forwarding'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deny-IP-Forwarding'].libDefinition.properties.enforcementMode
  }
}

// // Module - Policy Assignment - Deny-Public-IP - NOT DONE IN ARM?????
// module modPolicyAssignmentLZsDenyPublicIP '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
//   dependsOn: [
//     modCustomPolicyDefinitions
//   ]
//   scope: managementGroup(varManagementGroupIDs.landingZones)
//   name: varModuleDeploymentNames.modPolicyAssignmentLZsDenyPublicIP
//   params: {
//     parPolicyAssignmentDefinitionID: varPolicyAssignments['Deny-Public-IP'].definitionID
//     parPolicyAssignmentName: varPolicyAssignments['Deny-Public-IP'].libDefinition.name
//     parPolicyAssignmentDisplayName: varPolicyAssignments['Deny-Public-IP'].libDefinition.properties.displayName
//     parPolicyAssignmentDescription: varPolicyAssignments['Deny-Public-IP'].libDefinition.properties.description
//     parPolicyAssignmentParameters: varPolicyAssignments['Deny-Public-IP'].libDefinition.properties.parameters
//     parPolicyAssignmentIdentityType: varPolicyAssignments['Deny-Public-IP'].libDefinition.identity.type
//     parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deny-Public-IP'].libDefinition.properties.enforcementMode
//   }
// }

// Module - Policy Assignment - Deny-RDP-From-Internet
module modPolicyAssignmentLZstDenyRDPFromInternet '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsDenyRDPFromInternet
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deny-RDP-From-Internet'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deny-RDP-From-Internet'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deny-RDP-From-Internet'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deny-RDP-From-Internet'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deny-RDP-From-Internet'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deny-RDP-From-Internet'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deny-RDP-From-Internet'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Deny-Subnet-Without-Nsg
module modPolicyAssignmentLZsDenySubnetWithoutNSG '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsDenySubnetWithoutNSG
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deny-Subnet-Without-Nsg'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deny-Subnet-Without-Nsg'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deny-Subnet-Without-Nsg'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deny-Subnet-Without-Nsg'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deny-Subnet-Without-Nsg'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deny-Subnet-Without-Nsg'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deny-Subnet-Without-Nsg'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Deploy-VM-Backup
module modPolicyAssignmentLZsDeployVMBackup '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsDeployVMBackup
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deploy-VM-Backup'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deploy-VM-Backup'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deploy-VM-Backup'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deploy-VM-Backup'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deploy-VM-Backup'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deploy-VM-Backup'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deploy-VM-Backup'].libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.owner
    ]
  }
}

// Module - Policy Assignment - Enable-DDoS-VNET
module modPolicyAssignmentLZsEnableDDoSVNET '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.platformConnectivity)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsEnableDDoSVNET
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Enable-DDoS-VNET'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Enable-DDoS-VNET'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Enable-DDoS-VNET'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Enable-DDoS-VNET'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Enable-DDoS-VNET'].libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      ddosPlan: {
        value: modHubNetworking.outputs.outDDoSPlanResourceID
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignments['Enable-DDoS-VNET'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Enable-DDoS-VNET'].libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.networkContributor
    ]
  }
}

// Module - Policy Assignment - Deny-Storage-http
module modPolicyAssignmentLZsDenyStorageHttp '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsDenyStorageHttp
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deny-Storage-http'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deny-Storage-http'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deny-Storage-http'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deny-Storage-http'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deny-Storage-http'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deny-Storage-http'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deny-Storage-http'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Deny-Priv-Escalation-AKS
module modPolicyAssignmentLZsDenyPrivEscalationAKS '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsDenyPrivEscalationAKS
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deny-Priv-Escalation-AKS'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deny-Priv-Escalation-AKS'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deny-Priv-Escalation-AKS'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deny-Priv-Escalation-AKS'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deny-Priv-Escalation-AKS'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deny-Priv-Escalation-AKS'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deny-Priv-Escalation-AKS'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Deny-Priv-Containers-AKS
module modPolicyAssignmentLZsDenyPrivContainersAKS '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsDenyPrivContainersAKS
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deny-Priv-Containers-AKS'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deny-Priv-Containers-AKS'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deny-Priv-Containers-AKS'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deny-Priv-Containers-AKS'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deny-Priv-Containers-AKS'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deny-Priv-Containers-AKS'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deny-Priv-Containers-AKS'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Enforce-AKS-HTTPS
module modPolicyAssignmentLZsEnforceAKSHTTPS '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsEnforceAKSHTTPS
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Enforce-AKS-HTTPS'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Enforce-AKS-HTTPS'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Enforce-AKS-HTTPS'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Enforce-AKS-HTTPS'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Enforce-AKS-HTTPS'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Enforce-AKS-HTTPS'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Enforce-AKS-HTTPS'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Enforce-TLS-SSL
module modPolicyAssignmentLZsEnforceTLSSSL '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsEnforceTLSSSL
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Enforce-TLS-SSL'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Enforce-TLS-SSL'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Enforce-TLS-SSL'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Enforce-TLS-SSL'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Enforce-TLS-SSL'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Enforce-TLS-SSL'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Enforce-TLS-SSL'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Deploy-SQL-DB-Auditing
module modPolicyAssignmentLZsDeploySQLDBAuditing '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsDeploySQLDBAuditing
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deploy-SQL-DB-Auditing'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deploy-SQL-DB-Auditing'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deploy-SQL-DB-Auditing'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deploy-SQL-DB-Auditing'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deploy-SQL-DB-Auditing'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deploy-SQL-DB-Auditing'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deploy-SQL-DB-Auditing'].libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.owner
    ]
  }
}

// Module - Policy Assignment - Deploy-SQL-Threat
module modPolicyAssignmentLZsDeploySQLThreat '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsDeploySQLThreat
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deploy-SQL-Threat'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deploy-SQL-Threat'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deploy-SQL-Threat'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deploy-SQL-Threat'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deploy-SQL-Threat'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deploy-SQL-Threat'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deploy-SQL-Threat'].libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.owner
    ]
  }
}

// Modules - Policy Assignments - Corp Management Group
// Module - Policy Assignment - Deny-Public-Endpoints
module modPolicyAssignmentLZsDenyPublicEndpoints '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsDenyPublicEndpoints
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deny-Public-Endpoints'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deny-Public-Endpoints'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deny-Public-Endpoints'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deny-Public-Endpoints'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deny-Public-Endpoints'].libDefinition.properties.parameters
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deny-Public-Endpoints'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deny-Public-Endpoints'].libDefinition.properties.enforcementMode
  }
}

// Module - Policy Assignment - Deploy-Private-DNS-Zones
module modPolicyAssignmentLZsDeployPrivateDNSZones '../../policy/assignments/policyAssignmentManagementGroup.bicep' = {
  dependsOn: [
    modCustomPolicyDefinitions
  ]
  scope: managementGroup(varManagementGroupIDs.landingZones)
  name: varModuleDeploymentNames.modPolicyAssignmentLZsDeployPrivateDNSZones
  params: {
    parPolicyAssignmentDefinitionID: varPolicyAssignments['Deny-Public-Endpoints'].definitionID
    parPolicyAssignmentName: varPolicyAssignments['Deny-Public-Endpoints'].libDefinition.name
    parPolicyAssignmentDisplayName: varPolicyAssignments['Deny-Public-Endpoints'].libDefinition.properties.displayName
    parPolicyAssignmentDescription: varPolicyAssignments['Deny-Public-Endpoints'].libDefinition.properties.description
    parPolicyAssignmentParameters: varPolicyAssignments['Deny-Public-Endpoints'].libDefinition.properties.parameters
    parPolicyAssignmentParameterOverrides: {
      azureFilePrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[29].id
      }
      azureWebPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[37].id
      }
      azureBatchPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[15].id
      }
      azureAppPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[36].id
      }
      azureAsrPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[21].id
      }
      azureIoTPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[38].id
      }
      azureKeyVaultPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[19].id
      }
      azureSignalRPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[28].id
      }
      azureAppServicesPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[25].id
      }
      azureEventGridTopicsPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[24].id
      }
      azureDiskAccessPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[4].id
      }
      azureCognitiveServicesPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[39].id
      }
      azureIotHubsPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[23].id
      }
      azureEventGridDomainsPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[24].id
      }
      azureRedisCachePrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[32].id
      }
      azureAcrPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[40].id
      }
      azureEventHubNamespacePrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[22].id
      }
      azureMachineLearningWorkspacePrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[26].id
      }
      azureServiceBusNamespacePrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[22].id
      }
      azureCognitiveSearchPrivateDnsZoneId: {
        value: modHubNetworking.outputs.outPrivateDnsZones[41].id
      }
    }
    parPolicyAssignmentIdentityType: varPolicyAssignments['Deny-Public-Endpoints'].libDefinition.identity.type
    parPolicyAssignmentEnforcementMode: varPolicyAssignments['Deny-Public-Endpoints'].libDefinition.properties.enforcementMode
    parPolicyAssignmentIdentityRoleDefinitionIDs: [
      varRBACRoleDefinitionIDs.networkContributor
    ]
  }
}

// Resource - Resource Group - For Spoke Networking - https://github.com/Azure/bicep/issues/5151
module modResourceGroupForSpokeNetworking '../../resourceGroup/resourceGroup.bicep' = [for (corpSub, i) in parCorpSubscriptionIds: if (!empty(parCorpSubscriptionIds)) {
  scope: subscription(corpSub.subID)
  name: '${varModuleDeploymentNames.modResourceGroupForSpokeNetworking}-${i}'
  params: {
    parResourceGroupLocation: parLocation
    parResourceGroupName: parResourceGroupNameForSpokeNetworking
  }
}]


// Module - Spoke Virtual Networking
module modSpokeNetworking '../../spokeNetworking/spokeNetworking.bicep' = [for (corpSub, i) in parCorpSubscriptionIds: if (!empty(parCorpSubscriptionIds)) {
  scope: resourceGroup(corpSub.subID, parResourceGroupNameForSpokeNetworking)
  name: '${varModuleDeploymentNames.modSpokeNetworking}-${i}'
  params: {
     parSpokeNetworkPrefix: parSpokeNetworkPrefix
     parSpokeNetworkAddressPrefix: corpSub.vnetCIDR
     parDdosEnabled: parDDoSEnabled
     parDdosProtectionPlanId: modHubNetworking.outputs.outDDoSPlanResourceID
     parNetworkDNSEnableProxy: parNetworkDNSEnableProxy
     parHubNVAEnabled: parAzureFirewallEnabled
     parDNSServerIPArray: parDNSServerIPArray
     parNextHopIPAddress: parAzureFirewallEnabled ? modHubNetworking.outputs.outAzureFirewallPrivateIP : ''
     parSpoketoHubRouteTableName: parSpoketoHubRouteTableName
     parBGPRoutePropogation: parBGPRoutePropogation
     parTags: parTags
  }
}]
