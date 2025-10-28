@echo off
for %%i in ("%~dp0..") do set "PROJECT_ROOT=%%~fi"
cd /d "%PROJECT_ROOT%"

echo Stopping all project services...
docker compose down
echo Done.
pause