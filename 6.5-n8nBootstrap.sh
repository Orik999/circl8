#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_SOURCE="6.5-n8nBootstrap.sh"
SCRIPT_VERSION="v1.0.1"
SCRIPT_UPDATED="2026-06-18"
SCRIPT_BUILD="sudo-nopasswd-alignment"

LOG_FILE="/var/log/circl8-n8n.log"
VERIFY_LOG="/var/log/circl8-n8n-verify.log"
COMPLETED_MARKER="/root/.circl8-n8n-template-preflight-completed"
DEPLOYED_MARKER="/root/.circl8-n8n-completed"

SCRIPT61_MARKER="/root/.circl8-platform-core-completed"
SCRIPT63_MARKER="/root/.circl8-authentik-completed"
SCRIPT64_MARKER="/root/.circl8-app-completed"

DEFAULT_N8N_VERSION="2.26.7"
DEFAULT_N8N_IMAGE="docker.n8n.io/n8nio/n8n:2.26.7"
DEFAULT_N8N_RUNNERS_IMAGE="n8nio/runners:2.26.7"
DEFAULT_N8N_POSTGRES_IMAGE="postgres:17-alpine"
DEFAULT_N8N_REDIS_IMAGE="redis:7-alpine"

umask 077
TMP_DIR="$(mktemp -d)"
CURRENT_PROGRESS=""
ENV_KEYS_ADDED=0
HANDOFF_STATUS="not-run"
ENV_STATUS="not-run"
DIR_STATUS="not-run"
TEMPLATE_STATUS="not-run"
STATIC_STATUS="not-run"
COMPOSE_CONFIG_STATUS="not-run"
MARKER_STATUS="not-written"

cleanup() {
  [[ -n "${CURRENT_PROGRESS}" ]] && printf '\r\033[K' || true
  rm -rf "${TMP_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

on_error() {
  local line="${1:-unknown}"
  [[ -n "${CURRENT_PROGRESS}" ]] && printf '\r\033[K' || true
  {
    echo "[$(date -Is)] ERROR ${SCRIPT_SOURCE} failed near line ${line}"
    echo "Status: failed"
    echo "Deployment: not-run"
  } >> "${LOG_FILE}" 2>/dev/null || true
  create_verification_report "FAIL"
  echo ""
  echo "FAILED"
  echo "  Script: ${SCRIPT_SOURCE} ${SCRIPT_VERSION}"
  echo "  Status: preflight failed"
  echo "  Deployment: not-run"
  echo "  Verify log: ${VERIFY_LOG}"
  exit 1
}
trap 'on_error ${LINENO}' ERR

section() {
  echo ""
  echo "$1"
}

row() {
  printf '  %-22s %s\n' "$1:" "$2"
}

msg_info() {
  CURRENT_PROGRESS="$1"
  printf '\r\033[K- %s' "$1"
}

msg_ok() {
  local msg="$1"
  printf '\r\033[K✓ %s\n' "$msg"
  CURRENT_PROGRESS=""
}

fail() {
  local msg="$1"
  [[ -n "${CURRENT_PROGRESS}" ]] && printf '\r\033[K' || true
  echo "ERROR: ${msg}" >&2
  exit 1
}

require_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    return 0
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    fail "Root privileges are required and sudo is not installed. Re-run as root or install/configure sudo NOPASSWD."
  fi

  msg_info "Checking sudo NOPASSWD access"
  if ! sudo -n true >/dev/null 2>&1; then
    fail "Passwordless sudo is required for remote Script 6.5 execution. Re-run as root or configure sudo NOPASSWD for this user."
  fi

  local script_path="${BASH_SOURCE[0]}"
  local sudo_script=""
  if [[ "${script_path}" == /dev/fd/* || "${script_path}" == /proc/*/fd/* ]]; then
    sudo_script="${TMP_DIR}/circl8-n8n-sudo-handoff.sh"
    cat "${script_path}" > "${sudo_script}" || fail "Could not copy script for sudo handoff."
    chmod 700 "${sudo_script}" || true
    msg_ok "SUDO ACCESS CONFIRMED"
    exec sudo -n -E bash -c 'script="$1"; handoff_dir="$2"; shift 2; trap '\''rm -f "$script"; rmdir "$handoff_dir" 2>/dev/null || true'\'' EXIT; bash "$script" "$@"' bash "${sudo_script}" "${TMP_DIR}" "$@"
  fi

  msg_ok "SUDO ACCESS CONFIRMED"
  exec sudo -n -E bash "${script_path}" "$@"
}

log_line() {
  printf '[%s] %s\n' "$(date -Is)" "$1" >> "${LOG_FILE}"
}

source_marker() {
  local marker="$1"
  [[ -f "${marker}" ]] || fail "Required marker not found: ${marker}"
  # shellcheck disable=SC1090
  set -a
  source "${marker}"
  set +a
}

get_env_value() {
  local key="$1"
  local env_file="$2"
  [[ -f "${env_file}" ]] || return 0
  awk -F= -v k="${key}" '$1 == k {sub(/^[^=]*=/, ""); print; exit}' "${env_file}"
}

set_env_key_if_missing() {
  local env_file="$1"
  local key="$2"
  local value="$3"
  touch "${env_file}"
  chmod 600 "${env_file}"
  if grep -qE "^${key}=" "${env_file}"; then
    return 0
  fi
  printf '%s=%s\n' "${key}" "${value}" >> "${env_file}"
  ENV_KEYS_ADDED=$((ENV_KEYS_ADDED + 1))
}

generate_secret() {
  local bytes="${1:-32}"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "${bytes}"
  else
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c $((bytes * 2))
    echo ""
  fi
}

version_at_least() {
  local have="$1"
  local need="$2"
  [[ "$(printf '%s\n%s\n' "${need}" "${have}" | sort -V | head -n1)" == "${need}" ]]
}

image_tag() {
  local image="$1"
  [[ "${image}" == *:* ]] || return 1
  printf '%s\n' "${image##*:}"
}

load_project_context() {
  DOCKER_DIR="${DOCKER_DIR:-${SCRIPT61_DOCKER_DIR:-}}"
  COMPOSE_DIR="${COMPOSE_DIR:-${SCRIPT61_COMPOSE_DIR:-}}"
  RAW_BASE_DEFAULT="${RAW_BASE_DEFAULT:-${SCRIPT61_RAW_BASE_DEFAULT:-${RAW_BASE:-}}}"
  PROJECT_SLUG="${PROJECT_SLUG:-${SCRIPT61_PROJECT_SLUG:-${SCRIPT64_PROJECT_SLUG:-circl8}}}"
  PROJECT_NAME="${PROJECT_NAME:-${SCRIPT61_PROJECT_NAME:-${SCRIPT64_PROJECT_NAME:-Project Circl8}}}"
  DOMAIN="${DOMAIN:-${SCRIPT61_DOMAIN:-${SCRIPT64_DOMAIN:-}}}"

  [[ -n "${DOCKER_DIR}" ]] || DOCKER_DIR="/opt/docker"
  [[ -n "${COMPOSE_DIR}" ]] || COMPOSE_DIR="${DOCKER_DIR}/compose"
  [[ -n "${RAW_BASE_DEFAULT}" ]] || RAW_BASE_DEFAULT=""

  ENV_FILE="${DOCKER_DIR}/.env"
  if [[ -f "${ENV_FILE}" ]]; then
    DOCKER_DIR="$(get_env_value DOCKER_DIR "${ENV_FILE}" || true)"
    DOCKER_DIR="${DOCKER_DIR:-/opt/docker}"
    COMPOSE_DIR="$(get_env_value COMPOSE_DIR "${ENV_FILE}" || true)"
    COMPOSE_DIR="${COMPOSE_DIR:-${DOCKER_DIR}/compose}"
    RAW_BASE_DEFAULT="$(get_env_value RAW_BASE_DEFAULT "${ENV_FILE}" || true)"
    RAW_BASE_DEFAULT="${RAW_BASE_DEFAULT:-${RAW_BASE:-}}"
    DOMAIN="$(get_env_value DOMAIN "${ENV_FILE}" || true)"
    DOMAIN="${DOMAIN:-${SCRIPT61_DOMAIN:-${SCRIPT64_DOMAIN:-}}}"
    PROJECT_SLUG="$(get_env_value PROJECT_SLUG "${ENV_FILE}" || true)"
    PROJECT_SLUG="${PROJECT_SLUG:-${SCRIPT61_PROJECT_SLUG:-${SCRIPT64_PROJECT_SLUG:-circl8}}}"
    PROJECT_NAME="$(get_env_value PROJECT_NAME "${ENV_FILE}" || true)"
    PROJECT_NAME="${PROJECT_NAME:-${SCRIPT61_PROJECT_NAME:-${SCRIPT64_PROJECT_NAME:-Project Circl8}}}"
  fi

  [[ -n "${DOMAIN}" ]] || fail "Base domain could not be derived from markers or .env."
  ENV_FILE="${DOCKER_DIR}/.env"
  TEMPLATE_SOURCE="docker/07-n8n-compose.yml"
  TEMPLATE_URL="${RAW_BASE_DEFAULT%/}/docker/07-n8n-compose.yml"
  RUNTIME_COMPOSE="${COMPOSE_DIR}/07-n8n-compose.yml"
  N8N_APPDATA="${DOCKER_DIR}/appdata/n8n"
  N8N_POSTGRES_DATA="${N8N_APPDATA}/postgres"
  N8N_REDIS_DATA="${N8N_APPDATA}/redis"
  N8N_STORAGE="${N8N_APPDATA}/storage"
}

check_handoff_gates() {
  msg_info "Checking handoff markers..."
  source_marker "${SCRIPT61_MARKER}"
  [[ "${SCRIPT61_STATUS:-}" == "completed" ]] || fail "Script 6.1 status is not completed."
  [[ "${SCRIPT61_VERIFY_STATUS:-}" == "PASS" ]] || fail "Script 6.1 verification is not PASS."

  source_marker "${SCRIPT63_MARKER}"
  [[ "${SCRIPT63_STATUS:-}" == "completed" ]] || fail "Script 6.3 status is not completed."
  [[ "${SCRIPT63_VERIFY_STATUS:-}" == "PASS" ]] || fail "Script 6.3 verification is not PASS."
  [[ "${SCRIPT63_FORWARD_AUTH:-}" == "ready" || "${SCRIPT63_TRAEFIK_FORWARD_AUTH:-}" == "ready" ]] || fail "Script 6.3 platform/admin ForwardAuth lane is not ready."

  source_marker "${SCRIPT64_MARKER}"
  [[ "${SCRIPT64_STATUS:-}" == "completed" ]] || fail "Script 6.4 status is not completed."
  [[ "${SCRIPT64_VERIFY_STATUS:-}" == "PASS" ]] || fail "Script 6.4 verification is not PASS."
  [[ "${SCRIPT64_READY_FOR_SCRIPT65:-}" == "yes" ]] || fail "Script 6.4 is not marked ready for Script 6.5."
  HANDOFF_STATUS="PASS"
  msg_ok "Handoff markers ready"
}

prepare_env() {
  msg_info "Preparing n8n env..."
  mkdir -p "$(dirname "${ENV_FILE}")"
  touch "${ENV_FILE}"
  chmod 600 "${ENV_FILE}"

  local existing_host existing_url existing_webhook n8n_host
  existing_host="$(get_env_value N8N_HOST "${ENV_FILE}" || true)"
  n8n_host="${existing_host:-n8n.${DOMAIN}}"
  existing_url="$(get_env_value N8N_URL "${ENV_FILE}" || true)"
  existing_webhook="$(get_env_value N8N_WEBHOOK_URL "${ENV_FILE}" || true)"

  set_env_key_if_missing "${ENV_FILE}" "N8N_VERSION" "${DEFAULT_N8N_VERSION}"
  set_env_key_if_missing "${ENV_FILE}" "N8N_IMAGE" "${DEFAULT_N8N_IMAGE}"
  set_env_key_if_missing "${ENV_FILE}" "N8N_RUNNERS_IMAGE" "${DEFAULT_N8N_RUNNERS_IMAGE}"
  set_env_key_if_missing "${ENV_FILE}" "N8N_POSTGRES_IMAGE" "${DEFAULT_N8N_POSTGRES_IMAGE}"
  set_env_key_if_missing "${ENV_FILE}" "N8N_REDIS_IMAGE" "${DEFAULT_N8N_REDIS_IMAGE}"
  set_env_key_if_missing "${ENV_FILE}" "N8N_HOST" "${n8n_host}"
  set_env_key_if_missing "${ENV_FILE}" "N8N_URL" "${existing_url:-https://${n8n_host}}"
  set_env_key_if_missing "${ENV_FILE}" "N8N_WEBHOOK_URL" "${existing_webhook:-https://${n8n_host}}"
  set_env_key_if_missing "${ENV_FILE}" "N8N_POSTGRES_DB" "n8n"
  set_env_key_if_missing "${ENV_FILE}" "N8N_POSTGRES_USER" "n8n"
  set_env_key_if_missing "${ENV_FILE}" "N8N_POSTGRES_PASSWORD" "$(generate_secret 24)"
  set_env_key_if_missing "${ENV_FILE}" "N8N_ENCRYPTION_KEY" "$(generate_secret 32)"
  set_env_key_if_missing "${ENV_FILE}" "N8N_RUNNERS_AUTH_TOKEN" "$(generate_secret 32)"
  set_env_key_if_missing "${ENV_FILE}" "N8N_LOG_LEVEL" "info"

  validate_image_pairing
  ENV_STATUS="PASS"
  msg_ok "n8n env ready"
}

validate_image_pairing() {
  local n8n_version n8n_image runners_image n8n_tag runner_tag
  n8n_version="$(get_env_value N8N_VERSION "${ENV_FILE}" || true)"
  n8n_image="$(get_env_value N8N_IMAGE "${ENV_FILE}" || true)"
  runners_image="$(get_env_value N8N_RUNNERS_IMAGE "${ENV_FILE}" || true)"
  n8n_version="${n8n_version:-${DEFAULT_N8N_VERSION}}"
  n8n_image="${n8n_image:-${DEFAULT_N8N_IMAGE}}"
  runners_image="${runners_image:-${DEFAULT_N8N_RUNNERS_IMAGE}}"

  [[ "${n8n_image}" != *":latest" ]] || fail "N8N_IMAGE must not use latest."
  [[ "${runners_image}" != *":latest" ]] || fail "N8N_RUNNERS_IMAGE must not use latest."
  n8n_tag="$(image_tag "${n8n_image}")" || fail "N8N_IMAGE must include an explicit tag."
  runner_tag="$(image_tag "${runners_image}")" || fail "N8N_RUNNERS_IMAGE must include an explicit tag."
  [[ "${n8n_tag}" == "${runner_tag}" ]] || fail "n8n and runner image tags must match."
  [[ "${n8n_tag}" == "${n8n_version}" ]] || fail "N8N_IMAGE tag must match N8N_VERSION."
  version_at_least "${n8n_version}" "1.111.0" || fail "External task runners require n8n >= 1.111.0."
}

prepare_directories() {
  msg_info "Preparing n8n directories..."
  mkdir -p "${COMPOSE_DIR}" "${N8N_APPDATA}" "${N8N_POSTGRES_DATA}" "${N8N_REDIS_DATA}" "${N8N_STORAGE}"
  chmod 700 "${N8N_APPDATA}" "${N8N_POSTGRES_DATA}" "${N8N_REDIS_DATA}" "${N8N_STORAGE}"
  DIR_STATUS="PASS"
  msg_ok "n8n directories ready"
}

sync_template() {
  msg_info "Syncing n8n compose template..."
  local source_path=""
  if [[ -f "${TEMPLATE_SOURCE}" ]]; then
    source_path="${TEMPLATE_SOURCE}"
  elif [[ -n "${TEMPLATE_URL}" && "${TEMPLATE_URL}" == http* ]] && command -v curl >/dev/null 2>&1; then
    source_path="${TMP_DIR}/07-n8n-compose.yml"
    curl -fsSL "${TEMPLATE_URL}" -o "${source_path}"
  else
    fail "n8n compose template not found: ${TEMPLATE_SOURCE}"
  fi
  install -m 600 "${source_path}" "${RUNTIME_COMPOSE}"
  TEMPLATE_STATUS="PASS"
  msg_ok "n8n compose template synced"
}

contains_regex() {
  local file="$1"
  local regex="$2"
  grep -Eq -- "${regex}" "${file}"
}

require_regex() {
  local file="$1"
  local regex="$2"
  local message="$3"
  contains_regex "${file}" "${regex}" || fail "${message}"
}

reject_regex() {
  local file="$1"
  local regex="$2"
  local message="$3"
  if contains_regex "${file}" "${regex}"; then
    fail "${message}"
  fi
}

validate_static_safety() {
  msg_info "Running static safety checks..."
  local compose="${RUNTIME_COMPOSE}"
  [[ -f "${compose}" ]] || fail "Rendered compose file missing."

  require_regex "${compose}" '^[[:space:]]{2}n8n-postgres:' "Compose missing n8n-postgres service."
  require_regex "${compose}" '^[[:space:]]{2}n8n-redis:' "Compose missing n8n-redis service."
  require_regex "${compose}" '^[[:space:]]{2}n8n:' "Compose missing n8n service."
  require_regex "${compose}" '^[[:space:]]{2}n8n-runner:' "Compose missing n8n-runner service."
  require_regex "${compose}" '^[[:space:]]{2}n8n-worker:' "Compose missing n8n-worker service."
  require_regex "${compose}" '^[[:space:]]{2}n8n-worker-runner:' "Compose missing n8n-worker-runner service."
  require_regex "${compose}" 'n8n-internal' "Compose missing private n8n network."
  require_regex "${compose}" 't2_proxy' "Compose missing platform proxy network reference."
  require_regex "${compose}" 'postgres:17-alpine' "Postgres image baseline is not present."
  require_regex "${compose}" 'redis:7-alpine' "Redis image baseline is not present."
  require_regex "${compose}" '2[.]26[.]7' "n8n 2.26.7 baseline is not present."
  require_regex "${compose}" 'EXECUTIONS_MODE.*queue|queue.*EXECUTIONS_MODE' "Queue mode is not enabled."
  require_regex "${compose}" 'N8N_RUNNERS_ENABLED.*true|true.*N8N_RUNNERS_ENABLED|OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS.*true|true.*OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS' "External runner settings are not present."
  require_regex "${compose}" '/webhook' "Production webhook route is not present."
  require_regex "${compose}" 'authentik|forwardauth|forward-auth|chain' "Protected platform/admin middleware reference is not present."

  reject_regex "${compose}" '^[[:space:]]{2}traefik:' "Compose must not bundle Traefik."
  reject_regex "${compose}" 'ports:' "Compose must not publish container ports."
  reject_regex "${compose}" 'docker[.]sock|/var/run/docker[.]sock' "Compose must not mount the Docker socket."
  reject_regex "${compose}" 'status-(trial|active|past-due|cancelled|suspended|deletion-requested)|plan-(starter|growth|pro)' "Compose must not reference customer status or plan groups."
  reject_regex "${compose}" 'app[.]circl8[.]co[.]uk|auth[.]circl8[.]co[.]uk|[.]circl8[.]co[.]uk' "Compose must not hardcode public identity values."
  reject_regex "${compose}" 'elastic[[:alpha:]]*|temporal[-]ui|[s]tripe' "Compose contains out-of-scope services or workflows."

  validate_service_network_scope "${compose}"
  validate_webhook_auth_scope "${compose}"
  validate_script_self_safety
  STATIC_STATUS="PASS"
  msg_ok "Static safety checks passed"
}

validate_service_network_scope() {
  local compose="$1"
  local attached_services invalid_services

  attached_services="$(awk '
    /^services:[[:space:]]*$/ {in_services=1; svc=""; in_networks=0; next}
    in_services && /^[A-Za-z0-9_-]+:/ {in_services=0; svc=""; in_networks=0}
    !in_services {next}
    /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {svc=$1; gsub(":", "", svc); in_networks=0; next}
    /^    networks:[[:space:]]*$/ {in_networks=1; next}
    in_networks && /^    [A-Za-z0-9_-]+:/ {in_networks=0}
    in_networks && /(^|[[:space:]-])t2_proxy([[:space:]]|$)/ {if (svc != "") print svc}
  ' "${compose}" | sort -u)"

  printf '%s\n' "${attached_services}" | grep -qx 'n8n' || fail "n8n service must be attached to t2_proxy."
  invalid_services="$(printf '%s\n' "${attached_services}" | grep -vx 'n8n' || true)"
  [[ -z "${invalid_services}" ]] || fail "t2_proxy must be attached only to the n8n service."
}

validate_webhook_auth_scope() {
  local compose="$1"
  local routers router middleware_lines

  routers="$(awk '
    /traefik[.]http[.]routers[.][A-Za-z0-9_-]+[.]rule/ && /\/webhook/ && !/\/webhook-test/ {
      line=$0
      sub(/^.*traefik[.]http[.]routers[.]/, "", line)
      sub(/[.]rule.*$/, "", line)
      print line
    }
  ' "${compose}" | sort -u)"

  [[ -n "${routers}" ]] || fail "Public production webhook route is missing."

  while IFS= read -r router; do
    [[ -n "${router}" ]] || continue
    middleware_lines="$(grep -E "traefik[.]http[.]routers[.]${router//./[.]}[.]middlewares" "${compose}" || true)"
    [[ -z "${middleware_lines}" ]] || fail "Production webhook route must not use Authentik middleware."
  done <<< "${routers}"

  if awk '
    /traefik[.]http[.]routers[.][A-Za-z0-9_-]+[.]rule/ && /\/webhook-test/ {
      line=$0
      sub(/^.*traefik[.]http[.]routers[.]/, "", line)
      sub(/[.]rule.*$/, "", line)
      print line
    }
  ' "${compose}" | while IFS= read -r router; do
    [[ -n "${router}" ]] || continue
    grep -E "traefik[.]http[.]routers[.]${router//./[.]}[.]middlewares" "${compose}" >/dev/null 2>&1 || exit 1
  done; then
    :
  else
    fail "webhook-test route must not be publicly exposed without platform/admin middleware."
  fi
}

validate_script_self_safety() {
  local script_path
  script_path="$(readlink -f "$0")"
  [[ -f "${script_path}" ]] || return 0
  reject_regex "${script_path}" 'docker[[:space:]]+compose[[:space:]]+(up|pull|down|restart|stop|rm)' "Script contains a forbidden Docker Compose lifecycle action."
  reject_regex "${script_path}" 'docker[[:space:]]+(image|volume|network|system)[[:space:]]+prune' "Script contains a forbidden prune action."
  reject_regex "${script_path}" 'docker[.]sock|/var/run/docker[.]sock' "Script contains a Docker socket reference."
  reject_regex "${script_path}" 'app[.]circl8[.]co[.]uk|auth[.]circl8[.]co[.]uk|[.]circl8[.]co[.]uk' "Script contains hardcoded public identity values."
  reject_regex "${script_path}" 'status-(trial|active|past-due|cancelled|suspended|deletion-requested)|plan-(starter|growth|pro)' "Script contains customer status or plan group references."
  reject_regex "${script_path}" '[s]tripe|postiz source|custom image build|elastic[[:alpha:]]*|temporal[-]ui' "Script contains out-of-scope workflow or app modification references."
}

validate_compose_config() {
  msg_info "Validating compose config..."
  if ! command -v docker >/dev/null 2>&1; then
    fail "Docker is required for compose config validation."
  fi
  docker compose -f "${RUNTIME_COMPOSE}" --env-file "${ENV_FILE}" config > "${TMP_DIR}/n8n-compose-config.out" 2> "${TMP_DIR}/n8n-compose-config.err" || {
    cat "${TMP_DIR}/n8n-compose-config.err" >> "${LOG_FILE}" 2>/dev/null || true
    fail "Docker Compose config validation failed. See ${LOG_FILE}."
  }
  COMPOSE_CONFIG_STATUS="PASS"
  msg_ok "Compose config valid"
}

write_marker() {
  msg_info "Writing preflight marker..."
  cat > "${COMPLETED_MARKER}" <<EOF_MARKER
SCRIPT65_STATUS=template-preflight-completed
SCRIPT65_VERSION=${SCRIPT_VERSION}
SCRIPT65_BUILD=${SCRIPT_BUILD}
SCRIPT65_VERIFY_STATUS=PASS
SCRIPT65_DEPLOYMENT=not-run
SCRIPT65_MARKER_WRITTEN=yes
SCRIPT65_READY_FOR_DEPLOYMENT_LANE=yes
SCRIPT65_READY_FOR_WORKFLOW_LANE=no
SCRIPT65_READY_FOR_SCRIPT66=no
SCRIPT65_PROJECT_SLUG=${PROJECT_SLUG}
SCRIPT65_PROJECT_NAME=${PROJECT_NAME}
SCRIPT65_N8N_HOST=$(get_env_value N8N_HOST "${ENV_FILE}" || true)
SCRIPT65_N8N_URL=$(get_env_value N8N_URL "${ENV_FILE}" || true)
SCRIPT65_N8N_WEBHOOK_URL=$(get_env_value N8N_WEBHOOK_URL "${ENV_FILE}" || true)
SCRIPT65_ENV_STATUS=ready
SCRIPT65_ENV_KEYS_ADDED=${ENV_KEYS_ADDED}
SCRIPT65_N8N_APPDATA=ready
SCRIPT65_N8N_POSTGRES_DATA=ready
SCRIPT65_N8N_REDIS_DATA=ready
SCRIPT65_N8N_STORAGE=ready
SCRIPT65_N8N_COMPOSE_TEMPLATE=synced
SCRIPT65_N8N_COMPOSE_CONFIG=valid
SCRIPT65_N8N_STATIC_SAFETY=pass
SCRIPT65_AUTHENTIK_LANE=platform-admin
SCRIPT65_AUTHENTIK_APPLICATION=not-used
SCRIPT65_AUTHENTIK_PROVIDER=not-used
SCRIPT65_AUTHENTIK_OUTPOST=preserved
EOF_MARKER
  chmod 600 "${COMPLETED_MARKER}"
  MARKER_STATUS="written"
  msg_ok "Preflight marker written"
}

create_verification_report() {
  local status="${1:-PASS}"
  {
    echo "Script: ${SCRIPT_SOURCE}"
    echo "Version: ${SCRIPT_VERSION}"
    echo "Build: ${SCRIPT_BUILD}"
    echo "Status: ${status}"
    echo "Deployment: not-run"
    echo "Handoff gates: ${HANDOFF_STATUS}"
    echo "Env keys added: ${ENV_KEYS_ADDED}"
    echo "Env status: ${ENV_STATUS}"
    echo "Appdata dirs: ${DIR_STATUS}"
    echo "Template: ${TEMPLATE_STATUS}"
    echo "Static safety: ${STATIC_STATUS}"
    echo "Compose config: ${COMPOSE_CONFIG_STATUS}"
    echo "Marker: ${MARKER_STATUS}"
    echo "Deployment marker written: no"
    echo "Containers started: no"
    echo "Authentik writes: no"
    echo "n8n workflows created: no"
  } > "${VERIFY_LOG}"
  chmod 600 "${VERIFY_LOG}"
}

print_banner() {
  clear 2>/dev/null || true
  echo "SCRIPT 6.5 n8n Bootstrap"
  echo "  Source:  ${SCRIPT_SOURCE}"
  echo "  Version: ${SCRIPT_VERSION}"
  echo "  Build:   ${SCRIPT_BUILD}"
  echo ""
  echo "Phase: template/preflight only"
  echo "Deployment: not-run"
}

print_plan() {
  section "PREFLIGHT PLAN"
  row "Handoff gates" "Script 6.1, 6.3, 6.4"
  row "Identity lane" "platform/admin"
  row "Template" "docker/07-n8n-compose.yml"
  row "Runtime compose" "${RUNTIME_COMPOSE}"
  row "Deployment" "not-run"
}

print_summary() {
  section "FINISHED"
  row "Source" "${SCRIPT_SOURCE}"
  row "Version" "${SCRIPT_VERSION}"
  row "Build" "${SCRIPT_BUILD}"
  echo ""
  echo "Preflight:"
  row "Handoff gates" "${HANDOFF_STATUS}"
  row "Env prepared" "${ENV_STATUS}"
  row "Appdata dirs" "${DIR_STATUS}"
  row "Template synced" "${TEMPLATE_STATUS}"
  row "Static safety" "${STATIC_STATUS}"
  row "Compose config" "${COMPOSE_CONFIG_STATUS}"
  echo ""
  echo "Deployment:"
  row "Status" "not-run"
  row "Containers started" "no"
  row "Authentik writes" "no"
  echo ""
  echo "Next:"
  row "Ready" "future Script 6.5 deploy lane patch"
  echo ""
  row "Verify log" "${VERIFY_LOG}"
  row "Marker" "${COMPLETED_MARKER}"
}

main() {
  require_root "$@"
  : > "${LOG_FILE}"
  chmod 600 "${LOG_FILE}" 2>/dev/null || true
  log_line "Starting ${SCRIPT_SOURCE} ${SCRIPT_VERSION} ${SCRIPT_BUILD}"
  print_banner
  check_handoff_gates
  load_project_context
  print_plan
  prepare_env
  prepare_directories
  sync_template
  validate_static_safety
  validate_compose_config
  write_marker
  create_verification_report "PASS"
  print_summary
}

main "$@"
