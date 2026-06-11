#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Project Circl8 - Script 6.2 Admin UI Bootstrap
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

SCRIPT_SOURCE="6.2-adminUiBootstrap.sh"
SCRIPT_VERSION="v1.0.0"
SCRIPT_UPDATED="2026-06-11"
SCRIPT_BUILD="admin-ui-bootstrap"

T=15
LOG_FILE="/var/log/circl8-admin-ui.log"
RUNTIME_LOG_FILE=""
VERIFY_LOG="/var/log/circl8-admin-ui-verify.log"
DEPLOY_OUTPUT_FILE=""
FAILED_DEPLOY_LOG=""
COMPLETED_MARKER="/root/.circl8-admin-ui-completed"
SCRIPT61_MARKER="/root/.circl8-platform-core-completed"

SUDO_CMD=""
VERIFY_STATUS="not-run"
VERIFY_PASS_COUNT="0"
VERIFY_WARN_COUNT="0"
VERIFY_FAIL_COUNT="0"
VERIFY_FIRST_ISSUE_TYPE=""
VERIFY_FIRST_ISSUE_CHECK=""
VERIFY_FIRST_ISSUE_REASON=""
VERIFY_FIRST_ISSUE_FIX=""

SCRIPT61_STATUS="missing"
SCRIPT61_VERSION="unknown"
SCRIPT61_BUILD="unknown"
SCRIPT61_VERIFY_STATUS="missing"
SCRIPT61_DOCKER_DIR=""
SCRIPT61_COMPOSE_DIR=""
SCRIPT61_SECRETS_DIR=""
SCRIPT61_READY_FOR_SCRIPT62="no"
SCRIPT61_SOCKET_PROXY="unknown"
SCRIPT61_TRAEFIK="unknown"
SCRIPT61_PORT_80="unknown"
SCRIPT61_PORT_443="unknown"

DOCKER_USER=""
DOCKER_DIR=""
COMPOSE_DIR=""
SECRETS_DIR=""
DOMAIN_VALUE=""
ENV_FILE=""
RAW_BASE="${CIRCL8_RAW_BASE:-https://raw.githubusercontent.com/Orik999/circl8/refs/heads/main}"
SCRIPT_DIR=""
TEMP_FILES=()
TEMP_DIRS=()

COMPOSE_DOCKGE="04-[1]-dockge-compose.yml"
OVERRIDE_DOCKGE="04-[1]-dockge-bootstrap-override.yml"
COMPOSE_DOCKHAND="04-[2]-dockhand-compose.yml"
OVERRIDE_DOCKHAND="04-[2]-dockhand-bootstrap-override.yml"
COMPOSE_KOMODO="04-[3]-komodo-compose.yml"
OVERRIDE_KOMODO="04-[3]-komodo-bootstrap-override.yml"
COMPOSE_PORTAINER="04-[4]-portainer-compose.yml"
OVERRIDE_PORTAINER="04-[4]-portainer-bootstrap-override.yml"
ADMIN_UI_FILES=("$OVERRIDE_DOCKGE" "$COMPOSE_DOCKGE" "$OVERRIDE_DOCKHAND" "$COMPOSE_DOCKHAND" "$OVERRIDE_KOMODO" "$COMPOSE_KOMODO" "$OVERRIDE_PORTAINER" "$COMPOSE_PORTAINER")

PROJECT_DOCKGE="circl8-admin-dockge"
PROJECT_DOCKHAND="circl8-admin-dockhand"
PROJECT_KOMODO="circl8-admin-komodo"
PROJECT_PORTAINER="circl8-admin-portainer"

SCRIPT62_DOCKGE="unknown"
SCRIPT62_DOCKHAND="unknown"
SCRIPT62_KOMODO="unknown"
SCRIPT62_PORTAINER="unknown"
SCRIPT62_BOOTSTRAP_ACCESS="unknown"
SCRIPT62_PUBLIC_AUTH_ROUTES="pending-script-6.3"
SCRIPT62_READY_FOR_SCRIPT63="no"
SCRIPT62_READY_FOR_SCRIPT64="no"
SCRIPT62_READY_FOR_SCRIPT65="no"
SCRIPT62_READY_FOR_SCRIPT66="no"

SETUP_MODE="fresh install"
EXISTING_ADMIN_UI="not detected"
COMPOSE_FILES_STATE="will install"
NETWORK_T2_PROXY="unknown"
NETWORK_SOCKET_PROXY="unknown"
BOOTSTRAP_PORTS_STATE="unknown"
UI_LABEL_WIDTH="28"

function header_info() {
cat <<'BANNER'

   ██████╗    ██████╗        █████╗ ██████╗ ███╗   ███╗██╗███╗   ██╗
  ██╔════╝   ██╔════╝       ██╔══██╗██╔══██╗████╗ ████║██║████╗  ██║
  ███████╗   ███████╗       ███████║██║  ██║██╔████╔██║██║██╔██╗ ██║
  ██╔═══██╗  ██╔═══██╗      ██╔══██║██║  ██║██║╚██╔╝██║██║██║╚██╗██║
  ╚██████╔╝  ╚██████╔╝      ██║  ██║██████╔╝██║ ╚═╝ ██║██║██║ ╚████║
   ╚═════╝    ╚═════╝       ╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝

                         6.2-ADMIN-UI
BANNER
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

function status_color_for_value() {
    local value="${1:-unknown}"
    case "$value" in
        PASS|completed|active|running|healthy|yes|ready|present|configured|deployed|validated|available/platform) printf '%s' "$GN" ;;
        PASS_WITH_WARNINGS|skipped|unknown|pending-script-6.3|configured*|rerun/update|will*|not\ detected) printf '%s' "$YW" ;;
        FAIL|failed|missing|no|inactive|not-ready|blocked) printf '%s' "$RD" ;;
        *) printf '%s' "$GN" ;;
    esac
}

function aligned_status_line() {
    local label="$1" value="${2:-unknown}" color="${3:-}" width="${4:-$UI_LABEL_WIDTH}"
    [ -n "$value" ] || value="unknown"
    [ -n "$color" ] || color="$(status_color_for_value "$value")"
    printf '  %b%-*s%b %b%s%b\n' "$BL" "$width" "${label}:" "$CL" "$color" "$value" "$CL"
}

function final_line() {
    local label="$1" value="${2:-not configured}" color="${3:-$GN}"
    [ -n "$value" ] || value="not configured"
    printf '  %b%-24s%b %b%s%b\n' "$BL" "${label}:" "$CL" "$color" "$value" "$CL"
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
    local value=""
    value="$(trim_value "${1:-}")"
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
    local err_file=""
    err_file="$(mktemp)"
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
        RUNTIME_LOG_FILE="$(mktemp /tmp/circl8-admin-ui-log.XXXXXX)"
        TEMP_FILES+=("$RUNTIME_LOG_FILE")
        exec > >(tee -a "$RUNTIME_LOG_FILE") 2>&1
    else
        RUNTIME_LOG_FILE="$LOG_FILE"
        exec > >(tee -a "$LOG_FILE") 2>&1
    fi
    DEPLOY_OUTPUT_FILE="$(mktemp /tmp/circl8-admin-ui-deploy.XXXXXX)"
    TEMP_FILES+=("$DEPLOY_OUTPUT_FILE")
    : > "$DEPLOY_OUTPUT_FILE"
}

function validate_sudo_access() {
    if [ -n "$SUDO_CMD" ]; then
        msg_info "Validating sudo access"
        if "$SUDO_CMD" -n true >/dev/null 2>&1 || "$SUDO_CMD" -v; then msg_ok "SUDO ACCESS CONFIRMED"; else msg_error "Sudo authentication failed"; fi
    fi
}

function validate_dependencies() {
    local cmds=(awk cat chmod command cp cut date grep id mkdir mktemp openssl rm sed sort stat tee test tr)
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

function load_script61_marker() {
    SCRIPT61_STATUS="$(marker_key_value SCRIPT61_STATUS "$SCRIPT61_MARKER")"; [ -n "$SCRIPT61_STATUS" ] || SCRIPT61_STATUS="missing"
    SCRIPT61_VERSION="$(marker_key_value SCRIPT61_VERSION "$SCRIPT61_MARKER")"; [ -n "$SCRIPT61_VERSION" ] || SCRIPT61_VERSION="unknown"
    SCRIPT61_BUILD="$(marker_key_value SCRIPT61_BUILD "$SCRIPT61_MARKER")"; [ -n "$SCRIPT61_BUILD" ] || SCRIPT61_BUILD="unknown"
    SCRIPT61_VERIFY_STATUS="$(marker_key_value SCRIPT61_VERIFY_STATUS "$SCRIPT61_MARKER")"; [ -n "$SCRIPT61_VERIFY_STATUS" ] || SCRIPT61_VERIFY_STATUS="missing"
    SCRIPT61_DOCKER_DIR="$(marker_key_value SCRIPT61_DOCKER_DIR "$SCRIPT61_MARKER")"
    SCRIPT61_COMPOSE_DIR="$(marker_key_value SCRIPT61_COMPOSE_DIR "$SCRIPT61_MARKER")"
    SCRIPT61_SECRETS_DIR="$(marker_key_value SCRIPT61_SECRETS_DIR "$SCRIPT61_MARKER")"
    SCRIPT61_READY_FOR_SCRIPT62="$(marker_key_value SCRIPT61_READY_FOR_SCRIPT62 "$SCRIPT61_MARKER")"; [ -n "$SCRIPT61_READY_FOR_SCRIPT62" ] || SCRIPT61_READY_FOR_SCRIPT62="no"
    SCRIPT61_SOCKET_PROXY="$(marker_key_value SCRIPT61_SOCKET_PROXY "$SCRIPT61_MARKER")"; [ -n "$SCRIPT61_SOCKET_PROXY" ] || SCRIPT61_SOCKET_PROXY="unknown"
    SCRIPT61_TRAEFIK="$(marker_key_value SCRIPT61_TRAEFIK "$SCRIPT61_MARKER")"; [ -n "$SCRIPT61_TRAEFIK" ] || SCRIPT61_TRAEFIK="unknown"
    SCRIPT61_PORT_80="$(marker_key_value SCRIPT61_PORT_80 "$SCRIPT61_MARKER")"; [ -n "$SCRIPT61_PORT_80" ] || SCRIPT61_PORT_80="unknown"
    SCRIPT61_PORT_443="$(marker_key_value SCRIPT61_PORT_443 "$SCRIPT61_MARKER")"; [ -n "$SCRIPT61_PORT_443" ] || SCRIPT61_PORT_443="unknown"

    DOCKER_DIR="$SCRIPT61_DOCKER_DIR"
    COMPOSE_DIR="$SCRIPT61_COMPOSE_DIR"
    SECRETS_DIR="$SCRIPT61_SECRETS_DIR"
    ENV_FILE="${DOCKER_DIR}/.env"
    DOCKER_USER="$(env_key_value DOCKER_USER)"
    [ -n "$DOCKER_USER" ] || DOCKER_USER="$(env_key_value USER)"
    [ -n "$DOCKER_USER" ] || DOCKER_USER="$(basename "$(dirname "$DOCKER_DIR")")"
    DOMAIN_VALUE="$(env_key_value DOMAIN)"
}

function validate_script61_handoff() {
    local failure="no"
    section "SCRIPT 6.1 HANDOFF"
    load_script61_marker

    echo -e "${YW}Script 6.1:${CL}"
    aligned_status_line "Status" "$SCRIPT61_STATUS" "$(status_color_for_value "$SCRIPT61_STATUS")"
    aligned_status_line "Version" "$SCRIPT61_VERSION" "$GN"
    aligned_status_line "Verification" "$SCRIPT61_VERIFY_STATUS" "$(status_color_for_value "$SCRIPT61_VERIFY_STATUS")"
    aligned_status_line "Ready for Script 6.2" "$SCRIPT61_READY_FOR_SCRIPT62" "$(status_color_for_value "$SCRIPT61_READY_FOR_SCRIPT62")"
    echo ""
    echo -e "${YW}Prepared environment:${CL}"
    aligned_status_line "Docker user" "${DOCKER_USER:-missing}" "$(status_color_for_value "${DOCKER_USER:-missing}")"
    aligned_status_line "Docker dir" "${DOCKER_DIR:-missing}" "$GN"
    aligned_status_line "Compose dir" "${COMPOSE_DIR:-missing}" "$GN"
    aligned_status_line "Secrets dir" "${SECRETS_DIR:-missing}" "$GN"
    aligned_status_line "Domain" "${DOMAIN_VALUE:-missing}" "$GN"
    echo ""
    echo -e "${YW}Platform core:${CL}"
    aligned_status_line "Socket Proxy" "$SCRIPT61_SOCKET_PROXY" "$(status_color_for_value "$SCRIPT61_SOCKET_PROXY")"
    aligned_status_line "Traefik" "$SCRIPT61_TRAEFIK" "$(status_color_for_value "$SCRIPT61_TRAEFIK")"
    aligned_status_line "Port 80" "$SCRIPT61_PORT_80" "$(status_color_for_value "$SCRIPT61_PORT_80")"
    aligned_status_line "Port 443" "$SCRIPT61_PORT_443" "$(status_color_for_value "$SCRIPT61_PORT_443")"

    root_path_exists "$SCRIPT61_MARKER" || { msg_warn "Script 6.1 marker missing: ${SCRIPT61_MARKER}"; failure="yes"; }
    [ "$SCRIPT61_STATUS" = "completed" ] || { msg_warn "Script 6.1 marker is not completed"; failure="yes"; }
    [ "$SCRIPT61_VERIFY_STATUS" = "PASS" ] || { msg_warn "Script 6.1 verification is not PASS"; failure="yes"; }
    [ "$SCRIPT61_READY_FOR_SCRIPT62" = "yes" ] || { msg_warn "Script 6.1 marker is not ready for Script 6.2"; failure="yes"; }
    validate_linux_username "$DOCKER_USER" && [ "$DOCKER_USER" != "root" ] && id "$DOCKER_USER" >/dev/null 2>&1 || { msg_warn "Valid non-root Docker user could not be derived"; failure="yes"; }
    validate_domain "$DOMAIN_VALUE" || { msg_warn "Domain is invalid or missing"; failure="yes"; }

    [ "$failure" = "no" ] || { echo ""; echo -e "${RD}Script 6.2 cannot continue until Script 6.1 handoff is healthy.${CL}"; exit 1; }
    msg_ok "SCRIPT 6.1 HANDOFF VERIFIED"
}

function docker_service_active() { systemctl is-active docker 2>/dev/null || true; }
function containerd_service_active() { systemctl is-active containerd 2>/dev/null || true; }

function port_owner_line() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then ss -H -ltnp "sport = :${port}" 2>/dev/null | head -n1 || true; else printf ''; fi
}

function port_busy_status() {
    local port="$1"
    if [ -n "$(port_owner_line "$port")" ]; then printf 'listening'; else printf 'available'; fi
}

function any_admin_container_exists() {
    local name=""
    for name in dockge dockhand komodo-core komodo-postgres komodo-ferretdb komodo-periphery portainer; do
        docker inspect "$name" >/dev/null 2>&1 && return 0
    done
    return 1
}

function any_admin_bootstrap_port_listening() {
    local port=""
    for port in 5001 3000 9120 9443; do [ "$(port_busy_status "$port")" = "listening" ] && return 0; done
    return 1
}

function any_admin_compose_file_exists() {
    local f=""
    for f in "${ADMIN_UI_FILES[@]}"; do root_path_exists "${COMPOSE_DIR}/${f}" && return 0; done
    return 1
}

function refresh_setup_mode() {
    SETUP_MODE="fresh install"
    EXISTING_ADMIN_UI="not detected"
    if [ "$(marker_key_value SCRIPT62_STATUS "$COMPLETED_MARKER")" = "completed" ] || any_admin_container_exists || any_admin_bootstrap_port_listening || any_admin_compose_file_exists; then
        SETUP_MODE="rerun/update"
        EXISTING_ADMIN_UI="detected"
    fi
}

function validate_preflight_runtime() {
    local failure="no"
    section "RUNTIME PREFLIGHT"

    if command -v docker >/dev/null 2>&1; then aligned_status_line "Docker command" "ready" "$GN"; else aligned_status_line "Docker command" "missing" "$RD"; failure="yes"; fi
    if docker compose version >/dev/null 2>&1; then aligned_status_line "Docker Compose" "ready" "$GN"; else aligned_status_line "Docker Compose" "missing" "$RD"; failure="yes"; fi
    aligned_status_line "Docker service" "$(docker_service_active)" "$(status_color_for_value "$(docker_service_active)")"
    aligned_status_line "containerd" "$(containerd_service_active)" "$(status_color_for_value "$(containerd_service_active)")"
    [ "$(docker_service_active)" = "active" ] || failure="yes"
    [ "$(containerd_service_active)" = "active" ] || failure="yes"

    root_path_exists "$DOCKER_DIR" && aligned_status_line "Docker dir" "present" "$GN" || { aligned_status_line "Docker dir" "missing" "$RD"; failure="yes"; }
    root_path_exists "$COMPOSE_DIR" && aligned_status_line "Compose dir" "present" "$GN" || { aligned_status_line "Compose dir" "missing" "$RD"; failure="yes"; }
    root_path_exists "$SECRETS_DIR" && aligned_status_line "Secrets dir" "present" "$GN" || { aligned_status_line "Secrets dir" "missing" "$RD"; failure="yes"; }
    root_path_exists "$ENV_FILE" && aligned_status_line ".env file" "present" "$GN" || { aligned_status_line ".env file" "missing" "$RD"; failure="yes"; }
    docker network inspect t2_proxy >/dev/null 2>&1 && { NETWORK_T2_PROXY="yes"; aligned_status_line "t2_proxy network" "ready" "$GN"; } || { NETWORK_T2_PROXY="no"; aligned_status_line "t2_proxy network" "missing" "$RD"; failure="yes"; }
    docker network inspect socket_proxy >/dev/null 2>&1 && { NETWORK_SOCKET_PROXY="yes"; aligned_status_line "socket_proxy network" "ready" "$GN"; } || { NETWORK_SOCKET_PROXY="no"; aligned_status_line "socket_proxy network" "missing" "$RD"; failure="yes"; }
    aligned_status_line "Compose files" "will install" "$YW"
    aligned_status_line "Bootstrap port 5001" "$(port_busy_status 5001)" "$(status_color_for_value "$(port_busy_status 5001)")"
    aligned_status_line "Bootstrap port 3000" "$(port_busy_status 3000)" "$(status_color_for_value "$(port_busy_status 3000)")"
    aligned_status_line "Bootstrap port 9120" "$(port_busy_status 9120)" "$(status_color_for_value "$(port_busy_status 9120)")"
    aligned_status_line "Bootstrap port 9443" "$(port_busy_status 9443)" "$(status_color_for_value "$(port_busy_status 9443)")"

    refresh_setup_mode
    [ "$failure" = "no" ] || msg_error "Runtime preflight failed. Fix the checks above, then rerun Script 6.2."
    msg_ok "RUNTIME PREFLIGHT PASSED"
}

function show_setup_plan_and_confirm() {
    local apply_yn=""
    section "SETUP PLAN"
    echo -e "${YW}Script 6.2 will deploy only the Admin UI bootstrap layer after confirmation.${CL}"
    echo ""
    echo -e "${YW}Setup mode:${CL}"
    aligned_status_line "Mode" "$SETUP_MODE" "$(status_color_for_value "$SETUP_MODE")"
    aligned_status_line "Existing Admin UI" "$EXISTING_ADMIN_UI" "$(status_color_for_value "$EXISTING_ADMIN_UI")"
    aligned_status_line "Bootstrap access" "will install/refresh" "$GN"
    aligned_status_line "Public Auth routes" "configured / pending Script 6.3" "$YW"
    if [ "$SETUP_MODE" = "rerun/update" ]; then
        echo ""
        echo -e "${YW}Existing Admin UI bootstrap deployment detected.${CL}"
        echo -e "${YW}This rerun will refresh compose files, verify/reuse Docker networks, and update existing Admin UI containers.${CL}"
        echo -e "${YW}Persistent data, existing secrets, and bootstrap access will be preserved.${CL}"
    fi
    echo ""
    echo -e "${YW}Apply changes:${CL}"
    aligned_status_line "Compose files" "install into compose dir" "$GN"
    aligned_status_line "Bootstrap overrides" "install into compose dir" "$GN"
    aligned_status_line "Docker networks" "verify/reuse" "$GN"
    aligned_status_line "Compose configs" "validate before deploy" "$GN"
    aligned_status_line "Deployment" "deploy Admin UI only" "$GN"
    aligned_status_line "Verification" "write report and marker" "$GN"
    echo ""
    echo -e "${YW}Deployment order:${CL}"
    aligned_status_line "1" "Dockge" "$GN" 4
    aligned_status_line "2" "Dockhand" "$GN" 4
    aligned_status_line "3" "Komodo" "$GN" 4
    aligned_status_line "4" "Portainer" "$GN" 4
    echo ""
    echo -e "${YW}Prepared by Script 6.1:${CL}"
    aligned_status_line "Docker dir" "$DOCKER_DIR" "$GN"
    aligned_status_line "Compose dir" "$COMPOSE_DIR" "$GN"
    aligned_status_line "Secrets dir" "$SECRETS_DIR" "$GN"
    aligned_status_line "Domain" "$DOMAIN_VALUE" "$GN"
    echo ""
    if [ -r /dev/tty ]; then read -r -p "Apply this Admin UI bootstrap setup plan? [Y/n]: " apply_yn </dev/tty || apply_yn=""; else read -r -p "Apply this Admin UI bootstrap setup plan? [Y/n]: " apply_yn || apply_yn=""; fi
    if [[ "$apply_yn" =~ ^[Nn]$ ]]; then
        echo -e "${YW}Admin UI bootstrap setup cancelled. No compose files or stacks were changed.${CL}"
        exit 0
    fi
}

function download_file() {
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then curl -fsSL "$url" -o "$dest"; else wget -qO "$dest" "$url"; fi
}

function compose_display_name() {
    case "${1:-}" in
        "$COMPOSE_DOCKGE"|"$OVERRIDE_DOCKGE") printf 'Dockge' ;;
        "$COMPOSE_DOCKHAND"|"$OVERRIDE_DOCKHAND") printf 'Dockhand' ;;
        "$COMPOSE_KOMODO"|"$OVERRIDE_KOMODO") printf 'Komodo' ;;
        "$COMPOSE_PORTAINER"|"$OVERRIDE_PORTAINER") printf 'Portainer' ;;
        *) printf '%s' "${1:-unknown}" ;;
    esac
}

function install_admin_ui_file() {
    local filename="${1:-}" local_source="" url="" dest="" tmp="" display_name=""
    [ -n "$filename" ] || msg_error "Admin UI filename was not provided."
    display_name="$(compose_display_name "$filename")"
    local_source="${SCRIPT_DIR}/docker/${filename}"
    url="${RAW_BASE}/docker/${filename}"
    dest="${COMPOSE_DIR}/${filename}"
    if [ -f "$local_source" ]; then
        msg_info "Installing ${display_name} file"
        run_cmd "installing local ${filename}" cp "$local_source" "$dest"
    else
        msg_info "Downloading ${display_name} file"
        tmp="$(mktemp)"; TEMP_FILES+=("$tmp")
        download_file "$url" "$tmp" || msg_error "Failed to download ${url}"
        if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" cp "$tmp" "$dest"; else cp "$tmp" "$dest"; fi
    fi
    root_file_not_empty "$dest" || msg_error "Admin UI file install failed or produced an empty file: ${dest}"
    run_cmd "setting ${filename} ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$dest"
    run_cmd "setting ${filename} mode" chmod 640 "$dest"
    msg_ok "${display_name}: installed"
}

function install_admin_ui_files() {
    section "COMPOSE FILES"
    local file=""
    run_cmd "creating compose directory" mkdir -p "$COMPOSE_DIR"
    for file in "${ADMIN_UI_FILES[@]}"; do install_admin_ui_file "$file"; done
    msg_ok "ADMIN UI COMPOSE FILES VERIFIED"
}

function verify_networks() {
    section "NETWORKS"
    docker network inspect t2_proxy >/dev/null 2>&1 && NETWORK_T2_PROXY="yes" || NETWORK_T2_PROXY="no"
    docker network inspect socket_proxy >/dev/null 2>&1 && NETWORK_SOCKET_PROXY="yes" || NETWORK_SOCKET_PROXY="no"
    aligned_status_line "t2_proxy" "$NETWORK_T2_PROXY" "$(status_color_for_value "$NETWORK_T2_PROXY")" 18
    aligned_status_line "socket_proxy" "$NETWORK_SOCKET_PROXY" "$(status_color_for_value "$NETWORK_SOCKET_PROXY")" 18
    [ "$NETWORK_T2_PROXY" = "yes" ] && [ "$NETWORK_SOCKET_PROXY" = "yes" ] || msg_error "Required Script 6.1 Docker networks are missing."
}

function generate_secret() { openssl rand -hex 32 | cut -c1-48; }
function env_has_key() { root_read_file "$ENV_FILE" 2>/dev/null | grep -Eq "^${1}="; }
function append_env_key_secret() {
    local key="$1" value=""
    if env_has_key "$key"; then return 0; fi
    value="$(generate_secret)"
    if [ -n "$SUDO_CMD" ]; then
        printf '%s="%s"\n' "$key" "$value" | "$SUDO_CMD" tee -a "$ENV_FILE" >/dev/null
    else
        printf '%s="%s"\n' "$key" "$value" >> "$ENV_FILE"
    fi
}

function ensure_admin_ui_secret_env() {
    # Komodo needs local app secrets. Generate only if absent, never print values.
    append_env_key_secret "KOMODO_DB_PASSWORD"
    append_env_key_secret "KOMODO_PASSKEY"
    append_env_key_secret "KOMODO_JWT_SECRET"
    append_env_key_secret "KOMODO_WEBHOOK_SECRET"
    run_cmd "setting .env mode" chmod 600 "$ENV_FILE"
}

function compose_path() { printf '%s/%s' "$COMPOSE_DIR" "$1"; }
function compose_project_for_file() {
    case "$1" in
        "$COMPOSE_DOCKGE") printf '%s' "$PROJECT_DOCKGE" ;;
        "$COMPOSE_DOCKHAND") printf '%s' "$PROJECT_DOCKHAND" ;;
        "$COMPOSE_KOMODO") printf '%s' "$PROJECT_KOMODO" ;;
        "$COMPOSE_PORTAINER") printf '%s' "$PROJECT_PORTAINER" ;;
        *) printf 'circl8-admin-ui' ;;
    esac
}
function override_for_file() {
    case "$1" in
        "$COMPOSE_DOCKGE") printf '%s' "$OVERRIDE_DOCKGE" ;;
        "$COMPOSE_DOCKHAND") printf '%s' "$OVERRIDE_DOCKHAND" ;;
        "$COMPOSE_KOMODO") printf '%s' "$OVERRIDE_KOMODO" ;;
        "$COMPOSE_PORTAINER") printf '%s' "$OVERRIDE_PORTAINER" ;;
        *) printf '' ;;
    esac
}
function primary_container_for_file() {
    case "$1" in
        "$COMPOSE_DOCKGE") printf 'dockge' ;;
        "$COMPOSE_DOCKHAND") printf 'dockhand' ;;
        "$COMPOSE_KOMODO") printf 'komodo-core' ;;
        "$COMPOSE_PORTAINER") printf 'portainer' ;;
        *) printf '' ;;
    esac
}

function validate_compose_files() {
    section "COMPOSE VALIDATION"
    local file="" project="" override="" display_name=""
    for file in "$COMPOSE_DOCKGE" "$COMPOSE_DOCKHAND" "$COMPOSE_KOMODO" "$COMPOSE_PORTAINER"; do
        display_name="$(compose_display_name "$file")"
        project="$(compose_project_for_file "$file")"
        override="$(override_for_file "$file")"
        msg_info "Validating ${display_name}"
        docker compose --env-file "$ENV_FILE" -p "$project" -f "$(compose_path "$file")" -f "$(compose_path "$override")" config >/dev/null
        msg_ok "${display_name}: config valid"
    done
}

function write_deployment_failure_log() {
    local display_name="${1:-unknown}" failed_file="${2:-unknown}" failed_project="${3:-unknown}" reason="${4:-deployment failed}" timestamp=""
    timestamp="$(date +%Y%m%d-%H%M%S)"
    FAILED_DEPLOY_LOG="/var/log/circl8-admin-ui-deploy-failed-${timestamp}.log"
    {
        echo "--- CIRCL8 ADMIN UI DEPLOYMENT FAILURE LOG ---"
        echo "Date: $(date)"
        echo "Script: ${SCRIPT_SOURCE} ${SCRIPT_VERSION} ${SCRIPT_BUILD}"
        echo "Failure: ${reason}"
        echo "Failed stack: ${display_name}"
        echo "Compose file: ${failed_file}"
        echo "Compose project: ${failed_project}"
        echo "Docker dir: ${DOCKER_DIR}"
        echo "Compose dir: ${COMPOSE_DIR}"
        echo "Verify log: ${VERIFY_LOG}"
        echo ""
        echo "Detailed deployment/readiness output:"
        if [ -n "${DEPLOY_OUTPUT_FILE:-}" ] && [ -s "$DEPLOY_OUTPUT_FILE" ]; then cat "$DEPLOY_OUTPUT_FILE"; else echo "No deployment output captured."; fi
    } | write_root_file "$FAILED_DEPLOY_LOG"
    run_cmd "setting failure log mode" chmod 0644 "$FAILED_DEPLOY_LOG"
}

function fail_with_deployment_log() {
    local display_name="${1:-unknown}" failed_file="${2:-unknown}" failed_project="${3:-unknown}" reason="${4:-deployment failed}"
    write_deployment_failure_log "$display_name" "$failed_file" "$failed_project" "$reason"
    echo -e "${BFR} ${CROSS} ${RD}${reason}${CL}"
    echo -e "  ${BL}Verify log:${CL} ${GN}${VERIFY_LOG}${CL}"
    echo -e "  ${BL}Failure log:${CL} ${GN}${FAILED_DEPLOY_LOG}${CL}"
    exit 1
}

function wait_for_docker_readiness() {
    local attempts=10 delay=2 i="" docker_ready="no" compose_ready="no" api_ready="no" networks_ready="no"
    section "DOCKER READINESS"
    for ((i=1; i<=attempts; i++)); do
        docker_ready="no"; compose_ready="no"; api_ready="no"; networks_ready="no"
        command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1 && docker_ready="yes"
        docker compose version >/dev/null 2>&1 && compose_ready="yes"
        docker info >/dev/null 2>&1 && api_ready="yes"
        docker network inspect socket_proxy >/dev/null 2>&1 && docker network inspect t2_proxy >/dev/null 2>&1 && networks_ready="yes"
        { echo ""; echo "--- Docker readiness attempt ${i}/${attempts} ---"; echo "Date: $(date)"; echo "Docker command: ${docker_ready}"; echo "Docker Compose: ${compose_ready}"; echo "Docker API: ${api_ready}"; echo "Docker networks: ${networks_ready}"; } >> "$DEPLOY_OUTPUT_FILE"
        if [ "$docker_ready" = "yes" ] && [ "$compose_ready" = "yes" ] && [ "$api_ready" = "yes" ] && [ "$networks_ready" = "yes" ]; then
            aligned_status_line "Docker daemon" "ready" "$GN" 24
            aligned_status_line "Docker Compose" "ready" "$GN" 24
            aligned_status_line "Docker API" "responsive" "$GN" 24
            aligned_status_line "Docker networks" "settled" "$GN" 24
            return 0
        fi
        sleep "$delay"
    done
    fail_with_deployment_log "Docker readiness" "n/a" "n/a" "Docker readiness did not settle before deployment"
}

function container_state() {
    local name="$1" state="" health=""
    state="$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || true)"
    health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$name" 2>/dev/null || true)"
    if [ "$health" = "healthy" ]; then printf 'healthy'; elif [ "$state" = "running" ]; then printf 'running'; elif [ -n "$state" ]; then printf 'failed'; else printf 'unknown'; fi
}

function wait_for_container_ready() {
    local name="${1:-}" display_name="${2:-container}" timeout_seconds="${3:-90}" interval_seconds="${4:-3}" elapsed=0 state="unknown"
    [ -n "$name" ] || return 1
    while [ "$elapsed" -le "$timeout_seconds" ]; do
        state="$(container_state "$name")"
        { echo ""; echo "--- Waiting for ${display_name} readiness ---"; echo "Date: $(date)"; echo "Container: ${name}"; echo "State: ${state}"; echo "Elapsed: ${elapsed}/${timeout_seconds}s"; } >> "$DEPLOY_OUTPUT_FILE"
        case "$state" in running|healthy) msg_ok "${display_name}: ${state}"; return 0 ;; esac
        sleep "$interval_seconds"
        elapsed=$((elapsed + interval_seconds))
    done
    fail_with_deployment_log "$display_name" "n/a" "n/a" "${display_name} did not become ready before timeout"
}

function deploy_compose_file() {
    local file="${1:-}" project="" display_name="" override="" compose_file="" override_file="" attempt="" max_attempts=3 retry_delay=4
    [ -n "$file" ] || msg_error "Compose filename was not provided to deploy_compose_file."
    project="$(compose_project_for_file "$file")"
    display_name="$(compose_display_name "$file")"
    override="$(override_for_file "$file")"
    compose_file="$(compose_path "$file")"
    override_file="$(compose_path "$override")"
    msg_info "Deploying ${display_name}"
    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        { echo ""; echo "--- Deploying ${display_name} (${file}) attempt ${attempt}/${max_attempts} ---"; echo "Date: $(date)"; echo "Project: ${project}"; echo "Compose file: ${compose_file}"; echo "Override file: ${override_file}"; } >> "$DEPLOY_OUTPUT_FILE"
        if docker compose --env-file "$ENV_FILE" -p "$project" -f "$compose_file" -f "$override_file" up -d --remove-orphans >> "$DEPLOY_OUTPUT_FILE" 2>&1; then
            msg_ok "${display_name}: deployed"
            return 0
        fi
        { echo "Deploy attempt ${attempt}/${max_attempts} failed for ${display_name}."; echo "Retry delay: ${retry_delay}s"; } >> "$DEPLOY_OUTPUT_FILE"
        [ "$attempt" -lt "$max_attempts" ] && sleep "$retry_delay"
    done
    fail_with_deployment_log "$display_name" "$file" "$project" "${display_name} deployment failed"
}

function deploy_admin_ui() {
    section "DEPLOYMENT"
    deploy_compose_file "$COMPOSE_DOCKGE"
    wait_for_container_ready "dockge" "Dockge" 90 3
    SCRIPT62_DOCKGE="deployed"
    deploy_compose_file "$COMPOSE_DOCKHAND"
    wait_for_container_ready "dockhand" "Dockhand" 90 3
    SCRIPT62_DOCKHAND="deployed"
    deploy_compose_file "$COMPOSE_KOMODO"
    wait_for_container_ready "komodo-core" "Komodo" 120 4
    SCRIPT62_KOMODO="deployed"
    deploy_compose_file "$COMPOSE_PORTAINER"
    wait_for_container_ready "portainer" "Portainer" 90 3
    SCRIPT62_PORTAINER="deployed"
}

function verify_record_first_issue() {
    local issue_type="$1" check="$2" reason="$3" fix="$4"
    if [ -z "$VERIFY_FIRST_ISSUE_TYPE" ]; then VERIFY_FIRST_ISSUE_TYPE="$issue_type"; VERIFY_FIRST_ISSUE_CHECK="$check"; VERIFY_FIRST_ISSUE_REASON="$reason"; VERIFY_FIRST_ISSUE_FIX="$fix"; fi
}

function create_verification_report() {
    msg_info "Creating Admin UI verification report"
    local report_body="" mode=""
    report_body="$(mktemp)"; TEMP_FILES+=("$report_body")
    VERIFY_STATUS="PASS"; VERIFY_PASS_COUNT="0"; VERIFY_WARN_COUNT="0"; VERIFY_FAIL_COUNT="0"; VERIFY_FIRST_ISSUE_TYPE=""; VERIFY_FIRST_ISSUE_CHECK=""; VERIFY_FIRST_ISSUE_REASON=""; VERIFY_FIRST_ISSUE_FIX=""
    verify_pass() { VERIFY_PASS_COUNT="$((VERIFY_PASS_COUNT + 1))"; echo "✓ PASS - $1" >> "$report_body"; }
    verify_warn() { local check="$1" reason="${2:-warning}" fix="${3:-review logs}"; VERIFY_WARN_COUNT="$((VERIFY_WARN_COUNT + 1))"; verify_record_first_issue "Warning" "$check" "$reason" "$fix"; echo "! WARN - ${check}: ${reason}" >> "$report_body"; }
    verify_fail() { local check="$1" reason="${2:-failed}" fix="${3:-review logs}"; VERIFY_FAIL_COUNT="$((VERIFY_FAIL_COUNT + 1))"; verify_record_first_issue "Failure" "$check" "$reason" "$fix"; echo "✗ FAIL - ${check}: ${reason}" >> "$report_body"; }
    verify_info() { echo "- INFO - $1" >> "$report_body"; }

    [ "$SCRIPT61_STATUS" = "completed" ] && verify_pass "Script 6.1 status completed" || verify_fail "Script 6.1 status" "status is ${SCRIPT61_STATUS}" "complete/fix Script 6.1"
    [ "$SCRIPT61_VERIFY_STATUS" = "PASS" ] && verify_pass "Script 6.1 verification PASS" || verify_fail "Script 6.1 verification" "status is ${SCRIPT61_VERIFY_STATUS}" "complete/fix Script 6.1"
    docker network inspect t2_proxy >/dev/null 2>&1 && verify_pass "t2_proxy network exists" || verify_fail "t2_proxy network" "missing" "rerun Script 6.1"
    docker network inspect socket_proxy >/dev/null 2>&1 && verify_pass "socket_proxy network exists" || verify_fail "socket_proxy network" "missing" "rerun Script 6.1"
    for f in "${ADMIN_UI_FILES[@]}"; do root_file_not_empty "${COMPOSE_DIR}/${f}" && verify_pass "${f} exists" || verify_fail "${f}" "missing or empty" "rerun Script 6.2"; done

    [ "$(container_state dockge)" = "running" ] || [ "$(container_state dockge)" = "healthy" ] && verify_pass "Dockge running" || verify_fail "Dockge running" "state is $(container_state dockge)" "inspect docker logs dockge"
    [ "$(container_state dockhand)" = "running" ] || [ "$(container_state dockhand)" = "healthy" ] && verify_pass "Dockhand running" || verify_fail "Dockhand running" "state is $(container_state dockhand)" "inspect docker logs dockhand"
    [ "$(container_state komodo-core)" = "running" ] || [ "$(container_state komodo-core)" = "healthy" ] && verify_pass "Komodo running" || verify_fail "Komodo running" "state is $(container_state komodo-core)" "inspect docker logs komodo-core"
    [ "$(container_state portainer)" = "running" ] || [ "$(container_state portainer)" = "healthy" ] && verify_pass "Portainer running" || verify_fail "Portainer running" "state is $(container_state portainer)" "inspect docker logs portainer"

    if [ "$(port_busy_status 5001)" = "listening" ] || [ "$(port_busy_status 3000)" = "listening" ] || [ "$(port_busy_status 9120)" = "listening" ] || [ "$(port_busy_status 9443)" = "listening" ]; then
        SCRIPT62_BOOTSTRAP_ACCESS="ready"
        verify_pass "Admin UI bootstrap ports listening"
    else
        SCRIPT62_BOOTSTRAP_ACCESS="pending"
        verify_warn "Admin UI bootstrap ports" "no bootstrap port listener detected yet" "check container startup and compose overrides"
    fi

    verify_info "Public Auth routes are configured/pending Script 6.3 Authentik"
    if [ "$VERIFY_FAIL_COUNT" -gt 0 ]; then VERIFY_STATUS="FAIL"; elif [ "$VERIFY_WARN_COUNT" -gt 0 ]; then VERIFY_STATUS="PASS_WITH_WARNINGS"; else VERIFY_STATUS="PASS"; fi
    if [ "$VERIFY_STATUS" = "PASS" ] || [ "$VERIFY_STATUS" = "PASS_WITH_WARNINGS" ]; then
        SCRIPT62_READY_FOR_SCRIPT63="yes"; SCRIPT62_READY_FOR_SCRIPT64="yes"; SCRIPT62_READY_FOR_SCRIPT65="yes"; SCRIPT62_READY_FOR_SCRIPT66="yes"
    fi

    {
        echo "--- CIRCL8 ADMIN UI VERIFICATION REPORT ---"
        echo "Date: $(date)"
        echo "Docker dir: ${DOCKER_DIR}"
        echo "Compose dir: ${COMPOSE_DIR}"
        echo "Secrets dir: ${SECRETS_DIR}"
        echo "Setup mode: ${SETUP_MODE}"
        echo "Public Auth routes: ${SCRIPT62_PUBLIC_AUTH_ROUTES}"
        echo "VERIFY_STATUS=${VERIFY_STATUS}"
        echo "VERIFY_PASS_COUNT=${VERIFY_PASS_COUNT}"
        echo "VERIFY_WARN_COUNT=${VERIFY_WARN_COUNT}"
        echo "VERIFY_FAIL_COUNT=${VERIFY_FAIL_COUNT}"
        echo ""
        echo "Results:"
        cat "$report_body"
        echo ""
        echo "Deployment output:"
        if [ -s "$DEPLOY_OUTPUT_FILE" ]; then cat "$DEPLOY_OUTPUT_FILE"; else echo "No deployment output captured."; fi
    } | write_root_file "$VERIFY_LOG"
    run_cmd "setting verify log mode" chmod 0644 "$VERIFY_LOG"
    rm -f "$report_body"
    msg_ok "Admin UI verification report created"
}

function write_completion_marker() {
    msg_info "Writing completion marker"
    {
        echo "Admin UI Bootstrap completed on: $(date)"
        echo "Docker dir: ${DOCKER_DIR}"
        echo "Compose dir: ${COMPOSE_DIR}"
        echo "Secrets dir: ${SECRETS_DIR}"
        echo "Verify log: ${VERIFY_LOG}"
        echo "SCRIPT62_STATUS=completed"
        echo "SCRIPT62_VERSION=${SCRIPT_VERSION}"
        echo "SCRIPT62_BUILD=${SCRIPT_BUILD}"
        echo "SCRIPT62_VERIFY_STATUS=${VERIFY_STATUS}"
        echo "SCRIPT62_DOCKER_DIR=${DOCKER_DIR}"
        echo "SCRIPT62_COMPOSE_DIR=${COMPOSE_DIR}"
        echo "SCRIPT62_SECRETS_DIR=${SECRETS_DIR}"
        echo "SCRIPT62_DOCKGE=${SCRIPT62_DOCKGE}"
        echo "SCRIPT62_DOCKHAND=${SCRIPT62_DOCKHAND}"
        echo "SCRIPT62_KOMODO=${SCRIPT62_KOMODO}"
        echo "SCRIPT62_PORTAINER=${SCRIPT62_PORTAINER}"
        echo "SCRIPT62_BOOTSTRAP_ACCESS=${SCRIPT62_BOOTSTRAP_ACCESS}"
        echo "SCRIPT62_PUBLIC_AUTH_ROUTES=${SCRIPT62_PUBLIC_AUTH_ROUTES}"
        echo "SCRIPT62_READY_FOR_SCRIPT63=${SCRIPT62_READY_FOR_SCRIPT63}"
        echo "SCRIPT62_READY_FOR_SCRIPT64=${SCRIPT62_READY_FOR_SCRIPT64}"
        echo "SCRIPT62_READY_FOR_SCRIPT65=${SCRIPT62_READY_FOR_SCRIPT65}"
        echo "SCRIPT62_READY_FOR_SCRIPT66=${SCRIPT62_READY_FOR_SCRIPT66}"
    } | write_root_file "$COMPLETED_MARKER"
    run_cmd "setting completion marker mode" chmod 0644 "$COMPLETED_MARKER"
    msg_ok "Completion marker written"
}

function show_finished_summary() {
    section_flash_success "     ━━━━━━━━━━━━━━━━━    FINISHED    ━━━━━━━━━━━━━━━━━"
    echo -e "${YW}Admin UI:${CL}"
    final_line "Dockge" "$SCRIPT62_DOCKGE" "$(status_color_for_value "$SCRIPT62_DOCKGE")"
    final_line "Dockhand" "$SCRIPT62_DOCKHAND" "$(status_color_for_value "$SCRIPT62_DOCKHAND")"
    final_line "Komodo" "$SCRIPT62_KOMODO" "$(status_color_for_value "$SCRIPT62_KOMODO")"
    final_line "Portainer" "$SCRIPT62_PORTAINER" "$(status_color_for_value "$SCRIPT62_PORTAINER")"
    final_line "Bootstrap access" "$SCRIPT62_BOOTSTRAP_ACCESS" "$(status_color_for_value "$SCRIPT62_BOOTSTRAP_ACCESS")"
    final_line "Public Auth routes" "$SCRIPT62_PUBLIC_AUTH_ROUTES" "$YW"
    echo ""
    echo -e "${YW}Verification:${CL}"
    final_line "Status" "$VERIFY_STATUS" "$(status_color_for_value "$VERIFY_STATUS")"
    final_line "Pass" "$VERIFY_PASS_COUNT" "$GN"
    final_line "Warn" "$VERIFY_WARN_COUNT" "$YW"
    final_line "Fail" "$VERIFY_FAIL_COUNT" "$RD"
    final_line "Verify log" "$VERIFY_LOG" "$GN"
    echo ""
    echo -e "${YW}Next Step:${CL}"
    echo -e "  ${YW}Run ${ANS}Script 6.3 Authentik bootstrap${YW}.${CL}"
}

function main() {
    init_script
    validate_script61_handoff
    validate_preflight_runtime
    show_setup_plan_and_confirm
    section "APPLY CHANGES"
    install_admin_ui_files
    ensure_admin_ui_secret_env
    verify_networks
    validate_compose_files
    wait_for_docker_readiness
    deploy_admin_ui
    section "VERIFICATION / MARKER"
    create_verification_report
    write_completion_marker
    show_finished_summary
}

main "$@"
