FROM kong/kong-gateway:3.13.0.0
LABEL maintainer="SyncScope Team"
LABEL description="Kong API Gateway for SyncScope - Railway Deployment"
LABEL version="1.0.0"

ENV KONG_DATABASE=postgres
ENV KONG_PG_HOST=${KONG_PG_HOST}
ENV KONG_PG_PORT=${KONG_PG_PORT:-5432}
ENV KONG_PG_USER=${KONG_PG_USER:-postgres}
ENV KONG_PG_PASSWORD=${KONG_PG_PASSWORD}
ENV KONG_PG_DATABASE=${KONG_PG_DATABASE:-kong}
ENV KONG_PROXY_ACCESS_LOG=/dev/stdout
ENV KONG_ADMIN_ACCESS_LOG=/dev/stdout
ENV KONG_PROXY_ERROR_LOG=/dev/stderr
ENV KONG_ADMIN_ERROR_LOG=/dev/stderr
ENV KONG_LOG_LEVEL=${KONG_LOG_LEVEL:-info}
ENV KONG_ADMIN_LISTEN="0.0.0.0:8081"
ENV KONG_DECLARATIVE_CONFIG=/etc/kong/kong.yml
ENV KONG_NGINX_WORKER_PROCESSES=${KONG_NGINX_WORKER_PROCESSES:-auto}
ENV KONG_NGINX_DAEMON=off
ENV KONG_SSL_CIPHER_SUITE=${KONG_SSL_CIPHER_SUITE:-intermediate}
ENV KONG_SERVER_TOKENS_HEADER=off
ENV KONG_REAL_IP_HEADER=X-Forwarded-For
ENV KONG_TRUSTED_IPS="0.0.0.0/0,::/0"
ENV KONG_PLUGINS=${KONG_PLUGINS:-bundled,pre-function}

USER root

# Copy Kong configuration
COPY kong.yml /etc/kong/kong.yml
COPY start.sh /usr/local/bin/start.sh

# Make startup script executable
RUN chmod +x /usr/local/bin/start.sh

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
  CMD kong health

EXPOSE 8080 8081 8443

CMD ["/bin/sh", "/usr/local/bin/start.sh"]