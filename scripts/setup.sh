#!/bin/bash
# =============================================================================
# SyncScope API Gateway - Setup Script
# =============================================================================
# This script sets up the Kong API Gateway and all required services
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# FUNCTIONS
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is not installed"
        return 1
    else
        print_success "$1 is installed"
        return 0
    fi
}

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

print_header "Pre-flight Checks"

print_info "Checking for required tools..."
check_command "docker" || exit 1
check_command "docker-compose" || check_command "docker" || exit 1

# =============================================================================
# ENVIRONMENT SELECTION
# =============================================================================

print_header "Environment Selection"

if [ -z "$ENVIRONMENT" ]; then
    echo "Select environment:"
    echo "1) Development (dev)"
    echo "2) QA (qa)"
    echo "3) Production (prod)"
    read -p "Enter choice [1-3]: " env_choice

    case $env_choice in
        1)
            ENVIRONMENT="dev"
            ;;
        2)
            ENVIRONMENT="qa"
            ;;
        3)
            ENVIRONMENT="prod"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
fi

print_success "Environment: $ENVIRONMENT"

ENV_FILE=".${ENVIRONMENT}.env"

if [ ! -f "$ENV_FILE" ]; then
    print_error "Environment file $ENV_FILE not found"
    exit 1
fi

print_success "Found environment file: $ENV_FILE"

# Load environment variables
set -a
source "$ENV_FILE"
set +a

# =============================================================================
# DOCKER COMPOSE SETUP
# =============================================================================

print_header "Docker Compose Setup"

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found"
    exit 1
fi

print_info "Pulling latest Docker images..."
docker-compose pull

print_success "Docker images pulled successfully"

# =============================================================================
# DATABASE INITIALIZATION
# =============================================================================

print_header "Database Initialization"

print_info "Starting Kong database..."
docker-compose up -d kong-database

print_info "Waiting for database to be ready..."
sleep 10

print_info "Running Kong database migrations..."
docker-compose up kong-migration

if [ $? -eq 0 ]; then
    print_success "Database migrations completed successfully"
else
    print_error "Database migrations failed"
    exit 1
fi

# =============================================================================
# KONG STARTUP
# =============================================================================

print_header "Starting Kong Gateway"

print_info "Starting Kong Gateway..."
docker-compose up -d kong

print_info "Waiting for Kong to be ready..."
sleep 15

# Check if Kong is running
if docker-compose ps kong | grep -q "Up"; then
    print_success "Kong Gateway is running"
else
    print_error "Kong Gateway failed to start"
    exit 1
fi

# =============================================================================
# HEALTH CHECK
# =============================================================================

print_header "Health Check"

print_info "Checking Kong health..."
./scripts/health-check.sh

if [ $? -eq 0 ]; then
    print_success "All health checks passed"
else
    print_warning "Some health checks failed"
fi

# =============================================================================
# OPTIONAL SERVICES
# =============================================================================

print_header "Optional Services"

read -p "Start Konga (Admin UI)? [y/N]: " start_konga
if [[ $start_konga =~ ^[Yy]$ ]]; then
    print_info "Starting Konga..."
    docker-compose up -d konga
    print_success "Konga started at http://localhost:${KONGA_PORT:-1337}"
fi

read -p "Start Prometheus (Metrics)? [y/N]: " start_prometheus
if [[ $start_prometheus =~ ^[Yy]$ ]]; then
    print_info "Starting Prometheus..."
    docker-compose up -d prometheus
    print_success "Prometheus started at http://localhost:${PROMETHEUS_PORT:-9090}"
fi

read -p "Start Grafana (Dashboards)? [y/N]: " start_grafana
if [[ $start_grafana =~ ^[Yy]$ ]]; then
    print_info "Starting Grafana..."
    docker-compose up -d grafana
    print_success "Grafana started at http://localhost:${GRAFANA_PORT:-3001}"
fi

# =============================================================================
# SUMMARY
# =============================================================================

print_header "Setup Complete"

print_success "SyncScope API Gateway is now running!"
echo ""
print_info "Access points:"
echo "  - Kong Proxy (HTTP):  http://localhost:${KONG_PROXY_PORT:-8000}"
echo "  - Kong Proxy (HTTPS): https://localhost:${KONG_PROXY_SSL_PORT:-8443}"
echo "  - Kong Admin API:     http://localhost:${KONG_ADMIN_PORT:-8001}"
echo "  - Kong Admin GUI:     http://localhost:${KONG_ADMIN_GUI_PORT:-8002}"
if [[ $start_konga =~ ^[Yy]$ ]]; then
    echo "  - Konga Admin UI:     http://localhost:${KONGA_PORT:-1337}"
fi
if [[ $start_prometheus =~ ^[Yy]$ ]]; then
    echo "  - Prometheus:         http://localhost:${PROMETHEUS_PORT:-9090}"
fi
if [[ $start_grafana =~ ^[Yy]$ ]]; then
    echo "  - Grafana:            http://localhost:${GRAFANA_PORT:-3001}"
fi
echo ""
print_info "Next steps:"
echo "  1. Configure Konga (if started) to connect to Kong"
echo "  2. Review Kong configuration: curl http://localhost:${KONG_ADMIN_PORT:-8001}"
echo "  3. Test API routes: curl http://localhost:${KONG_PROXY_PORT:-8000}/health"
echo "  4. Monitor logs: docker-compose logs -f kong"
echo ""
print_info "To stop services: docker-compose down"
print_info "To view logs: docker-compose logs -f"
echo ""
