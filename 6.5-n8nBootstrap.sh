#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Project Circl8 - Script 6.5 n8n Bootstrap
# =========================================================
# Phase 2: template/preflight only. This script prepares the n8n
# foundation contract, validates the rendered compose file, and writes
# a preflight marker. It does not deploy containers or write Authentik/n8n APIs.

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

SCRIPT_SOURCE="6.5-n8nBootstrap.sh"
SCRIPT_VERSION="v1.0.0"
SCRIPT_UPDATED="2026-06-18"
SCRIPT_BUILD="n8n-template-preflight-fresh"

T="15"
UI_LABEL_WIDTH="34"

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
RAW_BASE_FALLBACK="https://raw.githubusercontent.com/Orik999/circl8/refs/heads/main"

SUDO_CMD=""
RUNTIME_LOG_FILE=""
SCRIPT_DIR=""
TEMP_FILES=()
TEMP_DIRS=()
PROGRESS_LINE_ACTIVE="no"

SCRIPT61_STATUS="unknown"
SCRIPT61_VERIFY_STATUS="unknown"
SCRIPT63_STATUS="unknown"
SCRIPT63_VERIFY_STATUS="unknown"
SCRIPT63_FORWARD_AUTH="unknown"
SCRIPT63_TRAEFIK_FORWARD_AUTH="unknown"
SCRIPT64_STATUS="unknown"
SCRIPT64_VERIFY_STATUS="unknown"
SCRIPT64_READY_FOR_SCRIPT65="unknown"

DOCKER_DIR=""
COMPOSE_DIR=""
ENV_FILE=""
RAW_BASE_DEFAULT=""
DOMAIN_VALUE=""
PROJECT_SLUG=""
PROJECT_NAME=""
N8N_HOST=""
N8N_URL=""
N8N_WEBHOOK_URL=""
N8N_APPDATA_DIR=""
N8N_POSTGRES_DIR=""
N8N_REDIS_DIR=""
N8N_STORAGE_DIR=""
N8N_COMPOSE_FILE=""
N8N_DOCKGE_COMPOSE_FILE=""
N8N_TEMPLATE_URL=""

SCRIPT65_STATUS="template-preflight-pending"
SCRIPT65_VERIFY_STATUS="PENDING"
SCRIPT65_DEPLOYMENT="not-run"
SCRIPT65_MARKER_WRITTEN="no"
SCRIPT65_HANDOFF_GATES="not-run"
SCRIPT65_ENV_STATUS="not-run"
SCRIPT65_ENV_BACKUP="not-needed"
SCRIPT65_ENV_KEYS_ADDED="0"
SCRIPT65_N8N_APPDATA="not-run"
SCRIPT65_N8N_POSTGRES_DATA="not-run"
SCRIPT65_N8N_REDIS_DATA="not-run"
SCRIPT65_N8N_STORAGE="not-run"
SCRIPT65_N8N_COMPOSE_TEMPLATE="not-run"
SCRIPT65_N8N_COMPOSE_CONFIG="not-run"
SCRIPT65_N8N_STATIC_SAFETY="not-run"
SCRIPT65_READY_FOR_DEPLOYMENT_LANE="no"
SCRIPT65_READY_FOR_WORKFLOW_LANE="no"
SCRIPT65_READY_FOR_SCRIPT66="no"

# =========================================================
#  ROOT / SUDO HANDOFF
# =========================================================
function early_error() {
    echo -e "${CROSS} ${RD}$1${CL}" >&2
    exit 1
}

function elevate_to_root_if_needed() {
    if [ "${EUID}" -eq 0 ]; then
        return 0
    fi

    command -v sudo >/dev/null 2>&1 || early_error "Root privileges are required. Install sudo or re-run as root."

    # Script 6-family VM installs use NOPASSWD sudo. Validate that path only;
    # never call sudo in a way that can prompt during streamed/process-substitution runs.
    if ! sudo -n true >/dev/null 2>&1; then
        early_error "Passwordless sudo is required for this remote bootstrap. Configure NOPASSWD sudo or re-run as root."
    fi

    local script_path="${BASH_SOURCE[0]}"
    local handoff_script=""

    case "$script_path" in
        /dev/fd/*|/proc/*/fd/*)
            handoff_script="$(mktemp /tmp/circl8-n8n-sudo-handoff.XXXXXX.sh)" || early_error "Could not prepare sudo handoff script."
            cat "$script_path" > "$handoff_script" || { rm -f "$handoff_script" 2>/dev/null || true; early_error "Could not copy script for sudo handoff."; }
            chmod 700 "$handoff_script" 2>/dev/null || true
            exec sudo -n -E bash -c 'script="$1"; shift; trap '\''rm -f "$script"'\'' EXIT; bash "$script" "$@"' bash "$handoff_script" "$@"
            ;;
        *)
            exec sudo -n -E bash "$script_path" "$@"
            ;;
    esac
}

# =========================================================
#  UI HELPERS
# =========================================================
function header_info() {
cat <<'BANNER'

   ██████╗    ███████╗       ███╗   ██╗ █████╗ ███╗   ██╗
  ██╔════╝    ██╔════╝       ████╗  ██║██╔══██╗████╗  ██║
  ███████╗    ███████╗       ██╔██╗ ██║╚█████╔╝██╔██╗ ██║
  ██╔═══██╗   ╚════██║       ██║╚██╗██║██╔══██╗██║╚██╗██║
  ╚██████╔╝██╗███████║       ██║ ╚████║╚█████╔╝██║ ╚████║
   ╚═════╝ ╚═╝╚══════╝       ╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═══╝

                              6.5 n8n
BANNER
}

function show_script_version() {
    echo -e "${GN}SCRIPT VERSION: ${SCRIPT_VERSION} | UPDATED: ${SCRIPT_UPDATED} | BUILD: ${SCRIPT_BUILD}${CL}"
    echo -e "${BL}SOURCE: ${SCRIPT_SOURCE}${CL}"
}

function section() { echo ""; echo -e "${BORDER}"; echo -e "${BL}$1${CL}"; echo -e "${BORDER}"; }
function section_flash_success() { echo ""; echo -e "${BORDER}"; echo -e "${GN}${CLF}$1${CL}"; echo -e "${BORDER}"; }
function mini_header() { echo ""; echo -e "${YW}$1:${CL}"; }
function clear_progress_line() { [ "${PROGRESS_LINE_ACTIVE:-no}" = "yes" ] && printf '%b' "${BFR}" && PROGRESS_LINE_ACTIVE="no" || true; }
function msg_info() { PROGRESS_LINE_ACTIVE="yes"; echo -ne " ${HOLD} ${YW}$1...${CL}"; }
function msg_ok() { echo -e "${BFR} ${CM} ${GN}$1${CL}"; PROGRESS_LINE_ACTIVE="no"; }
function msg_warn() { echo -e "${BFR} ${WARN} ${YW}$1${CL}"; PROGRESS_LINE_ACTIVE="no"; }
function msg_error() { echo -e "${BFR} ${CROSS} ${RD}$1${CL}"; exit 1; }

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

function status_color_for_value() {
    local value="${1:-unknown}"
    case "$value" in
        PASS|pass|completed|present|ready|yes|valid|downloaded|rendered|synced|created|preserved|healthy|running|protected|not-needed|template-preflight-completed|not-run|not\ run) printf '%s' "$GN" ;;
        PENDING|pending|unknown|skipped|needs-review|will-create|not-selected) printf '%s' "$YW" ;;
        FAIL|FAILED|failed|missing|no|invalid|blocked|unsafe) printf '%s' "$RD" ;;
        *) printf '%s' "$GN" ;;
    esac
}

function aligned_status_line() {
    local label="$1" value="${2:-unknown}" color="${3:-}" width="${4:-$UI_LABEL_WIDTH}" display_value=""
    [ -n "$value" ] || value="unknown"
    [ -n "$color" ] || color="$(status_color_for_value "$value")"
    display_value="$(ui_display_value "$value")"
    printf '  %b%-*s%b %b%s%b\n' "$BL" "$width" "${label}:" "$CL" "$color" "$display_value" "$CL"
}

function final_line() { aligned_status_line "$1" "${2:-unknown}" "${3:-}" "$UI_LABEL_WIDTH"; }

# =========================================================
#  LOGGING / CLEANUP
# =========================================================
function detect_root_or_sudo() { if [ "${EUID}" -eq 0 ]; then SUDO_CMD=""; else SUDO_CMD="sudo -n"; fi; }

function init_logging() {
    RUNTIME_LOG_FILE="$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
}

function cleanup() {
    local exit_code="$?" file="" dir=""
    clear_progress_line || true
    for file in "${TEMP_FILES[@]:-}"; do [ -n "$file" ] && [ -f "$file" ] && rm -f "$file" 2>/dev/null || true; done
    for dir in "${TEMP_DIRS[@]:-}"; do [ -n "$dir" ] && [ -d "$dir" ] && rm -rf "$dir" 2>/dev/null || true; done
    exit "$exit_code"
}

function on_error() {
    local line_no="$1"
    clear_progress_line || true
    SCRIPT65_STATUS="template-preflight-failed"
    SCRIPT65_VERIFY_STATUS="FAILED"
    SCRIPT65_READY_FOR_DEPLOYMENT_LANE="no"
    write_verify_report || true
    echo -e "${RD}ERROR:${CL} Script failed at line ${line_no}. Check ${LOG_FILE}"
    echo -e "  ${BL}Verify log:${CL} ${VERIFY_LOG}"
}

function fail_with_report() {
    local message="$1"
    clear_progress_line || true
    SCRIPT65_STATUS="template-preflight-failed"
    SCRIPT65_VERIFY_STATUS="FAILED"
    SCRIPT65_DEPLOYMENT="not-run"
    SCRIPT65_READY_FOR_DEPLOYMENT_LANE="no"
    SCRIPT65_READY_FOR_WORKFLOW_LANE="no"
    SCRIPT65_READY_FOR_SCRIPT66="no"
    write_verify_report || true
    echo -e "${CROSS} ${RD}${message}${CL}"
    echo -e "  ${BL}Verify log:${CL} ${VERIFY_LOG}"
    exit 1
}

# =========================================================
#  ROOT FILE / COMMAND HELPERS
# =========================================================
function root_path_exists() { test -e "$1"; }
function root_file_not_empty() { test -s "$1"; }
function root_read_file() { cat "$1"; }
function root_copy_file() { cp -f "$1" "$2"; }
function root_install_dir() { install -d -m "${2:-755}" "$1"; }
function root_set_owner_group() { chown "$2" "$1" 2>/dev/null || true; }
function root_set_mode() { chmod "$2" "$1"; }
function write_root_file() { cat > "$1"; }

function run_cmd() {
    local description="$1"; shift
    local err_file=""
    err_file="$(mktemp)"
    TEMP_FILES+=("$err_file")
    if ! "$@" >/dev/null 2>"$err_file"; then
        echo ""
        echo -e "${RD}Command failed during:${CL} ${description}"
        echo -e "${YW}Command:${CL} $*"
        sed -E '/(PASSWORD|PASSWD|SECRET|TOKEN|DATABASE_URL|REDIS_URL|JWT|NEXTAUTH|AUTHORIZATION|BEARER)/Id' "$err_file" || true
        exit 1
    fi
    rm -f "$err_file"
}

function validate_dependencies() {
    local cmds=(awk cat chmod command cp cut date grep install mkdir mktemp openssl rm sed sort stat tee test tr)
    local cmd=""
    for cmd in "${cmds[@]}"; do command -v "$cmd" >/dev/null 2>&1 || msg_error "Required command not found: ${cmd}"; done
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then msg_error "curl or wget is required to download n8n templates."; fi
    command -v docker >/dev/null 2>&1 || msg_error "Docker command not found. Complete Script 5/6 first."
}

function download_file() {
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then curl -fsSL "$url" -o "$dest"; else wget -qO "$dest" "$url"; fi
}

# =========================================================
#  VALUE / MARKER / ENV HELPERS
# =========================================================
function trim_shell_value() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//"; }

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

function env_has_nonempty_value() { local value=""; value="$(env_value "$1")"; [ -n "$value" ]; }

function env_line_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

function append_env_line() { printf '%s="%s"\n' "$1" "$(env_line_escape "$2")"; }
function generate_secret_hex() { openssl rand -hex "${1:-32}"; }

function host_from_url() {
    local value="${1:-}"
    value="$(printf '%s' "$value" | trim_shell_value)"
    value="${value#http://}"; value="${value#https://}"; value="${value%%/*}"; value="${value%%:*}"
    printf '%s' "$value" | tr '[:upper:]' '[:lower:]'
}

function sanitize_slug() { printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'; }
function title_case_slug() { printf '%s' "${1:-}" | awk -F'[-_ ]+' '{out=""; for (i=1; i<=NF; i++) if ($i != "") out=out (out?" ":"") toupper(substr($i,1,1)) substr($i,2); print out}'; }
function validate_domain() { [[ "${1:-}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]]; }

function image_tag() { local image="$1"; [[ "$image" == *:* ]] || return 1; printf '%s' "${image##*:}"; }
function version_at_least() { local have="$1" need="$2"; [ "$(printf '%s\n%s\n' "$need" "$have" | sort -V | head -n1)" = "$need" ]; }

# =========================================================
#  PREFLIGHT GATES / PROJECT CONTEXT
# =========================================================
function validate_handoff_gates() {
    section "SCRIPT 6.5 HANDOFF"

    if ! root_path_exists "$SCRIPT61_MARKER"; then fail_with_report "Script 6.1 completion marker is missing."; fi
    SCRIPT61_STATUS="$(marker_file_key_value "$SCRIPT61_MARKER" SCRIPT61_STATUS)"
    SCRIPT61_VERIFY_STATUS="$(marker_file_key_value "$SCRIPT61_MARKER" SCRIPT61_VERIFY_STATUS)"
    aligned_status_line "Script 6.1 status" "${SCRIPT61_STATUS:-missing}" "$(status_color_for_value "${SCRIPT61_STATUS:-missing}")"
    aligned_status_line "Script 6.1 verify" "${SCRIPT61_VERIFY_STATUS:-missing}" "$(status_color_for_value "${SCRIPT61_VERIFY_STATUS:-missing}")"
    [ "$SCRIPT61_STATUS" = "completed" ] || fail_with_report "Script 6.1 status is not completed."
    [ "$SCRIPT61_VERIFY_STATUS" = "PASS" ] || fail_with_report "Script 6.1 verification is not PASS."

    if ! root_path_exists "$SCRIPT63_MARKER"; then fail_with_report "Script 6.3 completion marker is missing."; fi
    SCRIPT63_STATUS="$(marker_file_key_value "$SCRIPT63_MARKER" SCRIPT63_STATUS)"
    SCRIPT63_VERIFY_STATUS="$(marker_file_key_value "$SCRIPT63_MARKER" SCRIPT63_VERIFY_STATUS)"
    SCRIPT63_FORWARD_AUTH="$(marker_file_key_value "$SCRIPT63_MARKER" SCRIPT63_FORWARD_AUTH)"
    SCRIPT63_TRAEFIK_FORWARD_AUTH="$(marker_file_key_value "$SCRIPT63_MARKER" SCRIPT63_TRAEFIK_FORWARD_AUTH)"
    aligned_status_line "Script 6.3 status" "${SCRIPT63_STATUS:-missing}" "$(status_color_for_value "${SCRIPT63_STATUS:-missing}")"
    aligned_status_line "Script 6.3 verify" "${SCRIPT63_VERIFY_STATUS:-missing}" "$(status_color_for_value "${SCRIPT63_VERIFY_STATUS:-missing}")"
    aligned_status_line "ForwardAuth" "${SCRIPT63_FORWARD_AUTH:-missing}" "$(status_color_for_value "${SCRIPT63_FORWARD_AUTH:-missing}")"
    aligned_status_line "Traefik ForwardAuth" "${SCRIPT63_TRAEFIK_FORWARD_AUTH:-missing}" "$(status_color_for_value "${SCRIPT63_TRAEFIK_FORWARD_AUTH:-missing}")"
    [ "$SCRIPT63_STATUS" = "completed" ] || fail_with_report "Script 6.3 status is not completed."
    [ "$SCRIPT63_VERIFY_STATUS" = "PASS" ] || fail_with_report "Script 6.3 verification is not PASS."
    [ "$SCRIPT63_FORWARD_AUTH" = "ready" ] || fail_with_report "Script 6.3 ForwardAuth is not ready."
    [ "$SCRIPT63_TRAEFIK_FORWARD_AUTH" = "ready" ] || fail_with_report "Script 6.3 Traefik ForwardAuth is not ready."

    if ! root_path_exists "$SCRIPT64_MARKER"; then fail_with_report "Script 6.4 deployment marker is missing."; fi
    SCRIPT64_STATUS="$(marker_file_key_value "$SCRIPT64_MARKER" SCRIPT64_STATUS)"
    SCRIPT64_VERIFY_STATUS="$(marker_file_key_value "$SCRIPT64_MARKER" SCRIPT64_VERIFY_STATUS)"
    SCRIPT64_READY_FOR_SCRIPT65="$(marker_file_key_value "$SCRIPT64_MARKER" SCRIPT64_READY_FOR_SCRIPT65)"
    aligned_status_line "Script 6.4 status" "${SCRIPT64_STATUS:-missing}" "$(status_color_for_value "${SCRIPT64_STATUS:-missing}")"
    aligned_status_line "Script 6.4 verify" "${SCRIPT64_VERIFY_STATUS:-missing}" "$(status_color_for_value "${SCRIPT64_VERIFY_STATUS:-missing}")"
    aligned_status_line "Ready for Script 6.5" "${SCRIPT64_READY_FOR_SCRIPT65:-missing}" "$(status_color_for_value "${SCRIPT64_READY_FOR_SCRIPT65:-missing}")"
    [ "$SCRIPT64_STATUS" = "completed" ] || fail_with_report "Script 6.4 status is not completed."
    [ "$SCRIPT64_VERIFY_STATUS" = "PASS" ] || fail_with_report "Script 6.4 verification is not PASS."
    [ "$SCRIPT64_READY_FOR_SCRIPT65" = "yes" ] || fail_with_report "Script 6.4 is not marked ready for Script 6.5."

    SCRIPT65_HANDOFF_GATES="PASS"
    msg_ok "SCRIPT 6.5 HANDOFF PASSED"
}

function load_project_context() {
    section "PROJECT IDENTITY"
    DOCKER_DIR="$(marker_file_key_value "$SCRIPT61_MARKER" SCRIPT61_DOCKER_DIR)"
    COMPOSE_DIR="$(marker_file_key_value "$SCRIPT61_MARKER" SCRIPT61_COMPOSE_DIR)"
    [ -n "$DOCKER_DIR" ] || DOCKER_DIR="$(marker_file_key_value "$SCRIPT64_MARKER" SCRIPT64_DOCKER_DIR)"
    [ -n "$COMPOSE_DIR" ] || COMPOSE_DIR="${DOCKER_DIR}/compose"
    [ -n "$DOCKER_DIR" ] || DOCKER_DIR="/opt/docker"
    ENV_FILE="${DOCKER_DIR}/.env"

    RAW_BASE_DEFAULT="${RAW_BASE_DEFAULT:-}"
    [ -n "$RAW_BASE_DEFAULT" ] || RAW_BASE_DEFAULT="$(env_value RAW_BASE_DEFAULT)"
    [ -n "$RAW_BASE_DEFAULT" ] || RAW_BASE_DEFAULT="$(env_value RAW_BASE)"
    [ -n "$RAW_BASE_DEFAULT" ] || RAW_BASE_DEFAULT="$RAW_BASE_FALLBACK"

    DOMAIN_VALUE="$(env_value DOMAIN)"
    [ -n "$DOMAIN_VALUE" ] || DOMAIN_VALUE="$(marker_file_key_value "$SCRIPT61_MARKER" SCRIPT61_DOMAIN)"
    [ -n "$DOMAIN_VALUE" ] || DOMAIN_VALUE="$(marker_file_key_value "$SCRIPT64_MARKER" SCRIPT64_PROJECT_BASE_DOMAIN)"
    DOMAIN_VALUE="$(host_from_url "$DOMAIN_VALUE")"
    validate_domain "$DOMAIN_VALUE" || fail_with_report "Base domain could not be derived from markers or .env."

    PROJECT_SLUG="$(env_value PROJECT_SLUG)"
    [ -n "$PROJECT_SLUG" ] || PROJECT_SLUG="$(marker_file_key_value "$SCRIPT64_MARKER" SCRIPT64_PROJECT_SLUG)"
    [ -n "$PROJECT_SLUG" ] || PROJECT_SLUG="$(sanitize_slug "${DOMAIN_VALUE%%.*}")"
    PROJECT_SLUG="$(sanitize_slug "$PROJECT_SLUG")"
    [ -n "$PROJECT_SLUG" ] || fail_with_report "Project slug could not be derived."

    PROJECT_NAME="$(env_value PROJECT_NAME)"
    [ -n "$PROJECT_NAME" ] || PROJECT_NAME="$(marker_file_key_value "$SCRIPT64_MARKER" SCRIPT64_PROJECT_NAME)"
    [ -n "$PROJECT_NAME" ] || PROJECT_NAME="$(title_case_slug "$PROJECT_SLUG")"

    N8N_HOST="$(env_value N8N_HOST)"
    [ -n "$N8N_HOST" ] || N8N_HOST="n8n.${DOMAIN_VALUE}"
    N8N_HOST="$(host_from_url "$N8N_HOST")"
    N8N_URL="$(env_value N8N_URL)"
    [ -n "$N8N_URL" ] || N8N_URL="https://${N8N_HOST}"
    N8N_WEBHOOK_URL="$(env_value N8N_WEBHOOK_URL)"
    [ -n "$N8N_WEBHOOK_URL" ] || N8N_WEBHOOK_URL="https://${N8N_HOST}"

    N8N_APPDATA_DIR="${DOCKER_DIR}/appdata/n8n"
    N8N_POSTGRES_DIR="${N8N_APPDATA_DIR}/postgres"
    N8N_REDIS_DIR="${N8N_APPDATA_DIR}/redis"
    N8N_STORAGE_DIR="${N8N_APPDATA_DIR}/storage"
    N8N_COMPOSE_FILE="${COMPOSE_DIR}/07-n8n-compose.yml"
    N8N_DOCKGE_COMPOSE_FILE="${COMPOSE_DIR}/n8n/compose.yaml"
    N8N_TEMPLATE_URL="${RAW_BASE_DEFAULT%/}/docker/07-n8n-compose.yml"

    aligned_status_line "Base domain" "$DOMAIN_VALUE" "$GN"
    aligned_status_line "Project slug" "$PROJECT_SLUG" "$GN"
    aligned_status_line "Project name" "$PROJECT_NAME" "$GN"
    aligned_status_line "n8n host" "$N8N_HOST" "$GN"
    aligned_status_line "Identity lane" "platform-admin" "$GN"
}

function print_plan() {
    section "PREFLIGHT PLAN"
    aligned_status_line "Action" "template/preflight only" "$GN"
    aligned_status_line "Template" "docker/07-n8n-compose.yml" "$GN"
    aligned_status_line "Runtime compose" "$N8N_COMPOSE_FILE" "$BL"
    aligned_status_line "Deployment" "not-run" "$GN"
    aligned_status_line "Authentik API writes" "not-run" "$GN"
}

# =========================================================
#  ENV / DIRECTORY / TEMPLATE PREP
# =========================================================
function set_env_key_if_missing() {
    local env_file="$1" key="$2" value="$3"
    touch "$env_file"
    chmod 600 "$env_file"
    if grep -qE "^${key}=" "$env_file"; then return 0; fi
    append_env_line "$key" "$value" >> "$env_file"
    SCRIPT65_ENV_KEYS_ADDED=$((SCRIPT65_ENV_KEYS_ADDED + 1))
}

function prepare_env() {
    section "N8N ENV"
    local backup_path="" ts=""
    root_install_dir "$(dirname "$ENV_FILE")" 755
    touch "$ENV_FILE"
    chmod 600 "$ENV_FILE"

    ts="$(date +%Y%m%d-%H%M%S)"
    backup_path="${ENV_FILE}.bak.script65-${ts}"
    cp -f "$ENV_FILE" "$backup_path"
    SCRIPT65_ENV_BACKUP="created"

    set_env_key_if_missing "$ENV_FILE" N8N_VERSION "$DEFAULT_N8N_VERSION"
    set_env_key_if_missing "$ENV_FILE" N8N_IMAGE "$DEFAULT_N8N_IMAGE"
    set_env_key_if_missing "$ENV_FILE" N8N_RUNNERS_IMAGE "$DEFAULT_N8N_RUNNERS_IMAGE"
    set_env_key_if_missing "$ENV_FILE" N8N_POSTGRES_IMAGE "$DEFAULT_N8N_POSTGRES_IMAGE"
    set_env_key_if_missing "$ENV_FILE" N8N_REDIS_IMAGE "$DEFAULT_N8N_REDIS_IMAGE"
    set_env_key_if_missing "$ENV_FILE" N8N_HOST "$N8N_HOST"
    set_env_key_if_missing "$ENV_FILE" N8N_URL "$N8N_URL"
    set_env_key_if_missing "$ENV_FILE" N8N_WEBHOOK_URL "$N8N_WEBHOOK_URL"
    set_env_key_if_missing "$ENV_FILE" N8N_POSTGRES_DB "n8n"
    set_env_key_if_missing "$ENV_FILE" N8N_POSTGRES_USER "n8n"
    set_env_key_if_missing "$ENV_FILE" N8N_POSTGRES_PASSWORD "$(generate_secret_hex 24)"
    set_env_key_if_missing "$ENV_FILE" N8N_ENCRYPTION_KEY "$(generate_secret_hex 32)"
    set_env_key_if_missing "$ENV_FILE" N8N_RUNNERS_AUTH_TOKEN "$(generate_secret_hex 32)"
    set_env_key_if_missing "$ENV_FILE" N8N_LOG_LEVEL "info"

    if [ "$SCRIPT65_ENV_KEYS_ADDED" -eq 0 ]; then
        rm -f "$backup_path" 2>/dev/null || true
        SCRIPT65_ENV_BACKUP="not-needed"
    fi

    validate_image_pairing
    SCRIPT65_ENV_STATUS="ready"
    aligned_status_line "Keys added" "$SCRIPT65_ENV_KEYS_ADDED" "$GN"
    aligned_status_line "Secrets" "preserved/generated" "$GN"
    msg_ok "N8N ENV READY"
}

function validate_image_pairing() {
    local n8n_version="" n8n_image="" runners_image="" n8n_tag="" runner_tag=""
    n8n_version="$(env_value N8N_VERSION)"; [ -n "$n8n_version" ] || n8n_version="$DEFAULT_N8N_VERSION"
    n8n_image="$(env_value N8N_IMAGE)"; [ -n "$n8n_image" ] || n8n_image="$DEFAULT_N8N_IMAGE"
    runners_image="$(env_value N8N_RUNNERS_IMAGE)"; [ -n "$runners_image" ] || runners_image="$DEFAULT_N8N_RUNNERS_IMAGE"

    [[ "$n8n_image" != *":latest" ]] || fail_with_report "N8N_IMAGE must not use latest."
    [[ "$runners_image" != *":latest" ]] || fail_with_report "N8N_RUNNERS_IMAGE must not use latest."
    n8n_tag="$(image_tag "$n8n_image")" || fail_with_report "N8N_IMAGE must include an explicit tag."
    runner_tag="$(image_tag "$runners_image")" || fail_with_report "N8N_RUNNERS_IMAGE must include an explicit tag."
    [ "$n8n_tag" = "$runner_tag" ] || fail_with_report "n8n and runner image tags must match."
    [ "$n8n_tag" = "$n8n_version" ] || fail_with_report "N8N_IMAGE tag must match N8N_VERSION."
    version_at_least "$n8n_version" "1.111.0" || fail_with_report "External task runners require n8n >= 1.111.0."
}

function prepare_n8n_directories() {
    section "N8N DIRECTORIES"
    root_install_dir "$COMPOSE_DIR" 755
    root_install_dir "$N8N_APPDATA_DIR" 700
    root_install_dir "$N8N_POSTGRES_DIR" 700
    root_install_dir "$N8N_REDIS_DIR" 700
    root_install_dir "$N8N_STORAGE_DIR" 700
    SCRIPT65_N8N_APPDATA="ready"
    SCRIPT65_N8N_POSTGRES_DATA="ready"
    SCRIPT65_N8N_REDIS_DATA="ready"
    SCRIPT65_N8N_STORAGE="ready"
    aligned_status_line "Appdata" "$SCRIPT65_N8N_APPDATA" "$GN"
    aligned_status_line "Postgres data" "$SCRIPT65_N8N_POSTGRES_DATA" "$GN"
    aligned_status_line "Redis data" "$SCRIPT65_N8N_REDIS_DATA" "$GN"
    aligned_status_line "Storage" "$SCRIPT65_N8N_STORAGE" "$GN"
    msg_ok "N8N DIRECTORIES READY"
}

function sync_n8n_template() {
    section "TEMPLATES"
    local template_tmp=""
    template_tmp="$(mktemp /tmp/circl8-n8n-compose-template.XXXXXX)"
    TEMP_FILES+=("$template_tmp")

    if [ -f "docker/07-n8n-compose.yml" ]; then
        cp -f "docker/07-n8n-compose.yml" "$template_tmp"
    else
        msg_info "Downloading n8n compose template"
        download_file "$N8N_TEMPLATE_URL" "$template_tmp" || fail_with_report "Failed to download n8n compose template."
        msg_ok "N8N COMPOSE TEMPLATE DOWNLOADED"
    fi

    root_file_not_empty "$template_tmp" || fail_with_report "n8n compose template is empty."
    root_copy_file "$template_tmp" "$N8N_COMPOSE_FILE"
    chmod 640 "$N8N_COMPOSE_FILE"
    SCRIPT65_N8N_COMPOSE_TEMPLATE="synced"
    aligned_status_line "Runtime compose" "synced" "$GN"

    if [ "$(env_value ADMIN_UI)" = "dockge" ]; then
        root_install_dir "$(dirname "$N8N_DOCKGE_COMPOSE_FILE")" 755
        root_copy_file "$N8N_COMPOSE_FILE" "$N8N_DOCKGE_COMPOSE_FILE"
        chmod 640 "$N8N_DOCKGE_COMPOSE_FILE"
        aligned_status_line "Dockge compose" "synced" "$GN"
    else
        aligned_status_line "Dockge compose" "skipped" "$YW"
    fi
}

# =========================================================
#  STATIC SAFETY / COMPOSE CONFIG
# =========================================================
function contains_regex() { grep -Eq -- "$2" "$1"; }
function reject_regex() { if contains_regex "$1" "$2"; then fail_with_report "$3"; fi; }
function require_regex() { contains_regex "$1" "$2" || fail_with_report "$3"; }

function uncommented_file_content() { sed '/^[[:space:]]*#/d' "$1"; }

function validate_static_safety() {
    section "STATIC SAFETY"
    local compose="$N8N_COMPOSE_FILE" noncomment=""
    [ -f "$compose" ] || fail_with_report "Rendered n8n compose file is missing."
    noncomment="$(uncommented_file_content "$compose")"

    require_regex "$compose" '^[[:space:]]{2}n8n-postgres:' "Compose missing n8n-postgres service."
    require_regex "$compose" '^[[:space:]]{2}n8n-redis:' "Compose missing n8n-redis service."
    require_regex "$compose" '^[[:space:]]{2}n8n:' "Compose missing n8n service."
    require_regex "$compose" '^[[:space:]]{2}n8n-runner:' "Compose missing n8n-runner service."
    require_regex "$compose" '^[[:space:]]{2}n8n-worker:' "Compose missing n8n-worker service."
    require_regex "$compose" '^[[:space:]]{2}n8n-worker-runner:' "Compose missing n8n-worker-runner service."
    require_regex "$compose" 'n8n-internal' "Compose missing private n8n internal network."
    require_regex "$compose" 't2_proxy' "Compose missing platform proxy network reference."
    require_regex "$compose" 'postgres:17-alpine|N8N_POSTGRES_IMAGE:-postgres:17-alpine' "Postgres image baseline is not present."
    require_regex "$compose" 'redis:7-alpine|N8N_REDIS_IMAGE:-redis:7-alpine' "Redis image baseline is not present."
    require_regex "$compose" '2[.]26[.]7' "n8n 2.26.7 baseline is not present."
    require_regex "$compose" 'EXECUTIONS_MODE.*queue|queue.*EXECUTIONS_MODE' "Queue mode is not enabled."
    require_regex "$compose" 'N8N_RUNNERS_ENABLED.*true|true.*N8N_RUNNERS_ENABLED|OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS.*true|true.*OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS' "External runner settings are not present."
    require_regex "$compose" '/webhook' "Production webhook route is not present."
    require_regex "$compose" 'authentik|forwardauth|forward-auth|chain' "Protected platform/admin middleware reference is not present."

    printf '%s\n' "$noncomment" | grep -qE '^[[:space:]]{2}traefik:' && fail_with_report "Compose must not bundle Traefik."
    printf '%s\n' "$noncomment" | grep -qE '^[[:space:]]+ports:' && fail_with_report "Compose must not publish container ports."
    printf '%s\n' "$noncomment" | grep -qE 'docker[.]sock|/var/run/docker[.]sock' && fail_with_report "Compose must not mount the Docker socket."
    printf '%s\n' "$noncomment" | grep -qE 'status-(trial|active|past-due|cancelled|suspended|deletion-requested)|plan-(starter|growth|pro)' && fail_with_report "Compose must not reference customer status or plan groups."
    printf '%s\n' "$noncomment" | grep -qE 'app[.]circl8[.]co[.]uk|auth[.]circl8[.]co[.]uk|[.]circl8[.]co[.]uk' && fail_with_report "Compose must not hardcode public identity values."
    printf '%s\n' "$noncomment" | grep -qE 'elastic[[:alpha:]]*|temporal[-]ui|[s]tripe' && fail_with_report "Compose contains out-of-scope services or workflows."

    validate_service_network_scope "$compose"
    validate_webhook_auth_scope "$compose"
    validate_script_self_safety
    SCRIPT65_N8N_STATIC_SAFETY="pass"
    aligned_status_line "Service networks" "pass" "$GN"
    aligned_status_line "Webhook routing" "pass" "$GN"
    aligned_status_line "Forbidden patterns" "absent" "$GN"
    msg_ok "STATIC SAFETY PASSED"
}

function validate_service_network_scope() {
    local compose="$1" attached_services="" invalid_services=""
    attached_services="$(awk '
        /^services:[[:space:]]*$/ {in_services=1; svc=""; in_networks=0; next}
        in_services && /^[^[:space:]][A-Za-z0-9_.-]*:/ {in_services=0; svc=""; in_networks=0}
        !in_services {next}
        /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ {svc=$1; gsub(":", "", svc); in_networks=0; next}
        /^    networks:[[:space:]]*$/ {in_networks=1; next}
        in_networks && /^    [A-Za-z0-9_.-]+:/ {in_networks=0}
        in_networks && /(^|[[:space:]-])t2_proxy([[:space:]]|$)/ {if (svc != "") print svc}
    ' "$compose" | sort -u)"
    printf '%s\n' "$attached_services" | grep -qx 'n8n' || fail_with_report "n8n service must be attached to t2_proxy."
    invalid_services="$(printf '%s\n' "$attached_services" | grep -vx 'n8n' || true)"
    [ -z "$invalid_services" ] || fail_with_report "t2_proxy must be attached only to the n8n service."
}

function validate_webhook_auth_scope() {
    local compose="$1" routers="" router="" middleware_lines="" ui_middleware=""
    routers="$(awk '
        /traefik[.]http[.]routers[.][A-Za-z0-9_.-]+[.]rule/ && /\/webhook/ && !/\/webhook-test/ {
            line=$0
            sub(/^.*traefik[.]http[.]routers[.]/, "", line)
            sub(/[.]rule.*$/, "", line)
            print line
        }
    ' "$compose" | sort -u)"
    [ -n "$routers" ] || fail_with_report "Public production webhook route is missing."
    while IFS= read -r router; do
        [ -n "$router" ] || continue
        middleware_lines="$(grep -E "traefik[.]http[.]routers[.]${router//./[.]}[.]middlewares" "$compose" || true)"
        [ -z "$middleware_lines" ] || fail_with_report "Production webhook route must not use Authentik middleware."
    done <<< "$routers"

    ui_middleware="$(grep -E 'traefik[.]http[.]routers[.][A-Za-z0-9_.-]+[.]middlewares' "$compose" | grep -E 'authentik|forwardauth|forward-auth|chain' || true)"
    [ -n "$ui_middleware" ] || fail_with_report "Protected UI router middleware reference is missing."

    if awk '
        /traefik[.]http[.]routers[.][A-Za-z0-9_.-]+[.]rule/ && /\/webhook-test/ {
            line=$0
            sub(/^.*traefik[.]http[.]routers[.]/, "", line)
            sub(/[.]rule.*$/, "", line)
            print line
        }
    ' "$compose" | while IFS= read -r router; do
        [ -n "$router" ] || continue
        grep -E "traefik[.]http[.]routers[.]${router//./[.]}[.]middlewares" "$compose" | grep -E 'authentik|forwardauth|forward-auth|chain' >/dev/null 2>&1 || exit 1
    done; then
        :
    else
        fail_with_report "webhook-test route must not be publicly exposed without platform/admin middleware."
    fi
}

function validate_script_self_safety() {
    local script_path=""
    script_path="$(readlink -f "${BASH_SOURCE[0]}")"
    [ -f "$script_path" ] || return 0
    reject_regex "$script_path" 'docker[[:space:]]+compose[[:space:]]+(up|pull|down|restart|stop|rm)' "Script contains a forbidden Docker Compose lifecycle action."
    reject_regex "$script_path" 'docker[[:space:]]+(image|volume|network|system)[[:space:]]+prune' "Script contains a forbidden prune action."
    reject_regex "$script_path" 'docker[.]sock|/var/run/docker[.]sock' "Script contains a Docker socket reference."
    reject_regex "$script_path" 'app[.]circl8[.]co[.]uk|auth[.]circl8[.]co[.]uk|[.]circl8[.]co[.]uk' "Script contains hardcoded public identity values."
    reject_regex "$script_path" 'status-(trial|active|past-due|cancelled|suspended|deletion-requested)|plan-(starter|growth|pro)' "Script contains customer status or plan group references."
    reject_regex "$script_path" '[s]tripe|postiz source|custom image build|elastic[[:alpha:]]*|temporal[-]ui' "Script contains out-of-scope workflow or app modification references."
}

function validate_compose_config() {
    section "COMPOSE CONFIG"
    msg_info "Validating n8n compose config"
    docker compose -f "$N8N_COMPOSE_FILE" --env-file "$ENV_FILE" config > /tmp/circl8-n8n-compose-config.out 2> /tmp/circl8-n8n-compose-config.err || {
        sed -E '/(PASSWORD|PASSWD|SECRET|TOKEN|DATABASE_URL|REDIS_URL|JWT|AUTHORIZATION|BEARER)/Id' /tmp/circl8-n8n-compose-config.err >> "$LOG_FILE" 2>/dev/null || true
        fail_with_report "Docker Compose config validation failed for n8n."
    }
    rm -f /tmp/circl8-n8n-compose-config.out /tmp/circl8-n8n-compose-config.err 2>/dev/null || true
    SCRIPT65_N8N_COMPOSE_CONFIG="valid"
    msg_ok "N8N COMPOSE CONFIG VALID"
}

# =========================================================
#  REPORT / MARKER / SUMMARY
# =========================================================
function write_verify_report() {
    {
        printf '%s\n' "SCRIPT65_STATUS=${SCRIPT65_STATUS}"
        printf '%s\n' "SCRIPT65_VERSION=${SCRIPT_VERSION}"
        printf '%s\n' "SCRIPT65_BUILD=${SCRIPT_BUILD}"
        printf '%s\n' "SCRIPT65_VERIFY_STATUS=${SCRIPT65_VERIFY_STATUS}"
        printf '%s\n' "SCRIPT65_DEPLOYMENT=${SCRIPT65_DEPLOYMENT}"
        printf '%s\n' "SCRIPT65_MARKER_WRITTEN=${SCRIPT65_MARKER_WRITTEN}"
        printf '%s\n' "SCRIPT65_HANDOFF_GATES=${SCRIPT65_HANDOFF_GATES}"
        printf '%s\n' "SCRIPT61_STATUS=${SCRIPT61_STATUS}"
        printf '%s\n' "SCRIPT61_VERIFY_STATUS=${SCRIPT61_VERIFY_STATUS}"
        printf '%s\n' "SCRIPT63_STATUS=${SCRIPT63_STATUS}"
        printf '%s\n' "SCRIPT63_VERIFY_STATUS=${SCRIPT63_VERIFY_STATUS}"
        printf '%s\n' "SCRIPT63_FORWARD_AUTH=${SCRIPT63_FORWARD_AUTH}"
        printf '%s\n' "SCRIPT63_TRAEFIK_FORWARD_AUTH=${SCRIPT63_TRAEFIK_FORWARD_AUTH}"
        printf '%s\n' "SCRIPT64_STATUS=${SCRIPT64_STATUS}"
        printf '%s\n' "SCRIPT64_VERIFY_STATUS=${SCRIPT64_VERIFY_STATUS}"
        printf '%s\n' "SCRIPT64_READY_FOR_SCRIPT65=${SCRIPT64_READY_FOR_SCRIPT65}"
        printf '%s\n' "SCRIPT65_PROJECT_SLUG=${PROJECT_SLUG}"
        printf '%s\n' "SCRIPT65_PROJECT_NAME=${PROJECT_NAME}"
        printf '%s\n' "SCRIPT65_N8N_HOST=${N8N_HOST}"
        printf '%s\n' "SCRIPT65_N8N_URL=${N8N_URL}"
        printf '%s\n' "SCRIPT65_N8N_WEBHOOK_URL=${N8N_WEBHOOK_URL}"
        printf '%s\n' "SCRIPT65_ENV_STATUS=${SCRIPT65_ENV_STATUS}"
        printf '%s\n' "SCRIPT65_ENV_BACKUP=${SCRIPT65_ENV_BACKUP}"
        printf '%s\n' "SCRIPT65_ENV_KEYS_ADDED=${SCRIPT65_ENV_KEYS_ADDED}"
        printf '%s\n' "SCRIPT65_N8N_APPDATA=${SCRIPT65_N8N_APPDATA}"
        printf '%s\n' "SCRIPT65_N8N_POSTGRES_DATA=${SCRIPT65_N8N_POSTGRES_DATA}"
        printf '%s\n' "SCRIPT65_N8N_REDIS_DATA=${SCRIPT65_N8N_REDIS_DATA}"
        printf '%s\n' "SCRIPT65_N8N_STORAGE=${SCRIPT65_N8N_STORAGE}"
        printf '%s\n' "SCRIPT65_N8N_COMPOSE_TEMPLATE=${SCRIPT65_N8N_COMPOSE_TEMPLATE}"
        printf '%s\n' "SCRIPT65_N8N_COMPOSE_CONFIG=${SCRIPT65_N8N_COMPOSE_CONFIG}"
        printf '%s\n' "SCRIPT65_N8N_STATIC_SAFETY=${SCRIPT65_N8N_STATIC_SAFETY}"
        printf '%s\n' "SCRIPT65_AUTHENTIK_LANE=platform-admin"
        printf '%s\n' "SCRIPT65_AUTHENTIK_APPLICATION=not-used"
        printf '%s\n' "SCRIPT65_AUTHENTIK_PROVIDER=not-used"
        printf '%s\n' "SCRIPT65_AUTHENTIK_OUTPOST=preserved"
        printf '%s\n' "SCRIPT65_READY_FOR_DEPLOYMENT_LANE=${SCRIPT65_READY_FOR_DEPLOYMENT_LANE}"
        printf '%s\n' "SCRIPT65_READY_FOR_WORKFLOW_LANE=${SCRIPT65_READY_FOR_WORKFLOW_LANE}"
        printf '%s\n' "SCRIPT65_READY_FOR_SCRIPT66=${SCRIPT65_READY_FOR_SCRIPT66}"
        printf '%s\n' "SCRIPT65_COMPOSE_FILE=${N8N_COMPOSE_FILE}"
        printf '%s\n' "SCRIPT65_TEMPLATE_PREFLIGHT_MARKER_PATH=${COMPLETED_MARKER}"
        printf '%s\n' "SCRIPT65_DEPLOYED_MARKER_PATH=${DEPLOYED_MARKER}"
        printf '%s\n' "SCRIPT65_DEPLOYED_MARKER_WRITTEN=no"
    } | write_root_file "$VERIFY_LOG"
    chmod 600 "$VERIFY_LOG" 2>/dev/null || true
}

function write_completion_marker() {
    local tmp_file=""
    tmp_file="$(mktemp /tmp/circl8-n8n-template-marker.XXXXXX)"
    {
        printf '%s\n' "SCRIPT65_STATUS=template-preflight-completed"
        printf '%s\n' "SCRIPT65_VERSION=${SCRIPT_VERSION}"
        printf '%s\n' "SCRIPT65_BUILD=${SCRIPT_BUILD}"
        printf '%s\n' "SCRIPT65_VERIFY_STATUS=PASS"
        printf '%s\n' "SCRIPT65_DEPLOYMENT=not-run"
        printf '%s\n' "SCRIPT65_MARKER_WRITTEN=yes"
        printf '%s\n' "SCRIPT65_READY_FOR_DEPLOYMENT_LANE=yes"
        printf '%s\n' "SCRIPT65_READY_FOR_WORKFLOW_LANE=no"
        printf '%s\n' "SCRIPT65_READY_FOR_SCRIPT66=no"
        printf '%s\n' "SCRIPT65_PROJECT_SLUG=${PROJECT_SLUG}"
        printf '%s\n' "SCRIPT65_PROJECT_NAME=${PROJECT_NAME}"
        printf '%s\n' "SCRIPT65_N8N_HOST=${N8N_HOST}"
        printf '%s\n' "SCRIPT65_N8N_URL=${N8N_URL}"
        printf '%s\n' "SCRIPT65_N8N_WEBHOOK_URL=${N8N_WEBHOOK_URL}"
        printf '%s\n' "SCRIPT65_ENV_STATUS=ready"
        printf '%s\n' "SCRIPT65_ENV_KEYS_ADDED=${SCRIPT65_ENV_KEYS_ADDED}"
        printf '%s\n' "SCRIPT65_N8N_APPDATA=ready"
        printf '%s\n' "SCRIPT65_N8N_POSTGRES_DATA=ready"
        printf '%s\n' "SCRIPT65_N8N_REDIS_DATA=ready"
        printf '%s\n' "SCRIPT65_N8N_STORAGE=ready"
        printf '%s\n' "SCRIPT65_N8N_COMPOSE_TEMPLATE=synced"
        printf '%s\n' "SCRIPT65_N8N_COMPOSE_CONFIG=valid"
        printf '%s\n' "SCRIPT65_N8N_STATIC_SAFETY=pass"
        printf '%s\n' "SCRIPT65_AUTHENTIK_LANE=platform-admin"
        printf '%s\n' "SCRIPT65_AUTHENTIK_APPLICATION=not-used"
        printf '%s\n' "SCRIPT65_AUTHENTIK_PROVIDER=not-used"
        printf '%s\n' "SCRIPT65_AUTHENTIK_OUTPOST=preserved"
    } > "$tmp_file"
    chmod 600 "$tmp_file"
    mv -f "$tmp_file" "$COMPLETED_MARKER"
    SCRIPT65_MARKER_WRITTEN="yes"
}

function mark_template_preflight_ready() {
    SCRIPT65_STATUS="template-preflight-completed"
    SCRIPT65_VERIFY_STATUS="PASS"
    SCRIPT65_DEPLOYMENT="not-run"
    SCRIPT65_READY_FOR_DEPLOYMENT_LANE="yes"
    SCRIPT65_READY_FOR_WORKFLOW_LANE="no"
    SCRIPT65_READY_FOR_SCRIPT66="no"
    write_completion_marker
    write_verify_report
}

function print_summary() {
    section_flash_success "FINISHED"
    mini_header "Script"
    final_line "Source" "$SCRIPT_SOURCE" "$GN"
    final_line "Version" "$SCRIPT_VERSION" "$GN"
    final_line "Build" "$SCRIPT_BUILD" "$GN"

    mini_header "Preflight"
    final_line "Handoff gates" "$SCRIPT65_HANDOFF_GATES" "$GN"
    final_line "Env prepared" "$SCRIPT65_ENV_STATUS" "$GN"
    final_line "Appdata dirs" "$SCRIPT65_N8N_APPDATA" "$GN"
    final_line "Template synced" "$SCRIPT65_N8N_COMPOSE_TEMPLATE" "$GN"
    final_line "Static safety" "$SCRIPT65_N8N_STATIC_SAFETY" "$GN"
    final_line "Compose config" "$SCRIPT65_N8N_COMPOSE_CONFIG" "$GN"

    mini_header "Deployment"
    final_line "Status" "not-run" "$GN"
    final_line "Containers started" "no" "$GN"
    final_line "Authentik writes" "no" "$GN"

    mini_header "Next"
    final_line "Ready" "future Script 6.5 deploy lane patch" "$YW"
    final_line "Verify log" "$VERIFY_LOG" "$BL"
    final_line "Marker" "$COMPLETED_MARKER" "$BL"
}

function init_script() {
    elevate_to_root_if_needed "$@"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    detect_root_or_sudo
    init_logging
    trap 'on_error "$LINENO"' ERR
    trap cleanup EXIT
    : > "$LOG_FILE"
    chmod 600 "$LOG_FILE" 2>/dev/null || true
    clear 2>/dev/null || printf '\033c'
    header_info
    show_script_version
    validate_dependencies
}

function main() {
    init_script "$@"
    validate_handoff_gates
    load_project_context
    print_plan
    prepare_env
    prepare_n8n_directories
    sync_n8n_template
    validate_static_safety
    validate_compose_config
    mark_template_preflight_ready
    print_summary
}

main "$@"
