#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Ubuntu VM Setup - Project circl8
# =========================================================
# Purpose:
#   Configure a fresh Ubuntu VM/LXC for the Project circl8 Docker deployment chain.
#
# Design rules:
#   - Phase 1: detect + collect every user answer first.
#   - Phase 2: show a final READY TO APPLY summary.
#   - Phase 3: only then change the system.
#   - Text/path/name/token inputs are untimed; only Y/n prompts use countdowns.
#   - Ubuntu Pro is attached/enabled before the main package upgrade.
#   - Sensitive values are never printed to logs, marker files, or summaries.
#   - Script 1 visual style is preserved.
# =========================================================

# --- 1. COLOR VARIABLES (KEEP ALL FOR FUTURE MODIFICATIONS) ---
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

SCRIPT_SOURCE="4-ubuntuVMsetup.sh"
SCRIPT_VERSION="v2.1.9"
SCRIPT_UPDATED="2026-06-07"
SCRIPT_BUILD="crowdsec-install-parity"

# --- 2. GLOBAL VARIABLES ---
T=15
REBOOT_T=30

LOG_FILE="/var/log/ubuntu-vm-setup.log"
RUNTIME_LOG_FILE=""
VERIFY_LOG="/var/log/ubuntu-vm-setup-verify.log"
VERIFY_DISPLAY_LOG="/var/log/ubuntu-vm-setup-verify-display.log"
POST_REBOOT_VERIFY_HOOK="/etc/profile.d/circl8-script4-post-reboot-verify.sh"
POST_REBOOT_VERIFY_HELPER="/usr/local/sbin/circl8-script4-post-reboot-verify"
POST_REBOOT_VERIFY_MARKER=""
VERIFY_ONLY_MODE="no"
VERIFY_STATUS="not-run"
VERIFY_PASS_COUNT="0"
VERIFY_WARN_COUNT="0"
VERIFY_FAIL_COUNT="0"
VERIFY_FIRST_ISSUE_TYPE=""
VERIFY_FIRST_ISSUE_CHECK=""
VERIFY_FIRST_ISSUE_REASON=""
VERIFY_FIRST_ISSUE_FIX=""
COMPLETED_MARKER="/root/.ubuntu-vm-setup-completed"

DEFAULT_USERNAME="${DEFAULT_USERNAME:-orik}"

SUDO_CMD=""
TEMP_FILES=()
LOGGING_ENABLED="no"

IS_CONTAINER="no"
IS_LXC="no"
IS_VM="no"
VIRT_TYPE="unknown"
ROOT_KEYS="/root/.ssh/authorized_keys"
CURRENT_USER_KEYS=""
SOURCE_KEYS=""
DEST_KEYS=""

USERNAME=""
LOCK_USER_PASSWORD="y"
ATTACH_UBUNTU_PRO="n"
PRO_TOKEN=""
ENABLE_ESM_APPS="y"
ENABLE_ESM_INFRA="y"
ENABLE_LIVEPATCH="y"
RUN_SYSTEM_UPDATE="y"
INSTALL_QEMU_AGENT="y"
EXPAND_ROOT_LVM="y"
CONFIGURE_UFW="y"
ENABLE_CROWDSEC="y"
APPLY_SSH_HARDENING="y"
RUN_SYSTEM_CLEANUP="y"
REBOOT_AFTER_FINISH="y"

EXISTING_USER="no"
SUDO_USER_CREATED="no"
USER_ADDED_TO_SUDO="no"
USER_PASSWORD_LOCKED="no"
SSH_KEYS_CONFIGURED="no"
SSH_HARDENING_APPLIED="no"
QEMU_AGENT_INSTALLED="no"
UFW_ENABLED="no"
CROWDSEC_PACKAGE_INSTALLED="no"
CROWDSEC_SERVICE_STATUS="no"
CROWDSEC_COLLECTIONS_STATUS="no"
CROWDSEC_BOUNCER_PACKAGE="none"
CROWDSEC_BOUNCER_STATUS="none"
UNATTENDED_UPGRADES_CONFIGURED="no"
ROOT_EXPANDED="no"
UBUNTU_PRO_ATTACHED="no"
UBUNTU_PRO_ESM_APPS="not-requested"
UBUNTU_PRO_ESM_INFRA="not-requested"
UBUNTU_PRO_LIVEPATCH="not-requested"
SYSTEM_UPDATED="no"
SYSTEM_CLEANED="no"

ROOT_SOURCE=""
ROOT_LV_PATH=""
VG_NAME=""
VG_FREE_BYTES="0"
ROOT_FS_BEFORE_GB="unknown"
ROOT_FS_AFTER_GB="unknown"
APPLY_CHANGES_SECTION_SHOWN="no"
APPLY_CURRENT_GROUP=""

# =========================================================
#  OUTPUT / LOGGING FUNCTIONS
# =========================================================

# --- 3. HEADER FUNCTION ---
function header_info {
echo -e "${BL}
  ██╗   ██╗ ███╗   ███╗    ███████╗ ███████╗ ████████╗ ██╗   ██╗ ██████╗
  ██║   ██║ ████╗ ████║    ██╔════╝ ██╔════╝ ╚══██╔══╝ ██║   ██║ ██╔══██╗
  ██║   ██║ ██╔████╔██║    ███████╗ █████╗      ██║    ██║   ██║ ██████╔╝
  ╚██╗ ██╔╝ ██║╚██╔╝██║    ╚════██║ ██╔══╝      ██║    ██║   ██║ ██╔═══╝
   ╚████╔╝  ██║ ╚═╝ ██║    ███████║ ███████╗    ██║    ╚██████╔╝ ██║
    ╚═══╝   ╚═╝     ╚═╝    ╚══════╝ ╚══════╝    ╚═╝     ╚═════╝  ╚═╝
${CL}"
}

# --- 4. MESSAGE HELPERS ---
function msg_info() { local text="${1:-}"; echo -ne " ${HOLD} ${YW}${text}...${CL}"; }
function msg_ok() { local text="${1:-}"; echo -e "${BFR} ${CM} ${GN}${text}${CL}"; }
function msg_warn() { local text="${1:-}"; echo -e "${BFR} ${WARN} ${YW}${text}${CL}"; }
function msg_skip() { local text="${1:-}"; echo -e "${BFR} - ${BL}INFO${CL} - ${YW}${text}${CL}"; }
function msg_error() { local text="${1:-Unknown error}"; echo -e "${BFR} ${CROSS} ${RD}${text}${CL}"; exit 1; }

# --- SCRIPT VERSION DISPLAY ---
# Prints the currently running script version immediately under the ASCII banner.
function show_script_version() {
    echo -e "${GN}SCRIPT VERSION: ${SCRIPT_VERSION} | UPDATED: ${SCRIPT_UPDATED} | BUILD: ${SCRIPT_BUILD}${CL}"
    echo -e "${BL}SOURCE: ${SCRIPT_SOURCE}${CL}"
}

# --- 5. SECTION HEADER HELPER ---
function section() {
    echo ""
    echo -e "${BORDER}"
    echo -e "${BL}$1${CL}"
    echo -e "${BORDER}"
}

# --- 5A. FLASHING SUCCESS SECTION HEADER HELPER ---
function section_flash_success() {
    echo ""
    echo -e "${BORDER}"
    echo -e "${GN}${CLF}$1${CL}"
    echo -e "${BORDER}"
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

    APPLY_CURRENT_GROUP="$title"
    echo ""
    echo -e "${YW}${title}:${CL}"
}

function bytes_to_gb_display() {
    local bytes="${1:-0}"

    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "unknown"
        return 0
    fi

    awk -v b="$bytes" 'BEGIN { printf "%.2f GB", b / 1024 / 1024 / 1024 }'
}

function get_root_filesystem_size_gb() {
    local size_kb=""

    size_kb="$(df -k / 2>/dev/null | awk 'NR==2 {print $2; exit}' || true)"
    if [[ "$size_kb" =~ ^[0-9]+$ ]]; then
        awk -v kb="$size_kb" 'BEGIN { printf "%.2f GB", kb / 1024 / 1024 }'
    else
        echo "unknown"
    fi
}

# --- 5B. DETAIL LINE HELPER ---
function detail_line() {
    local label="${1:-}"
    local value="${2:-}"
    echo -e " ${BL}━━━━━▶${CL} ${label}: ${GN}${value}${CL}"
}

# --- 6. TTY PRINT HELPERS ---
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

# --- 7. INPUT BUFFER FLUSH HELPER ---
function flush_input_buffer() {
    local junk=""
    local i=""

    [ -r /dev/tty ] || return 0

    for i in {1..20}; do
        if ! IFS= read -rsn1 -t 0.02 junk < /dev/tty 2>/dev/null; then
            break
        fi
    done

    return 0
}

# =========================================================
#  CLEANUP / ERROR HANDLING
# =========================================================

# --- 8. CLEANUP FUNCTION ---
function cleanup() {
    local exit_code="$?"
    local file=""

    stty sane < /dev/tty 2>/dev/null || true

    if [ -n "${SUDO_CMD:-}" ] && [ -n "${RUNTIME_LOG_FILE:-}" ] && [ -s "$RUNTIME_LOG_FILE" ]; then
        "$SUDO_CMD" cp "$RUNTIME_LOG_FILE" "$LOG_FILE" 2>/dev/null || true
        "$SUDO_CMD" chmod 0644 "$LOG_FILE" 2>/dev/null || true
    fi

    for file in "${TEMP_FILES[@]:-}"; do
        [ -n "$file" ] && [ -f "$file" ] && rm -f "$file" 2>/dev/null || true
    done

    exit "$exit_code"
}

# --- 9. ERROR TRAP HELPER ---
function on_error() {
    local line_no="${1:-unknown}"
    echo -e "${RD}ERROR:${CL} Script failed at line ${line_no}. Check ${LOG_FILE}"
}

# --- 10. COMMAND RUNNER ---
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
function run_optional() {
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" "$@" >/dev/null 2>&1 || true
    else
        "$@" >/dev/null 2>&1 || true
    fi
}

# --- 12. ROOT FILE HELPERS ---
function root_file_exists() {
    local path="$1"
    if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" test -f "$path"; else test -f "$path"; fi
}

function root_grep_quiet() {
    local pattern="$1"
    local path="$2"
    if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" grep -Eq "$pattern" "$path"; else grep -Eq "$pattern" "$path"; fi
}

function root_cat_file() {
    local path="$1"
    if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" cat "$path"; else cat "$path"; fi
}

function root_append_line() {
    local path="$1"
    local line="$2"
    if [ -n "$SUDO_CMD" ]; then
        printf '%s\n' "$line" | "$SUDO_CMD" tee -a "$path" >/dev/null
    else
        printf '%s\n' "$line" >> "$path"
    fi
}

function get_effective_sshd_config() {
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" sshd -T -C user="${USERNAME:-root}",host=localhost,addr=127.0.0.1 2>/dev/null || true
    else
        sshd -T -C user="${USERNAME:-root}",host=localhost,addr=127.0.0.1 2>/dev/null || true
    fi
}

# =========================================================
#  LOGGING CONTROL
# =========================================================

# --- 13. LOGGING CONTROL ---
function disable_logging() {
    if [ -w /dev/tty ]; then
        exec > /dev/tty 2> /dev/tty
    else
        exec >&3 2>&4
    fi
    LOGGING_ENABLED="no"
}

function enable_logging() {
    if [ -n "$RUNTIME_LOG_FILE" ]; then
        exec > >(tee -a "$RUNTIME_LOG_FILE") 2>&1
    else
        exec > >(tee -a "$LOG_FILE") 2>&1
    fi
    LOGGING_ENABLED="yes"
}

# =========================================================
#  PROMPT FUNCTIONS
# =========================================================

# --- 14. YES/NO LABEL HELPER ---
function yes_no_label() {
    local value="${1:-n}"
    if [[ "$value" =~ ^[Yy]$ ]]; then echo "yes"; else echo "no"; fi
}

# --- 15. BLOCKING YES/NO HELPER ---
function tty_read_yes_no_blocking() {
    local prompt="$1"
    local default="$2"
    local default_label="Y/n"
    local key=""

    if [[ "$default" =~ ^[Nn]$ ]]; then default_label="y/N"; fi

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

# --- 16. TIMED YES/NO PROMPT HELPER ---
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

    if [[ "$default" =~ ^[Nn]$ ]]; then default_label="y/N"; fi

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
                case "$key" in
                    " ") answer="$(tty_read_yes_no_blocking "$prompt" "$default")"; break ;;
                    [YyNn]) answer="$key"; flush_input_buffer; break ;;
                    "") answer="$default"; flush_input_buffer; break ;;
                esac
            fi
        else
            if IFS= read -rsn1 -t 1 key; then
                case "$key" in
                    " ") answer="$(tty_read_yes_no_blocking "$prompt" "$default")"; break ;;
                    [YyNn]) answer="$key"; flush_input_buffer; break ;;
                    "") answer="$default"; flush_input_buffer; break ;;
                esac
            fi
        fi
    done

    [ -z "$answer" ] && answer="$default"
    final_label="$(yes_no_label "$answer")"

    tty_print "${BFR}"
    tty_println "${CM} ${GN}${prompt}${CL} ${ANS}${final_label}${CL}"
    flush_input_buffer

    echo "$answer"
}

# --- 17. EDITABLE INPUT LOOP HELPER ---
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
            $'\177'|$'\b') answer="${answer%?}" ;;
            *) answer+="$key" ;;
        esac
    done
}

# --- 18. TEXT INPUT HELPER ---
# Text/path/name inputs are intentionally untimed.
# Yes/no prompts keep countdown timers, but anything the user may need to type or paste waits normally.
function timed_text_input() {
    local prompt="$1"
    local default="$2"
    local answer=""

    # Text/path/name inputs are deliberately NOT timed.
    # Countdown prompts are reserved only for simple Y/n decisions.
    # This prevents defaults being accepted while the user is away and gives enough time to type/paste.
    answer="$(editable_input_loop "$prompt" "$default" "")"
    [ -z "$answer" ] && answer="$default"

    tty_print "${BFR}"
    tty_println "${CM} ${GN}${prompt}${CL} ${ANS}${answer}${CL}"
    flush_input_buffer 2>/dev/null || true

    echo "$answer"
}

# --- 19. SENSITIVE LINE INPUT HELPER ---
function sensitive_line_input() {
    local prompt="$1"
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

    printf '%s' "$answer"
}

# --- 20. REBOOT COUNTDOWN HELPER ---
function timed_reboot_countdown() {
    local seconds="$1"
    local key=""
    local deadline=""
    local now=""
    local remaining=""
    local first_draw="yes"

    flush_input_buffer
    deadline=$(( $(date +%s) + seconds ))

    while true; do
        now=$(date +%s)
        remaining=$(( deadline - now ))

        if [ "$remaining" -le 0 ]; then
            [ "$first_draw" == "no" ] && tty_print "\033[2A\033[2K\r\033[1B\033[2K\r\033[1A"
            return 0
        fi

        if [ "$first_draw" == "yes" ]; then
            first_draw="no"
        else
            tty_print "\033[2A\033[2K\r\033[1B\033[2K\r\033[1A"
        fi

        tty_print "${BL}${CLF}REBOOTING IN ${remaining} SECONDS...${CL}\n${YW}(ENTER/Y = Reboot Now, SPACE/N = Cancel)${CL}\n"

        key=""
        if [ -r /dev/tty ]; then
            if IFS= read -rsn1 -t 1 key < /dev/tty; then
                case "$key" in
                    ""|[Yy])
                        tty_print "\033[2A\033[2K\r\033[1B\033[2K\r\033[1A"
                        tty_println "${BL}${CLF}REBOOTING NOW...${CL}"
                        return 0
                        ;;
                    " "|[Nn])
                        tty_print "\033[2A\033[2K\r\033[1B\033[2K\r\033[1A"
                        tty_println "${YW}Reboot countdown stopped. Reboot manually when ready.${CL}"
                        return 1
                        ;;
                esac
            fi
        else
            sleep 1
        fi
    done
}

# =========================================================
#  VALIDATION / INIT
# =========================================================

# --- 21. USERNAME VALIDATION HELPER ---
function validate_linux_username() {
    local username="$1"
    [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

# --- 22. DEPENDENCY VALIDATION ---
function validate_dependencies() {
    local required_commands=(
        apt-get awk cat chmod chown cp date findmnt grep id mkdir mktemp
        passwd readlink sed sleep sshd systemctl tee useradd usermod xargs
    )
    local cmd=""

    for cmd in "${required_commands[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || msg_error "Required command not found: ${cmd}"
    done

    if [ -n "$SUDO_CMD" ]; then
        command -v sudo >/dev/null 2>&1 || msg_error "sudo is required when not running as root."
    fi
}

# --- 23. ROOT / SUDO DETECTION ---
function detect_root_or_sudo() {
    if [ "$EUID" -eq 0 ]; then SUDO_CMD=""; else SUDO_CMD="sudo"; fi
}

# --- 24. SUDO VALIDATION ---
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
function init_logging() {
    exec 3>&1
    exec 4>&2

    if [ -n "$SUDO_CMD" ]; then
        RUNTIME_LOG_FILE="$(mktemp /tmp/ubuntu-vm-setup-log.XXXXXX)"
        TEMP_FILES+=("$RUNTIME_LOG_FILE")
        exec > >(tee -a "$RUNTIME_LOG_FILE") 2>&1
    else
        RUNTIME_LOG_FILE="$LOG_FILE"
        exec > >(tee -a "$LOG_FILE") 2>&1
    fi

    LOGGING_ENABLED="yes"
}

# --- 26. SCRIPT 4 ENVIRONMENT GUARD ---
# Refuses to run on Proxmox/PVE and only allows Ubuntu VM environments.
# This guard runs before logging, package operations, user/group changes, services or firewall changes.
function detect_proxmox_host() {
    command -v pveversion >/dev/null 2>&1 && return 0
    [ -d /etc/pve ] && return 0
    [ -f /etc/pve/storage.cfg ] && return 0
    dpkg -l 2>/dev/null | grep -q '^ii[[:space:]]\+pve-manager[[:space:]]' && return 0

    return 1
}

function detect_ubuntu_os() {
    local os_id="unknown"

    if [ -r /etc/os-release ]; then
        os_id="$(awk -F= '$1 == "ID" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release 2>/dev/null || true)"
    fi

    [ "${os_id:-unknown}" == "ubuntu" ]
}

function get_detected_os_id() {
    local os_id="unknown"

    if [ -r /etc/os-release ]; then
        os_id="$(awk -F= '$1 == "ID" { gsub(/"/, "", $2); print $2; exit }' /etc/os-release 2>/dev/null || true)"
    fi

    echo "${os_id:-unknown}"
}

function extract_first_ipv4() {
    printf '%s\n' "$*" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1 || true
}

function extract_first_ssh_command() {
    printf '%s\n' "$*" | grep -Eo '^ssh[[:space:]]+[^[:space:]@]+@([0-9]{1,3}\.){3}[0-9]{1,3}$|ssh[[:space:]]+[^[:space:]@]+@([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1 || true
}

function marker_value() {
    local label="$1"
    local file="$2"

    [ -r "$file" ] || return 0
    awk -F': ' -v label="$label" '$1 == label { $1=""; sub(/^: /, ""); print; exit }' "$file" 2>/dev/null | xargs || true
}

function marker_value_or_unknown_for_display() {
    local label="$1"
    local file="$2"
    local value=""

    if root_file_exists "$file"; then
        value="$(root_cat_file "$file" 2>/dev/null | awk -F': ' -v label="$label" '$1 == label { $1=""; sub(/^: /, ""); print; exit }' | xargs || true)"
    fi

    [ -n "$value" ] || value="unknown"
    echo "$value"
}

function show_previous_marker_compact_summary() {
    local marker_file="$1"
    local completed=""
    local username=""
    local virt_type=""
    local is_container=""
    local is_vm=""
    local environment="unknown"

    completed="$(marker_value_or_unknown_for_display "Ubuntu VM Setup completed on" "$marker_file")"
    username="$(marker_value_or_unknown_for_display "Username" "$marker_file")"
    virt_type="$(marker_value_or_unknown_for_display "Virt Type" "$marker_file")"
    is_container="$(marker_value_or_unknown_for_display "Container" "$marker_file")"
    is_vm="$(marker_value_or_unknown_for_display "VM" "$marker_file")"

    if [ "$is_container" == "yes" ]; then
        environment="Container (${virt_type})"
    elif [ "$is_vm" == "yes" ]; then
        environment="VM (${virt_type})"
    elif [ "$virt_type" != "unknown" ]; then
        environment="$virt_type"
    fi

    echo -e "${YW}Existing setup:${CL}"
    echo -e "  ${BL}Completed:${CL} ${GN}${completed}${CL}"
    echo -e "  ${BL}Username:${CL} ${GN}${username}${CL}"
    echo -e "  ${BL}Environment:${CL} ${GN}${environment}${CL}"
    echo -e "  ${BL}SSH keys:${CL} ${GN}$(marker_value_or_unknown_for_display "SSH Keys Configured" "$marker_file")${CL}"
    echo -e "  ${BL}SSH hardened:${CL} ${GN}$(marker_value_or_unknown_for_display "SSH Hardened" "$marker_file")${CL}"
    echo -e "  ${BL}Root expanded:${CL} ${GN}$(marker_value_or_unknown_for_display "Root Expanded" "$marker_file")${CL}"
    echo -e "  ${BL}UFW firewall:${CL} ${GN}$(marker_value_or_unknown_for_display "UFW" "$marker_file")${CL}"
    echo -e "  ${BL}CrowdSec:${CL} ${GN}$(marker_value_or_unknown_for_display "CrowdSec Service" "$marker_file")${CL}"
    echo -e "  ${BL}QEMU guest agent:${CL} ${GN}$(marker_value_or_unknown_for_display "QEMU Agent" "$marker_file")${CL}"
    echo -e "  ${BL}Verify log:${CL} ${GN}$(marker_value_or_unknown_for_display "Verify Log" "$marker_file")${CL}"
}

function marker_key_value_or_empty() {
    local key="$1"
    local file="$2"
    local value=""

    if root_file_exists "$file"; then
        value="$(root_cat_file "$file" 2>/dev/null | awk -F= -v key="$key" '$1 == key { $1=""; sub(/^=/, ""); print; exit }' | xargs || true)"
    fi

    echo "$value"
}

function previous_marker_action_menu() {
    local action=""
    local action_label=""

    while true; do
        tty_println "  ${YW}1)${CL} Verify existing setup"
        tty_println "  ${YW}2)${CL} Re-run Ubuntu VM setup"
        tty_println "  ${YW}3)${CL} Exit"
        tty_println ""
        tty_print "${YW}Select action [default: 1]: ${CL}"

        if [ -r /dev/tty ]; then
            IFS= read -r action < /dev/tty || action=""
        else
            IFS= read -r action || action=""
        fi

        action="$(printf '%s' "$action" | tr -d '
' | xargs || true)"
        [ -z "$action" ] && action="1"

        case "$action" in
            1) action_label="Verify existing setup" ;;
            2) action_label="Re-run Ubuntu VM setup" ;;
            3) action_label="Exit" ;;
            *)
                tty_println "${WARN} ${YW}Invalid action. Choose 1, 2, or 3.${CL}"
                tty_println ""
                continue
                ;;
        esac

        tty_println "${CM} ${GN}Selected action:${CL} ${ANS}${action_label}${CL}"
        echo "$action"
        return 0
    done
}

function build_ssh_hint_from_marker() {
    local marker="/root/.ubuntu-autoinstall-seed-completed"
    local marker_text=""
    local username=""
    local assigned_raw=""
    local ssh_raw=""
    local ssh_command=""
    local assigned_ipv4=""
    local vmid=""
    local vm_name=""

    SCRIPT4_SSH_HINT_COMMAND="ssh <ubuntu-user>@<vm-ip>"
    SCRIPT4_SSH_HINT_SOURCE="none"
    SCRIPT4_SSH_HINT_VMID=""
    SCRIPT4_SSH_HINT_VM_NAME=""
    SCRIPT4_SSH_HINT_IP=""

    [ -r "$marker" ] || return 0

    marker_text="$(cat "$marker" 2>/dev/null || true)"
    username="$(marker_value "Username" "$marker")"
    assigned_raw="$(marker_value "Assigned IPv4" "$marker")"
    ssh_raw="$(marker_value "SSH Command" "$marker")"
    vmid="$(marker_value "VMID" "$marker")"
    vm_name="$(marker_value "VM Name" "$marker")"

    ssh_command="$(extract_first_ssh_command "$ssh_raw")"
    assigned_ipv4="$(extract_first_ipv4 "$assigned_raw")"

    if [ -z "$assigned_ipv4" ]; then
        assigned_ipv4="$(extract_first_ipv4 "$marker_text")"
    fi

    if [ -z "$ssh_command" ] && [ -n "$username" ] && [ -n "$assigned_ipv4" ]; then
        ssh_command="ssh ${username}@${assigned_ipv4}"
    fi

    if [ -n "$ssh_command" ]; then
        SCRIPT4_SSH_HINT_COMMAND="$ssh_command"
        SCRIPT4_SSH_HINT_SOURCE="Script 3.5 completion marker"
        SCRIPT4_SSH_HINT_VMID="$vmid"
        SCRIPT4_SSH_HINT_VM_NAME="$vm_name"
        SCRIPT4_SSH_HINT_IP="$assigned_ipv4"
    fi
}

function print_proxmox_correct_location_hint() {
    build_ssh_hint_from_marker

    echo -e "${BL}Correct location:${CL}"
    echo -e "  SSH into the Ubuntu VM first:"
    echo -e "    ${GN}${SCRIPT4_SSH_HINT_COMMAND}${CL}"

    if [ "$SCRIPT4_SSH_HINT_SOURCE" == "Script 3.5 completion marker" ]; then
        echo ""
        echo -e "${BL}Detected from Script 3.5 completion marker:${CL}"
        if [ -n "$SCRIPT4_SSH_HINT_VM_NAME" ] || [ -n "$SCRIPT4_SSH_HINT_VMID" ]; then
            echo -e "  VM:  ${GN}${SCRIPT4_SSH_HINT_VM_NAME:-unknown} (${SCRIPT4_SSH_HINT_VMID:-unknown})${CL}"
        fi
        if [ -n "$SCRIPT4_SSH_HINT_IP" ]; then
            echo -e "  IP:  ${GN}${SCRIPT4_SSH_HINT_IP}${CL}"
        fi
    fi
}

function guard_script4_environment() {
    local os_id=""

    if detect_proxmox_host; then
        echo -e "${RD}ERROR: This script must run inside the Ubuntu VM, not on the Proxmox host.${CL}"
        echo ""
        echo -e "${RD}Detected Proxmox/PVE environment.${CL}"
        echo -e "${YW}Stop here.${CL}"
        echo ""
        print_proxmox_correct_location_hint
        echo ""
        echo -e "Then run:"
        echo -e "  ${GN}4-ubuntuVMsetup.sh${CL}"
        exit 1
    fi

    if ! detect_ubuntu_os; then
        os_id="$(get_detected_os_id)"
        echo -e "${RD}ERROR: This script is intended for the Ubuntu VM only.${CL}"
        echo -e "${YW}Detected OS: ${os_id}${CL}"
        exit 1
    fi
}

function is_environment_check_mode() {
    local arg=""

    [ "${SCRIPT4_CHECK_ENV:-0}" = "1" ] && return 0

    for arg in "$@"; do
        [ "$arg" = "--check-environment" ] && return 0
    done

    return 1
}

# --- 26. SCRIPT INITIALIZATION ---
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

# --- 27. PREVIOUS MARKER CHECK ---
function check_previous_marker() {
    local marker_action=""

    if root_file_exists "$COMPLETED_MARKER"; then
        section "PREVIOUS UBUNTU VM SETUP MARKER DETECTED"

        show_previous_marker_compact_summary "$COMPLETED_MARKER"
        echo ""
        echo -e "${YW}Action:${CL}"

        marker_action="$(previous_marker_action_menu)"

        case "$marker_action" in
            1)
                run_verify_only_mode
                exit 0
                ;;
            2)
                return 0
                ;;
            3)
                exit 0
                ;;
            *)
                return 0
                ;;
        esac
    fi

    return 0
}

# =========================================================
#  PHASE 1: DETECTION + INPUT COLLECTION
# =========================================================

# --- 28. ENVIRONMENT DETECTION ---
function detect_environment() {
    section "ENVIRONMENT CHECK"

    msg_info "Detecting environment"

    IS_CONTAINER="no"
    IS_LXC="no"
    IS_VM="no"
    VIRT_TYPE="unknown"

    if command -v systemd-detect-virt >/dev/null 2>&1; then
        VIRT_TYPE="$(systemd-detect-virt 2>/dev/null || echo "none")"

        if systemd-detect-virt --container --quiet 2>/dev/null; then
            IS_CONTAINER="yes"
            [ "$VIRT_TYPE" == "lxc" ] && IS_LXC="yes"
        elif systemd-detect-virt --vm --quiet 2>/dev/null; then
            IS_VM="yes"
        fi
    fi

    if [ "$VIRT_TYPE" == "unknown" ] || [ "$VIRT_TYPE" == "none" ]; then
        if grep -qa container=lxc /proc/1/environ 2>/dev/null; then
            IS_CONTAINER="yes"
            IS_LXC="yes"
            VIRT_TYPE="lxc"
        elif [ -d /sys/class/dmi/id ] && grep -qiE "qemu|kvm|vmware|virtualbox|hyper-v" /sys/class/dmi/id/product_name 2>/dev/null; then
            IS_VM="yes"
            VIRT_TYPE="vm"
        else
            VIRT_TYPE="${VIRT_TYPE:-unknown}"
            IS_VM="yes"
        fi
    fi

    if [ "$IS_CONTAINER" == "yes" ]; then
        msg_ok "ENVIRONMENT DETECTED (${VIRT_TYPE} container)"
    elif [ "$IS_VM" == "yes" ]; then
        msg_ok "ENVIRONMENT DETECTED (${VIRT_TYPE} VM)"
    else
        IS_VM="yes"
        msg_warn "Environment unclear (${VIRT_TYPE}); continuing with VM-safe defaults"
    fi
}

# --- 29. START CONFIRMATION ---
function start_confirmation() {
    local start_yn=""

    section "START"

    echo -e "${YW}Ubuntu VM setup can configure SSH keys, QEMU guest agent,${CL}"
    echo -e "${YW}root disk expansion, UFW, SSH hardening, and optional Ubuntu Pro.${CL}"

    if [ "$IS_CONTAINER" == "yes" ]; then
        echo -e "${YW}Container mode detected: QEMU Guest Agent and root LVM expansion will be skipped.${CL}"
    fi

    echo ""

    start_yn="$(timed_yes_no "Start the Ubuntu VM Setup Script?" "y")"
    [[ "$start_yn" =~ ^[Nn] ]] && exit 0

    return 0
}

# --- 30. USERNAME INPUT ---
function collect_username() {
    section "SETUP OPTIONS"

    while true; do
        USERNAME="$(timed_text_input "Enter username" "$DEFAULT_USERNAME")"

        if validate_linux_username "$USERNAME"; then
            break
        fi

        msg_warn "Invalid username. Use lowercase Linux username format, for example: orik"
    done

    if id "$USERNAME" >/dev/null 2>&1; then
        EXISTING_USER="yes"
    else
        EXISTING_USER="no"
    fi

    CURRENT_USER_KEYS="/home/${USERNAME}/.ssh/authorized_keys"

    if [ -s "$CURRENT_USER_KEYS" ]; then
        SOURCE_KEYS="$CURRENT_USER_KEYS"
    elif [ -s "$ROOT_KEYS" ]; then
        SOURCE_KEYS="$ROOT_KEYS"
    else
        SOURCE_KEYS=""
    fi

    LOCK_USER_PASSWORD="$(timed_yes_no "Lock password for SSH-key-only user?" "y")"
    APPLY_SSH_HARDENING="$(timed_yes_no "Apply SSH key-only hardening after keys are verified?" "y")"

    return 0
}

# --- 31. UBUNTU PRO INPUTS ---
function collect_ubuntu_pro_inputs() {
    echo ""
    echo -e "${YW}Ubuntu Pro:${CL}"

    echo -e "${BL}Ubuntu Pro is optional. If enabled, this script attaches Pro before the main system upgrade.${CL}"
    echo -e "${BL}Token input is not logged and is never written to disk by this script.${CL}"
    echo ""

    ATTACH_UBUNTU_PRO="$(timed_yes_no "Attach Ubuntu Pro token?" "n")"

    if [[ "$ATTACH_UBUNTU_PRO" =~ ^[Yy] ]]; then
        disable_logging

        if [ -n "${UBUNTU_PRO_TOKEN:-}" ]; then
            PRO_TOKEN="$UBUNTU_PRO_TOKEN"
            unset UBUNTU_PRO_TOKEN
        else
            PRO_TOKEN="$(sensitive_line_input "Enter Ubuntu Pro token")"
        fi

        enable_logging

        PRO_TOKEN="$(printf '%s' "$PRO_TOKEN" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

        if [ -z "$PRO_TOKEN" ]; then
            msg_warn "Ubuntu Pro token was empty; Ubuntu Pro attachment will be skipped"
            ATTACH_UBUNTU_PRO="n"
            ENABLE_ESM_APPS="n"
            ENABLE_ESM_INFRA="n"
            ENABLE_LIVEPATCH="n"
            return 0
        fi

        ENABLE_ESM_APPS="$(timed_yes_no "Enable Ubuntu Pro ESM Apps?" "y")"
        ENABLE_ESM_INFRA="$(timed_yes_no "Enable Ubuntu Pro ESM Infra?" "y")"
        ENABLE_LIVEPATCH="$(timed_yes_no "Enable Ubuntu Pro Livepatch?" "y")"
    else
        ENABLE_ESM_APPS="n"
        ENABLE_ESM_INFRA="n"
        ENABLE_LIVEPATCH="n"
    fi

    return 0
}

# --- 32. SYSTEM ACTION INPUTS ---
function collect_system_action_inputs() {
    echo ""
    echo -e "${YW}System:${CL}"

    RUN_SYSTEM_UPDATE="$(timed_yes_no "Run apt update and full upgrade?" "y")"

    if [ "$IS_CONTAINER" == "yes" ]; then
        INSTALL_QEMU_AGENT="n"
        EXPAND_ROOT_LVM="n"
        CONFIGURE_UFW="$(timed_yes_no "Attempt UFW firewall setup inside LXC/container?" "n")"
    else
        INSTALL_QEMU_AGENT="$(timed_yes_no "Install and enable QEMU Guest Agent?" "y")"
        EXPAND_ROOT_LVM="$(timed_yes_no "Expand root LVM filesystem if free space exists?" "y")"
        CONFIGURE_UFW="$(timed_yes_no "Install and enable UFW firewall baseline?" "y")"
    fi

    RUN_SYSTEM_CLEANUP="$(timed_yes_no "Run package cleanup at the end?" "y")"
    REBOOT_AFTER_FINISH="$(timed_yes_no "Reboot automatically after setup finishes?" "y")"

    return 0
}

# --- 33. READY SUMMARY ---
function show_ready_summary_and_confirm() {
    local apply_yn=""

    section "SETUP PLAN"

    echo -e "${YW}User / SSH:${CL}"
    echo -e "  ${BL}Username:${CL} ${ANS}${USERNAME}${CL}"
    echo -e "  ${BL}Existing user:${CL} ${ANS}${EXISTING_USER}${CL}"
    echo -e "  ${BL}SSH key source:${CL} ${ANS}${SOURCE_KEYS:-none detected}${CL}"
    echo -e "  ${BL}Lock password login:${CL} ${ANS}$(yes_no_label "$LOCK_USER_PASSWORD")${CL}"
    echo -e "  ${BL}SSH hardening:${CL} ${ANS}$(yes_no_label "$APPLY_SSH_HARDENING")${CL}"
    if [ "$IS_CONTAINER" == "yes" ]; then
        echo -e "  ${BL}Environment:${CL} ${ANS}Container/LXC (${VIRT_TYPE})${CL}"
    else
        echo -e "  ${BL}Environment:${CL} ${ANS}VM (${VIRT_TYPE})${CL}"
    fi

    echo ""
    echo -e "${YW}Ubuntu Pro:${CL}"
    echo -e "  ${BL}Attach:${CL} ${ANS}$(yes_no_label "$ATTACH_UBUNTU_PRO")${CL}"
    if [[ "$ATTACH_UBUNTU_PRO" =~ ^[Yy] ]]; then
        echo -e "  ${BL}ESM Apps:${CL} ${ANS}$(yes_no_label "$ENABLE_ESM_APPS")${CL}"
        echo -e "  ${BL}ESM Infra:${CL} ${ANS}$(yes_no_label "$ENABLE_ESM_INFRA")${CL}"
        echo -e "  ${BL}Livepatch:${CL} ${ANS}$(yes_no_label "$ENABLE_LIVEPATCH")${CL}"
    fi

    echo ""
    echo -e "${YW}System:${CL}"
    echo -e "  ${BL}Upgrade:${CL} ${ANS}$(yes_no_label "$RUN_SYSTEM_UPDATE")${CL}"
    echo -e "  ${BL}QEMU guest agent:${CL} ${ANS}$(yes_no_label "$INSTALL_QEMU_AGENT")${CL}"
    echo -e "  ${BL}Root expansion:${CL} ${ANS}$(yes_no_label "$EXPAND_ROOT_LVM")${CL}"
    echo -e "  ${BL}UFW firewall:${CL} ${ANS}$(yes_no_label "$CONFIGURE_UFW")${CL}"
    echo -e "  ${BL}CrowdSec:${CL} ${ANS}install${CL}"
    echo -e "  ${BL}Cleanup:${CL} ${ANS}$(yes_no_label "$RUN_SYSTEM_CLEANUP")${CL}"
    echo -e "  ${BL}Reboot:${CL} ${ANS}$(yes_no_label "$REBOOT_AFTER_FINISH")${CL}"

    echo ""
    echo -e "${YW}After confirmation, Ubuntu VM setup changes will be applied.${CL}"
    echo ""

    apply_yn="$(timed_yes_no "Apply this Ubuntu VM setup plan?" "y")"
    [[ "$apply_yn" =~ ^[Nn] ]] && exit 0

    return 0
}

# =========================================================
#  PHASE 2: APPLY SYSTEM CHANGES
# =========================================================

# --- 34. USER CREATION / REUSE ---
function apply_user_setup() {
    apply_group_header "User / SSH"

    if [ "$EXISTING_USER" == "no" ]; then
        msg_info "Creating user ${USERNAME}"
        run_cmd "creating user ${USERNAME}" useradd -m -s /bin/bash "$USERNAME"
        SUDO_USER_CREATED="yes"
        msg_ok "USER CREATED"
    else
        msg_ok "USER ${USERNAME} ALREADY EXISTS"
    fi

    msg_info "Ensuring ${USERNAME} is in sudo group"
    run_cmd "adding ${USERNAME} to sudo group" usermod -aG sudo "$USERNAME"
    USER_ADDED_TO_SUDO="yes"
    msg_ok "USER SUDO ACCESS CONFIRMED"

    DEST_KEYS="/home/${USERNAME}/.ssh/authorized_keys"

    if [ -n "$SOURCE_KEYS" ]; then
        run_cmd "creating SSH directory for ${USERNAME}" mkdir -p "/home/${USERNAME}/.ssh"

        if [ "$(readlink -f "$SOURCE_KEYS")" = "$(readlink -f "$DEST_KEYS" 2>/dev/null || echo "$DEST_KEYS")" ]; then
            msg_ok "SSH KEYS ALREADY CONFIGURED"
        else
            msg_info "Copying SSH keys for ${USERNAME}"
            run_cmd "copying SSH keys for ${USERNAME}" cp "$SOURCE_KEYS" "$DEST_KEYS"
            msg_ok "SSH KEYS CONFIGURED"
        fi

        msg_info "Fixing SSH key ownership and permissions"
        run_cmd "setting SSH directory ownership" chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.ssh"
        run_cmd "setting SSH directory permissions" chmod 700 "/home/${USERNAME}/.ssh"
        run_cmd "setting authorized_keys permissions" chmod 600 "$DEST_KEYS"
        SSH_KEYS_CONFIGURED="yes"
        msg_ok "SSH KEY PERMISSIONS VERIFIED"
    else
        SSH_KEYS_CONFIGURED="no"
        msg_warn "SSH key setup skipped because no authorized_keys source was found"
    fi

    if [[ "$LOCK_USER_PASSWORD" =~ ^[Yy] ]]; then
        local passwd_state=""

        msg_info "Locking password for ${USERNAME}"
        run_cmd "locking password for ${USERNAME}" passwd -l "$USERNAME"

        passwd_state="$(passwd -S "$USERNAME" 2>/dev/null | awk '{print $2}' || true)"
        if [ "$passwd_state" == "L" ] || [ "$passwd_state" == "NP" ]; then
            USER_PASSWORD_LOCKED="yes"
            msg_ok "USER PASSWORD LOCKED"
        else
            USER_PASSWORD_LOCKED="verify-failed"
            msg_warn "Password lock command ran but verification did not confirm locked state"
        fi
    else
        USER_PASSWORD_LOCKED="no"
        msg_warn "USER PASSWORD LOCK SKIPPED"
    fi
}

# --- 35. UBUNTU PRO CLIENT INSTALL HELPER ---
function ensure_ubuntu_pro_client() {
    if command -v pro >/dev/null 2>&1; then
        msg_ok "UBUNTU PRO CLIENT FOUND"
        return 0
    fi

    msg_warn "Ubuntu Pro client not found; installing it before Pro attach"

    msg_info "Updating package lists for Ubuntu Pro client"
    run_cmd "updating package lists for Ubuntu Pro client" apt-get update
    msg_ok "PACKAGE LISTS UPDATED"

    msg_info "Installing Ubuntu Pro client"
    run_cmd "installing Ubuntu Pro client" env DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-pro-client ubuntu-advantage-tools
    msg_ok "UBUNTU PRO CLIENT INSTALLED"
}

# --- 36A. UBUNTU PRO SERVICE ENABLE HELPER ---
function run_pro_enable_service() {
    local service="$1"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" pro enable "$service" --assume-yes >/dev/null 2>&1
    else
        pro enable "$service" --assume-yes >/dev/null 2>&1
    fi
}

# --- 36. UBUNTU PRO APPLY ---
function apply_ubuntu_pro() {
    apply_group_header "System"

    if [[ ! "$ATTACH_UBUNTU_PRO" =~ ^[Yy] ]]; then
        UBUNTU_PRO_ATTACHED="no"
        msg_skip "UBUNTU PRO ATTACHMENT SKIPPED"
        return 0
    fi

    ensure_ubuntu_pro_client

    if pro status 2>/dev/null | grep -qi 'Subscription:'; then
        UBUNTU_PRO_ATTACHED="already-attached"
        msg_ok "UBUNTU PRO ALREADY ATTACHED"
    else
        local err_file=""
        err_file="$(mktemp)"
        TEMP_FILES+=("$err_file")

        msg_info "Attaching Ubuntu Pro"

        if [ -n "$SUDO_CMD" ]; then
            if "$SUDO_CMD" pro attach "$PRO_TOKEN" --no-auto-enable > /dev/null 2> "$err_file"; then
                UBUNTU_PRO_ATTACHED="yes"
                msg_ok "UBUNTU PRO ATTACHED"
            else
                UBUNTU_PRO_ATTACHED="failed"
                msg_warn "Ubuntu Pro attachment failed"
                echo -e "${YW}Real error:${CL}"
                sed -E 's/[A-Za-z0-9_-]{20,}/[redacted]/g' "$err_file" || true
            fi
        else
            if pro attach "$PRO_TOKEN" --no-auto-enable > /dev/null 2> "$err_file"; then
                UBUNTU_PRO_ATTACHED="yes"
                msg_ok "UBUNTU PRO ATTACHED"
            else
                UBUNTU_PRO_ATTACHED="failed"
                msg_warn "Ubuntu Pro attachment failed"
                echo -e "${YW}Real error:${CL}"
                sed -E 's/[A-Za-z0-9_-]{20,}/[redacted]/g' "$err_file" || true
            fi
        fi

        rm -f "$err_file"
    fi

    unset PRO_TOKEN
    PRO_TOKEN=""

    if [ "$UBUNTU_PRO_ATTACHED" == "failed" ]; then
        msg_warn "Pro service enablement skipped because attach failed"
        return 0
    fi

    if [[ "$ENABLE_ESM_APPS" =~ ^[Yy] ]]; then
        msg_info "Enabling Ubuntu Pro ESM Apps"
        if run_pro_enable_service "esm-apps"; then UBUNTU_PRO_ESM_APPS="yes"; msg_ok "ESM APPS ENABLED"; else UBUNTU_PRO_ESM_APPS="failed"; msg_warn "ESM Apps could not be enabled"; fi
    fi

    if [[ "$ENABLE_ESM_INFRA" =~ ^[Yy] ]]; then
        msg_info "Enabling Ubuntu Pro ESM Infra"
        if run_pro_enable_service "esm-infra"; then UBUNTU_PRO_ESM_INFRA="yes"; msg_ok "ESM INFRA ENABLED"; else UBUNTU_PRO_ESM_INFRA="failed"; msg_warn "ESM Infra could not be enabled"; fi
    fi

    if [[ "$ENABLE_LIVEPATCH" =~ ^[Yy] ]]; then
        msg_info "Enabling Ubuntu Pro Livepatch"
        if run_pro_enable_service "livepatch"; then UBUNTU_PRO_LIVEPATCH="yes"; msg_ok "LIVEPATCH ENABLED"; else UBUNTU_PRO_LIVEPATCH="failed"; msg_warn "Livepatch could not be enabled"; fi
    fi
}

# --- 37. SYSTEM UPDATE ---
function update_system_packages() {
    apply_group_header "System"

    if [[ ! "$RUN_SYSTEM_UPDATE" =~ ^[Yy] ]]; then
        SYSTEM_UPDATED="skipped"
        msg_skip "SYSTEM UPDATE SKIPPED"
        return 0
    fi

    msg_info "Updating package lists"
    run_cmd "updating package lists" apt-get update
    msg_ok "PACKAGE LISTS UPDATED"

    msg_info "Upgrading system packages"
    run_cmd "upgrading system packages" env DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade
    SYSTEM_UPDATED="yes"
    msg_ok "SYSTEM PACKAGES UPGRADED"

    msg_info "Removing unused packages"
    run_optional env DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
    msg_ok "UNUSED PACKAGES REMOVED"
}

# --- 38. QEMU GUEST AGENT INSTALL ---
function install_qemu_guest_agent() {
    apply_group_header "System"

    if [ "$IS_CONTAINER" == "yes" ] || [[ ! "$INSTALL_QEMU_AGENT" =~ ^[Yy] ]]; then
        QEMU_AGENT_INSTALLED="skipped"
        msg_skip "QEMU GUEST AGENT SKIPPED"
        return 0
    fi

    msg_info "Installing QEMU guest agent"
    run_cmd "installing QEMU guest agent" env DEBIAN_FRONTEND=noninteractive apt-get install -y qemu-guest-agent
    msg_ok "QEMU GUEST AGENT PACKAGE INSTALLED"

    msg_info "Enabling QEMU guest agent"
    run_cmd "enabling QEMU guest agent" systemctl enable --now qemu-guest-agent
    msg_ok "QEMU GUEST AGENT ENABLED"

    if systemctl is-active --quiet qemu-guest-agent; then
        QEMU_AGENT_INSTALLED="yes"
        msg_ok "QEMU GUEST AGENT ACTIVE"
    else
        QEMU_AGENT_INSTALLED="installed-not-active"
        msg_warn "QEMU guest agent installed but service is not active"
    fi
}

# --- 39. ROOT FILESYSTEM LVM EXPANSION ---
function expand_root_lvm_if_possible() {
    apply_group_header "Root disk expansion"

    local root_source=""
    local root_candidate=""
    local lvm_rows=""
    local lv_path=""
    local lv_dm_path=""
    local vg_name=""
    local lv_name=""
    local resolved_lv_path=""
    local resolved_dm_path=""
    local vg_free_raw=""
    local vg_free_int="0"
    local min_expand_bytes="1073741824"

    if [ "$IS_CONTAINER" == "yes" ] || [[ ! "$EXPAND_ROOT_LVM" =~ ^[Yy] ]]; then
        ROOT_FS_BEFORE_GB="$(get_root_filesystem_size_gb)"
        ROOT_FS_AFTER_GB="$ROOT_FS_BEFORE_GB"
        ROOT_EXPANDED="skipped"
        msg_skip "ROOT LVM EXPANSION SKIPPED"
        return 0
    fi

    if ! command -v lvs >/dev/null 2>&1 || ! command -v vgs >/dev/null 2>&1 || ! command -v lvextend >/dev/null 2>&1; then
        ROOT_FS_BEFORE_GB="$(get_root_filesystem_size_gb)"
        ROOT_FS_AFTER_GB="$ROOT_FS_BEFORE_GB"
        ROOT_EXPANDED="not-needed"
        msg_ok "LVM TOOLS NOT FOUND; ROOT LVM EXPANSION NOT NEEDED"
        return 0
    fi

    msg_info "Checking root filesystem free space"
    ROOT_FS_BEFORE_GB="$(get_root_filesystem_size_gb)"

    root_source="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
    ROOT_SOURCE="$root_source"

    if [ -n "$root_source" ]; then
        root_candidate="$(readlink -f "$root_source" 2>/dev/null || echo "$root_source")"
    fi

    if [ -n "$SUDO_CMD" ]; then
        lvm_rows="$($SUDO_CMD lvs --noheadings --separator '|' -o lv_path,lv_dm_path,vg_name,lv_name 2>/dev/null || true)"
    else
        lvm_rows="$(lvs --noheadings --separator '|' -o lv_path,lv_dm_path,vg_name,lv_name 2>/dev/null || true)"
    fi

    while IFS='|' read -r lv_path lv_dm_path vg_name lv_name; do
        lv_path="$(echo "$lv_path" | xargs)"
        lv_dm_path="$(echo "$lv_dm_path" | xargs)"
        vg_name="$(echo "$vg_name" | xargs)"
        lv_name="$(echo "$lv_name" | xargs)"

        [ -z "$lv_path" ] && continue

        resolved_lv_path="$(readlink -f "$lv_path" 2>/dev/null || echo "$lv_path")"
        resolved_dm_path="$(readlink -f "$lv_dm_path" 2>/dev/null || echo "$lv_dm_path")"

        if [ "$root_source" == "$lv_path" ] || \
           [ "$root_source" == "$lv_dm_path" ] || \
           [ "$root_candidate" == "$resolved_lv_path" ] || \
           [ "$root_candidate" == "$resolved_dm_path" ]; then
            ROOT_LV_PATH="$lv_path"
            VG_NAME="$vg_name"
            break
        fi
    done <<< "$lvm_rows"

    if [ -z "$ROOT_LV_PATH" ] || [ -z "$VG_NAME" ]; then
        ROOT_EXPANDED="not-needed"
        ROOT_FS_AFTER_GB="$ROOT_FS_BEFORE_GB"
        msg_ok "ROOT FILESYSTEM LVM EXPANSION NOT NEEDED"
        detail_line "Root source" "${ROOT_SOURCE:-unknown}"
        detail_line "Resolved root source" "${root_candidate:-unknown}"
        return 0
    fi

    if [ -n "$SUDO_CMD" ]; then
        vg_free_raw="$($SUDO_CMD vgs --noheadings --units b --nosuffix -o vg_free "$VG_NAME" 2>/dev/null | xargs || true)"
    else
        vg_free_raw="$(vgs --noheadings --units b --nosuffix -o vg_free "$VG_NAME" 2>/dev/null | xargs || true)"
    fi

    vg_free_int="${vg_free_raw%%.*}"
    vg_free_int="${vg_free_int//[^0-9]/}"
    [ -z "$vg_free_int" ] && vg_free_int="0"
    VG_FREE_BYTES="$vg_free_int"

    echo -e "${YW}Root disk expansion:${CL}"
    echo -e "  ${BL}Root LV:${CL} ${GN}${ROOT_LV_PATH}${CL}"
    echo -e "  ${BL}Volume group:${CL} ${GN}${VG_NAME}${CL}"
    echo -e "  ${BL}Free LVM space:${CL} ${GN}$(bytes_to_gb_display "$VG_FREE_BYTES")${CL}"

    if [[ "$VG_FREE_BYTES" =~ ^[0-9]+$ ]] && [ "$VG_FREE_BYTES" -gt "$min_expand_bytes" ]; then
        msg_ok "FOUND EMPTY LVM SPACE"

        msg_info "Expanding Ubuntu root filesystem"
        run_cmd "expanding Ubuntu root filesystem" lvextend -r -l +100%FREE "$ROOT_LV_PATH"
        ROOT_EXPANDED="yes"
        ROOT_FS_AFTER_GB="$(get_root_filesystem_size_gb)"
        msg_ok "UBUNTU ROOT FILESYSTEM EXPANDED"
        echo -e "  ${BL}Result:${CL} ${GN}expanded${CL}"
    else
        ROOT_EXPANDED="not-needed"
        ROOT_FS_AFTER_GB="$(get_root_filesystem_size_gb)"
        msg_ok "NO EMPTY LVM SPACE FOUND"
        echo -e "  ${BL}Result:${CL} ${GN}not needed${CL}"
    fi
}

# --- 40. UFW FIREWALL SETUP ---
function configure_ufw_firewall() {
    apply_group_header "Firewall"

    if [[ ! "$CONFIGURE_UFW" =~ ^[Yy] ]]; then
        UFW_ENABLED="skipped"
        msg_skip "UFW FIREWALL SKIPPED"
        return 0
    fi

    msg_info "Installing UFW"
    run_cmd "installing UFW" env DEBIAN_FRONTEND=noninteractive apt-get install -y ufw
    msg_ok "UFW INSTALLED"

    msg_info "Configuring UFW firewall rules"
    run_optional ufw default deny incoming
    run_optional ufw default allow outgoing
    run_optional ufw allow OpenSSH
    run_optional ufw allow 80/tcp
    run_optional ufw allow 443/tcp
    msg_ok "UFW FIREWALL RULES CONFIGURED"

    msg_info "Enabling UFW firewall"

    if [ -n "$SUDO_CMD" ]; then
        if "$SUDO_CMD" ufw --force enable >/dev/null 2>&1; then
            UFW_ENABLED="yes"
            msg_ok "UFW FIREWALL ENABLED"
        else
            UFW_ENABLED="failed"
            msg_warn "UFW failed to enable. This can happen inside restricted containers."
        fi
    else
        if ufw --force enable >/dev/null 2>&1; then
            UFW_ENABLED="yes"
            msg_ok "UFW FIREWALL ENABLED"
        else
            UFW_ENABLED="failed"
            msg_warn "UFW failed to enable. This can happen inside restricted containers."
        fi
    fi
}

# --- 41. SSH HARDENING ---
function harden_ssh() {
    local ssh_config="/etc/ssh/sshd_config"
    local effective_config=""
    local effective_password_auth=""
    local effective_pubkey_auth=""
    local effective_permit_root=""
    local effective_kbd_auth=""

    apply_group_header "SSH hardening"

    if [[ ! "$APPLY_SSH_HARDENING" =~ ^[Yy] ]]; then
        SSH_HARDENING_APPLIED="skipped"
        msg_skip "SSH HARDENING SKIPPED"
        return 0
    fi

    if [ ! -s "/home/${USERNAME}/.ssh/authorized_keys" ]; then
        SSH_HARDENING_APPLIED="no"
        msg_warn "SSH hardening skipped because SSH keys were not detected for ${USERNAME}"
        return 0
    fi

    msg_info "Verifying SSH key permissions before hardening"
    run_cmd "setting SSH directory ownership" chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.ssh"
    run_cmd "setting SSH directory permissions" chmod 700 "/home/${USERNAME}/.ssh"
    run_cmd "setting authorized_keys permissions" chmod 600 "/home/${USERNAME}/.ssh/authorized_keys"
    msg_ok "SSH KEY PERMISSIONS VERIFIED"

    msg_info "Writing SSH key-only policy"

    run_optional sed -i -E 's/^[#[:space:]]*AddressFamily.*/AddressFamily inet/' "$ssh_config"
    root_grep_quiet '^AddressFamily[[:space:]]+' "$ssh_config" || root_append_line "$ssh_config" "AddressFamily inet"

    run_optional sed -i -E 's/^[#[:space:]]*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$ssh_config"
    root_grep_quiet '^PubkeyAuthentication[[:space:]]+' "$ssh_config" || root_append_line "$ssh_config" "PubkeyAuthentication yes"

    run_optional sed -i -E 's/^[#[:space:]]*PasswordAuthentication.*/PasswordAuthentication no/' "$ssh_config"
    root_grep_quiet '^PasswordAuthentication[[:space:]]+' "$ssh_config" || root_append_line "$ssh_config" "PasswordAuthentication no"

    run_optional sed -i -E 's/^[#[:space:]]*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' "$ssh_config"
    root_grep_quiet '^KbdInteractiveAuthentication[[:space:]]+' "$ssh_config" || root_append_line "$ssh_config" "KbdInteractiveAuthentication no"

    run_optional sed -i -E 's/^[#[:space:]]*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$ssh_config"
    root_grep_quiet '^ChallengeResponseAuthentication[[:space:]]+' "$ssh_config" || root_append_line "$ssh_config" "ChallengeResponseAuthentication no"

    run_optional sed -i -E 's/^[#[:space:]]*PermitRootLogin.*/PermitRootLogin no/' "$ssh_config"
    root_grep_quiet '^PermitRootLogin[[:space:]]+' "$ssh_config" || root_append_line "$ssh_config" "PermitRootLogin no"

    msg_ok "SSH KEY-ONLY POLICY WRITTEN"

    msg_info "Validating effective SSH configuration"
    run_cmd "validating sshd configuration" sshd -t

    effective_config="$(get_effective_sshd_config)"
    effective_password_auth="$(awk '$1=="passwordauthentication" {print $2; exit}' <<< "$effective_config")"
    effective_pubkey_auth="$(awk '$1=="pubkeyauthentication" {print $2; exit}' <<< "$effective_config")"
    effective_permit_root="$(awk '$1=="permitrootlogin" {print $2; exit}' <<< "$effective_config")"
    effective_kbd_auth="$(awk '$1=="kbdinteractiveauthentication" {print $2; exit}' <<< "$effective_config")"

    [ "${effective_pubkey_auth:-unknown}" == "yes" ] || msg_error "SSH validation failed: PubkeyAuthentication is ${effective_pubkey_auth:-unknown}, expected yes"
    [ "${effective_password_auth:-unknown}" == "no" ] || msg_error "SSH validation failed: PasswordAuthentication is ${effective_password_auth:-unknown}, expected no"

    case "${effective_permit_root:-unknown}" in
        no|prohibit-password|without-password) ;;
        *) msg_error "SSH validation failed: PermitRootLogin is ${effective_permit_root:-unknown}, expected no/prohibit-password/without-password" ;;
    esac

    if [ -n "$effective_kbd_auth" ] && [ "$effective_kbd_auth" != "no" ]; then
        msg_error "SSH validation failed: KbdInteractiveAuthentication is ${effective_kbd_auth}, expected no"
    fi

    msg_ok "EFFECTIVE SSH CONFIG VERIFIED"

    msg_info "Restarting SSH service"
    run_optional systemctl restart ssh
    run_optional systemctl restart sshd
    msg_ok "SSH SERVICE RESTARTED"

    SSH_HARDENING_APPLIED="yes"

    msg_ok "SSH SECURITY HARDENED"
    echo -e "  ${DGN}${USERNAME} SSH KEY LOGIN PRESERVED${CL}"
    echo -e "  ${DGN}SSH PASSWORD LOGIN DISABLED${CL}"
    echo -e "  ${DGN}ROOT SSH LOGIN DISABLED${CL}"
}


# --- 42. CROWDSEC SECURITY ---
function crowdsec_collection_installed() {
    local collection="$1"

    command -v cscli >/dev/null 2>&1 || return 1

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" cscli collections list 2>/dev/null | grep -q "$collection"
    else
        cscli collections list 2>/dev/null | grep -q "$collection"
    fi
}

function install_crowdsec_collection_if_missing() {
    local collection="$1"

    command -v cscli >/dev/null 2>&1 || return 1

    if crowdsec_collection_installed "$collection"; then
        return 0
    fi

    run_optional cscli collections install "$collection"
    crowdsec_collection_installed "$collection"
}

function apply_crowdsec_security() {
    apply_group_header "CrowdSec"

    if [ "$ENABLE_CROWDSEC" != "y" ]; then
        CROWDSEC_PACKAGE_INSTALLED="skipped"
        CROWDSEC_SERVICE_STATUS="skipped"
        CROWDSEC_COLLECTIONS_STATUS="skipped"
        msg_skip "CROWDSEC SECURITY SUITE SKIPPED"
        return 0
    fi

    msg_info "Installing CrowdSec dependency packages"
    run_optional env DEBIAN_FRONTEND=noninteractive apt-get install -y curl gnupg ca-certificates
    msg_ok "CROWDSEC INSTALL DEPENDENCIES READY"

    if ! grep -Rqs 'crowdsec' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
        if command -v curl >/dev/null 2>&1; then
            msg_info "Running CrowdSec repository installer"
            if [ -n "$SUDO_CMD" ]; then
                curl -fsSL https://install.crowdsec.net | "$SUDO_CMD" sh >/dev/null 2>&1 || true
            else
                curl -fsSL https://install.crowdsec.net | sh >/dev/null 2>&1 || true
            fi
            msg_ok "CROWDSEC REPOSITORY INSTALLER EXECUTED"
        else
            msg_warn "curl not found after dependency install; CrowdSec repository installer skipped"
        fi
    else
        msg_ok "CROWDSEC REPOSITORY ALREADY CONFIGURED"
    fi

    msg_info "Updating APT package lists for CrowdSec"
    run_optional env DEBIAN_FRONTEND=noninteractive apt-get update
    msg_ok "APT PACKAGE LISTS UPDATED FOR CROWDSEC"

    msg_info "Installing CrowdSec and unattended-upgrades"
    run_optional env DEBIAN_FRONTEND=noninteractive apt-get install -y crowdsec unattended-upgrades
    if command -v crowdsec >/dev/null 2>&1 && command -v cscli >/dev/null 2>&1; then
        CROWDSEC_PACKAGE_INSTALLED="installed"
        msg_ok "CROWDSEC PACKAGE INSTALLED"
    else
        CROWDSEC_PACKAGE_INSTALLED="not-installed"
        msg_warn "CrowdSec package install did not confirm crowdsec/cscli binaries"
    fi

    msg_info "Checking available CrowdSec firewall bouncer package"
    if apt-cache show crowdsec-firewall-bouncer-nftables >/dev/null 2>&1; then
        run_optional env DEBIAN_FRONTEND=noninteractive apt-get install -y crowdsec-firewall-bouncer-nftables
        CROWDSEC_BOUNCER_PACKAGE="crowdsec-firewall-bouncer-nftables"
        msg_ok "CROWDSEC NFTABLES FIREWALL BOUNCER INSTALLED"
    elif apt-cache show crowdsec-firewall-bouncer-iptables >/dev/null 2>&1; then
        run_optional env DEBIAN_FRONTEND=noninteractive apt-get install -y crowdsec-firewall-bouncer-iptables
        CROWDSEC_BOUNCER_PACKAGE="crowdsec-firewall-bouncer-iptables"
        msg_ok "CROWDSEC IPTABLES FIREWALL BOUNCER INSTALLED"
    else
        CROWDSEC_BOUNCER_PACKAGE="none"
        msg_warn "CrowdSec firewall bouncer package not found"
    fi

    if command -v cscli >/dev/null 2>&1; then
        msg_info "Installing CrowdSec collections"
        run_optional cscli hub update
        install_crowdsec_collection_if_missing "crowdsecurity/linux" || true
        install_crowdsec_collection_if_missing "crowdsecurity/sshd" || true
        install_crowdsec_collection_if_missing "crowdsecurity/http-cve" || true

        if crowdsec_collection_installed 'crowdsecurity/linux' && \
           crowdsec_collection_installed 'crowdsecurity/sshd' && \
           crowdsec_collection_installed 'crowdsecurity/http-cve'; then
            CROWDSEC_COLLECTIONS_STATUS="ready"
            msg_ok "CROWDSEC COLLECTIONS READY"
        else
            CROWDSEC_COLLECTIONS_STATUS="partial"
            msg_warn "CrowdSec collections were not fully confirmed"
        fi
    else
        CROWDSEC_COLLECTIONS_STATUS="unavailable"
        msg_warn "cscli not found after install; CrowdSec collection install skipped"
    fi

    msg_info "Enabling CrowdSec service"
    run_optional systemctl enable --now crowdsec
    run_optional systemctl restart crowdsec

    if systemctl is-active --quiet crowdsec 2>/dev/null; then
        CROWDSEC_SERVICE_STATUS="active"
        msg_ok "CROWDSEC SERVICE ACTIVE"
    else
        CROWDSEC_SERVICE_STATUS="not-active"
        msg_warn "CrowdSec service is not active after install"
    fi

    msg_info "Checking CrowdSec firewall bouncer service"
    if systemctl list-unit-files 'crowdsec-firewall-bouncer*' --no-pager --no-legend 2>/dev/null | grep -q "crowdsec-firewall-bouncer"; then
        run_optional systemctl enable --now crowdsec-firewall-bouncer
        run_optional systemctl restart crowdsec-firewall-bouncer
        if systemctl is-active --quiet crowdsec-firewall-bouncer 2>/dev/null; then
            CROWDSEC_BOUNCER_STATUS="active"
            msg_ok "CROWDSEC FIREWALL BOUNCER ACTIVE"
        else
            CROWDSEC_BOUNCER_STATUS="installed-not-active"
            msg_warn "CrowdSec firewall bouncer service is installed but not active"
        fi
    else
        CROWDSEC_BOUNCER_STATUS="not-found"
        msg_warn "CrowdSec firewall bouncer service was not found after install"
    fi

    msg_info "Writing unattended-upgrades config"
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" bash -c "cat > /etc/apt/apt.conf.d/20auto-upgrades" <<'EOF_AUTO_UPGRADES'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF_AUTO_UPGRADES
    else
        cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF_AUTO_UPGRADES'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF_AUTO_UPGRADES
    fi
    UNATTENDED_UPGRADES_CONFIGURED="yes"
    msg_ok "UNATTENDED UPGRADES CONFIGURED"

    msg_ok "CROWDSEC SECURITY COMPLETE"
}

# --- 42. SYSTEM CLEANUP ---
function clean_system() {
    apply_group_header "System"

    if [[ ! "$RUN_SYSTEM_CLEANUP" =~ ^[Yy] ]]; then
        SYSTEM_CLEANED="skipped"
        msg_skip "SYSTEM CLEANUP SKIPPED"
        return 0
    fi

    msg_info "Cleaning system"
    run_optional apt-get clean
    run_optional env DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
    SYSTEM_CLEANED="yes"
    msg_ok "SYSTEM CLEANED"
}

# =========================================================
#  VERIFICATION / MARKER / SUMMARY
# =========================================================

# --- 43. COMPLETION MARKER ---
function write_completion_marker() {
    apply_group_header "Marker / verification"

    msg_info "Writing completion marker"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" bash -c "cat > '$COMPLETED_MARKER'" <<EOF_MARKER
Ubuntu VM Setup completed on: $(date)
Username: $USERNAME
User Created: $SUDO_USER_CREATED
User Added To Sudo: $USER_ADDED_TO_SUDO
User Password Locked: $USER_PASSWORD_LOCKED
SSH Keys Configured: $SSH_KEYS_CONFIGURED
Virt Type: $VIRT_TYPE
Container: $IS_CONTAINER
LXC: $IS_LXC
VM: $IS_VM
Ubuntu Pro Attached: $UBUNTU_PRO_ATTACHED
Ubuntu Pro ESM Apps: $UBUNTU_PRO_ESM_APPS
Ubuntu Pro ESM Infra: $UBUNTU_PRO_ESM_INFRA
Ubuntu Pro Livepatch: $UBUNTU_PRO_LIVEPATCH
System Updated: $SYSTEM_UPDATED
QEMU Agent: $QEMU_AGENT_INSTALLED
Root Expanded: $ROOT_EXPANDED
UFW: $UFW_ENABLED
CrowdSec Package: $CROWDSEC_PACKAGE_INSTALLED
CrowdSec Service: $CROWDSEC_SERVICE_STATUS
CrowdSec Collections: $CROWDSEC_COLLECTIONS_STATUS
CrowdSec Bouncer Package: $CROWDSEC_BOUNCER_PACKAGE
CrowdSec Bouncer: $CROWDSEC_BOUNCER_STATUS
Unattended Upgrades: $UNATTENDED_UPGRADES_CONFIGURED
SSH Hardened: $SSH_HARDENING_APPLIED
System Cleaned: $SYSTEM_CLEANED
Verify Log: $VERIFY_LOG
SCRIPT4_STATUS=completed
SCRIPT4_VERSION=$SCRIPT_VERSION
SCRIPT4_BUILD=$SCRIPT_BUILD
SCRIPT4_VERIFY_STATUS=$VERIFY_STATUS
SCRIPT4_VERIFY_LOG=$VERIFY_LOG
SCRIPT4_VERIFY_DISPLAY_LOG=$VERIFY_DISPLAY_LOG
SCRIPT4_POST_REBOOT_DISPLAY_HOOK=$POST_REBOOT_VERIFY_HOOK
SCRIPT4_POST_REBOOT_DISPLAY_MARKER=/home/${USERNAME}/.ubuntu-vm-setup-verify-displayed
SCRIPT4_USERNAME=$USERNAME
SCRIPT4_ROOT_EXPANDED=$ROOT_EXPANDED
SCRIPT4_UFW_ENABLED=$UFW_ENABLED
SCRIPT4_CROWDSEC_PACKAGE=$CROWDSEC_PACKAGE_INSTALLED
SCRIPT4_CROWDSEC_SERVICE=$CROWDSEC_SERVICE_STATUS
SCRIPT4_CROWDSEC_COLLECTIONS=$CROWDSEC_COLLECTIONS_STATUS
SCRIPT4_CROWDSEC_BOUNCER_PACKAGE=$CROWDSEC_BOUNCER_PACKAGE
SCRIPT4_CROWDSEC_BOUNCER=$CROWDSEC_BOUNCER_STATUS
SCRIPT4_QEMU_AGENT=$QEMU_AGENT_INSTALLED
SCRIPT4_SSH_HARDENED=$SSH_HARDENING_APPLIED
EOF_MARKER
    else
        cat > "$COMPLETED_MARKER" <<EOF_MARKER
Ubuntu VM Setup completed on: $(date)
Username: $USERNAME
User Created: $SUDO_USER_CREATED
User Added To Sudo: $USER_ADDED_TO_SUDO
User Password Locked: $USER_PASSWORD_LOCKED
SSH Keys Configured: $SSH_KEYS_CONFIGURED
Virt Type: $VIRT_TYPE
Container: $IS_CONTAINER
LXC: $IS_LXC
VM: $IS_VM
Ubuntu Pro Attached: $UBUNTU_PRO_ATTACHED
Ubuntu Pro ESM Apps: $UBUNTU_PRO_ESM_APPS
Ubuntu Pro ESM Infra: $UBUNTU_PRO_ESM_INFRA
Ubuntu Pro Livepatch: $UBUNTU_PRO_LIVEPATCH
System Updated: $SYSTEM_UPDATED
QEMU Agent: $QEMU_AGENT_INSTALLED
Root Expanded: $ROOT_EXPANDED
UFW: $UFW_ENABLED
CrowdSec Package: $CROWDSEC_PACKAGE_INSTALLED
CrowdSec Service: $CROWDSEC_SERVICE_STATUS
CrowdSec Collections: $CROWDSEC_COLLECTIONS_STATUS
CrowdSec Bouncer Package: $CROWDSEC_BOUNCER_PACKAGE
CrowdSec Bouncer: $CROWDSEC_BOUNCER_STATUS
Unattended Upgrades: $UNATTENDED_UPGRADES_CONFIGURED
SSH Hardened: $SSH_HARDENING_APPLIED
System Cleaned: $SYSTEM_CLEANED
Verify Log: $VERIFY_LOG
SCRIPT4_STATUS=completed
SCRIPT4_VERSION=$SCRIPT_VERSION
SCRIPT4_BUILD=$SCRIPT_BUILD
SCRIPT4_VERIFY_STATUS=$VERIFY_STATUS
SCRIPT4_VERIFY_LOG=$VERIFY_LOG
SCRIPT4_VERIFY_DISPLAY_LOG=$VERIFY_DISPLAY_LOG
SCRIPT4_POST_REBOOT_DISPLAY_HOOK=$POST_REBOOT_VERIFY_HOOK
SCRIPT4_POST_REBOOT_DISPLAY_MARKER=/home/${USERNAME}/.ubuntu-vm-setup-verify-displayed
SCRIPT4_USERNAME=$USERNAME
SCRIPT4_ROOT_EXPANDED=$ROOT_EXPANDED
SCRIPT4_UFW_ENABLED=$UFW_ENABLED
SCRIPT4_CROWDSEC_PACKAGE=$CROWDSEC_PACKAGE_INSTALLED
SCRIPT4_CROWDSEC_SERVICE=$CROWDSEC_SERVICE_STATUS
SCRIPT4_CROWDSEC_COLLECTIONS=$CROWDSEC_COLLECTIONS_STATUS
SCRIPT4_CROWDSEC_BOUNCER_PACKAGE=$CROWDSEC_BOUNCER_PACKAGE
SCRIPT4_CROWDSEC_BOUNCER=$CROWDSEC_BOUNCER_STATUS
SCRIPT4_QEMU_AGENT=$QEMU_AGENT_INSTALLED
SCRIPT4_SSH_HARDENED=$SSH_HARDENING_APPLIED
EOF_MARKER
    fi

    msg_ok "COMPLETION MARKER WRITTEN"
}

# --- 44. VERIFICATION REPORT ---
function create_verification_report() {
    if [ "${VERIFY_ONLY_MODE:-no}" != "yes" ]; then
        apply_group_header "Marker / verification"
    fi

    msg_info "Creating verification report"

    local report_body=""
    local effective_config=""
    local ufw_status=""
    local ufw_service_state=""
    local ufw_ssh_rules=""

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

    verify_record_first_issue() {
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

    verify_pass() {
        VERIFY_PASS_COUNT="$(( VERIFY_PASS_COUNT + 1 ))"
        echo "✓ PASS - $1" >> "$report_body"
    }

    verify_warn() {
        local check="$1"
        local reason="${2:-warning condition detected}"
        local fix="${3:-review ${VERIFY_LOG}}"

        VERIFY_WARN_COUNT="$(( VERIFY_WARN_COUNT + 1 ))"
        verify_record_first_issue "Warning" "$check" "$reason" "$fix"
        echo "! WARN - ${check}: ${reason}" >> "$report_body"
    }

    verify_fail() {
        local check="$1"
        local reason="${2:-check failed}"
        local fix="${3:-review ${VERIFY_LOG}}"

        VERIFY_FAIL_COUNT="$(( VERIFY_FAIL_COUNT + 1 ))"
        verify_record_first_issue "Failure" "$check" "$reason" "$fix"
        echo "✗ FAIL - ${check}: ${reason}" >> "$report_body"
    }

    verify_info() {
        echo "- INFO - $1" >> "$report_body"
    }

    if id "$USERNAME" >/dev/null 2>&1; then verify_pass "User exists"; else verify_fail "User exists" "user ${USERNAME} is missing" "create the user or rerun Script 4"; fi
    if id -nG "$USERNAME" 2>/dev/null | grep -qw sudo; then verify_pass "User is in sudo group"; else verify_warn "User sudo group" "sudo group membership not confirmed" "run sudo usermod -aG sudo ${USERNAME}"; fi
    if [ -s "/home/${USERNAME}/.ssh/authorized_keys" ]; then verify_pass "SSH authorized_keys present"; else verify_warn "SSH authorized_keys" "authorized_keys missing for ${USERNAME}" "copy a valid public key to /home/${USERNAME}/.ssh/authorized_keys"; fi

    if [ -n "$SUDO_CMD" ]; then
        if sudo -n sshd -t >/dev/null 2>&1; then verify_pass "SSHD configuration valid"; else verify_fail "SSHD configuration" "sshd -t failed" "review /etc/ssh/sshd_config and /etc/ssh/sshd_config.d/*.conf, then run sudo -n sshd -t"; fi
        effective_config="$(sudo -n sshd -T -C user="${USERNAME:-root}",host=localhost,addr=127.0.0.1 2>/dev/null || true)"
    else
        if sshd -t >/dev/null 2>&1; then verify_pass "SSHD configuration valid"; else verify_fail "SSHD configuration" "sshd -t failed" "review /etc/ssh/sshd_config and /etc/ssh/sshd_config.d/*.conf, then run sshd -t"; fi
        effective_config="$(sshd -T -C user="${USERNAME:-root}",host=localhost,addr=127.0.0.1 2>/dev/null || true)"
    fi

    if [ "$SSH_HARDENING_APPLIED" == "yes" ]; then
        if grep -q "^passwordauthentication no" <<< "$effective_config"; then verify_pass "SSH password authentication disabled"; else verify_fail "SSH password authentication" "expected passwordauthentication no" "set PasswordAuthentication no and validate with sudo -n sshd -T"; fi
        if grep -q "^pubkeyauthentication yes" <<< "$effective_config"; then verify_pass "SSH public key authentication enabled"; else verify_fail "SSH public key authentication" "expected pubkeyauthentication yes" "set PubkeyAuthentication yes and validate with sudo -n sshd -T"; fi
        if grep -q "^permitrootlogin no" <<< "$effective_config"; then verify_pass "Root SSH login disabled"; else verify_fail "Root SSH login" "expected permitrootlogin no" "set PermitRootLogin no and validate with sudo -n sshd -T"; fi
        if grep -q "^kbdinteractiveauthentication no" <<< "$effective_config"; then verify_pass "SSH keyboard-interactive auth disabled"; else verify_fail "SSH keyboard-interactive auth" "expected kbdinteractiveauthentication no" "set KbdInteractiveAuthentication no and validate with sudo -n sshd -T"; fi
    else
        verify_info "SSH hardening state: $SSH_HARDENING_APPLIED"
    fi

    if command -v ip >/dev/null 2>&1 && ip -4 addr show | grep -q "inet "; then verify_pass "IPv4 address detected"; else verify_warn "IPv4 address" "IPv4 address not detected" "check DHCP/network configuration"; fi

    if [ "$IS_CONTAINER" == "yes" ]; then
        verify_info "QEMU Guest Agent skipped for container"
        verify_info "Root LVM expansion skipped for container"
    else
        if [[ "$INSTALL_QEMU_AGENT" =~ ^[Yy] ]]; then
            if systemctl is-enabled --quiet qemu-guest-agent 2>/dev/null; then verify_pass "QEMU guest agent enabled"; else verify_warn "QEMU guest agent enabled" "service is not enabled" "run sudo systemctl enable --now qemu-guest-agent"; fi
            if systemctl is-active --quiet qemu-guest-agent 2>/dev/null; then verify_pass "QEMU guest agent active"; else verify_warn "QEMU guest agent active" "service is not active" "run sudo systemctl status qemu-guest-agent"; fi
        else
            verify_info "QEMU Guest Agent skipped by user choice"
        fi
    fi

    if [[ "$ATTACH_UBUNTU_PRO" =~ ^[Yy] ]]; then
        if [ "$UBUNTU_PRO_ATTACHED" == "yes" ] || [ "$UBUNTU_PRO_ATTACHED" == "already-attached" ]; then verify_pass "Ubuntu Pro attached"; else verify_warn "Ubuntu Pro attachment" "state is ${UBUNTU_PRO_ATTACHED}" "run pro status and attach manually if needed"; fi
    else
        verify_info "Ubuntu Pro attachment skipped by user choice"
    fi

    if [[ "$RUN_SYSTEM_UPDATE" =~ ^[Yy] ]]; then
        if [ "$SYSTEM_UPDATED" == "yes" ]; then verify_pass "System update completed"; else verify_warn "System update" "state is ${SYSTEM_UPDATED}" "review apt logs and rerun update if needed"; fi
    else
        verify_info "System update skipped by user choice"
    fi

    if [ "$UFW_ENABLED" == "yes" ]; then
        if [ -n "$SUDO_CMD" ]; then
            ufw_status="$(sudo -n ufw status verbose 2>/dev/null || true)"
        else
            ufw_status="$(ufw status verbose 2>/dev/null || true)"
        fi
        ufw_service_state="$(systemctl is-active ufw 2>/dev/null || true)"

        if grep -qi "Status:[[:space:]]*active" <<< "$ufw_status" || [ "$ufw_service_state" == "active" ]; then
            verify_pass "UFW firewall active"
        else
            verify_warn "UFW firewall active" "ufw status/systemctl did not confirm active" "run sudo -n ufw status verbose and sudo systemctl status ufw"
        fi

        if [ -n "$SUDO_CMD" ]; then
            ufw_ssh_rules="$(sudo -n ufw status 2>/dev/null | grep -E '22/tcp|OpenSSH' || true)"
        else
            ufw_ssh_rules="$(ufw status 2>/dev/null | grep -E '22/tcp|OpenSSH' || true)"
        fi

        if [ -n "$ufw_ssh_rules" ]; then verify_pass "UFW SSH rule present"; else verify_warn "UFW SSH rule" "OpenSSH/22 rule not confirmed" "run sudo -n ufw allow OpenSSH before enabling strict firewall rules"; fi
    elif [[ "$CONFIGURE_UFW" =~ ^[Yy] ]]; then
        verify_warn "UFW firewall" "state is ${UFW_ENABLED}" "run sudo -n ufw status verbose and inspect firewall setup"
    else
        verify_info "UFW setup skipped by user choice"
    fi


    if command -v crowdsec >/dev/null 2>&1 && command -v cscli >/dev/null 2>&1; then
        CROWDSEC_PACKAGE_INSTALLED="installed"
        verify_pass "CrowdSec package installed"
    else
        CROWDSEC_PACKAGE_INSTALLED="missing"
        verify_warn "CrowdSec package" "crowdsec/cscli command not found" "rerun Script 4 CrowdSec setup or install crowdsec"
    fi

    if systemctl is-enabled --quiet crowdsec 2>/dev/null; then
        verify_pass "CrowdSec service enabled"
    else
        verify_warn "CrowdSec service enabled" "service is not enabled" "run sudo systemctl enable --now crowdsec"
    fi

    if systemctl is-active --quiet crowdsec 2>/dev/null; then
        CROWDSEC_SERVICE_STATUS="active"
        verify_pass "CrowdSec service active"
    else
        CROWDSEC_SERVICE_STATUS="not-active"
        verify_warn "CrowdSec service active" "service is not active" "run sudo systemctl status crowdsec"
    fi

    if command -v cscli >/dev/null 2>&1; then
        if crowdsec_collection_installed 'crowdsecurity/linux' && \
           crowdsec_collection_installed 'crowdsecurity/sshd' && \
           crowdsec_collection_installed 'crowdsecurity/http-cve'; then
            CROWDSEC_COLLECTIONS_STATUS="ready"
            verify_pass "CrowdSec collections ready"
        else
            CROWDSEC_COLLECTIONS_STATUS="partial"
            verify_warn "CrowdSec collections" "baseline linux/sshd/http-cve collections not fully confirmed" "run sudo cscli collections list"
        fi
    else
        CROWDSEC_COLLECTIONS_STATUS="unavailable"
        verify_warn "CrowdSec collections" "cscli is unavailable" "install crowdsec and rerun verification"
    fi

    if [[ "$RUN_SYSTEM_CLEANUP" =~ ^[Yy] ]]; then
        if [ "$SYSTEM_CLEANED" == "yes" ]; then verify_pass "System cleanup completed"; else verify_warn "System cleanup" "state is ${SYSTEM_CLEANED}" "review apt autoremove/clean output"; fi
    else
        verify_info "System cleanup skipped by user choice"
    fi

    if [ -n "$SUDO_CMD" ]; then
        if sudo -n test -f /root/.ubuntu-vm-setup-completed; then verify_pass "Completion marker exists"; else verify_warn "Completion marker" "${COMPLETED_MARKER} missing" "rerun marker write step or inspect permissions"; fi
    else
        if test -f /root/.ubuntu-vm-setup-completed; then verify_pass "Completion marker exists"; else verify_warn "Completion marker" "${COMPLETED_MARKER} missing" "rerun marker write step or inspect permissions"; fi
    fi

    if [[ "$REBOOT_AFTER_FINISH" =~ ^[Yy] ]]; then
        verify_info "Auto reboot selected by user choice"
    else
        verify_info "Auto reboot skipped by user choice"
    fi

    if [ "$VERIFY_FAIL_COUNT" -gt 0 ]; then
        VERIFY_STATUS="FAIL"
    elif [ "$VERIFY_WARN_COUNT" -gt 0 ]; then
        VERIFY_STATUS="PASS_WITH_WARNINGS"
    else
        VERIFY_STATUS="PASS"
    fi

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" bash -c "cat > '$VERIFY_LOG'" <<EOF_VERIFY
--- UBUNTU VM SETUP VERIFICATION REPORT ---
Date: $(date)
Username: $USERNAME
Virt Type: $VIRT_TYPE
Container: $IS_CONTAINER
LXC: $IS_LXC
VM: $IS_VM
VERIFY_STATUS=$VERIFY_STATUS
VERIFY_PASS_COUNT=$VERIFY_PASS_COUNT
VERIFY_WARN_COUNT=$VERIFY_WARN_COUNT
VERIFY_FAIL_COUNT=$VERIFY_FAIL_COUNT

Results:
$(cat "$report_body")
EOF_VERIFY
    else
        cat > "$VERIFY_LOG" <<EOF_VERIFY
--- UBUNTU VM SETUP VERIFICATION REPORT ---
Date: $(date)
Username: $USERNAME
Virt Type: $VIRT_TYPE
Container: $IS_CONTAINER
LXC: $IS_LXC
VM: $IS_VM
VERIFY_STATUS=$VERIFY_STATUS
VERIFY_PASS_COUNT=$VERIFY_PASS_COUNT
VERIFY_WARN_COUNT=$VERIFY_WARN_COUNT
VERIFY_FAIL_COUNT=$VERIFY_FAIL_COUNT

Results:
$(cat "$report_body")
EOF_VERIFY
    fi

    rm -f "$report_body"
    msg_ok "VERIFICATION REPORT CREATED"
}


function load_state_from_completion_marker() {
    local marker_file="$COMPLETED_MARKER"
    local marker_username=""
    local value=""

    marker_username="$(marker_value_or_unknown_for_display "Username" "$marker_file")"
    if [ -n "$marker_username" ] && [ "$marker_username" != "unknown" ]; then
        USERNAME="$marker_username"
    elif [ -n "${SUDO_USER:-}" ]; then
        USERNAME="$SUDO_USER"
    elif [ -n "${USER:-}" ] && [ "${USER:-}" != "root" ]; then
        USERNAME="$USER"
    else
        USERNAME="$DEFAULT_USERNAME"
    fi

    value="$(marker_value_or_unknown_for_display "Virt Type" "$marker_file")"; [ "$value" != "unknown" ] && VIRT_TYPE="$value"
    value="$(marker_value_or_unknown_for_display "Container" "$marker_file")"; [ "$value" != "unknown" ] && IS_CONTAINER="$value"
    value="$(marker_value_or_unknown_for_display "LXC" "$marker_file")"; [ "$value" != "unknown" ] && IS_LXC="$value"
    value="$(marker_value_or_unknown_for_display "VM" "$marker_file")"; [ "$value" != "unknown" ] && IS_VM="$value"
    value="$(marker_value_or_unknown_for_display "SSH Hardened" "$marker_file")"; [ "$value" != "unknown" ] && SSH_HARDENING_APPLIED="$value"
    value="$(marker_value_or_unknown_for_display "UFW" "$marker_file")"; [ "$value" != "unknown" ] && UFW_ENABLED="$value"
    value="$(marker_value_or_unknown_for_display "QEMU Agent" "$marker_file")"; [ "$value" != "unknown" ] && QEMU_AGENT_INSTALLED="$value"
    value="$(marker_value_or_unknown_for_display "Root Expanded" "$marker_file")"; [ "$value" != "unknown" ] && ROOT_EXPANDED="$value"
    value="$(marker_value_or_unknown_for_display "Ubuntu Pro Attached" "$marker_file")"; [ "$value" != "unknown" ] && UBUNTU_PRO_ATTACHED="$value"
    value="$(marker_value_or_unknown_for_display "System Updated" "$marker_file")"; [ "$value" != "unknown" ] && SYSTEM_UPDATED="$value"
    value="$(marker_value_or_unknown_for_display "System Cleaned" "$marker_file")"; [ "$value" != "unknown" ] && SYSTEM_CLEANED="$value"
    value="$(marker_value_or_unknown_for_display "CrowdSec Package" "$marker_file")"; [ "$value" != "unknown" ] && CROWDSEC_PACKAGE_INSTALLED="$value"
    value="$(marker_value_or_unknown_for_display "CrowdSec Service" "$marker_file")"; [ "$value" != "unknown" ] && CROWDSEC_SERVICE_STATUS="$value"
    value="$(marker_value_or_unknown_for_display "CrowdSec Collections" "$marker_file")"; [ "$value" != "unknown" ] && CROWDSEC_COLLECTIONS_STATUS="$value"
    value="$(marker_value_or_unknown_for_display "CrowdSec Bouncer Package" "$marker_file")"; [ "$value" != "unknown" ] && CROWDSEC_BOUNCER_PACKAGE="$value"
    value="$(marker_value_or_unknown_for_display "CrowdSec Bouncer" "$marker_file")"; [ "$value" != "unknown" ] && CROWDSEC_BOUNCER_STATUS="$value"
    value="$(marker_value_or_unknown_for_display "Unattended Upgrades" "$marker_file")"; [ "$value" != "unknown" ] && UNATTENDED_UPGRADES_CONFIGURED="$value"

    if [ "$SSH_HARDENING_APPLIED" == "yes" ]; then APPLY_SSH_HARDENING="y"; else APPLY_SSH_HARDENING="n"; fi
    if [ "$UFW_ENABLED" == "yes" ]; then CONFIGURE_UFW="y"; else CONFIGURE_UFW="n"; fi
    if [ "$QEMU_AGENT_INSTALLED" == "yes" ]; then INSTALL_QEMU_AGENT="y"; else INSTALL_QEMU_AGENT="n"; fi
    if [ "$UBUNTU_PRO_ATTACHED" == "yes" ] || [ "$UBUNTU_PRO_ATTACHED" == "already-attached" ]; then ATTACH_UBUNTU_PRO="y"; else ATTACH_UBUNTU_PRO="n"; fi
    if [ "$SYSTEM_UPDATED" == "yes" ]; then RUN_SYSTEM_UPDATE="y"; else RUN_SYSTEM_UPDATE="n"; fi
    if [ "$SYSTEM_CLEANED" == "yes" ]; then RUN_SYSTEM_CLEANUP="y"; else RUN_SYSTEM_CLEANUP="n"; fi

    ROOT_FS_BEFORE_GB="$(get_root_filesystem_size_gb)"
    ROOT_FS_AFTER_GB="$ROOT_FS_BEFORE_GB"
    POST_REBOOT_VERIFY_MARKER="/home/${USERNAME}/.ubuntu-vm-setup-verify-displayed"

    return 0
}

function write_verify_display_log() {
    local display_tmp=""
    local result_lines=""
    local user_lines=""
    local system_lines=""
    local other_lines=""
    local status_color="$YW"

    display_tmp="$(mktemp)"
    TEMP_FILES+=("$display_tmp")

    if root_file_exists "$VERIFY_LOG"; then
        result_lines="$(root_cat_file "$VERIFY_LOG" 2>/dev/null | awk '/^Results:/{flag=1; next} flag {print}' || true)"
    fi

    user_lines="$(printf '%s
' "$result_lines" | grep -E 'User exists|User is in sudo group|SSH authorized_keys present|SSHD configuration valid|SSH password authentication disabled|SSH public key authentication enabled|Root SSH login disabled|SSH keyboard-interactive auth disabled' || true)"
    system_lines="$(printf '%s
' "$result_lines" | grep -E 'IPv4 address detected|QEMU guest agent enabled|QEMU guest agent active|UFW firewall active|UFW SSH rule present|System cleanup completed|Completion marker exists|CrowdSec package installed|CrowdSec service enabled|CrowdSec service active|CrowdSec collections ready' || true)"
    other_lines="$(printf '%s
' "$result_lines" | grep -Ev 'User exists|User is in sudo group|SSH authorized_keys present|SSHD configuration valid|SSH password authentication disabled|SSH public key authentication enabled|Root SSH login disabled|SSH keyboard-interactive auth disabled|IPv4 address detected|QEMU guest agent enabled|QEMU guest agent active|UFW firewall active|UFW SSH rule present|System cleanup completed|Completion marker exists|CrowdSec package installed|CrowdSec service enabled|CrowdSec service active|CrowdSec collections ready' || true)"

    case "$VERIFY_STATUS" in
        PASS) status_color="$GN" ;;
        PASS_WITH_WARNINGS) status_color="$YW" ;;
        FAIL) status_color="$RD" ;;
        *) status_color="$YW" ;;
    esac

    display_colorize_lines() {
        local lines="$1"
        local fallback="$2"

        if [ -n "$lines" ]; then
            while IFS= read -r line; do
                case "$line" in
                    "✓ PASS - "*) echo -e "  ${GN}${line}${CL}" ;;
                    "! WARN - "*) echo -e "  ${YW}${line}${CL}" ;;
                    "✗ FAIL - "*) echo -e "  ${RD}${line}${CL}" ;;
                    "- INFO - "*) echo -e "  ${BL}${line}${CL}" ;;
                    *) echo -e "  ${DGN}${line}${CL}" ;;
                esac
            done <<< "$lines"
        else
            echo -e "  ${BL}- INFO - ${fallback}${CL}"
        fi
    }

    {
        echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
        echo -e "${BL}SCRIPT 4 POST-REBOOT VERIFICATION${CL}"
        echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
        echo ""
        echo -e "${YW}User / SSH:${CL}"
        display_colorize_lines "$user_lines" "No User / SSH verification lines recorded"
        echo ""
        echo -e "${YW}System:${CL}"
        display_colorize_lines "$system_lines" "No System verification lines recorded"
        if [ -n "$other_lines" ]; then display_colorize_lines "$other_lines" ""; fi
        echo ""
        echo -e "${YW}CrowdSec:${CL}"
        echo -e "  ${BL}Package:${CL} ${GN}${CROWDSEC_PACKAGE_INSTALLED}${CL}"
        echo -e "  ${BL}Service:${CL} ${GN}${CROWDSEC_SERVICE_STATUS}${CL}"
        echo -e "  ${BL}Collections:${CL} ${GN}${CROWDSEC_COLLECTIONS_STATUS}${CL}"
        echo -e "  ${BL}Bouncer:${CL} ${GN}${CROWDSEC_BOUNCER_STATUS}${CL}"
        echo ""
        echo -e "${YW}Storage:${CL}"
        echo -e "  ${BL}Root filesystem:${CL} ${GN}${ROOT_FS_AFTER_GB}${CL}"
        echo -e "  ${BL}Root expansion:${CL} ${GN}${ROOT_EXPANDED}${CL}"
        echo ""
        echo -e "${YW}Verification:${CL}"
        echo -e "  ${BL}Status:${CL} ${status_color}${VERIFY_STATUS}${CL}"
        echo -e "  ${BL}Passed checks:${CL} ${GN}${VERIFY_PASS_COUNT}${CL}"
        echo -e "  ${BL}Warnings:${CL} ${YW}${VERIFY_WARN_COUNT}${CL}"
        echo -e "  ${BL}Failed checks:${CL} ${RD}${VERIFY_FAIL_COUNT}${CL}"
        echo -e "  ${BL}Verify log:${CL} ${GN}${VERIFY_LOG}${CL}"
        echo ""
        echo -e "${YW}Next Step:${CL}"
        echo -e "  ${YW}Run ${ANS}Script 5${YW}.${CL}"
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

function install_post_reboot_verify_hook() {
    local helper_tmp=""
    local hook_tmp=""
    local display_marker="/home/${USERNAME}/.ubuntu-vm-setup-verify-displayed"

    POST_REBOOT_VERIFY_MARKER="$display_marker"

    helper_tmp="$(mktemp)"
    hook_tmp="$(mktemp)"
    TEMP_FILES+=("$helper_tmp" "$hook_tmp")

    cat > "$helper_tmp" <<EOF_HELPER
#!/usr/bin/env bash
set +e
COMPLETED_MARKER="$COMPLETED_MARKER"
VERIFY_DISPLAY_LOG="$VERIFY_DISPLAY_LOG"
DISPLAY_MARKER="$display_marker"
TARGET_USER="$USERNAME"

if [ -f "\$COMPLETED_MARKER" ]; then
    :
elif command -v sudo >/dev/null 2>&1 && sudo -n test -f "\$COMPLETED_MARKER" >/dev/null 2>&1; then
    :
else
    [ -f "\$VERIFY_DISPLAY_LOG" ] || exit 0
fi

[ -f "\$VERIFY_DISPLAY_LOG" ] || exit 0
[ -n "\${SSH_CONNECTION:-}" ] || exit 0
[ "\${USER:-}" = "\$TARGET_USER" ] || exit 0
[ -f "\$DISPLAY_MARKER" ] && exit 0

cat "\$VERIFY_DISPLAY_LOG" 2>/dev/null || true
mkdir -p "\$(dirname "\$DISPLAY_MARKER")" 2>/dev/null || true
touch "\$DISPLAY_MARKER" 2>/dev/null || true
exit 0
EOF_HELPER

    cat > "$hook_tmp" <<'EOF_HOOK'
case "$-" in
  *i*) ;;
  *) return 0 2>/dev/null || exit 0 ;;
esac

[ -n "${SSH_CONNECTION:-}" ] || return 0 2>/dev/null || exit 0

/usr/local/sbin/circl8-script4-post-reboot-verify 2>/dev/null || true
return 0 2>/dev/null || exit 0
EOF_HOOK

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" cp "$helper_tmp" "$POST_REBOOT_VERIFY_HELPER" 2>/dev/null || true
        "$SUDO_CMD" chmod 0755 "$POST_REBOOT_VERIFY_HELPER" 2>/dev/null || true
        "$SUDO_CMD" cp "$hook_tmp" "$POST_REBOOT_VERIFY_HOOK" 2>/dev/null || true
        "$SUDO_CMD" chmod 0644 "$POST_REBOOT_VERIFY_HOOK" 2>/dev/null || true
    else
        cp "$helper_tmp" "$POST_REBOOT_VERIFY_HELPER" 2>/dev/null || true
        chmod 0755 "$POST_REBOOT_VERIFY_HELPER" 2>/dev/null || true
        cp "$hook_tmp" "$POST_REBOOT_VERIFY_HOOK" 2>/dev/null || true
        chmod 0644 "$POST_REBOOT_VERIFY_HOOK" 2>/dev/null || true
    fi

    rm -f "$helper_tmp" "$hook_tmp"
}

function update_completion_marker_script4_fields() {
    local marker_tmp=""
    local existing_marker=""
    local display_marker="/home/${USERNAME}/.ubuntu-vm-setup-verify-displayed"

    POST_REBOOT_VERIFY_MARKER="$display_marker"
    marker_tmp="$(mktemp)"
    TEMP_FILES+=("$marker_tmp")

    if root_file_exists "$COMPLETED_MARKER"; then
        existing_marker="$(root_cat_file "$COMPLETED_MARKER" 2>/dev/null | grep -Ev '^SCRIPT4_' || true)"
    fi

    {
        [ -n "$existing_marker" ] && printf '%s
' "$existing_marker"
        echo "SCRIPT4_STATUS=completed"
        echo "SCRIPT4_VERSION=$SCRIPT_VERSION"
        echo "SCRIPT4_BUILD=$SCRIPT_BUILD"
        echo "SCRIPT4_VERIFY_STATUS=$VERIFY_STATUS"
        echo "SCRIPT4_VERIFY_LOG=$VERIFY_LOG"
        echo "SCRIPT4_VERIFY_DISPLAY_LOG=$VERIFY_DISPLAY_LOG"
        echo "SCRIPT4_POST_REBOOT_DISPLAY_HOOK=$POST_REBOOT_VERIFY_HOOK"
        echo "SCRIPT4_POST_REBOOT_DISPLAY_MARKER=$display_marker"
        echo "SCRIPT4_USERNAME=$USERNAME"
        echo "SCRIPT4_ROOT_EXPANDED=$ROOT_EXPANDED"
        echo "SCRIPT4_UFW_ENABLED=$UFW_ENABLED"
        echo "SCRIPT4_CROWDSEC_PACKAGE=$CROWDSEC_PACKAGE_INSTALLED"
        echo "SCRIPT4_CROWDSEC_SERVICE=$CROWDSEC_SERVICE_STATUS"
        echo "SCRIPT4_CROWDSEC_COLLECTIONS=$CROWDSEC_COLLECTIONS_STATUS"
        echo "SCRIPT4_CROWDSEC_BOUNCER_PACKAGE=$CROWDSEC_BOUNCER_PACKAGE"
        echo "SCRIPT4_CROWDSEC_BOUNCER=$CROWDSEC_BOUNCER_STATUS"
        echo "SCRIPT4_QEMU_AGENT=$QEMU_AGENT_INSTALLED"
        echo "SCRIPT4_SSH_HARDENED=$SSH_HARDENING_APPLIED"
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

function show_verify_only_summary() {
    section_flash_success "     ━━━━━━━━━━━━━━━━━    FINISHED    ━━━━━━━━━━━━━━━━━"

    echo -e "${YW}Verification:${CL}"
    case "$VERIFY_STATUS" in
        PASS) echo -e "  ${BL}Status:${CL} ${GN}${VERIFY_STATUS}${CL}" ;;
        PASS_WITH_WARNINGS) echo -e "  ${BL}Status:${CL} ${YW}${VERIFY_STATUS}${CL}" ;;
        FAIL) echo -e "  ${BL}Status:${CL} ${RD}${VERIFY_STATUS}${CL}" ;;
        *) echo -e "  ${BL}Status:${CL} ${YW}${VERIFY_STATUS:-unknown}${CL}" ;;
    esac
    echo -e "  ${BL}Passed checks:${CL} ${GN}${VERIFY_PASS_COUNT}${CL}"
    echo -e "  ${BL}Warnings:${CL} ${YW}${VERIFY_WARN_COUNT}${CL}"
    echo -e "  ${BL}Failed checks:${CL} ${RD}${VERIFY_FAIL_COUNT}${CL}"
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
    echo -e "${BL}Next Step:${CL}"
    echo -e "  ${YW}Run ${ANS}Script 5${YW}.${CL}"
    echo ""
}

function run_verify_only_mode() {
    VERIFY_ONLY_MODE="yes"

    load_state_from_completion_marker
    create_verification_report
    write_verify_display_log
    update_completion_marker_script4_fields
    show_verify_only_summary

    exit 0
}

# --- 45. FINAL SUMMARY ---
function show_final_summary() {
    section_flash_success "     ━━━━━━━━━━━━━━━━━    FINISHED    ━━━━━━━━━━━━━━━━━"

    detail_line "USERNAME" "$USERNAME"
    detail_line "USER CREATED" "$SUDO_USER_CREATED"
    detail_line "USER ADDED TO SUDO" "$USER_ADDED_TO_SUDO"
    detail_line "PASSWORD LOCKED" "$USER_PASSWORD_LOCKED"
    detail_line "SSH KEYS" "$SSH_KEYS_CONFIGURED"

    if [ "$IS_CONTAINER" == "yes" ]; then
        detail_line "ENVIRONMENT" "LXC/Container (${VIRT_TYPE})"
    else
        detail_line "ENVIRONMENT" "VM (${VIRT_TYPE})"
    fi

    detail_line "UBUNTU PRO ATTACHED" "$UBUNTU_PRO_ATTACHED"
    detail_line "ESM APPS" "$UBUNTU_PRO_ESM_APPS"
    detail_line "ESM INFRA" "$UBUNTU_PRO_ESM_INFRA"
    detail_line "LIVEPATCH" "$UBUNTU_PRO_LIVEPATCH"
    detail_line "SYSTEM UPDATED" "$SYSTEM_UPDATED"
    detail_line "QEMU GUEST AGENT" "$QEMU_AGENT_INSTALLED"
    detail_line "ROOT EXPANDED" "$ROOT_EXPANDED"
    detail_line "UFW FIREWALL" "$UFW_ENABLED"
    detail_line "CROWDSEC" "$CROWDSEC_SERVICE_STATUS"
    detail_line "SSH HARDENING" "$SSH_HARDENING_APPLIED"
    detail_line "SYSTEM CLEANED" "$SYSTEM_CLEANED"

    echo ""
    echo -e "${YW}CrowdSec:${CL}"
    echo -e "  ${BL}Package:${CL} ${GN}${CROWDSEC_PACKAGE_INSTALLED}${CL}"
    echo -e "  ${BL}Service:${CL} ${GN}${CROWDSEC_SERVICE_STATUS}${CL}"
    echo -e "  ${BL}Collections:${CL} ${GN}${CROWDSEC_COLLECTIONS_STATUS}${CL}"
    echo -e "  ${BL}Bouncer:${CL} ${GN}${CROWDSEC_BOUNCER_STATUS}${CL}"

    echo ""
    echo -e "${YW}Storage:${CL}"
    echo -e "  ${BL}Root filesystem before:${CL} ${GN}${ROOT_FS_BEFORE_GB}${CL}"
    echo -e "  ${BL}Root filesystem after:${CL} ${GN}${ROOT_FS_AFTER_GB}${CL}"
    echo -e "  ${BL}Root expansion:${CL} ${GN}${ROOT_EXPANDED}${CL}"

    echo ""
    echo -e "${YW}Verification:${CL}"
    case "$VERIFY_STATUS" in
        PASS) echo -e "  ${BL}Status:${CL} ${GN}${VERIFY_STATUS}${CL}" ;;
        PASS_WITH_WARNINGS) echo -e "  ${BL}Status:${CL} ${YW}${VERIFY_STATUS}${CL}" ;;
        FAIL) echo -e "  ${BL}Status:${CL} ${RD}${VERIFY_STATUS}${CL}" ;;
        *) echo -e "  ${BL}Status:${CL} ${YW}${VERIFY_STATUS:-unknown}${CL}" ;;
    esac
    echo -e "  ${BL}Passed checks:${CL} ${GN}${VERIFY_PASS_COUNT}${CL}"
    echo -e "  ${BL}Warnings:${CL} ${YW}${VERIFY_WARN_COUNT}${CL}"
    echo -e "  ${BL}Failed checks:${CL} ${RD}${VERIFY_FAIL_COUNT}${CL}"
    echo -e "  ${BL}Setup log:${CL} ${GN}${LOG_FILE}${CL}"
    echo -e "  ${BL}Verify log:${CL} ${GN}${VERIFY_LOG}${CL}"

    if [ -n "$VERIFY_FIRST_ISSUE_TYPE" ]; then
        echo ""
        echo -e "${YW}${VERIFY_FIRST_ISSUE_TYPE} 1:${CL}"
        echo -e "  ${BL}Check:${CL} ${GN}${VERIFY_FIRST_ISSUE_CHECK}${CL}"
        echo -e "  ${BL}Reason:${CL} ${YW}${VERIFY_FIRST_ISSUE_REASON}${CL}"
        echo -e "  ${BL}Fix:${CL} ${GN}${VERIFY_FIRST_ISSUE_FIX}${CL}"
    fi

    echo ""
    echo -e "${GN}Ubuntu setup completed successfully.${CL}"
    echo ""
    echo -e "${BL}Next Step${CL}"
    echo ""
    if [[ "$REBOOT_AFTER_FINISH" =~ ^[Yy] ]]; then
        echo -e "${YW}Reboot the VM, SSH back in, then run ${ANS}Script 5${YW}.${CL}"
    else
        echo -e "${YW}Option A - ${GN}reboot first:${CL}"
        echo -e "  ${YW}Reboot the VM manually, SSH back in, then run ${ANS}Script 5${YW}.${CL}"
        echo ""
        echo -e "${YW}Option B - ${GN}continue now:${CL}"
        echo -e "  ${YW}Run ${ANS}Script 5${YW} when you are ready.${CL}"
    fi
}

# --- 46. REBOOT PROMPT ---
function reboot_prompt() {
    section "REBOOT"

    if [[ ! "$REBOOT_AFTER_FINISH" =~ ^[Yy] ]]; then
        msg_skip "AUTO REBOOT SKIPPED"
        echo -e "${YW}Reboot manually when ready.${CL}"
        return 0
    fi

    if [ "$IS_CONTAINER" == "yes" ]; then
        echo -e "${YW}Container mode detected. Reboot/restart may be controlled from the Proxmox host.${CL}"
        echo -e "${YW}Reboot skipped. Restart the container from Proxmox host if needed.${CL}"
        return 0
    fi

    if timed_reboot_countdown "$REBOOT_T"; then
        if [ -n "$SUDO_CMD" ]; then "$SUDO_CMD" reboot; else reboot; fi
    fi
}

# =========================================================
#  MAIN ORCHESTRATION
# =========================================================

# --- 47. MAIN FUNCTION ---
function main() {
    guard_script4_environment
    init_script
    check_previous_marker
    detect_environment
    start_confirmation

    # Phase 1: all questions first.
    collect_username
    collect_ubuntu_pro_inputs
    collect_system_action_inputs
    show_ready_summary_and_confirm

    # Phase 2: apply changes after final confirmation.
    apply_user_setup
    apply_ubuntu_pro
    update_system_packages
    install_qemu_guest_agent
    expand_root_lvm_if_possible
    configure_ufw_firewall
    apply_crowdsec_security
    harden_ssh
    clean_system

    # Phase 3: verify, summarize and reboot.
    write_completion_marker
    create_verification_report
    write_verify_display_log
    install_post_reboot_verify_hook
    update_completion_marker_script4_fields
    show_final_summary
    reboot_prompt

    exit 0
}

if is_environment_check_mode "$@"; then
    guard_script4_environment
    echo -e "${CM} ${GN}Script 4 environment check passed. Ubuntu VM detected.${CL}"
    exit 0
fi

main "$@"
