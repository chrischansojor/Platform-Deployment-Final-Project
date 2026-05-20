# syntax=docker/dockerfile:1

FROM composer:2 AS vendor

WORKDIR /app

COPY composer.json composer.lock symfony.lock ./

RUN composer install \
    --no-dev \
    --no-scripts \
    --no-autoloader \
    --prefer-dist \
    --no-progress

COPY . .

RUN composer install \
    --no-dev \
    --optimize-autoloader \
    --no-scripts \
    --no-progress

# ---------------------------------------------------------------------------
# PHP-FPM base (used by docker-compose "php" service)
# ---------------------------------------------------------------------------
FROM php:8.2-fpm-alpine AS base

RUN apk add --no-cache \
    icu-dev \
    libzip-dev \
    oniguruma-dev \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j"$(nproc)" intl opcache pdo_mysql zip \
    && apk del --no-cache icu-dev libzip-dev oniguruma-dev

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY --from=vendor /app /var/www/html

COPY entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

RUN mkdir -p var/cache var/log \
    && chown -R www-data:www-data var

ENTRYPOINT ["docker-entrypoint"]

FROM base AS fpm

CMD ["php-fpm"]

# ---------------------------------------------------------------------------
# All-in-one image for Railway (Nginx + PHP-FPM)
# ---------------------------------------------------------------------------
FROM base AS production

RUN apk add --no-cache nginx

COPY nginx-main.conf /etc/nginx/nginx.conf
COPY nginx.conf /etc/nginx/http.d/default.conf
COPY docker/start-production.sh /usr/local/bin/start-production.sh
RUN chmod +x /usr/local/bin/start-production.sh

RUN sed -i 's/fastcgi_pass php:9000;/fastcgi_pass 127.0.0.1:9000;/' /etc/nginx/http.d/default.conf

ENV APP_ENV=prod

RUN APP_ENV=prod APP_SECRET=build_secret \
    DATABASE_URL="sqlite:///%kernel.project_dir%/var/build.db" \
    php bin/console assets:install public --no-interaction \
    && php bin/console importmap:install --no-interaction \
    && php bin/console cache:warmup --no-interaction

EXPOSE 8080

CMD ["/usr/local/bin/start-production.sh"]
