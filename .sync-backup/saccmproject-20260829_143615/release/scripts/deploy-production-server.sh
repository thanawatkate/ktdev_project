#!/usr/bin/env bash
# Deploy SACCM backend + registry on a Linux VPS (run ON the server as deploy user).
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
PUBLIC_HOST="${PUBLIC_HOST:-ktdevelop.com}"
CORS_ORIGIN="${CORS_ORIGIN:-https://${PUBLIC_HOST}}"
SKIP_NPM_CI="${SKIP_NPM_CI:-0}"
SKIP_MIGRATE="${SKIP_MIGRATE:-0}"

BACKEND_ENV="${BACKEND_ENV:-$REPO_ROOT/backend/.env}"
REGISTRY_ENV="${REGISTRY_ENV:-$REPO_ROOT/registry-backend/.env}"

log() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v node >/dev/null 2>&1 || die "Node.js 18+ required"
command -v npm >/dev/null 2>&1 || die "npm required"

[[ -f "$BACKEND_ENV" ]] || die "Missing $BACKEND_ENV — create from release/templates/.env.production.example"
[[ -f "$REGISTRY_ENV" ]] || die "Missing $REGISTRY_ENV — create from registry-backend/.env.example"

patch_env() {
  local file="$1"
  local key="$2"
  local value="$3"
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

log "Patch production proxy/CORS for $PUBLIC_HOST"
patch_env "$BACKEND_ENV" TRUST_PROXY true
patch_env "$BACKEND_ENV" CORS_ORIGIN "$CORS_ORIGIN"
patch_env "$REGISTRY_ENV" TRUST_PROXY true
patch_env "$REGISTRY_ENV" CORS_ORIGIN "$CORS_ORIGIN"
patch_env "$REGISTRY_ENV" ONLINE_API_BASE "https://${PUBLIC_HOST}/saccapi/"

log "Production config preflight"
node "$REPO_ROOT/release/scripts/check-production-config.js" \
  --backend-env "$BACKEND_ENV" \
  --registry-env "$REGISTRY_ENV"

if [[ "$SKIP_NPM_CI" != "1" ]]; then
  log "backend npm ci"
  (cd "$REPO_ROOT/backend" && npm ci)
  log "registry-backend npm ci"
  (cd "$REPO_ROOT/registry-backend" && npm ci)
fi

if [[ "$SKIP_MIGRATE" != "1" ]]; then
  log "backend migrate"
  (cd "$REPO_ROOT/backend" && npm run migrate)
  log "registry migrate"
  (cd "$REPO_ROOT/registry-backend" && npm run migrate)
fi

if command -v pm2 >/dev/null 2>&1; then
  sudo mkdir -p /var/log/saccm
  sudo chown "$(whoami):$(whoami)" /var/log/saccm 2>/dev/null || true
  log "PM2 restart"
  (cd "$REPO_ROOT" && pm2 startOrReload release/deploy/ecosystem.config.cjs --update-env)
  pm2 save
else
  log "PM2 not installed — start manually: cd backend && npm start (3801), registry-backend && npm start (3802)"
fi

log "Local health checks"
curl -fsS "http://127.0.0.1:3801/saccapi" | head -c 200 && echo
curl -fsS "http://127.0.0.1:3802/registryapi" | head -c 200 && echo

log "Deploy complete. Configure nginx from release/deploy/nginx-saccm.conf.example then verify:"
echo "  node release/scripts/check-deployed-endpoints.js \\"
echo "    --backend-base https://${PUBLIC_HOST}/saccapi \\"
echo "    --registry-base https://${PUBLIC_HOST}/registryapi \\"
echo "    --origin ${CORS_ORIGIN}"
