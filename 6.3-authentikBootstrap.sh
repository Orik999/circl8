#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Project Circl8 - Script 6.3 Authentik Prep
# =========================================================
# Lane 4 only: hard gate, preflight, env/folder readiness validation,
# Authentik compose deployment, container readiness, deploy verify report,
# and no provider/application/outpost automation.

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
SCRIPT_VERSION="v1.0.4"
SCRIPT_UPDATED="2026-06-11"
SCRIPT_BUILD="authentik-deploy-readiness"

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
SCRIPT63_LANE="deploy"
SCRIPT63_STATUS="prepared-not-deployed"
SCRIPT63_VERIFY_STATUS="PREPARED"
SCRIPT63_DEPLOYMENT_STATUS="not-run"
SCRIPT63_MARKER_WRITTEN="no"
SCRIPT63_SECRET_STORAGE="env-only"
SCRIPT63_READY_FOR_DEPLOYMENT_LANE="no"
SCRIPT63_READY_FOR_AUTOMATION_LANE="no"

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
DOCKER_READINESS_STATUS="unknown"
DOCKER_DAEMON_READINESS_STATUS="unknown"
DOCKER_COMPOSE_READINESS_STATUS="unknown"
DOCKER_NETWORKS_READINESS_STATUS="unknown"
AUTHENTIK_DEPLOYMENT_STATUS="not-run"
AUTHENTIK_POSTGRES_STATUS="unknown"
AUTHENTIK_SERVER_STATUS="unknown"
AUTHENTIK_WORKER_STATUS="unknown"
AUTHENTIK_INTERNAL_API_STATUS="unknown"

# =========================================================
#  OUTPUT HELPERS
# =========================================================
function header_info() {
cat <<'BANNER'

 ██████╗██╗██████╗  ██████╗██╗     █████╗  █████╗     █████╗ ██╗   ██╗████████╗██╗  ██╗
██╔════╝██║██╔══██╗██╔════╝██║    ██╔══██╗██╔══██╗   ██╔══██╗██║   ██║╚══██╔══╝██║  ██║
██║     ██║██████╔╝██║     ██║    ╚█████╔╝╚█████╔╝   ███████║██║   ██║   ██║   ███████║
██║     ██║██╔══██╗██║     ██║    ██╔══██╗██╔══██╗   ██╔══██║██║   ██║   ██║   ██╔══██║
╚██████╗██║██║  ██║╚██████╗███████╗╚█████╔╝╚█████╔╝   ██║  ██║╚██████╔╝   ██║   ██║  ██║
 ╚═════╝╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝ ╚════╝  ╚════╝    ╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚═╝  ╚═╝

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

function status_color_for_value() {
    local value="${1:-unknown}"
    case "$value" in
        ready|present|completed|PASS|yes|running|active|responsive|detected|configured|generated|preserved|fixed|valid|installed|healthy|settled|DEPLOYED|SKELETON|PREPARED|fresh\ install|fresh-install|rerun/update|rerun-update|not\ written|not\ run|not-run|not\ used|planned|unchanged|stored\ root-only|env\ only|env-only|created|not\ needed|not-needed|reused|partial|will\ create|will-create|will\ generate|will-generate)
            printf '%s' "$GN"
            ;;
        warning|skipped|unknown|not\ detected|will\ install\ later|not\ present|not\ configured|reuse\ if\ present|missing|preserve\ in\ later\ lane|planned\ for\ later\ lane)
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
        pending-lane-5) printf 'pending lane 5' ;;
        deployed-auth-not-configured) printf 'deployed, Auth not configured' ;;
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
        printf '%s\n' "SCRIPT63_SETUP_MODE=${SCRIPT63_SETUP_MODE}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_EXISTING=${AUTHENTIK_EXISTING}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE=${AUTHENTIK_COMPOSE_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE_FILE=${AUTHENTIK_COMPOSE_FILE}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE_RUNTIME_PATH=${AUTHENTIK_COMPOSE_RUNTIME_PATH}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE_STATUS=${AUTHENTIK_COMPOSE_SOURCE_STATUS}"
        printf '%s\n' "SCRIPT63_AUTHENTIK_COMPOSE_CONFIG=${AUTHENTIK_COMPOSE_CONFIG_STATUS}"
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
        printf '%s\n' "SCRIPT63_FORWARD_AUTH_AUTOMATION=pending-lane-5"
        printf '%s\n' "SCRIPT63_PROVIDER=pending-lane-5"
        printf '%s\n' "SCRIPT63_APPLICATION=pending-lane-5"
        printf '%s\n' "SCRIPT63_AUTHENTIK_OUTPOST=pending-lane-5"
        printf '%s\n' "SCRIPT63_FORWARD_AUTH=pending-lane-5"
        printf '%s\n' "SCRIPT63_READY_FOR_SCRIPT64=no"
        printf '%s\n' "SCRIPT63_COMPLETION_MARKER_PATH=${SCRIPT63_MARKER}"
        printf '%s\n' "SCRIPT63_COMPLETION_MARKER_NOTE=not written in deploy lane"
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
    root_copy_regular_file "$tmp" "$dest"
    rm -f "$tmp"
}

function fail_with_verify_log() {
    local message="$1"
    write_verify_report || true
    echo -e "${CROSS} ${RD}${message}${CL}"
    echo -e "  ${BL}Verify log:${CL} ${VERIFY_LOG}"
    exit 1
}

function fail_with_failure_log() {
    local message="$1"
    if [ "${SCRIPT63_LANE:-}" == "deploy" ] && [ "${SCRIPT63_DEPLOYMENT_STATUS:-}" != "completed" ]; then
        SCRIPT63_STATUS="deploy-failed"
        SCRIPT63_VERIFY_STATUS="FAILED"
        SCRIPT63_DEPLOYMENT_STATUS="failed"
        SCRIPT63_READY_FOR_AUTOMATION_LANE="no"
    fi
    preserve_failure_log "$message" || true
    write_verify_report || true
    echo -e "${CROSS} ${RD}${message}${CL}"
    echo -e "  ${BL}Verify log:${CL}  ${VERIFY_LOG}"
    echo -e "  ${BL}Failure log:${CL} ${FAILURE_LOG}"
    exit 1
}

# Placeholder for final completion lane. Intentionally not called in lane 4.
function write_completion_marker() {
    return 0
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
    if root_read_file "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null | grep -Eq 'chain-authentik|authentik-server|outpost\.goauthentik\.io'; then
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
        fail_with_verify_log "Docker project directory owner/group could not be detected."
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

function ensure_managed_dir() {
    local path="$1" status_var="$2" mode="${3:-755}" preserve_if_nonempty="${4:-no}" changed="no" was_nonempty="no" current_owner_group="" current_mode=""

    if ! root_path_exists "$path"; then
        if ! root_install_dir "$path" "$mode"; then
            printf -v "$status_var" '%s' "failed"
            return 1
        fi
        changed="yes"
    fi

    if [ "$preserve_if_nonempty" == "yes" ] && root_dir_has_entries "$path"; then
        was_nonempty="yes"
    fi

    current_owner_group="$(root_stat_owner_group "$path")"
    if [ "$current_owner_group" != "$AUTHENTIK_DIR_OWNER_GROUP" ]; then
        if ! root_set_dir_owner_group "$path" "$AUTHENTIK_DIR_OWNER_GROUP"; then
            printf -v "$status_var" '%s' "failed"
            return 1
        fi
        changed="yes"
    fi

    current_mode="$(root_stat_mode "$path")"
    if [ "$current_mode" != "$mode" ]; then
        if ! root_set_dir_mode "$path" "$mode"; then
            printf -v "$status_var" '%s' "failed"
            return 1
        fi
        changed="yes"
    fi

    if ! root_write_test_dir "$path"; then
        printf -v "$status_var" '%s' "failed"
        return 1
    fi

    if [ "$was_nonempty" == "yes" ] && [ "$changed" == "no" ]; then
        printf -v "$status_var" '%s' "preserved"
    elif [ "$changed" == "yes" ]; then
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
    resolve_authentik_dir_owner_group
    ensure_regular_dir "$AUTHENTIK_APPDATA_DIR" AUTHENTIK_APPDATA_DIR_STATUS || fail_with_verify_log "Authentik appdata folder could not be prepared safely."
    ensure_postgresql_dir || fail_with_verify_log "PostgreSQL data folder could not be prepared safely."
    ensure_regular_dir "$AUTHENTIK_MEDIA_DIR" AUTHENTIK_MEDIA_DIR_STATUS || fail_with_verify_log "Authentik media folder could not be prepared safely."
    ensure_regular_dir "$AUTHENTIK_TEMPLATES_DIR" AUTHENTIK_TEMPLATES_DIR_STATUS || fail_with_verify_log "Authentik templates folder could not be prepared safely."
    ensure_regular_dir "$AUTHENTIK_CERTS_DIR" AUTHENTIK_CERTS_DIR_STATUS || fail_with_verify_log "Authentik certs folder could not be prepared safely."
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

function inspect_folders_required_for_deploy() {
    AUTHENTIK_APPDATA_DIR="${DOCKER_DIR}/appdata/authentik"
    AUTHENTIK_POSTGRESQL_DIR="${AUTHENTIK_APPDATA_DIR}/postgresql"
    AUTHENTIK_MEDIA_DIR="${AUTHENTIK_APPDATA_DIR}/media"
    AUTHENTIK_TEMPLATES_DIR="${AUTHENTIK_APPDATA_DIR}/custom-templates"
    AUTHENTIK_CERTS_DIR="${AUTHENTIK_APPDATA_DIR}/certs"

    if root_path_exists "$AUTHENTIK_APPDATA_DIR"; then AUTHENTIK_APPDATA_DIR_STATUS="ready"; else AUTHENTIK_APPDATA_DIR_STATUS="failed"; fi
    if root_path_exists "$AUTHENTIK_POSTGRESQL_DIR"; then
        if root_dir_has_entries "$AUTHENTIK_POSTGRESQL_DIR"; then AUTHENTIK_POSTGRESQL_DIR_STATUS="preserved"; else AUTHENTIK_POSTGRESQL_DIR_STATUS="ready"; fi
    else
        AUTHENTIK_POSTGRESQL_DIR_STATUS="failed"
    fi
    if root_path_exists "$AUTHENTIK_MEDIA_DIR"; then AUTHENTIK_MEDIA_DIR_STATUS="ready"; else AUTHENTIK_MEDIA_DIR_STATUS="failed"; fi
    if root_path_exists "$AUTHENTIK_TEMPLATES_DIR"; then AUTHENTIK_TEMPLATES_DIR_STATUS="ready"; else AUTHENTIK_TEMPLATES_DIR_STATUS="failed"; fi
    if root_path_exists "$AUTHENTIK_CERTS_DIR"; then AUTHENTIK_CERTS_DIR_STATUS="ready"; else AUTHENTIK_CERTS_DIR_STATUS="failed"; fi

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

function validate_prep_ready_for_deploy() {
    if [ "$SCRIPT63_READY_FOR_DEPLOYMENT_LANE" != "yes" ]; then
        fail_with_verify_log "Authentik preparation is not ready for deployment."
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

    aligned_status_line "Mode" "$SCRIPT63_SETUP_MODE"
    aligned_status_line "Existing Authentik" "$AUTHENTIK_EXISTING" "$(status_color_for_value "$AUTHENTIK_EXISTING")"
    aligned_status_line "Authentik compose" "$AUTHENTIK_COMPOSE_STATUS" "$(status_color_for_value "$AUTHENTIK_COMPOSE_STATUS")"
    aligned_status_line "Public route" "$AUTHENTIK_ROUTE_HOST"
    aligned_status_line "External URL" "$AUTHENTIK_EXTERNAL_URL"
    aligned_status_line "Database" "PostgreSQL 17"
    aligned_status_line "PostgreSQL data" "$AUTHENTIK_POSTGRESQL_DIR_STATUS"
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

    mini_header "Environment"
    aligned_status_line "AUTHENTIK_SECRET_KEY" "$(display_env_plan_status "$AUTHENTIK_SECRET_KEY_STATUS")"
    aligned_status_line "PostgreSQL password" "$(display_env_plan_status "$AUTHENTIK_POSTGRES_PASSWORD_STATUS")"
    aligned_status_line "Bootstrap email" "$(display_env_plan_status "$AUTHENTIK_BOOTSTRAP_EMAIL_STATUS")"
    aligned_status_line "Bootstrap password" "$(display_env_plan_status "$AUTHENTIK_BOOTSTRAP_PASSWORD_STATUS")"
    aligned_status_line "Bootstrap token" "$(display_env_plan_status "$AUTHENTIK_BOOTSTRAP_TOKEN_STATUS")"
    aligned_status_line "SMTP" "$SMTP_STATUS" "$(status_color_for_value "$SMTP_STATUS")"
    aligned_status_line "Secret storage" "$SCRIPT63_SECRET_STORAGE" "$GN"

    mini_header "Folders"
    aligned_status_line "Authentik appdata" "$AUTHENTIK_APPDATA_DIR_PLAN"
    aligned_status_line "PostgreSQL data" "$AUTHENTIK_POSTGRESQL_DIR_PLAN"
    aligned_status_line "Media" "$AUTHENTIK_MEDIA_DIR_PLAN"
    aligned_status_line "Templates" "$AUTHENTIK_TEMPLATES_DIR_PLAN"
    aligned_status_line "Certs" "$AUTHENTIK_CERTS_DIR_PLAN"
}

# =========================================================
#  PLAN / CONFIRMATION / PREP CHECKS
# =========================================================
function show_setup_plan() {
    section "SETUP PLAN"

    if [ "$SCRIPT63_SETUP_MODE" == "rerun-update" ]; then
        echo -e "${YW}Rerun/update detected. Authentik data, database, and secrets will be preserved.${CL}"
        echo -e "${YW}This lane refreshes the compose file, redeploys Authentik, and verifies readiness only.${CL}"
    else
        echo -e "${YW}Script 6.3 lane 4 will deploy Authentik containers only.${CL}"
        echo -e "${YW}Provider, application, Embedded Outpost, and ForwardAuth automation remain pending lane 5.${CL}"
    fi

    mini_header "Setup mode"
    aligned_status_line "Mode" "$SCRIPT63_SETUP_MODE"
    aligned_status_line "Compose file" "$([ "$SCRIPT63_SETUP_MODE" == "rerun-update" ] && printf 'refresh' || printf 'install/refresh')"
    aligned_status_line "Data/secrets" "$([ "$SCRIPT63_SETUP_MODE" == "rerun-update" ] && printf 'preserve' || printf 'prepared')"
    aligned_status_line "Docker networks" "verify/reuse"
    aligned_status_line "Compose config" "validate Authentik only"
    aligned_status_line "Deployment" "$([ "$SCRIPT63_SETUP_MODE" == "rerun-update" ] && printf 'redeploy Authentik only' || printf 'deploy Authentik only')"
    aligned_status_line "Readiness" "PostgreSQL/server/worker/internal API"
    aligned_status_line "ForwardAuth automation" "pending-lane-5"
    aligned_status_line "Completion marker" "not written"
}

function confirm_or_exit() {
    local answer=""
    echo ""
    answer="$(timed_yes_no_value_only "Apply this Authentik deployment plan?" "y")"
    if [[ "$answer" =~ ^[Nn]$ ]]; then
        msg_ok "Authentik deployment plan cancelled"
        exit 0
    fi
    tty_println "${CM} ${GN}Applying confirmed Authentik deployment plan.${CL}"
}

function install_authentik_compose_file() {
    local local_source="./docker/${AUTHENTIK_COMPOSE_FILE}"
    AUTHENTIK_COMPOSE_RUNTIME_PATH="${COMPOSE_DIR}/${AUTHENTIK_COMPOSE_FILE}"
    init_deploy_output_log

    if [ -f "$local_source" ]; then
        append_deploy_log "Installing Authentik compose from repo-local source: ${local_source}"
        if root_copy_regular_file "$local_source" "$AUTHENTIK_COMPOSE_RUNTIME_PATH" && root_file_not_empty "$AUTHENTIK_COMPOSE_RUNTIME_PATH"; then
            AUTHENTIK_COMPOSE_SOURCE_STATUS="installed"
            AUTHENTIK_COMPOSE_STATUS="present"
            AUTHENTIK_COMPOSE_LOCATION="$AUTHENTIK_COMPOSE_RUNTIME_PATH"
            return 0
        fi
    else
        append_deploy_log "Repo-local Authentik compose source not found; downloading from GitHub raw URL."
        if root_download_url_to_file "$AUTHENTIK_RAW_COMPOSE_URL" "$AUTHENTIK_COMPOSE_RUNTIME_PATH" && root_file_not_empty "$AUTHENTIK_COMPOSE_RUNTIME_PATH"; then
            AUTHENTIK_COMPOSE_SOURCE_STATUS="installed"
            AUTHENTIK_COMPOSE_STATUS="present"
            AUTHENTIK_COMPOSE_LOCATION="$AUTHENTIK_COMPOSE_RUNTIME_PATH"
            return 0
        fi
    fi

    AUTHENTIK_COMPOSE_SOURCE_STATUS="failed"
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
    deploy_authentik_compose
    deploy_status_line "Compose deployment" "$AUTHENTIK_DEPLOYMENT_STATUS" "$GN"
    wait_for_postgresql_healthy
    deploy_status_line "PostgreSQL" "$AUTHENTIK_POSTGRES_STATUS" "$GN"
    wait_for_container_running authentik-server AUTHENTIK_SERVER_STATUS
    deploy_status_line "Authentik server" "$AUTHENTIK_SERVER_STATUS" "$GN"
    wait_for_container_running authentik-worker AUTHENTIK_WORKER_STATUS
    deploy_status_line "Authentik worker" "$AUTHENTIK_WORKER_STATUS" "$GN"
    wait_for_internal_api_ready
    deploy_status_line "Internal API" "$AUTHENTIK_INTERNAL_API_STATUS" "$GN"

    SCRIPT63_STATUS="deployed-auth-not-configured"
    SCRIPT63_VERIFY_STATUS="DEPLOYED"
    SCRIPT63_DEPLOYMENT_STATUS="completed"
    SCRIPT63_READY_FOR_AUTOMATION_LANE="yes"
}

function show_verification_marker_scaffold() {
    section "VERIFICATION / MARKER"
    write_verify_report
    deploy_status_line "Authentik deploy report" "created" "$GN" 24
    deploy_status_line "Completion marker" "not written" "$GN" 24
}

function show_deploy_finished() {
    section_flash_success "AUTHENTIK DEPLOY COMPLETE"

    mini_header "Authentik"
    final_line "Status" "deployed"
    final_line "PostgreSQL" "$AUTHENTIK_POSTGRES_STATUS" "$(status_color_for_value "$AUTHENTIK_POSTGRES_STATUS")"
    final_line "Server" "$AUTHENTIK_SERVER_STATUS" "$(status_color_for_value "$AUTHENTIK_SERVER_STATUS")"
    final_line "Worker" "$AUTHENTIK_WORKER_STATUS" "$(status_color_for_value "$AUTHENTIK_WORKER_STATUS")"
    final_line "Internal API" "$AUTHENTIK_INTERNAL_API_STATUS" "$(status_color_for_value "$AUTHENTIK_INTERNAL_API_STATUS")"
    final_line "ForwardAuth automation" "pending-lane-5" "$YW"
    final_line "Completion marker" "not written"

    mini_header "Verification"
    final_line "Status" "$SCRIPT63_VERIFY_STATUS"
    final_line "Verify log" "$VERIFY_LOG" "$BL"

    mini_header "Next Step"
    echo -e "${GN}Continue Script 6.3 implementation: provider, application, Embedded Outpost, and ForwardAuth automation.${CL}"
}

function main() {
    init_script
    validate_script62_handoff
    runtime_preflight
    detect_authentik_state
    inspect_authentik_prep_for_deploy
    show_authentik_preflight
    show_authentik_prep_plan
    validate_prep_ready_for_deploy
    show_setup_plan
    confirm_or_exit
    run_authentik_deploy
    show_verification_marker_scaffold
    show_deploy_finished
}

main "$@"
