@description('Azure Region for the deployment')
param location string = resourceGroup().location

param adminusername string = 'reallysecureadmin'
@secure()
param adminpassword string = ''

@description('name of the veeam virtual machine')
param VMName string = 'Veeam'

@description('Name and IP address range of the Virtual Network')
param VNETName string = 'VeeamBR-VNET-01'
param VNetAddress string = '10.0.0.0/22'

@description('Name and IP address range of the Subnet 1')
param SNET1Name string = 'VeeamBR-SNET-01'
param SNet1Address string = '10.0.1.0/24'

@description('Size of the Veeam VM')
@allowed([
  'Standard_B1ms'
  'Standard_B4ms'
  'Standard_D1_v2'
  'Standard_D4s_v3'
])
param VMSize string = 'Standard_D1_v2'

@description(' Link to external script to configure the virtual machine')
param fileurl string = 'https://raw.githubusercontent.com/nate8523/Cloud-Templates/main/Azure/QD-Bicep-Veeam-v11-BR/Customise-Veeam-Backup.ps1'

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-07-01' = {
  name: '${VMName}-NSG-01'
  location: location
  properties: {
    securityRules: [
      {
        name: 'CloudConnect-TCP'
        properties: {
          protocol: 'Tcp'
          priority: 1010
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '6180'
      }
    }
    {
      name: 'CloudConnect-UDP'
      properties: {
        protocol: 'UDP'
        priority: 1011
        access: 'Allow'
        direction: 'Inbound'
        sourceAddressPrefix: '*'
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '6180'
    }
  }
  {
    name: 'Allow-Inbound-RDP'
    properties: {
      protocol: 'Tcp'
      priority: 1012
      access: 'Allow'
      direction: 'Inbound'
      sourceAddressPrefix: '*'
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '3389'
  }
}
    ]
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
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
}
}

resource publicIpAddressName 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: '${VMName}-PIP-External-01'
  location: location
  properties: {
    publicIPAllocationMethod: 'Static'
    }
    sku: {
      name: 'Basic'
  }
}

resource networkInterfaceName 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${VMName}-NIC-01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${virtualNetworkName.id}/subnets/${SNET1Name}'
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddressName.id
          }
        }      
      }
    ]
  }
}

resource virtualmachine 'Microsoft.Compute/virtualMachines@2022-08-01' ={
  name: VMName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: VMSize
    }
    storageProfile: {
      osDisk: {
        name: '${VMName}-OSDisk-01'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: {
        publisher: 'veeam'
        offer: 'veeam-backup-replication'
        sku: 'veeam-backup-replication-v11'
        version: 'latest'
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
          id: networkInterfaceName.id
          properties: {
          }
        }
      ]
    }
    osProfile: {
      computerName: VMName
      adminUsername: adminusername
      adminPassword: adminpassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          enableHotpatching: false
          patchMode: 'AutomaticByOS'
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  plan: {
    name: 'veeam-backup-replication-v11'
    publisher: 'veeam'
    product: 'veeam-backup-replication'
  }
}

resource customscriptextension 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: virtualmachine
  name: 'VeeamDataDisk'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        fileurl
      ]
      commandToExecute: 'powershell -ExecutionPolicy Bypass -File Customise-Veeam-Backup.ps1'
    }
}
}
