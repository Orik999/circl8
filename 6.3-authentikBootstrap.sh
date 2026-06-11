#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Project Circl8 - Script 6.3 Authentik Bootstrap Skeleton
# =========================================================
# Lane 2 only: hard gate, read-only preflight, UI flow,
# skeleton verify report scaffold, and no deployment.

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
SCRIPT_VERSION="v1.0.1"
SCRIPT_UPDATED="2026-06-11"
SCRIPT_BUILD="authentik-skeleton-marker-align"

# --- GLOBAL SETTINGS ---
T="15"
UI_LABEL_WIDTH="25"

SCRIPT62_MARKER="/root/.circl8-admin-ui-completed"
SCRIPT63_MARKER="/root/.circl8-authentik-completed"
SCRIPT63_BOOTSTRAP_CREDENTIALS_FILE="/root/.circl8-authentik-bootstrap-credentials"

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
SCRIPT63_VERIFY_STATUS="SKELETON"
SCRIPT63_DEPLOYMENT_STATUS="not-run"
SCRIPT63_MARKER_WRITTEN="no"

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
        ready|present|completed|PASS|yes|running|active|responsive|detected|configured|valid|SKELETON|fresh\ install|fresh-install|rerun/update|rerun-update|not\ written|not\ run|not-run|not\ used|planned|unchanged|stored\ root-only)
            printf '%s' "$GN"
            ;;
        warning|skipped|unknown|not\ detected|will\ install\ later|not\ present|not\ configured|reuse\ if\ present)
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
        echo "SCRIPT63_LANE=skeleton"
        echo "SCRIPT63_STATUS=not-deployed"
        echo "SCRIPT63_VERSION=${SCRIPT_VERSION}"
        echo "SCRIPT63_BUILD=${SCRIPT_BUILD}"
        echo "SCRIPT63_VERIFY_STATUS=${SCRIPT63_VERIFY_STATUS}"
        echo "SCRIPT63_DEPLOYMENT=${SCRIPT63_DEPLOYMENT_STATUS}"
        echo "SCRIPT63_MARKER_WRITTEN=${SCRIPT63_MARKER_WRITTEN}"
        echo "SCRIPT62_STATUS=${SCRIPT62_STATUS}"
        echo "SCRIPT62_VERIFY_STATUS=${SCRIPT62_VERIFY_STATUS}"
        echo "SCRIPT62_READY_FOR_SCRIPT63=${SCRIPT62_READY_FOR_SCRIPT63}"
        echo "SCRIPT63_SETUP_MODE=${SCRIPT63_SETUP_MODE}"
        echo "SCRIPT63_AUTHENTIK_EXISTING=${AUTHENTIK_EXISTING}"
        echo "SCRIPT63_AUTHENTIK_COMPOSE=${AUTHENTIK_COMPOSE_STATUS}"
        echo "SCRIPT63_TRAEFIK_AUTHENTIK_REFERENCES=${TRAEFIK_AUTHENTIK_REFERENCES}"
        echo "SCRIPT63_COMPLETION_MARKER_PATH=${SCRIPT63_MARKER}"
        echo "SCRIPT63_COMPLETION_MARKER_NOTE=not written in skeleton lane"
    } | write_text_root_file "$VERIFY_LOG"
}

function preserve_failure_log() {
    local reason="${1:-Authentik skeleton checks failed}"
    local ts=""
    ts="$(date +%Y%m%d-%H%M%S)"
    FAILURE_LOG="/var/log/circl8-authentik-deploy-failed-${ts}.log"
    {
        echo "$reason"
        [ -n "${DEPLOY_OUTPUT_LOG:-}" ] && [ -s "$DEPLOY_OUTPUT_LOG" ] && cat "$DEPLOY_OUTPUT_LOG"
    } | write_text_root_file "$FAILURE_LOG"
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
    preserve_failure_log "$message" || true
    write_verify_report || true
    echo -e "${CROSS} ${RD}${message}${CL}"
    echo -e "  ${BL}Verify log:${CL}  ${VERIFY_LOG}"
    echo -e "  ${BL}Failure log:${CL} ${FAILURE_LOG}"
    exit 1
}

# Placeholder for future lanes. Intentionally not called in lane 2.
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
#  AUTHENTIK PREFLIGHT / DETECTION
# =========================================================
function detect_authentik_compose() {
    local runtime_compose="${COMPOSE_DIR}/05-authentik-compose.yml"
    local repo_compose="./docker/05-authentik-compose.yml"

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
    aligned_status_line "PostgreSQL data" "planned"
    aligned_status_line "Redis" "not used"
    aligned_status_line "SMTP" "reuse if present"
    aligned_status_line "Embedded Outpost" "planned"
    aligned_status_line "Admin UI bootstrap" "unchanged"

    if [ "$TRAEFIK_DYNAMIC_STATUS" != "present" ] || [ "$TRAEFIK_AUTHENTIK_REFERENCES" != "ready" ]; then
        fail_with_verify_log "Runtime preflight failed."
    fi
}

# =========================================================
#  PLAN / CONFIRMATION / SKELETON CHECKS
# =========================================================
function show_setup_plan() {
    section "SETUP PLAN"

    if [ "$SCRIPT63_SETUP_MODE" == "rerun-update" ]; then
        echo -e "${YW}Rerun/update detected. Authentik data, database, and secrets will be preserved in later lanes.${CL}"
        echo -e "${YW}This lane only validates gates, preflight, and script flow.${CL}"
    else
        echo -e "${YW}Script 6.3 skeleton will validate gates and planning only.${CL}"
        echo -e "${YW}No deployment, folders, secrets, or completion marker will be written in this lane.${CL}"
    fi

    mini_header "Setup mode"
    aligned_status_line "Mode" "$SCRIPT63_SETUP_MODE"
    aligned_status_line "Existing Authentik" "$AUTHENTIK_EXISTING" "$(status_color_for_value "$AUTHENTIK_EXISTING")"
    aligned_status_line "Data/secrets" "$([ "$SCRIPT63_SETUP_MODE" == "rerun-update" ] && printf 'preserve in later lane' || printf 'planned for later lane')"
    aligned_status_line "Deployment" "$([ "$SCRIPT63_SETUP_MODE" == "rerun-update" ] && printf 'redeploy in later lane' || printf 'planned for later lane')"
    aligned_status_line "Provider/outpost" "$([ "$SCRIPT63_SETUP_MODE" == "rerun-update" ] && printf 'verify/update in later lane' || printf 'planned for later lane')"
    aligned_status_line "Completion marker" "not written"
}

function confirm_or_exit() {
    local answer=""
    echo ""
    answer="$(timed_yes_no_value_only "Apply this Authentik skeleton plan?" "y")"
    if [[ "$answer" =~ ^[Nn]$ ]]; then
        msg_ok "Authentik skeleton plan cancelled"
        exit 0
    fi
    tty_println "${CM} ${GN}Applying confirmed Authentik skeleton plan.${CL}"
}

function run_skeleton_checks() {
    section "PREPARE AUTHENTIK"

    mini_header "Skeleton checks"
    deploy_status_line "Script 6.2 handoff" "ready" "$GN"
    deploy_status_line "Runtime preflight" "ready" "$GN"
    deploy_status_line "Authentik mode" "$SCRIPT63_SETUP_MODE" "$GN"
    deploy_status_line "Compose availability" "$AUTHENTIK_COMPOSE_STATUS" "$(status_color_for_value "$AUTHENTIK_COMPOSE_STATUS")"
    deploy_status_line "Traefik prerequisites" "$TRAEFIK_AUTHENTIK_REFERENCES" "$(status_color_for_value "$TRAEFIK_AUTHENTIK_REFERENCES")"
    deploy_status_line "Completion marker" "not written" "$GN"

    if [ "$TRAEFIK_AUTHENTIK_REFERENCES" != "ready" ]; then
        fail_with_failure_log "Authentik skeleton checks failed."
    fi
}

function show_verification_marker_scaffold() {
    section "VERIFICATION / MARKER"
    write_verify_report
    deploy_status_line "Authentik skeleton report" "created" "$GN" 24
    deploy_status_line "Completion marker" "not written" "$GN" 24
}

function show_skeleton_finished() {
    section_flash_success "SKELETON COMPLETE"

    mini_header "Authentik"
    final_line "Status" "skeleton ready"
    final_line "Action" "$SCRIPT63_SETUP_MODE"
    [ "$SCRIPT63_SETUP_MODE" == "rerun-update" ] && final_line "Existing Authentik" "$AUTHENTIK_EXISTING"
    final_line "Compose file" "$AUTHENTIK_COMPOSE_STATUS" "$(status_color_for_value "$AUTHENTIK_COMPOSE_STATUS")"
    final_line "Database" "$([ "$SCRIPT63_SETUP_MODE" == "rerun-update" ] && printf 'PostgreSQL 17 preserve planned' || printf 'PostgreSQL 17 planned')"
    final_line "Redis" "not used"
    final_line "Embedded Outpost" "$([ "$SCRIPT63_SETUP_MODE" == "rerun-update" ] && printf 'verify/update planned' || printf 'planned')"
    final_line "Admin UI bootstrap" "unchanged"
    final_line "Deployment" "not run"
    final_line "Completion marker" "not written"

    mini_header "Verification"
    final_line "Status" "$SCRIPT63_VERIFY_STATUS"
    final_line "Verify log" "$VERIFY_LOG" "$BL"

    mini_header "Next Step"
    echo -e "${GN}Continue Script 6.3 implementation: secrets, env, and folder preparation.${CL}"
}

function main() {
    init_script
    validate_script62_handoff
    runtime_preflight
    detect_authentik_state
    show_authentik_preflight
    show_setup_plan
    confirm_or_exit
    run_skeleton_checks
    show_verification_marker_scaffold
    show_skeleton_finished
}

main "$@"
