#!/bin/bash
set -euo pipefail

APP_PATH="${APP_PATH:-/myapp/actuator/health}"
NGINX_CONF="${NGINX_CONF:-/etc/nginx/conf.d/app.conf}"
BLUE_PORT="${BLUE_PORT:-8080}"
GREEN_PORT="${GREEN_PORT:-8081}"

ACTIVE="$(grep -oE '# ACTIVE: (blue|green)' "$NGINX_CONF" | awk '{print $3}')"
if [ "$ACTIVE" = "blue" ]; then
  NEXT="green"
  NEXT_PORT="$GREEN_PORT"
else
  NEXT="blue"
  NEXT_PORT="$BLUE_PORT"
fi

for _ in $(seq 1 20); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${NEXT_PORT}${APP_PATH}" || true)"
  [ "$code" = "200" ] && break
  sleep 3
done

if [ "${code:-}" != "200" ]; then
  echo "health check failed: ${NEXT}:${NEXT_PORT}"
  exit 1
fi

sudo sed -i "s/# ACTIVE: ${ACTIVE}/# ACTIVE: ${NEXT}/" "$NGINX_CONF"
sudo nginx -t
sudo systemctl reload nginx

echo "switched ${ACTIVE} -> ${NEXT}"
