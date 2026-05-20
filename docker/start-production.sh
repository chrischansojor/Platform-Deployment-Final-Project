#!/bin/sh
set -e

PORT="${PORT:-8080}"
echo "Starting Nginx on 0.0.0.0:${PORT}"

sed -i "s/listen 80;/listen 0.0.0.0:${PORT};/" /etc/nginx/http.d/default.conf

nginx -t

php-fpm -D
exec nginx -g 'daemon off;'
