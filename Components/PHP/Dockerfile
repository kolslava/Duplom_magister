# components/php/Dockerfile
FROM php:8.2-fpm-alpine
WORKDIR /var/www/html
RUN apk add --no-cache \
        freetype libjpeg-turbo libpng libzip oniguruma libxml2 curl git \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS build-base linux-headers autoconf \
        freetype-dev libjpeg-turbo-dev libpng-dev libzip-dev oniguruma-dev libxml2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) pdo pdo_mysql mbstring exif pcntl bcmath gd zip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps
COPY custom.ini /usr/local/etc/php/conf.d/custom.ini
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
USER www-data