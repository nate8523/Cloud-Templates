param location string
param virtualNetworkName string
param virtualNetworkAddress string
param subnetName string
param subnetAddress string
param dnsServerIPAddress array
param tagValues object

// Deploy the virtual network and a default subnet
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: virtualNetworkName
  location: location
  tags: tagValues
  properties: {
    addressSpace: {
      addressPrefixes: [
        virtualNetworkAddress
      ]
    }
    dhcpOptions: {
      dnsServers: ((!empty(dnsServerIPAddress)) ? array(dnsServerIPAddress) : json('null'))
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddress
        }
      }
    ]
  }
}

output virtualNetworkId string = vnet.id
output virtualSubnetName string = subnetName
output subnetId string = vnet.properties.subnets[0].id

