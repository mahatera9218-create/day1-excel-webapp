# Mr.Untold 로컬 렌더 설치 (Windows + NVIDIA GPU)
# 관리자 PowerShell 에서 1회 실행:  powershell -ExecutionPolicy Bypass -File setup.ps1
$ErrorActionPreference = "Stop"
$Base = "C:\mruntold"                      # 전부 여기 밑에 깐다 (원하면 바꿔도 됨)
New-Item -ItemType Directory -Force -Path $Base | Out-Null

Write-Host "== 1/6 필수 프로그램 설치 (winget) ==" -ForegroundColor Cyan
winget install --id Git.Git           -e --accept-package-agreements --accept-source-agreements
winget install --id Python.Python.3.12 -e --accept-package-agreements --accept-source-agreements
winget install --id 7zip.7zip          -e --accept-package-agreements --accept-source-agreements
winget install --id Gyan.FFmpeg        -e --accept-package-agreements --accept-source-agreements
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Host "== 2/6 레포 클론 ==" -ForegroundColor Cyan
if (!(Test-Path "$Base\day1-excel-webapp")) {
  git clone https://github.com/mahatera9218-create/day1-excel-webapp "$Base\day1-excel-webapp"
} else { Write-Host "이미 있음 — 건너뜀" }

Write-Host "== 3/6 ComfyUI 포터블 다운로드/압축해제 (~2GB) ==" -ForegroundColor Cyan
if (!(Test-Path "$Base\ComfyUI_windows_portable")) {
  $zip = "$Base\ComfyUI_portable.7z"
  curl.exe -L -o $zip "https://github.com/comfyanonymous/ComfyUI/releases/latest/download/ComfyUI_windows_portable_nvidia.7z"
  & "C:\Program Files\7-Zip\7z.exe" x $zip "-o$Base" -y
  Remove-Item $zip
} else { Write-Host "이미 있음 — 건너뜀" }

Write-Host "== 4/6 SDXL 모델 다운로드 (~6.9GB, 시간 걸림) ==" -ForegroundColor Cyan
$ckptDir = "$Base\ComfyUI_windows_portable\ComfyUI\models\checkpoints"
New-Item -ItemType Directory -Force -Path $ckptDir | Out-Null
$ckpt = "$ckptDir\sd_xl_base_1.0.safetensors"
if (!(Test-Path $ckpt)) {
  curl.exe -L -o $ckpt "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors?download=true"
} else { Write-Host "이미 있음 — 건너뜀" }

Write-Host "== 5/6 파이썬 의존성 설치 ==" -ForegroundColor Cyan
Set-Location "$Base\day1-excel-webapp\youtube-auto"
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

Write-Host "== 6/6 .env 템플릿 ==" -ForegroundColor Cyan
$envPath = "$Base\day1-excel-webapp\youtube-auto\.env"
if (!(Test-Path $envPath)) {
@"
# 모션(짧은 영상)에 Pika 를 쓸 때만 필요. 안 쓰면 비워도 됨(모션 장면은 스틸로).
PIKA_API_KEY=
ELEVENLABS_API_KEY=
"@ | Out-File -Encoding utf8 $envPath
}

Write-Host "`n설치 끝!" -ForegroundColor Green
Write-Host "이제 README.md 의 '한 번만 하는 수동 단계' 를 마저 하세요:" -ForegroundColor Yellow
Write-Host "  1) 유튜브 인증(token.json),  2) BIOS 자동부팅,  3) 작업 스케줄러 등록(install_task.ps1),  4) 스마트플러그 ON 스케줄"
