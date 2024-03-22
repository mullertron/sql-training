//Creates a domain controller and 2 sql servers

@description('Admin username')
param adminUsername string 

@description('Admin password')
@secure()
param adminPassword string 

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Size of the virtual machines')
param vmSize string = 'Standard_D2s_v3'

@description('Name for the Public IP used to access the Virtual Machine.')
param publicIpName string = 'test-sql01-pub-ip'

@description('Allocation method for the Public IP used to access the Virtual Machine.')
@allowed([
  'Dynamic'
  'Static'
])
param publicIPAllocationMethod string = 'Dynamic'

@description('SKU for the Public IP used to access the Virtual Machine.')
@allowed([
  'Basic'
  'Standard'
])
param publicIpSku string = 'Basic'

@description('Get the current time to create a SAS Token')
param baseTime string = utcNow('u')

//VM Name 1
@description('The name of the VM')
param virtualSQLMachineName1 string = 'test-sql01'

//VM Name 2
@description('The name of the VM')
param virtualSQLMachineName2 string = 'test-sql02'

@description('Windows Server and SQL Offer')
@allowed([
  'sql2019-ws2019'
  'sql2017-ws2019'
  'sql2019-ws2022'
  'SQL2016SP1-WS2016'
  'SQL2016SP2-WS2016'
  'SQL2014SP3-WS2012R2'
  'SQL2014SP2-WS2012R2'
])
param imageOffer string = 'sql2019-ws2022'

@description('SQL Server Sku')
@allowed([
  'standard-gen2'
  'enterprise-gen2'
  'SQLDEV-gen2'
  'web-gen2'
  'enterprisedbengineonly-gen2'
])
param sqlSku string = 'standard-gen2'

@description('SQL Server Workload Type')
@allowed([
  'General'
  'OLTP'
  'DW'
])
param storageWorkloadType string = 'General'

@description('Amount of data disks (1TB each) for SQL Data files')
@minValue(1)
@maxValue(8)
param sqlDataDisksCount int = 1

@description('Path for SQL Data files. Please choose drive letter from F to Z, and other drives from A to E are reserved for system')
param dataPath string = 'F:\\SQLData'

@description('Amount of data disks (1TB each) for SQL Log files')
@minValue(1)
@maxValue(8)
param sqlLogDisksCount int = 1

@description('Path for SQL Log files. Please choose drive letter from F to Z and different than the one used for SQL data. Drive letter from A to E are reserved for system')
param logPath string = 'G:\\SQLLog'


@description('Security Type of the Virtual Machine.')
@allowed([
  'Standard'
  'TrustedLaunch'
])
param securityType string = 'TrustedLaunch'

var securityProfileJson = {
  uefiSettings: {
    secureBootEnabled: true
    vTpmEnabled: true
  }
  securityType: securityType
}

var storageAccountType = 'Standard_LRS'
var storageAccountName = uniqueString(resourceGroup().id)
var virtualNetworkName = 'sql-training-vnet'
var virtualNetworkAddressRange = '10.0.0.0/16'
var dataSubnetName = 'data-sn'
var infraSubnetName = 'infra-sn'
var vmName = 'test-dom01'
var networkInterfaceNameDC = 'test-dom01-nic'
var networkSecurityGroupName = 'data-nsg'
var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, infraSubnetName)
var dataSubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, dataSubnetName)
var domainName = 'muldown.local'
var installStorageAccountName = 'mulsttorage'
var containerName = 'build-dc'
var infraSubnetRange = '10.0.1.0/24'
var dataSubnetRange = '10.0.2.0/24'
// SQL Server Variables
//var virtualSQLMachineName1 = 'test-sql01'
//var virtualSQLMachineName2 = 'test-sql02'
var networkInterfaceNameSQL01 = 'test-SQL01-nic'
var networkInterfaceNameSQL02 = 'test-SQL02-nic'
var publicIpAddressNameSQLVM1 = '${virtualSQLMachineName1}-publicip'
var publicIpAddressNameSQLVM2 = '${virtualSQLMachineName2}-publicip'
//var publicIpAddressType = 'Dynamic'
//var publicIpAddressSku = 'Basic'
var diskConfigurationType = 'NEW'
var dataDisksLuns = range(0, sqlDataDisksCount)
var logDisksLuns = range(sqlDataDisksCount, sqlLogDisksCount)
var dataDisks = {
  createOption: 'Empty'
  caching: 'ReadOnly'
  writeAcceleratorEnabled: false
  storageAccountType: 'Premium_LRS'
  diskSizeGB: 16
}
var tempDbPath = 'D:\\SQLTemp'
/*
Not required
var extensionName = 'GuestAttestation'
var extensionPublisher = 'Microsoft.Azure.Security.WindowsAttestation'
var extensionVersion = '1.0'
var maaTenantName = 'GuestAttestation'
*/




@description('Existing storage account which has the DSC Files')
resource stg 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: installStorageAccountName 
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
  }
}

resource publicIp2 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: publicIpAddressNameSQLVM1
  location: location
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
  }
}

resource publicIp3 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: publicIpAddressNameSQLVM2
  location: location
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-05-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: [
      {
        name: 'default-allow-3389'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '3389'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}


resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddressRange
      ]
    }
    subnets: [
      {
        name: infraSubnetName
        properties: {
          addressPrefix: infraSubnetRange
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
      {
        name: dataSubnetName
        properties: {
          addressPrefix: dataSubnetRange
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource networkInterfaceDC 'Microsoft.Network/networkInterfaces@2021-05-01' =  {
  name: networkInterfaceNameDC
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: subnetRef
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource networkInterfaceSQL01 'Microsoft.Network/networkInterfaces@2021-05-01' =  {
  name: networkInterfaceNameSQL01
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp2.id
          }
          subnet: {
            id: dataSubnetRef
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource networkInterfaceSQL02 'Microsoft.Network/networkInterfaces@2021-05-01' =  {
  name: networkInterfaceNameSQL02
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp3.id
          }
          subnet: {
            id: dataSubnetRef
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

//Domain Controller
resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' =  {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
      dataDisks: [
        {
          diskSizeGB: 64
          lun: 0
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
        {
          diskSizeGB: 32
          lun: 1
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceDC.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}

//sql01
resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: virtualSQLMachineName1
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      dataDisks: [for j in range(0, length(range(0, (sqlDataDisksCount + sqlLogDisksCount)))): {
        lun: range(0, (sqlDataDisksCount + sqlLogDisksCount))[j]
        createOption: dataDisks.createOption
        caching: ((range(0, (sqlDataDisksCount + sqlLogDisksCount))[j] >= sqlDataDisksCount) ? 'None' : dataDisks.caching)
        writeAcceleratorEnabled: dataDisks.writeAcceleratorEnabled
        diskSizeGB: dataDisks.diskSizeGB
        managedDisk: {
          storageAccountType: dataDisks.storageAccountType
        }
      }]
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftSQLServer'
        offer: imageOffer
        sku: sqlSku
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceSQL01.id
        }
      ]
    }
    osProfile: {
      computerName: virtualSQLMachineName1
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    securityProfile: ((securityType == 'TrustedLaunch') ? securityProfileJson : null)
  }
}
   
//sql02
resource virtualMachine2 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: virtualSQLMachineName2
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      dataDisks: [for j in range(0, length(range(0, (sqlDataDisksCount + sqlLogDisksCount)))): {
        lun: range(0, (sqlDataDisksCount + sqlLogDisksCount))[j]
        createOption: dataDisks.createOption
        caching: ((range(0, (sqlDataDisksCount + sqlLogDisksCount))[j] >= sqlDataDisksCount) ? 'None' : dataDisks.caching)
        writeAcceleratorEnabled: dataDisks.writeAcceleratorEnabled
        diskSizeGB: dataDisks.diskSizeGB
        managedDisk: {
          storageAccountType: dataDisks.storageAccountType
        }
      }]
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftSQLServer'
        offer: imageOffer
        sku: sqlSku
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceSQL02.id
        }
      ]
    }
    osProfile: {
      computerName: virtualSQLMachineName2
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    securityProfile: ((securityType == 'TrustedLaunch') ? securityProfileJson : null)
  }
}

//SQL Virtaul Machine1
resource Microsoft_SqlVirtualMachine_sqlVirtualMachines_virtualMachine 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2022-07-01-preview' = {
  name: virtualSQLMachineName1
  location: location
  properties: {
    virtualMachineResourceId: virtualMachine.id
    sqlManagement: 'Full'
    sqlServerLicenseType: 'PAYG'
    storageConfigurationSettings: {
      diskConfigurationType: diskConfigurationType
      storageWorkloadType: storageWorkloadType
      sqlDataSettings: {
        luns: dataDisksLuns
        defaultFilePath: dataPath
      }
      sqlLogSettings: {
        luns: logDisksLuns
        defaultFilePath: logPath
      }
      sqlTempDbSettings: {
        defaultFilePath: tempDbPath
      }
    }
  }
}

//SQL Virtaul Machine1
resource Microsoft_SqlVirtualMachine_sqlVirtualMachines_virtualMachine2 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2022-07-01-preview' = {
  name: virtualSQLMachineName2
  location: location
  properties: {
    virtualMachineResourceId: virtualMachine2.id
    sqlManagement: 'Full'
    sqlServerLicenseType: 'PAYG'
    storageConfigurationSettings: {
      diskConfigurationType: diskConfigurationType
      storageWorkloadType: storageWorkloadType
      sqlDataSettings: {
        luns: dataDisksLuns
        defaultFilePath: dataPath
      }
      sqlLogSettings: {
        luns: logDisksLuns
        defaultFilePath: logPath
      }
      sqlTempDbSettings: {
        defaultFilePath: tempDbPath
      }
    }
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
resource dscExtension 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = {
  location: location
  parent: vm
  name: 'Microsoft.Powershell.DSC'
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: '${stg.properties.primaryEndpoints.blob}${containerName}/CreateADPDC.ps1.zip'
        script: 'CreateADPDC.ps1'
        function: 'CreateADPDC'
      }
      configurationArguments: {
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

/*
module UpdateVNetDNS2 './nestedtemplates/vnet.bicep' = {
  name: 'UpdateVNetDNS2'
  params: {
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddressRange: virtualNetworkAddressRange
    subnetName: infraSubnetName 
    subnetRange: infraSubnetRange 
    DNSServerAddress: ['10.0.1.4']
    location: location
  }
  dependsOn: [
    dscExtension
  ]
}

resource dscExtensiondomjoin 'Microsoft.Compute/virtualMachines/extensions@2018-10-01' = {
  location: location
  parent: virtualMachine
  name: 'Microsoft.Powershell.DSC'
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.77'
    autoUpgradeMinorVersion: true
    settings: {
      wmfVersion: 'latest'
      configuration: {
        url: '${stg.properties.primaryEndpoints.blob}${containerName}/domainJoin.ps1.zip'
        script: 'domainJoin.ps1'
        function: 'domainJoin'
      }
      configurationArguments: {
        computername: virtualSQLMachineName1
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
  dependsOn: [
    UpdateVNetDNS2
  ]
}
EMD OF DELETION
*/




/*

*/
/*
Next Steps:
1. Create 2 new users for the domain, SQL Service and SQL Agent
2. Create the 2 SQL Servers
   a. Add to the domain
   b. Add the 2 Disks
   c. Copy over the SQL Install Media to the C drive
   d. Copy over the sqlconfiguration.ini file to the C Drive
   e. Install SQL 
   f. 

*/


/*
SQL Media SAS Token:
https://muldowninstallfiles.blob.core.windows.net/sqltraining/enu_sql_server_2022_enterprise_edition_x64_dvd_aa36de9e.iso?sp=r&st=2024-02-21T11:28:28Z&se=2024-03-09T19:28:28Z&spr=https&sv=2022-11-02&sr=b&sig=kJUsPWKQzZKVNwWIyUUuI66mN5Ormo39xG5iUJw%2BM6k%3D
https://muldowninstallfiles.blob.core.windows.net/sqltraining/SQLIaaS.reg?sp=r&st=2024-02-21T11:32:37Z&se=2024-03-09T19:32:37Z&spr=https&sv=2022-11-02&sr=b&sig=rFcMciE1CpGE4MnxnmU6UUWZ3bOvzzLqTSON7mWGwCo%3D

az login
az group create --name TestRG --location eastus
az deployment group create --resource-group domain-controller-temp --template-file dc-install.bicep
*/
