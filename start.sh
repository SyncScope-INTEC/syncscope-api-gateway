#!/bin/sh
set -e

# Start nginx in the background to serve static files
echo "Starting nginx for static files..."
nginx -c /etc/nginx/nginx-static.conf -g 'daemon off;' &
NGINX_PID=$!

# Give nginx time to start
sleep 2

# Export Kong proxy listen port
export KONG_PROXY_LISTEN="0.0.0.0:${PORT:-8080}"

# Run Kong migrations
echo "Running Kong migrations..."
kong migrations bootstrap

# Import Kong declarative config into database
echo "Importing Kong configuration..."
kong config db_import /etc/kong/kong.yml

# Start Kong in foreground
echo "Starting Kong..."
exec kong start --vv
