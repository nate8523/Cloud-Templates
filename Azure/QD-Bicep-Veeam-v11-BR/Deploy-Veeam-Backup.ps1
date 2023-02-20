<#
.SYNOPSIS
  Script Name:      Deploy-Veeam-Backup.ps1
  Script Summary:   This script is used to provision a Veeam backup server in Azure 

.DESCRIPTION
  The script Provisons the follwoing Resources:
    * A New Resource Group for the deployment
    * A Virtual Network and 1 Subnets
    * A virtual Machine with one NIC
    * Veeam Backup and Replication Installed
    * Additional Data disk attached to the VM and Mounted as a Veeam Storage Repository

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
$ResourceGroupName = 'Veeam-BR-02'

$DeploymentName = "VeeamBRv2-"+"$date"

$ImagePublisher = 'Veeam'
$ImageName = 'veeam-backup-replication'
$ImageSKU = 'veeam-backup-replication-v11'
$ImageOffer = 'virtualmachine'

#-------------------- [ Script Body ] -----------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

# Get Date and Time format
$date = Get-Date -Format "dd-MM-yyyy"

# Connect to Azure
Write-Host "Initializing... " -ForegroundColor Yellow -NoNewline; Write-Host "Connecting to Azure Account..."
Connect-AzAccount

# List and Select Subscriptions
Write-Host "Initializing... " -ForegroundColor Yellow -NoNewline; Write-Host "Listing available Subscriptions.."
$Subscription = Get-AzSubscription | Out-GridView -title "Select Azure Subscription ..." -PassThru
Set-AzContext -SubscriptionId $Subscription.Id

# Get Latest Veeam Version
Write-Host ""
Write-Host "Initializing... " -ForegroundColor Yellow -NoNewline; Write-Host "Getting Veeam Images..."
$VMVersion = Get-AzVMImage `
    -location $Location `
    -PublisherName $ImagePublisher `
    -Offer $ImageName `
    -Skus $ImageSKU | Format-Table -Property Version -HideTableHeaders | Out-String
    Write-Host "Status Update... " -ForegroundColor Yellow -NoNewline; Write-Host "Veeam "$VMVersion.trim() "will be installed" 
Write-Host ""

# Prompt to continue install
Function ScriptContinue {
    $UserInput = Read-Host -Prompt "Do you wish to continue.. [Y/N]?"
    switch ($UserInput) {
        'Y' {
            Write-Host ""
            Write-Host "Status Update... " -ForegroundColor Yellow -NoNewline; Write-host "Deployment Starting... "
            Write-Host ""
          }
        'N' {
            Write-Host ""
            Write-Host "Exiting Script... " -ForegroundColor DarkCyan
            Write-Host ""
          Exit
        }
        Default {
          Write-Warning "Please only enter Y or N"
          ScriptContinue
        }
      }
    }
    ScriptContinue
    
# Marketplace Terms
# Get Marketplace Terms and accept
Write-Host "Status Update... " -ForegroundColor Yellow -NoNewline; Write-Host "Retrieving Marketplace Terms for Image..."
Write-Host "Status Update... " -ForegroundColor Yellow -NoNewline; Write-Host "Accepting Marketplace Terms for Image..."
Get-AzMarketplaceTerms `
        -Publisher $ImagePublisher `
        -Product $ImageName `
        -Name $ImageSKU `
        -OfferType $ImageOffer | Set-AzMarketplaceTerms -Accept | Out-Null
    
# Create Resource Group
Write-Host ""
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; Write-Host "Creating Azure Resource Group..."
New-AzResourceGroup `
        -Name $ResourceGroupName `
        -Location $Location | Out-Null
    
# Get password input 
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; 
$adminpassword = Read-Host "Enter Password for Local Administrator.." -AsSecureString
    
# Deploy Veeam BR
Write-Host ""
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; Write-Host "Deploying Solution to Azure..."
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; Write-Host "This may take around 6 minutes to complete..."
Write-Host "Deploying... " -ForegroundColor Blue -NoNewline; Write-Host "The deployment Status can be monitored in the Azure Portal..."
New-AzResourceGroupDeployment `
        -Name $DeploymentName `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile .\main.bicep -adminpassword $adminpassword | Out-Null