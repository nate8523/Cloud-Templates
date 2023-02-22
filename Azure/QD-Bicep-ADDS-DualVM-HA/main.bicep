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
param virtualNetworkName string = 'ADDS-VNET-01'
param virtualNetworkAddress string = '10.0.0.0/22'

@description('Name and IP address range of the Subnet 1')
param subnetName string = 'ADDS-SNET-01'
param subnetAddress string = '10.0.1.0/24'

@description('Prefix name of the ADDS virtual machine')
param VMName string = 'ADDS'

@description('Name of the Availability Set for the virtual machine')
param AvailabilitySetName string = 'ADDS-AVSET-01'

@description(' Number of Virtual Machines to be deployed')
param vmCount int = 2

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

@description('name of the new internal domain')
param DomainName string = 'domain.co.uk'

@description('IP Addresses of the initial DNS Servers')
var dnsServerIPAddress = [
  '8.8.8.8'
  '4.4.4.4'
]

@description('IP Addresses of the DNS Servers of the domain controllers')
var DomaindnsServerIPAddress = [
  '10.0.1.4'
  '10.0.1.5'
]

resource VMDiagStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: toLower(VMDiagStoreName)
  location: location
  tags: tagValues
  kind: VMDiagStoreKind
  sku: {
    name: VMDiagStoreSKU
  }
}

module virtualNetwork 'Modules/VirtualNetwork.bicep' ={
  name: 'VNET-Deploy'
    params: {
    location: location
    tagValues: tagValues
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddress: virtualNetworkAddress
    subnetName: subnetName
    subnetAddress: subnetAddress
    dnsServerIPAddress: dnsServerIPAddress
  }
}

resource VMNic 'Microsoft.Network/networkInterfaces@2022-07-01' = [for i in range (01, vmCount): {
  name: '${VMName}${i}-NIC-01'
  location: location
  tags:tagValues
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${virtualNetwork.outputs.virtualNetworkId}/subnets/${virtualNetwork.outputs.virtualSubnetName}'
          }
        }
      }
    ]
  }
}]

resource availabilitySet 'Microsoft.Compute/availabilitySets@2019-03-01' = {
  location: location
  name: AvailabilitySetName
  tags: tagValues
  properties: {
    platformUpdateDomainCount: 20
    platformFaultDomainCount: 2
  }
  sku: {
    name: 'Aligned'
  }
}

resource VirtualMachine 'Microsoft.Compute/virtualMachines@2022-08-01' = [for i in range(01, vmCount): {
  name: '${VMName}${i}'
  location: location
  tags: tagValues
  properties: {
    osProfile: {
      computerName: '${VMName}${i}'
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
        name: '${VMName}${i}-OSDisk-01'
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
          name: '${VMName}${i}-DataDisk-01'
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
          id: resourceId('Microsoft.Network/networkInterfaces', '${VMName}${i}-NIC-01')
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
    virtualNetwork
  ]
}]

resource PrimaryADDSVM 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: '${VMName}1/Configure-Primary-DC'
  location: location
  tags: tagValues
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.19'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: 'https://raw.githubusercontent.com/nate8523/Cloud-Templates/main/Azure/QD-Bicep-ADDS-DualVM-HA/DSC/CreateADPrimaryDC.zip'
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
  dependsOn: [
    VirtualMachine
  ]
}

module UpdateVNetDNS 'Modules/VirtualNetwork.bicep' = {
  name: 'UpdateVNetDNS'
  params: {
    tagValues: tagValues
    virtualNetworkName: virtualNetworkName
    virtualNetworkAddress: virtualNetworkAddress
    subnetName: subnetName
    subnetAddress: subnetAddress
    dnsServerIPAddress: DomaindnsServerIPAddress
    location: location
  }
  dependsOn: [
    PrimaryADDSVM
  ]
}

resource AdditionalADDSVM 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: '${VMName}2/Configure-Additional-DC'
  location: location
  tags: tagValues
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.19'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: 'https://raw.githubusercontent.com/nate8523/Cloud-Templates/main/Azure/QD-Bicep-ADDS-DualVM-HA/DSC/CreateADAdditionalDC.zip'
      ConfigurationFunction: 'CreateADAdditionalDC.ps1\\CreateADAdditionalDC'
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
  dependsOn: [
    UpdateVNetDNS
  ]
}
