targetScope = 'subscription'

// ========== //
// Parameters //
// ========== //
@description('Optional. The name of the resource group to deploy for testing purposes.')
@maxLength(90)
param resourceGroupName string = 'ms.machinelearningservices.workspaces-${serviceShort}-rg'

@description('Optional. The location to deploy resources to.')
param location string = deployment().location

@description('Optional. A short identifier for the kind of deployment. Should be kept short to not run into resource-name length-constraints.')
param serviceShort string = 'mlswcom'

// =========== //
// Deployments //
// =========== //

// General resources
// =================
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
}

module resourceGroupResources 'dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-paramNested'
  params: {
    virtualNetworkName: 'dep-<<namePrefix>>-vnet-${serviceShort}'
    managedIdentityName: 'dep-<<namePrefix>>-msi-${serviceShort}'
    keyVaultName: 'dep-<<namePrefix>>-kv-${serviceShort}'
    applicationInsightsName: 'dep-<<namePrefix>>-appi-${serviceShort}'
    storageAccountName: 'dep<<namePrefix>>st${serviceShort}'
  }
}

// Diagnostics
// ===========
module diagnosticDependencies '../../../../.shared/dependencyConstructs/diagnostic.dependencies.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name, location)}-diagnosticDependencies'
  params: {
    storageAccountName: 'dep<<namePrefix>>diasa${serviceShort}01'
    logAnalyticsWorkspaceName: 'dep-<<namePrefix>>-law-${serviceShort}'
    eventHubNamespaceEventHubName: 'dep-<<namePrefix>>-evh-${serviceShort}'
    eventHubNamespaceName: 'dep-<<namePrefix>>-evhns-${serviceShort}'
    location: location
  }
}

// ============== //
// Test Execution //
// ============== //

module testDeployment '../../deploy.bicep' = {
  scope: resourceGroup
  name: '${uniqueString(deployment().name)}-test-${serviceShort}'
  params: {
    name: '<<namePrefix>>${serviceShort}001'
    associatedApplicationInsightsResourceId: resourceGroupResources.outputs.applicationInsightsResourceId
    associatedKeyVaultResourceId: resourceGroupResources.outputs.keyVaultResourceId
    associatedStorageAccountResourceId: resourceGroupResources.outputs.storageAccountResourceId
    sku: 'Basic'
    computes: [
      {
        computeLocation: 'westeurope'
        computeType: 'AmlCompute'
        description: 'Default CPU Cluster'
        disableLocalAuth: false
        location: 'westeurope'
        name: 'DefaultCPU'
        properties: {
          enableNodePublicIp: true
          isolatedNetwork: false
          osType: 'Linux'
          remoteLoginPortPublicAccess: 'Disabled'
          scaleSettings: {
            maxNodeCount: 3
            minNodeCount: 0
            nodeIdleTimeBeforeScaleDown: 'PT5M'
          }
          vmPriority: 'Dedicated'
          vmSize: 'STANDARD_DS11_V2'
        }
        sku: 'Basic'
        // Must be false if `primaryUserAssignedIdentity` is provided
        systemAssignedIdentity: false
        userAssignedIdentities: {
          '${resourceGroupResources.outputs.managedIdentityResourceId}': {}
        }
      }
    ]
    description: 'The cake is a lie.'
    diagnosticLogsRetentionInDays: 7
    diagnosticStorageAccountId: diagnosticDependencies.outputs.storageAccountResourceId
    diagnosticWorkspaceId: diagnosticDependencies.outputs.logAnalyticsWorkspaceResourceId
    diagnosticEventHubAuthorizationRuleId: diagnosticDependencies.outputs.eventHubAuthorizationRuleId
    diagnosticEventHubName: diagnosticDependencies.outputs.eventHubNamespaceEventHubName
    discoveryUrl: 'http://example.com'
    imageBuildCompute: 'testcompute'
    lock: 'CanNotDelete'
    primaryUserAssignedIdentity: resourceGroupResources.outputs.managedIdentityResourceId
    privateEndpoints: [
      {
        service: 'amlworkspace'
        subnetResourceId: resourceGroupResources.outputs.subnetResourceId
        privateDnsZoneGroup: {
          privateDNSResourceIds: [
            resourceGroupResources.outputs.privateDNSZoneResourceId
          ]
        }
      }
    ]
    roleAssignments: [
      {
        principalIds: [
          resourceGroupResources.outputs.managedIdentityPrincipalId
        ]
        roleDefinitionIdOrName: 'Reader'
      }
    ]
    systemAssignedIdentity: false
    userAssignedIdentities: {
      '${resourceGroupResources.outputs.managedIdentityResourceId}': {}
    }
  }
}
