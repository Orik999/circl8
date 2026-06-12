#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Project Circl8 - Script 6.3 Authentik Prep
# =========================================================
# Lane 5: hard gate, preflight, deploy readiness validation,
# Authentik ForwardAuth provider/application/Embedded Outpost automation,
# final ForwardAuth verification, verify report, and completion marker.

# --- COLOR VARIABLES ---
YW="$(printf '\033[33m')"
YL="$(printf '\033[1;93m')"
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

SCRIPT_SOURCE="6.3-authentikBootstrap.sh"
SCRIPT_VERSION="v1.0.13"
SCRIPT_UPDATED="2026-06-11"
SCRIPT_BUILD="authentik-fresh-folder-prep-fix"

# --- GLOBAL SETTINGS ---
T="15"
UI_LABEL_WIDTH="25"

SCRIPT62_MARKER="/root/.circl8-admin-ui-completed"
SCRIPT63_MARKER="/root/.circl8-authentik-completed"

LOG_FILE="/var/log/circl8-authentik.log"
VERIFY_LOG="/var/log/circl8-authentik-verify.log"
FAILURE_LOG=""
DEPLOY_OUTPUT_LOG=""
RUNTIME_LOG_FILE=""
SUDO_CMD=""
DOCKER_NEEDS_SUDO="no"

SCRIPT62_STATUS="unknown"
SCRIPT62_VERSION="unknown"
SCRIPT62_VERIFY_STATUS="unknown"
SCRIPT62_READY_FOR_SCRIPT63="unknown"
SCRIPT62_SELECTED_ADMIN_UI="unknown"
SCRIPT62_BOOTSTRAP_ACCESS="unknown"
SCRIPT62_DOCKER_DIR=""
SCRIPT62_COMPOSE_DIR=""
SCRIPT62_SECRETS_DIR=""

DOCKER_DIR=""
COMPOSE_DIR=""
SECRETS_DIR=""
ENV_FILE=""
DOMAIN_VALUE=""
AUTHENTIK_ROUTE_HOST=""
AUTHENTIK_EXTERNAL_URL=""
TRAEFIK_DYNAMIC_CONFIG_FILE=""
AUTHENTIK_COMPOSE_FILE="05-authentik-compose.yml"
AUTHENTIK_COMPOSE_STATUS="unknown"
AUTHENTIK_COMPOSE_LOCATION="will install later"

DOCKER_COMMAND_STATUS="unknown"
DOCKER_COMPOSE_STATUS="unknown"
DOCKER_SERVICE_STATUS="unknown"
CONTAINERD_SERVICE_STATUS="unknown"
DOCKER_API_STATUS="unknown"
DOCKER_DIR_STATUS="unknown"
COMPOSE_DIR_STATUS="unknown"
SECRETS_DIR_STATUS="unknown"
ENV_FILE_STATUS="unknown"
T2_PROXY_STATUS="unknown"
TRAEFIK_STATUS="unknown"
TRAEFIK_DYNAMIC_STATUS="unknown"
TRAEFIK_AUTHENTIK_REFERENCES="unknown"

SCRIPT63_SETUP_MODE="fresh-install"
AUTHENTIK_EXISTING="not detected"
AUTHENTIK_MARKER_STATUS="not present"
AUTHENTIK_CONTAINER_STATUS="not detected"
SCRIPT63_LANE="prep"
SCRIPT63_STATUS="prep-pending"
SCRIPT63_VERIFY_STATUS="PENDING"
SCRIPT63_DEPLOYMENT_STATUS="not-run"
SCRIPT63_MARKER_WRITTEN="no"
SCRIPT63_SECRET_STORAGE="env-only"
SCRIPT63_READY_FOR_DEPLOYMENT_LANE="no"
SCRIPT63_READY_FOR_AUTOMATION_LANE="no"
SCRIPT63_READY_FOR_SCRIPT64="no"
SCRIPT63_AUTOMATION_MODE="fresh-automation"

ENV_STATUS="unknown"
ENV_BACKUP_STATUS="not-needed"
ENV_BACKUP_PATH=""
ENV_KEYS_ADDED=0
ENV_KEYS_PRESERVED=0
ENV_APPEND_LINES=()

AUTHENTIK_SECRET_KEY_STATUS="unknown"
AUTHENTIK_POSTGRES_PASSWORD_STATUS="unknown"
AUTHENTIK_BOOTSTRAP_EMAIL_STATUS="unknown"
AUTHENTIK_BOOTSTRAP_PASSWORD_STATUS="unknown"
AUTHENTIK_BOOTSTRAP_TOKEN_STATUS="unknown"
AUTHENTIK_ROUTE_STATUS="unknown"
SMTP_STATUS="not-configured"

AUTHENTIK_APPDATA_DIR=""
AUTHENTIK_POSTGRESQL_DIR=""
AUTHENTIK_MEDIA_DIR=""
AUTHENTIK_TEMPLATES_DIR=""
AUTHENTIK_CERTS_DIR=""
AUTHENTIK_APPDATA_DIR_STATUS="unknown"
AUTHENTIK_POSTGRESQL_DIR_STATUS="unknown"
AUTHENTIK_MEDIA_DIR_STATUS="unknown"
AUTHENTIK_TEMPLATES_DIR_STATUS="unknown"
AUTHENTIK_CERTS_DIR_STATUS="unknown"
AUTHENTIK_DIR_OWNER_GROUP="unknown"
AUTHENTIK_APPDATA_DIR_PLAN="unknown"
AUTHENTIK_POSTGRESQL_DIR_PLAN="unknown"
AUTHENTIK_MEDIA_DIR_PLAN="unknown"
AUTHENTIK_TEMPLATES_DIR_PLAN="unknown"
AUTHENTIK_CERTS_DIR_PLAN="unknown"

COMPOSE_PROJECT_NAME="circl8-authentik"
AUTHENTIK_RAW_COMPOSE_URL="https://raw.githubusercontent.com/Orik999/circl8/refs/heads/main/docker/05-authentik-compose.yml"
AUTHENTIK_COMPOSE_RUNTIME_PATH=""
AUTHENTIK_COMPOSE_SOURCE_STATUS="unknown"
AUTHENTIK_COMPOSE_CONFIG_STATUS="unknown"
AUTHENTIK_COMPOSE_FILE_OWNER_GROUP="unknown"
AUTHENTIK_COMPOSE_FILE_MODE="unknown"
AUTHENTIK_COMPOSE_FILE_READABLE="no"
DOCKER_READINESS_STATUS="unknown"
DOCKER_DAEMON_READINESS_STATUS="unknown"
DOCKER_COMPOSE_READINESS_STATUS="unknown"
DOCKER_NETWORKS_READINESS_STATUS="unknown"
AUTHENTIK_DEPLOYMENT_STATUS="not-run"
AUTHENTIK_POSTGRES_STATUS="unknown"
AUTHENTIK_SERVER_STATUS="unknown"
AUTHENTIK_WORKER_STATUS="unknown"
AUTHENTIK_INTERNAL_API_STATUS="unknown"
AUTHENTIK_API_ACCESS_STATUS="unknown"
AUTHENTIK_AUTHENTICATION_FLOW_STATUS="not-run"
AUTHENTIK_AUTHORIZATION_FLOW_STATUS="not-run"
AUTHENTIK_INVALIDATION_FLOW_STATUS="not-run"
AUTHENTIK_PROVIDER_STATUS="not-run"
AUTHENTIK_PROVIDER_PK=""
AUTHENTIK_PROVIDER_MODE="forward_domain"
AUTHENTIK_APPLICATION_STATUS="not-run"
AUTHENTIK_APPLICATION_SLUG="circl8-traefik-forwardauth"
AUTHENTIK_OUTPOST_STATUS="not-run"
AUTHENTIK_OUTPOST_PK=""
FORWARD_AUTH_STATUS="not-run"
INTERNAL_FORWARD_AUTH_STATUS="not-run"
TRAEFIK_FORWARD_AUTH_STATUS="not-run"
TRAEFIK_RESOLUTION_STATUS="not-run"
TRAEFIK_FORWARD_AUTH_ERRORS="unknown"
AUTHENTIK_BOOTSTRAP_TOKEN_VALUE=""
AUTHENTIK_API_TOKEN_VALUE=""
PROGRESS_LINE_ACTIVE="no"


# =========================================================
#  OUTPUT HELPERS
# =========================================================
function header_info() {
cat <<'BANNER'

   ██████╗    ██████╗      █████╗ ██╗   ██╗████████╗██╗  ██╗███████╗███╗   ██╗████████╗██╗██╗  ██╗
  ██╔════╝    ╚════██╗    ██╔══██╗██║   ██║╚══██╔══╝██║  ██║██╔════╝████╗  ██║╚══██╔══╝██║██║ ██╔╝
  ███████╗     █████╔╝    ███████║██║   ██║   ██║   ███████║█████╗  ██╔██╗ ██║   ██║   ██║█████╔╝
  ██╔═══██╗    ╚═══██╗    ██╔══██║██║   ██║   ██║   ██╔══██║██╔══╝  ██║╚██╗██║   ██║   ██║██╔═██╗
  ╚██████╔╝██╗██████╔╝    ██║  ██║╚██████╔╝   ██║   ██║  ██║███████╗██║ ╚████║   ██║   ██║██║  ██╗
   ╚═════╝ ╚═╝╚═════╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝   ╚═╝╚═╝  ╚═╝

BANNER
}

function show_script_version() {
    echo -e "${GN}SCRIPT VERSION: ${SCRIPT_VERSION} | UPDATED: ${SCRIPT_UPDATED} | BUILD: ${SCRIPT_BUILD}${CL}"
    echo -e "${BL}SOURCE: ${SCRIPT_SOURCE}${CL}"
}

function section() {
    echo ""
    echo -e "${BORDER}"
    echo -e "${BL}$1${CL}"
    echo -e "${BORDER}"
}

function section_flash_success() {
    echo ""
    echo -e "${BORDER}"
    echo -e "${GN}${CLF}$1${CL}"
    echo -e "${BORDER}"
}

function mini_header() {
    echo ""
    echo -e "${YW}$1:${CL}"
}

function mini_header_compact() {
    echo -e "${YW}$1:${CL}"
}

function status_color_for_value() {
    local value="${1:-unknown}"
    case "$value" in
        ready|present|completed|PASS|yes|running|active|responsive|detected|configured|updated|attached|generated|preserved|fixed|valid|installed|healthy|settled|written|DEPLOYED|SKELETON|PREPARED|fresh\ install|fresh-install|fresh-automation|rerun/update|rerun-update|not\ written|not\ run|not-run|not\ used|planned|unchanged|stored\ root-only|env\ only|env-only|created|not\ needed|not-needed|reused|partial|will\ create|will-create|will\ generate|will-generate)
            printf '%s' "$GN"
            ;;
        warning|skipped|unknown|not\ detected|not\ verified|will\ install\ later|not\ present|not\ configured|reuse\ if\ present|missing|preserve\ in\ later\ lane|planned\ for\ later\ lane)
            printf '%s' "$YW"
            ;;
        fail|FAIL|failed|missing|no|not-ready|not\ ready)
            printf '%s' "$RD"
            ;;
        *)
            printf '%s' "$GN"
            ;;
    esac
}

function ui_display_value() {
    local value="${1:-unknown}"
    case "$value" in
        fresh-install) printf 'fresh install' ;;
        fresh-automation) printf 'fresh automation' ;;
        rerun-update) printf 'rerun/update' ;;
        not-run) printf 'not run' ;;
        not-detected) printf 'not detected' ;;
        not-present) printf 'not present' ;;
        not-written) printf 'not written' ;;
        will-install-later) printf 'will install later' ;;
        will-generate) printf 'will generate' ;;
        will-create) printf 'will create' ;;
        env-only) printf '.env only' ;;
        not-needed) printf 'not needed' ;;
        not-configured) printf 'not configured' ;;
        pending-lane-5) printf 'pending next step' ;;
        deployed-auth-not-configured) printf 'deployed, Auth not configured' ;;
        *) printf '%s' "$value" ;;
    esac
}

function rerun_ui_color() {
    local value="${1:-unknown}"
    if [ "${SCRIPT63_SETUP_MODE:-fresh-install}" == "rerun-update" ]; then
        case "$value" in
            rerun-update|rerun/update|detected|preserved|preserve|refresh|redeploy\ Authentik\ only|update\ if\ needed|preserve/attach\ provider|refresh\ on\ success)
                printf '%s' "$YW"
                return 0
                ;;
        esac
    fi
    status_color_for_value "$value"
}

function prep_value_color() {
    local value="${1:-unknown}"
    if [ "${SCRIPT63_SETUP_MODE:-fresh-install}" == "rerun-update" ] && [ "$value" == "preserved" ]; then
        printf '%s' "$YW"
        return 0
    fi
    status_color_for_value "$value"
}

function aligned_status_line() {
    local label="$1" value="${2:-unknown}" color="${3:-}" width="${4:-$UI_LABEL_WIDTH}" display_value=""
    [ -n "$value" ] || value="unknown"
    [ -n "$color" ] || color="$(status_color_for_value "$value")"
    display_value="$(ui_display_value "$value")"
    printf '%b%-*s%b %b%s%b\n' "$BL" "$width" "${label}:" "$CL" "$color" "$display_value" "$CL"
}

function final_line() {
    local label="$1" value="${2:-unknown}" color="${3:-}" display_value=""
    [ -n "$value" ] || value="unknown"
    [ -n "$color" ] || color="$(status_color_for_value "$value")"
    display_value="$(ui_display_value "$value")"
    printf '%b%-*s%b %b%s%b\n' "$BL" "$UI_LABEL_WIDTH" "${label}:" "$CL" "$color" "$display_value" "$CL"
}

function deploy_status_line() {
    local label="$1" value="${2:-unknown}" color="${3:-}" width="${4:-$UI_LABEL_WIDTH}" display_value="" tick_prefix_width="2" effective_width=""
    [ -n "$value" ] || value="unknown"
    [ -n "$color" ] || color="$(status_color_for_value "$value")"
    effective_width=$((width - tick_prefix_width))
    [ "$effective_width" -gt 0 ] || effective_width="$width"
    display_value="$(ui_display_value "$value")"
    printf '%b %b%-*s%b %b%s%b\n' "$CM" "$BL" "$effective_width" "${label}:" "$CL" "$color" "$display_value" "$CL"
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

function clear_transient_line() {
    tty_print "${BFR}"
}

function progress_line() {
    PROGRESS_LINE_ACTIVE="yes"
    # Progress lines use stdout instead of direct /dev/tty so they stay ordered with
    # section headers written through tee-based logging. This prevents stale progress
    # text from merging with borders or later rows.
    printf '%b' "${BFR}${YW}* $1...${CL}"
}

function clear_progress_line() {
    if [ "${PROGRESS_LINE_ACTIVE:-no}" == "yes" ]; then
        printf '%b' "${BFR}"
        PROGRESS_LINE_ACTIVE="no"
    else
        clear_transient_line
    fi
}

function msg_info() { echo -ne " ${HOLD} ${YW}$1...${CL}"; }
function msg_ok() { echo -e "${BFR} ${CM} ${GN}$1${CL}"; }
function msg_warn() { echo -e "${BFR} ${WARN} ${YW}$1${CL}"; }
function msg_error() { echo -e "${BFR} ${CROSS} ${RD}$1${CL}"; exit 1; }

# =========================================================
#  LOGGING / CLEANUP
# =========================================================
function detect_root_or_sudo() {
    if [ "${EUID}" -eq 0 ]; then
        SUDO_CMD=""
    else
        SUDO_CMD="sudo"
    fi
}

function validate_sudo_access() {
    if [ -n "$SUDO_CMD" ]; then
        if "$SUDO_CMD" -n true >/dev/null 2>&1; then
            return 0
        fi
        "$SUDO_CMD" -v >/dev/null 2>&1 || msg_error "Sudo authentication failed. Script cancelled."
    fi
}

function init_logging() {
    if [ -n "$SUDO_CMD" ]; then
        RUNTIME_LOG_FILE="$(mktemp /tmp/circl8-authentik-log.XXXXXX)"
        exec > >(tee -a "$RUNTIME_LOG_FILE") 2>&1
    else
        RUNTIME_LOG_FILE="$LOG_FILE"
        exec > >(tee -a "$LOG_FILE") 2>&1
    fi
}

function copy_runtime_log() {
    if [ -n "${SUDO_CMD:-}" ] && [ -n "${RUNTIME_LOG_FILE:-}" ] && [ -s "$RUNTIME_LOG_FILE" ]; then
        "$SUDO_CMD" cp "$RUNTIME_LOG_FILE" "$LOG_FILE" 2>/dev/null || true
    fi
}

function cleanup() {
    local exit_code="$?"
    copy_runtime_log
    exit "$exit_code"
}

function on_error() {
    local line_no="$1"
    echo -e "${RD}ERROR:${CL} Script failed at line ${line_no}. Check ${LOG_FILE}"
}

function init_script() {
    detect_root_or_sudo
    validate_sudo_access
    init_logging
    trap 'on_error "$LINENO"' ERR
    trap cleanup EXIT

    clear
    header_info
    show_script_version
}

# =========================================================
#  ROOT / MARKER READ HELPERS
# =========================================================
function root_path_exists() {
    local path="$1"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" test -e "$path"
    else
        test -e "$path"
    fi
}

function root_file_not_empty() {
    local path="$1"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" test -s "$path"
    else
        test -s "$path"
    fi
}

function root_read_file() {
    local path="$1"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" cat "$path"
    else
        cat "$path"
    fi
}

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
    [ -n "${ENV_FILE:-}" ] || return 0
    root_path_exists "$ENV_FILE" || return 0
    root_read_file "$ENV_FILE" 2>/dev/null | awk -F= -v k="$key" '
        $1 == k {
            val=$0
            sub("^[^=]*=", "", val)
            gsub(/^"|"$/, "", val)
            print val
            exit
        }
    ' || true
}

# =========================================================
#  COMMAND / DOCKER READ HELPERS
# =========================================================
function systemctl_is_active_value() {
    local service="$1"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" systemctl is-active "$service" 2>/dev/null || true
    else
        systemctl is-active "$service" 2>/dev/null || true
    fi
}

function docker_cmd() {
    if [ "$DOCKER_NEEDS_SUDO" == "yes" ]; then
        "$SUDO_CMD" docker "$@"
    else
        docker "$@"
    fi
}

function detect_docker_access() {
    if docker info >/dev/null 2>&1; then
        DOCKER_NEEDS_SUDO="no"
        DOCKER_API_STATUS="responsive"
        return 0
    fi

    if [ -n "$SUDO_CMD" ] && "$SUDO_CMD" docker info >/dev/null 2>&1; then
        DOCKER_NEEDS_SUDO="yes"
        DOCKER_API_STATUS="responsive"
        return 0
    fi

    DOCKER_API_STATUS="not ready"
    return 1
}

function docker_container_exists_by_name() {
    local name="$1"
    docker_cmd ps -a --format '{{.Names}}' 2>/dev/null | grep -Fxq "$name"
}

function docker_project_exists() {
    docker_cmd ps -a --filter "label=com.docker.compose.project=circl8-authentik" --format '{{.Names}}' 2>/dev/null | grep -q .
}

function docker_container_running_by_name() {
    local name="$1"
    docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -Fxq "$name"
}

# =========================================================
#  INPUT HELPERS
# =========================================================
function flush_input_buffer() {
    local junk="" i=""
    [ -r /dev/tty ] || return 0
    for i in {1..20}; do
        if ! IFS= read -rsn1 -t 0.02 junk < /dev/tty; then
            break
        fi
    done
}

function yes_no_label() {
    local value="$1"
    if [[ "$value" =~ ^[Yy]$ ]]; then
        printf 'yes'
    else
        printf 'no'
    fi
}

function tty_read_yes_no_blocking() {
    local prompt="$1" default="$2" default_label="Y/n" key=""
    [[ "$default" =~ ^[Nn]$ ]] && default_label="y/N"
    flush_input_buffer

    while true; do
        tty_print "${BFR}${YW}${prompt} (${default_label}): ${CL}"
        if [ -r /dev/tty ]; then
            IFS= read -rsn1 key < /dev/tty || true
        else
            IFS= read -rsn1 key || true
        fi
        if [[ -z "$key" ]]; then
            tty_print "${BFR}"
            echo "$default"
            flush_input_buffer
            return 0
        elif [[ "$key" =~ ^[YyNn]$ ]]; then
            tty_print "${BFR}"
            echo "$key"
            flush_input_buffer
            return 0
        fi
    done
}

function timed_yes_no_value_only() {
    local prompt="$1" default="$2" answer="" key="" default_label="Y/n" deadline="" now="" remaining=""
    [[ "$default" =~ ^[Nn]$ ]] && default_label="y/N"
    flush_input_buffer
    deadline=$(( $(date +%s) + T ))

    while true; do
        now=$(date +%s)
        remaining=$(( deadline - now ))
        if [ "$remaining" -le 0 ]; then
            answer="$default"
            break
        fi
        tty_print "${BFR}${YW}${prompt} (${default_label}) [${remaining}s]${CL} "
        if [ -r /dev/tty ]; then
            if IFS= read -rsn1 -t 1 key < /dev/tty; then
                if [[ "$key" == " " ]]; then answer="$(tty_read_yes_no_blocking "$prompt" "$default")"; break; fi
                if [[ "$key" =~ ^[YyNn]$ ]]; then answer="$key"; break; fi
                if [[ -z "$key" ]]; then answer="$default"; break; fi
            fi
        else
            if IFS= read -rsn1 -t 1 key; then
                if [[ "$key" == " " ]]; then answer="$(tty_read_yes_no_blocking "$prompt" "$default")"; break; fi
                if [[ "$key" =~ ^[YyNn]$ ]]; then answer="$key"; break; fi
                if [[ -z "$key" ]]; then answer="$default"; break; fi
            fi
        fi
    done

    [ -z "$answer" ] && answer="$default"
    tty_print "${BFR}"
    flush_input_buffer
    echo "$answer"
}

function tty_read_line_blocking() {
    local prompt="$1" answer=""
    flush_input_buffer
    tty_print "${YW}${prompt}${CL} "
    if [ -r /dev/tty ]; then
        IFS= read -r answer < /dev/tty || true
    else
        IFS= read -r answer || true
    fi
    flush_input_buffer
    printf '%s' "$answer"
}

# =========================================================
#  REPORT / FAILURE HELPERS
# =========================================================
function write_text_root_file() {
    local path="$1"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" tee "$path" >/dev/null
    else
        cat > "$path"
    fi
}

function write_verify_report() {
    {
        printf '%s\n' "SCRIPT63_LANE=${SCRIPT63_LANE}"
        printf '%s\n' "SCRIPT63_STATUS=${SCRIPT63_STATUS}"
        printf '%s\n' "SCRIPT63_VERSION=${SCRIPT_VERSION}"
        printf '%s\n' "SCRIPT63_BUILD=${SCRIPT_BUILD}"
        printf '%s\n' "SCRIPT63_VERIFY_STATUS=${SCRIPT63_VERIFY_STATUS}"
        printf '%s\n' "SCRIPT63_DEPLOYMENT=${SCRIPT63_DEPLOYMENT_STATUS}"
        printf '%s\n' "SCRIPT63_MARKER_WRITTEN=${SCRIPT63_MARKER_WRITTEN}"
        printf '%s\n' "SCRIPT63_SECRET_STORAGE=${SCRIPT63_SECRET_STORAGE}"
        printf '%s\n' "SCRIPT62_STATUS=${SCRIPT62_STATUS}"
        printf '%s\n' "SCRIPT62_VERIFY_STATUS=${SCRIPT62_VERIFY_STATUS}"
        printf '%s\n' "SCRIPT62_READY_FOR_SCRIPT63=${SCRIPT62_READY_FOR_SCRIPT63}"
        printf '%s\n' "SCRIPT63_SETUP_MODE=${SCRIPT63_AUTOMATION_MODE}"
        printf '%s\n' "SCRIPT63_DEPLOY_SETUP_MODE=${SCRIPT63_SETUP_MODE}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_EXISTING=${AUTHENTIK_EXISTING}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE=${AUTHENTIK_COMPOSE_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE_FILE=${AUTHENTIK_COMPOSE_FILE}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE_RUNTIME_PATH=${AUTHENTIK_COMPOSE_RUNTIME_PATH}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE_STATUS=${AUTHENTIK_COMPOSE_SOURCE_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE_CONFIG=${AUTHENTIK_COMPOSE_CONFIG_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE_FILE_OWNER=${AUTHENTIK_COMPOSE_FILE_OWNER_GROUP}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE_FILE_MODE=${AUTHENTIK_COMPOSE_FILE_MODE}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE_FILE_READABLE=${AUTHENTIK_COMPOSE_FILE_READABLE}"
        printf '%s\n' "SCRIPT63_TRAEFIK_AUTHENTIK_REFERENCES=${TRAEFIK_AUTHENTIK_REFERENCES}"
        printf '%s\n' "SCRIPT63_ENV_STATUS=${ENV_STATUS}"
        printf '%s\n' "SCRIPT63_ENV_BACKUP=${ENV_BACKUP_STATUS}"
        printf '%s\n' "SCRIPT63_ENV_KEYS_ADDED=${ENV_KEYS_ADDED}"
        printf '%s\n' "SCRIPT63_ENV_KEYS_PRESERVED=${ENV_KEYS_PRESERVED}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_SECRET_KEY=${AUTHENTIK_SECRET_KEY_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_POSTGRES_PASSWORD=${AUTHENTIK_POSTGRES_PASSWORD_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_BOOTSTRAP_EMAIL=${AUTHENTIK_BOOTSTRAP_EMAIL_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_BOOTSTRAP_PASSWORD=${AUTHENTIK_BOOTSTRAP_PASSWORD_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_BOOTSTRAP_TOKEN=${AUTHENTIK_BOOTSTRAP_TOKEN_STATUS}"
        printf '%s\n' "SCRIPT63_SMTP_STATUS=${SMTP_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_APPDATA_DIR=${AUTHENTIK_APPDATA_DIR_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_POSTGRESQL_DIR=${AUTHENTIK_POSTGRESQL_DIR_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_MEDIA_DIR=${AUTHENTIK_MEDIA_DIR_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_TEMPLATES_DIR=${AUTHENTIK_TEMPLATES_DIR_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_CERTS_DIR=${AUTHENTIK_CERTS_DIR_STATUS}"
        printf '%s\n' "SCRIPT63_READY_FOR_DEPLOYMENT_LANE=${SCRIPT63_READY_FOR_DEPLOYMENT_LANE}"
        printf '%s\n' "SCRIPT63_READY_FOR_AUTOMATION_LANE=${SCRIPT63_READY_FOR_AUTOMATION_LANE}"
        printf '%s\n' "SCRIPT63_DOCKER_READINESS=${DOCKER_READINESS_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_DEPLOYMENT=${AUTHENTIK_DEPLOYMENT_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_POSTGRES=${AUTHENTIK_POSTGRES_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_SERVER=${AUTHENTIK_SERVER_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_WORKER=${AUTHENTIK_WORKER_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_INTERNAL_API=${AUTHENTIK_INTERNAL_API_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_API_ACCESS=${AUTHENTIK_API_ACCESS_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_AUTHENTICATION_FLOW=${AUTHENTIK_AUTHENTICATION_FLOW_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_AUTHORIZATION_FLOW=${AUTHENTIK_AUTHORIZATION_FLOW_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_INVALIDATION_FLOW=${AUTHENTIK_INVALIDATION_FLOW_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_PROVIDER=${AUTHENTIK_PROVIDER_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_PROVIDER_PK=${AUTHENTIK_PROVIDER_PK}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_PROVIDER_MODE=${AUTHENTIK_PROVIDER_MODE}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_APPLICATION=${AUTHENTIK_APPLICATION_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_APPLICATION_SLUG=${AUTHENTIK_APPLICATION_SLUG}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_OUTPOST=${AUTHENTIK_OUTPOST_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_OUTPOST_PK=${AUTHENTIK_OUTPOST_PK}"
        printf '%s\n' "SCRIPT63_FORWARD_AUTH=${FORWARD_AUTH_STATUS}"
        printf '%s\n' "SCRIPT63_INTERNAL_FORWARD_AUTH=${INTERNAL_FORWARD_AUTH_STATUS}"
        printf '%s\n' "SCRIPT63_TRAEFIK_FORWARD_AUTH=${TRAEFIK_FORWARD_AUTH_STATUS}"
        printf '%s\n' "SCRIPT63_TRAEFIK_RESOLUTION=${TRAEFIK_RESOLUTION_STATUS}"
        printf '%s\n' "SCRIPT63_TRAEFIK_FORWARD_AUTH_ERRORS=${TRAEFIK_FORWARD_AUTH_ERRORS}"
        printf '%s\n' "SCRIPT63_READY_FOR_SCRIPT64=${SCRIPT63_READY_FOR_SCRIPT64}"
        printf '%s\n' "SCRIPT63_COMPLETION_MARKER_PATH=${SCRIPT63_MARKER}"
    } | write_text_root_file "$VERIFY_LOG"
}

function preserve_failure_log() {
    local reason="${1:-Authentik deployment checks failed}"
    local ts=""
    ts="$(date +%Y%m%d-%H%M%S)"
    FAILURE_LOG="/var/log/circl8-authentik-deploy-failed-${ts}.log"
    {
        echo "$reason"
        [ -n "${DEPLOY_OUTPUT_LOG:-}" ] && [ -s "$DEPLOY_OUTPUT_LOG" ] && cat "$DEPLOY_OUTPUT_LOG"
    } | write_text_root_file "$FAILURE_LOG"
}


function init_deploy_output_log() {
    if [ -z "${DEPLOY_OUTPUT_LOG:-}" ]; then
        DEPLOY_OUTPUT_LOG="$(mktemp /tmp/circl8-authentik-deploy.XXXXXX)"
    fi
}

function append_deploy_log() {
    init_deploy_output_log
    printf '%s\n' "$*" >> "$DEPLOY_OUTPUT_LOG"
}

function append_file_to_deploy_log_sanitized() {
    local file="$1"
    init_deploy_output_log
    [ -s "$file" ] || return 0
    sed -E '/(PASSWORD|TOKEN|SECRET_KEY|AUTHENTIK_EMAIL__PASSWORD|AUTHENTIK_POSTGRES_PASSWORD|AUTHENTIK_BOOTSTRAP)/Id' "$file" >> "$DEPLOY_OUTPUT_LOG" || true
}

function root_copy_regular_file() {
    local src="$1" dest="$2"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" cp -f "$src" "$dest"
    else
        cp -f "$src" "$dest"
    fi
}

function root_set_path_owner_group() {
    local path="$1" owner_group="$2"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" chown "$owner_group" "$path"
    else
        chown "$owner_group" "$path"
    fi
}

function root_set_path_mode() {
    local path="$1" mode="$2"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" chmod "$mode" "$path"
    else
        chmod "$mode" "$path"
    fi
}

function resolve_compose_file_owner_group() {
    local owner_group=""
    owner_group="$(root_stat_owner_group "$COMPOSE_DIR")"
    if [ -z "$owner_group" ] || [ "$owner_group" == ":" ]; then
        owner_group="$(root_stat_owner_group "$DOCKER_DIR")"
    fi
    if [ -z "$owner_group" ] || [ "$owner_group" == ":" ]; then
        append_deploy_log "Runtime compose file owner/group could not be resolved from compose/docker directory."
        return 1
    fi
    AUTHENTIK_COMPOSE_FILE_OWNER_GROUP="$owner_group"
    return 0
}

function verify_runtime_compose_file_access() {
    local current_owner_group="" current_mode=""
    AUTHENTIK_COMPOSE_FILE_READABLE="no"
    if ! root_file_not_empty "$AUTHENTIK_COMPOSE_RUNTIME_PATH"; then
        append_deploy_log "Runtime Authentik compose file is missing or empty after install."
        return 1
    fi

    current_owner_group="$(root_stat_owner_group "$AUTHENTIK_COMPOSE_RUNTIME_PATH")"
    current_mode="$(root_stat_mode "$AUTHENTIK_COMPOSE_RUNTIME_PATH")"
    AUTHENTIK_COMPOSE_FILE_OWNER_GROUP="$current_owner_group"
    AUTHENTIK_COMPOSE_FILE_MODE="$current_mode"

    if [ "$current_mode" != "644" ]; then
        append_deploy_log "Runtime Authentik compose mode is ${current_mode}; expected 644."
        return 1
    fi

    # Mode 644 with the project owner/group makes the file readable by the Docker project user
    # and prevents root-only 600 files from breaking docker compose config on rerun.
    AUTHENTIK_COMPOSE_FILE_READABLE="yes"
    return 0
}

function repair_runtime_compose_file_permissions() {
    local desired_owner_group="" current_owner_group="" current_mode=""
    resolve_compose_file_owner_group || return 1
    desired_owner_group="$AUTHENTIK_COMPOSE_FILE_OWNER_GROUP"

    current_owner_group="$(root_stat_owner_group "$AUTHENTIK_COMPOSE_RUNTIME_PATH")"
    if [ "$current_owner_group" != "$desired_owner_group" ]; then
        root_set_path_owner_group "$AUTHENTIK_COMPOSE_RUNTIME_PATH" "$desired_owner_group" || return 1
    fi

    current_mode="$(root_stat_mode "$AUTHENTIK_COMPOSE_RUNTIME_PATH")"
    if [ "$current_mode" != "644" ]; then
        root_set_path_mode "$AUTHENTIK_COMPOSE_RUNTIME_PATH" 644 || return 1
    fi

    verify_runtime_compose_file_access
}

function root_download_url_to_file() {
    local url="$1" dest="$2" tmp=""
    tmp="$(mktemp /tmp/circl8-authentik-compose.XXXXXX)"
    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL "$url" -o "$tmp" >>"$DEPLOY_OUTPUT_LOG" 2>&1; then
            rm -f "$tmp"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -qO "$tmp" "$url" >>"$DEPLOY_OUTPUT_LOG" 2>&1; then
            rm -f "$tmp"
            return 1
        fi
    else
        rm -f "$tmp"
        append_deploy_log "Neither curl nor wget is available for compose download."
        return 1
    fi
    if ! [ -s "$tmp" ]; then
        rm -f "$tmp"
        append_deploy_log "Downloaded Authentik compose temporary file is empty."
        return 1
    fi
    root_copy_regular_file "$tmp" "$dest"
    rm -f "$tmp"
}

function set_prep_failure_status() {
    SCRIPT63_LANE="prep"
    SCRIPT63_STATUS="prep-failed"
    SCRIPT63_VERIFY_STATUS="FAILED"
    SCRIPT63_DEPLOYMENT_STATUS="not-run"
    AUTHENTIK_DEPLOYMENT_STATUS="not-run"
    SCRIPT63_MARKER_WRITTEN="no"
    SCRIPT63_READY_FOR_DEPLOYMENT_LANE="no"
    SCRIPT63_READY_FOR_AUTOMATION_LANE="no"
    SCRIPT63_READY_FOR_SCRIPT64="no"
}

function fail_with_verify_log() {
    local message="$1"
    clear_progress_line || true
    if [ "${SCRIPT63_LANE:-}" == "prep" ]; then
        set_prep_failure_status
    fi
    write_verify_report || true
    echo -e "${CROSS} ${RD}${message}${CL}"
    echo -e "  ${BL}Verify log:${CL} ${VERIFY_LOG}"
    exit 1
}

function fail_with_failure_log() {
    local message="$1"
    clear_progress_line || true
    if [ "${SCRIPT63_LANE:-}" == "prep" ]; then
        set_prep_failure_status
    elif [ "${SCRIPT63_LANE:-}" == "deploy" ] && [ "${SCRIPT63_DEPLOYMENT_STATUS:-}" != "completed" ]; then
        SCRIPT63_STATUS="deploy-failed"
        SCRIPT63_VERIFY_STATUS="FAILED"
        SCRIPT63_DEPLOYMENT_STATUS="failed"
        SCRIPT63_READY_FOR_AUTOMATION_LANE="no"
    elif [ "${SCRIPT63_LANE:-}" == "automation" ]; then
        SCRIPT63_STATUS="automation-failed"
        SCRIPT63_VERIFY_STATUS="FAILED"
        SCRIPT63_MARKER_WRITTEN="no"
        SCRIPT63_READY_FOR_SCRIPT64="no"
    fi
    preserve_failure_log "$message" || true
    write_verify_report || true
    echo -e "${CROSS} ${RD}${message}${CL}"
    echo -e "  ${BL}Verify log:${CL}  ${VERIFY_LOG}"
    echo -e "  ${BL}Failure log:${CL} ${FAILURE_LOG}"
    exit 1
}

function write_completion_marker() {
    local tmp_file=""
    tmp_file="$(mktemp /tmp/circl8-authentik-marker.XXXXXX)"
    {
        printf '%s\n' "SCRIPT63_STATUS=completed"
        printf '%s\n' "SCRIPT63_VERSION=${SCRIPT_VERSION}"
        printf '%s\n' "SCRIPT63_BUILD=${SCRIPT_BUILD}"
        printf '%s\n' "SCRIPT63_VERIFY_STATUS=PASS"
        printf '%s\n' "SCRIPT63_DEPLOYMENT=completed"
        printf '%s\n' "SCRIPT63_MARKER_WRITTEN=yes"
        printf '%s\n' "SCRIPT63_SECRET_STORAGE=${SCRIPT63_SECRET_STORAGE}"
        printf '%s\n' "SCRIPT63_SETUP_MODE=${SCRIPT63_AUTOMATION_MODE}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE_CONFIG=${AUTHENTIK_COMPOSE_CONFIG_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_DEPLOYMENT=${AUTHENTIK_DEPLOYMENT_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_POSTGRES=${AUTHENTIK_POSTGRES_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_SERVER=${AUTHENTIK_SERVER_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_WORKER=${AUTHENTIK_WORKER_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_INTERNAL_API=${AUTHENTIK_INTERNAL_API_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_PROVIDER=${AUTHENTIK_PROVIDER_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_PROVIDER_PK=${AUTHENTIK_PROVIDER_PK}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_PROVIDER_MODE=${AUTHENTIK_PROVIDER_MODE}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_APPLICATION=${AUTHENTIK_APPLICATION_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_APPLICATION_SLUG=${AUTHENTIK_APPLICATION_SLUG}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_OUTPOST=${AUTHENTIK_OUTPOST_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_OUTPOST_PK=${AUTHENTIK_OUTPOST_PK}"
        printf '%s\n' "SCRIPT63_FORWARD_AUTH=${FORWARD_AUTH_STATUS}"
        printf '%s\n' "SCRIPT63_INTERNAL_FORWARD_AUTH=${INTERNAL_FORWARD_AUTH_STATUS}"
        printf '%s\n' "SCRIPT63_TRAEFIK_FORWARD_AUTH=${TRAEFIK_FORWARD_AUTH_STATUS}"
        printf '%s\n' "SCRIPT63_TRAEFIK_RESOLUTION=${TRAEFIK_RESOLUTION_STATUS}"
        printf '%s\n' "SCRIPT63_TRAEFIK_FORWARD_AUTH_ERRORS=${TRAEFIK_FORWARD_AUTH_ERRORS}"
        printf '%s\n' "SCRIPT63_READY_FOR_SCRIPT64=yes"
    } > "$tmp_file"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" chmod 600 "$tmp_file"
        "$SUDO_CMD" mv -f "$tmp_file" "$SCRIPT63_MARKER"
    else
        chmod 600 "$tmp_file"
        mv -f "$tmp_file" "$SCRIPT63_MARKER"
    fi
    SCRIPT63_MARKER_WRITTEN="yes"
}

# =========================================================
#  SCRIPT 6.2 HANDOFF
# =========================================================
function validate_script62_handoff() {
    section "SCRIPT 6.2 HANDOFF"

    if ! root_path_exists "$SCRIPT62_MARKER"; then
        SCRIPT62_STATUS="missing"
        write_verify_report || true
        echo -e "${CROSS} ${RD}Script 6.2 completion marker missing.${CL}"
        aligned_status_line "Required marker" "$SCRIPT62_MARKER" "$RD"
        aligned_status_line "Verify log" "$VERIFY_LOG" "$BL"
        exit 1
    fi

    SCRIPT62_STATUS="$(marker_file_key_value "$SCRIPT62_MARKER" SCRIPT62_STATUS)"
    SCRIPT62_VERSION="$(marker_file_key_value "$SCRIPT62_MARKER" SCRIPT62_VERSION)"
    SCRIPT62_VERIFY_STATUS="$(marker_file_key_value "$SCRIPT62_MARKER" SCRIPT62_VERIFY_STATUS)"
    SCRIPT62_READY_FOR_SCRIPT63="$(marker_file_key_value "$SCRIPT62_MARKER" SCRIPT62_READY_FOR_SCRIPT63)"
    SCRIPT62_SELECTED_ADMIN_UI="$(marker_file_key_value "$SCRIPT62_MARKER" SCRIPT62_SELECTED_ADMIN_UI)"
    SCRIPT62_BOOTSTRAP_ACCESS="$(marker_file_key_value "$SCRIPT62_MARKER" SCRIPT62_BOOTSTRAP_ACCESS)"
    SCRIPT62_DOCKER_DIR="$(marker_file_key_value "$SCRIPT62_MARKER" SCRIPT62_DOCKER_DIR)"
    SCRIPT62_COMPOSE_DIR="$(marker_file_key_value "$SCRIPT62_MARKER" SCRIPT62_COMPOSE_DIR)"
    SCRIPT62_SECRETS_DIR="$(marker_file_key_value "$SCRIPT62_MARKER" SCRIPT62_SECRETS_DIR)"

    [ -n "$SCRIPT62_VERSION" ] || SCRIPT62_VERSION="unknown"
    [ -n "$SCRIPT62_SELECTED_ADMIN_UI" ] || SCRIPT62_SELECTED_ADMIN_UI="unknown"
    [ -n "$SCRIPT62_BOOTSTRAP_ACCESS" ] || SCRIPT62_BOOTSTRAP_ACCESS="unknown"

    DOCKER_DIR="$SCRIPT62_DOCKER_DIR"
    COMPOSE_DIR="$SCRIPT62_COMPOSE_DIR"
    SECRETS_DIR="$SCRIPT62_SECRETS_DIR"
    [ -z "$DOCKER_DIR" ] && DOCKER_DIR="unknown"
    [ -z "$COMPOSE_DIR" ] && COMPOSE_DIR="${DOCKER_DIR}/compose"
    [ -z "$SECRETS_DIR" ] && SECRETS_DIR="${DOCKER_DIR}/secrets"
    ENV_FILE="${DOCKER_DIR}/.env"

    mini_header "Script 6.2"
    aligned_status_line "Status" "${SCRIPT62_STATUS:-missing}" "$(status_color_for_value "${SCRIPT62_STATUS:-missing}")"
    aligned_status_line "Version" "$SCRIPT62_VERSION"
    aligned_status_line "Verification" "${SCRIPT62_VERIFY_STATUS:-missing}" "$(status_color_for_value "${SCRIPT62_VERIFY_STATUS:-missing}")"
    aligned_status_line "Ready for Script 6.3" "${SCRIPT62_READY_FOR_SCRIPT63:-missing}" "$(status_color_for_value "${SCRIPT62_READY_FOR_SCRIPT63:-missing}")"

    mini_header "Prepared environment"
    aligned_status_line "Docker dir" "$DOCKER_DIR"
    aligned_status_line "Compose dir" "$COMPOSE_DIR"
    aligned_status_line "Secrets dir" "$SECRETS_DIR"
    aligned_status_line "Selected Admin UI" "$SCRIPT62_SELECTED_ADMIN_UI"
    aligned_status_line "Admin UI bootstrap" "$SCRIPT62_BOOTSTRAP_ACCESS"

    if [ "$SCRIPT62_STATUS" != "completed" ] || [ "$SCRIPT62_VERIFY_STATUS" != "PASS" ] || [ "$SCRIPT62_READY_FOR_SCRIPT63" != "yes" ]; then
        fail_with_verify_log "Script 6.2 handoff failed."
    fi
}

# =========================================================
#  RUNTIME PREFLIGHT
# =========================================================
function command_status() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        printf 'ready'
    else
        printf 'missing'
    fi
}

function file_status() {
    local path="$1"
    if root_path_exists "$path"; then
        printf 'present'
    else
        printf 'missing'
    fi
}

function network_status() {
    local network="$1"
    if docker_cmd network inspect "$network" >/dev/null 2>&1; then
        printf 'ready'
    else
        printf 'missing'
    fi
}

function load_env_runtime_values() {
    DOMAIN_VALUE="$(env_value DOMAIN)"
    AUTHENTIK_ROUTE_HOST="$(env_value AUTHENTIK_ROUTE_HOST)"
    AUTHENTIK_EXTERNAL_URL="$(env_value AUTHENTIK_EXTERNAL_URL)"
    TRAEFIK_DYNAMIC_CONFIG_FILE="$(env_value TRAEFIK_DYNAMIC_CONFIG_FILE)"

    [ -n "$AUTHENTIK_ROUTE_HOST" ] || AUTHENTIK_ROUTE_HOST="auth.${DOMAIN_VALUE:-domain.example}"
    [ -n "$AUTHENTIK_EXTERNAL_URL" ] || AUTHENTIK_EXTERNAL_URL="https://${AUTHENTIK_ROUTE_HOST}"
    [ -n "$TRAEFIK_DYNAMIC_CONFIG_FILE" ] || TRAEFIK_DYNAMIC_CONFIG_FILE="${DOCKER_DIR}/appdata/traefik/dynamic-config.yml"
}

function check_traefik_references() {
    if ! root_file_not_empty "$TRAEFIK_DYNAMIC_CONFIG_FILE"; then
        TRAEFIK_DYNAMIC_STATUS="missing"
        TRAEFIK_AUTHENTIK_REFERENCES="missing"
        return 0
    fi

    TRAEFIK_DYNAMIC_STATUS="present"
    local dynamic_config=""
    dynamic_config="$(root_read_file "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null || true)"
    if printf '%s\n' "$dynamic_config" | grep -q 'chain-authentik' \
        && printf '%s\n' "$dynamic_config" | grep -q 'authentik-server' \
        && printf '%s\n' "$dynamic_config" | grep -Eq 'outpost\.goauthentik\.io.*/auth/traefik|outpost\.goauthentik\.io/auth/traefik'; then
        TRAEFIK_AUTHENTIK_REFERENCES="ready"
    else
        TRAEFIK_AUTHENTIK_REFERENCES="missing"
    fi
}

function runtime_preflight() {
    section "RUNTIME PREFLIGHT"

    DOCKER_COMMAND_STATUS="$(command_status docker)"
    if [ "$DOCKER_COMMAND_STATUS" == "ready" ] && docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_STATUS="ready"
    elif [ "$DOCKER_COMMAND_STATUS" == "ready" ] && [ -n "$SUDO_CMD" ] && "$SUDO_CMD" docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_STATUS="ready"
    else
        DOCKER_COMPOSE_STATUS="missing"
    fi

    DOCKER_SERVICE_STATUS="$(systemctl_is_active_value docker)"
    CONTAINERD_SERVICE_STATUS="$(systemctl_is_active_value containerd)"
    detect_docker_access || true

    DOCKER_DIR_STATUS="$(file_status "$DOCKER_DIR")"
    COMPOSE_DIR_STATUS="$(file_status "$COMPOSE_DIR")"
    SECRETS_DIR_STATUS="$(file_status "$SECRETS_DIR")"
    ENV_FILE_STATUS="$(file_status "$ENV_FILE")"

    if [ "$DOCKER_API_STATUS" == "responsive" ]; then
        T2_PROXY_STATUS="$(network_status t2_proxy)"
        if docker_container_running_by_name traefik || docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -Eq '(^|[-_])traefik($|[-_])'; then
            TRAEFIK_STATUS="running"
        else
            TRAEFIK_STATUS="not detected"
        fi
    else
        T2_PROXY_STATUS="unknown"
        TRAEFIK_STATUS="unknown"
    fi

    load_env_runtime_values
    check_traefik_references

    aligned_status_line "Docker command" "$DOCKER_COMMAND_STATUS" "$(status_color_for_value "$DOCKER_COMMAND_STATUS")"
    aligned_status_line "Docker Compose" "$DOCKER_COMPOSE_STATUS" "$(status_color_for_value "$DOCKER_COMPOSE_STATUS")"
    aligned_status_line "Docker service" "$DOCKER_SERVICE_STATUS" "$(status_color_for_value "$DOCKER_SERVICE_STATUS")"
    aligned_status_line "containerd" "$CONTAINERD_SERVICE_STATUS" "$(status_color_for_value "$CONTAINERD_SERVICE_STATUS")"
    aligned_status_line "Docker API" "$DOCKER_API_STATUS" "$(status_color_for_value "$DOCKER_API_STATUS")"
    aligned_status_line "Docker dir" "$DOCKER_DIR_STATUS" "$(status_color_for_value "$DOCKER_DIR_STATUS")"
    aligned_status_line "Compose dir" "$COMPOSE_DIR_STATUS" "$(status_color_for_value "$COMPOSE_DIR_STATUS")"
    aligned_status_line "Secrets dir" "$SECRETS_DIR_STATUS" "$(status_color_for_value "$SECRETS_DIR_STATUS")"
    aligned_status_line ".env file" "$ENV_FILE_STATUS" "$(status_color_for_value "$ENV_FILE_STATUS")"
    aligned_status_line "t2_proxy network" "$T2_PROXY_STATUS" "$(status_color_for_value "$T2_PROXY_STATUS")"
    aligned_status_line "Traefik" "$TRAEFIK_STATUS" "$(status_color_for_value "$TRAEFIK_STATUS")"

    if [ "$DOCKER_COMMAND_STATUS" != "ready" ] \
        || [ "$DOCKER_COMPOSE_STATUS" != "ready" ] \
        || [ "$DOCKER_SERVICE_STATUS" != "active" ] \
        || [ "$CONTAINERD_SERVICE_STATUS" != "active" ] \
        || [ "$DOCKER_API_STATUS" != "responsive" ] \
        || [ "$DOCKER_DIR_STATUS" != "present" ] \
        || [ "$COMPOSE_DIR_STATUS" != "present" ] \
        || [ "$SECRETS_DIR_STATUS" != "present" ] \
        || [ "$ENV_FILE_STATUS" != "present" ] \
        || [ "$T2_PROXY_STATUS" != "ready" ] \
        || [ "$TRAEFIK_STATUS" != "running" ]; then
        fail_with_verify_log "Runtime preflight failed."
    fi
}


# =========================================================
#  ENV / SECRET / FOLDER PREP HELPERS
# =========================================================
function root_dir_has_entries() {
    local path="$1"
    if ! root_path_exists "$path"; then
        return 1
    fi
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" find "$path" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .
    else
        find "$path" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null | grep -q .
    fi
}

function root_install_dir() {
    local path="$1" mode="${2:-750}"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" install -d -m "$mode" "$path"
    else
        install -d -m "$mode" "$path"
    fi
}

function root_stat_owner_group() {
    local path="$1"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" stat -c '%U:%G' "$path" 2>/dev/null || true
    else
        stat -c '%U:%G' "$path" 2>/dev/null || true
    fi
}

function root_stat_mode() {
    local path="$1"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" stat -c '%a' "$path" 2>/dev/null || true
    else
        stat -c '%a' "$path" 2>/dev/null || true
    fi
}

function root_set_dir_owner_group() {
    local path="$1" owner_group="$2"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" chown "$owner_group" "$path"
    else
        chown "$owner_group" "$path"
    fi
}

function root_set_dir_mode() {
    local path="$1" mode="$2"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" chmod "$mode" "$path"
    else
        chmod "$mode" "$path"
    fi
}

function resolve_authentik_dir_owner_group() {
    AUTHENTIK_DIR_OWNER_GROUP="$(root_stat_owner_group "$DOCKER_DIR")"
    if [ -z "$AUTHENTIK_DIR_OWNER_GROUP" ] || [ "$AUTHENTIK_DIR_OWNER_GROUP" == ":" ]; then
        AUTHENTIK_DIR_OWNER_GROUP="$(root_stat_owner_group "${DOCKER_DIR}/appdata")"
    fi
    if [ -z "$AUTHENTIK_DIR_OWNER_GROUP" ] || [ "$AUTHENTIK_DIR_OWNER_GROUP" == ":" ]; then
        append_deploy_log "Authentik folder owner/group could not be detected from Docker project directory or appdata directory."
        fail_with_failure_log "Docker project directory owner/group could not be detected."
    fi
}

function root_write_test_dir() {
    local path="$1"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" sh -c 't="$1/.circl8-write-test.$$"; : > "$t" && rm -f "$t"' sh "$path"
    else
        local test_file="${path}/.circl8-write-test.$$"
        : > "$test_file" && rm -f "$test_file"
    fi
}

function root_copy_preserve() {
    local src="$1" dest="$2"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" cp -p "$src" "$dest"
    else
        cp -p "$src" "$dest"
    fi
}

function root_append_line_to_file() {
    local path="$1" line="$2"
    if [ -n "$SUDO_CMD" ]; then
        printf '%s\n' "$line" | "$SUDO_CMD" sh -c 'cat >> "$1"' sh "$path"
    else
        printf '%s\n' "$line" >> "$path"
    fi
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

function queue_env_value() {
    local key="$1" value="$2" line=""
    line="${key}=\"$(env_line_escape "$value")\""
    ENV_APPEND_LINES+=("$line")
}

function generate_secret_hex() {
    local bytes="${1:-32}"
    command -v openssl >/dev/null 2>&1 || return 1
    openssl rand -hex "$bytes"
}

function env_key_result() {
    local key="$1" missing_result="$2" var_name="$3" value=""
    if env_has_nonempty_value "$key"; then
        printf -v "$var_name" '%s' "preserved"
        ENV_KEYS_PRESERVED=$((ENV_KEYS_PRESERVED + 1))
        return 0
    fi
    printf -v "$var_name" '%s' "$missing_result"
    return 1
}

function classify_smtp_status() {
    local host="" from="" any="no"
    host="$(env_value AUTHENTIK_EMAIL__HOST)"
    from="$(env_value AUTHENTIK_EMAIL__FROM)"

    for key in AUTHENTIK_EMAIL__HOST AUTHENTIK_EMAIL__PORT AUTHENTIK_EMAIL__USERNAME AUTHENTIK_EMAIL__PASSWORD AUTHENTIK_EMAIL__USE_TLS AUTHENTIK_EMAIL__USE_SSL AUTHENTIK_EMAIL__TIMEOUT AUTHENTIK_EMAIL__FROM; do
        if env_has_nonempty_value "$key"; then
            any="yes"
            break
        fi
    done

    if [ -n "$host" ] && [ -n "$from" ]; then
        SMTP_STATUS="configured"
    elif [ "$any" == "yes" ]; then
        SMTP_STATUS="partial"
    else
        SMTP_STATUS="not-configured"
    fi
}

function prompt_missing_bootstrap_email() {
    local email=""
    email="$(tty_read_line_blocking "Enter Authentik bootstrap email:")"
    email="$(printf '%s' "$email" | trim_shell_value)"
    if [ -z "$email" ]; then
        AUTHENTIK_BOOTSTRAP_EMAIL_STATUS="missing"
        ENV_STATUS="failed"
        SCRIPT63_READY_FOR_DEPLOYMENT_LANE="no"
SCRIPT63_READY_FOR_AUTOMATION_LANE="no"
        deploy_status_line "Bootstrap email" "missing" "$RD"
        fail_with_verify_log "AUTHENTIK_BOOTSTRAP_EMAIL is required before Authentik deployment."
    fi
    queue_env_value AUTHENTIK_BOOTSTRAP_EMAIL "$email"
    AUTHENTIK_BOOTSTRAP_EMAIL_STATUS="configured"
    ENV_KEYS_ADDED=$((ENV_KEYS_ADDED + 1))
}

function plan_authentik_env() {
    local value="" route_host="" generated=""
    ENV_APPEND_LINES=()
    ENV_KEYS_ADDED=0
    ENV_KEYS_PRESERVED=0
    ENV_STATUS="planned"
    SCRIPT63_READY_FOR_DEPLOYMENT_LANE="no"
SCRIPT63_READY_FOR_AUTOMATION_LANE="no"

    DOMAIN_VALUE="$(env_value DOMAIN)"
    route_host="$(env_value AUTHENTIK_ROUTE_HOST)"
    if [ -z "$route_host" ]; then
        if [ -z "$DOMAIN_VALUE" ]; then
            AUTHENTIK_ROUTE_STATUS="missing"
            ENV_STATUS="failed"
            fail_with_verify_log "Authentik route values cannot be derived because DOMAIN is missing."
        fi
        route_host="auth.${DOMAIN_VALUE}"
        queue_env_value AUTHENTIK_ROUTE_HOST "$route_host"
        ENV_KEYS_ADDED=$((ENV_KEYS_ADDED + 1))
        AUTHENTIK_ROUTE_STATUS="configured"
    else
        AUTHENTIK_ROUTE_STATUS="preserved"
        ENV_KEYS_PRESERVED=$((ENV_KEYS_PRESERVED + 1))
    fi
    AUTHENTIK_ROUTE_HOST="$route_host"

    for key in AUTHENTIK_EXTERNAL_URL AUTHENTIK_HOST AUTHENTIK_HOST_BROWSER AUTHENTIK_HOST_BROWSER_VALUE; do
        if env_has_nonempty_value "$key"; then
            ENV_KEYS_PRESERVED=$((ENV_KEYS_PRESERVED + 1))
        else
            queue_env_value "$key" "https://${AUTHENTIK_ROUTE_HOST}"
            ENV_KEYS_ADDED=$((ENV_KEYS_ADDED + 1))
        fi
    done
    AUTHENTIK_EXTERNAL_URL="$(env_value AUTHENTIK_EXTERNAL_URL)"
    [ -n "$AUTHENTIK_EXTERNAL_URL" ] || AUTHENTIK_EXTERNAL_URL="https://${AUTHENTIK_ROUTE_HOST}"

    if ! env_key_result AUTHENTIK_SECRET_KEY "will-generate" AUTHENTIK_SECRET_KEY_STATUS; then
        generated="$(generate_secret_hex 48)" || { AUTHENTIK_SECRET_KEY_STATUS="missing"; ENV_STATUS="failed"; fail_with_verify_log "A required Authentik value could not be generated safely."; }
        queue_env_value AUTHENTIK_SECRET_KEY "$generated"
        AUTHENTIK_SECRET_KEY_STATUS="generated"
        ENV_KEYS_ADDED=$((ENV_KEYS_ADDED + 1))
    fi

    if ! env_key_result AUTHENTIK_POSTGRES_PASSWORD "will-generate" AUTHENTIK_POSTGRES_PASSWORD_STATUS; then
        generated="$(generate_secret_hex 32)" || { AUTHENTIK_POSTGRES_PASSWORD_STATUS="missing"; ENV_STATUS="failed"; fail_with_verify_log "A required Authentik value could not be generated safely."; }
        queue_env_value AUTHENTIK_POSTGRES_PASSWORD "$generated"
        AUTHENTIK_POSTGRES_PASSWORD_STATUS="generated"
        ENV_KEYS_ADDED=$((ENV_KEYS_ADDED + 1))
    fi

    if env_has_nonempty_value AUTHENTIK_BOOTSTRAP_EMAIL; then
        AUTHENTIK_BOOTSTRAP_EMAIL_STATUS="preserved"
        ENV_KEYS_PRESERVED=$((ENV_KEYS_PRESERVED + 1))
    else
        prompt_missing_bootstrap_email
    fi

    if ! env_key_result AUTHENTIK_BOOTSTRAP_PASSWORD "will-generate" AUTHENTIK_BOOTSTRAP_PASSWORD_STATUS; then
        generated="$(generate_secret_hex 32)" || { AUTHENTIK_BOOTSTRAP_PASSWORD_STATUS="missing"; ENV_STATUS="failed"; fail_with_verify_log "A required Authentik value could not be generated safely."; }
        queue_env_value AUTHENTIK_BOOTSTRAP_PASSWORD "$generated"
        AUTHENTIK_BOOTSTRAP_PASSWORD_STATUS="generated"
        ENV_KEYS_ADDED=$((ENV_KEYS_ADDED + 1))
    fi

    if ! env_key_result AUTHENTIK_BOOTSTRAP_TOKEN "will-generate" AUTHENTIK_BOOTSTRAP_TOKEN_STATUS; then
        generated="$(generate_secret_hex 48)" || { AUTHENTIK_BOOTSTRAP_TOKEN_STATUS="missing"; ENV_STATUS="failed"; fail_with_verify_log "A required Authentik value could not be generated safely."; }
        queue_env_value AUTHENTIK_BOOTSTRAP_TOKEN "$generated"
        AUTHENTIK_BOOTSTRAP_TOKEN_STATUS="generated"
        ENV_KEYS_ADDED=$((ENV_KEYS_ADDED + 1))
    fi

    classify_smtp_status
    ENV_STATUS="ready"
}

function path_plan_status() {
    local path="$1" pg_mode="${2:-no}"
    if root_path_exists "$path"; then
        if [ "$pg_mode" == "yes" ] && root_dir_has_entries "$path"; then
            printf 'preserved'
        else
            printf 'present'
        fi
    else
        printf 'will-create'
    fi
}

function plan_authentik_folders() {
    AUTHENTIK_DIR_OWNER_GROUP="$(root_stat_owner_group "$DOCKER_DIR")"
    [ -n "$AUTHENTIK_DIR_OWNER_GROUP" ] || AUTHENTIK_DIR_OWNER_GROUP="unknown"

    AUTHENTIK_APPDATA_DIR="${DOCKER_DIR}/appdata/authentik"
    AUTHENTIK_POSTGRESQL_DIR="${AUTHENTIK_APPDATA_DIR}/postgresql"
    AUTHENTIK_MEDIA_DIR="${AUTHENTIK_APPDATA_DIR}/media"
    AUTHENTIK_TEMPLATES_DIR="${AUTHENTIK_APPDATA_DIR}/custom-templates"
    AUTHENTIK_CERTS_DIR="${AUTHENTIK_APPDATA_DIR}/certs"

    AUTHENTIK_APPDATA_DIR_PLAN="$(path_plan_status "$AUTHENTIK_APPDATA_DIR")"
    AUTHENTIK_POSTGRESQL_DIR_PLAN="$(path_plan_status "$AUTHENTIK_POSTGRESQL_DIR" yes)"
    AUTHENTIK_MEDIA_DIR_PLAN="$(path_plan_status "$AUTHENTIK_MEDIA_DIR")"
    AUTHENTIK_TEMPLATES_DIR_PLAN="$(path_plan_status "$AUTHENTIK_TEMPLATES_DIR")"
    AUTHENTIK_CERTS_DIR_PLAN="$(path_plan_status "$AUTHENTIK_CERTS_DIR")"
}

function plan_authentik_prep() {
    plan_authentik_env
    plan_authentik_folders
}

function backup_env_if_needed() {
    local ts=""
    if [ "${#ENV_APPEND_LINES[@]}" -eq 0 ]; then
        ENV_BACKUP_STATUS="not-needed"
        return 0
    fi
    ts="$(date +%Y%m%d-%H%M%S)"
    ENV_BACKUP_PATH="${ENV_FILE}.bak.script63-lane3-${ts}"
    if root_copy_preserve "$ENV_FILE" "$ENV_BACKUP_PATH"; then
        ENV_BACKUP_STATUS="created"
    else
        ENV_BACKUP_STATUS="failed"
        ENV_STATUS="failed"
        deploy_status_line ".env update" "failed" "$RD"
        fail_with_verify_log "Authentik .env preparation failed."
    fi
}

function append_missing_env_values() {
    local line=""
    backup_env_if_needed
    for line in "${ENV_APPEND_LINES[@]}"; do
        if ! root_append_line_to_file "$ENV_FILE" "$line"; then
            ENV_STATUS="failed"
            deploy_status_line ".env update" "failed" "$RD"
            fail_with_verify_log "Authentik .env preparation failed."
        fi
    done
    ENV_STATUS="ready"
}

function append_folder_prep_diagnostic() {
    local path="$1" expected_owner_group="$2" expected_mode="$3" reason="$4" actual_owner_group="missing" actual_mode="missing"
    init_deploy_output_log
    if root_path_exists "$path"; then
        actual_owner_group="$(root_stat_owner_group "$path")"
        actual_mode="$(root_stat_mode "$path")"
    fi
    append_deploy_log "Authentik folder prep failure: ${reason}"
    append_deploy_log "Path: ${path}"
    append_deploy_log "Expected owner/group: ${expected_owner_group}"
    append_deploy_log "Expected mode: ${expected_mode}"
    append_deploy_log "Actual owner/group: ${actual_owner_group}"
    append_deploy_log "Actual mode: ${actual_mode}"
}

function verify_managed_dir() {
    local path="$1" expected_owner_group="$2" expected_mode="$3" actual_owner_group="" actual_mode=""
    if ! root_path_exists "$path"; then
        append_folder_prep_diagnostic "$path" "$expected_owner_group" "$expected_mode" "directory is missing after create/repair"
        return 1
    fi
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" test -d "$path" || { append_folder_prep_diagnostic "$path" "$expected_owner_group" "$expected_mode" "path exists but is not a directory"; return 1; }
    else
        test -d "$path" || { append_folder_prep_diagnostic "$path" "$expected_owner_group" "$expected_mode" "path exists but is not a directory"; return 1; }
    fi
    actual_owner_group="$(root_stat_owner_group "$path")"
    actual_mode="$(root_stat_mode "$path")"
    if [ "$actual_owner_group" != "$expected_owner_group" ]; then
        append_folder_prep_diagnostic "$path" "$expected_owner_group" "$expected_mode" "owner/group mismatch after create/repair"
        return 1
    fi
    if [ "$actual_mode" != "$expected_mode" ]; then
        append_folder_prep_diagnostic "$path" "$expected_owner_group" "$expected_mode" "mode mismatch after create/repair"
        return 1
    fi
    return 0
}

function ensure_managed_dir() {
    local path="$1" status_var="$2" mode="${3:-755}" preserve_if_nonempty="${4:-no}" created="no" repaired="no" was_nonempty="no" current_owner_group="" current_mode=""

    if ! root_path_exists "$path"; then
        if ! root_install_dir "$path" "$mode"; then
            printf -v "$status_var" '%s' "failed"
            append_folder_prep_diagnostic "$path" "$AUTHENTIK_DIR_OWNER_GROUP" "$mode" "directory creation failed"
            return 1
        fi
        created="yes"
    fi

    if [ "$preserve_if_nonempty" == "yes" ] && root_dir_has_entries "$path"; then
        was_nonempty="yes"
    fi

    current_owner_group="$(root_stat_owner_group "$path")"
    if [ "$current_owner_group" != "$AUTHENTIK_DIR_OWNER_GROUP" ]; then
        if ! root_set_dir_owner_group "$path" "$AUTHENTIK_DIR_OWNER_GROUP"; then
            printf -v "$status_var" '%s' "failed"
            append_folder_prep_diagnostic "$path" "$AUTHENTIK_DIR_OWNER_GROUP" "$mode" "owner/group repair failed"
            return 1
        fi
        repaired="yes"
    fi

    current_mode="$(root_stat_mode "$path")"
    if [ "$current_mode" != "$mode" ]; then
        if ! root_set_dir_mode "$path" "$mode"; then
            printf -v "$status_var" '%s' "failed"
            append_folder_prep_diagnostic "$path" "$AUTHENTIK_DIR_OWNER_GROUP" "$mode" "mode repair failed"
            return 1
        fi
        repaired="yes"
    fi

    if ! verify_managed_dir "$path" "$AUTHENTIK_DIR_OWNER_GROUP" "$mode"; then
        printf -v "$status_var" '%s' "failed"
        return 1
    fi

    # For existing PostgreSQL data, avoid creating test files inside database contents.
    if [ "$preserve_if_nonempty" == "yes" ] && [ "$was_nonempty" == "yes" ]; then
        :
    elif ! root_write_test_dir "$path"; then
        printf -v "$status_var" '%s' "failed"
        append_folder_prep_diagnostic "$path" "$AUTHENTIK_DIR_OWNER_GROUP" "$mode" "writeability test failed"
        return 1
    fi

    if [ "$created" == "yes" ]; then
        printf -v "$status_var" '%s' "created"
    elif [ "$repaired" == "yes" ]; then
        printf -v "$status_var" '%s' "fixed"
    else
        printf -v "$status_var" '%s' "ready"
    fi
    return 0
}

function ensure_regular_dir() {
    local path="$1" status_var="$2"
    ensure_managed_dir "$path" "$status_var" 755 no
}

function ensure_postgresql_dir() {
    # Only the PostgreSQL top-level bind directory is managed here.
    # Existing data inside it is never deleted, emptied, or recursively chowned/chmodded.
    ensure_managed_dir "$AUTHENTIK_POSTGRESQL_DIR" AUTHENTIK_POSTGRESQL_DIR_STATUS 750 yes
}

function prepare_authentik_folders() {
    SCRIPT63_LANE="prep"
    SCRIPT63_STATUS="prep-running"
    SCRIPT63_VERIFY_STATUS="PENDING"
    SCRIPT63_DEPLOYMENT_STATUS="not-run"
    AUTHENTIK_DEPLOYMENT_STATUS="not-run"
    SCRIPT63_READY_FOR_DEPLOYMENT_LANE="no"
    init_deploy_output_log
    resolve_authentik_dir_owner_group
    ensure_regular_dir "$AUTHENTIK_APPDATA_DIR" AUTHENTIK_APPDATA_DIR_STATUS || fail_with_failure_log "Authentik appdata folder could not be prepared safely."
    ensure_postgresql_dir || fail_with_failure_log "PostgreSQL data folder could not be prepared safely."
    ensure_regular_dir "$AUTHENTIK_MEDIA_DIR" AUTHENTIK_MEDIA_DIR_STATUS || fail_with_failure_log "Authentik media folder could not be prepared safely."
    ensure_regular_dir "$AUTHENTIK_TEMPLATES_DIR" AUTHENTIK_TEMPLATES_DIR_STATUS || fail_with_failure_log "Authentik templates folder could not be prepared safely."
    ensure_regular_dir "$AUTHENTIK_CERTS_DIR" AUTHENTIK_CERTS_DIR_STATUS || fail_with_failure_log "Authentik certs folder could not be prepared safely."
    SCRIPT63_STATUS="prep-ready"
    SCRIPT63_VERIFY_STATUS="PREPARED"
}

function display_env_plan_status() {
    case "$1" in
        generated) printf 'will generate' ;;
        configured) printf 'configured' ;;
        preserved) printf 'preserved' ;;
        missing) printf 'missing' ;;
        *) printf '%s' "$1" ;;
    esac
}


# =========================================================
#  DEPLOY-LANE READINESS INSPECTION
# =========================================================
function inspect_env_required_for_deploy() {
    local key="" missing="no"
    ENV_APPEND_LINES=()
    ENV_KEYS_ADDED=0
    ENV_KEYS_PRESERVED=0
    ENV_BACKUP_STATUS="not-needed"
    ENV_STATUS="ready"
    SCRIPT63_READY_FOR_DEPLOYMENT_LANE="no"

    DOMAIN_VALUE="$(env_value DOMAIN)"
    AUTHENTIK_ROUTE_HOST="$(env_value AUTHENTIK_ROUTE_HOST)"
    AUTHENTIK_EXTERNAL_URL="$(env_value AUTHENTIK_EXTERNAL_URL)"

    for key in AUTHENTIK_ROUTE_HOST AUTHENTIK_EXTERNAL_URL AUTHENTIK_HOST AUTHENTIK_HOST_BROWSER AUTHENTIK_HOST_BROWSER_VALUE; do
        if env_has_nonempty_value "$key"; then
            ENV_KEYS_PRESERVED=$((ENV_KEYS_PRESERVED + 1))
        else
            missing="yes"
        fi
    done

    if env_has_nonempty_value AUTHENTIK_SECRET_KEY; then
        AUTHENTIK_SECRET_KEY_STATUS="preserved"; ENV_KEYS_PRESERVED=$((ENV_KEYS_PRESERVED + 1))
    else
        AUTHENTIK_SECRET_KEY_STATUS="missing"; missing="yes"
    fi
    if env_has_nonempty_value AUTHENTIK_POSTGRES_PASSWORD; then
        AUTHENTIK_POSTGRES_PASSWORD_STATUS="preserved"; ENV_KEYS_PRESERVED=$((ENV_KEYS_PRESERVED + 1))
    else
        AUTHENTIK_POSTGRES_PASSWORD_STATUS="missing"; missing="yes"
    fi
    if env_has_nonempty_value AUTHENTIK_BOOTSTRAP_EMAIL; then
        AUTHENTIK_BOOTSTRAP_EMAIL_STATUS="preserved"; ENV_KEYS_PRESERVED=$((ENV_KEYS_PRESERVED + 1))
    else
        AUTHENTIK_BOOTSTRAP_EMAIL_STATUS="missing"; missing="yes"
    fi
    if env_has_nonempty_value AUTHENTIK_BOOTSTRAP_PASSWORD; then
        AUTHENTIK_BOOTSTRAP_PASSWORD_STATUS="preserved"; ENV_KEYS_PRESERVED=$((ENV_KEYS_PRESERVED + 1))
    else
        AUTHENTIK_BOOTSTRAP_PASSWORD_STATUS="missing"; missing="yes"
    fi
    if env_has_nonempty_value AUTHENTIK_BOOTSTRAP_TOKEN; then
        AUTHENTIK_BOOTSTRAP_TOKEN_STATUS="preserved"; ENV_KEYS_PRESERVED=$((ENV_KEYS_PRESERVED + 1))
    else
        AUTHENTIK_BOOTSTRAP_TOKEN_STATUS="missing"; missing="yes"
    fi

    classify_smtp_status

    if [ "$missing" == "yes" ]; then
        ENV_STATUS="failed"
    fi
}

function preserve_success_folder_status() {
    local status_var="$1" path="$2" current_value=""
    if ! root_path_exists "$path"; then
        printf -v "$status_var" '%s' "failed"
        return 0
    fi
    eval "current_value=\${${status_var}:-unknown}"
    case "$current_value" in
        ready|created|fixed) return 0 ;;
        *) printf -v "$status_var" '%s' "ready" ;;
    esac
}

function inspect_folders_required_for_deploy() {
    AUTHENTIK_APPDATA_DIR="${DOCKER_DIR}/appdata/authentik"
    AUTHENTIK_POSTGRESQL_DIR="${AUTHENTIK_APPDATA_DIR}/postgresql"
    AUTHENTIK_MEDIA_DIR="${AUTHENTIK_APPDATA_DIR}/media"
    AUTHENTIK_TEMPLATES_DIR="${AUTHENTIK_APPDATA_DIR}/custom-templates"
    AUTHENTIK_CERTS_DIR="${AUTHENTIK_APPDATA_DIR}/certs"

    preserve_success_folder_status AUTHENTIK_APPDATA_DIR_STATUS "$AUTHENTIK_APPDATA_DIR"
    preserve_success_folder_status AUTHENTIK_POSTGRESQL_DIR_STATUS "$AUTHENTIK_POSTGRESQL_DIR"
    preserve_success_folder_status AUTHENTIK_MEDIA_DIR_STATUS "$AUTHENTIK_MEDIA_DIR"
    preserve_success_folder_status AUTHENTIK_TEMPLATES_DIR_STATUS "$AUTHENTIK_TEMPLATES_DIR"
    preserve_success_folder_status AUTHENTIK_CERTS_DIR_STATUS "$AUTHENTIK_CERTS_DIR"

    AUTHENTIK_APPDATA_DIR_PLAN="$AUTHENTIK_APPDATA_DIR_STATUS"
    AUTHENTIK_POSTGRESQL_DIR_PLAN="$AUTHENTIK_POSTGRESQL_DIR_STATUS"
    AUTHENTIK_MEDIA_DIR_PLAN="$AUTHENTIK_MEDIA_DIR_STATUS"
    AUTHENTIK_TEMPLATES_DIR_PLAN="$AUTHENTIK_TEMPLATES_DIR_STATUS"
    AUTHENTIK_CERTS_DIR_PLAN="$AUTHENTIK_CERTS_DIR_STATUS"
}

function inspect_authentik_prep_for_deploy() {
    inspect_env_required_for_deploy
    inspect_folders_required_for_deploy
    if [ "$ENV_STATUS" == "ready" ] \
        && [ "$AUTHENTIK_APPDATA_DIR_STATUS" != "failed" ] \
        && [ "$AUTHENTIK_POSTGRESQL_DIR_STATUS" != "failed" ] \
        && [ "$AUTHENTIK_MEDIA_DIR_STATUS" != "failed" ] \
        && [ "$AUTHENTIK_TEMPLATES_DIR_STATUS" != "failed" ] \
        && [ "$AUTHENTIK_CERTS_DIR_STATUS" != "failed" ]; then
        SCRIPT63_READY_FOR_DEPLOYMENT_LANE="yes"
    else
        SCRIPT63_READY_FOR_DEPLOYMENT_LANE="no"
    fi
}

function append_prep_readiness_diagnostics() {
    init_deploy_output_log
    append_deploy_log "Authentik preparation readiness failed."
    append_deploy_log "Expected Authentik folder owner/group: ${AUTHENTIK_DIR_OWNER_GROUP:-unknown}"
    append_deploy_log "Environment status: ${ENV_STATUS}"
    append_folder_prep_diagnostic "$AUTHENTIK_APPDATA_DIR" "${AUTHENTIK_DIR_OWNER_GROUP:-unknown}" "755" "readiness status ${AUTHENTIK_APPDATA_DIR_STATUS}"
    append_folder_prep_diagnostic "$AUTHENTIK_POSTGRESQL_DIR" "${AUTHENTIK_DIR_OWNER_GROUP:-unknown}" "750" "readiness status ${AUTHENTIK_POSTGRESQL_DIR_STATUS}"
    append_folder_prep_diagnostic "$AUTHENTIK_MEDIA_DIR" "${AUTHENTIK_DIR_OWNER_GROUP:-unknown}" "755" "readiness status ${AUTHENTIK_MEDIA_DIR_STATUS}"
    append_folder_prep_diagnostic "$AUTHENTIK_TEMPLATES_DIR" "${AUTHENTIK_DIR_OWNER_GROUP:-unknown}" "755" "readiness status ${AUTHENTIK_TEMPLATES_DIR_STATUS}"
    append_folder_prep_diagnostic "$AUTHENTIK_CERTS_DIR" "${AUTHENTIK_DIR_OWNER_GROUP:-unknown}" "755" "readiness status ${AUTHENTIK_CERTS_DIR_STATUS}"
}

function validate_prep_ready_for_deploy() {
    if [ "$SCRIPT63_READY_FOR_DEPLOYMENT_LANE" != "yes" ]; then
        append_prep_readiness_diagnostics
        fail_with_failure_log "Authentik preparation is not ready for deployment."
    fi
}

# =========================================================
#  AUTHENTIK PREFLIGHT / DETECTION
# =========================================================
function detect_authentik_compose() {
    local runtime_compose="${COMPOSE_DIR}/05-authentik-compose.yml"
    local repo_compose="./docker/05-authentik-compose.yml"
    AUTHENTIK_COMPOSE_RUNTIME_PATH="$runtime_compose"

    if root_path_exists "$runtime_compose"; then
        AUTHENTIK_COMPOSE_STATUS="present"
        AUTHENTIK_COMPOSE_LOCATION="$runtime_compose"
    elif [ -f "$repo_compose" ]; then
        AUTHENTIK_COMPOSE_STATUS="present"
        AUTHENTIK_COMPOSE_LOCATION="$repo_compose"
    else
        AUTHENTIK_COMPOSE_STATUS="will install later"
        AUTHENTIK_COMPOSE_LOCATION="will install later"
    fi
}

function detect_authentik_state() {
    local found="no"

    if root_path_exists "$SCRIPT63_MARKER"; then
        AUTHENTIK_MARKER_STATUS="present"
        found="yes"
    else
        AUTHENTIK_MARKER_STATUS="not present"
    fi

    if [ "$DOCKER_API_STATUS" == "responsive" ]; then
        if docker_container_exists_by_name authentik-server \
            || docker_container_exists_by_name authentik-worker \
            || docker_container_exists_by_name authentik-postgresql \
            || docker_project_exists; then
            AUTHENTIK_CONTAINER_STATUS="detected"
            found="yes"
        else
            AUTHENTIK_CONTAINER_STATUS="not detected"
        fi
    else
        AUTHENTIK_CONTAINER_STATUS="unknown"
    fi

    if [ "$found" == "yes" ]; then
        SCRIPT63_SETUP_MODE="rerun-update"
        AUTHENTIK_EXISTING="detected"
    else
        SCRIPT63_SETUP_MODE="fresh-install"
        AUTHENTIK_EXISTING="not detected"
    fi

    detect_authentik_compose
}

function show_authentik_preflight() {
    section "AUTHENTIK PREFLIGHT"

    aligned_status_line "Mode" "$SCRIPT63_SETUP_MODE" "$(rerun_ui_color "$SCRIPT63_SETUP_MODE")"
    aligned_status_line "Existing Authentik" "$AUTHENTIK_EXISTING" "$(rerun_ui_color "$AUTHENTIK_EXISTING")"
    aligned_status_line "Authentik compose" "$AUTHENTIK_COMPOSE_STATUS" "$(status_color_for_value "$AUTHENTIK_COMPOSE_STATUS")"
    aligned_status_line "Public route" "$AUTHENTIK_ROUTE_HOST"
    aligned_status_line "External URL" "$AUTHENTIK_EXTERNAL_URL"
    aligned_status_line "Database" "PostgreSQL 17"
    aligned_status_line "PostgreSQL data" "$AUTHENTIK_POSTGRESQL_DIR_STATUS" "$(rerun_ui_color "$AUTHENTIK_POSTGRESQL_DIR_STATUS")"
    aligned_status_line "Redis" "not used"
    aligned_status_line "SMTP" "$SMTP_STATUS" "$(status_color_for_value "$SMTP_STATUS")"
    aligned_status_line "Embedded Outpost" "pending-lane-5"
    aligned_status_line "Admin UI bootstrap" "unchanged"

    if [ "$TRAEFIK_DYNAMIC_STATUS" != "present" ] || [ "$TRAEFIK_AUTHENTIK_REFERENCES" != "ready" ]; then
        fail_with_verify_log "Runtime preflight failed."
    fi
}

function show_authentik_prep_plan() {
    section "AUTHENTIK PREP"
    mini_header_compact "Environment"
    aligned_status_line "AUTHENTIK_SECRET_KEY" "$(display_env_plan_status "$AUTHENTIK_SECRET_KEY_STATUS")" "$(prep_value_color "$AUTHENTIK_SECRET_KEY_STATUS")"
    aligned_status_line "PostgreSQL password" "$(display_env_plan_status "$AUTHENTIK_POSTGRES_PASSWORD_STATUS")" "$(prep_value_color "$AUTHENTIK_POSTGRES_PASSWORD_STATUS")"
    aligned_status_line "Bootstrap email" "$(display_env_plan_status "$AUTHENTIK_BOOTSTRAP_EMAIL_STATUS")" "$(prep_value_color "$AUTHENTIK_BOOTSTRAP_EMAIL_STATUS")"
    aligned_status_line "Bootstrap password" "$(display_env_plan_status "$AUTHENTIK_BOOTSTRAP_PASSWORD_STATUS")" "$(prep_value_color "$AUTHENTIK_BOOTSTRAP_PASSWORD_STATUS")"
    aligned_status_line "Bootstrap token" "$(display_env_plan_status "$AUTHENTIK_BOOTSTRAP_TOKEN_STATUS")" "$(prep_value_color "$AUTHENTIK_BOOTSTRAP_TOKEN_STATUS")"
    aligned_status_line "SMTP" "$SMTP_STATUS" "$(status_color_for_value "$SMTP_STATUS")"
    aligned_status_line "Secret storage" "$SCRIPT63_SECRET_STORAGE" "$GN"

    mini_header "Folders"
    aligned_status_line "Authentik appdata" "$AUTHENTIK_APPDATA_DIR_PLAN"
    aligned_status_line "PostgreSQL data" "$AUTHENTIK_POSTGRESQL_DIR_PLAN" "$(rerun_ui_color "$AUTHENTIK_POSTGRESQL_DIR_PLAN")"
    aligned_status_line "Media" "$AUTHENTIK_MEDIA_DIR_PLAN"
    aligned_status_line "Templates" "$AUTHENTIK_TEMPLATES_DIR_PLAN"
    aligned_status_line "Certs" "$AUTHENTIK_CERTS_DIR_PLAN"
}

# =========================================================
#  PLAN / CONFIRMATION / PREP CHECKS
# =========================================================
function show_setup_plan() {
    section "SETUP PLAN"

    if [ "$SCRIPT63_AUTOMATION_MODE" == "rerun-update" ]; then
        echo -e "${YW}Rerun/update detected.${CL}"
        echo -e "${YW}Existing Authentik automation will be verified and updated idempotently.${CL}"
    else
        echo -e "${YW}Script 6.3 will configure Authentik ForwardAuth and write the completion marker only after checks pass.${CL}"
    fi

    local provider_action="create/update" app_action="create/update" outpost_action="attach provider" marker_action="write on success"
    if [ "$SCRIPT63_AUTOMATION_MODE" == "rerun-update" ]; then
        provider_action="update if needed"
        app_action="update if needed"
        outpost_action="preserve/attach provider"
        marker_action="refresh on success"
    fi

    mini_header "Setup mode"
    aligned_status_line "Automation mode" "$SCRIPT63_AUTOMATION_MODE" "$(rerun_ui_color "$SCRIPT63_AUTOMATION_MODE")"
    aligned_status_line "Provider" "$provider_action" "$(rerun_ui_color "$provider_action")"
    aligned_status_line "Application" "$app_action" "$(rerun_ui_color "$app_action")"
    aligned_status_line "Embedded Outpost" "$outpost_action" "$(rerun_ui_color "$outpost_action")"
    aligned_status_line "ForwardAuth endpoint" "verify"
    aligned_status_line "Traefik resolution" "verify"
    aligned_status_line "Completion marker" "$marker_action" "$(rerun_ui_color "$marker_action")"
}

function confirm_or_exit() {
    local answer=""
    echo ""
    answer="$(timed_yes_no_value_only "Apply this Authentik automation plan?" "y")"
    if [[ "$answer" =~ ^[Nn]$ ]]; then
        msg_ok "Authentik deployment plan cancelled"
        exit 0
    fi
    tty_println "${CM} ${GN}Applying confirmed Authentik automation plan.${CL}"
}

function install_authentik_compose_file() {
    local local_source="./docker/${AUTHENTIK_COMPOSE_FILE}" tmp_file=""
    AUTHENTIK_COMPOSE_RUNTIME_PATH="${COMPOSE_DIR}/${AUTHENTIK_COMPOSE_FILE}"
    init_deploy_output_log

    tmp_file="$(mktemp /tmp/circl8-authentik-compose-install.XXXXXX)"
    if [ -f "$local_source" ]; then
        append_deploy_log "Installing Authentik compose from repo-local source: ${local_source}"
        if ! cp -f "$local_source" "$tmp_file"; then
            rm -f "$tmp_file"
            AUTHENTIK_COMPOSE_SOURCE_STATUS="failed"
            fail_with_failure_log "Authentik compose file could not be installed."
        fi
    else
        append_deploy_log "Repo-local Authentik compose source not found; downloading from GitHub raw URL."
        if ! root_download_url_to_file "$AUTHENTIK_RAW_COMPOSE_URL" "$tmp_file"; then
            rm -f "$tmp_file"
            AUTHENTIK_COMPOSE_SOURCE_STATUS="failed"
            fail_with_failure_log "Authentik compose file could not be installed."
        fi
    fi

    if ! [ -s "$tmp_file" ]; then
        rm -f "$tmp_file"
        AUTHENTIK_COMPOSE_SOURCE_STATUS="failed"
        fail_with_failure_log "Authentik compose file could not be installed."
    fi

    if root_copy_regular_file "$tmp_file" "$AUTHENTIK_COMPOSE_RUNTIME_PATH" \
        && root_file_not_empty "$AUTHENTIK_COMPOSE_RUNTIME_PATH" \
        && repair_runtime_compose_file_permissions; then
        rm -f "$tmp_file"
        AUTHENTIK_COMPOSE_SOURCE_STATUS="installed"
        AUTHENTIK_COMPOSE_STATUS="present"
        AUTHENTIK_COMPOSE_LOCATION="$AUTHENTIK_COMPOSE_RUNTIME_PATH"
        return 0
    fi

    rm -f "$tmp_file"
    AUTHENTIK_COMPOSE_SOURCE_STATUS="failed"
    AUTHENTIK_COMPOSE_FILE_READABLE="no"
    fail_with_failure_log "Authentik compose file could not be installed."
}

function run_docker_readiness_gate() {
    local attempt="" ok="no"
    init_deploy_output_log
    for attempt in {1..10}; do
        append_deploy_log "Docker readiness attempt ${attempt}."
        if docker_cmd info >/dev/null 2>&1 \
            && docker_cmd compose version >/dev/null 2>&1 \
            && docker_cmd network inspect t2_proxy >/dev/null 2>&1 \
            && root_file_not_empty "$ENV_FILE"; then
            ok="yes"
            break
        fi
        sleep 2
    done

    if [ "$ok" != "yes" ]; then
        DOCKER_READINESS_STATUS="failed"
        DOCKER_DAEMON_READINESS_STATUS="failed"
        DOCKER_COMPOSE_READINESS_STATUS="failed"
        DOCKER_NETWORKS_READINESS_STATUS="failed"
        fail_with_failure_log "Docker readiness gate failed."
    fi

    DOCKER_READINESS_STATUS="ready"
    DOCKER_DAEMON_READINESS_STATUS="ready"
    DOCKER_COMPOSE_READINESS_STATUS="ready"
    DOCKER_API_STATUS="responsive"
    DOCKER_NETWORKS_READINESS_STATUS="settled"
}

function validate_authentik_compose_config() {
    local err_file=""
    err_file="$(mktemp /tmp/circl8-authentik-compose-config.XXXXXX)"
    init_deploy_output_log
    append_deploy_log "Validating Authentik compose config. Full rendered config is intentionally not logged."
    if docker_cmd compose --env-file "$ENV_FILE" -p "$COMPOSE_PROJECT_NAME" -f "$AUTHENTIK_COMPOSE_RUNTIME_PATH" config >/dev/null 2>"$err_file"; then
        AUTHENTIK_COMPOSE_CONFIG_STATUS="valid"
        rm -f "$err_file"
        return 0
    fi

    AUTHENTIK_COMPOSE_CONFIG_STATUS="failed"
    append_deploy_log "Authentik compose validation stderr, sanitized:"
    append_file_to_deploy_log_sanitized "$err_file"
    rm -f "$err_file"
    fail_with_failure_log "Authentik compose validation failed."
}

function deploy_authentik_compose() {
    local attempt="" out_file="" ok="no"
    init_deploy_output_log
    for attempt in {1..3}; do
        out_file="$(mktemp /tmp/circl8-authentik-compose-up.XXXXXX)"
        append_deploy_log "Authentik compose deployment attempt ${attempt}."
        if docker_cmd compose --env-file "$ENV_FILE" -p "$COMPOSE_PROJECT_NAME" -f "$AUTHENTIK_COMPOSE_RUNTIME_PATH" up -d --remove-orphans >"$out_file" 2>&1; then
            append_file_to_deploy_log_sanitized "$out_file"
            rm -f "$out_file"
            ok="yes"
            break
        fi
        append_file_to_deploy_log_sanitized "$out_file"
        rm -f "$out_file"
        sleep 5
    done

    if [ "$ok" != "yes" ]; then
        AUTHENTIK_DEPLOYMENT_STATUS="failed"
        fail_with_failure_log "Authentik compose deployment failed."
    fi
    AUTHENTIK_DEPLOYMENT_STATUS="completed"
}

function docker_inspect_value() {
    local format="$1" name="$2"
    docker_cmd inspect -f "$format" "$name" 2>/dev/null || true
}

function collect_authentik_failure_context() {
    local container=""
    init_deploy_output_log
    append_deploy_log "Container status snapshot:"
    docker_cmd ps -a --filter "name=authentik" --format '{{.Names}} {{.Status}}' >> "$DEPLOY_OUTPUT_LOG" 2>/dev/null || true
    for container in authentik-postgresql authentik-server authentik-worker; do
        append_deploy_log "Logs for ${container}, sanitized:"
        docker_cmd logs --tail 120 "$container" 2>/dev/null | sed -E '/(PASSWORD|TOKEN|SECRET_KEY|AUTHENTIK_EMAIL__PASSWORD|AUTHENTIK_POSTGRES_PASSWORD|AUTHENTIK_BOOTSTRAP)/Id' >> "$DEPLOY_OUTPUT_LOG" || true
    done
}

function wait_for_postgresql_healthy() {
    local deadline="" status=""
    deadline=$(( $(date +%s) + 180 ))
    while [ "$(date +%s)" -le "$deadline" ]; do
        status="$(docker_inspect_value '{{.State.Health.Status}}' authentik-postgresql)"
        if [ "$status" == "healthy" ]; then
            AUTHENTIK_POSTGRES_STATUS="healthy"
            return 0
        fi
        sleep 5
    done
    AUTHENTIK_POSTGRES_STATUS="failed"
    collect_authentik_failure_context
    fail_with_failure_log "PostgreSQL did not become healthy before timeout."
}

function wait_for_container_running() {
    local name="$1" status_var="$2" deadline="" state="" running="" restarting=""
    deadline=$(( $(date +%s) + 180 ))
    while [ "$(date +%s)" -le "$deadline" ]; do
        state="$(docker_inspect_value '{{.State.Running}} {{.State.Restarting}}' "$name")"
        running="${state%% *}"
        restarting="${state##* }"
        if [ "$running" == "true" ] && [ "$restarting" == "false" ]; then
            printf -v "$status_var" '%s' "running"
            return 0
        fi
        sleep 5
    done
    printf -v "$status_var" '%s' "failed"
    collect_authentik_failure_context
    fail_with_failure_log "${name} did not become ready before timeout."
}

function authentik_internal_api_check_once() {
    local py_code="" api_url="http://127.0.0.1:9000/api/v3/core/users/me/"
    py_code='import sys, urllib.request, urllib.error
url=sys.argv[1]
try:
    response=urllib.request.urlopen(url, timeout=5)
    code=getattr(response, "status", 200)
except urllib.error.HTTPError as error:
    code=error.code
except Exception:
    code=0
sys.exit(0 if code in (200, 401, 403) else 1)'
    docker_cmd exec authentik-server python -c "$py_code" "$api_url" >/dev/null 2>&1 \
        || docker_cmd exec authentik-server python3 -c "$py_code" "$api_url" >/dev/null 2>&1
}

function wait_for_internal_api_ready() {
    local deadline=""
    deadline=$(( $(date +%s) + 300 ))
    while [ "$(date +%s)" -le "$deadline" ]; do
        if authentik_internal_api_check_once; then
            AUTHENTIK_INTERNAL_API_STATUS="ready"
            return 0
        fi
        sleep 5
    done
    AUTHENTIK_INTERNAL_API_STATUS="failed"
    collect_authentik_failure_context
    fail_with_failure_log "Authentik server did not become ready before timeout."
}

function run_authentik_deploy() {
    SCRIPT63_LANE="deploy"
    SCRIPT63_STATUS="deploy-running"
    SCRIPT63_VERIFY_STATUS="PENDING"
    SCRIPT63_DEPLOYMENT_STATUS="not-run"
    section "DEPLOY AUTHENTIK"
    init_deploy_output_log

    mini_header "Docker readiness"
    run_docker_readiness_gate
    deploy_status_line "Docker daemon" "$DOCKER_DAEMON_READINESS_STATUS" "$GN"
    deploy_status_line "Docker Compose" "$DOCKER_COMPOSE_READINESS_STATUS" "$GN"
    deploy_status_line "Docker API" "$DOCKER_API_STATUS" "$GN"
    deploy_status_line "Docker networks" "$DOCKER_NETWORKS_READINESS_STATUS" "$GN"

    mini_header "Compose files"
    install_authentik_compose_file
    deploy_status_line "Authentik compose" "$AUTHENTIK_COMPOSE_SOURCE_STATUS" "$GN"

    mini_header "Compose validation"
    validate_authentik_compose_config
    deploy_status_line "Authentik compose" "$AUTHENTIK_COMPOSE_CONFIG_STATUS" "$GN"

    mini_header "Authentik"
    progress_line "Deploying Authentik compose"
    deploy_authentik_compose
    clear_progress_line
    deploy_status_line "Compose deployment" "$AUTHENTIK_DEPLOYMENT_STATUS" "$GN"
    progress_line "Waiting for PostgreSQL health"
    wait_for_postgresql_healthy
    clear_progress_line
    deploy_status_line "PostgreSQL" "$AUTHENTIK_POSTGRES_STATUS" "$GN"
    progress_line "Waiting for Authentik server"
    wait_for_container_running authentik-server AUTHENTIK_SERVER_STATUS
    clear_progress_line
    deploy_status_line "Authentik server" "$AUTHENTIK_SERVER_STATUS" "$GN"
    progress_line "Waiting for Authentik worker"
    wait_for_container_running authentik-worker AUTHENTIK_WORKER_STATUS
    clear_progress_line
    deploy_status_line "Authentik worker" "$AUTHENTIK_WORKER_STATUS" "$GN"
    progress_line "Waiting for Internal API readiness"
    wait_for_internal_api_ready
    clear_progress_line
    deploy_status_line "Internal API" "$AUTHENTIK_INTERNAL_API_STATUS" "$GN"

    SCRIPT63_STATUS="deployed-auth-not-configured"
    SCRIPT63_VERIFY_STATUS="DEPLOYED"
    SCRIPT63_DEPLOYMENT_STATUS="completed"
    SCRIPT63_READY_FOR_AUTOMATION_LANE="yes"
}

# =========================================================
#  AUTHENTIK AUTOMATION HELPERS
# =========================================================
function build_authentik_automation_payload() {
    local action="$1" marker_present="no"
    local host_browser=""
    AUTHENTIK_BOOTSTRAP_TOKEN_VALUE="$(env_value AUTHENTIK_BOOTSTRAP_TOKEN)"
    AUTHENTIK_API_TOKEN_VALUE="$(env_value AUTHENTIK_API_TOKEN)"
    AUTHENTIK_EXTERNAL_URL="$(env_value AUTHENTIK_EXTERNAL_URL)"
    AUTHENTIK_ROUTE_HOST="$(env_value AUTHENTIK_ROUTE_HOST)"
    DOMAIN_VALUE="$(env_value DOMAIN)"
    host_browser="$(env_value AUTHENTIK_HOST_BROWSER)"
    [ -n "$host_browser" ] || host_browser="$(env_value AUTHENTIK_HOST_BROWSER_VALUE)"
    [ -n "$host_browser" ] || host_browser="$AUTHENTIK_EXTERNAL_URL"
    root_path_exists "$SCRIPT63_MARKER" && marker_present="yes"

    python3 -c 'import json, sys
keys = [
    "action", "bootstrap_token", "api_token", "external_url", "host_browser", "route_host", "domain", "marker_present"
]
values = sys.stdin.read().splitlines()
while len(values) < len(keys):
    values.append("")
print(json.dumps(dict(zip(keys, values))))' <<PAYLOAD
${action}
${AUTHENTIK_BOOTSTRAP_TOKEN_VALUE}
${AUTHENTIK_API_TOKEN_VALUE}
${AUTHENTIK_EXTERNAL_URL}
${host_browser}
${AUTHENTIK_ROUTE_HOST}
${DOMAIN_VALUE}
${marker_present}
PAYLOAD
}

function authentik_python_code() {
cat <<'PYCODE'
import json, sys, urllib.request, urllib.error, urllib.parse, time, re

BASE_URL = "http://127.0.0.1:9000"
PROVIDER_NAME = "Circl8 Traefik ForwardAuth"
APPLICATION_NAME = "Circl8 Traefik ForwardAuth"
APPLICATION_SLUG = "circl8-traefik-forwardauth"
EMBEDDED_OUTPOST_NAME = "authentik Embedded Outpost"
EMBEDDED_OUTPOST_MANAGED = "goauthentik.io/outposts/embedded"
OUTPOST_PING_PATH = "/outpost.goauthentik.io/ping"

payload = json.loads(sys.stdin.read() or "{}")
selected_token = ""

def sanitize(text):
    text = str(text or "")
    for key in ("bootstrap_token", "api_token"):
        value = payload.get(key) or ""
        if value:
            text = text.replace(value, "[redacted]")
    text = re.sub(r'(?i)(password|token|secret)[^\\n]{0,160}', '[redacted]', text)
    return text[:800]

def emit(key, value):
    value = "" if value is None else str(value)
    value = value.replace("\n", " ").replace("\r", " ")
    print(f"{key}={value}")

def fail(stage, message):
    emit("RESULT", "failed")
    emit("ERROR_STAGE", stage)
    emit("ERROR_MESSAGE", sanitize(message))
    sys.exit(2)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None

opener = urllib.request.build_opener(NoRedirect)

def raw_request(method, path, body=None, token=None, timeout=15, follow_redirect=False):
    url = BASE_URL + path
    data = None
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method)
    if token:
        req.add_header("Authorization", "Bearer " + token)
    if body is not None:
        req.add_header("Content-Type", "application/json")
    handler = urllib.request.urlopen if follow_redirect else opener.open
    try:
        with handler(req, timeout=timeout) as response:
            raw = response.read().decode("utf-8", "replace")
            code = getattr(response, "status", 200)
    except urllib.error.HTTPError as error:
        raw = error.read().decode("utf-8", "replace")
        code = error.code
    except Exception as error:
        return 0, None, sanitize(error)
    try:
        parsed = json.loads(raw) if raw else None
    except Exception:
        parsed = None
    return code, parsed, raw

def api_request(method, path, body=None, expected=(200,), stage="api"):
    code, parsed, raw = raw_request(method, path, body=body, token=selected_token)
    if code not in expected:
        fail(stage, f"{method} {path} returned HTTP {code}: {sanitize(raw)}")
    return parsed

def result_items(parsed):
    if isinstance(parsed, dict) and isinstance(parsed.get("results"), list):
        return parsed["results"]
    if isinstance(parsed, list):
        return parsed
    return []

def validate_token():
    global selected_token
    candidates = [("bootstrap", payload.get("bootstrap_token") or ""), ("api", payload.get("api_token") or "")]
    for source, token in candidates:
        if not token:
            continue
        code, parsed, raw = raw_request("GET", "/api/v3/core/users/me/", token=token)
        if code == 200:
            selected_token = token
            emit("AUTHENTIK_API_ACCESS_STATUS", "valid")
            emit("AUTHENTIK_API_TOKEN_SOURCE", source)
            return
    fail("api-token", "No provided Authentik API token returned HTTP 200 for /api/v3/core/users/me/.")

def lookup_flow(slug, label):
    query = urllib.parse.urlencode({"slug": slug})
    parsed = api_request("GET", f"/api/v3/flows/instances/?{query}", stage="flow")
    for item in result_items(parsed):
        if item.get("slug") == slug and item.get("pk"):
            emit(label, "found")
            return item["pk"]
    fail("flow", f"Required flow slug missing: {slug}")

def options_fields(path):
    code, parsed, raw = raw_request("OPTIONS", path, token=selected_token)
    if code != 200 or not isinstance(parsed, dict):
        return set()
    actions = parsed.get("actions") or {}
    post = actions.get("POST") or {}
    if isinstance(post, dict):
        return set(post.keys())
    return set()

def find_provider():
    query = urllib.parse.urlencode({"search": PROVIDER_NAME})
    parsed = api_request("GET", f"/api/v3/providers/proxy/?{query}", stage="provider")
    for item in result_items(parsed):
        if item.get("name") == PROVIDER_NAME:
            return item
    return None

def find_application():
    query = urllib.parse.urlencode({"slug": APPLICATION_SLUG})
    parsed = api_request("GET", f"/api/v3/core/applications/?{query}", stage="application")
    for item in result_items(parsed):
        if item.get("slug") == APPLICATION_SLUG:
            return item
    return None

def find_embedded_outpost():
    parsed = api_request("GET", "/api/v3/outposts/instances/", stage="outpost")
    for item in result_items(parsed):
        if item.get("name") == EMBEDDED_OUTPOST_NAME and item.get("managed") == EMBEDDED_OUTPOST_MANAGED and item.get("type") == "proxy":
            return item
    fail("outpost", "Embedded Outpost was not found.")

def provider_ids_from_outpost(outpost):
    ids = []
    for provider in outpost.get("providers") or []:
        if isinstance(provider, dict):
            pk = provider.get("pk")
        else:
            pk = provider
        if pk and str(pk) not in ids:
            ids.append(str(pk))
    return ids

def automation_mode(provider, application, outpost):
    providers = provider_ids_from_outpost(outpost) if outpost else []
    provider_pk = str(provider.get("pk")) if provider and provider.get("pk") else ""
    if payload.get("marker_present") == "yes" or provider or application or (provider_pk and provider_pk in providers):
        return "rerun-update"
    return "fresh-automation"

def inspect_state():
    provider = find_provider()
    application = find_application()
    outpost = find_embedded_outpost()
    mode = automation_mode(provider, application, outpost)
    emit("SCRIPT63_AUTOMATION_MODE", mode)
    if provider:
        emit("AUTHENTIK_PROVIDER_STATUS", "configured")
        emit("AUTHENTIK_PROVIDER_PK", provider.get("pk", ""))
    else:
        emit("AUTHENTIK_PROVIDER_STATUS", "not configured")
    if application:
        emit("AUTHENTIK_APPLICATION_STATUS", "configured")
    else:
        emit("AUTHENTIK_APPLICATION_STATUS", "not configured")
    if outpost:
        emit("AUTHENTIK_OUTPOST_STATUS", "detected")
        emit("AUTHENTIK_OUTPOST_PK", outpost.get("pk", ""))
        if provider and str(provider.get("pk")) in provider_ids_from_outpost(outpost):
            emit("AUTHENTIK_OUTPOST_STATUS", "attached")
    emit("FORWARD_AUTH_STATUS", "ready" if provider and application and outpost and str(provider.get("pk")) in provider_ids_from_outpost(outpost) else "not verified")

def configure_provider(auth_flow, authz_flow, invalidation_flow):
    fields = options_fields("/api/v3/providers/proxy/")
    provider = find_provider()
    body = {
        "name": PROVIDER_NAME,
        "mode": "forward_domain",
        "external_host": payload.get("external_url") or "",
        "authentication_flow": auth_flow,
        "authorization_flow": authz_flow,
        "invalidation_flow": invalidation_flow,
        "basic_auth_enabled": False,
        "skip_path_regex": "",
    }
    if "cookie_domain" in fields and payload.get("domain"):
        body["cookie_domain"] = "." + payload["domain"].lstrip(".")
    if provider and provider.get("pk"):
        pk = provider["pk"]
        api_request("PATCH", f"/api/v3/providers/proxy/{pk}/", body=body, expected=(200,), stage="provider")
        emit("AUTHENTIK_PROVIDER_STATUS", "updated")
        emit("AUTHENTIK_PROVIDER_PK", pk)
        return str(pk)
    parsed = api_request("POST", "/api/v3/providers/proxy/", body=body, expected=(200, 201), stage="provider")
    pk = parsed.get("pk") if isinstance(parsed, dict) else ""
    if not pk:
        fail("provider", "Provider response did not include pk.")
    emit("AUTHENTIK_PROVIDER_STATUS", "configured")
    emit("AUTHENTIK_PROVIDER_PK", pk)
    return str(pk)

def configure_application(provider_pk):
    application = find_application()
    body = {
        "name": APPLICATION_NAME,
        "slug": APPLICATION_SLUG,
        "provider": provider_pk,
        "open_in_new_tab": False,
        "meta_launch_url": "",
    }
    if application:
        detail = f"/api/v3/core/applications/{APPLICATION_SLUG}/"
        code, parsed, raw = raw_request("PATCH", detail, body=body, token=selected_token)
        if code != 200 and application.get("pk"):
            code, parsed, raw = raw_request("PATCH", f"/api/v3/core/applications/{application['pk']}/", body=body, token=selected_token)
        if code != 200:
            fail("application", f"PATCH application returned HTTP {code}: {sanitize(raw)}")
        emit("AUTHENTIK_APPLICATION_STATUS", "updated")
        emit("AUTHENTIK_APPLICATION_SLUG", APPLICATION_SLUG)
        return
    api_request("POST", "/api/v3/core/applications/", body=body, expected=(200, 201), stage="application")
    emit("AUTHENTIK_APPLICATION_STATUS", "configured")
    emit("AUTHENTIK_APPLICATION_SLUG", APPLICATION_SLUG)

def configure_outpost(provider_pk):
    outpost = find_embedded_outpost()
    pk = outpost.get("pk")
    if not pk:
        fail("outpost", "Embedded Outpost response did not include pk.")
    providers = provider_ids_from_outpost(outpost)
    already = provider_pk in providers
    if not already:
        providers.append(provider_pk)
    config = outpost.get("config") if isinstance(outpost.get("config"), dict) else {}
    config = dict(config)
    if payload.get("external_url"):
        config["authentik_host"] = payload["external_url"]
    if payload.get("host_browser"):
        config["authentik_host_browser"] = payload["host_browser"]
    body = {"providers": providers, "config": config}
    api_request("PATCH", f"/api/v3/outposts/instances/{pk}/", body=body, expected=(200,), stage="outpost")
    emit("AUTHENTIK_OUTPOST_STATUS", "attached")
    emit("AUTHENTIK_OUTPOST_PK", pk)
    return str(pk)

def check_outpost_ping_url(hostname="127.0.0.1"):
    url = f"http://{hostname}:9000{OUTPOST_PING_PATH}"
    if hostname == "127.0.0.1":
        code, parsed, raw = raw_request("GET", OUTPOST_PING_PATH, token=None)
    else:
        req = urllib.request.Request(url, method="GET")
        try:
            with opener.open(req, timeout=5) as response:
                code = getattr(response, "status", 200)
        except urllib.error.HTTPError as error:
            code = error.code
        except Exception:
            code = 0
    return code == 204, code

def wait_for_outpost(provider_pk):
    deadline = time.time() + 90
    last_code = 0
    while time.time() <= deadline:
        outpost = find_embedded_outpost()
        if provider_pk in provider_ids_from_outpost(outpost):
            ok, code = check_outpost_ping_url("127.0.0.1")
            last_code = code
            if ok:
                emit("AUTHENTIK_OUTPOST_READY_STATUS", "ready")
                emit("INTERNAL_FORWARD_AUTH_STATUS", "ready")
                return
        time.sleep(5)
    fail("forwardauth", f"Embedded Outpost did not refresh before timeout. Last internal outpost ping HTTP status: {last_code}")

def configure():
    auth_flow = lookup_flow("default-authentication-flow", "AUTHENTIK_AUTHENTICATION_FLOW_STATUS")
    authz_flow = lookup_flow("default-provider-authorization-implicit-consent", "AUTHENTIK_AUTHORIZATION_FLOW_STATUS")
    invalidation_flow = lookup_flow("default-provider-invalidation-flow", "AUTHENTIK_INVALIDATION_FLOW_STATUS")
    provider_pk = configure_provider(auth_flow, authz_flow, invalidation_flow)
    emit("AUTHENTIK_PROVIDER_MODE", "forward_domain")
    configure_application(provider_pk)
    configure_outpost(provider_pk)
    wait_for_outpost(provider_pk)
    emit("FORWARD_AUTH_STATUS", "ready")

def main():
    validate_token()
    if payload.get("action") == "inspect":
        inspect_state()
    elif payload.get("action") == "configure":
        configure()
    else:
        fail("input", "Unknown Authentik automation action.")
    emit("RESULT", "ok")

main()
PYCODE
}

function apply_automation_result_file() {
    local file="$1" key="" value=""
    while IFS='=' read -r key value; do
        case "$key" in
            SCRIPT63_AUTOMATION_MODE) SCRIPT63_AUTOMATION_MODE="$value" ;;
            AUTHENTIK_API_ACCESS_STATUS) AUTHENTIK_API_ACCESS_STATUS="$value" ;;
            AUTHENTIK_AUTHENTICATION_FLOW_STATUS) AUTHENTIK_AUTHENTICATION_FLOW_STATUS="$value" ;;
            AUTHENTIK_AUTHORIZATION_FLOW_STATUS) AUTHENTIK_AUTHORIZATION_FLOW_STATUS="$value" ;;
            AUTHENTIK_INVALIDATION_FLOW_STATUS) AUTHENTIK_INVALIDATION_FLOW_STATUS="$value" ;;
            AUTHENTIK_PROVIDER_STATUS) AUTHENTIK_PROVIDER_STATUS="$value" ;;
            AUTHENTIK_PROVIDER_PK) AUTHENTIK_PROVIDER_PK="$value" ;;
            AUTHENTIK_PROVIDER_MODE) AUTHENTIK_PROVIDER_MODE="$value" ;;
            AUTHENTIK_APPLICATION_STATUS) AUTHENTIK_APPLICATION_STATUS="$value" ;;
            AUTHENTIK_APPLICATION_SLUG) AUTHENTIK_APPLICATION_SLUG="$value" ;;
            AUTHENTIK_OUTPOST_STATUS) AUTHENTIK_OUTPOST_STATUS="$value" ;;
            AUTHENTIK_OUTPOST_PK) AUTHENTIK_OUTPOST_PK="$value" ;;
            FORWARD_AUTH_STATUS) FORWARD_AUTH_STATUS="$value" ;;
            INTERNAL_FORWARD_AUTH_STATUS) INTERNAL_FORWARD_AUTH_STATUS="$value" ;;
            ERROR_STAGE) AUTHENTIK_AUTOMATION_ERROR_STAGE="$value" ;;
            ERROR_MESSAGE) AUTHENTIK_AUTOMATION_ERROR_MESSAGE="$value" ;;
        esac
    done < "$file"
}

function automation_failure_message() {
    case "${AUTHENTIK_AUTOMATION_ERROR_STAGE:-unknown}" in
        api-token) printf 'Authentik API token validation failed.' ;;
        flow) printf 'Required Authentik flow was not found.' ;;
        provider) printf 'Authentik ForwardAuth provider configuration failed.' ;;
        application) printf 'Authentik application configuration failed.' ;;
        outpost) printf 'Embedded Outpost attachment failed.' ;;
        forwardauth) printf 'ForwardAuth endpoint returned an infrastructure failure.' ;;
        *) printf 'Authentik automation failed.' ;;
    esac
}

function run_authentik_python_action() {
    local action="$1" py_code="" payload="" out_file="" err_file=""
    init_deploy_output_log
    py_code="$(authentik_python_code)"
    payload="$(build_authentik_automation_payload "$action")"
    out_file="$(mktemp /tmp/circl8-authentik-api-out.XXXXXX)"
    err_file="$(mktemp /tmp/circl8-authentik-api-err.XXXXXX)"
    if printf '%s' "$payload" | docker_cmd exec -i authentik-server python -c "$py_code" >"$out_file" 2>"$err_file"; then
        apply_automation_result_file "$out_file"
        rm -f "$out_file" "$err_file"
        return 0
    fi
    apply_automation_result_file "$out_file" || true
    append_deploy_log "Authentik automation stderr, sanitized:"
    append_file_to_deploy_log_sanitized "$err_file"
    append_deploy_log "Authentik automation result, sanitized:"
    append_file_to_deploy_log_sanitized "$out_file"
    rm -f "$out_file" "$err_file"
    return 1
}

function inspect_existing_authentik_deployment() {
    local pg_health="" server_state="" worker_state=""
    pg_health="$(docker_inspect_value '{{.State.Health.Status}}' authentik-postgresql)"
    [ "$pg_health" == "healthy" ] && AUTHENTIK_POSTGRES_STATUS="healthy" || AUTHENTIK_POSTGRES_STATUS="unknown"
    server_state="$(docker_inspect_value '{{.State.Running}} {{.State.Restarting}}' authentik-server)"
    if [ "${server_state%% *}" == "true" ] && [ "${server_state##* }" == "false" ]; then AUTHENTIK_SERVER_STATUS="running"; else AUTHENTIK_SERVER_STATUS="unknown"; fi
    worker_state="$(docker_inspect_value '{{.State.Running}} {{.State.Restarting}}' authentik-worker)"
    if [ "${worker_state%% *}" == "true" ] && [ "${worker_state##* }" == "false" ]; then AUTHENTIK_WORKER_STATUS="running"; else AUTHENTIK_WORKER_STATUS="unknown"; fi
    if authentik_internal_api_check_once; then AUTHENTIK_INTERNAL_API_STATUS="ready"; else AUTHENTIK_INTERNAL_API_STATUS="unknown"; fi
    if [ "$AUTHENTIK_POSTGRES_STATUS" == "healthy" ] && [ "$AUTHENTIK_SERVER_STATUS" == "running" ] && [ "$AUTHENTIK_WORKER_STATUS" == "running" ] && [ "$AUTHENTIK_INTERNAL_API_STATUS" == "ready" ]; then
        AUTHENTIK_DEPLOYMENT_STATUS="completed"
        SCRIPT63_DEPLOYMENT_STATUS="completed"
        SCRIPT63_READY_FOR_AUTOMATION_LANE="yes"
        return 0
    fi
    SCRIPT63_READY_FOR_AUTOMATION_LANE="no"
    return 1
}

function ensure_authentik_deployed_for_automation() {
    if inspect_existing_authentik_deployment; then
        return 0
    fi
    run_authentik_deploy
    inspect_existing_authentik_deployment || fail_with_failure_log "Authentik deployment readiness is required before automation."
}

function inspect_authentik_automation_preflight() {
    SCRIPT63_LANE="automation"
    if ! inspect_existing_authentik_deployment; then
        return 0
    fi
    validate_authentik_compose_config
    if run_authentik_python_action inspect; then
        AUTHENTIK_API_ACCESS_STATUS="valid"
        return 0
    fi
    fail_with_failure_log "$(automation_failure_message)"
}

function show_automation_preflight() {
    section "AUTHENTIK AUTOMATION PREFLIGHT"
    aligned_status_line "Deployment" "completed"
    aligned_status_line "Compose config" "$AUTHENTIK_COMPOSE_CONFIG_STATUS" "$(status_color_for_value "$AUTHENTIK_COMPOSE_CONFIG_STATUS")"
    aligned_status_line "Automation mode" "$SCRIPT63_AUTOMATION_MODE" "$(rerun_ui_color "$SCRIPT63_AUTOMATION_MODE")"
    aligned_status_line "PostgreSQL" "$AUTHENTIK_POSTGRES_STATUS" "$(status_color_for_value "$AUTHENTIK_POSTGRES_STATUS")"
    aligned_status_line "Server" "$AUTHENTIK_SERVER_STATUS" "$(status_color_for_value "$AUTHENTIK_SERVER_STATUS")"
    aligned_status_line "Worker" "$AUTHENTIK_WORKER_STATUS" "$(status_color_for_value "$AUTHENTIK_WORKER_STATUS")"
    aligned_status_line "Internal API" "$AUTHENTIK_INTERNAL_API_STATUS" "$(status_color_for_value "$AUTHENTIK_INTERNAL_API_STATUS")"
    aligned_status_line "API token" "ready"
    aligned_status_line "Provider" "$AUTHENTIK_PROVIDER_STATUS" "$(rerun_ui_color "$AUTHENTIK_PROVIDER_STATUS")"
    aligned_status_line "Application" "$AUTHENTIK_APPLICATION_STATUS" "$(rerun_ui_color "$AUTHENTIK_APPLICATION_STATUS")"
    aligned_status_line "Embedded Outpost" "$AUTHENTIK_OUTPOST_STATUS" "$(rerun_ui_color "$AUTHENTIK_OUTPOST_STATUS")"
    aligned_status_line "ForwardAuth" "$FORWARD_AUTH_STATUS" "$(status_color_for_value "$FORWARD_AUTH_STATUS")"
}

function configure_authentik_forwardauth() {
    section "CONFIGURE AUTHENTIK"
    progress_line "Configuring Authentik ForwardAuth"
    if ! run_authentik_python_action configure; then
        clear_progress_line
        case "${AUTHENTIK_AUTOMATION_ERROR_STAGE:-unknown}" in
            api-token)
                mini_header_compact "API access"
                deploy_status_line "API token" "failed" "$RD"
                ;;
            flow)
                mini_header_compact "API access"
                deploy_status_line "API token" "valid" "$GN"
                mini_header "Flow lookup"
                [ "$AUTHENTIK_AUTHENTICATION_FLOW_STATUS" != "not-run" ] && deploy_status_line "Authentication flow" "$AUTHENTIK_AUTHENTICATION_FLOW_STATUS" "$(status_color_for_value "$AUTHENTIK_AUTHENTICATION_FLOW_STATUS")"
                [ "$AUTHENTIK_AUTHORIZATION_FLOW_STATUS" != "not-run" ] && deploy_status_line "Authorization flow" "$AUTHENTIK_AUTHORIZATION_FLOW_STATUS" "$(status_color_for_value "$AUTHENTIK_AUTHORIZATION_FLOW_STATUS")"
                [ "$AUTHENTIK_INVALIDATION_FLOW_STATUS" != "not-run" ] && deploy_status_line "Invalidation flow" "$AUTHENTIK_INVALIDATION_FLOW_STATUS" "$(status_color_for_value "$AUTHENTIK_INVALIDATION_FLOW_STATUS")"
                ;;
            provider)
                mini_header "ForwardAuth provider"
                deploy_status_line "Provider" "failed" "$RD"
                ;;
            application)
                mini_header "Application"
                deploy_status_line "Application" "failed" "$RD"
                ;;
            outpost|forwardauth)
                mini_header "Embedded Outpost"
                deploy_status_line "Embedded Outpost" "failed" "$RD"
                ;;
            *)
                mini_header_compact "API access"
                deploy_status_line "API token" "failed" "$RD"
                ;;
        esac
        fail_with_failure_log "$(automation_failure_message)"
    fi
    clear_progress_line

    mini_header_compact "API access"
    deploy_status_line "API token" "valid" "$GN"

    mini_header "Flow lookup"
    deploy_status_line "Authentication flow" "$AUTHENTIK_AUTHENTICATION_FLOW_STATUS" "$GN"
    deploy_status_line "Authorization flow" "$AUTHENTIK_AUTHORIZATION_FLOW_STATUS" "$GN"
    deploy_status_line "Invalidation flow" "$AUTHENTIK_INVALIDATION_FLOW_STATUS" "$GN"

    mini_header "ForwardAuth provider"
    deploy_status_line "Provider" "$AUTHENTIK_PROVIDER_STATUS" "$GN"

    mini_header "Application"
    deploy_status_line "Application" "$AUTHENTIK_APPLICATION_STATUS" "$GN"

    mini_header "Embedded Outpost"
    progress_line "Waiting for Embedded Outpost refresh"
    clear_progress_line
    deploy_status_line "Embedded Outpost" "$AUTHENTIK_OUTPOST_STATUS" "$GN"
    deploy_status_line "Embedded Outpost" "ready" "$GN"
}

function outpost_ping_check_from_authentik_server() {
    local py_code="" url="http://127.0.0.1:9000/outpost.goauthentik.io/ping"
    py_code='import sys, urllib.request, urllib.error
try:
    response=urllib.request.urlopen(sys.argv[1], timeout=5)
    code=getattr(response, "status", 200)
except urllib.error.HTTPError as error:
    code=error.code
except Exception:
    code=0
sys.exit(0 if code == 204 else 1)'
    docker_cmd exec authentik-server python -c "$py_code" "$url" >/dev/null 2>&1 \
        || docker_cmd exec authentik-server python3 -c "$py_code" "$url" >/dev/null 2>&1
}

function append_traefik_ping_failure_diagnostics() {
    local method="$1" url="$2" parsed_status="${3:-none}" output="${4:-}"
    init_deploy_output_log
    append_deploy_log "Traefik outpost ping verification failed."
    append_deploy_log "Traefik ping method: ${method}"
    append_deploy_log "Traefik ping target: ${url}"
    append_deploy_log "Traefik ping parsed HTTP status: ${parsed_status:-none}"
    append_deploy_log "Traefik ping command output, sanitized excerpt:"
    if [ -n "$output" ]; then
        printf '%s\n' "$output" \
            | sed -E '/(PASSWORD|TOKEN|SECRET_KEY|AUTHENTIK_EMAIL__PASSWORD|AUTHENTIK_POSTGRES_PASSWORD|AUTHENTIK_BOOTSTRAP)/Id' \
            | head -40 >> "$DEPLOY_OUTPUT_LOG" || true
    else
        printf '%s\n' "<no output captured>" >> "$DEPLOY_OUTPUT_LOG"
    fi
}

function parse_http_status_from_headers() {
    awk '/HTTP\/[0-9.]+[[:space:]]+[0-9][0-9][0-9]/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9][0-9][0-9]$/) code = $i } END { print code }'
}

function parse_http_status_from_curl_output() {
    awk 'NF { line=$0 } END { gsub(/[^0-9]/, "", line); if (length(line) >= 3) print substr(line, length(line)-2, 3) }'
}

function outpost_ping_check_from_traefik() {
    local url="http://authentik-server:9000/outpost.goauthentik.io/ping" output="" code=""

    if docker_cmd exec traefik sh -c 'command -v wget >/dev/null 2>&1' >/dev/null 2>&1; then
        output="$(docker_cmd exec traefik sh -lc 'url="$1"; wget -S -O /dev/null "$url" 2>&1' sh "$url" 2>&1 || true)"
        code="$(printf '%s\n' "$output" | parse_http_status_from_headers)"
        if [ "$code" = "204" ]; then
            return 0
        fi
        append_traefik_ping_failure_diagnostics "wget" "$url" "${code:-none}" "$output"
        return 1
    fi

    if docker_cmd exec traefik sh -c 'command -v curl >/dev/null 2>&1' >/dev/null 2>&1; then
        output="$(docker_cmd exec traefik sh -lc 'url="$1"; curl -sS -o /dev/null -w "%{http_code}" "$url" 2>&1 || true' sh "$url" 2>&1 || true)"
        code="$(printf '%s\n' "$output" | parse_http_status_from_curl_output)"
        if [ "$code" = "204" ]; then
            return 0
        fi
        append_traefik_ping_failure_diagnostics "curl" "$url" "${code:-none}" "$output"
        return 1
    fi

    append_deploy_log "Traefik outpost ping verification failed."
    append_deploy_log "Traefik ping method: unavailable"
    append_deploy_log "Traefik ping target: ${url}"
    append_deploy_log "Traefik container has no wget/curl for endpoint verification. No helper image was pulled."
    return 1
}

function verify_traefik_logs_for_forwardauth() {
    local log_file=""
    log_file="$(mktemp /tmp/circl8-traefik-authentik-logs.XXXXXX)"
    docker_cmd logs --since 2m traefik >"$log_file" 2>&1 || true
    if grep -Eiq 'authentik-server.*(no such host|server misbehaving|connection refused)|forwardAuth.*(500|error)|middleware.*authentik.*error' "$log_file"; then
        append_deploy_log "Recent Traefik ForwardAuth errors:"
        append_file_to_deploy_log_sanitized "$log_file"
        rm -f "$log_file"
        TRAEFIK_FORWARD_AUTH_ERRORS="detected"
        TRAEFIK_RESOLUTION_STATUS="failed"
        return 1
    fi
    rm -f "$log_file"
    TRAEFIK_FORWARD_AUTH_ERRORS="none"
    TRAEFIK_RESOLUTION_STATUS="ready"
    return 0
}

function verify_forwardauth() {
    section "VERIFY FORWARDAUTH"
    mini_header_compact "ForwardAuth"
    if [ "$INTERNAL_FORWARD_AUTH_STATUS" != "ready" ]; then
        if outpost_ping_check_from_authentik_server; then
            INTERNAL_FORWARD_AUTH_STATUS="ready"
        else
            INTERNAL_FORWARD_AUTH_STATUS="failed"
            deploy_status_line "Internal ForwardAuth" "failed" "$RD"
            fail_with_failure_log "Authentik Embedded Outpost ping failed internally."
        fi
    fi
    deploy_status_line "Internal ForwardAuth" "$INTERNAL_FORWARD_AUTH_STATUS" "$GN"

    if outpost_ping_check_from_traefik; then
        TRAEFIK_FORWARD_AUTH_STATUS="ready"
    else
        TRAEFIK_FORWARD_AUTH_STATUS="failed"
        deploy_status_line "Traefik endpoint" "failed" "$RD"
        fail_with_failure_log "Authentik Embedded Outpost ping failed from Traefik network context."
    fi
    deploy_status_line "Traefik endpoint" "$TRAEFIK_FORWARD_AUTH_STATUS" "$GN"

    if [ "$TRAEFIK_AUTHENTIK_REFERENCES" == "ready" ]; then
        deploy_status_line "Traefik middleware" "present" "$GN"
    else
        deploy_status_line "Traefik middleware" "missing" "$RD"
        fail_with_failure_log "Traefik Authentik middleware references are missing."
    fi

    if verify_traefik_logs_for_forwardauth; then
        deploy_status_line "Traefik resolution" "$TRAEFIK_RESOLUTION_STATUS" "$GN"
    else
        deploy_status_line "Traefik resolution" "failed" "$RD"
        fail_with_failure_log "Traefik reported ForwardAuth infrastructure errors."
    fi
    FORWARD_AUTH_STATUS="ready"
}

function show_verification_marker_scaffold() {
    section "VERIFICATION / MARKER"
    validate_authentik_compose_config
    SCRIPT63_STATUS="completed"
    SCRIPT63_VERIFY_STATUS="PASS"
    SCRIPT63_DEPLOYMENT_STATUS="completed"
    SCRIPT63_READY_FOR_SCRIPT64="yes"
    write_completion_marker
    write_verify_report
    deploy_status_line "Verification report" "created" "$GN"
    deploy_status_line "Completion marker" "written" "$GN"
}

function show_deploy_finished() {
    section_flash_success "FINISHED"
    mini_header_compact "Authentik"
    final_line "Status" "completed"
    final_line "Deployment" "$AUTHENTIK_DEPLOYMENT_STATUS" "$(status_color_for_value "$AUTHENTIK_DEPLOYMENT_STATUS")"
    final_line "PostgreSQL" "$AUTHENTIK_POSTGRES_STATUS" "$(status_color_for_value "$AUTHENTIK_POSTGRES_STATUS")"
    final_line "Server" "$AUTHENTIK_SERVER_STATUS" "$(status_color_for_value "$AUTHENTIK_SERVER_STATUS")"
    final_line "Worker" "$AUTHENTIK_WORKER_STATUS" "$(status_color_for_value "$AUTHENTIK_WORKER_STATUS")"
    final_line "Internal API" "$AUTHENTIK_INTERNAL_API_STATUS" "$(status_color_for_value "$AUTHENTIK_INTERNAL_API_STATUS")"
    final_line "Provider" "$AUTHENTIK_PROVIDER_STATUS" "$(status_color_for_value "$AUTHENTIK_PROVIDER_STATUS")"
    final_line "Application" "$AUTHENTIK_APPLICATION_STATUS" "$(status_color_for_value "$AUTHENTIK_APPLICATION_STATUS")"
    final_line "Embedded Outpost" "$AUTHENTIK_OUTPOST_STATUS" "$(status_color_for_value "$AUTHENTIK_OUTPOST_STATUS")"
    final_line "ForwardAuth" "$FORWARD_AUTH_STATUS" "$(status_color_for_value "$FORWARD_AUTH_STATUS")"
    final_line "Completion marker" "written"

    mini_header "Verification"
    final_line "Status" "$SCRIPT63_VERIFY_STATUS"
    final_line "Verify log" "$VERIFY_LOG" "$BL"

    mini_header "Next Step"
    echo -e "${GN}Run Script 6.4.${CL}"
}

function main() {
    init_script
    validate_script62_handoff
    runtime_preflight
    detect_authentik_state
    inspect_folders_required_for_deploy
    prepare_authentik_folders
    inspect_authentik_prep_for_deploy
    show_authentik_preflight
    show_authentik_prep_plan
    validate_prep_ready_for_deploy
    inspect_authentik_automation_preflight
    if [ "$SCRIPT63_READY_FOR_AUTOMATION_LANE" == "yes" ]; then
        show_automation_preflight
    fi
    show_setup_plan
    confirm_or_exit
    if [ "$SCRIPT63_READY_FOR_AUTOMATION_LANE" != "yes" ]; then
        ensure_authentik_deployed_for_automation
        inspect_authentik_automation_preflight
        show_automation_preflight
    fi
    configure_authentik_forwardauth
    verify_forwardauth
    show_verification_marker_scaffold
    show_deploy_finished
}

main "$@"
