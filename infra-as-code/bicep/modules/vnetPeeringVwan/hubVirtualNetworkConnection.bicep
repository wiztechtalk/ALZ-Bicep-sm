@description('Virtual WAN Hub resource ID.')
param parVirtualWanHubResourceId string

@description('Remote Spoke virtual network resource ID.')
param parRemoteVirtualNetworkResourceId string

var varVwanHubName = split(parVirtualWanHubResourceId, '/')[8]

var varSpokeVnetName = split(parRemoteVirtualNetworkResourceId, '/')[8]

var varVnetPeeringVwanName = '${varVwanHubName}/${varSpokeVnetName}-vhc'

resource resVnetPeeringVwan 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2021-08-01' = if (!empty(parVirtualWanHubResourceId) && !empty(parRemoteVirtualNetworkResourceId)) {
  name: varVnetPeeringVwanName
  properties: {
    remoteVirtualNetwork: {
      id: parRemoteVirtualNetworkResourceId
    }
  }
}

output outHubVirtualNetworkConnectionName string = resVnetPeeringVwan.name
output outHubVirtualNetworkConnectionResourceId string = resVnetPeeringVwan.id
