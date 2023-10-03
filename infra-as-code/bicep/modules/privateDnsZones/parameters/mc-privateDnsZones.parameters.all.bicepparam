using '../privateDnsZones.bicep'

param parLocation = 'chinaeast2'

param parPrivateDnsZones = [
  'privatelink.azure-automation.cn'
  'privatelink.database.chinacloudapi.cn'
  'privatelink.blob.core.chinacloudapi.cn'
  'privatelink.table.core.chinacloudapi.cn'
  'privatelink.queue.core.chinacloudapi.cn'
  'privatelink.file.core.chinacloudapi.cn'
  'privatelink.web.core.chinacloudapi.cn'
  'privatelink.dfs.core.chinacloudapi.cn'
  'privatelink.documents.azure.cn'
  'privatelink.mongo.cosmos.azure.cn'
  'privatelink.cassandra.cosmos.azure.cn'
  'privatelink.gremlin.cosmos.azure.cn'
  'privatelink.table.cosmos.azure.cn'
  'privatelink.postgres.database.chinacloudapi.cn'
  'privatelink.mysql.database.chinacloudapi.cn'
  'privatelink.mariadb.database.chinacloudapi.cn'
  'privatelink.vaultcore.azure.cn'
  'privatelink.servicebus.chinacloudapi.cn'
  'privatelink.azure-devices.cn'
  'privatelink.eventgrid.azure.cn'
  'privatelink.chinacloudsites.cn'
  'privatelink.api.ml.azure.cn'
  'privatelink.notebooks.chinacloudapi.cn'
  'privatelink.signalr.azure.cn'
  'privatelink.azurehdinsight.cn'
  'privatelink.afs.azure.cn'
  'privatelink.datafactory.azure.cn'
  'privatelink.adf.azure.cn'
  'privatelink.redis.cache.chinacloudapi.cn'
]

param parPrivateDnsZoneAutoMergeAzureBackupZone = true

param parTags = {
  Environment: 'Live'
}

param parVirtualNetworkIdToLink = '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/xxxxxxxxxxx/providers/Microsoft.Network/virtualNetworks/xxxxxxxxxxx'

param parTelemetryOptOut = false
