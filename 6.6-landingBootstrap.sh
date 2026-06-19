#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Project Circl8 - Script 6.6 Landing Bootstrap
# =========================================================
# Script 6.6 prepares the public Astro landing-site bootstrap lane.
# This v1.0.3 phase is read-only/preflight only: it inspects context,
# source/appdata/template/runtime state, and writes a verification report.
# It does not build, copy, deploy, create directories, write .env values,
# or write the final landing completion marker.

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

SCRIPT_SOURCE="6.6-landingBootstrap.sh"
SCRIPT_VERSION="v1.0.3"
SCRIPT_UPDATED="2026-06-19"
SCRIPT_BUILD="preflight-runtime-blocker-fix"

UI_LABEL_WIDTH="34"
LOG_FILE="/var/log/circl8-landing.log"
VERIFY_LOG="/var/log/circl8-landing-verify.log"
DEPLOY_FAILURE_LOG="/var/log/circl8-landing-deploy-failure.log"
FINAL_MARKER="/root/.circl8-landing-completed"
SCRIPT61_MARKER="/root/.circl8-platform-core-completed"
SCRIPT64_MARKER="/root/.circl8-app-completed"
SCRIPT65_MARKER="/root/.circl8-n8n-completed"
RAW_BASE_FALLBACK="https://raw.githubusercontent.com/Orik999/circl8/refs/heads/main"

SUDO_CMD=""
SCRIPT_DIR=""
TEMP_FILES=()
PROGRESS_LINE_ACTIVE="no"
DOCKER_AVAILABLE="unknown"
DOCKER_NEEDS_SUDO="no"

SCRIPT61_STATUS="unknown"
SCRIPT61_VERIFY_STATUS="unknown"
SCRIPT64_STATUS="unknown"
SCRIPT64_VERIFY_STATUS="unknown"
SCRIPT64_READY_FOR_SCRIPT65="unknown"
SCRIPT65_STATUS="unknown"
SCRIPT65_VERIFY_STATUS="unknown"
SCRIPT65_DEPLOYMENT="unknown"
SCRIPT65_READY_FOR_SCRIPT66="unknown"
SCRIPT66_HANDOFF_GATES="not-run"

DOCKER_USER="${SUDO_USER:-orik}"
DOCKER_DIR=""
COMPOSE_DIR=""
ENV_FILE=""
RAW_BASE_DEFAULT=""
DOMAIN_VALUE=""
LANDING_HOST=""
LANDING_WWW_HOST=""
LANDING_URL=""
LANDING_WWW_URL=""
LANDING_SOURCE_PATH=""
LANDING_APPDATA_PATH=""
LANDING_BACKUP_DIR=""
LANDING_REPO_COMPOSE="docker/08-landing-compose.yml"
LANDING_RUNTIME_COMPOSE=""
LANDING_TEMPLATE_URL=""
LANDING_CONTAINER_NAME="circl8-landing"
LANDING_IMAGE_ENV_STATUS="unknown"
LANDING_IMAGE_VALUE=""
LANDING_IMAGE_FALLBACK="nginx:alpine"
LANDING_EFFECTIVE_IMAGE="nginx:alpine"
VM_COPY_USER=""
VM_COPY_HOST=""
VM_COPY_TARGET="<vm-user>@<vm-ip>"

SCRIPT66_STATUS="preflight"
SCRIPT66_VERIFY_STATUS="PENDING"
SCRIPT66_DEPLOYMENT="not-run"
SCRIPT66_CONTAINERS="not-run"
SCRIPT66_HEALTH_STATUS="not-run"
SCRIPT66_ASTRO_SOURCE_STATUS="not-run"
SCRIPT66_ASTRO_PACKAGE_JSON="not-run"
SCRIPT66_ASTRO_CONFIG="not-run"
SCRIPT66_ASTRO_BUILD_SCRIPT="not-run"
SCRIPT66_ASTRO_DIST_STATUS="not-run"
SCRIPT66_APPDATA_STATUS="not-run"
SCRIPT66_APPDATA_INDEX_STATUS="not-run"
SCRIPT66_RUNTIME_COMPOSE_STATE="unknown"
SCRIPT66_RUNTIME_COMPOSE_SYNC_NEEDED="unknown"
SCRIPT66_TEMPLATE_SOURCE="unknown"
SCRIPT66_TEMPLATE_INSPECTION="not-run"
SCRIPT66_TEMPLATE_CHECK_SUMMARY="not-run"
SCRIPT66_CONTAINER_STATUS="not-run"
SCRIPT66_CONTAINER_RUNNING="not-run"
SCRIPT66_ROUTE_LABELS="not-run"
SCRIPT66_ROUTE_STATUS="deferred"
SCRIPT66_AUTHENTIK_WRITES="no"
SCRIPT66_READY_FOR_DEPLOY_PHASE="no"

# =========================================================
#  ROOT / SUDO HANDOFF
# =========================================================
function early_error() {
    echo -e "${CROSS} ${RD}$1${CL}" >&2
    exit 1
}

function validate_handoff_script_shape() {
    local script_path="$1"
    [ -s "$script_path" ] || return 1
    grep -q '^SCRIPT_SOURCE="6[.]6-landingBootstrap[.]sh"' "$script_path" || return 1
    grep -q '^SCRIPT_VERSION=' "$script_path" || return 1
    grep -q '^function main()' "$script_path" || return 1
    grep -q '^main "[$]@"' "$script_path" || return 1
    return 0
}

function download_handoff_script() {
    local dest="$1"
    local url="${RAW_BASE_FALLBACK%/}/${SCRIPT_SOURCE}"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$url"
    else
        return 1
    fi
}

function prepare_process_substitution_handoff() {
    local source_path="$1" dest="$2"
    : > "$dest" || return 1

    # A /dev/fd or /proc/*/fd process-substitution path can point at a stream
    # that bash has already partially consumed. Try the direct copy first, then
    # verify the copied script is complete before trusting it.
    if [ -r "$source_path" ]; then
        cat "$source_path" > "$dest" 2>/dev/null || true
    fi

    if ! validate_handoff_script_shape "$dest"; then
        : > "$dest" || return 1
        download_handoff_script "$dest" || return 1
    fi

    validate_handoff_script_shape "$dest" || return 1
    chmod 700 "$dest" 2>/dev/null || return 1
    return 0
}

function elevate_to_root_if_needed() {
    if [ "${EUID}" -eq 0 ]; then
        return 0
    fi

    command -v sudo >/dev/null 2>&1 || early_error "Root privileges are required. Install sudo or re-run as root."
    if ! sudo -n true >/dev/null 2>&1; then
        early_error "Passwordless sudo is required for this bootstrap. Configure NOPASSWD sudo or re-run as root."
    fi

    local script_path="${BASH_SOURCE[0]}" handoff_script=""
    case "$script_path" in
        /dev/fd/*|/proc/*/fd/*)
            handoff_script="$(mktemp /tmp/circl8-landing-sudo-handoff.XXXXXX.sh)" || early_error "Could not prepare sudo handoff script."
            if ! prepare_process_substitution_handoff "$script_path" "$handoff_script"; then
                rm -f "$handoff_script" 2>/dev/null || true
                early_error "Could not prepare a complete sudo handoff script from process substitution."
            fi
            exec sudo -n bash -c 'script="$1"; shift; trap '\''rm -f "$script"'\'' EXIT; bash "$script" "$@"' bash "$handoff_script" "$@"
            ;;
        *)
            exec sudo -n bash "$script_path" "$@"
            ;;
    esac
}

# =========================================================
#  UI HELPERS
# =========================================================
function header_info() {
cat <<'BANNER'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Project Circl8
  6.6 Landing
  Read-only preflight
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

BANNER
}

function show_script_version() {
    echo -e "${GN}SCRIPT VERSION: ${SCRIPT_VERSION} | UPDATED: ${SCRIPT_UPDATED} | BUILD: ${SCRIPT_BUILD}${CL}"
    echo -e "${BL}SOURCE: ${SCRIPT_SOURCE}${CL}"
}

function section() { echo ""; echo -e "${BORDER}"; echo -e "${BL}$1${CL}"; echo -e "${BORDER}"; }
function section_flash_success() { echo ""; echo -e "${BORDER}"; echo -e "${GN}${CLF}$1${CL}"; echo -e "${BORDER}"; }
function mini_header() { clear_progress_line || true; echo ""; echo -e "${YW}$1:${CL}"; }
function clear_progress_line() { [ "${PROGRESS_LINE_ACTIVE:-no}" = "yes" ] && printf '%b' "${BFR}" && PROGRESS_LINE_ACTIVE="no" || true; }
function msg_info() { clear_progress_line || true; PROGRESS_LINE_ACTIVE="yes"; echo -ne " ${HOLD} ${YW}$1...${CL}"; }
function msg_ok() { echo -e "${BFR} ${CM} ${GN}$1${CL}"; PROGRESS_LINE_ACTIVE="no"; }
function msg_warn() { echo -e "${BFR} ${WARN} ${YW}$1${CL}"; PROGRESS_LINE_ACTIVE="no"; }
function msg_error() { echo -e "${BFR} ${CROSS} ${RD}$1${CL}"; exit 1; }

function ui_display_value() {
    local value="${1:-unknown}"
    case "$value" in
        not-run) printf 'not run' ;;
        not-needed) printf 'not needed' ;;
        needs-review) printf 'needs review' ;;
        present-current) printf 'present-current' ;;
        present-stale) printf 'present-stale' ;;
        *) printf '%s' "$value" ;;
    esac
}

function status_color_for_value() {
    local value="${1:-unknown}"
    case "$value" in
        PASS|pass|completed|present|present-current|current|ready|yes|valid|detected|public|absent|not-needed|not-run|not\ run|deferred|preflight|running) printf '%s' "$GN" ;;
        WARN|warn|warning|unknown|present-stale|stopped|exited|skipped|needs-review|missing-source|missing-runtime|missing-template|partial|incomplete|planned) printf '%s' "$YW" ;;
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
    exec > >(tee -a "$LOG_FILE") 2>&1
}

function cleanup() {
    local exit_code="$?" file=""
    clear_progress_line || true
    for file in "${TEMP_FILES[@]:-}"; do
        [ -n "$file" ] && [ -f "$file" ] && rm -f "$file" 2>/dev/null || true
    done
    exit "$exit_code"
}

function on_error() {
    local line_no="$1"
    clear_progress_line || true
    SCRIPT66_STATUS="preflight-failed"
    SCRIPT66_VERIFY_STATUS="FAILED"
    SCRIPT66_DEPLOYMENT="not-run"
    SCRIPT66_READY_FOR_DEPLOY_PHASE="no"
    write_verify_report || true
    echo -e "${RD}ERROR:${CL} Script failed at line ${line_no}. Check ${LOG_FILE}"
    echo -e "  ${BL}Verify log:${CL} ${VERIFY_LOG}"
}

function fail_with_report() {
    local message="$1"
    clear_progress_line || true
    SCRIPT66_STATUS="preflight-failed"
    SCRIPT66_VERIFY_STATUS="FAILED"
    SCRIPT66_DEPLOYMENT="not-run"
    SCRIPT66_READY_FOR_DEPLOY_PHASE="no"
    write_verify_report || true
    echo -e "${BFR} ${CROSS} ${RD}${message}${CL}"
    echo -e "  ${BL}Verify log:${CL} ${VERIFY_LOG}"
    exit 1
}

# =========================================================
#  READ-ONLY HELPERS
# =========================================================
function root_path_exists() { test -e "$1"; }
function root_file_not_empty() { test -s "$1"; }
function root_read_file() { cat "$1"; }
function write_root_file() { cat > "$1"; }

function validate_dependencies() {
    local cmds=(awk cat command date grep mktemp rm sed sort stat tee test tr python3)
    local cmd=""
    for cmd in "${cmds[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || msg_error "Required command not found: ${cmd}"
    done
}

function detect_docker_access() {
    section "DOCKER ACCESS CHECK"
    msg_info "Checking Docker access"

    if ! command -v docker >/dev/null 2>&1; then
        DOCKER_AVAILABLE="no"
        SCRIPT66_CONTAINERS="not-run"
        msg_warn "DOCKER COMMAND NOT FOUND; CONTAINER INSPECTION DEFERRED"
        aligned_status_line "Docker" "deferred" "$YW"
        return 0
    fi

    if docker ps >/dev/null 2>&1; then
        DOCKER_AVAILABLE="yes"
        DOCKER_NEEDS_SUDO="no"
        msg_ok "DOCKER ACCESS CONFIRMED"
        aligned_status_line "Docker" "current user" "$GN"
        return 0
    fi

    if [ -n "$SUDO_CMD" ] && $SUDO_CMD docker ps >/dev/null 2>&1; then
        DOCKER_AVAILABLE="yes"
        DOCKER_NEEDS_SUDO="yes"
        msg_ok "DOCKER ACCESS CONFIRMED WITH SUDO"
        aligned_status_line "Docker" "sudo fallback" "$GN"
        return 0
    fi

    DOCKER_AVAILABLE="no"
    SCRIPT66_CONTAINERS="not-run"
    msg_warn "DOCKER DAEMON NOT REACHABLE; CONTAINER INSPECTION DEFERRED"
    aligned_status_line "Docker" "deferred" "$YW"
}

function docker_read() {
    if [ "$DOCKER_NEEDS_SUDO" = "yes" ]; then
        $SUDO_CMD docker "$@"
    else
        docker "$@"
    fi
}

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
        $0 ~ "^[[:space:]]*#" {next}
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

function host_from_url() {
    local value="${1:-}"
    value="$(printf '%s' "$value" | trim_shell_value)"
    value="${value#http://}"; value="${value#https://}"; value="${value%%/*}"; value="${value%%:*}"
    printf '%s' "$value" | tr '[:upper:]' '[:lower:]'
}

function validate_domain() { [[ "${1:-}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]]; }
function first_nonempty_marker_value() {
    local key="" value=""
    for key in "$@"; do
        value="$(marker_file_key_value "$SCRIPT61_MARKER" "$key")"
        [ -n "$value" ] && { printf '%s' "$value"; return 0; }
        value="$(marker_file_key_value "$SCRIPT64_MARKER" "$key")"
        [ -n "$value" ] && { printf '%s' "$value"; return 0; }
        value="$(marker_file_key_value "$SCRIPT65_MARKER" "$key")"
        [ -n "$value" ] && { printf '%s' "$value"; return 0; }
    done
    return 1
}

function detect_vm_copy_user() {
    local user=""
    user="${DOCKER_USER:-}"
    [ -n "$user" ] || user="$(first_nonempty_marker_value SCRIPT61_DOCKER_USER SCRIPT64_DOCKER_USER SCRIPT65_DOCKER_USER || true)"
    [ -n "$user" ] || user="${SUDO_USER:-}"
    [ -n "$user" ] || user="$(id -un 2>/dev/null || true)"
    if [ "$user" = "root" ] && [ -n "${SUDO_USER:-}" ]; then
        user="$SUDO_USER"
    fi
    printf '%s' "$user"
}

function valid_copy_host() {
    local host="${1:-}"
    [ -n "$host" ] || return 1
    [[ "$host" =~ ^[A-Za-z0-9._:-]+$ ]]
}

function detect_vm_copy_host() {
    local value="" key=""

    for key in VM_IP VM_HOST SERVER_IP SERVER_HOST HOST_IP SSH_HOST; do
        value="$(env_value "$key")"
        value="$(host_from_url "$value")"
        if valid_copy_host "$value"; then
            printf '%s' "$value"
            return 0
        fi
    done

    value="$(first_nonempty_marker_value SCRIPT61_VM_IP SCRIPT61_HOST_IP SCRIPT64_VM_IP SCRIPT65_VM_IP SERVER_IP HOST_IP || true)"
    value="$(host_from_url "$value")"
    if valid_copy_host "$value"; then
        printf '%s' "$value"
        return 0
    fi

    if command -v ip >/dev/null 2>&1; then
        value="$(ip -o -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}' || true)"
        if valid_copy_host "$value"; then
            printf '%s' "$value"
            return 0
        fi
        value="$(ip -o -4 addr show scope global 2>/dev/null | awk '{split($4, a, "/"); print a[1]; exit}' || true)"
        if valid_copy_host "$value"; then
            printf '%s' "$value"
            return 0
        fi
    fi

    if command -v hostname >/dev/null 2>&1; then
        value="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
        if valid_copy_host "$value"; then
            printf '%s' "$value"
            return 0
        fi
    fi

    return 1
}

function detect_landing_copy_target() {
    VM_COPY_USER="$(detect_vm_copy_user)"
    VM_COPY_HOST="$(detect_vm_copy_host || true)"

    if [ -n "$VM_COPY_USER" ] && [ -n "$VM_COPY_HOST" ]; then
        VM_COPY_TARGET="${VM_COPY_USER}@${VM_COPY_HOST}"
    else
        VM_COPY_TARGET="<vm-user>@<vm-ip>"
    fi
}

function detect_landing_image_context() {
    local image_value="" template_path="" template_image_line="" fallback=""

    image_value="$(env_value LANDING_IMAGE)"
    if [ -n "$image_value" ]; then
        LANDING_IMAGE_ENV_STATUS="present"
        LANDING_IMAGE_VALUE="$image_value"
        LANDING_EFFECTIVE_IMAGE="$image_value"
        return 0
    fi

    LANDING_IMAGE_ENV_STATUS="absent"
    if template_path="$(landing_template_path 2>/dev/null)"; then
        template_image_line="$(grep -E '^[[:space:]]*image:[[:space:]]*[$][{]LANDING_IMAGE:-' "$template_path" | head -n1 || true)"
        fallback="$(printf '%s' "$template_image_line" | sed -n 's/.*[$][{]LANDING_IMAGE:-\([^}]*\)}.*/\1/p')"
        [ -n "$fallback" ] && LANDING_IMAGE_FALLBACK="$fallback"
    fi
    LANDING_EFFECTIVE_IMAGE="$LANDING_IMAGE_FALLBACK"
}

# =========================================================
#  PREFLIGHT GATES / PROJECT CONTEXT
# =========================================================
function validate_handoff_gates() {
    if ! root_path_exists "$SCRIPT61_MARKER"; then fail_with_report "Script 6.1 completion marker is missing."; fi
    SCRIPT61_STATUS="$(marker_file_key_value "$SCRIPT61_MARKER" SCRIPT61_STATUS)"
    SCRIPT61_VERIFY_STATUS="$(marker_file_key_value "$SCRIPT61_MARKER" SCRIPT61_VERIFY_STATUS)"
    [ "$SCRIPT61_STATUS" = "completed" ] || fail_with_report "Script 6.1 status is not completed."
    [ "$SCRIPT61_VERIFY_STATUS" = "PASS" ] || fail_with_report "Script 6.1 verification is not PASS."

    if ! root_path_exists "$SCRIPT64_MARKER"; then fail_with_report "Script 6.4 completion marker is missing."; fi
    SCRIPT64_STATUS="$(marker_file_key_value "$SCRIPT64_MARKER" SCRIPT64_STATUS)"
    SCRIPT64_VERIFY_STATUS="$(marker_file_key_value "$SCRIPT64_MARKER" SCRIPT64_VERIFY_STATUS)"
    SCRIPT64_READY_FOR_SCRIPT65="$(marker_file_key_value "$SCRIPT64_MARKER" SCRIPT64_READY_FOR_SCRIPT65)"
    [ "$SCRIPT64_STATUS" = "completed" ] || fail_with_report "Script 6.4 status is not completed."
    [ "$SCRIPT64_VERIFY_STATUS" = "PASS" ] || fail_with_report "Script 6.4 verification is not PASS."
    [ "$SCRIPT64_READY_FOR_SCRIPT65" = "yes" ] || fail_with_report "Script 6.4 is not marked ready for Script 6.5."

    if ! root_path_exists "$SCRIPT65_MARKER"; then fail_with_report "Script 6.5 deployed marker is missing."; fi
    SCRIPT65_STATUS="$(marker_file_key_value "$SCRIPT65_MARKER" SCRIPT65_STATUS)"
    SCRIPT65_VERIFY_STATUS="$(marker_file_key_value "$SCRIPT65_MARKER" SCRIPT65_VERIFY_STATUS)"
    SCRIPT65_DEPLOYMENT="$(marker_file_key_value "$SCRIPT65_MARKER" SCRIPT65_DEPLOYMENT)"
    SCRIPT65_READY_FOR_SCRIPT66="$(marker_file_key_value "$SCRIPT65_MARKER" SCRIPT65_READY_FOR_SCRIPT66)"
    [ "$SCRIPT65_STATUS" = "completed" ] || fail_with_report "Script 6.5 status is not completed."
    [ "$SCRIPT65_VERIFY_STATUS" = "PASS" ] || fail_with_report "Script 6.5 verification is not PASS."
    [ "$SCRIPT65_DEPLOYMENT" = "deployed" ] || fail_with_report "Script 6.5 deployment is not marked deployed."
    [ "$SCRIPT65_READY_FOR_SCRIPT66" = "yes" ] || fail_with_report "Script 6.5 is not marked ready for Script 6.6."

    SCRIPT66_HANDOFF_GATES="PASS"
}

function load_project_context() {
    DOCKER_DIR="$(marker_file_key_value "$SCRIPT61_MARKER" SCRIPT61_DOCKER_DIR)"
    COMPOSE_DIR="$(marker_file_key_value "$SCRIPT61_MARKER" SCRIPT61_COMPOSE_DIR)"
    [ -n "$DOCKER_DIR" ] || DOCKER_DIR="$(marker_file_key_value "$SCRIPT64_MARKER" SCRIPT64_DOCKER_DIR)"
    [ -n "$DOCKER_DIR" ] || DOCKER_DIR="/home/${DOCKER_USER}/docker"
    [ -n "$COMPOSE_DIR" ] || COMPOSE_DIR="${DOCKER_DIR}/compose"
    ENV_FILE="${DOCKER_DIR}/.env"

    RAW_BASE_DEFAULT="$(env_value RAW_BASE_DEFAULT)"
    [ -n "$RAW_BASE_DEFAULT" ] || RAW_BASE_DEFAULT="$(env_value RAW_BASE)"
    [ -n "$RAW_BASE_DEFAULT" ] || RAW_BASE_DEFAULT="$RAW_BASE_FALLBACK"

    DOMAIN_VALUE="$(env_value DOMAIN)"
    [ -n "$DOMAIN_VALUE" ] || DOMAIN_VALUE="$(marker_file_key_value "$SCRIPT61_MARKER" SCRIPT61_DOMAIN)"
    [ -n "$DOMAIN_VALUE" ] || DOMAIN_VALUE="$(marker_file_key_value "$SCRIPT64_MARKER" SCRIPT64_PROJECT_BASE_DOMAIN)"
    DOMAIN_VALUE="$(host_from_url "$DOMAIN_VALUE")"
    validate_domain "$DOMAIN_VALUE" || fail_with_report "Base domain could not be derived from markers or .env."

    LANDING_HOST="$DOMAIN_VALUE"
    LANDING_WWW_HOST="www.${DOMAIN_VALUE}"
    LANDING_URL="https://${LANDING_HOST}"
    LANDING_WWW_URL="https://${LANDING_WWW_HOST}"
    LANDING_SOURCE_PATH="${DOCKER_DIR}/projects/landing"
    LANDING_APPDATA_PATH="${DOCKER_DIR}/appdata/landing"
    LANDING_BACKUP_DIR="${DOCKER_DIR}/backups/landing"
    LANDING_RUNTIME_COMPOSE="${COMPOSE_DIR}/08-landing-compose.yml"
    LANDING_TEMPLATE_URL="${RAW_BASE_DEFAULT%/}/docker/08-landing-compose.yml"

    detect_landing_image_context
    detect_landing_copy_target
}

function print_handoff_summary() {
    section "HANDOFF"
    aligned_status_line "Script 6.4" "$SCRIPT64_VERIFY_STATUS" "$(status_color_for_value "$SCRIPT64_VERIFY_STATUS")"
    aligned_status_line "Script 6.5" "$SCRIPT65_VERIFY_STATUS" "$(status_color_for_value "$SCRIPT65_VERIFY_STATUS")"
    aligned_status_line "Ready" "$SCRIPT65_READY_FOR_SCRIPT66" "$(status_color_for_value "$SCRIPT65_READY_FOR_SCRIPT66")"
    msg_ok "SCRIPT 6.6 HANDOFF PASSED"
}

# =========================================================
#  LANDING READ-ONLY INSPECTION
# =========================================================
function package_has_build_script() {
    local package_file="$1"
    python3 - "$package_file" <<'PY_PACKAGE_BUILD'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        data = json.load(fh)
    scripts = data.get("scripts") or {}
    build = scripts.get("build")
    raise SystemExit(0 if isinstance(build, str) and build.strip() else 1)
except Exception:
    raise SystemExit(1)
PY_PACKAGE_BUILD
}

function inspect_landing_source() {
    local source="$LANDING_SOURCE_PATH"

    if root_path_exists "$source"; then
        SCRIPT66_ASTRO_SOURCE_STATUS="present"
    else
        SCRIPT66_ASTRO_SOURCE_STATUS="missing-source"
        SCRIPT66_ASTRO_PACKAGE_JSON="missing"
        SCRIPT66_ASTRO_CONFIG="missing"
        SCRIPT66_ASTRO_BUILD_SCRIPT="missing"
        SCRIPT66_ASTRO_DIST_STATUS="not-run"
        return 0
    fi

    if root_file_not_empty "${source}/package.json"; then
        SCRIPT66_ASTRO_PACKAGE_JSON="present"
    else
        SCRIPT66_ASTRO_PACKAGE_JSON="missing"
    fi

    if ls "${source}"/astro.config.* >/dev/null 2>&1; then
        SCRIPT66_ASTRO_CONFIG="present"
    else
        SCRIPT66_ASTRO_CONFIG="missing"
    fi

    if [ "$SCRIPT66_ASTRO_PACKAGE_JSON" = "present" ] && package_has_build_script "${source}/package.json"; then
        SCRIPT66_ASTRO_BUILD_SCRIPT="present"
    else
        SCRIPT66_ASTRO_BUILD_SCRIPT="missing"
    fi

    if root_path_exists "${source}/dist"; then
        SCRIPT66_ASTRO_DIST_STATUS="present"
    else
        SCRIPT66_ASTRO_DIST_STATUS="missing"
    fi

    if [ "$SCRIPT66_ASTRO_PACKAGE_JSON" = "present" ] && [ "$SCRIPT66_ASTRO_CONFIG" = "present" ] && [ "$SCRIPT66_ASTRO_BUILD_SCRIPT" = "present" ]; then
        SCRIPT66_ASTRO_SOURCE_STATUS="valid"
    else
        SCRIPT66_ASTRO_SOURCE_STATUS="incomplete"
    fi
}

function inspect_landing_appdata() {
    if root_path_exists "$LANDING_APPDATA_PATH"; then
        SCRIPT66_APPDATA_STATUS="present"
    else
        SCRIPT66_APPDATA_STATUS="missing"
    fi

    if root_file_not_empty "${LANDING_APPDATA_PATH}/index.html"; then
        SCRIPT66_APPDATA_INDEX_STATUS="present"
    else
        SCRIPT66_APPDATA_INDEX_STATUS="missing"
    fi
}

function landing_template_path() {
    if [ -f "${SCRIPT_DIR}/${LANDING_REPO_COMPOSE}" ]; then
        printf '%s' "${SCRIPT_DIR}/${LANDING_REPO_COMPOSE}"
        return 0
    fi
    if [ -f "$LANDING_REPO_COMPOSE" ]; then
        printf '%s' "$LANDING_REPO_COMPOSE"
        return 0
    fi
    return 1
}

function inspect_runtime_compose() {
    local template_path=""
    if root_file_not_empty "$LANDING_RUNTIME_COMPOSE"; then
        if template_path="$(landing_template_path)"; then
            if cmp -s "$template_path" "$LANDING_RUNTIME_COMPOSE"; then
                SCRIPT66_RUNTIME_COMPOSE_STATE="present-current"
                SCRIPT66_RUNTIME_COMPOSE_SYNC_NEEDED="no"
            else
                SCRIPT66_RUNTIME_COMPOSE_STATE="present-stale"
                SCRIPT66_RUNTIME_COMPOSE_SYNC_NEEDED="yes"
            fi
        else
            SCRIPT66_RUNTIME_COMPOSE_STATE="present-deferred"
            SCRIPT66_RUNTIME_COMPOSE_SYNC_NEEDED="deferred"
        fi
    else
        SCRIPT66_RUNTIME_COMPOSE_STATE="missing-runtime"
        SCRIPT66_RUNTIME_COMPOSE_SYNC_NEEDED="yes"
    fi
}

function inspect_landing_container() {
    local state="" labels=""
    if [ "$DOCKER_AVAILABLE" != "yes" ]; then
        SCRIPT66_CONTAINER_STATUS="deferred"
        SCRIPT66_CONTAINER_RUNNING="deferred"
        SCRIPT66_CONTAINERS="read-only-deferred"
        SCRIPT66_ROUTE_LABELS="deferred"
        return 0
    fi

    state="$(docker_read inspect -f '{{.State.Status}}' "$LANDING_CONTAINER_NAME" 2>/dev/null || true)"
    if [ -z "$state" ]; then
        SCRIPT66_CONTAINER_STATUS="missing"
        SCRIPT66_CONTAINER_RUNNING="no"
        SCRIPT66_CONTAINERS="missing"
        SCRIPT66_ROUTE_LABELS="not-run"
        return 0
    fi

    SCRIPT66_CONTAINER_STATUS="present"
    SCRIPT66_CONTAINER_RUNNING="$state"
    SCRIPT66_CONTAINERS="read-only"

    labels="$(docker_read inspect -f '{{json .Config.Labels}}' "$LANDING_CONTAINER_NAME" 2>/dev/null || true)"
    if printf '%s' "$labels" | grep -q 'traefik.http.routers.circl8-landing.rule' \
        && printf '%s' "$labels" | grep -q "${LANDING_HOST}"; then
        SCRIPT66_ROUTE_LABELS="present"
    else
        SCRIPT66_ROUTE_LABELS="missing"
    fi
}

function appdata_display_status() {
    if [ "$SCRIPT66_APPDATA_STATUS" = "present" ] && [ "$SCRIPT66_APPDATA_INDEX_STATUS" = "present" ]; then
        printf 'present'
    elif [ "$SCRIPT66_APPDATA_STATUS" = "present" ]; then
        printf 'present-no-index'
    else
        printf 'missing'
    fi
}

function container_display_status() {
    case "$SCRIPT66_CONTAINER_STATUS:$SCRIPT66_CONTAINER_RUNNING" in
        missing:*) printf 'missing' ;;
        deferred:*) printf 'deferred' ;;
        present:running) printf 'running' ;;
        present:*) printf 'stopped' ;;
        *) printf '%s' "$SCRIPT66_CONTAINER_STATUS" ;;
    esac
}

function template_display_status() {
    case "$SCRIPT66_TEMPLATE_SOURCE:$SCRIPT66_TEMPLATE_INSPECTION" in
        remote-planned:*) printf 'remote planned' ;;
        local\ repo:*) printf 'local' ;;
        *:deferred) printf 'remote planned' ;;
        *) printf '%s' "$SCRIPT66_TEMPLATE_SOURCE" ;;
    esac
}

function template_checks_display_status() {
    case "$SCRIPT66_TEMPLATE_INSPECTION" in
        pass) printf 'PASS' ;;
        warn) printf 'WARN' ;;
        failed) printf 'FAILED' ;;
        deferred) printf 'deferred' ;;
        *) printf '%s' "$SCRIPT66_TEMPLATE_INSPECTION" ;;
    esac
}

function print_landing_state_inspection() {
    section "CURRENT STATE"
    inspect_landing_source
    inspect_landing_appdata
    inspect_runtime_compose
    inspect_landing_container
    inspect_landing_template

    aligned_status_line "Source" "$SCRIPT66_ASTRO_SOURCE_STATUS" "$(status_color_for_value "$SCRIPT66_ASTRO_SOURCE_STATUS")"
    if [ "$SCRIPT66_ASTRO_SOURCE_STATUS" = "incomplete" ]; then
        aligned_status_line "Source details" "package/config/build missing" "$YW"
    fi
    aligned_status_line "Static web root" "$(appdata_display_status)" "$(status_color_for_value "$(appdata_display_status)")"
    aligned_status_line "Runtime compose" "$SCRIPT66_RUNTIME_COMPOSE_STATE" "$(status_color_for_value "$SCRIPT66_RUNTIME_COMPOSE_STATE")"
    aligned_status_line "Template" "$(template_display_status)" "$(status_color_for_value "$SCRIPT66_TEMPLATE_INSPECTION")"
    aligned_status_line "Checks" "$(template_checks_display_status)" "$(status_color_for_value "$SCRIPT66_TEMPLATE_INSPECTION")"
    aligned_status_line "Container" "$(container_display_status)" "$(status_color_for_value "$(container_display_status)")"
    aligned_status_line "Route" "$SCRIPT66_ROUTE_STATUS" "$YW"
}

# =========================================================
#  COMPOSE TEMPLATE INSPECTION
# =========================================================
function uncommented_file_content() { sed '/^[[:space:]]*#/d' "$1"; }

function template_check_fixed() {
    local file="$1" literal="$2"
    grep -Fq -- "$literal" "$file"
}

function template_check_regex() {
    local file="$1" pattern="$2"
    grep -Eq -- "$pattern" "$file"
}

function inspect_landing_template() {
    local template_path="" noncomment_file="" failures=() warnings=() networks=""

    if ! template_path="$(landing_template_path)"; then
        SCRIPT66_TEMPLATE_SOURCE="remote-planned"
        SCRIPT66_TEMPLATE_INSPECTION="deferred"
        SCRIPT66_TEMPLATE_CHECK_SUMMARY="deferred"
        return 0
    fi

    SCRIPT66_TEMPLATE_SOURCE="local repo"
    noncomment_file="$(mktemp /tmp/circl8-landing-template-noncomment.XXXXXX)"
    TEMP_FILES+=("$noncomment_file")
    uncommented_file_content "$template_path" > "$noncomment_file"

    template_check_fixed "$template_path" 'image: ${LANDING_IMAGE:-nginx:alpine}' || failures+=("image interpolation missing")
    template_check_fixed "$template_path" 'Host(`${LANDING_HOST}`) || Host(`${LANDING_WWW_HOST}`)' || failures+=("landing Host rule missing expected variables")
    template_check_fixed "$template_path" 'chain-secure@file' || warnings+=("chain-secure@file missing")
    ! template_check_fixed "$template_path" 'chain-authentik@file' || failures+=("chain-authentik@file must not be used")
    ! template_check_regex "$template_path" 'forwardAuth|forwardauth|forward-auth' || failures+=("forward auth reference must not be present")
    ! template_check_regex "$template_path" 'circl8[.]co[.]uk' || failures+=("hardcoded public domain present")
    ! template_check_regex "$noncomment_file" '^[[:space:]]+ports:[[:space:]]*$' || failures+=("host ports present")
    ! template_check_regex "$noncomment_file" 'docker[.]sock|/var/run/docker[.]sock' || failures+=("Docker socket reference present")
    template_check_fixed "$template_path" '${DOCKER_DIR}/appdata/landing:/usr/share/nginx/html:ro' || failures+=("landing appdata read-only volume missing")
    template_check_fixed "$template_path" 'traefik.http.services.circl8-landing.loadbalancer.server.port=80' || failures+=("Traefik service port 80 missing")

    networks="$(awk '
        /^services:[[:space:]]*$/ {in_services=1; svc=""; in_networks=0; next}
        in_services && /^[^[:space:]][A-Za-z0-9_.-]*:/ {in_services=0; svc=""; in_networks=0}
        !in_services {next}
        /^  circl8-landing:[[:space:]]*$/ {svc="circl8-landing"; in_networks=0; next}
        /^  [A-Za-z0-9_.-]+:[[:space:]]*$/ && $1 != "circl8-landing:" {svc=""; in_networks=0; next}
        svc == "circl8-landing" && /^    networks:[[:space:]]*$/ {in_networks=1; next}
        in_networks && /^    [A-Za-z0-9_.-]+:/ {in_networks=0}
        in_networks && /^[[:space:]]*-[[:space:]]*[A-Za-z0-9_.-]+/ {gsub(/^[[:space:]]*-[[:space:]]*/, ""); print}
    ' "$template_path" | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    [ "$networks" = "t2_proxy" ] || failures+=("service must use only t2_proxy network")

    if [ "${#failures[@]}" -gt 0 ]; then
        SCRIPT66_TEMPLATE_INSPECTION="failed"
        SCRIPT66_TEMPLATE_CHECK_SUMMARY="${failures[*]}"
    elif [ "${#warnings[@]}" -gt 0 ]; then
        SCRIPT66_TEMPLATE_INSPECTION="warn"
        SCRIPT66_TEMPLATE_CHECK_SUMMARY="${warnings[*]}"
    else
        SCRIPT66_TEMPLATE_INSPECTION="pass"
        SCRIPT66_TEMPLATE_CHECK_SUMMARY="PASS"
    fi
}

function print_template_inspection() {
    # Template status is intentionally shown in CURRENT STATE to keep Phase 2 UI compact.
    :
}

# =========================================================
#  PLAN / SAFETY / REPORT
# =========================================================
function print_plan() {
    section "LANDING TARGET"
    aligned_status_line "Domain" "$DOMAIN_VALUE" "$GN"
    aligned_status_line "Public URL" "$LANDING_URL" "$GN"
    aligned_status_line "WWW URL" "$LANDING_WWW_URL" "$GN"
    aligned_status_line "Middleware" "chain-secure@file" "$GN"
    aligned_status_line "Auth" "public / no forward-auth" "$GN"
    aligned_status_line "Image env" "$LANDING_IMAGE_ENV_STATUS" "$(status_color_for_value "$LANDING_IMAGE_ENV_STATUS")"
    aligned_status_line "Effective image" "$LANDING_EFFECTIVE_IMAGE" "$GN"
}

function print_copy_source_plan() {
    section "COPY SOURCE PLAN"
    echo -e "${YW}The private Astro landing source stays local/private and is not embedded in this script.${CL}"
    echo ""
    aligned_status_line "Source path" "$LANDING_SOURCE_PATH" "$BL"
    aligned_status_line "Copy target" "$VM_COPY_TARGET" "$(status_color_for_value "$([ "$VM_COPY_TARGET" = "<vm-user>@<vm-ip>" ] && printf deferred || printf detected)")"
    echo ""
    echo -e "${BL}Copy example:${CL}"
    echo -e "  ${GN}scp -r /path/to/circl8_astro/* ${VM_COPY_TARGET}:${LANDING_SOURCE_PATH}/${CL}"
    echo ""
    echo -e "${YW}If you use an SSH alias, you may replace the detected target with that alias.${CL}"
}

function print_safety_summary() {
    section "SAFETY"
    echo -e "${YW}This phase made no deploy, build, copy, directory, container, or .env changes.${CL}"
    aligned_status_line "Final marker" "not written" "$GN"
    aligned_status_line "Authentik writes" "no" "$GN"
}

function decide_preflight_result() {
    SCRIPT66_STATUS="preflight"
    SCRIPT66_DEPLOYMENT="not-run"
    SCRIPT66_HEALTH_STATUS="not-run"
    SCRIPT66_AUTHENTIK_WRITES="no"

    case "$SCRIPT66_TEMPLATE_INSPECTION" in
        failed)
            SCRIPT66_VERIFY_STATUS="FAILED"
            SCRIPT66_READY_FOR_DEPLOY_PHASE="no"
            ;;
        warn)
            SCRIPT66_VERIFY_STATUS="WARN"
            SCRIPT66_READY_FOR_DEPLOY_PHASE="no"
            ;;
        pass|deferred)
            SCRIPT66_VERIFY_STATUS="PASS"
            SCRIPT66_READY_FOR_DEPLOY_PHASE="yes"
            ;;
        *)
            SCRIPT66_VERIFY_STATUS="WARN"
            SCRIPT66_READY_FOR_DEPLOY_PHASE="no"
            ;;
    esac

    if [ "$SCRIPT66_ASTRO_SOURCE_STATUS" = "missing-source" ]; then
        # Missing private source is expected before the manual copy phase and is not a preflight failure.
        :
    elif [ "$SCRIPT66_ASTRO_SOURCE_STATUS" = "incomplete" ]; then
        SCRIPT66_VERIFY_STATUS="WARN"
    fi
}

function write_verify_report() {
    {
        printf '%s\n' "SCRIPT66_STATUS=${SCRIPT66_STATUS}"
        printf '%s\n' "SCRIPT66_VERSION=${SCRIPT_VERSION}"
        printf '%s\n' "SCRIPT66_BUILD=${SCRIPT_BUILD}"
        printf '%s\n' "SCRIPT66_VERIFY_STATUS=${SCRIPT66_VERIFY_STATUS}"
        printf '%s\n' "SCRIPT66_DEPLOYMENT=${SCRIPT66_DEPLOYMENT}"
        printf '%s\n' "SCRIPT66_LANDING_IMAGE_ENV_STATUS=${LANDING_IMAGE_ENV_STATUS}"
        printf '%s\n' "SCRIPT66_LANDING_EFFECTIVE_IMAGE=${LANDING_EFFECTIVE_IMAGE}"
        printf '%s\n' "SCRIPT66_COPY_TARGET=${VM_COPY_TARGET}"
        printf '%s\n' "SCRIPT66_CONTAINERS=${SCRIPT66_CONTAINERS}"
        printf '%s\n' "SCRIPT66_HEALTH_STATUS=${SCRIPT66_HEALTH_STATUS}"
        printf '%s\n' "SCRIPT66_LANDING_HOST=${LANDING_HOST}"
        printf '%s\n' "SCRIPT66_LANDING_WWW_HOST=${LANDING_WWW_HOST}"
        printf '%s\n' "SCRIPT66_LANDING_URL=${LANDING_URL}"
        printf '%s\n' "SCRIPT66_LANDING_WWW_URL=${LANDING_WWW_URL}"
        printf '%s\n' "SCRIPT66_SOURCE_PATH=${LANDING_SOURCE_PATH}"
        printf '%s\n' "SCRIPT66_APPDATA_PATH=${LANDING_APPDATA_PATH}"
        printf '%s\n' "SCRIPT66_BACKUP_PATH=${LANDING_BACKUP_DIR}"
        printf '%s\n' "SCRIPT66_COMPOSE_FILE=${LANDING_RUNTIME_COMPOSE}"
        printf '%s\n' "SCRIPT66_REPO_COMPOSE=${LANDING_REPO_COMPOSE}"
        printf '%s\n' "SCRIPT66_TEMPLATE_SOURCE=${SCRIPT66_TEMPLATE_SOURCE}"
        printf '%s\n' "SCRIPT66_TEMPLATE_INSPECTION=${SCRIPT66_TEMPLATE_INSPECTION}"
        printf '%s\n' "SCRIPT66_TEMPLATE_CHECK_SUMMARY=${SCRIPT66_TEMPLATE_CHECK_SUMMARY}"
        printf '%s\n' "SCRIPT66_ASTRO_SOURCE_STATUS=${SCRIPT66_ASTRO_SOURCE_STATUS}"
        printf '%s\n' "SCRIPT66_ASTRO_PACKAGE_JSON=${SCRIPT66_ASTRO_PACKAGE_JSON}"
        printf '%s\n' "SCRIPT66_ASTRO_CONFIG=${SCRIPT66_ASTRO_CONFIG}"
        printf '%s\n' "SCRIPT66_ASTRO_BUILD_SCRIPT=${SCRIPT66_ASTRO_BUILD_SCRIPT}"
        printf '%s\n' "SCRIPT66_ASTRO_BUILD_STATUS=not-run"
        printf '%s\n' "SCRIPT66_DIST_STATUS=${SCRIPT66_ASTRO_DIST_STATUS}"
        printf '%s\n' "SCRIPT66_APPDATA_STATUS=${SCRIPT66_APPDATA_STATUS}"
        printf '%s\n' "SCRIPT66_APPDATA_INDEX_STATUS=${SCRIPT66_APPDATA_INDEX_STATUS}"
        printf '%s\n' "SCRIPT66_RUNTIME_COMPOSE_STATE=${SCRIPT66_RUNTIME_COMPOSE_STATE}"
        printf '%s\n' "SCRIPT66_RUNTIME_COMPOSE_SYNC_NEEDED=${SCRIPT66_RUNTIME_COMPOSE_SYNC_NEEDED}"
        printf '%s\n' "SCRIPT66_ROUTE_LABELS=${SCRIPT66_ROUTE_LABELS}"
        printf '%s\n' "SCRIPT66_ROUTE_STATUS=${SCRIPT66_ROUTE_STATUS}"
        printf '%s\n' "SCRIPT66_AUTHENTIK_WRITES=no"
        printf '%s\n' "SCRIPT66_FINAL_MARKER_WRITTEN=no"
        printf '%s\n' "SCRIPT66_FINAL_MARKER_PATH=${FINAL_MARKER}"
        printf '%s\n' "SCRIPT66_HANDOFF_GATES=${SCRIPT66_HANDOFF_GATES}"
        printf '%s\n' "SCRIPT65_STATUS=${SCRIPT65_STATUS}"
        printf '%s\n' "SCRIPT65_VERIFY_STATUS=${SCRIPT65_VERIFY_STATUS}"
        printf '%s\n' "SCRIPT65_DEPLOYMENT=${SCRIPT65_DEPLOYMENT}"
        printf '%s\n' "SCRIPT65_READY_FOR_SCRIPT66=${SCRIPT65_READY_FOR_SCRIPT66}"
        printf '%s\n' "SCRIPT66_READY_FOR_DEPLOY_PHASE=${SCRIPT66_READY_FOR_DEPLOY_PHASE}"
    } | write_root_file "$VERIFY_LOG"
}

function print_final_summary() {
    section_flash_success "FINISHED"
    final_line "Verification" "$SCRIPT66_VERIFY_STATUS" "$(status_color_for_value "$SCRIPT66_VERIFY_STATUS")"
    final_line "Ready for source-copy phase" "$SCRIPT66_READY_FOR_DEPLOY_PHASE" "$(status_color_for_value "$SCRIPT66_READY_FOR_DEPLOY_PHASE")"
    final_line "Verify log" "$VERIFY_LOG" "$BL"
}

function init_script() {
    elevate_to_root_if_needed "$@"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    detect_root_or_sudo
    init_logging
    trap 'on_error "$LINENO"' ERR
    trap cleanup EXIT
    clear 2>/dev/null || printf '\033c'
    header_info
    show_script_version
    validate_dependencies
}

function main() {
    init_script "$@"
    validate_handoff_gates
    load_project_context
    detect_docker_access
    print_handoff_summary
    print_plan
    print_landing_state_inspection
    print_copy_source_plan
    print_safety_summary
    decide_preflight_result
    write_verify_report
    print_final_summary
}

main "$@"
