/*
Instructions

1. Create the storage account
2. Create the container
3. Run the deployment script which will output the variables
4. The deployment script will then write out the files which will be loaded into storage acocunt
5. later on in the script, the vmextension resource will call the script against the VM

*/


@description('Location for all resources.')
param location string = resourceGroup().location

param storageAccountPrefix string = 'tststg'
param storageAccountSku string = 'Standard_LRS'
param storageAccountKind string = 'StorageV2'
param storageContributorRoleDefinitionId string = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/17d1049b-9a84-46fb-8f53-869881c3d3ab'
param containersToCreate object = {
  dsc: [ 'updateSQLService.ps1', 'updateSQLAgent.ps1' ]
}
var containersToCreateFormatted = replace(string(containersToCreate), '"', '\\"')
var storageAccountName = '${storageAccountPrefix}${uniqueString(resourceGroup().id)}'
var containerName = 'dsc'
var serviceacc = 'localadmin'
param baseTime string = utcNow()


//VM Name 1
//@description('The name of the VM')
//param virtualSQLMachineName1 string = 'test-sql01'
var domain = 'testdomain'
var vmname = 'test-sql01'
param PWord string 

resource stg 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountSku
  }
  kind: storageAccountKind
  properties: {
    allowBlobPublicAccess: true
    supportsHttpsTrafficOnly: true
  }
}

resource deploymentScriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'deploymentScriptIdentity'
  location: location
}

resource dsRBAC 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deploymentScriptIdentity.name, 'dsRBAC')
  scope: resourceGroup()
  properties: {
    principalId: deploymentScriptIdentity.properties.principalId
    roleDefinitionId: storageContributorRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

resource createContainers 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzurePowerShell'
  location: location
  name: 'CreateDefaultContainers'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptIdentity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '3.0'
    retentionInterval: 'PT1H'
    cleanupPreference: 'Always'
    arguments: '-storageAccountName ${storageAccountName} -resourceGroupName ${resourceGroup().name} -containersToCreate \'${containersToCreateFormatted}\' -domain ${domain} -PWord ${PWord} -serviceacc ${serviceacc} -vmname ${vmname}'
    scriptContent: loadTextContent('./DSC/test.ps1')
  }
}

// Get SAS Token for Storage Account with DSC files
var _artifactsLocationSasToken = stg.listServiceSAS('2021-04-01', {
  canonicalizedResource: '/blob/${stg.name}/${containerName}'
  signedResource: 'c'
  signedProtocol: 'https'
  signedPermission: 'r'
  signedServices: 'b'
  signedExpiry: dateTimeAdd(baseTime, 'PT1H')
}).serviceSasToken

// Created Active Directory forest and DOmain Controller

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' existing = {
  name: vmname
}

resource csExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = {
  location: location
  parent: vm
  name: 'Microsoft.Powershell.Command'
  properties: {
    //publisher: 'Microsoft.Powershell'
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.8'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        '${stg.properties.primaryEndpoints.blob}${containerName}/updateSQLService.ps1?${_artifactsLocationSasToken}'
        '${stg.properties.primaryEndpoints.blob}${containerName}/updateSQLAgent.ps1?${_artifactsLocationSasToken}'
        ]
      CommandToExecute: 'powershell -ExecutionPolicy Unrestricted -File updateSQLService.ps1'
      managedIdentity: {} 
      timestamp: 2000
      configuration: {
      }
      configurationArguments: {
        domainName: domain
        PWord: PWord
        serviceacc: serviceacc
        vmname: vmname
      }
    }
    protectedSettings: {
      configurationUrlSasToken: '?${_artifactsLocationSasToken}'
    }
  }
  dependsOn: [
    createContainers
  ]
}

