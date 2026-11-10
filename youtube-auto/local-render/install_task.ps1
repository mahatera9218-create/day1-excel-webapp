# Register a Task Scheduler job so render_once.ps1 runs at boot
# (smart plug powers the PC on -> this runs). Run once in ADMIN PowerShell:
#   powershell -ExecutionPolicy Bypass -File install_task.ps1
$ErrorActionPreference = "Stop"
$Base = "C:\mruntold"
$script = "$Base\day1-excel-webapp\youtube-auto\local-render\render_once.ps1"

$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
           -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = "PT3M"     # 3 min after boot (let drivers + network settle)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask -TaskName "MrUntold-LocalRender" -Action $action -Trigger $trigger `
  -Principal $principal -Settings $settings -Force

Write-Host "Registered task 'MrUntold-LocalRender' (runs 3 min after boot)." -ForegroundColor Green
Write-Host "Test it now:  powershell -ExecutionPolicy Bypass -File `"$script`""
Write-Host "(to stop the auto-shutdown during a test, run in another window:  shutdown /a )"
