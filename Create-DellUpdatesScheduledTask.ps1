Start-Transcript -Path "C:\Windows\Logs\Create-DellDriverBIOS_ScheduledTask.log"

$File = "Update-DellDriversBIOS.ps1"
$Folder = "C:\Updates\Dell"
$ScriptPath = "$Folder\$File"
$TaskName = "Update-DellDriversBIOS"
$ScriptyDoodle = @'
$DellPath = 'C:\updates\Dell'

##Run Dell Command Update
Show-InstallationProgress -StatusMessage 'Now running Dell Command Update'
if(Test-Path -Path "${env:ProgramFiles(x86)}\Dell\CommandUpdate"){
	$DellInstallPath = "${env:ProgramFiles(x86)}\Dell\CommandUpdate"
} else {
	$DellInstallPath = "$env:ProgramFiles\Dell\CommandUpdate"
}
		
$updateType = 'driver,firmware,bios'
$updateSeverity = 'security,critical,recommended'

While((Test-Path -Path "$DellInstallPath\dcu-cli.exe") -eq $False){
	Start-Sleep -Seconds 15
}

Start-Process -FilePath "$DellInstallPath\dcu-cli.exe" -ArgumentList "/configure -downloadLocation=`"$DellPath\Downloads`" -updateType=`"$updatetype`" -updateSeverity=`"$updateSeverity`" -autoSuspendBitlocker=enable -outputlog=`"$DellPath\Logs\Config.log`"" -wait
Start-Process -FilePath "$DellInstallPath\dcu-cli.exe" -ArgumentList "/scan -report=`"$DellPath\Logs\Report`" -outputLog=`"$DellPath\Logs\Scan.log`" -updatetype=`"$updateType`"" -wait
Start-Process -FilePath "$DellInstallPath\dcu-cli.exe" -ArgumentList "/DriverInstall -outputlog=`"$DellPath\Logs\DriverInstall.log`" -reboot=enable -silent" -wait
Start-Process -FilePath "$DellInstallPath\dcu-cli.exe" -ArgumentList "/ApplyUpdates -outputLog=`"$DellPath\Logs\ApplyUpdates.log`" -updateType=`"$updateType`" -updateSeverity=`"$updateSeverity`" -autoSuspendBitlocker=enable -reboot=enable" -wait
'@

#Creates the Folder if the Folder doesn't exist
if(!(Test-Path -Path $Folder)){
  New-Item -Path $Folder -ItemType Directory -Force
}

#Creates the PS1 File for the Scheduled task to Call
$ScriptyDoodle | Out-File -FilePath $ScriptPath -Verbose -Force

#Test if Task exists, if so, unregister existing.
$Task = Get-ScheduledTask -TaskName $TaskName
if($null -ne $Task){
  $Task | Unregister-ScheduledTask -Force  
}


#https://stackoverflow.com/questions/42801733/creating-a-scheduled-task-which-uses-a-specific-event-log-entry-as-a-trigger

$Action = New-ScheduledTaskAction  -Execute 'Powershell.exe' -Argument "-ExecutionPolicy Bypass -File $ScriptPath"
$Trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 2 -At 6:00AM  -DaysOfWeek Wednesday
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries

Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName $TaskName -Principal $principal -Settings $settings -Force
Start-ScheduledTask -TaskName $TaskName -Verbose

Stop-Transcript