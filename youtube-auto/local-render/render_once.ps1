# Mr.Untold: 로컬에서 승인된 2편을 렌더·업로드하고 PC 를 끈다.
# 스마트플러그로 PC 가 켜지면 작업 스케줄러가 이걸 자동 실행한다(install_task.ps1).
$ErrorActionPreference = "Continue"
$Base  = "C:\mruntold"
$repo  = "$Base\day1-excel-webapp"
$comfy = "$Base\ComfyUI_windows_portable"
$log   = "$Base\render_last.log"
Start-Transcript -Path $log -Force | Out-Null

# 0) .env → 환경변수 + 이미지 엔진을 로컬(ComfyUI)로 전환 (클라우드는 안 건드림)
if (Test-Path "$repo\youtube-auto\.env") {
  Get-Content "$repo\youtube-auto\.env" | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {
      [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
    }
  }
}
$env:AUTOTUBE_IMAGE_ENGINE = "comfy"

# 1) 최신 코드/에피소드 받기
Set-Location $repo
git fetch origin main; git checkout main; git pull --ff-only

# 2) ComfyUI 백그라운드 기동
$proc = Start-Process -FilePath "$comfy\run_nvidia_gpu.bat" -WorkingDirectory $comfy -PassThru -WindowStyle Minimized

# 3) ComfyUI 뜰 때까지 대기 (최대 ~3분)
$ok = $false
for ($i=0; $i -lt 90; $i++) {
  try { Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:8188/system_stats" -TimeoutSec 3 | Out-Null; $ok=$true; break }
  catch { Start-Sleep -Seconds 2 }
}
if (-not $ok) { Write-Host "[경고] ComfyUI 기동 확인 실패 — 그래도 렌더 시도" }

# 4) 렌더 2편 (이미지=로컬 SDXL, 모션=Pika 키 있으면, 업로드=비공개)
Set-Location "$repo\youtube-auto"
python -m autotube render world --yes --count 2

# 5) ComfyUI 종료
if ($proc) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
Get-Process | Where-Object { $_.Path -like "*ComfyUI_windows_portable*" } | Stop-Process -Force -ErrorAction SilentlyContinue

# 6) 업로드 표식(youtube_id) push
Set-Location $repo
git add youtube-auto/episodes
git commit -m "local render: 업로드 완료 표식" 2>$null
git pull --rebase origin main 2>$null
git push origin HEAD:main

Stop-Transcript | Out-Null

# 7) 2분 뒤 자동 종료 (취소하려면 다른 창에서  shutdown /a )
shutdown /s /t 120
