#!/bin/bash

# --- Крок 0: Читаємо .env файл ---
export $(grep -v '^#' .env | xargs)

# --- Крок 1: Налаштування прав доступу та очищення ---
echo "Налаштування прав доступу та очищення..."
sudo mkdir -p web-ui
sudo chmod -R 777 web-ui
sudo mkdir -p components/suricata/logs components/mysql/data
sudo chown -R 1000:1000 components/suricata/logs
sudo chmod -R 777 components/mysql/data

# --- Крок 2: Збірка та запуск базових сервісів ---
echo "Збірка та запуск базових сервісів (MySQL, Redis, PHP, Nginx)..."
docker compose up -d --build mysql redis php nginx

# --- Крок 3: Очікування готовності MySQL ---
echo "Очікування повної готовності MySQL..."
while [ "$(docker inspect -f '{{.State.Health.Status}}' nac_adaptive_mysql)" != "healthy" ]; do
    printf '.'
    sleep 2
done
echo ""
echo "MySQL готовий."

# --- Крок 4: Ініціалізація бази даних Fleet ---
echo "Ініціалізація бази даних для Fleet..."
docker compose run --rm fleet-prepare-db
if [ $? -ne 0 ]; then
    echo "Помилка під час ініціалізації БД Fleet. Зупинка."
    docker compose down --volumes
    exit 1
fi
echo "База даних Fleet успішно ініціалізована."

# --- Крок 5: Запуск решти сервісів ---
echo "Запуск Fleet та Suricata..."
docker compose up -d fleet suricata

# --- Крок 6: Встановлення та налаштування Laravel ---
echo "Встановлення та налаштування Laravel..."
if [ ! -f "web-ui/artisan" ]; then
    # Встановлюємо Laravel без запуску скриптів, щоб уникнути помилок з правами
    docker compose exec -u www-data php composer create-project --no-scripts laravel/laravel .
    if [ $? -ne 0 ]; then
        echo "Помилка під час встановлення Laravel. Зупинка."
        docker compose down --volumes
        exit 1
    fi

    # Виправляємо права на storage одразу після створення файлів
    docker compose exec php chown -R www-data:www-data storage bootstrap/cache
    docker compose exec php chmod -R 775 storage bootstrap/cache

    # Копіюємо .env і генеруємо ключ
    docker compose exec php cp .env.example .env
    docker compose exec php php artisan key:generate

    # Налаштовуємо .env за допомогою нашого PHP-скрипта
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
else
    echo "Laravel вже встановлено. Пропускаємо."
fi

# --- Крок 7: Виправлення власника файлів ---
echo "Виправлення власника файлів у web-ui..."
sudo chown -R $USER:$USER web-ui

# --- Завершення ---
echo ""
echo "=================================================="
echo "      РОЗГОРТАННЯ УСПІШНО ЗАВЕРШЕНО!"
echo "=================================================="
echo "-> Laravel UI доступний за адресою: http://localhost:${FORWARD_NGINX_PORT}"
echo "-> Fleet UI доступний за адресою:  https://${FLEET_SERVER_HOSTNAME}:${FORWARD_FLEET_UI_PORT}"
echo "   (Ігноруйте попередження браузера про безпеку)"
echo "=================================================="
echo ""