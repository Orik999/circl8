#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Ubuntu Auto Install
# =========================================================

# --- 1. COLOR VARIABLES / VISUAL THEME ---
# Keeps the visual theme centralized so colours can be changed easily later.
YW="$(printf '\033[33m')"
BL="$(printf '\033[36m')"
RD="$(printf '\033[01;31m')"
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
FLASH_ON=$'\033[5m'
FLASH_OFF=$'\033[25m'

BORDER="${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"

SCRIPT_SOURCE="3.5-ubuntuAutoInstallSeed.sh"
SCRIPT_VERSION="v1.2.27"
SCRIPT_UPDATED="2026-06-09"
SCRIPT_BUILD="ubuntu-swap-detect-display"

# --- 2. GLOBAL DEFAULTS ---
# Stores defaults, paths, timeout values and runtime state.
T=15
LOG_FILE="/var/log/ubuntu-autoinstall-seed.log"
VERIFY_LOG="/var/log/ubuntu-autoinstall-seed-verify.log"
COMPLETED_MARKER="/root/.ubuntu-autoinstall-seed-completed"
VM_SIDE_MARKER_PATH="/root/.ubuntu-autoinstall-seed-completed"

DEFAULT_USERNAME="orik"
DEFAULT_TIMEZONE="Europe/London"
DEFAULT_KEYBOARD_LAYOUT="gb"
DEFAULT_KEYBOARD_VARIANT=""
DEFAULT_LOCALE="en_GB.UTF-8"
DEFAULT_ISO_NAME="ubuntu-26.04-live-server-amd64.iso"

DEFAULT_INSTALL_WAIT_MINUTES="30"
INSTALL_WAIT_MINUTES="30"

POST_INSTALL_START_VM="y"
DELETE_GENERATED_ISO_AFTER_INSTALL="y"

SSH_IP_DETECT_TIMEOUT_SECONDS="90"
SSH_IP_CHECK_INTERVAL_SECONDS="3"

ASSIGNED_IPV4=""
SSH_COMMAND=""

TARGET_VMID=""
TARGET_VM_NAME=""
TARGET_VM_STATUS=""
VM_STATUS_AT_PREFLIGHT="unknown"
VM_SHUTDOWN_APPROVED="not-needed"
ATTACH_START_APPROVED="unset"
TARGET_VM_MAC=""
TARGET_USERNAME=""
TARGET_TIMEZONE=""
TARGET_KEYBOARD_LAYOUT=""
TARGET_KEYBOARD_VARIANT=""
TARGET_LOCALE=""
TARGET_HOSTNAME=""

INSTALL_ISO_PATH=""
INSTALL_ISO_REF=""

AUTOINSTALL_ISO_NAME=""
AUTOINSTALL_ISO_PATH=""
AUTOINSTALL_ISO_REF=""
WORK_DIR=""

SSH_KEYS=""
KEY_SOURCE=""
SSH_KEYS_YAML=""
VERIFIER_B64=""
VM_MARKER_B64=""
RANDOM_PASSWORD_HASH=""

NETWORK_MODE="dhcp"
STATIC_IP_CIDR=""
STATIC_GATEWAY=""
STATIC_DNS="1.1.1.1,1.0.0.1"

INSTALL_POWERED_OFF="no"
INSTALL_DURATION_SECONDS=""
INSTALL_DURATION_TEXT=""
INSTALLED_VM_STARTED_STATUS=""
QEMU_IPV4_STATUS=""
HOST_VERIFICATION_STATUS=""
VM_SIDE_MARKER_UPDATE_STATUS="not-run"
VM_SWAP_STATUS="unknown"
VM_SWAP_FILE="unknown"
VM_SWAP_SIZE="unknown"
VM_SWAP_TYPE="unknown"

CLEANUP_INSTALLED_TOOLS="yes"
CLEANUP_TEMP_WORKFILES="yes"
ISO_TOOL_CLEANUP_DONE="no"
TEMP_WORKSPACE_CLEANUP_DONE="no"
INSTALLED_TOOL_PACKAGES=()
ISO_CLEANUP_TOOL_PACKAGES=(xorriso p7zip-full)
TEMP_FILES=()

REUSE_EXISTING_AUTOINSTALL_ISO="no"
GENERATED_ISO_EXISTS="no"
GENERATED_ISO_ACTION="create"
TOOLS_CHECKED="no"
MISSING_TOOL_PACKAGES=()
INSTALL_MISSING_TOOLS_APPROVED="not-needed"
ISO_PREP_GROUPED_OUTPUT="no"
SCRIPT35_UI_DEMO_ACTIVE="no"

BOOT_PARAM='autoinstall ds=nocloud\;s=/cdrom/nocloud/ subiquity.autoinstallpath=cdrom/autoinstall.yaml'

PROXMOX_HOSTNAME=""
PROXMOX_FQDN=""
PROXMOX_DOMAIN=""
PROXMOX_LAN_IP=""
PROXMOX_LAN_URL=""

TIMED_CONFIRM_OUTPUT="yes"

# =========================================================
#  OUTPUT / LOGGING FUNCTIONS
# =========================================================

# --- 3. HEADER FUNCTION ---
# Displays a clear script banner. Intentionally says AUTO INSTALL, not just AUTO.
header_info() {
    echo -e "${BL}
██╗   ██╗██████╗ ██╗   ██╗███╗   ██╗████████╗██╗   ██╗     █████╗ ██╗   ██╗████████╗ ██████╗     ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     
██║   ██║██╔══██╗██║   ██║████╗  ██║╚══██╔══╝██║   ██║    ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     
██║   ██║██████╔╝██║   ██║██╔██╗ ██║   ██║   ██║   ██║    ███████║██║   ██║   ██║   ██║   ██║    ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     
██║   ██║██╔══██╗██║   ██║██║╚██╗██║   ██║   ██║   ██║    ██╔══██║██║   ██║   ██║   ██║   ██║    ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     
╚██████╔╝██████╔╝╚██████╔╝██║ ╚████║   ██║   ╚██████╔╝    ██║  ██║╚██████╔╝   ██║   ╚██████╔╝    ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
 ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝   ╚═╝    ╚═════╝     ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝     ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝
${CL}"
}

# --- 4. MESSAGE HELPERS ---
# Provides consistent Success / Warning / Error prefixes.
msg_info() { echo -ne " ${HOLD} ${YW}$1...${CL}"; }
msg_ok() { echo -e "${BFR} ${CM} ${GN}$1${CL}"; }
msg_warn() { echo -e "${BFR} ${WARN} ${YW}$1${CL}"; }
msg_error() { echo -e "${BFR} ${CROSS} ${RD}$1${CL}"; exit 1; }

# --- SCRIPT VERSION DISPLAY ---
# Prints the currently running script version immediately under the ASCII banner.
function show_script_version() {
    echo -e "${GN}SCRIPT VERSION: ${SCRIPT_VERSION} | UPDATED: ${SCRIPT_UPDATED} | BUILD: ${SCRIPT_BUILD}${CL}"
    echo -e "${BL}SOURCE: ${SCRIPT_SOURCE}${CL}"
}

section() {
    echo ""
    echo -e "${BORDER}"
    echo -e "${BL}$1${CL}"
    echo -e "${BORDER}"
}

section_flash_success() {
    echo ""
    echo -e "${BORDER}"
    echo -e "${GN}${CLF}$1${CL}"
    echo -e "${BORDER}"
}

ui_line() {
    local label="$1"
    local value="${2:-}"
    local color="${3:-$GN}"
    local width="${4:-18}"

    if [ -n "$value" ]; then
        printf "  ${BL}%-${width}s${CL} ${color}%s${CL}\n" "${label}:" "$value"
    else
        printf "  ${GN}%s${CL}\n" "$label"
    fi
}

status_line() {
    ui_line "$1" "${2:-}" "${3:-$GN}" "${4:-18}"
}

answer_line() {
    ui_line "$1" "${2:-}" "$ANS" "${3:-18}"
}

group_heading() {
    echo -e "${YW}$1:${CL}"
}

group_status_line() {
    status_line "$1" "${2:-}" "${3:-$GN}" "${4:-24}"
}

group_answer_line() {
    answer_line "$1" "${2:-}" "${3:-24}"
}

clear_terminal_lines() {
    local count="${1:-0}"

    [ "$count" -gt 0 ] || return 0
    tty_print "\033[${count}A\033[J"
}

detail_line() {
    if [ "$#" -ge 2 ]; then
        status_line "$1" "$2"
    else
        status_line "$1"
    fi
}

# --- 5. TTY PRINT HELPERS ---
# Prints directly to terminal even when functions return values through stdout.
tty_print() {
    if [ -w /dev/tty ]; then
        echo -ne "$*" > /dev/tty
    else
        echo -ne "$*" >&2
    fi
}

tty_println() {
    if [ -w /dev/tty ]; then
        echo -e "$*" > /dev/tty
    else
        echo -e "$*" >&2
    fi
}

# =========================================================
#  CLEANUP / ERROR HANDLING
# =========================================================

# --- 6. CLEANUP FUNCTION ---
# Cleans temporary working files and optionally removes ISO-generation-only tools.
cleanup_temp_workspace_runtime() {
    if [ "$CLEANUP_TEMP_WORKFILES" == "yes" ] && [ "${DEBUG_KEEP_WORKDIR:-0}" != "1" ] && [ -n "${WORK_DIR:-}" ] && [ -d "$WORK_DIR" ]; then
        rm -rf "$WORK_DIR" 2>/dev/null || true
        TEMP_WORKSPACE_CLEANUP_DONE="yes"
        msg_ok "Temporary workspace removed."
    elif [ -n "${WORK_DIR:-}" ] && [ -d "$WORK_DIR" ]; then
        TEMP_WORKSPACE_CLEANUP_DONE="yes"
        msg_ok "Temporary workspace kept by user choice: ${WORK_DIR}"
    else
        TEMP_WORKSPACE_CLEANUP_DONE="yes"
        msg_ok "Temporary workspace already absent."
    fi
}

cleanup_iso_generation_tools_runtime() {
    local pkg=""
    local removed=()
    local absent=()
    local failed=()

    if [ "$CLEANUP_INSTALLED_TOOLS" != "yes" ]; then
        ISO_TOOL_CLEANUP_DONE="yes"
        msg_ok "ISO generation tools kept by user choice."
        return 0
    fi

    for pkg in "${ISO_CLEANUP_TOOL_PACKAGES[@]}"; do
        [ -z "$pkg" ] && continue

        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            absent+=("$pkg")
            continue
        fi

        if DEBIAN_FRONTEND=noninteractive apt-get purge -y "$pkg" >/dev/null 2>&1; then
            if dpkg -s "$pkg" >/dev/null 2>&1; then
                failed+=("$pkg")
            else
                removed+=("$pkg")
            fi
        else
            failed+=("$pkg")
        fi
    done

    if ! DEBIAN_FRONTEND=noninteractive apt-get autoremove -y >/dev/null 2>&1; then
        msg_warn "apt autoremove failed during ISO tool cleanup; review manually if needed."
    fi

    ISO_TOOL_CLEANUP_DONE="yes"

    if [ "${#removed[@]}" -gt 0 ]; then
        msg_ok "ISO generation tools removed: ${removed[*]}"
    fi

    if [ "${#absent[@]}" -gt 0 ]; then
        msg_ok "ISO generation tools already absent: ${absent[*]}"
    fi

    if [ "${#failed[@]}" -gt 0 ]; then
        msg_warn "ISO generation tools failed to remove: ${failed[*]}"
    fi
}

cleanup() {
    local exit_code="$?"
    local file=""

    # Always remove small internal temporary files such as captured stderr logs.
    # The larger ISO build workspace is controlled separately by CLEANUP_TEMP_WORKFILES.
    for file in "${TEMP_FILES[@]:-}"; do
        if [ -n "$file" ] && [ -e "$file" ]; then
            if [ -n "${WORK_DIR:-}" ] && [ "$file" == "$WORK_DIR" ]; then
                continue
            fi
            rm -rf "$file" 2>/dev/null || true
        fi
    done

    if [ "$TEMP_WORKSPACE_CLEANUP_DONE" != "yes" ]; then
        if [ "$CLEANUP_TEMP_WORKFILES" == "yes" ] && [ "${DEBUG_KEEP_WORKDIR:-0}" != "1" ] && [ -n "${WORK_DIR:-}" ] && [ -d "$WORK_DIR" ]; then
            rm -rf "$WORK_DIR" 2>/dev/null || true
        elif [ -n "${WORK_DIR:-}" ] && [ -d "$WORK_DIR" ]; then
            echo ""
            echo -e "${YW}Temporary ISO workspace kept for inspection:${CL} ${GN}${WORK_DIR}${CL}"
        fi
    fi

    if [ "$ISO_TOOL_CLEANUP_DONE" != "yes" ] && [ "$CLEANUP_INSTALLED_TOOLS" == "yes" ]; then
        echo ""
        echo -e "${YW}Cleaning up ISO generation tools...${CL}"
        cleanup_iso_generation_tools_runtime
    fi

    exit "$exit_code"
}

# --- 7. ERROR TRAP ---
# Reports failing line while preserving normal cleanup.
on_error() {
    local line_no="$1"
    echo -e "${RD}ERROR:${CL} Script failed at line ${line_no}. Check ${LOG_FILE}"
}

# --- 8. COMMAND RUNNER ---
# Runs critical commands quietly but shows real stderr if they fail.
run_cmd() {
    local description="$1"
    shift

    local err_file=""
    err_file="$(mktemp)"
    TEMP_FILES+=("$err_file")

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

    rm -f "$err_file"
}

# --- 9. OPTIONAL COMMAND RUNNER ---
# Runs non-critical commands quietly and does not stop the script.
run_optional() {
    "$@" >/dev/null 2>&1 || true
}

# =========================================================
#  INPUT FUNCTIONS
# =========================================================

# --- 10. YES/NO LABEL HELPER ---
yes_no_label() {
    local value="$1"

    if [[ "$value" =~ ^[Yy]$ ]]; then
        echo "yes"
    else
        echo "no"
    fi
}

# --- 11. BLOCKING YES/NO HELPER ---
# Used after SPACE is pressed during a timed Y/n prompt.
tty_read_yes_no_blocking() {
    local prompt="$1"
    local default="$2"
    local default_label="Y/n"
    local key=""

    if [[ "$default" =~ ^[Nn]$ ]]; then
        default_label="y/N"
    fi

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
            return 0
        elif [[ "$key" =~ ^[YyNn]$ ]]; then
            tty_print "${BFR}"
            echo "$key"
            return 0
        fi
    done
}

# --- 12. TIMED YES/NO PROMPT HELPER ---
# Uses wall-clock countdown. SPACE pauses. Timeout accepts default.
timed_yes_no() {
    local prompt="$1"
    local default="$2"
    local answer=""
    local key=""
    local default_label="Y/n"
    local final_label=""
    local confirm_label=""
    local confirm_label_override="${3:-}"
    local yes_confirm_value="${4:-}"
    local no_confirm_value="${5:-}"
    local deadline=""
    local now=""
    local remaining=""

    if [[ "$default" =~ ^[Nn]$ ]]; then
        default_label="y/N"
    fi

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
    confirm_label="${confirm_label_override:-${prompt%\?}}"

    if [[ "$answer" =~ ^[Yy]$ ]] && [ -n "$yes_confirm_value" ]; then
        final_label="$yes_confirm_value"
    elif [[ "$answer" =~ ^[Nn]$ ]] && [ -n "$no_confirm_value" ]; then
        final_label="$no_confirm_value"
    fi

    tty_print "${BFR}"
    if [ "${TIMED_CONFIRM_OUTPUT:-yes}" == "yes" ]; then
        tty_println "${CM} ${BL}${confirm_label}:${CL} ${ANS}${final_label}${CL}"
    fi

    echo "$answer"
}

# --- 13. NUMERIC VALIDATION HELPER ---
validate_number() {
    local value="$1"
    local min_value="${2:-1}"
    local max_value="${3:-}"

    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if [ "$value" -lt "$min_value" ]; then
        return 1
    fi

    if [ -n "$max_value" ] && [ "$value" -gt "$max_value" ]; then
        return 1
    fi

    return 0
}

print_number_error() {
    local min_value="${1:-1}"
    local max_value="${2:-}"

    if [ -n "$max_value" ]; then
        tty_println "${RD}Invalid input. Enter numbers only between ${min_value} and ${max_value}.${CL}"
    else
        tty_println "${RD}Invalid input. Enter numbers only. Minimum value is ${min_value}.${CL}"
    fi
}

# --- 14. EDITABLE INPUT LOOP HELPER ---
editable_input_loop() {
    local prompt="$1"
    local default="$2"
    local numeric_only="${3:-no}"
    local min_value="${4:-1}"
    local max_value="${5:-}"
    local initial_value="${6:-}"
    local answer="$initial_value"
    local key=""

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

                if [ "$numeric_only" == "yes" ]; then
                    if validate_number "$answer" "$min_value" "$max_value"; then
                        tty_print "${BFR}"
                        echo "$answer"
                        return 0
                    fi

                    tty_print "${BFR}"
                    print_number_error "$min_value" "$max_value"
                    answer=""
                else
                    tty_print "${BFR}"
                    echo "$answer"
                    return 0
                fi
                ;;
            $'\177'|$'\b')
                answer="${answer%?}"
                ;;
            *)
                if [ "$numeric_only" == "yes" ]; then
                    if [[ "$key" =~ ^[0-9]$ ]]; then
                        answer+="$key"
                    else
                        tty_print "${BFR}"
                        print_number_error "$min_value" "$max_value"
                        answer=""
                    fi
                else
                    answer+="$key"
                fi
                ;;
        esac
    done
}

# --- 15. TIMED TEXT INPUT HELPER ---
function timed_text_input() {
    local prompt="$1"
    local default="$2"
    local answer=""
    local confirm_label=""

    # Text/path/name inputs are deliberately NOT timed.
    # Countdown prompts are reserved only for simple Y/n decisions.
    # This prevents defaults being accepted while the user is away and gives enough time to type/paste.
    answer="$(editable_input_loop "$prompt" "$default" "no" "1" "" "")"
    [ -z "$answer" ] && answer="$default"

    confirm_label="${prompt%\?}"

    tty_print "${BFR}"
    if [ "${TIMED_CONFIRM_OUTPUT:-yes}" == "yes" ]; then
        tty_println "${CM} ${BL}${confirm_label}:${CL} ${ANS}${answer}${CL}"
    fi

    echo "$answer"
}

# --- 16. TIMED NUMERIC INPUT HELPER ---
function timed_number_input() {
    local prompt="$1"
    local default="$2"
    local min_value="${3:-1}"
    local max_value="${4:-}"
    local answer=""
    local confirm_label=""

    # Numeric inputs are deliberately NOT timed.
    # Countdown prompts are reserved only for simple Y/n decisions.
    while true; do
        answer="$(editable_input_loop "$prompt" "$default" "yes" "$min_value" "$max_value" "")"
        [ -z "$answer" ] && answer="$default"

        if validate_number "$answer" "$min_value" "$max_value"; then
            confirm_label="${prompt%\?}"

            tty_print "${BFR}"
            if [ "${TIMED_CONFIRM_OUTPUT:-yes}" == "yes" ]; then
                tty_println "${CM} ${BL}${confirm_label}:${CL} ${ANS}${answer}${CL}"
            fi
            echo "$answer"
            return 0
        fi

        tty_print "${BFR}"
        print_number_error "$min_value" "$max_value"
    done
}

timed_yes_no_quiet() {
    local previous_confirm="${TIMED_CONFIRM_OUTPUT:-yes}"
    local result=""

    TIMED_CONFIRM_OUTPUT="no"
    result="$(timed_yes_no "$@")"
    TIMED_CONFIRM_OUTPUT="$previous_confirm"
    echo "$result"
}

timed_text_input_quiet() {
    local previous_confirm="${TIMED_CONFIRM_OUTPUT:-yes}"
    local result=""

    TIMED_CONFIRM_OUTPUT="no"
    result="$(timed_text_input "$@")"
    TIMED_CONFIRM_OUTPUT="$previous_confirm"
    echo "$result"
}

timed_number_input_quiet() {
    local previous_confirm="${TIMED_CONFIRM_OUTPUT:-yes}"
    local result=""

    TIMED_CONFIRM_OUTPUT="no"
    result="$(timed_number_input "$@")"
    TIMED_CONFIRM_OUTPUT="$previous_confirm"
    echo "$result"
}

# --- 17. MENU SELECTION HELPER ---
timed_menu_select() {
    local title="$1"
    local default_index="$2"
    shift 2
    local options=("$@")
    local idx=""
    local selected=""
    local display_title="${title} options"

    if [ "$title" == "Keyboard Layout" ]; then
        display_title="Keyboard layout options"
    fi

    tty_println ""
    tty_println "${YW}${display_title}:${CL}"

    for i in "${!options[@]}"; do
        tty_println "  ${GN}$((i+1))) ${options[$i]}${CL}"
    done

    idx="$(timed_number_input_quiet "Select ${title} option number" "$default_index" "1" "${#options[@]}")"
    clear_terminal_lines "$(( ${#options[@]} + 2 ))"
    selected="${options[$((idx-1))]}"

    echo "$selected"
}

# =========================================================
#  VALIDATION HELPERS
# =========================================================

# --- 18. UBUNTU USERNAME VALIDATOR ---
# Linux username rule: starts with lowercase letter or underscore, then lowercase letters, numbers, underscore or hyphen.
validate_linux_username() {
    local username="$1"

    if [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        return 0
    fi

    return 1
}

# --- 19. IPV4 VALIDATOR ---
# Validates dotted IPv4 address and octet range.
validate_ipv4() {
    local ip="$1"
    local a=""
    local b=""
    local c=""
    local d=""

    if ! [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 1
    fi

    IFS='.' read -r a b c d <<< "$ip"

    for octet in "$a" "$b" "$c" "$d"; do
        if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
            return 1
        fi
    done

    return 0
}

# --- 20. IPV4 CIDR VALIDATOR ---
# Validates IPv4/CIDR format, for example 192.168.1.50/24.
validate_ipv4_cidr() {
    local value="$1"
    local ip=""
    local prefix=""

    if ! [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 1
    fi

    ip="${value%/*}"
    prefix="${value#*/}"

    validate_ipv4 "$ip" || return 1

    if [ "$prefix" -lt 1 ] || [ "$prefix" -gt 32 ]; then
        return 1
    fi

    return 0
}

# --- 21. DNS LIST VALIDATOR ---
# Validates comma-separated IPv4 DNS server list.
validate_dns_list() {
    local value="$1"
    local dns=""

    [ -z "$value" ] && return 1

    IFS=',' read -ra DNS_CHECK_ARRAY <<< "$value"

    for dns in "${DNS_CHECK_ARRAY[@]}"; do
        dns="$(echo "$dns" | xargs)"
        validate_ipv4 "$dns" || return 1
    done

    return 0
}

validate_hostname_label() {
    local value="${1:-}"

    [[ "$value" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] || return 1
    [[ "$value" != localhost ]] || return 1

    return 0
}

validate_fqdn() {
    local value="${1:-}"
    local first_label=""

    [[ "$value" == *.* ]] || return 1
    [[ "$value" != localhost.* ]] || return 1
    [[ "$value" != *.localdomain ]] || return 1

    first_label="${value%%.*}"
    validate_hostname_label "$first_label" || return 1
    [[ "$value" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]] || return 1

    return 0
}

fqdn_matches_short_hostname() {
    local fqdn="${1:-}"
    local short="${2:-}"

    [ -n "$short" ] || return 1
    [ "${fqdn%%.*}" == "$short" ] || return 1

    return 0
}

is_rfc1918_ipv4() {
    local ip="${1:-}"
    local second=""

    validate_ipv4 "$ip" || return 1

    case "$ip" in
        10.*|192.168.*) return 0 ;;
    esac

    if [[ "$ip" =~ ^172\.([0-9]{1,3})\. ]]; then
        second="${BASH_REMATCH[1]}"
        [ "$second" -ge 16 ] && [ "$second" -le 31 ] && return 0
    fi

    return 1
}

# =========================================================
#  GENERAL HELPERS
# =========================================================

# --- 22. YAML QUOTE HELPER ---
yaml_quote() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
}

marker_kv_quote() {
    local value="${1:-}"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '\"%s\"' "$value"
}
build_vm_side_marker_payload() {
    local assigned_ipv4="${ASSIGNED_IPV4:-not-detected}"

    [ -n "$assigned_ipv4" ] || assigned_ipv4="not-detected"

    cat <<EOF
SCRIPT35_STATUS=completed
SCRIPT35_VERSION=$(marker_kv_quote "$SCRIPT_VERSION")
SCRIPT35_BUILD=$(marker_kv_quote "$SCRIPT_BUILD")
SCRIPT35_MARKER_SCOPE=vm
SCRIPT35_MARKER_SOURCE=$(marker_kv_quote "$SCRIPT_SOURCE")
SCRIPT35_VM_HOSTNAME=$(marker_kv_quote "$TARGET_HOSTNAME")
SCRIPT35_VM_USERNAME=$(marker_kv_quote "$TARGET_USERNAME")
SCRIPT35_VM_NETWORK_MODE=$(marker_kv_quote "$NETWORK_MODE")
SCRIPT35_VM_ASSIGNED_IPV4=$(marker_kv_quote "$assigned_ipv4")
SCRIPT35_VM_MAC=$(marker_kv_quote "$TARGET_VM_MAC")
SCRIPT35_VM_SWAP_STATUS=$(marker_kv_quote "$VM_SWAP_STATUS")
SCRIPT35_VM_SWAP_FILE=$(marker_kv_quote "$VM_SWAP_FILE")
SCRIPT35_VM_SWAP_SIZE=$(marker_kv_quote "$VM_SWAP_SIZE")
SCRIPT35_VM_SWAP_TYPE=$(marker_kv_quote "$VM_SWAP_TYPE")
PROXMOX_HOSTNAME=$(marker_kv_quote "$PROXMOX_HOSTNAME")
PROXMOX_FQDN=$(marker_kv_quote "$PROXMOX_FQDN")
PROXMOX_DOMAIN=$(marker_kv_quote "$PROXMOX_DOMAIN")
PROXMOX_LAN_IP=$(marker_kv_quote "$PROXMOX_LAN_IP")
PROXMOX_LAN_URL=$(marker_kv_quote "$PROXMOX_LAN_URL")
EOF
}

build_vm_side_marker_base64() {
    local marker_file="$1"

    build_vm_side_marker_payload > "$marker_file"
    base64 -w0 "$marker_file"
}

wait_for_vm_ssh_ready() {
    local deadline=""
    local now=""

    [ -n "${ASSIGNED_IPV4:-}" ] || return 1
    [ -n "${TARGET_USERNAME:-}" ] || return 1

    deadline=$(( $(date +%s) + SSH_IP_DETECT_TIMEOUT_SECONDS ))

    while true; do
        if ssh \
            -o BatchMode=yes \
            -o ConnectTimeout=5 \
            -o StrictHostKeyChecking=accept-new \
            -o UserKnownHostsFile=/root/.ssh/known_hosts \
            "${TARGET_USERNAME}@${ASSIGNED_IPV4}" \
            "true" >/dev/null 2>&1; then
            return 0
        fi

        now=$(date +%s)
        [ "$now" -ge "$deadline" ] && return 1
        sleep "$SSH_IP_CHECK_INTERVAL_SECONDS"
    done
}

detect_vm_swap_readonly() {
    local probe=""
    local status="unknown"
    local file="unknown"
    local size="unknown"
    local type="unknown"

    VM_SWAP_STATUS="unknown"
    VM_SWAP_FILE="unknown"
    VM_SWAP_SIZE="unknown"
    VM_SWAP_TYPE="unknown"

    [ -n "${ASSIGNED_IPV4:-}" ] || return 0
    [ -n "${TARGET_USERNAME:-}" ] || return 0

    msg_info "Detecting Ubuntu swap"

    probe="$(ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/root/.ssh/known_hosts \
        "${TARGET_USERNAME}@${ASSIGNED_IPV4}" \
        "bash -s" <<'SWAP_DETECT_EOF' 2>/dev/null | head -n1 || true
swap_line="$(swapon --show --noheadings --raw --output=NAME,TYPE,SIZE 2>/dev/null | awk 'NF >= 3 {print; exit}' || true)"
proc_line="$(awk 'NR > 1 {print; exit}' /proc/swaps 2>/dev/null || true)"
fstab_line="$(grep -E '^[^#].*[[:space:]]swap[[:space:]]' /etc/fstab 2>/dev/null | head -n1 || true)"

if [ -n "$swap_line" ]; then
    set -- $swap_line
    printf 'detected|%s|%s|%s\n' "${1:-unknown}" "${3:-unknown}" "${2:-unknown}"
elif [ -n "$proc_line" ]; then
    set -- $proc_line
    printf 'detected|%s|%s|%s\n' "${1:-unknown}" "${3:-unknown}" "${2:-unknown}"
elif [ -n "$fstab_line" ]; then
    set -- $fstab_line
    printf 'not-detected|%s|unknown|fstab-only\n' "${1:-unknown}"
else
    printf 'not-detected|unknown|unknown|unknown\n'
fi
SWAP_DETECT_EOF
)"

    if [ -z "$probe" ]; then
        msg_warn "Ubuntu swap detection skipped; SSH not ready."
        return 0
    fi

    IFS='|' read -r status file size type <<< "$probe"

    case "$status" in
        detected|not-detected|unknown) VM_SWAP_STATUS="$status" ;;
        *) VM_SWAP_STATUS="unknown" ;;
    esac

    VM_SWAP_FILE="$(swap_value_or_unknown "$file")"
    VM_SWAP_SIZE="$(swap_value_or_unknown "$size")"
    VM_SWAP_TYPE="$(swap_value_or_unknown "$type")"

    if [ "$VM_SWAP_STATUS" == "detected" ]; then
        msg_ok "Ubuntu swap detected: ${VM_SWAP_FILE} (${VM_SWAP_SIZE}, ${VM_SWAP_TYPE})."
    elif [ "$VM_SWAP_STATUS" == "not-detected" ]; then
        msg_warn "Ubuntu swap not detected."
    else
        msg_warn "Ubuntu swap detection status unknown."
    fi
}

update_vm_side_marker_assigned_ipv4() {
    local marker_file=""
    local marker_b64=""

    if [ -z "${ASSIGNED_IPV4:-}" ]; then
        VM_SIDE_MARKER_UPDATE_STATUS="skipped-no-ip"
        return 0
    fi

    if ! wait_for_vm_ssh_ready; then
        VM_SIDE_MARKER_UPDATE_STATUS="ssh-not-ready"
        msg_warn "VM-side marker IPv4 update skipped; SSH not ready."
        return 0
    fi

    detect_vm_swap_readonly

    msg_info "Updating VM-side marker assigned IPv4"

    marker_file="$(mktemp)"
    TEMP_FILES+=("$marker_file")
    marker_b64="$(build_vm_side_marker_base64 "$marker_file")"

    if printf '%s' "$marker_b64" | ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=10 \
        -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/root/.ssh/known_hosts \
        "${TARGET_USERNAME}@${ASSIGNED_IPV4}" \
        "sudo -n sh -c 'base64 -d > ${VM_SIDE_MARKER_PATH} && chmod 0600 ${VM_SIDE_MARKER_PATH}'" >/dev/null 2>&1; then
        VM_SIDE_MARKER_UPDATE_STATUS="yes"
        msg_ok "VM-side marker assigned IPv4 updated."
    else
        VM_SIDE_MARKER_UPDATE_STATUS="failed"
        msg_warn "VM-side marker IPv4 update failed; update manually if needed."
    fi
}

# --- 23. SAFE HOSTNAME HELPER ---
safe_hostname() {
    local value="$1"

    value="$(echo "$value" | tr '[:upper:]' '[:lower:]')"
    value="$(echo "$value" | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"

    if [ -z "$value" ]; then
        value="ubuntu-vm"
    fi

    echo "$value"
}

proxmox_identity_value_or_not_detected() {
    local value="${1:-}"

    [ -n "$value" ] && printf '%s' "$value" || printf 'not detected'
}

discover_proxmox_short_hostname() {
    local value=""

    if command -v hostname >/dev/null 2>&1; then
        value="$(hostname -s 2>/dev/null | head -n1 | xargs || true)"
    fi

    if ! validate_hostname_label "$value" && command -v hostnamectl >/dev/null 2>&1; then
        value="$(hostnamectl --static 2>/dev/null | head -n1 | xargs || true)"
    fi

    if ! validate_hostname_label "$value" && [ -r /etc/hostname ]; then
        value="$(head -n1 /etc/hostname 2>/dev/null | xargs || true)"
    fi

    if validate_hostname_label "$value"; then
        printf '%s' "$value"
    else
        printf ''
    fi
}

discover_proxmox_fqdn_from_hosts() {
    local short_hostname="${1:-}"
    local value=""

    [ -n "$short_hostname" ] || { printf ''; return 0; }
    [ -r /etc/hosts ] || { printf ''; return 0; }

    value="$(awk -v short="$short_hostname" '
        $1 !~ /^#/ {
            found_short=0
            found_fqdn=""
            for (i=2; i<=NF; i++) {
                if ($i == short) found_short=1
                if ($i ~ /^[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$/ && $i !~ /^localhost[.]/) found_fqdn=$i
            }
            if (found_short && found_fqdn != "") { print found_fqdn; exit }
        }
    ' /etc/hosts 2>/dev/null | head -n1 | xargs || true)"

    if validate_fqdn "$value" && fqdn_matches_short_hostname "$value" "$short_hostname"; then
        printf '%s' "$value"
    else
        printf ''
    fi
}

discover_proxmox_fqdn() {
    local short_hostname="${1:-}"
    local value=""

    if command -v hostname >/dev/null 2>&1; then
        value="$(hostname -f 2>/dev/null | head -n1 | xargs || true)"
    fi

    if validate_fqdn "$value" && fqdn_matches_short_hostname "$value" "$short_hostname"; then
        printf '%s' "$value"
        return 0
    fi

    discover_proxmox_fqdn_from_hosts "$short_hostname"
}

derive_domain_from_fqdn() {
    local fqdn="${1:-}"

    if validate_fqdn "$fqdn"; then
        printf '%s' "${fqdn#*.}"
    else
        printf ''
    fi
}

detect_proxmox_lan_ip() {
    local ip=""
    local candidate=""

    if command -v ip >/dev/null 2>&1; then
        ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}' | xargs || true)"
        if is_rfc1918_ipv4 "$ip"; then
            printf '%s' "$ip"
            return 0
        fi
    fi

    if command -v hostname >/dev/null 2>&1; then
        while IFS= read -r candidate; do
            if is_rfc1918_ipv4 "$candidate"; then
                printf '%s' "$candidate"
                return 0
            fi
        done < <(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || true)
    fi

    printf ''
}

discover_proxmox_identity() {
    PROXMOX_HOSTNAME="$(discover_proxmox_short_hostname)"
    PROXMOX_FQDN="$(discover_proxmox_fqdn "$PROXMOX_HOSTNAME")"
    PROXMOX_DOMAIN="$(derive_domain_from_fqdn "$PROXMOX_FQDN")"
    PROXMOX_LAN_IP="$(detect_proxmox_lan_ip)"

    if [ -n "$PROXMOX_LAN_IP" ]; then
        PROXMOX_LAN_URL="https://${PROXMOX_LAN_IP}:8006"
    else
        PROXMOX_LAN_URL=""
    fi
}

show_proxmox_identity_summary() {
    echo -e "${YW}Proxmox identity:${CL}"
    status_line "Hostname" "$(proxmox_identity_value_or_not_detected "$PROXMOX_HOSTNAME")" "$GN" 18
    status_line "FQDN" "$(proxmox_identity_value_or_not_detected "$PROXMOX_FQDN")" "$GN" 18
    status_line "Domain" "$(proxmox_identity_value_or_not_detected "$PROXMOX_DOMAIN")" "$GN" 18
    status_line "LAN URL" "$(proxmox_identity_value_or_not_detected "$PROXMOX_LAN_URL")" "$GN" 18
}

# --- 23A. YES/NO DISPLAY HELPER ---
# Converts internal y/n-style flags into user-facing yes/no text.
yn_word() {
    local value="${1:-}"

    if [[ "$value" =~ ^([Yy]|yes|YES|true|TRUE|1)$ ]]; then
        echo "yes"
    else
        echo "no"
    fi
}


display_iso_ref() {
    local value="${1:-}"

    value="${value#local:iso/}"
    value="${value##*/}"

    printf '%s' "$value"
}

swap_value_or_unknown() {
    local value="${1:-unknown}"

    [ -n "$value" ] && printf '%s' "$value" || printf 'unknown'
}

# Extracts the first IPv4 from possibly polluted multiline text.
extract_first_ipv4() {
    printf '%s
' "$*" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1 || true
}

# Extracts the first clean SSH command with an IPv4 target from possibly polluted text.
extract_first_ssh_command() {
    printf '%s
' "$*" | grep -Eo 'ssh[[:space:]]+[^[:space:]]+@([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1 || true
}

# Reads a single known marker value line without allowing multiline pollution into UI output.
marker_value() {
    local label="$1"
    local file="$2"

    awk -F': ' -v label="$label" '$1 == label { $1=""; sub(/^: /, ""); print; exit }' "$file" 2>/dev/null | xargs || true
}

marker_value_or_default() {
    local label="$1"
    local file="$2"
    local default="${3:-unknown}"
    local value=""

    value="$(marker_value "$label" "$file")"
    [ -n "$value" ] || value="$default"

    echo "$value"
}

marker_yn_value_or_unknown() {
    local label="$1"
    local file="$2"
    local value=""

    value="$(marker_value "$label" "$file")"
    [ -n "$value" ] || { echo "unknown"; return 0; }

    yn_word "$value"
}

previous_marker_line() {
    local label="$1"
    local value="${2:-unknown}"
    status_line "$label" "${value:-unknown}" "$GN" 22
}

show_previous_marker_summary() {
    local marker="$1"
    local completed="" vmid="" vm_name="" vm_mac="" username=""
    local assigned_ipv4="" ssh_command="" raw_ssh=""
    local generated_deleted="" installed_started="" tools_cleanup_enabled=""
    local tools_cleanup_done="" temp_cleanup=""
    local vm_swap_status="" vm_swap_file="" vm_swap_size="" vm_swap_type=""

    completed="$(marker_value_or_default "Ubuntu Auto Install completed on" "$marker" "unknown")"
    vmid="$(marker_value_or_default "VMID" "$marker" "unknown")"
    vm_name="$(marker_value_or_default "VM Name" "$marker" "unknown")"
    vm_mac="$(marker_value_or_default "VM MAC" "$marker" "unknown")"
    username="$(marker_value "Username" "$marker")"
    assigned_ipv4="$(extract_first_ipv4 "$(cat "$marker" 2>/dev/null || true)")"
    raw_ssh="$(cat "$marker" 2>/dev/null || true)"
    ssh_command="$(extract_first_ssh_command "$raw_ssh")"

    if [ -z "$ssh_command" ] && [ -n "$username" ] && [ -n "$assigned_ipv4" ]; then
        ssh_command="ssh ${username}@${assigned_ipv4}"
    fi

    [ -n "$assigned_ipv4" ] || assigned_ipv4="not-detected"
    [ -n "$ssh_command" ] || ssh_command="not-generated"

    generated_deleted="$(marker_yn_value_or_unknown "Generated ISO Deleted" "$marker")"
    installed_started="$(marker_yn_value_or_unknown "Installed VM Started" "$marker")"
    tools_cleanup_enabled="$(marker_yn_value_or_unknown "ISO Generation Tools Cleanup Enabled" "$marker")"
    tools_cleanup_done="$(marker_yn_value_or_unknown "ISO Generation Tools Cleanup Done" "$marker")"
    temp_cleanup="$(marker_yn_value_or_unknown "Temporary Workspace Cleanup Done" "$marker")"
    vm_swap_status="$(marker_value_or_default "VM Swap Status" "$marker" "unknown")"
    vm_swap_file="$(marker_value_or_default "VM Swap File" "$marker" "unknown")"
    vm_swap_size="$(marker_value_or_default "VM Swap Size" "$marker" "unknown")"
    vm_swap_type="$(marker_value_or_default "VM Swap Type" "$marker" "unknown")"

    echo -e "${YW}Marker:${CL}"
    previous_marker_line "path" "$marker"
    previous_marker_line "completed on" "$completed"
    echo ""

    echo -e "${YW}VM:${CL}"
    previous_marker_line "VM ID" "$vmid"
    previous_marker_line "VM NAME" "$vm_name"
    previous_marker_line "VM MAC" "$vm_mac"
    previous_marker_line "Assigned IPv4" "$assigned_ipv4"
    previous_marker_line "SSH command" "$ssh_command"
    echo ""

    echo -e "${YW}Install:${CL}"
    previous_marker_line "Installed VM started" "$installed_started"
    previous_marker_line "Generated ISO deleted" "$generated_deleted"
    echo ""

    echo -e "${YW}Swap:${CL}"
    previous_marker_line "Status" "$vm_swap_status"
    previous_marker_line "File" "$vm_swap_file"
    previous_marker_line "Size" "$vm_swap_size"
    previous_marker_line "Type" "$vm_swap_type"
    echo ""

    echo -e "${YW}Cleanup:${CL}"
    previous_marker_line "ISO tools cleanup enabled" "$tools_cleanup_enabled"
    previous_marker_line "ISO tools cleanup done" "$tools_cleanup_done"
    previous_marker_line "Temporary workspace cleanup" "$temp_cleanup"
}

# --- 24. VM STATUS HELPER ---
get_vm_status() {
    local vmid="$1"
    qm status "$vmid" 2>/dev/null | awk '{print $2}'
}

# --- 25. WAIT FOR VM POWEROFF HELPER ---
wait_for_vm_poweroff() {
    local vmid="$1"
    local timeout_minutes="$2"
    local timeout_seconds=$(( timeout_minutes * 60 ))
    local start_time=""
    local now_time=""
    local elapsed=""
    local status=""
    local status_display=""
    local elapsed_min=""
    local elapsed_sec=""
    local progress_drawn="no"

    start_time="$(date +%s)"

    section "INSTALL MONITORING"

    echo -e "${BL}Ubuntu autoinstall is running inside:${CL}"
    echo -e "  VM: ${GN}${TARGET_VM_NAME} (${vmid})${CL}"
    echo ""
    echo -e "${YW}Waiting for the VM to power off after installation.${CL}"
    echo -e "${RD}Do not manually restart the VM during this stage.${CL}"
    echo ""

    while true; do
        now_time="$(date +%s)"
        elapsed=$(( now_time - start_time ))
        elapsed_min=$(( elapsed / 60 ))
        elapsed_sec=$(( elapsed % 60 ))

        status="$(get_vm_status "$vmid")"

        if [ "$status" == "stopped" ]; then
            INSTALL_DURATION_SECONDS="$elapsed"
            INSTALL_DURATION_TEXT="${elapsed_min}m ${elapsed_sec}s"
            if [ "$progress_drawn" == "yes" ]; then
                tty_print "\033[3A\033[J"
            else
                tty_print "${BFR}"
            fi
            msg_ok "Ubuntu autoinstall completed. (${INSTALL_DURATION_TEXT})"
            msg_ok "VM ${vmid} powered off after install."
            return 0
        fi

        if [ "$elapsed" -ge "$timeout_seconds" ]; then
            if [ "$progress_drawn" == "yes" ]; then
                tty_print "\033[3A\033[J"
            else
                tty_print "${BFR}"
            fi
            msg_warn "Autoinstall wait timeout reached. VM ${vmid} is still ${status:-unknown}."
            return 1
        fi

        if [ "$progress_drawn" == "yes" ]; then
            tty_print "\033[3A\033[J"
        fi
        status_display="${status:-unknown}"
        if [ "$status_display" == "running" ]; then
            status_display="${FLASH_ON}${YW}running${FLASH_OFF}${CL}"
        else
            status_display="${YW}${status_display}${CL}"
        fi

        tty_println "${YW}Waiting for VM poweroff:${CL}"
        tty_println "${YW}  elapsed: ${elapsed_min}m ${elapsed_sec}s / ${timeout_minutes}m${CL}"
        tty_println "${YW}  status:${CL}  ${status_display}"
        progress_drawn="yes"
        sleep 10
    done
}
# --- 26. VM IPV4 DETECTION HELPER ---
get_vm_ipv4_from_guest_agent() {
    local vmid="$1"

    qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | \
        grep -oE '"ip-address"[[:space:]]*:[[:space:]]*"([0-9]{1,3}\.){3}[0-9]{1,3}"' | \
        sed -E 's/.*"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/' | \
        grep -Ev '^(127\.|169\.254\.)' | \
        head -n 1
}

# --- 27. WAIT FOR VM IPV4 HELPER ---
# Progress goes to /dev/tty; only the final IPv4 goes to stdout.
wait_for_vm_ipv4() {
    local vmid="$1"
    local timeout_seconds="$2"
    local interval_seconds="$3"
    local start_time=""
    local now_time=""
    local elapsed=""
    local remaining=""
    local ip=""

    start_time="$(date +%s)"

    tty_println "${BL}Detecting VM IPv4 from QEMU Guest Agent:${CL}"
    tty_println "  VM: ${GN}${TARGET_VM_NAME} (${vmid})${CL}"

    while true; do
        now_time="$(date +%s)"
        elapsed=$(( now_time - start_time ))
        remaining=$(( timeout_seconds - elapsed ))
        [ "$remaining" -lt 0 ] && remaining="0"

        ip="$(get_vm_ipv4_from_guest_agent "$vmid" || true)"

        if [ -n "$ip" ]; then
            tty_print "${BFR}"
            printf '%s\n' "$ip"
            return 0
        fi

        if [ "$elapsed" -ge "$timeout_seconds" ]; then
            tty_print "${BFR}"
            return 1
        fi

        tty_print "${BFR}${YW}  Timeout remaining:${CL} ${GN}${remaining}s${CL}"
        sleep "$interval_seconds"
    done
}
# --- 28. PATCH GRUB FILE HELPER ---
patch_grub_file() {
    local file="$1"
    local temp_file=""
    local line=""
    local default_present="no"

    [ -f "$file" ] || return 0

    if grep -q "^set default=" "$file"; then
        default_present="yes"
    fi

    temp_file="$(mktemp)"
    TEMP_FILES+=("$temp_file")

    if [ "$default_present" == "no" ]; then
        echo "set default=0" >> "$temp_file"
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^set[[:space:]]+timeout= ]]; then
            echo "set timeout=3" >> "$temp_file"
            continue
        fi

        if [[ "$line" =~ ^set[[:space:]]+default= ]]; then
            echo "set default=0" >> "$temp_file"
            continue
        fi

        if [[ "$line" == *'menuentry "Try or Install Ubuntu Server"'* ]]; then
            line="${line//menuentry \"Try or Install Ubuntu Server\"/menuentry \"AUTO-INSTALL Ubuntu Server\"}"
        fi

        if [[ "$line" == *"menuentry 'Try or Install Ubuntu Server'"* ]]; then
            line="${line//menuentry \'Try or Install Ubuntu Server\'/menuentry \'AUTO-INSTALL Ubuntu Server\'}"
        fi

        if [[ "$line" == *"/casper/vmlinuz"* ]]; then
            if [[ "$line" == *" ---"* ]]; then
                line="${line%% ---*} ${BOOT_PARAM} ---"
            else
                line="${line} ${BOOT_PARAM}"
            fi
        fi

        echo "$line" >> "$temp_file"
    done < "$file"

    cat "$temp_file" > "$file"
    rm -f "$temp_file"
}

# --- 29. NETWORK AUTOINSTALL YAML BUILDER ---
build_network_autoinstall_yaml() {
    if [ "$NETWORK_MODE" == "dhcp" ]; then
        cat <<EOF
network:
  version: 2
  ethernets:
    vmnic0:
      match:
        macaddress: "${TARGET_VM_MAC}"
      set-name: ens18
      dhcp4: true
      dhcp6: false
EOF
    else
        local dns_yaml=""
        local dns=""
        IFS=',' read -ra DNS_ARRAY <<< "$STATIC_DNS"

        for dns in "${DNS_ARRAY[@]}"; do
            dns="$(echo "$dns" | xargs)"
            [ -n "$dns" ] && dns_yaml+="          - ${dns}"$'\n'
        done

        cat <<EOF
network:
  version: 2
  ethernets:
    vmnic0:
      match:
        macaddress: "${TARGET_VM_MAC}"
      set-name: ens18
      dhcp4: false
      dhcp6: false
      addresses:
        - ${STATIC_IP_CIDR}
      routes:
        - to: default
          via: ${STATIC_GATEWAY}
      nameservers:
        addresses:
${dns_yaml}
EOF
    fi
}

# --- 30. LOGIN VERIFIER BUILDER ---
build_verifier_base64() {
    local verifier_file="$1"

    cat > "$verifier_file" <<EOF
#!/usr/bin/env bash

VERIFY_MARKER="/home/${TARGET_USERNAME}/.ubuntu-autoinstall-verify-displayed"

if [ "\$(id -un)" != "${TARGET_USERNAME}" ] && [ "\$(id -u)" -ne 0 ]; then
    return 0 2>/dev/null || exit 0
fi

if [ -f "\$VERIFY_MARKER" ]; then
    return 0 2>/dev/null || exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " UBUNTU AUTOINSTALL VERIFICATION REPORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Date: \$(date)"
echo "Host: \$(hostname)"
echo "User: ${TARGET_USERNAME}"
echo "Expected VM MAC: ${TARGET_VM_MAC}"
echo "Keyboard Layout: ${TARGET_KEYBOARD_LAYOUT}"
echo "Locale: ${TARGET_LOCALE}"
echo ""

# Colourised output for readability (UI-only). Uses ANSI escapes so
# the verifier script remains self-contained when executed on target.
PASS() { echo -e "\033[1;92m✓ PASS - \$1\033[m"; }
WARN() { echo -e "\033[33m! WARN - \$1\033[m"; }
FAIL() { echo -e "\033[01;31m✗ FAIL - \$1\033[m"; }

if [ -s "/home/${TARGET_USERNAME}/.ssh/authorized_keys" ]; then PASS "SSH authorized_keys present"; else FAIL "SSH authorized_keys missing"; fi
if sshd -T 2>/dev/null | grep -q "^passwordauthentication no"; then PASS "SSH password authentication disabled"; else FAIL "SSH password authentication not disabled"; fi
if sshd -T 2>/dev/null | grep -Eq "^permitrootlogin (no|prohibit-password|without-password)"; then PASS "Root SSH login disabled or passwordless-only"; else WARN "Root SSH login not confirmed secure"; fi
if [ -f "/etc/sudoers.d/90-${TARGET_USERNAME}-nopasswd" ]; then PASS "NOPASSWD sudo rule present"; else WARN "NOPASSWD sudo rule missing"; fi
if systemctl is-enabled --quiet qemu-guest-agent 2>/dev/null; then PASS "QEMU guest agent enabled"; else WARN "QEMU guest agent not enabled"; fi
if systemctl is-active --quiet qemu-guest-agent 2>/dev/null; then PASS "QEMU guest agent active"; else WARN "QEMU guest agent not active yet"; fi
if [ -f /var/log/ubuntu-autoinstall-completed ]; then PASS "Autoinstall completion marker exists"; else WARN "Autoinstall marker missing"; fi
if findmnt / >/dev/null 2>&1; then PASS "Root filesystem mounted"; else FAIL "Root filesystem check failed"; fi
if command -v ip >/dev/null 2>&1 && ip -4 addr show | grep -q "inet "; then PASS "IPv4 address detected"; else WARN "IPv4 address not detected"; fi
if apt-get check >/dev/null 2>&1; then PASS "APT database healthy"; else WARN "APT database check failed"; fi

echo ""
echo "Network:"
ip -br addr 2>/dev/null || true
echo ""
echo "Disk:"
df -h / 2>/dev/null || true
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

touch "\$VERIFY_MARKER" 2>/dev/null || true
rm -f /etc/profile.d/ubuntu-autoinstall-verify-display.sh 2>/dev/null || true
EOF

    base64 -w0 "$verifier_file"
}

# --- 31. AUTOINSTALL DIRECT CONFIG WRITER ---
write_direct_autoinstall_yaml() {
    local file="$1"

    cat > "$file" <<EOF
version: 1
refresh-installer:
  update: false
locale: ${TARGET_LOCALE}
keyboard:
  layout: ${TARGET_KEYBOARD_LAYOUT}
  variant: "${TARGET_KEYBOARD_VARIANT}"
timezone: ${TARGET_TIMEZONE}
identity:
  hostname: ${TARGET_HOSTNAME}
  username: ${TARGET_USERNAME}
  password: "${RANDOM_PASSWORD_HASH}"
ssh:
  install-server: true
  allow-pw: false
  authorized-keys:
${SSH_KEYS_YAML}
apt:
  preserve_sources_list: false
  primary:
    - arches: [default]
      uri: http://archive.ubuntu.com/ubuntu
$(build_network_autoinstall_yaml)
storage:
  layout:
    name: lvm
late-commands:
  - curtin in-target --target=/target -- usermod -aG sudo ${TARGET_USERNAME}
  - curtin in-target --target=/target -- bash -c 'echo "${TARGET_USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-${TARGET_USERNAME}-nopasswd'
  - curtin in-target --target=/target -- chmod 0440 /etc/sudoers.d/90-${TARGET_USERNAME}-nopasswd
  - curtin in-target --target=/target -- apt-get update
  - curtin in-target --target=/target -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y qemu-guest-agent curl ca-certificates'
  - curtin in-target --target=/target -- systemctl enable qemu-guest-agent
  - curtin in-target --target=/target -- bash -c 'sed -i -E "s/^[#[:space:]]*PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config'
  - curtin in-target --target=/target -- bash -c 'grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication no" >> /etc/ssh/sshd_config'
  - curtin in-target --target=/target -- bash -c 'sed -i -E "s/^[#[:space:]]*PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config'
  - curtin in-target --target=/target -- bash -c 'grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin no" >> /etc/ssh/sshd_config'
  - curtin in-target --target=/target -- bash -c 'sed -i -E "s/^[#[:space:]]*AddressFamily.*/AddressFamily inet/" /etc/ssh/sshd_config'
  - curtin in-target --target=/target -- bash -c 'grep -q "^AddressFamily" /etc/ssh/sshd_config || echo "AddressFamily inet" >> /etc/ssh/sshd_config'
  - curtin in-target --target=/target -- bash -c 'date > /var/log/ubuntu-autoinstall-completed'
  - curtin in-target --target=/target -- bash -c 'echo "${VM_MARKER_B64}" | base64 -d > /root/.ubuntu-autoinstall-seed-completed'
  - curtin in-target --target=/target -- chmod 0600 /root/.ubuntu-autoinstall-seed-completed
  - curtin in-target --target=/target -- bash -c 'echo "${VERIFIER_B64}" | base64 -d > /etc/profile.d/ubuntu-autoinstall-verify-display.sh'
  - curtin in-target --target=/target -- chmod +x /etc/profile.d/ubuntu-autoinstall-verify-display.sh
shutdown: poweroff
EOF
}

# --- 32. CLOUD-CONFIG USER-DATA WRITER ---
write_cloud_config_user_data() {
    local source_file="$1"
    local output_file="$2"

    {
        echo "#cloud-config"
        echo "autoinstall:"
        sed 's/^/  /' "$source_file"
    } > "$output_file"
}

# =========================================================
#  VALIDATION / INITIALIZATION
# =========================================================

# --- 33. DEPENDENCY VALIDATION ---
validate_dependencies() {
    local required_commands=(
        awk
        base64
        basename
        cat
        chmod
        cut
        date
        dpkg
        env
        find
        grep
        head
        mkdir
        mktemp
        openssl
        pveversion
        qm
        rm
        sed
        sleep
        sort
        ssh
        tee
        tr
        xargs
    )

    local cmd=""

    for cmd in "${required_commands[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || msg_error "Required command not found: ${cmd}"
    done
}

# --- 34. PROXMOX VALIDATION ---
validate_proxmox() {
    local pve_major=""

    if ! command -v pveversion >/dev/null 2>&1; then
        msg_error "This system is not Proxmox VE. Script cancelled."
    fi

    pve_major="$(pveversion | cut -d'/' -f2 | cut -d'.' -f1)"

    if ! [[ "$pve_major" =~ ^[0-9]+$ ]] || [ "$pve_major" -lt 9 ]; then
        msg_error "Requires Proxmox VE 9+."
    fi
}

# --- 35. TOOL INSTALLATION ---
# Installs required ISO tooling only if missing; optional cleanup removes ISO-generation-only tools.
detect_missing_iso_tools() {
    local missing_packages=()
    local pkg=""

    for pkg in xorriso rsync p7zip-full; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            missing_packages+=("$pkg")
        fi
    done

    MISSING_TOOL_PACKAGES=("${missing_packages[@]}")
    TOOLS_CHECKED="yes"
}

missing_iso_tools_display() {
    if [ "${#MISSING_TOOL_PACKAGES[@]}" -eq 0 ]; then
        echo "none"
    else
        echo "${MISSING_TOOL_PACKAGES[*]}"
    fi
}

iso_tool_action_display() {
    if [ "${#MISSING_TOOL_PACKAGES[@]}" -eq 0 ]; then
        echo "no action"
    elif [ "$CLEANUP_INSTALLED_TOOLS" == "yes" ]; then
        echo "install then remove"
    else
        echo "install and keep"
    fi
}

install_missing_tools_display() {
    if [ "$INSTALL_MISSING_TOOLS_APPROVED" == "not-needed" ]; then
        echo "not-needed"
    else
        yn_word "$INSTALL_MISSING_TOOLS_APPROVED"
    fi
}

vm_shutdown_display() {
    if [ "$VM_SHUTDOWN_APPROVED" == "not-needed" ]; then
        echo "not-needed"
    else
        yn_word "$VM_SHUTDOWN_APPROVED"
    fi
}

attach_start_display() {
    yn_word "$ATTACH_START_APPROVED"
}

collect_attach_start_decision() {
    local attach_yn=""

    echo -e "${WARN} ${RD}Starting Ubuntu autoinstall will wipe VM disk.${CL}"
    attach_yn="$(timed_yes_no_quiet "Start unattended Ubuntu install?" "y")"

    if [[ "$attach_yn" =~ ^[Nn] ]]; then
        ATTACH_START_APPROVED="no"
    else
        ATTACH_START_APPROVED="yes"
    fi
}

collect_missing_iso_tools_decision() {
    detect_missing_iso_tools

    if [ "${#MISSING_TOOL_PACKAGES[@]}" -gt 0 ]; then
        INSTALL_MISSING_TOOLS_APPROVED="yes"
    else
        INSTALL_MISSING_TOOLS_APPROVED="not-needed"
    fi
}

ensure_tools() {
    local pkg=""

    if [ "$ISO_PREP_GROUPED_OUTPUT" != "yes" ]; then
        section "ISO TOOL CHECK"
    fi

    msg_info "Checking required ISO tools"
    detect_missing_iso_tools

    if [ "${#MISSING_TOOL_PACKAGES[@]}" -gt 0 ]; then
        if [ "$INSTALL_MISSING_TOOLS_APPROVED" != "yes" ]; then
            msg_error "Required ISO tools are missing and installation was not approved during preflight. Cannot create a new autoinstall ISO."
        fi

        msg_ok "Required ISO tool check complete."
        msg_info "Installing missing ISO tools"
        run_cmd "updating APT package lists before tool install" env DEBIAN_FRONTEND=noninteractive apt-get update

        for pkg in "${MISSING_TOOL_PACKAGES[@]}"; do
            run_cmd "installing ${pkg}" env DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
            INSTALLED_TOOL_PACKAGES+=("$pkg")
        done

        detect_missing_iso_tools
        if [ "${#MISSING_TOOL_PACKAGES[@]}" -gt 0 ]; then
            msg_error "Required ISO tools are still missing after install attempt: ${MISSING_TOOL_PACKAGES[*]}"
        fi
    fi

    msg_ok "Required ISO tools available."
    command -v xorriso >/dev/null 2>&1 || msg_error "xorriso is required."
}

cleanup_preference_summary() {
    group_heading "Cleanup"
    group_answer_line "Remove ISO tools" "$(yn_word "$CLEANUP_INSTALLED_TOOLS")"
    group_answer_line "Remove workspace" "$(yn_word "$CLEANUP_TEMP_WORKFILES")"
    group_answer_line "Remove autoinstall ISO" "$(yn_word "$DELETE_GENERATED_ISO_AFTER_INSTALL")"
}

vm_network_summary() {
    group_heading "VM"
    group_answer_line "Selected VM" "${TARGET_VM_NAME} (${TARGET_VMID})"
    group_status_line "Status" "$TARGET_VM_STATUS"
    [ -n "${TARGET_VM_MAC:-}" ] && group_status_line "MAC" "$TARGET_VM_MAC"
    group_status_line "Network" "$NETWORK_MODE"
    if [ "$NETWORK_MODE" == "static" ]; then
        group_status_line "Static IP/CIDR" "$STATIC_IP_CIDR"
        group_status_line "Gateway" "$STATIC_GATEWAY"
        group_status_line "DNS" "$STATIC_DNS"
    fi
}

identity_locale_summary() {
    group_heading "Identity / locale"
    group_answer_line "Ubuntu user" "$TARGET_USERNAME"
    group_answer_line "Timezone" "$TARGET_TIMEZONE"
    group_answer_line "Locale" "$TARGET_LOCALE"
    group_answer_line "Keyboard" "$TARGET_KEYBOARD_LAYOUT"
    if [ -n "${TARGET_KEYBOARD_VARIANT:-}" ]; then
        group_answer_line "Keyboard variant" "$TARGET_KEYBOARD_VARIANT"
    fi
}

install_options_summary() {
    group_heading "Install"
    group_answer_line "Autoinstall timeout" "${INSTALL_WAIT_MINUTES}m"
    group_answer_line "IP detection timeout" "${SSH_IP_DETECT_TIMEOUT_SECONDS}s"
    group_answer_line "Start after cleanup" "$(yn_word "$POST_INSTALL_START_VM")"
    echo ""
    group_heading "ISO"
    group_answer_line "Source ISO" "$(display_iso_ref "$INSTALL_ISO_REF")"
    group_status_line "Generated ISO" "$(display_iso_ref "$AUTOINSTALL_ISO_REF")"
    group_status_line "Missing tools" "$(missing_iso_tools_display)"
    group_status_line "Tool action" "$(iso_tool_action_display)"
}

# --- 35A. EARLY CLEANUP PREFERENCES ---
# Collects cleanup decisions before package installation, work directories, ISO writes, or VM changes.
# This keeps reruns predictable and ensures the user decides cleanup behaviour at the beginning.
collect_early_cleanup_preferences() {
    local tool_cleanup_yn=""
    local temp_cleanup_yn=""
    local iso_cleanup_yn=""

    section "CLEANUP PREFERENCES"

    echo -e "${YW}Cleanup:${CL}"
    echo -e "  ${BL}Tools:${CL} ${GN}xorriso p7zip-full${CL}"
    echo -e "  ${YW}Recommended: remove temporary ISO tools/workspace from the Proxmox host.${CL}"
    echo ""

    tool_cleanup_yn="$(timed_yes_no "Remove ISO tools" "y")"
    if [[ "$tool_cleanup_yn" =~ ^[Nn] ]]; then
        CLEANUP_INSTALLED_TOOLS="no"
    else
        CLEANUP_INSTALLED_TOOLS="yes"
    fi

    temp_cleanup_yn="$(timed_yes_no "Remove workspace" "y")"
    if [[ "$temp_cleanup_yn" =~ ^[Nn] ]]; then
        CLEANUP_TEMP_WORKFILES="no"
    else
        CLEANUP_TEMP_WORKFILES="yes"
    fi

    iso_cleanup_yn="$(timed_yes_no "Remove autoinstall ISO" "y")"
    if [[ "$iso_cleanup_yn" =~ ^[Nn] ]]; then
        DELETE_GENERATED_ISO_AFTER_INSTALL="n"
    else
        DELETE_GENERATED_ISO_AFTER_INSTALL="y"
    fi

    clear_terminal_lines 7
    cleanup_preference_summary
}

# --- 35B. GENERATED ISO PATH PREPARATION ---
# Calculates the generated ISO path before any work directory or file changes are made.
set_autoinstall_iso_paths() {
    AUTOINSTALL_ISO_NAME="ubuntu-26.04-autoinstall-vm${TARGET_VMID}.iso"
    AUTOINSTALL_ISO_PATH="/var/lib/vz/template/iso/${AUTOINSTALL_ISO_NAME}"
    AUTOINSTALL_ISO_REF="local:iso/${AUTOINSTALL_ISO_NAME}"
}

# --- 35C. GENERATED ISO REUSE / RECREATE PREFLIGHT ---
# Collects generated ISO reuse/recreate/create choice before ISO preparation starts.
collect_generated_iso_action() {
    local reuse_yn=""
    local recreate_yn=""

    set_autoinstall_iso_paths

    if [ -f "$AUTOINSTALL_ISO_PATH" ]; then
        GENERATED_ISO_EXISTS="yes"
        msg_warn "Generated autoinstall ISO already exists"
        echo ""
        echo -e "${YW}You can reuse it to redeploy the VM without rebuilding the ISO, or recreate it with the current answers.${CL}"
        echo ""

        reuse_yn="$(timed_yes_no_quiet "Reuse existing generated ISO?" "y")"

        if [[ "$reuse_yn" =~ ^[Yy] ]]; then
            GENERATED_ISO_ACTION="reuse"
            REUSE_EXISTING_AUTOINSTALL_ISO="yes"
            return 0
        fi

        recreate_yn="$(timed_yes_no_quiet "Recreate and replace existing generated ISO?" "y")"

        if [[ "$recreate_yn" =~ ^[Nn] ]]; then
            msg_error "Existing generated ISO was not reused or replaced. Script cancelled before changes."
        fi

        GENERATED_ISO_ACTION="recreate"
        REUSE_EXISTING_AUTOINSTALL_ISO="no"
    else
        GENERATED_ISO_EXISTS="no"
        GENERATED_ISO_ACTION="create"
        REUSE_EXISTING_AUTOINSTALL_ISO="no"
    fi
}

# Applies the preflight-generated ISO action during ISO preparation without asking again.
precheck_generated_iso_reuse() {
    set_autoinstall_iso_paths

    if [ "$ISO_PREP_GROUPED_OUTPUT" != "yes" ]; then
        section "RERUN / GENERATED ISO PREFLIGHT"
    fi

    detail_line "Expected generated ISO" "$AUTOINSTALL_ISO_PATH"
    detail_line "Generated ISO action" "$GENERATED_ISO_ACTION"

    case "$GENERATED_ISO_ACTION" in
        reuse)
            if [ ! -f "$AUTOINSTALL_ISO_PATH" ]; then
                msg_error "Generated ISO was selected for reuse but is missing: ${AUTOINSTALL_ISO_PATH}"
            fi
            GENERATED_ISO_EXISTS="yes"
            REUSE_EXISTING_AUTOINSTALL_ISO="yes"
            ;;
        recreate)
            GENERATED_ISO_EXISTS="yes"
            REUSE_EXISTING_AUTOINSTALL_ISO="no"
            ;;
        create)
            GENERATED_ISO_EXISTS="no"
            REUSE_EXISTING_AUTOINSTALL_ISO="no"
            ;;
        *)
            msg_error "Invalid generated ISO action: ${GENERATED_ISO_ACTION}"
            ;;
    esac

    msg_ok "Existing generated ISO check complete."
}

# --- 36. PREVIOUS RUN MARKER CHECK ---
check_previous_marker() {
    local continue_yn=""

    if [ -f "$COMPLETED_MARKER" ]; then
        section "PREVIOUS AUTOINSTALL CHECK"

        show_previous_marker_summary "$COMPLETED_MARKER"
        echo ""

        continue_yn="$(timed_yes_no "Continue anyway?" "n")"

        if [[ "$continue_yn" =~ ^[Nn] ]]; then
            exit 0
        fi
    fi
}

# --- 37. INITIALIZATION ---
init_script() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RD}Please run as root.${CL}"
        exit 1
    fi

    exec > >(tee -a "$LOG_FILE") 2>&1

    trap 'on_error "$LINENO"' ERR
    trap cleanup EXIT

    clear
    header_info
    show_script_version

    validate_dependencies
    validate_proxmox
    discover_proxmox_identity
}

# =========================================================
#  INPUT COLLECTION
# =========================================================

# --- 38. START WARNING ---
show_start_warning() {
    echo -e "${YW}This script creates a generated Ubuntu 26.04 autoinstall ISO copy.${CL}"
    echo -e "${YW}The original Ubuntu ISO remains untouched.${CL}"
    echo -e "${YW}Written for: ${GN}${DEFAULT_ISO_NAME}${CL}"
    echo ""
    echo -e "${RD}WARNING:${CL} Ubuntu autoinstall can erase the selected VM install disk."
    echo -e "${YW}For best results, use a fresh VM created by script 3-proxmoxVMsetup with one OS disk.${CL}"
    echo ""
}

# --- 39. VM SELECTION ---
select_vm() {
    local vmid=""
    local name=""
    local status=""
    local default_vm_index="1"
    local highest_vmid="0"
    local vm_index=""
    local list_lines="0"

    section "VM SELECTION"

    msg_info "Detecting Proxmox VMs"

    mapfile -t VM_LINES < <(qm list | awk 'NR>1 {print $1 "|" $2 "|" $3}')

    if [ "${#VM_LINES[@]}" -eq 0 ]; then
        msg_error "No VMs found. Run script 3 first, then run this script."
    fi

    tty_print "${BFR}"
    echo -e "${YW}Available VMs:${CL}"
    list_lines=1

    for i in "${!VM_LINES[@]}"; do
        vmid="$(echo "${VM_LINES[$i]}" | cut -d'|' -f1)"
        name="$(echo "${VM_LINES[$i]}" | cut -d'|' -f2)"
        status="$(echo "${VM_LINES[$i]}" | cut -d'|' -f3)"

        if [ "$vmid" -gt "$highest_vmid" ]; then
            highest_vmid="$vmid"
            default_vm_index="$((i+1))"
        fi

        echo "  $((i+1))) ${vmid} | ${name} | ${status}"
        list_lines=$((list_lines + 1))
    done

    [ "${#VM_LINES[@]}" -eq 1 ] && default_vm_index="1"

    vm_index="$(timed_number_input "Select VM for Ubuntu autoinstall" "$default_vm_index" "1" "${#VM_LINES[@]}")"
    clear_terminal_lines "$((list_lines + 1))"

    TARGET_VMID="$(echo "${VM_LINES[$((vm_index-1))]}" | cut -d'|' -f1)"
    TARGET_VM_NAME="$(echo "${VM_LINES[$((vm_index-1))]}" | cut -d'|' -f2)"
    TARGET_VM_STATUS="$(echo "${VM_LINES[$((vm_index-1))]}" | cut -d'|' -f3)"

    qm config "$TARGET_VMID" >/dev/null 2>&1 || msg_error "Selected VM ${TARGET_VMID} does not exist."

    if [ "$TARGET_VM_STATUS" == "running" ]; then
        msg_warn "VM ${TARGET_VMID} is running; it will not be stopped until final apply."
    fi
}

# --- 39A. VM SHUTDOWN DECISION PREFLIGHT ---
# Collects shutdown approval before ISO preparation or VM apply actions.
collect_vm_shutdown_decision() {
    local shutdown_yn=""
    local current_status=""

    current_status="$(get_vm_status "$TARGET_VMID" || true)"
    VM_STATUS_AT_PREFLIGHT="${current_status:-unknown}"
    TARGET_VM_STATUS="$VM_STATUS_AT_PREFLIGHT"

    if [ "$VM_STATUS_AT_PREFLIGHT" == "running" ]; then
        msg_warn "Selected VM is currently running."
        echo -e "${YW}The VM must be stopped before attaching installer media safely.${CL}"
        echo ""

        shutdown_yn="$(timed_yes_no_quiet "Selected VM is currently running. Shutdown VM before apply?" "y")"

        if [[ "$shutdown_yn" =~ ^[Nn] ]]; then
            VM_SHUTDOWN_APPROVED="no"
        else
            VM_SHUTDOWN_APPROVED="yes"
        fi
    else
        VM_SHUTDOWN_APPROVED="not-needed"
    fi

}

# --- 39B. VM STOP SAFETY BEFORE APPLY ---
# Stops the selected VM only after all prechecks, ISO decisions and final confirmation are complete.
ensure_vm_stopped_before_apply() {
    local current_status=""

    current_status="$(get_vm_status "$TARGET_VMID")"
    TARGET_VM_STATUS="${current_status:-unknown}"

    if [ "$TARGET_VM_STATUS" != "running" ]; then
        return 0
    fi

    msg_warn "VM ${TARGET_VMID} is currently running"
    echo -e "${YW}The VM must be stopped before attaching installer media safely.${CL}"
    echo ""

    if [ "$VM_SHUTDOWN_APPROVED" != "yes" ]; then
        msg_error "VM is still running and shutdown was not approved during preflight. Refusing to attach installer media."
    fi

    msg_info "Shutting down VM ${TARGET_VMID}"
    if qm shutdown "$TARGET_VMID" --timeout 60 >/dev/null 2>&1; then
        msg_ok "VM shutdown complete."
    else
        msg_warn "Graceful shutdown failed or timed out; forcing stop"
        run_cmd "stopping VM ${TARGET_VMID}" qm stop "$TARGET_VMID"
        msg_ok "VM stopped."
    fi
    TARGET_VM_STATUS="stopped"
}

# --- 40. VM MAC DETECTION ---
detect_vm_mac() {
    msg_info "Detecting VM MAC address"

    TARGET_VM_MAC="$(qm config "$TARGET_VMID" | awk -F'[=,]' '/^net0:/ {print $2; exit}' | tr '[:lower:]' '[:upper:]')"

    if [ -z "$TARGET_VM_MAC" ]; then
        msg_error "Could not detect net0 MAC address for VM ${TARGET_VMID}. Check: qm config ${TARGET_VMID}"
    fi

    tty_print "${BFR}"
}

# --- 41. USER / LOCALE INPUTS ---
collect_user_locale_inputs() {
    local keyboard_choice=""

    section "IDENTITY / LOCALE"

    while true; do
        TARGET_USERNAME="$(timed_text_input "Enter Ubuntu admin username" "$DEFAULT_USERNAME")"

        if validate_linux_username "$TARGET_USERNAME"; then
            break
        fi

        msg_warn "Invalid username. Use lowercase Linux username format."
    done

    TARGET_TIMEZONE="$(timed_text_input "Enter timezone" "$DEFAULT_TIMEZONE")"
    TARGET_LOCALE="$(timed_text_input "Enter Ubuntu locale" "$DEFAULT_LOCALE")"

    keyboard_choice="$(timed_menu_select "Keyboard Layout" "1" \
        "UK / British keyboard (gb)" \
        "US keyboard (us)" \
        "Custom keyboard layout")"

    case "$keyboard_choice" in
        "UK / British keyboard (gb)")
            TARGET_KEYBOARD_LAYOUT="gb"
            TARGET_KEYBOARD_VARIANT=""
            ;;
        "US keyboard (us)")
            TARGET_KEYBOARD_LAYOUT="us"
            TARGET_KEYBOARD_VARIANT=""
            ;;
        *)
            TARGET_KEYBOARD_LAYOUT="$(timed_text_input_quiet "Enter keyboard layout code" "$DEFAULT_KEYBOARD_LAYOUT")"
            TARGET_KEYBOARD_VARIANT="$(timed_text_input_quiet "Enter keyboard variant or leave blank" "$DEFAULT_KEYBOARD_VARIANT")"
            ;;
    esac

    TARGET_HOSTNAME="$(safe_hostname "$TARGET_VM_NAME")"

    if [ -n "${TARGET_KEYBOARD_VARIANT:-}" ]; then
        clear_terminal_lines 5
    else
        clear_terminal_lines 3
    fi
    identity_locale_summary
}

# --- 42. SSH KEY DETECTION ---
detect_ssh_keys() {
    section "SSH KEY DETECTION"

    msg_info "Detecting SSH authorized keys"

    KEY_SOURCE=""

    if [ -s "/home/${TARGET_USERNAME}/.ssh/authorized_keys" ]; then
        KEY_SOURCE="/home/${TARGET_USERNAME}/.ssh/authorized_keys"
    elif [ -s "/root/.ssh/authorized_keys" ]; then
        KEY_SOURCE="/root/.ssh/authorized_keys"
    else
        for pubkey in /root/.ssh/id_*.pub "/home/${TARGET_USERNAME}/.ssh/id_"*.pub; do
            if [ -s "$pubkey" ]; then
                KEY_SOURCE="$pubkey"
                break
            fi
        done
    fi

    if [ -z "$KEY_SOURCE" ]; then
        echo ""
        echo -e "${RD}No SSH public key source found.${CL}"
        echo -e "${YW}This autoinstall is SSH-key-only and will not create usable password SSH login.${CL}"
        echo -e "${YW}Add a key to /root/.ssh/authorized_keys or /home/${TARGET_USERNAME}/.ssh/authorized_keys and rerun.${CL}"
        exit 1
    fi

    SSH_KEYS="$(grep -E '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-|sk-ssh-)' "$KEY_SOURCE" | sed '/^[[:space:]]*$/d' || true)"

    if [ -z "$SSH_KEYS" ]; then
        msg_error "SSH key source exists but no valid public key lines were found: ${KEY_SOURCE}"
    fi

    msg_ok "SSH KEYS DETECTED (${KEY_SOURCE})"
}

# --- 43. NETWORK INPUTS ---
collect_network_inputs() {
    local dhcp_yn=""

    dhcp_yn="$(timed_yes_no "Use DHCP networking inside Ubuntu?" "y")"

    if [[ "$dhcp_yn" =~ ^[Nn] ]]; then
        NETWORK_MODE="static"

        section "NETWORK CONFIGURATION"

        while true; do
            STATIC_IP_CIDR="$(timed_text_input_quiet "Enter static IP/CIDR" "192.0.2.50/24")"
            validate_ipv4_cidr "$STATIC_IP_CIDR" && break
            msg_warn "Invalid static IP/CIDR. Example: 192.0.2.50/24"
        done

        while true; do
            STATIC_GATEWAY="$(timed_text_input_quiet "Enter gateway IP" "192.0.2.1")"
            validate_ipv4 "$STATIC_GATEWAY" && break
            msg_warn "Invalid gateway IPv4 address. Example: 192.0.2.1"
        done

        while true; do
            STATIC_DNS="$(timed_text_input_quiet "Enter DNS servers comma-separated" "$STATIC_DNS")"
            validate_dns_list "$STATIC_DNS" && break
            msg_warn "Invalid DNS list. Example: 1.1.1.1,1.0.0.1"
        done
    else
        NETWORK_MODE="dhcp"
    fi

    if [ "$NETWORK_MODE" == "dhcp" ]; then
        clear_terminal_lines 1
    fi

    vm_network_summary
}
# --- 44. POST-INSTALL INPUTS ---
collect_post_install_options() {
    local start_installed_yn=""

    section "INSTALL OPTIONS"

    INSTALL_WAIT_MINUTES="$(timed_number_input "Enter autoinstall wait timeout in minutes" "$DEFAULT_INSTALL_WAIT_MINUTES" "10" "240")"
    SSH_IP_DETECT_TIMEOUT_SECONDS="$(timed_number_input "Enter VM IPv4 detection timeout in seconds" "$SSH_IP_DETECT_TIMEOUT_SECONDS" "30" "600")"

    start_installed_yn="$(timed_yes_no "Start installed Ubuntu VM after cleanup?" "y")"
    [[ "$start_installed_yn" =~ ^[Nn] ]] && POST_INSTALL_START_VM="n" || POST_INSTALL_START_VM="y"
    clear_terminal_lines 3
}

# --- 45. UBUNTU ISO SELECTION ---
select_ubuntu_iso() {
    local default_iso_index="1"
    local iso_base=""
    local iso_index=""
    local list_lines="0"

    msg_info "Finding Ubuntu install ISO"

    mapfile -t ISOS < <(find /var/lib/vz/template/iso -maxdepth 1 -type f -iname "*.iso" ! -iname "*autoinstall*" ! -iname "*seed*" | sort || true)

    if [ "${#ISOS[@]}" -eq 0 ]; then
        msg_error "No original ISO files found in /var/lib/vz/template/iso."
    fi

    tty_print "${BFR}"
    echo -e "${YW}Available ISOs:${CL}"
    list_lines=1

    for i in "${!ISOS[@]}"; do
        iso_base="$(basename "${ISOS[$i]}")"
        [ "$iso_base" == "$DEFAULT_ISO_NAME" ] && default_iso_index="$((i+1))"
        echo "  $((i+1))) ${iso_base}"
        list_lines=$((list_lines + 1))
    done

    iso_index="$(timed_number_input "Select Ubuntu ISO number" "$default_iso_index" "1" "${#ISOS[@]}")"
    clear_terminal_lines "$((list_lines + 1))"
    INSTALL_ISO_PATH="${ISOS[$((iso_index-1))]}"
    INSTALL_ISO_REF="local:iso/$(basename "$INSTALL_ISO_PATH")"

    set_autoinstall_iso_paths
    detect_missing_iso_tools
    install_options_summary
}

# --- 46. UBUNTU PRO NOTE ---
show_ubuntu_pro_note() {
    # Ubuntu Pro attachment is handled later by Script 4.
    return 0
}
# =========================================================
#  ISO / AUTOINSTALL GENERATION
# =========================================================

# --- 47. PREPARE WORKSPACE ---
prepare_workspace() {
    WORK_DIR="$(mktemp -d "/tmp/ubuntu-autoinstall-vm${TARGET_VMID}.XXXXXX")"
    TEMP_FILES+=("$WORK_DIR")

    mkdir -p "$WORK_DIR/nocloud"
    mkdir -p "$WORK_DIR/grub"
    mkdir -p "$WORK_DIR/verify"
}

# --- 47A. EXISTING GENERATED ISO VALIDATION ---
# Lightweight validation for reuse mode. It avoids modifying files or VM config.
verify_reused_generated_iso() {
    if [ "$ISO_PREP_GROUPED_OUTPUT" != "yes" ]; then
        section "REUSED ISO CHECK"
    fi

    if [ ! -s "$AUTOINSTALL_ISO_PATH" ]; then
        msg_error "Selected reuse ISO is missing or empty: ${AUTOINSTALL_ISO_PATH}"
    fi

    msg_ok "Existing generated ISO check complete."
    detail_line "Generated ISO" "$(display_iso_ref "$AUTOINSTALL_ISO_REF")"

    if command -v xorriso >/dev/null 2>&1; then
        msg_info "Quick-checking reused ISO boot data"
        if xorriso -indev "$AUTOINSTALL_ISO_PATH" -report_el_torito plain >/dev/null 2>&1; then
            msg_ok "Reused generated ISO boot data readable."
        else
            msg_warn "Could not read reused ISO boot data with xorriso. You may recreate it if boot fails."
        fi
    else
        msg_warn "xorriso not installed; reused ISO was not deep-verified. This is acceptable for reuse mode."
    fi
}

# --- 48. BUILD SSH KEY YAML ---
build_ssh_key_yaml() {
    SSH_KEYS_YAML=""

    while IFS= read -r keyline; do
        [ -z "$keyline" ] && continue
        SSH_KEYS_YAML+="      - $(yaml_quote "$keyline")"$'\n'
    done <<< "$SSH_KEYS"
}

# --- 49. WRITE NETWORK CONFIG ---
write_nocloud_network_config() {
    local dns_yaml=""
    local dns=""

    if [ "$NETWORK_MODE" == "dhcp" ]; then
cat > "${WORK_DIR}/nocloud/network-config" <<EOF
version: 2
ethernets:
  vmnic0:
    match:
      macaddress: "${TARGET_VM_MAC}"
    set-name: ens18
    dhcp4: true
    dhcp6: false
EOF
    else
        IFS=',' read -ra DNS_ARRAY <<< "$STATIC_DNS"

        for dns in "${DNS_ARRAY[@]}"; do
            dns="$(echo "$dns" | xargs)"
            [ -n "$dns" ] && dns_yaml+="        - ${dns}"$'\n'
        done

cat > "${WORK_DIR}/nocloud/network-config" <<EOF
version: 2
ethernets:
  vmnic0:
    match:
      macaddress: "${TARGET_VM_MAC}"
    set-name: ens18
    dhcp4: false
    dhcp6: false
    addresses:
      - ${STATIC_IP_CIDR}
    routes:
      - to: default
        via: ${STATIC_GATEWAY}
    nameservers:
      addresses:
${dns_yaml}
EOF
    fi
}

# --- 50. WRITE META-DATA ---
write_metadata() {
cat > "${WORK_DIR}/nocloud/meta-data" <<EOF
instance-id: ubuntu-autoinstall-vm${TARGET_VMID}
local-hostname: ${TARGET_HOSTNAME}
EOF
}

# --- 51. WRITE AUTOINSTALL CONFIG ---
write_autoinstall_config() {
    if [ "$ISO_PREP_GROUPED_OUTPUT" != "yes" ]; then
        section "AUTOINSTALL CONFIGURATION"
    fi

    msg_info "Creating Ubuntu autoinstall configuration"

    RANDOM_PASSWORD_HASH="$(openssl passwd -6 "$(openssl rand -base64 48)")"
    build_ssh_key_yaml
    VERIFIER_B64="$(build_verifier_base64 "${WORK_DIR}/ubuntu-autoinstall-verify-display.sh")"
    VM_MARKER_B64="$(build_vm_side_marker_base64 "${WORK_DIR}/ubuntu-autoinstall-seed-marker")"

    write_direct_autoinstall_yaml "${WORK_DIR}/autoinstall.yaml"
    write_cloud_config_user_data "${WORK_DIR}/autoinstall.yaml" "${WORK_DIR}/nocloud/user-data"

    if grep -q "^#!/usr/bin/env bash" "${WORK_DIR}/autoinstall.yaml"; then
        msg_error "Generated autoinstall.yaml contains an unindented shell script and would fail YAML parsing."
    fi

    if ! grep -q "^shutdown: poweroff" "${WORK_DIR}/autoinstall.yaml"; then
        msg_error "Generated autoinstall.yaml must use shutdown: poweroff to prevent reinstall loops."
    fi

    msg_ok "Autoinstall configuration created."
}

# --- 52. EXTRACT GRUB CONFIGS ---
extract_grub_configs() {
    if [ "$ISO_PREP_GROUPED_OUTPUT" != "yes" ]; then
        section "BOOT CONFIG EXTRACTION"
    fi

    msg_info "Extracting Ubuntu boot configuration"

    run_cmd "extracting /boot/grub/grub.cfg from source ISO" \
        xorriso -osirrox on -indev "$INSTALL_ISO_PATH" -extract /boot/grub/grub.cfg "$WORK_DIR/grub/grub.cfg"

    xorriso -osirrox on -indev "$INSTALL_ISO_PATH" -extract /boot/grub/loopback.cfg "$WORK_DIR/grub/loopback.cfg" &>/dev/null || true

    msg_ok "Ubuntu boot configuration extracted."
}

# --- 53. PATCH BOOT PARAMETERS ---
patch_boot_parameters() {
    if [ "$ISO_PREP_GROUPED_OUTPUT" != "yes" ]; then
        section "BOOT PARAMETER PATCHING"
    fi

    msg_info "Patching Ubuntu autoinstall boot parameters"

    patch_grub_file "$WORK_DIR/grub/grub.cfg"
    patch_grub_file "$WORK_DIR/grub/loopback.cfg"

    if ! grep -q "AUTO-INSTALL Ubuntu Server" "$WORK_DIR/grub/grub.cfg"; then
        msg_error "Autoinstall menu title was not injected into grub.cfg."
    fi

    if ! grep -q "ds=nocloud" "$WORK_DIR/grub/grub.cfg"; then
        msg_error "NoCloud boot parameter was not injected into grub.cfg."
    fi

    if ! grep -q "subiquity.autoinstallpath" "$WORK_DIR/grub/grub.cfg"; then
        msg_error "Subiquity autoinstall path was not injected into grub.cfg."
    fi

    msg_ok "Autoinstall boot parameters patched."
}

# --- 54. BUILD GENERATED ISO ---
build_generated_iso() {
    if [ "$ISO_PREP_GROUPED_OUTPUT" != "yes" ]; then
        section "AUTOINSTALL ISO BUILD"
    fi

    msg_info "Building generated Ubuntu autoinstall ISO copy"

    rm -f "$AUTOINSTALL_ISO_PATH"

    XORRISO_ARGS=(
        -indev "$INSTALL_ISO_PATH"
        -outdev "$AUTOINSTALL_ISO_PATH"
        -boot_image any replay
        -map "$WORK_DIR/autoinstall.yaml" /autoinstall.yaml
        -map "$WORK_DIR/nocloud" /nocloud
        -map "$WORK_DIR/grub/grub.cfg" /boot/grub/grub.cfg
    )

    if [ -f "$WORK_DIR/grub/loopback.cfg" ]; then
        XORRISO_ARGS+=(
            -map "$WORK_DIR/grub/loopback.cfg" /boot/grub/loopback.cfg
        )
    fi

    run_cmd "building generated Ubuntu autoinstall ISO copy" xorriso "${XORRISO_ARGS[@]}"

    if [ ! -s "$AUTOINSTALL_ISO_PATH" ]; then
        msg_error "Generated Ubuntu autoinstall ISO was not created."
    fi

    msg_ok "Generated autoinstall ISO created. ($(display_iso_ref "$AUTOINSTALL_ISO_REF"))"
}

# --- 55. VERIFY GENERATED ISO ---
verify_generated_iso() {
    if [ "$ISO_PREP_GROUPED_OUTPUT" != "yes" ]; then
        section "AUTOINSTALL ISO VERIFICATION"
    fi

    msg_info "Verifying generated autoinstall ISO"

    rm -rf "$WORK_DIR/verify"
    mkdir -p "$WORK_DIR/verify"

    run_cmd "verifying generated ISO grub.cfg" \
        xorriso -osirrox on -indev "$AUTOINSTALL_ISO_PATH" -extract /boot/grub/grub.cfg "$WORK_DIR/verify/grub.cfg"

    run_cmd "verifying generated ISO /autoinstall.yaml" \
        xorriso -osirrox on -indev "$AUTOINSTALL_ISO_PATH" -extract /autoinstall.yaml "$WORK_DIR/verify/autoinstall.yaml"

    run_cmd "verifying generated ISO /nocloud/user-data" \
        xorriso -osirrox on -indev "$AUTOINSTALL_ISO_PATH" -extract /nocloud/user-data "$WORK_DIR/verify/user-data"

    grep -q "AUTO-INSTALL Ubuntu Server" "$WORK_DIR/verify/grub.cfg" || msg_error "Generated ISO boot menu title was not patched."
    grep -q "ds=nocloud" "$WORK_DIR/verify/grub.cfg" || msg_error "Generated ISO is missing NoCloud boot parameter."
    grep -q "subiquity.autoinstallpath" "$WORK_DIR/verify/grub.cfg" || msg_error "Generated ISO is missing Subiquity autoinstall path parameter."
    grep -q "^version: 1" "$WORK_DIR/verify/autoinstall.yaml" || msg_error "Generated ISO /autoinstall.yaml is not valid direct autoinstall format."
    grep -q "^shutdown: poweroff" "$WORK_DIR/verify/autoinstall.yaml" || msg_error "Generated ISO /autoinstall.yaml is missing shutdown: poweroff."
    ! grep -q "^#!/usr/bin/env bash" "$WORK_DIR/verify/autoinstall.yaml" || msg_error "Generated ISO /autoinstall.yaml contains unindented shell script content."
    grep -q "^#cloud-config" "$WORK_DIR/verify/user-data" || msg_error "Generated ISO /nocloud/user-data is missing #cloud-config header."

    msg_ok "Generated autoinstall ISO verified."
}

# --- 56. GENERATE AUTOINSTALL ISO ---
generate_autoinstall_iso() {
    if [ "$ISO_PREP_GROUPED_OUTPUT" != "yes" ]; then
        section "AUTOINSTALL ISO PREPARATION"
        ISO_PREP_GROUPED_OUTPUT="yes"
    fi

    if [ "$REUSE_EXISTING_AUTOINSTALL_ISO" == "yes" ]; then
        verify_reused_generated_iso
        return 0
    fi

    prepare_workspace
    write_nocloud_network_config
    write_metadata
    write_autoinstall_config
    extract_grub_configs
    patch_boot_parameters
    build_generated_iso
    verify_generated_iso
}

# =========================================================
#  APPLY / EXECUTION
# =========================================================

# --- 57. FINAL SUMMARY BEFORE APPLY ---
show_apply_summary() {
    section "SETUP PLAN"

    group_heading "VM"
    group_answer_line "Target" "${TARGET_VM_NAME} (${TARGET_VMID})"
    group_status_line "Action" "wipe disk and install Ubuntu" "$YW"
    group_status_line "Autoinstall ISO" "$(display_iso_ref "$AUTOINSTALL_ISO_REF")"
    group_answer_line "Start after cleanup" "$(yn_word "$POST_INSTALL_START_VM")"
    echo ""

    group_heading "Ubuntu"
    group_answer_line "Hostname" "$TARGET_HOSTNAME"
    group_answer_line "User" "$TARGET_USERNAME"
    group_answer_line "Network" "$NETWORK_MODE"
    echo ""


    group_heading "Proxmox identity"
    group_status_line "Hostname" "$(proxmox_identity_value_or_not_detected "$PROXMOX_HOSTNAME")"
    group_status_line "Domain" "$(proxmox_identity_value_or_not_detected "$PROXMOX_DOMAIN")"
    group_status_line "LAN URL" "$(proxmox_identity_value_or_not_detected "$PROXMOX_LAN_URL")"
    echo ""

    group_heading "Cleanup"
    group_answer_line "Generated ISO" "$( [ "$DELETE_GENERATED_ISO_AFTER_INSTALL" == "y" ] && echo delete || echo keep )"
    group_answer_line "Tools" "$( [ "$CLEANUP_INSTALLED_TOOLS" == "yes" ] && echo remove || echo keep )"
    group_answer_line "Workspace" "$( [ "$CLEANUP_TEMP_WORKFILES" == "yes" ] && echo remove || echo keep )"
    echo ""

    group_heading "Warning"
    echo -e "  ${RD}Selected VM disk will be wiped.${CL}"
    echo -e "  ${YW}Use a fresh VM with one OS disk.${CL}"
}
# --- 58. ATTACH AND START INSTALL ---
attach_iso_and_start_install() {
    ensure_vm_stopped_before_apply

    msg_info "Attaching generated Ubuntu autoinstall ISO"
    run_cmd "attaching generated Ubuntu autoinstall ISO" qm set "$TARGET_VMID" --ide2 "${AUTOINSTALL_ISO_REF},media=cdrom"
    msg_ok "Installer ISO attached."

    msg_info "Setting VM boot order to installer first"
    run_cmd "setting VM boot order to installer first" qm set "$TARGET_VMID" --boot "order=ide2;scsi0"
    msg_ok "VM boot order configured."

    msg_info "Starting VM ${TARGET_VMID} for Ubuntu autoinstall"
    run_cmd "starting VM ${TARGET_VMID} for Ubuntu autoinstall" qm start "$TARGET_VMID"
    msg_ok "VM started for autoinstall."
}

# --- 59. POST-INSTALL CLEANUP ---
post_install_cleanup() {
    if wait_for_vm_poweroff "$TARGET_VMID" "$INSTALL_WAIT_MINUTES"; then
        INSTALL_POWERED_OFF="yes"
    else
        INSTALL_POWERED_OFF="no"
    fi

    if [ "$INSTALL_POWERED_OFF" != "yes" ]; then
        echo ""
        echo -e "${RD}AUTOINSTALL DID NOT REACH POWEROFF BEFORE TIMEOUT.${CL}"
        echo -e "${YW}Leaving installer ISO attached for troubleshooting.${CL}"
        echo -e "${YW}Check the Proxmox console for installer errors.${CL}"
        echo ""
        echo -e "${YW}Useful host checks:${CL}"
        echo -e "${GN}qm config ${TARGET_VMID} | grep -E \"ide2|boot\"${CL}"
        echo -e "${GN}xorriso -indev ${AUTOINSTALL_ISO_PATH} -report_el_torito plain${CL}"
        echo ""
        exit 1
    fi

    section "CLEANUP"

    msg_info "Detaching generated autoinstall ISO from VM"
    run_cmd "detaching installer ISO from VM" qm set "$TARGET_VMID" --delete ide2
    msg_ok "Installer media detached."

    msg_info "Setting VM boot order to installed disk"
    run_cmd "setting VM boot order to installed disk" qm set "$TARGET_VMID" --boot "order=scsi0"
    msg_ok "VM boot order set to installed disk."

    if [ "$DELETE_GENERATED_ISO_AFTER_INSTALL" == "y" ]; then
        msg_info "Deleting generated autoinstall ISO"
        rm -f "$AUTOINSTALL_ISO_PATH"
        msg_ok "Generated autoinstall ISO deleted."
    else
        msg_ok "Generated autoinstall ISO kept by user choice."
    fi

    cleanup_temp_workspace_runtime
    cleanup_iso_generation_tools_runtime
}

# --- 60. START INSTALLED VM AND DETECT IP ---
start_installed_vm_and_detect_ip() {
    if [ "$POST_INSTALL_START_VM" == "y" ]; then
        msg_info "Starting installed Ubuntu VM"
        run_cmd "starting installed Ubuntu VM" qm start "$TARGET_VMID"
        INSTALLED_VM_STARTED_STATUS="Installed Ubuntu VM started."
        msg_ok "$INSTALLED_VM_STARTED_STATUS"

        ASSIGNED_IPV4="$(wait_for_vm_ipv4 "$TARGET_VMID" "$SSH_IP_DETECT_TIMEOUT_SECONDS" "$SSH_IP_CHECK_INTERVAL_SECONDS" || true)"
        ASSIGNED_IPV4="$(printf '%s\n' "$ASSIGNED_IPV4" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | head -n 1 || true)"

        if [ -n "$ASSIGNED_IPV4" ]; then
            SSH_COMMAND="ssh ${TARGET_USERNAME}@${ASSIGNED_IPV4}"
            QEMU_IPV4_STATUS="QEMU Guest Agent reported IPv4 address: ${ASSIGNED_IPV4}"
        else
            QEMU_IPV4_STATUS="QEMU Guest Agent did not report an IPv4 address within ${SSH_IP_DETECT_TIMEOUT_SECONDS}s"
            msg_warn "${QEMU_IPV4_STATUS}"
        fi
    else
        INSTALLED_VM_STARTED_STATUS="Installed Ubuntu VM left powered off by user choice."
        msg_warn "Installed Ubuntu VM was left powered off because user selected no"
    fi
}

# --- 61. WRITE COMPLETION MARKER ---
write_completion_marker() {
    cat > "$COMPLETED_MARKER" <<EOF
Ubuntu Auto Install completed on: $(date)
VMID: $TARGET_VMID
VM Name: $TARGET_VM_NAME
VM MAC: $TARGET_VM_MAC
Hostname: $TARGET_HOSTNAME
Username: $TARGET_USERNAME
Timezone: $TARGET_TIMEZONE
Locale: $TARGET_LOCALE
Keyboard Layout: $TARGET_KEYBOARD_LAYOUT
Keyboard Variant: ${TARGET_KEYBOARD_VARIANT:-none}
Network Mode: $NETWORK_MODE
Source ISO: $INSTALL_ISO_REF
Generated ISO: $AUTOINSTALL_ISO_REF
Install Powered Off: $INSTALL_POWERED_OFF
Install Duration: ${INSTALL_DURATION_TEXT:-not-recorded}
Installer Detached: yes
Boot Order: scsi0
Generated ISO Deleted: $(yn_word "$DELETE_GENERATED_ISO_AFTER_INSTALL")
Installed VM Started: $(yn_word "$POST_INSTALL_START_VM")
Use DHCP: $( [ "$NETWORK_MODE" == "dhcp" ] && echo yes || echo no )
VM Swap Status: $VM_SWAP_STATUS
VM Swap File: $VM_SWAP_FILE
VM Swap Size: $VM_SWAP_SIZE
VM Swap Type: $VM_SWAP_TYPE
Attach Generated ISO And Start VM: $(yn_word "$ATTACH_START_APPROVED")
Start Installed VM After Cleanup: $(yn_word "$POST_INSTALL_START_VM")
Assigned IPv4: ${ASSIGNED_IPV4:-not-detected}
SSH Command: ${SSH_COMMAND:-not-generated}
Verify Log: $VERIFY_LOG
VM Side Marker: $VM_SIDE_MARKER_PATH
VM Side Marker Updated: $VM_SIDE_MARKER_UPDATE_STATUS
SCRIPT35_STATUS=completed
SCRIPT35_VERSION="$SCRIPT_VERSION"
SCRIPT35_BUILD="$SCRIPT_BUILD"
SCRIPT35_MARKER_SCOPE=host
SCRIPT35_MARKER_SOURCE="$SCRIPT_SOURCE"
SCRIPT35_VM_HOSTNAME="$TARGET_HOSTNAME"
SCRIPT35_VM_USERNAME="$TARGET_USERNAME"
SCRIPT35_VM_NETWORK_MODE="$NETWORK_MODE"
SCRIPT35_VM_ASSIGNED_IPV4="${ASSIGNED_IPV4:-not-detected}"
SCRIPT35_VM_MAC="$TARGET_VM_MAC"
SCRIPT35_VM_SWAP_STATUS="$VM_SWAP_STATUS"
SCRIPT35_VM_SWAP_FILE="$VM_SWAP_FILE"
SCRIPT35_VM_SWAP_SIZE="$VM_SWAP_SIZE"
SCRIPT35_VM_SWAP_TYPE="$VM_SWAP_TYPE"
PROXMOX_HOSTNAME="${PROXMOX_HOSTNAME}"
PROXMOX_FQDN="${PROXMOX_FQDN}"
PROXMOX_DOMAIN="${PROXMOX_DOMAIN}"
PROXMOX_LAN_IP="${PROXMOX_LAN_IP}"
PROXMOX_LAN_URL="${PROXMOX_LAN_URL}"
Tools Installed By Script: ${INSTALLED_TOOL_PACKAGES[*]:-none}
ISO Generation Tools Cleanup Enabled: $(yn_word "$CLEANUP_INSTALLED_TOOLS")
ISO Generation Tools Cleanup Done: $(yn_word "$ISO_TOOL_CLEANUP_DONE")
Temporary Workspace Cleanup Enabled: $(yn_word "$CLEANUP_TEMP_WORKFILES")
Temporary Workspace Cleanup Done: $(yn_word "$TEMP_WORKSPACE_CLEANUP_DONE")
EOF
}

# --- 62. HOST VERIFICATION REPORT ---
# Writes a host-side verification report after install cleanup and optional VM start.
create_host_verification_report() {
    cat > "$VERIFY_LOG" <<EOF
--- UBUNTU AUTOINSTALL HOST VERIFICATION REPORT ---
Date: $(date)
VMID: $TARGET_VMID
VM Name: $TARGET_VM_NAME
VM MAC: $TARGET_VM_MAC
Source ISO: $INSTALL_ISO_REF
Generated ISO: $AUTOINSTALL_ISO_REF
Install Powered Off: $INSTALL_POWERED_OFF
Install Duration: ${INSTALL_DURATION_TEXT:-not-recorded}
Post Install Start VM: $(yn_word "$POST_INSTALL_START_VM")
Assigned IPv4: ${ASSIGNED_IPV4:-not-detected}
SSH Command: ${SSH_COMMAND:-not-generated}
VM Side Marker: $VM_SIDE_MARKER_PATH
VM Side Marker Updated: $VM_SIDE_MARKER_UPDATE_STATUS
VM Marker Assigned IPv4: ${ASSIGNED_IPV4:-not-detected}
VM Swap Status: ${VM_SWAP_STATUS}
VM Swap File: ${VM_SWAP_FILE}
VM Swap Size: ${VM_SWAP_SIZE}
VM Swap Type: ${VM_SWAP_TYPE}
Proxmox Hostname: ${PROXMOX_HOSTNAME:-not-detected}
Proxmox FQDN: ${PROXMOX_FQDN:-not-detected}
Proxmox Domain: ${PROXMOX_DOMAIN:-not-detected}
Proxmox LAN IP: ${PROXMOX_LAN_IP:-not-detected}
Proxmox LAN URL: ${PROXMOX_LAN_URL:-not-detected}

Results:
EOF

    {
        PASS() { echo -e "\033[1;92m✓ PASS - $1\033[m"; }
        WARN() { echo -e "\033[33m! WARN - $1\033[m"; }
        FAIL() { echo -e "\033[01;31m✗ FAIL - $1\033[m"; }

        if qm config "$TARGET_VMID" >/dev/null 2>&1; then PASS "VM config exists"; else FAIL "VM config missing"; fi
        if qm config "$TARGET_VMID" 2>/dev/null | grep -q "^boot: order=scsi0"; then PASS "Boot order is installed disk first"; else WARN "Boot order is not confirmed as scsi0"; fi
        if ! qm config "$TARGET_VMID" 2>/dev/null | grep -q "^ide2:"; then PASS "Installer ISO is detached"; else FAIL "Installer ISO still attached on ide2"; fi

        if [ "$INSTALL_POWERED_OFF" == "yes" ]; then PASS "VM powered off after autoinstall"; else FAIL "VM did not power off after autoinstall"; fi

        if [ "$DELETE_GENERATED_ISO_AFTER_INSTALL" == "y" ]; then
            if [ ! -f "$AUTOINSTALL_ISO_PATH" ]; then PASS "Generated autoinstall ISO deleted"; else WARN "Generated autoinstall ISO still exists"; fi
        else
            if [ -f "$AUTOINSTALL_ISO_PATH" ]; then PASS "Generated autoinstall ISO kept as requested"; else WARN "Generated autoinstall ISO not found even though keep was selected"; fi
        fi

        if [ "$POST_INSTALL_START_VM" == "y" ]; then
            if [ "$(get_vm_status "$TARGET_VMID")" == "running" ]; then PASS "Installed VM is running"; else WARN "Installed VM is not running"; fi
            if [ -n "${ASSIGNED_IPV4:-}" ]; then PASS "IPv4 detected through QEMU Guest Agent: ${ASSIGNED_IPV4}"; else WARN "IPv4 was not detected through QEMU Guest Agent"; fi
            if [ -n "${SSH_COMMAND:-}" ]; then PASS "SSH command generated: ${SSH_COMMAND}"; else WARN "SSH command not generated"; fi
        else
            WARN "Installed VM start skipped by user"
        fi

        case "$VM_SWAP_STATUS" in
            detected) PASS "Ubuntu swap detected: ${VM_SWAP_FILE} (${VM_SWAP_SIZE}, ${VM_SWAP_TYPE})" ;;
            not-detected) WARN "Ubuntu swap was not detected" ;;
            *) WARN "Ubuntu swap detection status: ${VM_SWAP_STATUS}" ;;
        esac

        if [ -f "$COMPLETED_MARKER" ]; then PASS "Completion marker exists"; else WARN "Completion marker missing at verification time"; fi
        if [ "$VM_SIDE_MARKER_UPDATE_STATUS" == "yes" ]; then PASS "VM-side marker assigned IPv4 updated: ${ASSIGNED_IPV4}"; else WARN "VM-side marker assigned IPv4 update status: ${VM_SIDE_MARKER_UPDATE_STATUS}"; fi
    } >> "$VERIFY_LOG"

    HOST_VERIFICATION_STATUS="Host verification report created."
}

# --- 63. GENERATED ISO ONLY SUMMARY ---
# Shows a clean summary when user generated the ISO but chose not to attach/start it.
show_generated_iso_only_summary() {
    section "GENERATED ISO READY"

    status_line "VM" "${TARGET_VMID} / ${TARGET_VM_NAME}" "$GN" 16
    status_line "Generated ISO" "$(display_iso_ref "$AUTOINSTALL_ISO_REF")" "$GN" 16
    status_line "Host path" "${AUTOINSTALL_ISO_PATH}" "$GN" 16
    echo ""
    echo -e "${YW}The ISO was generated and verified but was not attached or started.${CL}"
    echo -e "${YW}Run this script again when you are ready to attach it and start autoinstall.${CL}"
    echo ""
}

# --- 64. FINAL OUTPUT ---
show_final_output() {
    local autoinstall_status="not-completed"
    local installed_vm_status="not-started"
    local qemu_agent_ip="not detected"
    local generated_iso_status="kept"
    local workspace_status="kept"
    local tools_status="kept"
    local marker_status="${VM_SIDE_MARKER_UPDATE_STATUS:-not-run}"

    [ "$INSTALL_POWERED_OFF" == "yes" ] && autoinstall_status="completed"
    [ "$POST_INSTALL_START_VM" == "y" ] && installed_vm_status="started"
    [ -n "$ASSIGNED_IPV4" ] && qemu_agent_ip="$ASSIGNED_IPV4"
    [ "$DELETE_GENERATED_ISO_AFTER_INSTALL" == "y" ] && generated_iso_status="deleted"
    [ "$TEMP_WORKSPACE_CLEANUP_DONE" == "yes" ] && workspace_status="cleaned"
    [ "$ISO_TOOL_CLEANUP_DONE" == "yes" ] && tools_status="yes"

    section_flash_success "FINISHED"

    echo -e "${YW}VM:${CL}"
    answer_line "VM" "${TARGET_VM_NAME} (${TARGET_VMID})" 18
    status_line "Hostname" "$TARGET_HOSTNAME" "$GN" 18
    status_line "MAC" "$TARGET_VM_MAC" "$GN" 18
    status_line "IP" "${ASSIGNED_IPV4:-not-detected}" "$GN" 18
    if [ -n "$SSH_COMMAND" ]; then
        status_line "SSH" "$SSH_COMMAND" "$GN" 18
    else
        status_line "SSH" "ssh ${TARGET_USERNAME}@<assigned-ip>" "$GN" 18
    fi
    echo ""

    echo -e "${YW}Proxmox:${CL}"
    status_line "Hostname" "$(proxmox_identity_value_or_not_detected "$PROXMOX_HOSTNAME")" "$GN" 18
    status_line "FQDN" "$(proxmox_identity_value_or_not_detected "$PROXMOX_FQDN")" "$GN" 18
    status_line "Domain" "$(proxmox_identity_value_or_not_detected "$PROXMOX_DOMAIN")" "$GN" 18
    status_line "LAN URL" "$(proxmox_identity_value_or_not_detected "$PROXMOX_LAN_URL")" "$GN" 18
    echo ""

    echo -e "${YW}Install:${CL}"
    status_line "Autoinstall" "$autoinstall_status" "$GN" 18
    status_line "VM powered off" "$(yn_word "$INSTALL_POWERED_OFF")" "$GN" 18
    status_line "Installed VM" "$installed_vm_status" "$GN" 18
    status_line "QEMU agent IP" "$qemu_agent_ip" "$GN" 18
    status_line "Swap" "${VM_SWAP_STATUS:-unknown}" "$GN" 18
    if [ "${VM_SWAP_STATUS:-unknown}" == "detected" ]; then
        status_line "Swap file" "${VM_SWAP_FILE:-unknown}" "$GN" 18
        status_line "Swap size" "${VM_SWAP_SIZE:-unknown}" "$GN" 18
        status_line "Swap type" "${VM_SWAP_TYPE:-unknown}" "$GN" 18
    fi
    if [ -n "${INSTALL_DURATION_TEXT:-}" ]; then
        status_line "Duration" "$INSTALL_DURATION_TEXT" "$GN" 18
    fi
    echo ""

    echo -e "${YW}Files / cleanup:${CL}"
    status_line "Generated ISO" "$generated_iso_status" "$GN" 18
    status_line "Tools cleanup" "$tools_status" "$GN" 18
    status_line "Workspace" "$workspace_status" "$GN" 18
    status_line "VM marker" "${marker_status} / ${VM_SIDE_MARKER_PATH}" "$GN" 18
    status_line "Verify log" "$VERIFY_LOG" "$GN" 18
    echo ""

    if [ -n "${HOST_VERIFICATION_STATUS:-}" ]; then
        echo -e "${CM} ${GN}${HOST_VERIFICATION_STATUS}${CL}"
        echo ""
    fi

    echo -e "${YW}Next Step:${CL}"
    if [ -n "$SSH_COMMAND" ]; then
        status_line "SSH into Ubuntu" "$SSH_COMMAND" "$GN" 22
    else
        status_line "SSH into Ubuntu" "ssh ${TARGET_USERNAME}@<assigned-ip>" "$GN" 22
    fi
    status_line "Run inside Ubuntu" "4-ubuntuVMsetup.sh" "$GN" 22
    echo ""
    echo -e "${FLASH_ON}${RD}DO NOT RUN 4-ubuntuVMsetup.sh ON THE PROXMOX HOST.${FLASH_OFF}${CL}"
    echo ""
}


# =========================================================
#  UI DEMO MODE
# =========================================================

# --- 65. UI DEMO MODE DETECTION ---
# Supports a pure rendering-only demo path before root/Proxmox validation.
is_ui_demo_mode() {
    local arg=""

    [ "${SCRIPT35_UI_DEMO:-0}" = "1" ] && return 0

    for arg in "$@"; do
        [ "$arg" = "--ui-demo" ] && return 0
    done

    return 1
}

# --- 66. UI DEMO SAMPLE DATA ---
# Fixed sample values only; no host, VM, ISO, package or filesystem checks.
setup_ui_demo_sample_data() {
    SCRIPT35_UI_DEMO_ACTIVE="yes"
    TARGET_VM_NAME="circl8-ubuntu"
    TARGET_VMID="108"
    TARGET_VM_MAC="demo-vm-mac"
    VM_STATUS_AT_PREFLIGHT="running"
    VM_SHUTDOWN_APPROVED="yes"
    ATTACH_START_APPROVED="yes"
    ASSIGNED_IPV4="192.0.2.108"
    TARGET_USERNAME="orik"
    TARGET_HOSTNAME="circl8-ubuntu"
    TARGET_TIMEZONE="Europe/London"
    TARGET_LOCALE="en_GB.UTF-8"
    TARGET_KEYBOARD_LAYOUT="gb"
    TARGET_KEYBOARD_VARIANT=""
    NETWORK_MODE="dhcp"
    INSTALL_ISO_REF="local:iso/ubuntu-26.04-live-server-amd64.iso"
    AUTOINSTALL_ISO_REF="local:iso/ubuntu-26.04-autoinstall-vm108.iso"
    GENERATED_ISO_ACTION="create"
    MISSING_TOOL_PACKAGES=()
    INSTALL_MISSING_TOOLS_APPROVED="not-needed"
    INSTALL_WAIT_MINUTES="30"
    SSH_IP_DETECT_TIMEOUT_SECONDS="90"
    POST_INSTALL_START_VM="y"
    DELETE_GENERATED_ISO_AFTER_INSTALL="y"
    CLEANUP_TEMP_WORKFILES="yes"
    CLEANUP_INSTALLED_TOOLS="yes"
    INSTALL_POWERED_OFF="yes"
    INSTALL_DURATION_TEXT="6m 34s"
    INSTALLED_VM_STARTED_STATUS="Installed Ubuntu VM started."
    QEMU_IPV4_STATUS="QEMU Guest Agent reported IPv4 address: 192.0.2.108"
    VM_SWAP_STATUS="detected"
    VM_SWAP_FILE="/swap.img"
    VM_SWAP_SIZE="4G"
    VM_SWAP_TYPE="file"
    HOST_VERIFICATION_STATUS="Host verification report created."
    SSH_COMMAND="ssh orik@192.0.2.108"
}

# --- 67. UI DEMO RENDER HELPERS ---
demo_line() {
    status_line "$1"
}

demo_section_note() {
    echo -e "${YW}UI DEMO MODE:${CL} rendering sample output only. No system changes will be made."
}

demo_cleanup_preferences() {
    section "CLEANUP PREFERENCES"
    demo_line "Remove ISO generation tools after finish: $(yn_word "$CLEANUP_INSTALLED_TOOLS")"
    demo_line "Tools: xorriso p7zip-full"
    demo_line "Delete generated autoinstall ISO after successful install: $(yn_word "$DELETE_GENERATED_ISO_AFTER_INSTALL")"
    demo_line "Remove temporary workspace after finish: $(yn_word "$CLEANUP_TEMP_WORKFILES")"
}

demo_vm_selection() {
    section "VM SELECTION"
    msg_ok "Selected VM: ${TARGET_VM_NAME} (${TARGET_VMID})"
    demo_line "VM MAC address: ${TARGET_VM_MAC}"
    demo_line "Ubuntu network mode: DHCP"
}

demo_identity_locale() {
    section "IDENTITY / LOCALE"
    demo_line "hostname: ${TARGET_HOSTNAME}"
    demo_line "user: ${TARGET_USERNAME}"
    demo_line "timezone: ${TARGET_TIMEZONE}"
    demo_line "locale: ${TARGET_LOCALE}"
    demo_line "keyboard: ${TARGET_KEYBOARD_LAYOUT}"
}

demo_ssh_key_detection() {
    section "SSH KEY DETECTION"
    msg_ok "SSH public key sample detected for ${TARGET_USERNAME}."
}

demo_network_configuration() {
    demo_line "Ubuntu network mode: DHCP"
}

demo_post_install_options() {
    section "POST-INSTALL OPTIONS"
    demo_line "autoinstall wait timeout: ${INSTALL_WAIT_MINUTES} minutes"
    demo_line "VM IPv4 detection timeout: ${SSH_IP_DETECT_TIMEOUT_SECONDS}s"
    demo_line "start installed VM after cleanup: $(yn_word "$POST_INSTALL_START_VM")"
}

demo_iso_selection() {
    section "ISO SELECTION"
    demo_line "source ISO: $(display_iso_ref "$INSTALL_ISO_REF")"
    demo_line "generated ISO: $(display_iso_ref "$AUTOINSTALL_ISO_REF")"
}

demo_ubuntu_pro_note() {
    return 0
}

demo_preflight_questions() {
    section "SETUP PLAN"
    demo_line "generated ISO action: ${GENERATED_ISO_ACTION}"
    demo_line "missing ISO tools: $(missing_iso_tools_display)"
    demo_line "install missing ISO tools: $(install_missing_tools_display)"
    demo_line "VM status before apply: ${VM_STATUS_AT_PREFLIGHT}"
    echo -e "${WARN} ${RD}Starting Ubuntu autoinstall will wipe VM disk.${CL}"
    demo_line "start unattended Ubuntu install: $(attach_start_display)"
}

demo_autoinstall_iso_preparation() {
    section "APPLY CHANGES"
    msg_ok "Existing generated ISO check complete."
    msg_ok "Required ISO tools available."
    msg_ok "Autoinstall configuration created."
    msg_ok "Ubuntu boot configuration extracted."
    msg_ok "Autoinstall boot parameters patched."
    msg_ok "Generated autoinstall ISO created."
    msg_ok "Generated autoinstall ISO verified."
}

demo_ready_to_apply() {
    section "READY TO APPLY"

    echo -e "${YW}VM:${CL}"
    echo -e "  ${GN}${TARGET_VM_NAME} (${TARGET_VMID})${CL}"
    echo -e "  MAC: ${GN}${TARGET_VM_MAC}${CL}"
    echo -e "  status before apply: ${GN}${VM_STATUS_AT_PREFLIGHT}${CL}"
    echo ""

    echo -e "${YW}UBUNTU IDENTITY:${CL}"
    echo -e "  hostname: ${GN}${TARGET_HOSTNAME}${CL}"
    echo -e "  user: ${GN}${TARGET_USERNAME}${CL}"
    echo -e "  timezone: ${GN}${TARGET_TIMEZONE}${CL}"
    echo -e "  locale: ${GN}${TARGET_LOCALE}${CL}"
    echo -e "  keyboard: ${GN}${TARGET_KEYBOARD_LAYOUT}${CL}"
    echo ""

    echo -e "${YW}NETWORK:${CL}"
    echo -e "  mode: ${GN}${NETWORK_MODE}${CL}"
    echo ""

    echo -e "${YW}ISO:${CL}"
    echo -e "  source: ${GN}$(display_iso_ref "$INSTALL_ISO_REF")${CL}"
    echo -e "  generated: ${GN}$(display_iso_ref "$AUTOINSTALL_ISO_REF")${CL}"
    echo -e "  generated ISO action: ${GN}${GENERATED_ISO_ACTION}${CL}"
    echo -e "  missing ISO tools: ${GN}$(missing_iso_tools_display)${CL}"
    echo -e "  install missing ISO tools: ${GN}$(install_missing_tools_display)${CL}"
    echo ""

    echo -e "${YW}INSTALL:${CL}"
    echo -e "  timeout: ${GN}${INSTALL_WAIT_MINUTES} minutes${CL}"
    echo -e "  start VM after cleanup: ${GN}$(yn_word "$POST_INSTALL_START_VM")${CL}"
    echo -e "  IP detection timeout: ${GN}${SSH_IP_DETECT_TIMEOUT_SECONDS}s${CL}"
    echo -e "  start unattended Ubuntu install: ${GN}$(attach_start_display)${CL}"
    echo ""

    echo -e "${YW}Cleanup:${CL}"
    echo -e "  delete generated ISO after install: ${GN}$(yn_word "$DELETE_GENERATED_ISO_AFTER_INSTALL")${CL}"
    echo -e "  remove temporary workspace: ${GN}$(yn_word "$CLEANUP_TEMP_WORKFILES")${CL}"
    echo -e "  remove ISO generation tools after finish: ${GN}$(yn_word "$CLEANUP_INSTALLED_TOOLS")${CL}"
    echo ""
}

demo_preparing_system() {
    msg_ok "VM ${TARGET_VMID} shutdown complete."
    msg_ok "Installer ISO attached."
    msg_ok "VM boot order configured."
    msg_ok "VM started for autoinstall."
}

demo_install_monitoring() {
    section "INSTALL MONITORING"
    echo -e "${BL}Ubuntu autoinstall is running inside:${CL}"
    echo -e "  VM: ${GN}${TARGET_VM_NAME} (${TARGET_VMID})${CL}"
    echo ""
    echo -e "${YW}Waiting for the VM to power off after installation.${CL}"
    echo -e "${RD}Do not manually restart the VM during this stage.${CL}"
    echo ""
    msg_ok "Ubuntu autoinstall completed. (${INSTALL_DURATION_TEXT})"
    msg_ok "VM ${TARGET_VMID} powered off after install."
}

demo_cleanup() {
    section "CLEANUP"
    msg_ok "Installer media detached."
    msg_ok "VM boot order set to installed disk."
    msg_ok "Generated autoinstall ISO deleted."
    msg_ok "Temporary workspace removed."
    msg_ok "ISO generation tools removed: xorriso p7zip-full"
}

demo_final_output() {
    show_final_output
}

# --- 68. UI DEMO ORCHESTRATION ---
# Renders sample output only. It must stay independent of real workflow functions.
run_ui_demo() {
    setup_ui_demo_sample_data
    header_info
    show_script_version
    echo ""
    demo_section_note

    demo_cleanup_preferences
    demo_vm_selection
    demo_identity_locale
    demo_ssh_key_detection
    demo_post_install_options
    demo_iso_selection
    demo_ubuntu_pro_note
    demo_preflight_questions
    demo_autoinstall_iso_preparation
    demo_ready_to_apply
    demo_preparing_system
    demo_install_monitoring
    demo_cleanup
    demo_final_output
}

# =========================================================
#  MAIN ORCHESTRATION
# =========================================================

main() {
    local start_yn=""

    init_script

    check_previous_marker
    section "START"
    show_start_warning
    start_yn="$(timed_yes_no "Start Ubuntu Auto Install ISO Creator?" "y")"

    if [[ "$start_yn" =~ ^[Nn] ]]; then
        exit 0
    fi

    collect_early_cleanup_preferences

    select_vm
    detect_vm_mac
    collect_network_inputs
    collect_user_locale_inputs
    detect_ssh_keys
    collect_post_install_options
    select_ubuntu_iso
    show_ubuntu_pro_note

    collect_vm_shutdown_decision
    collect_generated_iso_action
    collect_missing_iso_tools_decision

    show_apply_summary
    collect_attach_start_decision

    section "APPLY CHANGES"
    ISO_PREP_GROUPED_OUTPUT="yes"
    precheck_generated_iso_reuse

    if [ "$REUSE_EXISTING_AUTOINSTALL_ISO" != "yes" ]; then
        ensure_tools
    fi

    generate_autoinstall_iso
    ISO_PREP_GROUPED_OUTPUT="no"

    if [ "$ATTACH_START_APPROVED" != "yes" ]; then
        show_generated_iso_only_summary
        exit 0
    fi

    attach_iso_and_start_install
    post_install_cleanup
    start_installed_vm_and_detect_ip
    update_vm_side_marker_assigned_ipv4
    write_completion_marker
    create_host_verification_report
    show_final_output
}

if is_ui_demo_mode "$@"; then
    run_ui_demo
    exit 0
fi

main "$@"
