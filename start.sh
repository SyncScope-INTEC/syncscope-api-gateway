#!/bin/sh
set -e

echo "SyncScope API Gateway - Kong Startup"
echo "===================================="

# Export Kong proxy listen port
export KONG_PROXY_LISTEN="0.0.0.0:${PORT:-8080}"

# Run Kong migrations
echo "Running Kong database migrations..."
kong migrations bootstrap

# Reset Kong database to clean state
echo "Resetting Kong database (removing old routes)..."
kong migrations reset --yes || true

# Re-run migrations after reset
echo "Running Kong migrations again..."
kong migrations bootstrap

# Import Kong declarative config into database
echo "Importing Kong declarative configuration..."
kong config db_import /etc/kong/kong.yml

# Start Kong in foreground
echo "Starting Kong API Gateway..."
exec kong start --vv
