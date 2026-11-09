# 부팅 시 render_once.ps1 가 자동 실행되도록 작업 스케줄러에 등록.
# 관리자 PowerShell 에서 1회:  powershell -ExecutionPolicy Bypass -File install_task.ps1
$ErrorActionPreference = "Stop"
$Base = "C:\mruntold"
$script = "$Base\day1-excel-webapp\youtube-auto\local-render\render_once.ps1"

$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
           -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = "PT3M"     # 부팅 3분 뒤 (드라이버·네트워크 준비 시간)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask -TaskName "MrUntold-LocalRender" -Action $action -Trigger $trigger `
  -Principal $principal -Settings $settings -Force

Write-Host "등록 완료: 'MrUntold-LocalRender' (부팅 3분 뒤 자동 렌더)." -ForegroundColor Green
Write-Host "지금 한번 수동 테스트:  powershell -ExecutionPolicy Bypass -File `"$Base\day1-excel-webapp\youtube-auto\local-render\render_once.ps1`""
Write-Host "(테스트 중 자동 종료를 막으려면 렌더 끝나기 전에 다른 창에서  shutdown /a )"
