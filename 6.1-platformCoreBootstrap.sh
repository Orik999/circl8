#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Project Circl8 - Script 6.1 Platform Core Bootstrap
# =========================================================

YW="$(printf '\033[33m')"
BL="$(printf '\033[36m')"
RD="$(printf '\033[01;31m')"
GN="$(printf '\033[1;92m')"
ANS="$(printf '\033[1;95m')"
CL="$(printf '\033[m')"
CLF="$(printf '\033[5m')"
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
WARN="${YW}!${CL}"
CROSS="${RD}✗${CL}"
BORDER="${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"

SCRIPT_SOURCE="6.1-platformCoreBootstrap.sh"
SCRIPT_VERSION="v1.0.2"
SCRIPT_UPDATED="2026-06-10"
SCRIPT_BUILD="confirm-before-apply-flow"

T=15
LOG_FILE="/var/log/circl8-platform-core.log"
RUNTIME_LOG_FILE=""
VERIFY_LOG="/var/log/circl8-platform-core-verify.log"
COMPLETED_MARKER="/root/.circl8-platform-core-completed"
SCRIPT6_MARKER="/root/.docker-env-setup-completed"

SUDO_CMD=""
LOGGING_ENABLED="no"
VERIFY_STATUS="not-run"
VERIFY_PASS_COUNT="0"
VERIFY_WARN_COUNT="0"
VERIFY_FAIL_COUNT="0"
VERIFY_FIRST_ISSUE_TYPE=""
VERIFY_FIRST_ISSUE_CHECK=""
VERIFY_FIRST_ISSUE_REASON=""
VERIFY_FIRST_ISSUE_FIX=""

SCRIPT6_STATUS="missing"
SCRIPT6_VERSION="unknown"
SCRIPT6_BUILD="unknown"
SCRIPT6_VERIFY_STATUS="missing"
SCRIPT6_DOCKER_USER=""
SCRIPT6_DOCKER_DIR=""
SCRIPT6_COMPOSE_DIR=""
SCRIPT6_SECRETS_DIR=""
SCRIPT6_DOMAIN=""
SCRIPT6_TIMEZONE=""
SCRIPT6_TRAEFIK_CONFIG_READY="no"
SCRIPT6_TRAEFIK_ACME_READY="no"
SCRIPT6_CF_TOKEN_FILE_READY="unknown"
SCRIPT6_ENV_FILE_READY="no"
SCRIPT6_SECRETS_READY="no"
SCRIPT6_READY_FOR_SCRIPT61="no"
SCRIPT6_CROWDSEC_SELECTED="unknown"
SCRIPT6_CROWDSEC_BOUNCER="unknown"

DOCKER_USER=""
DOCKER_DIR=""
COMPOSE_DIR=""
SECRETS_DIR=""
DOMAIN_VALUE=""
ENV_FILE=""
TRAEFIK_STATIC_CONFIG_FILE=""
TRAEFIK_DYNAMIC_CONFIG_FILE=""
TRAEFIK_ACME_FILE=""
CF_API_TOKEN_FILE=""
CF_SERVICES_ENABLED="no"

RAW_BASE="${CIRCL8_RAW_BASE:-https://raw.githubusercontent.com/Orik999/circl8/refs/heads/main}"
SCRIPT_DIR=""
TEMP_FILES=()
TEMP_DIRS=()

COMPOSE_SOCKET_PROXY="00-socket-proxy-compose.yml"
COMPOSE_TRAEFIK="01-traefik-compose.yml"
COMPOSE_CF_DDNS="02-cf-ddns-compose.yml"
COMPOSE_CF_COMPANION="03-cf-companion-compose.yml"
CORE_COMPOSE_FILES=("$COMPOSE_SOCKET_PROXY" "$COMPOSE_TRAEFIK" "$COMPOSE_CF_DDNS" "$COMPOSE_CF_COMPANION")

PROJECT_SOCKET_PROXY="circl8-socket-proxy"
PROJECT_TRAEFIK="circl8-traefik"
PROJECT_CF_DDNS="circl8-cf-ddns"
PROJECT_CF_COMPANION="circl8-cf-companion"

SCRIPT61_NETWORK_T2_PROXY="no"
SCRIPT61_NETWORK_SOCKET_PROXY="no"
SCRIPT61_SOCKET_PROXY="unknown"
SCRIPT61_TRAEFIK="unknown"
SCRIPT61_CF_DDNS="unknown"
SCRIPT61_CF_COMPANION="unknown"
SCRIPT61_TRAEFIK_CONFIG_READY="no"
SCRIPT61_TRAEFIK_ACME_READY="no"
SCRIPT61_PORT_80="unknown"
SCRIPT61_PORT_443="unknown"
SCRIPT61_READY_FOR_SCRIPT62="no"
SCRIPT61_READY_FOR_SCRIPT63="no"
SCRIPT61_READY_FOR_SCRIPT64="no"
SCRIPT61_READY_FOR_SCRIPT65="no"
SCRIPT61_READY_FOR_SCRIPT66="no"

function header_info() {
cat <<'EOF'

   ██████╗     ██╗        ██████╗ ██████╗ ██████╗ ███████╗
  ██╔════╝    ███║       ██╔════╝██╔═══██╗██╔══██╗██╔════╝
  ███████╗    ╚██║       ██║     ██║   ██║██████╔╝█████╗
  ██╔═══██╗    ██║       ██║     ██║   ██║██╔══██╗██╔══╝
  ╚██████╔╝    ██║       ╚██████╗╚██████╔╝██║  ██║███████╗
   ╚═════╝     ╚═╝        ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝

                         6.1-CORE
EOF
}

function show_script_version() {
    echo -e "${GN}SCRIPT VERSION: ${SCRIPT_VERSION} | UPDATED: ${SCRIPT_UPDATED} | BUILD: ${SCRIPT_BUILD}${CL}"
    echo -e "${BL}SOURCE: ${SCRIPT_SOURCE}${CL}"
}

function section() { echo ""; echo -e "${BORDER}"; echo -e "${BL}$1${CL}"; echo -e "${BORDER}"; }
function section_flash_success() { echo ""; echo -e "${BORDER}"; echo -e "${GN}${CLF}$1${CL}"; echo -e "${BORDER}"; }
function msg_info() { echo -ne " ${HOLD} ${YW}$1...${CL}"; }
function msg_ok() { echo -e "${BFR} ${CM} ${GN}$1${CL}"; }
function msg_warn() { echo -e "${BFR} ${WARN} ${YW}$1${CL}"; }
function msg_error() { echo -e "${BFR} ${CROSS} ${RD}$1${CL}"; exit 1; }

function aligned_status_line() {
    local label="$1" value="${2:-unknown}" color="${3:-}" width="${4:-24}"
    [ -n "$value" ] || value="unknown"
    [ -n "$color" ] || color="$(status_color_for_value "$value")"
    printf '  %b%-*s%b %b%s%b\n' "$BL" "$width" "${label}:" "$CL" "$color" "$value" "$CL"
}

function final_line() {
    local label="$1" value="${2:-not configured}" color="${3:-$GN}"
    [ -n "$value" ] || value="not configured"
    printf '  %b%-24s%b %b%s%b\n' "$BL" "${label}:" "$CL" "$color" "$value" "$CL"
}

function status_color_for_value() {
    local value="${1:-unknown}"
    case "$value" in
        PASS|completed|active|running|healthy|yes|ready|listening|preserved|active/running) printf '%s' "$GN" ;;
        PASS_WITH_WARNINGS|skipped|unknown|not-listening) printf '%s' "$YW" ;;
        FAIL|failed|missing|no|inactive|not-ready) printf '%s' "$RD" ;;
        *) printf '%s' "$GN" ;;
    esac
}

function trim_value() {
    local value="${1:-}"
    value="${value//$'\r'/}"
    value="${value//$'\n'/}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

function strip_outer_quotes() {
    local value="$(trim_value "${1:-}")"
    if [ "${#value}" -ge 2 ]; then
        local first="${value:0:1}" last="${value: -1}"
        if { [ "$first" = '"' ] && [ "$last" = '"' ]; } || { [ "$first" = "'" ] && [ "$last" = "'" ]; }; then
            value="${value:1:${#value}-2}"
        fi
    fi
    trim_value "$value"
}

function marker_safe_value() { strip_outer_quotes "${1:-}"; }

function cleanup() {
    local exit_code="$?" file=""
    if [ -n "${SUDO_CMD:-}" ] && [ -n "${RUNTIME_LOG_FILE:-}" ] && [ -s "$RUNTIME_LOG_FILE" ]; then
        "$SUDO_CMD" cp "$RUNTIME_LOG_FILE" "$LOG_FILE" 2>/dev/null || true
        "$SUDO_CMD" chmod 0644 "$LOG_FILE" 2>/dev/null || true
    fi
    for file in "${TEMP_FILES[@]:-}"; do [ -n "$file" ] && [ -f "$file" ] && rm -f "$file" 2>/dev/null || true; done
    for file in "${TEMP_DIRS[@]:-}"; do [ -n "$file" ] && [ -d "$file" ] && rm -rf "$file" 2>/dev/null || true; done
    exit "$exit_code"
}

function on_error() { echo -e "${RD}ERROR:${CL} Script failed at line $1. Check ${LOG_FILE}"; }

function detect_root_or_sudo() { if [ "$EUID" -eq 0 ]; then SUDO_CMD=""; else SUDO_CMD="sudo"; fi; }
function root_path_exists() { if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" test -e "$1"; else test -e "$1"; fi; }
function root_file_not_empty() { if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" test -s "$1"; else test -s "$1"; fi; }
function root_read_file() { if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" cat "$1"; else cat "$1"; fi; }
function root_stat_mode() { if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" stat -c '%a' "$1" 2>/dev/null || true; else stat -c '%a' "$1" 2>/dev/null || true; fi; }
function write_root_file() { if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" tee "$1" >/dev/null; else cat > "$1"; fi; }

function run_cmd() {
    local description="$1"; shift
    local err_file="$(mktemp)"
    TEMP_FILES+=("$err_file")
    if [ -n "$SUDO_CMD" ]; then
        if ! "$SUDO_CMD" "$@" > /dev/null 2> "$err_file"; then
            echo ""; echo -e "${RD}Command failed during:${CL} ${description}"; echo -e "${YW}Command:${CL} sudo $*"; cat "$err_file"; exit 1
        fi
    else
        if ! "$@" > /dev/null 2> "$err_file"; then
            echo ""; echo -e "${RD}Command failed during:${CL} ${description}"; echo -e "${YW}Command:${CL} $*"; cat "$err_file"; exit 1
        fi
    fi
    rm -f "$err_file"
}

function init_logging() {
    exec 3>&1
    exec 4>&2
    if [ -n "$SUDO_CMD" ]; then
        RUNTIME_LOG_FILE="$(mktemp /tmp/circl8-platform-core-log.XXXXXX)"
        TEMP_FILES+=("$RUNTIME_LOG_FILE")
        exec > >(tee -a "$RUNTIME_LOG_FILE") 2>&1
    else
        RUNTIME_LOG_FILE="$LOG_FILE"
        exec > >(tee -a "$LOG_FILE") 2>&1
    fi
    LOGGING_ENABLED="yes"
}

function validate_sudo_access() {
    if [ -n "$SUDO_CMD" ]; then
        msg_info "Validating sudo access"
        if "$SUDO_CMD" -n true >/dev/null 2>&1 || "$SUDO_CMD" -v; then msg_ok "SUDO ACCESS CONFIRMED"; else msg_error "Sudo authentication failed"; fi
    fi
}

function validate_dependencies() {
    local cmds=(awk cat chmod command cp cut date grep id mkdir mktemp rm sed sort stat tee test tr)
    local cmd=""
    for cmd in "${cmds[@]}"; do command -v "$cmd" >/dev/null 2>&1 || msg_error "Required command not found: ${cmd}"; done
    if [ -n "$SUDO_CMD" ]; then command -v sudo >/dev/null 2>&1 || msg_error "sudo is required when not running as root"; fi
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then msg_error "curl or wget is required to fetch compose files when local copies are absent"; fi
}

function validate_linux_username() { [[ "${1:-}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; }
function validate_domain() { [[ "${1:-}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]]; }

function marker_key_value() {
    local key="$1" file="$2" value=""
    if root_path_exists "$file"; then
        value="$(marker_safe_value "$(root_read_file "$file" 2>/dev/null | awk -F= -v key="$key" '$1 == key { $1=""; sub(/^=/, ""); print; exit }')")"
    fi
    printf '%s' "$value"
}

function env_key_value() {
    local key="$1" value=""
    if root_path_exists "$ENV_FILE"; then
        value="$(marker_safe_value "$(root_read_file "$ENV_FILE" 2>/dev/null | awk -F= -v key="$key" '$1 == key { $1=""; sub(/^=/, ""); print; exit }')")"
    fi
    printf '%s' "$value"
}

function init_script() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    detect_root_or_sudo
    validate_sudo_access
    init_logging
    trap 'on_error "$LINENO"' ERR
    trap cleanup EXIT
    clear || true
    header_info
    show_script_version
    validate_dependencies
}

function load_script6_marker() {
    SCRIPT6_STATUS="$(marker_key_value SCRIPT6_STATUS "$SCRIPT6_MARKER")"; [ -n "$SCRIPT6_STATUS" ] || SCRIPT6_STATUS="missing"
    SCRIPT6_VERSION="$(marker_key_value SCRIPT6_VERSION "$SCRIPT6_MARKER")"; [ -n "$SCRIPT6_VERSION" ] || SCRIPT6_VERSION="unknown"
    SCRIPT6_BUILD="$(marker_key_value SCRIPT6_BUILD "$SCRIPT6_MARKER")"; [ -n "$SCRIPT6_BUILD" ] || SCRIPT6_BUILD="unknown"
    SCRIPT6_VERIFY_STATUS="$(marker_key_value SCRIPT6_VERIFY_STATUS "$SCRIPT6_MARKER")"; [ -n "$SCRIPT6_VERIFY_STATUS" ] || SCRIPT6_VERIFY_STATUS="missing"
    SCRIPT6_DOCKER_USER="$(marker_key_value SCRIPT6_DOCKER_USER "$SCRIPT6_MARKER")"
    SCRIPT6_DOCKER_DIR="$(marker_key_value SCRIPT6_DOCKER_DIR "$SCRIPT6_MARKER")"
    SCRIPT6_COMPOSE_DIR="$(marker_key_value SCRIPT6_COMPOSE_DIR "$SCRIPT6_MARKER")"
    SCRIPT6_SECRETS_DIR="$(marker_key_value SCRIPT6_SECRETS_DIR "$SCRIPT6_MARKER")"
    SCRIPT6_DOMAIN="$(marker_key_value SCRIPT6_DOMAIN "$SCRIPT6_MARKER")"
    SCRIPT6_TIMEZONE="$(marker_key_value SCRIPT6_TIMEZONE "$SCRIPT6_MARKER")"
    SCRIPT6_TRAEFIK_CONFIG_READY="$(marker_key_value SCRIPT6_TRAEFIK_CONFIG_READY "$SCRIPT6_MARKER")"; [ -n "$SCRIPT6_TRAEFIK_CONFIG_READY" ] || SCRIPT6_TRAEFIK_CONFIG_READY="no"
    SCRIPT6_TRAEFIK_ACME_READY="$(marker_key_value SCRIPT6_TRAEFIK_ACME_READY "$SCRIPT6_MARKER")"; [ -n "$SCRIPT6_TRAEFIK_ACME_READY" ] || SCRIPT6_TRAEFIK_ACME_READY="no"
    SCRIPT6_CF_TOKEN_FILE_READY="$(marker_key_value SCRIPT6_CF_TOKEN_FILE_READY "$SCRIPT6_MARKER")"; [ -n "$SCRIPT6_CF_TOKEN_FILE_READY" ] || SCRIPT6_CF_TOKEN_FILE_READY="unknown"
    SCRIPT6_ENV_FILE_READY="$(marker_key_value SCRIPT6_ENV_FILE_READY "$SCRIPT6_MARKER")"; [ -n "$SCRIPT6_ENV_FILE_READY" ] || SCRIPT6_ENV_FILE_READY="no"
    SCRIPT6_SECRETS_READY="$(marker_key_value SCRIPT6_SECRETS_READY "$SCRIPT6_MARKER")"; [ -n "$SCRIPT6_SECRETS_READY" ] || SCRIPT6_SECRETS_READY="no"
    SCRIPT6_READY_FOR_SCRIPT61="$(marker_key_value SCRIPT6_READY_FOR_SCRIPT61 "$SCRIPT6_MARKER")"; [ -n "$SCRIPT6_READY_FOR_SCRIPT61" ] || SCRIPT6_READY_FOR_SCRIPT61="no"
    SCRIPT6_CROWDSEC_SELECTED="$(marker_key_value SCRIPT6_CROWDSEC_SELECTED "$SCRIPT6_MARKER")"; [ -n "$SCRIPT6_CROWDSEC_SELECTED" ] || SCRIPT6_CROWDSEC_SELECTED="unknown"
    SCRIPT6_CROWDSEC_BOUNCER="$(marker_key_value SCRIPT6_CROWDSEC_BOUNCER "$SCRIPT6_MARKER")"; [ -n "$SCRIPT6_CROWDSEC_BOUNCER" ] || SCRIPT6_CROWDSEC_BOUNCER="unknown"

    DOCKER_USER="$SCRIPT6_DOCKER_USER"
    DOCKER_DIR="$SCRIPT6_DOCKER_DIR"
    COMPOSE_DIR="$SCRIPT6_COMPOSE_DIR"
    SECRETS_DIR="$SCRIPT6_SECRETS_DIR"
    DOMAIN_VALUE="$SCRIPT6_DOMAIN"
    ENV_FILE="${DOCKER_DIR}/.env"
}

function refresh_env_paths() {
    local value=""
    [ -n "$ENV_FILE" ] || ENV_FILE="${DOCKER_DIR}/.env"
    value="$(env_key_value TRAEFIK_STATIC_CONFIG_FILE)"; [ -n "$value" ] && TRAEFIK_STATIC_CONFIG_FILE="$value"
    value="$(env_key_value TRAEFIK_DYNAMIC_CONFIG_FILE)"; [ -n "$value" ] && TRAEFIK_DYNAMIC_CONFIG_FILE="$value"
    value="$(env_key_value TRAEFIK_ACME_STORAGE)"; [ -n "$value" ] && TRAEFIK_ACME_FILE="$value"
    value="$(env_key_value CF_API_TOKEN_FILE)"; [ -n "$value" ] && CF_API_TOKEN_FILE="$value"
    [ -n "$TRAEFIK_STATIC_CONFIG_FILE" ] || TRAEFIK_STATIC_CONFIG_FILE="${DOCKER_DIR}/appdata/traefik/traefik.yml"
    [ -n "$TRAEFIK_DYNAMIC_CONFIG_FILE" ] || TRAEFIK_DYNAMIC_CONFIG_FILE="${DOCKER_DIR}/appdata/traefik/dynamic-config.yml"
    [ -n "$TRAEFIK_ACME_FILE" ] || TRAEFIK_ACME_FILE="${DOCKER_DIR}/appdata/traefik/acme/acme.json"
    [ -n "$CF_API_TOKEN_FILE" ] || CF_API_TOKEN_FILE="${SECRETS_DIR}/cf_api_token"
    if [ "$SCRIPT6_CF_TOKEN_FILE_READY" = "yes" ] && root_file_not_empty "$CF_API_TOKEN_FILE"; then CF_SERVICES_ENABLED="yes"; else CF_SERVICES_ENABLED="no"; fi
}

function docker_compose_cmd() { docker compose --env-file "$ENV_FILE" "$@"; }

function docker_service_active() { systemctl is-active docker 2>/dev/null || true; }
function containerd_service_active() { systemctl is-active containerd 2>/dev/null || true; }

function validate_script6_handoff() {
    local failure="no"
    section "SCRIPT 6 HANDOFF"
    load_script6_marker
    refresh_env_paths

    echo -e "${YW}Script 6:${CL}"
    aligned_status_line "Status" "$SCRIPT6_STATUS" "$(status_color_for_value "$SCRIPT6_STATUS")" 26
    aligned_status_line "Version" "$SCRIPT6_VERSION" "$GN" 26
    aligned_status_line "Verification" "$SCRIPT6_VERIFY_STATUS" "$(status_color_for_value "$SCRIPT6_VERIFY_STATUS")" 26
    aligned_status_line "Ready for Script 6.1" "$SCRIPT6_READY_FOR_SCRIPT61" "$(status_color_for_value "$SCRIPT6_READY_FOR_SCRIPT61")" 26
    echo ""
    echo -e "${YW}Prepared environment:${CL}"
    aligned_status_line "Docker user" "${DOCKER_USER:-missing}" "$(status_color_for_value "${DOCKER_USER:-missing}")" 26
    aligned_status_line "Docker dir" "${DOCKER_DIR:-missing}" "$GN" 26
    aligned_status_line "Compose dir" "${COMPOSE_DIR:-missing}" "$GN" 26
    aligned_status_line "Secrets dir" "${SECRETS_DIR:-missing}" "$GN" 26
    aligned_status_line "Domain" "${DOMAIN_VALUE:-missing}" "$GN" 26
    echo ""
    echo -e "${YW}Runtime handoff:${CL}"
    aligned_status_line "Traefik config" "$SCRIPT6_TRAEFIK_CONFIG_READY" "$(status_color_for_value "$SCRIPT6_TRAEFIK_CONFIG_READY")" 26
    aligned_status_line "Traefik ACME" "$SCRIPT6_TRAEFIK_ACME_READY" "$(status_color_for_value "$SCRIPT6_TRAEFIK_ACME_READY")" 26
    aligned_status_line "Cloudflare token file" "$SCRIPT6_CF_TOKEN_FILE_READY" "$(status_color_for_value "$SCRIPT6_CF_TOKEN_FILE_READY")" 26

    root_path_exists "$SCRIPT6_MARKER" || { msg_warn "Script 6 marker missing: ${SCRIPT6_MARKER}"; failure="yes"; }
    [ "$SCRIPT6_STATUS" = "completed" ] || { msg_warn "Script 6 marker is not completed"; failure="yes"; }
    [ "$SCRIPT6_VERIFY_STATUS" = "PASS" ] || { msg_warn "Script 6 verification is not PASS"; failure="yes"; }
    [ "$SCRIPT6_READY_FOR_SCRIPT61" = "yes" ] || { msg_warn "Script 6 marker is not ready for Script 6.1"; failure="yes"; }
    validate_linux_username "$DOCKER_USER" && [ "$DOCKER_USER" != "root" ] && id "$DOCKER_USER" >/dev/null 2>&1 || { msg_warn "Valid non-root Docker user could not be derived"; failure="yes"; }
    validate_domain "$DOMAIN_VALUE" || { msg_warn "Script 6 domain is invalid or missing"; failure="yes"; }

    [ "$failure" = "no" ] || { echo ""; echo -e "${RD}Script 6.1 cannot continue until Script 6 handoff is healthy.${CL}"; exit 1; }
    msg_ok "SCRIPT 6 HANDOFF VERIFIED"
}

function port_owner_line() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -H -ltnp "sport = :${port}" 2>/dev/null | head -n1 || true
    elif command -v lsof >/dev/null 2>&1; then
        lsof -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null | tail -n +2 | head -n1 || true
    else
        printf ''
    fi
}

function port_non_platform_blocker() {
    local port="$1" line=""
    line="$(port_owner_line "$port")"
    [ -z "$line" ] && return 1
    if grep -Eiq 'docker-proxy|traefik|com.docker' <<< "$line"; then return 1; fi
    printf '%s' "$line"
    return 0
}

function validate_preflight_runtime() {
    local failure="no" blocker=""
    section "RUNTIME PREFLIGHT"

    if command -v docker >/dev/null 2>&1; then aligned_status_line "Docker command" "ready" "$GN" 24; else aligned_status_line "Docker command" "missing" "$RD" 24; failure="yes"; fi
    if docker compose version >/dev/null 2>&1; then aligned_status_line "Docker Compose" "ready" "$GN" 24; else aligned_status_line "Docker Compose" "missing" "$RD" 24; failure="yes"; fi
    aligned_status_line "Docker service" "$(docker_service_active)" "$(status_color_for_value "$(docker_service_active)")" 24
    aligned_status_line "containerd" "$(containerd_service_active)" "$(status_color_for_value "$(containerd_service_active)")" 24
    [ "$(docker_service_active)" = "active" ] || failure="yes"
    [ "$(containerd_service_active)" = "active" ] || failure="yes"

    root_path_exists "$DOCKER_DIR" && aligned_status_line "Docker dir" "present" "$GN" 24 || { aligned_status_line "Docker dir" "missing" "$RD" 24; failure="yes"; }
    if root_path_exists "$COMPOSE_DIR"; then
        aligned_status_line "Compose dir" "present" "$GN" 24
    elif root_path_exists "$DOCKER_DIR"; then
        aligned_status_line "Compose dir" "will create" "$YW" 24
    else
        aligned_status_line "Compose dir" "missing" "$RD" 24
        failure="yes"
    fi
    root_path_exists "$SECRETS_DIR" && aligned_status_line "Secrets dir" "present" "$GN" 24 || { aligned_status_line "Secrets dir" "missing" "$RD" 24; failure="yes"; }
    root_path_exists "$ENV_FILE" && aligned_status_line ".env file" "present" "$GN" 24 || { aligned_status_line ".env file" "missing" "$RD" 24; failure="yes"; }
    root_path_exists "$TRAEFIK_STATIC_CONFIG_FILE" && aligned_status_line "Traefik static config" "present" "$GN" 24 || { aligned_status_line "Traefik static config" "missing" "$RD" 24; failure="yes"; }
    root_path_exists "$TRAEFIK_DYNAMIC_CONFIG_FILE" && aligned_status_line "Traefik dynamic config" "present" "$GN" 24 || { aligned_status_line "Traefik dynamic config" "missing" "$RD" 24; failure="yes"; }
    if root_path_exists "$TRAEFIK_ACME_FILE" && [ "$(root_stat_mode "$TRAEFIK_ACME_FILE")" = "600" ]; then aligned_status_line "acme.json" "600" "$GN" 24; else aligned_status_line "acme.json" "not-ready" "$RD" 24; failure="yes"; fi
    if [ "$SCRIPT6_CF_TOKEN_FILE_READY" = "yes" ]; then root_file_not_empty "$CF_API_TOKEN_FILE" && aligned_status_line "Cloudflare token file" "present" "$GN" 24 || { aligned_status_line "Cloudflare token file" "missing" "$RD" 24; failure="yes"; }; else aligned_status_line "Cloudflare token file" "skipped" "$YW" 24; fi
    aligned_status_line "Compose files" "will install" "$YW" 24

    blocker="$(port_non_platform_blocker 80 || true)"
    if [ -n "$blocker" ]; then aligned_status_line "Port 80 preflight" "blocked" "$RD" 24; echo -e "  ${YW}${blocker}${CL}"; failure="yes"; else aligned_status_line "Port 80 preflight" "available/platform" "$GN" 24; fi
    blocker="$(port_non_platform_blocker 443 || true)"
    if [ -n "$blocker" ]; then aligned_status_line "Port 443 preflight" "blocked" "$RD" 24; echo -e "  ${YW}${blocker}${CL}"; failure="yes"; else aligned_status_line "Port 443 preflight" "available/platform" "$GN" 24; fi

    [ "$failure" = "no" ] || msg_error "Runtime preflight failed. Fix the checks above, then rerun Script 6.1."
    msg_ok "RUNTIME PREFLIGHT PASSED"
}

function download_file() {
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then curl -fsSL "$url" -o "$dest"; else wget -qO "$dest" "$url"; fi
}

function install_compose_file() {
    local filename="${1:-}"
    local local_source=""
    local url=""
    local dest=""
    local tmp=""
    local display_name=""

    [ -n "$filename" ] || msg_error "Compose filename was not provided to install_compose_file."

    display_name="$(compose_display_name "$filename")"
    local_source="${SCRIPT_DIR}/docker/${filename}"
    url="${RAW_BASE}/docker/${filename}"
    dest="${COMPOSE_DIR}/${filename}"

    if [ -f "$local_source" ]; then
        msg_info "Installing ${display_name}"
        run_cmd "installing local ${filename}" cp "$local_source" "$dest"
    else
        msg_info "Downloading ${display_name}"
        tmp="$(mktemp)"
        TEMP_FILES+=("$tmp")
        download_file "$url" "$tmp" || msg_error "Failed to download ${url}"
        if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" cp "$tmp" "$dest"; else cp "$tmp" "$dest"; fi
    fi

    if ! root_file_not_empty "$dest"; then
        msg_error "Compose file install failed or produced an empty file: ${dest}"
    fi

    run_cmd "setting ${filename} ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$dest"
    run_cmd "setting ${filename} mode" chmod 640 "$dest"
    msg_ok "${display_name}: installed"
}

function verify_core_compose_files_installed() {
    local file=""
    local path=""
    local missing_files=()

    for file in "${CORE_COMPOSE_FILES[@]}"; do
        path="${COMPOSE_DIR}/${file}"
        if ! root_file_not_empty "$path"; then
            missing_files+=("$file")
        fi
    done

    if [ "${#missing_files[@]}" -gt 0 ]; then
        echo ""
        echo -e "${RD}Missing or empty platform core compose file(s):${CL}"
        for file in "${missing_files[@]}"; do
            echo -e "  ${RD}${file}${CL}"
        done
        msg_error "Platform core compose file installation did not complete."
    fi

    msg_ok "PLATFORM CORE COMPOSE FILES VERIFIED"
}

function install_core_compose_files() {
    section "COMPOSE FILES"
    local file=""
    run_cmd "creating compose directory" mkdir -p "$COMPOSE_DIR"
    for file in "${CORE_COMPOSE_FILES[@]}"; do
        install_compose_file "$file"
    done
    verify_core_compose_files_installed
}

function ensure_network() {
    local network="$1"
    if docker network inspect "$network" >/dev/null 2>&1; then
        return 0
    fi
    run_cmd "creating Docker network ${network}" docker network create "$network"
}

function create_networks() {
    section "NETWORKS"
    ensure_network "socket_proxy"
    ensure_network "t2_proxy"
    docker network inspect socket_proxy >/dev/null 2>&1 && SCRIPT61_NETWORK_SOCKET_PROXY="yes"
    docker network inspect t2_proxy >/dev/null 2>&1 && SCRIPT61_NETWORK_T2_PROXY="yes"
    aligned_status_line "socket_proxy" "$SCRIPT61_NETWORK_SOCKET_PROXY" "$(status_color_for_value "$SCRIPT61_NETWORK_SOCKET_PROXY")" 18
    aligned_status_line "t2_proxy" "$SCRIPT61_NETWORK_T2_PROXY" "$(status_color_for_value "$SCRIPT61_NETWORK_T2_PROXY")" 18
}

function compose_file_path() { printf '%s/%s' "$COMPOSE_DIR" "$1"; }
function compose_project_for_file() {
    case "$1" in
        "$COMPOSE_SOCKET_PROXY") printf '%s' "$PROJECT_SOCKET_PROXY" ;;
        "$COMPOSE_TRAEFIK") printf '%s' "$PROJECT_TRAEFIK" ;;
        "$COMPOSE_CF_DDNS") printf '%s' "$PROJECT_CF_DDNS" ;;
        "$COMPOSE_CF_COMPANION") printf '%s' "$PROJECT_CF_COMPANION" ;;
        *) printf 'circl8-platform-core' ;;
    esac
}

function compose_display_name() {
    case "${1:-}" in
        "$COMPOSE_SOCKET_PROXY") printf 'Socket Proxy' ;;
        "$COMPOSE_TRAEFIK") printf 'Traefik' ;;
        "$COMPOSE_CF_DDNS") printf 'Cloudflare DDNS' ;;
        "$COMPOSE_CF_COMPANION") printf 'Cloudflare Companion' ;;
        *) printf '%s' "${1:-unknown}" ;;
    esac
}

function validate_compose_files() {
    section "COMPOSE VALIDATION"
    local file="" project="" display_name=""
    for file in "${CORE_COMPOSE_FILES[@]}"; do
        display_name="$(compose_display_name "$file")"
        if [ "$CF_SERVICES_ENABLED" != "yes" ] && { [ "$file" = "$COMPOSE_CF_DDNS" ] || [ "$file" = "$COMPOSE_CF_COMPANION" ]; }; then
            aligned_status_line "$display_name" "skipped" "$YW" 28
            continue
        fi
        project="$(compose_project_for_file "$file")"
        msg_info "Validating ${display_name}"
        docker compose --env-file "$ENV_FILE" -p "$project" -f "$(compose_file_path "$file")" config >/dev/null
        msg_ok "${display_name}: config valid"
    done
}

function show_setup_plan_and_confirm() {
    local apply_yn=""
    section "SETUP PLAN"
    echo -e "${YW}Script 6.1 will deploy only platform core services after confirmation.${CL}"
    echo ""
    echo -e "${YW}Apply changes:${CL}"
    aligned_status_line "Compose files" "install into compose dir" "$GN" 24
    aligned_status_line "Docker networks" "create/verify" "$GN" 24
    aligned_status_line "Compose configs" "validate before deploy" "$GN" 24
    aligned_status_line "Verification" "write report and marker" "$GN" 24
    echo ""
    echo -e "${YW}Deployment order:${CL}"
    aligned_status_line "1" "$(compose_display_name "$COMPOSE_SOCKET_PROXY")" "$GN" 4
    aligned_status_line "2" "$(compose_display_name "$COMPOSE_TRAEFIK")" "$GN" 4
    aligned_status_line "3" "$([ "$CF_SERVICES_ENABLED" = "yes" ] && compose_display_name "$COMPOSE_CF_DDNS" || echo "$(compose_display_name "$COMPOSE_CF_DDNS") (skipped)")" "$GN" 4
    aligned_status_line "4" "$([ "$CF_SERVICES_ENABLED" = "yes" ] && compose_display_name "$COMPOSE_CF_COMPANION" || echo "$(compose_display_name "$COMPOSE_CF_COMPANION") (skipped)")" "$GN" 4
    echo ""
    echo -e "${YW}Prepared by Script 6:${CL}"
    aligned_status_line "Domain" "$DOMAIN_VALUE" "$GN" 18
    aligned_status_line "Docker dir" "$DOCKER_DIR" "$GN" 18
    aligned_status_line "Compose dir" "$COMPOSE_DIR" "$GN" 18
    aligned_status_line "Secrets dir" "$SECRETS_DIR" "$GN" 18
    aligned_status_line "Traefik config" "$SCRIPT6_TRAEFIK_CONFIG_READY" "$(status_color_for_value "$SCRIPT6_TRAEFIK_CONFIG_READY")" 18
    aligned_status_line "ACME storage" "$SCRIPT6_TRAEFIK_ACME_READY" "$(status_color_for_value "$SCRIPT6_TRAEFIK_ACME_READY")" 18
    aligned_status_line "Cloudflare DNS" "$([ "$CF_SERVICES_ENABLED" = "yes" ] && echo enabled || echo skipped)" "$GN" 18
    echo ""
    read -r -p "Apply this platform core setup plan? [Y/n]: " apply_yn </dev/tty || apply_yn=""
    if [[ "$apply_yn" =~ ^[Nn]$ ]]; then
        echo -e "${YW}Platform core setup cancelled. No compose stacks were deployed.${CL}"
        exit 0
    fi
}

function deploy_compose_file() {
    local file="${1:-}"
    local project=""
    local display_name=""
    [ -n "$file" ] || msg_error "Compose filename was not provided to deploy_compose_file."
    project="$(compose_project_for_file "$file")"
    display_name="$(compose_display_name "$file")"
    msg_info "Deploying ${display_name}"
    docker compose --env-file "$ENV_FILE" -p "$project" -f "$(compose_file_path "$file")" up -d --remove-orphans >/dev/null
    msg_ok "${display_name}: deployed"
}

function deploy_platform_core() {
    section "DEPLOYMENT"
    deploy_compose_file "$COMPOSE_SOCKET_PROXY"
    deploy_compose_file "$COMPOSE_TRAEFIK"
    if [ "$CF_SERVICES_ENABLED" = "yes" ]; then
        deploy_compose_file "$COMPOSE_CF_DDNS"
        deploy_compose_file "$COMPOSE_CF_COMPANION"
    else
        SCRIPT61_CF_DDNS="skipped"
        SCRIPT61_CF_COMPANION="skipped"
        msg_warn "Cloudflare DDNS/companion deployment skipped because token file is not ready"
    fi
}

function container_state() {
    local name="$1" state="" health=""
    state="$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || true)"
    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$name" 2>/dev/null || true)"
    if [ "$health" = "healthy" ]; then printf 'healthy'; elif [ "$state" = "running" ]; then printf 'running'; elif [ -n "$state" ]; then printf 'failed'; else printf 'unknown'; fi
}

function port_listening_status() {
    local port="$1"
    if [ -n "$(port_owner_line "$port")" ]; then printf 'listening'; else printf 'not-listening'; fi
}

function verify_record_first_issue() {
    local issue_type="$1" check="$2" reason="$3" fix="$4"
    if [ -z "$VERIFY_FIRST_ISSUE_TYPE" ]; then
        VERIFY_FIRST_ISSUE_TYPE="$issue_type"; VERIFY_FIRST_ISSUE_CHECK="$check"; VERIFY_FIRST_ISSUE_REASON="$reason"; VERIFY_FIRST_ISSUE_FIX="$fix"
    fi
}

function create_verification_report() {
    section "VERIFICATION"
    msg_info "Creating platform core verification report"
    local report_body="$(mktemp)" mode=""
    TEMP_FILES+=("$report_body")
    VERIFY_STATUS="PASS"; VERIFY_PASS_COUNT="0"; VERIFY_WARN_COUNT="0"; VERIFY_FAIL_COUNT="0"
    VERIFY_FIRST_ISSUE_TYPE=""; VERIFY_FIRST_ISSUE_CHECK=""; VERIFY_FIRST_ISSUE_REASON=""; VERIFY_FIRST_ISSUE_FIX=""

    verify_pass() { VERIFY_PASS_COUNT="$((VERIFY_PASS_COUNT + 1))"; echo "✓ PASS - $1" >> "$report_body"; }
    verify_warn() { local check="$1" reason="${2:-warning}" fix="${3:-review logs}"; VERIFY_WARN_COUNT="$((VERIFY_WARN_COUNT + 1))"; verify_record_first_issue "Warning" "$check" "$reason" "$fix"; echo "! WARN - ${check}: ${reason}" >> "$report_body"; }
    verify_fail() { local check="$1" reason="${2:-failed}" fix="${3:-review logs}"; VERIFY_FAIL_COUNT="$((VERIFY_FAIL_COUNT + 1))"; verify_record_first_issue "Failure" "$check" "$reason" "$fix"; echo "✗ FAIL - ${check}: ${reason}" >> "$report_body"; }
    verify_info() { echo "- INFO - $1" >> "$report_body"; }

    docker network inspect t2_proxy >/dev/null 2>&1 && { SCRIPT61_NETWORK_T2_PROXY="yes"; verify_pass "t2_proxy network exists"; } || { SCRIPT61_NETWORK_T2_PROXY="no"; verify_fail "t2_proxy network" "missing" "rerun Script 6.1 network step"; }
    docker network inspect socket_proxy >/dev/null 2>&1 && { SCRIPT61_NETWORK_SOCKET_PROXY="yes"; verify_pass "socket_proxy network exists"; } || { SCRIPT61_NETWORK_SOCKET_PROXY="no"; verify_fail "socket_proxy network" "missing" "rerun Script 6.1 network step"; }

    SCRIPT61_SOCKET_PROXY="$(container_state socket-proxy)"
    SCRIPT61_TRAEFIK="$(container_state traefik)"
    if [ "$CF_SERVICES_ENABLED" = "yes" ]; then
        SCRIPT61_CF_DDNS="$(container_state cf-ddns)"
        SCRIPT61_CF_COMPANION="$(container_state cf-companion)"
    else
        SCRIPT61_CF_DDNS="skipped"
        SCRIPT61_CF_COMPANION="skipped"
    fi

    case "$SCRIPT61_SOCKET_PROXY" in running|healthy) verify_pass "socket-proxy container ${SCRIPT61_SOCKET_PROXY}" ;; *) verify_fail "socket-proxy container" "state is ${SCRIPT61_SOCKET_PROXY}" "run docker logs socket-proxy" ;; esac
    case "$SCRIPT61_TRAEFIK" in running|healthy) verify_pass "Traefik container ${SCRIPT61_TRAEFIK}" ;; *) verify_fail "Traefik container" "state is ${SCRIPT61_TRAEFIK}" "run docker logs traefik" ;; esac
    case "$SCRIPT61_CF_DDNS" in running|healthy|skipped) verify_pass "Cloudflare DDNS ${SCRIPT61_CF_DDNS}" ;; *) verify_warn "Cloudflare DDNS" "state is ${SCRIPT61_CF_DDNS}" "check token/DNS config or skip if not used" ;; esac
    case "$SCRIPT61_CF_COMPANION" in running|healthy|skipped) verify_pass "Cloudflare companion ${SCRIPT61_CF_COMPANION}" ;; *) verify_warn "Cloudflare companion" "state is ${SCRIPT61_CF_COMPANION}" "check socket-proxy/token config" ;; esac

    root_path_exists "$TRAEFIK_STATIC_CONFIG_FILE" && { SCRIPT61_TRAEFIK_CONFIG_READY="yes"; verify_pass "Traefik static config exists"; } || { SCRIPT61_TRAEFIK_CONFIG_READY="no"; verify_fail "Traefik static config" "missing" "rerun Script 6"; }
    root_path_exists "$TRAEFIK_DYNAMIC_CONFIG_FILE" && verify_pass "Traefik dynamic config exists" || verify_fail "Traefik dynamic config" "missing" "rerun Script 6"
    mode="$(root_stat_mode "$TRAEFIK_ACME_FILE")"
    if root_path_exists "$TRAEFIK_ACME_FILE" && [ "$mode" = "600" ]; then SCRIPT61_TRAEFIK_ACME_READY="yes"; verify_pass "acme.json exists and mode is 600"; else SCRIPT61_TRAEFIK_ACME_READY="no"; verify_fail "acme.json" "mode is ${mode:-unknown}" "rerun Script 6 permissions"; fi

    SCRIPT61_PORT_80="$(port_listening_status 80)"
    SCRIPT61_PORT_443="$(port_listening_status 443)"
    [ "$SCRIPT61_PORT_80" = "listening" ] && verify_pass "Port 80 listening" || verify_warn "Port 80" "not listening" "check Traefik container and port mapping"
    [ "$SCRIPT61_PORT_443" = "listening" ] && verify_pass "Port 443 listening" || verify_warn "Port 443" "not listening" "check Traefik container and port mapping"

    if [ "$VERIFY_FAIL_COUNT" -gt 0 ]; then VERIFY_STATUS="FAIL"; elif [ "$VERIFY_WARN_COUNT" -gt 0 ]; then VERIFY_STATUS="PASS_WITH_WARNINGS"; else VERIFY_STATUS="PASS"; fi

    if [ "$VERIFY_STATUS" = "PASS" ] || [ "$VERIFY_STATUS" = "PASS_WITH_WARNINGS" ]; then
        SCRIPT61_READY_FOR_SCRIPT62="yes"; SCRIPT61_READY_FOR_SCRIPT63="yes"; SCRIPT61_READY_FOR_SCRIPT64="yes"; SCRIPT61_READY_FOR_SCRIPT65="yes"; SCRIPT61_READY_FOR_SCRIPT66="yes"
    fi

    {
        echo "--- CIRCL8 PLATFORM CORE VERIFICATION REPORT ---"
        echo "Date: $(date)"
        echo "Script: ${SCRIPT_SOURCE} ${SCRIPT_VERSION} ${SCRIPT_BUILD}"
        echo "Docker dir: ${DOCKER_DIR}"
        echo "Compose dir: ${COMPOSE_DIR}"
        echo "Secrets dir: ${SECRETS_DIR}"
        echo "Domain: ${DOMAIN_VALUE}"
        echo "VERIFY_STATUS=${VERIFY_STATUS}"
        echo "VERIFY_PASS_COUNT=${VERIFY_PASS_COUNT}"
        echo "VERIFY_WARN_COUNT=${VERIFY_WARN_COUNT}"
        echo "VERIFY_FAIL_COUNT=${VERIFY_FAIL_COUNT}"
        echo ""
        echo "Results:"
        cat "$report_body"
    } | write_root_file "$VERIFY_LOG"

    rm -f "$report_body"
    msg_ok "PLATFORM CORE VERIFICATION REPORT CREATED"
}

function write_completion_marker() {
    section "MARKER"
    msg_info "Writing platform core completion marker"
    {
        echo "Platform Core completed on: $(date)"
        echo "Docker dir: ${DOCKER_DIR}"
        echo "Compose dir: ${COMPOSE_DIR}"
        echo "Secrets dir: ${SECRETS_DIR}"
        echo "Domain: ${DOMAIN_VALUE}"
        echo "Verify log: ${VERIFY_LOG}"
        echo "SCRIPT61_STATUS=completed"
        echo "SCRIPT61_VERSION=${SCRIPT_VERSION}"
        echo "SCRIPT61_BUILD=${SCRIPT_BUILD}"
        echo "SCRIPT61_VERIFY_STATUS=${VERIFY_STATUS}"
        echo "SCRIPT61_VERIFY_LOG=${VERIFY_LOG}"
        echo "SCRIPT61_DOCKER_DIR=${DOCKER_DIR}"
        echo "SCRIPT61_COMPOSE_DIR=${COMPOSE_DIR}"
        echo "SCRIPT61_SECRETS_DIR=${SECRETS_DIR}"
        echo "SCRIPT61_DOMAIN=${DOMAIN_VALUE}"
        echo "SCRIPT61_NETWORK_T2_PROXY=${SCRIPT61_NETWORK_T2_PROXY}"
        echo "SCRIPT61_NETWORK_SOCKET_PROXY=${SCRIPT61_NETWORK_SOCKET_PROXY}"
        echo "SCRIPT61_SOCKET_PROXY=${SCRIPT61_SOCKET_PROXY}"
        echo "SCRIPT61_TRAEFIK=${SCRIPT61_TRAEFIK}"
        echo "SCRIPT61_CF_DDNS=${SCRIPT61_CF_DDNS}"
        echo "SCRIPT61_CF_COMPANION=${SCRIPT61_CF_COMPANION}"
        echo "SCRIPT61_TRAEFIK_CONFIG_READY=${SCRIPT61_TRAEFIK_CONFIG_READY}"
        echo "SCRIPT61_TRAEFIK_ACME_READY=${SCRIPT61_TRAEFIK_ACME_READY}"
        echo "SCRIPT61_PORT_80=${SCRIPT61_PORT_80}"
        echo "SCRIPT61_PORT_443=${SCRIPT61_PORT_443}"
        echo "SCRIPT61_READY_FOR_SCRIPT62=${SCRIPT61_READY_FOR_SCRIPT62}"
        echo "SCRIPT61_READY_FOR_SCRIPT63=${SCRIPT61_READY_FOR_SCRIPT63}"
        echo "SCRIPT61_READY_FOR_SCRIPT64=${SCRIPT61_READY_FOR_SCRIPT64}"
        echo "SCRIPT61_READY_FOR_SCRIPT65=${SCRIPT61_READY_FOR_SCRIPT65}"
        echo "SCRIPT61_READY_FOR_SCRIPT66=${SCRIPT61_READY_FOR_SCRIPT66}"
        echo "SCRIPT61_NEXT_STEP=6.2-admin-ui-bootstrap"
    } | write_root_file "$COMPLETED_MARKER"
    if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" chmod 0644 "$COMPLETED_MARKER"; else chmod 0644 "$COMPLETED_MARKER"; fi
    msg_ok "COMPLETION MARKER WRITTEN"
}

function show_final_summary() {
    section_flash_success "     ━━━━━━━━━━━━━━━━━    FINISHED    ━━━━━━━━━━━━━━━━━"
    echo -e "${YW}Platform core:${CL}"
    final_line "Socket proxy" "$SCRIPT61_SOCKET_PROXY" "$(status_color_for_value "$SCRIPT61_SOCKET_PROXY")"
    final_line "Traefik" "$SCRIPT61_TRAEFIK" "$(status_color_for_value "$SCRIPT61_TRAEFIK")"
    final_line "CF DDNS" "$SCRIPT61_CF_DDNS" "$(status_color_for_value "$SCRIPT61_CF_DDNS")"
    final_line "CF companion" "$SCRIPT61_CF_COMPANION" "$(status_color_for_value "$SCRIPT61_CF_COMPANION")"
    echo ""
    echo -e "${YW}Network:${CL}"
    final_line "t2_proxy" "$SCRIPT61_NETWORK_T2_PROXY" "$(status_color_for_value "$SCRIPT61_NETWORK_T2_PROXY")"
    final_line "socket_proxy" "$SCRIPT61_NETWORK_SOCKET_PROXY" "$(status_color_for_value "$SCRIPT61_NETWORK_SOCKET_PROXY")"
    final_line "Port 80" "$SCRIPT61_PORT_80" "$(status_color_for_value "$SCRIPT61_PORT_80")"
    final_line "Port 443" "$SCRIPT61_PORT_443" "$(status_color_for_value "$SCRIPT61_PORT_443")"
    echo ""
    echo -e "${YW}Prepared by Script 6:${CL}"
    final_line "Domain" "$DOMAIN_VALUE"
    final_line "Docker dir" "$DOCKER_DIR"
    final_line "Compose dir" "$COMPOSE_DIR"
    final_line "Secrets dir" "$SECRETS_DIR"
    final_line "Traefik config" "$TRAEFIK_STATIC_CONFIG_FILE"
    final_line "ACME storage" "$TRAEFIK_ACME_FILE"
    echo ""
    echo -e "${YW}Verification:${CL}"
    final_line "Status" "$VERIFY_STATUS" "$(status_color_for_value "$VERIFY_STATUS")"
    final_line "Pass" "$VERIFY_PASS_COUNT" "$GN"
    final_line "Warn" "$VERIFY_WARN_COUNT" "$YW"
    final_line "Fail" "$VERIFY_FAIL_COUNT" "$RD"
    final_line "Verify log" "$VERIFY_LOG"
    final_line "Marker" "$COMPLETED_MARKER"
    if [ -n "$VERIFY_FIRST_ISSUE_TYPE" ]; then
        echo ""
        echo -e "${YW}${VERIFY_FIRST_ISSUE_TYPE} 1:${CL}"
        final_line "Check" "$VERIFY_FIRST_ISSUE_CHECK"
        final_line "Reason" "$VERIFY_FIRST_ISSUE_REASON" "$YW"
        final_line "Fix" "$VERIFY_FIRST_ISSUE_FIX"
    fi
    echo ""
    echo -e "${BL}Next Step:${CL}"
    echo -e "  ${YW}Run ${ANS}Script 6.2 admin UI bootstrap${YW}.${CL}"
    echo ""
}

function apply_platform_core_changes() {
    section "APPLY CHANGES"
    echo -e "${YW}Applying confirmed platform core setup plan.${CL}"
    install_core_compose_files
    create_networks
    validate_compose_files
    deploy_platform_core
}

function main() {
    init_script
    validate_script6_handoff
    validate_preflight_runtime
    show_setup_plan_and_confirm
    apply_platform_core_changes
    create_verification_report
    write_completion_marker
    show_final_summary
}

main "$@"
