# Load Balancing Configuration for SyncScope API Gateway

## Overview

Kong API Gateway provides built-in load balancing capabilities using **upstreams** and **targets**. This document explains how load balancing is configured and how to scale services horizontally.

## Current Configuration

The API Gateway is configured with upstreams for all backend services. Each upstream is configured with:

- **Health checks**: Active and passive health monitoring
- **Load balancing algorithm**: Round-robin (configurable)
- **Connection pooling**: Optimized for performance
- **Circuit breaker**: Automatic failover on service failures

## Upstreams Configuration

### Structure

Each backend service has a corresponding upstream in `kong.yml`:

```yaml
upstreams:
  - name: auth-service-upstream
    algorithm: round-robin
    hash_on: none
    healthchecks:
      active:
        healthy:
          interval: 30
          successes: 2
        unhealthy:
          interval: 5
          http_failures: 3
          timeouts: 3
    targets:
      - target: syncscope-auth-service:8000
        weight: 100
```

### Available Load Balancing Algorithms

Kong supports the following algorithms:

1. **round-robin** (default): Distributes requests evenly across all healthy targets
2. **consistent-hashing**: Uses a hash key to determine target (sticky sessions)
3. **least-connections**: Routes to target with fewest active connections

To change the algorithm, update the `algorithm` field in the upstream configuration.

## Health Checks

### Active Health Checks

Kong actively probes backend services at configured intervals:

- **Interval**: 30 seconds for healthy targets, 5 seconds for unhealthy
- **Success threshold**: 2 consecutive successes to mark healthy
- **Failure threshold**: 3 consecutive failures to mark unhealthy
- **Timeout threshold**: 3 consecutive timeouts to mark unhealthy

### Passive Health Checks

Kong monitors actual request traffic to detect failures:

- Tracks HTTP status codes (500-504 considered unhealthy)
- Monitors connection timeouts
- Automatically removes unhealthy targets from rotation

## Scaling Services Horizontally

### Adding Service Instances

To add more instances of a service for load balancing:

1. **Deploy additional service instances** on Railway or your infrastructure
2. **Get the service endpoints** (host:port)
3. **Update kong.yml** with new targets:

```yaml
upstreams:
  - name: auth-service-upstream
    targets:
      # Primary instance
      - target: syncscope-auth-service-1.up.railway.app:443
        weight: 100
      # Secondary instance (newly added)
      - target: syncscope-auth-service-2.up.railway.app:443
        weight: 100
```

4. **Apply configuration** using Kong Admin API or restart with new config

### Using Kong Admin API

You can also add targets dynamically without restarting:

```bash
# Add a new target to auth-service-upstream
curl -X POST http://localhost:8001/upstreams/auth-service-upstream/targets \
  --data "target=syncscope-auth-service-2:8000" \
  --data "weight=100"

# List all targets for an upstream
curl http://localhost:8001/upstreams/auth-service-upstream/targets

# Mark a target as unhealthy (for maintenance)
curl -X POST http://localhost:8001/upstreams/auth-service-upstream/targets/{target-id}/unhealthy

# Mark a target as healthy again
curl -X POST http://localhost:8001/upstreams/auth-service-upstream/targets/{target-id}/healthy

# Remove a target
curl -X DELETE http://localhost:8001/upstreams/auth-service-upstream/targets/{target-id}
```

## Target Weights

The `weight` parameter determines the proportion of traffic each target receives:

```yaml
targets:
  # This target receives 75% of traffic
  - target: service-instance-1:8000
    weight: 75
  # This target receives 25% of traffic
  - target: service-instance-2:8000
    weight: 25
```

Use cases:
- **Canary deployments**: Route small percentage to new version
- **Hardware differences**: Route more traffic to more powerful instances
- **Gradual rollout**: Slowly increase traffic to new instances

## Blue-Green Deployments

For zero-downtime deployments:

1. **Deploy new version** (green) alongside current version (blue)
2. **Add green targets** with weight 0:

```yaml
targets:
  - target: auth-service-blue:8000
    weight: 100
  - target: auth-service-green:8000
    weight: 0
```

3. **Gradually shift traffic** by adjusting weights:

```bash
# 50/50 split
curl -X PATCH http://localhost:8001/upstreams/auth-service-upstream/targets/blue-id \
  --data "weight=50"
curl -X PATCH http://localhost:8001/upstreams/auth-service-upstream/targets/green-id \
  --data "weight=50"

# Full cutover to green
curl -X PATCH http://localhost:8001/upstreams/auth-service-upstream/targets/blue-id \
  --data "weight=0"
curl -X PATCH http://localhost:8001/upstreams/auth-service-upstream/targets/green-id \
  --data "weight=100"
```

4. **Remove blue targets** once confident in green deployment

## Monitoring Load Balancing

### Prometheus Metrics

The API Gateway exports upstream health metrics:

```promql
# Upstream health status (1 = healthy, 0 = unhealthy)
kong_upstream_target_health{upstream="auth-service-upstream"}

# Request count per target
kong_upstream_target_requests_total{upstream="auth-service-upstream", target="..."}

# Connection pool usage
kong_upstream_target_connections{upstream="auth-service-upstream", state="active"}
```

### Kong Admin API

Check upstream health status:

```bash
# Get upstream health
curl http://localhost:8001/upstreams/auth-service-upstream/health

# Example response:
{
  "total": 2,
  "healthy": 2,
  "unhealthy": 0,
  "data": [
    {
      "target": "syncscope-auth-service-1:8000",
      "health": "HEALTHY",
      "weight": 100
    },
    {
      "target": "syncscope-auth-service-2:8000",
      "health": "HEALTHY",
      "weight": 100
    }
  ]
}
```

### Grafana Dashboard

Create Grafana dashboards to visualize:
- Upstream target health over time
- Request distribution across targets
- Response time per target
- Error rate per target

Example queries in `grafana-dashboards/load-balancing.json`.

## Circuit Breaker Behavior

When a target becomes unhealthy:

1. Kong marks it as unhealthy based on active/passive checks
2. Traffic is automatically routed to remaining healthy targets
3. Kong continues health checking the unhealthy target
4. Once health checks succeed, traffic gradually returns

## Connection Pooling

Kong maintains connection pools to backend services:

```yaml
upstreams:
  - name: auth-service-upstream
    slots: 10000  # Maximum number of upstream targets
```

Benefits:
- Reduced connection overhead
- Lower latency
- Better resource utilization

## DNS-Based Load Balancing

For services behind a load balancer (e.g., Kubernetes, AWS ELB):

```yaml
upstreams:
  - name: auth-service-upstream
    targets:
      # Single DNS entry that resolves to multiple IPs
      - target: auth-service.internal.syncscope.com:8000
        weight: 100
```

Kong will resolve the DNS and load balance across all IPs.

## Best Practices

1. **Start with round-robin**: Simple and effective for most use cases
2. **Monitor health checks**: Ensure intervals and thresholds are appropriate
3. **Use weights for canary**: Test new versions with 5-10% of traffic first
4. **Set up alerts**: Alert on upstream becoming unhealthy
5. **Test failover**: Regularly test what happens when targets go down
6. **Document target changes**: Keep track of when targets are added/removed
7. **Use tags**: Tag targets for easier management

## Example: Scaling Auth Service

Complete example of scaling the auth service from 1 to 3 instances:

```yaml
upstreams:
  - name: auth-service-upstream
    algorithm: round-robin
    hash_on: none
    tags:
      - auth
      - production
    healthchecks:
      active:
        https_verify_certificate: false
        healthy:
          interval: 30
          successes: 2
        unhealthy:
          interval: 5
          http_failures: 3
          timeouts: 3
      passive:
        healthy:
          successes: 5
        unhealthy:
          http_failures: 3
          timeouts: 3
    targets:
      # Primary instance (US-East)
      - target: auth-1.us-east.railway.app:443
        weight: 100
        tags:
          - primary
          - us-east
      # Secondary instance (US-West)
      - target: auth-2.us-west.railway.app:443
        weight: 100
        tags:
          - secondary
          - us-west
      # Tertiary instance (EU)
      - target: auth-3.eu-central.railway.app:443
        weight: 100
        tags:
          - tertiary
          - eu-central
```

Then update the service to use the upstream:

```yaml
services:
  - name: auth-service
    host: auth-service-upstream  # References the upstream
    protocol: https
    port: 443
    # ... rest of service config
```

## Troubleshooting

### All Targets Marked Unhealthy

**Symptom**: 503 Service Unavailable errors

**Possible causes**:
- Health check endpoint is incorrect
- Network connectivity issues
- Services are actually down

**Debug**:
```bash
# Check upstream health
curl http://localhost:8001/upstreams/auth-service-upstream/health

# Check if service is reachable from Kong container
docker exec kong-gateway curl http://syncscope-auth-service:8000/health

# Review Kong logs
docker logs kong-gateway | grep upstream
```

### Uneven Load Distribution

**Symptom**: One target receives disproportionate traffic

**Possible causes**:
- Weight misconfiguration
- Sticky sessions enabled unintentionally
- One target is faster (least-connections algorithm)

**Fix**:
```bash
# Verify weights
curl http://localhost:8001/upstreams/auth-service-upstream/targets

# Check algorithm
curl http://localhost:8001/upstreams/auth-service-upstream
```

### Health Checks Too Aggressive

**Symptom**: Healthy services marked unhealthy during high load

**Fix**: Adjust thresholds in kong.yml:
```yaml
healthchecks:
  active:
    unhealthy:
      http_failures: 5  # Increase from 3
      timeouts: 5       # Increase from 3
```

## References

- [Kong Upstream Documentation](https://docs.konghq.com/gateway/latest/admin-api/#upstream-object)
- [Kong Health Checks](https://docs.konghq.com/gateway/latest/how-kong-works/health-checks/)
- [Load Balancing Algorithms](https://docs.konghq.com/gateway/latest/how-kong-works/load-balancing/)
