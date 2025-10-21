#!/bin/bash
# =============================================================================
# SyncScope API Gateway - Health Check Script
# =============================================================================
# This script performs comprehensive health checks on the API Gateway
# and all backend services
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# CONFIGURATION
# =============================================================================

KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8001}"
KONG_PROXY_URL="${KONG_PROXY_URL:-http://localhost:8000}"

# Timeout for HTTP requests (seconds)
TIMEOUT=5

# Exit code
EXIT_CODE=0

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
    EXIT_CODE=1
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_http() {
    local url=$1
    local name=$2
    local expected_status=${3:-200}

    print_info "Checking $name..."

    response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "$url" 2>/dev/null)

    if [ $? -eq 0 ] && [ "$response" -eq "$expected_status" ]; then
        print_success "$name is healthy (HTTP $response)"
        return 0
    else
        print_error "$name is unhealthy (HTTP $response)"
        return 1
    fi
}

check_docker_container() {
    local container_name=$1

    print_info "Checking Docker container: $container_name..."

    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        status=$(docker inspect -f '{{.State.Status}}' "$container_name")
        if [ "$status" = "running" ]; then
            print_success "Container $container_name is running"
            return 0
        else
            print_error "Container $container_name is not running (status: $status)"
            return 1
        fi
    else
        print_error "Container $container_name not found"
        return 1
    fi
}

# =============================================================================
# DOCKER CONTAINERS CHECK
# =============================================================================

print_header "Docker Containers Health Check"

check_docker_container "syncscope-kong-db"
check_docker_container "syncscope-kong"

# Check optional containers
if docker ps --format '{{.Names}}' | grep -q "syncscope-konga"; then
    check_docker_container "syncscope-konga"
fi

if docker ps --format '{{.Names}}' | grep -q "syncscope-prometheus"; then
    check_docker_container "syncscope-prometheus"
fi

if docker ps --format '{{.Names}}' | grep -q "syncscope-grafana"; then
    check_docker_container "syncscope-grafana"
fi

# =============================================================================
# KONG HEALTH CHECK
# =============================================================================

print_header "Kong Gateway Health Check"

# Check Kong status
print_info "Checking Kong status..."
if kong_status=$(curl -s --connect-timeout $TIMEOUT "$KONG_ADMIN_URL/status" 2>/dev/null); then
    print_success "Kong Admin API is accessible"

    # Parse database status
    db_reachable=$(echo "$kong_status" | grep -o '"reachable":true' || echo "")
    if [ -n "$db_reachable" ]; then
        print_success "Kong database is reachable"
    else
        print_error "Kong database is not reachable"
    fi
else
    print_error "Kong Admin API is not accessible"
fi

# Check Kong services
print_info "Checking Kong services..."
if kong_services=$(curl -s --connect-timeout $TIMEOUT "$KONG_ADMIN_URL/services" 2>/dev/null); then
    service_count=$(echo "$kong_services" | grep -o '"name"' | wc -l)
    print_success "Found $service_count Kong services"
else
    print_error "Unable to retrieve Kong services"
fi

# Check Kong routes
print_info "Checking Kong routes..."
if kong_routes=$(curl -s --connect-timeout $TIMEOUT "$KONG_ADMIN_URL/routes" 2>/dev/null); then
    route_count=$(echo "$kong_routes" | grep -o '"name"' | wc -l)
    print_success "Found $route_count Kong routes"
else
    print_error "Unable to retrieve Kong routes"
fi

# =============================================================================
# BACKEND SERVICES HEALTH CHECK
# =============================================================================

print_header "Backend Services Health Check"

# Load environment variables if available
if [ -f ".dev.env" ]; then
    source .dev.env
fi

# Check Auth Service
if [ -n "$AUTH_SERVICE_URL" ]; then
    check_http "$AUTH_SERVICE_URL/health/" "Auth Service"
else
    print_warning "AUTH_SERVICE_URL not set, skipping"
fi

# Check Monitoring Service
if [ -n "$MONITORING_SERVICE_URL" ]; then
    check_http "$MONITORING_SERVICE_URL/health/" "Monitoring Service"
else
    print_warning "MONITORING_SERVICE_URL not set, skipping"
fi

# Check Management Service
if [ -n "$MANAGEMENT_SERVICE_URL" ]; then
    check_http "$MANAGEMENT_SERVICE_URL/health/" "Management Service"
else
    print_warning "MANAGEMENT_SERVICE_URL not set, skipping"
fi

# Check Analytics Service
if [ -n "$ANALYTICS_SERVICE_URL" ]; then
    check_http "$ANALYTICS_SERVICE_URL/health/" "Analytics Service"
else
    print_warning "ANALYTICS_SERVICE_URL not set, skipping"
fi

# Check Alerts Service
if [ -n "$ALERTS_SERVICE_URL" ]; then
    check_http "$ALERTS_SERVICE_URL/health/" "Alerts Service"
else
    print_warning "ALERTS_SERVICE_URL not set, skipping"
fi

# =============================================================================
# PROXY ROUTES CHECK
# =============================================================================

print_header "Kong Proxy Routes Health Check"

print_info "Testing proxy routes through Kong..."

# Test health endpoints through Kong proxy
check_http "$KONG_PROXY_URL/auth/health/" "Auth Route (via Kong)"
check_http "$KONG_PROXY_URL/monitoring/health/" "Monitoring Route (via Kong)"
check_http "$KONG_PROXY_URL/management/health/" "Management Route (via Kong)"
check_http "$KONG_PROXY_URL/analytics/health/" "Analytics Route (via Kong)"
check_http "$KONG_PROXY_URL/alerts/health/" "Alerts Route (via Kong)"

# =============================================================================
# METRICS CHECK
# =============================================================================

print_header "Metrics Health Check"

# Check Prometheus
if docker ps --format '{{.Names}}' | grep -q "syncscope-prometheus"; then
    check_http "http://localhost:${PROMETHEUS_PORT:-9090}/-/healthy" "Prometheus"
fi

# Check Kong Prometheus endpoint
if curl -s --connect-timeout $TIMEOUT "$KONG_ADMIN_URL/metrics" >/dev/null 2>&1; then
    print_success "Kong Prometheus metrics available"
else
    print_warning "Kong Prometheus metrics not available"
fi

# =============================================================================
# SUMMARY
# =============================================================================

print_header "Health Check Summary"

if [ $EXIT_CODE -eq 0 ]; then
    print_success "All health checks passed!"
    echo ""
    print_info "API Gateway Status: HEALTHY"
else
    print_error "Some health checks failed!"
    echo ""
    print_info "API Gateway Status: DEGRADED"
    print_info "Review the errors above and check logs: docker-compose logs -f"
fi

echo ""
exit $EXIT_CODE
