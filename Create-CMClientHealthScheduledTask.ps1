Start-Transcript -Path "C:\Windows\Logs\Create-CMClientHealthScheduledTask.log"

$File = "\\hseftn226\ccmsetup$\ConfigMgrClientHealth.ps1"
$Config = "\\hseftn226\ccmsetup$\config.xml"
$TaskName = "CMClientHealth"

$Action = New-ScheduledTaskAction  -Execute 'Powershell.exe' -Argument "-ExecutionPolicy Bypass -File $File -Config $Config"

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