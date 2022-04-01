Start-Transcript -Path "C:\Windows\Logs\Create-SCCMActionsScheduledTask.log"

$File = "Run-SCCMActions5x.ps1"
$Folder = "C:\Updates\SCCM"
$ScriptPath = "$Folder\$File"
$TaskName = "Run-SCCMActions5x"
$ScriptyDoodle = @'
Function Run-SCCMClientAction {
  [CmdletBinding()]
          
  # Parameters used in this function
  param
  ( 
      [Parameter(Position=0, Mandatory = $True, HelpMessage="Provide server names", ValueFromPipeline = $true)] 
      #[string[]]$Computername,

     [ValidateSet('MachinePolicy', 
                  'DiscoveryData', 
                  'ComplianceEvaluation', 
                  'AppDeployment',  
                  'HardwareInventory', 
                  'UpdateDeployment', 
                  'UpdateScan', 
                  'SoftwareInventory')] 
      [string[]]$ClientAction

  ) 
  $ActionResults = @()
  Try { 
          $ActionResults = Invoke-Command {param($ClientAction)

                  Foreach ($Item in $ClientAction) {
                      $Object = @{} | select "Action name",Status
                      Try{
                          $ScheduleIDMappings = @{ 
                              'MachinePolicy'        = '{00000000-0000-0000-0000-000000000021}'; 
                              'DiscoveryData'        = '{00000000-0000-0000-0000-000000000003}'; 
                              'ComplianceEvaluation' = '{00000000-0000-0000-0000-000000000071}'; 
                              'AppDeployment'        = '{00000000-0000-0000-0000-000000000121}'; 
                              'HardwareInventory'    = '{00000000-0000-0000-0000-000000000001}'; 
                              'UpdateDeployment'     = '{00000000-0000-0000-0000-000000000108}'; 
                              'UpdateScan'           = '{00000000-0000-0000-0000-000000000113}'; 
                              'SoftwareInventory'    = '{00000000-0000-0000-0000-000000000002}'; 
                          }
                          $ScheduleID = $ScheduleIDMappings[$item]
                          Write-Verbose "Processing $Item - $ScheduleID"
                          [void]([wmiclass] "root\ccm:SMS_Client").TriggerSchedule($ScheduleID);
                          $Status = "Success"
                          Write-Verbose "Operation status - $status"
                      }
                      Catch{
                          $Status = "Failed"
                          Write-Verbose "Operation status - $status"
                      }
                      $Object."Action name" = $item
                      $Object.Status = $Status
                      $Object
                  }

      } -ArgumentList $ClientAction -ErrorAction Stop | Select-Object @{n='ServerName';e={$_.pscomputername}},"Action name",Status
  }  
  Catch{
      Write-Error $_.Exception.Message 
  }   
  Return $ActionResults           
}

$Count = 0
While($Count -lt 6){
Run-SCCMClientAction -ClientAction AppDeployment
Run-SCCMClientAction -ClientAction MachinePolicy
Run-SCCMClientAction -ClientAction DiscoveryData
Run-SCCMClientAction -ClientAction ComplianceEvaluation
Run-SCCMClientAction -ClientAction HardwareInventory
Run-SCCMClientAction -ClientAction UpdateDeployment
Run-SCCMClientAction -ClientAction UpdateScan
Run-SCCMClientAction -ClientAction SoftwareInventory
Write-Output "Actions have run $Count times."
$Count ++
}
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