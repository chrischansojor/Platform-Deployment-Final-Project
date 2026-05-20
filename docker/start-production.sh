#!/bin/sh
set -e

PORT="${PORT:-8080}"
sed -i "s/listen 80;/listen ${PORT};/" /etc/nginx/http.d/default.conf

php-fpm -D
exec nginx -g 'daemon off;'
