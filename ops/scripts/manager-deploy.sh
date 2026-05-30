#!/bin/bash
set -euo pipefail

MANAGER_URL="${MANAGER_URL:-http://127.0.0.1:8080/manager/text}"
APP_PATH="${APP_PATH:-/myapp}"
WAR_FILE="${1:?usage: manager-deploy.sh /path/to/app.war}"
CRED_FILE="${CRED_FILE:-/etc/tomcat-manager-credentials}"

if [ ! -f "$CRED_FILE" ]; then
  echo "missing credential file: $CRED_FILE"
  exit 1
fi

CRED="$(cat "$CRED_FILE")"

curl -sf -u "$CRED" \
  --upload-file "$WAR_FILE" \
  "${MANAGER_URL}/deploy?path=${APP_PATH}&update=true"

curl -sf -u "$CRED" "${MANAGER_URL}/list" | grep "^${APP_PATH}:"
