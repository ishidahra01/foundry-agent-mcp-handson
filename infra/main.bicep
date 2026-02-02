// Main Bicep template for Flow① MCP Hands-on
targetScope = 'subscription'

@description('Name of the resource group')
param resourceGroupName string = 'rg-foundry-mcp-handson'

@description('Location for all resources')
param location string = 'japaneast'

@description('Base name for all resources')
param baseName string = 'foundry-mcp-${uniqueString(subscription().subscriptionId)}'

@description('Azure AD Tenant ID for APIM JWT validation')
param tenantId string

@description('Azure AD App Client ID (Audience for JWT)')
param clientId string

@description('APIM SKU')
@allowed([
  'BasicV2'
  'StandardV2'
])
param apimSku string = 'BasicV2'

@description('APIM publisher email')
param publisherEmail string

@description('APIM publisher name')
param publisherName string

// Create resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

// Deploy resources in the resource group
module resources './resources.bicep' = {
  name: 'resources-deployment'
  scope: rg
  params: {
    location: location
    baseName: baseName
    tenantId: tenantId
    clientId: clientId
    apimSku: apimSku
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// Output important values
output resourceGroupName string = rg.name
output apimName string = resources.outputs.apimName
output apimGatewayUrl string = resources.outputs.apimGatewayUrl
output functionAppName string = resources.outputs.functionAppName
output functionAppUrl string = resources.outputs.functionAppUrl
output webAppName string = resources.outputs.webAppName
output webAppUrl string = resources.outputs.webAppUrl
output appInsightsName string = resources.outputs.appInsightsName
output appInsightsInstrumentationKey string = resources.outputs.appInsightsInstrumentationKey
