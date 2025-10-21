# CI Testing Strategy

## Overview

The CI/CD pipeline uses a simplified Kong configuration to test that the API gateway starts correctly without requiring actual backend services.

## Testing Approach

### DB-less Mode for CI

The integration tests run Kong in **DB-less mode** using a minimal declarative configuration (`kong-test.yml`). This approach:

✅ **Faster** - No database setup or migrations needed
✅ **Simpler** - Fewer moving parts, less chance of failure
✅ **Sufficient** - Tests that Kong starts, loads config, and APIs work
✅ **Portable** - Works consistently across CI environments

### Configuration Files

| File | Purpose | Mode |
|------|---------|------|
| `kong.yml` | Production configuration with all services | Database + Declarative |
| `kong-test.yml` | Minimal CI test configuration | DB-less only |
| `local-dev/docker-compose.yml` | Local development setup | Database + Declarative |

## What the Tests Verify

The integration tests validate:

1. ✅ Kong container starts successfully
2. ✅ Kong loads the declarative configuration
3. ✅ Admin API is accessible (`/status`, `/services`, `/routes`)
4. ✅ Proxy port is listening
5. ✅ No critical errors in logs

## What the Tests DON'T Verify

❌ Actual service routing (backend services don't exist in CI)
❌ Authentication/Authorization plugins (no real auth service)
❌ Full end-to-end request flows
❌ Load balancing or failover scenarios

These should be tested in staging/QA environments with actual services running.

## Local Development vs CI

### Local Development (`docker-compose up`)
- Uses PostgreSQL database
- Runs migrations
- Loads full `kong.yml` configuration
- Includes Konga admin UI
- Suitable for development and manual testing

### CI Pipeline (`docker run`)
- Uses DB-less mode (no database)
- Loads minimal `kong-test.yml`
- Single container only
- Fast startup (~10 seconds)
- Suitable for automated testing

## Running Tests Locally

To replicate the CI tests locally:

```bash
# Start Kong in DB-less mode
docker run -d \
  --name kong-test \
  -e "KONG_DATABASE=off" \
  -e "KONG_DECLARATIVE_CONFIG=/kong.yml" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8081" \
  -v "$(pwd)/kong-test.yml:/kong.yml:ro" \
  -p 8080:8000 \
  -p 8081:8081 \
  kong:3.4

# Wait for startup
sleep 5

# Test endpoints
curl http://localhost:8081/status
curl http://localhost:8081/services
curl http://localhost:8081/routes

# Cleanup
docker stop kong-test && docker rm kong-test
```

## Why Keep Integration Tests?

Integration tests are essential for:

1. **Early Detection** - Catch configuration errors before deployment
2. **Confidence** - Know that Kong will start in production
3. **Documentation** - Living proof that the setup works
4. **Regression Protection** - Prevent breaking changes
5. **CI/CD Gate** - Automated quality check before merge

## Troubleshooting CI Failures

### Kong fails to start
- Check `kong-test.yml` syntax
- Verify Kong image version exists (`kong:3.4`)
- Review container logs in CI output

### Timeout waiting for Kong
- Increase timeout in workflow (currently 90s)
- Check if Kong is listening on correct ports
- Verify no port conflicts in CI runner

### Admin API not responding
- Ensure `KONG_ADMIN_LISTEN=0.0.0.0:8081`
- Check firewall/network settings
- Verify port mapping `-p 8081:8081`

## Future Improvements

Consider adding:
- [ ] Configuration validation tests
- [ ] Plugin loading verification
- [ ] Basic routing smoke tests
- [ ] Performance benchmarks
- [ ] Security scanning integration
