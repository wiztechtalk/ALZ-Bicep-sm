@description('Name of Public IP to create in Azure. Default: None')
param parPublicIPName string

@description('Public IP Address SKU. Default: None')
param parPublicIPSku object

@description('Properties of Public IP to be deployed. Default: None')
param parPublicIPProperties object

@description('Azure Region to deploy Public IP Address to. Default: Current Resource Group')
param parLocation string = resourceGroup().location

@allowed([
  '1'
  '2'
  '3'
])
@description('Availability Zones to deploy the Public IP across. Region must support Availability Zones to use. If it does not then leave empty.')
param parAvailabilityZones array = []

@description('Tags to be applied to resource when deployed.  Default: None')
param parTags object

@description('Set Parameter to true to Opt-out of deployment telemetry')
param parTelemetryOptOut bool = false

// Customer Usage Attribution Id
var varCuaid = '3f85b84c-6bad-4c42-86bf-11c233241c22'

resource resPublicIP 'Microsoft.Network/publicIPAddresses@2021-05-01' ={
  name: parPublicIPName
  tags: parTags
  location: parLocation
  zones: parAvailabilityZones
  sku: parPublicIPSku
  properties: parPublicIPProperties
}

// Optional Deployment for Customer Usage Attribution
module modCustomerUsageAttribution '../../CRML/customerUsageAttribution/cuaIdResourceGroup.bicep' = if (!parTelemetryOptOut) {
  #disable-next-line no-loc-expr-outside-params //Only to ensure telemetry data is stored in same location as deployment. See https://github.com/Azure/ALZ-Bicep/wiki/FAQ#why-are-some-linter-rules-disabled-via-the-disable-next-line-bicep-function for more information
  name: 'pid-${varCuaid}-${uniqueString(resourceGroup().location, parPublicIPName)}'
  params: {}
}

output outPublicIPID string = resPublicIP.id


