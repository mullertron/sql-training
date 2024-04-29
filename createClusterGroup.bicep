


@description('Admin username')
param adminUsername string 

@description('Admin password')
@secure()
param adminPassword string 

param installStorageAccountName string = 'stgseg6rzf6ahs3lu4'
@description('Existing storage account which has the DSC Files')
resource stg 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: installStorageAccountName 
}

param baseTime string = utcNow('u')
var clustername = 'testcluster'
var domainName = 'testdomain.local'
var containerName = 'dsc'
var staticIPAddress = '10.0.2.21'
//VM Name 1
@description('The name of the VM')
param virtualSQLMachineName1 string = 'test-sql01'

var _artifactsLocationSasToken = stg.listServiceSAS('2021-04-01', {
  canonicalizedResource: '/blob/${stg.name}/${containerName}'
  signedResource: 'c'
  signedProtocol: 'https'
  signedPermission: 'r'
  signedServices: 'b'
  signedExpiry: dateTimeAdd(baseTime, 'PT1H')
}).serviceSasToken

@description('Location for all resources.')
param location string = resourceGroup().location

resource virtualMachine1 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: virtualSQLMachineName1
}


resource dscExtensiondomjoinsql01 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = {
    location: location
    parent: virtualMachine1
    name: 'Microsoft.Powershell.DSC'
    properties: {
      publisher: 'Microsoft.Powershell'
      type: 'DSC'
      typeHandlerVersion: '2.77'
      autoUpgradeMinorVersion: true
      settings: {
        wmfVersion: 'latest'
        configuration: {
          url: '${stg.properties.primaryEndpoints.blob}${containerName}/Cluster_CreateFirstNodeOfAFailoverClusterConfig.ps1.zip'
          script: 'Cluster_CreateFirstNodeOfAFailoverClusterConfig.ps1'
          function: 'Cluster_CreateFirstNodeOfAFailoverClusterConfig'
        }
        configurationArguments: {
          clustername: clustername
          staticIPAddress: staticIPAddress
          domainName: domainName
        }
      }
      protectedSettings: {
        configurationUrlSasToken: '?${_artifactsLocationSasToken}'
        configurationArguments: {
          adminCreds: {
            userName: adminUsername
            password: adminPassword
          }
        }
      }
    }
  }
    