# Mr.Untold local render - one-time setup (Windows + NVIDIA GPU)
# Uses ComfyUI's bundled Python, so you do NOT need to install Windows Python.
# Run in an ADMIN PowerShell:  powershell -ExecutionPolicy Bypass -File setup.ps1
$ErrorActionPreference = "Continue"
$Base = "C:\mruntold"
New-Item -ItemType Directory -Force -Path $Base | Out-Null

Write-Host "== 1/5 Installing tools (winget) ==" -ForegroundColor Cyan
winget install --id Git.Git     -e --accept-package-agreements --accept-source-agreements
winget install --id 7zip.7zip   -e --accept-package-agreements --accept-source-agreements
winget install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "== 2/5 Clone repo ==" -ForegroundColor Cyan
if (!(Test-Path "$Base\day1-excel-webapp")) {
  git clone https://github.com/mahatera9218-create/day1-excel-webapp "$Base\day1-excel-webapp"
} else { Write-Host "already present - skip" }

Write-Host "== 3/5 Download ComfyUI portable (includes its own Python) ==" -ForegroundColor Cyan
if (!(Test-Path "$Base\ComfyUI_windows_portable")) {
  $zip = "$Base\ComfyUI_portable.7z"
  curl.exe -L -o $zip "https://github.com/comfyanonymous/ComfyUI/releases/latest/download/ComfyUI_windows_portable_nvidia.7z"
  & "C:\Program Files\7-Zip\7z.exe" x $zip "-o$Base" -y
  Remove-Item $zip
} else { Write-Host "already present - skip" }

Write-Host "== 4/5 Download SDXL model (~6.9GB, takes a while) ==" -ForegroundColor Cyan
$ckptDir = "$Base\ComfyUI_windows_portable\ComfyUI\models\checkpoints"
New-Item -ItemType Directory -Force -Path $ckptDir | Out-Null
$ckpt = "$ckptDir\sd_xl_base_1.0.safetensors"
if (!(Test-Path $ckpt)) {
  curl.exe -L -o $ckpt "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors?download=true"
} else { Write-Host "already present - skip" }

Write-Host "== 5/5 Install python deps into ComfyUI's Python ==" -ForegroundColor Cyan
$PY = "$Base\ComfyUI_windows_portable\python_embeded\python.exe"
if (!(Test-Path $PY)) {
  Write-Host "ERROR: ComfyUI Python not found ($PY). Did the ComfyUI download finish?" -ForegroundColor Red
} else {
  & $PY -m pip --version
  if ($LASTEXITCODE -ne 0) {
    curl.exe -L -o "$Base\get-pip.py" "https://bootstrap.pypa.io/get-pip.py"
    & $PY "$Base\get-pip.py"
  }
  & $PY -m pip install --upgrade pip
  & $PY -m pip install -r "$Base\day1-excel-webapp\youtube-auto\requirements.txt"
  # make 'autotube' importable by ComfyUI's embedded Python (it uses a ._pth file)
  $pth = Get-ChildItem "$Base\ComfyUI_windows_portable\python_embeded" -Filter "python*._pth" | Select-Object -First 1
  $ytdir = "$Base\day1-excel-webapp\youtube-auto"
  if ($pth -and -not (Select-String -Path $pth.FullName -SimpleMatch $ytdir -Quiet)) {
    Add-Content -Path $pth.FullName -Value $ytdir
    Write-Host ("Registered autotube path in " + $pth.Name)
  }
}

$envPath = "$Base\day1-excel-webapp\youtube-auto\.env"
if (!(Test-Path $envPath)) { "PIKA_API_KEY=`nELEVENLABS_API_KEY=" | Out-File -Encoding ascii $envPath }

Write-Host ""
Write-Host "DONE." -ForegroundColor Green
Write-Host "Next: run test_render.ps1 to see the look (no upload)." -ForegroundColor Yellow
