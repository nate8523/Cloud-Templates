<#
.SYNOPSIS
  Script Name:      Deploy-AzureBackup.ps1
  Script Summary:   This script is used to provision an Azure Backup Repository

.DESCRIPTION
  The script Provisons the following Resources:
    * A New Resource Group for the deployment
    * A Recovery Services Vault

.DISCLAIMER
  This script is provided AS IS without warranty of any kind. In no event shall its author, or anyone else involved in the creation, 
  production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of 
  business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or 
  inability to use the scripts or documentation, even if the author has been advised of the possibility of such damages. 

.NOTES
  Version:        1.0
  Author:         Nathan Carroll
  Creation Date:  06 May 2021
  Purpose/Change: Initial script development
  
.EXAMPLE

#>

#-------------------- [ Variables ] -----------------------
$Location = 'Uk South'
$ResourceGroupName = 'Azure-BackupVault-01'

# Get Date and Time format
$date = Get-Date -Format "dd-MM-yyyy"

$DeploymentName = "Azure-BackupVault-"+"$date"

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

# Create Resource Group
Write-Host ""
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; Write-Host "Creating Azure Resource Group..."
New-AzResourceGroup `
    -Name $ResourceGroupName `
    -Location $Location | Out-Null

# Deploy Azure Backup Solution
Write-Host ""
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; Write-Host "Deploying Solution to Azure..."
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; Write-Host "This may take around 10 minutes to complete..."
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; Write-Host "The deployment Status can be monitored in the Azure Portal..."
New-AzResourceGroupDeployment `
    -Name $DeploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile .\main.bicep | Out-Null

    