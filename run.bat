@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ============================================
echo   해외법인 실적 대시보드 실행
echo ============================================

if not exist "node_modules\vite" (
    echo [1/2] 필요한 패키지를 설치합니다. 잠시만 기다려주세요...
    call npm install
    if errorlevel 1 (
        echo 패키지 설치에 실패했습니다. 인터넷 연결을 확인해주세요.
        pause
        exit /b 1
    )
) else (
    echo [1/2] 패키지가 이미 설치되어 있습니다.
)

echo [2/2] 개발 서버를 시작합니다...
echo 브라우저가 자동으로 열립니다. (http://localhost:5173)
echo 종료하려면 이 창에서 Ctrl+C 를 누르세요.
echo.

call npm run dev

pause
