@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ============================================
echo   AI 유튜브 자동 제작
echo ============================================

where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo ffmpeg 이 없습니다. 먼저 설치해주세요:  winget install ffmpeg
    pause
    exit /b 1
)

if not exist ".venv" (
    echo [준비] 파이썬 패키지를 설치합니다...
    python -m venv .venv
    call .venv\Scripts\pip install -r requirements.txt
)
if not exist ".env" (
    copy .env.example .env >nul
    echo .env 파일에 API 키를 넣고 저장한 뒤 다시 실행해주세요.
    notepad .env
    exit /b 0
)
if not exist "config.yaml" copy config.example.yaml config.yaml >nul

set /p TOPIC=영상 주제 (비우면 topics.txt 에서 자동 선택):
if "%TOPIC%"=="" (
    call .venv\Scripts\python -m autotube run
) else (
    call .venv\Scripts\python -m autotube run --topic "%TOPIC%"
)

pause
