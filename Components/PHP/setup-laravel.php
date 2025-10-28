<?php
// components/php/setup-laravel.php

$envFile = '/var/www/html/.env';

if (!file_exists($envFile)) {
    echo ".env file not found. Aborting.\n";
    exit(1);
}

// Читаємо весь файл
$content = file_get_contents($envFile);

// --- Крок 1: Деактивуємо SQLite ---
$content = str_replace('DB_CONNECTION=sqlite', '#DB_CONNECTION=sqlite', $content);

// --- Крок 2: Замінюємо налаштування кешу та сесій ---
$content = str_replace('CACHE_STORE=database', 'CACHE_STORE=redis', $content);
$content = str_replace('SESSION_DRIVER=database', 'SESSION_DRIVER=redis', $content);
$content = str_replace('QUEUE_CONNECTION=database', 'QUEUE_CONNECTION=redis', $content);

// --- Крок 3: Налаштовуємо Redis ---
$content = str_replace('REDIS_HOST=127.0.0.1', 'REDIS_HOST=redis', $content);
$content = str_replace('REDIS_PASSWORD=null', 'REDIS_PASSWORD=' . getenv('REDIS_PASSWORD'), $content);

// --- Крок 4: Додаємо блок налаштувань MySQL в кінець файлу ---
$mysqlConfig = "\n"
    . "DB_CONNECTION=mysql\n"
    . "DB_HOST=mysql\n"
    . "DB_PORT=3306\n"
    . "DB_DATABASE=" . getenv('MYSQL_DATABASE') . "\n"
    . "DB_USERNAME=" . getenv('MYSQL_USER') . "\n"
    . "DB_PASSWORD=" . getenv('MYSQL_PASSWORD') . "\n";

// Додаємо новий блок і зберігаємо файл
file_put_contents($envFile, $content . $mysqlConfig);

echo "Laravel .env file configured successfully.\n";