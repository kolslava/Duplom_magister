#!/bin/bash

echo "=== ПОЧАТОК ПОВНОГО ВСТАНОВЛЕННЯ ==="

# --- Крок 1: Очищення ---
echo "Зупинка контейнерів та видалення томів..."
docker compose down --volumes
sudo rm -rf web-ui
echo "Очищення завершено."

# --- Крок 2: Створення структури та генерація сертифікатів ---
echo "Створення каталогів та генерація сертифікатів..."
export $(grep -v '^#' .env | xargs)
mkdir -p components/fleet/certs
openssl req -new -newkey rsa:4096 -x509 -sha256 -days 3650 -nodes \
-out components/fleet/certs/server.crt \
-keyout components/fleet/certs/server.key \
-subj "/C=UA/ST=Kyiv/L=Kyiv/O=NAC-Adaptive-PJ/OU=Development/CN=${FLEET_SERVER_HOSTNAME}"
chmod 644 components/fleet/certs/server.key components/fleet/certs/server.crt
sudo mkdir -p web-ui
sudo chmod -R 777 web-ui
sudo mkdir -p components/suricata/logs
sudo chown -R 1000:1000 components/suricata/logs

# --- Крок 3: Запуск всього стеку ---
echo "Збірка та запуск всіх сервісів..."
docker compose up -d --build

# --- Крок 4: Очікування готовності MySQL ---
echo "Очікування повної готовності MySQL..."
while [ "$(docker inspect -f '{{.State.Health.Status}}' nac_adaptive_mysql)" != "healthy" ]; do
    printf '.'
    sleep 2
done
echo "" && echo "MySQL готовий."

# --- Крок 5: Ініціалізація бази даних Fleet ---
echo "Ініціалізація бази даних для Fleet..."
docker compose run --rm fleet-prepare-db
if [ $? -ne 0 ]; then
    echo "Помилка під час ініціалізації БД Fleet. Зупинка."
    docker compose down --volumes
    exit 1
fi
echo "База даних Fleet успішно ініціалізована."

# --- Крок 6: Встановлення та налаштування Laravel ---
echo "Встановлення та налаштування Laravel..."
docker compose exec -u www-data php composer create-project --no-scripts laravel/laravel .
docker compose exec php cp .env.example .env
docker compose exec php php artisan key:generate

# ## ЗМІНА ТУТ: Виправляємо права ДО налаштування .env, щоб уникнути помилок логування ##
echo "Налаштування прав доступу для Laravel..."
docker compose exec php chown -R www-data:www-data storage bootstrap/cache
docker compose exec php chmod -R ug+rwx storage bootstrap/cache

# Налаштовуємо .env
docker compose exec \
  -e MYSQL_DATABASE=${MYSQL_DATABASE} \
  -e MYSQL_USER=${MYSQL_USER} \
  -e MYSQL_PASSWORD=${MYSQL_PASSWORD} \
  -e REDIS_PASSWORD=${REDIS_PASSWORD} \
  php php /usr/local/bin/setup-laravel.php

# Запускаємо міграції
echo "Запуск міграцій Laravel..."
docker compose exec php php artisan config:clear
docker compose exec php php artisan migrate

# --- Крок 7: Виправлення власника файлів ---
echo "Виправлення власника файлів у web-ui..."
sudo chown -R $USER:$USER web-ui

echo ""
echo "=================================================="
echo "      ПОВНЕ ВСТАНОВЛЕННЯ ЗАВЕРШЕНО!"
echo "=================================================="