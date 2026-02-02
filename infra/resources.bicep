// Resources template for Flow① MCP Hands-on
@description('Location for all resources')
param location string

@description('Base name for all resources')
param baseName string

@description('Azure AD Tenant ID for APIM JWT validation')
param tenantId string

@description('Azure AD App Client ID (Audience for JWT)')
param clientId string

@description('APIM SKU')
param apimSku string

@description('APIM publisher email')
param publisherEmail string

@description('APIM publisher name')
param publisherName string

// Variables
var apimName = 'apim-${baseName}'
var functionAppName = 'func-${baseName}'
var webAppName = 'web-${baseName}'
var appInsightsName = 'appins-${baseName}'
var storageAccountName = 'st${replace(baseName, '-', '')}'
var appServicePlanName = 'asp-${baseName}'
var logAnalyticsName = 'log-${baseName}'

// Log Analytics Workspace for App Insights
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Storage Account for Functions
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// App Service Plan for Functions and Web App
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true // Linux
  }
}

// Azure Function App (MCP Server)
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
      ]
      cors: {
        allowedOrigins: [
          '*'
        ]
      }
    }
    httpsOnly: true
  }
}

// Web App (Next.js)
resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '20-lts'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
    }
    httpsOnly: true
  }
}

// API Management
resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: apimSku
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// APIM Named Value for Function Key (placeholder)
resource apimNamedValueFunctionKey 'Microsoft.ApiManagement/service/namedValues@2023-05-01-preview' = {
  name: 'function-key'
  parent: apim
  properties: {
    displayName: 'function-key'
    value: 'placeholder' // Should be updated after deployment with actual function key
    secret: true
  }
}

// APIM API for MCP
resource apimMcpApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  name: 'mcp-api'
  parent: apim
  properties: {
    displayName: 'MCP API'
    path: 'mcp'
    protocols: [
      'https'
    ]
    serviceUrl: 'https://${functionApp.properties.defaultHostName}/api'
    subscriptionRequired: false
  }
}

// APIM Operation for MCP Filter
resource apimMcpFilterOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  name: 'filter'
  parent: apimMcpApi
  properties: {
    displayName: 'MCP Filter Operation'
    method: '*'
    urlTemplate: '/filter/*'
    description: 'MCP endpoint with JWT validation and user ID filtering'
  }
}

// APIM Policy for MCP Filter Operation
resource apimMcpFilterPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-05-01-preview' = {
  name: 'policy'
  parent: apimMcpFilterOperation
  properties: {
    format: 'xml'
    value: '''
      <policies>
        <inbound>
          <base />
          <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized. Access token is missing or invalid.">
            <openid-config url="https://login.microsoftonline.com/${tenantId}/v2.0/.well-known/openid-configuration" />
            <audiences>
              <audience>${clientId}</audience>
            </audiences>
            <required-claims>
              <claim name="oid" match="any">
                <value>@(context.Request.Headers.GetValueOrDefault("Authorization","").AsJwt()?.Claims["oid"].FirstOrDefault())</value>
              </claim>
            </required-claims>
          </validate-jwt>
          <set-header name="X-EndUser-Id" exists-action="override">
            <value>@{
              var jwt = context.Request.Headers.GetValueOrDefault("Authorization","").AsJwt();
              return jwt?.Claims.GetValueOrDefault("oid", "unknown");
            }</value>
          </set-header>
          <rewrite-uri template="/{*path}" copy-unmatched-params="true" />
        </inbound>
        <backend>
          <base />
        </backend>
        <outbound>
          <base />
        </outbound>
        <on-error>
          <base />
        </on-error>
      </policies>
    '''
  }
}

// Outputs
output apimName string = apim.name
output apimGatewayUrl string = apim.properties.gatewayUrl
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output appInsightsName string = appInsights.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
