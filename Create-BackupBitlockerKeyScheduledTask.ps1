Start-Transcript -Path "C:\Windows\Logs\Create-BackupBitlockerKeyScheduledTask.log"

$File = "Backup-BitlockerKeyAD.ps1"
$Folder = "C:\Updates\Bitlocker"
$ScriptPath = "$Folder\$File"
$TaskName = "Backup Bitlocker Key to AD"
$ScriptyDoodle = @'
Start-Transcript -Path "C:\Windows\Logs\Bitlocker\BackupBitlockerKey.log"

$blv = Get-BitlockerVolume -MountPoint "C:"
    
$RecoveryGUID = $blv.keyprotector | Where-Object{$_.keyprotectortype -eq 'recoverypassword'} | Select-Object -expandproperty keyprotectorid
    
$RecoveryPassword = $blv.keyprotector | Where-Object{$_.keyprotectortype -eq 'recoverypassword'} | Select-Object -expandproperty RecoveryPassword

Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $RecoveryGUID

Stop-Transcript

Exit 0
'@


#Test Path for Folder
if(!(Test-Path -Path $Folder)){
  New-Item -Path $Folder -ItemType Directory -Force
}

$ScriptyDoodle | Out-File -FilePath $ScriptPath -Verbose -Force



#https://stackoverflow.com/questions/42801733/creating-a-scheduled-task-which-uses-a-specific-event-log-entry-as-a-trigger

$Action = New-ScheduledTaskAction  -Execute 'Powershell.exe' -Argument "-ExecutionPolicy Bypass -File $ScriptPath"

$CIMTriggerClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler:MSFT_TaskEventTrigger
$Trigger = New-CimInstance -CimClass $CIMTriggerClass -ClientOnly
$Trigger.Subscription = 
@"
<QueryList><Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"><Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000]]</Select></Query></QueryList>
"@
$Trigger.Enabled = $True 
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -NetworkName "cdhs.state.co.us" -AllowStartIfOnBatteries

Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName $TaskName -Principal $principal -Settings $settings -Force
Start-ScheduledTask -TaskName $TaskName -Verbose


Stop-Transcript