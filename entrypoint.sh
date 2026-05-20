#!/bin/sh
set -e

cd /var/www/html

if [ -n "$MYSQL_HOST" ]; then
  echo "Waiting for MySQL at ${MYSQL_HOST}..."
  until php -r "
    try {
      new PDO(
        'mysql:host=${MYSQL_HOST};port=${MYSQL_PORT:-3306};dbname=${MYSQL_DATABASE}',
        '${MYSQL_USER}',
        '${MYSQL_PASSWORD}'
      );
      exit(0);
    } catch (Exception \$e) {
      exit(1);
    }
  " 2>/dev/null; do
    sleep 2
  done
  echo "MySQL is ready."
fi

if [ ! -d vendor ] || [ ! -f vendor/autoload.php ]; then
  composer install --prefer-dist --no-progress --no-interaction
fi

php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration

if [ "$APP_ENV" = "prod" ]; then
  php bin/console cache:clear --no-warmup
  php bin/console cache:warmup
fi

# PHP-FPM runs as www-data; cache warmup runs as root
mkdir -p var/cache var/log var/share
chown -R www-data:www-data var

exec "$@"
