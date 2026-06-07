#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Docker Bootstrap Setup
# =========================================================

# --- 1. COLOR VARIABLES (KEEP ALL FOR FUTURE MODIFICATIONS) ---
# Central visual theme aligned with Script 1 / Script 4 / Script 5 / Script 6.
YW="$(printf '\033[33m')"
YL="$(printf '\033[1;93m')"
BL="$(printf '\033[36m')"
RD="$(printf '\033[01;31m')"
BGN="$(printf '\033[4;92m')"
GN="$(printf '\033[1;92m')"
ANS="$(printf '\033[1;95m')"
DGN="$(printf '\033[32m')"
CL="$(printf '\033[m')"
CLF="$(printf '\033[5m')"
BFR="\\r\\033[K"

HOLD="-"
CM="${GN}✓${CL}"
WARN="${YW}!${CL}"
CROSS="${RD}✗${CL}"
BORDER="${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"

SCRIPT_SOURCE="6.5-stackDeployVerify.sh"
SCRIPT_VERSION="v1.3.58"
SCRIPT_UPDATED="2026-06-07"
SCRIPT_BUILD="traefik-acme-email-validation"

# --- 2. GLOBAL VARIABLES ---
# Stores timers, paths, GitHub source, Docker state and final bootstrap results.
T=15
SETUP_OPTIONS_LABEL_WIDTH="22"
APPLY_LABEL_WIDTH="18"

LOG_FILE="/var/log/docker-bootstrap-setup.log"
RUNTIME_LOG_FILE=""
VERIFY_LOG="/var/log/docker-bootstrap-setup-verify.log"
VERIFY_DISPLAY_LOG="/var/log/docker-stack-deploy-verify-display.log"
VERIFY_STATUS="not-run"
VERIFY_PASS_COUNT="0"
VERIFY_WARN_COUNT="0"
VERIFY_FAIL_COUNT="0"
COMPLETED_MARKER="/root/.docker-bootstrap-setup-completed"

DEFAULT_DOCKER_USER="${SUDO_USER:-orik}"
DOCKER_USER="${DOCKER_USER:-$DEFAULT_DOCKER_USER}"
DOCKER_DIR="${DOCKER_DIR:-/home/${DOCKER_USER}/docker}"
COMPOSE_DIR="${COMPOSE_DIR:-${DOCKER_DIR}/compose}"
ENV_FILE="${ENV_FILE:-${DOCKER_DIR}/.env}"

DEFAULT_GITHUB_RAW_BASE="https://raw.githubusercontent.com/Orik999/circl8/refs/heads/main/docker"
GITHUB_RAW_BASE="${GITHUB_RAW_BASE_OVERRIDE:-${GITHUB_RAW_BASE:-$DEFAULT_GITHUB_RAW_BASE}}"
if [ -n "${GITHUB_RAW_BASE_OVERRIDE:-}" ] || [ "${GITHUB_RAW_BASE}" != "$DEFAULT_GITHUB_RAW_BASE" ]; then
    COMPOSE_SOURCE_LABEL="override from environment"
else
    COMPOSE_SOURCE_LABEL="default repo"
fi
TRAEFIK_TEMPLATE_RAW_BASE="${TRAEFIK_TEMPLATE_RAW_BASE:-https://raw.githubusercontent.com/Orik999/circl8/refs/heads/main/docker/traefik}"
TRAEFIK_STATIC_TEMPLATE_URL="${TRAEFIK_STATIC_TEMPLATE_URL:-${TRAEFIK_TEMPLATE_RAW_BASE}/traefik.yml.template}"
TRAEFIK_DYNAMIC_TEMPLATE_URL="${TRAEFIK_DYNAMIC_TEMPLATE_URL:-${TRAEFIK_TEMPLATE_RAW_BASE}/dynamic-config.yml.template}"
SOCKET_PROXY_STACK_FILE="00-socket-proxy-compose.yml"
PORTAINER_STACK_FILE="01-[4]-portainer-compose.yml"
PORTAINER_BOOTSTRAP_OVERRIDE_FILE_NAME="01-[4]-portainer-bootstrap-override.yml"
DOCKGE_STACK_FILE="01-[1]-dockge-compose.yml"
KOMODO_STACK_FILE="01-[3]-komodo-compose.yml"
DOCKHAND_STACK_FILE="01-[2]-dockhand-compose.yml"

# Optional environment overrides for advanced/testing workflows.
# If these are not set, URLs are rebuilt from the locked GITHUB_RAW_BASE value.
SOCKET_PROXY_STACK_URL_OVERRIDE="${SOCKET_PROXY_STACK_URL:-}"
PORTAINER_STACK_URL_OVERRIDE="${PORTAINER_STACK_URL:-}"
PORTAINER_BOOTSTRAP_OVERRIDE_URL_OVERRIDE="${PORTAINER_BOOTSTRAP_OVERRIDE_URL:-}"
DOCKGE_STACK_URL_OVERRIDE="${DOCKGE_STACK_URL:-}"
DOCKGE_BOOTSTRAP_OVERRIDE_FILE_NAME="01-[1]-dockge-bootstrap-override.yml"
DOCKGE_BOOTSTRAP_OVERRIDE_URL_OVERRIDE="${DOCKGE_BOOTSTRAP_OVERRIDE_URL:-}"
KOMODO_STACK_URL_OVERRIDE="${KOMODO_STACK_URL:-}"
KOMODO_BOOTSTRAP_OVERRIDE_FILE_NAME="01-[3]-komodo-bootstrap-override.yml"
KOMODO_BOOTSTRAP_OVERRIDE_URL_OVERRIDE="${KOMODO_BOOTSTRAP_OVERRIDE_URL:-}"
DOCKHAND_STACK_URL_OVERRIDE="${DOCKHAND_STACK_URL:-}"
DOCKHAND_BOOTSTRAP_OVERRIDE_FILE_NAME="01-[2]-dockhand-bootstrap-override.yml"
DOCKHAND_BOOTSTRAP_OVERRIDE_URL_OVERRIDE="${DOCKHAND_BOOTSTRAP_OVERRIDE_URL:-}"
SOCKET_PROXY_STACK_URL="${SOCKET_PROXY_STACK_URL_OVERRIDE:-${GITHUB_RAW_BASE}/${SOCKET_PROXY_STACK_FILE}}"
PORTAINER_STACK_URL="${PORTAINER_STACK_URL_OVERRIDE:-${GITHUB_RAW_BASE}/${PORTAINER_STACK_FILE}}"
PORTAINER_BOOTSTRAP_OVERRIDE_URL="${PORTAINER_BOOTSTRAP_OVERRIDE_URL_OVERRIDE:-${GITHUB_RAW_BASE}/${PORTAINER_BOOTSTRAP_OVERRIDE_FILE_NAME}}"
DOCKGE_STACK_URL="${DOCKGE_STACK_URL_OVERRIDE:-${GITHUB_RAW_BASE}/${DOCKGE_STACK_FILE}}"
DOCKGE_BOOTSTRAP_OVERRIDE_URL="${DOCKGE_BOOTSTRAP_OVERRIDE_URL_OVERRIDE:-${GITHUB_RAW_BASE}/${DOCKGE_BOOTSTRAP_OVERRIDE_FILE_NAME}}"
KOMODO_STACK_URL="${KOMODO_STACK_URL_OVERRIDE:-${GITHUB_RAW_BASE}/${KOMODO_STACK_FILE}}"
KOMODO_BOOTSTRAP_OVERRIDE_URL="${KOMODO_BOOTSTRAP_OVERRIDE_URL_OVERRIDE:-${GITHUB_RAW_BASE}/${KOMODO_BOOTSTRAP_OVERRIDE_FILE_NAME}}"
DOCKHAND_STACK_URL="${DOCKHAND_STACK_URL_OVERRIDE:-${GITHUB_RAW_BASE}/${DOCKHAND_STACK_FILE}}"
DOCKHAND_BOOTSTRAP_OVERRIDE_URL="${DOCKHAND_BOOTSTRAP_OVERRIDE_URL_OVERRIDE:-${GITHUB_RAW_BASE}/${DOCKHAND_BOOTSTRAP_OVERRIDE_FILE_NAME}}"


# Fixed project stack registry. No GitHub directory scanning is used.
POSTGRES_STACK_FILE="02-postgres-compose.yml"
REDIS_STACK_FILE="03-redis-compose.yml"
TRAEFIK_STACK_FILE="04-traefik-compose.yml"
AUTHENTIK_STACK_FILE="05-authentik-compose.yml"
TEMPORAL_STACK_FILE="06-temporal-compose.yml"
POSTIZ_TEMPORAL_GUARD_STACK_FILE="07-postiz-temporal-guard-compose.yml"
POSTIZ_STACK_FILE="08-postiz-compose.yml"
CF_DDNS_STACK_FILE="09-cf-ddns-compose.yml"
CF_COMPANION_STACK_FILE="10-cf-companion-compose.yml"
VSCODE_STACK_FILE="11-vscode-compose.yml"
FILEBROWSER_STACK_FILE="12-filebrowser-compose.yml"

DEPLOY_POSTIZ="n"
DEPLOY_CF_DDNS="n"
DEPLOY_CF_COMPANION="n"
DEPLOY_VSCODE="n"
DEPLOY_FILEBROWSER="n"

SELECTED_STACK_FILES=()
SELECTED_STACK_PROJECTS=()
SELECTED_STACK_SERVICES=()
DEPENDENCY_REASONS=()

SOCKET_PROXY_SUBNET_EXPECTED="192.168.91.0/24"
T2_PROXY_SUBNET_EXPECTED="192.168.90.0/24"
SOCKET_PROXY_SUBNET_ACTUAL=""
T2_PROXY_SUBNET_ACTUAL=""
DATABASE_NETWORK_NAME=""

PORTAINER_BOOTSTRAP_PORT="${PORTAINER_BOOTSTRAP_PORT:-9443}"
DOCKGE_BOOTSTRAP_PORT="${DOCKGE_BOOTSTRAP_PORT:-5001}"
KOMODO_BOOTSTRAP_PORT="${KOMODO_BOOTSTRAP_PORT:-9120}"
DOCKHAND_BOOTSTRAP_PORT="${DOCKHAND_BOOTSTRAP_PORT:-3000}"
ADMIN_UI_BOOTSTRAP_BIND="${ADMIN_UI_BOOTSTRAP_BIND:-0.0.0.0}"
ADMIN_UI_BOOTSTRAP_PORT=""
ADMIN_UI_INTERNAL_PORT=""
ADMIN_UI_BOOTSTRAP_SCHEME="http"
ADMIN_UI_BOOTSTRAP_OVERRIDE_NAME=""
ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE=""
ADMIN_UI_BOOTSTRAP_ACCESS_IP=""
ADMIN_UI_BOOTSTRAP_ACCESS_URL=""

ADMIN_UI="${ADMIN_UI:-dockge}"
ADMIN_UI_DISPLAY_NAME="Dockge"
ADMIN_UI_SERVICE_NAME="dockge"
ADMIN_UI_COMPOSE_FILE=""
ADMIN_UI_PROJECT_NAME="dockge"
ADMIN_UI_HOST=""
ADMIN_UI_URL=""
AUTHENTIK_ROUTE_HOST=""
AUTHENTIK_EXTERNAL_URL=""
AUTHENTIK_HOST_BROWSER_VALUE=""
VSCODE_HOST=""
FILEBROWSER_HOST=""
ADMIN_UI_DEPLOYED="no"
ADMIN_UI_VALIDATED="no"

DOMAIN_VALUE=""
DOCKER_SECRETS_DIR=""
CF_API_TOKEN_FILE=""
TRAEFIK_STATIC_CONFIG_FILE=""
TRAEFIK_DYNAMIC_CONFIG_FILE=""
TRAEFIK_ACME_STORAGE=""
TRAEFIK_ACME_EMAIL_VALUE=""
TRAEFIK_ACME_EMAIL_STATUS="unknown"
TRAEFIK_DASHBOARD_HOST=""
PROXMOX_ROUTE_ENABLED="n"
PROXMOX_HOST=""
PROXMOX_URL=""
CF_API_EMAIL_VALUE=""

SYSCTL_REDIS_OK="no"
TRAEFIK_PLACEHOLDERS_OK="no"
TRAEFIK_DNS_DELAY_OK="no"
TRAEFIK_ENCODED_CHARS_OK="no"
TRAEFIK_AUTHENTIK_REFERENCES_OK="no"
AUTHENTIK_FOLDERS_OK="no"
AUTHENTIK_DEPENDENCIES_OK="not-run"
AUTHENTIK_API_OK="not-run"
AUTHENTIK_PROVIDER_OK="not-run"
AUTHENTIK_APPLICATION_OK="not-run"
AUTHENTIK_OUTPOST_ATTACH_OK="not-run"
AUTHENTIK_OUTPOST_302_OK="not-run"
PROTECTED_ROUTE_VERIFY_OK="not-run"
AUTHENTIK_HOST_ROUTE_OK="not-run"
AUTHENTIK_API_TOKEN="${AUTHENTIK_API_TOKEN:-}"
AUTHENTIK_API_BASE=""
CF_COMPANION_SECRET_OK="skipped"
FILEBROWSER_FOLDERS_OK="skipped"
SUDO_CMD=""
DOCKER_NEEDS_SUDO="no"
DOCKER_ACCESS_STATUS="not ready"
DOCKERHUB_LOGIN_ATTEMPTED="no"
TEMP_FILES=()

NETWORKS_CREATED="no"
NETWORKS_VERIFIED="no"
SOCKET_PROXY_STACK_DOWNLOADED="no"
PORTAINER_STACK_DOWNLOADED="no"
PORTAINER_BOOTSTRAP_OVERRIDE_DOWNLOADED="no"
DOCKGE_STACK_DOWNLOADED="no"
DOCKGE_BOOTSTRAP_OVERRIDE_DOWNLOADED="no"
KOMODO_STACK_DOWNLOADED="no"
KOMODO_BOOTSTRAP_OVERRIDE_DOWNLOADED="no"
DOCKHAND_STACK_DOWNLOADED="no"
DOCKHAND_BOOTSTRAP_OVERRIDE_DOWNLOADED="no"
SOCKET_PROXY_DEPLOYED="no"
PORTAINER_DEPLOYED="no"
ADMIN_UI_BOOTSTRAP_OVERRIDE_WRITTEN="no"
ADMIN_UI_BOOTSTRAP_PORT_EXPOSED="no"
UFW_BOOTSTRAP_PORT_OPENED="no"
VERIFY_ONLY_MODE="no"
DEPLOYED_STACKS="none"
FAILED_STACKS="none"

SCRIPT6_MARKER="/root/.docker-env-setup-completed"
SCRIPT6_PREFLIGHT_STATUS="unknown"
SCRIPT6_VERIFY_STATUS="unknown"
SCRIPT6_MARKER_DOCKER_DIR=""
SCRIPT6_MARKER_DOMAIN=""
SCRIPT6_MARKER_ADMIN_UI=""
SCRIPT6_ENV_REQUIRED_KEYS_STATUS="unknown"
SCRIPT6_ENV_HOSTNAMES_STATUS="unknown"
SCRIPT6_ENV_URLS_STATUS="unknown"
SCRIPT6_SECRETS_STATUS="unknown"
SCRIPT6_HTPASSWD_STATUS="unknown"
TRAEFIK_CONFIG_PREFLIGHT_STATUS="unknown"
SAFE_WRITE_BACKUP_COUNT="0"
SAFE_WRITE_UNCHANGED_COUNT="0"
SAFE_WRITE_CREATED_COUNT="0"
SAFE_WRITE_UPDATED_COUNT="0"
COMPOSE_PROGRESS_ACTIVE="no"
CURRENT_APPLY_GROUP=""
PUBLIC_ROUTE_WARNINGS="none"
APPLY_GROUPS_SHOWN=""
POSTGRES_PERMISSIONS_STATUS="not-run"
POSTGRES_DEPENDENTS_STATUS="not-run"
REDIS_PERMISSIONS_STATUS="not-run"
COMPOSE_VALIDATION_STATUS="not-run"
DNS_RECORDS_STATUS="not-run"
CF_COMPANION_RUNTIME_STATUS="not selected"
CF_COMPANION_RESCAN_STATUS="not selected"
DNS_WAIT_STATUS="not-run"
AUTHENTIK_INTERNAL_STATUS="not-run"
PUBLIC_ROUTE_SUMMARY_STATUS="not-run"

# =========================================================
#  OUTPUT / LOGGING FUNCTIONS
# =========================================================

# --- 3. HEADER FUNCTION ---
# Displays the Docker Bootstrap banner.
function header_info() {
echo -e "${BL}
██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗     ██████╗  ██████╗  ██████╗ ████████╗███████╗████████╗██████╗  █████╗ ██████╗ 
██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗    ██╔══██╗██╔═══██╗██╔═══██╗╚══██╔══╝██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔══██╗
██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝    ██████╔╝██║   ██║██║   ██║   ██║   ███████╗   ██║   ██████╔╝███████║██████╔╝
██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗    ██╔══██╗██║   ██║██║   ██║   ██║   ╚════██║   ██║   ██╔══██╗██╔══██║██╔═══╝ 
██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║    ██████╔╝╚██████╔╝╚██████╔╝   ██║   ███████║   ██║   ██║  ██║██║  ██║██║     
╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝    ╚═════╝  ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     
${CL}"
}

# --- 4. MESSAGE HELPER FUNCTIONS ---
# Provides consistent display -> apply -> success output style.
function msg_info() { echo -ne " ${HOLD} ${YW}$1...${CL}"; }
function msg_ok() { echo -e "${BFR} ${CM} ${GN}$1${CL}"; }
function msg_warn() { echo -e "${BFR} ${WARN} ${YW}$1${CL}"; }
function msg_skip() { echo -e "${BFR} ${HOLD} ${BL}INFO - $1${CL}"; }
function msg_error() { echo -e "${BFR} ${CROSS} ${RD}$1${CL}"; exit 1; }

# --- SCRIPT VERSION DISPLAY ---
# Prints the currently running script version immediately under the ASCII banner.
function show_script_version() {
    echo -e "${GN}SCRIPT VERSION: ${SCRIPT_VERSION} | UPDATED: ${SCRIPT_UPDATED} | BUILD: ${SCRIPT_BUILD}${CL}"
    echo -e "${BL}SOURCE: ${SCRIPT_SOURCE}${CL}"
}

# --- 5. SECTION HEADER HELPER ---
# Keeps terminal output clean and grouped by stage.
function section() {
    if [ "$1" != "APPLY CHANGES" ]; then
        echo ""
    fi
    echo -e "${BORDER}"
    echo -e "${BL}$1${CL}"
    echo -e "${BORDER}"
}

# --- 6. FLASHING SUCCESS SECTION HEADER HELPER ---
# Uses the same section layout as source-of-truth scripts, but renders final success heading in bold flashing green.
function section_flash_success() {
    echo ""
    echo -e "${BORDER}"
    echo -e "${GN}${CLF}$1${CL}"
    echo -e "${BORDER}"
}

# --- 7. DETAIL LINE HELPER ---
# Prints aligned label/value lines for summaries and audit output.
function detail_line() {
    local label="$1"
    local value="$2"
    local value_color="${3:-$GN}"
    local width="${4:-18}"
    printf "  %b%-${width}s%b %b%s%b\n" "$BL" "${label}:" "$CL" "$value_color" "$value" "$CL"
}

function plan_line() {
    local label="$1"
    local value="$2"
    local value_color="${3:-$GN}"
    local width="${4:-18}"
    printf "  %b%-${width}s%b %b%s%b\n" "$BL" "${label}:" "$CL" "$value_color" "$value" "$CL"
}

function answer_line() {
    local label="$1"
    local value="$2"
    local width="${3:-18}"
    plan_line "$label" "$value" "$ANS" "$width"
}

function setup_option_line() {
    local label="$1"
    local value="$2"
    local value_color="${3:-$GN}"

    detail_line "$label" "$value" "$value_color" "$SETUP_OPTIONS_LABEL_WIDTH"
}

function apply_line() {
    local label="$1"
    local value="$2"
    local value_color="${3:-$GN}"

    detail_line "$label" "$value" "$value_color" "$APPLY_LABEL_WIDTH"
}

function selected_stack_plan_list() {
    local i=""
    local printed="0"

    echo -e "  ${GN}socket-proxy${CL}"
    echo -e "  ${GN}${ADMIN_UI_PROJECT_NAME:-$ADMIN_UI}${CL}"

    for i in "${!SELECTED_STACK_FILES[@]}"; do
        if is_helper_compose_file "${SELECTED_STACK_FILES[$i]}"; then
            continue
        fi
        echo -e "  ${GN}${SELECTED_STACK_PROJECTS[$i]}${CL}"
        printed="1"
    done

    if [ "$printed" == "0" ] && [ "${#SELECTED_STACK_PROJECTS[@]}" -eq 0 ]; then
        return 0
    fi
}

function stack_choice_summary() {
    setup_option_line "Socket proxy" "selected"
    setup_option_line "Admin UI" "$ADMIN_UI_DISPLAY_NAME"
    setup_option_line "Traefik" "$(selected_stack_contains "$TRAEFIK_STACK_FILE" && echo selected || echo not selected)"
    setup_option_line "Authentik" "$(selected_stack_contains "$AUTHENTIK_STACK_FILE" && echo selected || echo not selected)"
    setup_option_line "Postiz" "$(yes_no_label "$DEPLOY_POSTIZ")" "$ANS"
    setup_option_line "Cloudflare DDNS" "$(yes_no_label "$DEPLOY_CF_DDNS")" "$ANS"
    setup_option_line "Cloudflare Companion" "$(yes_no_label "$DEPLOY_CF_COMPANION")" "$ANS"
    setup_option_line "VS Code" "$(yes_no_label "$DEPLOY_VSCODE")" "$ANS"
    setup_option_line "Filebrowser" "$(yes_no_label "$DEPLOY_FILEBROWSER")" "$ANS"
}

function readiness_status_summary() {
    setup_option_line "Script 6 handoff" "${SCRIPT6_PREFLIGHT_STATUS:-unknown}" "$(status_color_for_value "${SCRIPT6_PREFLIGHT_STATUS:-unknown}")"
    setup_option_line "Project config" "${SCRIPT6_ENV_REQUIRED_KEYS_STATUS:-unknown}" "$(status_color_for_value "${SCRIPT6_ENV_REQUIRED_KEYS_STATUS:-unknown}")"
    setup_option_line "Secrets" "${SCRIPT6_SECRETS_STATUS:-unknown}" "$(status_color_for_value "${SCRIPT6_SECRETS_STATUS:-unknown}")"
    setup_option_line "Traefik config" "${TRAEFIK_CONFIG_PREFLIGHT_STATUS:-not selected}" "$(status_color_for_value "${TRAEFIK_CONFIG_PREFLIGHT_STATUS:-not selected}")"
    setup_option_line "ACME email" "${TRAEFIK_ACME_EMAIL_STATUS:-unknown}" "$(status_color_for_value "${TRAEFIK_ACME_EMAIL_STATUS:-unknown}")"
    setup_option_line "Redis/sysctl" "${SYSCTL_REDIS_OK:-not selected}" "$(status_color_for_value "${SYSCTL_REDIS_OK:-not selected}")"
    setup_option_line "Authentik folders" "${AUTHENTIK_FOLDERS_OK:-not selected}" "$(status_color_for_value "${AUTHENTIK_FOLDERS_OK:-not selected}")"
    setup_option_line "SMTP env" "${AUTHENTIK_SMTP_ENV_OK:-not selected}" "$(status_color_for_value "${AUTHENTIK_SMTP_ENV_OK:-not selected}")"
    setup_option_line "Cloudflare token" "$CF_COMPANION_SECRET_OK" "$(status_color_for_value "$CF_COMPANION_SECRET_OK")"
}

function all_required_readiness_status() {
    if [ "${SCRIPT6_ENV_REQUIRED_KEYS_STATUS:-unknown}" == "ready" ] \
        && [ "${SCRIPT6_ENV_HOSTNAMES_STATUS:-unknown}" == "ready" ] \
        && [ "${SCRIPT6_ENV_URLS_STATUS:-unknown}" == "ready" ] \
        && [ "${SCRIPT6_SECRETS_STATUS:-unknown}" == "ready" ] \
        && [ "${TRAEFIK_CONFIG_PREFLIGHT_STATUS:-unknown}" == "ready" ]; then
        printf 'ready'
    else
        printf 'review'
    fi
}

function group_heading() {
    echo -e "${YW}$1:${CL}"
}

function apply_group_heading() {
    local heading="$1"

    case " ${APPLY_GROUPS_SHOWN} " in
        *"|${heading}|"*)
            return 0
            ;;
    esac

    APPLY_GROUPS_SHOWN="${APPLY_GROUPS_SHOWN}|${heading}|"
    CURRENT_APPLY_GROUP="$heading"
    echo ""
    group_heading "$heading"
}

# Runtime labels rendered by detail_line for compact compose summaries.
function compose_progress_summary() {
    local status="$1"

    if [ "$status" == "ready" ]; then
        tty_print "${BFR}"
        apply_line "Status" "ready"
        apply_line "Stacks" "$(selected_stack_count)"
        apply_line "Helpers" "$(helper_file_count)"
        apply_line "Compose files" "$(compose_file_total_count)"
        apply_line "Backups" "$SAFE_WRITE_BACKUP_COUNT"
        return 0
    fi

    # Suppress live per-file progress in terminal. Detailed operations remain in logs.
    return 0
}

function stack_list_lines() {
    local csv="$1"
    local item=""

    if [ -z "$csv" ] || [ "$csv" == "none" ]; then
        echo -e "  ${GN}none${CL}"
        return 0
    fi

    IFS=',' read -r -a _stack_items <<< "$csv"
    for item in "${_stack_items[@]}"; do
        [ -n "$item" ] && echo -e "  ${GN}${item}${CL}"
    done
}

function display_selected_stack_lines() {
    local names=""
    names="$(selected_stack_names)"
    stack_list_lines "$names"
}

function stack_status_line() {
    local label="$1"
    local value="$2"
    local color=""
    color="$(status_color_for_value "$value")"
    apply_line "$label" "$value" "$color"
}

function apply_compose_summary() {
    apply_group_heading "Compose files"
    compose_progress_summary "ready"
}

# --- 8. TTY PRINT HELPER ---
# Prints directly to terminal even when functions return values through stdout.
function tty_print() {
    if [ -w /dev/tty ]; then
        echo -ne "$*" > /dev/tty
    else
        echo -ne "$*" >&2
    fi
}

# --- 9. TTY PRINTLN HELPER ---
# Prints directly to terminal with newline.
function tty_println() {
    if [ -w /dev/tty ]; then
        echo -e "$*" > /dev/tty
    else
        echo -e "$*" >&2
    fi
}

# --- 10. INPUT BUFFER FLUSH HELPER ---
# Clears only a small bounded amount of already-buffered terminal input.
# Important: never reads from stdin because streamed scripts use stdin for the script body.
function flush_input_buffer() {
    local junk=""
    local i=""

    if [ ! -r /dev/tty ]; then
        return 0
    fi

    for i in {1..20}; do
        if ! IFS= read -rsn1 -t 0.02 junk < /dev/tty; then
            break
        fi
    done

    return 0
}

# =========================================================
#  CLEANUP / ERROR HANDLING
# =========================================================

# --- 11. CLEANUP FUNCTION ---
# Removes temporary files and copies runtime log to /var/log when running non-root.
function cleanup() {
    local exit_code="$?"
    local file=""

    if [ -n "${SUDO_CMD:-}" ] && [ -n "${RUNTIME_LOG_FILE:-}" ] && [ -s "$RUNTIME_LOG_FILE" ]; then
        "$SUDO_CMD" cp "$RUNTIME_LOG_FILE" "$LOG_FILE" 2>/dev/null || true
        "$SUDO_CMD" chmod 0644 "$LOG_FILE" 2>/dev/null || true
    fi

    for file in "${TEMP_FILES[@]:-}"; do
        [ -n "$file" ] && [ -f "$file" ] && rm -f "$file" 2>/dev/null || true
    done

    exit "$exit_code"
}

# --- 12. ERROR TRAP HELPER ---
# Shows the failing line number and points to the log file.
function on_error() {
    local line_no="$1"
    echo -e "${RD}ERROR:${CL} Script failed at line ${line_no}. Check ${LOG_FILE}"
}

# --- 13. COMMAND RUNNER ---
# Runs privileged commands quietly, but shows real stderr if they fail.
function run_cmd() {
    local description="$1"
    shift

    local err_file=""
    err_file="$(mktemp)"
    TEMP_FILES+=("$err_file")

    if [ -n "$SUDO_CMD" ]; then
        if ! "$SUDO_CMD" "$@" > /dev/null 2> "$err_file"; then
            echo ""
            echo -e "${RD}Command failed during:${CL} ${description}"
            echo -e "${YW}Command:${CL} sudo $*"
            echo ""
            echo -e "${RD}Real error:${CL}"
            cat "$err_file"
            rm -f "$err_file"
            exit 1
        fi
    else
        if ! "$@" > /dev/null 2> "$err_file"; then
            echo ""
            echo -e "${RD}Command failed during:${CL} ${description}"
            echo -e "${YW}Command:${CL} $*"
            echo ""
            echo -e "${RD}Real error:${CL}"
            cat "$err_file"
            rm -f "$err_file"
            exit 1
        fi
    fi

    rm -f "$err_file"
}

# --- 14. ROOT PATH EXISTS HELPER ---
# Checks whether a root-owned path exists.
function root_path_exists() {
    local path="$1"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" test -e "$path"
    else
        test -e "$path"
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

function root_file_not_empty() {
    local path="$1"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" test -s "$path"
    else
        test -s "$path"
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

# =========================================================
#  PROMPT FUNCTIONS
# =========================================================

# --- 15. YES/NO LABEL HELPER ---
# Converts Y/N answers to readable yes/no output.
function yes_no_label() {
    local value="$1"

    if [[ "$value" =~ ^[Yy]$ ]]; then
        echo "yes"
    else
        echo "no"
    fi
}

# --- 16. BLOCKING YES/NO HELPER ---
# SPACE pauses countdown and waits for Y/N/ENTER.
function tty_read_yes_no_blocking() {
    local prompt="$1"
    local default="$2"
    local default_label="Y/n"
    local key=""

    if [[ "$default" =~ ^[Nn]$ ]]; then
        default_label="y/N"
    fi

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

# --- 17. TIMED YES/NO PROMPT HELPER ---
# Uses wall-clock countdown. SPACE pauses, timeout accepts default, final answer stays visible.
function timed_yes_no() {
    local prompt="$1"
    local default="$2"
    local answer=""
    local key=""
    local default_label="Y/n"
    local final_label=""
    local deadline=""
    local now=""
    local remaining=""

    if [[ "$default" =~ ^[Nn]$ ]]; then
        default_label="y/N"
    fi

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
                if [[ "$key" == " " ]]; then
                    answer="$(tty_read_yes_no_blocking "$prompt" "$default")"
                    break
                elif [[ "$key" =~ ^[YyNn]$ ]]; then
                    answer="$key"
                    break
                elif [[ -z "$key" ]]; then
                    answer="$default"
                    break
                fi
            fi
        else
            if IFS= read -rsn1 -t 1 key; then
                if [[ "$key" == " " ]]; then
                    answer="$(tty_read_yes_no_blocking "$prompt" "$default")"
                    break
                elif [[ "$key" =~ ^[YyNn]$ ]]; then
                    answer="$key"
                    break
                elif [[ -z "$key" ]]; then
                    answer="$default"
                    break
                fi
            fi
        fi
    done

    [ -z "$answer" ] && answer="$default"
    final_label="$(yes_no_label "$answer")"

    tty_print "${BFR}"
    tty_println "${CM} ${GN}${prompt} ${final_label}${CL}"
    flush_input_buffer

    echo "$answer"
}

# --- 17A. TIMED YES/NO VALUE-ONLY HELPER ---
# Same countdown behavior as timed_yes_no, but clears the prompt and returns only the answer.
# Used when the caller prints a cleaner custom confirmation line.
function timed_yes_no_value_only() {
    local prompt="$1"
    local default="$2"
    local answer=""
    local key=""
    local default_label="Y/n"
    local deadline=""
    local now=""
    local remaining=""

    if [[ "$default" =~ ^[Nn]$ ]]; then
        default_label="y/N"
    fi

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
                if [[ "$key" == " " ]]; then
                    answer="$(tty_read_yes_no_blocking "$prompt" "$default")"
                    break
                elif [[ "$key" =~ ^[YyNn]$ ]]; then
                    answer="$key"
                    break
                elif [[ -z "$key" ]]; then
                    answer="$default"
                    break
                fi
            fi
        else
            if IFS= read -rsn1 -t 1 key; then
                if [[ "$key" == " " ]]; then
                    answer="$(tty_read_yes_no_blocking "$prompt" "$default")"
                    break
                elif [[ "$key" =~ ^[YyNn]$ ]]; then
                    answer="$key"
                    break
                elif [[ -z "$key" ]]; then
                    answer="$default"
                    break
                fi
            fi
        fi
    done

    [ -z "$answer" ] && answer="$default"
    tty_print "${BFR}"
    flush_input_buffer
    echo "$answer"
}

function timed_yes_no_keep_visible() {
    local prompt="$1"
    local default="$2"
    local answer=""
    local final_label=""

    answer="$(timed_yes_no_value_only "$prompt" "$default")"
    final_label="$(yes_no_label "$answer")"
    tty_println "${CM} ${GN}${prompt} ${ANS}${final_label}${CL}"
    echo "$answer"
}

# --- 18. EDITABLE INPUT LOOP HELPER ---
# Shared editable input system for text prompts.
function editable_input_loop() {
    local prompt="$1"
    local default="$2"
    local initial_value="${3:-}"
    local answer="$initial_value"
    local key=""

    flush_input_buffer

    while true; do
        tty_print "${BFR}${YW}${prompt} [default: ${default}]: ${CL}${answer}"

        if [ -r /dev/tty ]; then
            IFS= read -rsn1 key < /dev/tty || true
        else
            IFS= read -rsn1 key || true
        fi

        case "$key" in
            "")
                [ -z "$answer" ] && answer="$default"
                tty_print "${BFR}"
                echo "$answer"
                flush_input_buffer
                return 0
                ;;
            $'\177'|$'\b')
                answer="${answer%?}"
                ;;
            *)
                answer+="$key"
                ;;
        esac
    done
}

# --- 19. TIMED TEXT INPUT HELPER ---
# Shows wall-clock countdown. SPACE pauses with empty editable buffer.
function timed_text_input() {
    local prompt="$1"
    local default="$2"
    local answer=""

    # Text/path/name/domain/URL prompts are deliberately NOT timed.
    # Countdown prompts are reserved only for simple Y/n decisions.
    answer="$(editable_input_loop "$prompt" "$default" "")"
    [ -z "$answer" ] && answer="$default"

    tty_print "${BFR}"
    tty_println "${CM} ${GN}${prompt} ${answer}${CL}"
    flush_input_buffer 2>/dev/null || true

    echo "$answer"
}

# --- 19A. SENSITIVE LINE INPUT HELPER ---
# Reads secret/token input without echoing it and without printing the value back to logs.
function sensitive_line_input() {
    local prompt="$1"
    local answer=""

    flush_input_buffer 2>/dev/null || true

    if [ -r /dev/tty ]; then
        tty_print "${YW}${prompt}: ${CL}"
        IFS= read -rs answer < /dev/tty || true
        tty_println ""
    else
        echo -ne "${YW}${prompt}: ${CL}" >&2
        IFS= read -rs answer || true
        echo "" >&2
    fi

    flush_input_buffer 2>/dev/null || true
    printf '%s' "$answer"
}

# =========================================================
#  VALIDATION HELPERS
# =========================================================

# --- 20. USERNAME VALIDATION HELPER ---
# Validates Linux username format.
function validate_linux_username() {
    local username="$1"

    if [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        return 0
    fi

    return 1
}

# --- 21. URL VALIDATION HELPER ---
# Validates HTTP(S) URLs used for GitHub raw downloads.
function validate_url() {
    local url="$1"

    if [[ "$url" =~ ^https?://[^[:space:]]+$ ]]; then
        return 0
    fi

    return 1
}

function is_email_like() {
    local email="${1:-}"

    [ -n "$email" ] || return 1
    [[ "$email" != *[[:space:]]* ]] || return 1
    [[ "$email" != '""' ]] || return 1
    [[ "$email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] || return 1

    return 0
}

# --- 22. DEPENDENCY VALIDATION ---
# Validates base commands before system changes.
function validate_dependencies() {
    local required_commands=(
        awk
        cat
        chmod
        cp
        curl
        date
        docker
        grep
        head
        hostname
        id
        ip
        mkdir
        mktemp
        rm
        sed
        tee
        tput
        xargs
    )

    local cmd=""

    for cmd in "${required_commands[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || msg_error "Required command not found: ${cmd}"
    done

    if [ -n "$SUDO_CMD" ]; then
        command -v sudo >/dev/null 2>&1 || msg_error "sudo is required when not running as root."
    fi

    if ! docker compose version >/dev/null 2>&1 && ! { [ -n "$SUDO_CMD" ] && "$SUDO_CMD" docker compose version >/dev/null 2>&1; }; then
        msg_error "Docker Compose plugin not available. Run script 5 first."
    fi
}

# =========================================================
#  INITIALIZATION
# =========================================================

# --- 23. ROOT / SUDO DETECTION ---
# Uses sudo when not root.
function detect_root_or_sudo() {
    if [ "$EUID" -eq 0 ]; then
        SUDO_CMD=""
    else
        SUDO_CMD="sudo"
    fi
}

# --- 24. SUDO VALIDATION ---
# Validates sudo once near the start. Supports passwordless sudo from earlier scripts.
function validate_sudo_access() {
    if [ -n "$SUDO_CMD" ]; then
        msg_info "Validating sudo access"

        if "$SUDO_CMD" -n true >/dev/null 2>&1; then
            msg_ok "PASSWORDLESS SUDO CONFIRMED"
            return 0
        fi

        if "$SUDO_CMD" -v; then
            msg_ok "SUDO ACCESS CONFIRMED"
            return 0
        fi

        msg_error "Sudo authentication failed. Script cancelled."
    fi
}

# --- 25. LOGGING INITIALIZATION ---
# Avoids piping interactive prompts through sudo tee. Runtime log is copied to /var/log during cleanup.
function init_logging() {
    if [ -n "$SUDO_CMD" ]; then
        RUNTIME_LOG_FILE="$(mktemp /tmp/docker-bootstrap-setup-log.XXXXXX)"
        TEMP_FILES+=("$RUNTIME_LOG_FILE")
        exec > >(tee -a "$RUNTIME_LOG_FILE") 2>&1
    else
        RUNTIME_LOG_FILE="$LOG_FILE"
        exec > >(tee -a "$LOG_FILE") 2>&1
    fi
}

# --- 26. SCRIPT INITIALIZATION ---
# Detects sudo, validates access, starts logging, installs traps, shows banner and validates dependencies.
function init_script() {
    detect_root_or_sudo
    validate_sudo_access
    init_logging

    trap 'on_error "$LINENO"' ERR
    trap cleanup EXIT

    clear
    header_info
    show_script_version

    validate_dependencies
}

# --- 27. DOCKER ACCESS DETECTION ---
# Prefers normal docker group access, falls back to sudo docker if needed.
function status_color_for_value() {
    local value="$1"

    case "$value" in
        ready|present|completed|PASS|yes|deployed|downloaded|selected|enabled|running|configured|confirmed|valid|written|all\ selected\ stacks|complete)
            printf '%s' "$GN"
            ;;
        PASS_WITH_WARNINGS|warning|warnings|skipped|not-active|not-found|not\ selected|not\ needed|needs\ review|empty\ placeholder|review|needs-review|needs\ UI\ confirmation|auth-host-tls-failed|acme-rate-limited)
            printf '%s' "$YW"
            ;;
        missing|fail|FAIL|no|not\ ready|not-ready|empty|unknown)
            printf '%s' "$RD"
            ;;
        *)
            printf '%s' "$GN"
            ;;
    esac
}

function env_status_line() {
    local label="$1"
    local value="$2"
    local color=""

    color="$(status_color_for_value "$value")"
    detail_line "$label" "$value" "$color"
}

function detected_runtime_user() {
    if [ -n "${SUDO_USER:-}" ]; then
        printf '%s' "$SUDO_USER"
    elif [ -n "${USER:-}" ]; then
        printf '%s' "$USER"
    else
        id -un 2>/dev/null || printf 'unknown'
    fi
}

function refresh_compose_source_urls() {
    if [ -z "$SOCKET_PROXY_STACK_URL_OVERRIDE" ]; then
        SOCKET_PROXY_STACK_URL="${GITHUB_RAW_BASE}/${SOCKET_PROXY_STACK_FILE}"
    fi

    if [ -z "$PORTAINER_STACK_URL_OVERRIDE" ]; then
        PORTAINER_STACK_URL="${GITHUB_RAW_BASE}/${PORTAINER_STACK_FILE}"
    fi

    if [ -z "$PORTAINER_BOOTSTRAP_OVERRIDE_URL_OVERRIDE" ]; then
        PORTAINER_BOOTSTRAP_OVERRIDE_URL="${GITHUB_RAW_BASE}/${PORTAINER_BOOTSTRAP_OVERRIDE_FILE_NAME}"
    fi

    if [ -z "$DOCKGE_STACK_URL_OVERRIDE" ]; then
        DOCKGE_STACK_URL="${GITHUB_RAW_BASE}/${DOCKGE_STACK_FILE}"
    fi

    if [ -z "$DOCKGE_BOOTSTRAP_OVERRIDE_URL_OVERRIDE" ]; then
        DOCKGE_BOOTSTRAP_OVERRIDE_URL="${GITHUB_RAW_BASE}/${DOCKGE_BOOTSTRAP_OVERRIDE_FILE_NAME}"
    fi

    if [ -z "$KOMODO_STACK_URL_OVERRIDE" ]; then
        KOMODO_STACK_URL="${GITHUB_RAW_BASE}/${KOMODO_STACK_FILE}"
    fi

    if [ -z "$KOMODO_BOOTSTRAP_OVERRIDE_URL_OVERRIDE" ]; then
        KOMODO_BOOTSTRAP_OVERRIDE_URL="${GITHUB_RAW_BASE}/${KOMODO_BOOTSTRAP_OVERRIDE_FILE_NAME}"
    fi

    if [ -z "$DOCKHAND_STACK_URL_OVERRIDE" ]; then
        DOCKHAND_STACK_URL="${GITHUB_RAW_BASE}/${DOCKHAND_STACK_FILE}"
    fi

    if [ -z "$DOCKHAND_BOOTSTRAP_OVERRIDE_URL_OVERRIDE" ]; then
        DOCKHAND_BOOTSTRAP_OVERRIDE_URL="${GITHUB_RAW_BASE}/${DOCKHAND_BOOTSTRAP_OVERRIDE_FILE_NAME}"
    fi
}

function detect_docker_access() {
    local runtime_user=""

    msg_info "Checking Docker access"
    runtime_user="$(detected_runtime_user)"

    if docker ps >/dev/null 2>&1; then
        DOCKER_NEEDS_SUDO="no"
        DOCKER_ACCESS_STATUS="${runtime_user} ready"
        msg_ok "DOCKER ACCESS CONFIRMED"
        return 0
    fi

    if [ -n "$SUDO_CMD" ] && "$SUDO_CMD" docker ps >/dev/null 2>&1; then
        DOCKER_NEEDS_SUDO="yes"
        DOCKER_ACCESS_STATUS="sudo ready"
        msg_ok "DOCKER ACCESS CONFIRMED WITH SUDO"
        msg_warn "Current shell cannot use Docker without sudo. Reboot/logout may still be needed after script 5."
        return 0
    fi

    DOCKER_ACCESS_STATUS="not ready"
    msg_error "Docker daemon is not reachable. Run script 5 first and reboot/log back in."
}

# =========================================================
#  DOCKER WRAPPERS
# =========================================================

# --- 28. DOCKER COMMAND WRAPPER ---
# Runs docker through current user or sudo fallback depending on detected access.
function docker_cmd() {
    if [ "$DOCKER_NEEDS_SUDO" == "yes" ]; then
        "$SUDO_CMD" docker "$@"
    else
        docker "$@"
    fi
}

# --- 28A. TRANSIENT LINE CLEAR HELPER ---
# Clears short live/progress messages after the operation completes.
function clear_transient_line() {
    tty_print "${BFR}"
}

function clear_terminal_lines() {
    local count="${1:-0}"
    local i=""

    if [ "$count" -le 0 ]; then
        return 0
    fi

    if [ -w /dev/tty ]; then
        for i in $(seq 1 "$count"); do
            printf '\033[1A\r\033[K' > /dev/tty
        done
    fi
}

# --- 28B. DOCKER CREDENTIAL STORE PATH HELPER ---
# Reports the Docker config path used by docker login without exposing credentials.
function docker_config_path_hint() {
    if [ "$DOCKER_NEEDS_SUDO" == "yes" ]; then
        echo "/root/.docker/config.json"
    else
        echo "${HOME:-/home/${DOCKER_USER}}/.docker/config.json"
    fi
}

# --- 29. DOCKER HUB RATE-LIMIT DETECTION ---
# Detects Docker Hub anonymous pull throttling and offers a secure docker login retry only when needed.
function is_dockerhub_rate_limit_error() {
    local err_file="$1"

    grep -Eiq \
        'toomanyrequests|unauthenticated pull rate limit|You have reached your unauthenticated pull rate limit|increase-rate-limit|docker\.com/increase-rate-limit' \
        "$err_file"
}


# --- 29A.1. DOCKER IMAGE EXTRACTION ERROR DETECTION ---
# Detects local Docker/containerd snapshot extraction corruption separately from compose/YAML errors.
function is_docker_layer_extract_error() {
    local err_file="$1"

    grep -Eiq         'failed to extract layer|failed to extract|containerd\.io\.containerd\.snapshotter|overlayfs|no such file or directory.*snapshot|no such file or directory.*layer'         "$err_file"
}

# --- 29A.2. DOCKER IMAGE EXTRACTION ERROR EXPLANATION ---
# Shows a targeted explanation when Docker/containerd fails while extracting pulled image layers.
function explain_docker_layer_extract_error() {
    local description="$1"
    local err_file="$2"

    echo ""
    echo -e "${RD}Docker image extraction failed during:${CL} ${description}"
    echo -e "${YW}This is usually a local Docker/containerd snapshot or partially-extracted image problem, not a compose path/YAML problem.${CL}"
    echo -e "${YW}Common fix: remove the failed image/container, restart Docker, then rerun Script 6.5.${CL}"
    echo ""
    echo -e "${BL}Suggested safe checks/fixes:${CL}"
    echo -e "${YW}docker compose -p postiz down${CL}"
    echo -e "${YW}docker image rm ghcr.io/gitroomhq/postiz-app:latest 2>/dev/null || true${CL}"
    echo -e "${YW}sudo systemctl restart docker${CL}"
    echo -e "${YW}Then rerun Script 6.5.${CL}"
    echo ""
    echo -e "${RD}Real error:${CL}"
    cat "$err_file"
}

# --- 29A. DOCKER HUB LOGIN / RETRY HELPER ---
# Uses Docker's own login prompt instead of collecting credentials in this script.
# This keeps passwords/tokens out of script variables and logs.
function offer_dockerhub_login_and_retry() {
    local description="$1"
    local err_file="$2"
    shift 2

    local login_yn=""
    local docker_username=""
    local config_hint=""

    echo ""
    msg_warn "DOCKER HUB RATE LIMIT DETECTED"
    echo -e "${YW}Docker Hub is throttling anonymous pulls from this IP. This is not a compose/YAML error.${CL}"
    echo -e "${YW}Login is only requested because the rate-limit error was detected.${CL}"
    echo -e "${BL}Tip:${CL} use your Docker Hub username and a Personal Access Token when Docker asks for a password."
    echo ""

    if [ "$DOCKERHUB_LOGIN_ATTEMPTED" == "yes" ]; then
        echo -e "${YW}Docker Hub login was already attempted once in this run.${CL}"
        return 1
    fi

    login_yn="$(timed_yes_no "Log in to Docker Hub now and retry this pull/deploy?" "y")"
    if [[ "$login_yn" =~ ^[Nn] ]]; then
        echo -e "${YW}Docker Hub login skipped. Run 'docker login' manually, then rerun Script 6.5.${CL}"
        return 1
    fi

    DOCKERHUB_LOGIN_ATTEMPTED="yes"

    echo ""
    echo -e "${YW}Starting Docker Hub login...${CL}"
    if ! docker_cmd login; then
        echo -e "${RD}Docker Hub login failed.${CL}"
        return 1
    fi

    docker_username="$(docker_cmd info --format '{{.Username}}' 2>/dev/null || true)"
    config_hint="$(docker_config_path_hint)"
    msg_ok "DOCKER HUB LOGIN SUCCEEDED"
    [ -n "$docker_username" ] && detail_line "Docker Hub user" "$docker_username"
    detail_line "Docker credentials file" "$config_hint"
    echo -e "${YW}Docker may store credentials unencrypted unless a credential helper is configured.${CL}"
    echo ""

    msg_info "Retrying failed Docker operation"
    : > "$err_file"
    if docker_cmd "$@" > /dev/null 2> "$err_file"; then
        msg_ok "RETRY SUCCEEDED: ${description^^}"
        return 0
    fi

    echo ""
    echo -e "${RD}Retry failed after Docker Hub login during:${CL} ${description}"
    echo -e "${YW}Command:${CL} docker $*"
    echo ""
    echo -e "${RD}Real error:${CL}"
    cat "$err_file"
    return 1
}

# --- 29B. DOCKER COMMAND RUNNER ---
# Runs docker commands quietly, with Docker Hub rate-limit detection and one secure login retry.
function run_docker_cmd() {
    local description="$1"
    shift

    local err_file=""
    err_file="$(mktemp)"
    TEMP_FILES+=("$err_file")

    if ! docker_cmd "$@" > /dev/null 2> "$err_file"; then
        if is_dockerhub_rate_limit_error "$err_file"; then
            if offer_dockerhub_login_and_retry "$description" "$err_file" "$@"; then
                rm -f "$err_file"
                return 0
            fi
        fi

        if is_docker_layer_extract_error "$err_file"; then
            explain_docker_layer_extract_error "$description" "$err_file"
            rm -f "$err_file"
            exit 1
        fi

        echo ""
        echo -e "${RD}Docker command failed during:${CL} ${description}"
        echo -e "${YW}Command:${CL} docker $*"
        echo ""
        echo -e "${RD}Real error:${CL}"
        cat "$err_file"
        rm -f "$err_file"
        exit 1
    fi

    rm -f "$err_file"
}


# --- 29B. CLEAN COMPOSE UP HELPER ---
# Runs docker compose up without terminal-flooding image pull/extract progress.
function compose_up_quiet() {
    local description="$1"
    shift

    msg_info "${description} (pulling/starting containers; this can take a few minutes)"

    if docker_cmd compose up --help 2>/dev/null | grep -q -- '--quiet-pull'; then
        run_docker_cmd "$description" compose "$@" up -d --quiet-pull
    else
        run_docker_cmd "$description" compose "$@" up -d
    fi

    clear_transient_line
}

# --- 29A. POSTIZ TEMPORAL GUARD RUNNER ---
# Runs the one-shot Temporal guard without hiding the container output. The guard
# is intentionally verbose because a failure here decides whether Postiz can start.
function run_postiz_temporal_guard_stack() {
    local project="$1"
    local file="$2"
    local guard_log=""
    local compose_path=""

    guard_log="$(mktemp)"
    TEMP_FILES+=("$guard_log")
    compose_path="$(compose_path_for_stack_file "$file")"

    msg_info "Running Postiz Temporal Guard from ${compose_path}"

    if docker_cmd compose --env-file "$ENV_FILE" -p "$project" -f "$compose_path" up --abort-on-container-exit --exit-code-from postiz-temporal-guard > "$guard_log" 2>&1; then
        clear_transient_line
        apply_line "temporal guard" "ready"
        return 0
    fi

    if is_dockerhub_rate_limit_error "$guard_log"; then
        if offer_dockerhub_login_and_retry "running Postiz Temporal Guard" "$guard_log" compose --env-file "$ENV_FILE" -p "$project" -f "$compose_path" up --abort-on-container-exit --exit-code-from postiz-temporal-guard; then
            clear_transient_line
            apply_line "temporal guard" "ready"
            return 0
        fi
    fi

    if is_docker_layer_extract_error "$guard_log"; then
        clear_transient_line
        explain_docker_layer_extract_error "running Postiz Temporal Guard" "$guard_log"
        exit 1
    fi

    clear_transient_line
    echo ""
    echo -e "${RD}Docker command failed during:${CL} running Postiz Temporal Guard"
    echo -e "${YW}Command:${CL} docker compose --env-file ${ENV_FILE} -p ${project} -f ${compose_path} up --abort-on-container-exit --exit-code-from postiz-temporal-guard"
    echo ""
    echo -e "${YW}Captured Postiz Temporal Guard output:${CL}"
    cat "$guard_log" 2>/dev/null || true
    echo ""
    echo -e "${YW}Postiz Temporal Guard container logs:${CL}"
    docker_cmd logs postiz-temporal-guard 2>/dev/null || true
    exit 1
}




# --- 29AA. ROOT FILE WRITE HELPER ---
# Writes stdin to a target path using sudo when needed.
function write_root_file() {
    local path="$1"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" tee "$path" >/dev/null
    else
        cat > "$path"
    fi
}

# --- 29AB. TRAEFIK TEMPLATE DOWNLOAD HELPER ---
# Downloads public Traefik templates when Script 6 output is missing.
function download_file() {
    local url="$1"
    local dest="$2"

    curl --globoff -fsSL "$url" -o "$dest"
}

# --- 29AC. TRAEFIK PROXMOX ROUTE BLOCK HELPER ---
# Rebuilds the same dynamic file-provider Proxmox block generated by Script 6.
function build_proxmox_route_block() {
    cat <<EOF
  # -------------------------------------------------------
  # FILE-PROVIDER ROUTERS
  # -------------------------------------------------------
  routers:
    traefik-dashboard:
      entryPoints:
        - https
      rule: Host(\`${TRAEFIK_DASHBOARD_HOST}\`)
      middlewares:
        - chain-authentik@file
      tls: {}
      service: api@internal
EOF

    if [ "$PROXMOX_ROUTE_ENABLED" != "y" ]; then
        cat <<'EOF'

  # Proxmox routing was disabled during setup.
EOF
        return 0
    fi

    cat <<EOF

    proxmox:
      entryPoints:
        - https
      rule: Host(\`${PROXMOX_HOST}\`)
      middlewares:
        - chain-authentik@file
      tls: {}
      service: proxmox

  # -------------------------------------------------------
  # FILE-PROVIDER SERVICES
  # -------------------------------------------------------
  services:
    proxmox:
      loadBalancer:
        serversTransport: proxmoxTransport
        passHostHeader: true
        servers:
          - url: "${PROXMOX_URL}"

  # -------------------------------------------------------
  # TARGETED SERVER TRANSPORTS
  # -------------------------------------------------------
  serversTransports:
    proxmoxTransport:
      insecureSkipVerify: true
EOF
}

# --- 29AD. TRAEFIK TEMPLATE RENDER HELPER ---
# Renders public-safe placeholders without embedding raw Cloudflare tokens.
function render_traefik_template() {
    local src="$1"
    local dest="$2"
    local content=""
    local proxmox_block=""

    content="$(cat "$src")"
    proxmox_block="$(build_proxmox_route_block)"

    content="${content//\{\{DOCKER_DIR\}\}/$DOCKER_DIR}"
    content="${content//\{\{DOMAIN\}\}/$DOMAIN_VALUE}"
    content="${content//\{\{CF_API_EMAIL\}\}/$CF_API_EMAIL_VALUE}"
    content="${content//\{\{TRAEFIK_DASHBOARD_HOST\}\}/$TRAEFIK_DASHBOARD_HOST}"
    : "${TRAEFIK_ACME_EMAIL_VALUE:?TRAEFIK_ACME_EMAIL_VALUE is required before rendering Traefik config}"
    is_email_like "$TRAEFIK_ACME_EMAIL_VALUE" || msg_error "TRAEFIK_ACME_EMAIL must be a valid email-like value before rendering Traefik config."

    content="${content//\{\{TRAEFIK_ACME_EMAIL\}\}/$TRAEFIK_ACME_EMAIL_VALUE}"
    content="${content//\{\{CF_API_TOKEN_SECRET_PATH\}\}//run/secrets/cf_api_token}"
    content="${content//\{\{HTPASSWD_SECRET_PATH\}\}//run/secrets/htpasswd}"
    content="${content//\{\{PROXMOX_ROUTE_BLOCK\}\}/$proxmox_block}"

    if grep -q '{{CF_API_TOKEN\|{{CLOUDFLARE_API_TOKEN' <<< "$content"; then
        msg_error "Traefik template contains a raw token placeholder. Use file-based token placeholders only."
    fi

    printf '%s\n' "$content" | write_root_file "$dest"
}

# --- 29AE. TRAEFIK CONFIG SELF-HEAL HELPER ---
# If Script 6 completed but Traefik config files are missing, rebuild them from the public templates.
function rebuild_missing_traefik_configs() {
    local tmp_dir=""
    local static_template=""
    local dynamic_template=""

    section "TRAEFIK TEMPLATE SELF-HEAL"

    msg_warn "Traefik rendered config files are missing. Attempting to rebuild them from templates."

    tmp_dir="$(mktemp -d /tmp/traefik-template-repair.XXXXXX)"
    TEMP_FILES+=("${tmp_dir}/traefik.yml.template" "${tmp_dir}/dynamic-config.yml.template")
    static_template="${tmp_dir}/traefik.yml.template"
    dynamic_template="${tmp_dir}/dynamic-config.yml.template"

    run_cmd "creating Traefik config directory" mkdir -p "$(dirname "$TRAEFIK_STATIC_CONFIG_FILE")"
    run_cmd "creating Traefik ACME directory" mkdir -p "$(dirname "$TRAEFIK_ACME_STORAGE")"
    run_cmd "creating Traefik ACME storage" touch "$TRAEFIK_ACME_STORAGE"

    msg_info "Downloading Traefik static template"
    download_file "$TRAEFIK_STATIC_TEMPLATE_URL" "$static_template" || msg_error "Failed to download Traefik static template: ${TRAEFIK_STATIC_TEMPLATE_URL}"
    msg_ok "TRAEFIK STATIC TEMPLATE DOWNLOADED"

    msg_info "Downloading Traefik dynamic template"
    download_file "$TRAEFIK_DYNAMIC_TEMPLATE_URL" "$dynamic_template" || msg_error "Failed to download Traefik dynamic template: ${TRAEFIK_DYNAMIC_TEMPLATE_URL}"
    msg_ok "TRAEFIK DYNAMIC TEMPLATE DOWNLOADED"

    msg_info "Rendering Traefik static config"
    render_traefik_template "$static_template" "$TRAEFIK_STATIC_CONFIG_FILE"
    msg_ok "TRAEFIK STATIC CONFIG REBUILT"

    msg_info "Rendering Traefik dynamic config"
    render_traefik_template "$dynamic_template" "$TRAEFIK_DYNAMIC_CONFIG_FILE"
    msg_ok "TRAEFIK DYNAMIC CONFIG REBUILT"

    run_cmd "setting Traefik config ownership" chown -R "${DOCKER_USER}:${DOCKER_USER}" "${DOCKER_DIR}/appdata/traefik"
    run_cmd "setting Traefik config directory permissions" chmod 750 "$(dirname "$TRAEFIK_STATIC_CONFIG_FILE")"
    run_cmd "setting Traefik static config permissions" chmod 644 "$TRAEFIK_STATIC_CONFIG_FILE"
    run_cmd "setting Traefik dynamic config permissions" chmod 644 "$TRAEFIK_DYNAMIC_CONFIG_FILE"
    run_cmd "setting Traefik ACME directory permissions" chmod 700 "$(dirname "$TRAEFIK_ACME_STORAGE")"
    run_cmd "setting Traefik ACME storage permissions" chmod 600 "$TRAEFIK_ACME_STORAGE"

    rm -rf "$tmp_dir" 2>/dev/null || true
    msg_ok "TRAEFIK CONFIG SELF-HEAL COMPLETE"
}

# --- 29A. ENV VALUE HELPER ---
# Reads a variable from the generated .env without printing secret values.
function env_value() {
    local key="$1"

    awk -F= -v k="$key" '
        $1 == k {
            val=$0
            sub("^[^=]*=", "", val)
            gsub(/^"|"$/, "", val)
            print val
            exit
        }
    ' "$ENV_FILE" 2>/dev/null || true
}

# --- 29A.1. ROUTE HOST NORMALIZATION HELPER ---
# Converts a hostname or URL from Script 6 into a bare Traefik Host() value.
function route_host_from_value() {
    local value="$1"

    value="${value#http://}"
    value="${value#https://}"
    value="${value%%/*}"
    value="${value%%:*}"
    printf '%s' "$value"
}

# --- 29A.2. ROUTE HOST REQUIREMENT HELPER ---
# Fails early if a compose route variable would be empty or accidentally contain a URL.
function require_route_host_value() {
    local key="$1"
    local value="$2"

    if [ -z "$value" ]; then
        msg_error "Required route hostname ${key} is missing from Script 6 .env output. Run fixed Script 6 before deployment."
    fi

    if [[ "$value" == *://* ]] || [[ "$value" == */* ]] || [[ "$value" =~ [[:space:]] ]]; then
        msg_error "Route hostname ${key} must be a bare hostname, got: ${value}"
    fi
}

# --- 29A.3. SCRIPT 6 HOSTNAME MAPPING HELPER ---
# Loads/derives non-sensitive route variables used by corrected compose templates.
function load_script6_route_values() {
    local authentik_host_raw=""
    local authentik_host_browser_raw=""

    DOMAIN_VALUE="$(env_value DOMAIN)"
    [ -n "$DOMAIN_VALUE" ] || msg_error "Required .env value DOMAIN is missing. Run fixed Script 6 before deployment."

    ADMIN_UI_HOST="$(env_value ADMIN_UI_HOST)"
    ADMIN_UI_URL="$(env_value ADMIN_UI_URL)"
    require_route_host_value "ADMIN_UI_HOST" "$ADMIN_UI_HOST"
    [ -n "$ADMIN_UI_URL" ] || ADMIN_UI_URL="https://${ADMIN_UI_HOST}"

    VSCODE_HOST="$(env_value VSCODE_HOST)"
    FILEBROWSER_HOST="$(env_value FILEBROWSER_HOST)"

    authentik_host_raw="$(env_value AUTHENTIK_EXTERNAL_URL)"
    [ -z "$authentik_host_raw" ] && authentik_host_raw="$(env_value AUTHENTIK_HOST)"
    [ -z "$authentik_host_raw" ] && authentik_host_raw="https://auth.${DOMAIN_VALUE}"

    AUTHENTIK_EXTERNAL_URL="$authentik_host_raw"
    if [[ "$AUTHENTIK_EXTERNAL_URL" != http://* ]] && [[ "$AUTHENTIK_EXTERNAL_URL" != https://* ]]; then
        AUTHENTIK_EXTERNAL_URL="https://${AUTHENTIK_EXTERNAL_URL}"
    fi

    AUTHENTIK_ROUTE_HOST="$(env_value AUTHENTIK_ROUTE_HOST)"
    [ -z "$AUTHENTIK_ROUTE_HOST" ] && AUTHENTIK_ROUTE_HOST="$(route_host_from_value "$AUTHENTIK_EXTERNAL_URL")"
    require_route_host_value "AUTHENTIK_ROUTE_HOST" "$AUTHENTIK_ROUTE_HOST"

    authentik_host_browser_raw="$(env_value AUTHENTIK_HOST_BROWSER)"
    [ -z "$authentik_host_browser_raw" ] && authentik_host_browser_raw="$AUTHENTIK_EXTERNAL_URL"
    AUTHENTIK_HOST_BROWSER_VALUE="$authentik_host_browser_raw"

    export ADMIN_UI_HOST ADMIN_UI_URL AUTHENTIK_ROUTE_HOST AUTHENTIK_EXTERNAL_URL VSCODE_HOST FILEBROWSER_HOST
}

# --- 29B. FILE WRITABILITY HELPER ---
# Verifies that the selected Docker user can create and remove a test file in a folder.
function verify_user_writable_dir() {
    local path="$1"
    local test_file="${path}/.bootstrap-write-test-$$"

    [ -d "$path" ] || return 1

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" -u "$DOCKER_USER" sh -c "touch '$test_file' && rm -f '$test_file'" >/dev/null 2>&1
    else
        su -s /bin/sh "$DOCKER_USER" -c "touch '$test_file' && rm -f '$test_file'" >/dev/null 2>&1
    fi
}

# --- 29C. COMPOSE FILE VALIDATION HELPER ---
# Validates an optional compose file only if it exists.
function validate_optional_compose_file() {
    local project="$1"
    local file="$2"

    if [ ! -f "$file" ]; then
        return 2
    fi

    run_docker_cmd "validating ${file}" compose --env-file "$ENV_FILE" -p "$project" -f "$file" config -q
}

# =========================================================
#  INPUT / PRECHECKS
# =========================================================

# --- 30. PREVIOUS MARKER CHECK ---
# Warns if Docker Bootstrap was already completed before.
function marker_key_value() {
    local key="$1"
    root_path_exists "$COMPLETED_MARKER" || return 0
    root_read_file "$COMPLETED_MARKER" 2>/dev/null | awk -F= -v key="$key" '$1 == key { $1=""; sub(/^=/, ""); print; exit }' | xargs || true
}

function marker_readable_value() {
    local label="$1"
    root_path_exists "$COMPLETED_MARKER" || return 0
    root_read_file "$COMPLETED_MARKER" 2>/dev/null | awk -F': ' -v label="$label" '$1 == label {print $2; exit}' | xargs || true
}

function numeric_menu_input() {
    local prompt="$1"
    local default="$2"
    local answer=""
    while true; do
        tty_print "${BFR}${YW}${prompt} [default: ${default}]: ${CL}"
        if [ -r /dev/tty ]; then IFS= read -r answer < /dev/tty || true; else IFS= read -r answer || true; fi
        [ -z "$answer" ] && answer="$default"
        if [[ "$answer" =~ ^[1-3]$ ]]; then clear_terminal_lines 1; printf '%s' "$answer"; return 0; fi
        tty_println "${YW}Enter 1, 2 or 3.${CL}"
    done
}

function previous_marker_summary_value() {
    local parseable_key="$1"
    local readable_label="$2"
    local value=""
    value="$(marker_key_value "$parseable_key")"
    [ -z "$value" ] && value="$(marker_readable_value "$readable_label")"
    [ -z "$value" ] && value="unknown"
    printf '%s' "$value"
}

function check_previous_marker() {
    local action=""
    local docker_dir=""
    local compose_dir=""
    local admin_ui=""
    local verification=""
    local deployed=""
    local failed=""

    if root_path_exists "$COMPLETED_MARKER"; then
        section "EXISTING DEPLOYMENT CHECK"
        docker_dir="$(previous_marker_summary_value SCRIPT65_DOCKER_DIR 'Docker dir')"
        compose_dir="$(previous_marker_summary_value SCRIPT65_COMPOSE_DIR 'Compose dir')"
        admin_ui="$(previous_marker_summary_value SCRIPT65_ADMIN_UI 'Admin UI')"
        verification="$(previous_marker_summary_value SCRIPT65_VERIFY_STATUS 'Verification')"
        deployed="$(previous_marker_summary_value SCRIPT65_DEPLOYED_STACKS 'Deployed stacks')"
        failed="$(previous_marker_summary_value SCRIPT65_FAILED_STACKS 'Failed stacks')"
        echo -e "${YW}Existing Docker deployment detected:${CL}"
        detail_line "Docker directory" "$docker_dir"
        detail_line "Compose directory" "$compose_dir"
        detail_line "Admin UI" "$admin_ui"
        detail_line "Verification" "$verification"
        detail_line "Deployed stacks" "$deployed"
        detail_line "Failed stacks" "$failed"
        echo ""
        echo -e "${YW}Action:${CL}"
        echo -e "  ${YW}1)${CL} ${GN}Verify existing deployment${CL}"
        echo -e "  ${YW}2)${CL} ${YW}Re-run stack deployment${CL}"
        echo -e "  ${YW}3)${CL} ${BL}Exit${CL}"
        echo ""
        action="$(numeric_menu_input 'Select action' '1')"
        case "$action" in
            1) VERIFY_ONLY_MODE="yes"; msg_ok "Verify existing deployment selected" ;;
            2) VERIFY_ONLY_MODE="no"; msg_ok "Re-run stack deployment selected" ;;
            3) msg_ok "Exit selected"; exit 0 ;;
        esac
    fi
    return 0
}
# --- 31. START CONFIRMATION ---
# Starts Docker network and Admin UI bootstrap after showing a clear description.
function start_confirmation() {
    local start_yn=""

    section "START"

    echo -e "${YW}Deploys Docker networks and selected stack compose files prepared by Script 6.${CL}"
    echo -e "${YW}No secrets are printed.${CL}"
    echo ""

    start_yn="$(timed_yes_no_value_only "Start Docker stack deployment?" "y")"

    if [[ "$start_yn" =~ ^[Nn] ]]; then
        exit 0
    fi

    msg_ok "Docker stack deployment start confirmed"
    return 0
}

# --- 32. BOOTSTRAP SETTINGS COLLECTION ---
# Shows Script 6-owned paths/source as locked handoff values without prompting.
function collect_bootstrap_settings() {
    section "SETUP OPTIONS"

    refresh_compose_source_urls

    if ! validate_url "$GITHUB_RAW_BASE"; then
        msg_error "GitHub raw compose base is not a valid HTTP/HTTPS URL. Set GITHUB_RAW_BASE or GITHUB_RAW_BASE_OVERRIDE before starting the script."
    fi

    group_heading "Script 6 paths"
    setup_option_line "Docker user" "$DOCKER_USER"
    setup_option_line "Docker directory" "$DOCKER_DIR"
    setup_option_line ".env file" "$ENV_FILE"
    setup_option_line "Compose dir" "$COMPOSE_DIR"
    setup_option_line "Compose source" "$COMPOSE_SOURCE_LABEL"
    echo ""
}

# --- 33. PATH PRECHECKS ---
# Validates Docker ENV output and compose directory before network/deploy work.
function validate_project_paths() {
    msg_info "Validating Docker project paths"
    clear_transient_line

    validate_script6_marker

    if ! root_path_exists "$DOCKER_DIR"; then
        msg_error "Docker directory not found: ${DOCKER_DIR}. Run script 6 first."
    fi

    if ! root_path_exists "$ENV_FILE"; then
        msg_error "Docker .env file not found: ${ENV_FILE}. Run script 6 first."
    fi

    run_cmd "creating compose directory" mkdir -p "$COMPOSE_DIR"
    run_cmd "setting compose directory ownership" chown -R "${DOCKER_USER}:${DOCKER_USER}" "$COMPOSE_DIR"

    # shellcheck disable=SC1090
    set -a
    . "$ENV_FILE"
    set +a

    DOCKER_DIR="${SCRIPT6_MARKER_DOCKER_DIR:-$DOCKER_DIR}"
    [ -z "$DOCKER_DIR" ] && DOCKER_DIR="$(env_value DOCKER_DIR)"
    COMPOSE_DIR="${DOCKER_DIR}/compose"
    ENV_FILE="${DOCKER_DIR}/.env"
    export DOCKER_DIR COMPOSE_DIR ENV_FILE

    load_script6_route_values
    DOCKER_SECRETS_DIR="$(env_value DOCKER_SECRETS_DIR)"
    CF_API_TOKEN_FILE="$(env_value CF_API_TOKEN_FILE)"
    CF_API_EMAIL_VALUE="$(env_value CF_API_EMAIL)"
    TRAEFIK_ACME_EMAIL_VALUE="$(env_value TRAEFIK_ACME_EMAIL)"
    TRAEFIK_DASHBOARD_HOST="$(env_value TRAEFIK_DASHBOARD_HOST)"
    [ -z "$TRAEFIK_DASHBOARD_HOST" ] && TRAEFIK_DASHBOARD_HOST="traefik.${DOMAIN_VALUE}"
    PROXMOX_ROUTE_ENABLED="$(env_value PROXMOX_ROUTE_ENABLED)"
    PROXMOX_ROUTE_ENABLED="${PROXMOX_ROUTE_ENABLED:-n}"
    PROXMOX_HOST="$(env_value PROXMOX_HOST)"
    PROXMOX_URL="$(env_value PROXMOX_URL)"
    ADMIN_UI="$(env_value ADMIN_UI)"
    ADMIN_UI="${ADMIN_UI:-dockge}"

    TRAEFIK_STATIC_CONFIG_FILE="$(env_value TRAEFIK_STATIC_CONFIG_FILE)"
    [ -z "$TRAEFIK_STATIC_CONFIG_FILE" ] && TRAEFIK_STATIC_CONFIG_FILE="${DOCKER_DIR}/appdata/traefik/traefik.yml"
    TRAEFIK_DYNAMIC_CONFIG_FILE="$(env_value TRAEFIK_DYNAMIC_CONFIG_FILE)"
    [ -z "$TRAEFIK_DYNAMIC_CONFIG_FILE" ] && TRAEFIK_DYNAMIC_CONFIG_FILE="${DOCKER_DIR}/appdata/traefik/dynamic-config.yml"
    TRAEFIK_ACME_STORAGE="$(env_value TRAEFIK_ACME_STORAGE)"
    [ -z "$TRAEFIK_ACME_STORAGE" ] && TRAEFIK_ACME_STORAGE="${DOCKER_DIR}/appdata/traefik/acme/acme.json"

    validate_script6_env_file

    msg_ok "SCRIPT 6 HANDOFF READY"
    echo ""
    group_heading "Environment"
    env_status_line "Docker access" "$DOCKER_ACCESS_STATUS"
    env_status_line "Script 6 marker" "present"
    env_status_line "Script 6 status" "completed"
    env_status_line "Script 6 verify" "$SCRIPT6_VERIFY_STATUS"
    detail_line "Docker directory" "$DOCKER_DIR"
    detail_line "Domain" "${DOMAIN_VALUE:-missing}"
    detail_line "Admin UI" "$ADMIN_UI"
    env_status_line ".env file" "present"
    env_status_line "Secrets" "$SCRIPT6_SECRETS_STATUS"
    env_status_line "Traefik config" "ready"
    env_status_line "ACME email" "${TRAEFIK_ACME_EMAIL_STATUS:-unknown}"
}


# =========================================================
#  SCRIPT 6 OUTPUT VALIDATION
# =========================================================


# --- 33A. SCRIPT 6 PREFLIGHT SAFETY HELPERS ---
# Validates Script 6 marker, .env, secrets and rendered config before deployment changes.
function script6_marker_key_value() {
    local key="$1"
    local value=""

    if root_path_exists "$SCRIPT6_MARKER"; then
        value="$(root_read_file "$SCRIPT6_MARKER" 2>/dev/null | awk -F= -v key="$key" '$1 == key { $1=""; sub(/^=/, ""); print; exit }' | xargs || true)"
    fi

    printf '%s' "$value"
}

function is_bare_hostname() {
    local value="$1"

    [ -n "$value" ] || return 1
    [[ "$value" != *://* ]] || return 1
    [[ "$value" != */* ]] || return 1
    [[ "$value" != *\?* ]] || return 1
    [[ "$value" != *#* ]] || return 1
    [[ "$value" != *[[:space:]]* ]] || return 1
    [[ "$value" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]]
}

function is_http_url() {
    local value="$1"

    [[ "$value" =~ ^https?://[^[:space:]/]+([^[:space:]]*)?$ ]]
}

function host_from_url() {
    local value="$1"

    value="${value#http://}"
    value="${value#https://}"
    value="${value%%/*}"
    value="${value%%\?*}"
    value="${value%%#*}"
    value="${value%%:*}"
    printf '%s' "$value"
}

function host_under_domain() {
    local host="$1"
    local domain="$2"

    [ -n "$host" ] || return 1
    [ -n "$domain" ] || return 1
    [ "$host" == "$domain" ] && return 0
    [[ "$host" == *."$domain" ]]
}

function require_env_key_present() {
    local key="$1"
    local value=""

    value="$(env_value "$key")"
    if [ -z "$value" ]; then
        msg_error "Required Script 6 .env key is missing or empty: ${key}"
    fi

    return 0
}

function require_email_env_key() {
    local key="$1"
    local value=""

    value="$(env_value "$key")"
    value="$(printf '%s' "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    if ! is_email_like "$value"; then
        msg_error "Required Script 6 .env key ${key} is missing, empty, or not email-like. Rerun Script 6 v1.6.14+."
    fi

    printf '%s' "$value"
}

function require_bare_host_env_key() {
    local key="$1"
    local value=""

    value="$(env_value "$key")"
    [ -n "$value" ] || msg_error "Required hostname key ${key} is missing from Script 6 .env. Rerun Script 6 v1.6.13+."
    is_bare_hostname "$value" || msg_error "${key} must be a bare hostname, got: ${value}"
    host_under_domain "$value" "$DOMAIN_VALUE" || msg_error "${key} (${value}) is outside configured DOMAIN (${DOMAIN_VALUE}). Rerun Script 6 v1.6.13+."
}

function require_url_env_key() {
    local key="$1"
    local value=""
    local url_host=""

    value="$(env_value "$key")"
    [ -n "$value" ] || msg_error "Required URL key ${key} is missing from Script 6 .env. Rerun Script 6 v1.6.13+."
    is_http_url "$value" || msg_error "${key} must be an http:// or https:// URL, got: ${value}"
    url_host="$(host_from_url "$value")"
    host_under_domain "$url_host" "$DOMAIN_VALUE" || msg_error "${key} host (${url_host}) is outside configured DOMAIN (${DOMAIN_VALUE}). Rerun Script 6 v1.6.13+."
}

function validate_rendered_traefik_acme_email() {
    local rendered_email=""

    root_path_exists "$TRAEFIK_STATIC_CONFIG_FILE" || msg_error "Traefik static config missing: ${TRAEFIK_STATIC_CONFIG_FILE}. Rerun Script 6."

    rendered_email="$(root_read_file "$TRAEFIK_STATIC_CONFIG_FILE" 2>/dev/null | grep -E '^[[:space:]]*email:[[:space:]]*' | head -n1 | sed -e 's/^[[:space:]]*email:[[:space:]]*//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" | xargs || true)"

    case "$rendered_email" in
        ""|'${TRAEFIK_ACME_EMAIL}'|'{{TRAEFIK_ACME_EMAIL}}')
            msg_error "Traefik ACME email is missing from rendered traefik.yml. Rerun Script 6 v1.6.14+."
            ;;
    esac

    if ! is_email_like "$rendered_email"; then
        msg_error "Traefik ACME email in rendered traefik.yml is not email-like. Rerun Script 6 v1.6.14+."
    fi

    TRAEFIK_ACME_EMAIL_STATUS="ready"
}

function validate_script6_marker() {
    local marker_status=""
    local marker_verify=""
    local marker_docker_dir=""
    local marker_domain=""
    local marker_admin_ui=""
    local marker_traefik=""
    local marker_secrets=""
    local marker_env=""

    msg_info "Validating Script 6 completion marker"

    root_path_exists "$SCRIPT6_MARKER" || msg_error "Script 6 completion marker missing: ${SCRIPT6_MARKER}. Run Script 6 v1.6.13 before Script 6.5."

    marker_status="$(script6_marker_key_value SCRIPT6_STATUS)"
    marker_verify="$(script6_marker_key_value SCRIPT6_VERIFY_STATUS)"
    marker_docker_dir="$(script6_marker_key_value SCRIPT6_DOCKER_DIR)"
    marker_domain="$(script6_marker_key_value SCRIPT6_DOMAIN)"
    marker_admin_ui="$(script6_marker_key_value SCRIPT6_ADMIN_UI)"
    marker_traefik="$(script6_marker_key_value SCRIPT6_TRAEFIK_CONFIG)"
    marker_secrets="$(script6_marker_key_value SCRIPT6_SECRETS_READY)"
    marker_env="$(script6_marker_key_value SCRIPT6_ENV_FILE_READY)"

    [ "$marker_status" == "completed" ] || msg_error "Script 6 marker is not completed. Found SCRIPT6_STATUS=${marker_status:-missing}."
    case "$marker_verify" in
        PASS)
            ;;
        PASS_WITH_WARNINGS)
            msg_warn "Script 6 verification completed with warnings. Continuing because PASS_WITH_WARNINGS is allowed."
            ;;
        *)
            msg_error "Script 6 verification is not deploy-safe. Found SCRIPT6_VERIFY_STATUS=${marker_verify:-missing}."
            ;;
    esac

    [ -n "$marker_docker_dir" ] || msg_error "Script 6 marker missing SCRIPT6_DOCKER_DIR. Rerun Script 6."
    [ -n "$marker_domain" ] || msg_error "Script 6 marker missing SCRIPT6_DOMAIN. Rerun Script 6."
    [ -n "$marker_admin_ui" ] || msg_error "Script 6 marker missing SCRIPT6_ADMIN_UI. Rerun Script 6."
    [ "$marker_traefik" == "yes" ] || msg_error "Script 6 marker says Traefik config is not ready: SCRIPT6_TRAEFIK_CONFIG=${marker_traefik:-missing}. Rerun Script 6."
    [ "$marker_secrets" == "yes" ] || msg_error "Script 6 marker says secrets are not ready: SCRIPT6_SECRETS_READY=${marker_secrets:-missing}. Rerun Script 6."
    [ "$marker_env" == "yes" ] || msg_error "Script 6 marker says .env is not ready: SCRIPT6_ENV_FILE_READY=${marker_env:-missing}. Rerun Script 6."

    SCRIPT6_PREFLIGHT_STATUS="$marker_verify"
    SCRIPT6_VERIFY_STATUS="$marker_verify"
    SCRIPT6_MARKER_DOCKER_DIR="$marker_docker_dir"
    SCRIPT6_MARKER_DOMAIN="$marker_domain"
    SCRIPT6_MARKER_ADMIN_UI="$marker_admin_ui"
    SCRIPT6_SECRETS_STATUS="ready"
    TRAEFIK_CONFIG_PREFLIGHT_STATUS="ready"

    DOCKER_DIR="$marker_docker_dir"
    DOCKER_USER="$(basename "$(dirname "$DOCKER_DIR")")"
    COMPOSE_DIR="${DOCKER_DIR}/compose"
    ENV_FILE="${DOCKER_DIR}/.env"
    export DOCKER_DIR COMPOSE_DIR ENV_FILE

    clear_transient_line
    msg_ok "SCRIPT 6 MARKER VALIDATED"
}

function validate_script6_env_file() {
    local key=""
    local required_keys=(
        DOMAIN
        ADMIN_UI
        ADMIN_UI_HOST
        ADMIN_UI_URL
        AUTHENTIK_ROUTE_HOST
        AUTHENTIK_EXTERNAL_URL
        TRAEFIK_ACME_EMAIL
        TRAEFIK_HOST
        POSTIZ_HOST
        FILEBROWSER_HOST
        VSCODE_HOST
        DOCKER_DIR
        DOCKER_SECRETS_DIR
    )
    local optional_host_keys=(
        LANDING_HOST
        LANDING_WWW_HOST
        AUTHENTIK_HOST_BROWSER_VALUE
        AUTHENTIK_HOST_BROWSER
        N8N_HOST
    )

    msg_info "Validating Script 6 .env keys"

    root_path_exists "$ENV_FILE" || msg_error "Script 6 .env file missing: ${ENV_FILE}. Rerun Script 6."

    for key in "${required_keys[@]}"; do
        require_env_key_present "$key"
    done

    TRAEFIK_ACME_EMAIL_VALUE="$(require_email_env_key "TRAEFIK_ACME_EMAIL")"
    TRAEFIK_ACME_EMAIL_STATUS="ready"

    require_bare_host_env_key "ADMIN_UI_HOST"
    require_bare_host_env_key "AUTHENTIK_ROUTE_HOST"
    require_bare_host_env_key "TRAEFIK_HOST"
    require_bare_host_env_key "POSTIZ_HOST"
    require_bare_host_env_key "FILEBROWSER_HOST"
    require_bare_host_env_key "VSCODE_HOST"
    require_url_env_key "ADMIN_UI_URL"
    require_url_env_key "AUTHENTIK_EXTERNAL_URL"

    for key in "${optional_host_keys[@]}"; do
        if [ -n "$(env_value "$key")" ]; then
            case "$key" in
                AUTHENTIK_HOST_BROWSER_VALUE|AUTHENTIK_HOST_BROWSER)
                    require_url_env_key "$key"
                    ;;
                *)
                    require_bare_host_env_key "$key"
                    ;;
            esac
        fi
    done

    SCRIPT6_ENV_REQUIRED_KEYS_STATUS="ready"
    SCRIPT6_ENV_HOSTNAMES_STATUS="ready"
    SCRIPT6_ENV_URLS_STATUS="ready"

    clear_transient_line
    msg_ok "SCRIPT 6 .ENV PREFLIGHT PASSED"
}

function secret_file_status() {
    local path="$1"
    local allow_empty="${2:-no}"

    if ! root_path_exists "$path"; then
        printf 'missing'
    elif root_file_not_empty "$path"; then
        printf 'present'
    elif [ "$allow_empty" == "yes" ]; then
        printf 'empty placeholder'
    else
        printf 'empty'
    fi
}

function require_secret_file_status() {
    local label="$1"
    local path="$2"
    local allow_empty="${3:-no}"
    local status=""

    status="$(secret_file_status "$path" "$allow_empty")"
    case "$status" in
        present)
            ;;
        "empty placeholder")
            ;;
        empty)
            msg_error "Required secret file is empty: ${path}"
            ;;
        missing)
            msg_error "Required secret file is missing: ${path}"
            ;;
    esac
}

function validate_required_secret_files() {
    local required_secrets=(
        postgres_password
        redis_password
        authentik_secret_key
        authentik_postgres_password
        postiz_postgres_password
        postiz_jwt_secret
        temporal_postgres_password
    )
    local secret=""

    [ -n "$DOCKER_SECRETS_DIR" ] || msg_error "DOCKER_SECRETS_DIR is missing from Script 6 .env. Rerun Script 6."
    root_path_exists "$DOCKER_SECRETS_DIR" || msg_error "Docker secrets directory missing: ${DOCKER_SECRETS_DIR}. Rerun Script 6."

    msg_info "Validating required secret files"
    clear_transient_line

    for secret in "${required_secrets[@]}"; do
        require_secret_file_status "$secret" "${DOCKER_SECRETS_DIR}/${secret}" "no"
    done

    require_secret_file_status "htpasswd" "${DOCKER_SECRETS_DIR}/htpasswd" "yes"

    if selected_stack_contains "$TRAEFIK_STACK_FILE" || [[ "$DEPLOY_CF_DDNS" =~ ^[Yy] ]] || [[ "$DEPLOY_CF_COMPANION" =~ ^[Yy] ]]; then
        require_secret_file_status "cf_api_token" "${CF_API_TOKEN_FILE:-${DOCKER_SECRETS_DIR}/cf_api_token}" "no"
    else
        :
    fi

    if [ "$ADMIN_UI" == "komodo" ]; then
        require_secret_file_status "komodo_db_password" "${DOCKER_SECRETS_DIR}/komodo_db_password" "no"
        require_secret_file_status "komodo_passkey" "${DOCKER_SECRETS_DIR}/komodo_passkey" "no"
        require_secret_file_status "komodo_webhook_secret" "${DOCKER_SECRETS_DIR}/komodo_webhook_secret" "no"
        require_secret_file_status "komodo_jwt_secret" "${DOCKER_SECRETS_DIR}/komodo_jwt_secret" "no"
    fi

    SCRIPT6_SECRETS_STATUS="ready"
    SCRIPT6_HTPASSWD_STATUS="$(secret_file_status "${DOCKER_SECRETS_DIR}/htpasswd" "yes")"
}

function validate_traefik_config_files_predeploy() {
    local acme_mode=""

    [ -f "$TRAEFIK_STATIC_CONFIG_FILE" ] || msg_error "Traefik static config missing: ${TRAEFIK_STATIC_CONFIG_FILE}. Rerun Script 6."
    [ -f "$TRAEFIK_DYNAMIC_CONFIG_FILE" ] || msg_error "Traefik dynamic config missing: ${TRAEFIK_DYNAMIC_CONFIG_FILE}. Rerun Script 6."
    [ -f "$TRAEFIK_ACME_STORAGE" ] || msg_error "Traefik acme.json missing: ${TRAEFIK_ACME_STORAGE}. Rerun Script 6."

    if grep -R '{{[^}]*}}' "$TRAEFIK_STATIC_CONFIG_FILE" "$TRAEFIK_DYNAMIC_CONFIG_FILE" >/dev/null 2>&1; then
        msg_error "Unresolved template placeholders remain in Traefik config files. Rerun Script 6."
    fi

    validate_rendered_traefik_acme_email

    acme_mode="$(root_stat_mode "$TRAEFIK_ACME_STORAGE")"
    [ "$acme_mode" == "600" ] || msg_error "Traefik acme.json mode is ${acme_mode:-unknown}; expected 600. Rerun Script 6."

    TRAEFIK_CONFIG_PREFLIGHT_STATUS="ready"
}

function validate_cf_companion_predeploy() {
    local cf_auth_mode=""
    local cf_email_required=""
    local cf_zone_id=""
    local cf_token_path=""

    cf_auth_mode="$(env_value CF_AUTH_MODE)"
    cf_email_required="$(env_value CF_EMAIL_REQUIRED)"
    cf_zone_id="$(env_value CF_ZONE_ID)"
    cf_token_path="${CF_API_TOKEN_FILE:-$(env_value CF_API_TOKEN_FILE)}"

    # Script 6 v1.6.14+ keeps Cloudflare token mode email-free.
    # cf-companion must use token + Zone ID and must not require CF_API_EMAIL.
    if [ "$cf_auth_mode" == "api_token" ] || [ "$cf_auth_mode" == "api_token_file_reuse" ] || [ "$cf_email_required" == "no" ]; then
        :
    fi

    [ -n "$cf_zone_id" ] || msg_error "Cloudflare Companion selected but CF_ZONE_ID is missing from .env. Rerun Script 6 and provide the Cloudflare Zone ID, or skip cf-companion."
    [ -n "$cf_token_path" ] || msg_error "Cloudflare Companion selected but CF_API_TOKEN_FILE is missing from .env. Rerun Script 6."
    root_file_not_empty "$cf_token_path" || msg_error "Cloudflare Companion selected but cf_api_token is missing or empty: ${cf_token_path}. Rerun Script 6 with a token, or skip cf-companion."
}

function selected_stack_count() {
    local count="2"
    local file=""

    for file in "${SELECTED_STACK_FILES[@]:-}"; do
        if is_helper_compose_file "$file"; then
            continue
        fi
        count=$((count + 1))
    done

    printf '%s' "$count"
}

function helper_file_count() {
    local count="1"
    local file=""

    # The selected Admin UI bootstrap override is a helper compose fragment,
    # not a deployed stack. Keep it out of selected/deployed/failed stack lists.
    for file in "${SELECTED_STACK_FILES[@]:-}"; do
        if is_helper_compose_file "$file"; then
            count=$((count + 1))
        fi
    done

    printf '%s' "$count"
}

function compose_file_total_count() {
    printf '%s' "$(( $(selected_stack_count) + $(helper_file_count) ))"
}

function compose_plan_selected_count() {
    compose_file_total_count
}

# --- 33A. REDIS HOST TUNING VERIFICATION ---
# Confirms Script 5 applied the Redis-recommended overcommit setting before Redis deployment.
function verify_redis_host_tuning() {
    local value=""
    value="$(cat /proc/sys/vm/overcommit_memory 2>/dev/null || echo "")"

    if [ "$value" == "1" ]; then
        SYSCTL_REDIS_OK="yes"
    else
        msg_error "vm.overcommit_memory is ${value:-unknown}. Run fixed Script 5 before deploying Redis."
    fi

    if [ -f /etc/sysctl.d/99-redis-overcommit.conf ] || { [ -n "$SUDO_CMD" ] && "$SUDO_CMD" test -f /etc/sysctl.d/99-redis-overcommit.conf 2>/dev/null; }; then
        :
    else
        msg_warn "Redis sysctl persistence file not found. Runtime value is correct, but reboot persistence should be fixed."
    fi
}

# --- 33B. TRAEFIK TEMPLATE RENDER VERIFICATION ---
# Ensures no unreplaced placeholders remain and final Traefik v3.7 settings exist.
function verify_traefik_rendered_configs() {
    [ -f "$TRAEFIK_STATIC_CONFIG_FILE" ] || msg_error "Traefik static config missing: ${TRAEFIK_STATIC_CONFIG_FILE}. Rerun Script 6."
    [ -f "$TRAEFIK_DYNAMIC_CONFIG_FILE" ] || msg_error "Traefik dynamic config missing: ${TRAEFIK_DYNAMIC_CONFIG_FILE}. Rerun Script 6."
    [ -f "$TRAEFIK_ACME_STORAGE" ] || msg_error "Traefik acme.json missing: ${TRAEFIK_ACME_STORAGE}. Rerun Script 6."

    if grep -R '{{[^}]*}}' "$TRAEFIK_STATIC_CONFIG_FILE" "$TRAEFIK_DYNAMIC_CONFIG_FILE" >/dev/null 2>&1; then
        msg_error "Unrendered {{PLACEHOLDER}} values remain in Traefik config. Fix Script 6 render logic/templates."
    fi
    validate_rendered_traefik_acme_email
    TRAEFIK_PLACEHOLDERS_OK="yes"

    if grep -q 'delayBefore''Checks' "$TRAEFIK_STATIC_CONFIG_FILE" && ! grep -q 'delayBefore''Check:' "$TRAEFIK_STATIC_CONFIG_FILE"; then
        TRAEFIK_DNS_DELAY_OK="yes"
    else
        msg_error "Traefik DNS challenge must use the current Traefik v3 propagation delay key, not the deprecated singular key."
    fi

    if grep -q 'encodedCharacters' "$TRAEFIK_STATIC_CONFIG_FILE"; then
        TRAEFIK_ENCODED_CHARS_OK="yes"
    else
        msg_error "Traefik encoded-character options missing from static config. Fix Script 6 template."
    fi

    if grep -q "authentik@""docker" "$TRAEFIK_DYNAMIC_CONFIG_FILE"; then
        msg_error "Stale Authentik Docker-provider middleware reference found in dynamic config. Use authentik file-provider middleware."
    fi
    TRAEFIK_AUTHENTIK_REFERENCES_OK="yes"

    if ! grep -q "main: \"${DOMAIN_VALUE}\"" "$TRAEFIK_STATIC_CONFIG_FILE" 2>/dev/null && ! grep -q "main: ${DOMAIN_VALUE}" "$TRAEFIK_STATIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik static config does not contain the base wildcard certificate domain."
    fi
    if ! grep -q "\*.${DOMAIN_VALUE}" "$TRAEFIK_STATIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik static config does not contain wildcard SAN *.${DOMAIN_VALUE}."
    fi
    if grep -q 'certResolver: cloudflare' "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik dynamic config still contains per-router certResolver entries. Wildcard issuance must stay centralized in traefik.yml."
    fi

    local acme_mode=""
    acme_mode="$(stat -c '%a' "$TRAEFIK_ACME_STORAGE" 2>/dev/null || true)"
    if [ "$acme_mode" == "600" ]; then
        :
    else
        msg_error "Traefik acme.json mode is ${acme_mode:-unknown}; expected 600."
    fi
}

# --- 33C. AUTHENTIK FOLDER VERIFICATION ---
# Confirms host bind mounts exist and are writable by the non-root Authentik container user.
function verify_authentik_folders() {
    local folders=(
        "${DOCKER_DIR}/appdata/authentik"
        "${DOCKER_DIR}/appdata/authentik/media"
        "${DOCKER_DIR}/appdata/authentik/custom-templates"
        "${DOCKER_DIR}/appdata/authentik/certs"
    )
    local folder=""

    for folder in "${folders[@]}"; do
        [ -d "$folder" ] || msg_error "Required Authentik folder missing: ${folder}"

        if [ -n "$SUDO_CMD" ]; then
            "$SUDO_CMD" -u '#1000' sh -c "touch '${folder}/.ak-write-test-$$' && rm -f '${folder}/.ak-write-test-$$'" >/dev/null 2>&1 || msg_error "Authentik UID 1000 cannot write to ${folder}"
        else
            touch "${folder}/.ak-write-test-$$" && rm -f "${folder}/.ak-write-test-$$" || msg_error "Cannot verify Authentik write access to ${folder}"
        fi

    done

    AUTHENTIK_FOLDERS_OK="yes"
}

function verify_authentik_smtp_env() {
    local smtp_host=""
    local smtp_port=""
    local smtp_username=""
    local smtp_from=""
    local smtp_use_tls=""
    local smtp_use_ssl=""
    local smtp_timeout=""
    local smtp_password=""
    local password_status=""

    [ -f "$ENV_FILE" ] || msg_error "Docker .env file not found: ${ENV_FILE}"

    smtp_host="$(grep -E '^AUTHENTIK_EMAIL__HOST=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" | xargs || true)"

    if [ -z "$smtp_host" ]; then
        msg_warn "Authentik SMTP relay not configured; skipping SMTP env verification"
        AUTHENTIK_SMTP_ENV_OK="skipped"
        return 0
    fi

    smtp_port="$(grep -E '^AUTHENTIK_EMAIL__PORT=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" | xargs || true)"
    smtp_username="$(grep -E '^AUTHENTIK_EMAIL__USERNAME=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" | xargs || true)"
    smtp_from="$(grep -E '^AUTHENTIK_EMAIL__FROM=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" | xargs || true)"
    smtp_use_tls="$(grep -E '^AUTHENTIK_EMAIL__USE_TLS=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" | xargs || true)"
    smtp_use_ssl="$(grep -E '^AUTHENTIK_EMAIL__USE_SSL=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" | xargs || true)"
    smtp_timeout="$(grep -E '^AUTHENTIK_EMAIL__TIMEOUT=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" | xargs || true)"
    smtp_password="$(grep -E '^AUTHENTIK_EMAIL__PASSWORD=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//" | xargs || true)"

    password_status="$( [ -n "$smtp_password" ] && echo set || echo missing)"


    [ -n "$smtp_port" ] || msg_error "Authentik SMTP port is required when SMTP host is set"
    [ -n "$smtp_username" ] || msg_error "Authentik SMTP username is required when SMTP host is set"
    [ -n "$smtp_password" ] || msg_error "Authentik SMTP password is required when SMTP host is set"
    [ -n "$smtp_from" ] || msg_error "Authentik SMTP sender address is required when SMTP host is set"
    [ -n "$smtp_use_tls" ] || msg_error "Authentik SMTP USE_TLS is required when SMTP host is set"
    [ -n "$smtp_use_ssl" ] || msg_error "Authentik SMTP USE_SSL is required when SMTP host is set"
    [ -n "$smtp_timeout" ] || msg_error "Authentik SMTP TIMEOUT is required when SMTP host is set"

    AUTHENTIK_SMTP_ENV_OK="yes"
}

# --- 33E. ADMIN UI SELECTION VERIFICATION ---
# Maps .env ADMIN_UI to expected compose template and service.
function verify_admin_ui_selection() {
    case "$ADMIN_UI" in
        dockge)
            ADMIN_UI_PROJECT_NAME="dockge"
            ADMIN_UI_SERVICE_NAME="dockge"
            ADMIN_UI_DISPLAY_NAME="Dockge"
            ADMIN_UI_COMPOSE_FILE="${COMPOSE_DIR}/${DOCKGE_STACK_FILE}"
            ADMIN_UI_BOOTSTRAP_OVERRIDE_NAME="$DOCKGE_BOOTSTRAP_OVERRIDE_FILE_NAME"
            ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE="${COMPOSE_DIR}/${DOCKGE_BOOTSTRAP_OVERRIDE_FILE_NAME}"
            ADMIN_UI_BOOTSTRAP_PORT="$DOCKGE_BOOTSTRAP_PORT"
            ADMIN_UI_INTERNAL_PORT="5001"
            ADMIN_UI_BOOTSTRAP_SCHEME="http"
            ;;
        portainer|portainer-ce)
            ADMIN_UI="portainer"
            ADMIN_UI_PROJECT_NAME="portainer"
            ADMIN_UI_SERVICE_NAME="portainer"
            ADMIN_UI_DISPLAY_NAME="Portainer"
            ADMIN_UI_COMPOSE_FILE="${COMPOSE_DIR}/${PORTAINER_STACK_FILE}"
            ADMIN_UI_BOOTSTRAP_OVERRIDE_NAME="$PORTAINER_BOOTSTRAP_OVERRIDE_FILE_NAME"
            ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE="${COMPOSE_DIR}/${PORTAINER_BOOTSTRAP_OVERRIDE_FILE_NAME}"
            ADMIN_UI_BOOTSTRAP_PORT="$PORTAINER_BOOTSTRAP_PORT"
            ADMIN_UI_INTERNAL_PORT="9443"
            ADMIN_UI_BOOTSTRAP_SCHEME="https"
            ;;
        komodo)
            ADMIN_UI_PROJECT_NAME="komodo"
            ADMIN_UI_SERVICE_NAME="komodo-core"
            ADMIN_UI_DISPLAY_NAME="Komodo"
            ADMIN_UI_COMPOSE_FILE="${COMPOSE_DIR}/${KOMODO_STACK_FILE}"
            ADMIN_UI_BOOTSTRAP_OVERRIDE_NAME="$KOMODO_BOOTSTRAP_OVERRIDE_FILE_NAME"
            ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE="${COMPOSE_DIR}/${KOMODO_BOOTSTRAP_OVERRIDE_FILE_NAME}"
            ADMIN_UI_BOOTSTRAP_PORT="$KOMODO_BOOTSTRAP_PORT"
            ADMIN_UI_INTERNAL_PORT="9120"
            ADMIN_UI_BOOTSTRAP_SCHEME="http"
            ;;
        dockhand)
            ADMIN_UI_PROJECT_NAME="dockhand"
            ADMIN_UI_SERVICE_NAME="dockhand"
            ADMIN_UI_DISPLAY_NAME="Dockhand"
            ADMIN_UI_COMPOSE_FILE="${COMPOSE_DIR}/${DOCKHAND_STACK_FILE}"
            ADMIN_UI_BOOTSTRAP_OVERRIDE_NAME="$DOCKHAND_BOOTSTRAP_OVERRIDE_FILE_NAME"
            ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE="${COMPOSE_DIR}/${DOCKHAND_BOOTSTRAP_OVERRIDE_FILE_NAME}"
            ADMIN_UI_BOOTSTRAP_PORT="$DOCKHAND_BOOTSTRAP_PORT"
            ADMIN_UI_INTERNAL_PORT="3000"
            ADMIN_UI_BOOTSTRAP_SCHEME="http"
            ;;
        *)
            msg_error "Invalid ADMIN_UI value in .env: ${ADMIN_UI}. Expected dockge, portainer, komodo, or dockhand."
            ;;
    esac

    require_route_host_value "ADMIN_UI_HOST" "$ADMIN_UI_HOST"
    [ -n "$ADMIN_UI_URL" ] || ADMIN_UI_URL="https://${ADMIN_UI_HOST}"
    export ADMIN_UI_HOST ADMIN_UI_URL

    group_heading "Admin UI"
    setup_option_line "Status" "verified"
    setup_option_line "Selected UI" "$ADMIN_UI_DISPLAY_NAME"
    setup_option_line "Admin UI host" "$ADMIN_UI_HOST"
    setup_option_line "Admin UI URL" "$ADMIN_UI_URL"
    setup_option_line "Stack compose" "$ADMIN_UI_COMPOSE_FILE"
    setup_option_line "Bootstrap override" "$ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE"
    setup_option_line "Bootstrap port" "$ADMIN_UI_BOOTSTRAP_PORT"
    echo ""
}

# --- 33F. CLOUDFLARE COMPANION SECRET VERIFICATION ---
# Ensures cf-companion can read Cloudflare token from a local secret file.
function verify_cf_companion_secret_file() {
    if [ -z "$CF_API_TOKEN_FILE" ]; then
        CF_COMPANION_SECRET_OK="missing-env"
        msg_warn "CF_API_TOKEN_FILE missing from .env"
        return 0
    fi

    if [ -s "$CF_API_TOKEN_FILE" ]; then
        CF_COMPANION_SECRET_OK="yes"
    else
        CF_COMPANION_SECRET_OK="empty-or-missing"
        msg_warn "Cloudflare token file is empty or missing: ${CF_API_TOKEN_FILE}"
    fi
}

# --- 33G. FILEBROWSER FOLDER VERIFICATION ---
# Confirms Filebrowser-safe writable folders exist before Filebrowser stack deployment.
function verify_filebrowser_folders() {
    local folders=(
        "${DOCKER_DIR}/appdata/filebrowser/database"
        "${DOCKER_DIR}/appdata/filebrowser/config"
        "${DOCKER_DIR}/shared"
        "${DOCKER_DIR}/backups"
        "${DOCKER_DIR}/compose"
    )
    local folder=""

    for folder in "${folders[@]}"; do
        [ -d "$folder" ] || msg_error "Required Filebrowser folder missing: ${folder}"
        verify_user_writable_dir "$folder" || msg_error "Docker user ${DOCKER_USER} cannot write to ${folder}"
    done

    FILEBROWSER_FOLDERS_OK="yes"
}



# --- 33H. POSTGRESQL / REDIS RUNTIME REPAIR + READINESS ---
# Re-applies proven safe service-specific permissions immediately before deployment.
function selected_stack_contains() {
    local wanted="$1"
    local item=""
    for item in "${SELECTED_STACK_FILES[@]:-}"; do
        [ "$item" == "$wanted" ] && return 0
    done
    return 1
}

function is_helper_compose_file() {
    local file="$1"

    case "$file" in
        "$POSTIZ_TEMPORAL_GUARD_STACK_FILE")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}


function service_compose_uses_puid_pgid() {
    local file="$1"
    local compose_path=""

    compose_path="$(compose_path_for_stack_file "$file")"

    [ -f "$compose_path" ] || return 1

    if grep -Eq 'PUID|PGID|\$\{PUID\}|\$\{PGID\}' "$compose_path"; then
        return 0
    fi

    return 1
}

function default_docker_user_uid() {
    id -u "$DOCKER_USER" 2>/dev/null || echo "1000"
}

function default_docker_user_gid() {
    id -g "$DOCKER_USER" 2>/dev/null || echo "1000"
}

function service_data_owner() {
    local file="$1"
    local default_uid="$2"
    local default_gid="$3"
    local uid=""
    local gid=""

    if service_compose_uses_puid_pgid "$file"; then
        uid="$(env_value PUID)"
        gid="$(env_value PGID)"
        [ -z "$uid" ] && uid="$(default_docker_user_uid)"
        [ -z "$gid" ] && gid="$(default_docker_user_gid)"
    else
        uid="$default_uid"
        gid="$default_gid"
    fi

    printf '%s:%s' "$uid" "$gid"
}

function postgres_process_owner() {
    local runtime_uid=""
    local runtime_gid=""

    # PostgreSQL can create/write the mounted cluster tree as the actual
    # running postgres server process user. Fresh testing proved this may differ
    # from the fallback 999:999, so runtime repairs must follow the live process
    # owner once the container exists.
    if docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx 'postgres'; then
        runtime_uid="$(docker_cmd exec postgres sh -lc "awk '/^Uid:/ {print \\$2; exit}' /proc/1/status" 2>/dev/null || true)"
        runtime_gid="$(docker_cmd exec postgres sh -lc "awk '/^Gid:/ {print \\$2; exit}' /proc/1/status" 2>/dev/null || true)"

        if [[ "$runtime_uid" =~ ^[0-9]+$ ]] && [[ "$runtime_gid" =~ ^[0-9]+$ ]]; then
            printf '%s:%s' "$runtime_uid" "$runtime_gid"
            return 0
        fi
    fi

    return 1
}

function postgres_data_owner() {
    local process_owner=""

    if process_owner="$(postgres_process_owner 2>/dev/null)" && [ -n "$process_owner" ]; then
        printf '%s' "$process_owner"
        return 0
    fi

    service_data_owner "$POSTGRES_STACK_FILE" "999" "999"
}

function postgres_container_process_owner() {
    local runtime_uid=""
    local runtime_gid=""

    if docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx 'postgres'; then
        runtime_uid="$(docker_cmd exec postgres sh -lc 'id -u postgres' 2>/dev/null || true)"
        runtime_gid="$(docker_cmd exec postgres sh -lc 'id -g postgres' 2>/dev/null || true)"

        if [[ "$runtime_uid" =~ ^[0-9]+$ ]] && [[ "$runtime_gid" =~ ^[0-9]+$ ]]; then
            printf '%s:%s' "$runtime_uid" "$runtime_gid"
            return 0
        fi
    fi

    return 1
}

function postgres_container_pgdata_path() {
    local pgdata=""

    if docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx 'postgres'; then
        pgdata="$(docker_cmd exec postgres sh -lc 'printf "%s\n" "${PGDATA:-/var/lib/postgresql/data}"' 2>/dev/null || true)"
    fi

    if [ -n "$pgdata" ]; then
        printf '%s' "$pgdata"
        return 0
    fi

    return 1
}

function redis_process_owner() {
    local runtime_uid=""
    local runtime_gid=""

    # docker exec id -u can report the exec/default user, not the actual Redis
    # server process owner. Use /proc/1/status first because temp RDB files are
    # created by the running redis-server process.
    if docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx 'redis'; then
        runtime_uid="$(docker_cmd exec redis sh -lc "awk '/^Uid:/ {print \\$2; exit}' /proc/1/status" 2>/dev/null || true)"
        runtime_gid="$(docker_cmd exec redis sh -lc "awk '/^Gid:/ {print \\$2; exit}' /proc/1/status" 2>/dev/null || true)"

        if [[ "$runtime_uid" =~ ^[0-9]+$ ]] && [[ "$runtime_gid" =~ ^[0-9]+$ ]]; then
            printf '%s:%s' "$runtime_uid" "$runtime_gid"
            return 0
        fi
    fi

    return 1
}

function redis_data_owner() {
    local process_owner=""

    if process_owner="$(redis_process_owner 2>/dev/null)" && [ -n "$process_owner" ]; then
        printf '%s' "$process_owner"
        return 0
    fi

    service_data_owner "$REDIS_STACK_FILE" "999" "999"
}

function ensure_core_stack_started() {
    local container_name="$1"
    local stack_file="$2"
    local project="$3"
    local description="$4"
    local compose_path=""

    compose_path="$(compose_path_for_stack_file "$stack_file")"

    if [ ! -f "$compose_path" ]; then
        msg_error "Compose file missing for ${description}: ${compose_path}"
    fi

    if ! docker_cmd ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$container_name"; then
        compose_up_quiet "deploying ${description} before dependency checks" --env-file "$ENV_FILE" -p "$project" -f "$compose_path"
        return 0
    fi

    if ! docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx "$container_name"; then
        compose_up_quiet "starting ${description} before dependency checks" --env-file "$ENV_FILE" -p "$project" -f "$compose_path"
        return 0
    fi

    return 0
}

function ensure_postgres_stack_started() {
    ensure_core_stack_started "postgres" "$POSTGRES_STACK_FILE" "postgres" "PostgreSQL"
}

function ensure_redis_stack_started() {
    ensure_core_stack_started "redis" "$REDIS_STACK_FILE" "redis" "Redis"
}


function repair_postgres_pgdata_permissions() {
    local pg_data_dir="${DOCKER_DIR}/appdata/postgres/pgdata"
    local expected_owner=""
    local expected_uid=""
    local expected_gid=""
    local deps="authentik-worker authentik-server postiz temporal"
    local running_deps=""
    local dep=""

    if [ -z "$pg_data_dir" ]; then
        msg_error "PostgreSQL pgdata path is empty. Cannot repair permissions."
    fi

    expected_owner="$(postgres_container_process_owner 2>/dev/null || true)"
    if [ -z "$expected_owner" ]; then
        expected_owner="$(postgres_data_owner)"
    fi

    expected_uid="${expected_owner%%:*}"
    expected_gid="${expected_owner##*:}"

    for dep in $deps; do
        if docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx "$dep"; then
            running_deps="${running_deps}${dep}"$'\n'
            docker_cmd stop "$dep" >/dev/null 2>&1 || true
        fi
    done

    if docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx 'postgres'; then
        docker_cmd stop postgres >/dev/null 2>&1 || true
    fi

    run_cmd "creating PostgreSQL PG18-compatible data directory" mkdir -p "$pg_data_dir"
    run_cmd "setting PostgreSQL pgdata ownership recursively" chown -R "${expected_uid}:${expected_gid}" "$pg_data_dir"
    run_cmd "setting PostgreSQL pgdata directory permissions" find "$pg_data_dir" -type d -exec chmod 700 {} +
    run_cmd "setting PostgreSQL pgdata file permissions" find "$pg_data_dir" -type f -exec chmod 600 {} +
    run_cmd "setting PostgreSQL pgdata root mode" chmod 700 "$pg_data_dir"

    ensure_postgres_stack_started
    wait_for_postgres_ready

    for dep in temporal postiz authentik-server authentik-worker; do
        if printf '%s' "$running_deps" | grep -qx "$dep"; then
            docker_cmd start "$dep" >/dev/null 2>&1 || true
            POSTGRES_DEPENDENTS_STATUS="restarted"
        fi
    done
}

function verify_postgres_pgdata_permissions() {
    local pg_data_dir="${DOCKER_DIR}/appdata/postgres/pgdata"
    local bad=""
    local container_pgdata=""
    local owner_spec=""
    local group_spec=""
    local expected_owner=""

    if ! docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx 'postgres'; then
        msg_error "PostgreSQL container is not running. Fix PostgreSQL before Authentik automation."
    fi

    expected_owner="$(postgres_container_process_owner 2>/dev/null || true)"
    if [ -z "$expected_owner" ]; then
        msg_error "Unable to determine PostgreSQL process owner from the postgres container."
    fi

    owner_spec="${expected_owner%%:*}"
    group_spec="${expected_owner##*:}"
    container_pgdata="$(postgres_container_pgdata_path 2>/dev/null || true)"
    if [ -z "$container_pgdata" ]; then
        container_pgdata="/var/lib/postgresql/data"
    fi

    bad="$(docker_cmd exec postgres sh -lc '
expected_uid="$(id -u postgres)"
expected_gid="$(id -g postgres)"
pgdata="${PGDATA:-/var/lib/postgresql/data}"
find "$pgdata" \( ! -uid "$expected_uid" -o ! -gid "$expected_gid" -o -type d ! -perm 700 -o -type f ! -perm 600 \) -printf "%u:%g %m %p\n" | head -30' 2>/dev/null || true)"

    if [ -n "$bad" ]; then
        msg_info "Repairing PostgreSQL pgdata permissions"
        repair_postgres_pgdata_permissions

        bad="$(docker_cmd exec postgres sh -lc '
expected_uid="$(id -u postgres)"
expected_gid="$(id -g postgres)"
pgdata="${PGDATA:-/var/lib/postgresql/data}"
find "$pgdata" \( ! -uid "$expected_uid" -o ! -gid "$expected_gid" -o -type d ! -perm 700 -o -type f ! -perm 600 \) -printf "%u:%g %m %p\n" | head -30' 2>/dev/null || true)"

        if [ -n "$bad" ]; then
            echo -e "${YW}PostgreSQL pgdata repair failed. Remaining container-side offenders:${CL}"
            printf '%s\n' "$bad"
            echo -e "${YW}Expected PostgreSQL UID:GID inside container:${CL} ${owner_spec}:${group_spec}"
            echo -e "${YW}PostgreSQL container PGDATA path:${CL} ${container_pgdata}"
            echo -e "${YW}Host PostgreSQL pgdata path:${CL} ${pg_data_dir}"
            msg_error "PostgreSQL pgdata still contains container-side ownership/permission offenders after repair. Refusing to deploy dependants."
        fi
        clear_transient_line
    fi

    POSTGRES_PERMISSIONS_STATUS="ready"
}

function repair_redis_data_permissions() {
    local redis_data_dir="${DOCKER_DIR}/appdata/redis"
    local redis_owner=""

    redis_owner="$(redis_data_owner)"

    run_cmd "creating Redis data directory" mkdir -p "$redis_data_dir"
    run_cmd "setting Redis data ownership recursively" chown -R "$redis_owner" "$redis_data_dir"
    run_cmd "setting Redis data permissions recursively" chmod -R u+rwX,g+rwX,o-rwx "$redis_data_dir"
    run_cmd "setting Redis data root mode" chmod 770 "$redis_data_dir"
}

function verify_redis_data_permissions() {
    local redis_data_dir="${DOCKER_DIR}/appdata/redis"
    local redis_owner=""
    local redis_uid=""
    local redis_gid=""
    local bad=""

    redis_owner="$(redis_data_owner)"
    redis_uid="${redis_owner%%:*}"
    redis_gid="${redis_owner##*:}"

    if [ -n "$SUDO_CMD" ]; then
        bad="$($SUDO_CMD find "$redis_data_dir" \( ! -uid "$redis_uid" -o ! -gid "$redis_gid" \) -printf '%u:%g %m %p\n' 2>/dev/null | head -20 || true)"
    else
        bad="$(find "$redis_data_dir" \( ! -uid "$redis_uid" -o ! -gid "$redis_gid" \) -printf '%u:%g %m %p\n' 2>/dev/null | head -20 || true)"
    fi

    if [ -n "$bad" ]; then
        echo -e "${YW}Redis permission offenders:${CL}"
        printf '%s\n' "$bad"
        msg_error "Redis data path still contains files not owned by ${redis_owner}. Refusing to continue."
    fi
}
function prepare_postgres_runtime_prereqs() {
    if ! selected_stack_contains "$POSTGRES_STACK_FILE"; then
        return 0
    fi

    apply_group_heading "Prerequisites"

    local pg_root_dir="${DOCKER_DIR}/appdata/postgres"
    local pg_data_dir="${pg_root_dir}/pgdata"
    local pg_init_dir="${pg_root_dir}/init"

    require_nonempty_env_value "POSTGRES_PASSWORD"
    require_nonempty_env_value "AUTHENTIK_POSTGRES_PASSWORD"
    require_nonempty_env_value "POSTIZ_POSTGRES_PASSWORD"
    require_nonempty_env_value "TEMPORAL_POSTGRES_PASSWORD"

    run_cmd "creating PostgreSQL data directory" mkdir -p "$pg_data_dir"
    run_cmd "creating PostgreSQL init directory" mkdir -p "$pg_init_dir"
    repair_postgres_pgdata_permissions
    verify_postgres_pgdata_permissions
    run_cmd "setting PostgreSQL init directory readability" chmod 755 "$pg_init_dir"

    apply_line "Secrets" "ready"
    apply_line "PostgreSQL" "ready"

    if docker_cmd inspect postgres --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' 2>/dev/null | grep -Eq 'restarting|unhealthy|exited|dead'; then
        msg_info "Existing PostgreSQL container is stale/unhealthy; removing container only, keeping data"
        docker_cmd rm -f postgres >/dev/null 2>&1 || true
        clear_transient_line
        msg_warn "Stale PostgreSQL container removed; data kept"
    fi
}

function prepare_redis_runtime_prereqs() {
    if ! selected_stack_contains "$REDIS_STACK_FILE"; then
        return 0
    fi

    apply_group_heading "Prerequisites"

    local redis_data_dir="${DOCKER_DIR}/appdata/redis"

    run_cmd "creating Redis data directory" mkdir -p "$redis_data_dir"
    repair_redis_data_permissions
    verify_redis_data_permissions

    REDIS_PERMISSIONS_STATUS="ready"
    apply_line "Redis" "ready"
}

function require_nonempty_env_value() {
    local key="$1"
    local value=""

    value="$(env_value "$key")"

    if [ -z "$value" ]; then
        msg_error "Required .env value ${key} is missing or empty. Run fixed Script 6 before deployment."
    fi

    return 0
}

function show_postgres_diagnostics() {
    echo ""
    echo -e "${YW}PostgreSQL diagnostics:${CL}"
    docker_cmd ps -a --filter "name=postgres" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
    docker_cmd inspect postgres --format 'status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}} exit={{.State.ExitCode}} restart_count={{.RestartCount}} oom={{.State.OOMKilled}} error={{.State.Error}}' 2>/dev/null || true
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" stat -c 'path=%n owner=%u:%g mode=%a type=%F' "${DOCKER_DIR}/appdata/postgres" "${DOCKER_DIR}/appdata/postgres/pgdata" "${DOCKER_DIR}/appdata/postgres/init" 2>/dev/null || true
    else
        stat -c 'path=%n owner=%u:%g mode=%a type=%F' "${DOCKER_DIR}/appdata/postgres" "${DOCKER_DIR}/appdata/postgres/pgdata" "${DOCKER_DIR}/appdata/postgres/init" 2>/dev/null || true
    fi
    docker_cmd logs --tail=160 postgres 2>/dev/null || true
}

function wait_for_postgres_ready() {
    local attempt=""
    local max_attempts="150"
    local container_status=""
    local health_status=""
    local restart_count=""

    for attempt in $(seq 1 "$max_attempts"); do
        container_status="$(docker_cmd inspect postgres --format '{{.State.Status}}' 2>/dev/null || true)"
        health_status="$(docker_cmd inspect postgres --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' 2>/dev/null || true)"
        restart_count="$(docker_cmd inspect postgres --format '{{.RestartCount}}' 2>/dev/null || true)"

        if [ "$container_status" == "running" ] && [ "$health_status" == "healthy" ]; then
            clear_transient_line
            return 0
        fi

        if [ "$container_status" == "restarting" ] && [ "${restart_count:-0}" -ge 1 ]; then
            clear_transient_line
            msg_warn "PostgreSQL container is restarting instead of starting cleanly."
            show_postgres_diagnostics
            msg_error "PostgreSQL is in a restart loop. Fix data directory permission/init/existing-data issue before continuing."
        fi

        if [ "$attempt" -eq 1 ] || [ $((attempt % 15)) -eq 0 ]; then
            tty_print "${BFR}${YW}PostgreSQL not ready yet (${attempt}/${max_attempts}) | status=${container_status:-missing} health=${health_status:-none} restart_count=${restart_count:-unknown}${CL}"
        fi

        sleep 2
    done

    clear_transient_line
    show_postgres_diagnostics
    msg_error "PostgreSQL did not become healthy before dependent stacks."
}

function verify_redis_persistence_ready() {
    if ! selected_stack_contains "$REDIS_STACK_FILE"; then
        return 0
    fi

    local attempt=""
    local max_attempts="60"
    local state=""
    local info=""
    local bgsave_status=""
    local bgsave_in_progress=""

    for attempt in $(seq 1 "$max_attempts"); do
        state="$(docker_cmd inspect redis --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || true)"
        if [ "$state" == "healthy" ] || [ "$state" == "running" ]; then
            break
        fi
        tty_print "${BFR}${YW}Redis not ready yet (${attempt}/${max_attempts}) | state=${state:-missing}${CL}"
        sleep 2
    done
    clear_transient_line

    repair_redis_data_permissions
    verify_redis_data_permissions

    if ! docker_cmd exec redis redis-cli BGSAVE >/dev/null 2>&1; then
        docker_cmd logs --tail=120 redis 2>/dev/null || true
        msg_error "Redis BGSAVE failed. Fix ${DOCKER_DIR}/appdata/redis ownership/permissions before continuing."
    fi

    for attempt in $(seq 1 30); do
        info="$(docker_cmd exec redis redis-cli INFO persistence 2>/dev/null || true)"
        bgsave_in_progress="$(printf '%s\n' "$info" | awk -F: '/^rdb_bgsave_in_progress:/ {gsub(/\r/,"",$2); print $2; exit}')"
        bgsave_status="$(printf '%s\n' "$info" | awk -F: '/^rdb_last_bgsave_status:/ {gsub(/\r/,"",$2); print $2; exit}')"

        if [ "$bgsave_in_progress" == "0" ] && [ "$bgsave_status" == "ok" ]; then
            return 0
        fi

        sleep 1
    done

    docker_cmd exec redis redis-cli INFO persistence 2>/dev/null || true
    docker_cmd logs --tail=120 redis 2>/dev/null || true
    msg_error "Redis persistence did not report rdb_last_bgsave_status:ok after BGSAVE. Fix ${DOCKER_DIR}/appdata/redis before continuing."
}

function wait_for_temporal_ready() {
    if ! selected_stack_contains "$TEMPORAL_STACK_FILE"; then
        return 0
    fi

    local temporal_address="${TEMPORAL_ADDRESS:-temporal:7233}"
    local temporal_namespace="${TEMPORAL_NAMESPACE:-default}"
    local temporal_admin_tools_image=""
    local attempt=""
    local max_attempts="150"
    local err_file=""

    temporal_admin_tools_image="$(env_value TEMPORAL_ADMIN_TOOLS_IMAGE)"
    [ -z "$temporal_admin_tools_image" ] && temporal_admin_tools_image="temporalio/admin-tools:latest"

    err_file="$(mktemp)"
    TEMP_FILES+=("$err_file")

    for attempt in $(seq 1 "$max_attempts"); do
        if docker_cmd run --rm --network database "$temporal_admin_tools_image" \
            temporal --address "$temporal_address" --namespace "$temporal_namespace" \
            operator search-attribute list >/dev/null 2>"$err_file"; then
            clear_transient_line
            return 0
        fi

        if [ "$attempt" -eq 1 ] || [ $((attempt % 15)) -eq 0 ]; then
            tty_print "${BFR}${YW}Temporal API not ready yet (${attempt}/${max_attempts}). Waiting before Postiz Temporal Guard...${CL}"
        fi

        sleep 2
    done

    echo -e "${RD}Last Temporal CLI error:${CL}"
    cat "$err_file" 2>/dev/null || true
    docker_cmd logs --tail=160 temporal 2>/dev/null || true
    docker_cmd logs --tail=100 postgres 2>/dev/null || true
    msg_error "Temporal is not reachable on ${temporal_address}. Fix Temporal/PostgreSQL before running Postiz Temporal Guard."
}

function dockge_stack_dir_name_for_file() {
    local file="$1"

    case "$file" in
        "$SOCKET_PROXY_STACK_FILE") echo "socket-proxy" ;;
        "$DOCKGE_STACK_FILE") echo "dockge" ;;
        "$DOCKHAND_STACK_FILE") echo "dockhand" ;;
        "$KOMODO_STACK_FILE") echo "komodo" ;;
        "$PORTAINER_STACK_FILE") echo "portainer" ;;
        "$POSTGRES_STACK_FILE") echo "postgres" ;;
        "$REDIS_STACK_FILE") echo "redis" ;;
        "$TRAEFIK_STACK_FILE") echo "traefik" ;;
        "$AUTHENTIK_STACK_FILE") echo "authentik" ;;
        "$TEMPORAL_STACK_FILE") echo "temporal" ;;
        "$POSTIZ_TEMPORAL_GUARD_STACK_FILE") echo "postiz-temporal-guard" ;;
        "$POSTIZ_STACK_FILE") echo "postiz" ;;
        "$CF_DDNS_STACK_FILE") echo "cf-ddns" ;;
        "$CF_COMPANION_STACK_FILE") echo "cf-companion" ;;
        "$VSCODE_STACK_FILE") echo "vscode" ;;
        "$FILEBROWSER_STACK_FILE") echo "filebrowser" ;;
        *) echo "${file%.yml}" | sed -E 's/^[0-9]+-//' ;;
    esac
}


function safe_install_file_with_backup() {
    local source_path="$1"
    local target_file="$2"
    local label="${3:-file}"
    local backup_file=""
    local timestamp=""

    [ -s "$source_path" ] || msg_error "Safe write source is missing or empty for ${label}: ${source_path}"

    if root_path_exists "$target_file"; then
        if { [ -n "$SUDO_CMD" ] && "$SUDO_CMD" cmp -s "$source_path" "$target_file"; } || { [ -z "$SUDO_CMD" ] && cmp -s "$source_path" "$target_file"; }; then
            SAFE_WRITE_UNCHANGED_COUNT=$(( SAFE_WRITE_UNCHANGED_COUNT + 1 ))
            if [ "$COMPOSE_PROGRESS_ACTIVE" != "yes" ]; then
                msg_ok "unchanged ${label}: ${target_file}"
            fi
            return 0
        fi

        timestamp="$(date +%Y%m%d-%H%M%S)"
        backup_file="${target_file}.bak-${timestamp}"
        run_cmd "backing up existing ${label}" cp "$target_file" "$backup_file"
        run_cmd "writing updated ${label}" cp "$source_path" "$target_file"
        SAFE_WRITE_BACKUP_COUNT=$(( SAFE_WRITE_BACKUP_COUNT + 1 ))
        SAFE_WRITE_UPDATED_COUNT=$(( SAFE_WRITE_UPDATED_COUNT + 1 ))
        if [ "$COMPOSE_PROGRESS_ACTIVE" != "yes" ]; then
            msg_ok "updated with backup: ${backup_file}"
        fi
    else
        run_cmd "writing new ${label}" cp "$source_path" "$target_file"
        SAFE_WRITE_CREATED_COUNT=$(( SAFE_WRITE_CREATED_COUNT + 1 ))
        if [ "$COMPOSE_PROGRESS_ACTIVE" != "yes" ]; then
            msg_ok "created ${label}: ${target_file}"
        fi
    fi
}

function sync_compose_file_for_dockge() {
    local file="$1"
    local source_path="$2"
    local stack_dir=""
    local target_dir=""
    local target_file=""

    if [ "$ADMIN_UI" != "dockge" ]; then
        return 0
    fi

    stack_dir="$(dockge_stack_dir_name_for_file "$file")"
    target_dir="${COMPOSE_DIR}/${stack_dir}"
    target_file="${target_dir}/compose.yaml"

    run_cmd "creating Dockge stack folder ${stack_dir}" mkdir -p "$target_dir"
    safe_install_file_with_backup "$source_path" "$target_file" "Dockge compose ${stack_dir}"
    run_cmd "setting Dockge compose ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$target_file"
    run_cmd "setting Dockge compose permissions" chmod 640 "$target_file"
    if [ "$COMPOSE_PROGRESS_ACTIVE" != "yes" ]; then
        msg_ok "Dockge compose ready: ${target_file}"
    fi
}

function sync_bootstrap_override_for_dockge() {
    local primary_file="$1"
    local source_path="$2"
    local stack_dir=""
    local target_dir=""
    local target_file=""

    if [ "$ADMIN_UI" != "dockge" ]; then
        return 0
    fi

    stack_dir="$(dockge_stack_dir_name_for_file "$primary_file")"
    target_dir="${COMPOSE_DIR}/${stack_dir}"
    target_file="${target_dir}/bootstrap-override.yaml"

    run_cmd "creating Dockge stack folder ${stack_dir}" mkdir -p "$target_dir"
    safe_install_file_with_backup "$source_path" "$target_file" "Dockge bootstrap override ${stack_dir}"
    run_cmd "setting Dockge bootstrap override ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$target_file"
    run_cmd "setting Dockge bootstrap override permissions" chmod 640 "$target_file"
}


# --- 33I.1. COMPOSE PATH RESOLUTION HELPERS ---
# When Dockge is the selected admin UI, Script 6.5 deploys from the same
# ${DOCKER_DIR}/compose/<stack>/compose.yaml layout that Dockge displays.
# The flat downloaded filename remains as a fallback and source file.
function compose_path_for_stack_file() {
    local file="$1"
    local stack_dir=""
    local dockge_path=""

    if [ "$ADMIN_UI" == "dockge" ]; then
        stack_dir="$(dockge_stack_dir_name_for_file "$file")"
        dockge_path="${COMPOSE_DIR}/${stack_dir}/compose.yaml"
        if [ -f "$dockge_path" ]; then
            printf '%s' "$dockge_path"
            return 0
        fi
    fi

    printf '%s' "${COMPOSE_DIR}/${file}"
}

function bootstrap_override_path_for_primary_file() {
    local primary_file="$1"
    local stack_dir=""
    local dockge_path=""

    if [ "$ADMIN_UI" == "dockge" ]; then
        stack_dir="$(dockge_stack_dir_name_for_file "$primary_file")"
        dockge_path="${COMPOSE_DIR}/${stack_dir}/bootstrap-override.yaml"
        if [ -f "$dockge_path" ]; then
            printf '%s' "$dockge_path"
            return 0
        fi
    fi

    printf '%s' "$ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE"
}

function primary_stack_for_bootstrap_override() {
    local file="$1"

    case "$file" in
        "$DOCKGE_BOOTSTRAP_OVERRIDE_FILE_NAME") echo "$DOCKGE_STACK_FILE" ;;
        "$PORTAINER_BOOTSTRAP_OVERRIDE_FILE_NAME") echo "$PORTAINER_STACK_FILE" ;;
        "$KOMODO_BOOTSTRAP_OVERRIDE_FILE_NAME") echo "$KOMODO_STACK_FILE" ;;
        "$DOCKHAND_BOOTSTRAP_OVERRIDE_FILE_NAME") echo "$DOCKHAND_STACK_FILE" ;;
        *) echo "" ;;
    esac
}


# --- 33H. STACK REGISTRY HELPERS ---
# Uses the fixed uploaded project structure. No GitHub scanning is performed.
function stack_project_for_file() {
    local file="$1"
    case "$file" in
        "$POSTGRES_STACK_FILE") echo "postgres" ;;
        "$REDIS_STACK_FILE") echo "redis" ;;
        "$TRAEFIK_STACK_FILE") echo "traefik" ;;
        "$AUTHENTIK_STACK_FILE") echo "authentik" ;;
        "$TEMPORAL_STACK_FILE") echo "temporal" ;;
        "$POSTIZ_TEMPORAL_GUARD_STACK_FILE") echo "postiz-temporal-guard" ;;
        "$POSTIZ_STACK_FILE") echo "postiz" ;;
        "$CF_DDNS_STACK_FILE") echo "cf-ddns" ;;
        "$CF_COMPANION_STACK_FILE") echo "cf-companion" ;;
        "$VSCODE_STACK_FILE") echo "vscode" ;;
        "$FILEBROWSER_STACK_FILE") echo "filebrowser" ;;
        *) echo "${file%.yml}" | tr '[:upper:]' '[:lower:]' ;;
    esac
}

function stack_primary_service_for_file() {
    local file="$1"
    case "$file" in
        "$POSTGRES_STACK_FILE") echo "postgres" ;;
        "$REDIS_STACK_FILE") echo "redis" ;;
        "$TRAEFIK_STACK_FILE") echo "traefik" ;;
        "$AUTHENTIK_STACK_FILE") echo "authentik-server" ;;
        "$TEMPORAL_STACK_FILE") echo "temporal" ;;
        "$POSTIZ_TEMPORAL_GUARD_STACK_FILE") echo "postiz-temporal-guard" ;;
        "$POSTIZ_STACK_FILE") echo "postiz" ;;
        "$CF_DDNS_STACK_FILE") echo "cf-ddns" ;;
        "$CF_COMPANION_STACK_FILE") echo "cf-companion" ;;
        "$VSCODE_STACK_FILE") echo "vscode" ;;
        "$FILEBROWSER_STACK_FILE") echo "filebrowser" ;;
        *) echo "" ;;
    esac
}

function add_selected_stack_once() {
    local file="$1"
    local reason="$2"
    local existing=""

    for existing in "${SELECTED_STACK_FILES[@]}"; do
        [ "$existing" == "$file" ] && return 0
    done

    SELECTED_STACK_FILES+=("$file")
    SELECTED_STACK_PROJECTS+=("$(stack_project_for_file "$file")")
    SELECTED_STACK_SERVICES+=("$(stack_primary_service_for_file "$file")")
    DEPENDENCY_REASONS+=("$reason")
}

function add_authentik_routing_dependencies() {
    local source_reason="$1"

    add_selected_stack_once "$POSTGRES_STACK_FILE" "PostgreSQL auto-selected because ${source_reason} requires Authentik/database-backed SSO."
    add_selected_stack_once "$REDIS_STACK_FILE" "Redis auto-selected because ${source_reason} requires Authentik cache/session storage."
    add_selected_stack_once "$TRAEFIK_STACK_FILE" "Traefik auto-selected because ${source_reason} requires HTTPS routing."
    add_selected_stack_once "$AUTHENTIK_STACK_FILE" "Authentik auto-selected because ${source_reason} is protected by file-provider forward-auth."
}

function add_traefik_only_dependency() {
    local source_reason="$1"
    add_selected_stack_once "$TRAEFIK_STACK_FILE" "Traefik auto-selected because ${source_reason} requires Traefik routing/labels."
}

function _readd_selected_stack_by_file() {
    local wanted="$1"
    local i=""

    for i in "${!SELECTED_STACK_FILES[@]}"; do
        if [ "${SELECTED_STACK_FILES[$i]}" == "$wanted" ]; then
            _ORDERED_STACK_FILES+=("${SELECTED_STACK_FILES[$i]}")
            _ORDERED_STACK_PROJECTS+=("${SELECTED_STACK_PROJECTS[$i]}")
            _ORDERED_STACK_SERVICES+=("${SELECTED_STACK_SERVICES[$i]}")
            _ORDERED_DEPENDENCY_REASONS+=("${DEPENDENCY_REASONS[$i]}")
            return 0
        fi
    done
}

function reorder_cloudflare_stacks_last() {
    local i=""
    local file=""
    local ordered_files=()
    local ordered_projects=()
    local ordered_services=()
    local ordered_reasons=()

    _ORDERED_STACK_FILES=()
    _ORDERED_STACK_PROJECTS=()
    _ORDERED_STACK_SERVICES=()
    _ORDERED_DEPENDENCY_REASONS=()

    for i in "${!SELECTED_STACK_FILES[@]}"; do
        file="${SELECTED_STACK_FILES[$i]}"
        case "$file" in
            "$CF_DDNS_STACK_FILE"|"$CF_COMPANION_STACK_FILE")
                ;;
            *)
                _ORDERED_STACK_FILES+=("${SELECTED_STACK_FILES[$i]}")
                _ORDERED_STACK_PROJECTS+=("${SELECTED_STACK_PROJECTS[$i]}")
                _ORDERED_STACK_SERVICES+=("${SELECTED_STACK_SERVICES[$i]}")
                _ORDERED_DEPENDENCY_REASONS+=("${DEPENDENCY_REASONS[$i]}")
                ;;
        esac
    done

    _readd_selected_stack_by_file "$CF_DDNS_STACK_FILE"
    _readd_selected_stack_by_file "$CF_COMPANION_STACK_FILE"

    SELECTED_STACK_FILES=("${_ORDERED_STACK_FILES[@]}")
    SELECTED_STACK_PROJECTS=("${_ORDERED_STACK_PROJECTS[@]}")
    SELECTED_STACK_SERVICES=("${_ORDERED_STACK_SERVICES[@]}")
    DEPENDENCY_REASONS=("${_ORDERED_DEPENDENCY_REASONS[@]}")

    unset _ORDERED_STACK_FILES _ORDERED_STACK_PROJECTS _ORDERED_STACK_SERVICES _ORDERED_DEPENDENCY_REASONS
}

# --- 33I. STACK DEPLOYMENT CHOICE COLLECTION ---
# Collects all deployment choices before any compose files, networks or containers are changed.
function collect_stack_deployment_choices() {
    local question_lines="0"

    group_heading "Required"
    setup_option_line "Socket proxy" "selected"
    setup_option_line "Admin UI" "${ADMIN_UI_DISPLAY_NAME} with temporary bootstrap access"
    echo ""

    group_heading "Stack choices"
    question_lines=$((question_lines + 1))

    DEPLOY_POSTIZ="$(timed_yes_no_keep_visible "Deploy Postiz social media stack?" "y")"
    question_lines=$((question_lines + 1))
    if [[ "$DEPLOY_POSTIZ" =~ ^[Yy] ]]; then
        add_selected_stack_once "$POSTGRES_STACK_FILE" "PostgreSQL auto-selected because Authentik, Temporal and Postiz need database storage."
        add_selected_stack_once "$REDIS_STACK_FILE" "Redis auto-selected because Authentik and Postiz need cache/session storage."
        add_selected_stack_once "$TRAEFIK_STACK_FILE" "Traefik auto-selected because public HTTPS routing is required."
        add_selected_stack_once "$AUTHENTIK_STACK_FILE" "Authentik auto-selected because SSO/front-door protection is required."
        add_selected_stack_once "$TEMPORAL_STACK_FILE" "Temporal auto-selected because Postiz requires workflow orchestration."
        add_selected_stack_once "$POSTIZ_TEMPORAL_GUARD_STACK_FILE" "Postiz Temporal Guard auto-selected because Postiz can crash if Temporal Text attributes remain."
        add_selected_stack_once "$POSTIZ_STACK_FILE" "Postiz selected by user."
    fi

    DEPLOY_CF_DDNS="$(timed_yes_no_keep_visible "Deploy Cloudflare DDNS stack?" "y")"
    question_lines=$((question_lines + 1))
    [[ "$DEPLOY_CF_DDNS" =~ ^[Yy] ]] && add_selected_stack_once "$CF_DDNS_STACK_FILE" "Cloudflare DDNS selected by user."

    DEPLOY_CF_COMPANION="$(timed_yes_no_keep_visible "Deploy Cloudflare Companion DNS automation stack?" "y")"
    question_lines=$((question_lines + 1))
    if [[ "$DEPLOY_CF_COMPANION" =~ ^[Yy] ]]; then
        add_traefik_only_dependency "Cloudflare Companion"
        add_selected_stack_once "$CF_COMPANION_STACK_FILE" "Cloudflare Companion selected by user for Traefik label-driven DNS automation."
    fi

    DEPLOY_VSCODE="$(timed_yes_no_keep_visible "Deploy VS Code server utility stack?" "y")"
    question_lines=$((question_lines + 1))
    if [[ "$DEPLOY_VSCODE" =~ ^[Yy] ]]; then
        add_authentik_routing_dependencies "VS Code"
        add_selected_stack_once "$VSCODE_STACK_FILE" "VS Code utility stack selected by user."
    fi

    DEPLOY_FILEBROWSER="$(timed_yes_no_keep_visible "Deploy Filebrowser utility stack?" "n")"
    question_lines=$((question_lines + 1))
    if [[ "$DEPLOY_FILEBROWSER" =~ ^[Yy] ]]; then
        add_authentik_routing_dependencies "Filebrowser"
        add_selected_stack_once "$FILEBROWSER_STACK_FILE" "Filebrowser utility stack selected by user."
    fi

    reorder_cloudflare_stacks_last
    clear_terminal_lines "$question_lines"
    group_heading "Stack choices"
    stack_choice_summary
    echo ""
}

# --- 33J. SELECTED STACK PREFLIGHTS ---
# Performs permission and secret checks for the selected plan before SETUP PLAN.
function verify_selected_stack_preflight() {
    require_route_host_value "ADMIN_UI_HOST" "$ADMIN_UI_HOST"
    require_route_host_value "AUTHENTIK_ROUTE_HOST" "$AUTHENTIK_ROUTE_HOST"

    if [[ "$DEPLOY_VSCODE" =~ ^[Yy] ]]; then
        require_route_host_value "VSCODE_HOST" "$VSCODE_HOST"
    fi

    if [[ "$DEPLOY_FILEBROWSER" =~ ^[Yy] ]]; then
        require_route_host_value "FILEBROWSER_HOST" "$FILEBROWSER_HOST"
    fi

    validate_required_secret_files

    if selected_stack_contains "$TRAEFIK_STACK_FILE"; then
        validate_traefik_config_files_predeploy
    fi

    if [[ "$DEPLOY_POSTIZ" =~ ^[Yy] ]]; then
        verify_redis_host_tuning
        verify_traefik_rendered_configs
        verify_authentik_folders
        verify_authentik_smtp_env
    fi

    if [[ "$DEPLOY_CF_COMPANION" =~ ^[Yy] ]]; then
        validate_cf_companion_predeploy
        verify_cf_companion_secret_file
    else
        CF_COMPANION_SECRET_OK="skipped"
    fi

    if [[ "$DEPLOY_FILEBROWSER" =~ ^[Yy] ]]; then
        verify_filebrowser_folders
    else
        FILEBROWSER_FOLDERS_OK="skipped"
    fi

    group_heading "Readiness"
    readiness_status_summary
    echo ""
}

# --- 33K. COMPOSE ENV VARIABLE COVERAGE CHECK ---
# Checks selected compose files for required ${VARIABLE} references without fallbacks.
function verify_compose_env_coverage_for_file() {
    local file="$1"
    local path=""

    path="$(compose_path_for_stack_file "$file")"
    local missing="no"
    local token=""
    local var=""

    [ -f "$path" ] || msg_error "Compose file missing for env coverage check: ${path}"

    while IFS= read -r token; do
        # Convert a compose token like ${DOCKER_DIR} or ${POSTIZ_IMAGE:-image:latest}
        # into a safe variable name before indirect expansion. This prevents Bash from
        # treating malformed leftovers such as DOCKER_DIR}} as an indirect variable name.
        var="${token#\$\{}"
        var="${var%\}}"

        # Skip variables with compose/default fallbacks because they are not mandatory.
        if [[ "$var" == *:-* ]] || [[ "$var" == *-* ]]; then
            continue
        fi

        # Ignore variables intentionally escaped for container-side shell scripts, e.g. $${i} in one-shot guards.
        [ "$var" == "i" ] && continue

        # Defensive guard before ${!var}; indirect expansion requires a valid shell variable name.
        if ! [[ "$var" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            continue
        fi

        if ! grep -qE "^${var}=" "$ENV_FILE" && [ -z "${!var:-}" ]; then
            echo -e "${RD}Missing variable for ${file}:${CL} ${var}"
            missing="yes"
        fi
    done < <(grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*(:-[^}]*)?\}' "$path" | sort -u || true)

    [ "$missing" == "no" ] || msg_error "Compose variable coverage failed for ${file}. Run fixed Script 6 first."
}

function verify_selected_compose_env_coverage() {
    apply_group_heading "Compose validation"
    local file=""

    verify_compose_env_coverage_for_file "$SOCKET_PROXY_STACK_FILE"
    verify_compose_env_coverage_for_file "$(basename "$ADMIN_UI_COMPOSE_FILE")"

    for file in "${SELECTED_STACK_FILES[@]}"; do
        verify_compose_env_coverage_for_file "$file"
    done

    COMPOSE_VALIDATION_STATUS="valid"
    apply_line "Environment" "valid"
}

function normalize_compose_for_wildcard_tls() {
    local target="$1"
    local file="$2"

    [ -n "$target" ] || return 0
    [ -n "$file" ] || return 0

    # No-op by design. Wildcard TLS and route host correctness now belong in
    # the checked-in compose templates, not in brittle post-download YAML edits.
    return 0
}

function download_fixed_stack_file() {
    local file="$1"
    local target="${COMPOSE_DIR}/${file}"
    local url="${GITHUB_RAW_BASE}/${file}"
    local primary_for_override=""
    local tmp_download=""
    local project_label=""

    project_label="$(stack_project_for_file "$file")"
    [ -z "$project_label" ] && project_label="${file%.yml}"
    compose_progress_summary "downloading ${project_label}"

    tmp_download="$(mktemp)"
    TEMP_FILES+=("$tmp_download")

    curl --globoff -fsSL "$url" -o "$tmp_download" || msg_error "Failed to download ${url}"
    [ -s "$tmp_download" ] || msg_error "Downloaded file is empty: ${url}"
    if grep -q "authentik@""docker" "$tmp_download"; then
        msg_error "Forbidden stale Authentik Docker-provider middleware reference found in ${file}."
    fi
    normalize_compose_for_wildcard_tls "$tmp_download" "$file"

    compose_progress_summary "installing ${project_label}"
    safe_install_file_with_backup "$tmp_download" "$target" "compose ${file}"
    run_cmd "setting compose file ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$target"
    run_cmd "setting compose file permissions" chmod 640 "$target"

    primary_for_override="$(primary_stack_for_bootstrap_override "$file")"
    if [ -n "$primary_for_override" ]; then
        sync_bootstrap_override_for_dockge "$primary_for_override" "$target"
    else
        sync_compose_file_for_dockge "$file" "$target"
    fi
}

function download_selected_compose_files() {
    apply_group_heading "Compose files"
    local file=""

    COMPOSE_PROGRESS_ACTIVE="yes"
    compose_progress_summary "starting"

    download_fixed_stack_file "$SOCKET_PROXY_STACK_FILE"
    download_fixed_stack_file "$(basename "$ADMIN_UI_COMPOSE_FILE")"
    download_fixed_stack_file "$ADMIN_UI_BOOTSTRAP_OVERRIDE_NAME"

    for file in "${SELECTED_STACK_FILES[@]}"; do
        download_fixed_stack_file "$file"
    done

    SOCKET_PROXY_STACK_DOWNLOADED="yes"
    ADMIN_UI_BOOTSTRAP_OVERRIDE_WRITTEN="downloaded"
    COMPOSE_PROGRESS_ACTIVE="no"
    apply_compose_summary
}

function validate_selected_compose_files() {
    apply_group_heading "Compose validation"
    local i=""
    local file=""
    local project=""

    export DOCKER_DIR COMPOSE_DIR ENV_FILE PORTAINER_BOOTSTRAP_PORT DOCKGE_BOOTSTRAP_PORT KOMODO_BOOTSTRAP_PORT DOCKHAND_BOOTSTRAP_PORT ADMIN_UI_BOOTSTRAP_BIND ADMIN_UI_HOST ADMIN_UI_URL AUTHENTIK_ROUTE_HOST AUTHENTIK_EXTERNAL_URL VSCODE_HOST FILEBROWSER_HOST

    msg_info "Validating selected compose files"
    run_docker_cmd "validating Socket Proxy stack compose" compose --env-file "$ENV_FILE" -p socket-proxy -f "$(compose_path_for_stack_file "$SOCKET_PROXY_STACK_FILE")" config -q
    run_docker_cmd "validating ${ADMIN_UI_DISPLAY_NAME} stack compose" compose --env-file "$ENV_FILE" -p "$ADMIN_UI_PROJECT_NAME" -f "$(compose_path_for_stack_file "$(basename "$ADMIN_UI_COMPOSE_FILE")")" -f "$(bootstrap_override_path_for_primary_file "$(basename "$ADMIN_UI_COMPOSE_FILE")")" config -q

    for i in "${!SELECTED_STACK_FILES[@]}"; do
        file="${SELECTED_STACK_FILES[$i]}"
        project="${SELECTED_STACK_PROJECTS[$i]}"
        run_docker_cmd "validating ${file}" compose --env-file "$ENV_FILE" -p "$project" -f "$(compose_path_for_stack_file "$file")" config -q
    done

    clear_transient_line
    ADMIN_UI_VALIDATED="yes"
    COMPOSE_VALIDATION_STATUS="valid"
    apply_line "Stacks" "valid"
}

function deploy_selected_stacks() {
    apply_group_heading "Stack deployment"
    local i=""
    local file=""
    local project=""
    local service=""
    local compose_path=""

    deploy_socket_proxy
    deploy_admin_ui

    for i in "${!SELECTED_STACK_FILES[@]}"; do
        file="${SELECTED_STACK_FILES[$i]}"
        project="${SELECTED_STACK_PROJECTS[$i]}"
        service="${SELECTED_STACK_SERVICES[$i]}"
        compose_path="$(compose_path_for_stack_file "$file")"

        if [ "$file" == "$POSTIZ_TEMPORAL_GUARD_STACK_FILE" ]; then
            run_postiz_temporal_guard_stack "$project" "$file"
            continue
        fi

        compose_up_quiet "deploying ${project}" --env-file "$ENV_FILE" -p "$project" -f "$compose_path"
        apply_line "$project" "deployed"

        if [ -n "$service" ] && ! docker_cmd ps --format '{{.Names}}' | grep -qx "$service"; then
            msg_warn "Container ${service} not confirmed yet. It may still be starting; check docker logs if needed."
        fi

        if [ "$file" == "$POSTGRES_STACK_FILE" ]; then
            wait_for_postgres_ready
        fi

        if [ "$file" == "$REDIS_STACK_FILE" ]; then
            verify_redis_persistence_ready
        fi

        if [ "$file" == "$TEMPORAL_STACK_FILE" ]; then
            wait_for_temporal_ready
        fi
    done
}

function cf_companion_recent_dns_activity() {
    local log_file="$1"

    grep -Eiq 'Found Service ID:.*Hostname|Created new record:|Existing record:|Updated record:' "$log_file"
}

function verify_cf_companion_runtime_if_selected() {
    apply_group_heading "DNS / CF"

    if ! [[ "$DEPLOY_CF_COMPANION" =~ ^[Yy] ]]; then
        CF_COMPANION_RUNTIME_STATUS="not selected"
        CF_COMPANION_RESCAN_STATUS="skipped"
        DNS_RECORDS_STATUS="not selected"
        DNS_WAIT_STATUS="skipped"
        msg_skip "CF-COMPANION RUNTIME CHECK SKIPPED; STACK NOT SELECTED"
        apply_line "CF DDNS" "$(yes_no_label "$DEPLOY_CF_DDNS")" "$(status_color_for_value "$(yes_no_label "$DEPLOY_CF_DDNS")")"
        apply_line "CF Companion" "$CF_COMPANION_RUNTIME_STATUS" "$(status_color_for_value "$CF_COMPANION_RUNTIME_STATUS")"
        apply_line "DNS records" "$DNS_RECORDS_STATUS" "$(status_color_for_value "$DNS_RECORDS_STATUS")"
        apply_line "Rescan" "$CF_COMPANION_RESCAN_STATUS" "$YW"
        apply_line "DNS wait" "$DNS_WAIT_STATUS" "$YW"
        return 0
    fi

    if ! docker_cmd ps --format '{{.Names}}' | grep -qx 'cf-companion'; then
        CF_COMPANION_RUNTIME_STATUS="not ready"
        CF_COMPANION_RESCAN_STATUS="skipped"
        DNS_RECORDS_STATUS="needs review"
        DNS_WAIT_STATUS="skipped"
        msg_warn "cf-companion container is not running yet. Check logs after startup."
        apply_line "CF DDNS" "$(yes_no_label "$DEPLOY_CF_DDNS")" "$(status_color_for_value "$(yes_no_label "$DEPLOY_CF_DDNS")")"
        apply_line "CF Companion" "$CF_COMPANION_RUNTIME_STATUS" "$YW"
        apply_line "DNS records" "$DNS_RECORDS_STATUS" "$YW"
        apply_line "Rescan" "$CF_COMPANION_RESCAN_STATUS" "$YW"
        apply_line "DNS wait" "$DNS_WAIT_STATUS" "$YW"
        return 0
    fi

    if docker_cmd logs cf-companion --tail=120 2>/dev/null | grep -Eiq 'unauthorized|authentication failed|invalid token|missing token|permission denied'; then
        msg_error "Cloudflare Companion logs show authentication/token errors. Verify cf_token secret and API token permissions."
    fi

    CF_COMPANION_RUNTIME_STATUS="running"
    refresh_cf_companion_dns_records
    return 0
}

function refresh_cf_companion_dns_records() {
    apply_group_heading "DNS / CF"

    local cf_log_file=""
    local rescan_needed="yes"
    local warn_lines=""

    if ! docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx 'cf-companion'; then
        CF_COMPANION_RUNTIME_STATUS="not ready"
        CF_COMPANION_RESCAN_STATUS="skipped"
        DNS_RECORDS_STATUS="needs review"
        DNS_WAIT_STATUS="skipped"
        apply_line "CF DDNS" "$(yes_no_label "$DEPLOY_CF_DDNS")" "$(status_color_for_value "$(yes_no_label "$DEPLOY_CF_DDNS")")"
        apply_line "CF Companion" "$CF_COMPANION_RUNTIME_STATUS" "$YW"
        apply_line "DNS records" "$DNS_RECORDS_STATUS" "$YW"
        apply_line "Rescan" "$CF_COMPANION_RESCAN_STATUS" "$YW"
        apply_line "DNS wait" "$DNS_WAIT_STATUS" "$YW"
        return 0
    fi

    cf_log_file="$(mktemp)"
    TEMP_FILES+=("$cf_log_file")
    docker_cmd logs --tail=220 cf-companion 2>/dev/null >"$cf_log_file" || true

    if cf_companion_recent_dns_activity "$cf_log_file"; then
        rescan_needed="no"
        DNS_RECORDS_STATUS="ready"
        CF_COMPANION_RESCAN_STATUS="skipped"
    fi

    if [ "$rescan_needed" == "yes" ]; then
        msg_info "Rescanning cf-companion DNS records"
        docker_cmd restart cf-companion >/dev/null 2>&1 || true
        sleep 12
        clear_transient_line
        docker_cmd logs --tail=220 cf-companion 2>/dev/null >"$cf_log_file" || true
        CF_COMPANION_RESCAN_STATUS="completed"
        if cf_companion_recent_dns_activity "$cf_log_file"; then
            DNS_RECORDS_STATUS="ready"
        else
            DNS_RECORDS_STATUS="needs review"
        fi
    fi

    warn_lines=$(grep -Ei 'error|denied|unauthorized|authentication failed|invalid token|missing token|permission denied' "$cf_log_file" | awk '{ if(length($0) > 140) print substr($0,1,137) "..."; else print }' | sort -u | head -n20 || true)
    [ -n "$warn_lines" ] && DNS_RECORDS_STATUS="needs review"

    msg_info "Waiting briefly before public route checks"
    sleep 20
    clear_transient_line
    DNS_WAIT_STATUS="complete"

    apply_line "CF DDNS" "$(yes_no_label "$DEPLOY_CF_DDNS")" "$(status_color_for_value "$(yes_no_label "$DEPLOY_CF_DDNS")")"
    apply_line "DNS records" "$DNS_RECORDS_STATUS" "$(status_color_for_value "$DNS_RECORDS_STATUS")"
    apply_line "CF Companion" "$CF_COMPANION_RUNTIME_STATUS"
    apply_line "Rescan" "$CF_COMPANION_RESCAN_STATUS" "$(status_color_for_value "$CF_COMPANION_RESCAN_STATUS")"
    apply_line "DNS wait" "$DNS_WAIT_STATUS"
    rm -f "$cf_log_file"
}


# =========================================================
#  AUTHENTIK FORWARD-AUTH SETUP / ROUTE VERIFICATION
# =========================================================

function json_get_first_pk() {
    python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)
items = data.get("results", data if isinstance(data, list) else []) if isinstance(data, (dict, list)) else []
print(items[0].get("pk", "") if items else "")
'
}

function json_get_first_uuid_or_pk() {
    python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)
items = data.get("results", data if isinstance(data, list) else []) if isinstance(data, (dict, list)) else []
print((items[0].get("pk") or items[0].get("uuid") or "") if items else "")
'
}

function json_is_valid_object_or_array() {
    python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
sys.exit(0 if isinstance(data, (dict, list)) else 1)
'
}

function json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))'
}

function verify_authentik_dependencies_for_deploy() {
    apply_group_heading "Protection / Authentik"

    local required="no"
    local check_output=""

    if [[ "$DEPLOY_POSTIZ" =~ ^[Yy] ]] || [[ "$DEPLOY_VSCODE" =~ ^[Yy] ]] || [[ "$DEPLOY_FILEBROWSER" =~ ^[Yy] ]]; then
        required="yes"
    fi

    if [ "$required" != "yes" ]; then
        AUTHENTIK_DEPENDENCIES_OK="skipped"
        msg_skip "AUTHENTIK DEPENDENCY GATE SKIPPED"
        return 0
    fi

    if ! docker_cmd ps --format '{{.Names}}' | grep -qx 'authentik-server'; then
        AUTHENTIK_DEPENDENCIES_OK="authentik-not-running"
        msg_warn "authentik-server is not running; API automation skipped."
        return 0
    fi

    ensure_postgres_stack_started
    ensure_redis_stack_started

    if ! docker_cmd ps --format '{{.Names}}' | grep -qx 'postgres'; then
        msg_error "PostgreSQL container is not running after deployment guard. Fix PostgreSQL before Authentik automation."
    fi

    if ! docker_cmd ps --format '{{.Names}}' | grep -qx 'redis'; then
        msg_error "Redis container is not running after deployment guard. Fix Redis before Authentik automation."
    fi

    repair_postgres_pgdata_permissions
    verify_postgres_pgdata_permissions
    repair_redis_data_permissions
    verify_redis_data_permissions

    verify_redis_persistence_ready

    check_output="$(docker_cmd exec authentik-server sh -lc '
python - <<PY
import socket, sys
failed = False
for host, port in [("postgres", 5432), ("redis", 6379)]:
    try:
        socket.create_connection((host, port), timeout=5).close()
        print(f"OK {host}:{port}")
    except Exception as e:
        print(f"FAIL {host}:{port} {e}")
        failed = True
sys.exit(1 if failed else 0)
PY
' 2>&1)" || {
        echo "$check_output"
        docker_cmd logs --tail=100 postgres 2>/dev/null || true
        docker_cmd logs --tail=100 redis 2>/dev/null || true
        msg_error "authentik-server cannot reach PostgreSQL/Redis. Fix dependency DNS/connectivity before API token setup."
    }

    AUTHENTIK_DEPENDENCIES_OK="yes"
    apply_line "Internal API" "ready"
}


function wait_for_authentik_internal_api_ready() {
    apply_group_heading "Protection / Authentik"

    local attempt=""
    local max_attempts="120"
    local status_output=""
    local http_code=""

    if ! docker_cmd ps --format '{{.Names}}' | grep -qx 'authentik-server'; then
        msg_warn "authentik-server is not running; internal API readiness check skipped."
        return 1
    fi

    for attempt in $(seq 1 "$max_attempts"); do
        status_output="$(docker_cmd exec authentik-server sh -lc '
python - <<AK_READY_PY
import urllib.request, urllib.error
url="http://127.0.0.1:9000/api/v3/core/users/me/"
try:
    r=urllib.request.urlopen(url, timeout=5)
    print(r.status)
except urllib.error.HTTPError as e:
    print(e.code)
except Exception as e:
    print("ERR", repr(e))
AK_READY_PY
' 2>/dev/null || true)"
        http_code="$(printf '%s\n' "$status_output" | tail -n 1 | awk '{print $1}')"

        # 401/403 means the API is alive and only requires authentication.
        # 200 can happen if the endpoint becomes accessible in a future Authentik version.
        if [[ "$http_code" =~ ^(200|401|403)$ ]]; then
            clear_transient_line
            AUTHENTIK_INTERNAL_STATUS="ready"
            return 0
        fi

        if [ "$attempt" -eq 1 ] || [ $((attempt % 10)) -eq 0 ]; then
            tty_print "${BFR}${YW}Authentik internal API not ready yet (${attempt}/${max_attempts}) | status=${http_code:-unknown}${CL}"
        fi

        sleep 3
    done

    clear_transient_line
    echo -e "${YW}Container status summary:${CL}"
    docker_cmd ps -a --filter "name=postgres" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
    docker_cmd ps -a --filter "name=redis" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
    docker_cmd ps -a --filter "name=authentik-server" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
    docker_cmd ps -a --filter "name=authentik-worker" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
    echo -e "${YW}PostgreSQL filtered logs:${CL}"
    docker_cmd logs --tail=200 postgres 2>/dev/null | grep -Ei 'error|exception|traceback|fatal|permission|denied|database|postgres|redis|migration|smtp|email' || true
    echo -e "${YW}Authentik server filtered logs:${CL}"
    docker_cmd logs --tail=200 authentik-server 2>/dev/null | grep -Ei 'error|exception|traceback|fatal|permission|denied|database|postgres|redis|migration|smtp|email' || true
    echo -e "${YW}Authentik worker filtered logs:${CL}"
    docker_cmd logs --tail=200 authentik-worker 2>/dev/null | grep -Ei 'error|exception|traceback|fatal|permission|denied|database|postgres|redis|migration|smtp|email' || true
    msg_error "Authentik internal API stayed unavailable/HTTP 500 after waiting. Fix Authentik logs before route automation."
}

function collect_authentik_api_token_for_deploy() {
    local env_api_token=""
    local env_bootstrap_token=""

    if [ -n "${AUTHENTIK_API_TOKEN:-}" ]; then
        return 0
    fi

    env_api_token="$(env_value AUTHENTIK_API_TOKEN)"
    env_bootstrap_token="$(env_value AUTHENTIK_BOOTSTRAP_TOKEN)"

    if [ -n "$env_api_token" ]; then
        AUTHENTIK_API_TOKEN="$env_api_token"
        export AUTHENTIK_API_TOKEN
        return 0
    fi

    if [ -n "$env_bootstrap_token" ]; then
        AUTHENTIK_API_TOKEN="$env_bootstrap_token"
        export AUTHENTIK_API_TOKEN
        return 0
    fi

    section "AUTHENTIK API TOKEN"
    echo -e "${YW}A valid Authentik API token is required to automate provider/application/outpost setup.${CL}"
    echo -e "${YW}Fresh Authentik creates the akadmin API Access token from AUTHENTIK_BOOTSTRAP_TOKEN.${CL}"
    echo -e "${YW}Leave blank to skip automation and keep bootstrap/direct access open.${CL}"

    AUTHENTIK_API_TOKEN="$(sensitive_line_input "Paste Authentik API token, or leave blank")"
    AUTHENTIK_API_TOKEN="$(printf '%s' "$AUTHENTIK_API_TOKEN" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    if [ -z "$AUTHENTIK_API_TOKEN" ]; then
        msg_warn "AUTHENTIK API TOKEN NOT PROVIDED; PROTECTED ROUTE AUTOMATION SKIPPED"
    else
        export AUTHENTIK_API_TOKEN
    fi
}

function ak_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local internal_base="http://127.0.0.1:9000/api/v3"

    [ -n "${AUTHENTIK_API_TOKEN:-}" ] || return 1

    # Important: use the Authentik container's local HTTP API for automation.
    # Calling https://auth.${DOMAIN_VALUE} goes through Cloudflare/Traefik and can return
    # HTML errors such as Cloudflare 525 or Authentik Server Error pages. Those are not JSON
    # API responses and previously caused false API success plus Python JSON tracebacks.
    if docker_cmd ps --format '{{.Names}}' | grep -qx 'authentik-server'; then
        if [ -n "$data" ]; then
            printf '%s' "$data" | docker_cmd exec -i authentik-server python3 -c '
import sys, urllib.request, urllib.error
method, url, token = sys.argv[1], sys.argv[2], sys.argv[3]
body = sys.stdin.read()
payload = body.encode() if body else None
headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
if payload is not None:
    headers["Content-Type"] = "application/json"
req = urllib.request.Request(url, data=payload, method=method, headers=headers)
try:
    with urllib.request.urlopen(req, timeout=30) as response:
        sys.stdout.write(response.read().decode(errors="replace"))
except urllib.error.HTTPError as exc:
    sys.stderr.write(f"Authentik internal API HTTP {exc.code}\n")
    sys.exit(22)
except Exception as exc:
    sys.stderr.write(f"Authentik internal API request failed: {exc}\n")
    sys.exit(1)
' "$method" "${internal_base}${endpoint}" "$AUTHENTIK_API_TOKEN"
        else
            docker_cmd exec -i authentik-server python3 -c '
import sys, urllib.request, urllib.error
method, url, token = sys.argv[1], sys.argv[2], sys.argv[3]
headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
req = urllib.request.Request(url, method=method, headers=headers)
try:
    with urllib.request.urlopen(req, timeout=30) as response:
        sys.stdout.write(response.read().decode(errors="replace"))
except urllib.error.HTTPError as exc:
    sys.stderr.write(f"Authentik internal API HTTP {exc.code}\n")
    sys.exit(22)
except Exception as exc:
    sys.stderr.write(f"Authentik internal API request failed: {exc}\n")
    sys.exit(1)
' "$method" "${internal_base}${endpoint}" "$AUTHENTIK_API_TOKEN"
        fi
        return $?
    fi

    msg_warn "authentik-server is not running; cannot call internal Authentik API."
    return 1
}

function verify_authentik_api_for_deploy() {
    apply_group_heading "Protection / Authentik"

    local api_response=""
    local api_error=""

    if [ -z "${AUTHENTIK_API_TOKEN:-}" ]; then
        AUTHENTIK_API_OK="skipped-no-token"
        msg_skip "AUTHENTIK API CHECK SKIPPED"
        return 0
    fi

    api_error="$(mktemp)"
    TEMP_FILES+=("$api_error")

    if api_response="$(ak_api GET "/core/users/me/" 2>"$api_error")" && printf '%s' "$api_response" | json_is_valid_object_or_array >/dev/null 2>&1; then
        AUTHENTIK_API_OK="yes"
        apply_line "API access" "confirmed"
    else
        AUTHENTIK_API_OK="failed"
        AUTHENTIK_API_TOKEN=""
        msg_warn "Authentik API token/internal API check failed. Protected route automation skipped."
    fi
}

function authentik_get_flow_pk() {
    local slug="$1"
    local response=""

    response="$(ak_api GET "/flows/instances/?slug=${slug}" 2>/dev/null || true)"
    printf '%s' "$response" | json_get_first_pk
}

function authentik_find_proxy_provider_pk() {
    local response=""
    response="$(ak_api GET "/providers/proxy/?search=Traefik%20Forward%20Auth" 2>/dev/null || true)"
    printf '%s' "$response" | json_get_first_pk
}

function authentik_find_application_pk() {
    local response=""
    response="$(ak_api GET "/core/applications/?slug=traefik-forward-auth" 2>/dev/null || true)"
    printf '%s' "$response" | json_get_first_pk
}

function authentik_find_embedded_outpost_pk() {
    local pk=""
    local response=""

    response="$(ak_api GET "/outposts/instances/?search=authentik%20Embedded%20Outpost" 2>/dev/null || true)"
    pk="$(printf '%s' "$response" | json_get_first_uuid_or_pk)"
    if [ -z "$pk" ]; then
        response="$(ak_api GET "/outposts/instances/?search=Embedded%20Outpost" 2>/dev/null || true)"
        pk="$(printf '%s' "$response" | json_get_first_uuid_or_pk)"
    fi
    printf '%s' "$pk"
}


function authentik_build_outpost_patch_payload() {
    local outpost_file="$1"
    local provider_pk="$2"
    local auth_host="$3"
    local auth_host_browser="$4"

    python3 - "$outpost_file" "$provider_pk" "$auth_host" "$auth_host_browser" <<'AK_OUTPOST_JSON'
import json, sys
path, provider_pk, auth_host, auth_host_browser = sys.argv[1:5]
with open(path, "r", encoding="utf-8") as fh:
    outpost = json.load(fh)
providers = list(outpost.get("providers") or [])
provider_value = int(provider_pk) if provider_pk.isdigit() else provider_pk
if provider_value not in providers:
    providers.append(provider_value)
config = dict(outpost.get("config") or {})
config["authentik_host"] = auth_host
config["authentik_host_browser"] = auth_host_browser or auth_host
payload = {"name": outpost.get("name", "authentik Embedded Outpost"), "type": outpost.get("type", "proxy"), "providers": providers, "config": config}
print(json.dumps(payload))
AK_OUTPOST_JSON
}

function authentik_verify_outpost_patch() {
    local outpost_pk="$1"
    local provider_pk="$2"
    local expected_auth_host="$3"
    local expected_browser_host="$4"
    local response_file=""
    local api_error_file=""

    response_file="$(mktemp)"
    api_error_file="$(mktemp)"
    TEMP_FILES+=("$response_file" "$api_error_file")

    if ! ak_api GET "/outposts/instances/${outpost_pk}/" > "$response_file" 2>/dev/null; then
        msg_warn "Could not re-read embedded outpost after patch."
        return 1
    fi

    python3 - "$response_file" "$provider_pk" "$expected_auth_host" "$expected_browser_host" <<'AK_VERIFY_OUTPOST'
import json, sys
path, provider_pk, expected_auth_host, expected_browser_host = sys.argv[1:5]
with open(path, "r", encoding="utf-8") as fh:
    outpost = json.load(fh)
providers = outpost.get("providers") or []
provider_value = int(provider_pk) if provider_pk.isdigit() else provider_pk
config = outpost.get("config") or {}
errors = []
if provider_value not in providers:
    errors.append(f"provider {provider_pk} not attached")
if config.get("authentik_host") != expected_auth_host:
    errors.append("authentik_host mismatch or blank")
if config.get("authentik_host_browser") != (expected_browser_host or expected_auth_host):
    errors.append("authentik_host_browser mismatch or blank")
if errors:
    print("; ".join(errors))
    sys.exit(1)
print("outpost config verified")
AK_VERIFY_OUTPOST
}

function restart_authentik_after_outpost_update() {
    if [ "$AUTHENTIK_OUTPOST_ATTACH_OK" != "yes" ]; then
        return 0
    fi

    msg_info "Reloading Authentik embedded outpost config"
    docker_cmd restart authentik-server authentik-worker >/dev/null
    sleep 45
    clear_transient_line
}

function create_or_update_authentik_forward_auth_for_deploy() {
    apply_group_heading "Protection / Authentik"

    if [ "$AUTHENTIK_API_OK" != "yes" ]; then
        AUTHENTIK_PROVIDER_OK="skipped-no-api"
        AUTHENTIK_APPLICATION_OK="skipped-no-api"
        AUTHENTIK_OUTPOST_ATTACH_OK="skipped-no-api"
        msg_skip "AUTHENTIK API AUTOMATION SKIPPED"
        return 0
    fi

    local authorization_flow=""
    local invalidation_flow=""
    local provider_pk=""
    local app_pk=""
    local outpost_pk=""
    local payload=""
    local response_file=""
    local api_error_file=""
    local auth_host_json=""
    local auth_host_value=""
    local auth_host_browser_value=""
    local domain_json=""
    local outpost_response_file=""

    response_file="$(mktemp)"
    api_error_file="$(mktemp)"
    TEMP_FILES+=("$response_file" "$api_error_file")

    authorization_flow="$(authentik_get_flow_pk "default-provider-authorization-implicit-consent")"
    [ -n "$authorization_flow" ] || authorization_flow="$(authentik_get_flow_pk "default-provider-authorization-explicit-consent")"
    invalidation_flow="$(authentik_get_flow_pk "default-provider-invalidation-flow")"

    if [ -z "$authorization_flow" ] || [ -z "$invalidation_flow" ]; then
        AUTHENTIK_PROVIDER_OK="flow-missing"
        msg_warn "Required Authentik default provider flows were not found through the internal API."
        detail_line "Authorization flow" "${authorization_flow:-missing}"
        detail_line "Invalidation flow" "${invalidation_flow:-missing}"
        return 0
    fi

    auth_host_value="${AUTHENTIK_EXTERNAL_URL:-https://${AUTHENTIK_ROUTE_HOST}}"
    auth_host_browser_value="${AUTHENTIK_HOST_BROWSER_VALUE:-$auth_host_value}"
    auth_host_json="$(printf '%s' "$auth_host_value" | json_escape)"
    domain_json="$(printf '%s' ".${DOMAIN_VALUE}" | json_escape)"

    provider_pk="$(authentik_find_proxy_provider_pk)"
    payload="$(cat <<JSON
{
  "name": "Traefik Forward Auth",
  "authorization_flow": "${authorization_flow}",
  "invalidation_flow": "${invalidation_flow}",
  "mode": "forward_domain",
  "external_host": ${auth_host_json},
  "cookie_domain": ${domain_json},
  "basic_auth_enabled": false,
  "skip_path_regex": "^/outpost.goauthentik.io/.*$"
}
JSON
)"

    if [ -z "$provider_pk" ]; then
        ak_api POST "/providers/proxy/" "$payload" > "$response_file" 2> "$api_error_file" || true
        provider_pk="$(python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); print(data.get("pk", ""))' "$response_file" 2>/dev/null || true)"
    else
        ak_api PATCH "/providers/proxy/${provider_pk}/" "$payload" > "$response_file" 2> "$api_error_file" || true
    fi

    if [ -z "$provider_pk" ]; then
        AUTHENTIK_PROVIDER_OK="failed"
        msg_warn "Forward-auth provider automation failed."
        return 0
    fi
    AUTHENTIK_PROVIDER_OK="yes"

    app_pk="$(authentik_find_application_pk)"
    payload="$(cat <<JSON
{
  "name": "Traefik Forward Auth",
  "slug": "traefik-forward-auth",
  "provider": "${provider_pk}",
  "meta_launch_url": "${auth_host_value}"
}
JSON
)"

    if [ -z "$app_pk" ]; then
        ak_api POST "/core/applications/" "$payload" > "$response_file" 2> "$api_error_file" || true
        app_pk="$(python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); print(data.get("pk", ""))' "$response_file" 2>/dev/null || true)"
    else
        ak_api PATCH "/core/applications/${app_pk}/" "$payload" > "$response_file" 2> "$api_error_file" || true
    fi

    if [ -z "$app_pk" ]; then
        AUTHENTIK_APPLICATION_OK="failed"
        msg_warn "Forward-auth application automation failed."
        return 0
    fi
    AUTHENTIK_APPLICATION_OK="yes"

    outpost_pk="$(authentik_find_embedded_outpost_pk)"
    if [ -z "$outpost_pk" ]; then
        AUTHENTIK_OUTPOST_ATTACH_OK="not-found"
        msg_warn "Existing authentik Embedded Outpost was not found; do not create a second custom outpost."
        return 0
    fi

    outpost_response_file="$(mktemp)"
    TEMP_FILES+=("$outpost_response_file")

    if ! ak_api GET "/outposts/instances/${outpost_pk}/" > "$outpost_response_file" 2>/dev/null; then
        AUTHENTIK_OUTPOST_ATTACH_OK="failed-read"
        msg_warn "Could not read embedded outpost before patching."
        return 0
    fi

    payload="$(authentik_build_outpost_patch_payload "$outpost_response_file" "$provider_pk" "$auth_host_value" "$auth_host_browser_value")"

    if ak_api PATCH "/outposts/instances/${outpost_pk}/" "$payload" >/dev/null 2>&1; then
        if authentik_verify_outpost_patch "$outpost_pk" "$provider_pk" "$auth_host_value" "$auth_host_browser_value" >/dev/null 2>&1; then
            AUTHENTIK_OUTPOST_ATTACH_OK="yes"
            apply_line "Forward auth" "ready"
            apply_line "Outpost" "configured"
        else
            AUTHENTIK_OUTPOST_ATTACH_OK="verify-failed"
            msg_warn "Outpost patch completed but verification failed. Re-check embedded outpost config in Authentik."
        fi
    else
        AUTHENTIK_OUTPOST_ATTACH_OK="failed"
        msg_warn "Outpost attach/config patch failed. Attach the provider and Authentik host manually in Authentik."
    fi
}

function verify_authentik_outpost_route_for_deploy() {
    apply_group_heading "Protection / Authentik"

    local test_host="$ADMIN_UI_HOST"
    local test_url="https://${test_host}/outpost.goauthentik.io/start?rd=https://${test_host}/"
    local http_code=""

    http_code="$(curl -ksS -o /dev/null -w '%{http_code}' "$test_url" || true)"
    if [[ "$http_code" =~ ^(302|303|307)$ ]]; then
        AUTHENTIK_OUTPOST_302_OK="yes"
    else
        AUTHENTIK_OUTPOST_302_OK="warning"
    fi

    apply_line "Protected routes" "$([ "$AUTHENTIK_OUTPOST_302_OK" == "yes" ] && echo ready || echo needs\ UI\ confirmation)" "$(status_color_for_value "$AUTHENTIK_OUTPOST_302_OK")"
}

function detect_recent_acme_rate_limit() {
    local domain_pattern="${DOMAIN_VALUE:-}"

    [ -n "$domain_pattern" ] || return 1

    docker_cmd logs --tail=260 traefik 2>/dev/null | grep -Eiq "rateLimited|too many certificates|acme: error: 429|${domain_pattern}"
}

function verify_authentik_public_host_route() {
    local auth_host="$AUTHENTIK_ROUTE_HOST"
    local public_code=""
    local local_code=""
    local headers_file=""

    headers_file="$(mktemp)"
    TEMP_FILES+=("$headers_file")

    public_code="$(curl -ksS -D "$headers_file" -o /dev/null -w '%{http_code}' "https://${auth_host}/" 2>/dev/null || true)"
    local_code="$(curl -ksS -o /dev/null -w '%{http_code}' --resolve "${auth_host}:443:127.0.0.1" "https://${auth_host}/" 2>/dev/null || true)"

    case "$public_code" in
        200|301|302|303|307|401|403)
            AUTHENTIK_HOST_ROUTE_OK="yes"
            ;;
        525)
            if detect_recent_acme_rate_limit; then
                AUTHENTIK_HOST_ROUTE_OK="acme-rate-limited"
            else
                AUTHENTIK_HOST_ROUTE_OK="auth-host-tls-failed"
            fi
            PUBLIC_ROUTE_WARNINGS="warnings"
            ;;
        *)
            if [ "$local_code" == "000" ] || [ -z "$local_code" ]; then
                if detect_recent_acme_rate_limit; then
                    AUTHENTIK_HOST_ROUTE_OK="acme-rate-limited"
                else
                    AUTHENTIK_HOST_ROUTE_OK="auth-host-tls-failed"
                fi
            else
                AUTHENTIK_HOST_ROUTE_OK="needs-review"
            fi
            PUBLIC_ROUTE_WARNINGS="warnings"
            ;;
    esac

    return 0
}

function verify_selected_protected_routes() {
    apply_group_heading "Route checks"

    local host=""
    local code=""
    local headers_file=""
    local warnings="0"
    local hosts=()
    local reason="ready"

    headers_file="$(mktemp)"
    TEMP_FILES+=("$headers_file")

    verify_authentik_public_host_route

    hosts+=("$ADMIN_UI_HOST")
    if [[ "$DEPLOY_VSCODE" =~ ^[Yy] ]]; then hosts+=("${VSCODE_HOST}"); fi
    if [[ "$DEPLOY_FILEBROWSER" =~ ^[Yy] ]]; then hosts+=("${FILEBROWSER_HOST}"); fi

    for host in "${hosts[@]}"; do
        : > "$headers_file"
        code="$(curl -ksS -D "$headers_file" -o /dev/null -w '%{http_code}' "https://${host}/" 2>/dev/null || true)"
        case "$code" in
            200|302|303|307|401|403) ;;
            *) warnings=$((warnings + 1)); PUBLIC_ROUTE_WARNINGS="warnings" ;;
        esac
    done

    if [ "$AUTHENTIK_HOST_ROUTE_OK" != "yes" ]; then
        warnings=$((warnings + 1))
        case "$AUTHENTIK_HOST_ROUTE_OK" in
            auth-host-tls-failed) reason="Cloudflare SSL/origin certificate" ;;
            acme-rate-limited) reason="ACME rate limit / certificate issuance" ;;
            *) reason="public Authentik route needs review" ;;
        esac
    fi

    if [ "$warnings" -eq 0 ]; then
        PROTECTED_ROUTE_VERIFY_OK="yes"
        PUBLIC_ROUTE_SUMMARY_STATUS="ready"
    else
        PROTECTED_ROUTE_VERIFY_OK="needs-review"
        PUBLIC_ROUTE_SUMMARY_STATUS="needs review"
    fi

    apply_line "Public routes" "$PUBLIC_ROUTE_SUMMARY_STATUS" "$(status_color_for_value "$PROTECTED_ROUTE_VERIFY_OK")"
    [ "$PUBLIC_ROUTE_SUMMARY_STATUS" != "ready" ] && apply_line "Reason" "$reason" "$YW"
}

function configure_authentik_and_verify_routes() {
    verify_authentik_dependencies_for_deploy
    if [ "$AUTHENTIK_DEPENDENCIES_OK" == "yes" ]; then
        wait_for_authentik_internal_api_ready
    fi
    collect_authentik_api_token_for_deploy
    verify_authentik_api_for_deploy
    create_or_update_authentik_forward_auth_for_deploy
    restart_authentik_after_outpost_update
    verify_authentik_outpost_route_for_deploy
    verify_selected_protected_routes
}


# =========================================================
#  NETWORK BOOTSTRAP
# =========================================================

# --- 34. NETWORK CREATION ---
# Creates the shared external networks used by all independent compose stacks.
function create_shared_networks() {
    apply_group_heading "Networks"

    docker_cmd network create --driver bridge --subnet "$SOCKET_PROXY_SUBNET_EXPECTED" socket_proxy >/dev/null 2>&1 || true
    docker_cmd network create --driver bridge --subnet "$T2_PROXY_SUBNET_EXPECTED" t2_proxy >/dev/null 2>&1 || true
    docker_cmd network create --driver bridge database >/dev/null 2>&1 || true

    NETWORKS_CREATED="yes"
}

function verify_shared_networks() {
    apply_group_heading "Networks"

    SOCKET_PROXY_SUBNET_ACTUAL="$(docker_cmd network inspect socket_proxy --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)"
    T2_PROXY_SUBNET_ACTUAL="$(docker_cmd network inspect t2_proxy --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)"
    DATABASE_NETWORK_NAME="$(docker_cmd network inspect database --format '{{.Name}}' 2>/dev/null || true)"

    if [ "$SOCKET_PROXY_SUBNET_ACTUAL" != "$SOCKET_PROXY_SUBNET_EXPECTED" ]; then
        msg_error "socket_proxy subnet mismatch: expected ${SOCKET_PROXY_SUBNET_EXPECTED}, got ${SOCKET_PROXY_SUBNET_ACTUAL:-missing}"
    fi

    if [ "$T2_PROXY_SUBNET_ACTUAL" != "$T2_PROXY_SUBNET_EXPECTED" ]; then
        msg_error "t2_proxy subnet mismatch: expected ${T2_PROXY_SUBNET_EXPECTED}, got ${T2_PROXY_SUBNET_ACTUAL:-missing}"
    fi

    if [ "$DATABASE_NETWORK_NAME" != "database" ]; then
        msg_error "database network missing or invalid."
    fi

    NETWORKS_VERIFIED="yes"

    apply_line "socket_proxy" "$SOCKET_PROXY_SUBNET_ACTUAL"
    apply_line "t2_proxy" "$T2_PROXY_SUBNET_ACTUAL"
    apply_line "database" "$DATABASE_NETWORK_NAME"
}

function download_bootstrap_compose_files() {
    apply_group_heading "Compose files"

    msg_info "Downloading Socket Proxy stack compose"
    curl --globoff -fsSL "$SOCKET_PROXY_STACK_URL" -o "${COMPOSE_DIR}/${SOCKET_PROXY_STACK_FILE}"
    SOCKET_PROXY_STACK_DOWNLOADED="yes"

    case "$ADMIN_UI" in
        portainer)
            msg_info "Downloading Portainer stack compose"
            curl --globoff -fsSL "$PORTAINER_STACK_URL" -o "${COMPOSE_DIR}/${PORTAINER_STACK_FILE}"
            PORTAINER_STACK_DOWNLOADED="yes"

            msg_info "Downloading Admin UI bootstrap override"
            curl --globoff -fsSL "$PORTAINER_BOOTSTRAP_OVERRIDE_URL" -o "$ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE"
            PORTAINER_BOOTSTRAP_OVERRIDE_DOWNLOADED="yes"
            ;;
        dockge)
            msg_info "Downloading Dockge stack compose"
            curl --globoff -fsSL "$DOCKGE_STACK_URL" -o "${COMPOSE_DIR}/${DOCKGE_STACK_FILE}"
            DOCKGE_STACK_DOWNLOADED="yes"

            msg_info "Downloading Dockge bootstrap override"
            curl --globoff -fsSL "$DOCKGE_BOOTSTRAP_OVERRIDE_URL" -o "$ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE"
            DOCKGE_BOOTSTRAP_OVERRIDE_DOWNLOADED="yes"
            ;;
        komodo)
            msg_info "Downloading Komodo stack compose"
            curl --globoff -fsSL "$KOMODO_STACK_URL" -o "${COMPOSE_DIR}/${KOMODO_STACK_FILE}"
            KOMODO_STACK_DOWNLOADED="yes"

            msg_info "Downloading Komodo bootstrap override"
            curl --globoff -fsSL "$KOMODO_BOOTSTRAP_OVERRIDE_URL" -o "$ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE"
            KOMODO_BOOTSTRAP_OVERRIDE_DOWNLOADED="yes"
            ;;
        dockhand)
            msg_info "Downloading Dockhand stack compose"
            curl --globoff -fsSL "$DOCKHAND_STACK_URL" -o "${COMPOSE_DIR}/${DOCKHAND_STACK_FILE}"
            DOCKHAND_STACK_DOWNLOADED="yes"

            msg_info "Downloading Dockhand bootstrap override"
            curl --globoff -fsSL "$DOCKHAND_BOOTSTRAP_OVERRIDE_URL" -o "$ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE"
            DOCKHAND_BOOTSTRAP_OVERRIDE_DOWNLOADED="yes"
            ;;
    esac

    ADMIN_UI_BOOTSTRAP_OVERRIDE_WRITTEN="downloaded"

    run_cmd "setting Socket Proxy compose file ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "${COMPOSE_DIR}/${SOCKET_PROXY_STACK_FILE}"
    run_cmd "setting Socket Proxy compose file permissions" chmod 640 "${COMPOSE_DIR}/${SOCKET_PROXY_STACK_FILE}"
    run_cmd "setting ${ADMIN_UI_DISPLAY_NAME} compose ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$ADMIN_UI_COMPOSE_FILE" "$ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE"
    run_cmd "setting ${ADMIN_UI_DISPLAY_NAME} compose permissions" chmod 640 "$ADMIN_UI_COMPOSE_FILE" "$ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE"
    sync_compose_file_for_dockge "$SOCKET_PROXY_STACK_FILE" "${COMPOSE_DIR}/${SOCKET_PROXY_STACK_FILE}"
    sync_compose_file_for_dockge "$(basename "$ADMIN_UI_COMPOSE_FILE")" "$ADMIN_UI_COMPOSE_FILE"
    sync_bootstrap_override_for_dockge "$(basename "$ADMIN_UI_COMPOSE_FILE")" "$ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE"

}
# --- 37. PORTAINER BOOTSTRAP OVERRIDE CHECK ---
# Confirms the downloaded Admin UI bootstrap override exists locally.
# Script 7 should later redeploy Portainer without this override to close the bootstrap port.
function verify_admin_ui_bootstrap_override_file() {
    apply_group_heading "Compose files"

    if [ ! -f "$ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE" ]; then
        msg_error "${ADMIN_UI_DISPLAY_NAME} bootstrap override was not downloaded: ${ADMIN_UI_BOOTSTRAP_OVERRIDE_FILE}"
    fi

    ADMIN_UI_BOOTSTRAP_OVERRIDE_WRITTEN="downloaded"
}


# --- 38. COMPOSE CONFIG VALIDATION ---
# Validates Socket Proxy stack, selected Admin UI stack and Admin UI bootstrap override before deployment.
function validate_bootstrap_compose_files() {
    apply_group_heading "Compose validation"

    msg_info "Validating bootstrap compose files"
    run_docker_cmd "validating Socket Proxy stack compose" compose --env-file "$ENV_FILE" -p socket-proxy -f "$(compose_path_for_stack_file "$SOCKET_PROXY_STACK_FILE")" config -q

    export PORTAINER_BOOTSTRAP_PORT DOCKGE_BOOTSTRAP_PORT KOMODO_BOOTSTRAP_PORT DOCKHAND_BOOTSTRAP_PORT ADMIN_UI_BOOTSTRAP_BIND
    run_docker_cmd "validating ${ADMIN_UI_DISPLAY_NAME} stack compose" compose --env-file "$ENV_FILE" -p "$ADMIN_UI_PROJECT_NAME" -f "$(compose_path_for_stack_file "$(basename "$ADMIN_UI_COMPOSE_FILE")")" -f "$(bootstrap_override_path_for_primary_file "$(basename "$ADMIN_UI_COMPOSE_FILE")")" config -q
    clear_transient_line
    ADMIN_UI_VALIDATED="yes"
}
# --- 39. SOCKET-PROXY DEPLOYMENT ---
# Deploys the Socket Proxy stack using Docker Compose.
function deploy_socket_proxy() {
    local compose_path=""
    compose_path="$(compose_path_for_stack_file "$SOCKET_PROXY_STACK_FILE")"
    compose_up_quiet "deploying socket-proxy" --env-file "$ENV_FILE" -p socket-proxy -f "$compose_path"
    SOCKET_PROXY_DEPLOYED="yes"
    apply_line "socket-proxy" "deployed"
}

function deploy_admin_ui() {
    local admin_compose_path=""
    local admin_override_path=""

    export PORTAINER_BOOTSTRAP_PORT DOCKGE_BOOTSTRAP_PORT KOMODO_BOOTSTRAP_PORT DOCKHAND_BOOTSTRAP_PORT ADMIN_UI_BOOTSTRAP_BIND
    admin_compose_path="$(compose_path_for_stack_file "$(basename "$ADMIN_UI_COMPOSE_FILE")")"
    admin_override_path="$(bootstrap_override_path_for_primary_file "$(basename "$ADMIN_UI_COMPOSE_FILE")")"
    compose_up_quiet "deploying ${ADMIN_UI_DISPLAY_NAME}" --env-file "$ENV_FILE" -p "$ADMIN_UI_PROJECT_NAME" -f "$admin_compose_path" -f "$admin_override_path"
    ADMIN_UI_DEPLOYED="yes"

    if [ "$ADMIN_UI" == "portainer" ]; then
        PORTAINER_DEPLOYED="yes"
    fi

    apply_line "$ADMIN_UI_PROJECT_NAME" "deployed"
}

function configure_bootstrap_firewall() {
    apply_group_heading "Prerequisites"

    if ! command -v ufw >/dev/null 2>&1; then
        UFW_BOOTSTRAP_PORT_OPENED="not-found"
        apply_line "Bootstrap" "ready"
        return 0
    fi

    if ! ufw status 2>/dev/null | grep -qi "Status: active" && ! { [ -n "$SUDO_CMD" ] && "$SUDO_CMD" ufw status 2>/dev/null | grep -qi "Status: active"; }; then
        UFW_BOOTSTRAP_PORT_OPENED="not-active"
        apply_line "Bootstrap" "ready"
        return 0
    fi

    msg_info "Allowing temporary ${ADMIN_UI_DISPLAY_NAME} bootstrap port ${ADMIN_UI_BOOTSTRAP_PORT}/tcp"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" ufw allow "${ADMIN_UI_BOOTSTRAP_PORT}/tcp" comment "temporary ${ADMIN_UI_DISPLAY_NAME} bootstrap" >/dev/null 2>&1 || true
    else
        ufw allow "${ADMIN_UI_BOOTSTRAP_PORT}/tcp" comment "temporary ${ADMIN_UI_DISPLAY_NAME} bootstrap" >/dev/null 2>&1 || true
    fi

    clear_transient_line
    UFW_BOOTSTRAP_PORT_OPENED="yes"
    apply_line "Bootstrap" "ready"
}

function detect_admin_ui_access_ip() {
    local detected_ip=""

    detected_ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}' || true)"

    if [ -z "$detected_ip" ]; then
        detected_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
    fi

    ADMIN_UI_BOOTSTRAP_ACCESS_IP="${detected_ip:-127.0.0.1}"
    ADMIN_UI_BOOTSTRAP_ACCESS_URL="${ADMIN_UI_BOOTSTRAP_SCHEME}://${ADMIN_UI_BOOTSTRAP_ACCESS_IP}:${ADMIN_UI_BOOTSTRAP_PORT}"
    PORTAINER_ACCESS_URL="$ADMIN_UI_BOOTSTRAP_ACCESS_URL"
}

function detect_portainer_access_ip() {
    detect_admin_ui_access_ip
}

# --- 43. CONTAINER VERIFICATION ---
# Verifies the bootstrap containers are running and visible.
function verify_bootstrap_containers() {
    apply_group_heading "Route checks"

    msg_info "Checking bootstrap containers"
    if docker_cmd ps --format '{{.Names}}' | grep -qx 'socket-proxy'; then
        SOCKET_PROXY_DEPLOYED="yes"
    else
        msg_error "socket-proxy container is not running."
    fi

    if docker_cmd ps --format '{{.Names}}' | grep -qx "$ADMIN_UI_SERVICE_NAME"; then
        ADMIN_UI_DEPLOYED="yes"
    else
        msg_error "${ADMIN_UI_SERVICE_NAME} container is not running."
    fi
    clear_transient_line

    detect_admin_ui_access_ip

    msg_info "Checking ${ADMIN_UI_DISPLAY_NAME} bootstrap access"
    if docker_cmd port "$ADMIN_UI_SERVICE_NAME" "${ADMIN_UI_INTERNAL_PORT}/tcp" 2>/dev/null | grep -q ":${ADMIN_UI_BOOTSTRAP_PORT}$"; then
        ADMIN_UI_BOOTSTRAP_PORT_EXPOSED="yes"
    else
        ADMIN_UI_BOOTSTRAP_PORT_EXPOSED="not-confirmed"
        msg_warn "${ADMIN_UI_DISPLAY_NAME} is running, but bootstrap access was not confirmed"
    fi
    clear_transient_line

    apply_line "Internal routes" "ready"
}

function verify_reset_counts() {
    VERIFY_PASS_COUNT="0"; VERIFY_WARN_COUNT="0"; VERIFY_FAIL_COUNT="0"; VERIFY_STATUS="not-run"
}
function verify_pass() { VERIFY_PASS_COUNT=$(( VERIFY_PASS_COUNT + 1 )); }
function verify_warn() { VERIFY_WARN_COUNT=$(( VERIFY_WARN_COUNT + 1 )); }
function verify_fail() { VERIFY_FAIL_COUNT=$(( VERIFY_FAIL_COUNT + 1 )); }
function finalize_verify_status() {
    if [ "${VERIFY_FAIL_COUNT:-0}" -gt 0 ]; then VERIFY_STATUS="FAIL"; elif [ "${VERIFY_WARN_COUNT:-0}" -gt 0 ]; then VERIFY_STATUS="PASS_WITH_WARNINGS"; else VERIFY_STATUS="PASS"; fi
}
function status_verify_from_value() {
    local label="$1"; local value="$2"
    case "$value" in yes|ready|downloaded|deployed|PASS|completed) verify_pass ;; no|missing|failed|FAIL|empty-or-missing) verify_fail ;; skipped|not-run|not-found|not-active|PASS_WITH_WARNINGS|warning|warnings|needs-review|auth-host-tls-failed|acme-rate-limited|skipped-no-api|skipped-no-token|authentik-not-running|not-confirmed|unknown) verify_warn ;; *) [ -n "$value" ] && verify_pass || verify_warn ;; esac
    printf '%s=%s\n' "$label" "$value"
}
function selected_stack_names() {
    local names=""; local i=""
    names="socket-proxy,${ADMIN_UI_PROJECT_NAME}"
    for i in "${!SELECTED_STACK_FILES[@]}"; do
        if is_helper_compose_file "${SELECTED_STACK_FILES[$i]}"; then
            continue
        fi
        names="${names:+${names},}${SELECTED_STACK_PROJECTS[$i]}"
    done
    printf '%s' "${names:-none}"
}
function update_deployed_failed_stack_summary() {
    local deployed=""; local failed=""; local i=""; local service=""; local project=""
    if [ "$SOCKET_PROXY_DEPLOYED" == "yes" ]; then deployed="socket-proxy"; else failed="socket-proxy"; fi
    if [ "$ADMIN_UI_DEPLOYED" == "yes" ]; then deployed="${deployed:+${deployed},}${ADMIN_UI_PROJECT_NAME}"; else failed="${failed:+${failed},}${ADMIN_UI_PROJECT_NAME}"; fi
    for i in "${!SELECTED_STACK_PROJECTS[@]}"; do
        if is_helper_compose_file "${SELECTED_STACK_FILES[$i]}"; then
            continue
        fi
        project="${SELECTED_STACK_PROJECTS[$i]}"; service="${SELECTED_STACK_SERVICES[$i]}"
        if [ -z "$service" ] || docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx "$service"; then deployed="${deployed:+${deployed},}${project}"; else failed="${failed:+${failed},}${project}"; fi
    done
    DEPLOYED_STACKS="${deployed:-none}"; FAILED_STACKS="${failed:-none}"
}

function deployed_matches_selected_stacks() {
    [ "${FAILED_STACKS:-none}" == "none" ] || return 1
    [ "${DEPLOYED_STACKS:-none}" == "$(selected_stack_names)" ]
}

function route_warning_reason() {
    case "${AUTHENTIK_HOST_ROUTE_OK:-not-run}" in
        auth-host-tls-failed)
            printf '%s' "Cloudflare SSL/origin certificate"
            ;;
        acme-rate-limited)
            printf '%s' "ACME rate limit / certificate issuance"
            ;;
        needs-review|not-run|unknown)
            printf '%s' "public route review required"
            ;;
        *)
            if [ "${PROTECTED_ROUTE_VERIFY_OK:-not-run}" == "needs-review" ]; then
                printf '%s' "Cloudflare/Auth route review required"
            else
                printf '%s' "ready"
            fi
            ;;
    esac
}

function write_verify_outputs() {
    local machine_tmp="" display_tmp=""
    machine_tmp="$(mktemp)"; display_tmp="$(mktemp)"; TEMP_FILES+=("$machine_tmp" "$display_tmp")
    update_deployed_failed_stack_summary; verify_reset_counts
    {
        echo "--- DOCKER STACK DEPLOY VERIFY LOG ---"; echo "Date=$(date)"; echo "SCRIPT_VERSION=${SCRIPT_VERSION}"; echo "SCRIPT_BUILD=${SCRIPT_BUILD}"; echo "Docker user=${DOCKER_USER}"; echo "Docker dir=${DOCKER_DIR}"; echo "Compose dir=${COMPOSE_DIR}"; echo "Env file=${ENV_FILE}"; echo "Domain=${DOMAIN_VALUE}"; echo "Admin UI=${ADMIN_UI}"; echo "Selected stacks=$(selected_stack_names)"; echo "Deployed stacks=${DEPLOYED_STACKS}"; echo "Failed stacks=${FAILED_STACKS}"; echo "Stacks=$(selected_stack_count)"; echo "Helpers=$(helper_file_count)"; echo "Compose files=$(compose_file_total_count)"; echo ""; echo "Checks:"
        status_verify_from_value "Script 6 verify" "${SCRIPT6_PREFLIGHT_STATUS}"
        status_verify_from_value ".env keys" "${SCRIPT6_ENV_REQUIRED_KEYS_STATUS}"
        status_verify_from_value "Hostnames" "${SCRIPT6_ENV_HOSTNAMES_STATUS}"
        status_verify_from_value "URLs" "${SCRIPT6_ENV_URLS_STATUS}"
        status_verify_from_value "Secrets" "${SCRIPT6_SECRETS_STATUS}"
        status_verify_from_value "Traefik config" "${TRAEFIK_CONFIG_PREFLIGHT_STATUS}"
        status_verify_from_value "ACME email" "${TRAEFIK_ACME_EMAIL_STATUS}"
        status_verify_from_value "Networks created" "${NETWORKS_CREATED}"
        status_verify_from_value "Networks verified" "${NETWORKS_VERIFIED}"
        status_verify_from_value "Socket proxy deployed" "${SOCKET_PROXY_DEPLOYED}"
        status_verify_from_value "Admin UI deployed" "${ADMIN_UI_DEPLOYED}"
        status_verify_from_value "Admin UI validated" "${ADMIN_UI_VALIDATED}"
        status_verify_from_value "Bootstrap port exposed" "${ADMIN_UI_BOOTSTRAP_PORT_EXPOSED}"
        status_verify_from_value "UFW bootstrap port" "${UFW_BOOTSTRAP_PORT_OPENED}"
        status_verify_from_value "Redis sysctl" "${SYSCTL_REDIS_OK}"
        status_verify_from_value "Traefik placeholders" "${TRAEFIK_PLACEHOLDERS_OK}"
        status_verify_from_value "Traefik DNS" "${TRAEFIK_DNS_DELAY_OK}"
        status_verify_from_value "Traefik encoded chars" "${TRAEFIK_ENCODED_CHARS_OK}"
        status_verify_from_value "Authentik folders" "${AUTHENTIK_FOLDERS_OK}"
        status_verify_from_value "CF companion secret" "${CF_COMPANION_SECRET_OK}"
        status_verify_from_value "Filebrowser folders" "${FILEBROWSER_FOLDERS_OK}"
        status_verify_from_value "Authentik dependency gate" "${AUTHENTIK_DEPENDENCIES_OK}"
        status_verify_from_value "Authentik API" "${AUTHENTIK_API_OK}"
        status_verify_from_value "Authentik provider" "${AUTHENTIK_PROVIDER_OK}"
        status_verify_from_value "Authentik application" "${AUTHENTIK_APPLICATION_OK}"
        status_verify_from_value "Authentik outpost attach" "${AUTHENTIK_OUTPOST_ATTACH_OK}"
        status_verify_from_value "Authentik outpost 302" "${AUTHENTIK_OUTPOST_302_OK}"
        status_verify_from_value "Authentik public host route" "${AUTHENTIK_HOST_ROUTE_OK}"
        status_verify_from_value "Protected routes" "${PROTECTED_ROUTE_VERIFY_OK}"
    } > "$machine_tmp"
    [ "$FAILED_STACKS" != "none" ] && verify_fail
    finalize_verify_status
    {
        echo "SCRIPT 6.5 STACK DEPLOY VERIFICATION"
        echo "Version: ${SCRIPT_VERSION} (${SCRIPT_BUILD})"
        echo "Date: $(date)"
        echo ""
        echo "Deployment:"
        echo "  Docker dir: ${DOCKER_DIR}"
        echo "  Compose dir: ${COMPOSE_DIR}"
        echo "  Domain: ${DOMAIN_VALUE}"
        echo "  Admin UI: ${ADMIN_UI}"
        echo "  Stacks: $(selected_stack_count)"
        echo "  Helpers: $(helper_file_count)"
        echo "  Compose files: $(compose_file_total_count)"
        echo "  Backups: ${SAFE_WRITE_BACKUP_COUNT}"
        echo "  Selected stacks:"
        stack_list_lines "$(selected_stack_names)" | sed 's/^/  /'
        echo "  Deployed stacks:"
        stack_list_lines "$DEPLOYED_STACKS" | sed 's/^/  /'
        echo "  Failed stacks:"
        stack_list_lines "$FAILED_STACKS" | sed 's/^/  /'
        echo ""
        echo "Readiness:"
        echo "  Script 6 dependency: ${SCRIPT6_PREFLIGHT_STATUS}"
        echo "  .env keys: ${SCRIPT6_ENV_REQUIRED_KEYS_STATUS}"
        echo "  Hostnames: ${SCRIPT6_ENV_HOSTNAMES_STATUS}"
        echo "  URLs: ${SCRIPT6_ENV_URLS_STATUS}"
        echo "  Secrets: ${SCRIPT6_SECRETS_STATUS}"
        echo "  Optional htpasswd: ${SCRIPT6_HTPASSWD_STATUS}"
        echo "  Traefik config: ${TRAEFIK_CONFIG_PREFLIGHT_STATUS}"
        echo "  ACME email: ${TRAEFIK_ACME_EMAIL_STATUS}"
        echo ""
        echo "Runtime:"
        echo "  Networks: ${NETWORKS_VERIFIED}"
        echo "  Socket proxy: ${SOCKET_PROXY_DEPLOYED}"
        echo "  Admin UI: ${ADMIN_UI_DEPLOYED}"
        echo "  Authentik API: ${AUTHENTIK_API_OK}"
        echo "  Protected routes: ${PROTECTED_ROUTE_VERIFY_OK}"
        echo "  Public route warnings: ${PUBLIC_ROUTE_WARNINGS}"
        echo "  DNS records: ${DNS_RECORDS_STATUS}"
        echo "  cf-companion: ${CF_COMPANION_RUNTIME_STATUS}"
        echo "  Rescan: ${CF_COMPANION_RESCAN_STATUS}"
        echo "  DNS wait: ${DNS_WAIT_STATUS}"
        echo ""
        echo "Verification:"
        echo "  Status: ${VERIFY_STATUS}"
        echo "  Pass: ${VERIFY_PASS_COUNT}"
        echo "  Warn: ${VERIFY_WARN_COUNT}"
        echo "  Fail: ${VERIFY_FAIL_COUNT}"
        echo "  Verify log: ${VERIFY_LOG}"
        echo "  Display log: ${VERIFY_DISPLAY_LOG}"
    } > "$display_tmp"
    { cat "$machine_tmp"; echo "VERIFY_STATUS=${VERIFY_STATUS}"; echo "VERIFY_PASS_COUNT=${VERIFY_PASS_COUNT}"; echo "VERIFY_WARN_COUNT=${VERIFY_WARN_COUNT}"; echo "VERIFY_FAIL_COUNT=${VERIFY_FAIL_COUNT}"; echo ""; echo "Docker containers:"; docker_cmd ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true; } | if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" tee "$VERIFY_LOG" >/dev/null; else tee "$VERIFY_LOG" >/dev/null; fi
    if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" cp "$display_tmp" "$VERIFY_DISPLAY_LOG"; "$SUDO_CMD" chmod 0644 "$VERIFY_DISPLAY_LOG" "$VERIFY_LOG" 2>/dev/null || true; else cp "$display_tmp" "$VERIFY_DISPLAY_LOG"; chmod 0644 "$VERIFY_DISPLAY_LOG" "$VERIFY_LOG" 2>/dev/null || true; fi
}

# --- 44. VERIFY LOG ---
# Writes a small Docker bootstrap verification report to /var/log.
function create_verification_report() {
    write_verify_outputs
    apply_line "Verification log" "written"
    apply_line "Display log" "written"
}

# --- 45. MARKER ---
# Stores successful bootstrap information.
function write_completion_marker() {
    local marker_tmp=""
    marker_tmp="$(mktemp)"; TEMP_FILES+=("$marker_tmp")
    update_deployed_failed_stack_summary
    cat > "$marker_tmp" <<MARKER_EOF
Docker Stack Deploy completed on: $(date)
Docker user: $DOCKER_USER
Docker dir: $DOCKER_DIR
Compose dir: $COMPOSE_DIR
Env file: $ENV_FILE
GitHub raw base: $GITHUB_RAW_BASE
Admin UI: $ADMIN_UI
Domain: $DOMAIN_VALUE
Verification: $VERIFY_STATUS
Deployed stacks: $DEPLOYED_STACKS
Failed stacks: $FAILED_STACKS
Verify log: $VERIFY_LOG
Display log: $VERIFY_DISPLAY_LOG

SCRIPT65_STATUS=completed
SCRIPT65_VERSION=$SCRIPT_VERSION
SCRIPT65_BUILD=$SCRIPT_BUILD
SCRIPT65_VERIFY_STATUS=$VERIFY_STATUS
SCRIPT65_VERIFY_LOG=$VERIFY_LOG
SCRIPT65_VERIFY_DISPLAY_LOG=$VERIFY_DISPLAY_LOG
SCRIPT65_DOCKER_DIR=$DOCKER_DIR
SCRIPT65_COMPOSE_DIR=$COMPOSE_DIR
SCRIPT65_ENV_FILE=$ENV_FILE
SCRIPT65_ADMIN_UI=$ADMIN_UI
SCRIPT65_DOMAIN=$DOMAIN_VALUE
SCRIPT65_DEPLOYED_STACKS=$DEPLOYED_STACKS
SCRIPT65_FAILED_STACKS=$FAILED_STACKS
SCRIPT65_STACK_COUNT=$(selected_stack_count)
SCRIPT65_HELPER_FILE_COUNT=$(helper_file_count)
SCRIPT65_COMPOSE_FILE_COUNT=$(compose_file_total_count)
SCRIPT65_NETWORKS_READY=$NETWORKS_VERIFIED
SCRIPT65_SOCKET_PROXY_READY=$SOCKET_PROXY_DEPLOYED
SCRIPT65_TRAEFIK_READY=$TRAEFIK_PLACEHOLDERS_OK
SCRIPT65_AUTHENTIK_READY=$AUTHENTIK_API_OK
SCRIPT65_BOOTSTRAP_PORT_OPEN=$UFW_BOOTSTRAP_PORT_OPENED
MARKER_EOF
    if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" cp "$marker_tmp" "$COMPLETED_MARKER"; "$SUDO_CMD" chmod 0600 "$COMPLETED_MARKER" 2>/dev/null || true; else cp "$marker_tmp" "$COMPLETED_MARKER"; chmod 0600 "$COMPLETED_MARKER" 2>/dev/null || true; fi
    apply_line "Marker" "written"
}

# --- 46. FINAL SUMMARY ---
# Displays clean final setup summary and next step.
function show_final_summary() {
    update_deployed_failed_stack_summary

    section_flash_success "     ━━━━━━━━━━━━━━━━━    FINISHED    ━━━━━━━━━━━━━━━━━"
    group_heading "Deployment"
    detail_line "Docker dir" "$DOCKER_DIR"
    detail_line "Compose dir" "$COMPOSE_DIR"
    detail_line "Domain" "$DOMAIN_VALUE"
    detail_line "Admin UI" "$ADMIN_UI_DISPLAY_NAME"
    detail_line "Stacks" "$(selected_stack_count)"
    detail_line "Helpers" "$(helper_file_count)"
    detail_line "Compose files" "$(compose_file_total_count)"
    detail_line "Backups" "$SAFE_WRITE_BACKUP_COUNT"
    if deployed_matches_selected_stacks; then
        detail_line "Deployed" "all selected stacks" "$GN"
        detail_line "Failed" "none" "$GN"
    else
        detail_line "Deployed" "see deployed stacks" "$YW"
        detail_line "Failed" "$FAILED_STACKS" "$(status_color_for_value "$FAILED_STACKS")"
    fi
    echo ""
    group_heading "Selected stacks"
    display_selected_stack_lines
    if ! deployed_matches_selected_stacks; then
        echo ""
        group_heading "Deployed stacks"
        stack_list_lines "$DEPLOYED_STACKS"
        echo ""
        group_heading "Failed stacks"
        stack_list_lines "$FAILED_STACKS"
    fi
    echo ""
    group_heading "Access"
    detail_line "Traefik URL" "https://${TRAEFIK_DASHBOARD_HOST:-traefik.${DOMAIN_VALUE}}"
    detail_line "Authentik URL" "${AUTHENTIK_EXTERNAL_URL:-https://${AUTHENTIK_ROUTE_HOST}}"
    if [ -n "${AUTHENTIK_HOST_BROWSER_VALUE:-}" ] && [ "${AUTHENTIK_HOST_BROWSER_VALUE}" != "${AUTHENTIK_EXTERNAL_URL:-https://${AUTHENTIK_ROUTE_HOST}}" ]; then
        detail_line "Browser URL" "$AUTHENTIK_HOST_BROWSER_VALUE"
    fi
    detail_line "Admin UI URL" "$ADMIN_UI_URL"
    detail_line "Temporary access" "${ADMIN_UI_BOOTSTRAP_ACCESS_URL:-not confirmed}" "$(status_color_for_value "${ADMIN_UI_BOOTSTRAP_PORT_EXPOSED:-not-confirmed}")"
    detail_line "Traefik/AuthentiK" "$ADMIN_UI_URL"
    detail_line "CF Companion" "$(yes_no_label "$DEPLOY_CF_COMPANION")" "$(status_color_for_value "$(yes_no_label "$DEPLOY_CF_COMPANION")")"
    detail_line "Public routes" "${PUBLIC_ROUTE_SUMMARY_STATUS:-$PROTECTED_ROUTE_VERIFY_OK}" "$(status_color_for_value "${PROTECTED_ROUTE_VERIFY_OK:-not-run}")"
    echo ""
    group_heading "Logs / marker"
    detail_line "Verify log" "$VERIFY_LOG"
    detail_line "Display log" "$VERIFY_DISPLAY_LOG"
    detail_line "Marker" "$COMPLETED_MARKER"
    echo ""
    group_heading "Verification"
    detail_line "Status" "$VERIFY_STATUS" "$(status_color_for_value "$VERIFY_STATUS")"
    detail_line "Pass" "$VERIFY_PASS_COUNT"
    detail_line "Warn" "$VERIFY_WARN_COUNT" "$YW"
    detail_line "Fail" "$VERIFY_FAIL_COUNT" "$RD"
    detail_line "Verify log" "$VERIFY_LOG"
    detail_line "Display log" "$VERIFY_DISPLAY_LOG"
    echo ""
    group_heading "Next Step"
    echo -e "  ${YW}Run Script 7 to close bootstrap access and finish hardening.${CL}"
    echo ""
}

function show_ready_to_apply() {
    local apply_yn=""
    local cf_guard="not selected"
    local required_status=""

    section "SETUP PLAN"
    [[ "$DEPLOY_CF_COMPANION" =~ ^[Yy] ]] && cf_guard="ready"
    required_status="$(all_required_readiness_status)"

    group_heading "Script 6 dependency"
    plan_line "Status" "$SCRIPT6_PREFLIGHT_STATUS" "$(status_color_for_value "$SCRIPT6_PREFLIGHT_STATUS")"
    plan_line "Docker dir" "$DOCKER_DIR"
    plan_line "Compose dir" "$COMPOSE_DIR"
    plan_line "Domain" "$DOMAIN_VALUE"
    plan_line "Admin UI" "$ADMIN_UI_DISPLAY_NAME" "$GN"
    echo ""

    group_heading "Deployment"
    plan_line "Compose source" "$COMPOSE_SOURCE_LABEL"
    plan_line "Admin UI" "$ADMIN_UI_DISPLAY_NAME" "$GN"
    plan_line "Bootstrap access" "${ADMIN_UI_BOOTSTRAP_BIND}:${ADMIN_UI_BOOTSTRAP_PORT}" "$GN"
    plan_line "Stacks" "$(selected_stack_count)" "$GN"
    plan_line "Helpers" "$(helper_file_count)" "$GN"
    plan_line "Compose files" "$(compose_file_total_count)" "$GN"
    plan_line "Compose drift" "backup if changed"
    echo ""

    group_heading "Selected stacks"
    selected_stack_plan_list
    echo ""

    group_heading "Readiness"
    plan_line "Required checks" "$required_status" "$(status_color_for_value "$required_status")"
    plan_line "Optional htpasswd" "$SCRIPT6_HTPASSWD_STATUS" "$(status_color_for_value "$SCRIPT6_HTPASSWD_STATUS")"
    plan_line "ACME email" "${TRAEFIK_ACME_EMAIL_STATUS:-unknown}" "$(status_color_for_value "${TRAEFIK_ACME_EMAIL_STATUS:-unknown}")"
    echo ""

    group_heading "Safety"
    plan_line "Backups" "enabled"
    plan_line "cf-companion" "$cf_guard" "$(status_color_for_value "$cf_guard")"
    plan_line "Changes applied" "no" "$GN"
    echo ""

    echo -e "${YL}After confirmation, Script 6.5 will:${CL}"
    echo -e "  ${YW}create networks, install compose files,${CL}"
    echo -e "  ${YW}deploy selected stacks and verify routes.${CL}"
    echo ""

    apply_yn="$(timed_yes_no "Apply this Docker stack deployment plan now?" "y")"
    if [[ "$apply_yn" =~ ^[Nn] ]]; then
        echo -e "${YW}Docker stack deployment cancelled. No Docker/bootstrap-changing actions were applied.${CL}"
        exit 0
    fi
    return 0
}

function verify_existing_deployment_state() {
    apply_group_heading "Route checks"
    if docker_cmd network inspect socket_proxy >/dev/null 2>&1 && docker_cmd network inspect t2_proxy >/dev/null 2>&1 && docker_cmd network inspect database >/dev/null 2>&1; then NETWORKS_VERIFIED="yes"; NETWORKS_CREATED="yes"; msg_ok "Existing Docker networks verified"; else NETWORKS_VERIFIED="no"; msg_warn "One or more Docker networks are missing"; fi
    SOCKET_PROXY_SUBNET_ACTUAL="$(docker_cmd network inspect socket_proxy --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)"; T2_PROXY_SUBNET_ACTUAL="$(docker_cmd network inspect t2_proxy --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || true)"; DATABASE_NETWORK_NAME="$(docker_cmd network inspect database --format '{{.Name}}' 2>/dev/null || true)"
    if docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx 'socket-proxy'; then SOCKET_PROXY_DEPLOYED="yes"; msg_ok "Socket proxy running"; else SOCKET_PROXY_DEPLOYED="no"; msg_warn "Socket proxy is not running"; fi
    if docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx "$ADMIN_UI_SERVICE_NAME"; then ADMIN_UI_DEPLOYED="yes"; ADMIN_UI_VALIDATED="yes"; msg_ok "${ADMIN_UI_DISPLAY_NAME} running"; else ADMIN_UI_DEPLOYED="no"; msg_warn "${ADMIN_UI_DISPLAY_NAME} is not running"; fi
    detect_admin_ui_access_ip
}
function run_verify_only_mode() {
    verify_admin_ui_selection; validate_required_secret_files; validate_traefik_config_files_predeploy; verify_existing_deployment_state; create_verification_report; write_completion_marker; show_final_summary; exit 0
}
function run_apply_changes() {
    section "APPLY CHANGES"
    CURRENT_APPLY_GROUP=""
    APPLY_GROUPS_SHOWN=""
    create_shared_networks
    verify_shared_networks
    download_selected_compose_files
    verify_admin_ui_bootstrap_override_file
    verify_selected_compose_env_coverage
    validate_selected_compose_files
    prepare_postgres_runtime_prereqs
    prepare_redis_runtime_prereqs
    configure_bootstrap_firewall
    deploy_selected_stacks
    verify_bootstrap_containers
    verify_cf_companion_runtime_if_selected
    configure_authentik_and_verify_routes
    apply_group_heading "Marker / logs"
    create_verification_report
    write_completion_marker
}


function main() {
    init_script
    section "ENVIRONMENT CHECK"
    detect_docker_access
    validate_project_paths
    check_previous_marker
    if [ "$VERIFY_ONLY_MODE" == "yes" ]; then run_verify_only_mode; fi
    start_confirmation
    collect_bootstrap_settings
    verify_admin_ui_selection
    collect_stack_deployment_choices
    verify_selected_stack_preflight
    show_ready_to_apply
    run_apply_changes
    show_final_summary
    exit 0
}

main "$@"
