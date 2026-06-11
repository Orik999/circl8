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
SCRIPT_VERSION="v1.0.11"
SCRIPT_UPDATED="2026-06-11"
SCRIPT_BUILD="selected-deploy-row-align"

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
SELECTED_ADMIN_UI=""
SELECTED_ADMIN_UI_DISPLAY=""
SELECTED_COMPOSE_FILE=""
SELECTED_OVERRIDE_FILE=""
SELECTED_PROJECT=""
SELECTED_CONTAINER=""
SELECTED_BOOTSTRAP_PORT=""
SELECTED_BOOTSTRAP_SCHEME="http"
SELECTED_FILES=()

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

SETUP_MODE="fresh-install"
EXISTING_ADMIN_UI="none"
PREVIOUS_ADMIN_UI="none"
ACTION_MODE="fresh-install"
SECRET_MODE="not-required"
BOOTSTRAP_MODE="enabled"
BOOTSTRAP_KEEP_AFTER_MIGRATION="yes"
BOOTSTRAP_CURRENT="not detected"
BOOTSTRAP_ACTION="enable"
MIGRATION_STOP_OLD="not-applicable"
BUSINESS_MODE="no"
COMPOSE_FILES_STATE="will install"
NETWORK_T2_PROXY="unknown"
NETWORK_SOCKET_PROXY="unknown"
BOOTSTRAP_PORTS_STATE="unknown"
UI_LABEL_WIDTH="25"

function header_info() {
cat <<'BANNER'

   ██████╗      ██████╗        █████╗ ██████╗ ███╗   ███╗██╗███╗   ██╗    ██╗   ██╗██╗
  ██╔════╝      ╚════██╗      ██╔══██╗██╔══██╗████╗ ████║██║████╗  ██║    ██║   ██║██║
  ███████╗       █████╔╝      ███████║██║  ██║██╔████╔██║██║██╔██╗ ██║    ██║   ██║██║
  ██╔═══██╗     ██╔═══╝       ██╔══██║██║  ██║██║╚██╔╝██║██║██║╚██╗██║    ██║   ██║██║
  ╚██████╔╝ ██╗ ███████╗      ██║  ██║██████╔╝██║ ╚═╝ ██║██║██║ ╚████║    ╚██████╔╝██║
   ╚═════╝  ╚═╝ ╚══════╝      ╚═╝  ╚═╝╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝     ╚═════╝ ╚═╝

                                   6.2 ADMIN UI
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
        PASS|completed|active|running|healthy|yes|ready|present|configured|deployed|validated|available/platform|available|fresh-install|enabled|generated|reused|manual|not-required|not\ required) printf '%s' "$GN" ;;
        PASS_WITH_WARNINGS|skipped|unknown|pending-script-6.3|pending\ Script\ 6.3|configured*|rerun/update|rerun-update|migration|will*|selection\ pending|not\ detected|none|not-selected|preserved-enabled|preserved-disabled|temporary-for-migration|user-enabled|user-disabled|temporary-closed|stopped-old|disabled|platform-owned) printf '%s' "$YW" ;;
        FAIL|failed|missing|no|inactive|not-ready|blocked) printf '%s' "$RD" ;;
        *) printf '%s' "$GN" ;;
    esac
}

function ui_display_value() {
    local value="${1:-unknown}"
    case "$value" in
        fresh-install) printf 'fresh install' ;;
        rerun-update) printf 'rerun/update' ;;
        not-required) printf 'not required' ;;
        pending-script-6.3) printf 'pending Script 6.3' ;;
        preserve\ enabled|preserved-enabled|user-enabled) printf 'keep enabled' ;;
        preserve\ disabled|preserved-disabled|user-disabled) printf 'keep disabled' ;;
        detected/running) printf 'running' ;;
        temporary-closed) printf 'closed after migration' ;;
        temporary-for-migration) printf 'temporary for migration' ;;
        not-applicable) printf 'not applicable' ;;
        *) printf '%s' "$value" ;;
    esac
}

function aligned_status_line() {
    local label="$1" value="${2:-unknown}" color="${3:-}" width="${4:-$UI_LABEL_WIDTH}" display_value=""
    [ -n "$value" ] || value="unknown"
    [ -n "$color" ] || color="$(status_color_for_value "$value")"
    display_value="$(ui_display_value "$value")"
    printf '%b%-*s%b %b%s%b\n' "$BL" "$width" "${label}:" "$CL" "$color" "$display_value" "$CL"
}

function final_line() {
    local label="$1" value="${2:-not configured}" color="${3:-$GN}" display_value=""
    [ -n "$value" ] || value="not configured"
    display_value="$(ui_display_value "$value")"
    printf '%b%-*s%b %b%s%b\n' "$BL" "$UI_LABEL_WIDTH" "${label}:" "$CL" "$color" "$display_value" "$CL"
}

function mini_header() {
    echo ""
    echo -e "${YW}$1:${CL}"
}

function progress_line() {
    [ -n "${DEPLOY_OUTPUT_FILE:-}" ] && echo "$1" >> "$DEPLOY_OUTPUT_FILE"
}

function deploy_status_line() {
    local label="$1" value="${2:-unknown}" color="${3:-}" width="${4:-$UI_LABEL_WIDTH}" display_value=""
    local tick_prefix_width=2 effective_width=""
    [ -n "$value" ] || value="unknown"
    [ -n "$color" ] || color="$(status_color_for_value "$value")"
    display_value="$(ui_display_value "$value")"
    effective_width=$((width - tick_prefix_width))
    [ "$effective_width" -gt 0 ] || effective_width="$width"
    printf '%b %b%-*s%b %b%s%b\n' "$CM" "$BL" "$effective_width" "${label}:" "$CL" "$color" "$display_value" "$CL"
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

function admin_display_name() {
    case "${1:-}" in
        dockge) printf 'Dockge' ;;
        dockhand) printf 'Dockhand' ;;
        komodo) printf 'Komodo' ;;
        portainer) printf 'Portainer' ;;
        none|"") printf 'none' ;;
        *) printf '%s' "$1" ;;
    esac
}

function admin_compose_file() {
    case "${1:-}" in
        dockge) printf '%s' "$COMPOSE_DOCKGE" ;;
        dockhand) printf '%s' "$COMPOSE_DOCKHAND" ;;
        komodo) printf '%s' "$COMPOSE_KOMODO" ;;
        portainer) printf '%s' "$COMPOSE_PORTAINER" ;;
        *) printf '' ;;
    esac
}

function admin_override_file() {
    case "${1:-}" in
        dockge) printf '%s' "$OVERRIDE_DOCKGE" ;;
        dockhand) printf '%s' "$OVERRIDE_DOCKHAND" ;;
        komodo) printf '%s' "$OVERRIDE_KOMODO" ;;
        portainer) printf '%s' "$OVERRIDE_PORTAINER" ;;
        *) printf '' ;;
    esac
}

function admin_project_name() {
    case "${1:-}" in
        dockge) printf '%s' "$PROJECT_DOCKGE" ;;
        dockhand) printf '%s' "$PROJECT_DOCKHAND" ;;
        komodo) printf '%s' "$PROJECT_KOMODO" ;;
        portainer) printf '%s' "$PROJECT_PORTAINER" ;;
        *) printf '' ;;
    esac
}

function admin_primary_container() {
    case "${1:-}" in
        dockge) printf 'dockge' ;;
        dockhand) printf 'dockhand' ;;
        komodo) printf 'komodo-core' ;;
        portainer) printf 'portainer' ;;
        *) printf '' ;;
    esac
}

function admin_bootstrap_port() {
    case "${1:-}" in
        dockge) printf '5001' ;;
        dockhand) printf '3000' ;;
        komodo) printf '9120' ;;
        portainer) printf '9443' ;;
        *) printf '' ;;
    esac
}

function admin_bootstrap_scheme() {
    case "${1:-}" in
        portainer) printf 'https' ;;
        *) printf 'http' ;;
    esac
}

function admin_container_names() {
    case "${1:-}" in
        dockge) printf 'dockge\n' ;;
        dockhand) printf 'dockhand\n' ;;
        komodo) printf 'komodo-core\nkomodo-postgres\nkomodo-ferretdb\nkomodo-periphery\n' ;;
        portainer) printf 'portainer\n' ;;
    esac
}

function admin_container_exists() {
    local admin="${1:-}" name=""
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        docker inspect "$name" >/dev/null 2>&1 && return 0
    done < <(admin_container_names "$admin")
    return 1
}

function admin_container_running() {
    local admin="${1:-}" name="" state=""
    while IFS= read -r name; do
        [ -n "$name" ] || continue
        state="$(container_state "$name")"
        [ "$state" = "running" ] || [ "$state" = "healthy" ] || return 1
    done < <(admin_container_names "$admin")
    return 0
}

function admin_compose_exists() {
    local admin="${1:-}" compose="" override=""
    compose="$(admin_compose_file "$admin")"
    override="$(admin_override_file "$admin")"
    [ -n "$compose" ] && root_path_exists "${COMPOSE_DIR}/${compose}" && return 0
    [ -n "$override" ] && root_path_exists "${COMPOSE_DIR}/${override}" && return 0
    return 1
}

function admin_bootstrap_listening() {
    local admin="${1:-}" port=""
    port="$(admin_bootstrap_port "$admin")"
    [ -n "$port" ] || return 1
    [ "$(port_busy_status "$port")" = "listening" ]
}


function active_admin_csv() {
    local admin="" names="" sep=""
    for admin in dockge dockhand komodo portainer; do
        if admin_container_running "$admin" || admin_bootstrap_listening "$admin"; then
            names="${names}${sep}${admin}"
            sep=","
        fi
    done
    printf '%s' "$names"
}

function active_admin_count() {
    local csv="$(active_admin_csv)"
    if [ -z "$csv" ]; then
        printf '0'
    else
        awk -F, '{print NF}' <<< "$csv"
    fi
}

function active_admin_display_csv() {
    local csv="$(active_admin_csv)" item="" output="" sep=""
    if [ -z "$csv" ]; then
        printf 'none'
        return 0
    fi
    IFS=',' read -r -a _active_admin_items <<< "$csv"
    for item in "${_active_admin_items[@]}"; do
        output="${output}${sep}$(admin_display_name "$item")"
        sep=", "
    done
    printf '%s' "$output"
}

function selected_bootstrap_port_status() {
    local port="${SELECTED_BOOTSTRAP_PORT:-}"
    [ -n "$port" ] || { printf 'unknown'; return 0; }
    if [ "$(port_busy_status "$port")" = "available" ]; then
        printf 'available'
    elif admin_bootstrap_listening "$SELECTED_ADMIN_UI"; then
        printf 'platform-owned'
    else
        printf 'blocked'
    fi
}

function selected_bootstrap_port_display() {
    local status=""
    status="$(selected_bootstrap_port_status)"
    if [ -z "${SELECTED_BOOTSTRAP_PORT:-}" ]; then
        printf 'unknown'
        return 0
    fi
    case "$status" in
        available) printf '%s available' "$SELECTED_BOOTSTRAP_PORT" ;;
        platform-owned) printf '%s in use by %s' "$SELECTED_BOOTSTRAP_PORT" "$SELECTED_ADMIN_UI_DISPLAY" ;;
        blocked) printf '%s blocked' "$SELECTED_BOOTSTRAP_PORT" ;;
        *) printf '%s %s' "$SELECTED_BOOTSTRAP_PORT" "$status" ;;
    esac
}

function runtime_access_host() {
    local host=""
    host="$(hostname -I 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i !~ /^127\./) {print $i; exit}}' || true)"
    [ -n "$host" ] || host="$(hostname -f 2>/dev/null || true)"
    [ -n "$host" ] || host="localhost"
    printf '%s' "$host"
}

function selected_bootstrap_url() {
    if [ "${SCRIPT62_BOOTSTRAP_ACCESS:-unknown}" != "ready" ]; then
        printf ''
        return 0
    fi
    [ -n "${SELECTED_BOOTSTRAP_PORT:-}" ] || return 0
    printf '%s://%s:%s' "$SELECTED_BOOTSTRAP_SCHEME" "$(runtime_access_host)" "$SELECTED_BOOTSTRAP_PORT"
}

function detected_admin_ui() {
    local marker_admin="" admin=""
    marker_admin="$(marker_key_value SCRIPT62_SELECTED_ADMIN_UI "$COMPLETED_MARKER")"
    case "$marker_admin" in dockge|dockhand|komodo|portainer) printf '%s' "$marker_admin"; return 0 ;; esac
    for admin in dockge dockhand komodo portainer; do
        if admin_container_exists "$admin" || admin_compose_exists "$admin" || admin_bootstrap_listening "$admin"; then
            printf '%s' "$admin"
            return 0
        fi
    done
    printf 'none'
}

function future_business_marker_exists() {
    local marker=""
    for marker in /root/.circl8-authentik-completed /root/.final-hardening-sso-completed /root/.circl8-post-core-setup-completed /root/.circl8-postiz-completed /root/.circl8-n8n-completed /root/.circl8-landing-completed; do
        root_path_exists "$marker" && return 0
    done
    return 1
}

function refresh_business_mode() {
    if future_business_marker_exists; then BUSINESS_MODE="yes"; else BUSINESS_MODE="no"; fi
}



function refresh_selected_admin_context() {
    [ -n "$SELECTED_ADMIN_UI" ] || return 0
    SELECTED_ADMIN_UI_DISPLAY="$(admin_display_name "$SELECTED_ADMIN_UI")"
    SELECTED_COMPOSE_FILE="$(admin_compose_file "$SELECTED_ADMIN_UI")"
    SELECTED_OVERRIDE_FILE="$(admin_override_file "$SELECTED_ADMIN_UI")"
    SELECTED_PROJECT="$(admin_project_name "$SELECTED_ADMIN_UI")"
    SELECTED_CONTAINER="$(admin_primary_container "$SELECTED_ADMIN_UI")"
    SELECTED_BOOTSTRAP_PORT="$(admin_bootstrap_port "$SELECTED_ADMIN_UI")"
    SELECTED_BOOTSTRAP_SCHEME="$(admin_bootstrap_scheme "$SELECTED_ADMIN_UI")"
    SELECTED_FILES=("$SELECTED_OVERRIDE_FILE" "$SELECTED_COMPOSE_FILE")
}

function refresh_setup_mode() {
    refresh_business_mode
    PREVIOUS_ADMIN_UI="$(detected_admin_ui)"
    EXISTING_ADMIN_UI="$PREVIOUS_ADMIN_UI"
    [ -n "$EXISTING_ADMIN_UI" ] || EXISTING_ADMIN_UI="none"
    [ "$EXISTING_ADMIN_UI" = "none" ] && EXISTING_ADMIN_UI="none"

    if [ -z "$SELECTED_ADMIN_UI" ]; then
        SETUP_MODE="fresh-install"
        ACTION_MODE="fresh-install"
        [ "$PREVIOUS_ADMIN_UI" != "none" ] && { SETUP_MODE="rerun-update"; ACTION_MODE="rerun-update"; }
        return 0
    fi

    if admin_bootstrap_listening "$SELECTED_ADMIN_UI"; then
        BOOTSTRAP_CURRENT="running"
    else
        BOOTSTRAP_CURRENT="not detected"
    fi

    if [ "$PREVIOUS_ADMIN_UI" = "none" ]; then
        SETUP_MODE="fresh-install"
        ACTION_MODE="fresh-install"
        BOOTSTRAP_MODE="enabled"
        BOOTSTRAP_ACTION="enable"
        MIGRATION_STOP_OLD="not-applicable"
    elif [ "$PREVIOUS_ADMIN_UI" = "$SELECTED_ADMIN_UI" ]; then
        SETUP_MODE="rerun-update"
        ACTION_MODE="rerun-update"
        if admin_bootstrap_listening "$SELECTED_ADMIN_UI"; then
            BOOTSTRAP_MODE="preserved-enabled"
            BOOTSTRAP_ACTION="keep enabled"
        else
            BOOTSTRAP_MODE="preserved-disabled"
            BOOTSTRAP_ACTION="keep disabled"
        fi
        MIGRATION_STOP_OLD="not-applicable"
    else
        SETUP_MODE="migration"
        ACTION_MODE="migration"
        BOOTSTRAP_MODE="temporary-for-migration"
        BOOTSTRAP_ACTION="temporary for migration"
        MIGRATION_STOP_OLD="after-new-verified"
    fi
}

function read_yes_no() {
    local prompt="$1" default="${2:-y}" answer=""
    local label="Y/n"
    [[ "$default" =~ ^[Nn]$ ]] && label="y/N"
    if [ -r /dev/tty ]; then read -r -p "${prompt} [${label}]: " answer </dev/tty || answer=""; else read -r -p "${prompt} [${label}]: " answer || answer=""; fi
    [ -z "$answer" ] && answer="$default"
    printf '%s' "$answer"
}

function collect_admin_ui_selection() {
    local choice="" count="" detected_display=""
    section "ADMIN UI SELECTION"
    refresh_setup_mode
    count="$(active_admin_count)"
    if [ "$count" -gt 1 ]; then
        aligned_status_line "Existing active Admin UI" "multiple detected" "$RD"
        aligned_status_line "Detected stacks" "$(active_admin_display_csv)" "$YW"
        aligned_status_line "Live/business mode" "$BUSINESS_MODE" "$(status_color_for_value "$BUSINESS_MODE")"
        aligned_status_line "Status" "cleanup required before migration" "$RD"
        msg_error "Multiple active Admin UI stacks were detected. Stop the extra Admin UI stack(s) before running Script 6.2 migration."
    fi

    if [ "$count" -eq 1 ]; then
        detected_display="$(active_admin_display_csv)"
    else
        detected_display="none"
    fi

    aligned_status_line "Existing active Admin UI" "$detected_display" "$(status_color_for_value "$detected_display")"
    aligned_status_line "Live/business mode" "$BUSINESS_MODE" "$(status_color_for_value "$BUSINESS_MODE")"
    echo ""
    echo -e "${YW}Choose exactly one Admin UI to deploy/manage:${CL}"
    echo -e "  ${YW}1:${CL} ${GN}Dockge${CL}"
    echo -e "  ${YW}2:${CL} ${GN}Dockhand${CL}"
    echo -e "  ${YW}3:${CL} ${GN}Komodo${CL}"
    echo -e "  ${YW}4:${CL} ${GN}Portainer${CL}"
    echo ""
    while true; do
        if [ -r /dev/tty ]; then read -r -p "Select Admin UI option number [default: 1]: " choice </dev/tty || choice=""; else read -r -p "Select Admin UI option number [default: 1]: " choice || choice=""; fi
        [ -z "$choice" ] && choice="1"
        case "$choice" in
            1) SELECTED_ADMIN_UI="dockge"; break ;;
            2) SELECTED_ADMIN_UI="dockhand"; break ;;
            3) SELECTED_ADMIN_UI="komodo"; break ;;
            4) SELECTED_ADMIN_UI="portainer"; break ;;
            *) echo -e "${YW}Enter 1, 2, 3, or 4.${CL}" ;;
        esac
    done
    refresh_selected_admin_context
    refresh_setup_mode
    msg_ok "Selected Admin UI: ${SELECTED_ADMIN_UI_DISPLAY}"
}


function collect_bootstrap_decision() {
    local keep=""
    section "BOOTSTRAP ACCESS"
    refresh_setup_mode

    if [ "$ACTION_MODE" = "rerun-update" ]; then
        if admin_bootstrap_listening "$SELECTED_ADMIN_UI"; then
            echo -e "${YW}${SELECTED_ADMIN_UI_DISPLAY} bootstrap is currently running.${CL}"
            keep="$(read_yes_no "Keep bootstrap access enabled?" "y")"
            if [[ "$keep" =~ ^[Yy]$ ]]; then
                BOOTSTRAP_MODE="user-enabled"
                BOOTSTRAP_ACTION="keep enabled"
                msg_ok "Bootstrap access will be kept enabled."
            else
                BOOTSTRAP_MODE="user-disabled"
                BOOTSTRAP_ACTION="keep disabled"
                msg_ok "Bootstrap access will be kept disabled."
            fi
        else
            echo -e "${YW}${SELECTED_ADMIN_UI_DISPLAY} bootstrap is not currently running.${CL}"
            keep="$(read_yes_no "Enable bootstrap access?" "n")"
            if [[ "$keep" =~ ^[Yy]$ ]]; then
                BOOTSTRAP_MODE="user-enabled"
                BOOTSTRAP_ACTION="enable"
                msg_ok "Bootstrap access will be enabled."
            else
                BOOTSTRAP_MODE="user-disabled"
                BOOTSTRAP_ACTION="keep disabled"
                msg_ok "Bootstrap access will be kept disabled."
            fi
        fi
    elif [ "$ACTION_MODE" = "migration" ]; then
        echo -e "${YW}${SELECTED_ADMIN_UI_DISPLAY} bootstrap will be enabled temporarily for migration verification.${CL}"
        if [ "$BUSINESS_MODE" = "yes" ]; then
            keep="$(read_yes_no "Keep new bootstrap access after successful migration?" "n")"
        else
            keep="$(read_yes_no "Keep new bootstrap access after successful migration?" "y")"
        fi
        if [[ "$keep" =~ ^[Yy]$ ]]; then
            BOOTSTRAP_KEEP_AFTER_MIGRATION="yes"
            BOOTSTRAP_MODE="user-enabled"
            BOOTSTRAP_ACTION="temporary test, then keep enabled"
            msg_ok "Bootstrap access will be kept enabled after migration."
        else
            BOOTSTRAP_KEEP_AFTER_MIGRATION="no"
            BOOTSTRAP_MODE="temporary-for-migration"
            BOOTSTRAP_ACTION="temporary test, then close"
            msg_ok "Bootstrap access will be closed after migration."
        fi
    else
        BOOTSTRAP_MODE="enabled"
        BOOTSTRAP_ACTION="enable"
        echo -e "${YW}${SELECTED_ADMIN_UI_DISPLAY} bootstrap will be enabled for initial setup.${CL}"
        msg_ok "Bootstrap access will be enabled."
    fi
}

function show_selected_stack_preflight() {
    local port_status=""
    section "SELECTED STACK PREFLIGHT"
    refresh_setup_mode

    aligned_status_line "Selected Admin UI" "$SELECTED_ADMIN_UI_DISPLAY" "$ANS"
    aligned_status_line "Current Admin UI" "$(admin_display_name "$PREVIOUS_ADMIN_UI")" "$(status_color_for_value "$PREVIOUS_ADMIN_UI")"
    aligned_status_line "Action" "$ACTION_MODE" "$(status_color_for_value "$ACTION_MODE")"
    aligned_status_line "Selected compose" "$SELECTED_COMPOSE_FILE" "$GN"
    aligned_status_line "Selected bootstrap" "$SELECTED_OVERRIDE_FILE" "$GN"
    aligned_status_line "Bootstrap current" "$BOOTSTRAP_CURRENT" "$(status_color_for_value "$BOOTSTRAP_CURRENT")"
    aligned_status_line "Bootstrap port" "$(selected_bootstrap_port_display)" "$(status_color_for_value "$(selected_bootstrap_port_status)")"
    aligned_status_line "Bootstrap action" "$BOOTSTRAP_ACTION" "$GN"
    aligned_status_line "Live/business mode" "$BUSINESS_MODE" "$(status_color_for_value "$BUSINESS_MODE")"
    if [ "$ACTION_MODE" = "migration" ]; then
        aligned_status_line "Migration safety" "stop old after new verified" "$YW"
    fi
    aligned_status_line "Public Auth route" "$SCRIPT62_PUBLIC_AUTH_ROUTES" "$YW"

    port_status="$(selected_bootstrap_port_status)"
    if [ "$port_status" = "blocked" ] && { [ "$BOOTSTRAP_ACTION" != "keep disabled" ] && [ "$BOOTSTRAP_ACTION" != "disable" ]; }; then
        msg_warn "Selected bootstrap port ${SELECTED_BOOTSTRAP_PORT} is already in use by something other than the selected Admin UI. Deployment may fail unless that listener is expected."
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
    refresh_setup_mode
    [ "$failure" = "no" ] || msg_error "Runtime preflight failed. Fix the checks above, then rerun Script 6.2."
    msg_ok "RUNTIME PREFLIGHT PASSED"
}

function show_setup_plan_and_confirm() {
    local apply_yn=""
    section "SETUP PLAN"
    if [ "$ACTION_MODE" = "migration" ]; then
        echo -e "${YW}Script 6.2 will deploy ${SELECTED_ADMIN_UI_DISPLAY}, verify it, then stop the old Admin UI after confirmation.${CL}"
    elif [ "$ACTION_MODE" = "rerun-update" ]; then
        echo -e "${YW}Rerun/update detected. ${SELECTED_ADMIN_UI_DISPLAY} data and secrets will be preserved.${CL}"
    else
        echo -e "${YW}Script 6.2 will deploy only the selected Admin UI after confirmation.${CL}"
    fi
    echo ""
    echo -e "${YW}Setup mode:${CL}"
    aligned_status_line "Mode" "$ACTION_MODE" "$(status_color_for_value "$ACTION_MODE")"
    aligned_status_line "Selected Admin UI" "$SELECTED_ADMIN_UI_DISPLAY" "$ANS"
    aligned_status_line "Existing Admin UI" "$(admin_display_name "$PREVIOUS_ADMIN_UI")" "$(status_color_for_value "$PREVIOUS_ADMIN_UI")"
    aligned_status_line "Live/business mode" "$BUSINESS_MODE" "$(status_color_for_value "$BUSINESS_MODE")"
    aligned_status_line "Bootstrap current" "$BOOTSTRAP_CURRENT" "$(status_color_for_value "$BOOTSTRAP_CURRENT")"
    aligned_status_line "Bootstrap port" "$(selected_bootstrap_port_display)" "$(status_color_for_value "$(selected_bootstrap_port_status)")"
    aligned_status_line "Bootstrap action" "$BOOTSTRAP_ACTION" "$GN"
    if [ "$ACTION_MODE" = "migration" ]; then
        aligned_status_line "Stop old stack" "after new verified" "$YW"
        aligned_status_line "Keep new bootstrap" "$BOOTSTRAP_KEEP_AFTER_MIGRATION" "$(status_color_for_value "$BOOTSTRAP_KEEP_AFTER_MIGRATION")"
    fi
    aligned_status_line "Public Auth route" "pending Script 6.3" "$YW"

    if [ "$ACTION_MODE" = "migration" ]; then
        echo ""
        echo -e "${YW}Migration safety:${CL}"
        echo -e "${YW}Existing Admin UI stays running until ${SELECTED_ADMIN_UI_DISPLAY} verifies successfully.${CL}"
        echo -e "${YW}Old data, secrets, and compose files are preserved; only the old stack is stopped.${CL}"
    fi
    echo ""
    echo -e "${YW}Apply changes:${CL}"
    aligned_status_line "Compose file" "$SELECTED_COMPOSE_FILE" "$GN"
    aligned_status_line "Bootstrap override" "$SELECTED_OVERRIDE_FILE" "$GN"
    aligned_status_line "Secrets/passwords" "selected only" "$GN"
    aligned_status_line "Docker networks" "verify/reuse" "$GN"
    aligned_status_line "Compose config" "validate selected only" "$GN"
    aligned_status_line "Deployment" "deploy selected only" "$GN"
    if [ "$ACTION_MODE" = "migration" ]; then
        aligned_status_line "Migration" "stop old after verify" "$YW"
    else
        aligned_status_line "Migration" "not-applicable" "$YW"
    fi
    aligned_status_line "Environment" "loaded from Script 6.1 handoff" "$GN"
    echo ""
    if [ -r /dev/tty ]; then read -r -p "Apply this Admin UI bootstrap setup plan? [Y/n]: " apply_yn </dev/tty || apply_yn=""; else read -r -p "Apply this Admin UI bootstrap setup plan? [Y/n]: " apply_yn || apply_yn=""; fi
    if [[ "$apply_yn" =~ ^[Nn]$ ]]; then
        echo -e "${YW}Admin UI bootstrap setup cancelled. No compose files or stacks were changed.${CL}"
        exit 0
    fi
    echo -e " ${CM} ${GN}Applying confirmed Admin UI bootstrap setup plan.${CL}"
}

function raw_url_path_encode() {
    local value="${1:-}"
    # GitHub raw URLs require literal square brackets in filenames to be percent-encoded.
    # Keep local destination filenames unchanged; encode only the URL path component.
    printf '%s' "$value" | sed 's/\[/%5B/g; s/\]/%5D/g'
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

function admin_file_role() {
    case "${1:-}" in
        *bootstrap-override.yml) printf 'bootstrap' ;;
        *compose.yml) printf 'compose' ;;
        *) printf 'file' ;;
    esac
}

function install_admin_ui_file() {
    local filename="${1:-}" encoded_filename="" local_source="" url="" dest="" tmp="" display_name="" file_role="" action_word=""
    [ -n "$filename" ] || msg_error "Admin UI filename was not provided."
    display_name="$(compose_display_name "$filename")"
    file_role="$(admin_file_role "$filename")"
    encoded_filename="$(raw_url_path_encode "$filename")"
    local_source="${SCRIPT_DIR}/docker/${filename}"
    url="${RAW_BASE}/docker/${encoded_filename}"
    dest="${COMPOSE_DIR}/${filename}"
    if [ -f "$local_source" ]; then
        action_word="Installing"
        progress_line "${action_word} ${display_name} ${file_role}"
        run_cmd "installing local ${filename}" cp "$local_source" "$dest"
    else
        action_word="Downloading"
        progress_line "${action_word} ${display_name} ${file_role}"
        tmp="$(mktemp)"; TEMP_FILES+=("$tmp")
        if ! download_file "$url" "$tmp" >> "$DEPLOY_OUTPUT_FILE" 2>&1; then
            { echo "Download failed for selected Admin UI file: ${filename}"; echo "URL: ${url}"; } >> "$DEPLOY_OUTPUT_FILE"
            fail_with_deployment_log "$display_name" "$filename" "${SELECTED_PROJECT:-n/a}" "Failed to download selected Admin UI file: ${filename}"
        fi
        if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" cp "$tmp" "$dest"; else cp "$tmp" "$dest"; fi
    fi
    root_file_not_empty "$dest" || msg_error "Admin UI file install failed or produced an empty file: ${dest}"
    run_cmd "setting ${filename} ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$dest"
    run_cmd "setting ${filename} mode" chmod 640 "$dest"
    deploy_status_line "${display_name} ${file_role}" "installed" "$GN"
}

function install_admin_ui_files() {
    mini_header "Compose files"
    local file=""
    run_cmd "creating compose directory" mkdir -p "$COMPOSE_DIR"
    for file in "${SELECTED_FILES[@]}"; do install_admin_ui_file "$file"; done
}

function verify_networks() {
    mini_header "Docker networks"
    docker network inspect t2_proxy >/dev/null 2>&1 && NETWORK_T2_PROXY="yes" || NETWORK_T2_PROXY="no"
    docker network inspect socket_proxy >/dev/null 2>&1 && NETWORK_SOCKET_PROXY="yes" || NETWORK_SOCKET_PROXY="no"
    deploy_status_line "t2_proxy" "$NETWORK_T2_PROXY" "$(status_color_for_value "$NETWORK_T2_PROXY")"
    deploy_status_line "socket_proxy" "$NETWORK_SOCKET_PROXY" "$(status_color_for_value "$NETWORK_SOCKET_PROXY")"
    [ "$NETWORK_T2_PROXY" = "yes" ] && [ "$NETWORK_SOCKET_PROXY" = "yes" ] || msg_error "Required Script 6.1 Docker networks are missing."
}

function generate_secret() { openssl rand -hex 32 | cut -c1-48; }
function env_has_key() { root_read_file "$ENV_FILE" 2>/dev/null | grep -Eq "^${1}="; }
function append_env_key_secret() {
    local key="$1" value=""
    if env_has_key "$key"; then return 0; fi
    value="$(generate_secret)"
    if [ -n "$SUDO_CMD" ]; then printf '%s="%s"\n' "$key" "$value" | "$SUDO_CMD" tee -a "$ENV_FILE" >/dev/null; else printf '%s="%s"\n' "$key" "$value" >> "$ENV_FILE"; fi
}

function prompt_secret_mode_for_komodo() {
    local existing="no" choice=""
    if env_has_key "KOMODO_DB_PASSWORD" && env_has_key "KOMODO_PASSKEY" && env_has_key "KOMODO_JWT_SECRET" && env_has_key "KOMODO_WEBHOOK_SECRET"; then existing="yes"; fi
    mini_header "Secrets / passwords"
    if [ "$SELECTED_ADMIN_UI" != "komodo" ]; then
        SECRET_MODE="not-required"
        deploy_status_line "${SELECTED_ADMIN_UI_DISPLAY} secrets" "not-required" "$GN"
        return 0
    fi
    if [ "$existing" = "yes" ]; then
        echo -e "${YW}Existing Komodo local secrets were detected. Values will never be printed.${CL}"
        echo -e "  ${YW}1:${CL} ${GN}Reuse existing secrets${CL}"
        echo -e "  ${YW}2:${CL} ${YW}Regenerate missing/selected secrets${CL}"
        echo ""
        if [ -r /dev/tty ]; then read -r -p "Select Komodo secret option [default: 1]: " choice </dev/tty || choice=""; else read -r -p "Select Komodo secret option [default: 1]: " choice || choice=""; fi
        [ -z "$choice" ] && choice="1"
        case "$choice" in
            2) SECRET_MODE="generated" ;;
            *) SECRET_MODE="reused" ;;
        esac
    else
        echo -e "${YW}Komodo requires local app secrets. Autogeneration is recommended.${CL}"
        echo -e "  ${YW}1:${CL} ${GN}Autogenerate secrets${CL}"
        echo -e "  ${YW}2:${CL} ${YW}Enter values manually later and cancel now${CL}"
        echo ""
        if [ -r /dev/tty ]; then read -r -p "Select Komodo secret option [default: 1]: " choice </dev/tty || choice=""; else read -r -p "Select Komodo secret option [default: 1]: " choice || choice=""; fi
        [ -z "$choice" ] && choice="1"
        if [ "$choice" = "2" ]; then
            SECRET_MODE="manual"
            msg_error "Manual Komodo secret entry is not printed/logged by this script. Add secrets to .env, then rerun."
        fi
        SECRET_MODE="generated"
    fi
    deploy_status_line "Komodo secrets" "$SECRET_MODE" "$(status_color_for_value "$SECRET_MODE")"
}

function ensure_admin_ui_secret_env() {
    prompt_secret_mode_for_komodo
    if [ "$SELECTED_ADMIN_UI" != "komodo" ]; then return 0; fi
    if [ "$SECRET_MODE" = "generated" ]; then
        append_env_key_secret "KOMODO_DB_PASSWORD"
        append_env_key_secret "KOMODO_PASSKEY"
        append_env_key_secret "KOMODO_JWT_SECRET"
        append_env_key_secret "KOMODO_WEBHOOK_SECRET"
    fi
    run_cmd "setting .env mode" chmod 600 "$ENV_FILE"
}

function compose_path() { printf '%s/%s' "$COMPOSE_DIR" "$1"; }
function compose_project_for_file() { printf '%s' "$SELECTED_PROJECT"; }
function override_for_file() { printf '%s' "$SELECTED_OVERRIDE_FILE"; }
function primary_container_for_file() { printf '%s' "$SELECTED_CONTAINER"; }

function selected_compose_args() {
    local include_bootstrap="${1:-yes}"
    printf '%s\n' "--env-file" "$ENV_FILE" "-p" "$SELECTED_PROJECT" "-f" "$(compose_path "$SELECTED_COMPOSE_FILE")"
    if [ "$include_bootstrap" = "yes" ]; then
        printf '%s\n' "-f" "$(compose_path "$SELECTED_OVERRIDE_FILE")"
    fi
}

function validate_compose_files() {
    local base_ok="no" bootstrap_ok="no"
    mini_header "Compose validation"
    if docker compose --env-file "$ENV_FILE" -p "$SELECTED_PROJECT" -f "$(compose_path "$SELECTED_COMPOSE_FILE")" config >/dev/null; then
        base_ok="yes"
        deploy_status_line "${SELECTED_ADMIN_UI_DISPLAY} compose" "valid" "$GN"
    fi
    [ "$base_ok" = "yes" ] || fail_with_deployment_log "$SELECTED_ADMIN_UI_DISPLAY" "$SELECTED_COMPOSE_FILE" "$SELECTED_PROJECT" "${SELECTED_ADMIN_UI_DISPLAY} compose config validation failed"

    if [ "$BOOTSTRAP_ACTION" = "keep disabled" ] || [ "$BOOTSTRAP_ACTION" = "disable" ]; then
        deploy_status_line "${SELECTED_ADMIN_UI_DISPLAY} bootstrap" "skipped" "$YW"
        return 0
    fi

    if docker compose --env-file "$ENV_FILE" -p "$SELECTED_PROJECT" -f "$(compose_path "$SELECTED_COMPOSE_FILE")" -f "$(compose_path "$SELECTED_OVERRIDE_FILE")" config >/dev/null; then
        bootstrap_ok="yes"
        deploy_status_line "${SELECTED_ADMIN_UI_DISPLAY} bootstrap" "valid" "$GN"
    fi
    [ "$bootstrap_ok" = "yes" ] || fail_with_deployment_log "$SELECTED_ADMIN_UI_DISPLAY" "$SELECTED_OVERRIDE_FILE" "$SELECTED_PROJECT" "${SELECTED_ADMIN_UI_DISPLAY} bootstrap config validation failed"
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
        echo "Action: ${ACTION_MODE}"
        echo "Selected Admin UI: ${SELECTED_ADMIN_UI}"
        echo "Previous Admin UI: ${PREVIOUS_ADMIN_UI}"
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
    mini_header "Docker readiness"
    for ((i=1; i<=attempts; i++)); do
        docker_ready="no"; compose_ready="no"; api_ready="no"; networks_ready="no"
        command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1 && docker_ready="yes"
        docker compose version >/dev/null 2>&1 && compose_ready="yes"
        docker info >/dev/null 2>&1 && api_ready="yes"
        docker network inspect socket_proxy >/dev/null 2>&1 && docker network inspect t2_proxy >/dev/null 2>&1 && networks_ready="yes"
        { echo ""; echo "--- Docker readiness attempt ${i}/${attempts} ---"; echo "Date: $(date)"; echo "Docker command: ${docker_ready}"; echo "Docker Compose: ${compose_ready}"; echo "Docker API: ${api_ready}"; echo "Docker networks: ${networks_ready}"; } >> "$DEPLOY_OUTPUT_FILE"
        if [ "$docker_ready" = "yes" ] && [ "$compose_ready" = "yes" ] && [ "$api_ready" = "yes" ] && [ "$networks_ready" = "yes" ]; then
            deploy_status_line "Docker daemon" "ready" "$GN"
            deploy_status_line "Docker Compose" "ready" "$GN"
            deploy_status_line "Docker API" "responsive" "$GN"
            deploy_status_line "Docker networks" "settled" "$GN"
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
        case "$state" in running|healthy) deploy_status_line "$display_name" "$state" "$(status_color_for_value "$state")"; return 0 ;; esac
        sleep "$interval_seconds"
        elapsed=$((elapsed + interval_seconds))
    done
    fail_with_deployment_log "$display_name" "n/a" "n/a" "${display_name} did not become ready before timeout"
}

function deploy_selected_stack() {
    local include_bootstrap="${1:-yes}" attempt="" max_attempts=3 retry_delay=4 args=()
    args=(--env-file "$ENV_FILE" -p "$SELECTED_PROJECT" -f "$(compose_path "$SELECTED_COMPOSE_FILE")")
    if [ "$include_bootstrap" = "yes" ]; then args+=(-f "$(compose_path "$SELECTED_OVERRIDE_FILE")"); fi
    progress_line "Deploying ${SELECTED_ADMIN_UI_DISPLAY}"
    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        { echo ""; echo "--- Deploying ${SELECTED_ADMIN_UI_DISPLAY} attempt ${attempt}/${max_attempts} ---"; echo "Date: $(date)"; echo "Project: ${SELECTED_PROJECT}"; echo "Compose file: $(compose_path "$SELECTED_COMPOSE_FILE")"; echo "Bootstrap: ${include_bootstrap}"; } >> "$DEPLOY_OUTPUT_FILE"
        if docker compose "${args[@]}" up -d --remove-orphans >> "$DEPLOY_OUTPUT_FILE" 2>&1; then
            deploy_status_line "${SELECTED_ADMIN_UI_DISPLAY}" "deployed" "$GN"
            return 0
        fi
        { echo "Deploy attempt ${attempt}/${max_attempts} failed for ${SELECTED_ADMIN_UI_DISPLAY}."; echo "Retry delay: ${retry_delay}s"; } >> "$DEPLOY_OUTPUT_FILE"
        [ "$attempt" -lt "$max_attempts" ] && sleep "$retry_delay"
    done
    fail_with_deployment_log "$SELECTED_ADMIN_UI_DISPLAY" "$SELECTED_COMPOSE_FILE" "$SELECTED_PROJECT" "${SELECTED_ADMIN_UI_DISPLAY} deployment failed"
}

function stop_admin_stack() {
    local admin="${1:-}" project="" compose="" override="" display=""
    case "$admin" in dockge|dockhand|komodo|portainer) ;; *) return 0 ;; esac
    project="$(admin_project_name "$admin")"
    compose="$(admin_compose_file "$admin")"
    override="$(admin_override_file "$admin")"
    display="$(admin_display_name "$admin")"
    if [ -f "$(compose_path "$compose")" ]; then
        { echo ""; echo "--- Stopping old Admin UI stack ${display} ---"; echo "Date: $(date)"; } >> "$DEPLOY_OUTPUT_FILE"
        if [ -f "$(compose_path "$override")" ]; then
            docker compose --env-file "$ENV_FILE" -p "$project" -f "$(compose_path "$compose")" -f "$(compose_path "$override")" down >> "$DEPLOY_OUTPUT_FILE" 2>&1 || true
        else
            docker compose --env-file "$ENV_FILE" -p "$project" -f "$(compose_path "$compose")" down >> "$DEPLOY_OUTPUT_FILE" 2>&1 || true
        fi
    else
        while IFS= read -r name; do [ -n "$name" ] && docker rm -f "$name" >> "$DEPLOY_OUTPUT_FILE" 2>&1 || true; done < <(admin_container_names "$admin")
    fi
    deploy_status_line "$display" "stopped old stack" "$YW"
}

function update_admin_statuses_after_deploy() {
    local admin=""
    SCRIPT62_DOCKGE="not-selected"; SCRIPT62_DOCKHAND="not-selected"; SCRIPT62_KOMODO="not-selected"; SCRIPT62_PORTAINER="not-selected"
    for admin in dockge dockhand komodo portainer; do
        if [ "$admin" = "$SELECTED_ADMIN_UI" ]; then
            case "$admin" in dockge) SCRIPT62_DOCKGE="running" ;; dockhand) SCRIPT62_DOCKHAND="running" ;; komodo) SCRIPT62_KOMODO="running" ;; portainer) SCRIPT62_PORTAINER="running" ;; esac
        elif [ "$ACTION_MODE" = "migration" ] && [ "$admin" = "$PREVIOUS_ADMIN_UI" ]; then
            case "$admin" in dockge) SCRIPT62_DOCKGE="stopped-old" ;; dockhand) SCRIPT62_DOCKHAND="stopped-old" ;; komodo) SCRIPT62_KOMODO="stopped-old" ;; portainer) SCRIPT62_PORTAINER="stopped-old" ;; esac
        fi
    done
}

function deploy_admin_ui() {
    local include_bootstrap="yes"
    mini_header "Admin UI"
    if [ "$BOOTSTRAP_ACTION" = "keep disabled" ] || [ "$BOOTSTRAP_ACTION" = "disable" ]; then include_bootstrap="no"; fi
    if [ "$ACTION_MODE" = "migration" ]; then include_bootstrap="yes"; fi
    deploy_selected_stack "$include_bootstrap"
    wait_for_container_ready "$SELECTED_CONTAINER" "$SELECTED_ADMIN_UI_DISPLAY" 120 4
    if [ "$ACTION_MODE" = "migration" ]; then
        stop_admin_stack "$PREVIOUS_ADMIN_UI"
        if [ "$BOOTSTRAP_KEEP_AFTER_MIGRATION" = "no" ]; then
            progress_line "Closing temporary ${SELECTED_ADMIN_UI_DISPLAY} bootstrap access"
            deploy_selected_stack "no"
            SCRIPT62_BOOTSTRAP_ACCESS="temporary-closed"
            BOOTSTRAP_MODE="temporary-for-migration"
            deploy_status_line "${SELECTED_ADMIN_UI_DISPLAY} bootstrap" "temporary closed" "$YW"
        fi
    fi
    update_admin_statuses_after_deploy
}

function verify_record_first_issue() {
    local issue_type="$1" check="$2" reason="$3" fix="$4"
    if [ -z "$VERIFY_FIRST_ISSUE_TYPE" ]; then VERIFY_FIRST_ISSUE_TYPE="$issue_type"; VERIFY_FIRST_ISSUE_CHECK="$check"; VERIFY_FIRST_ISSUE_REASON="$reason"; VERIFY_FIRST_ISSUE_FIX="$fix"; fi
}

function create_verification_report() {
    msg_info "Creating Admin UI verification report"
    local report_body="" selected_state="" port=""
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
    root_file_not_empty "${COMPOSE_DIR}/${SELECTED_COMPOSE_FILE}" && verify_pass "selected compose file exists" || verify_fail "selected compose file" "missing or empty" "rerun Script 6.2"
    root_file_not_empty "${COMPOSE_DIR}/${SELECTED_OVERRIDE_FILE}" && verify_pass "selected bootstrap override exists" || verify_fail "selected bootstrap override" "missing or empty" "rerun Script 6.2"

    selected_state="$(container_state "$SELECTED_CONTAINER")"
    if [ "$selected_state" = "running" ] || [ "$selected_state" = "healthy" ]; then verify_pass "${SELECTED_ADMIN_UI_DISPLAY} running"; else verify_fail "${SELECTED_ADMIN_UI_DISPLAY} running" "state is ${selected_state}" "inspect docker logs ${SELECTED_CONTAINER}"; fi

    port="$SELECTED_BOOTSTRAP_PORT"
    if [ "$BOOTSTRAP_ACTION" = "keep disabled" ] || [ "$BOOTSTRAP_ACTION" = "disable" ] || [ "$SCRIPT62_BOOTSTRAP_ACCESS" = "temporary-closed" ]; then
        [ "$SCRIPT62_BOOTSTRAP_ACCESS" = "temporary-closed" ] || SCRIPT62_BOOTSTRAP_ACCESS="disabled"
        verify_info "Bootstrap access disabled by selected mode"
    elif [ -n "$port" ] && [ "$(port_busy_status "$port")" = "listening" ]; then
        SCRIPT62_BOOTSTRAP_ACCESS="ready"
        verify_pass "${SELECTED_ADMIN_UI_DISPLAY} bootstrap port ${port} listening"
    else
        SCRIPT62_BOOTSTRAP_ACCESS="failed"
        verify_fail "${SELECTED_ADMIN_UI_DISPLAY} bootstrap access" "port ${port:-unknown} is not listening" "check compose override and container logs"
    fi

    if [ "$ACTION_MODE" = "migration" ] && [ "$PREVIOUS_ADMIN_UI" != "none" ]; then
        if admin_container_running "$PREVIOUS_ADMIN_UI"; then verify_fail "old Admin UI stopped" "${PREVIOUS_ADMIN_UI} still running" "stop old stack after verifying selected Admin UI"; else verify_pass "old Admin UI stopped after migration"; fi
    fi

    verify_info "Public Auth route is pending Script 6.3 Authentik"
    if [ "$VERIFY_FAIL_COUNT" -gt 0 ]; then VERIFY_STATUS="FAIL"; elif [ "$VERIFY_WARN_COUNT" -gt 0 ]; then VERIFY_STATUS="PASS_WITH_WARNINGS"; else VERIFY_STATUS="PASS"; fi
    if [ "$VERIFY_STATUS" = "PASS" ] || [ "$VERIFY_STATUS" = "PASS_WITH_WARNINGS" ]; then SCRIPT62_READY_FOR_SCRIPT63="yes"; SCRIPT62_READY_FOR_SCRIPT64="yes"; SCRIPT62_READY_FOR_SCRIPT65="yes"; SCRIPT62_READY_FOR_SCRIPT66="yes"; fi

    {
        echo "--- CIRCL8 ADMIN UI VERIFICATION REPORT ---"
        echo "Date: $(date)"
        echo "Docker dir: ${DOCKER_DIR}"
        echo "Compose dir: ${COMPOSE_DIR}"
        echo "Secrets dir: ${SECRETS_DIR}"
        echo "Selected Admin UI: ${SELECTED_ADMIN_UI}"
        echo "Previous Admin UI: ${PREVIOUS_ADMIN_UI}"
        echo "Action: ${ACTION_MODE}"
        echo "Secret mode: ${SECRET_MODE}"
        echo "Bootstrap mode: ${BOOTSTRAP_MODE}"
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
        echo "SCRIPT62_SELECTED_ADMIN_UI=${SELECTED_ADMIN_UI}"
        echo "SCRIPT62_PREVIOUS_ADMIN_UI=${PREVIOUS_ADMIN_UI}"
        echo "SCRIPT62_ACTION=${ACTION_MODE}"
        echo "SCRIPT62_SECRET_MODE=${SECRET_MODE}"
        echo "SCRIPT62_BOOTSTRAP_MODE=${BOOTSTRAP_MODE}"
        echo "SCRIPT62_MIGRATION_STOP_OLD=${MIGRATION_STOP_OLD}"
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

function selected_admin_status_value() {
    case "$SELECTED_ADMIN_UI" in
        dockge) printf '%s' "$SCRIPT62_DOCKGE" ;;
        dockhand) printf '%s' "$SCRIPT62_DOCKHAND" ;;
        komodo) printf '%s' "$SCRIPT62_KOMODO" ;;
        portainer) printf '%s' "$SCRIPT62_PORTAINER" ;;
        *) printf 'unknown' ;;
    esac
}

function show_finished_summary() {
    section_flash_success "     ━━━━━━━━━━━━━━━━━    FINISHED    ━━━━━━━━━━━━━━━━━"
    echo -e "${YW}Admin UI:${CL}"
    final_line "Selected" "$SELECTED_ADMIN_UI_DISPLAY" "$ANS"
    final_line "Status" "$(selected_admin_status_value)" "$(status_color_for_value "$(selected_admin_status_value)")"
    final_line "Action" "$ACTION_MODE" "$(status_color_for_value "$ACTION_MODE")"
    final_line "Secret mode" "$SECRET_MODE" "$(status_color_for_value "$SECRET_MODE")"
    if [ "$SCRIPT62_BOOTSTRAP_ACCESS" = "temporary-closed" ]; then
        final_line "Bootstrap" "closed after migration" "$YW"
    else
        final_line "Bootstrap" "$SCRIPT62_BOOTSTRAP_ACCESS" "$(status_color_for_value "$SCRIPT62_BOOTSTRAP_ACCESS")"
    fi
    if [ "$SCRIPT62_BOOTSTRAP_ACCESS" = "ready" ]; then
        final_line "Bootstrap URL" "$(selected_bootstrap_url)" "$GN"
    fi
    final_line "Public Auth route" "$SCRIPT62_PUBLIC_AUTH_ROUTES" "$YW"
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
    collect_admin_ui_selection
    collect_bootstrap_decision
    show_selected_stack_preflight
    show_setup_plan_and_confirm
    section "DEPLOY SELECTED ADMIN UI"
    wait_for_docker_readiness
    install_admin_ui_files
    ensure_admin_ui_secret_env
    validate_compose_files
    deploy_admin_ui
    section "VERIFICATION / MARKER"
    create_verification_report
    write_completion_marker
    show_finished_summary
}

main "$@"
