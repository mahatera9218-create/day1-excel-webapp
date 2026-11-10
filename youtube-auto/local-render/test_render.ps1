# Quick LOCAL test: render the newest episode using local SDXL images, NO upload, NO shutdown.
# Lets you SEE the look before wiring up the automation.
# Run:  powershell -ExecutionPolicy Bypass -File test_render.ps1
$ErrorActionPreference = "Continue"
$Base  = "C:\mruntold"
$repo  = "$Base\day1-excel-webapp"
$comfy = "$Base\ComfyUI_windows_portable"

Set-Location $repo
git pull --ff-only

# load .env (PIKA key is optional - only for motion clips)
if (Test-Path "$repo\youtube-auto\.env") {
  Get-Content "$repo\youtube-auto\.env" | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {
      [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
    }
  }
}
$env:AUTOTUBE_IMAGE_ENGINE = "comfy"

Write-Host "Starting ComfyUI (first time can take ~1 min)..." -ForegroundColor Cyan
$proc = Start-Process -FilePath "$comfy\run_nvidia_gpu.bat" -WorkingDirectory $comfy -PassThru -WindowStyle Minimized
$ok = $false
for ($i=0; $i -lt 120; $i++) {
  try { Invoke-WebRequest -UseBasicParsing "http://127.0.0.1:8188/system_stats" -TimeoutSec 3 | Out-Null; $ok=$true; break }
  catch { Start-Sleep -Seconds 2 }
}
if (-not $ok) { Write-Host "[warn] ComfyUI not responding - will try anyway" -ForegroundColor Yellow }

$ep = Get-ChildItem "$repo\youtube-auto\episodes\world" -Directory | Sort-Object Name -Descending | Select-Object -First 1
Write-Host ("Rendering (local images, NO upload): " + $ep.Name) -ForegroundColor Cyan
Set-Location "$repo\youtube-auto"
python -m autotube render world --yes --episode $ep.Name --no-upload

if ($proc) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
Get-Process | Where-Object { $_.Path -like "*ComfyUI_windows_portable*" } | Stop-Process -Force -ErrorAction SilentlyContinue

$final = Join-Path "$repo\youtube-auto\episodes\world\$($ep.Name)" "final.mp4"
Write-Host ""
if (Test-Path $final) {
  Write-Host ("DONE. Opening: " + $final) -ForegroundColor Green
  Start-Process $final
} else {
  Write-Host "No final.mp4 produced - copy any red error above and send it to Claude." -ForegroundColor Yellow
}
