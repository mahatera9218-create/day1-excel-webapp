# Mr.Untold: render the approved episodes locally, upload, then shut down.
# Started automatically at boot by Task Scheduler (install_task.ps1) when the smart plug powers the PC on.
# Uses ComfyUI's bundled Python (no Windows Python needed).
$ErrorActionPreference = "Continue"
$Base  = "C:\mruntold"
$repo  = "$Base\day1-excel-webapp"
$comfy = "$Base\ComfyUI_windows_portable"
$PY    = "$comfy\python_embeded\python.exe"
$env:PYTHONPATH = "$repo\youtube-auto"
$log   = "$Base\render_last.log"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
Start-Transcript -Path $log -Force | Out-Null

# 0) load .env; force LOCAL image engine (cloud stays on Pika)
if (Test-Path "$repo\youtube-auto\.env") {
  Get-Content "$repo\youtube-auto\.env" | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {
      [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
    }
  }
}
$env:AUTOTUBE_IMAGE_ENGINE = "comfy"

# 1) latest code + episodes
Set-Location $repo
git fetch origin main; git checkout main; git pull --ff-only

# 2) start ComfyUI
$proc = Start-Process -FilePath "$comfy\run_nvidia_gpu.bat" -WorkingDirectory $comfy -PassThru -WindowStyle Minimized

# 3) wait for ComfyUI (max ~4 min)
$ok = $false
for ($i=0; $i -lt 120; $i++) {
  try { Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:8188/system_stats" -TimeoutSec 3 | Out-Null; $ok=$true; break }
  catch { Start-Sleep -Seconds 2 }
}
if (-not $ok) { Write-Host "[warn] ComfyUI did not respond - trying render anyway" }

# 4) render 2 episodes (local SDXL images, motion via Pika if key set, private upload)
Set-Location "$repo\youtube-auto"
& $PY -m autotube render world --yes --count 2

# 5) stop ComfyUI
if ($proc) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
Get-Process | Where-Object { $_.Path -like "*ComfyUI_windows_portable*" } | Stop-Process -Force -ErrorAction SilentlyContinue

# 6) push uploaded markers
Set-Location $repo
git add youtube-auto/episodes
git commit -m "local render: uploaded markers" 2>$null
git pull --rebase origin main 2>$null
git push origin HEAD:main

Stop-Transcript | Out-Null

# 7) shut down in 2 min (cancel with:  shutdown /a )
shutdown /s /t 120
