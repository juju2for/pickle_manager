@echo off
chcp 65001 > nul
setlocal

echo ========================================================
echo  피클볼 점수판 자동 배포를 시작합니다 (pickle.anglesmith.com)
echo ========================================================
echo.

:: 1. Flutter 웹 빌드 (커스텀 도메인이라 루트 경로 / 사용)
echo [1/4] Flutter Web 빌드 중... (시간이 좀 걸립니다)
call flutter build web --base-href "/" --release

:: 빌드 실패 시 중단
if %errorlevel% neq 0 (
    echo [ERROR] 빌드 실패! 배포를 중단합니다.
    pause
    exit /b
)

:: 2. docs 폴더 동기화 (Robocopy 사용)
echo.
echo [2/4] docs 폴더로 결과물 복사 중...
:: /MIR 옵션: 미러링 (build/web과 똑같이 만듦. 구버전 파일은 자동 삭제됨)
robocopy "build\web" "docs" /MIR /NFL /NDL /NJH /NJS 1>nul

:: 3. 지워진 설정 파일 다시 만들기 (가장 중요!)
echo [3/4] CNAME 및 .nojekyll 파일 복구 중...
echo pickle.anglesmith.com> docs\CNAME
type nul > docs\.nojekyll

:: 4. Git 업로드
echo [4/4] GitHub로 전송(Push) 중...
echo.

:: 커밋 메시지 입력받기 (입력 안 하면 기본값)
set /p MSG="커밋 메시지를 입력하세요 (엔터 치면 '업데이트'로 저장): "
if "%MSG%"=="" set MSG=사이트 업데이트 및 재배포

git add .
git commit -m "%MSG%"
git push

echo.
echo ========================================================
echo  [성공] 배포가 완료되었습니다!
echo  약 1~2분 뒤에 http://pickle.anglesmith.com 에서 확인하세요.
echo ========================================================
pause