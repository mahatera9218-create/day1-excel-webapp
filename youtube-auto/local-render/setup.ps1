# Mr.Untold local render - one-time setup (Windows + NVIDIA GPU)
# Run in an ADMIN PowerShell:  powershell -ExecutionPolicy Bypass -File setup.ps1
$ErrorActionPreference = "Continue"
$Base = "C:\mruntold"
New-Item -ItemType Directory -Force -Path $Base | Out-Null

Write-Host "== 1/6 Installing tools (winget) ==" -ForegroundColor Cyan
winget install --id Git.Git            -e --accept-package-agreements --accept-source-agreements
winget install --id Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements
winget install --id 7zip.7zip          -e --accept-package-agreements --accept-source-agreements
winget install --id Gyan.FFmpeg        -e --accept-package-agreements --accept-source-agreements
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "== 2/6 Clone repo ==" -ForegroundColor Cyan
if (!(Test-Path "$Base\day1-excel-webapp")) {
  git clone https://github.com/mahatera9218-create/day1-excel-webapp "$Base\day1-excel-webapp"
} else { Write-Host "already present - skip" }

Write-Host "== 3/6 Download ComfyUI portable (~2GB) ==" -ForegroundColor Cyan
if (!(Test-Path "$Base\ComfyUI_windows_portable")) {
  $zip = "$Base\ComfyUI_portable.7z"
  curl.exe -L -o $zip "https://github.com/comfyanonymous/ComfyUI/releases/latest/download/ComfyUI_windows_portable_nvidia.7z"
  & "C:\Program Files\7-Zip\7z.exe" x $zip "-o$Base" -y
  Remove-Item $zip
} else { Write-Host "already present - skip" }

Write-Host "== 4/6 Download SDXL model (~6.9GB, takes a while) ==" -ForegroundColor Cyan
$ckptDir = "$Base\ComfyUI_windows_portable\ComfyUI\models\checkpoints"
New-Item -ItemType Directory -Force -Path $ckptDir | Out-Null
$ckpt = "$ckptDir\sd_xl_base_1.0.safetensors"
if (!(Test-Path $ckpt)) {
  curl.exe -L -o $ckpt "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors?download=true"
} else { Write-Host "already present - skip" }

Write-Host "== 5/6 Install python deps ==" -ForegroundColor Cyan
Set-Location "$Base\day1-excel-webapp\youtube-auto"
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

Write-Host "== 6/6 .env template ==" -ForegroundColor Cyan
$envPath = "$Base\day1-excel-webapp\youtube-auto\.env"
if (!(Test-Path $envPath)) {
  "PIKA_API_KEY=`nELEVENLABS_API_KEY=" | Out-File -Encoding ascii $envPath
}

Write-Host ""
Write-Host "DONE." -ForegroundColor Green
Write-Host "Next (one-time, see README): 1) YouTube auth  2) BIOS auto power-on  3) install_task.ps1  4) smart plug schedule" -ForegroundColor Yellow
