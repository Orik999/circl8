#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Project Circl8 - Script 6.4 Circl8 Template Preflight
# =========================================================
# Phase 4 v1.2.2 keeps the marker/env-derived Authentik identity lane and
# polishes interactive rerun/UI flow without changing core deploy or Authentik
# identity API semantics.

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
SCRIPT_VERSION="v1.2.3"
SCRIPT_UPDATED="2026-06-17"
SCRIPT_BUILD="temporal-search-attribute-guard"

T="15"
UI_LABEL_WIDTH="34"

LOG_FILE="/var/log/circl8-app-bootstrap.log"
VERIFY_LOG="/var/log/circl8-app-verify.log"
COMPLETED_MARKER="/root/.circl8-app-template-preflight-completed"
DEPLOYED_MARKER="/root/.circl8-app-completed"
FAILURE_LOG=""
DEPLOY_OUTPUT_LOG=""
SCRIPT6_MARKER="/root/.docker-env-setup-completed"
SCRIPT61_MARKER="/root/.circl8-platform-core-completed"
UBUNTU_SEED_MARKER="/root/.ubuntu-autoinstall-seed-completed"
SCRIPT63_MARKER="/root/.circl8-authentik-completed"

SUDO_CMD=""
DOCKER_NEEDS_SUDO="no"
RUNTIME_LOG_FILE=""
SCRIPT_DIR=""
TEMP_FILES=()
TEMP_DIRS=()
SCRIPT64_RUN_MODE="prompt"
SCRIPT64_AUTHENTIK_LANE_RAN="no"
SCRIPT64_EXISTING_DEPLOYMENT_STATE="unknown"

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

CIRCL8_HOST=""
CIRCL8_URL=""
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

PROJECT_BASE_DOMAIN=""
PROJECT_SLUG=""
PROJECT_NAME=""
PROJECT_APP_PREFIX=""
PROJECT_APP_HOST=""
PROJECT_APP_URL=""
PROJECT_AUTH_PREFIX=""
PROJECT_AUTH_HOST=""
PROJECT_AUTH_URL=""
PROJECT_COOKIE_DOMAIN=""
SCRIPT63_AUTHENTIK_OUTPOST_PK=""
SCRIPT63_AUTHENTIK_PROVIDER_PK=""

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
SCRIPT64_TEMPORAL_SEARCH_ATTRS="not-run"
SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR="not-needed"
SCRIPT64_AUTHENTIK_GROUPS="not-run"
SCRIPT64_AUTHENTIK_POLICY="not-run"
SCRIPT64_AUTHENTIK_APPLICATION="not-run"
SCRIPT64_AUTHENTIK_PROVIDER="not-run"
SCRIPT64_AUTHENTIK_OUTPOST="not-run"
SCRIPT64_AUTHENTIK_AKADMIN="not-run"
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
        PASS|pass|completed|present|ready|yes|valid|downloaded|rendered|synced|created|preserved|healthy|running|protected|not-needed|not\ needed|template-preflight-completed|render-only-completed|verify-only-completed|not-run|not\ run|preserved) printf '%s' "$GN" ;;
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
        render-only-completed) printf 'render only completed' ;;
        verify-only-completed) printf 'verify only completed' ;;
        deploy-core) printf 'deploy core only' ;;
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

function progress_status_line() {
    local label="$1" value="${2:-pending}" color="${3:-$YW}"
    aligned_status_line "$label" "$value" "$color"
}

function progress_ready_line() {
    local label="$1" value="${2:-ready}"
    printf '  %b %b%-*s%b %b%s%b\n' "$CM" "$BL" "$UI_LABEL_WIDTH" "${label}:" "$CL" "$GN" "$(ui_display_value "$value")" "$CL"
}

function progress_fail_line() {
    local label="$1" value="${2:-failed}"
    echo -ne "${BFR}"
    printf '  %b %b%-*s%b %b%s%b\n' "$CROSS" "$BL" "$UI_LABEL_WIDTH" "${label}:" "$CL" "$RD" "$(ui_display_value "$value")" "$CL"
}

function tty_print() {
    if [ -w /dev/tty ]; then
        echo -ne "$*" > /dev/tty
    else
        echo -ne "$*" >&2
    fi
}

function tty_println() {
    if [ -w /dev/tty ]; then
        echo -e "$*" > /dev/tty
    else
        echo -e "$*" >&2
    fi
}

function flush_input_buffer() {
    local junk="" i=""
    [ -r /dev/tty ] || return 0
    for i in {1..20}; do
        IFS= read -rsn1 -t 0.02 junk < /dev/tty || break
    done
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
' "Usage: sudo ./6.4-circl8Bootstrap.sh [--preflight-only|--deploy|--authentik-only|--verify-only|--render-only]"
}

function parse_args() {
    local arg=""
    SCRIPT64_RUN_MODE="prompt"
    SCRIPT64_AUTHENTIK_LANE_RAN="no"
    SCRIPT64_EXISTING_DEPLOYMENT_STATE="unknown"

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
            --authentik-only)
                SCRIPT64_RUN_MODE="authentik-only"
                ;;
            --verify-only)
                SCRIPT64_RUN_MODE="verify-only"
                ;;
            --render-only)
                SCRIPT64_RUN_MODE="render-only"
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
    local prompt="$1" default="${2:-n}" key="" label="y/N" answer=""
    [[ "$default" =~ ^[Yy]$ ]] && label="Y/n"

    if [ ! -r /dev/tty ]; then
        return 2
    fi

    flush_input_buffer 2>/dev/null || true
    while true; do
        tty_print "${BFR}${YW}${prompt} [${label}]: ${CL}"
        IFS= read -rsn1 key < /dev/tty || key=""
        case "$key" in
            "")
                answer="$default"
                break
                ;;
            $'\n'|$'\r')
                answer="$default"
                break
                ;;
            [Yy])
                answer="y"
                break
                ;;
            [Nn])
                answer="n"
                break
                ;;
            *)
                continue
                ;;
        esac
    done
    tty_print "${BFR}"
    flush_input_buffer 2>/dev/null || true
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

function circl8_http_status() {
    local port="$1" path="$2"
    docker_cmd exec circl8 node -e '''
const http = require("http");
const port = Number(process.argv[1]);
const path = process.argv[2] || "/";
const req = http.get({host: "127.0.0.1", port, path, timeout: 5000}, (res) => {
  console.log(res.statusCode);
  res.resume();
  res.on("end", () => process.exit(0));
});
req.on("error", () => process.exit(111));
req.setTimeout(5000, () => { req.destroy(); process.exit(124); });
''' "$port" "$path" 2>/dev/null | tr -d '\r' | tail -n1
}

function circl8_http_endpoint_ready() {
    local label="$1" port="$2" path="$3" status=""
    status="$(circl8_http_status "$port" "$path" || true)"
    [[ "$status" =~ ^[0-9]{3}$ ]] || return 1
    if [ "$label" = "nginx-api" ] && [ "$status" = "502" ]; then
        return 1
    fi
    return 0
}

function wait_for_circl8_internal_http() {
    local timeout_seconds="${1:-240}" elapsed="0"
    while [ "$elapsed" -le "$timeout_seconds" ]; do
        if circl8_http_endpoint_ready "frontend" 4200 "/"             && circl8_http_endpoint_ready "backend-root" 3000 "/"             && circl8_http_endpoint_ready "backend-register" 3000 "/auth/can-register"             && circl8_http_endpoint_ready "nginx-root" 5000 "/"             && circl8_http_endpoint_ready "nginx-api" 5000 "/api/auth/can-register"; then
            return 0
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    return 1
}

function temporal_sample_search_attribute_present() {
    local name="$1"
    docker_cmd exec circl8-temporal sh -lc "temporal operator search-attribute list --address circl8-temporal:7233 --namespace default 2>/dev/null | awk '{print \\$1}' | grep -Fxq '$name'"
}

function temporal_remove_sample_search_attribute() {
    local name="$1"
    case "$name" in
        CustomStringField)
            docker_cmd exec circl8-temporal temporal operator search-attribute remove --address circl8-temporal:7233 --namespace default --name CustomStringField --yes >/dev/null 2>&1
            ;;
        CustomTextField)
            docker_cmd exec circl8-temporal temporal operator search-attribute remove --address circl8-temporal:7233 --namespace default --name CustomTextField --yes >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

function temporal_sample_search_attributes_absent() {
    ! temporal_sample_search_attribute_present CustomStringField && ! temporal_sample_search_attribute_present CustomTextField
}

function verify_temporal_search_attribute_guard_readonly() {
    if temporal_sample_search_attributes_absent; then
        SCRIPT64_TEMPORAL_SEARCH_ATTRS="ready"
        SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR="not-needed"
        return 0
    fi
    SCRIPT64_TEMPORAL_SEARCH_ATTRS="failed"
    SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR="failed"
    return 1
}

function run_temporal_search_attribute_guard() {
    local repaired="no" failed="no" name=""

    for name in CustomStringField CustomTextField; do
        if temporal_sample_search_attribute_present "$name"; then
            if temporal_remove_sample_search_attribute "$name"; then
                repaired="yes"
            else
                failed="yes"
            fi
        fi
    done

    if [ "$failed" = "yes" ] || ! temporal_sample_search_attributes_absent; then
        SCRIPT64_TEMPORAL_SEARCH_ATTRS="failed"
        SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR="failed"
        return 1
    fi

    SCRIPT64_TEMPORAL_SEARCH_ATTRS="ready"
    if [ "$repaired" = "yes" ]; then
        SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR="repaired"
        return 2
    fi

    SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR="not-needed"
    return 0
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
    local labels="" route_host="${PROJECT_APP_HOST:-${CIRCL8_HOST}}"
    labels="$(docker_cmd inspect circl8 --format '{{json .Config.Labels}}' 2>/dev/null || true)"
    [ -n "$route_host" ] || return 1
    printf '%s\n' "$labels" | grep -q "$route_host" || return 1
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
        headers="$(curl -kIsS --max-time 12 "https://${PROJECT_APP_HOST:-${CIRCL8_HOST}}" 2>/dev/null || true)"
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
    DOMAIN_VALUE="${env_domain:-$(marker_file_key_value "$SCRIPT6_MARKER" SCRIPT6_DOMAIN)}"
    DOMAIN_VALUE="${DOMAIN_VALUE:-$(marker_file_key_value "$SCRIPT61_MARKER" SCRIPT61_DOMAIN)}"
    DOMAIN_VALUE="${DOMAIN_VALUE:-$(marker_file_key_value "$UBUNTU_SEED_MARKER" PROXMOX_DOMAIN)}"
    env_admin_ui="$(env_value ADMIN_UI)"
    ADMIN_UI="${env_admin_ui:-dockge}"
    CIRCL8_HOST="$(default_project_app_host)"
    CIRCL8_URL="https://${CIRCL8_HOST}"

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
#  PROJECT IDENTITY / AUTHENTIK IDENTITY LANE
# =========================================================
function host_from_url() {
    local value="${1:-}"
    value="$(printf '%s' "$value" | trim_shell_value)"
    value="${value#http://}"
    value="${value#https://}"
    value="${value%%/*}"
    value="${value%%:*}"
    value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
    printf '%s' "$value"
}

function sanitize_slug() {
    local value="${1:-}"
    value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
    printf '%s' "$value"
}

function first_label_from_domain() {
    local host="${1:-}" base="${2:-}" label=""
    host="$(host_from_url "$host")"
    base="$(host_from_url "$base")"
    if [ -n "$base" ] && [ "$host" != "$base" ]; then
        label="${host%.${base}}"
        label="${label%%.*}"
    else
        label="${host%%.*}"
    fi
    sanitize_slug "$label"
}

function title_case_slug() {
    local value="${1:-}"
    printf '%s' "$value" | awk -F'[-_ ]+' '{out=""; for (i=1; i<=NF; i++) { if ($i != "") out=out (out?" ":"") toupper(substr($i,1,1)) substr($i,2) } print out}'
}

function default_project_base_domain() {
    local value=""
    value="$(env_value DOMAIN)"
    value="${value:-$(marker_file_key_value "$SCRIPT6_MARKER" SCRIPT6_DOMAIN)}"
    value="${value:-$(marker_file_key_value "$SCRIPT61_MARKER" SCRIPT61_DOMAIN)}"
    value="${value:-$(marker_file_key_value "$UBUNTU_SEED_MARKER" PROXMOX_DOMAIN)}"
    value="$(host_from_url "$value")"
    printf '%s' "$value"
}

function default_project_app_host() {
    local base="" value=""
    base="$(default_project_base_domain)"
    value="$(env_value CIRCL8_HOST)"
    value="${value:-$(env_value POSTIZ_HOST)}"
    [ -n "$value" ] || value="$(host_from_url "$(env_value CIRCL8_URL)")"
    [ -n "$value" ] || value="$(host_from_url "$(env_value POSTIZ_URL)")"
    [ -n "$value" ] || value="app.${base}"
    value="$(host_from_url "$value")"
    printf '%s' "$value"
}

function derive_project_identity() {
    section "PROJECT IDENTITY"
    local env_project_slug="" env_app_slug="" env_project_name="" env_app_name="" env_company_name=""

    PROJECT_BASE_DOMAIN="$(default_project_base_domain)"
    [ -n "$PROJECT_BASE_DOMAIN" ] || fail_with_report "Project base domain could not be derived from .env or markers."

    PROJECT_APP_HOST="$(default_project_app_host)"
    [ -n "$PROJECT_APP_HOST" ] || fail_with_report "Project app host could not be derived."

    PROJECT_APP_PREFIX="$(first_label_from_domain "$PROJECT_APP_HOST" "$PROJECT_BASE_DOMAIN")"
    [ -n "$PROJECT_APP_PREFIX" ] || fail_with_report "Project app prefix could not be derived."

    PROJECT_AUTH_HOST="$(env_value AUTHENTIK_ROUTE_HOST)"
    [ -n "$PROJECT_AUTH_HOST" ] || PROJECT_AUTH_HOST="$(host_from_url "$(env_value AUTHENTIK_EXTERNAL_URL)")"
    [ -n "$PROJECT_AUTH_HOST" ] || PROJECT_AUTH_HOST="$(host_from_url "$(env_value AUTHENTIK_HOST)")"
    [ -n "$PROJECT_AUTH_HOST" ] || PROJECT_AUTH_HOST="$(host_from_url "$(env_value AUTHENTIK_HOST_BROWSER)")"
    [ -n "$PROJECT_AUTH_HOST" ] || PROJECT_AUTH_HOST="auth.${PROJECT_BASE_DOMAIN}"
    PROJECT_AUTH_HOST="$(host_from_url "$PROJECT_AUTH_HOST")"
    [ -n "$PROJECT_AUTH_HOST" ] || fail_with_report "Project Authentik host could not be derived."

    PROJECT_AUTH_PREFIX="$(first_label_from_domain "$PROJECT_AUTH_HOST" "$PROJECT_BASE_DOMAIN")"
    [ -n "$PROJECT_AUTH_PREFIX" ] || fail_with_report "Project Authentik prefix could not be derived."

    env_project_slug="$(env_value PROJECT_SLUG)"
    env_app_slug="$(env_value APP_SLUG)"
    PROJECT_SLUG="$(sanitize_slug "${env_project_slug:-${env_app_slug:-${PROJECT_BASE_DOMAIN%%.*}}}")"
    [ -n "$PROJECT_SLUG" ] || fail_with_report "Project slug could not be derived."

    env_project_name="$(env_value PROJECT_NAME)"
    env_app_name="$(env_value APP_NAME)"
    env_company_name="$(env_value COMPANY_NAME)"
    PROJECT_NAME="${env_project_name:-${env_app_name:-${env_company_name:-$(title_case_slug "$PROJECT_SLUG")}}}"
    [ -n "$PROJECT_NAME" ] || fail_with_report "Project name could not be derived."

    PROJECT_COOKIE_DOMAIN=".${PROJECT_BASE_DOMAIN}"
    PROJECT_APP_URL="https://${PROJECT_APP_HOST}"
    PROJECT_AUTH_URL="https://${PROJECT_AUTH_HOST}"
    CIRCL8_HOST="$PROJECT_APP_HOST"
    CIRCL8_URL="$PROJECT_APP_URL"

    SCRIPT63_AUTHENTIK_OUTPOST_PK="$(marker_file_key_value "$SCRIPT63_MARKER" SCRIPT63_AUTHENTIK_OUTPOST_PK)"
    SCRIPT63_AUTHENTIK_PROVIDER_PK="$(marker_file_key_value "$SCRIPT63_MARKER" SCRIPT63_AUTHENTIK_PROVIDER_PK)"
    [ -n "$SCRIPT63_AUTHENTIK_OUTPOST_PK" ] || fail_with_report "Script 6.3 Authentik outpost marker key is missing."

    aligned_status_line "Base domain" "$PROJECT_BASE_DOMAIN" "$GN"
    aligned_status_line "Project slug" "$PROJECT_SLUG" "$GN"
    aligned_status_line "Project name" "$PROJECT_NAME" "$GN"
    aligned_status_line "App host" "$PROJECT_APP_HOST" "$GN"
    aligned_status_line "Authentik host" "$PROJECT_AUTH_HOST" "$GN"
    aligned_status_line "Cookie domain" "$PROJECT_COOKIE_DOMAIN" "$GN"
}

function build_authentik_identity_payload() {
    local bootstrap_token="" api_token=""
    bootstrap_token="$(env_value AUTHENTIK_BOOTSTRAP_TOKEN)"
    api_token="$(env_value AUTHENTIK_API_TOKEN)"
    AUTHENTIK_BOOTSTRAP_TOKEN_PAYLOAD="$bootstrap_token" \
    AUTHENTIK_API_TOKEN_PAYLOAD="$api_token" \
    PROJECT_BASE_DOMAIN_PAYLOAD="$PROJECT_BASE_DOMAIN" \
    PROJECT_SLUG_PAYLOAD="$PROJECT_SLUG" \
    PROJECT_NAME_PAYLOAD="$PROJECT_NAME" \
    PROJECT_APP_URL_PAYLOAD="$PROJECT_APP_URL" \
    PROJECT_AUTH_URL_PAYLOAD="$PROJECT_AUTH_URL" \
    PROJECT_COOKIE_DOMAIN_PAYLOAD="$PROJECT_COOKIE_DOMAIN" \
    SCRIPT63_AUTHENTIK_OUTPOST_PK_PAYLOAD="$SCRIPT63_AUTHENTIK_OUTPOST_PK" \
    python3 - <<'PYCODE'
import json, os
keys = {
    "bootstrap_token": "AUTHENTIK_BOOTSTRAP_TOKEN_PAYLOAD",
    "api_token": "AUTHENTIK_API_TOKEN_PAYLOAD",
    "project_base_domain": "PROJECT_BASE_DOMAIN_PAYLOAD",
    "project_slug": "PROJECT_SLUG_PAYLOAD",
    "project_name": "PROJECT_NAME_PAYLOAD",
    "project_app_url": "PROJECT_APP_URL_PAYLOAD",
    "project_auth_url": "PROJECT_AUTH_URL_PAYLOAD",
    "project_cookie_domain": "PROJECT_COOKIE_DOMAIN_PAYLOAD",
    "outpost_pk": "SCRIPT63_AUTHENTIK_OUTPOST_PK_PAYLOAD",
}
print(json.dumps({key: os.environ.get(env, "") for key, env in keys.items()}))
PYCODE
}

function authentik_identity_python_code() {
cat <<'PYCODE'
import json, sys, time, re, urllib.parse, urllib.request, urllib.error

BASE_URL = "http://127.0.0.1:9000"
payload = json.loads(sys.stdin.read() or "{}")
selected_token = ""

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

opener = urllib.request.build_opener(NoRedirect)

def sanitize(text):
    text = str(text or "")
    for key in ("bootstrap_token", "api_token"):
        value = payload.get(key) or ""
        if value:
            text = text.replace(value, "[redacted]")
    text = re.sub(r"(?i)(password|token|secret|authorization|bearer)[^\n]{0,160}", "[redacted]", text)
    return text[:1000]

def emit(key, value):
    value = "" if value is None else str(value)
    value = value.replace("\n", " ").replace("\r", " ")
    print(f"{key}={value}")

def fail(stage, message):
    emit("RESULT", "failed")
    emit("ERROR_STAGE", stage)
    emit("ERROR_MESSAGE", sanitize(message))
    sys.exit(2)

def raw_request(method, path, body=None, token=None, expected=None, stage="api"):
    url = BASE_URL + path
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    if token:
        req.add_header("Authorization", "Bearer " + token)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with opener.open(req, timeout=15) as response:
            raw = response.read().decode("utf-8", "replace")
            code = getattr(response, "status", 200)
    except urllib.error.HTTPError as error:
        raw = error.read().decode("utf-8", "replace")
        code = error.code
    except Exception as error:
        raw = sanitize(error)
        code = 0
    parsed = None
    try:
        parsed = json.loads(raw) if raw else None
    except Exception:
        parsed = None
    if expected is not None and code not in expected:
        fail(stage, f"{method} {path} returned HTTP {code}: {sanitize(raw)}")
    return code, parsed, raw

def api_request(method, path, body=None, expected=(200,), stage="api"):
    code, parsed, raw = raw_request(method, path, body=body, token=selected_token, expected=expected, stage=stage)
    return parsed

def result_items(parsed):
    if isinstance(parsed, dict) and isinstance(parsed.get("results"), list):
        return parsed["results"]
    if isinstance(parsed, list):
        return parsed
    return []

def validate_token(timeout=180, interval=5):
    global selected_token
    candidates = [
        ("AUTHENTIK_BOOTSTRAP_TOKEN", payload.get("bootstrap_token") or ""),
        ("AUTHENTIK_API_TOKEN", payload.get("api_token") or ""),
    ]
    deadline = time.time() + timeout
    last_status = 0
    while time.time() <= deadline:
        for source, token in candidates:
            if not token:
                continue
            code, parsed, raw = raw_request("GET", "/api/v3/core/users/me/", token=token)
            last_status = code
            if code == 200:
                selected_token = token
                return
        time.sleep(interval)
    fail("api-token", f"Authentik API token did not become valid before timeout; last HTTP status {last_status}")

def urlenc(params):
    return urllib.parse.urlencode(params)

def find_named(path, name):
    parsed = api_request("GET", f"{path}?{urlenc({'search': name, 'page_size': 100})}", stage="lookup")
    for item in result_items(parsed):
        if item.get("name") == name:
            return item
    return None

def find_slugged(path, slug):
    parsed = api_request("GET", f"{path}?{urlenc({'slug': slug, 'page_size': 100})}", stage="lookup")
    for item in result_items(parsed):
        if item.get("slug") == slug:
            return item
    return None

def options_fields(path):
    code, parsed, raw = raw_request("OPTIONS", path, token=selected_token)
    if code != 200 or not isinstance(parsed, dict):
        return set()
    actions = parsed.get("actions") or {}
    post = actions.get("POST") or {}
    return set(post.keys()) if isinstance(post, dict) else set()

def get_flow_pk(slug):
    parsed = api_request("GET", f"/api/v3/flows/instances/?{urlenc({'search': slug, 'page_size': 100})}", stage="flow")
    for item in result_items(parsed):
        if item.get("slug") == slug and item.get("pk"):
            return item["pk"]
    fail("flow", f"Required Authentik flow not found: {slug}")

def ensure_group(name):
    item = find_named("/api/v3/core/groups/", name)
    body = {"name": name}
    if item and item.get("pk"):
        api_request("PATCH", f"/api/v3/core/groups/{item['pk']}/", body=body, expected=(200,), stage="group")
        return str(item["pk"])
    parsed = api_request("POST", "/api/v3/core/groups/", body=body, expected=(200, 201), stage="group")
    pk = parsed.get("pk") if isinstance(parsed, dict) else ""
    if not pk:
        fail("group", "Group response did not include pk")
    return str(pk)

def ensure_akadmin_admin(admin_group_pk):
    parsed = api_request("GET", "/api/v3/core/users/?" + urlenc({"username": "akadmin", "page_size": 100}), stage="akadmin")
    user = None
    for item in result_items(parsed):
        if item.get("username") == "akadmin":
            user = item
            break
    if not user or not user.get("pk"):
        fail("akadmin", "akadmin user was not found")
    groups = []
    for group in user.get("groups") or []:
        pk = group.get("pk") if isinstance(group, dict) else group
        if pk and str(pk) not in groups:
            groups.append(str(pk))
    if str(admin_group_pk) not in groups:
        groups.append(str(admin_group_pk))
        api_request("PATCH", f"/api/v3/core/users/{user['pk']}/", body={"groups": groups}, expected=(200,), stage="akadmin")

UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

def is_uuid(value):
    return bool(UUID_RE.match(str(value or "")))

def object_uuid(obj, stage, preferred=("pkuuid", "policy_uuid", "uuid", "pk")):
    if not isinstance(obj, dict):
        fail(stage, "Object response was not JSON object while resolving UUID")
    for key in preferred:
        value = obj.get(key)
        if is_uuid(value):
            return str(value)
    for key, value in obj.items():
        if isinstance(value, str) and is_uuid(value):
            return value
    fail(stage, "Object response did not expose a UUID target")

def object_num_pk(obj, stage):
    if not isinstance(obj, dict):
        fail(stage, "Object response was not JSON object while resolving numeric pk")
    value = obj.get("pk") or obj.get("num_pk")
    if value is None or value == "":
        fail(stage, "Object response did not include numeric pk")
    return str(value)

def binding_value(value):
    if isinstance(value, dict):
        for key in ("pkuuid", "policy_uuid", "uuid", "pk"):
            if value.get(key) is not None:
                return str(value.get(key))
    return str(value or "")

def ensure_policy(policy_name, allow_names):
    expression = (
        "allowed_groups = " + repr(allow_names) + "\n"
        "return any(group.name in allowed_groups for group in request.user.ak_groups.all())\n"
    )
    item = find_named("/api/v3/policies/expression/", policy_name)
    body = {"name": policy_name, "expression": expression}
    if item and item.get("pk"):
        updated = api_request("PATCH", f"/api/v3/policies/expression/{item['pk']}/", body=body, expected=(200,), stage="policy")
        return object_uuid(updated if isinstance(updated, dict) else item, "policy", ("pkuuid", "policy_uuid", "uuid", "pk"))
    parsed = api_request("POST", "/api/v3/policies/expression/", body=body, expected=(200, 201), stage="policy")
    return object_uuid(parsed, "policy", ("pkuuid", "policy_uuid", "uuid", "pk"))

def list_policy_bindings(policy_uuid):
    code, parsed, raw = raw_request("GET", "/api/v3/policies/bindings/?" + urlenc({"policy": policy_uuid, "page_size": 100}), token=selected_token)
    if code == 200:
        return result_items(parsed)
    parsed = api_request("GET", "/api/v3/policies/bindings/?" + urlenc({"page_size": 100}), stage="binding")
    return result_items(parsed)

def ensure_policy_binding(target_uuid, policy_uuid):
    if not is_uuid(target_uuid):
        fail("binding", "Policy binding target is not a UUID")
    if not is_uuid(policy_uuid):
        fail("binding", "Policy binding policy is not a UUID")
    binding = None
    for item in list_policy_bindings(policy_uuid):
        if binding_value(item.get("target")) == target_uuid and binding_value(item.get("policy")) == policy_uuid:
            binding = item
            break
    body = {"target": target_uuid, "policy": policy_uuid, "order": 0, "enabled": True, "negate": False, "timeout": 30}
    if binding and binding.get("pk"):
        api_request("PATCH", f"/api/v3/policies/bindings/{binding['pk']}/", body=body, expected=(200,), stage="binding")
    else:
        api_request("POST", "/api/v3/policies/bindings/", body=body, expected=(200, 201), stage="binding")

def ensure_provider(name, external_host, cookie_domain):
    auth_flow = get_flow_pk("default-authentication-flow")
    authz_flow = get_flow_pk("default-provider-authorization-implicit-consent")
    invalidation_flow = get_flow_pk("default-provider-invalidation-flow")
    item = find_named("/api/v3/providers/proxy/", name)
    fields = options_fields("/api/v3/providers/proxy/")
    body = {
        "name": name,
        "mode": "forward_domain",
        "external_host": external_host,
        "authentication_flow": auth_flow,
        "authorization_flow": authz_flow,
        "invalidation_flow": invalidation_flow,
        "basic_auth_enabled": False,
        "skip_path_regex": "",
    }
    if "cookie_domain" in fields:
        body["cookie_domain"] = cookie_domain
    if item and item.get("pk"):
        updated = api_request("PATCH", f"/api/v3/providers/proxy/{item['pk']}/", body=body, expected=(200,), stage="provider")
        return updated if isinstance(updated, dict) else item
    parsed = api_request("POST", "/api/v3/providers/proxy/", body=body, expected=(200, 201), stage="provider")
    if not isinstance(parsed, dict) or not parsed.get("pk"):
        fail("provider", "Provider response did not include pk")
    return parsed

def ensure_application(name, slug, app_url, provider_pk):
    item = find_slugged("/api/v3/core/applications/", slug)
    fields = options_fields("/api/v3/core/applications/")
    body = {"name": name, "slug": slug, "provider": provider_pk, "open_in_new_tab": False, "meta_launch_url": app_url}
    if "launch_url" in fields:
        body["launch_url"] = app_url
    if item:
        target = item.get("slug") or item.get("pk")
        code, parsed, raw = raw_request("PATCH", f"/api/v3/core/applications/{target}/", body=body, token=selected_token)
        if code != 200 and item.get("pk"):
            code, parsed, raw = raw_request("PATCH", f"/api/v3/core/applications/{item['pk']}/", body=body, token=selected_token)
        if code != 200:
            fail("application", f"PATCH application returned HTTP {code}: {sanitize(raw)}")
        return parsed if isinstance(parsed, dict) else (find_slugged("/api/v3/core/applications/", slug) or item)
    parsed = api_request("POST", "/api/v3/core/applications/", body=body, expected=(200, 201), stage="application")
    if not isinstance(parsed, dict):
        fail("application", "Application response did not include JSON object")
    return parsed

def provider_ids_from_outpost(outpost):
    ids = []
    for provider in outpost.get("providers") or []:
        pk = provider.get("pk") if isinstance(provider, dict) else provider
        if pk and str(pk) not in ids:
            ids.append(str(pk))
    return ids

def attach_provider_to_outpost(provider_pk, outpost_pk):
    if not outpost_pk:
        fail("outpost", "Script 6.3 outpost marker did not include an outpost pk")
    outpost = api_request("GET", f"/api/v3/outposts/instances/{outpost_pk}/", stage="outpost")
    providers = provider_ids_from_outpost(outpost)
    if str(provider_pk) not in providers:
        providers.append(str(provider_pk))
    api_request("PATCH", f"/api/v3/outposts/instances/{outpost_pk}/", body={"providers": providers}, expected=(200,), stage="outpost")

def configure_identity():
    slug = payload["project_slug"]
    project_name = payload["project_name"]
    group_suffixes = [
        "admins", "staff",
        "status-trial", "status-active", "status-past-due", "status-cancelled", "status-suspended", "status-deletion-requested",
        "plan-starter", "plan-growth", "plan-pro",
    ]
    group_names = {suffix: f"{slug}-{suffix}" for suffix in group_suffixes}
    group_pks = {suffix: ensure_group(name) for suffix, name in group_names.items()}
    emit("SCRIPT64_AUTHENTIK_GROUPS", "ready")
    ensure_akadmin_admin(group_pks["admins"])
    emit("SCRIPT64_AUTHENTIK_AKADMIN", group_names["admins"])
    allow_group_names = [group_names[suffix] for suffix in ("admins", "staff", "status-trial", "status-active")]
    policy_pk = ensure_policy(f"{project_name} App Access", allow_group_names)
    emit("SCRIPT64_AUTHENTIK_POLICY", "ready")
    provider_obj = ensure_provider(f"{project_name} App ForwardAuth", payload["project_auth_url"], payload["project_cookie_domain"])
    provider_pk = object_num_pk(provider_obj, "provider")
    emit("SCRIPT64_AUTHENTIK_PROVIDER", "ready")
    application_obj = ensure_application(f"{project_name} App", f"{slug}-app", payload["project_app_url"], provider_pk)
    emit("SCRIPT64_AUTHENTIK_APPLICATION", "ready")
    application_target_uuid = object_uuid(application_obj, "application", ("pkuuid", "uuid", "pk"))
    ensure_policy_binding(application_target_uuid, policy_pk)
    attach_provider_to_outpost(provider_pk, payload.get("outpost_pk") or "")
    emit("SCRIPT64_AUTHENTIK_OUTPOST", "attached")

def main():
    validate_token()
    configure_identity()
    emit("RESULT", "ok")

main()
PYCODE
}

function apply_authentik_identity_result_file() {
    local file="$1" key="" value=""
    while IFS='=' read -r key value; do
        case "$key" in
            SCRIPT64_AUTHENTIK_GROUPS) SCRIPT64_AUTHENTIK_GROUPS="$value" ;;
            SCRIPT64_AUTHENTIK_POLICY) SCRIPT64_AUTHENTIK_POLICY="$value" ;;
            SCRIPT64_AUTHENTIK_APPLICATION) SCRIPT64_AUTHENTIK_APPLICATION="$value" ;;
            SCRIPT64_AUTHENTIK_PROVIDER) SCRIPT64_AUTHENTIK_PROVIDER="$value" ;;
            SCRIPT64_AUTHENTIK_OUTPOST) SCRIPT64_AUTHENTIK_OUTPOST="$value" ;;
            SCRIPT64_AUTHENTIK_AKADMIN) SCRIPT64_AUTHENTIK_AKADMIN="$value" ;;
            ERROR_STAGE) AUTHENTIK_IDENTITY_ERROR_STAGE="$value" ;;
            ERROR_MESSAGE) AUTHENTIK_IDENTITY_ERROR_MESSAGE="$value" ;;
        esac
    done < "$file"
}

function write_authentik_identity_failure_log() {
    local reason="${1:-Authentik identity lane failed}" ts=""
    ts="$(date +%Y%m%d-%H%M%S)"
    FAILURE_LOG="/var/log/circl8-app-authentik-identity-failed-${ts}.log"
    {
        printf '%s\n' "$reason"
        printf '%s\n' "Stage: ${AUTHENTIK_IDENTITY_ERROR_STAGE:-unknown}"
        printf '%s\n' "Message: ${AUTHENTIK_IDENTITY_ERROR_MESSAGE:-unknown}"
        printf '%s\n' ""
        printf '%s\n' "Authentik server recent logs, sanitized:"
        docker_cmd logs --tail=160 authentik-server 2>&1 | sanitize_diagnostic_stream || true
    } | write_root_file "$FAILURE_LOG"
}

function fail_authentik_identity() {
    local message="$1"
    echo -ne "${BFR}"
    SCRIPT64_STATUS="authentik-identity-failed"
    SCRIPT64_VERIFY_STATUS="FAILED"
    SCRIPT64_DEPLOYMENT="completed"
    SCRIPT64_READY_FOR_DEPLOYMENT_LANE="yes"
    SCRIPT64_READY_FOR_AUTHENTIK_LANE="no"
    SCRIPT64_READY_FOR_SCRIPT65="no"
    write_authentik_identity_failure_log "$message" || true
    fail_with_report "$message"
}

function run_authentik_identity_lane() {
    section "AUTHENTIK"
    local payload="" py_code="" out_file="" err_file=""
    payload="$(build_authentik_identity_payload)"
    py_code="$(authentik_identity_python_code)"
    out_file="$(mktemp /tmp/circl8-authentik-identity-out.XXXXXX)"
    err_file="$(mktemp /tmp/circl8-authentik-identity-err.XXXXXX)"
    TEMP_FILES+=("$out_file" "$err_file")

    progress_status_line "Authentik" "configuring" "$YW"
    msg_info "Configuring derived Authentik identity objects"
    if printf '%s' "$payload" | docker_cmd exec -i authentik-server python -c "$py_code" >"$out_file" 2>"$err_file"; then
        apply_authentik_identity_result_file "$out_file"
        SCRIPT64_AUTHENTIK_LANE_RAN="yes"
        msg_ok "AUTHENTIK IDENTITY OBJECTS READY"
        progress_ready_line "Authentik" "ready"
    else
        apply_authentik_identity_result_file "$out_file" || true
        sanitize_diagnostic_stream < "$err_file" >> "${DEPLOY_OUTPUT_LOG:-/tmp/circl8-authentik-identity.err}" 2>/dev/null || true
        progress_fail_line "Authentik" "failed"
        fail_authentik_identity "Authentik identity lane failed."
    fi

    section "AUTHENTIK APPLICATION / PROVIDER"
    aligned_status_line "Application" "$SCRIPT64_AUTHENTIK_APPLICATION" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_APPLICATION")"
    aligned_status_line "Provider" "$SCRIPT64_AUTHENTIK_PROVIDER" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_PROVIDER")"
    aligned_status_line "Outpost" "$SCRIPT64_AUTHENTIK_OUTPOST" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_OUTPOST")"

    section "VERIFY AUTHENTIK IDENTITY"
    aligned_status_line "Groups" "$SCRIPT64_AUTHENTIK_GROUPS" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_GROUPS")"
    aligned_status_line "Policy" "$SCRIPT64_AUTHENTIK_POLICY" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_POLICY")"
    aligned_status_line "akadmin" "$SCRIPT64_AUTHENTIK_AKADMIN" "$GN"

    [ "$SCRIPT64_AUTHENTIK_GROUPS" = "ready" ] || fail_authentik_identity "Authentik groups were not ready."
    [ "$SCRIPT64_AUTHENTIK_POLICY" = "ready" ] || fail_authentik_identity "Authentik access policy was not ready."
    [ "$SCRIPT64_AUTHENTIK_APPLICATION" = "ready" ] || fail_authentik_identity "Authentik application was not ready."
    [ "$SCRIPT64_AUTHENTIK_PROVIDER" = "ready" ] || fail_authentik_identity "Authentik provider was not ready."
    [ "$SCRIPT64_AUTHENTIK_OUTPOST" = "attached" ] || fail_authentik_identity "Authentik outpost was not attached."
    SCRIPT64_READY_FOR_AUTHENTIK_LANE="yes"
    SCRIPT64_READY_FOR_SCRIPT65="no"
}

function verify_core_marker_or_stack() {
    local marker_status="" marker_verify="" marker_deploy="" marker_ready=""
    if [ "${SCRIPT64_RUN_MODE:-}" = "verify-only" ]; then
        verify_circl8_core
        SCRIPT64_DEPLOYMENT="completed"
        return 0
    fi
    marker_status="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_STATUS)"
    marker_verify="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_VERIFY_STATUS)"
    marker_deploy="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_DEPLOYMENT)"
    marker_ready="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_READY_FOR_AUTHENTIK_LANE)"
    if [ "$marker_status" = "completed" ] && [ "$marker_verify" = "PASS" ] && [ "$marker_deploy" = "completed" ] && [ "$marker_ready" = "yes" ]; then
        SCRIPT64_STATUS="completed"
        SCRIPT64_VERIFY_STATUS="PASS"
        SCRIPT64_DEPLOYMENT="completed"
        SCRIPT64_CIRCL8_POSTGRES="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_CIRCL8_POSTGRES)"
        SCRIPT64_CIRCL8_REDIS="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_CIRCL8_REDIS)"
        SCRIPT64_CIRCL8_TEMPORAL="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_CIRCL8_TEMPORAL)"
        SCRIPT64_CIRCL8_APP="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_CIRCL8_APP)"
        SCRIPT64_CIRCL8_INTERNAL_HTTP="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_CIRCL8_INTERNAL_HTTP)"
        SCRIPT64_CIRCL8_ROUTE="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_CIRCL8_ROUTE)"
        SCRIPT64_TEMPORAL_SEARCH_ATTRS="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_TEMPORAL_SEARCH_ATTRS)"
        SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR)"
        SCRIPT64_CIRCL8_POSTGRES="${SCRIPT64_CIRCL8_POSTGRES:-healthy}"
        SCRIPT64_CIRCL8_REDIS="${SCRIPT64_CIRCL8_REDIS:-healthy}"
        SCRIPT64_CIRCL8_TEMPORAL="${SCRIPT64_CIRCL8_TEMPORAL:-ready}"
        SCRIPT64_CIRCL8_APP="${SCRIPT64_CIRCL8_APP:-running}"
        SCRIPT64_CIRCL8_INTERNAL_HTTP="${SCRIPT64_CIRCL8_INTERNAL_HTTP:-ready}"
        SCRIPT64_CIRCL8_ROUTE="${SCRIPT64_CIRCL8_ROUTE:-protected}"
        SCRIPT64_TEMPORAL_SEARCH_ATTRS="${SCRIPT64_TEMPORAL_SEARCH_ATTRS:-ready}"
        SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR="${SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR:-not-needed}"
        aligned_status_line "Core marker" "ready" "$GN"
        return 0
    fi
    verify_circl8_core
    SCRIPT64_DEPLOYMENT="completed"
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
' "SCRIPT64_TEMPORAL_SEARCH_ATTRS=${SCRIPT64_TEMPORAL_SEARCH_ATTRS}"
        printf '%s
' "SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR=${SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR}"
        printf '%s
' "SCRIPT64_PROJECT_BASE_DOMAIN=${PROJECT_BASE_DOMAIN}"
        printf '%s
' "SCRIPT64_PROJECT_SLUG=${PROJECT_SLUG}"
        printf '%s
' "SCRIPT64_PROJECT_NAME=${PROJECT_NAME}"
        printf '%s
' "SCRIPT64_PROJECT_APP_PREFIX=${PROJECT_APP_PREFIX}"
        printf '%s
' "SCRIPT64_PROJECT_APP_HOST=${PROJECT_APP_HOST}"
        printf '%s
' "SCRIPT64_PROJECT_APP_URL=${PROJECT_APP_URL}"
        printf '%s
' "SCRIPT64_PROJECT_AUTH_PREFIX=${PROJECT_AUTH_PREFIX}"
        printf '%s
' "SCRIPT64_PROJECT_AUTH_HOST=${PROJECT_AUTH_HOST}"
        printf '%s
' "SCRIPT64_PROJECT_AUTH_URL=${PROJECT_AUTH_URL}"
        printf '%s
' "SCRIPT64_PROJECT_COOKIE_DOMAIN=${PROJECT_COOKIE_DOMAIN}"
        printf '%s
' "SCRIPT64_AUTHENTIK_GROUPS=${SCRIPT64_AUTHENTIK_GROUPS}"
        printf '%s
' "SCRIPT64_AUTHENTIK_POLICY=${SCRIPT64_AUTHENTIK_POLICY}"
        printf '%s
' "SCRIPT64_AUTHENTIK_APPLICATION=${SCRIPT64_AUTHENTIK_APPLICATION}"
        printf '%s
' "SCRIPT64_AUTHENTIK_PROVIDER=${SCRIPT64_AUTHENTIK_PROVIDER}"
        printf '%s
' "SCRIPT64_AUTHENTIK_OUTPOST=${SCRIPT64_AUTHENTIK_OUTPOST}"
        printf '%s
' "SCRIPT64_AUTHENTIK_AKADMIN=${SCRIPT64_AUTHENTIK_AKADMIN}"
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
    case "${SCRIPT64_STATUS:-}" in
        deploy-failed)
            SCRIPT64_READY_FOR_DEPLOYMENT_LANE="no"
            ;;
        authentik-identity-failed)
            SCRIPT64_DEPLOYMENT="completed"
            SCRIPT64_READY_FOR_DEPLOYMENT_LANE="yes"
            ;;
        *)
            SCRIPT64_STATUS="template-preflight-failed"
            SCRIPT64_READY_FOR_DEPLOYMENT_LANE="no"
            ;;
    esac
    SCRIPT64_VERIFY_STATUS="FAILED"
    SCRIPT64_READY_FOR_AUTHENTIK_LANE="no"
    SCRIPT64_READY_FOR_SCRIPT65="no"
    write_verify_report || true
    echo -ne "${BFR}"
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

function existing_deployment_marker_completed() {
    local marker_status="" marker_verify="" marker_deploy=""
    marker_status="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_STATUS)"
    marker_verify="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_VERIFY_STATUS)"
    marker_deploy="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_DEPLOYMENT)"
    [ "$marker_status" = "completed" ] && [ "$marker_verify" = "PASS" ] && [ "$marker_deploy" = "completed" ]
}

function preserve_existing_authentik_marker_values() {
    local value=""
    if ! existing_deployment_marker_completed; then
        return 0
    fi
    value="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_AUTHENTIK_GROUPS)"
    [ "$SCRIPT64_AUTHENTIK_GROUPS" = "not-run" ] && [ -n "$value" ] && SCRIPT64_AUTHENTIK_GROUPS="$value"
    value="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_AUTHENTIK_POLICY)"
    [ "$SCRIPT64_AUTHENTIK_POLICY" = "not-run" ] && [ -n "$value" ] && SCRIPT64_AUTHENTIK_POLICY="$value"
    value="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_AUTHENTIK_APPLICATION)"
    [ "$SCRIPT64_AUTHENTIK_APPLICATION" = "not-run" ] && [ -n "$value" ] && SCRIPT64_AUTHENTIK_APPLICATION="$value"
    value="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_AUTHENTIK_PROVIDER)"
    [ "$SCRIPT64_AUTHENTIK_PROVIDER" = "not-run" ] && [ -n "$value" ] && SCRIPT64_AUTHENTIK_PROVIDER="$value"
    value="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_AUTHENTIK_OUTPOST)"
    [ "$SCRIPT64_AUTHENTIK_OUTPOST" = "not-run" ] && [ -n "$value" ] && SCRIPT64_AUTHENTIK_OUTPOST="$value"
    value="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_AUTHENTIK_AKADMIN)"
    [ "$SCRIPT64_AUTHENTIK_AKADMIN" = "not-run" ] && [ -n "$value" ] && SCRIPT64_AUTHENTIK_AKADMIN="$value"
    value="$(marker_file_key_value "$DEPLOYED_MARKER" SCRIPT64_READY_FOR_AUTHENTIK_LANE)"
    [ "$SCRIPT64_READY_FOR_AUTHENTIK_LANE" = "no" ] && [ "$value" = "yes" ] && SCRIPT64_READY_FOR_AUTHENTIK_LANE="yes"
    if [ "$SCRIPT64_AUTHENTIK_GROUPS" = "ready" ]         && [ "$SCRIPT64_AUTHENTIK_POLICY" = "ready" ]         && [ "$SCRIPT64_AUTHENTIK_APPLICATION" = "ready" ]         && [ "$SCRIPT64_AUTHENTIK_PROVIDER" = "ready" ]         && [ "$SCRIPT64_AUTHENTIK_OUTPOST" = "attached" ]; then
        SCRIPT64_READY_FOR_AUTHENTIK_LANE="yes"
    fi
}

function write_deployment_marker() {
    local tmp_file=""
    if [ "$SCRIPT64_AUTHENTIK_LANE_RAN" != "yes" ]; then
        preserve_existing_authentik_marker_values
    fi
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
' "SCRIPT64_TEMPORAL_SEARCH_ATTRS=${SCRIPT64_TEMPORAL_SEARCH_ATTRS}"
        printf '%s
' "SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR=${SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR}"
        printf '%s
' "SCRIPT64_PROJECT_BASE_DOMAIN=${PROJECT_BASE_DOMAIN}"
        printf '%s
' "SCRIPT64_PROJECT_SLUG=${PROJECT_SLUG}"
        printf '%s
' "SCRIPT64_PROJECT_NAME=${PROJECT_NAME}"
        printf '%s
' "SCRIPT64_PROJECT_APP_PREFIX=${PROJECT_APP_PREFIX}"
        printf '%s
' "SCRIPT64_PROJECT_APP_HOST=${PROJECT_APP_HOST}"
        printf '%s
' "SCRIPT64_PROJECT_APP_URL=${PROJECT_APP_URL}"
        printf '%s
' "SCRIPT64_PROJECT_AUTH_PREFIX=${PROJECT_AUTH_PREFIX}"
        printf '%s
' "SCRIPT64_PROJECT_AUTH_HOST=${PROJECT_AUTH_HOST}"
        printf '%s
' "SCRIPT64_PROJECT_AUTH_URL=${PROJECT_AUTH_URL}"
        printf '%s
' "SCRIPT64_PROJECT_COOKIE_DOMAIN=${PROJECT_COOKIE_DOMAIN}"
        printf '%s
' "SCRIPT64_AUTHENTIK_GROUPS=${SCRIPT64_AUTHENTIK_GROUPS}"
        printf '%s
' "SCRIPT64_AUTHENTIK_POLICY=${SCRIPT64_AUTHENTIK_POLICY}"
        printf '%s
' "SCRIPT64_AUTHENTIK_APPLICATION=${SCRIPT64_AUTHENTIK_APPLICATION}"
        printf '%s
' "SCRIPT64_AUTHENTIK_PROVIDER=${SCRIPT64_AUTHENTIK_PROVIDER}"
        printf '%s
' "SCRIPT64_AUTHENTIK_OUTPOST=${SCRIPT64_AUTHENTIK_OUTPOST}"
        printf '%s
' "SCRIPT64_AUTHENTIK_AKADMIN=${SCRIPT64_AUTHENTIK_AKADMIN}"
        printf '%s
' "SCRIPT64_READY_FOR_AUTHENTIK_LANE=${SCRIPT64_READY_FOR_AUTHENTIK_LANE}"
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

function env_display_label_for_key() {
    local key="$1"
    case "$key" in
        CIRCL8_HOST) printf 'Host' ;;
        CIRCL8_URL) printf 'URL' ;;
        CIRCL8_IMAGE) printf 'App image' ;;
        CIRCL8_REDIS_IMAGE) printf 'Redis image' ;;
        CIRCL8_TEMPORAL_IMAGE) printf 'Temporal image' ;;
        CIRCL8_POSTGRES_SUPERUSER_PASSWORD) printf 'Postgres superuser secret' ;;
        CIRCL8_APP_POSTGRES_PASSWORD) printf 'App DB secret' ;;
        CIRCL8_TEMPORAL_POSTGRES_PASSWORD) printf 'Temporal DB secret' ;;
        CIRCL8_JWT_SECRET) printf 'JWT secret' ;;
        CIRCL8_NEXTAUTH_SECRET) printf 'NextAuth secret' ;;
        CIRCL8_SECRET_KEY) printf 'App secret' ;;
        CIRCL8_MEDIA_RETENTION_MODE) printf 'Media mode' ;;
        CIRCL8_MEDIA_RETRY_RETENTION_HOURS) printf 'Retry retention' ;;
        CIRCL8_MEDIA_DRAFT_RETENTION_DAYS) printf 'Draft retention' ;;
        CIRCL8_API_LIMIT) printf 'API limit' ;;
        *) printf '%s' "$key" ;;
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
    local key="" label="" value="" tmp_append="" backup_path="" ts=""

    tmp_append="$(mktemp /tmp/circl8-app-env-append.XXXXXX)"
    TEMP_FILES+=("$tmp_append")
    : > "$tmp_append"

    mini_header "Keys"
    for key in "${keys[@]}"; do
        label="$(env_display_label_for_key "$key")"
        if env_has_nonempty_value "$key"; then
            aligned_status_line "$label" "preserved" "$GN"
        else
            value="$(env_default_for_key "$key")"
            append_env_line "$key" "$value" >> "$tmp_append"
            SCRIPT64_ENV_KEYS_ADDED=$((SCRIPT64_ENV_KEYS_ADDED + 1))
            aligned_status_line "$label" "added" "$ANS"
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
    aligned_status_line "Project" "${PROJECT_NAME:-${PROJECT_SLUG:-circl8}}" "$GN"
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
    mini_header "Images"
    progress_status_line "Images" "checking" "$YW"
    mini_header "Compose"
    progress_status_line "Compose" "applying" "$YW"
    if docker_cmd compose --env-file "$ENV_FILE" -p circl8 -f "$CIRCL8_COMPOSE_FILE" up -d >> "$DEPLOY_OUTPUT_LOG" 2>&1; then
        progress_ready_line "Images" "ready"
        progress_ready_line "Compose" "ready"
    else
        progress_fail_line "Compose" "failed"
        SCRIPT64_DEPLOYMENT="failed"
        fail_deployment "Circl8 core compose deployment failed."
    fi
}

function verify_circl8_core() {
    section "VERIFY CIRCL8"
    mini_header "Containers"
    progress_status_line "Containers" "waiting" "$YW"

    msg_info "Waiting for circl8-postgres"
    if wait_for_container_status circl8-postgres healthy 240; then
        SCRIPT64_CIRCL8_POSTGRES="healthy"
        msg_ok "circl8-postgres healthy"
    else
        SCRIPT64_CIRCL8_POSTGRES="failed"
        progress_fail_line "Containers" "failed"
        fail_deployment "circl8-postgres did not become healthy."
    fi

    msg_info "Waiting for circl8-redis"
    if wait_for_container_status circl8-redis healthy-or-running 120; then
        SCRIPT64_CIRCL8_REDIS="healthy"
        msg_ok "circl8-redis ready"
    else
        SCRIPT64_CIRCL8_REDIS="failed"
        progress_fail_line "Containers" "failed"
        fail_deployment "circl8-redis did not become ready."
    fi

    msg_info "Waiting for circl8-temporal"
    if wait_for_container_status circl8-temporal healthy-or-running 300 && wait_for_temporal_api 240; then
        SCRIPT64_CIRCL8_TEMPORAL="ready"
        msg_ok "circl8-temporal ready"
    else
        SCRIPT64_CIRCL8_TEMPORAL="failed"
        progress_fail_line "Containers" "failed"
        fail_deployment "circl8-temporal API did not become ready."
    fi

    mini_header "Temporal"
    progress_status_line "Search attributes" "checking" "$YW"
    msg_info "Checking Temporal search attributes"
    if [ "${SCRIPT64_RUN_MODE:-}" = "verify-only" ]; then
        if verify_temporal_search_attribute_guard_readonly; then
            msg_ok "Temporal search attributes ready"
            aligned_status_line "Temporal search attributes" "ready" "$GN"
            aligned_status_line "Temporal repair" "not needed" "$GN"
        else
            progress_fail_line "Search attributes" "failed"
            fail_deployment "Temporal sample Text search attributes are present; run deploy/redeploy to repair them."
        fi
    else
        set +e
        run_temporal_search_attribute_guard
        local temporal_guard_rc="$?"
        set -e
        if [ "$temporal_guard_rc" = "0" ]; then
            msg_ok "Temporal search attributes ready"
            aligned_status_line "Temporal search attributes" "ready" "$GN"
            aligned_status_line "Temporal repair" "not needed" "$GN"
        elif [ "$temporal_guard_rc" = "2" ]; then
            msg_ok "Temporal search attributes repaired"
            aligned_status_line "Temporal search attributes" "repaired" "$GN"
            msg_info "Restarting circl8 app after Temporal repair"
            if docker_cmd restart circl8 >> "${DEPLOY_OUTPUT_LOG:-/tmp/circl8-app-deploy.log}" 2>&1; then
                msg_ok "circl8 app restarted"
            else
                fail_deployment "Temporal search attributes were repaired but circl8 app restart failed."
            fi
        else
            progress_fail_line "Search attributes" "failed"
            fail_deployment "Temporal search attribute guard failed."
        fi
    fi

    msg_info "Waiting for circl8 app"
    if wait_for_container_status circl8 healthy-or-running 300; then
        SCRIPT64_CIRCL8_APP="running"
        msg_ok "circl8 app running"
        progress_ready_line "Containers" "ready"
    else
        SCRIPT64_CIRCL8_APP="failed"
        progress_fail_line "Containers" "failed"
        fail_deployment "circl8 app container did not become ready."
    fi

    mini_header "Services"
    progress_status_line "Services" "waiting" "$YW"
    msg_info "Checking internal app HTTP"
    if wait_for_circl8_internal_http 240; then
        SCRIPT64_CIRCL8_INTERNAL_HTTP="ready"
        msg_ok "Internal HTTP/API ready"
        progress_ready_line "Services" "ready"
    else
        SCRIPT64_CIRCL8_INTERNAL_HTTP="failed"
        progress_fail_line "Services" "failed"
        fail_deployment "Circl8 frontend/backend/nginx API verification failed."
    fi

    mini_header "Route"
    progress_status_line "Route" "checking" "$YW"
    msg_info "Checking protected public route"
    if verify_public_route_behavior; then
        SCRIPT64_CIRCL8_ROUTE="protected"
        msg_ok "Circl8 route protected"
        progress_ready_line "Route" "protected"
    else
        local route_result="$?"
        if [ "$route_result" = "2" ]; then
            SCRIPT64_CIRCL8_ROUTE="failed"
            progress_fail_line "Route" "failed"
            fail_deployment "Circl8 Traefik labels are missing or invalid."
        fi
        if [ "$route_result" = "3" ]; then
            SCRIPT64_CIRCL8_ROUTE="failed"
            progress_fail_line "Route" "failed"
            fail_deployment "Circl8 public route responded without expected protected behavior."
        fi
        if check_traefik_infra_errors; then
            SCRIPT64_CIRCL8_ROUTE="needs-review"
            msg_warn "Circl8 public route needs review; internal app is ready and no Traefik infrastructure error was detected."
            progress_status_line "Route" "needs-review" "$YW"
        else
            SCRIPT64_CIRCL8_ROUTE="failed"
            progress_fail_line "Route" "failed"
            fail_deployment "Traefik reported Circl8 route infrastructure errors."
        fi
    fi
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
    final_line "Temporal search attributes" "$SCRIPT64_TEMPORAL_SEARCH_ATTRS" "$(status_color_for_value "$SCRIPT64_TEMPORAL_SEARCH_ATTRS")"
    final_line "Temporal repair" "$SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR" "$(status_color_for_value "$SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR")"
    final_line "Circl8 app" "$SCRIPT64_CIRCL8_APP" "$(status_color_for_value "$SCRIPT64_CIRCL8_APP")"
    final_line "Internal HTTP" "$SCRIPT64_CIRCL8_INTERNAL_HTTP" "$(status_color_for_value "$SCRIPT64_CIRCL8_INTERNAL_HTTP")"
    final_line "Public route" "$SCRIPT64_CIRCL8_ROUTE" "$(status_color_for_value "$SCRIPT64_CIRCL8_ROUTE")"
    final_line "Project slug" "$PROJECT_SLUG" "$GN"
    final_line "App host" "$PROJECT_APP_HOST" "$GN"
    final_line "Authentik host" "$PROJECT_AUTH_HOST" "$GN"
    final_line "Groups" "$SCRIPT64_AUTHENTIK_GROUPS" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_GROUPS")"
    final_line "Policy" "$SCRIPT64_AUTHENTIK_POLICY" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_POLICY")"
    final_line "Application" "$SCRIPT64_AUTHENTIK_APPLICATION" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_APPLICATION")"
    final_line "Provider" "$SCRIPT64_AUTHENTIK_PROVIDER" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_PROVIDER")"
    final_line "Outpost" "$SCRIPT64_AUTHENTIK_OUTPOST" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_OUTPOST")"
    final_line "akadmin" "$SCRIPT64_AUTHENTIK_AKADMIN" "$GN"
    final_line "Ready for Authentik lane" "$SCRIPT64_READY_FOR_AUTHENTIK_LANE" "$GN"
    final_line "Ready for Script 6.5" "$SCRIPT64_READY_FOR_SCRIPT65" "$YW"
    final_line "Verify log" "$VERIFY_LOG" "$BL"
    final_line "Template marker" "$COMPLETED_MARKER" "$BL"
    final_line "Deploy marker" "$DEPLOYED_MARKER" "$BL"
}

function finish_render_only_success() {
    SCRIPT64_STATUS="render-only-completed"
    SCRIPT64_VERIFY_STATUS="PASS"
    SCRIPT64_READY_FOR_DEPLOYMENT_LANE="yes"
    SCRIPT64_READY_FOR_SCRIPT65="no"
    if existing_deployment_marker_completed; then
        SCRIPT64_EXISTING_DEPLOYMENT_STATE="preserved"
        SCRIPT64_DEPLOYMENT="completed"
        SCRIPT64_DEPLOYMENT_MARKER_WRITTEN="no"
        preserve_existing_authentik_marker_values
    else
        SCRIPT64_EXISTING_DEPLOYMENT_STATE="not-present"
        SCRIPT64_DEPLOYMENT="not-run"
        SCRIPT64_READY_FOR_AUTHENTIK_LANE="no"
    fi
    write_verify_report

    section_flash_success "FINISHED"
    mini_header "Circl8"
    final_line "Status" "$SCRIPT64_STATUS" "$GN"
    final_line "Verification" "$SCRIPT64_VERIFY_STATUS" "$GN"
    final_line "Deployment" "$SCRIPT64_DEPLOYMENT" "$(status_color_for_value "$SCRIPT64_DEPLOYMENT")"
    final_line "Existing deploy" "$SCRIPT64_EXISTING_DEPLOYMENT_STATE" "$(status_color_for_value "$SCRIPT64_EXISTING_DEPLOYMENT_STATE")"
    final_line "Compose config" "$SCRIPT64_CIRCL8_COMPOSE_CONFIG" "$GN"
    final_line "Static safety" "$SCRIPT64_CIRCL8_STATIC_SAFETY" "$GN"
    final_line "Ready for Script 6.5" "$SCRIPT64_READY_FOR_SCRIPT65" "$YW"
    final_line "Verify log" "$VERIFY_LOG" "$BL"
    final_line "Deploy marker" "$DEPLOYED_MARKER" "$BL"
}

function finish_verify_only_success() {
    SCRIPT64_STATUS="verify-only-completed"
    SCRIPT64_VERIFY_STATUS="PASS"
    SCRIPT64_DEPLOYMENT="completed"
    SCRIPT64_READY_FOR_DEPLOYMENT_LANE="yes"
    SCRIPT64_READY_FOR_SCRIPT65="no"
    preserve_existing_authentik_marker_values
    write_verify_report

    section_flash_success "FINISHED"
    mini_header "Circl8"
    final_line "Status" "$SCRIPT64_STATUS" "$GN"
    final_line "Verification" "$SCRIPT64_VERIFY_STATUS" "$GN"
    final_line "Deployment" "$SCRIPT64_DEPLOYMENT" "$GN"
    final_line "PostgreSQL" "$SCRIPT64_CIRCL8_POSTGRES" "$(status_color_for_value "$SCRIPT64_CIRCL8_POSTGRES")"
    final_line "Redis" "$SCRIPT64_CIRCL8_REDIS" "$(status_color_for_value "$SCRIPT64_CIRCL8_REDIS")"
    final_line "Temporal" "$SCRIPT64_CIRCL8_TEMPORAL" "$(status_color_for_value "$SCRIPT64_CIRCL8_TEMPORAL")"
    final_line "Temporal search attributes" "$SCRIPT64_TEMPORAL_SEARCH_ATTRS" "$(status_color_for_value "$SCRIPT64_TEMPORAL_SEARCH_ATTRS")"
    final_line "Temporal repair" "$SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR" "$(status_color_for_value "$SCRIPT64_TEMPORAL_SEARCH_ATTR_REPAIR")"
    final_line "App" "$SCRIPT64_CIRCL8_APP" "$(status_color_for_value "$SCRIPT64_CIRCL8_APP")"
    final_line "Internal HTTP" "$SCRIPT64_CIRCL8_INTERNAL_HTTP" "$(status_color_for_value "$SCRIPT64_CIRCL8_INTERNAL_HTTP")"
    final_line "Public route" "$SCRIPT64_CIRCL8_ROUTE" "$(status_color_for_value "$SCRIPT64_CIRCL8_ROUTE")"
    final_line "Groups" "$SCRIPT64_AUTHENTIK_GROUPS" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_GROUPS")"
    final_line "Policy" "$SCRIPT64_AUTHENTIK_POLICY" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_POLICY")"
    final_line "Application" "$SCRIPT64_AUTHENTIK_APPLICATION" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_APPLICATION")"
    final_line "Provider" "$SCRIPT64_AUTHENTIK_PROVIDER" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_PROVIDER")"
    final_line "Outpost" "$SCRIPT64_AUTHENTIK_OUTPOST" "$(status_color_for_value "$SCRIPT64_AUTHENTIK_OUTPOST")"
    final_line "akadmin" "$SCRIPT64_AUTHENTIK_AKADMIN" "$GN"
    final_line "Ready for Script 6.5" "$SCRIPT64_READY_FOR_SCRIPT65" "$YW"
    final_line "Verify log" "$VERIFY_LOG" "$BL"
    final_line "Deploy marker" "$DEPLOYED_MARKER" "$BL"
}

function finish_clean_exit() {
    section_flash_success "FINISHED"
    mini_header "Circl8"
    final_line "Status" "exit" "$GN"
    final_line "Action" "no changes requested" "$YW"
    final_line "Markers" "unchanged" "$GN"
}

function run_circl8_core_only_success_path() {
    write_template_preflight_success
    deploy_circl8_core
    verify_circl8_core
    finish_deployment_success
}

function run_circl8_deploy_success_path() {
    write_template_preflight_success
    deploy_circl8_core
    verify_circl8_core
    run_authentik_identity_lane
    finish_deployment_success
}

function rerun_menu_available() {
    [ "$SCRIPT64_RUN_MODE" = "prompt" ] || return 1
    [ -r /dev/tty ] || return 1
    existing_deployment_marker_completed
}

function numeric_menu_input() {
    local prompt="$1" default="$2" min_choice="$3" max_choice="$4" raw_choice="" choice=""
    while true; do
        flush_input_buffer 2>/dev/null || true
        tty_print "${YW}${prompt} [default: ${default}]: ${CL}"
        IFS= read -r raw_choice < /dev/tty || raw_choice=""
        tty_print "${BFR}"
        raw_choice="${raw_choice//$'\r'/}"
        raw_choice="${raw_choice//$'\n'/}"
        raw_choice="$(printf '%s' "$raw_choice" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        [ -n "$raw_choice" ] || raw_choice="$default"
        choice="$(printf '%s' "$raw_choice" | tr -cd '0-9')"
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge "$min_choice" ] && [ "$choice" -le "$max_choice" ]; then
            printf '%s' "$choice"
            return 0
        fi
        tty_println "${WARN} ${YW}Invalid selection. Choose ${min_choice}-${max_choice}.${CL}"
    done
}

function show_rerun_menu() {
    local choice=""
    section "SCRIPT 6.4 RERUN OPTIONS"
    aligned_status_line "Existing deployment" "completed" "$GN"
    aligned_status_line "Project" "${PROJECT_NAME:-${PROJECT_SLUG:-circl8}}" "$GN"
    echo ""
    echo -e "  ${YW}1)${CL} Verify current Circl8 deployment"
    echo -e "  ${YW}2)${CL} Re-render templates/config only"
    echo -e "  ${YW}3)${CL} Deploy/redeploy core stack"
    echo -e "  ${YW}4)${CL} Run Authentik identity lane only"
    echo -e "  ${YW}5)${CL} Run full core deploy + Authentik identity lane"
    echo -e "  ${YW}6)${CL} Exit"
    echo ""
    choice="$(numeric_menu_input "Select action" "1" "1" "6")"
    echo ""
    case "$choice" in
        1) SCRIPT64_RUN_MODE="verify-only"; msg_ok "Verify current Circl8 deployment selected" ;;
        2) SCRIPT64_RUN_MODE="render-only"; msg_ok "Re-render templates/config only selected" ;;
        3) SCRIPT64_RUN_MODE="deploy-core"; msg_ok "Deploy/redeploy core stack selected" ;;
        4) SCRIPT64_RUN_MODE="authentik-only"; msg_ok "Authentik identity lane only selected" ;;
        5) SCRIPT64_RUN_MODE="deploy"; msg_ok "Full core deploy + Authentik identity lane selected" ;;
        6) SCRIPT64_RUN_MODE="exit"; msg_ok "Exit selected" ;;
    esac
}

function run_deploy_decision_or_mode() {
    if rerun_menu_available; then
        show_rerun_menu
    fi

    case "$SCRIPT64_RUN_MODE" in
        preflight-only)
            section "DEPLOY CIRCL8"
            mini_header "Mode"
            aligned_status_line "Run mode" "preflight-only" "$YW"
            aligned_status_line "Deployment" "not-run" "$GN"
            msg_warn "Preflight-only mode selected; Circl8 deployment skipped."
            finish_preflight_only_success
            ;;
        render-only)
            section "DEPLOY CIRCL8"
            mini_header "Mode"
            aligned_status_line "Run mode" "render-only" "$YW"
            aligned_status_line "Deployment" "not changed" "$GN"
            finish_render_only_success
            ;;
        verify-only)
            section "DEPLOY CIRCL8"
            mini_header "Mode"
            aligned_status_line "Run mode" "verify-only" "$GN"
            aligned_status_line "Deploy action" "not-run" "$GN"
            verify_core_marker_or_stack
            finish_verify_only_success
            ;;
        deploy-core)
            section "DEPLOY CIRCL8"
            mini_header "Mode"
            aligned_status_line "Run mode" "deploy-core" "$GN"
            aligned_status_line "Authentik API writes" "not-run" "$GN"
            run_circl8_core_only_success_path
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
        authentik-only)
            section "DEPLOY CIRCL8"
            mini_header "Mode"
            aligned_status_line "Run mode" "authentik-only" "$GN"
            aligned_status_line "Core deploy action" "not-run" "$GN"
            write_template_preflight_success
            verify_core_marker_or_stack
            run_authentik_identity_lane
            finish_deployment_success
            ;;
        exit)
            finish_clean_exit
            exit 0
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
    run_deploy_decision_or_mode
}

function main() {
    parse_args "$@"
    init_script
    validate_script63_gate
    runtime_preflight
    derive_project_identity
    ensure_circl8_env_keys
    prepare_circl8_directories
    download_and_render_templates
    require_static_safety
    validate_compose_config
    run_post_compose_flow
}

main "$@"
