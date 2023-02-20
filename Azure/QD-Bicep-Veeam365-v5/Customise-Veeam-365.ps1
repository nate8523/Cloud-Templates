# Veeam Deploy
initialize-Disk -Number 2 -PartitionStyle GPT
Get-Disk -Number 2 | New-Volume -Filesystem ReFS -DriveLetter F -AllocationUnitSize 64KB -FriendlyName "Veeam365 Backups"
Add-VBRBackupRepository -Name "Local Backups" -Folder "F:\" -Type WinLocal