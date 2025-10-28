@echo off
cls

echo === STARTING FULL PROJECT INSTALLATION ===

:: --- Step 1: Set script directory and read .env ---
:: This finds the directory the script is in, then goes up two levels to the project root
for %%i in ("%~dp0..\..") do set "PROJECT_ROOT=%%~fi"

echo Reading .env configuration from %PROJECT_ROOT%\.env
if not exist "%PROJECT_ROOT%\.env" (
    echo ERROR: .env file not found in project root!
    pause
    exit /b 1
)
for /f "usebackq delims=" %%a in ("%PROJECT_ROOT%\.env") do set "%%a"

:: --- Step 2: Create directories and generate certificates ---
echo Creating directories and generating certificates...
if not exist "%PROJECT_ROOT%\components\fleetdm\certs" mkdir "%PROJECT_ROOT%\components\fleetdm\certs"
if not exist "%PROJECT_ROOT%\WebUI" mkdir "%PROJECT_ROOT%\WebUI"

:: Check if openssl is in PATH
where openssl > nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: openssl is not found in your PATH. Please install it.
    echo See: https://slproweb.com/products/Win32OpenSSL.html
    pause
    exit /b 1
)

echo Generating certificate for %FLEET_SERVER_HOSTNAME%...
openssl req -new -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes -out "%PROJECT_ROOT%\components\fleetdm\certs\server.crt" -keyout "%PROJECT_ROOT%\components\fleetdm\certs\server.key" -subj "/C=UA/ST=Kyiv/L=Kyiv/O=NAC-Adaptive-PJ/OU=Development/CN=%FLEET_SERVER_HOSTNAME%"

:: --- Step 3: Go to project root and run docker compose ---
cd /d "%PROJECT_ROOT%"

echo Building and starting base services (MySQL, Redis, PHP, Nginx)...
docker compose up -d --build mysql redis php nginx

:: --- Step 4: Wait for MySQL to be healthy ---
echo Waiting for MySQL to become healthy...
:wait_mysql
for /f %%i in ('docker inspect -f "{{.State.Health.Status}}" %PROJECT_NAME%_mysql 2^>nul') do set HEALTH=%%i
if not "%HEALTH%"=="healthy" (
    echo -n .
    timeout /t 2 /nobreak > nul
    goto wait_mysql
)
echo.
echo MySQL is ready.

:: --- Step 5: Initialize Fleet Database ---
echo Initializing Fleet database...
docker compose run --rm fleet-prepare-db
if %errorlevel% neq 0 (
    echo ERROR: Failed to initialize Fleet DB. Stopping.
    docker compose down --volumes
    pause
    exit /b 1
)
echo Fleet database initialized successfully.

:: --- Step 6: Start remaining services ---
echo Starting Fleet and Suricata...
docker compose up -d fleet suricata

:: --- Step 7: Install and configure Laravel ---
echo Installing and configuring Laravel (this may take a while)...
docker compose exec -u www-data php composer create-project --no-scripts laravel/laravel .
if %errorlevel% neq 0 (
    echo ERROR: Composer create-project failed. Stopping.
    docker compose down --volumes
    pause
    exit /b 1
)

echo Setting up Laravel permissions and .env file...
docker compose exec php chown -R www-data:www-data storage bootstrap/cache
docker compose exec php chmod -R ug+rwx storage bootstrap/cache
docker compose exec php cp .env.example .env
docker compose exec php php artisan key:generate

docker compose exec -e MYSQL_DATABASE=%MYSQL_DATABASE% -e MYSQL_USER=%MYSQL_USER% -e MYSQL_PASSWORD=%MYSQL_PASSWORD% -e REDIS_PASSWORD=%REDIS_PASSWORD% php php /usr/local/bin/setup-laravel.php

echo Running Laravel migrations...
docker compose exec php php artisan config:clear
docker compose exec php php artisan migrate

echo.
echo ==================================================
echo      FULL INSTALLATION COMPLETED SUCCESSFULLY!
echo ==================================================
echo -> Laravel UI is available at: http://localhost:%FORWARD_NGINX_PORT%
echo -> Fleet UI is available at:   https://%FLEET_SERVER_HOSTNAME%:%FORWARD_FLEET_UI_PORT%
echo    (Ignore the browser security warning)
echo ==================================================
echo.
pause