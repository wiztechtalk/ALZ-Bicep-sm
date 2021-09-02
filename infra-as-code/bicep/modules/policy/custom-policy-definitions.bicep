/*
SUMMARY: This module deploys the custom Azure Policy Definitions & Initiatives supplied by the Enterprise Scale conceptual architecture and reference implementation to a specified Management Group.
DESCRIPTION: This module deploys the custom Azure Policy Definitions & Initiatives supplied by the Enterprise Scale conceptual architecture and reference implementation defined here (https://aka.ms/enterprisescale) to a specified Management Group.
AUTHOR/S: jtracey93
VERSION: 1.0.0
*/


targetScope = 'managementGroup'

var varTargetManagementGroupResoruceID = tenantResourceId('Microsoft.Management/managementGroups', '${managementGroup()}')

// This variable contains a number of objects that load in the custom Azure Policy Defintions that are provided as part of the ESLZ/ALZ reference implementation
var varCustomPolicyDefinitionsArray = [
  {
    name: 'Append-AppService-httpsonly'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_append_appservice_httpsonly.json'))
  }
  {
    name: 'Append-AppService-latestTLS'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_append_appservice_latesttls.json'))
  }
  {
    name: 'Append-KV-SoftDelete'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_append_kv_softdelete.json'))
  }
  {
    name: 'Append-Redis-disableNonSslPort'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_append_redis_disablenonsslport.json'))
  }
  {
    name: 'Append-Redis-sslEnforcement'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_append_redis_sslenforcement.json'))
  }
  {
    name: 'Audit-MachineLearning-PrivateEndpointId'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_audit_machinelearning_privateendpointid.json'))
  }
  {
    name: 'Deny-AA-child-resources'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_aa_child_resources.json'))
  }
  {
    name: 'Deny-AppGW-Without-WAF'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_appgw_without_waf.json'))
  }
  {
    name: 'Deny-AppServiceApiApp-http'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_appserviceapiapp_http.json'))
  }
  {
    name: 'Deny-AppServiceFunctionApp-http'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_appservicefunctionapp_http.json'))
  }
  {
    name: 'Deny-AppServiceWebApp-http'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_appservicewebapp_http.json'))
  }
  {
    name: 'Deny-Databricks-NoPublicIp'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_databricks_nopublicip.json'))
  }
  {
    name: 'Deny-Databricks-Sku'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_databricks_sku.json'))
  }
  {
    name: 'Deny-Databricks-VirtualNetwork'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_databricks_virtualnetwork.json'))
  }
  {
    name: 'Deny-MachineLearning-Aks'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_machinelearning_aks.json'))
  }
  {
    name: 'Deny-MachineLearning-Compute-SubnetId'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_machinelearning_compute_subnetid.json'))
  }
  {
    name: 'Deny-MachineLearning-Compute-VmSize'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_machinelearning_compute_vmsize.json'))
  }
  {
    name: 'Deny-MachineLearning-ComputeCluster-RemoteLoginPortPublicAccess'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_machinelearning_computecluster_remoteloginportpublicaccess.json'))
  }
  {
    name: 'Deny-MachineLearning-ComputeCluster-Scale'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_machinelearning_computecluster_scale.json'))
  }
  {
    name: 'Deny-MachineLearning-HbiWorkspace'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_machinelearning_hbiworkspace.json'))
  }
  {
    name: 'Deny-MachineLearning-PublicAccessWhenBehindVnet'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_machinelearning_publicaccesswhenbehindvnet.json'))
  }
  {
    name: 'Deny-MySql-http'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_mysql_http.json'))
  }
  {
    name: 'Deny-PostgreSql-http'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_postgresql_http.json'))
  }
  {
    name: 'Deny-Private-DNS-Zones'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_private_dns_zones.json'))
  }
  {
    name: 'Deny-PublicEndpoint-MariaDB'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_publicendpoint_mariadb.json'))
  }
  {
    name: 'Deny-PublicIP'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_publicip.json'))
  }
  {
    name: 'Deny-RDP-From-Internet'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_rdp_from_internet.json'))
  }
  {
    name: 'Deny-Redis-http'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_redis_http.json'))
  }
  {
    name: 'Deny-Sql-minTLS'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_sql_mintls.json'))
  }
  {
    name: 'Deny-SqlMi-minTLS'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_sqlmi_mintls.json'))
  }
  {
    name: 'Deny-Storage-minTLS'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_storage_mintls.json'))
  }
  {
    name: 'Deny-Subnet-Without-Nsg'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_subnet_without_nsg.json'))
  }
  {
    name: 'Deny-Subnet-Without-Udr'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_subnet_without_udr.json'))
  }
  {
    name: 'Deny-VNET-Peer-Cross-Sub'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_vnet_peer_cross_sub.json'))
  }
  {
    name: 'Deny-VNet-Peering'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deny_vnet_peering.json'))
  }
  {
    name: 'Deploy-ASC-Defender-ACR'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_asc_defender_acr.json'))
  }
  {
    name: 'Deploy-ASC-Defender-AKS'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_asc_defender_aks.json'))
  }
  {
    name: 'Deploy-ASC-Defender-AKV'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_asc_defender_akv.json'))
  }
  {
    name: 'Deploy-ASC-Defender-AppSrv'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_asc_defender_appsrv.json'))
  }
  {
    name: 'Deploy-ASC-Defender-ARM'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_asc_defender_arm.json'))
  }
  {
    name: 'Deploy-ASC-Defender-DNS'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_asc_defender_dns.json'))
  }
  {
    name: 'Deploy-ASC-Defender-SA'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_asc_defender_sa.json'))
  }
  {
    name: 'Deploy-ASC-Defender-Sql'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_asc_defender_sql.json'))
  }
  {
    name: 'Deploy-ASC-Defender-SQLVM'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_asc_defender_sqlvm.json'))
  }
  {
    name: 'Deploy-ASC-Defender-VMs'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_asc_defender_vms.json'))
  }
  {
    name: 'Deploy-ASC-SecurityContacts'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_asc_securitycontacts.json'))
  }
  {
    name: 'Deploy-Budget'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_budget.json'))
  }
  {
    name: 'Deploy-DDoSProtection'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_ddosprotection.json'))
  }
  {
    name: 'Deploy-Default-Udr'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_default_udr.json'))
  }
  {
    name: 'Deploy-Diagnostics-AA'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_aa.json'))
  }
  {
    name: 'Deploy-Diagnostics-ACI'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_aci.json'))
  }
  {
    name: 'Deploy-Diagnostics-ACR'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_acr.json'))
  }
  {
    name: 'Deploy-Diagnostics-AnalysisService'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_analysisservice.json'))
  }
  {
    name: 'Deploy-Diagnostics-ApiForFHIR'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_apiforfhir.json'))
  }
  {
    name: 'Deploy-Diagnostics-APIMgmt'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_apimgmt.json'))
  }
  {
    name: 'Deploy-Diagnostics-ApplicationGateway'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_applicationgateway.json'))
  }
  {
    name: 'Deploy-Diagnostics-CDNEndpoints'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_cdnendpoints.json'))
  }
  {
    name: 'Deploy-Diagnostics-CognitiveServices'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_cognitiveservices.json'))
  }
  {
    name: 'Deploy-Diagnostics-CosmosDB'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_cosmosdb.json'))
  }
  {
    name: 'Deploy-Diagnostics-Databricks'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_databricks.json'))
  }
  {
    name: 'Deploy-Diagnostics-DataExplorerCluster'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_dataexplorercluster.json'))
  }
  {
    name: 'Deploy-Diagnostics-DataFactory'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_datafactory.json'))
  }
  {
    name: 'Deploy-Diagnostics-DLAnalytics'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_dlanalytics.json'))
  }
  {
    name: 'Deploy-Diagnostics-EventGridSub'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_eventgridsub.json'))
  }
  {
    name: 'Deploy-Diagnostics-EventGridSystemTopic'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_eventgridsystemtopic.json'))
  }
  {
    name: 'Deploy-Diagnostics-EventGridTopic'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_eventgridtopic.json'))
  }
  {
    name: 'Deploy-Diagnostics-ExpressRoute'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_expressroute.json'))
  }
  {
    name: 'Deploy-Diagnostics-Firewall'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_firewall.json'))
  }
  {
    name: 'Deploy-Diagnostics-FrontDoor'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_frontdoor.json'))
  }
  {
    name: 'Deploy-Diagnostics-Function'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_function.json'))
  }
  {
    name: 'Deploy-Diagnostics-HDInsight'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_hdinsight.json'))
  }
  {
    name: 'Deploy-Diagnostics-iotHub'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_iothub.json'))
  }
  {
    name: 'Deploy-Diagnostics-LoadBalancer'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_loadbalancer.json'))
  }
  {
    name: 'Deploy-Diagnostics-LogicAppsISE'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_logicappsise.json'))
  }
  {
    name: 'Deploy-Diagnostics-MariaDB'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_mariadb.json'))
  }
  {
    name: 'Deploy-Diagnostics-MediaService'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_mediaservice.json'))
  }
  {
    name: 'Deploy-Diagnostics-MlWorkspace'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_mlworkspace.json'))
  }
  {
    name: 'Deploy-Diagnostics-MySQL'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_mysql.json'))
  }
  {
    name: 'Deploy-Diagnostics-NetworkSecurityGroups'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_networksecuritygroups.json'))
  }
  {
    name: 'Deploy-Diagnostics-NIC'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_nic.json'))
  }
  {
    name: 'Deploy-Diagnostics-PostgreSQL'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_postgresql.json'))
  }
  {
    name: 'Deploy-Diagnostics-PowerBIEmbedded'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_powerbiembedded.json'))
  }
  {
    name: 'Deploy-Diagnostics-RedisCache'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_rediscache.json'))
  }
  {
    name: 'Deploy-Diagnostics-Relay'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_relay.json'))
  }
  {
    name: 'Deploy-Diagnostics-SignalR'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_signalr.json'))
  }
  {
    name: 'Deploy-Diagnostics-SQLElasticPools'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_sqlelasticpools.json'))
  }
  {
    name: 'Deploy-Diagnostics-SQLMI'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_sqlmi.json'))
  }
  {
    name: 'Deploy-Diagnostics-TimeSeriesInsights'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_timeseriesinsights.json'))
  }
  {
    name: 'Deploy-Diagnostics-TrafficManager'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_trafficmanager.json'))
  }
  {
    name: 'Deploy-Diagnostics-VirtualNetwork'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_virtualnetwork.json'))
  }
  {
    name: 'Deploy-Diagnostics-VM'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_vm.json'))
  }
  {
    name: 'Deploy-Diagnostics-VMSS'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_vmss.json'))
  }
  {
    name: 'Deploy-Diagnostics-VNetGW'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_vnetgw.json'))
  }
  {
    name: 'Deploy-Diagnostics-WebServerFarm'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_webserverfarm.json'))
  }
  {
    name: 'Deploy-Diagnostics-Website'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_website.json'))
  }
  {
    name: 'Deploy-Diagnostics-WVDAppGroup'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_wvdappgroup.json'))
  }
  {
    name: 'Deploy-Diagnostics-WVDHostPools'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_wvdhostpools.json'))
  }
  {
    name: 'Deploy-Diagnostics-WVDWorkspace'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_diagnostics_wvdworkspace.json'))
  }
  {
    name: 'Deploy-FirewallPolicy'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_firewallpolicy.json'))
  }
  {
    name: 'Deploy-MySQL-sslEnforcement'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_mysql_sslenforcement.json'))
  }
  {
    name: 'Deploy-Nsg-FlowLogs-to-LA'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_nsg_flowlogs_to_la.json'))
  }
  {
    name: 'Deploy-Nsg-FlowLogs'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_nsg_flowlogs.json'))
  }
  {
    name: 'Deploy-PostgreSQL-sslEnforcement'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_postgresql_sslenforcement.json'))
  }
  {
    name: 'Deploy-Sql-AuditingSettings'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_sql_auditingsettings.json'))
  }
  {
    name: 'Deploy-SQL-minTLS'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_sql_mintls.json'))
  }
  {
    name: 'Deploy-Sql-SecurityAlertPolicies'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_sql_securityalertpolicies.json'))
  }
  {
    name: 'Deploy-Sql-Tde'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_sql_tde.json'))
  }
  {
    name: 'Deploy-Sql-vulnerabilityAssessments'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_sql_vulnerabilityassessments.json'))
  }
  {
    name: 'Deploy-SqlMi-minTLS'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_sqlmi_mintls.json'))
  }
  {
    name: 'Deploy-Storage-sslEnforcement'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_storage_sslenforcement.json'))
  }
  {
    name: 'Deploy-VNET-HubSpoke'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_vnet_hubspoke.json'))
  }
  {
    name: 'Deploy-Windows-DomainJoin'
    libDefinition: json(loadTextContent('lib/policy_definitions/policy_definition_es_deploy_windows_domainjoin.json'))
  }  
]

// This variable contains a number of objects that load in the custom Azure Policy Set/Initiative Defintions that are provided as part of the ESLZ/ALZ reference implementation
var varCustomPolicySetDefinitionsArray = [
  {
    name: 'Deny-PublicPaaSEndpoints'
    libDefinition: json(loadTextContent('lib/policy_set_definitions/policy_set_definition_es_deny_publicpaasendpoints.json'))
  }
  {
    name: 'Deploy-ASC-Config'
    libDefinition: json(loadTextContent('lib/policy_set_definitions/policy_set_definition_es_deploy_asc_config.json'))
  }
  {
    name: 'Deploy-Diagnostics-LogAnalytics'
    libDefinition: json(loadTextContent('lib/policy_set_definitions/policy_set_definition_es_deploy_diagnostics_loganalytics.json'))
  }
  {
    name: 'Deploy-Private-DNS-Zones'
    libDefinition: json(loadTextContent('lib/policy_set_definitions/policy_set_definition_es_deploy_private_dns_zones.json'))
  }
  {
    name: 'Deploy-Sql-Security'
    libDefinition: json(loadTextContent('lib/policy_set_definitions/policy_set_definition_es_deploy_sql_security.json'))
  }
  {
    name: 'Enforce-Encryption-CMK'
    libDefinition: json(loadTextContent('lib/policy_set_definitions/policy_set_definition_es_enforce_encryption_cmk.json'))
  }
  {
    name: 'Enforce-EncryptTransit'
    libDefinition: json(loadTextContent('lib/policy_set_definitions/policy_set_definition_es_enforce_encrypttransit.json'))
  }  
]


resource resPolicyDefinitions 'Microsoft.Authorization/policyDefinitions@2020-09-01' = [for policy in varCustomPolicyDefinitionsArray: {
  name: policy.libDefinition.name
  properties: {
    description: policy.libDefinition.properties.description
    displayName: policy.libDefinition.properties.displayName
    metadata: policy.libDefinition.properties.metadata
    mode: policy.libDefinition.properties.mode
    parameters: policy.libDefinition.properties.parameters
    policyType: policy.libDefinition.properties.policyType
    policyRule: policy.libDefinition.properties.policyRule
  }
}]

resource resPolicySetDefinitions 'Microsoft.Authorization/policySetDefinitions@2020-09-01' = [for policySet in varCustomPolicySetDefinitionsArray: {
  dependsOn: [
    resPolicyDefinitions // Must wait for policy definitons to be deployed before starting the creation of Policy Set/Initiative Defininitions
  ] 
  name: policySet.libDefinition.name
  properties: {
    description: policySet.libDefinition.properties.description
    displayName: policySet.libDefinition.properties.displayName
    metadata: policySet.libDefinition.properties.metadata
    parameters: policySet.libDefinition.properties.parameters
    policyType: policySet.libDefinition.properties.policyType
    policyDefinitions: policySet.libDefinition.properties.policyDefinitions
    policyDefinitionGroups: policySet.libDefinition.properties.policyDefinitionGroups
    
  }
}]

