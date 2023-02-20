@description('Azure Region for the deployment')
param location string = resourceGroup().location

param adminusername string = 'reallysecureadmin'
@secure()
param adminpassword string = ''

@description(' Tags will be added to all resources deployed')
var tagValues = {
  createdBy: 'UserName'
  environment: 'Dev/Test'
}

@description(' Configuration detials of the VM Diagnostics storage account')
param VMDiagStoreName string = 'VMDiagStore${VMName}'
param VMDiagStoreKind string = 'Storage'
param VMDiagStoreSKU string = 'Standard_LRS'

@description('Name and IP address range of the Virtual Network')
param VNETName string = 'ADDS-VNET-01'
param VNetAddress string = '10.0.0.0/22'

@description('Name and IP address range of the Subnet 1')
param SNET1Name string = 'ADDS-SNET-01'
param SNet1Address string = '10.0.1.0/24'

@description('name of the veeam virtual machine')
param VMName string = 'ADDS01'

@description('Name of the Availability Set for the virtual machine')
param AvailabilitySetName string = 'ADDS-AVSET-01'

@description('Size of the ADDS VM')
@allowed([
  'Standard_B1ms'
  'Standard_B4ms'
  'Standard_D1_v2'
  'Standard_D4s_v3'
])
param VMSize string = 'Standard_D1_v2'

@description('Operating system version of the ADDS VMs')
@allowed([
  '2016-Datacenter'
  '2019-Datacenter'
  '2022-datacenter'
])
param OSVersion string = '2022-datacenter'

@description('SKU of the OS and Data Disks')
param OSDiskStorage string = 'Standard_LRS'

param DomainName string = 'domain.co.uk'

resource VMDiagStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: toLower(VMDiagStoreName)
  location: location
  tags: tagValues
  kind: VMDiagStoreKind
  sku: {
    name: VMDiagStoreSKU
  }
}

resource virtualNetworkName 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: VNETName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        VNetAddress        
      ]
    }
    subnets: [
      {
        name: SNET1Name
        properties: {
          addressPrefix: SNet1Address
        }
      }
    ]
}
}

resource VMNic 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${VMName}-NIC-01'
  location: location
  tags:tagValues
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${virtualNetworkName.id}/subnets/${SNET1Name}'
          }
        }
      }
    ]
  }
}

resource availabilitySet 'Microsoft.Compute/availabilitySets@2019-03-01' = {
  location: location
  name: AvailabilitySetName
  properties: {
    platformUpdateDomainCount: 20
    platformFaultDomainCount: 2
  }
  sku: {
    name: 'Aligned'
  }
}

resource VirtualMachine 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: VMName
  location: location
  properties: {
    osProfile: {
      computerName: VMName
      adminUsername: adminusername
      adminPassword: adminpassword
      windowsConfiguration: {
        provisionVMAgent: true
      }
    }
    hardwareProfile: {
      vmSize: VMSize
    }
    availabilitySet: {
      id: availabilitySet.id
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: OSVersion
        version: 'latest'
      }
      osDisk: {
        name: '${VMName}-OSDisk-01'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: OSDiskStorage
        }
      }
      dataDisks: [
        {
          diskSizeGB: 32
          lun: 0
          createOption: 'Empty'
          name: '${VMName}-DataDisk-01'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          properties: {
            primary: true
          }
          id: VMNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: VMDiagStorage.properties.primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    virtualNetworkName
  ]
}

resource PrimaryADDSVM 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: VirtualMachine
  name: 'CreateADForest'
  location: location
  tags: tagValues
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.19'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: 'https://raw.githubusercontent.com/nate8523/Cloud-Templates/main/Azure/QD-Bicep-ADDS-SingleVM/DSC/CreateADPrimaryDC.zip'
      ConfigurationFunction: 'CreateADPrimaryDC.ps1\\CreateADPrimaryDC'
      Properties: {
        DomainName: DomainName
        AdminCredentials: {
          UserName: adminusername
          Password: 'PrivateSettingsRef:AdminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
        AdminPassword: adminpassword
      }
    }
  }
}

resource vnetDns 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: VNETName
  properties: {
    dhcpOptions: {
      dnsServers: [
        '8.8.8.8'
      ]
    }
  }
  dependsOn: [
    PrimaryADDSVM
  ]
}
