# Local Development with Docker Compose

This directory contains docker-compose configuration for running Kong API Gateway locally.

**Note**: Railway deployment uses the Dockerfile in the parent directory. This docker-compose.yml is only for local development and testing.

## Prerequisites

- Docker Desktop installed
- PostgreSQL client tools (psql, pg_dump)

## Quick Start

```bash
# From the local-dev directory
cd syncscope-api-gateway/local-dev

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f kong

# Stop all services
docker-compose down

# Remove all data (WARNING: destructive)
docker-compose down -v
```

## Services Included

- **Kong Gateway** (port 8080) - API Gateway proxy
- **Kong Admin API** (port 8081) - Kong configuration API
- **Konga UI** (port 1337) - Kong admin web interface
- **PostgreSQL** (port 5433) - Kong database

## Access Points

- Kong Proxy: http://localhost:8080
- Kong Admin API: http://localhost:8081
- Konga Admin UI: http://localhost:1337

## Konga Setup

On first run:
1. Open http://localhost:1337
2. Create an admin user
3. Add Kong connection: `http://kong:8081`

## Environment Variables

The docker-compose.yml uses environment variables from the parent directory's `.dev.env` file.

## Railway Deployment

This docker-compose setup is NOT used for Railway deployment. Railway uses:
- `../Dockerfile` - Container image
- `../railway.toml` - Railway configuration
- Environment variables set in Railway dashboard

## Troubleshooting

### Kong won't start
- Make sure PostgreSQL is healthy: `docker-compose ps`
- Check migrations completed: `docker-compose logs kong-migration`
- Restart Kong: `docker-compose restart kong`

### Port conflicts
If ports 8080, 8081, 8443, or 1337 are already in use, modify the port mappings in docker-compose.yml.

### Database issues
Reset the database:
```bash
docker-compose down -v  # Remove all data
docker-compose up -d    # Start fresh
```
