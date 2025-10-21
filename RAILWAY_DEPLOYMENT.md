# Kong API Gateway - Railway Deployment Guide

This guide explains how to deploy the Kong API Gateway to Railway.

## Overview

The Kong API Gateway is configured to run on Railway using:
- **Dockerfile**: Railway-optimized Kong container
- **railway.toml**: Railway build and deployment configuration
- **kong.yml**: Declarative Kong configuration
- **Environment files**: .dev.env, .qa.env, .prod.env

## Prerequisites

1. Railway account with CLI installed
2. PostgreSQL database service already created in Railway
3. Environment variables configured in Railway dashboard

## Railway Setup

### Step 1: Create Kong Database

Before deploying Kong, ensure the `kong` database exists on your PostgreSQL cluster:

**DEV Environment:**
```bash
PGPASSWORD=TcUQCbDhYagSaccdpbxQSLcUDgNUtWWI psql \
  -h ballast.proxy.rlwy.net \
  -p 13548 \
  -U postgres \
  -d postgres \
  -c "CREATE DATABASE kong;"
```

**QA Environment:**
```bash
PGPASSWORD=AMUpBMWJqTvXgJKtUjrPUFdUOYgXxsar psql \
  -h tramway.proxy.rlwy.net \
  -p 54691 \
  -U postgres \
  -d postgres \
  -c "CREATE DATABASE kong;"
```

**PROD Environment:**
```bash
PGPASSWORD=AeFNPImStftqtvaykfPJMqdshiwOKCTZ psql \
  -h trolley.proxy.rlwy.net \
  -p 34973 \
  -U postgres \
  -d postgres \
  -c "CREATE DATABASE kong;"
```

### Step 2: Configure Environment Variables in Railway

Set these environment variables in the Railway dashboard for your Kong service:

#### Database Configuration
```
KONG_DATABASE=postgres
KONG_PG_HOST=<your-postgres-host>     # e.g., ballast.proxy.rlwy.net
KONG_PG_PORT=<your-postgres-port>     # e.g., 13548
KONG_PG_USER=postgres
KONG_PG_PASSWORD=<your-postgres-password>
KONG_PG_DATABASE=kong
```

#### Kong Configuration
```
KONG_LOG_LEVEL=info                   # Use 'debug' for dev, 'warn' for prod
KONG_NGINX_WORKER_PROCESSES=auto
KONG_SSL_CIPHER_SUITE=intermediate    # Use 'modern' for production
KONG_PLUGINS=bundled,rate-limiting,cors,jwt,file-log,request-size-limiting,response-transformer
```

#### Service URLs (for each environment)
```
AUTH_SERVICE_URL=https://syncscope-auth-service-dev.up.railway.app
MONITORING_SERVICE_URL=https://syncscope-monitoring-service-dev.up.railway.app
MANAGEMENT_SERVICE_URL=https://syncscope-management-service-dev.up.railway.app
ANALYTICS_SERVICE_URL=https://syncscope-analytics-service-dev.up.railway.app
ALERTS_SERVICE_URL=https://syncscope-alerts-service-dev.up.railway.app
```

### Step 3: Deploy to Railway

Railway automatically detects the Dockerfile and builds the service.

```bash
# Link your local repo to Railway
railway link

# Deploy to Railway
railway up

# View logs
railway logs
```

### Step 4: Verify Deployment

After deployment, verify Kong is running:

```bash
# Check Kong health
curl https://your-kong-service.up.railway.app/health

# Check Kong Admin API
curl https://your-kong-service.up.railway.app:8081/

# Test a backend service through Kong
curl https://your-kong-service.up.railway.app/auth/health
```

## Important Notes

### Port Configuration
- Railway automatically assigns a PORT environment variable
- Kong proxy listens on this PORT (default: 8080)
- Kong Admin API listens on port 8081
- Kong Admin GUI is disabled for Railway deployment

### Database Migrations
- Kong automatically runs database migrations on startup
- First deployment will bootstrap the database schema
- Subsequent deployments will run incremental migrations

### Declarative Configuration
- Kong loads configuration from `kong.yml` on startup
- This includes all routes, services, and plugins
- Changes to kong.yml require a redeploy

### Logging
- All logs go to stdout/stderr
- Railway captures and displays logs in the dashboard
- Log level controlled by KONG_LOG_LEVEL environment variable

## Architecture

```
┌──────────────────────────────────────────────┐
│           Railway Platform                   │
├──────────────────────────────────────────────┤
│                                              │
│  ┌────────────────┐    ┌─────────────────┐  │
│  │  Kong Gateway  │───▶│   PostgreSQL    │  │
│  │   (Port 8080)  │    │   (kong DB)     │  │
│  └────────────────┘    └─────────────────┘  │
│         │                                    │
│         ▼                                    │
│  ┌──────────────────────────────────────┐   │
│  │       Backend Services               │   │
│  │  ┌─────┐ ┌──────┐ ┌────────┐        │   │
│  │  │Auth │ │Mgmt  │ │Monitor │ ...    │   │
│  │  └─────┘ └──────┘ └────────┘        │   │
│  └──────────────────────────────────────┘   │
│                                              │
└──────────────────────────────────────────────┘
```

## Troubleshooting

### Kong won't start
1. Check database connection: Verify KONG_PG_HOST, KONG_PG_PORT, KONG_PG_USER, KONG_PG_PASSWORD
2. Check database exists: Ensure `kong` database was created
3. Check migrations: Railway logs will show if migrations failed

### 502 Bad Gateway
1. Verify backend services are running
2. Check kong.yml routes point to correct Railway service URLs
3. Check CORS configuration if requests from frontend fail

### High memory usage
Reduce KONG_NGINX_WORKER_PROCESSES or set specific worker count:
```
KONG_NGINX_WORKER_PROCESSES=2
```

## Local Development

For local development with Docker Compose, see `local-dev/README.md`.

## Related Files

- `Dockerfile` - Railway container image
- `railway.toml` - Railway configuration
- `kong.yml` - Kong declarative configuration
- `.dev.env`, `.qa.env`, `.prod.env` - Environment-specific settings
- `local-dev/docker-compose.yml` - Local development only

## Support

For Railway-specific issues, check:
- Railway Docs: https://docs.railway.app
- Kong Docs: https://docs.konghq.com
- Railway Kong Template: https://railway.app/template/Addl8t
