@echo off
for %%i in ("%~dp0..") do set "PROJECT_ROOT=%%~fi"
cd /d "%PROJECT_ROOT%"

echo Starting all project services...
docker compose up -d
echo Done.
pause