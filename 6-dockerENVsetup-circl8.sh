#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Docker ENV Setup - Project circl8
# =========================================================

# --- 1. COLOR VARIABLES (KEEP ALL FOR FUTURE MODIFICATIONS) ---
# Central visual theme for Docker ENV Setup.
YW="$(printf '\033[33m')"
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

SCRIPT_SOURCE="6-dockerENVsetup-circl8.sh"
SCRIPT_VERSION="v1.7.4"
SCRIPT_UPDATED="2026-06-11"
SCRIPT_BUILD="htpasswd-secret-and-dashboard-label-cleanup"

# --- 2. GLOBAL VARIABLES ---
# Stores timers, defaults, paths, secret values, state flags and final result values.
T=15

LOG_FILE="/var/log/docker-env-setup.log"
RUNTIME_LOG_FILE=""
VERIFY_LOG="/var/log/docker-env-setup-verify.log"
VERIFY_DISPLAY_LOG="/var/log/docker-env-setup-verify-display.log"
VERIFY_ONLY_MODE="no"
VERIFY_STATUS="not-run"
VERIFY_PASS_COUNT="0"
VERIFY_WARN_COUNT="0"
VERIFY_FAIL_COUNT="0"
VERIFY_FIRST_ISSUE_TYPE=""
VERIFY_FIRST_ISSUE_CHECK=""
VERIFY_FIRST_ISSUE_REASON=""
VERIFY_FIRST_ISSUE_FIX=""
PERMISSION_AUDIT_STATUS="not-run"
COMPLETED_MARKER="/root/.docker-env-setup-completed"

DEFAULT_USER="${DEFAULT_USER:-${SUDO_USER:-${USER:-dockeradmin}}}"
DEFAULT_TZ="Europe/London"
DEFAULT_DOMAIN="${DEFAULT_DOMAIN:-example.com}"
DEFAULT_CF_API_EMAIL="${DEFAULT_CF_API_EMAIL:-}"
DEFAULT_CF_ZONE_ID=""
DEFAULT_HTPASSWD_USER="admin"
DEFAULT_ADMIN_UI="dockge"

SUDO_CMD=""
LOGGING_ENABLED="no"

DOCKER_USER=""
USERDIR=""
DOCKER_DIR=""
DOCKER_SECRETS_DIR=""
CF_API_TOKEN_FILE=""

PUID_VALUE=""
PGID_VALUE=""
TZ_VALUE=""
DOMAIN_VALUE=""
CF_API_EMAIL_VALUE=""
CF_ZONE_ID_VALUE=""
CF_API_TOKEN_VALUE=""
CF_AUTH_MODE=""
CF_EMAIL_REQUIRED=""
TRAEFIK_ACME_EMAIL_VALUE=""

EXISTING_SETUP="no"
REGENERATE_SECRETS="n"
DOCKER_READY="unknown"
DOCKER_COMPOSE_READY="unknown"
DOCKER_USER_IN_DOCKER_GROUP="unknown"
DOCKER_PREFLIGHT_USER=""
SCRIPT5_MARKER="/root/.docker-setup-completed"
SCRIPT5_VERIFY_LOG="/var/log/docker-setup-verify.log"
SCRIPT5_MARKER_STATE="missing"
SCRIPT5_VERIFY_LOG_STATE="missing"
SCRIPT5_VERIFY_STATUS="missing"
SCRIPT5_STATUS="missing"
SCRIPT5_VERSION="unknown"
SCRIPT5_BUILD="unknown"
SCRIPT5_TARGET_USER=""
SCRIPT5_DOCKER_INSTALLED="unknown"
SCRIPT5_DOCKER_SERVICE_ENABLED="unknown"
SCRIPT5_CONTAINERD_SERVICE_ENABLED="unknown"
SCRIPT5_SWAP_PRESERVE_SELECTED="unknown"
SCRIPT5_SWAP_RESULT="unknown"
SCRIPT5_SWAP_FILE="unknown"
SCRIPT5_SWAP_SIZE="unknown"
SCRIPT5_UFW_ENABLED="unknown"
SCRIPT5_REDIS_OVERCOMMIT="unknown"
SCRIPT5_SCRIPT4_CROWDSEC_SELECTED="unknown"
SCRIPT5_SCRIPT4_CROWDSEC_BOUNCER="unknown"
SCRIPT5_DOCKER_SERVICE_STATE="unknown"
SCRIPT5_CONTAINERD_SERVICE_STATE="unknown"
SCRIPT5_DOCKER_INFO_READY="unknown"
SCRIPT5_CROWDSEC_STATE="unknown"
SCRIPT5_CROWDSEC_BOUNCER_STATE="unknown"
SCRIPT5_CROWDSEC_BOUNCER_SUBSTATE="unknown"
SCRIPT6_CROWDSEC_BOUNCER_DISPLAY="unknown"
SCRIPT6_CROWDSEC_BOUNCER_RUNTIME="unknown"
SCRIPT35_MARKER="/root/.ubuntu-autoinstall-seed-completed"
PROXMOX_MARKER_STATE="missing"
PROXMOX_MARKER_SOURCE="no"
PROXMOX_MARKER_HOSTNAME=""
PROXMOX_MARKER_FQDN=""
PROXMOX_MARKER_DOMAIN=""
PROXMOX_MARKER_LAN_IP=""
PROXMOX_MARKER_LAN_URL=""

POSTGRES_PASSWORD=""
REDIS_PASSWORD=""
AUTHENTIK_SECRET_KEY=""
AUTHENTIK_POSTGRES_PASSWORD=""
POSTIZ_POSTGRES_PASSWORD=""
POSTIZ_REDIS_PASSWORD=""
POSTIZ_JWT_SECRET=""
TEMPORAL_POSTGRES_PASSWORD=""
N8N_ENCRYPTION_KEY=""
KOMODO_DB_PASSWORD=""
KOMODO_PASSKEY=""
KOMODO_JWT_SECRET=""
KOMODO_WEBHOOK_SECRET=""

ADMIN_UI="${DEFAULT_ADMIN_UI}"
ADMIN_UI_DISPLAY_NAME="Dockge"
ADMIN_UI_HOST=""
ADMIN_UI_URL=""

AUTHENTIK_HOST_VALUE=""
AUTHENTIK_ROUTE_HOST_VALUE=""
AUTHENTIK_EXTERNAL_URL_VALUE=""
AUTHENTIK_HOST_BROWSER_VALUE=""
AUTHENTIK_BOOTSTRAP_EMAIL_VALUE=""
AUTHENTIK_BOOTSTRAP_PASSWORD_VALUE=""
AUTHENTIK_BOOTSTRAP_PASSWORD_MODE="auto"
AUTHENTIK_BOOTSTRAP_TOKEN_VALUE=""
AUTHENTIK_BOOTSTRAP_TOKEN_MODE="auto"
AUTHENTIK_API_TOKEN_MODE="skip"
AUTHENTIK_API_TOKEN_VALUE=""
AUTHENTIK_EMAIL__HOST_VALUE=""
AUTHENTIK_EMAIL__PORT_VALUE=""
AUTHENTIK_EMAIL__USERNAME_VALUE=""
AUTHENTIK_EMAIL__PASSWORD_VALUE=""
AUTHENTIK_EMAIL__USE_TLS_VALUE=""
AUTHENTIK_EMAIL__USE_SSL_VALUE=""
AUTHENTIK_EMAIL__TIMEOUT_VALUE=""
AUTHENTIK_EMAIL__FROM_VALUE=""

HTPASSWD_MODE="empty"
HTPASSWD_USER_VALUE=""
HTPASSWD_PASSWORD_VALUE=""
HTPASSWD_HASH_VALUE=""
HTPASSWD_LINE_VALUE=""

SECRET_DISPLAY_WAS_SHOWN="no"
SECRET_SCREEN_CLEARED="no"

# Traefik template download defaults. These contain no secrets and can safely live in a public GitHub repo.
TRAEFIK_TEMPLATE_RAW_BASE="${TRAEFIK_TEMPLATE_RAW_BASE:-https://raw.githubusercontent.com/Orik999/circl8/refs/heads/main/docker/traefik}"
TRAEFIK_STATIC_TEMPLATE_URL="${TRAEFIK_STATIC_TEMPLATE_URL:-${TRAEFIK_TEMPLATE_RAW_BASE}/traefik.yml.template}"
TRAEFIK_DYNAMIC_TEMPLATE_URL="${TRAEFIK_DYNAMIC_TEMPLATE_URL:-${TRAEFIK_TEMPLATE_RAW_BASE}/dynamic-config.yml.template}"

TRAEFIK_DIR=""
TRAEFIK_ACME_DIR=""
TRAEFIK_STATIC_CONFIG_FILE=""
TRAEFIK_DYNAMIC_CONFIG_FILE=""
TRAEFIK_TEMPLATE_TMP_DIR=""

TRAEFIK_DASHBOARD_HOST=""
PROXMOX_ROUTE_ENABLED="n"
PROXMOX_PREFIX=""
PROXMOX_HOST=""
PROXMOX_URL=""
PROXMOX_URL_SOURCE="not-detected"
PROXMOX_ROUTE_SOURCE="not-configured"

TEMP_FILES=()
TEMP_DIRS=()
APPLY_CHANGES_SECTION_SHOWN="no"
APPLY_CURRENT_GROUP=""
SETUP_OPTIONS_SECTION_SHOWN="no"
SETUP_OPTIONS_CURRENT_GROUP=""
EXISTING_SETUP_SECTION_SHOWN="no"
EXISTING_SETUP_CURRENT_GROUP=""
MARKER_RERUN_SELECTED="no"
SCRIPT6_TRAEFIK_CONFIG_READY="no"
SCRIPT6_TRAEFIK_ACME_READY="no"
SCRIPT6_CF_TOKEN_FILE_READY="unknown"
SCRIPT6_ENV_FILE_READY="no"
SCRIPT6_SECRETS_READY="no"
SCRIPT6_READY_FOR_SCRIPT61="no"
SCRIPT6_READY_FOR_SCRIPT62="no"
SCRIPT6_READY_FOR_SCRIPT63="no"
SCRIPT6_READY_FOR_SCRIPT64="no"
SCRIPT6_READY_FOR_SCRIPT65="no"
SCRIPT6_READY_FOR_SCRIPT66="no"

# =========================================================
#  OUTPUT / LOGGING FUNCTIONS
# =========================================================

# --- 3. HEADER FUNCTION ---
# Displays the Docker ENV Setup banner.
function header_info {
echo -e "${BL}
  ███████╗ ███╗   ██╗ ██╗   ██╗    ███████╗ ███████╗ ████████╗ ██╗   ██╗ ██████╗
  ██╔════╝ ████╗  ██║ ██║   ██║    ██╔════╝ ██╔════╝ ╚══██╔══╝ ██║   ██║ ██╔══██╗
  █████╗   ██╔██╗ ██║ ██║   ██║    ███████╗ █████╗      ██║    ██║   ██║ ██████╔╝
  ██╔══╝   ██║╚██╗██║ ╚██╗ ██╔╝    ╚════██║ ██╔══╝      ██║    ██║   ██║ ██╔═══╝
  ███████╗ ██║ ╚████║  ╚████╔╝     ███████║ ███████╗    ██║    ╚██████╔╝ ██║
  ╚══════╝ ╚═╝  ╚═══╝   ╚═══╝      ╚══════╝ ╚══════╝    ╚═╝     ╚═════╝  ╚═╝
${CL}"
}

# --- 4. MESSAGE HELPER FUNCTIONS ---
# Provides consistent display -> apply -> success output style.
function msg_info() { echo -ne " ${HOLD} ${YW}$1...${CL}"; }
function msg_ok() { echo -e "${BFR} ${CM} ${GN}$1${CL}"; }
function msg_warn() { echo -e "${BFR} ${WARN} ${YW}$1${CL}"; }
function msg_skip() { echo -e "${BFR} - ${BL}INFO${CL} - ${YW}$1${CL}"; }
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
    echo ""
    echo -e "${BORDER}"
    echo -e "${BL}$1${CL}"
    echo -e "${BORDER}"
}

# --- 5A. FLASHING SUCCESS SECTION HEADER HELPER ---
# Uses the script 1-style final success section with bold flashing green text.
function section_flash_success() {
    echo ""
    echo -e "${BORDER}"
    echo -e "${GN}${CLF}$1${CL}"
    echo -e "${BORDER}"
}


function begin_setup_options_once() {
    if [ "$SETUP_OPTIONS_SECTION_SHOWN" != "yes" ]; then
        section "SETUP OPTIONS"
        SETUP_OPTIONS_SECTION_SHOWN="yes"
    fi
}

function setup_options_group_header() {
    local title="${1:-}"

    begin_setup_options_once

    if [ "${SETUP_OPTIONS_CURRENT_GROUP:-}" == "$title" ]; then
        return 0
    fi

    if [ -n "${SETUP_OPTIONS_CURRENT_GROUP:-}" ]; then
        echo ""
    fi

    SETUP_OPTIONS_CURRENT_GROUP="$title"
    echo -e "${YW}${title}:${CL}"
}

function begin_existing_setup_check_once() {
    if [ "$EXISTING_SETUP_SECTION_SHOWN" != "yes" ]; then
        section "EXISTING DOCKER ENV"
        EXISTING_SETUP_SECTION_SHOWN="yes"
    fi
}

function existing_setup_group_header() {
    local title="${1:-}"

    begin_existing_setup_check_once

    if [ "${EXISTING_SETUP_CURRENT_GROUP:-}" == "$title" ]; then
        return 0
    fi

    EXISTING_SETUP_CURRENT_GROUP="$title"
    echo ""
    echo -e "${YW}${title}:${CL}"
}

function begin_apply_changes_once() {
    if [ "$APPLY_CHANGES_SECTION_SHOWN" != "yes" ]; then
        section "APPLY CHANGES"
        APPLY_CHANGES_SECTION_SHOWN="yes"
    fi
}

function apply_group_header() {
    local title="${1:-}"

    begin_apply_changes_once

    if [ "${APPLY_CURRENT_GROUP:-}" == "$title" ]; then
        return 0
    fi

    if [ -n "${APPLY_CURRENT_GROUP:-}" ]; then
        echo ""
    fi

    APPLY_CURRENT_GROUP="$title"
    echo -e "${YW}${title}:${CL}"
}

# --- 5B. DETAIL LINE HELPER ---
# Prints clean script 1-style detail lines for summaries and audit output.
function detail_line() {
    local label="$1"
    local value="$2"
    echo -e "  ${BL}${label}:${CL} ${GN}${value}${CL}"
}

function final_line() {
    local label="$1"
    local value="${2:-not configured}"
    local value_color="${3:-$GN}"

    [ -n "$value" ] || value="not configured"
    printf '  %b%-24s%b %b%s%b\n' "${BL}" "${label}:" "${CL}" "${value_color}" "$value" "${CL}"
}

function https_url_or_not_configured() {
    local host="${1:-}"

    if [ -z "$host" ]; then
        printf 'not configured'
    elif [[ "$host" =~ ^https?:// ]]; then
        printf '%s' "$host"
    else
        printf 'https://%s' "$host"
    fi
}

function bare_host_from_url_or_host() {
    local value="${1:-}"

    value="${value#http://}"
    value="${value#https://}"
    value="${value%%/*}"
    value="${value%%\?*}"
    value="${value%%#*}"

    printf '%s' "$value"
}

function url_from_host_or_url() {
    local value="${1:-}"

    if [ -z "$value" ]; then
        printf ''
    elif [[ "$value" =~ ^https?:// ]]; then
        printf '%s' "$value"
    else
        printf 'https://%s' "$value"
    fi
}

function refresh_authentik_route_url_values() {
    local route_source="${AUTHENTIK_ROUTE_HOST_VALUE:-${AUTHENTIK_HOST:-}}"
    local external_source="${AUTHENTIK_EXTERNAL_URL_VALUE:-${AUTHENTIK_HOST_VALUE:-}}"
    local browser_source="${AUTHENTIK_HOST_BROWSER_VALUE:-}"

    [ -n "$route_source" ] || route_source="${external_source}"
    [ -n "$external_source" ] || external_source="${route_source}"

    AUTHENTIK_ROUTE_HOST_VALUE="$(bare_host_from_url_or_host "$route_source")"
    AUTHENTIK_EXTERNAL_URL_VALUE="$(url_from_host_or_url "$external_source")"

    [ -n "$AUTHENTIK_HOST_BROWSER_VALUE" ] || AUTHENTIK_HOST_BROWSER_VALUE="$browser_source"
    [ -n "$AUTHENTIK_HOST_BROWSER_VALUE" ] || AUTHENTIK_HOST_BROWSER_VALUE="$AUTHENTIK_EXTERNAL_URL_VALUE"
    AUTHENTIK_HOST_BROWSER_VALUE="$(url_from_host_or_url "$AUTHENTIK_HOST_BROWSER_VALUE")"

    AUTHENTIK_HOST_VALUE="$AUTHENTIK_EXTERNAL_URL_VALUE"
}

function lowercase_value() {
    printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

function trim_value() {
    local value="${1:-}"

    value="${value//$'\r'/}"
    value="${value//$'\n'/}"

    # Trim leading/trailing shell whitespace safely.
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "$value"
}

function strip_outer_quotes() {
    local value="${1:-}"

    value="$(trim_value "$value")"
    if [ "${#value}" -ge 2 ]; then
        local first="${value:0:1}"
        local last="${value: -1}"
        if { [ "$first" = '"' ] && [ "$last" = '"' ]; } || { [ "$first" = "'" ] && [ "$last" = "'" ]; }; then
            value="${value:1:${#value}-2}"
        fi
    fi

    trim_value "$value"
}

function marker_safe_value() {
    strip_outer_quotes "${1:-}"
}

function env_safe_value() {
    strip_outer_quotes "${1:-}"
}

function validate_subdomain_prefix() {
    local prefix="${1:-}"

    [ -n "$prefix" ] || return 1
    [[ "$prefix" != *.* ]] || return 1
    [[ "$prefix" != *://* ]] || return 1
    [[ "$prefix" != */* ]] || return 1
    [[ "$prefix" != *\?* ]] || return 1
    [[ "$prefix" != *#* ]] || return 1
    [[ "$prefix" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] || return 1

    return 0
}

function hostname_from_prefix() {
    local prefix="${1:-}"
    local domain="${2:-}"

    prefix="$(lowercase_value "$prefix")"
    domain="$(lowercase_value "$domain")"
    printf '%s.%s' "$prefix" "$domain"
}

function prefix_from_hostname() {
    local hostname="${1:-}"
    local domain="${2:-}"
    local fallback_prefix="${3:-}"
    local label="${4:-Service}"
    local bare=""
    local prefix=""

    fallback_prefix="$(lowercase_value "$fallback_prefix")"
    bare="$(bare_host_from_url_or_host "$hostname")"
    bare="$(lowercase_value "$bare")"
    domain="$(lowercase_value "$domain")"

    if [ -z "$bare" ]; then
        printf '%s' "$fallback_prefix"
        return 0
    fi

    if [ "$bare" == "$domain" ]; then
        printf '%s' "$fallback_prefix"
        return 0
    fi

    if [[ "$bare" == *."$domain" ]]; then
        prefix="${bare%.${domain}}"
        if validate_subdomain_prefix "$prefix"; then
            printf '%s' "$prefix"
            return 0
        fi
    fi

    msg_warn "Existing ${label} hostname is outside the configured domain and cannot be used in normal mode. Falling back to ${fallback_prefix}.${domain}."
    printf '%s' "$fallback_prefix"
    return 0
}

function prompt_subdomain_prefix() {
    local prompt="$1"
    local default_prefix="$2"
    local answer=""

    default_prefix="$(lowercase_value "$default_prefix")"

    while true; do
        answer="$(hostname_input "$prompt" "$default_prefix")"
        answer="$(lowercase_value "$(trim_value "$answer")")"

        if validate_subdomain_prefix "$answer"; then
            printf '%s' "$answer"
            return 0
        fi

        msg_warn "Invalid subdomain prefix. Use one DNS label only, for example: ${default_prefix}. Do not enter dots, URLs, paths, or leading/trailing hyphens."
    done
}

function status_color_for_value() {
    local value="${1:-unknown}"

    case "$value" in
        PASS|present|ready|yes|root|*" ready") printf '%s' "$GN" ;;
        PASS_WITH_WARNINGS|"partial setup detected") printf '%s' "$YW" ;;
        missing|unknown|FAIL|no|"not ready") printf '%s' "$RD" ;;
        *) printf '%s' "$GN" ;;
    esac
}

function aligned_status_line() {
    local label="$1"
    local value="${2:-unknown}"
    local value_color="${3:-}"
    local label_width="${4:-27}"

    [ -n "$value" ] || value="unknown"
    [ -n "$value_color" ] || value_color="$(status_color_for_value "$value")"
    printf '  %b%-*s%b %b%s%b\n' "$BL" "$label_width" "${label}:" "$CL" "$value_color" "$value" "$CL"
}

function aligned_value_line() {
    local label="$1"
    local value="${2:-not configured}"
    local value_color="${3:-$GN}"
    local label_width="${4:-18}"

    [ -n "$value" ] || value="not configured"
    printf '  %b%-*s%b %b%s%b\n' "$BL" "$label_width" "${label}:" "$CL" "$value_color" "$value" "$CL"
}

function aligned_check_line() {
    local label="$1"
    local value="${2:-}"
    local value_color="${3:-$ANS}"
    local label_width="${4:-18}"

    printf ' %b %b%-*s%b %b%s%b\n' "$CM" "$BL" "$label_width" "${label}:" "$CL" "$value_color" "$value" "$CL"
}

function compact_value_line() {
    local label="$1"
    local value="${2:-not configured}"
    local value_color="${3:-$GN}"

    [ -n "$value" ] || value="not configured"
    printf '  %b%s:%b %b%s%b\n' "$BL" "$label" "$CL" "$value_color" "$value" "$CL"
}

function apply_status_line() {
    local status="${1:-unknown}"

    # Compact apply status examples: Status: created | Status: generated | Status: reused | Status: regenerated | Status: written
    compact_value_line "Status" "$status" "$GN"
}

function permission_audit_line() {
    local prefix="$1"
    local path="$2"

    printf ' %b %b%-16s%b %b%s%b\n' "$CM" "$BL" "$prefix" "$CL" "$GN" "$path" "$CL"
}

function secret_generation_status_label() {
    if [ "$EXISTING_SETUP" == "yes" ]; then
        if [ "$REGENERATE_SECRETS" == "y" ]; then
            printf 'regenerated'
        else
            printf 'reused'
        fi
    else
        printf 'generated'
    fi
}

# --- 6. TTY PRINT HELPER ---
# Prints directly to terminal even when functions return values through stdout.
function tty_print() {
    if [ -w /dev/tty ]; then
        echo -ne "$*" > /dev/tty
    else
        echo -ne "$*" >&2
    fi
}

# --- 7. TTY PRINTLN HELPER ---
# Prints directly to terminal with newline.
function tty_println() {
    if [ -w /dev/tty ]; then
        echo -e "$*" > /dev/tty
    else
        echo -e "$*" >&2
    fi
}

# --- 7A. INPUT BUFFER FLUSH HELPER ---
# Clears only a small bounded amount of already-buffered terminal input.
# Important: this never reads from stdin, because streamed scripts may use stdin for the script body.
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

# --- 8. CLEANUP FUNCTION ---
# Removes temporary files created during execution.
function cleanup() {
    local exit_code="$?"
    local file=""

    # When running as a non-root user, logging is written to a temporary user-writable file first.
    # Copy it to /var/log at exit using sudo, then remove the temporary copy.
    if [ -n "${SUDO_CMD:-}" ] && [ -n "${RUNTIME_LOG_FILE:-}" ] && [ -s "$RUNTIME_LOG_FILE" ]; then
        "$SUDO_CMD" cp "$RUNTIME_LOG_FILE" "$LOG_FILE" 2>/dev/null || true
        "$SUDO_CMD" chmod 0644 "$LOG_FILE" 2>/dev/null || true
    fi

    for file in "${TEMP_FILES[@]:-}"; do
        [ -n "$file" ] && [ -f "$file" ] && rm -f "$file" 2>/dev/null || true
    done

    for file in "${TEMP_DIRS[@]:-}"; do
        [ -n "$file" ] && [ -d "$file" ] && rm -rf "$file" 2>/dev/null || true
    done

    exit "$exit_code"
}

# --- 9. ERROR TRAP HELPER ---
# Shows failing line number and points to the log file.
function on_error() {
    local line_no="$1"
    echo -e "${RD}ERROR:${CL} Script failed at line ${line_no}. Check ${LOG_FILE}"
}

# --- 10. COMMAND RUNNER ---
# Runs privileged commands quietly, but shows real stderr if they fail.
# Do not use this to print secret values.
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

# --- 11. OPTIONAL COMMAND RUNNER ---
# Runs non-critical privileged commands quietly and does not stop the script.
function run_optional() {
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" "$@" >/dev/null 2>&1 || true
    else
        "$@" >/dev/null 2>&1 || true
    fi
}

# --- 12. ROOT FILE WRITE HELPER ---
# Writes stdin to a privileged path with sudo when required.
# Heredoc content is not echoed to terminal, so this is safe for .env secret writing.
function write_root_file() {
    local path="$1"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" tee "$path" >/dev/null
    else
        cat > "$path"
    fi
}

# --- 13. ROOT PATH EXISTS HELPER ---
# Checks whether a root-owned path exists.
function root_path_exists() {
    local path="$1"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" test -e "$path"
    else
        test -e "$path"
    fi
}

# --- 14. ROOT FILE NOT EMPTY HELPER ---
# Checks whether a root-owned file exists and has content.
function root_file_not_empty() {
    local path="$1"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" test -s "$path"
    else
        test -s "$path"
    fi
}

# --- 15. ROOT FILE READ HELPER ---
# Reads root-owned file content for secret reuse.
# Do not call this unless assigning output into a variable.
function root_read_file() {
    local path="$1"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" cat "$path"
    else
        cat "$path"
    fi
}

# --- 16. ROOT STAT MODE HELPER ---
# Returns octal file mode for verification.
function root_stat_mode() {
    local path="$1"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" stat -c '%a' "$path" 2>/dev/null || true
    else
        stat -c '%a' "$path" 2>/dev/null || true
    fi
}

# --- 16A. SERVICE DIRECTORY CREATION HELPER ---
# Creates all service bind-mount directories first.
# Permission changes are intentionally done later in a separate chown stage and chmod stage.
function ensure_required_service_directories() {
    # Script 6 v1.7.0 owns only the neutral environment contract.
    # Runtime/app-specific bind mounts are created by Scripts 6.1-6.6 or Script 8.
    run_cmd "creating Docker root directory" mkdir -p "$DOCKER_DIR"
    run_cmd "creating Docker appdata directory" mkdir -p "${DOCKER_DIR}/appdata"
    run_cmd "creating Docker compose directory" mkdir -p "${DOCKER_DIR}/compose"
    run_cmd "creating Docker backups directory" mkdir -p "${DOCKER_DIR}/backups"
    run_cmd "creating Docker secrets directory" mkdir -p "$DOCKER_SECRETS_DIR"

    # Script 6 renders Traefik config for Script 6.1, so it owns these config paths.
    run_cmd "creating Traefik config directory" mkdir -p "$TRAEFIK_DIR"
    run_cmd "creating Traefik ACME directory" mkdir -p "$TRAEFIK_ACME_DIR"
    run_cmd "creating Traefik ACME storage" touch "${TRAEFIK_ACME_DIR}/acme.json"
}

function chown_required_service_directories() {
    run_cmd "setting Docker root directory ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$DOCKER_DIR"
    run_cmd "setting Docker appdata directory ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "${DOCKER_DIR}/appdata"
    run_cmd "setting compose directory ownership" chown -R "${DOCKER_USER}:${DOCKER_USER}" "${DOCKER_DIR}/compose"
    run_cmd "setting backups directory ownership" chown -R "${DOCKER_USER}:${DOCKER_USER}" "${DOCKER_DIR}/backups"
    run_cmd "setting secrets directory ownership" chown -R "${DOCKER_USER}:${DOCKER_USER}" "$DOCKER_SECRETS_DIR"
    run_cmd "setting Traefik ownership recursively" chown -R "${PUID_VALUE}:${PGID_VALUE}" "$TRAEFIK_DIR"
    run_cmd "setting .env ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "${DOCKER_DIR}/.env"
}

function chmod_required_service_directories() {
    run_cmd "setting Docker root directory mode" chmod 755 "$DOCKER_DIR"
    run_cmd "setting Docker appdata directory mode" chmod 755 "${DOCKER_DIR}/appdata"
    run_cmd "setting compose directory permissions recursively" chmod -R u+rwX,g+rwX,o-rwx "${DOCKER_DIR}/compose"
    run_cmd "setting backups directory permissions recursively" chmod -R u+rwX,g+rwX,o-rwx "${DOCKER_DIR}/backups"

    run_cmd "setting Traefik config directory mode" chmod 750 "$TRAEFIK_DIR"
    run_cmd "setting Traefik ACME directory mode" chmod 700 "$TRAEFIK_ACME_DIR"
    run_cmd "setting Traefik static config mode" chmod 644 "$TRAEFIK_STATIC_CONFIG_FILE"
    run_cmd "setting Traefik dynamic config mode" chmod 644 "$TRAEFIK_DYNAMIC_CONFIG_FILE"
    run_cmd "setting Traefik ACME storage mode" chmod 600 "${TRAEFIK_ACME_DIR}/acme.json"

    run_cmd "setting .env mode" chmod 600 "${DOCKER_DIR}/.env"
    run_cmd "setting secrets directory mode" chmod 700 "$DOCKER_SECRETS_DIR"

    if compgen -G "${DOCKER_SECRETS_DIR}/*" > /dev/null; then
        run_cmd "setting secret file modes" chmod 600 "${DOCKER_SECRETS_DIR}"/*
    fi
}

function detect_root_or_sudo() {
    if [ "$EUID" -eq 0 ]; then
        SUDO_CMD=""
    else
        SUDO_CMD="sudo"
    fi
}

# --- 18. SUDO VALIDATION ---
# Validates sudo once near the start so authentication failures happen before changes.
function validate_sudo_access() {
    if [ -n "$SUDO_CMD" ]; then
        msg_info "Validating sudo access"

        # First test the automation path created by script 3.5.
        # The Ubuntu autoinstall user is intentionally SSH-key-only and may not have a password.
        # sudo -n true confirms NOPASSWD sudo without ever prompting for a password.
        if "$SUDO_CMD" -n true >/dev/null 2>&1; then
            msg_ok "PASSWORDLESS SUDO CONFIRMED"
            return 0
        fi

        # Fallback for manually-created Ubuntu users that do have a normal sudo password.
        if "$SUDO_CMD" -v; then
            msg_ok "SUDO ACCESS CONFIRMED"
            return 0
        fi

        msg_error "Sudo authentication failed. Script cancelled."
    fi
}

# --- 19. LOGGING INITIALIZATION ---
# Starts tee logging while keeping original terminal descriptors available.
# When not root, logging goes to a temporary user-writable file first and is copied to /var/log during cleanup.
function init_logging() {
    exec 3>&1
    exec 4>&2

    if [ -n "$SUDO_CMD" ]; then
        # Avoid piping all interactive output through sudo tee.
        # Direct sudo tee can reorder /dev/tty prompts and make Enter appear inconsistent.
        RUNTIME_LOG_FILE="$(mktemp /tmp/docker-env-setup-log.XXXXXX)"
        TEMP_FILES+=("$RUNTIME_LOG_FILE")
        exec > >(tee -a "$RUNTIME_LOG_FILE") 2>&1
    else
        RUNTIME_LOG_FILE="$LOG_FILE"
        exec > >(tee -a "$LOG_FILE") 2>&1
    fi

    LOGGING_ENABLED="yes"
}

# --- 20. DISABLE LOGGING HELPER ---
# Sends output directly to the terminal, bypassing tee logging.
# Used for sensitive inputs and final secret display.
function disable_logging() {
    if [ -w /dev/tty ]; then
        exec > /dev/tty 2> /dev/tty
    else
        exec >&3 2>&4
    fi

    LOGGING_ENABLED="no"
}

# --- 21. ENABLE LOGGING HELPER ---
# Re-enables tee logging after sensitive terminal-only sections are complete.
function enable_logging() {
    if [ -n "$RUNTIME_LOG_FILE" ]; then
        exec > >(tee -a "$RUNTIME_LOG_FILE") 2>&1
    else
        exec > >(tee -a "$LOG_FILE") 2>&1
    fi

    LOGGING_ENABLED="yes"
}

# --- 22. CLEAR TERMINAL AND SCROLLBACK HELPER ---
# Clears visible terminal and scrollback where supported.
# This reduces the chance that displayed secrets remain visible after the user saves them.
function clear_terminal_scrollback() {
    if [ -w /dev/tty ]; then
        printf '\033[2J\033[3J\033[H' > /dev/tty
    else
        printf '\033[2J\033[3J\033[H'
    fi

    SECRET_SCREEN_CLEARED="yes"
}

# =========================================================
#  PROMPT FUNCTIONS
# =========================================================

# --- 23. YES/NO LABEL HELPER ---
# Converts Y/N answers to readable yes/no output.
function yes_no_label() {
    local value="$1"

    if [[ "$value" =~ ^[Yy]$ ]]; then
        echo "yes"
    else
        echo "no"
    fi
}

# --- 24. BLOCKING YES/NO HELPER ---
# Used when SPACE pauses a countdown and waits for Y/N/ENTER.
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

# --- 25. TIMED YES/NO PROMPT HELPER ---
# Uses wall-clock countdown.
# SPACE pauses and waits.
# Timeout accepts default.
# Final answer stays visible.
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
                    flush_input_buffer
                    break
                elif [[ -z "$key" ]]; then
                    answer="$default"
                    flush_input_buffer
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
                    flush_input_buffer
                    break
                elif [[ -z "$key" ]]; then
                    answer="$default"
                    flush_input_buffer
                    break
                fi
            fi
        fi
    done

    [ -z "$answer" ] && answer="$default"
    final_label="$(yes_no_label "$answer")"

    tty_print "${BFR}"
    if [ "${SUPPRESS_TIMED_YES_NO_CONFIRMATION:-no}" != "yes" ]; then
        tty_println "${CM} ${GN}${prompt}${CL} ${ANS}${final_label}${CL}"
    fi
    flush_input_buffer

    echo "$answer"
}

# --- 26. EDITABLE INPUT LOOP HELPER ---
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

# --- 27. TIMED TEXT INPUT HELPER ---
# Shows wall-clock countdown.
# SPACE pauses with empty editable buffer.
# Any typed character pauses with that character already inside the editable buffer.
function timed_text_input() {
    local prompt="$1"
    local default="$2"
    local answer=""

    # Text/path/name/domain/number/token-style prompts are deliberately NOT timed.
    # Countdown prompts are reserved only for simple Y/n decisions.
    answer="$(editable_input_loop "$prompt" "$default" "")"
    [ -z "$answer" ] && answer="$default"

    tty_print "${BFR}"
    if [ "${SUPPRESS_TEXT_INPUT_CONFIRMATION:-no}" != "yes" ]; then
        tty_println "${CM} ${GN}${prompt}${CL} ${ANS}${answer}${CL}"
    fi
    flush_input_buffer 2>/dev/null || true

    echo "$answer"
}

# --- 27B. NON-TIMED TEXT INPUT HELPER ---
# Uses editable_input_loop without a countdown for plain text fields.
function text_input() {
    local prompt="$1"
    local default="$2"
    local answer=""

    answer="$(editable_input_loop "$prompt" "$default" "")"
    [ -z "$answer" ] && answer="$default"
    if [ "${SUPPRESS_TEXT_INPUT_CONFIRMATION:-no}" != "yes" ]; then
        tty_println "${CM} ${GN}${prompt}${CL} ${ANS}${answer}${CL}"
    fi
    echo "$answer"
}

# --- 27A. ROBUST NUMERIC MENU INPUT HELPER ---
# Reads one full line from /dev/tty for numbered menus.
# This avoids the editable character-by-character path and prevents arrow-key escape residue from becoming repeated errors.
function numeric_menu_input() {
    local prompt="$1"
    local default="$2"
    local min_choice="$3"
    local max_choice="$4"
    local raw_choice=""
    local choice=""

    while true; do
        flush_input_buffer 2>/dev/null || true
        tty_print "${YW}${prompt} [default: ${default}]: ${CL}"

        if [ -r /dev/tty ]; then
            IFS= read -r raw_choice < /dev/tty || raw_choice=""
        else
            IFS= read -r raw_choice || raw_choice=""
        fi

        # Clear the prompt/value line after ENTER; caller-specific confirmations remain visible.
        tty_print $'\033[1A\r\033[2K'

        raw_choice="$(printf '%s' "$raw_choice" | tr -d '\r\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

        if [ -z "$raw_choice" ]; then
            choice="$default"
        else
            choice="$(printf '%s' "$raw_choice" | tr -cd '0-9')"
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge "$min_choice" ] && [ "$choice" -le "$max_choice" ]; then
            echo "$choice"
            return 0
        fi

        tty_println "${WARN} ${YW}Invalid selection. Choose ${min_choice}-${max_choice}.${CL}"
    done
}
# --- 27A. UNTIMED MENU INPUT HELPER ---
# Compatibility wrapper for numbered menus.
function untimed_menu_input() {
    numeric_menu_input "$1" "$2" "1" "9"
}

# --- 27B. NON-TIMED HOSTNAME INPUT HELPER ---
# Uses editable_input_loop directly to guarantee no countdown/timer is shown
function hostname_input() {
    local prompt="$1"
    local default="$2"
    local answer=""

    answer="$(editable_input_loop "$prompt" "$default" "")"
    [ -z "$answer" ] && answer="$default"
    if [ "${SUPPRESS_TEXT_INPUT_CONFIRMATION:-no}" != "yes" ]; then
        tty_println "${CM} ${GN}${prompt}${CL} ${ANS}${answer}${CL}"
    fi
    echo "$answer"
}


# --- 28. HIDDEN INPUT HELPER ---
# Reads sensitive input without echoing it to terminal.
# Call this while logging is disabled.
function hidden_input() {
    local prompt="$1"
    local answer=""

    tty_print "${YW}${prompt}: ${CL}"

    if [ -r /dev/tty ]; then
        IFS= read -rs answer < /dev/tty || true
    else
        IFS= read -rs answer || true
    fi

    tty_println ""

    echo "$answer"
}

# --- 28A. SENSITIVE LINE INPUT HELPER ---
# Reads one sensitive pasted line directly from /dev/tty and clears the visible prompt/token line immediately after ENTER.
# The value is returned through stdout for command substitution only; prompt/token text is printed only to /dev/tty.
# Do not call flush_input_buffer here because it can consume pasted token characters.
function sensitive_line_input() {
    sensitive_visible_line_input "$1" "${2:-}"
}

# --- 28B. VISIBLE SENSITIVE LINE INPUT HELPER ---
# Shows pasted/typed private values while entering, clears the raw line after ENTER, then prints a non-sensitive confirmation.
# The captured value is returned through stdout only for assignment. Do not call flush_input_buffer here; it can consume pasted tokens.
function sensitive_visible_line_input() {
    local prompt="$1"
    local confirmation_label="${2:-}"
    local answer=""
    local cols="80"
    local visible_len="0"
    local lines_to_clear="1"
    local i=""

    tty_print "${YW}${prompt}: ${CL}"

    if [ -r /dev/tty ]; then
        IFS= read -r answer < /dev/tty || answer=""
    else
        IFS= read -r answer || answer=""
    fi

    cols="$(tput cols 2>/dev/null || echo 80)"
    [[ "$cols" =~ ^[0-9]+$ ]] || cols="80"
    [ "$cols" -lt 20 ] && cols="80"

    visible_len=$(( ${#prompt} + 2 + ${#answer} ))
    lines_to_clear=$(( (visible_len + cols - 1) / cols ))
    [ "$lines_to_clear" -lt 1 ] && lines_to_clear="1"

    for ((i=0; i<lines_to_clear; i++)); do
        tty_print $'\033[1A\r\033[2K'
    done

    if [ -n "$confirmation_label" ]; then
        tty_println "${CM} ${GN}${confirmation_label}${CL}"
    fi

    printf '%s' "$answer"
}

# --- 29. SECRET SAVE CONFIRMATION HELPER ---
# Waits until the user confirms they saved displayed secrets, then clears terminal/scrollback.
function wait_then_clear_secret_display() {
    echo ""
    echo -e "${RD}${CLF}Save the secrets above now.${CL}"
    echo -e "${YW}After pressing ENTER, this screen and terminal scrollback will be cleared where supported.${CL}"
    echo ""

    if [ -r /dev/tty ]; then
        read -r -p "Press ENTER after you have saved the secrets securely..." _ < /dev/tty || true
    else
        read -r -p "Press ENTER after you have saved the secrets securely..." _ || true
    fi

    clear_terminal_scrollback
}

# =========================================================
#  VALIDATION HELPERS
# =========================================================

# --- 30. USERNAME VALIDATION HELPER ---
# Validates Linux username format.
function validate_linux_username() {
    local username="$1"

    if [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        return 0
    fi

    return 1
}

# --- 31. ABSOLUTE PATH VALIDATION HELPER ---
# Validates an absolute path and blocks unsafe top-level paths.
function validate_absolute_path() {
    local path="$1"

    if [[ "$path" != /* ]]; then
        return 1
    fi

    case "$path" in
        "/"|"/root"|"/etc"|"/usr"|"/var"|"/home")
            return 1
            ;;
    esac

    return 0
}

# --- 32. DOMAIN VALIDATION HELPER ---
# Validates domain-style value without protocol or slash.
function validate_domain() {
    local domain="$1"

    if [[ "$domain" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]]; then
        return 0
    fi

    return 1
}

function validate_ipv4() {
    local ip="$1"
    local a="" b="" c="" d=""

    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r a b c d <<< "$ip"

    for octet in "$a" "$b" "$c" "$d"; do
        [[ "$octet" =~ ^[0-9]+$ ]] || return 1
        [ "$octet" -ge 0 ] && [ "$octet" -le 255 ] || return 1
    done

    return 0
}

function validate_proxmox_lan_url() {
    local url="${1:-}"
    local host=""

    [[ "$url" =~ ^https?://[^/[:space:]]+:8006/?$ ]] || return 1
    host="${url#http://}"
    host="${host#https://}"
    host="${host%%:*}"
    validate_ipv4 "$host" || return 1
    return 0
}

function derive_domain_from_fqdn() {
    local fqdn="${1:-}"

    if validate_domain "$fqdn"; then
        printf '%s' "${fqdn#*.}"
    fi
}

function script35_marker_key_value() {
    local key="$1"
    local value=""

    if root_path_exists "$SCRIPT35_MARKER"; then
        value="$(marker_safe_value "$(root_read_file "$SCRIPT35_MARKER" 2>/dev/null | awk -F= -v key="$key" '$1 == key { $1=""; sub(/^=/, ""); print; exit }')")"
    fi

    printf '%s' "$value"
}

function load_script35_proxmox_marker() {
    local derived_domain=""

    if ! root_path_exists "$SCRIPT35_MARKER"; then
        PROXMOX_MARKER_STATE="missing"
        PROXMOX_MARKER_SOURCE="no"
        return 0
    fi

    PROXMOX_MARKER_STATE="present"
    PROXMOX_MARKER_HOSTNAME="$(script35_marker_key_value "PROXMOX_HOSTNAME")"
    PROXMOX_MARKER_FQDN="$(script35_marker_key_value "PROXMOX_FQDN")"
    PROXMOX_MARKER_DOMAIN="$(script35_marker_key_value "PROXMOX_DOMAIN")"
    PROXMOX_MARKER_LAN_IP="$(script35_marker_key_value "PROXMOX_LAN_IP")"
    PROXMOX_MARKER_LAN_URL="$(script35_marker_key_value "PROXMOX_LAN_URL")"

    validate_subdomain_prefix "$PROXMOX_MARKER_HOSTNAME" || PROXMOX_MARKER_HOSTNAME=""
    validate_domain "$PROXMOX_MARKER_FQDN" || PROXMOX_MARKER_FQDN=""
    validate_domain "$PROXMOX_MARKER_DOMAIN" || PROXMOX_MARKER_DOMAIN=""
    validate_ipv4 "$PROXMOX_MARKER_LAN_IP" || PROXMOX_MARKER_LAN_IP=""
    validate_proxmox_lan_url "$PROXMOX_MARKER_LAN_URL" || PROXMOX_MARKER_LAN_URL=""

    if [ -z "$PROXMOX_MARKER_DOMAIN" ] && [ -n "$PROXMOX_MARKER_FQDN" ]; then
        derived_domain="$(derive_domain_from_fqdn "$PROXMOX_MARKER_FQDN")"
        validate_domain "$derived_domain" && PROXMOX_MARKER_DOMAIN="$derived_domain"
    fi

    if [ -n "$PROXMOX_MARKER_HOSTNAME" ] || [ -n "$PROXMOX_MARKER_FQDN" ] || [ -n "$PROXMOX_MARKER_DOMAIN" ] || [ -n "$PROXMOX_MARKER_LAN_IP" ] || [ -n "$PROXMOX_MARKER_LAN_URL" ]; then
        PROXMOX_MARKER_SOURCE="yes"
    else
        PROXMOX_MARKER_SOURCE="no"
    fi

    return 0
}

# --- 33. EMAIL VALIDATION HELPER ---
# Simple email format validation for Cloudflare email.
function validate_email() {
    local email="$1"

    if [[ "$email" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
        return 0
    fi

    return 1
}

# --- 34. CLOUDFLARE ZONE ID VALIDATION HELPER ---
# Allows empty value, otherwise expects a hex-like Cloudflare zone ID.
function validate_cf_zone_id() {
    local zone_id="$1"

    if [ -z "$zone_id" ]; then
        return 0
    fi

    if [[ "$zone_id" =~ ^[A-Fa-f0-9]{16,64}$ ]]; then
        return 0
    fi

    return 1
}

# --- 35. HTPASSWD LINE VALIDATION HELPER ---
# Validates that provided htpasswd line looks like username:hash.
function normalize_htpasswd_line() {
    local line="${1:-}"

    line="$(printf '%s' "$line" | tr -d '\r\n')"
    # htpasswd files mounted into Traefik must contain literal dollar signs.
    # Docker Compose label escaping ($$) is not valid inside usersFile content.
    line="${line//\$\$/\$}"

    printf '%s' "$line"
}

function validate_htpasswd_line() {
    local line="$1"

    if [[ "$line" =~ ^[^:[:space:]]+:.+ ]]; then
        return 0
    fi

    return 1
}

function htpasswd_hash_prefix_status() {
    local line="${1:-}"
    local hash=""

    validate_htpasswd_line "$line" || { printf 'invalid'; return 0; }
    hash="${line#*:}"

    case "$hash" in
        \$\$apr1*|\$\$2a*|\$\$2b*|\$\$2y*) printf 'escaped-dollar';;
        \$apr1\$*|\$2a\$*|\$2b\$*|\$2y\$*|\$6\$*) printf 'known';;
        *) printf 'unknown';;
    esac
}

function validate_htpasswd_secret_file_shape() {
    local path="${DOCKER_SECRETS_DIR}/htpasswd"
    local raw_line=""
    local line=""
    local prefix_status=""

    root_path_exists "$path" || msg_error "htpasswd secret file was not created."

    if ! root_file_not_empty "$path"; then
        msg_warn "htpasswd secret file is empty; Basic Auth fallback remains disabled until a valid htpasswd entry is added."
        return 0
    fi

    raw_line="$(root_read_file "$path" 2>/dev/null | head -n1 || true)"
    prefix_status="$(htpasswd_hash_prefix_status "$raw_line")"
    if [ "$prefix_status" = "escaped-dollar" ]; then
        msg_error "htpasswd secret still contains escaped-dollar hash prefix. Use literal-dollar htpasswd file content."
    fi
    line="$(normalize_htpasswd_line "$raw_line")"

    if ! validate_htpasswd_line "$line"; then
        msg_error "htpasswd secret shape is invalid. Expected username:hash. The hash was not displayed."
    fi

    prefix_status="$(htpasswd_hash_prefix_status "$line")"
    case "$prefix_status" in
        escaped-dollar)
            msg_error "htpasswd secret still contains escaped-dollar hash prefix. Use literal-dollar htpasswd file content."
            ;;
        known)
            msg_ok "htpasswd secret shape verified"
            ;;
        *)
            msg_warn "htpasswd secret uses an unknown hash prefix; shape is username:hash and content was not displayed."
            ;;
    esac
}

# --- 36. DEPENDENCY VALIDATION ---
# Validates required commands early so failures happen before partial file creation.
function validate_dependencies() {
    local required_commands=(
        awk
        cat
        chmod
        clear
        chown
        command
        cut
        date
        grep
        id
        mkdir
        mktemp
        openssl
        rm
        sed
        stat
        tee
        test
        touch
        tput
        tr
    )

    local cmd=""

    for cmd in "${required_commands[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || msg_error "Required command not found: ${cmd}"
    done

    if [ -n "$SUDO_CMD" ]; then
        command -v sudo >/dev/null 2>&1 || msg_error "sudo is required when not running as root."
    fi

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        msg_error "Either curl or wget is required to download Traefik template files."
    fi
}

# =========================================================
#  SECRET HELPERS
# =========================================================

# --- 37. SECRET GENERATOR HELPER ---
# Generates hex-only secrets. Hex avoids shell/YAML/SQL quoting problems.
function generate_secret() {
    openssl rand -hex 32 | cut -c1-48
}

# --- 38. SECRET REUSE / GENERATION HELPER ---
# Reuses existing secret files by default on reruns.
# Generates a new value only when missing or when regeneration is selected.
function get_or_generate_secret() {
    local file="$1"

    if [ "$REGENERATE_SECRETS" != "y" ] && root_file_not_empty "$file"; then
        root_read_file "$file"
    else
        generate_secret
    fi
}

# --- 39. NO-NEWLINE SECRET WRITE HELPER ---
# Writes secret files without trailing newline.
# This is intentional for file-based secrets.
function write_secret_file_no_newline() {
    local path="$1"
    local value="$2"

    if [ -n "$SUDO_CMD" ]; then
        printf '%s' "$value" | "$SUDO_CMD" tee "$path" >/dev/null
    else
        printf '%s' "$value" > "$path"
    fi
}

# --- 39A. DOWNLOAD FILE HELPER ---
# Downloads a public template file to a temporary path without printing its content.
# Uses curl when available and falls back to wget.
function download_file() {
    local url="$1"
    local dest="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    else
        wget -qO "$dest" "$url"
    fi
}


# --- 39B.1. PRIMARY IPV4 DETECTION HELPER ---
# Detects the current machine's primary IPv4 address for network-context display.
function detect_primary_ipv4() {
    local ip_addr=""

    if command -v ip >/dev/null 2>&1; then
        ip_addr="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}' || true)"
    fi

    if [ -z "$ip_addr" ] && command -v hostname >/dev/null 2>&1; then
        ip_addr="$(hostname -I 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+\./) {print $i; exit}}' || true)"
    fi

    printf '%s' "$ip_addr"
    return 0
}

# --- 39B.2. DEFAULT GATEWAY DETECTION HELPER ---
# Detects the default gateway for display only. It is not assumed to be Proxmox.
function detect_default_gateway_ipv4() {
    local gateway=""

    if command -v ip >/dev/null 2>&1; then
        gateway="$(ip -4 route show default 2>/dev/null | awk '{print $3; exit}' || true)"
    fi

    printf '%s' "$gateway"
    return 0
}

# --- 39B.2A. PROXMOX HTTPS PROBE HELPER ---
# Checks whether a candidate IP appears to be a Proxmox VE web UI on port 8006.
function probe_proxmox_ip() {
    local candidate_ip="$1"
    local probe_output=""

    [[ "$candidate_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1

    if command -v curl >/dev/null 2>&1; then
        probe_output="$(curl -kfsS --connect-timeout 0.35 --max-time 1.2 "https://${candidate_ip}:8006/" 2>/dev/null | head -c 4096 || true)"
    elif command -v wget >/dev/null 2>&1; then
        probe_output="$(timeout 2 wget --no-check-certificate -qO- "https://${candidate_ip}:8006/" 2>/dev/null | head -c 4096 || true)"
    fi

    if grep -Eiq 'proxmox|pve|Proxmox Virtual Environment' <<< "$probe_output"; then
        printf 'https://%s:8006' "$candidate_ip"
        return 0
    fi

    return 1
}

# --- 39B.2B. LOCAL SUBNET PROXMOX DISCOVERY HELPER ---
# Attempts to find Proxmox from inside the Ubuntu VM without assuming the default gateway is Proxmox.
# As soon as a verified Proxmox host is found, this function returns immediately and skips remaining scans.
function discover_proxmox_url_from_lan() {
    local primary_ip=""
    local prefix=""
    local candidate=""
    local found_url=""
    local host=""
    local resolved_ip=""
    local octet=""

    if command -v getent >/dev/null 2>&1; then
        for host in pve2 pve proxmox proxmox.local pve2.local pve.local; do
            resolved_ip="$(getent hosts "$host" 2>/dev/null | awk '{print $1; exit}' || true)"
            if [[ "$resolved_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                if found_url="$(probe_proxmox_ip "$resolved_ip")"; then
                    printf '%s' "$found_url"
                    return 0
                fi
            fi
        done
    fi

    if command -v ip >/dev/null 2>&1; then
        while IFS= read -r candidate; do
            if [[ "$candidate" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                if found_url="$(probe_proxmox_ip "$candidate")"; then
                    printf '%s' "$found_url"
                    return 0
                fi
            fi
        done < <(ip -4 neigh show 2>/dev/null | awk '{print $1}' | sort -u || true)
    fi

    primary_ip="$(detect_primary_ipv4)"
    if [[ "$primary_ip" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.[0-9]+$ ]]; then
        prefix="${BASH_REMATCH[1]}"

        for octet in 10 11 2 3 5 20 50 100 101 102 156 200 1; do
            candidate="${prefix}.${octet}"
            [ "$candidate" = "$primary_ip" ] && continue
            if found_url="$(probe_proxmox_ip "$candidate")"; then
                printf '%s' "$found_url"
                return 0
            fi
        done

        for octet in $(seq 2 254); do
            candidate="${prefix}.${octet}"
            [ "$candidate" = "$primary_ip" ] && continue
            if found_url="$(probe_proxmox_ip "$candidate")"; then
                printf '%s' "$found_url"
                return 0
            fi
        done
    fi

    printf ''
    return 0
}

# --- 39B.3. PROXMOX URL DEFAULT DETECTION HELPER ---
# Builds the Proxmox internal URL default without hardcoding a fake static IP.
function detect_proxmox_internal_url_default() {
    local existing_env_url=""
    local discovered_url=""

    if [ -n "${PROXMOX_URL_DEFAULT:-}" ] && validate_proxmox_lan_url "$PROXMOX_URL_DEFAULT"; then
        PROXMOX_URL_SOURCE="environment"
        printf '%s' "$PROXMOX_URL_DEFAULT"
        return 0
    fi

    if [ -n "${PROXMOX_URL:-}" ] && validate_proxmox_lan_url "$PROXMOX_URL"; then
        PROXMOX_URL_SOURCE="existing"
        printf '%s' "$PROXMOX_URL"
        return 0
    fi

    if [ -n "${DOCKER_DIR:-}" ] && [ -f "${DOCKER_DIR}/.env" ]; then
        existing_env_url="$(read_existing_env_value "PROXMOX_URL")"
        if [ -n "$existing_env_url" ] && validate_proxmox_lan_url "$existing_env_url"; then
            PROXMOX_URL_SOURCE="existing-env"
            printf '%s' "$existing_env_url"
            return 0
        fi
    fi

    if [ -n "${PROXMOX_MARKER_LAN_URL:-}" ] && validate_proxmox_lan_url "$PROXMOX_MARKER_LAN_URL"; then
        PROXMOX_URL_SOURCE="marker"
        printf '%s' "$PROXMOX_MARKER_LAN_URL"
        return 0
    fi

    if [ -n "${PROXMOX_MARKER_LAN_IP:-}" ] && validate_ipv4 "$PROXMOX_MARKER_LAN_IP"; then
        PROXMOX_URL_SOURCE="marker"
        printf 'https://%s:8006' "$PROXMOX_MARKER_LAN_IP"
        return 0
    fi

    discovered_url="$(discover_proxmox_url_from_lan || true)"
    if [ -n "$discovered_url" ] && validate_proxmox_lan_url "$discovered_url"; then
        PROXMOX_URL_SOURCE="discovered"
        printf '%s' "$discovered_url"
        return 0
    fi

    PROXMOX_URL_SOURCE="not-detected"
    printf ''
    return 0
}

function proxmox_domain_default() {
    local existing_domain=""
    local derived_domain=""

    existing_domain="$(read_existing_env_value "DOMAIN")"
    if validate_domain "$existing_domain"; then
        printf '%s' "$existing_domain"
        return 0
    fi

    if validate_domain "${PROXMOX_MARKER_DOMAIN:-}"; then
        printf '%s' "$PROXMOX_MARKER_DOMAIN"
        return 0
    fi

    if validate_domain "${PROXMOX_MARKER_FQDN:-}"; then
        derived_domain="$(derive_domain_from_fqdn "$PROXMOX_MARKER_FQDN")"
        if validate_domain "$derived_domain"; then
            printf '%s' "$derived_domain"
            return 0
        fi
    fi

    printf '%s' "$DEFAULT_DOMAIN"
}

function proxmox_prefix_default() {
    local existing_host=""
    local marker_prefix=""
    local fqdn_prefix=""

    existing_host="$(read_existing_env_value "PROXMOX_HOST")"
    if [ -n "$existing_host" ]; then
        marker_prefix="$(prefix_from_hostname "$existing_host" "$DOMAIN_VALUE" "" "Proxmox")"
        if validate_subdomain_prefix "$marker_prefix"; then
            printf '%s' "$marker_prefix"
            return 0
        fi
    fi

    if validate_subdomain_prefix "${PROXMOX_MARKER_HOSTNAME:-}"; then
        printf '%s' "$PROXMOX_MARKER_HOSTNAME"
        return 0
    fi

    if [ -n "${PROXMOX_MARKER_FQDN:-}" ]; then
        fqdn_prefix="$(prefix_from_hostname "$PROXMOX_MARKER_FQDN" "$DOMAIN_VALUE" "" "Proxmox")"
        if validate_subdomain_prefix "$fqdn_prefix"; then
            printf '%s' "$fqdn_prefix"
            return 0
        fi
    fi

    printf 'proxmox'
}

# --- 39B. TRAEFIK TEMPLATE RENDER HELPER ---
# Replaces public-safe placeholders in downloaded Traefik templates.
# Secret values are never embedded into Traefik config files.
# Cloudflare and htpasswd credentials remain file-based Docker secrets.
function render_traefik_template() {
    local src="$1"
    local dest="$2"
    local content=""
    local proxmox_block=""

    content="$(cat "$src")"
    proxmox_block="$(build_proxmox_route_block)"

    validate_email "${TRAEFIK_ACME_EMAIL_VALUE:-}" || msg_error "Traefik ACME email is missing or invalid. Re-run Script 6 email setup."

    content="${content//\{\{DOCKER_DIR\}\}/$DOCKER_DIR}"
    content="${content//\{\{DOMAIN\}\}/$DOMAIN_VALUE}"
    content="${content//\{\{CF_API_EMAIL\}\}/$CF_API_EMAIL_VALUE}"
    content="${content//\{\{TRAEFIK_DASHBOARD_HOST\}\}/$TRAEFIK_DASHBOARD_HOST}"
    content="${content//\{\{TRAEFIK_ACME_EMAIL\}\}/$TRAEFIK_ACME_EMAIL_VALUE}"
    content="${content//\{\{CF_API_TOKEN_SECRET_PATH\}\}//run/secrets/cf_api_token}"
    content="${content//\{\{HTPASSWD_SECRET_PATH\}\}//run/secrets/htpasswd}"
    content="${content//\{\{PROXMOX_ROUTE_BLOCK\}\}/$proxmox_block}"

    if grep -q '{{CF_API_TOKEN\|{{CLOUDFLARE_API_TOKEN' <<< "$content"; then
        msg_error "Traefik template contains a raw token placeholder. Use file-based token placeholders only."
    fi

    printf '%s\n' "$content" | write_root_file "$dest"
}

# --- 39C. TRAEFIK DYNAMIC ROUTER BLOCK HELPER ---
# Builds only the optional Proxmox file-provider router/service/transport block.
# The Traefik dashboard router is defined directly in dynamic-config.yml.template.
# Proxmox routing is disabled by default and only generated when explicitly selected.
function build_proxmox_route_block() {
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
  # Only Proxmox gets insecureSkipVerify because Proxmox commonly uses a self-signed local cert.
  # Do not use global insecureSkipVerify.
  serversTransports:
    proxmoxTransport:
      insecureSkipVerify: true
EOF
}

# =========================================================
#  INITIALIZATION
# =========================================================

# --- 40. SCRIPT INITIALIZATION ---
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
    load_script35_proxmox_marker
}

# --- 41. PREVIOUS MARKER CHECK ---
# Warns if Docker ENV setup was already completed before.
function marker_display_value() {
    local label="$1"
    local file="$2"
    local value=""

    if root_path_exists "$file"; then
        value="$(marker_safe_value "$(root_read_file "$file" 2>/dev/null | awk -F': ' -v label="$label" '$1 == label { $1=""; sub(/^: /, ""); print; exit }')")"
    fi

    [ -n "$value" ] || value="unknown"
    echo "$value"
}

function marker_key_value() {
    local key="$1"
    local file="$2"
    local value=""

    if root_path_exists "$file"; then
        value="$(marker_safe_value "$(root_read_file "$file" 2>/dev/null | awk -F= -v key="$key" '$1 == key { $1=""; sub(/^=/, ""); print; exit }')")"
    fi

    echo "$value"
}

function docker_env_summary_value_color() {
    local value="${1:-unknown}"
    case "$value" in
        present|PASS) printf '%s' "$GN" ;;
        PASS_WITH_WARNINGS) printf '%s' "$YW" ;;
        missing|FAIL|unknown) printf '%s' "$RD" ;;
        *) printf '%s' "$GN" ;;
    esac
}

function show_previous_marker_compact_summary() {
    local marker_file="$1"
    local marker_docker_dir=""
    local marker_secrets_dir=""
    local verify_status=""
    local env_state="missing"
    local secrets_state="missing"
    local marker_state="present"

    marker_docker_dir="$(marker_display_value "Docker dir" "$marker_file")"
    marker_secrets_dir="$(marker_display_value "Secrets dir" "$marker_file")"
    verify_status="$(marker_key_value "SCRIPT6_VERIFY_STATUS" "$marker_file")"
    [ -n "$verify_status" ] || verify_status="unknown"

    if [ "$marker_docker_dir" != "unknown" ] && root_path_exists "${marker_docker_dir}/.env"; then
        env_state="present"
    fi

    if [ "$marker_secrets_dir" != "unknown" ] && root_path_exists "$marker_secrets_dir"; then
        secrets_state="present"
    fi

    echo -e "${YW}Existing Docker ENV detected:${CL}"
    aligned_status_line "Docker directory" "$marker_docker_dir" "$(docker_env_summary_value_color "$marker_docker_dir")" 19
    aligned_status_line ".env file" "$env_state" "$(docker_env_summary_value_color "$env_state")" 19
    aligned_status_line "Secrets directory" "$secrets_state" "$(docker_env_summary_value_color "$secrets_state")" 19
    aligned_status_line "Completion marker" "$marker_state" "$(docker_env_summary_value_color "$marker_state")" 19
    aligned_status_line "Verification" "$verify_status" "$(docker_env_summary_value_color "$verify_status")" 19
}

function show_existing_path_compact_summary() {
    local env_state="missing"
    local secrets_state="missing"
    local marker_state="missing"
    local verify_status="unknown"

    root_path_exists "${DOCKER_DIR}/.env" && env_state="present"
    root_path_exists "$DOCKER_SECRETS_DIR" && secrets_state="present"
    root_path_exists "$COMPLETED_MARKER" && marker_state="present"
    if root_path_exists "$COMPLETED_MARKER"; then
        verify_status="$(marker_key_value "SCRIPT6_VERIFY_STATUS" "$COMPLETED_MARKER")"
        [ -n "$verify_status" ] || verify_status="unknown"
    fi

    echo -e "${YW}Existing Docker ENV detected:${CL}"
    aligned_status_line "Docker directory" "$DOCKER_DIR" "$(docker_env_summary_value_color "$DOCKER_DIR")" 19
    aligned_status_line ".env file" "$env_state" "$(docker_env_summary_value_color "$env_state")" 19
    aligned_status_line "Secrets directory" "$secrets_state" "$(docker_env_summary_value_color "$secrets_state")" 19
    aligned_status_line "Completion marker" "$marker_state" "$(docker_env_summary_value_color "$marker_state")" 19
    aligned_status_line "Verification" "$verify_status" "$(docker_env_summary_value_color "$verify_status")" 19
}

function previous_marker_action_menu() {
    local action=""

    while true; do
        tty_println "  ${YW}1)${CL} Verify existing setup"
        tty_println "  ${YW}2)${CL} Re-run Docker ENV setup"
        tty_println "  ${YW}3)${CL} Exit"
        tty_println ""

        action="$(numeric_menu_input "Select action" "1" "1" "3")"

        case "$action" in
            1)
                tty_println "${CM} ${GN}Verify existing setup selected${CL}"
                echo "$action"
                return 0
                ;;
            2)
                tty_println "${CM} ${GN}Re-run Docker ENV setup selected${CL}"
                echo "$action"
                return 0
                ;;
            3)
                tty_println "${CM} ${GN}Exit selected${CL}"
                echo "$action"
                return 0
                ;;
            *)
                tty_println "${WARN} ${YW}Invalid action. Choose 1, 2, or 3.${CL}"
                tty_println ""
                ;;
        esac
    done
}

function default_docker_env_setup_present() {
    local default_userdir="${USERDIR:-/home/${DEFAULT_USER}}"
    local default_docker_dir="${DOCKER_DIR:-${default_userdir}/docker}"
    local default_secrets_dir="${DOCKER_SECRETS_DIR:-${default_docker_dir}/secrets}"

    if root_path_exists "$COMPLETED_MARKER" || root_path_exists "${default_docker_dir}/.env" || root_path_exists "$default_secrets_dir"; then
        return 0
    fi

    return 1
}

function docker_env_setup_state_label() {
    local default_userdir="${USERDIR:-/home/${DEFAULT_USER}}"
    local default_docker_dir="${DOCKER_DIR:-${default_userdir}/docker}"
    local default_secrets_dir="${DOCKER_SECRETS_DIR:-${default_docker_dir}/secrets}"
    local found_count=0

    root_path_exists "$COMPLETED_MARKER" && found_count=$(( found_count + 1 ))
    root_path_exists "${default_docker_dir}/.env" && found_count=$(( found_count + 1 ))
    root_path_exists "$default_secrets_dir" && found_count=$(( found_count + 1 ))

    if [ "$found_count" -eq 0 ]; then
        printf 'not detected'
    elif [ "$found_count" -ge 2 ]; then
        printf 'detected'
    else
        printf 'partial setup detected'
    fi
}

function docker_env_setup_state_color() {
    local state="${1:-unknown}"

    case "$state" in
        "not detected"|detected) printf '%s' "$GN" ;;
        "partial setup detected") printf '%s' "$YW" ;;
        *) printf '%s' "$RD" ;;
    esac
}

# --- 41. PREVIOUS MARKER CHECK ---
# Offers verification-only rerun mode when Docker ENV setup was already completed previously.
function check_previous_marker() {
    local marker_action=""
    local default_userdir="/home/${DEFAULT_USER}"
    local default_docker_dir="${default_userdir}/docker"
    local default_secrets_dir="${default_docker_dir}/secrets"

    if root_path_exists "$COMPLETED_MARKER"; then
        section "EXISTING DOCKER ENV"
        EXISTING_SETUP_SECTION_SHOWN="yes"
        show_previous_marker_compact_summary "$COMPLETED_MARKER"
        echo ""
        echo -e "${YW}Action:${CL}"

        marker_action="$(previous_marker_action_menu)"

        case "$marker_action" in
            1) run_verify_only_mode; exit 0 ;;
            2) MARKER_RERUN_SELECTED="yes"; return 0 ;;
            3) exit 0 ;;
            *) return 0 ;;
        esac
    fi

    if root_path_exists "${default_docker_dir}/.env" || root_path_exists "$default_secrets_dir"; then
        DOCKER_USER="$DEFAULT_USER"
        USERDIR="$default_userdir"
        DOCKER_DIR="$default_docker_dir"
        DOCKER_SECRETS_DIR="$default_secrets_dir"
        CF_API_TOKEN_FILE="${DOCKER_SECRETS_DIR}/cf_api_token"

        section "EXISTING DOCKER ENV"
        EXISTING_SETUP_SECTION_SHOWN="yes"
        show_existing_path_compact_summary
        echo ""
        echo -e "${YW}Action:${CL}"

        marker_action="$(previous_marker_action_menu)"

        case "$marker_action" in
            1) prepare_existing_verify_state_from_paths; run_verify_only_mode; exit 0 ;;
            2) MARKER_RERUN_SELECTED="yes"; return 0 ;;
            3) exit 0 ;;
            *) return 0 ;;
        esac
    fi

    return 0
}

# =========================================================
#  INPUT COLLECTION
# =========================================================

# --- 42. START CONFIRMATION ---
# Starts Docker ENV setup after showing a clear description.
function start_confirmation() {
    local start_yn=""

    section "START"

    echo -e "${YW}Creates Docker folders, .env, service secrets and Traefik config.${CL}"
    echo -e "${YW}Sensitive inputs are not logged.${CL}"
    echo ""

    SUPPRESS_TIMED_YES_NO_CONFIRMATION="yes"
    start_yn="$(timed_yes_no "Start the Docker ENV Setup Script?" "y")"
    unset SUPPRESS_TIMED_YES_NO_CONFIRMATION

    if [[ "$start_yn" =~ ^[Nn] ]]; then
        exit 0
    fi

    msg_ok "Docker ENV setup start confirmed"
    return 0
}

# --- 42A. SCRIPT 5 PREFLIGHT HELPERS ---
# Reads Script 5 marker/verification state and validates Docker user/group readiness before Script 6 choices.
function script5_marker_readable_value() {
    local label="$1"
    local value=""

    if root_path_exists "$SCRIPT5_MARKER"; then
        value="$(marker_safe_value "$(root_read_file "$SCRIPT5_MARKER" 2>/dev/null | awk -F': ' -v label="$label" '$1 == label { $1=""; sub(/^: /, ""); print; exit }')")"
    fi

    printf '%s' "$value"
}

function script5_marker_key_value() {
    local key="$1"
    local value=""

    if root_path_exists "$SCRIPT5_MARKER"; then
        value="$(marker_safe_value "$(root_read_file "$SCRIPT5_MARKER" 2>/dev/null | awk -F= -v key="$key" '$1 == key { $1=""; sub(/^=/, ""); print; exit }')")"
    fi

    printf '%s' "$value"
}

function current_login_user_guess() {
    local candidate="${SUDO_USER:-}"

    if [ -z "$candidate" ] || [ "$candidate" == "root" ]; then
        candidate="$(logname 2>/dev/null || true)"
    fi

    if [ -z "$candidate" ] || [ "$candidate" == "root" ]; then
        candidate="${USER:-}"
    fi

    printf '%s' "$candidate"
}

function detect_script5_preflight_state() {
    local marker_user=""
    local current_user=""
    local verify_from_log=""
    local user_added=""

    if root_path_exists "$SCRIPT5_MARKER"; then
        SCRIPT5_MARKER_STATE="present"
    else
        SCRIPT5_MARKER_STATE="missing"
    fi

    if root_path_exists "$SCRIPT5_VERIFY_LOG"; then
        SCRIPT5_VERIFY_LOG_STATE="present"
        verify_from_log="$(marker_safe_value "$(root_read_file "$SCRIPT5_VERIFY_LOG" 2>/dev/null | awk -F= '$1 == "VERIFY_STATUS" {print $2; exit}')")"
    else
        SCRIPT5_VERIFY_LOG_STATE="missing"
    fi

    SCRIPT5_STATUS="$(script5_marker_key_value "SCRIPT5_STATUS")"
    [ -n "$SCRIPT5_STATUS" ] || SCRIPT5_STATUS="missing"
    SCRIPT5_VERSION="$(script5_marker_key_value "SCRIPT5_VERSION")"; [ -n "$SCRIPT5_VERSION" ] || SCRIPT5_VERSION="unknown"
    SCRIPT5_BUILD="$(script5_marker_key_value "SCRIPT5_BUILD")"; [ -n "$SCRIPT5_BUILD" ] || SCRIPT5_BUILD="unknown"
    SCRIPT5_DOCKER_INSTALLED="$(script5_marker_key_value "SCRIPT5_DOCKER_INSTALLED")"; [ -n "$SCRIPT5_DOCKER_INSTALLED" ] || SCRIPT5_DOCKER_INSTALLED="unknown"
    SCRIPT5_DOCKER_SERVICE_ENABLED="$(script5_marker_key_value "SCRIPT5_DOCKER_SERVICE_ENABLED")"; [ -n "$SCRIPT5_DOCKER_SERVICE_ENABLED" ] || SCRIPT5_DOCKER_SERVICE_ENABLED="unknown"
    SCRIPT5_CONTAINERD_SERVICE_ENABLED="$(script5_marker_key_value "SCRIPT5_CONTAINERD_SERVICE_ENABLED")"; [ -n "$SCRIPT5_CONTAINERD_SERVICE_ENABLED" ] || SCRIPT5_CONTAINERD_SERVICE_ENABLED="unknown"
    SCRIPT5_SWAP_PRESERVE_SELECTED="$(script5_marker_key_value "SCRIPT5_SWAP_PRESERVE_SELECTED")"; [ -n "$SCRIPT5_SWAP_PRESERVE_SELECTED" ] || SCRIPT5_SWAP_PRESERVE_SELECTED="unknown"
    SCRIPT5_SWAP_RESULT="$(script5_marker_key_value "SCRIPT5_SWAP_RESULT")"; [ -n "$SCRIPT5_SWAP_RESULT" ] || SCRIPT5_SWAP_RESULT="unknown"
    SCRIPT5_SWAP_FILE="$(script5_marker_key_value "SCRIPT5_SWAP_FILE")"; [ -n "$SCRIPT5_SWAP_FILE" ] || SCRIPT5_SWAP_FILE="unknown"
    SCRIPT5_SWAP_SIZE="$(script5_marker_key_value "SCRIPT5_SWAP_SIZE")"; [ -n "$SCRIPT5_SWAP_SIZE" ] || SCRIPT5_SWAP_SIZE="unknown"
    SCRIPT5_UFW_ENABLED="$(script5_marker_key_value "SCRIPT5_UFW_ENABLED")"; [ -n "$SCRIPT5_UFW_ENABLED" ] || SCRIPT5_UFW_ENABLED="unknown"
    SCRIPT5_REDIS_OVERCOMMIT="$(script5_marker_key_value "SCRIPT5_REDIS_OVERCOMMIT")"; [ -n "$SCRIPT5_REDIS_OVERCOMMIT" ] || SCRIPT5_REDIS_OVERCOMMIT="unknown"
    SCRIPT5_SCRIPT4_CROWDSEC_SELECTED="$(script5_marker_key_value "SCRIPT5_SCRIPT4_CROWDSEC_SELECTED")"; [ -n "$SCRIPT5_SCRIPT4_CROWDSEC_SELECTED" ] || SCRIPT5_SCRIPT4_CROWDSEC_SELECTED="unknown"
    SCRIPT5_SCRIPT4_CROWDSEC_BOUNCER="$(script5_marker_key_value "SCRIPT5_SCRIPT4_CROWDSEC_BOUNCER")"; [ -n "$SCRIPT5_SCRIPT4_CROWDSEC_BOUNCER" ] || SCRIPT5_SCRIPT4_CROWDSEC_BOUNCER="unknown"

    SCRIPT5_VERIFY_STATUS="$(script5_marker_key_value "SCRIPT5_VERIFY_STATUS")"
    [ -n "$SCRIPT5_VERIFY_STATUS" ] || SCRIPT5_VERIFY_STATUS="$verify_from_log"
    if [ -z "$SCRIPT5_VERIFY_STATUS" ]; then
        if [ "$SCRIPT5_VERIFY_LOG_STATE" == "present" ]; then
            SCRIPT5_VERIFY_STATUS="unknown"
        else
            SCRIPT5_VERIFY_STATUS="missing"
        fi
    fi

    marker_user="$(script5_marker_key_value "SCRIPT5_TARGET_USER")"
    [ -n "$marker_user" ] || marker_user="$(script5_marker_readable_value "Target user")"
    [ -n "$marker_user" ] || marker_user="$(script5_marker_readable_value "User")"
    current_user="$(current_login_user_guess)"

    SCRIPT5_TARGET_USER="$marker_user"
    if [ -n "$marker_user" ]; then
        DOCKER_PREFLIGHT_USER="$marker_user"
    else
        DOCKER_PREFLIGHT_USER="$current_user"
    fi

    user_added="$(script5_marker_key_value "SCRIPT5_USER_ADDED_TO_DOCKER")"

    if getent group docker >/dev/null 2>&1 && [ -n "$DOCKER_PREFLIGHT_USER" ] && id "$DOCKER_PREFLIGHT_USER" >/dev/null 2>&1 && id -nG "$DOCKER_PREFLIGHT_USER" 2>/dev/null | grep -qw docker; then
        DOCKER_USER_IN_DOCKER_GROUP="${DOCKER_PREFLIGHT_USER} ready"
    elif [ "$user_added" == "yes" ] && [ -n "$DOCKER_PREFLIGHT_USER" ] && id "$DOCKER_PREFLIGHT_USER" >/dev/null 2>&1 && getent group docker >/dev/null 2>&1 && id -nG "$DOCKER_PREFLIGHT_USER" 2>/dev/null | grep -qw docker; then
        DOCKER_USER_IN_DOCKER_GROUP="${DOCKER_PREFLIGHT_USER} ready"
    else
        DOCKER_USER_IN_DOCKER_GROUP="not ready"
    fi
}

function script5_verify_display_value() {
    if [ "$SCRIPT5_VERIFY_LOG_STATE" != "present" ]; then
        printf 'missing'
    else
        printf '%s' "${SCRIPT5_VERIFY_STATUS:-unknown}"
    fi
}

function script5_preflight_needs_warning() {
    [ "$SCRIPT5_MARKER_STATE" != "present" ] && return 0
    [ "$SCRIPT5_VERIFY_LOG_STATE" != "present" ] && return 0
    case "$SCRIPT5_VERIFY_STATUS" in
        PASS|PASS_WITH_WARNINGS) ;;
        *) return 0 ;;
    esac
    [ "$DOCKER_USER_IN_DOCKER_GROUP" == "not ready" ] && return 0
    return 1
}

function systemctl_is_active_value() {
    local service="$1"

    systemctl is-active "$service" 2>/dev/null || true
}

function systemctl_substate_value() {
    local service="$1"

    systemctl show "$service" -p SubState --value 2>/dev/null || true
}

function docker_cli_ready() {
    command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1
}

function docker_compose_ready() {
    command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1
}

function docker_info_ready() {
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        return 0
    fi

    if command -v docker >/dev/null 2>&1 && [ -n "$SUDO_CMD" ] && "$SUDO_CMD" docker info >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

function refresh_docker_runtime_state() {
    if docker_cli_ready; then
        DOCKER_READY="yes"
    elif command -v docker >/dev/null 2>&1 && [ -n "$SUDO_CMD" ] && "$SUDO_CMD" docker --version >/dev/null 2>&1; then
        DOCKER_READY="yes"
    else
        DOCKER_READY="no"
    fi

    if docker_compose_ready; then
        DOCKER_COMPOSE_READY="yes"
    elif command -v docker >/dev/null 2>&1 && [ -n "$SUDO_CMD" ] && "$SUDO_CMD" docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_READY="yes"
    else
        DOCKER_COMPOSE_READY="no"
    fi

    if docker_info_ready; then
        SCRIPT5_DOCKER_INFO_READY="yes"
    else
        SCRIPT5_DOCKER_INFO_READY="no"
    fi

    SCRIPT5_DOCKER_SERVICE_STATE="$(systemctl_is_active_value docker)"
    [ -n "$SCRIPT5_DOCKER_SERVICE_STATE" ] || SCRIPT5_DOCKER_SERVICE_STATE="unknown"
    SCRIPT5_CONTAINERD_SERVICE_STATE="$(systemctl_is_active_value containerd)"
    [ -n "$SCRIPT5_CONTAINERD_SERVICE_STATE" ] || SCRIPT5_CONTAINERD_SERVICE_STATE="unknown"
}

function refresh_crowdsec_runtime_state() {
    SCRIPT5_CROWDSEC_STATE="$(systemctl_is_active_value crowdsec)"
    [ -n "$SCRIPT5_CROWDSEC_STATE" ] || SCRIPT5_CROWDSEC_STATE="unknown"
    SCRIPT5_CROWDSEC_BOUNCER_STATE="$(systemctl_is_active_value crowdsec-firewall-bouncer)"
    [ -n "$SCRIPT5_CROWDSEC_BOUNCER_STATE" ] || SCRIPT5_CROWDSEC_BOUNCER_STATE="unknown"
    SCRIPT5_CROWDSEC_BOUNCER_SUBSTATE="$(systemctl_substate_value crowdsec-firewall-bouncer)"
    [ -n "$SCRIPT5_CROWDSEC_BOUNCER_SUBSTATE" ] || SCRIPT5_CROWDSEC_BOUNCER_SUBSTATE="unknown"
}

function crowdsec_bouncer_runtime_value() {
    if [ "${SCRIPT5_CROWDSEC_BOUNCER_STATE:-unknown}" == "active" ] && [ -n "${SCRIPT5_CROWDSEC_BOUNCER_SUBSTATE:-}" ] && [ "${SCRIPT5_CROWDSEC_BOUNCER_SUBSTATE:-unknown}" != "unknown" ]; then
        printf '%s/%s' "$SCRIPT5_CROWDSEC_BOUNCER_STATE" "$SCRIPT5_CROWDSEC_BOUNCER_SUBSTATE"
    elif [ "${SCRIPT5_CROWDSEC_BOUNCER_STATE:-unknown}" != "unknown" ]; then
        printf '%s' "$SCRIPT5_CROWDSEC_BOUNCER_STATE"
    else
        printf 'unknown'
    fi
}

function crowdsec_bouncer_handoff_display_value() {
    local runtime_value=""
    local marker_value="${SCRIPT5_SCRIPT4_CROWDSEC_BOUNCER:-unknown}"

    runtime_value="$(crowdsec_bouncer_runtime_value)"
    SCRIPT6_CROWDSEC_BOUNCER_RUNTIME="$runtime_value"

    if [ "$runtime_value" == "active/running" ]; then
        printf '%s' "$runtime_value"
    elif [ "$marker_value" != "unknown" ] && [ -n "$marker_value" ]; then
        printf '%s' "$marker_value"
    elif [ "$runtime_value" != "unknown" ] && [ -n "$runtime_value" ]; then
        printf '%s' "$runtime_value"
    elif [ "${SCRIPT5_SCRIPT4_CROWDSEC_SELECTED:-unknown}" == "no" ]; then
        printf 'skipped'
    else
        printf 'unknown'
    fi
}

function refresh_crowdsec_bouncer_display_state() {
    SCRIPT6_CROWDSEC_BOUNCER_DISPLAY="$(crowdsec_bouncer_handoff_display_value)"
    [ -n "$SCRIPT6_CROWDSEC_BOUNCER_DISPLAY" ] || SCRIPT6_CROWDSEC_BOUNCER_DISPLAY="unknown"
}

function script5_crowdsec_selected_or_active() {
    local selected=""
    local marker_bouncer=""

    selected="$(script5_marker_key_value "SCRIPT5_SCRIPT4_CROWDSEC_SELECTED")"
    marker_bouncer="$(script5_marker_key_value "SCRIPT5_SCRIPT4_CROWDSEC_BOUNCER")"

    [ "$selected" == "yes" ] && return 0
    [ "$marker_bouncer" == "active" ] && return 0
    [ "$SCRIPT5_CROWDSEC_STATE" == "active" ] && return 0
    [ "$SCRIPT5_CROWDSEC_BOUNCER_STATE" == "active" ] && return 0

    return 1
}

function detect_environment_label() {
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt=""
        virt="$(systemd-detect-virt 2>/dev/null || true)"
        if [ -n "$virt" ] && [ "$virt" != "none" ]; then
            printf '%s VM' "$virt"
            return 0
        fi
    fi

    printf 'bare metal/unknown'
}

function derive_user_and_docker_paths() {
    local passwd_home=""
    local marker_docker_dir=""

    [ -n "${DOCKER_USER:-}" ] || DOCKER_USER="${SCRIPT5_TARGET_USER:-}"
    passwd_home="$(getent passwd "$DOCKER_USER" 2>/dev/null | cut -d: -f6 || true)"
    if validate_absolute_path "$passwd_home"; then
        USERDIR="$passwd_home"
    else
        USERDIR="/home/${DOCKER_USER}"
    fi

    DOCKER_DIR="${USERDIR}/docker"
    if root_path_exists "$COMPLETED_MARKER"; then
        marker_docker_dir="$(marker_display_value "Docker dir" "$COMPLETED_MARKER")"
        if [ "$marker_docker_dir" != "unknown" ] && validate_absolute_path "$marker_docker_dir"; then
            DOCKER_DIR="$marker_docker_dir"
            USERDIR="${DOCKER_DIR%/docker}"
        fi
    fi

    DOCKER_SECRETS_DIR="${DOCKER_DIR}/secrets"
    CF_API_TOKEN_FILE="${DOCKER_SECRETS_DIR}/cf_api_token"
}

function validate_script5_handoff() {
    local failure="no"
    local compose_state="not ready"
    local bouncer_display="unknown"

    detect_script5_preflight_state
    refresh_docker_runtime_state
    refresh_crowdsec_runtime_state
    refresh_crowdsec_bouncer_display_state
    bouncer_display="$SCRIPT6_CROWDSEC_BOUNCER_DISPLAY"
    [ "$DOCKER_COMPOSE_READY" == "yes" ] && compose_state="ready"

    section "SCRIPT 5 HANDOFF"
    echo -e "${YW}Script 5:${CL}"
    aligned_status_line "Status" "$SCRIPT5_STATUS" "$(status_color_for_value "$SCRIPT5_STATUS")" 18
    aligned_status_line "Verification" "$SCRIPT5_VERIFY_STATUS" "$(status_color_for_value "$SCRIPT5_VERIFY_STATUS")" 18
    aligned_status_line "Docker user" "${SCRIPT5_TARGET_USER:-missing}" "$(status_color_for_value "${SCRIPT5_TARGET_USER:-missing}")" 18
    aligned_status_line "Docker" "${SCRIPT5_DOCKER_INSTALLED:-unknown}" "$(status_color_for_value "${SCRIPT5_DOCKER_INSTALLED:-unknown}")" 18
    aligned_status_line "Docker service" "$SCRIPT5_DOCKER_SERVICE_STATE" "$(status_color_for_value "$SCRIPT5_DOCKER_SERVICE_STATE")" 18
    aligned_status_line "Compose" "$compose_state" "$(status_color_for_value "$compose_state")" 18
    aligned_status_line "containerd" "$SCRIPT5_CONTAINERD_SERVICE_STATE" "$(status_color_for_value "$SCRIPT5_CONTAINERD_SERVICE_STATE")" 18
    echo ""
    echo -e "${YW}System:${CL}"
    aligned_status_line "Ubuntu swap" "$SCRIPT5_SWAP_RESULT" "$(status_color_for_value "$SCRIPT5_SWAP_RESULT")" 18
    aligned_status_line "Swap file" "$SCRIPT5_SWAP_FILE" "$(status_color_for_value "$SCRIPT5_SWAP_FILE")" 18
    aligned_status_line "Swap size" "$SCRIPT5_SWAP_SIZE" "$(status_color_for_value "$SCRIPT5_SWAP_SIZE")" 18
    aligned_status_line "UFW firewall" "$SCRIPT5_UFW_ENABLED" "$(status_color_for_value "$SCRIPT5_UFW_ENABLED")" 18
    aligned_status_line "Redis host tuning" "$SCRIPT5_REDIS_OVERCOMMIT" "$(status_color_for_value "$SCRIPT5_REDIS_OVERCOMMIT")" 18
    echo ""
    echo -e "${YW}Security:${CL}"
    aligned_status_line "CrowdSec selected" "$SCRIPT5_SCRIPT4_CROWDSEC_SELECTED" "$(status_color_for_value "$SCRIPT5_SCRIPT4_CROWDSEC_SELECTED")" 18
    aligned_status_line "Bouncer" "$bouncer_display" "$(status_color_for_value "$bouncer_display")" 18

    if [ "$SCRIPT5_MARKER_STATE" != "present" ]; then msg_warn "Script 5 marker is missing: ${SCRIPT5_MARKER}"; failure="yes"; fi
    if [ "$SCRIPT5_STATUS" != "completed" ]; then msg_warn "Script 5 marker is not completed"; failure="yes"; fi
    if [ "$SCRIPT5_VERIFY_STATUS" != "PASS" ]; then msg_warn "Script 5 verification is not PASS"; failure="yes"; fi
    if ! validate_linux_username "${SCRIPT5_TARGET_USER:-}" || [ "${SCRIPT5_TARGET_USER:-}" == "root" ] || ! id "$SCRIPT5_TARGET_USER" >/dev/null 2>&1; then msg_warn "Script 5 target user is missing, root, invalid, or not a local user"; failure="yes"; fi
    if [ "$DOCKER_READY" != "yes" ]; then msg_warn "Docker CLI is not ready"; failure="yes"; fi
    if [ "$DOCKER_COMPOSE_READY" != "yes" ]; then msg_warn "Docker Compose plugin is not ready"; failure="yes"; fi
    if [ "$SCRIPT5_DOCKER_INFO_READY" != "yes" ]; then msg_warn "docker info is not ready"; failure="yes"; fi
    if [ "$SCRIPT5_DOCKER_SERVICE_STATE" != "active" ]; then msg_warn "Docker service is not active"; failure="yes"; fi
    if [ "$SCRIPT5_CONTAINERD_SERVICE_STATE" != "active" ]; then msg_warn "containerd service is not active"; failure="yes"; fi
    if [ "$DOCKER_USER_IN_DOCKER_GROUP" == "not ready" ]; then msg_warn "Script 5 target user is not confirmed in docker group"; failure="yes"; fi

    if [ "$SCRIPT5_SWAP_RESULT" == "unknown" ] || [ "$SCRIPT5_SWAP_FILE" == "unknown" ] || [ "$SCRIPT5_SWAP_SIZE" == "unknown" ]; then
        msg_warn "Script 5 swap handoff fields are unknown; continuing because swap metadata is informational for Script 6."
    fi

    if script5_crowdsec_selected_or_active; then
        if [ "$SCRIPT5_CROWDSEC_STATE" != "active" ] && [ "$SCRIPT5_SCRIPT4_CROWDSEC_SELECTED" != "yes" ]; then
            msg_warn "CrowdSec service is not active and no Script 5 marker fallback is available"
            failure="yes"
        fi

        if [ "$SCRIPT5_CROWDSEC_BOUNCER_STATE" == "active" ] && [ "$SCRIPT5_CROWDSEC_BOUNCER_SUBSTATE" == "running" ]; then
            :
        elif [ "$SCRIPT5_SCRIPT4_CROWDSEC_BOUNCER" == "active" ] && [ "$SCRIPT5_VERIFY_STATUS" == "PASS" ]; then
            :
        else
            msg_warn "CrowdSec bouncer runtime/marker continuity is not healthy"
            failure="yes"
        fi
    fi

    if [ "$failure" == "yes" ]; then
        echo ""
        echo -e "${RD}Script 6 cannot continue until Script 5 handoff is healthy.${CL}"
        echo -e "${YW}Complete/fix Script 5 first, then rerun Script 6.${CL}"
        exit 1
    fi

    DOCKER_USER="$SCRIPT5_TARGET_USER"
    DEFAULT_USER="$DOCKER_USER"
    msg_ok "SCRIPT 5 HANDOFF VERIFIED"
}

function show_script5_handoff_summary() {
    echo -e "${YW}Script 5:${CL}"
    aligned_value_line "Status" "$SCRIPT5_STATUS" "$(status_color_for_value "$SCRIPT5_STATUS")" 21
    aligned_value_line "Verification" "$SCRIPT5_VERIFY_STATUS" "$(status_color_for_value "$SCRIPT5_VERIFY_STATUS")" 21
    aligned_value_line "Docker user" "$DOCKER_USER" "$GN" 21
    aligned_value_line "Docker" "$SCRIPT5_DOCKER_SERVICE_STATE" "$(status_color_for_value "$SCRIPT5_DOCKER_SERVICE_STATE")" 21
    aligned_value_line "Compose" "$([ "$DOCKER_COMPOSE_READY" == "yes" ] && echo ready || echo "not ready")" "$(status_color_for_value "$([ "$DOCKER_COMPOSE_READY" == "yes" ] && echo ready || echo "not ready")")" 21
    aligned_value_line "Containerd" "$SCRIPT5_CONTAINERD_SERVICE_STATE" "$(status_color_for_value "$SCRIPT5_CONTAINERD_SERVICE_STATE")" 21
    echo ""
    echo -e "${YW}System:${CL}"
    aligned_value_line "Ubuntu swap" "$SCRIPT5_SWAP_RESULT" "$(status_color_for_value "$SCRIPT5_SWAP_RESULT")" 21
    aligned_value_line "Swap file" "$SCRIPT5_SWAP_FILE" "$(status_color_for_value "$SCRIPT5_SWAP_FILE")" 21
    aligned_value_line "Swap size" "$SCRIPT5_SWAP_SIZE" "$(status_color_for_value "$SCRIPT5_SWAP_SIZE")" 21
    aligned_value_line "UFW firewall" "$SCRIPT5_UFW_ENABLED" "$(status_color_for_value "$SCRIPT5_UFW_ENABLED")" 21
    aligned_value_line "Redis host tuning" "$SCRIPT5_REDIS_OVERCOMMIT" "$(status_color_for_value "$SCRIPT5_REDIS_OVERCOMMIT")" 21
}

function check_docker_readiness() {
    local sudo_state="ready"
    local env_setup_state=""
    local env_setup_color=""
    local env_label_prefix="${CM}"

    detect_script5_preflight_state
    if validate_linux_username "${SCRIPT5_TARGET_USER:-}" && [ "${SCRIPT5_TARGET_USER:-}" != "root" ]; then
        DEFAULT_USER="$SCRIPT5_TARGET_USER"
        DOCKER_USER="$SCRIPT5_TARGET_USER"
        derive_user_and_docker_paths
    fi

    section "ENVIRONMENT CHECK"

    [ -z "$SUDO_CMD" ] && sudo_state="ready"
    env_setup_state="$(docker_env_setup_state_label)"
    env_setup_color="$(docker_env_setup_state_color "$env_setup_state")"
    [ "$env_setup_state" == "partial setup detected" ] && env_label_prefix="$WARN"

    msg_ok "ENVIRONMENT DETECTED ($(detect_environment_label))"
    echo -e " ${CM} ${GN}Passwordless sudo:${CL} ${GN}${sudo_state}${CL}"
    echo -e " ${CM} ${GN}Required dependencies:${CL} ${GN}ready${CL}"
    echo -e " ${env_label_prefix} ${GN}Existing Docker ENV setup:${CL} ${env_setup_color}${env_setup_state}${CL}"

    validate_script5_handoff
}


# --- 44. USER AND PATH INPUTS ---
# Collects and validates Docker user, user home path and Docker project path.
function collect_user_and_path_inputs() {
    setup_options_group_header "User / path"

    DOCKER_USER="$SCRIPT5_TARGET_USER"
    if ! validate_linux_username "$DOCKER_USER" || [ "$DOCKER_USER" == "root" ] || ! id "$DOCKER_USER" >/dev/null 2>&1; then
        msg_error "Script 5 target user is invalid. Complete/fix Script 5 first."
    fi

    derive_user_and_docker_paths

    PUID_VALUE="$(id -u "$DOCKER_USER")"
    PGID_VALUE="$(id -g "$DOCKER_USER")"
    DOCKER_GID_VALUE="$(getent group docker 2>/dev/null | cut -d: -f3 || true)"

    aligned_value_line "Docker user" "$DOCKER_USER" "$GN" 21
    aligned_value_line "User home" "$USERDIR" "$GN" 21
    aligned_value_line "Docker directory" "$DOCKER_DIR" "$GN" 21

    if id -nG "$DOCKER_USER" 2>/dev/null | grep -qw docker; then
        DOCKER_USER_IN_DOCKER_GROUP="yes"
    else
        DOCKER_USER_IN_DOCKER_GROUP="no"
        msg_error "User ${DOCKER_USER} is not in docker group. Complete/fix Script 5 first."
    fi
}


# --- 45. EXISTING SETUP DETECTION ---
# Detects existing .env, secrets folder or marker to prevent accidental secret rotation.
function read_existing_env_value() {
    local key="$1"
    local value=""

    if [ -n "${DOCKER_DIR:-}" ] && root_path_exists "${DOCKER_DIR}/.env"; then
        value="$(env_safe_value "$(root_read_file "${DOCKER_DIR}/.env" 2>/dev/null | awk -F= -v key="$key" '$1 == key { $1=""; sub(/^=/, ""); print; exit }')")"
    fi

    printf '%s' "$value"
}


function email_input() {
    local prompt="$1"
    local default="$2"
    local value=""

    while true; do
        value="$(timed_text_input "$prompt" "$default")"
        value="$(printf '%s' "$value" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

        if validate_email "$value"; then
            printf '%s' "$value"
            return 0
        fi

        tty_println "${WARN} ${YW}Invalid email format. Use an address such as admin@${DOMAIN_VALUE}.${CL}"
    done
}

function collect_traefik_authentik_email_inputs() {
    local default_shared_email="admin@${DOMAIN_VALUE}"
    local default_acme_email="certs@${DOMAIN_VALUE}"
    local default_authentik_email="admin@${DOMAIN_VALUE}"
    local existing_acme_email=""
    local existing_authentik_email=""
    local shared_email=""
    local split_default="n"
    local split_yn=""

    setup_options_group_header "Traefik / Authentik"

    existing_acme_email="$(read_existing_env_value "TRAEFIK_ACME_EMAIL")"
    existing_authentik_email="$(read_existing_env_value "AUTHENTIK_BOOTSTRAP_EMAIL")"

    if validate_email "$existing_acme_email" && validate_email "$existing_authentik_email"; then
        if [ "$existing_acme_email" == "$existing_authentik_email" ]; then
            default_shared_email="$existing_acme_email"
            default_acme_email="$existing_acme_email"
            default_authentik_email="$existing_authentik_email"
            split_default="n"
        else
            default_acme_email="$existing_acme_email"
            default_authentik_email="$existing_authentik_email"
            split_default="y"
        fi
    elif validate_email "$existing_authentik_email"; then
        default_shared_email="$existing_authentik_email"
        default_authentik_email="$existing_authentik_email"
    elif validate_email "$existing_acme_email"; then
        default_shared_email="$existing_acme_email"
        default_acme_email="$existing_acme_email"
    fi

    split_yn="$(timed_yes_no "Use separate ACME and Authentik emails?" "$split_default")"
    if [[ "$split_yn" =~ ^[Yy]$ ]]; then
        TRAEFIK_ACME_EMAIL_VALUE="$(email_input "Enter ACME email" "$default_acme_email")"
        AUTHENTIK_BOOTSTRAP_EMAIL_VALUE="$(email_input "Enter Authentik email" "$default_authentik_email")"

    else
        shared_email="$(email_input "Enter Traefik/AuthentiK email" "$default_shared_email")"
        TRAEFIK_ACME_EMAIL_VALUE="$shared_email"
        AUTHENTIK_BOOTSTRAP_EMAIL_VALUE="$shared_email"

    fi

    return 0
}

function prepare_existing_verify_state_from_paths() {
    local value=""

    [ -n "${DOCKER_SECRETS_DIR:-}" ] || DOCKER_SECRETS_DIR="${DOCKER_DIR}/secrets"
    [ -n "${CF_API_TOKEN_FILE:-}" ] || CF_API_TOKEN_FILE="${DOCKER_SECRETS_DIR}/cf_api_token"
    [ -n "${TRAEFIK_DIR:-}" ] || TRAEFIK_DIR="${DOCKER_DIR}/appdata/traefik"
    [ -n "${TRAEFIK_ACME_DIR:-}" ] || TRAEFIK_ACME_DIR="${TRAEFIK_DIR}/acme"
    [ -n "${TRAEFIK_STATIC_CONFIG_FILE:-}" ] || TRAEFIK_STATIC_CONFIG_FILE="${TRAEFIK_DIR}/traefik.yml"
    [ -n "${TRAEFIK_DYNAMIC_CONFIG_FILE:-}" ] || TRAEFIK_DYNAMIC_CONFIG_FILE="${TRAEFIK_DIR}/dynamic-config.yml"

    value="$(read_existing_env_value "DOMAIN")"; [ -n "$value" ] && DOMAIN_VALUE="$value"
    value="$(read_existing_env_value "ADMIN_UI")"; [ -n "$value" ] && ADMIN_UI="$value"
    value="$(read_existing_env_value "TRAEFIK_DASHBOARD_HOST")"; [ -n "$value" ] && TRAEFIK_DASHBOARD_HOST="$value"

    return 0
}

# --- 45. EXISTING SETUP DETECTION ---
# Detects existing .env, secrets folder or marker to prevent accidental secret rotation.
function detect_existing_setup() {
    local existing_action=""
    local regenerate_yn=""
    local env_state="missing"
    local secrets_state="missing"
    local marker_state="missing"

    msg_info "Checking selected Docker ENV path"

    if root_path_exists "$COMPLETED_MARKER"; then marker_state="present"; fi
    if root_path_exists "${DOCKER_DIR}/.env"; then env_state="present"; fi
    if root_path_exists "${DOCKER_SECRETS_DIR}"; then secrets_state="present"; fi

    if [ "$marker_state" == "present" ] || [ "$env_state" == "present" ] || [ "$secrets_state" == "present" ]; then
        EXISTING_SETUP="yes"
    else
        EXISTING_SETUP="no"
    fi

    if [ "$EXISTING_SETUP" != "yes" ]; then
        REGENERATE_SECRETS="n"
        tty_print "${BFR}"
        return 0
    fi

    tty_print "${BFR}"

    if [ "$MARKER_RERUN_SELECTED" != "yes" ]; then
        echo ""
        show_existing_path_compact_summary
        echo ""
        echo -e "${YW}Action:${CL}"
        existing_action="$(previous_marker_action_menu)"

        case "$existing_action" in
            1)
                prepare_existing_verify_state_from_paths
                run_verify_only_mode
                exit 0
                ;;
            2)
                ;;
            3)
                exit 0
                ;;
            *)
                ;;
        esac
    fi

    msg_warn "Existing Docker ENV setup detected"
    echo -e "${YW}Existing secrets will be reused unless you explicitly choose to regenerate them.${CL}"
    echo ""

    regenerate_yn="$(timed_yes_no "Regenerate all service secrets?" "n")"

    if [[ "$regenerate_yn" =~ ^[Yy] ]]; then
        REGENERATE_SECRETS="y"
        msg_warn "Secret regeneration selected. Existing deployed containers may need rebuilding."
    else
        REGENERATE_SECRETS="n"
        msg_ok "EXISTING SECRETS WILL BE REUSED WHERE PRESENT"
    fi
}

# --- 46. DOMAIN / CLOUDFLARE INPUTS ---
# Collects and validates timezone, domain, Cloudflare email/zone ID and token.
function collect_domain_cloudflare_inputs() {
    local cf_zone_summary="empty"
    local cf_token_summary="not provided"
    local cf_email_summary=""
    local domain_default=""

    setup_options_group_header "Domain / Timezone"

    domain_default="$(proxmox_domain_default)"

    TZ_VALUE="$(timed_text_input "Enter timezone" "$DEFAULT_TZ")"

    while true; do
        DOMAIN_VALUE="$(timed_text_input "Enter domain" "$domain_default")"

        if validate_domain "$DOMAIN_VALUE"; then
            break
        fi

        msg_warn "Invalid domain. Use a bare domain such as example.com, without https:// or slashes."
    done

    setup_options_group_header "Cloudflare"

    while true; do
        CF_ZONE_ID_VALUE="$(sensitive_visible_line_input "Enter Cloudflare Zone ID, or leave empty")" || CF_ZONE_ID_VALUE=""
        CF_ZONE_ID_VALUE="$(trim_value "$CF_ZONE_ID_VALUE")"

        if validate_cf_zone_id "$CF_ZONE_ID_VALUE"; then
            if [ -n "$CF_ZONE_ID_VALUE" ]; then
                cf_zone_summary="captured"
            else
                cf_zone_summary="empty"
            fi
            aligned_check_line "Zone ID" "$cf_zone_summary" "$GN" 21
            break
        fi

        msg_warn "Invalid Cloudflare Zone ID. Leave empty or enter the hex Zone ID."
    done

    # Ask for API token before email. When token auth is used, Cloudflare email is not required.
    # This avoids cf-companion receiving email-style auth values when a scoped API token is intended.
    CF_API_TOKEN_VALUE="$(sensitive_visible_line_input "Enter Cloudflare API Token, or leave empty")" || CF_API_TOKEN_VALUE=""
    CF_API_TOKEN_VALUE="$(trim_value "$CF_API_TOKEN_VALUE")"

    if [ -z "$CF_API_TOKEN_VALUE" ] && root_file_not_empty "$CF_API_TOKEN_FILE"; then
        CF_API_TOKEN_VALUE="$(root_read_file "$CF_API_TOKEN_FILE")"
        CF_AUTH_MODE="api_token_file_reuse"
        CF_EMAIL_REQUIRED="no"
        CF_API_EMAIL_VALUE=""
        cf_token_summary="reused"
    elif [ -n "$CF_API_TOKEN_VALUE" ]; then
        CF_AUTH_MODE="api_token"
        CF_EMAIL_REQUIRED="no"
        CF_API_EMAIL_VALUE=""
        cf_token_summary="captured"
    else
        CF_AUTH_MODE="email_or_manual"
        CF_EMAIL_REQUIRED="yes"
        cf_token_summary="not provided"
    fi

    aligned_check_line "API token" "$cf_token_summary" "$GN" 21

    if [ "$CF_EMAIL_REQUIRED" == "yes" ]; then
        while true; do
            CF_API_EMAIL_VALUE="$(timed_text_input "Enter Cloudflare API Email" "$DEFAULT_CF_API_EMAIL")"

            if validate_email "$CF_API_EMAIL_VALUE"; then
                cf_email_summary="${CF_API_EMAIL_VALUE}"
                break
            fi

            msg_warn "Invalid email format."
        done
        aligned_check_line "API Email" "$cf_email_summary" "$ANS" 21
    else
        aligned_value_line "Auth mode" "API token" "$GN" 21
    fi

    return 0
}

function collect_network_proxmox_inputs() {
    local proxmox_yn=""
    local default_proxmox_prefix=""
    local default_proxmox_url=""
    local detected_primary_ip=""
    local detected_gateway_ip=""

    setup_options_group_header "Network / Proxmox"

    detected_primary_ip="$(detect_primary_ipv4)"
    detected_gateway_ip="$(detect_default_gateway_ipv4)"
    default_proxmox_url="$(detect_proxmox_internal_url_default)"

    [ -n "$detected_primary_ip" ] && aligned_value_line "System IPv4" "$detected_primary_ip" "$GN" 21
    [ -n "$detected_gateway_ip" ] && aligned_value_line "Default gateway" "$detected_gateway_ip" "$GN" 21
    aligned_value_line "LAN URL" "$([ -n "$default_proxmox_url" ] && echo "$default_proxmox_url" || echo "not found")" "$GN" 21
    aligned_value_line "Proxmox marker" "$([ "$PROXMOX_MARKER_SOURCE" == "yes" ] && echo detected || echo not detected)" "$GN" 21
    echo ""

    proxmox_yn="$(timed_yes_no "Create optional Proxmox route in Traefik dynamic config?" "y")"

    if [[ "$proxmox_yn" =~ ^[Yy] ]]; then
        PROXMOX_ROUTE_ENABLED="y"
        default_proxmox_prefix="$(proxmox_prefix_default)"
        validate_subdomain_prefix "$default_proxmox_prefix" || default_proxmox_prefix="proxmox"
        PROXMOX_PREFIX="$default_proxmox_prefix"
        PROXMOX_HOST="$(hostname_from_prefix "$PROXMOX_PREFIX" "$DOMAIN_VALUE")"

        if [ -n "$(read_existing_env_value "PROXMOX_HOST")" ]; then
            PROXMOX_ROUTE_SOURCE="existing-env"
        elif [ -n "${PROXMOX_MARKER_HOSTNAME:-}" ] || [ -n "${PROXMOX_MARKER_FQDN:-}" ]; then
            PROXMOX_ROUTE_SOURCE="marker/default"
        else
            PROXMOX_ROUTE_SOURCE="default"
        fi

        if [ -n "$default_proxmox_url" ]; then
            PROXMOX_URL="$default_proxmox_url"
        else
            while true; do
                PROXMOX_URL="$(timed_text_input "Enter Proxmox LAN URL" "")"
                PROXMOX_URL="$(trim_value "$PROXMOX_URL")"

                if validate_proxmox_lan_url "$PROXMOX_URL"; then
                    PROXMOX_URL_SOURCE="user"
                    break
                fi

                msg_warn "Invalid Proxmox LAN URL. Use http:// or https:// URL format with port 8006."
            done
        fi

        aligned_value_line "Route" "enabled" "$GN" 21
        aligned_value_line "Source" "$PROXMOX_ROUTE_SOURCE" "$GN" 21
    else
        PROXMOX_ROUTE_ENABLED="n"
        PROXMOX_PREFIX=""
        PROXMOX_HOST=""
        PROXMOX_URL=""
        PROXMOX_ROUTE_SOURCE="skipped"
        aligned_value_line "Route" "skipped" "$GN" 21
        aligned_value_line "Source" "$PROXMOX_ROUTE_SOURCE" "$GN" 21
    fi

    return 0
}

function collect_service_hostnames() {
    setup_options_group_header "Service URLs"

    local d="${DOMAIN_VALUE}"
    local def_landing="${d}"
    local def_landing_www_prefix="www"
    local def_authentik_prefix="auth"
    local def_traefik_prefix="traefik"
    local def_admin_prefix="dockge"
        local def_postiz_prefix="app"
    local def_n8n_prefix="n8n"
        local def_proxmox_prefix=""

    local landing_www_prefix=""
    local authentik_prefix=""
    local traefik_prefix=""
    local admin_prefix=""
    local proxmox_prefix=""
    local postiz_prefix=""
    local n8n_prefix=""
    local existing_landing=""
    local existing_landing_www=""
    local existing_authentik=""
    local existing_traefik=""
    local existing_admin=""
        local existing_proxmox=""
    local existing_postiz=""
    local existing_n8n=""
        local customize=""
    local confirm=""

    case "$ADMIN_UI" in
        dockge) def_admin_prefix="dockge" ;;
        portainer|portainer-ce) def_admin_prefix="portainer" ;;
        komodo) def_admin_prefix="komodo" ;;
        dockhand) def_admin_prefix="dockhand" ;;
        *) def_admin_prefix="dockge" ;;
    esac

    if [ -n "${DOCKER_DIR:-}" ] && [ -f "${DOCKER_DIR}/.env" ]; then
        existing_landing="$(read_existing_env_value "LANDING_HOST")"
        existing_landing_www="$(read_existing_env_value "LANDING_WWW_HOST")"
        existing_authentik="$(read_existing_env_value "AUTHENTIK_ROUTE_HOST")"
        if [ -z "$existing_authentik" ]; then
            existing_authentik="$(read_existing_env_value "AUTHENTIK_HOST")"
        fi
        existing_traefik="$(read_existing_env_value "TRAEFIK_HOST")"
        existing_admin="$(read_existing_env_value "ADMIN_UI_HOST")"
        existing_proxmox="$(read_existing_env_value "PROXMOX_HOST")"
        existing_postiz="$(read_existing_env_value "POSTIZ_HOST")"
        existing_n8n="$(read_existing_env_value "N8N_HOST")"
    fi

    if [ -n "${ADMIN_UI_HOST:-}" ]; then
        existing_admin="${ADMIN_UI_HOST}"
    fi

    LANDING_HOST="$def_landing"
    if [ -n "$existing_landing" ] && [ "$(lowercase_value "$(bare_host_from_url_or_host "$existing_landing")")" != "$(lowercase_value "$d")" ]; then
        msg_warn "Existing Landing page hostname is outside the configured domain and cannot be used in normal mode. Landing root will remain ${d}."
    fi

    landing_www_prefix="$(prefix_from_hostname "$existing_landing_www" "$d" "$def_landing_www_prefix" "Landing www")"
    authentik_prefix="$(prefix_from_hostname "$existing_authentik" "$d" "$def_authentik_prefix" "Authentik")"
    traefik_prefix="$(prefix_from_hostname "$existing_traefik" "$d" "$def_traefik_prefix" "Traefik")"
    admin_prefix="$(prefix_from_hostname "$existing_admin" "$d" "$def_admin_prefix" "Admin UI")"
    postiz_prefix="$(prefix_from_hostname "$existing_postiz" "$d" "$def_postiz_prefix" "Postiz app")"
    n8n_prefix="$(prefix_from_hostname "$existing_n8n" "$d" "$def_n8n_prefix" "n8n")"

    if [ "$PROXMOX_ROUTE_ENABLED" == "y" ]; then
        def_proxmox_prefix="${PROXMOX_PREFIX:-$(proxmox_prefix_default)}"
        validate_subdomain_prefix "$def_proxmox_prefix" || def_proxmox_prefix="proxmox"
        proxmox_prefix="$(prefix_from_hostname "${existing_proxmox:-${PROXMOX_HOST:-}}" "$d" "$def_proxmox_prefix" "Proxmox")"
    fi

    LANDING_WWW_HOST="$(hostname_from_prefix "$landing_www_prefix" "$d")"
    AUTHENTIK_ROUTE_HOST_VALUE="$(hostname_from_prefix "$authentik_prefix" "$d")"
    AUTHENTIK_HOST="$AUTHENTIK_ROUTE_HOST_VALUE"
    TRAEFIK_HOST="$(hostname_from_prefix "$traefik_prefix" "$d")"
    TRAEFIK_DASHBOARD_HOST="$TRAEFIK_HOST"
    ADMIN_UI_HOST="$(hostname_from_prefix "$admin_prefix" "$d")"
    ADMIN_UI_URL="https://${ADMIN_UI_HOST}"
    if [ "$PROXMOX_ROUTE_ENABLED" == "y" ]; then
        PROXMOX_PREFIX="$proxmox_prefix"
        PROXMOX_HOST="$(hostname_from_prefix "$PROXMOX_PREFIX" "$d")"
    fi
    POSTIZ_HOST="$(hostname_from_prefix "$postiz_prefix" "$d")"
    N8N_HOST="$(hostname_from_prefix "$n8n_prefix" "$d")"
    AUTHENTIK_EXTERNAL_URL_VALUE="https://${AUTHENTIK_ROUTE_HOST_VALUE}"
    AUTHENTIK_HOST_VALUE="$AUTHENTIK_EXTERNAL_URL_VALUE"
    AUTHENTIK_HOST_BROWSER_VALUE="$AUTHENTIK_EXTERNAL_URL_VALUE"

    aligned_value_line "Landing page" "$LANDING_HOST" "$GN" 21
    aligned_value_line "Landing www" "$LANDING_WWW_HOST" "$GN" 21
    aligned_value_line "Authentik" "$AUTHENTIK_ROUTE_HOST_VALUE" "$GN" 21
    aligned_value_line "Traefik" "$TRAEFIK_HOST" "$GN" 21
    aligned_value_line "Admin UI" "$ADMIN_UI_HOST" "$GN" 21
    if [ "$PROXMOX_ROUTE_ENABLED" == "y" ]; then
        aligned_value_line "Proxmox" "$PROXMOX_HOST" "$GN" 21
    fi
    aligned_value_line "Postiz/Circl8 app" "$POSTIZ_HOST" "$GN" 21
    aligned_value_line "n8n" "$N8N_HOST" "$GN" 21
    echo ""

    customize="$(timed_yes_no "Customize service hostnames?" "N")"

    if [[ "$customize" =~ ^[Nn]$ ]]; then
        msg_ok "Service URLs set to defaults/preserved values"
        return 0
    fi

    local original_landing_www_prefix="$landing_www_prefix"
    local original_authentik_prefix="$authentik_prefix"
    local original_traefik_prefix="$traefik_prefix"
    local original_admin_prefix="$admin_prefix"
    local original_proxmox_prefix="$proxmox_prefix"
    local original_postiz_prefix="$postiz_prefix"
    local original_n8n_prefix="$n8n_prefix"

    echo -e "${BL}Landing root host remains:${CL} ${GN}${LANDING_HOST}${CL}"
    echo -e "${YW}Enter subdomain prefixes only. Script 6 will append .${DOMAIN_VALUE}.${CL}"
    echo ""

    landing_www_prefix="$(prompt_subdomain_prefix "Landing www subdomain" "$landing_www_prefix")"
    authentik_prefix="$(prompt_subdomain_prefix "Authentik subdomain" "$authentik_prefix")"
    traefik_prefix="$(prompt_subdomain_prefix "Traefik subdomain" "$traefik_prefix")"
    admin_prefix="$(prompt_subdomain_prefix "Admin UI subdomain" "$admin_prefix")"
    if [ "$PROXMOX_ROUTE_ENABLED" == "y" ]; then
        proxmox_prefix="$(prompt_subdomain_prefix "Proxmox subdomain" "$proxmox_prefix")"
    fi
    postiz_prefix="$(prompt_subdomain_prefix "Postiz app subdomain" "$postiz_prefix")"
    n8n_prefix="$(prompt_subdomain_prefix "n8n subdomain" "$n8n_prefix")"

    LANDING_WWW_HOST="$(hostname_from_prefix "$landing_www_prefix" "$d")"
    AUTHENTIK_ROUTE_HOST_VALUE="$(hostname_from_prefix "$authentik_prefix" "$d")"
    AUTHENTIK_HOST="$AUTHENTIK_ROUTE_HOST_VALUE"
    TRAEFIK_HOST="$(hostname_from_prefix "$traefik_prefix" "$d")"
    TRAEFIK_DASHBOARD_HOST="$TRAEFIK_HOST"
    ADMIN_UI_HOST="$(hostname_from_prefix "$admin_prefix" "$d")"
    ADMIN_UI_URL="https://${ADMIN_UI_HOST}"
    if [ "$PROXMOX_ROUTE_ENABLED" == "y" ]; then
        PROXMOX_PREFIX="$proxmox_prefix"
        PROXMOX_HOST="$(hostname_from_prefix "$PROXMOX_PREFIX" "$d")"
        PROXMOX_ROUTE_SOURCE="user"
    fi
    POSTIZ_HOST="$(hostname_from_prefix "$postiz_prefix" "$d")"
    N8N_HOST="$(hostname_from_prefix "$n8n_prefix" "$d")"
    AUTHENTIK_EXTERNAL_URL_VALUE="https://${AUTHENTIK_ROUTE_HOST_VALUE}"
    AUTHENTIK_HOST_VALUE="$AUTHENTIK_EXTERNAL_URL_VALUE"
    AUTHENTIK_HOST_BROWSER_VALUE="$AUTHENTIK_EXTERNAL_URL_VALUE"

    echo ""
    confirm="$(timed_yes_no "Write these hostnames to .env?" "Y")"
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        msg_ok "Hostnames will be written into .env when write_env_file() runs"
    else
        msg_skip "Hostname changes cancelled; safe defaults/preserved values under ${DOMAIN_VALUE} will be used"
        LANDING_WWW_HOST="$(hostname_from_prefix "$original_landing_www_prefix" "$d")"
        AUTHENTIK_ROUTE_HOST_VALUE="$(hostname_from_prefix "$original_authentik_prefix" "$d")"
        AUTHENTIK_HOST="$AUTHENTIK_ROUTE_HOST_VALUE"
        TRAEFIK_HOST="$(hostname_from_prefix "$original_traefik_prefix" "$d")"
        TRAEFIK_DASHBOARD_HOST="$TRAEFIK_HOST"
        ADMIN_UI_HOST="$(hostname_from_prefix "$original_admin_prefix" "$d")"
        ADMIN_UI_URL="https://${ADMIN_UI_HOST}"
        if [ "$PROXMOX_ROUTE_ENABLED" == "y" ]; then
            PROXMOX_PREFIX="$original_proxmox_prefix"
            PROXMOX_HOST="$(hostname_from_prefix "$PROXMOX_PREFIX" "$d")"
        fi
        POSTIZ_HOST="$(hostname_from_prefix "$original_postiz_prefix" "$d")"
        N8N_HOST="$(hostname_from_prefix "$original_n8n_prefix" "$d")"
        AUTHENTIK_EXTERNAL_URL_VALUE="https://${AUTHENTIK_ROUTE_HOST_VALUE}"
        AUTHENTIK_HOST_VALUE="$AUTHENTIK_EXTERNAL_URL_VALUE"
        AUTHENTIK_HOST_BROWSER_VALUE="$AUTHENTIK_EXTERNAL_URL_VALUE"
    fi
}

function collect_traefik_inputs() {
    TRAEFIK_DASHBOARD_HOST="${TRAEFIK_HOST:-traefik.${DOMAIN_VALUE}}"

    if ! validate_domain "$TRAEFIK_DASHBOARD_HOST"; then
        msg_error "Traefik dashboard host is invalid after Service URLs collection."
    fi

    TRAEFIK_DIR="${DOCKER_DIR}/appdata/traefik"
    TRAEFIK_ACME_DIR="${TRAEFIK_DIR}/acme"
    TRAEFIK_STATIC_CONFIG_FILE="${TRAEFIK_DIR}/traefik.yml"
    TRAEFIK_DYNAMIC_CONFIG_FILE="${TRAEFIK_DIR}/dynamic-config.yml"

    return 0
}

function collect_htpasswd_inputs() {
    local has_htpasswd_yn=""
    local create_htpasswd_yn=""

    setup_options_group_header "Optional htpasswd"

    echo -e "${BL}Optional Traefik basic-auth credentials.${CL}"
    echo -e "${YW}Skip this when Authentik/SSO is used for access control.${CL}"
    echo ""

    has_htpasswd_yn="$(timed_yes_no "Do you already have a hashed htpasswd line?" "n")"

    if [[ "$has_htpasswd_yn" =~ ^[Yy] ]]; then
        HTPASSWD_LINE_VALUE="$(sensitive_visible_line_input "Paste full htpasswd line username:hash")"

        HTPASSWD_LINE_VALUE="$(normalize_htpasswd_line "$HTPASSWD_LINE_VALUE")"

        if [ -n "$HTPASSWD_LINE_VALUE" ]; then
            if validate_htpasswd_line "$HTPASSWD_LINE_VALUE"; then
                HTPASSWD_MODE="provided"
                msg_ok "htpasswd line captured"
            else
                HTPASSWD_LINE_VALUE=""
                HTPASSWD_MODE="empty"
                msg_warn "Provided htpasswd line did not look valid. Empty placeholder will be used unless an existing file is present."
            fi
        else
            HTPASSWD_MODE="empty"
            msg_skip "htpasswd skipped"
        fi
    else
        create_htpasswd_yn="$(timed_yes_no "Create htpasswd entry now?" "n")"

        if [[ "$create_htpasswd_yn" =~ ^[Yy] ]]; then
            HTPASSWD_USER_VALUE="$(timed_text_input "Enter htpasswd username" "$DEFAULT_HTPASSWD_USER")"

            HTPASSWD_PASSWORD_VALUE="$(sensitive_visible_line_input "Enter htpasswd password" "htpasswd password captured")"

            if [ -n "$HTPASSWD_PASSWORD_VALUE" ]; then
                HTPASSWD_HASH_VALUE="$(openssl passwd -apr1 "$HTPASSWD_PASSWORD_VALUE")"
                HTPASSWD_LINE_VALUE="${HTPASSWD_USER_VALUE}:${HTPASSWD_HASH_VALUE}"
                HTPASSWD_PASSWORD_VALUE=""
                HTPASSWD_MODE="generated"
                aligned_value_line "htpasswd line" "generated" "$GN" 15
            else
                HTPASSWD_MODE="empty"
                msg_warn "htpasswd password was empty. Empty placeholder will be used unless an existing file is present."
            fi
        else
            HTPASSWD_MODE="empty"
            msg_skip "htpasswd skipped"
        fi
    fi
}

# --- 47AA. ADMIN UI DETAIL HELPER ---
# Derives the formal admin UI display name, hostname and URL from the selected admin UI key.
function set_admin_ui_details() {
    case "$ADMIN_UI" in
        dockge)
            ADMIN_UI_DISPLAY_NAME="Dockge"
            ADMIN_UI_HOST="dockge.${DOMAIN_VALUE}"
            ;;
        portainer|portainer-ce)
            ADMIN_UI="portainer"
            ADMIN_UI_DISPLAY_NAME="Portainer"
            ADMIN_UI_HOST="portainer.${DOMAIN_VALUE}"
            ;;
        komodo)
            ADMIN_UI_DISPLAY_NAME="Komodo"
            ADMIN_UI_HOST="komodo.${DOMAIN_VALUE}"
            ;;
        dockhand)
            ADMIN_UI_DISPLAY_NAME="Dockhand"
            ADMIN_UI_HOST="dockhand.${DOMAIN_VALUE}"
            ;;
        *)
            ADMIN_UI="dockge"
            ADMIN_UI_DISPLAY_NAME="Dockge"
            ADMIN_UI_HOST="dockge.${DOMAIN_VALUE}"
            ;;
    esac

    ADMIN_UI_URL="https://${ADMIN_UI_HOST}"
}

# --- 47A. ADMIN UI SELECTION ---
# Selects the container management interface once during configuration generation.
function collect_admin_ui_selection() {
    local choice=""
    local default_choice="1"

    setup_options_group_header "Admin UI"

    echo -e "  ${YW}1)${CL} Dockge"
    echo -e "  ${YW}2)${CL} Portainer CE"
    echo -e "  ${YW}3)${CL} Komodo"
    echo -e "  ${YW}4)${CL} Dockhand"
    echo ""

    while true; do
        choice="$(numeric_menu_input "Select admin UI option [1-4]" "$default_choice" "1" "4")"

        case "$choice" in
            1) ADMIN_UI="dockge"; break ;;
            2) ADMIN_UI="portainer"; break ;;
            3) ADMIN_UI="komodo"; break ;;
            4) ADMIN_UI="dockhand"; break ;;
            *) msg_warn "Invalid admin UI selection. Choose 1, 2, 3, or 4." ;;
        esac
    done

    set_admin_ui_details

    msg_ok "Admin UI default preseeded for Script 6.2: ${ADMIN_UI_DISPLAY_NAME}"

    return 0
}

function collect_authentik_inputs() {
    local password_choice=""
    local token_choice=""

    setup_options_group_header "Authentik bootstrap"

    AUTHENTIK_ROUTE_HOST_VALUE="$(bare_host_from_url_or_host "${AUTHENTIK_ROUTE_HOST_VALUE:-auth.${DOMAIN_VALUE}}")"
    AUTHENTIK_EXTERNAL_URL_VALUE="https://${AUTHENTIK_ROUTE_HOST_VALUE}"
    AUTHENTIK_HOST_VALUE="$AUTHENTIK_EXTERNAL_URL_VALUE"
    AUTHENTIK_HOST_BROWSER_VALUE="$AUTHENTIK_EXTERNAL_URL_VALUE"

    refresh_authentik_route_url_values
    if [[ "$(lowercase_value "$AUTHENTIK_ROUTE_HOST_VALUE")" != *."$(lowercase_value "$DOMAIN_VALUE")" ]]; then
        msg_warn "Authentik route host is outside the configured domain. Resetting route to auth.${DOMAIN_VALUE}."
        AUTHENTIK_ROUTE_HOST_VALUE="auth.${DOMAIN_VALUE}"
        AUTHENTIK_EXTERNAL_URL_VALUE="https://${AUTHENTIK_ROUTE_HOST_VALUE}"
        AUTHENTIK_HOST_VALUE="$AUTHENTIK_EXTERNAL_URL_VALUE"
        AUTHENTIK_HOST_BROWSER_VALUE="$AUTHENTIK_EXTERNAL_URL_VALUE"
    fi

    if ! validate_email "${AUTHENTIK_BOOTSTRAP_EMAIL_VALUE:-}"; then
        AUTHENTIK_BOOTSTRAP_EMAIL_VALUE="admin@${DOMAIN_VALUE}"
    fi

    echo -e "${YW}Password:${CL}"
    echo -e "  ${BL}1)${CL} Auto-generate password ${GN}(recommended)${CL}"
    echo -e "  ${BL}2)${CL} Enter custom password"
    echo ""

    password_choice="$(numeric_menu_input "Select Authentik bootstrap password option [1-2]" "1" "1" "2")"
    case "$password_choice" in
        2)
            AUTHENTIK_BOOTSTRAP_PASSWORD_VALUE="$(sensitive_visible_line_input "Enter Authentik bootstrap admin password" "Authentik custom bootstrap password captured")" || AUTHENTIK_BOOTSTRAP_PASSWORD_VALUE=""
            AUTHENTIK_BOOTSTRAP_PASSWORD_VALUE="$(trim_value "$AUTHENTIK_BOOTSTRAP_PASSWORD_VALUE")"
            [ -n "$AUTHENTIK_BOOTSTRAP_PASSWORD_VALUE" ] || msg_error "Authentik bootstrap password cannot be empty."
            AUTHENTIK_BOOTSTRAP_PASSWORD_MODE="custom"
            ;;
        *)
            AUTHENTIK_BOOTSTRAP_PASSWORD_VALUE="$(generate_secret)"
            AUTHENTIK_BOOTSTRAP_PASSWORD_MODE="auto"
            msg_ok "Authentik bootstrap password generated"
            ;;
    esac

    echo ""
    echo -e "${YW}Bootstrap/API token:${CL}"
    echo -e "  ${BL}1)${CL} Auto-generate bootstrap/API token ${GN}(recommended)${CL}"
    echo -e "  ${BL}2)${CL} Enter custom bootstrap/API token"
    echo -e "  ${BL}3)${CL} Skip API automation"
    echo ""

    token_choice="$(numeric_menu_input "Select Authentik bootstrap/API token option [1-3]" "1" "1" "3")"
    case "$token_choice" in
        2)
            AUTHENTIK_BOOTSTRAP_TOKEN_VALUE="$(sensitive_visible_line_input "Enter Authentik bootstrap/API token" "Authentik custom bootstrap API token captured")" || AUTHENTIK_BOOTSTRAP_TOKEN_VALUE=""
            AUTHENTIK_BOOTSTRAP_TOKEN_VALUE="$(trim_value "$AUTHENTIK_BOOTSTRAP_TOKEN_VALUE")"
            [ -n "$AUTHENTIK_BOOTSTRAP_TOKEN_VALUE" ] || msg_error "Authentik bootstrap/API token cannot be empty."
            AUTHENTIK_BOOTSTRAP_TOKEN_MODE="custom"
            AUTHENTIK_API_TOKEN_MODE="bootstrap"
            AUTHENTIK_API_TOKEN_VALUE="$AUTHENTIK_BOOTSTRAP_TOKEN_VALUE"
            ;;
        3)
            AUTHENTIK_BOOTSTRAP_TOKEN_VALUE="$(generate_secret)"
            AUTHENTIK_BOOTSTRAP_TOKEN_MODE="auto"
            AUTHENTIK_API_TOKEN_MODE="skip"
            AUTHENTIK_API_TOKEN_VALUE=""
            msg_ok "Authentik API automation skipped"
            ;;
        *)
            AUTHENTIK_BOOTSTRAP_TOKEN_VALUE="$(generate_secret)"
            AUTHENTIK_BOOTSTRAP_TOKEN_MODE="auto"
            AUTHENTIK_API_TOKEN_MODE="bootstrap"
            AUTHENTIK_API_TOKEN_VALUE="$AUTHENTIK_BOOTSTRAP_TOKEN_VALUE"
            msg_ok "Authentik bootstrap API token generated"
            ;;
    esac

    return 0
}

function collect_authentik_email_smtp_inputs() {
    local configure_choice=""
    local existing_host=""
    local existing_port=""
    local existing_username=""
    local existing_password=""
    local existing_use_tls=""
    local existing_use_ssl=""
    local existing_timeout=""
    local existing_from=""
    local password_rotate=""
    local has_existing_smtp="no"
    local use_defaults=""
    local show_smtp_plan="no"
    local defaults_selected="no"

    setup_options_group_header "Authentik SMTP relay"

    if [ -n "${DOCKER_DIR:-}" ] && [ -f "${DOCKER_DIR}/.env" ]; then
        existing_host="$(read_existing_env_value "AUTHENTIK_EMAIL__HOST")"
        existing_port="$(read_existing_env_value "AUTHENTIK_EMAIL__PORT")"
        existing_username="$(read_existing_env_value "AUTHENTIK_EMAIL__USERNAME")"
        existing_password="$(read_existing_env_value "AUTHENTIK_EMAIL__PASSWORD")"
        existing_use_tls="$(read_existing_env_value "AUTHENTIK_EMAIL__USE_TLS")"
        existing_use_ssl="$(read_existing_env_value "AUTHENTIK_EMAIL__USE_SSL")"
        existing_timeout="$(read_existing_env_value "AUTHENTIK_EMAIL__TIMEOUT")"
        existing_from="$(read_existing_env_value "AUTHENTIK_EMAIL__FROM")"
    fi

    if [ -n "${AUTHENTIK_EMAIL__HOST:-}" ] || [ -n "${AUTHENTIK_EMAIL__USERNAME:-}" ] || [ -n "${AUTHENTIK_EMAIL__PASSWORD:-}" ] || [ -n "$existing_host" ] || [ -n "$existing_username" ] || [ -n "$existing_password" ]; then
        has_existing_smtp="yes"
    fi

    AUTHENTIK_EMAIL__HOST_VALUE="${AUTHENTIK_EMAIL__HOST:-${existing_host:-smtp-relay.brevo.com}}"
    AUTHENTIK_EMAIL__PORT_VALUE="${AUTHENTIK_EMAIL__PORT:-${existing_port:-587}}"
    AUTHENTIK_EMAIL__USERNAME_VALUE="${AUTHENTIK_EMAIL__USERNAME:-${existing_username:-}}"
    AUTHENTIK_EMAIL__PASSWORD_VALUE="${AUTHENTIK_EMAIL__PASSWORD:-${existing_password:-}}"
    AUTHENTIK_EMAIL__USE_TLS_VALUE="${AUTHENTIK_EMAIL__USE_TLS:-${existing_use_tls:-true}}"
    AUTHENTIK_EMAIL__USE_SSL_VALUE="${AUTHENTIK_EMAIL__USE_SSL:-${existing_use_ssl:-false}}"
    AUTHENTIK_EMAIL__TIMEOUT_VALUE="${AUTHENTIK_EMAIL__TIMEOUT:-${existing_timeout:-30}}"
    AUTHENTIK_EMAIL__FROM_VALUE="${AUTHENTIK_EMAIL__FROM:-${existing_from:-Circl8 <no-reply@${DOMAIN_VALUE}>}}"

    if [ "$has_existing_smtp" == "yes" ]; then
        echo -e "${YW}Existing SMTP settings:${CL}"
        aligned_value_line "SMTP host" "${AUTHENTIK_EMAIL__HOST_VALUE:-not configured}" "$GN" 21
        aligned_value_line "SMTP port" "${AUTHENTIK_EMAIL__PORT_VALUE:-587}" "$GN" 21
        aligned_value_line "SMTP username" "$( [ -n "$AUTHENTIK_EMAIL__USERNAME_VALUE" ] && echo set || echo missing)" "$GN" 21
        aligned_value_line "SMTP from" "${AUTHENTIK_EMAIL__FROM_VALUE:-not set}" "$GN" 21
        aligned_value_line "TLS/SSL" "${AUTHENTIK_EMAIL__USE_TLS_VALUE}/${AUTHENTIK_EMAIL__USE_SSL_VALUE}" "$GN" 21
        aligned_value_line "Timeout" "${AUTHENTIK_EMAIL__TIMEOUT_VALUE:-30}s" "$GN" 21
        echo ""

        configure_choice="$(timed_yes_no "Update Authentik SMTP relay settings?" "N")"
        if [[ "$configure_choice" =~ ^[Nn]$ ]]; then
            msg_ok "Authentik SMTP relay settings preserved"
            return 0
        fi

        show_smtp_plan="yes"
    else
        echo -e "${YW}Defaults:${CL}"
        aligned_value_line "SMTP host" "${AUTHENTIK_EMAIL__HOST_VALUE}" "$GN" 21
        aligned_value_line "SMTP port" "${AUTHENTIK_EMAIL__PORT_VALUE}" "$GN" 21
        aligned_value_line "SMTP from" "${AUTHENTIK_EMAIL__FROM_VALUE}" "$GN" 21
        aligned_value_line "TLS/SSL" "${AUTHENTIK_EMAIL__USE_TLS_VALUE}/${AUTHENTIK_EMAIL__USE_SSL_VALUE}" "$GN" 21
        aligned_value_line "Timeout" "${AUTHENTIK_EMAIL__TIMEOUT_VALUE}s" "$GN" 21
        echo ""

        use_defaults="$(timed_yes_no "Use these SMTP defaults?" "Y")"
        if [[ "$use_defaults" =~ ^[Yy]$ ]]; then
            defaults_selected="yes"
        else
            show_smtp_plan="yes"
        fi
    fi

    if [ "$show_smtp_plan" == "yes" ]; then
        while true; do
            AUTHENTIK_EMAIL__HOST_VALUE="$(hostname_input "Enter Authentik SMTP host" "${AUTHENTIK_EMAIL__HOST_VALUE:-smtp-relay.brevo.com}")"
            if [ -n "$AUTHENTIK_EMAIL__HOST_VALUE" ]; then
                break
            fi
            msg_warn "SMTP host cannot be empty."
        done

        AUTHENTIK_EMAIL__PORT_VALUE="$(text_input "Enter Authentik SMTP port" "${AUTHENTIK_EMAIL__PORT_VALUE:-587}")"
    fi

    AUTHENTIK_EMAIL__USERNAME_VALUE="$(text_input "Enter Authentik SMTP username" "${AUTHENTIK_EMAIL__USERNAME_VALUE:-}")"

    if [ "$has_existing_smtp" == "yes" ] && [ -n "${AUTHENTIK_EMAIL__PASSWORD_VALUE:-}" ]; then
        password_rotate="$(timed_yes_no "Rotate/update Authentik SMTP password?" "N")"
        if [[ "$password_rotate" =~ ^[Yy]$ ]]; then
            AUTHENTIK_EMAIL__PASSWORD_VALUE="$(sensitive_visible_line_input "Enter Authentik SMTP password" "Authentik SMTP password captured")" || AUTHENTIK_EMAIL__PASSWORD_VALUE=""
        else
            msg_ok "Existing Authentik SMTP password preserved"
        fi
    else
        AUTHENTIK_EMAIL__PASSWORD_VALUE="$(sensitive_visible_line_input "Enter Authentik SMTP password" "Authentik SMTP password captured")" || AUTHENTIK_EMAIL__PASSWORD_VALUE=""
    fi

    AUTHENTIK_EMAIL__PASSWORD_VALUE="$(printf '%s' "$AUTHENTIK_EMAIL__PASSWORD_VALUE" | tr -d '\r\n')"
    [ -n "$AUTHENTIK_EMAIL__PASSWORD_VALUE" ] || msg_error "Authentik SMTP password cannot be empty when SMTP host is configured."

    if [ "$show_smtp_plan" == "yes" ]; then
        AUTHENTIK_EMAIL__FROM_VALUE="$(text_input "Enter Authentik SMTP sender address" "${AUTHENTIK_EMAIL__FROM_VALUE}")"
        AUTHENTIK_EMAIL__TIMEOUT_VALUE="$(text_input "Enter Authentik SMTP timeout seconds" "${AUTHENTIK_EMAIL__TIMEOUT_VALUE:-30}")"
    fi
}
# --- 47C. SETUP PLAN SUMMARY ---
# Shows every collected setting before directories, secrets, .env, templates or permissions are written.
function show_ready_summary_and_confirm() {
    local apply_yn=""
    local cloudflare_auth_summary=""
    local cloudflare_token_summary=""
    local smtp_summary="skipped"
    local service_secret_summary="generate new"
    local bootstrap_summary=""

    section "SETUP PLAN"

    if [ "$CF_AUTH_MODE" == "api_token" ]; then
        cloudflare_auth_summary="API token captured"
        cloudflare_token_summary="captured"
    elif [ "$CF_AUTH_MODE" == "api_token_file_reuse" ]; then
        cloudflare_auth_summary="API token reused"
        cloudflare_token_summary="reused"
    elif [ "$CF_AUTH_MODE" == "email_or_manual" ]; then
        cloudflare_auth_summary="email/manual"
        cloudflare_token_summary="not provided"
    else
        cloudflare_auth_summary="${CF_AUTH_MODE:-unknown}"
        cloudflare_token_summary="unknown"
    fi

    if [ -n "${AUTHENTIK_EMAIL__HOST_VALUE:-}" ] && [ -n "${AUTHENTIK_EMAIL__USERNAME_VALUE:-}" ]; then
        smtp_summary="configured"
    fi

    if [ "$EXISTING_SETUP" == "yes" ] && [ "$REGENERATE_SECRETS" != "y" ]; then
        service_secret_summary="reuse existing"
    fi

    if [ "${AUTHENTIK_API_TOKEN_MODE:-skip}" == "skip" ]; then
        bootstrap_summary="$([ "${AUTHENTIK_BOOTSTRAP_PASSWORD_MODE:-auto}" == "custom" ] && echo "custom password" || echo "generated password") / API automation skipped"
    else
        bootstrap_summary="$([ "${AUTHENTIK_BOOTSTRAP_PASSWORD_MODE:-auto}" == "custom" ] && echo "custom password" || echo "generated password") / $([ "${AUTHENTIK_BOOTSTRAP_TOKEN_MODE:-auto}" == "custom" ] && echo "custom token" || echo "generated token")"
    fi

    echo -e "${YW}No Docker ENV files, secrets or templates have been written yet.${CL}"
    echo ""
    show_script5_handoff_summary
    echo ""
    echo -e "${YW}User / path:${CL}"
    aligned_value_line "Docker user" "$DOCKER_USER" "$GN" 21
    aligned_value_line "User home" "$USERDIR" "$GN" 21
    aligned_value_line "Docker directory" "$DOCKER_DIR" "$GN" 21
    echo ""
    echo -e "${YW}Domain / routing:${CL}"
    aligned_value_line "Domain" "$DOMAIN_VALUE" "$ANS" 21
    aligned_value_line "Cloudflare auth" "$cloudflare_auth_summary" "$ANS" 21
    if [ "$CF_EMAIL_REQUIRED" == "yes" ]; then
        aligned_value_line "Cloudflare email" "$CF_API_EMAIL_VALUE" "$GN" 21
    fi
    aligned_value_line "Proxmox route" "$(yes_no_label "$PROXMOX_ROUTE_ENABLED")" "$ANS" 21
    if [ "$PROXMOX_ROUTE_ENABLED" == "y" ]; then
        aligned_value_line "Proxmox LAN URL" "$PROXMOX_URL" "$GN" 21
    fi
    echo ""
    echo -e "${YW}Service URLs:${CL}"
    aligned_value_line "Landing page" "$LANDING_HOST" "$GN" 21
    aligned_value_line "Landing www" "$LANDING_WWW_HOST" "$GN" 21
    aligned_value_line "Authentik" "$AUTHENTIK_ROUTE_HOST_VALUE" "$GN" 21
    aligned_value_line "Traefik" "$TRAEFIK_HOST" "$GN" 21
    aligned_value_line "Admin UI" "$ADMIN_UI_HOST" "$GN" 21
    if [ "$PROXMOX_ROUTE_ENABLED" == "y" ]; then
        aligned_value_line "Proxmox" "$PROXMOX_HOST" "$GN" 21
    fi
    aligned_value_line "Postiz/Circl8 app" "$POSTIZ_HOST" "$GN" 21
    aligned_value_line "n8n" "$N8N_HOST" "$GN" 21
    echo ""
    echo -e "${YW}Applications:${CL}"
    aligned_value_line "Admin UI default" "$ADMIN_UI_DISPLAY_NAME" "$ANS" 21
    aligned_value_line "Authentik URL" "$AUTHENTIK_HOST_VALUE" "$ANS" 21
    aligned_value_line "ACME email" "$TRAEFIK_ACME_EMAIL_VALUE" "$ANS" 21
    aligned_value_line "Authentik email" "$AUTHENTIK_BOOTSTRAP_EMAIL_VALUE" "$ANS" 21
    aligned_value_line "SMTP relay" "$smtp_summary" "$GN" 21
    echo ""
    echo -e "${YW}Secrets:${CL}"
    aligned_value_line "Service secrets" "$service_secret_summary" "$GN" 21
    aligned_value_line "Cloudflare token" "$cloudflare_token_summary" "$GN" 21
    aligned_value_line "Authentik bootstrap" "$bootstrap_summary" "$ANS" 21
    if [ "$EXISTING_SETUP" == "yes" ]; then
        aligned_value_line "Regenerate secrets" "$(yes_no_label "$REGENERATE_SECRETS")" "$ANS" 21
    fi
    echo ""
    echo -e "${RD}After confirmation, Script 6 will create:${CL}"
    echo -e "  ${RD}folders, .env, secrets and Traefik config.${CL}"
    echo ""

    apply_yn="$(timed_yes_no "Apply this Docker ENV setup plan now?" "y")"

    if [[ "$apply_yn" =~ ^[Nn] ]]; then
        echo -e "${YW}Docker ENV setup cancelled. No Docker ENV/system-changing actions were applied.${CL}"
        exit 0
    fi

    return 0
}

# =========================================================
#  FILE / SECRET CREATION
# =========================================================

# --- 48. DOCKER DIRECTORY CREATION ---
# Creates project folders for compose, appdata, backups, shared files and secrets.
function create_docker_directories() {
    apply_group_header "Folder structure"

    msg_info "Creating Docker folder structure"
    ensure_required_service_directories
    tty_print "${BFR}"
    apply_status_line "created"
}


# --- 49. SECRET GENERATION / REUSE ---
# Generates service secrets on first run. On reruns, reuses existing secret files unless regeneration was explicitly selected.
function generate_or_reuse_secrets() {
    apply_group_header "Secret generation / reuse"

    msg_info "Generating or reusing 6-family service secrets"

    AUTHENTIK_SECRET_KEY="$(get_or_generate_secret "${DOCKER_SECRETS_DIR}/authentik_secret_key")"
    AUTHENTIK_POSTGRES_PASSWORD="$(get_or_generate_secret "${DOCKER_SECRETS_DIR}/authentik_postgres_password")"
    POSTIZ_POSTGRES_PASSWORD="$(get_or_generate_secret "${DOCKER_SECRETS_DIR}/postiz_postgres_password")"
    POSTIZ_REDIS_PASSWORD="$(get_or_generate_secret "${DOCKER_SECRETS_DIR}/postiz_redis_password")"
    POSTIZ_JWT_SECRET="$(get_or_generate_secret "${DOCKER_SECRETS_DIR}/postiz_jwt_secret")"
    TEMPORAL_POSTGRES_PASSWORD="$(get_or_generate_secret "${DOCKER_SECRETS_DIR}/temporal_postgres_password")"
    N8N_ENCRYPTION_KEY="$(get_or_generate_secret "${DOCKER_SECRETS_DIR}/n8n_encryption_key")"

    tty_print "${BFR}"
    apply_status_line "$(secret_generation_status_label)"
}

function create_postgres_init_script() {
    # Deprecated in Script 6 v1.7.0.
    # Service-owned databases are created by their owning 6-family deployment scripts.
    return 0
}

function create_traefik_config_files() {
    local static_template=""
    local dynamic_template=""

    apply_group_header "Traefik config files"

    msg_info "Preparing temporary Traefik template workspace"
    TRAEFIK_TEMPLATE_TMP_DIR="$(mktemp -d /tmp/traefik-template-render.XXXXXX)"
    TEMP_DIRS+=("$TRAEFIK_TEMPLATE_TMP_DIR")
    static_template="${TRAEFIK_TEMPLATE_TMP_DIR}/traefik.yml.template"
    dynamic_template="${TRAEFIK_TEMPLATE_TMP_DIR}/dynamic-config.yml.template"
    msg_ok "Template workspace ready"

    msg_info "Downloading Traefik static template"
    download_file "$TRAEFIK_STATIC_TEMPLATE_URL" "$static_template" || msg_error "Failed to download Traefik template: ${TRAEFIK_STATIC_TEMPLATE_URL}"
    msg_ok "Static template downloaded"

    msg_info "Downloading Traefik dynamic template"
    download_file "$TRAEFIK_DYNAMIC_TEMPLATE_URL" "$dynamic_template" || msg_error "Failed to download Traefik template: ${TRAEFIK_DYNAMIC_TEMPLATE_URL}"
    msg_ok "Dynamic template downloaded"

    msg_info "Rendering Traefik static config"
    render_traefik_template "$static_template" "$TRAEFIK_STATIC_CONFIG_FILE"
    msg_ok "Static config created"

    msg_info "Rendering Traefik dynamic config"
    render_traefik_template "$dynamic_template" "$TRAEFIK_DYNAMIC_CONFIG_FILE"
    msg_ok "Dynamic config created"

    msg_info "Securing Traefik ACME storage"
    run_cmd "setting Traefik ACME storage permissions" chmod 600 "${TRAEFIK_ACME_DIR}/acme.json"
    msg_ok "ACME storage ready"
}

# --- 50B. TRAEFIK CONFIG POST-RENDER VERIFICATION ---
# Verifies Traefik files immediately after rendering so Script 6 fails here, not later in Script 6.1.
function verify_traefik_config_files_created() {
    apply_group_header "Traefik config files"

    [ -f "$TRAEFIK_STATIC_CONFIG_FILE" ] || msg_error "Traefik static config was not created: ${TRAEFIK_STATIC_CONFIG_FILE}"
    [ -f "$TRAEFIK_DYNAMIC_CONFIG_FILE" ] || msg_error "Traefik dynamic config was not created: ${TRAEFIK_DYNAMIC_CONFIG_FILE}"
    [ -f "${TRAEFIK_ACME_DIR}/acme.json" ] || msg_error "Traefik ACME storage was not created: ${TRAEFIK_ACME_DIR}/acme.json"

    if grep -R '{{[^}]*}}' "$TRAEFIK_STATIC_CONFIG_FILE" "$TRAEFIK_DYNAMIC_CONFIG_FILE" >/dev/null 2>&1; then
        msg_error "Unrendered {{PLACEHOLDER}} values remain in Traefik config files."
    fi

    if ! grep -q "main: \"${DOMAIN_VALUE}\"" "$TRAEFIK_STATIC_CONFIG_FILE" 2>/dev/null && ! grep -q "main: ${DOMAIN_VALUE}" "$TRAEFIK_STATIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik static config does not contain the base wildcard certificate domain."
    fi

    if ! grep -q "\*.${DOMAIN_VALUE}" "$TRAEFIK_STATIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik static config does not contain the wildcard SAN for *.${DOMAIN_VALUE}."
    fi

    if ! grep -q 'traefik-dashboard:' "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik dynamic config does not contain the Traefik dashboard router."
    fi

    if ! grep -q "Host(\`${TRAEFIK_DASHBOARD_HOST}\`)" "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik dynamic config dashboard router does not contain the expected dashboard host."
    fi

    if ! grep -q 'chain-authentik@file' "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik dynamic config dashboard router is not Authentik-protected."
    fi

    if ! grep -q 'chain-basic-auth' "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik dynamic config does not contain the Basic Auth middleware chain."
    fi

    if ! grep -q 'middlewares-basic-auth' "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik dynamic config does not contain the Basic Auth middleware."
    fi

    if ! grep -q 'usersFile: /run/secrets/htpasswd' "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik dynamic config does not use the htpasswd usersFile secret."
    fi

    if ! grep -q 'certResolver: cloudflare' "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik dynamic config dashboard router does not contain the Cloudflare certResolver."
    fi

    if ! grep -q "main: \"${DOMAIN_VALUE}\"" "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null && ! grep -q "main: ${DOMAIN_VALUE}" "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik dynamic config dashboard router does not contain the base wildcard certificate domain."
    fi

    if ! grep -q "\*.${DOMAIN_VALUE}" "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik dynamic config dashboard router does not contain the wildcard SAN for *.${DOMAIN_VALUE}."
    fi

    if ! grep -q 'encoded-characters-safe:' "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik dynamic config does not contain encoded-characters-safe middleware."
    fi

    if ! grep -q 'allowEncodedSlash: true' "$TRAEFIK_DYNAMIC_CONFIG_FILE" 2>/dev/null; then
        msg_error "Traefik dynamic config does not allow encoded slashes in the reusable middleware."
    fi

    msg_ok "Config files verified"
}


# --- 51. SECRET FILE CREATION ---
# Writes generated/reused secrets to individual secret files.
function write_secret_files() {
    apply_group_header "Secret files"

    msg_info "Writing 6-family secret files"

    write_secret_file_no_newline "${DOCKER_SECRETS_DIR}/authentik_secret_key" "$AUTHENTIK_SECRET_KEY"
    write_secret_file_no_newline "${DOCKER_SECRETS_DIR}/authentik_postgres_password" "$AUTHENTIK_POSTGRES_PASSWORD"
    write_secret_file_no_newline "${DOCKER_SECRETS_DIR}/postiz_postgres_password" "$POSTIZ_POSTGRES_PASSWORD"
    write_secret_file_no_newline "${DOCKER_SECRETS_DIR}/postiz_redis_password" "$POSTIZ_REDIS_PASSWORD"
    write_secret_file_no_newline "${DOCKER_SECRETS_DIR}/postiz_jwt_secret" "$POSTIZ_JWT_SECRET"
    write_secret_file_no_newline "${DOCKER_SECRETS_DIR}/temporal_postgres_password" "$TEMPORAL_POSTGRES_PASSWORD"
    write_secret_file_no_newline "${DOCKER_SECRETS_DIR}/n8n_encryption_key" "$N8N_ENCRYPTION_KEY"

    if [ -n "$CF_API_TOKEN_VALUE" ]; then
        write_secret_file_no_newline "$CF_API_TOKEN_FILE" "$CF_API_TOKEN_VALUE"
    elif root_file_not_empty "$CF_API_TOKEN_FILE"; then
        msg_ok "EXISTING CLOUDFLARE TOKEN FILE PRESERVED"
    else
        run_cmd "creating empty Cloudflare API token placeholder" touch "$CF_API_TOKEN_FILE"
    fi

    if [ -n "$HTPASSWD_LINE_VALUE" ]; then
        HTPASSWD_LINE_VALUE="$(normalize_htpasswd_line "$HTPASSWD_LINE_VALUE")"
        write_secret_file_no_newline "${DOCKER_SECRETS_DIR}/htpasswd" "$HTPASSWD_LINE_VALUE"
    elif root_file_not_empty "${DOCKER_SECRETS_DIR}/htpasswd"; then
        HTPASSWD_LINE_VALUE="$(normalize_htpasswd_line "$(root_read_file "${DOCKER_SECRETS_DIR}/htpasswd" 2>/dev/null | head -n1 || true)")"
        if [ -n "$HTPASSWD_LINE_VALUE" ]; then
            write_secret_file_no_newline "${DOCKER_SECRETS_DIR}/htpasswd" "$HTPASSWD_LINE_VALUE"
        fi
        msg_ok "EXISTING HTPASSWD FILE PRESERVED"
    else
        run_cmd "creating empty htpasswd placeholder" touch "${DOCKER_SECRETS_DIR}/htpasswd"
    fi

    validate_htpasswd_secret_file_shape

    tty_print "${BFR}"
    apply_status_line "written"
}

function write_env_file() {
    apply_group_header ".env file"

    msg_info "Creating Docker .env file"

    local DOMAIN="${DOMAIN_VALUE}"

    refresh_authentik_route_url_values

    : "${DOMAIN_VALUE:?DOMAIN_VALUE is required before writing .env}"
    : "${DOCKER_DIR:?DOCKER_DIR is required before writing .env}"
    : "${DOCKER_SECRETS_DIR:?DOCKER_SECRETS_DIR is required before writing .env}"
    : "${USERDIR:?USERDIR is required before writing .env}"
    validate_email "${TRAEFIK_ACME_EMAIL_VALUE:-}" || msg_error "TRAEFIK_ACME_EMAIL_VALUE is required before writing .env"
    validate_email "${AUTHENTIK_BOOTSTRAP_EMAIL_VALUE:-}" || msg_error "AUTHENTIK_BOOTSTRAP_EMAIL_VALUE is required before writing .env"

    write_root_file "${DOCKER_DIR}/.env" <<EOF
# =========================================================
#  Project: Circl8
#  Owner: Script 6 v1.7.0 six-family environment baseline
#  Notes: Local runtime file. Do not commit real values or secrets.
# =========================================================

# --- Core paths ---
DOCKER_DIR="${DOCKER_DIR}"
DOCKER_SECRETS_DIR="${DOCKER_SECRETS_DIR}"
USERDIR="${USERDIR}"

# --- Linux user/container IDs ---
PUID="${PUID_VALUE}"
PGID="${PGID_VALUE}"
DOCKER_GID="${DOCKER_GID_VALUE}"

# --- Localisation ---
TZ="${TZ_VALUE}"

# --- Script 5 handoff ---
SCRIPT5_STATUS="${SCRIPT5_STATUS}"
SCRIPT5_VERSION="${SCRIPT5_VERSION}"
SCRIPT5_VERIFY_STATUS="${SCRIPT5_VERIFY_STATUS}"
SCRIPT5_SWAP_PRESERVE_SELECTED="${SCRIPT5_SWAP_PRESERVE_SELECTED}"
SCRIPT5_SWAP_RESULT="${SCRIPT5_SWAP_RESULT}"
SCRIPT5_SWAP_FILE="${SCRIPT5_SWAP_FILE}"
SCRIPT5_SWAP_SIZE="${SCRIPT5_SWAP_SIZE}"
SCRIPT5_UFW_ENABLED="${SCRIPT5_UFW_ENABLED}"
SCRIPT5_REDIS_OVERCOMMIT="${SCRIPT5_REDIS_OVERCOMMIT}"

# --- Domain / Cloudflare / Traefik ---
DOMAIN="${DOMAIN}"
CF_AUTH_MODE="${CF_AUTH_MODE}"
CF_EMAIL_REQUIRED="${CF_EMAIL_REQUIRED}"
CF_API_EMAIL="${CF_API_EMAIL_VALUE}"
CF_ZONE_ID="${CF_ZONE_ID_VALUE}"
CF_API_TOKEN_FILE="${CF_API_TOKEN_FILE}"
CF_TOKEN_FILE="${CF_API_TOKEN_FILE}"
CF_TOKEN_SECRET_NAME="cf_token"
PROXMOX_ROUTE_ENABLED="${PROXMOX_ROUTE_ENABLED}"
PROXMOX_PREFIX="${PROXMOX_PREFIX}"
PROXMOX_HOST="${PROXMOX_HOST}"
PROXMOX_URL="${PROXMOX_URL}"
PROXMOX_ROUTE_SOURCE="${PROXMOX_ROUTE_SOURCE}"
PROXMOX_URL_SOURCE="${PROXMOX_URL_SOURCE}"
TRAEFIK_DASHBOARD_HOST="${TRAEFIK_DASHBOARD_HOST}"
TRAEFIK_HOST="${TRAEFIK_HOST}"
TRAEFIK_STATIC_CONFIG_FILE="${TRAEFIK_STATIC_CONFIG_FILE}"
TRAEFIK_DYNAMIC_CONFIG_FILE="${TRAEFIK_DYNAMIC_CONFIG_FILE}"
TRAEFIK_ACME_STORAGE="${TRAEFIK_ACME_DIR}/acme.json"
TRAEFIK_ACME_EMAIL="${TRAEFIK_ACME_EMAIL_VALUE}"

# --- Script 6-family service hostnames ---
LANDING_HOST="${LANDING_HOST}"
LANDING_WWW_HOST="${LANDING_WWW_HOST}"
AUTHENTIK_ROUTE_HOST="${AUTHENTIK_ROUTE_HOST_VALUE}"
ADMIN_UI="${ADMIN_UI}"
ADMIN_UI_DISPLAY_NAME="${ADMIN_UI_DISPLAY_NAME}"
ADMIN_UI_HOST="${ADMIN_UI_HOST}"
ADMIN_UI_URL="${ADMIN_UI_URL}"
POSTIZ_HOST="${POSTIZ_HOST:-app.${DOMAIN_VALUE}}"
N8N_HOST="${N8N_HOST}"

# --- Authentik owned by Script 6.3 ---
AUTHENTIK_EXTERNAL_URL="${AUTHENTIK_EXTERNAL_URL_VALUE}"
AUTHENTIK_HOST="${AUTHENTIK_EXTERNAL_URL_VALUE}"
AUTHENTIK_HOST_BROWSER_VALUE="${AUTHENTIK_HOST_BROWSER_VALUE}"
AUTHENTIK_HOST_BROWSER="${AUTHENTIK_HOST_BROWSER_VALUE}"
AUTHENTIK_SECRET_KEY="${AUTHENTIK_SECRET_KEY}"
AUTHENTIK_POSTGRES_PASSWORD="${AUTHENTIK_POSTGRES_PASSWORD}"
AUTHENTIK_BOOTSTRAP_EMAIL="${AUTHENTIK_BOOTSTRAP_EMAIL_VALUE}"
AUTHENTIK_BOOTSTRAP_PASSWORD="${AUTHENTIK_BOOTSTRAP_PASSWORD_VALUE}"
AUTHENTIK_BOOTSTRAP_TOKEN="${AUTHENTIK_BOOTSTRAP_TOKEN_VALUE}"
AUTHENTIK_API_TOKEN_MODE="${AUTHENTIK_API_TOKEN_MODE}"
AUTHENTIK_API_TOKEN="${AUTHENTIK_API_TOKEN_VALUE}"
AUTHENTIK_DISABLE_UPDATE_CHECK="true"
AUTHENTIK_DISABLE_STARTUP_ANALYTICS="true"
AUTHENTIK_ERROR_REPORTING__ENABLED="false"
AUTHENTIK_EMAIL__HOST="${AUTHENTIK_EMAIL__HOST_VALUE:-}"
AUTHENTIK_EMAIL__PORT="${AUTHENTIK_EMAIL__PORT_VALUE:-587}"
AUTHENTIK_EMAIL__USERNAME="${AUTHENTIK_EMAIL__USERNAME_VALUE:-}"
AUTHENTIK_EMAIL__PASSWORD="${AUTHENTIK_EMAIL__PASSWORD_VALUE:-}"
AUTHENTIK_EMAIL__USE_TLS="${AUTHENTIK_EMAIL__USE_TLS_VALUE:-true}"
AUTHENTIK_EMAIL__USE_SSL="${AUTHENTIK_EMAIL__USE_SSL_VALUE:-false}"
AUTHENTIK_EMAIL__TIMEOUT="${AUTHENTIK_EMAIL__TIMEOUT_VALUE:-30}"
AUTHENTIK_EMAIL__FROM="${AUTHENTIK_EMAIL__FROM_VALUE:-Circl8 <no-reply@${DOMAIN_VALUE}>}"

# --- Postiz owned by Script 6.4 ---
POSTIZ_POSTGRES_PASSWORD="${POSTIZ_POSTGRES_PASSWORD}"
POSTIZ_REDIS_PASSWORD="${POSTIZ_REDIS_PASSWORD}"
POSTIZ_JWT_SECRET="${POSTIZ_JWT_SECRET}"
POSTIZ_HOST="${POSTIZ_HOST:-app.${DOMAIN_VALUE}}"
TEMPORAL_POSTGRES_PASSWORD="${TEMPORAL_POSTGRES_PASSWORD}"
TEMPORAL_DBNAME="temporal"
TEMPORAL_VISIBILITY_DBNAME="temporal_visibility"

# --- n8n owned by Script 6.5 ---
N8N_ENCRYPTION_KEY="${N8N_ENCRYPTION_KEY}"
N8N_DB_MODE="sqlite"
N8N_WEBHOOK_URL="https://${N8N_HOST}/"

# --- Images ---
# Image defaults are compose-owned. Script 7 can later record or pin verified running image digests.
EOF

    tty_print "${BFR}"
    apply_status_line "created"
}

function apply_permissions() {
    apply_group_header "Permissions"

    msg_info "Ensuring all required service folders exist"
    ensure_required_service_directories
    msg_ok "SERVICE FOLDERS CONFIRMED"

    msg_info "Applying service ownership"
    chown_required_service_directories
    msg_ok "SERVICE OWNERSHIP SET"

    msg_info "Applying service permissions"
    chmod_required_service_directories
    msg_ok "SERVICE PERMISSIONS SET"
}



# --- 53A. SERVICE PERMISSION AUDIT ---
# Fails early if Script 6 did not leave service bind mounts in the state required by the compose stacks.
function assert_owner_mode() {
    local path="$1"
    local expected_uid="$2"
    local expected_gid="$3"
    local expected_mode="$4"
    local actual=""

    # Use sudo-aware existence/stat checks because service paths such as
    # Some future service-owned paths may be locked to service-specific UIDs.
    # Use sudo-aware existence/stat checks so audits do not false-report paths as missing.
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" test -e "$path" || msg_error "Permission audit path missing: ${path}"
        actual="$("$SUDO_CMD" stat -c '%u:%g:%a' "$path" 2>/dev/null || true)"
    else
        test -e "$path" || msg_error "Permission audit path missing: ${path}"
        actual="$(stat -c '%u:%g:%a' "$path" 2>/dev/null || true)"
    fi

    if [ "$actual" != "${expected_uid}:${expected_gid}:${expected_mode}" ]; then
        msg_error "Permission audit failed for ${path}. Expected ${expected_uid}:${expected_gid}:${expected_mode}, got ${actual:-unknown}."
    fi

    permission_audit_line "PERMISSION OK:" "$path"
}


function assert_root_executable() {
    local path="$1"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" test -x "$path" || msg_error "Executable audit failed: ${path}"
    else
        test -x "$path" || msg_error "Executable audit failed: ${path}"
    fi

    permission_audit_line "EXECUTABLE OK:" "$path"
}


function assert_user_writable_dir() {
    local path="$1"
    local test_file="${path}/.script6-write-test-$$"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" test -d "$path" || msg_error "Writable audit path missing: ${path}"
        "$SUDO_CMD" -u "$DOCKER_USER" sh -c "touch '$test_file' && rm -f '$test_file'" >/dev/null 2>&1 || msg_error "Docker user ${DOCKER_USER} cannot write to ${path}"
    else
        test -d "$path" || msg_error "Writable audit path missing: ${path}"
        touch "$test_file" && rm -f "$test_file" >/dev/null 2>&1 || msg_error "Current user cannot write to ${path}"
    fi

    permission_audit_line "WRITABLE OK:" "$path"
}

function verify_service_permissions() {
    apply_group_header "Environment permission audit"

    assert_owner_mode "$DOCKER_DIR" "$(id -u "$DOCKER_USER")" "$(id -g "$DOCKER_USER")" "755"
    assert_owner_mode "${DOCKER_DIR}/appdata" "$(id -u "$DOCKER_USER")" "$(id -g "$DOCKER_USER")" "755"
    assert_user_writable_dir "${DOCKER_DIR}/compose"
    assert_user_writable_dir "${DOCKER_DIR}/backups"

    assert_owner_mode "$DOCKER_SECRETS_DIR" "$(id -u "$DOCKER_USER")" "$(id -g "$DOCKER_USER")" "700"
    assert_owner_mode "${DOCKER_DIR}/.env" "$(id -u "$DOCKER_USER")" "$(id -g "$DOCKER_USER")" "600"
    assert_owner_mode "${TRAEFIK_ACME_DIR}/acme.json" "$PUID_VALUE" "$PGID_VALUE" "600"

    PERMISSION_AUDIT_STATUS="PASS"
    msg_ok "ENVIRONMENT PERMISSION AUDIT PASSED"
}

function verify_record_first_issue() {
    local issue_type="$1"
    local check="$2"
    local reason="$3"
    local fix="$4"

    if [ -z "$VERIFY_FIRST_ISSUE_TYPE" ]; then
        VERIFY_FIRST_ISSUE_TYPE="$issue_type"
        VERIFY_FIRST_ISSUE_CHECK="$check"
        VERIFY_FIRST_ISSUE_REASON="$reason"
        VERIFY_FIRST_ISSUE_FIX="$fix"
    fi
}


function verify_docker_runtime_continuity() {
    refresh_docker_runtime_state

    if command -v docker >/dev/null 2>&1; then verify_pass "Docker CLI detected"; else verify_fail "Docker CLI detected" "docker command not found" "run Script 5 before deploying"; fi
    if [ "$SCRIPT5_DOCKER_INFO_READY" == "yes" ]; then verify_pass "Docker info succeeds"; else verify_fail "Docker info succeeds" "docker daemon is not responding" "run sudo systemctl status docker"; fi
    if [ "$DOCKER_COMPOSE_READY" == "yes" ]; then verify_pass "Docker Compose plugin detected"; else verify_fail "Docker Compose plugin" "docker compose version failed" "run Script 5 and re-login if needed"; fi
    if [ "$SCRIPT5_DOCKER_SERVICE_STATE" == "active" ]; then verify_pass "Docker service active"; else verify_fail "Docker service active" "state is ${SCRIPT5_DOCKER_SERVICE_STATE:-unknown}" "run sudo systemctl status docker"; fi
    if [ "$SCRIPT5_CONTAINERD_SERVICE_STATE" == "active" ]; then verify_pass "containerd service active"; else verify_fail "containerd service active" "state is ${SCRIPT5_CONTAINERD_SERVICE_STATE:-unknown}" "run sudo systemctl status containerd"; fi
    if id "$DOCKER_USER" >/dev/null 2>&1; then verify_pass "Docker user exists"; else verify_fail "Docker user exists" "user ${DOCKER_USER:-unknown} missing" "run Script 4/5 or create the Docker user"; fi
    if id -nG "$DOCKER_USER" 2>/dev/null | grep -qw docker; then verify_pass "Docker user is in docker group"; else verify_fail "Docker user docker group" "membership not confirmed" "run Script 5 and re-login"; fi
}

function verify_crowdsec_runtime_continuity() {
    refresh_crowdsec_runtime_state
    refresh_crowdsec_bouncer_display_state

    if ! script5_crowdsec_selected_or_active; then
        verify_info "CrowdSec runtime continuity skipped; CrowdSec was not detected as selected/active"
        return 0
    fi

    if [ "$SCRIPT5_CROWDSEC_STATE" == "active" ]; then
        verify_pass "CrowdSec service active"
    elif [ "$SCRIPT5_SCRIPT4_CROWDSEC_SELECTED" == "yes" ] && [ "$SCRIPT5_VERIFY_STATUS" == "PASS" ]; then
        verify_info "CrowdSec service live state unavailable; Script 5 marker selected CrowdSec and verification was PASS"
    else
        verify_warn "CrowdSec service" "state is ${SCRIPT5_CROWDSEC_STATE:-unknown}" "run sudo systemctl status crowdsec"
    fi

    if [ "$SCRIPT5_CROWDSEC_BOUNCER_STATE" == "active" ] && [ "$SCRIPT5_CROWDSEC_BOUNCER_SUBSTATE" == "running" ]; then
        verify_pass "CrowdSec firewall bouncer runtime active/running"
    elif [ "$SCRIPT5_SCRIPT4_CROWDSEC_BOUNCER" == "active" ] && [ "$SCRIPT5_VERIFY_STATUS" == "PASS" ]; then
        verify_pass "CrowdSec firewall bouncer marker active"
    else
        verify_warn "CrowdSec firewall bouncer runtime" "state is ${SCRIPT5_CROWDSEC_BOUNCER_STATE:-unknown}/${SCRIPT5_CROWDSEC_BOUNCER_SUBSTATE:-unknown}; marker is ${SCRIPT5_SCRIPT4_CROWDSEC_BOUNCER:-unknown}" "run sudo systemctl status crowdsec-firewall-bouncer"
    fi
}

# --- 54. VERIFICATION REPORT ---
# Creates a verification report without printing secret values.
function create_verification_report() {
    if [ "${VERIFY_ONLY_MODE:-no}" != "yes" ]; then
        apply_group_header "Marker / verification"
    fi

    msg_info "Creating Docker ENV verification report"

    local report_body=""
    local secret_file=""
    local current_mode=""

    report_body="$(mktemp)"
    TEMP_FILES+=("$report_body")

    VERIFY_STATUS="PASS"
    VERIFY_PASS_COUNT="0"
    VERIFY_WARN_COUNT="0"
    VERIFY_FAIL_COUNT="0"
    VERIFY_FIRST_ISSUE_TYPE=""
    VERIFY_FIRST_ISSUE_CHECK=""
    VERIFY_FIRST_ISSUE_REASON=""
    VERIFY_FIRST_ISSUE_FIX=""

    verify_pass() { VERIFY_PASS_COUNT="$(( VERIFY_PASS_COUNT + 1 ))"; echo "✓ PASS - $1" >> "$report_body"; }
    verify_warn() { local check="$1" reason="${2:-warning condition detected}" fix="${3:-review ${VERIFY_LOG}}"; VERIFY_WARN_COUNT="$(( VERIFY_WARN_COUNT + 1 ))"; verify_record_first_issue "Warning" "$check" "$reason" "$fix"; echo "! WARN - ${check}: ${reason}" >> "$report_body"; }
    verify_fail() { local check="$1" reason="${2:-check failed}" fix="${3:-review ${VERIFY_LOG}}"; VERIFY_FAIL_COUNT="$(( VERIFY_FAIL_COUNT + 1 ))"; verify_record_first_issue "Failure" "$check" "$reason" "$fix"; echo "✗ FAIL - ${check}: ${reason}" >> "$report_body"; }
    verify_info() { echo "- INFO - $1" >> "$report_body"; }

    if [ "$SCRIPT5_STATUS" == "completed" ]; then verify_pass "Script 5 status completed"; else verify_fail "Script 5 status" "status is ${SCRIPT5_STATUS}" "complete/fix Script 5 first"; fi
    if [ "$SCRIPT5_VERIFY_STATUS" == "PASS" ]; then verify_pass "Script 5 verification PASS"; else verify_fail "Script 5 verification" "status is ${SCRIPT5_VERIFY_STATUS}" "resolve Script 5 verification first"; fi
    if [ "$SCRIPT5_SWAP_RESULT" == "unknown" ]; then verify_warn "Script 5 swap handoff" "swap result is unknown" "inspect ${SCRIPT5_MARKER}"; else verify_pass "Script 5 swap handoff present"; fi

    if id "$DOCKER_USER" >/dev/null 2>&1; then verify_pass "Docker user exists"; else verify_fail "Docker user exists" "user ${DOCKER_USER:-unknown} missing" "run Script 4/5 or create the Docker user"; fi
    if root_path_exists "$DOCKER_DIR"; then verify_pass "Docker directory exists"; else verify_fail "Docker directory exists" "${DOCKER_DIR:-unknown} missing" "rerun Script 6 setup"; fi
    if root_path_exists "${DOCKER_DIR}/.env"; then verify_pass ".env exists"; else verify_fail ".env exists" "${DOCKER_DIR}/.env missing" "rerun Script 6 setup"; fi

    current_mode="$(root_stat_mode "${DOCKER_DIR}/.env")"
    if [ "$current_mode" == "600" ]; then verify_pass ".env mode is 600"; else verify_warn ".env mode is 600" "current mode is ${current_mode:-unknown}" "run normal Script 6 setup to repair permissions"; fi

    if root_path_exists "$DOCKER_SECRETS_DIR"; then verify_pass "secrets directory exists"; else verify_fail "secrets directory exists" "${DOCKER_SECRETS_DIR:-unknown} missing" "rerun Script 6 setup"; fi
    current_mode="$(root_stat_mode "$DOCKER_SECRETS_DIR")"
    if [ "$current_mode" == "700" ]; then verify_pass "secrets directory mode is 700"; else verify_warn "secrets directory mode is 700" "current mode is ${current_mode:-unknown}" "run normal Script 6 setup to repair permissions"; fi

    for secret_file in \
        authentik_secret_key \
        authentik_postgres_password \
        postiz_postgres_password \
        postiz_redis_password \
        postiz_jwt_secret \
        temporal_postgres_password \
        n8n_encryption_key
    do
        if root_file_not_empty "${DOCKER_SECRETS_DIR}/${secret_file}"; then verify_pass "${secret_file} exists and is non-empty"; else verify_fail "${secret_file}" "secret file missing or empty" "rerun Script 6 setup or restore secret file from backup"; fi
        current_mode="$(root_stat_mode "${DOCKER_SECRETS_DIR}/${secret_file}")"
        if [ "$current_mode" == "600" ]; then verify_pass "${secret_file} mode is 600"; else verify_warn "${secret_file} mode is 600" "current mode is ${current_mode:-unknown}" "run normal Script 6 setup to repair permissions"; fi
    done

    if root_path_exists "$CF_API_TOKEN_FILE"; then verify_pass "Cloudflare token file exists"; else verify_warn "Cloudflare token file exists" "token file missing" "create token file or rerun Script 6 if Cloudflare DNS automation is required"; fi
    if root_path_exists "${DOCKER_SECRETS_DIR}/htpasswd"; then
        verify_pass "htpasswd file exists"
        if root_file_not_empty "${DOCKER_SECRETS_DIR}/htpasswd"; then
            local htpasswd_raw_line=""
            local htpasswd_line=""
            local htpasswd_prefix_status=""
            htpasswd_raw_line="$(root_read_file "${DOCKER_SECRETS_DIR}/htpasswd" 2>/dev/null | head -n1 || true)"
            htpasswd_prefix_status="$(htpasswd_hash_prefix_status "$htpasswd_raw_line")"
            if [ "$htpasswd_prefix_status" != "escaped-dollar" ]; then
                htpasswd_line="$(normalize_htpasswd_line "$htpasswd_raw_line")"
                htpasswd_prefix_status="$(htpasswd_hash_prefix_status "$htpasswd_line")"
            fi
            case "$htpasswd_prefix_status" in
                escaped-dollar) verify_fail "htpasswd hash prefix" "escaped dollar prefix detected" "rewrite htpasswd secret with literal dollar signs" ;;
                known) verify_pass "htpasswd hash prefix is literal-dollar supported shape" ;;
                unknown) verify_warn "htpasswd hash prefix" "unknown hash prefix; hash not displayed" "confirm htpasswd file uses a Traefik-supported hash" ;;
                *) verify_fail "htpasswd shape" "expected username:hash" "replace htpasswd secret with a valid htpasswd line" ;;
            esac
        else
            verify_info "htpasswd file is empty; Basic Auth fallback is disabled until populated"
        fi
    else
        verify_info "htpasswd file missing; acceptable when SSO/auth gateway is used"
    fi
    if root_path_exists "$TRAEFIK_STATIC_CONFIG_FILE"; then verify_pass "Traefik static config exists"; else verify_fail "Traefik static config" "missing" "rerun Script 6 template render step"; fi
    if root_path_exists "$TRAEFIK_DYNAMIC_CONFIG_FILE"; then verify_pass "Traefik dynamic config exists"; else verify_fail "Traefik dynamic config" "missing" "rerun Script 6 template render step"; fi
    if root_path_exists "${TRAEFIK_ACME_DIR}/acme.json"; then verify_pass "Traefik acme.json exists"; else verify_fail "Traefik acme.json" "missing" "rerun Script 6 setup"; fi
    current_mode="$(root_stat_mode "${TRAEFIK_ACME_DIR}/acme.json")"
    if [ "$current_mode" == "600" ]; then verify_pass "Traefik acme.json mode is 600"; else verify_warn "Traefik acme.json mode is 600" "current mode is ${current_mode:-unknown}" "run normal Script 6 setup to repair permissions"; fi

    verify_docker_runtime_continuity
    verify_crowdsec_runtime_continuity

    if root_path_exists "$COMPLETED_MARKER"; then verify_pass "Completion marker exists"; else verify_warn "Completion marker exists" "marker not present yet" "rerun marker write step"; fi

    if [ "$VERIFY_FAIL_COUNT" -gt 0 ]; then VERIFY_STATUS="FAIL"; elif [ "$VERIFY_WARN_COUNT" -gt 0 ]; then VERIFY_STATUS="PASS_WITH_WARNINGS"; else VERIFY_STATUS="PASS"; fi

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" bash -c "cat > '$VERIFY_LOG'" <<EOF
--- DOCKER ENV SETUP VERIFICATION REPORT ---
Date: $(date)
Docker user: $DOCKER_USER
Docker dir: $DOCKER_DIR
Secrets dir: $DOCKER_SECRETS_DIR
Domain: $DOMAIN_VALUE
Script 5 status: $SCRIPT5_STATUS
Script 5 verification: $SCRIPT5_VERIFY_STATUS
Script 5 swap: $SCRIPT5_SWAP_RESULT $SCRIPT5_SWAP_FILE $SCRIPT5_SWAP_SIZE
VERIFY_STATUS=$VERIFY_STATUS
VERIFY_PASS_COUNT=$VERIFY_PASS_COUNT
VERIFY_WARN_COUNT=$VERIFY_WARN_COUNT
VERIFY_FAIL_COUNT=$VERIFY_FAIL_COUNT

Results:
$(cat "$report_body")
EOF
    else
        cat > "$VERIFY_LOG" <<EOF
--- DOCKER ENV SETUP VERIFICATION REPORT ---
Date: $(date)
Docker user: $DOCKER_USER
Docker dir: $DOCKER_DIR
Secrets dir: $DOCKER_SECRETS_DIR
Domain: $DOMAIN_VALUE
Script 5 status: $SCRIPT5_STATUS
Script 5 verification: $SCRIPT5_VERIFY_STATUS
Script 5 swap: $SCRIPT5_SWAP_RESULT $SCRIPT5_SWAP_FILE $SCRIPT5_SWAP_SIZE
VERIFY_STATUS=$VERIFY_STATUS
VERIFY_PASS_COUNT=$VERIFY_PASS_COUNT
VERIFY_WARN_COUNT=$VERIFY_WARN_COUNT
VERIFY_FAIL_COUNT=$VERIFY_FAIL_COUNT

Results:
$(cat "$report_body")
EOF
    fi

    rm -f "$report_body"
    msg_ok "DOCKER ENV VERIFICATION REPORT CREATED"
}

function marker_readiness_values() {
    SCRIPT6_TRAEFIK_CONFIG_READY="no"
    SCRIPT6_TRAEFIK_ACME_READY="no"
    SCRIPT6_CF_TOKEN_FILE_READY="no"
    SCRIPT6_ENV_FILE_READY="no"
    SCRIPT6_SECRETS_READY="no"
    SCRIPT6_READY_FOR_SCRIPT61="no"
    SCRIPT6_READY_FOR_SCRIPT62="no"
    SCRIPT6_READY_FOR_SCRIPT63="no"
    SCRIPT6_READY_FOR_SCRIPT64="no"
    SCRIPT6_READY_FOR_SCRIPT65="no"
    SCRIPT6_READY_FOR_SCRIPT66="no"

    root_path_exists "$TRAEFIK_STATIC_CONFIG_FILE" && root_path_exists "$TRAEFIK_DYNAMIC_CONFIG_FILE" && SCRIPT6_TRAEFIK_CONFIG_READY="yes"
    root_path_exists "${TRAEFIK_ACME_DIR}/acme.json" && [ "$(root_stat_mode "${TRAEFIK_ACME_DIR}/acme.json")" == "600" ] && SCRIPT6_TRAEFIK_ACME_READY="yes"
    root_path_exists "${DOCKER_DIR}/.env" && SCRIPT6_ENV_FILE_READY="yes"
    if root_file_not_empty "${DOCKER_SECRETS_DIR}/authentik_secret_key" \
        && root_file_not_empty "${DOCKER_SECRETS_DIR}/authentik_postgres_password" \
        && root_file_not_empty "${DOCKER_SECRETS_DIR}/postiz_postgres_password" \
        && root_file_not_empty "${DOCKER_SECRETS_DIR}/postiz_redis_password" \
        && root_file_not_empty "${DOCKER_SECRETS_DIR}/postiz_jwt_secret" \
        && root_file_not_empty "${DOCKER_SECRETS_DIR}/temporal_postgres_password" \
        && root_file_not_empty "${DOCKER_SECRETS_DIR}/n8n_encryption_key"; then
        SCRIPT6_SECRETS_READY="yes"
    fi

    if root_file_not_empty "$CF_API_TOKEN_FILE"; then
        SCRIPT6_CF_TOKEN_FILE_READY="yes"
    elif [ "${CF_AUTH_MODE:-}" == "email_or_manual" ]; then
        SCRIPT6_CF_TOKEN_FILE_READY="skipped"
    else
        SCRIPT6_CF_TOKEN_FILE_READY="no"
    fi

    if [ "$SCRIPT6_TRAEFIK_CONFIG_READY" == "yes" ] && [ "$SCRIPT6_TRAEFIK_ACME_READY" == "yes" ] && [ "$SCRIPT6_ENV_FILE_READY" == "yes" ] && [ "$SCRIPT6_SECRETS_READY" == "yes" ]; then
        SCRIPT6_READY_FOR_SCRIPT61="yes"
        SCRIPT6_READY_FOR_SCRIPT62="yes"
        SCRIPT6_READY_FOR_SCRIPT63="yes"
        SCRIPT6_READY_FOR_SCRIPT64="yes"
        SCRIPT6_READY_FOR_SCRIPT65="yes"
        SCRIPT6_READY_FOR_SCRIPT66="yes"
    fi
}

function write_completion_marker() {
    apply_group_header "Marker / verification"

    msg_info "Writing completion marker"
    refresh_crowdsec_bouncer_display_state
    marker_readiness_values

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" bash -c "cat > '$COMPLETED_MARKER'" <<EOF
Docker ENV Setup completed on: $(date)
Docker dir: $DOCKER_DIR
Compose dir: ${DOCKER_DIR}/compose
Secrets dir: $DOCKER_SECRETS_DIR
Domain: $DOMAIN_VALUE
User: $DOCKER_USER
PUID: $PUID_VALUE
PGID: $PGID_VALUE
Timezone: $TZ_VALUE
Existing setup detected: $EXISTING_SETUP
Secrets regenerated: $REGENERATE_SECRETS
Cloudflare token file: $CF_API_TOKEN_FILE
Traefik static config: $TRAEFIK_STATIC_CONFIG_FILE
Traefik dynamic config: $TRAEFIK_DYNAMIC_CONFIG_FILE
Traefik ACME storage: ${TRAEFIK_ACME_DIR}/acme.json
Traefik ACME email: $TRAEFIK_ACME_EMAIL_VALUE
Authentik bootstrap email: $AUTHENTIK_BOOTSTRAP_EMAIL_VALUE
Traefik dashboard host: $TRAEFIK_DASHBOARD_HOST
Proxmox route enabled: $PROXMOX_ROUTE_ENABLED
Proxmox route host: ${PROXMOX_HOST:-}
Proxmox LAN URL: ${PROXMOX_URL:-}
Proxmox marker source: $PROXMOX_MARKER_SOURCE
Htpasswd mode: $HTPASSWD_MODE
Docker ready: $DOCKER_READY
Docker Compose ready: $DOCKER_COMPOSE_READY
Docker user in docker group: $DOCKER_USER_IN_DOCKER_GROUP
Script 5 status: $SCRIPT5_STATUS
Script 5 verification: $SCRIPT5_VERIFY_STATUS
Script 5 target user: $SCRIPT5_TARGET_USER
Script 5 swap result: $SCRIPT5_SWAP_RESULT
Script 5 swap file: $SCRIPT5_SWAP_FILE
Script 5 swap size: $SCRIPT5_SWAP_SIZE
Script 5 UFW: $SCRIPT5_UFW_ENABLED
Script 5 Redis host tuning: $SCRIPT5_REDIS_OVERCOMMIT
Docker service: $SCRIPT5_DOCKER_SERVICE_STATE
Containerd service: $SCRIPT5_CONTAINERD_SERVICE_STATE
CrowdSec service: $SCRIPT5_CROWDSEC_STATE
CrowdSec bouncer: $SCRIPT6_CROWDSEC_BOUNCER_DISPLAY
Secret screen displayed: $SECRET_DISPLAY_WAS_SHOWN
Secret screen cleared: $SECRET_SCREEN_CLEARED
Verify log: $VERIFY_LOG
SCRIPT6_STATUS=completed
SCRIPT6_VERSION=$SCRIPT_VERSION
SCRIPT6_BUILD=$SCRIPT_BUILD
SCRIPT6_VERIFY_STATUS=$VERIFY_STATUS
SCRIPT6_VERIFY_LOG=$VERIFY_LOG
SCRIPT6_VERIFY_DISPLAY_LOG=$VERIFY_DISPLAY_LOG
SCRIPT6_DOCKER_USER=$DOCKER_USER
SCRIPT6_DOCKER_DIR=$DOCKER_DIR
SCRIPT6_COMPOSE_DIR=${DOCKER_DIR}/compose
SCRIPT6_SECRETS_DIR=$DOCKER_SECRETS_DIR
SCRIPT6_DOMAIN=$DOMAIN_VALUE
SCRIPT6_TIMEZONE=$TZ_VALUE
SCRIPT6_PUID=$PUID_VALUE
SCRIPT6_PGID=$PGID_VALUE
SCRIPT6_SCRIPT5_STATUS=$SCRIPT5_STATUS
SCRIPT6_SCRIPT5_VERIFY_STATUS=$SCRIPT5_VERIFY_STATUS
SCRIPT6_SCRIPT5_SWAP_RESULT=$SCRIPT5_SWAP_RESULT
SCRIPT6_SCRIPT5_SWAP_FILE=$SCRIPT5_SWAP_FILE
SCRIPT6_SCRIPT5_SWAP_SIZE=$SCRIPT5_SWAP_SIZE
SCRIPT6_SCRIPT5_UFW_ENABLED=$SCRIPT5_UFW_ENABLED
SCRIPT6_SCRIPT5_REDIS_OVERCOMMIT=$SCRIPT5_REDIS_OVERCOMMIT
SCRIPT6_CROWDSEC_SELECTED=$SCRIPT5_SCRIPT4_CROWDSEC_SELECTED
SCRIPT6_CROWDSEC_BOUNCER=$SCRIPT6_CROWDSEC_BOUNCER_DISPLAY
SCRIPT6_CROWDSEC_BOUNCER_RUNTIME=$SCRIPT6_CROWDSEC_BOUNCER_RUNTIME
SCRIPT6_TRAEFIK_CONFIG_READY=$SCRIPT6_TRAEFIK_CONFIG_READY
SCRIPT6_TRAEFIK_ACME_READY=$SCRIPT6_TRAEFIK_ACME_READY
SCRIPT6_CF_TOKEN_FILE_READY=$SCRIPT6_CF_TOKEN_FILE_READY
SCRIPT6_ENV_FILE_READY=$SCRIPT6_ENV_FILE_READY
SCRIPT6_SECRETS_READY=$SCRIPT6_SECRETS_READY
SCRIPT6_READY_FOR_SCRIPT61=$SCRIPT6_READY_FOR_SCRIPT61
SCRIPT6_READY_FOR_SCRIPT62=$SCRIPT6_READY_FOR_SCRIPT62
SCRIPT6_READY_FOR_SCRIPT63=$SCRIPT6_READY_FOR_SCRIPT63
SCRIPT6_READY_FOR_SCRIPT64=$SCRIPT6_READY_FOR_SCRIPT64
SCRIPT6_READY_FOR_SCRIPT65=$SCRIPT6_READY_FOR_SCRIPT65
SCRIPT6_READY_FOR_SCRIPT66=$SCRIPT6_READY_FOR_SCRIPT66
SCRIPT6_ADMIN_UI_DEFAULT=$ADMIN_UI
SCRIPT6_PROXMOX_HOST=${PROXMOX_HOST:-}
SCRIPT6_PROXMOX_LAN_URL=${PROXMOX_URL:-}
SCRIPT6_PROXMOX_MARKER_SOURCE=$PROXMOX_MARKER_SOURCE
SCRIPT6_PERMISSION_AUDIT=$PERMISSION_AUDIT_STATUS
EOF
    else
        cat > "$COMPLETED_MARKER" <<EOF
Docker ENV Setup completed on: $(date)
Docker dir: $DOCKER_DIR
Compose dir: ${DOCKER_DIR}/compose
Secrets dir: $DOCKER_SECRETS_DIR
Domain: $DOMAIN_VALUE
User: $DOCKER_USER
PUID: $PUID_VALUE
PGID: $PGID_VALUE
Timezone: $TZ_VALUE
Existing setup detected: $EXISTING_SETUP
Secrets regenerated: $REGENERATE_SECRETS
Cloudflare token file: $CF_API_TOKEN_FILE
Traefik static config: $TRAEFIK_STATIC_CONFIG_FILE
Traefik dynamic config: $TRAEFIK_DYNAMIC_CONFIG_FILE
Traefik ACME storage: ${TRAEFIK_ACME_DIR}/acme.json
Traefik ACME email: $TRAEFIK_ACME_EMAIL_VALUE
Authentik bootstrap email: $AUTHENTIK_BOOTSTRAP_EMAIL_VALUE
Traefik dashboard host: $TRAEFIK_DASHBOARD_HOST
Proxmox route enabled: $PROXMOX_ROUTE_ENABLED
Proxmox route host: ${PROXMOX_HOST:-}
Proxmox LAN URL: ${PROXMOX_URL:-}
Proxmox marker source: $PROXMOX_MARKER_SOURCE
Htpasswd mode: $HTPASSWD_MODE
Docker ready: $DOCKER_READY
Docker Compose ready: $DOCKER_COMPOSE_READY
Docker user in docker group: $DOCKER_USER_IN_DOCKER_GROUP
Script 5 status: $SCRIPT5_STATUS
Script 5 verification: $SCRIPT5_VERIFY_STATUS
Script 5 target user: $SCRIPT5_TARGET_USER
Script 5 swap result: $SCRIPT5_SWAP_RESULT
Script 5 swap file: $SCRIPT5_SWAP_FILE
Script 5 swap size: $SCRIPT5_SWAP_SIZE
Script 5 UFW: $SCRIPT5_UFW_ENABLED
Script 5 Redis host tuning: $SCRIPT5_REDIS_OVERCOMMIT
Docker service: $SCRIPT5_DOCKER_SERVICE_STATE
Containerd service: $SCRIPT5_CONTAINERD_SERVICE_STATE
CrowdSec service: $SCRIPT5_CROWDSEC_STATE
CrowdSec bouncer: $SCRIPT6_CROWDSEC_BOUNCER_DISPLAY
Secret screen displayed: $SECRET_DISPLAY_WAS_SHOWN
Secret screen cleared: $SECRET_SCREEN_CLEARED
Verify log: $VERIFY_LOG
SCRIPT6_STATUS=completed
SCRIPT6_VERSION=$SCRIPT_VERSION
SCRIPT6_BUILD=$SCRIPT_BUILD
SCRIPT6_VERIFY_STATUS=$VERIFY_STATUS
SCRIPT6_VERIFY_LOG=$VERIFY_LOG
SCRIPT6_VERIFY_DISPLAY_LOG=$VERIFY_DISPLAY_LOG
SCRIPT6_DOCKER_USER=$DOCKER_USER
SCRIPT6_DOCKER_DIR=$DOCKER_DIR
SCRIPT6_COMPOSE_DIR=${DOCKER_DIR}/compose
SCRIPT6_SECRETS_DIR=$DOCKER_SECRETS_DIR
SCRIPT6_DOMAIN=$DOMAIN_VALUE
SCRIPT6_TIMEZONE=$TZ_VALUE
SCRIPT6_PUID=$PUID_VALUE
SCRIPT6_PGID=$PGID_VALUE
SCRIPT6_SCRIPT5_STATUS=$SCRIPT5_STATUS
SCRIPT6_SCRIPT5_VERIFY_STATUS=$SCRIPT5_VERIFY_STATUS
SCRIPT6_SCRIPT5_SWAP_RESULT=$SCRIPT5_SWAP_RESULT
SCRIPT6_SCRIPT5_SWAP_FILE=$SCRIPT5_SWAP_FILE
SCRIPT6_SCRIPT5_SWAP_SIZE=$SCRIPT5_SWAP_SIZE
SCRIPT6_SCRIPT5_UFW_ENABLED=$SCRIPT5_UFW_ENABLED
SCRIPT6_SCRIPT5_REDIS_OVERCOMMIT=$SCRIPT5_REDIS_OVERCOMMIT
SCRIPT6_CROWDSEC_SELECTED=$SCRIPT5_SCRIPT4_CROWDSEC_SELECTED
SCRIPT6_CROWDSEC_BOUNCER=$SCRIPT6_CROWDSEC_BOUNCER_DISPLAY
SCRIPT6_CROWDSEC_BOUNCER_RUNTIME=$SCRIPT6_CROWDSEC_BOUNCER_RUNTIME
SCRIPT6_TRAEFIK_CONFIG_READY=$SCRIPT6_TRAEFIK_CONFIG_READY
SCRIPT6_TRAEFIK_ACME_READY=$SCRIPT6_TRAEFIK_ACME_READY
SCRIPT6_CF_TOKEN_FILE_READY=$SCRIPT6_CF_TOKEN_FILE_READY
SCRIPT6_ENV_FILE_READY=$SCRIPT6_ENV_FILE_READY
SCRIPT6_SECRETS_READY=$SCRIPT6_SECRETS_READY
SCRIPT6_READY_FOR_SCRIPT61=$SCRIPT6_READY_FOR_SCRIPT61
SCRIPT6_READY_FOR_SCRIPT62=$SCRIPT6_READY_FOR_SCRIPT62
SCRIPT6_READY_FOR_SCRIPT63=$SCRIPT6_READY_FOR_SCRIPT63
SCRIPT6_READY_FOR_SCRIPT64=$SCRIPT6_READY_FOR_SCRIPT64
SCRIPT6_READY_FOR_SCRIPT65=$SCRIPT6_READY_FOR_SCRIPT65
SCRIPT6_READY_FOR_SCRIPT66=$SCRIPT6_READY_FOR_SCRIPT66
SCRIPT6_ADMIN_UI_DEFAULT=$ADMIN_UI
SCRIPT6_PROXMOX_HOST=${PROXMOX_HOST:-}
SCRIPT6_PROXMOX_LAN_URL=${PROXMOX_URL:-}
SCRIPT6_PROXMOX_MARKER_SOURCE=$PROXMOX_MARKER_SOURCE
SCRIPT6_PERMISSION_AUDIT=$PERMISSION_AUDIT_STATUS
EOF
    fi

    msg_ok "COMPLETION MARKER WRITTEN"
}

function update_completion_marker_script6_fields() {
    local marker_tmp=""
    local existing_marker=""

    refresh_crowdsec_bouncer_display_state
    marker_readiness_values
    marker_tmp="$(mktemp)"
    TEMP_FILES+=("$marker_tmp")

    if root_path_exists "$COMPLETED_MARKER"; then
        existing_marker="$(root_read_file "$COMPLETED_MARKER" 2>/dev/null | grep -Ev '^SCRIPT6_' || true)"
    fi

    {
        [ -n "$existing_marker" ] && printf '%s\n' "$existing_marker"
        echo "SCRIPT6_STATUS=completed"
        echo "SCRIPT6_VERSION=$SCRIPT_VERSION"
        echo "SCRIPT6_BUILD=$SCRIPT_BUILD"
        echo "SCRIPT6_VERIFY_STATUS=$VERIFY_STATUS"
        echo "SCRIPT6_VERIFY_LOG=$VERIFY_LOG"
        echo "SCRIPT6_VERIFY_DISPLAY_LOG=$VERIFY_DISPLAY_LOG"
        echo "SCRIPT6_DOCKER_USER=$DOCKER_USER"
        echo "SCRIPT6_DOCKER_DIR=$DOCKER_DIR"
        echo "SCRIPT6_COMPOSE_DIR=${DOCKER_DIR}/compose"
        echo "SCRIPT6_SECRETS_DIR=$DOCKER_SECRETS_DIR"
        echo "SCRIPT6_DOMAIN=$DOMAIN_VALUE"
        echo "SCRIPT6_TIMEZONE=$TZ_VALUE"
        echo "SCRIPT6_PUID=$PUID_VALUE"
        echo "SCRIPT6_PGID=$PGID_VALUE"
        echo "SCRIPT6_SCRIPT5_STATUS=$SCRIPT5_STATUS"
        echo "SCRIPT6_SCRIPT5_VERIFY_STATUS=$SCRIPT5_VERIFY_STATUS"
        echo "SCRIPT6_SCRIPT5_SWAP_RESULT=$SCRIPT5_SWAP_RESULT"
        echo "SCRIPT6_SCRIPT5_SWAP_FILE=$SCRIPT5_SWAP_FILE"
        echo "SCRIPT6_SCRIPT5_SWAP_SIZE=$SCRIPT5_SWAP_SIZE"
        echo "SCRIPT6_SCRIPT5_UFW_ENABLED=$SCRIPT5_UFW_ENABLED"
        echo "SCRIPT6_SCRIPT5_REDIS_OVERCOMMIT=$SCRIPT5_REDIS_OVERCOMMIT"
        echo "SCRIPT6_CROWDSEC_SELECTED=$SCRIPT5_SCRIPT4_CROWDSEC_SELECTED"
        echo "SCRIPT6_CROWDSEC_BOUNCER=$SCRIPT6_CROWDSEC_BOUNCER_DISPLAY"
        echo "SCRIPT6_CROWDSEC_BOUNCER_RUNTIME=$SCRIPT6_CROWDSEC_BOUNCER_RUNTIME"
        echo "SCRIPT6_TRAEFIK_CONFIG_READY=$SCRIPT6_TRAEFIK_CONFIG_READY"
        echo "SCRIPT6_TRAEFIK_ACME_READY=$SCRIPT6_TRAEFIK_ACME_READY"
        echo "SCRIPT6_CF_TOKEN_FILE_READY=$SCRIPT6_CF_TOKEN_FILE_READY"
        echo "SCRIPT6_ENV_FILE_READY=$SCRIPT6_ENV_FILE_READY"
        echo "SCRIPT6_SECRETS_READY=$SCRIPT6_SECRETS_READY"
        echo "SCRIPT6_READY_FOR_SCRIPT61=$SCRIPT6_READY_FOR_SCRIPT61"
        echo "SCRIPT6_READY_FOR_SCRIPT62=$SCRIPT6_READY_FOR_SCRIPT62"
        echo "SCRIPT6_READY_FOR_SCRIPT63=$SCRIPT6_READY_FOR_SCRIPT63"
        echo "SCRIPT6_READY_FOR_SCRIPT64=$SCRIPT6_READY_FOR_SCRIPT64"
        echo "SCRIPT6_READY_FOR_SCRIPT65=$SCRIPT6_READY_FOR_SCRIPT65"
        echo "SCRIPT6_READY_FOR_SCRIPT66=$SCRIPT6_READY_FOR_SCRIPT66"
        echo "SCRIPT6_ADMIN_UI_DEFAULT=$ADMIN_UI"
        echo "SCRIPT6_TRAEFIK_ACME_EMAIL=$TRAEFIK_ACME_EMAIL_VALUE"
        echo "SCRIPT6_AUTHENTIK_EMAIL=$AUTHENTIK_BOOTSTRAP_EMAIL_VALUE"
        echo "SCRIPT6_PROXMOX_HOST=${PROXMOX_HOST:-}"
        echo "SCRIPT6_PROXMOX_LAN_URL=${PROXMOX_URL:-}"
        echo "SCRIPT6_PROXMOX_MARKER_SOURCE=$PROXMOX_MARKER_SOURCE"
        echo "SCRIPT6_PERMISSION_AUDIT=$PERMISSION_AUDIT_STATUS"
    } > "$marker_tmp"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" cp "$marker_tmp" "$COMPLETED_MARKER" 2>/dev/null || true
        "$SUDO_CMD" chmod 0644 "$COMPLETED_MARKER" 2>/dev/null || true
    else
        cp "$marker_tmp" "$COMPLETED_MARKER" 2>/dev/null || true
        chmod 0644 "$COMPLETED_MARKER" 2>/dev/null || true
    fi

    rm -f "$marker_tmp"
}

function colorize_verify_line() {
    local line="$1"
    case "$line" in
        "✓ PASS -"*) printf '%b\n' "  ${GN}${line}${CL}" ;;
        "! WARN -"*) printf '%b\n' "  ${YW}${line}${CL}" ;;
        "✗ FAIL -"*) printf '%b\n' "  ${RD}${line}${CL}" ;;
        "- INFO -"*) printf '%b\n' "  ${BL}${line}${CL}" ;;
        *) printf '%b\n' "  ${DGN}${line}${CL}" ;;
    esac
}

function write_verify_display_log() {
    local display_tmp=""
    local result_lines=""
    local line=""

    marker_readiness_values
    display_tmp="$(mktemp)"
    TEMP_FILES+=("$display_tmp")

    if root_path_exists "$VERIFY_LOG"; then
        result_lines="$(root_read_file "$VERIFY_LOG" 2>/dev/null | awk '/^Results:/{flag=1; next} flag {print}' || true)"
    fi

    {
        echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
        echo -e "${BL}SCRIPT 6 VERIFICATION SUMMARY${CL}"
        echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
        echo ""
        echo -e "${YW}Prepared environment:${CL}"
        echo -e "  ${BL}Docker dir:${CL} ${GN}${DOCKER_DIR:-unknown}${CL}"
        echo -e "  ${BL}Compose dir:${CL} ${GN}${DOCKER_DIR:-unknown}/compose${CL}"
        echo -e "  ${BL}.env file:${CL} ${GN}${DOCKER_DIR:-unknown}/.env${CL}"
        echo -e "  ${BL}Secrets dir:${CL} ${GN}${DOCKER_SECRETS_DIR:-unknown}${CL}"
        echo -e "  ${BL}Domain:${CL} ${GN}${DOMAIN_VALUE:-unknown}${CL}"
        echo ""
        echo -e "${YW}6-family readiness:${CL}"
        echo -e "  ${BL}Ready for Script 6.1:${CL} ${GN}${SCRIPT6_READY_FOR_SCRIPT61}${CL}"
        echo -e "  ${BL}Ready for Script 6.2:${CL} ${GN}${SCRIPT6_READY_FOR_SCRIPT62}${CL}"
        echo -e "  ${BL}Ready for Script 6.3:${CL} ${GN}${SCRIPT6_READY_FOR_SCRIPT63}${CL}"
        echo -e "  ${BL}Ready for Script 6.4:${CL} ${GN}${SCRIPT6_READY_FOR_SCRIPT64}${CL}"
        echo -e "  ${BL}Ready for Script 6.5:${CL} ${GN}${SCRIPT6_READY_FOR_SCRIPT65}${CL}"
        echo -e "  ${BL}Ready for Script 6.6:${CL} ${GN}${SCRIPT6_READY_FOR_SCRIPT66}${CL}"
        echo ""
        echo -e "${YW}Checks:${CL}"
        if [ -n "$result_lines" ]; then
            while IFS= read -r line; do [ -n "$line" ] && colorize_verify_line "$line"; done <<< "$result_lines"
        else
            echo -e "  ${BL}- INFO - No verification lines recorded${CL}"
        fi
        echo ""
        echo -e "${YW}Verification:${CL}"
        case "$VERIFY_STATUS" in
            PASS) echo -e "  ${BL}Status:${CL} ${GN}${VERIFY_STATUS}${CL}" ;;
            PASS_WITH_WARNINGS) echo -e "  ${BL}Status:${CL} ${YW}${VERIFY_STATUS}${CL}" ;;
            FAIL) echo -e "  ${BL}Status:${CL} ${RD}${VERIFY_STATUS}${CL}" ;;
            *) echo -e "  ${BL}Status:${CL} ${YW}${VERIFY_STATUS:-unknown}${CL}" ;;
        esac
        echo -e "  ${BL}Pass:${CL} ${GN}${VERIFY_PASS_COUNT}${CL}"
        echo -e "  ${BL}Warn:${CL} ${YW}${VERIFY_WARN_COUNT}${CL}"
        echo -e "  ${BL}Fail:${CL} ${RD}${VERIFY_FAIL_COUNT}${CL}"
        echo -e "  ${BL}Verify log:${CL} ${GN}${VERIFY_LOG}${CL}"
        echo -e "  ${BL}Display log:${CL} ${GN}${VERIFY_DISPLAY_LOG}${CL}"
        echo ""
        echo -e "${YW}Next Step:${CL}"
        echo -e "  ${YW}Build/run ${ANS}Script 6.1 platform core bootstrap${YW}.${CL}"
    } > "$display_tmp"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" cp "$display_tmp" "$VERIFY_DISPLAY_LOG" 2>/dev/null || true
        "$SUDO_CMD" chmod 0644 "$VERIFY_DISPLAY_LOG" 2>/dev/null || true
    else
        cp "$display_tmp" "$VERIFY_DISPLAY_LOG" 2>/dev/null || true
        chmod 0644 "$VERIFY_DISPLAY_LOG" 2>/dev/null || true
    fi

    rm -f "$display_tmp"
}

function load_state_from_completion_marker() {
    local marker_file="$COMPLETED_MARKER"
    local value=""
    local acme_storage=""

    value="$(marker_display_value "Docker dir" "$marker_file")"; [ "$value" != "unknown" ] && DOCKER_DIR="$value"
    value="$(marker_display_value "Secrets dir" "$marker_file")"; [ "$value" != "unknown" ] && DOCKER_SECRETS_DIR="$value"
    value="$(marker_display_value "Domain" "$marker_file")"; [ "$value" != "unknown" ] && DOMAIN_VALUE="$value"
    value="$(marker_display_value "User" "$marker_file")"; [ "$value" != "unknown" ] && DOCKER_USER="$value"
    value="$(marker_display_value "PUID" "$marker_file")"; [ "$value" != "unknown" ] && PUID_VALUE="$value"
    value="$(marker_display_value "PGID" "$marker_file")"; [ "$value" != "unknown" ] && PGID_VALUE="$value"
    value="$(marker_display_value "Existing setup detected" "$marker_file")"; [ "$value" != "unknown" ] && EXISTING_SETUP="$value"
    value="$(marker_display_value "Secrets regenerated" "$marker_file")"; [ "$value" != "unknown" ] && REGENERATE_SECRETS="$value"
    value="$(marker_display_value "Cloudflare token file" "$marker_file")"; [ "$value" != "unknown" ] && CF_API_TOKEN_FILE="$value"
    value="$(marker_display_value "Traefik static config" "$marker_file")"; [ "$value" != "unknown" ] && TRAEFIK_STATIC_CONFIG_FILE="$value"
    value="$(marker_display_value "Traefik dynamic config" "$marker_file")"; [ "$value" != "unknown" ] && TRAEFIK_DYNAMIC_CONFIG_FILE="$value"
    acme_storage="$(marker_display_value "Traefik ACME storage" "$marker_file")"
    if [ "$acme_storage" != "unknown" ]; then
        TRAEFIK_ACME_DIR="${acme_storage%/*}"
    fi
    value="$(marker_display_value "Traefik dashboard host" "$marker_file")"; [ "$value" != "unknown" ] && TRAEFIK_DASHBOARD_HOST="$value"
    value="$(marker_display_value "Proxmox route enabled" "$marker_file")"; [ "$value" != "unknown" ] && PROXMOX_ROUTE_ENABLED="$value"
    value="$(marker_display_value "Docker ready" "$marker_file")"; [ "$value" != "unknown" ] && DOCKER_READY="$value"
    value="$(marker_display_value "Docker Compose ready" "$marker_file")"; [ "$value" != "unknown" ] && DOCKER_COMPOSE_READY="$value"
    value="$(marker_display_value "Docker user in docker group" "$marker_file")"; [ "$value" != "unknown" ] && DOCKER_USER_IN_DOCKER_GROUP="$value"
    value="$(marker_key_value "SCRIPT6_ADMIN_UI" "$marker_file")"; [ -n "$value" ] && ADMIN_UI="$value"

    [ -n "${DOCKER_SECRETS_DIR:-}" ] || DOCKER_SECRETS_DIR="${DOCKER_DIR}/secrets"
    [ -n "${CF_API_TOKEN_FILE:-}" ] || CF_API_TOKEN_FILE="${DOCKER_SECRETS_DIR}/cf_api_token"
    [ -n "${TRAEFIK_ACME_DIR:-}" ] || TRAEFIK_ACME_DIR="${DOCKER_DIR}/appdata/traefik/acme"
    [ -n "${TRAEFIK_STATIC_CONFIG_FILE:-}" ] || TRAEFIK_STATIC_CONFIG_FILE="${DOCKER_DIR}/appdata/traefik/traefik.yml"
    [ -n "${TRAEFIK_DYNAMIC_CONFIG_FILE:-}" ] || TRAEFIK_DYNAMIC_CONFIG_FILE="${DOCKER_DIR}/appdata/traefik/dynamic-config.yml"

    return 0
}

function show_verify_only_summary() {
    section_flash_success "     ━━━━━━━━━━━━━━━━━    FINISHED    ━━━━━━━━━━━━━━━━━"

    echo -e "${YW}Verification:${CL}"
    case "$VERIFY_STATUS" in
        PASS) echo -e "  ${BL}Status:${CL} ${GN}${VERIFY_STATUS}${CL}" ;;
        PASS_WITH_WARNINGS) echo -e "  ${BL}Status:${CL} ${YW}${VERIFY_STATUS}${CL}" ;;
        FAIL) echo -e "  ${BL}Status:${CL} ${RD}${VERIFY_STATUS}${CL}" ;;
        *) echo -e "  ${BL}Status:${CL} ${YW}${VERIFY_STATUS:-unknown}${CL}" ;;
    esac
    echo -e "  ${BL}Pass:${CL} ${GN}${VERIFY_PASS_COUNT}${CL}"
    echo -e "  ${BL}Warn:${CL} ${YW}${VERIFY_WARN_COUNT}${CL}"
    echo -e "  ${BL}Fail:${CL} ${RD}${VERIFY_FAIL_COUNT}${CL}"
    echo -e "  ${BL}Verify log:${CL} ${GN}${VERIFY_LOG}${CL}"
    echo -e "  ${BL}Display log:${CL} ${GN}${VERIFY_DISPLAY_LOG}${CL}"

    if [ -n "$VERIFY_FIRST_ISSUE_TYPE" ]; then
        echo ""
        echo -e "${YW}${VERIFY_FIRST_ISSUE_TYPE} 1:${CL}"
        echo -e "  ${BL}Check:${CL} ${GN}${VERIFY_FIRST_ISSUE_CHECK}${CL}"
        echo -e "  ${BL}Reason:${CL} ${YW}${VERIFY_FIRST_ISSUE_REASON}${CL}"
        echo -e "  ${BL}Fix:${CL} ${GN}${VERIFY_FIRST_ISSUE_FIX}${CL}"
    fi

    echo ""
    echo -e "${YW}Next Step:${CL}"
    echo -e "  ${YW}Build/run ${ANS}Script 6.1 platform core bootstrap${YW}.${CL}"
}

function run_verify_only_mode() {
    VERIFY_ONLY_MODE="yes"
    load_state_from_completion_marker
    create_verification_report
    write_verify_display_log
    update_completion_marker_script6_fields
    show_verify_only_summary
    exit 0
}

# --- 55B. POST-APPLY AUDIT PAUSE ---
# Lets the user review all apply-stage output before the screen is cleared for one-time secret display.
function wait_before_secret_display() {
    section "APPLY STAGE COMPLETE"

    echo -e "${GN}Docker ENV files, service folders, secrets, templates and permissions have been created/updated.${CL}"
    echo -e "${YW}Review the output above now. The next screen shows sensitive secrets and clears terminal scrollback after confirmation.${CL}"
    echo ""

    if [ -r /dev/tty ]; then
        read -r -p "Press ENTER when you are ready to view the one-time secret display..." _ < /dev/tty || true
    else
        read -r -p "Press ENTER when you are ready to view the one-time secret display..." _ || true
    fi

    return 0
}

# --- 56. FINAL SECRET DISPLAY ---
# Shows generated/reused secret values once while logging is disabled.
# After user confirms they saved them, terminal and scrollback are cleared where supported.
function show_secrets_once_without_logging() {
    disable_logging
    clear_terminal_scrollback
    SECRET_DISPLAY_WAS_SHOWN="yes"

    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo -e "${BL}SCRIPT 6 SECRET / ENV HANDOFF${CL}"
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
    echo -e "${RD}Sensitive values are shown once only and are not written to ${LOG_FILE}.${CL}"
    echo ""

    echo -e "${YW}CLOUDFLARE:${CL}"
    echo -e "CF_API_TOKEN_FILE=${GN}${CF_API_TOKEN_FILE}${CL}"
    if [ -n "$CF_API_TOKEN_VALUE" ]; then
        echo -e "CF_API_TOKEN=${YW}<captured / not displayed>${CL}"
    else
        echo -e "CF_API_TOKEN=${YW}<empty / not provided>${CL}"
    fi

    echo ""
    echo -e "${YW}AUTHENTIK BOOTSTRAP / API:${CL}"
    refresh_authentik_route_url_values
    echo -e "AUTHENTIK_ROUTE_HOST=${GN}${AUTHENTIK_ROUTE_HOST_VALUE}${CL}"
    echo -e "AUTHENTIK_EXTERNAL_URL=${GN}${AUTHENTIK_EXTERNAL_URL_VALUE}${CL}"
    echo -e "AUTHENTIK_BOOTSTRAP_EMAIL=${GN}${AUTHENTIK_BOOTSTRAP_EMAIL_VALUE}${CL}"
    if [ "${AUTHENTIK_BOOTSTRAP_PASSWORD_MODE:-auto}" == "custom" ]; then
        echo -e "AUTHENTIK_BOOTSTRAP_PASSWORD=${YW}<custom / not displayed>${CL}"
    else
        echo -e "AUTHENTIK_BOOTSTRAP_PASSWORD=${GN}${AUTHENTIK_BOOTSTRAP_PASSWORD_VALUE}${CL}"
    fi
    if [ "${AUTHENTIK_BOOTSTRAP_TOKEN_MODE:-auto}" == "custom" ]; then
        echo -e "AUTHENTIK_BOOTSTRAP_TOKEN=${YW}<custom / not displayed>${CL}"
    else
        echo -e "AUTHENTIK_BOOTSTRAP_TOKEN=${GN}${AUTHENTIK_BOOTSTRAP_TOKEN_VALUE}${CL}"
    fi
    echo -e "AUTHENTIK_API_TOKEN_MODE=${GN}${AUTHENTIK_API_TOKEN_MODE}${CL}"
    if [ -n "$AUTHENTIK_API_TOKEN_VALUE" ]; then
        echo -e "AUTHENTIK_API_TOKEN=${YW}<captured / not displayed>${CL}"
    else
        echo -e "AUTHENTIK_API_TOKEN=${YW}<empty / skipped>${CL}"
    fi
    echo -e "${YW}Reminder: Script 6.3 can use the Authentik bootstrap/API token when API automation is enabled.${CL}"

    echo ""
    echo -e "${YW}6-FAMILY SERVICE SECRETS:${CL}"
    echo -e "AUTHENTIK_SECRET_KEY=${GN}${AUTHENTIK_SECRET_KEY}${CL}"
    echo -e "AUTHENTIK_POSTGRES_PASSWORD=${GN}${AUTHENTIK_POSTGRES_PASSWORD}${CL}"
    echo -e "POSTIZ_POSTGRES_PASSWORD=${GN}${POSTIZ_POSTGRES_PASSWORD}${CL}"
    echo -e "POSTIZ_REDIS_PASSWORD=${GN}${POSTIZ_REDIS_PASSWORD}${CL}"
    echo -e "POSTIZ_JWT_SECRET=${GN}${POSTIZ_JWT_SECRET}${CL}"
    echo -e "TEMPORAL_POSTGRES_PASSWORD=${GN}${TEMPORAL_POSTGRES_PASSWORD}${CL}"
    echo -e "N8N_ENCRYPTION_KEY=${GN}${N8N_ENCRYPTION_KEY}${CL}"
    echo ""

    echo -e "${YW}HTPASSWD:${CL}"
    if [ "$HTPASSWD_MODE" == "generated" ]; then
        echo -e "HTPASSWD_HASHED_LINE=${GN}${HTPASSWD_LINE_VALUE}${CL}"
        echo -e "${YW}Plain htpasswd password was not displayed or logged.${CL}"
    elif [ "$HTPASSWD_MODE" == "provided" ]; then
        echo -e "${GN}Provided htpasswd entry saved to:${CL} ${DOCKER_SECRETS_DIR}/htpasswd"
        echo -e "${YW}Provided htpasswd hash is intentionally not displayed or logged.${CL}"
    elif root_file_not_empty "${DOCKER_SECRETS_DIR}/htpasswd"; then
        echo -e "${GN}Existing htpasswd file preserved at:${CL} ${DOCKER_SECRETS_DIR}/htpasswd"
        echo -e "${YW}Existing htpasswd content is intentionally not displayed.${CL}"
    else
        echo -e "${YW}htpasswd file created empty:${CL} ${DOCKER_SECRETS_DIR}/htpasswd"
        echo -e "${YW}This is fine when Authentik/SSO is used instead of Traefik basic-auth.${CL}"
    fi

    echo ""
    echo -e "${YW}Sensitive final output above was intentionally not written to ${LOG_FILE}.${CL}"

    wait_then_clear_secret_display
    enable_logging
}

function show_clean_final_summary() {
    local smtp_summary="skipped"
    local service_secret_summary="generated"
    local htpasswd_summary="empty or existing placeholder"
    local traefik_app_host=""

    marker_readiness_values
    section_flash_success "     ━━━━━━━━━━━━━━━━━    FINISHED    ━━━━━━━━━━━━━━━━━"

    if [ -n "${AUTHENTIK_EMAIL__HOST_VALUE:-}" ] && [ -n "${AUTHENTIK_EMAIL__USERNAME_VALUE:-}" ]; then
        smtp_summary="configured"
    fi

    if [ "$EXISTING_SETUP" == "yes" ] && [ "$REGENERATE_SECRETS" != "y" ]; then
        service_secret_summary="reused"
    fi

    case "$HTPASSWD_MODE" in
        generated) htpasswd_summary="${DOCKER_SECRETS_DIR}/htpasswd (generated)" ;;
        provided) htpasswd_summary="${DOCKER_SECRETS_DIR}/htpasswd (provided)" ;;
        *) htpasswd_summary="${DOCKER_SECRETS_DIR}/htpasswd" ;;
    esac

    traefik_app_host="${TRAEFIK_HOST:-${TRAEFIK_DASHBOARD_HOST:-}}"

    echo -e "${YW}Prepared:${CL}"
    final_line "Docker dir" "$DOCKER_DIR"
    final_line "Compose dir" "${DOCKER_DIR}/compose"
    final_line ".env" "${DOCKER_DIR}/.env"
    final_line "Secrets dir" "$DOCKER_SECRETS_DIR"
    final_line "Domain" "$DOMAIN_VALUE"
    final_line "Docker user" "$DOCKER_USER"
    final_line "PUID / PGID" "${PUID_VALUE} / ${PGID_VALUE}"

    echo ""
    echo -e "${YW}Script 5 handoff:${CL}"
    final_line "Script 5" "$SCRIPT5_STATUS" "$(status_color_for_value "$SCRIPT5_STATUS")"
    final_line "Verification" "$SCRIPT5_VERIFY_STATUS" "$(status_color_for_value "$SCRIPT5_VERIFY_STATUS")"
    final_line "Ubuntu swap" "$SCRIPT5_SWAP_RESULT" "$(status_color_for_value "$SCRIPT5_SWAP_RESULT")"
    final_line "Swap file" "$SCRIPT5_SWAP_FILE" "$(status_color_for_value "$SCRIPT5_SWAP_FILE")"
    final_line "Swap size" "$SCRIPT5_SWAP_SIZE" "$(status_color_for_value "$SCRIPT5_SWAP_SIZE")"
    final_line "Redis host tuning" "$SCRIPT5_REDIS_OVERCOMMIT" "$(status_color_for_value "$SCRIPT5_REDIS_OVERCOMMIT")"

    echo ""
    echo -e "${YW}Routing:${CL}"
    final_line "Proxmox route" "$(yes_no_label "$PROXMOX_ROUTE_ENABLED")"
    final_line "Proxmox host" "${PROXMOX_HOST:-skipped}"
    final_line "Proxmox LAN URL" "${PROXMOX_URL:-skipped}"
    final_line "Static config" "$TRAEFIK_STATIC_CONFIG_FILE"
    final_line "Dynamic config" "$TRAEFIK_DYNAMIC_CONFIG_FILE"
    final_line "acme.json" "${TRAEFIK_ACME_DIR}/acme.json"
    final_line "Cloudflare token" "$SCRIPT6_CF_TOKEN_FILE_READY" "$(status_color_for_value "$SCRIPT6_CF_TOKEN_FILE_READY")"

    echo ""
    echo -e "${YW}6-family defaults:${CL}"
    final_line "Admin UI default" "$ADMIN_UI_DISPLAY_NAME"
    final_line "Landing URL" "$(https_url_or_not_configured "${LANDING_HOST:-}")"
    final_line "Landing www" "$(https_url_or_not_configured "${LANDING_WWW_HOST:-}")"
    final_line "Traefik URL" "$(https_url_or_not_configured "$traefik_app_host")"
    final_line "Authentik URL" "$(https_url_or_not_configured "${AUTHENTIK_EXTERNAL_URL_VALUE:-${AUTHENTIK_HOST_VALUE:-${AUTHENTIK_HOST:-}}}")"
    final_line "Postiz URL" "$(https_url_or_not_configured "${POSTIZ_HOST:-}")"
    final_line "n8n URL" "$(https_url_or_not_configured "${N8N_HOST:-}")"
    final_line "Authentik email" "$AUTHENTIK_BOOTSTRAP_EMAIL_VALUE"
    final_line "SMTP relay" "$smtp_summary"

    echo ""
    echo -e "${YW}Secrets:${CL}"
    final_line "Service secrets" "$service_secret_summary"
    final_line "Cloudflare token file" "$CF_API_TOKEN_FILE"
    final_line "Htpasswd file" "$htpasswd_summary"
    final_line "Secret screen cleared" "$SECRET_SCREEN_CLEARED"

    echo ""
    echo -e "${YW}Readiness:${CL}"
    final_line "Traefik config" "$SCRIPT6_TRAEFIK_CONFIG_READY" "$(status_color_for_value "$SCRIPT6_TRAEFIK_CONFIG_READY")"
    final_line "acme.json" "$SCRIPT6_TRAEFIK_ACME_READY" "$(status_color_for_value "$SCRIPT6_TRAEFIK_ACME_READY")"
    final_line ".env" "$SCRIPT6_ENV_FILE_READY" "$(status_color_for_value "$SCRIPT6_ENV_FILE_READY")"
    final_line "Secrets" "$SCRIPT6_SECRETS_READY" "$(status_color_for_value "$SCRIPT6_SECRETS_READY")"
    final_line "Ready for 6.1" "$SCRIPT6_READY_FOR_SCRIPT61" "$(status_color_for_value "$SCRIPT6_READY_FOR_SCRIPT61")"
    final_line "Ready for 6.2" "$SCRIPT6_READY_FOR_SCRIPT62" "$(status_color_for_value "$SCRIPT6_READY_FOR_SCRIPT62")"
    final_line "Ready for 6.3" "$SCRIPT6_READY_FOR_SCRIPT63" "$(status_color_for_value "$SCRIPT6_READY_FOR_SCRIPT63")"
    final_line "Ready for 6.4" "$SCRIPT6_READY_FOR_SCRIPT64" "$(status_color_for_value "$SCRIPT6_READY_FOR_SCRIPT64")"
    final_line "Ready for 6.5" "$SCRIPT6_READY_FOR_SCRIPT65" "$(status_color_for_value "$SCRIPT6_READY_FOR_SCRIPT65")"
    final_line "Ready for 6.6" "$SCRIPT6_READY_FOR_SCRIPT66" "$(status_color_for_value "$SCRIPT6_READY_FOR_SCRIPT66")"

    echo ""
    echo -e "${YW}Verification:${CL}"
    case "$VERIFY_STATUS" in
        PASS) final_line "Status" "$VERIFY_STATUS" "$GN" ;;
        PASS_WITH_WARNINGS) final_line "Status" "$VERIFY_STATUS" "$YW" ;;
        FAIL) final_line "Status" "$VERIFY_STATUS" "$RD" ;;
        *) final_line "Status" "${VERIFY_STATUS:-unknown}" "$YW" ;;
    esac
    final_line "Pass" "$VERIFY_PASS_COUNT" "$GN"
    final_line "Warn" "$VERIFY_WARN_COUNT" "$YW"
    final_line "Fail" "$VERIFY_FAIL_COUNT" "$RD"
    final_line "Verify log" "$VERIFY_LOG" "$GN"
    final_line "Display log" "$VERIFY_DISPLAY_LOG" "$GN"

    if [ -n "$VERIFY_FIRST_ISSUE_TYPE" ]; then
        echo ""
        echo -e "${YW}${VERIFY_FIRST_ISSUE_TYPE} 1:${CL}"
        final_line "Check" "$VERIFY_FIRST_ISSUE_CHECK" "$GN"
        final_line "Reason" "$VERIFY_FIRST_ISSUE_REASON" "$YW"
        final_line "Fix" "$VERIFY_FIRST_ISSUE_FIX" "$GN"
    fi

    echo ""
    echo -e "${YW}Script 6 prepared the environment only. No compose stacks were deployed.${CL}"
    echo -e "${YW}Sensitive values were displayed once, not logged, then terminal output was cleared where supported.${CL}"
    echo ""
    echo -e "${BL}Next Step:${CL}"
    echo -e "  ${YW}Build/run ${ANS}Script 6.1 platform core bootstrap${YW}.${CL}"
    echo ""
}

function main() {
    init_script

    check_docker_readiness
    check_previous_marker
    start_confirmation
    collect_user_and_path_inputs
    detect_existing_setup
    collect_domain_cloudflare_inputs
    collect_traefik_authentik_email_inputs
    collect_admin_ui_selection
    collect_network_proxmox_inputs
    collect_service_hostnames
    collect_traefik_inputs
    collect_authentik_inputs
    collect_authentik_email_smtp_inputs
    collect_htpasswd_inputs
    show_ready_summary_and_confirm

    create_docker_directories
    generate_or_reuse_secrets
    create_traefik_config_files
    verify_traefik_config_files_created
    write_secret_files
    write_env_file
    apply_permissions
    verify_service_permissions

    wait_before_secret_display
    show_secrets_once_without_logging

    write_completion_marker
    create_verification_report
    write_verify_display_log
    update_completion_marker_script6_fields
    show_clean_final_summary

    exit 0
}


main "$@"