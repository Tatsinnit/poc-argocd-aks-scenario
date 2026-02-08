// Azure Container Registry Bicep Module
targetScope = 'resourceGroup'

@description('Name of the Azure Container Registry')
@minLength(5)
@maxLength(50)
param acrName string

@description('Location for the ACR')
param location string = resourceGroup().location

@description('SKU for the ACR')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Basic'

@description('Enable admin user for ACR')
param adminUserEnabled bool = false

@description('Tags for the ACR resource')
param tags object = {
  Environment: 'Demo'
  Project: 'ArgoCD-AKS'
  ManagedBy: 'Bicep'
}

// Azure Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: acrSku == 'Premium' ? 'Enabled' : 'Disabled'
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        status: 'disabled'
        type: 'Notary'
      }
      retentionPolicy: {
        days: 7
        status: acrSku == 'Premium' ? 'enabled' : 'disabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
  }
}

// Outputs
@description('The resource ID of the ACR')
output acrId string = containerRegistry.id

@description('The name of the ACR')
output acrName string = containerRegistry.name

@description('The login server of the ACR')
output acrLoginServer string = containerRegistry.properties.loginServer
