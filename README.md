# SyncScope API Gateway

[![Kong Version](https://img.shields.io/badge/kong-3.8-blue.svg)](https://konghq.com/)
[![Status](https://img.shields.io/badge/status-production-green.svg)](https://github.com/SyncScope-INTEC/syncscope-api-gateway)

**Kong-based API Gateway for the SyncScope developer productivity monitoring platform.**

## Overview

The SyncScope API Gateway serves as the single entry point for all client requests to the SyncScope microservices ecosystem. Built on Kong Gateway 3.8, it provides:

- **Unified API Entry Point**: Single endpoint for all SyncScope services
- **Authentication & Authorization**: JWT-based authentication with centralized token validation
- **Rate Limiting**: Protect backend services from abuse with configurable rate limits
- **Request Routing**: Intelligent routing to Auth, Monitoring, Management, Analytics, and Alerts services
- **Monitoring & Observability**: Prometheus metrics, logging, and health checks
- **Security**: CORS, SSL/TLS termination, request validation, and security headers
- **High Availability**: Load balancing, health checks, and automatic failover

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     External Clients                            │
│        (Frontend, Mobile Apps, Third-party Integrations)        │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────────┐
        │      Kong API Gateway (Port 8000)         │
        │  ┌─────────────────────────────────────┐  │
        │  │  Authentication (JWT)               │  │
        │  │  Rate Limiting                      │  │
        │  │  CORS                               │  │
        │  │  Logging & Monitoring               │  │
        │  │  Request Transformation             │  │
        │  └─────────────────────────────────────┘  │
        └───────────────────┬───────────────────────┘
                            │
       ┌────────────────────┼────────────────────┐
       │                    │                    │
       ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Auth       │    │  Monitoring  │    │  Management  │
│  Service     │    │   Service    │    │   Service    │
│  (Port 8000) │    │  (Port 8002) │    │  (Port 8001) │
└──────────────┘    └──────────────┘    └──────────────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Analytics   │    │   Alerts     │    │  PostgreSQL  │
│  Service     │    │  Service     │    │   Database   │
│  (Port 8003) │    │  (Port 8004) │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
```

## Features

### Core Gateway Functionality
- **Service Discovery**: Automatic routing to 5 backend microservices
- **Health Monitoring**: Comprehensive health checks for all services
- **Declarative Configuration**: Version-controlled Kong configuration via kong.yml
- **Admin UI**: Konga dashboard for visual gateway management

### Security Features
- **JWT Authentication**: Centralized token validation with Auth Service
- **Rate Limiting**: Configurable limits per user tier (anonymous, authenticated, admin)
- **CORS**: Cross-origin request handling for web applications
- **Request Validation**: Payload size limits and input sanitization
- **SSL/TLS**: HTTPS support with certificate management

### Monitoring & Observability
- **Prometheus Integration**: Real-time metrics collection
- **Grafana Dashboards**: Visual monitoring and alerting
- **Structured Logging**: JSON-formatted logs for analysis
- **Custom Metrics**: Request count, latency, error rates per service

### Developer Experience
- **Setup Scripts**: Automated gateway setup and health checking
- **Docker Support**: Complete containerized deployment
- **CI/CD Pipeline**: Automated testing and deployment workflows
- **Comprehensive Documentation**: API reference and integration guides

## Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- Git
- curl (for health checks)

### 1. Clone the Repository

```bash
git clone https://github.com/SyncScope-INTEC/syncscope-api-gateway.git
cd syncscope-api-gateway
```

### 2. Configure Environment

```bash
# Copy environment template for your environment
cp .dev.env .env

# Edit environment variables
nano .env
```

### 3. Run Setup Script

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run setup (interactive)
./scripts/setup.sh
```

### 4. Verify Installation

```bash
# Run health checks
./scripts/health-check.sh

# Check Kong status
curl http://localhost:8001/status

# Test proxy
curl http://localhost:8000
```

## Manual Setup

### Start All Services

```bash
# Start Kong database
docker-compose up -d kong-database

# Wait for database to be ready
sleep 10

# Run database migrations
docker-compose up kong-migration

# Start Kong Gateway
docker-compose up -d kong

# Start optional services
docker-compose up -d konga prometheus grafana
```

### Verify Services

```bash
# Check running containers
docker-compose ps

# View Kong logs
docker-compose logs -f kong

# Test Kong Admin API
curl http://localhost:8001

# Test Kong Proxy
curl http://localhost:8000
```

## Configuration

### Environment Variables

Key environment variables in `.env` files:

| Variable | Description | Default |
|----------|-------------|---------|
| `KONG_PG_HOST` | PostgreSQL host | localhost |
| `KONG_PG_DATABASE` | Kong database name | kong_dev |
| `KONG_LOG_LEVEL` | Logging level | info |
| `AUTH_SERVICE_URL` | Auth service endpoint | - |
| `JWT_SECRET_KEY` | JWT secret (match Auth Service) | - |
| `RATE_LIMIT_ANONYMOUS` | Anonymous user rate limit | 10/min |
| `RATE_LIMIT_AUTHENTICATED` | Authenticated user rate limit | 100/min |

### Kong Configuration (kong.yml)

The declarative configuration defines:

- **Services**: Backend microservice definitions
- **Routes**: URL path mappings to services
- **Plugins**: CORS, rate limiting, JWT, logging, metrics
- **Consumers**: API consumers and credentials

Example service definition:

```yaml
services:
  - name: auth-service
    url: http://syncscope-auth-service:8000
    routes:
      - name: auth-login
        paths:
          - /auth/login
        methods:
          - POST
```

### Route Mappings

| Route | Backend Service | Authentication |
|-------|----------------|----------------|
| `/auth/*` | Auth Service (8000) | Public + Protected |
| `/monitoring/*` | Monitoring Service (8002) | Required |
| `/management/*` | Management Service (8001) | Required |
| `/analytics/*` | Analytics Service (8003) | Required |
| `/alerts/*` | Alerts Service (8004) | Required |

**Public Routes** (No JWT required):
- `POST /auth/login`
- `POST /auth/register`
- `GET /auth/oauth/github`
- `GET /auth/github/url`
- `POST /auth/github/callback`
- `GET /*/health` (All health endpoints)

**Protected Routes** (JWT required):
- All other routes require valid JWT token in `Authorization: Bearer <token>` header

## API Usage

### Authentication Flow

1. **Obtain JWT Token** (via Auth Service):

```bash
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password"
  }'
```

2. **Use Token for Protected Routes**:

```bash
curl -X GET http://localhost:8000/monitoring/sessions/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Example Requests

#### Start Monitoring Session

```bash
curl -X POST http://localhost:8000/monitoring/sessions/start \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ide_name": "VS Code",
    "project_name": "my-project",
    "branch_name": "main"
  }'
```

#### Get Team Members

```bash
curl -X GET http://localhost:8000/management/teams/123/members/ \
  -H "Authorization: Bearer $TOKEN"
```

#### Generate Analytics Report

```bash
curl -X POST http://localhost:8000/analytics/reports/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Monthly Productivity Report",
    "type": "productivity",
    "config": {
      "start_date": "2024-01-01",
      "end_date": "2024-01-31"
    }
  }'
```

## Admin UI (Konga)

### Access Konga

1. Navigate to: `http://localhost:1337`
2. Create admin account on first visit
3. Add Kong connection:
   - **Name**: SyncScope Kong
   - **Kong Admin URL**: `http://kong:8001`

### Konga Features

- **Dashboard**: Overview of services, routes, and plugins
- **Services Management**: Add/edit/delete services
- **Routes Management**: Configure URL routing
- **Plugins Management**: Enable/configure plugins
- **Consumers**: Manage API consumers and credentials
- **Health Checks**: Monitor service health

## Monitoring

### Prometheus Metrics

Access Prometheus at: `http://localhost:9090`

**Key Metrics:**

- `kong_http_requests_total`: Total HTTP requests
- `kong_latency_bucket`: Request latency histogram
- `kong_bandwidth_bytes`: Bandwidth usage
- `kong_upstream_health`: Backend service health

**Example Queries:**

```promql
# Request rate by service
rate(kong_http_requests_total[5m])

# P95 latency
histogram_quantile(0.95, kong_latency_bucket)

# Error rate
rate(kong_http_requests_total{status=~"5.."}[5m])
```

### Grafana Dashboards

Access Grafana at: `http://localhost:3001`

**Default Credentials:**
- Username: `admin`
- Password: `admin`

**Recommended Dashboards:**
- Kong Official Dashboard (ID: 7424)
- Custom SyncScope metrics dashboard

### Health Checks

```bash
# Run automated health checks
./scripts/health-check.sh

# Individual service health
curl http://localhost:8000/auth/health/
curl http://localhost:8000/monitoring/health/
curl http://localhost:8000/management/health/
curl http://localhost:8000/analytics/health/
curl http://localhost:8000/alerts/health/

# Kong status
curl http://localhost:8001/status
```

## Deployment

### Railway Deployment

1. **Connect Repository to Railway**

```bash
railway link
```

2. **Set Environment Variables**

Add all variables from `.prod.env` to Railway dashboard

3. **Deploy**

```bash
railway up
```

4. **Verify Deployment**

```bash
curl https://your-railway-url.railway.app/health
```

### Docker Deployment

#### Development

```bash
docker-compose up -d
```

#### Production

```bash
docker-compose -f docker-compose.prod.yml up -d
```

### Kubernetes Deployment

Example deployment manifest:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kong-gateway
spec:
  replicas: 3
  selector:
    matchLabels:
      app: kong-gateway
  template:
    metadata:
      labels:
        app: kong-gateway
    spec:
      containers:
      - name: kong
        image: kong:3.8-alpine
        ports:
        - containerPort: 8000
        - containerPort: 8443
        - containerPort: 8001
        env:
        - name: KONG_DATABASE
          value: "postgres"
        - name: KONG_PG_HOST
          valueFrom:
            secretKeyRef:
              name: kong-postgres
              key: host
```

## Testing

### Run CI/CD Pipeline

```bash
# Validate configuration
docker run --rm -v $(pwd)/kong.yml:/kong.yml kong:3.8-alpine kong config parse /kong.yml

# Validate docker-compose
docker-compose config

# Run integration tests
docker-compose up -d
./scripts/health-check.sh
docker-compose down -v
```

### Manual Testing

```bash
# Test authentication flow
TOKEN=$(curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}' \
  | jq -r '.access_token')

# Test protected route
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/monitoring/sessions/

# Test rate limiting
for i in {1..15}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/auth/health/
done
```

## Troubleshooting

### Common Issues

#### Kong Won't Start

```bash
# Check database connectivity
docker-compose exec kong-database psql -U kong -d kong -c "SELECT version();"

# Check Kong logs
docker-compose logs kong

# Restart Kong
docker-compose restart kong
```

#### Routes Not Working

```bash
# Verify routes are loaded
curl http://localhost:8001/routes

# Check service status
curl http://localhost:8001/services

# Reload declarative config
docker-compose restart kong
```

#### Authentication Failing

```bash
# Verify JWT secret matches Auth Service
echo $JWT_SECRET_KEY

# Test token validation
curl -X POST http://localhost:8000/auth/verify-token \
  -H "Authorization: Bearer $TOKEN"

# Check plugin configuration
curl http://localhost:8001/plugins
```

#### Rate Limiting Issues

```bash
# Check rate limit headers
curl -I http://localhost:8000/auth/health/

# View rate limit plugin config
curl http://localhost:8001/plugins | jq '.data[] | select(.name=="rate-limiting")'
```

### Debug Mode

Enable debug logging:

```bash
# Edit .env
KONG_LOG_LEVEL=debug

# Restart Kong
docker-compose restart kong

# View detailed logs
docker-compose logs -f kong
```

## Performance Tuning

### Worker Processes

```yaml
# In docker-compose.yml
KONG_NGINX_WORKER_PROCESSES: auto  # or specific number
```

### Connection Limits

```yaml
# In kong.yml
services:
  - name: my-service
    connect_timeout: 60000
    write_timeout: 60000
    read_timeout: 60000
```

### Database Connection Pooling

```yaml
# In docker-compose.yml
KONG_PG_MAX_CONCURRENT_QUERIES: 50
KONG_PG_SEMAPHORE_TIMEOUT: 5000
```

## Security

### SSL/TLS Configuration

1. **Add SSL Certificates**:

```bash
docker-compose exec kong mkdir -p /etc/kong/ssl
docker cp cert.pem kong:/etc/kong/ssl/
docker cp key.pem kong:/etc/kong/ssl/
```

2. **Configure HTTPS**:

```yaml
# In docker-compose.yml
KONG_SSL_CERT: /etc/kong/ssl/cert.pem
KONG_SSL_CERT_KEY: /etc/kong/ssl/key.pem
```

### IP Restriction

```yaml
# Add to kong.yml
plugins:
  - name: ip-restriction
    config:
      allow:
        - 10.0.0.0/8
        - 172.16.0.0/12
```

### Bot Detection

```yaml
plugins:
  - name: bot-detection
    config:
      deny:
        - "curl"
        - "wget"
```