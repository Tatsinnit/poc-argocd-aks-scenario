// Main Bicep template for AKS + ArgoCD Demo Infrastructure
targetScope = 'resourceGroup'

@description('The name of the AKS cluster')
param clusterName string = 'aks-argocd-demo'

@description('The location for all resources')
param location string = resourceGroup().location

@description('The number of nodes in the AKS cluster')
@minValue(1)
@maxValue(50)
param nodeCount int = 3

@description('The VM size for the AKS nodes')
param vmSize string = 'Standard_DS2_v2'

@description('Kubernetes version')
param kubernetesVersion string = '1.28'

@description('Name of the Azure Container Registry')
param acrName string = 'acrargocdemo${uniqueString(resourceGroup().id)}'

@description('Enable RBAC for the AKS cluster')
param enableRBAC bool = true

@description('Network plugin for AKS')
@allowed([
  'azure'
  'kubenet'
])
param networkPlugin string = 'kubenet'

@description('Enable managed identity')
param enableManagedIdentity bool = true

// Azure Container Registry
module acr 'acr.bicep' = {
  name: 'acrDeployment'
  params: {
    acrName: acrName
    location: location
  }
}

// AKS Cluster
resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  name: clusterName
  location: location
  identity: enableManagedIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: '${clusterName}-dns'
    enableRBAC: enableRBAC
    agentPoolProfiles: [
      {
        name: 'nodepool1'
        count: nodeCount
        vmSize: vmSize
        osType: 'Linux'
        mode: 'System'
        enableAutoScaling: false
        type: 'VirtualMachineScaleSets'
        availabilityZones: []
      }
    ]
    networkProfile: {
      networkPlugin: networkPlugin
      loadBalancerSku: 'standard'
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
    }
  }
}

// Role Assignment: Allow AKS to pull images from ACR
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableManagedIdentity) {
  name: guid(resourceGroup().id, aksCluster.id, acr.outputs.acrId, 'AcrPull')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull role
    principalId: aksCluster.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
@description('The resource ID of the AKS cluster')
output aksClusterId string = aksCluster.id

@description('The name of the AKS cluster')
output aksClusterName string = aksCluster.name

@description('The FQDN of the AKS cluster')
output aksClusterFqdn string = aksCluster.properties.fqdn

@description('The resource ID of the ACR')
output acrId string = acr.outputs.acrId

@description('The name of the ACR')
output acrName string = acr.outputs.acrName

@description('The login server of the ACR')
output acrLoginServer string = acr.outputs.acrLoginServer

@description('The principal ID of the AKS managed identity')
output aksPrincipalId string = enableManagedIdentity ? aksCluster.identity.principalId : ''
