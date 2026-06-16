#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Project Circl8 - Script 6.4 Circl8 Template Preflight
# =========================================================
# Phase 3 v1.1.3 keeps the Circl8 template/preflight foundation and fixes
# the main run-mode flow before the first confirmed core deployment lane.
# It prepares .env keys, appdata folders, downloaded/rendered templates,
# compose file placement, static safety checks and compose config validation
# before any container start. The deploy lane starts only the Circl8 core
# project after explicit confirmation or the explicit --deploy run mode.

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

SCRIPT_SOURCE="6.4-circl8Bootstrap.sh"
SCRIPT_VERSION="v1.1.5"
SCRIPT_UPDATED="2026-06-16"
SCRIPT_BUILD="circl8-core-temporal-address-fix"

T="15"
UI_LABEL_WIDTH="34"

LOG_FILE="/var/log/circl8-app-bootstrap.log"
VERIFY_LOG="/var/log/circl8-app-verify.log"
COMPLETED_MARKER="/root/.circl8-app-template-preflight-completed"
DEPLOYED_MARKER="/root/.circl8-app-completed"
FAILURE_LOG=""
DEPLOY_OUTPUT_LOG=""
SCRIPT6_MARKER="/root/.docker-env-setup-completed"
SCRIPT63_MARKER="/root/.circl8-authentik-completed"

SUDO_CMD=""
DOCKER_NEEDS_SUDO="no"
RUNTIME_LOG_FILE=""
SCRIPT_DIR=""
TEMP_FILES=()
TEMP_DIRS=()
SCRIPT64_RUN_MODE="prompt"

RAW_BASE_DEFAULT="https://raw.githubusercontent.com/Orik999/circl8/refs/heads/main"
CIRCL8_COMPOSE_TEMPLATE_URL="${CIRCL8_COMPOSE_TEMPLATE_URL:-${RAW_BASE_DEFAULT}/docker/06-circl8-compose.yml}"
CIRCL8_POSTGRES_INIT_TEMPLATE_URL="${CIRCL8_POSTGRES_INIT_TEMPLATE_URL:-${RAW_BASE_DEFAULT}/docker/circl8/postgres-init/10-create-circl8-databases.sh.template}"
CIRCL8_TEMPORAL_DYNAMIC_CONFIG_TEMPLATE_URL="${CIRCL8_TEMPORAL_DYNAMIC_CONFIG_TEMPLATE_URL:-${RAW_BASE_DEFAULT}/docker/circl8/temporal-dynamicconfig/development-sql.yml.template}"

DOCKER_USER=""
DOCKER_DIR=""
COMPOSE_DIR=""
ENV_FILE=""
DOMAIN_VALUE=""
ADMIN_UI=""

CIRCL8_HOST="app.circl8.co.uk"
CIRCL8_URL="https://app.circl8.co.uk"
CIRCL8_APPDATA_DIR=""
CIRCL8_COMPOSE_FILE=""
CIRCL8_DOCKGE_COMPOSE_FILE=""
CIRCL8_POSTGRES_DIR=""
CIRCL8_POSTGRES_INIT_DIR=""
CIRCL8_REDIS_DIR=""
CIRCL8_UPLOADS_DIR=""
CIRCL8_TEMPORAL_DYNAMIC_CONFIG_DIR=""
CIRCL8_POSTGRES_INIT_FILE=""
CIRCL8_TEMPORAL_DYNAMIC_CONFIG_FILE=""

SCRIPT63_STATUS="unknown"
SCRIPT63_VERIFY_STATUS="unknown"
SCRIPT63_READY_FOR_SCRIPT64="unknown"
SCRIPT63_FORWARD_AUTH="unknown"
SCRIPT63_TRAEFIK_FORWARD_AUTH="unknown"
SCRIPT64_SCRIPT63_GATE="unknown"

SCRIPT64_STATUS="template-preflight-pending"
SCRIPT64_VERIFY_STATUS="PENDING"
SCRIPT64_DEPLOYMENT="not-run"
SCRIPT64_MARKER_WRITTEN="no"
SCRIPT64_ENV_BACKUP="not-needed"
SCRIPT64_ENV_KEYS_ADDED="0"
SCRIPT64_CIRCL8_COMPOSE_TEMPLATE="not-run"
SCRIPT64_CIRCL8_POSTGRES_INIT_TEMPLATE="not-run"
SCRIPT64_CIRCL8_TEMPORAL_CONFIG_TEMPLATE="not-run"
SCRIPT64_CIRCL8_COMPOSE_CONFIG="not-run"
SCRIPT64_CIRCL8_STATIC_SAFETY="not-run"
SCRIPT64_NETWORK_T2_PROXY="unknown"
SCRIPT64_NETWORK_DATABASE="unknown"
SCRIPT64_TEMPLATE_PREFLIGHT_MARKER_WRITTEN="no"
SCRIPT64_DEPLOYMENT_MARKER_WRITTEN="no"
SCRIPT64_CIRCL8_POSTGRES="not-run"
SCRIPT64_CIRCL8_REDIS="not-run"
SCRIPT64_CIRCL8_TEMPORAL="not-run"
SCRIPT64_CIRCL8_APP="not-run"
SCRIPT64_CIRCL8_INTERNAL_HTTP="not-run"
SCRIPT64_CIRCL8_ROUTE="not-run"
SCRIPT64_READY_FOR_AUTHENTIK_LANE="no"
SCRIPT64_READY_FOR_DEPLOYMENT_LANE="no"
SCRIPT64_READY_FOR_SCRIPT65="no"

# =========================================================
#  UI HELPERS
# =========================================================
function header_info() {
cat <<'BANNER'

   ██████╗    ██╗  ██╗       ██████╗██╗██████╗  ██████╗██╗     █████╗
  ██╔════╝    ██║  ██║      ██╔════╝██║██╔══██╗██╔════╝██║    ██╔══██╗
  ███████╗    ███████║      ██║     ██║██████╔╝██║     ██║    ╚█████╔╝
  ██╔═══██╗   ╚════██║      ██║     ██║██╔══██╗██║     ██║    ██╔══██╗
  ╚██████╔╝██╗     ██║      ╚██████╗██║██║  ██║╚██████╗███████╗╚█████╔╝
   ╚═════╝ ╚═╝     ╚═╝       ╚═════╝╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝ ╚════╝

                              6.4 CIRCL8
BANNER
}

function show_script_version() {
    echo -e "${GN}SCRIPT VERSION: ${SCRIPT_VERSION} | UPDATED: ${SCRIPT_UPDATED} | BUILD: ${SCRIPT_BUILD}${CL}"
    echo -e "${BL}SOURCE: ${SCRIPT_SOURCE}${CL}"
}

function section() { echo ""; echo -e "${BORDER}"; echo -e "${BL}$1${CL}"; echo -e "${BORDER}"; }
function section_flash_success() { echo ""; echo -e "${BORDER}"; echo -e "${GN}${CLF}$1${CL}"; echo -e "${BORDER}"; }
function mini_header() { echo ""; echo -e "${YW}$1:${CL}"; }
function msg_info() { echo -ne " ${HOLD} ${YW}$1...${CL}"; }
function msg_ok() { echo -e "${BFR} ${CM} ${GN}$1${CL}"; }
function msg_warn() { echo -e "${BFR} ${WARN} ${YW}$1${CL}"; }
function msg_error() { echo -e "${BFR} ${CROSS} ${RD}$1${CL}"; exit 1; }

function status_color_for_value() {
    local value="${1:-unknown}"
    case "$value" in
        PASS|pass|completed|present|ready|yes|valid|downloaded|rendered|synced|created|preserved|healthy|running|protected|not-needed|not\ needed|template-preflight-completed|not-run|not\ run) printf '%s' "$GN" ;;
        PENDING|pending|unknown|skipped|needs-review|will-create|will\ create|not-selected|not\ selected) printf '%s' "$YW" ;;
        FAIL|FAILED|failed|missing|no|invalid|blocked|unsafe) printf '%s' "$RD" ;;
        *) printf '%s' "$GN" ;;
    esac
}

function ui_display_value() {
    local value="${1:-unknown}"
    case "$value" in
        not-run) printf 'not run' ;;
        not-needed) printf 'not needed' ;;
        template-preflight-completed) printf 'template preflight completed' ;;
        needs-review) printf 'needs review' ;;
        *) printf '%s' "$value" ;;
    esac
}

function aligned_status_line() {
    local label="$1" value="${2:-unknown}" color="${3:-}" width="${4:-$UI_LABEL_WIDTH}" display_value=""
    [ -n "$value" ] || value="unknown"
    [ -n "$color" ] || color="$(status_color_for_value "$value")"
    display_value="$(ui_display_value "$value")"
    printf '  %b%-*s%b %b%s%b\n' "$BL" "$width" "${label}:" "$CL" "$color" "$display_value" "$CL"
}

function final_line() {
    aligned_status_line "$1" "${2:-unknown}" "${3:-}" "$UI_LABEL_WIDTH"
}

# =========================================================
#  ROOT / LOGGING / COMMAND HELPERS
# =========================================================
function detect_root_or_sudo() { if [ "${EUID}" -eq 0 ]; then SUDO_CMD=""; else SUDO_CMD="sudo"; fi; }

function validate_sudo_access() {
    if [ -n "$SUDO_CMD" ]; then
        msg_info "Validating sudo access"
        if "$SUDO_CMD" -n true >/dev/null 2>&1 || "$SUDO_CMD" -v >/dev/null 2>&1; then
            msg_ok "SUDO ACCESS CONFIRMED"
        else
            msg_error "Sudo authentication failed. Script cancelled."
        fi
    fi
}

function init_logging() {
    if [ -n "$SUDO_CMD" ]; then
        RUNTIME_LOG_FILE="$(mktemp /tmp/circl8-app-bootstrap-log.XXXXXX)"
        TEMP_FILES+=("$RUNTIME_LOG_FILE")
        exec > >(tee -a "$RUNTIME_LOG_FILE") 2>&1
    else
        RUNTIME_LOG_FILE="$LOG_FILE"
        exec > >(tee -a "$LOG_FILE") 2>&1
    fi
}

function copy_runtime_log() {
    if [ -n "${SUDO_CMD:-}" ] && [ -n "${RUNTIME_LOG_FILE:-}" ] && [ -s "$RUNTIME_LOG_FILE" ]; then
        "$SUDO_CMD" cp "$RUNTIME_LOG_FILE" "$LOG_FILE" 2>/dev/null || true
        "$SUDO_CMD" chmod 0644 "$LOG_FILE" 2>/dev/null || true
    fi
}

function cleanup() {
    local exit_code="$?" file=""
    copy_runtime_log
    for file in "${TEMP_FILES[@]:-}"; do [ -n "$file" ] && [ -f "$file" ] && rm -f "$file" 2>/dev/null || true; done
    for file in "${TEMP_DIRS[@]:-}"; do [ -n "$file" ] && [ -d "$file" ] && rm -rf "$file" 2>/dev/null || true; done
    exit "$exit_code"
}

function on_error() { echo -e "${RD}ERROR:${CL} Script failed at line $1. Check ${LOG_FILE}"; }

function root_path_exists() { if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" test -e "$1"; else test -e "$1"; fi; }
function root_dir_exists() { if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" test -d "$1"; else test -d "$1"; fi; }
function root_file_not_empty() { if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" test -s "$1"; else test -s "$1"; fi; }
function root_read_file() { if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" cat "$1"; else cat "$1"; fi; }
function root_stat_mode() { if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" stat -c '%a' "$1" 2>/dev/null || true; else stat -c '%a' "$1" 2>/dev/null || true; fi; }
function root_stat_owner_group() { if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" stat -c '%U:%G' "$1" 2>/dev/null || true; else stat -c '%U:%G' "$1" 2>/dev/null || true; fi; }
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

function root_copy_file() {
    local src="$1" dest="$2"
    if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" cp -f "$src" "$dest"; else cp -f "$src" "$dest"; fi
}

function root_install_dir() {
    local path="$1" mode="${2:-755}"
    if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" install -d -m "$mode" "$path"; else install -d -m "$mode" "$path"; fi
}

function root_set_owner_group() {
    local path="$1" owner_group="$2"
    if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" chown "$owner_group" "$path"; else chown "$owner_group" "$path"; fi
}

function root_set_mode() {
    local path="$1" mode="$2"
    if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" chmod "$mode" "$path"; else chmod "$mode" "$path"; fi
}

function root_dir_has_entries() {
    local path="$1"
    root_dir_exists "$path" || return 1
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" find "$path" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .
    else
        find "$path" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .
    fi
}

function validate_dependencies() {
    local cmds=(awk cat chmod command cp cut date find grep id mkdir mktemp openssl rm sed sort stat tee test tr)
    local cmd=""
    for cmd in "${cmds[@]}"; do command -v "$cmd" >/dev/null 2>&1 || msg_error "Required command not found: ${cmd}"; done
    if [ -n "$SUDO_CMD" ]; then command -v sudo >/dev/null 2>&1 || msg_error "sudo is required when not running as root."; fi
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then msg_error "curl or wget is required to download Circl8 templates."; fi
    command -v docker >/dev/null 2>&1 || msg_error "Docker command not found. Complete Script 5/6 first."
    command -v python3 >/dev/null 2>&1 || true
}

function docker_cmd() {
    if [ "$DOCKER_NEEDS_SUDO" == "yes" ]; then "$SUDO_CMD" docker "$@"; else docker "$@"; fi
}

function detect_docker_access() {
    if docker info >/dev/null 2>&1; then DOCKER_NEEDS_SUDO="no"; return 0; fi
    if [ -n "$SUDO_CMD" ] && "$SUDO_CMD" docker info >/dev/null 2>&1; then DOCKER_NEEDS_SUDO="yes"; return 0; fi
    return 1
}

function download_file() {
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then curl -fsSL "$url" -o "$dest"; else wget -qO "$dest" "$url"; fi
}

function usage() {
    printf '%s
' "Usage: sudo ./6.4-circl8Bootstrap.sh [--preflight-only|--deploy]"
}

function parse_args() {
    local arg=""
    SCRIPT64_RUN_MODE="prompt"

    if [ "$#" -gt 1 ]; then
        usage >&2
        exit 2
    fi

    for arg in "$@"; do
        case "$arg" in
            --preflight-only)
                SCRIPT64_RUN_MODE="preflight-only"
                ;;
            --deploy)
                SCRIPT64_RUN_MODE="deploy"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                usage >&2
                exit 2
                ;;
        esac
    done
}

function read_yes_no() {
    local prompt="$1" default="${2:-n}" answer="" label="y/N"
    [[ "$default" =~ ^[Yy]$ ]] && label="Y/n"

    if [ ! -r /dev/tty ]; then
        return 2
    fi

    read -r -p "${prompt} [${label}]: " answer < /dev/tty || answer=""
    [ -n "$answer" ] || answer="$default"
    [[ "$answer" =~ ^[Yy]$ ]]
}

function init_deploy_output_log() {
    if [ -z "${DEPLOY_OUTPUT_LOG:-}" ]; then
        DEPLOY_OUTPUT_LOG="$(mktemp /tmp/circl8-app-deploy.XXXXXX)"
        TEMP_FILES+=("$DEPLOY_OUTPUT_LOG")
    fi
    : > "$DEPLOY_OUTPUT_LOG"
}

function sanitize_diagnostic_stream() {
    sed -E '/(PASSWORD|PASSWD|SECRET|TOKEN|DATABASE_URL|REDIS_URL|JWT|NEXTAUTH|POSTGRES_PWD|COOKIE|AUTHORIZATION|BEARER)/Id'
}

function container_state() {
    local name="$1"
    docker_cmd inspect -f '{{.State.Status}}' "$name" 2>/dev/null || printf 'missing'
}

function container_health() {
    local name="$1"
    docker_cmd inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || printf 'missing'
}

function wait_for_container_status() {
    local name="$1" mode="$2" timeout_seconds="${3:-240}" elapsed="0" state="" health=""
    while [ "$elapsed" -le "$timeout_seconds" ]; do
        state="$(container_state "$name")"
        health="$(container_health "$name")"
        case "$mode" in
            healthy)
                [ "$health" = "healthy" ] && return 0
                ;;
            healthy-or-running)
                { [ "$health" = "healthy" ] || { [ "$health" = "none" ] && [ "$state" = "running" ]; } || [ "$state" = "running" ]; } && return 0
                ;;
            running)
                [ "$state" = "running" ] && return 0
                ;;
        esac
        sleep 5
        elapsed=$((elapsed + 5))
    done
    return 1
}

function wait_for_temporal_api() {
    local timeout_seconds="${1:-240}" elapsed="0" address=""
    local temporal_addresses=(
        "circl8-temporal:7233"
        "localhost:7233"
        "127.0.0.1:7233"
    )

    while [ "$elapsed" -le "$timeout_seconds" ]; do
        for address in "${temporal_addresses[@]}"; do
            if docker_cmd exec circl8-temporal temporal operator cluster health --address "$address" >/dev/null 2>&1; then
                return 0
            fi
        done
        sleep 5
        elapsed=$((elapsed + 5))
    done
    return 1
}

function wait_for_circl8_internal_http() {
    local timeout_seconds="${1:-240}" elapsed="0"
    while [ "$elapsed" -le "$timeout_seconds" ]; do
        if docker_cmd exec circl8 node -e 'const http=require("http"); const r=http.get("http://127.0.0.1:5000/", res => process.exit(res.statusCode < 500 ? 0 : 1)); r.on("error", () => process.exit(1)); r.setTimeout(5000, () => { r.destroy(); process.exit(1); });' >/dev/null 2>&1; then
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    return 1
}

function traefik_container_name() {
    local name=""
    for name in traefik circl8-traefik; do
        if docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -Fxq "$name"; then
            printf '%s' "$name"
            return 0
        fi
    done
    docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -E '(^|[-_])traefik($|[-_])' | head -n1 || true
}

function check_circl8_traefik_labels() {
    local labels=""
    labels="$(docker_cmd inspect circl8 --format '{{json .Config.Labels}}' 2>/dev/null || true)"
    printf '%s\n' "$labels" | grep -q 'app.circl8.co.uk' || return 1
    printf '%s\n' "$labels" | grep -q 'chain-authentik@file' || return 1
    printf '%s\n' "$labels" | grep -q 'loadbalancer.server.port' || return 1
    return 0
}

function check_traefik_infra_errors() {
    local traefik_name="" recent=""
    traefik_name="$(traefik_container_name)"
    [ -n "$traefik_name" ] || return 1
    recent="$(docker_cmd logs --since 10m "$traefik_name" 2>&1 | sanitize_diagnostic_stream | grep -Ei 'circl8|app\.circl8|chain-authentik|middleware|router|service' || true)"
    if printf '%s\n' "$recent" | grep -Eiq 'error|unable|not found|does not exist|cannot|failed'; then
        return 1
    fi
    return 0
}

function verify_public_route_behavior() {
    local headers="" status_line="" location_line=""
    check_circl8_traefik_labels || return 2
    if command -v curl >/dev/null 2>&1; then
        headers="$(curl -kIsS --max-time 12 "https://${CIRCL8_HOST}" 2>/dev/null || true)"
        status_line="$(printf '%s\n' "$headers" | awk 'tolower($0) ~ /^http\// {line=$0} END {print line}')"
        location_line="$(printf '%s\n' "$headers" | awk 'tolower($0) ~ /^location:/ {print; exit}')"
        if printf '%s\n%s\n' "$status_line" "$location_line" | grep -Eiq 'HTTP/.*30[1278].*(|$)|authentik|outpost\.goauthentik|authorize|login'; then
            if printf '%s\n' "$location_line" | grep -Eiq 'authentik|outpost\.goauthentik|authorize|login'; then
                return 0
            fi
        fi
        if printf '%s\n' "$status_line" | grep -Eq 'HTTP/.* (401|403)'; then
            return 0
        fi
        if [ -n "$status_line" ]; then
            return 3
        fi
    fi
    return 1
}

function write_deployment_failure_log() {
    local reason="${1:-Circl8 deployment failed}" service="" traefik_name="" ts=""
    ts="$(date +%Y%m%d-%H%M%S)"
    FAILURE_LOG="/var/log/circl8-app-deploy-failed-${ts}.log"
    {
        printf '%s\n' "$reason"
        printf '%s\n' ""
        printf '%s\n' "Compose output:"
        [ -n "${DEPLOY_OUTPUT_LOG:-}" ] && [ -s "$DEPLOY_OUTPUT_LOG" ] && sanitize_diagnostic_stream < "$DEPLOY_OUTPUT_LOG" || true
        printf '%s\n' ""
        printf '%s\n' "Circl8 containers:"
        docker_cmd ps -a --filter "name=circl8" --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' 2>/dev/null | sanitize_diagnostic_stream || true
        for service in circl8-postgres circl8-redis circl8-temporal circl8; do
            printf '%s\n' ""
            printf '%s\n' "Logs: ${service}"
            docker_cmd logs --tail=160 "$service" 2>&1 | sanitize_diagnostic_stream || true
        done
        traefik_name="$(traefik_container_name)"
        if [ -n "$traefik_name" ]; then
            printf '%s\n' ""
            printf '%s\n' "Traefik recent Circl8-related lines:"
            docker_cmd logs --since 10m "$traefik_name" 2>&1 | sanitize_diagnostic_stream | grep -Ei 'circl8|app\.circl8|chain-authentik|middleware|router|service|error|failed|unable' || true
        fi
    } | write_root_file "$FAILURE_LOG"
}

function fail_deployment() {
    local message="$1"
    echo -ne "${BFR}"
    SCRIPT64_STATUS="deploy-failed"
    SCRIPT64_VERIFY_STATUS="FAILED"
    SCRIPT64_DEPLOYMENT="failed"
    SCRIPT64_DEPLOYMENT_MARKER_WRITTEN="no"
    SCRIPT64_READY_FOR_AUTHENTIK_LANE="no"
    SCRIPT64_READY_FOR_SCRIPT65="no"
    write_deployment_failure_log "$message" || true
    fail_with_report "$message"
}

# =========================================================
#  VALUE / MARKER / ENV HELPERS
# =========================================================
function trim_shell_value() {
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"
}

function marker_file_key_value() {
    local marker_path="$1" key="$2"
    root_path_exists "$marker_path" || return 0
    root_read_file "$marker_path" 2>/dev/null | awk -F= -v key="$key" '$1 == key { $1=""; sub(/^=/, ""); print; exit }' | trim_shell_value || true
}

function env_value() {
    local key="$1"
    root_path_exists "$ENV_FILE" || return 0
    root_read_file "$ENV_FILE" 2>/dev/null | awk -F= -v k="$key" '
        $1 == k {
            val=$0
            sub("^[^=]*=", "", val)
            gsub(/^"|"$/, "", val)
            gsub(/^'"'"'|'"'"'$/, "", val)
            print val
            exit
        }
    ' || true
}

function env_has_nonempty_value() {
    local key="$1" value=""
    value="$(env_value "$key")"
    [ -n "$value" ]
}

function env_line_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

function generate_secret_hex() {
    local bytes="${1:-32}"
    openssl rand -hex "$bytes"
}

function load_docker_project_context() {
    local marker_docker_dir="" marker_compose_dir="" marker_user="" env_admin_ui="" env_domain="" env_docker_user=""
    marker_docker_dir="$(marker_file_key_value "$SCRIPT6_MARKER" SCRIPT6_DOCKER_DIR)"
    marker_compose_dir="$(marker_file_key_value "$SCRIPT6_MARKER" SCRIPT6_COMPOSE_DIR)"
    marker_user="$(marker_file_key_value "$SCRIPT6_MARKER" SCRIPT6_DOCKER_USER)"

    DOCKER_DIR="${marker_docker_dir:-${DOCKER_DIR:-/home/orik/docker}}"
    COMPOSE_DIR="${marker_compose_dir:-${DOCKER_DIR}/compose}"
    ENV_FILE="${DOCKER_DIR}/.env"

    env_docker_user="$(env_value DOCKER_USER)"
    DOCKER_USER="${marker_user:-${env_docker_user:-$(basename "$(dirname "$DOCKER_DIR")")}}"
    env_domain="$(env_value DOMAIN)"
    DOMAIN_VALUE="${env_domain:-circl8.co.uk}"
    env_admin_ui="$(env_value ADMIN_UI)"
    ADMIN_UI="${env_admin_ui:-dockge}"

    CIRCL8_APPDATA_DIR="${DOCKER_DIR}/appdata/circl8"
    CIRCL8_COMPOSE_FILE="${COMPOSE_DIR}/06-circl8-compose.yml"
    CIRCL8_DOCKGE_COMPOSE_FILE="${COMPOSE_DIR}/circl8/compose.yaml"
    CIRCL8_POSTGRES_DIR="${CIRCL8_APPDATA_DIR}/postgres"
    CIRCL8_POSTGRES_INIT_DIR="${CIRCL8_APPDATA_DIR}/postgres-init"
    CIRCL8_REDIS_DIR="${CIRCL8_APPDATA_DIR}/redis"
    CIRCL8_UPLOADS_DIR="${CIRCL8_APPDATA_DIR}/uploads"
    CIRCL8_TEMPORAL_DYNAMIC_CONFIG_DIR="${CIRCL8_APPDATA_DIR}/temporal-dynamicconfig"
    CIRCL8_POSTGRES_INIT_FILE="${CIRCL8_POSTGRES_INIT_DIR}/10-create-circl8-databases.sh"
    CIRCL8_TEMPORAL_DYNAMIC_CONFIG_FILE="${CIRCL8_TEMPORAL_DYNAMIC_CONFIG_DIR}/development-sql.yml"
}

# =========================================================
#  REPORT / MARKER
# =========================================================
function write_verify_report() {
    {
        printf '%s
' "SCRIPT64_STATUS=${SCRIPT64_STATUS}"
        printf '%s
' "SCRIPT64_VERSION=${SCRIPT_VERSION}"
        printf '%s
' "SCRIPT64_BUILD=${SCRIPT_BUILD}"
        printf '%s
' "SCRIPT64_VERIFY_STATUS=${SCRIPT64_VERIFY_STATUS}"
        printf '%s
' "SCRIPT64_DEPLOYMENT=${SCRIPT64_DEPLOYMENT}"
        printf '%s
' "SCRIPT64_MARKER_WRITTEN=${SCRIPT64_MARKER_WRITTEN}"
        printf '%s
' "SCRIPT64_TEMPLATE_PREFLIGHT_MARKER_WRITTEN=${SCRIPT64_TEMPLATE_PREFLIGHT_MARKER_WRITTEN}"
        printf '%s
' "SCRIPT64_DEPLOYMENT_MARKER_WRITTEN=${SCRIPT64_DEPLOYMENT_MARKER_WRITTEN}"
        printf '%s
' "SCRIPT64_SCRIPT63_GATE=${SCRIPT64_SCRIPT63_GATE}"
        printf '%s
' "SCRIPT64_NETWORK_T2_PROXY=${SCRIPT64_NETWORK_T2_PROXY}"
        printf '%s
' "SCRIPT64_NETWORK_DATABASE=${SCRIPT64_NETWORK_DATABASE}"
        printf '%s
' "SCRIPT64_ENV_BACKUP=${SCRIPT64_ENV_BACKUP}"
        printf '%s
' "SCRIPT64_ENV_KEYS_ADDED=${SCRIPT64_ENV_KEYS_ADDED}"
        printf '%s
' "SCRIPT64_CIRCL8_COMPOSE_TEMPLATE=${SCRIPT64_CIRCL8_COMPOSE_TEMPLATE}"
        printf '%s
' "SCRIPT64_CIRCL8_POSTGRES_INIT_TEMPLATE=${SCRIPT64_CIRCL8_POSTGRES_INIT_TEMPLATE}"
        printf '%s
' "SCRIPT64_CIRCL8_TEMPORAL_CONFIG_TEMPLATE=${SCRIPT64_CIRCL8_TEMPORAL_CONFIG_TEMPLATE}"
        printf '%s
' "SCRIPT64_CIRCL8_COMPOSE_CONFIG=${SCRIPT64_CIRCL8_COMPOSE_CONFIG}"
        printf '%s
' "SCRIPT64_CIRCL8_STATIC_SAFETY=${SCRIPT64_CIRCL8_STATIC_SAFETY}"
        printf '%s
' "SCRIPT64_CIRCL8_POSTGRES=${SCRIPT64_CIRCL8_POSTGRES}"
        printf '%s
' "SCRIPT64_CIRCL8_REDIS=${SCRIPT64_CIRCL8_REDIS}"
        printf '%s
' "SCRIPT64_CIRCL8_TEMPORAL=${SCRIPT64_CIRCL8_TEMPORAL}"
        printf '%s
' "SCRIPT64_CIRCL8_APP=${SCRIPT64_CIRCL8_APP}"
        printf '%s
' "SCRIPT64_CIRCL8_INTERNAL_HTTP=${SCRIPT64_CIRCL8_INTERNAL_HTTP}"
        printf '%s
' "SCRIPT64_CIRCL8_ROUTE=${SCRIPT64_CIRCL8_ROUTE}"
        printf '%s
' "SCRIPT64_READY_FOR_DEPLOYMENT_LANE=${SCRIPT64_READY_FOR_DEPLOYMENT_LANE}"
        printf '%s
' "SCRIPT64_READY_FOR_AUTHENTIK_LANE=${SCRIPT64_READY_FOR_AUTHENTIK_LANE}"
        printf '%s
' "SCRIPT64_READY_FOR_SCRIPT65=${SCRIPT64_READY_FOR_SCRIPT65}"
        printf '%s
' "SCRIPT64_DOCKER_DIR=${DOCKER_DIR}"
        printf '%s
' "SCRIPT64_COMPOSE_FILE=${CIRCL8_COMPOSE_FILE}"
        printf '%s
' "SCRIPT64_DOCKGE_COMPOSE_FILE=${CIRCL8_DOCKGE_COMPOSE_FILE}"
        printf '%s
' "SCRIPT64_POSTGRES_INIT_FILE=${CIRCL8_POSTGRES_INIT_FILE}"
        printf '%s
' "SCRIPT64_TEMPORAL_DYNAMIC_CONFIG_FILE=${CIRCL8_TEMPORAL_DYNAMIC_CONFIG_FILE}"
        printf '%s
' "SCRIPT64_TEMPLATE_PREFLIGHT_MARKER_PATH=${COMPLETED_MARKER}"
        printf '%s
' "SCRIPT64_DEPLOYED_MARKER_PATH=${DEPLOYED_MARKER}"
        [ -n "${FAILURE_LOG:-}" ] && printf '%s
' "SCRIPT64_FAILURE_LOG=${FAILURE_LOG}" || true
    } | write_root_file "$VERIFY_LOG"
}

function fail_with_report() {
    local message="$1"
    if [ "${SCRIPT64_STATUS:-}" != "deploy-failed" ]; then
        SCRIPT64_STATUS="template-preflight-failed"
    fi
    SCRIPT64_VERIFY_STATUS="FAILED"
    SCRIPT64_READY_FOR_DEPLOYMENT_LANE="no"
    SCRIPT64_READY_FOR_AUTHENTIK_LANE="no"
    SCRIPT64_READY_FOR_SCRIPT65="no"
    write_verify_report || true
    echo -e "${CROSS} ${RD}${message}${CL}"
    echo -e "  ${BL}Verify log:${CL} ${VERIFY_LOG}"
    [ -n "${FAILURE_LOG:-}" ] && echo -e "  ${BL}Failure log:${CL} ${FAILURE_LOG}"
    exit 1
}

function write_completion_marker() {
    local tmp_file=""
    tmp_file="$(mktemp /tmp/circl8-app-template-marker.XXXXXX)"
    {
        printf '%s
' "SCRIPT64_STATUS=template-preflight-completed"
        printf '%s
' "SCRIPT64_VERSION=${SCRIPT_VERSION}"
        printf '%s
' "SCRIPT64_BUILD=${SCRIPT_BUILD}"
        printf '%s
' "SCRIPT64_VERIFY_STATUS=PASS"
        printf '%s
' "SCRIPT64_DEPLOYMENT=not-run"
        printf '%s
' "SCRIPT64_MARKER_WRITTEN=yes"
        printf '%s
' "SCRIPT64_TEMPLATE_PREFLIGHT_MARKER_WRITTEN=yes"
        printf '%s
' "SCRIPT64_DEPLOYMENT_MARKER_WRITTEN=no"
        printf '%s
' "SCRIPT64_SCRIPT63_GATE=pass"
        printf '%s
' "SCRIPT64_NETWORK_T2_PROXY=${SCRIPT64_NETWORK_T2_PROXY}"
        printf '%s
' "SCRIPT64_NETWORK_DATABASE=${SCRIPT64_NETWORK_DATABASE}"
        printf '%s
' "SCRIPT64_ENV_BACKUP=${SCRIPT64_ENV_BACKUP}"
        printf '%s
' "SCRIPT64_ENV_KEYS_ADDED=${SCRIPT64_ENV_KEYS_ADDED}"
        printf '%s
' "SCRIPT64_CIRCL8_COMPOSE_TEMPLATE=downloaded"
        printf '%s
' "SCRIPT64_CIRCL8_POSTGRES_INIT_TEMPLATE=downloaded"
        printf '%s
' "SCRIPT64_CIRCL8_TEMPORAL_CONFIG_TEMPLATE=downloaded"
        printf '%s
' "SCRIPT64_CIRCL8_COMPOSE_CONFIG=valid"
        printf '%s
' "SCRIPT64_CIRCL8_STATIC_SAFETY=pass"
        printf '%s
' "SCRIPT64_READY_FOR_DEPLOYMENT_LANE=yes"
        printf '%s
' "SCRIPT64_READY_FOR_AUTHENTIK_LANE=no"
        printf '%s
' "SCRIPT64_READY_FOR_SCRIPT65=no"
    } > "$tmp_file"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" chmod 600 "$tmp_file"
        "$SUDO_CMD" mv -f "$tmp_file" "$COMPLETED_MARKER"
    else
        chmod 600 "$tmp_file"
        mv -f "$tmp_file" "$COMPLETED_MARKER"
    fi
    SCRIPT64_TEMPLATE_PREFLIGHT_MARKER_WRITTEN="yes"
    SCRIPT64_MARKER_WRITTEN="yes"
}

function write_deployment_marker() {
    local tmp_file=""
    tmp_file="$(mktemp /tmp/circl8-app-deployed-marker.XXXXXX)"
    {
        printf '%s
' "SCRIPT64_STATUS=completed"
        printf '%s
' "SCRIPT64_VERSION=${SCRIPT_VERSION}"
        printf '%s
' "SCRIPT64_BUILD=${SCRIPT_BUILD}"
        printf '%s
' "SCRIPT64_VERIFY_STATUS=PASS"
        printf '%s
' "SCRIPT64_DEPLOYMENT=completed"
        printf '%s
' "SCRIPT64_MARKER_WRITTEN=yes"
        printf '%s
' "SCRIPT64_TEMPLATE_PREFLIGHT_MARKER_WRITTEN=yes"
        printf '%s
' "SCRIPT64_SCRIPT63_GATE=pass"
        printf '%s
' "SCRIPT64_NETWORK_T2_PROXY=${SCRIPT64_NETWORK_T2_PROXY}"
        printf '%s
' "SCRIPT64_NETWORK_DATABASE=${SCRIPT64_NETWORK_DATABASE}"
        printf '%s
' "SCRIPT64_CIRCL8_COMPOSE_CONFIG=valid"
        printf '%s
' "SCRIPT64_CIRCL8_STATIC_SAFETY=pass"
        printf '%s
' "SCRIPT64_CIRCL8_POSTGRES=${SCRIPT64_CIRCL8_POSTGRES}"
        printf '%s
' "SCRIPT64_CIRCL8_REDIS=${SCRIPT64_CIRCL8_REDIS}"
        printf '%s
' "SCRIPT64_CIRCL8_TEMPORAL=${SCRIPT64_CIRCL8_TEMPORAL}"
        printf '%s
' "SCRIPT64_CIRCL8_APP=${SCRIPT64_CIRCL8_APP}"
        printf '%s
' "SCRIPT64_CIRCL8_INTERNAL_HTTP=${SCRIPT64_CIRCL8_INTERNAL_HTTP}"
        printf '%s
' "SCRIPT64_CIRCL8_ROUTE=${SCRIPT64_CIRCL8_ROUTE}"
        printf '%s
' "SCRIPT64_READY_FOR_AUTHENTIK_LANE=yes"
        printf '%s
' "SCRIPT64_READY_FOR_SCRIPT65=no"
    } > "$tmp_file"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" chmod 600 "$tmp_file"
        "$SUDO_CMD" mv -f "$tmp_file" "$DEPLOYED_MARKER"
    else
        chmod 600 "$tmp_file"
        mv -f "$tmp_file" "$DEPLOYED_MARKER"
    fi
    SCRIPT64_DEPLOYMENT_MARKER_WRITTEN="yes"
    SCRIPT64_MARKER_WRITTEN="yes"
}

# =========================================================
#  PREFLIGHTS
# =========================================================
function validate_script63_gate() {
    section "SCRIPT 6.3 GATE"

    if ! root_path_exists "$SCRIPT63_MARKER"; then
        aligned_status_line "Marker" "missing" "$RD"
        fail_with_report "Script 6.3 marker is missing."
    fi

    SCRIPT63_STATUS="$(marker_file_key_value "$SCRIPT63_MARKER" SCRIPT63_STATUS)"
    SCRIPT63_VERIFY_STATUS="$(marker_file_key_value "$SCRIPT63_MARKER" SCRIPT63_VERIFY_STATUS)"
    SCRIPT63_READY_FOR_SCRIPT64="$(marker_file_key_value "$SCRIPT63_MARKER" SCRIPT63_READY_FOR_SCRIPT64)"
    SCRIPT63_FORWARD_AUTH="$(marker_file_key_value "$SCRIPT63_MARKER" SCRIPT63_FORWARD_AUTH)"
    SCRIPT63_TRAEFIK_FORWARD_AUTH="$(marker_file_key_value "$SCRIPT63_MARKER" SCRIPT63_TRAEFIK_FORWARD_AUTH)"

    aligned_status_line "Status" "${SCRIPT63_STATUS:-missing}" "$(status_color_for_value "${SCRIPT63_STATUS:-missing}")"
    aligned_status_line "Verification" "${SCRIPT63_VERIFY_STATUS:-missing}" "$(status_color_for_value "${SCRIPT63_VERIFY_STATUS:-missing}")"
    aligned_status_line "Ready for Script 6.4" "${SCRIPT63_READY_FOR_SCRIPT64:-missing}" "$(status_color_for_value "${SCRIPT63_READY_FOR_SCRIPT64:-missing}")"
    aligned_status_line "ForwardAuth" "${SCRIPT63_FORWARD_AUTH:-missing}" "$(status_color_for_value "${SCRIPT63_FORWARD_AUTH:-missing}")"
    aligned_status_line "Traefik ForwardAuth" "${SCRIPT63_TRAEFIK_FORWARD_AUTH:-missing}" "$(status_color_for_value "${SCRIPT63_TRAEFIK_FORWARD_AUTH:-missing}")"

    if [ "$SCRIPT63_STATUS" != "completed" ] \
        || [ "$SCRIPT63_VERIFY_STATUS" != "PASS" ] \
        || [ "$SCRIPT63_READY_FOR_SCRIPT64" != "yes" ] \
        || [ "$SCRIPT63_FORWARD_AUTH" != "ready" ] \
        || [ "$SCRIPT63_TRAEFIK_FORWARD_AUTH" != "ready" ]; then
        SCRIPT64_SCRIPT63_GATE="failed"
        fail_with_report "Script 6.3 gate failed."
    fi

    SCRIPT64_SCRIPT63_GATE="pass"
    msg_ok "SCRIPT 6.3 GATE PASSED"
}

function runtime_preflight() {
    section "RUNTIME PREFLIGHT"
    load_docker_project_context

    aligned_status_line "Docker user" "${DOCKER_USER:-missing}" "$(status_color_for_value "${DOCKER_USER:-missing}")"
    aligned_status_line "Docker dir" "${DOCKER_DIR:-missing}"
    aligned_status_line "Compose dir" "${COMPOSE_DIR:-missing}"
    aligned_status_line ".env file" "$(root_path_exists "$ENV_FILE" && printf present || printf missing)" "$(root_path_exists "$ENV_FILE" && printf '%s' "$GN" || printf '%s' "$RD")"
    aligned_status_line "Admin UI" "${ADMIN_UI:-unknown}"

    [ -n "$DOCKER_DIR" ] || fail_with_report "Docker directory could not be determined."
    root_path_exists "$DOCKER_DIR" || fail_with_report "Docker directory missing: ${DOCKER_DIR}"
    root_path_exists "$ENV_FILE" || fail_with_report "Docker .env missing: ${ENV_FILE}"
    root_install_dir "$COMPOSE_DIR" 755
    validate_dependencies
    detect_docker_access || fail_with_report "Docker API is not reachable."

    if ! docker_cmd compose version >/dev/null 2>&1; then
        fail_with_report "Docker Compose plugin is not available."
    fi

    if docker_cmd network inspect t2_proxy >/dev/null 2>&1; then
        SCRIPT64_NETWORK_T2_PROXY="ready"
        aligned_status_line "t2_proxy network" "$SCRIPT64_NETWORK_T2_PROXY" "$GN"
    else
        SCRIPT64_NETWORK_T2_PROXY="missing"
        aligned_status_line "t2_proxy network" "$SCRIPT64_NETWORK_T2_PROXY" "$RD"
        fail_with_report "Required external Docker network missing: t2_proxy"
    fi

    if docker_cmd network inspect database >/dev/null 2>&1; then
        SCRIPT64_NETWORK_DATABASE="preserved"
        aligned_status_line "database network" "$SCRIPT64_NETWORK_DATABASE" "$GN"
    else
        msg_info "Creating database network"
        if docker_cmd network create database >/dev/null 2>&1 && docker_cmd network inspect database >/dev/null 2>&1; then
            SCRIPT64_NETWORK_DATABASE="created"
            msg_ok "DATABASE NETWORK CREATED"
            aligned_status_line "database network" "$SCRIPT64_NETWORK_DATABASE" "$GN"
        else
            SCRIPT64_NETWORK_DATABASE="failed"
            aligned_status_line "database network" "$SCRIPT64_NETWORK_DATABASE" "$RD"
            fail_with_report "Required Docker network could not be created: database"
        fi
    fi

    msg_ok "RUNTIME PREFLIGHT PASSED"
}

# =========================================================
#  ENV PREP
# =========================================================
function append_env_line() {
    local key="$1" value="$2"
    printf '%s="%s"\n' "$key" "$(env_line_escape "$value")"
}

function env_default_for_key() {
    local key="$1"
    case "$key" in
        CIRCL8_HOST) printf '%s' "$CIRCL8_HOST" ;;
        CIRCL8_URL) printf '%s' "$CIRCL8_URL" ;;
        CIRCL8_IMAGE) printf 'ghcr.io/gitroomhq/postiz-app:latest' ;;
        CIRCL8_REDIS_IMAGE) printf 'redis:7-alpine' ;;
        CIRCL8_TEMPORAL_IMAGE) printf 'temporalio/auto-setup:1.28.1' ;;
        CIRCL8_POSTGRES_SUPERUSER_PASSWORD) generate_secret_hex 32 ;;
        CIRCL8_APP_POSTGRES_PASSWORD) generate_secret_hex 32 ;;
        CIRCL8_TEMPORAL_POSTGRES_PASSWORD) generate_secret_hex 32 ;;
        CIRCL8_JWT_SECRET) generate_secret_hex 32 ;;
        CIRCL8_NEXTAUTH_SECRET) generate_secret_hex 32 ;;
        CIRCL8_SECRET_KEY) generate_secret_hex 64 ;;
        CIRCL8_MEDIA_RETENTION_MODE) printf 'delete-after-publish' ;;
        CIRCL8_MEDIA_RETRY_RETENTION_HOURS) printf '72' ;;
        CIRCL8_MEDIA_DRAFT_RETENTION_DAYS) printf '30' ;;
        CIRCL8_API_LIMIT) printf '30' ;;
        *) return 1 ;;
    esac
}

function ensure_circl8_env_keys() {
    section "CIRCL8 ENV"
    local keys=(
        CIRCL8_HOST
        CIRCL8_URL
        CIRCL8_IMAGE
        CIRCL8_REDIS_IMAGE
        CIRCL8_TEMPORAL_IMAGE
        CIRCL8_POSTGRES_SUPERUSER_PASSWORD
        CIRCL8_APP_POSTGRES_PASSWORD
        CIRCL8_TEMPORAL_POSTGRES_PASSWORD
        CIRCL8_JWT_SECRET
        CIRCL8_NEXTAUTH_SECRET
        CIRCL8_SECRET_KEY
        CIRCL8_MEDIA_RETENTION_MODE
        CIRCL8_MEDIA_RETRY_RETENTION_HOURS
        CIRCL8_MEDIA_DRAFT_RETENTION_DAYS
        CIRCL8_API_LIMIT
    )
    local key="" value="" tmp_append="" backup_path="" ts=""

    tmp_append="$(mktemp /tmp/circl8-app-env-append.XXXXXX)"
    TEMP_FILES+=("$tmp_append")
    : > "$tmp_append"

    mini_header "Keys"
    for key in "${keys[@]}"; do
        if env_has_nonempty_value "$key"; then
            aligned_status_line "$key" "preserved" "$GN"
        else
            value="$(env_default_for_key "$key")"
            append_env_line "$key" "$value" >> "$tmp_append"
            SCRIPT64_ENV_KEYS_ADDED=$((SCRIPT64_ENV_KEYS_ADDED + 1))
            aligned_status_line "$key" "added" "$ANS"
        fi
    done

    if [ "$SCRIPT64_ENV_KEYS_ADDED" -gt 0 ]; then
        local tmp_env=""
        tmp_env="$(mktemp /tmp/circl8-app-env-new.XXXXXX)"
        TEMP_FILES+=("$tmp_env")
        ts="$(date +%Y%m%d-%H%M%S)"
        backup_path="${ENV_FILE}.bak.script64-${ts}"
        root_copy_file "$ENV_FILE" "$backup_path"
        SCRIPT64_ENV_BACKUP="created"
        root_read_file "$ENV_FILE" > "$tmp_env"
        printf '\n# Circl8 app keys added by Script 6.4 on %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" >> "$tmp_env"
        sed -n 'p' "$tmp_append" >> "$tmp_env"
        root_copy_file "$tmp_env" "$ENV_FILE"
        root_set_owner_group "$ENV_FILE" "${DOCKER_USER}:${DOCKER_USER}"
        root_set_mode "$ENV_FILE" 600
    else
        SCRIPT64_ENV_BACKUP="not-needed"
    fi

    msg_ok "CIRCL8 ENV READY"
}

# =========================================================
#  FOLDERS / TEMPLATES
# =========================================================
function prepare_postgres_dir() {
    if ! root_dir_exists "$CIRCL8_POSTGRES_DIR"; then
        root_install_dir "$CIRCL8_POSTGRES_DIR" 750
        root_set_owner_group "$CIRCL8_POSTGRES_DIR" "${DOCKER_USER}:${DOCKER_USER}"
        aligned_status_line "PostgreSQL data" "created" "$GN"
        return 0
    fi

    if root_path_exists "${CIRCL8_POSTGRES_DIR}/PG_VERSION"; then
        aligned_status_line "PostgreSQL data" "preserved" "$YW"
        return 0
    fi

    if root_dir_has_entries "$CIRCL8_POSTGRES_DIR"; then
        aligned_status_line "PostgreSQL data" "blocked" "$RD"
        fail_with_report "Circl8 PostgreSQL directory is non-empty without PG_VERSION: ${CIRCL8_POSTGRES_DIR}"
    fi

    root_set_owner_group "$CIRCL8_POSTGRES_DIR" "${DOCKER_USER}:${DOCKER_USER}"
    root_set_mode "$CIRCL8_POSTGRES_DIR" 750
    aligned_status_line "PostgreSQL data" "ready" "$GN"
}

function prepare_circl8_directories() {
    section "CIRCL8 DIRECTORIES"
    local dir=""

    root_install_dir "$CIRCL8_APPDATA_DIR" 755
    root_set_owner_group "$CIRCL8_APPDATA_DIR" "${DOCKER_USER}:${DOCKER_USER}"
    aligned_status_line "Appdata" "ready" "$GN"

    prepare_postgres_dir

    for dir in "$CIRCL8_POSTGRES_INIT_DIR" "$CIRCL8_REDIS_DIR" "$CIRCL8_UPLOADS_DIR" "$CIRCL8_TEMPORAL_DYNAMIC_CONFIG_DIR"; do
        root_install_dir "$dir" 755
        root_set_owner_group "$dir" "${DOCKER_USER}:${DOCKER_USER}"
    done

    aligned_status_line "Postgres init" "ready" "$GN"
    aligned_status_line "Redis data" "ready" "$GN"
    aligned_status_line "Uploads" "ready" "$GN"
    aligned_status_line "Temporal config" "ready" "$GN"
    msg_ok "CIRCL8 DIRECTORIES READY"
}

function render_template_simple() {
    local src="$1" dest="$2" tmp=""
    tmp="$(mktemp /tmp/circl8-render.XXXXXX)"
    TEMP_FILES+=("$tmp")
    sed \
        -e "s|{{DOCKER_DIR}}|${DOCKER_DIR}|g" \
        -e "s|{{DOMAIN}}|${DOMAIN_VALUE}|g" \
        -e "s|{{CIRCL8_HOST}}|${CIRCL8_HOST}|g" \
        -e "s|{{CIRCL8_URL}}|${CIRCL8_URL}|g" \
        "$src" > "$tmp"
    root_copy_file "$tmp" "$dest"
}

function download_and_render_templates() {
    section "TEMPLATES"
    local compose_tmp="" init_tmp="" dynamic_tmp=""

    compose_tmp="$(mktemp /tmp/circl8-compose-template.XXXXXX)"
    init_tmp="$(mktemp /tmp/circl8-postgres-init-template.XXXXXX)"
    dynamic_tmp="$(mktemp /tmp/circl8-temporal-config-template.XXXXXX)"
    TEMP_FILES+=("$compose_tmp" "$init_tmp" "$dynamic_tmp")

    msg_info "Downloading Circl8 compose template"
    download_file "$CIRCL8_COMPOSE_TEMPLATE_URL" "$compose_tmp" || fail_with_report "Failed to download Circl8 compose template."
    root_file_not_empty "$compose_tmp" || fail_with_report "Downloaded Circl8 compose template is empty."
    SCRIPT64_CIRCL8_COMPOSE_TEMPLATE="downloaded"
    msg_ok "CIRCL8 COMPOSE TEMPLATE DOWNLOADED"

    msg_info "Downloading Circl8 PostgreSQL init template"
    download_file "$CIRCL8_POSTGRES_INIT_TEMPLATE_URL" "$init_tmp" || fail_with_report "Failed to download Circl8 PostgreSQL init template."
    root_file_not_empty "$init_tmp" || fail_with_report "Downloaded Circl8 PostgreSQL init template is empty."
    SCRIPT64_CIRCL8_POSTGRES_INIT_TEMPLATE="downloaded"
    msg_ok "CIRCL8 POSTGRES INIT TEMPLATE DOWNLOADED"

    msg_info "Downloading Circl8 Temporal dynamic config template"
    download_file "$CIRCL8_TEMPORAL_DYNAMIC_CONFIG_TEMPLATE_URL" "$dynamic_tmp" || fail_with_report "Failed to download Circl8 Temporal dynamic config template."
    root_file_not_empty "$dynamic_tmp" || fail_with_report "Downloaded Circl8 Temporal dynamic config template is empty."
    SCRIPT64_CIRCL8_TEMPORAL_CONFIG_TEMPLATE="downloaded"
    msg_ok "CIRCL8 TEMPORAL CONFIG TEMPLATE DOWNLOADED"

    root_install_dir "$COMPOSE_DIR" 755
    render_template_simple "$compose_tmp" "$CIRCL8_COMPOSE_FILE"
    root_set_owner_group "$CIRCL8_COMPOSE_FILE" "${DOCKER_USER}:${DOCKER_USER}"
    root_set_mode "$CIRCL8_COMPOSE_FILE" 640
    aligned_status_line "Runtime compose" "rendered" "$GN"

    if [ "$ADMIN_UI" == "dockge" ]; then
        root_install_dir "$(dirname "$CIRCL8_DOCKGE_COMPOSE_FILE")" 755
        root_set_owner_group "$(dirname "$CIRCL8_DOCKGE_COMPOSE_FILE")" "${DOCKER_USER}:${DOCKER_USER}"
        root_copy_file "$CIRCL8_COMPOSE_FILE" "$CIRCL8_DOCKGE_COMPOSE_FILE"
        root_set_owner_group "$CIRCL8_DOCKGE_COMPOSE_FILE" "${DOCKER_USER}:${DOCKER_USER}"
        root_set_mode "$CIRCL8_DOCKGE_COMPOSE_FILE" 640
        aligned_status_line "Dockge compose" "synced" "$GN"
    else
        aligned_status_line "Dockge compose" "skipped" "$YW"
    fi

    render_template_simple "$init_tmp" "$CIRCL8_POSTGRES_INIT_FILE"
    root_set_owner_group "$CIRCL8_POSTGRES_INIT_FILE" "${DOCKER_USER}:${DOCKER_USER}"
    root_set_mode "$CIRCL8_POSTGRES_INIT_FILE" 755
    aligned_status_line "PostgreSQL init" "rendered" "$GN"

    render_template_simple "$dynamic_tmp" "$CIRCL8_TEMPORAL_DYNAMIC_CONFIG_FILE"
    root_set_owner_group "$CIRCL8_TEMPORAL_DYNAMIC_CONFIG_FILE" "${DOCKER_USER}:${DOCKER_USER}"
    root_set_mode "$CIRCL8_TEMPORAL_DYNAMIC_CONFIG_FILE" 644
    aligned_status_line "Temporal config" "rendered" "$GN"
}

# =========================================================
#  STATIC SAFETY / COMPOSE VALIDATION
# =========================================================
function uncommented_file_content() {
    local file="$1"
    root_read_file "$file" 2>/dev/null | sed '/^[[:space:]]*#/d'
}

function active_service_names() {
    local file="$1"
    root_read_file "$file" 2>/dev/null | awk '
        /^services:[[:space:]]*$/ { in_services=1; next }
        /^[^[:space:]][A-Za-z0-9_.-]*:/ { if (in_services) exit }
        in_services && /^[[:space:]][[:space:]][A-Za-z0-9_.-]+:[[:space:]]*$/ {
            line=$0
            sub(/^[[:space:]]*/, "", line)
            sub(/:.*/, "", line)
            print line
        }
    ' | sort
}

function require_static_safety() {
    section "STATIC SAFETY"
    local active="" expected="" noncomment=""
    active="$(active_service_names "$CIRCL8_COMPOSE_FILE" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    expected="circl8 circl8-postgres circl8-redis circl8-temporal"
    noncomment="$(uncommented_file_content "$CIRCL8_COMPOSE_FILE")"

    aligned_status_line "Active services" "$active" "$GN"
    [ "$active" == "$expected" ] || fail_with_report "Rendered compose active services are not limited to the expected Circl8 set."

    if printf '%s\n' "$noncomment" | grep -qE '^[[:space:]]{2}temporal-elasticsearch:'; then fail_with_report "Rendered compose has active temporal-elasticsearch service."; fi
    if printf '%s\n' "$noncomment" | grep -qE 'ENABLE_ES[[:space:]]*[:=][[:space:]]*true'; then fail_with_report "Rendered compose enables Elasticsearch."; fi
    if printf '%s\n' "$noncomment" | grep -qE '^[[:space:]-]*ES_SEEDS[[:space:]]*[:=]'; then fail_with_report "Rendered compose has active ES_SEEDS."; fi
    if printf '%s\n' "$noncomment" | grep -qE 'docker[.]sock|/var/run/docker[.]sock'; then fail_with_report "Rendered compose contains a Docker socket mount/reference."; fi
    if printf '%s\n' "$noncomment" | grep -qE '^[[:space:]]+ports:'; then fail_with_report "Rendered compose contains active host ports."; fi
    if printf '%s\n' "$noncomment" | grep -q 'CIRCL8_POSTGRES_PASSWORD'; then fail_with_report "Rendered compose still references legacy CIRCL8_POSTGRES_PASSWORD."; fi
    printf '%s\n' "$noncomment" | grep -q 'image: postgres:17-alpine' || fail_with_report "Rendered compose does not use postgres:17-alpine."
    printf '%s\n' "$noncomment" | grep -q 'DB: postgres12' || fail_with_report "Rendered compose does not set Temporal DB mode postgres12."
    printf '%s\n' "$noncomment" | grep -q 'ghcr.io/gitroomhq/postiz-app:latest' || fail_with_report "Rendered compose does not preserve the upstream Postiz image."
    printf '%s\n' "$noncomment" | grep -q 'POSTGRES_PASSWORD: ${CIRCL8_POSTGRES_SUPERUSER_PASSWORD}' || fail_with_report "Rendered compose does not use CIRCL8_POSTGRES_SUPERUSER_PASSWORD for POSTGRES_PASSWORD."
    printf '%s\n' "$noncomment" | grep -q 'DATABASE_URL: postgresql://circl8_app_user:${CIRCL8_APP_POSTGRES_PASSWORD}@circl8-postgres:5432/circl8_app' || fail_with_report "Rendered compose does not use CIRCL8_APP_POSTGRES_PASSWORD in DATABASE_URL."
    printf '%s\n' "$noncomment" | grep -q 'POSTGRES_PWD: ${CIRCL8_TEMPORAL_POSTGRES_PASSWORD}' || fail_with_report "Rendered compose does not use CIRCL8_TEMPORAL_POSTGRES_PASSWORD for Temporal."

    SCRIPT64_CIRCL8_STATIC_SAFETY="pass"
    aligned_status_line "Elasticsearch" "not active" "$GN"
    aligned_status_line "Host ports" "none" "$GN"
    aligned_status_line "Legacy DB variable" "absent" "$GN"
    msg_ok "STATIC SAFETY PASSED"
}

function validate_compose_config() {
    section "COMPOSE CONFIG"
    msg_info "Validating Circl8 compose config"
    if docker_cmd compose --env-file "$ENV_FILE" -p circl8 -f "$CIRCL8_COMPOSE_FILE" config -q >/dev/null; then
        SCRIPT64_CIRCL8_COMPOSE_CONFIG="valid"
        msg_ok "CIRCL8 COMPOSE CONFIG VALID"
    else
        SCRIPT64_CIRCL8_COMPOSE_CONFIG="failed"
        fail_with_report "docker compose config validation failed for Circl8."
    fi
}

function mark_template_preflight_ready() {
    SCRIPT64_STATUS="template-preflight-completed"
    SCRIPT64_VERIFY_STATUS="PASS"
    SCRIPT64_DEPLOYMENT="not-run"
    SCRIPT64_READY_FOR_DEPLOYMENT_LANE="yes"
    SCRIPT64_READY_FOR_AUTHENTIK_LANE="no"
    SCRIPT64_READY_FOR_SCRIPT65="no"
    write_completion_marker
    write_verify_report
}

function confirm_deploy_or_finish_preflight() {
    section "DEPLOY CIRCL8"
    mini_header "Plan"
    aligned_status_line "Action" "start core containers" "$YW"
    aligned_status_line "Project" "circl8" "$GN"
    aligned_status_line "Services" "circl8-postgres, circl8-redis, circl8-temporal, circl8" "$GN"
    aligned_status_line "Data reset" "no" "$GN"
    aligned_status_line "Destructive actions" "none" "$GN"
    echo ""
    echo -e "${YW}This will start the Circl8 core containers but will not delete/reset data.${CL}"
    echo ""

    if [ ! -r /dev/tty ]; then
        msg_warn "No interactive TTY available; Circl8 deployment skipped. Template preflight remains complete."
        aligned_status_line "Deployment confirmation" "no" "$YW"
        return 1
    fi

    if read_yes_no "Start Circl8 core containers now? This will not delete/reset data." "n"; then
        aligned_status_line "Deployment confirmation" "yes" "$GN"
        return 0
    fi

    aligned_status_line "Deployment confirmation" "no" "$YW"
    return 1
}

function write_template_preflight_success() {
    mark_template_preflight_ready
}

function write_template_preflight_marker_report() {
    write_template_preflight_success
}

function deploy_circl8_core() {
    SCRIPT64_DEPLOYMENT="running"
    init_deploy_output_log
    msg_info "Starting Circl8 core stack"
    if docker_cmd compose --env-file "$ENV_FILE" -p circl8 -f "$CIRCL8_COMPOSE_FILE" up -d >> "$DEPLOY_OUTPUT_LOG" 2>&1; then
        msg_ok "CIRCL8 CORE STACK STARTED"
    else
        SCRIPT64_DEPLOYMENT="failed"
        fail_deployment "Circl8 core compose deployment failed."
    fi
}

function verify_circl8_core() {
    section "VERIFY CIRCL8"

    msg_info "Waiting for circl8-postgres"
    if wait_for_container_status circl8-postgres healthy 240; then
        SCRIPT64_CIRCL8_POSTGRES="healthy"
        msg_ok "circl8-postgres healthy"
    else
        SCRIPT64_CIRCL8_POSTGRES="failed"
        fail_deployment "circl8-postgres did not become healthy."
    fi

    msg_info "Waiting for circl8-redis"
    if wait_for_container_status circl8-redis healthy-or-running 120; then
        SCRIPT64_CIRCL8_REDIS="healthy"
        msg_ok "circl8-redis ready"
    else
        SCRIPT64_CIRCL8_REDIS="failed"
        fail_deployment "circl8-redis did not become ready."
    fi

    msg_info "Waiting for circl8-temporal"
    if wait_for_container_status circl8-temporal healthy-or-running 300 && wait_for_temporal_api 240; then
        SCRIPT64_CIRCL8_TEMPORAL="ready"
        msg_ok "circl8-temporal ready"
    else
        SCRIPT64_CIRCL8_TEMPORAL="failed"
        fail_deployment "circl8-temporal API did not become ready."
    fi

    msg_info "Waiting for circl8 app"
    if wait_for_container_status circl8 healthy-or-running 300; then
        SCRIPT64_CIRCL8_APP="running"
        msg_ok "circl8 app running"
    else
        SCRIPT64_CIRCL8_APP="failed"
        fail_deployment "circl8 app container did not become ready."
    fi

    msg_info "Checking internal app HTTP"
    if wait_for_circl8_internal_http 240; then
        SCRIPT64_CIRCL8_INTERNAL_HTTP="ready"
        msg_ok "Internal app HTTP ready"
    else
        SCRIPT64_CIRCL8_INTERNAL_HTTP="failed"
        fail_deployment "Circl8 internal app HTTP did not respond on expected port."
    fi

    msg_info "Checking protected public route"
    if verify_public_route_behavior; then
        SCRIPT64_CIRCL8_ROUTE="protected"
        msg_ok "Circl8 route protected"
    else
        local route_result="$?"
        if [ "$route_result" = "2" ]; then
            SCRIPT64_CIRCL8_ROUTE="failed"
            fail_deployment "Circl8 Traefik labels are missing or invalid."
        fi
        if [ "$route_result" = "3" ]; then
            SCRIPT64_CIRCL8_ROUTE="failed"
            fail_deployment "Circl8 public route responded without expected protected behavior."
        fi
        if check_traefik_infra_errors; then
            SCRIPT64_CIRCL8_ROUTE="needs-review"
            msg_warn "Circl8 public route needs review; internal app is ready and no Traefik infrastructure error was detected."
        else
            SCRIPT64_CIRCL8_ROUTE="failed"
            fail_deployment "Traefik reported Circl8 route infrastructure errors."
        fi
    fi

    aligned_status_line "PostgreSQL" "$SCRIPT64_CIRCL8_POSTGRES" "$(status_color_for_value "$SCRIPT64_CIRCL8_POSTGRES")"
    aligned_status_line "Redis" "$SCRIPT64_CIRCL8_REDIS" "$(status_color_for_value "$SCRIPT64_CIRCL8_REDIS")"
    aligned_status_line "Temporal" "$SCRIPT64_CIRCL8_TEMPORAL" "$(status_color_for_value "$SCRIPT64_CIRCL8_TEMPORAL")"
    aligned_status_line "Circl8 app" "$SCRIPT64_CIRCL8_APP" "$(status_color_for_value "$SCRIPT64_CIRCL8_APP")"
    aligned_status_line "Internal HTTP" "$SCRIPT64_CIRCL8_INTERNAL_HTTP" "$(status_color_for_value "$SCRIPT64_CIRCL8_INTERNAL_HTTP")"
    aligned_status_line "Public route" "$SCRIPT64_CIRCL8_ROUTE" "$(status_color_for_value "$SCRIPT64_CIRCL8_ROUTE")"
}

function finish_preflight_only_success() {
    mark_template_preflight_ready

    section_flash_success "FINISHED"
    mini_header "Circl8"
    final_line "Status" "$SCRIPT64_STATUS" "$GN"
    final_line "Verification" "$SCRIPT64_VERIFY_STATUS" "$GN"
    final_line "Deployment" "$SCRIPT64_DEPLOYMENT" "$GN"
    final_line "t2_proxy network" "$SCRIPT64_NETWORK_T2_PROXY" "$(status_color_for_value "$SCRIPT64_NETWORK_T2_PROXY")"
    final_line "database network" "$SCRIPT64_NETWORK_DATABASE" "$(status_color_for_value "$SCRIPT64_NETWORK_DATABASE")"
    final_line "Compose config" "$SCRIPT64_CIRCL8_COMPOSE_CONFIG" "$GN"
    final_line "Static safety" "$SCRIPT64_CIRCL8_STATIC_SAFETY" "$GN"
    final_line "Ready for deploy lane" "$SCRIPT64_READY_FOR_DEPLOYMENT_LANE" "$GN"
    final_line "Ready for Authentik lane" "$SCRIPT64_READY_FOR_AUTHENTIK_LANE" "$YW"
    final_line "Ready for Script 6.5" "$SCRIPT64_READY_FOR_SCRIPT65" "$YW"
    final_line "Verify log" "$VERIFY_LOG" "$BL"
    final_line "Template marker" "$COMPLETED_MARKER" "$BL"
}

function finish_deployment_success() {
    SCRIPT64_STATUS="completed"
    SCRIPT64_VERIFY_STATUS="PASS"
    SCRIPT64_DEPLOYMENT="completed"
    SCRIPT64_READY_FOR_DEPLOYMENT_LANE="yes"
    SCRIPT64_READY_FOR_AUTHENTIK_LANE="yes"
    SCRIPT64_READY_FOR_SCRIPT65="no"
    write_deployment_marker
    write_verify_report

    section_flash_success "FINISHED"
    mini_header "Circl8"
    final_line "Status" "$SCRIPT64_STATUS" "$GN"
    final_line "Verification" "$SCRIPT64_VERIFY_STATUS" "$GN"
    final_line "Deployment" "$SCRIPT64_DEPLOYMENT" "$GN"
    final_line "PostgreSQL" "$SCRIPT64_CIRCL8_POSTGRES" "$(status_color_for_value "$SCRIPT64_CIRCL8_POSTGRES")"
    final_line "Redis" "$SCRIPT64_CIRCL8_REDIS" "$(status_color_for_value "$SCRIPT64_CIRCL8_REDIS")"
    final_line "Temporal" "$SCRIPT64_CIRCL8_TEMPORAL" "$(status_color_for_value "$SCRIPT64_CIRCL8_TEMPORAL")"
    final_line "Circl8 app" "$SCRIPT64_CIRCL8_APP" "$(status_color_for_value "$SCRIPT64_CIRCL8_APP")"
    final_line "Internal HTTP" "$SCRIPT64_CIRCL8_INTERNAL_HTTP" "$(status_color_for_value "$SCRIPT64_CIRCL8_INTERNAL_HTTP")"
    final_line "Public route" "$SCRIPT64_CIRCL8_ROUTE" "$(status_color_for_value "$SCRIPT64_CIRCL8_ROUTE")"
    final_line "Ready for Authentik lane" "$SCRIPT64_READY_FOR_AUTHENTIK_LANE" "$GN"
    final_line "Ready for Script 6.5" "$SCRIPT64_READY_FOR_SCRIPT65" "$YW"
    final_line "Verify log" "$VERIFY_LOG" "$BL"
    final_line "Template marker" "$COMPLETED_MARKER" "$BL"
    final_line "Deploy marker" "$DEPLOYED_MARKER" "$BL"
}

function run_circl8_deploy_success_path() {
    deploy_circl8_core
    verify_circl8_core
    finish_deployment_success
}

function run_deploy_decision_or_mode() {
    case "$SCRIPT64_RUN_MODE" in
        preflight-only)
            section "DEPLOY CIRCL8"
            mini_header "Mode"
            aligned_status_line "Run mode" "preflight-only" "$YW"
            aligned_status_line "Deployment" "not-run" "$GN"
            msg_warn "Preflight-only mode selected; Circl8 deployment skipped."
            finish_preflight_only_success
            ;;
        deploy)
            section "DEPLOY CIRCL8"
            mini_header "Mode"
            aligned_status_line "Run mode" "deploy" "$GN"
            aligned_status_line "Deployment confirmation" "yes" "$GN"
            run_circl8_deploy_success_path
            ;;
        prompt)
            if confirm_deploy_or_finish_preflight; then
                run_circl8_deploy_success_path
            else
                finish_preflight_only_success
            fi
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
}

function init_script() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    detect_root_or_sudo
    validate_sudo_access
    init_logging
    trap 'on_error "$LINENO"' ERR
    trap cleanup EXIT
    clear 2>/dev/null || printf '\033c'
    header_info
    show_script_version
    validate_dependencies
}

function run_post_compose_flow() {
    write_template_preflight_success
    run_deploy_decision_or_mode
}

function main() {
    parse_args "$@"
    init_script
    validate_script63_gate
    runtime_preflight
    ensure_circl8_env_keys
    prepare_circl8_directories
    download_and_render_templates
    require_static_safety
    validate_compose_config
    run_post_compose_flow
}

main "$@"
