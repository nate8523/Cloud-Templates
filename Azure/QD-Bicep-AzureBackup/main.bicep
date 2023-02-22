@description('Azure Region for the deployment')
param location string = resourceGroup().location

@description(' Tags will be added to all resources deployed')
var tagValues = {
  createdBy: 'UserName'
  environment: 'Dev/Test'
}

@description('Recovery Services vault name')
param RecoveryVaultName string = 'm247vault01'

@description('Storage replication type for Recovery Services vault')
@allowed([
  'LocallyRedundant'
  'GeoRedundant'
])
param StorageReplication string = 'LocallyRedundant'

param timeZone string = 'UTC'

//param BackupFrequency string = 'Daily'  //timezone and start time option
//param deployloganalytics string = 'Yes'  //region required
//Resource Group Name + Validadtion


resource recoveryServicesVault 'Microsoft.RecoveryServices/vaults@2023-01-01' = {
  name: RecoveryVaultName
  location: location
  tags: tagValues
  properties: {
    publicNetworkAccess: 'Disabled'
  }
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
}

resource recoveryServicesVault_StorageConfig 'Microsoft.RecoveryServices/vaults/backupstorageconfig@2023-01-01' = {
  parent: recoveryServicesVault
  name: 'vaultstorageconfig'
  properties: {
    storageModelType: StorageReplication
  }
}

resource backupPolicy_Daily 'Microsoft.RecoveryServices/vaults/backupPolicies@2016-06-01' = {
  parent: recoveryServicesVault
  name: 'daiily-recovery-policy'
  location: location
  properties: {
    backupManagementType: 'AzureIaasVM'
    instantRpRetentionRangeInDays: 2
    schedulePolicy: {
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        '19:00'
      ]
      schedulePolicyType: 'SimpleSchedulePolicy'
    }
    retentionPolicy: {
      dailySchedule: {
        retentionTimes: [
          '19:00'
        ]
        retentionDuration: {
          count: 7
          durationType: 'Days'
        }
      }
      retentionPolicyType: 'LongTermRetentionPolicy'
    }
    timeZone: timeZone
  }
}
//Advanced settings



//deploy now



