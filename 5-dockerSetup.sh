#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Docker Setup
# =========================================================

# --- 1. COLOR VARIABLES (KEEP ALL FOR FUTURE MODIFICATIONS) ---
# Central visual theme for Docker Setup.
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

SCRIPT_SOURCE="5-dockerSetup.sh"
SCRIPT_VERSION="v1.2.1"
SCRIPT_UPDATED="2026-06-06"
SCRIPT_BUILD="standard-ui-verification-reboot"

# --- 2. GLOBAL VARIABLES ---
# Stores timer, log paths, user choices, environment state and final status values.
T=15
REBOOT_T=30

LOG_FILE="/var/log/docker-setup.log"
RUNTIME_LOG_FILE=""
VERIFY_LOG="/var/log/docker-setup-verify.log"
VERIFY_DISPLAY_LOG="/var/log/docker-setup-verify-display.log"
POST_REBOOT_VERIFY_HOOK="/etc/profile.d/circl8-script5-post-reboot-verify.sh"
POST_REBOOT_VERIFY_HELPER="/usr/local/sbin/circl8-script5-post-reboot-verify"
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
COMPLETED_MARKER="/root/.docker-setup-completed"

DEFAULT_TARGET_USER="${SUDO_USER:-orik}"
TARGET_USER="$DEFAULT_TARGET_USER"

SUDO_CMD=""

IS_CONTAINER="no"
IS_LXC="no"
IS_VM="no"
VIRT_TYPE="unknown"

EXISTING_SETUP="no"
DOCKER_CLI_FOUND="no"
DOCKER_DAEMON_CONFIG_FOUND="no"
DOCKER_MARKER_FOUND="no"
DOCKER_SERVICE_ACTIVE="no"
CONTAINERD_SERVICE_ACTIVE="no"

DISABLE_SWAP="y"
INSTALL_DOCKER_GC="y"
CONFIGURE_UFW="y"
DOCKER_FIREWALL_MODE="docker-iptables-enabled"
REBOOT_AFTER_FINISH="y"

DOCKER_INSTALLED="no"
DOCKER_SERVICE_ENABLED="no"
CONTAINERD_SERVICE_ENABLED="no"
DOCKER_GROUP_READY="no"
USER_ADDED_TO_DOCKER="no"
DAEMON_CONFIG_VALID="no"
UFW_ENABLED="no"
SWAP_DISABLED="no"
DOCKER_GC_INSTALLED="no"
DOCKER_GC_TIMER_INSTALLED="no"
REDIS_OVERCOMMIT_CONFIGURED="no"
REDIS_OVERCOMMIT_VALUE="unknown"

UBUNTU_CODENAME=""
ARCHITECTURE=""

TEMP_FILES=()
APPLY_CHANGES_SECTION_SHOWN="no"
APPLY_CURRENT_GROUP=""

# =========================================================
#  OUTPUT / LOGGING FUNCTIONS
# =========================================================

# --- 3. HEADER FUNCTION ---
# Displays the Docker Setup banner.
function header_info {
echo -e "${BL}
██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗     ███████╗███████╗████████╗██╗   ██╗██████╗ 
██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝    ███████╗█████╗     ██║   ██║   ██║██████╔╝
██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██║     
╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     
${CL}"
}

# --- 4. MESSAGE HELPER FUNCTIONS ---
# Provides consistent status messages.
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
# Keeps terminal output organized into readable stages.
function section() {
    echo ""
    echo -e "${BORDER}"
    echo -e "${BL}$1${CL}"
    echo -e "${BORDER}"
}

# --- 5A. FLASHING SUCCESS SECTION HEADER HELPER ---
# Uses the same section layout as script 1, but renders final success headings in bold flashing green.
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

# --- 5B. DETAIL LINE HELPER ---
# Prints clean script 1-style detail lines for summaries and audit output.
function detail_line() {
    local label="$1"
    local value="$2"
    echo -e " ${BL}━━━━━▶${CL} ${label}: ${GN}${value}${CL}"
}

# --- 6. TTY OUTPUT HELPER ---
# Prints directly to terminal from prompt functions.
function tty_print() {
    if [ -w /dev/tty ]; then
        echo -ne "$*" > /dev/tty
    else
        echo -ne "$*" >&2
    fi
}

# --- 7. TTY OUTPUT WITH NEWLINE HELPER ---
# Prints directly to terminal with newline.
function tty_println() {
    if [ -w /dev/tty ]; then
        echo -e "$*" > /dev/tty
    else
        echo -e "$*" >&2
    fi
}

# =========================================================
#  CLEANUP / ERROR HANDLING
# =========================================================

# --- 8. CLEANUP FUNCTION ---
# Removes temporary files created during repository/key/command handling.
function cleanup() {
    local exit_code="$?"
    local file=""

    # When running as a non-root user, write logs to a user-writable temp file first.
    # This avoids routing interactive prompts through sudo tee, which can break prompt ordering.
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
# Shows failing line number and points to the log file.
function on_error() {
    local line_no="$1"
    echo -e "${RD}ERROR:${CL} Script failed at line ${line_no}. Check ${LOG_FILE}"
}

# --- 10. COMMAND RUNNER ---
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

# --- 14. ROOT FILE CAT HELPER ---
# Reads root-owned file content.
function root_cat_file() {
    local path="$1"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" cat "$path"
    else
        cat "$path"
    fi
}

# =========================================================
#  PROMPT FUNCTIONS
# =========================================================

# --- 15. INPUT BUFFER FLUSH HELPER ---
# Clears leftover buffered keyboard input between prompts.
# This prevents ENTER/SPACE from needing to be pressed twice on Ubuntu terminal sessions.
function flush_input_buffer() {
    local junk=""
    local i=""

    # Never flush stdin. Streamed/process-substituted scripts may use stdin for script content.
    [ -r /dev/tty ] || return 0

    for i in {1..20}; do
        if ! IFS= read -rsn1 -t 0.02 junk < /dev/tty 2>/dev/null; then
            break
        fi
    done

    return 0
}

# --- 16. YES/NO LABEL HELPER ---
# Converts Y/N answers to visible yes/no.
function yes_no_label() {
    local value="$1"

    if [[ "$value" =~ ^[Yy]$ ]]; then
        echo "yes"
    else
        echo "no"
    fi
}

# --- 17. BLOCKING YES/NO HELPER ---
# Used after SPACE is pressed during a timed Y/n prompt.
# The countdown disappears and the prompt waits for Y/N/ENTER.
# ENTER accepts the default.
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

# --- 18. TIMED YES/NO PROMPT HELPER ---
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
    tty_println "${CM} ${GN}${prompt}${CL} ${ANS}${final_label}${CL}"
    flush_input_buffer

    echo "$answer"
}

# --- 19. EDITABLE INPUT LOOP HELPER ---
# Shared editable input system for text prompts.
# The initial key is passed into the same editable buffer, so Backspace/Delete can delete it.
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

# --- 20. TIMED TEXT INPUT HELPER ---
# Shows wall-clock countdown.
# SPACE pauses with empty editable buffer.
# Any typed character pauses with that character already inside the editable buffer.
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

# --- 21. REBOOT COUNTDOWN HELPER ---
# Offers Ubuntu VM Setup-compatible reboot flow so Docker group membership applies cleanly.
# ENTER/Y = reboot now.
# SPACE/N = cancel reboot.
# Timeout = reboot automatically.
function timed_reboot_countdown() {
    local seconds="$1"
    local key=""
    local deadline=""
    local now=""
    local remaining=""
    local first_draw="yes"

    deadline=$(( $(date +%s) + seconds ))

    while true; do
        now=$(date +%s)
        remaining=$(( deadline - now ))

        if [ "$remaining" -le 0 ]; then
            if [ "$first_draw" == "no" ]; then
                tty_print "\033[2A\033[2K\r\033[1B\033[2K\r\033[1A"
            fi
            return 0
        fi

        if [ "$first_draw" == "yes" ]; then
            first_draw="no"
        else
            tty_print "\033[2A\033[2K\r\033[1B\033[2K\r\033[1A"
        fi

        tty_print "${BL}${CLF}REBOOTING IN ${remaining} SECONDS...${CL}\n${YW}(ENTER/Y = Reboot Now, SPACE/N = Cancel)${CL}\n"

        if [ -r /dev/tty ]; then
            if IFS= read -rsn1 -t 1 key < /dev/tty; then
                case "$key" in
                    ""|[Yy])
                        tty_print "\033[2A\033[2K\r\033[1B\033[2K\r\033[1A"
                        tty_println "${BL}${CLF}REBOOTING NOW...${CL}"
                        flush_input_buffer
                        return 0
                        ;;
                    " "|[Nn])
                        tty_print "\033[2A\033[2K\r\033[1B\033[2K\r\033[1A"
                        tty_println "${YW}Reboot countdown stopped. Reboot manually when ready.${CL}"
                        flush_input_buffer
                        return 1
                        ;;
                esac
            fi
        else
            if IFS= read -rsn1 -t 1 key; then
                case "$key" in
                    ""|[Yy])
                        tty_print "\033[2A\033[2K\r\033[1B\033[2K\r\033[1A"
                        tty_println "${BL}${CLF}REBOOTING NOW...${CL}"
                        flush_input_buffer
                        return 0
                        ;;
                    " "|[Nn])
                        tty_print "\033[2A\033[2K\r\033[1B\033[1A"
                        tty_println "${YW}Reboot countdown stopped. Reboot manually when ready.${CL}"
                        flush_input_buffer
                        return 1
                        ;;
                esac
            fi
        fi
    done
}

# =========================================================
#  VALIDATION HELPERS
# =========================================================

# --- 22. USERNAME VALIDATION HELPER ---
# Validates Linux username format before using it in usermod/group logic.
function validate_linux_username() {
    local username="$1"

    if [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        return 0
    fi

    return 1
}

# --- 23. DEPENDENCY VALIDATION ---
# Validates base commands before system changes.
function validate_dependencies() {
    local required_commands=(
        apt-cache
        apt-get
        awk
        cat
        chmod
        cp
        date
        dpkg
        getent
        grep
        groupadd
        id
        install
        mkdir
        mktemp
        rm
        sed
        swapoff
        swapon
        systemctl
        tee
        uname
        usermod
        xargs
    )

    local cmd=""

    for cmd in "${required_commands[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || msg_error "Required command not found: ${cmd}"
    done

    if [ -n "$SUDO_CMD" ]; then
        command -v sudo >/dev/null 2>&1 || msg_error "sudo is required when not running as root."
    fi
}

# --- 24. DAEMON JSON VALIDATION HELPER ---
# Validates daemon.json before restarting Docker.
function validate_docker_daemon_json() {
    if command -v dockerd >/dev/null 2>&1; then
        if dockerd --validate --config-file /etc/docker/daemon.json >/dev/null 2>&1; then
            DAEMON_CONFIG_VALID="yes"
            return 0
        fi
    fi

    if command -v python3 >/dev/null 2>&1; then
        if python3 -m json.tool /etc/docker/daemon.json >/dev/null 2>&1; then
            DAEMON_CONFIG_VALID="yes"
            return 0
        fi
    fi

    DAEMON_CONFIG_VALID="no"
    return 1
}

function apt_lock_holders() {
    local lock=""
    local output=""

    if ! command -v fuser >/dev/null 2>&1; then
        return 0
    fi

    for lock in /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock; do
        if [ -e "$lock" ]; then
            output="$(fuser -v "$lock" 2>&1 || true)"
            [ -n "$output" ] && printf '%s\n' "$output"
        fi
    done
}

function wait_for_apt_locks() {
    local waited="0"
    local timeout="180"
    local holders=""

    if ! command -v fuser >/dev/null 2>&1; then
        return 0
    fi

    while true; do
        holders="$(apt_lock_holders || true)"
        if [ -z "$holders" ]; then
            return 0
        fi

        if [ "$waited" -ge "$timeout" ]; then
            echo ""
            echo -e "${RD}APT/dpkg lock still held.${CL}"
            echo -e "${YW}Holder:${CL}"
            printf '%s\n' "$holders" | sed 's/^/  /'
            echo ""
            echo -e "${YW}Fix:${CL}"
            echo -e "  Wait for apt/unattended-upgrades to finish, then rerun Script 5."
            exit 1
        fi

        if [ "$waited" -eq 0 ]; then
            msg_info "Waiting for apt/dpkg locks"
        fi

        sleep 5
        waited="$(( waited + 5 ))"
    done
}

function validate_docker_package_availability() {
    local packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
    local pkg=""
    local missing=()

    for pkg in "${packages[@]}"; do
        if ! apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ { if ($2 != "(none)") found=1 } END { exit found ? 0 : 1 }'; then
            missing+=("$pkg")
        fi
    done

    if [ "${#missing[@]}" -gt 0 ]; then
        echo ""
        echo -e "${RD}Docker packages are not available for detected Ubuntu codename: ${UBUNTU_CODENAME}.${CL}"
        echo ""
        echo -e "${YW}Detected:${CL}"
        echo -e "  ${BL}Ubuntu codename:${CL} ${GN}${UBUNTU_CODENAME}${CL}"
        echo -e "  ${BL}Architecture:${CL} ${GN}${ARCHITECTURE}${CL}"
        echo -e "  ${BL}Missing packages:${CL} ${RD}${missing[*]}${CL}"
        echo ""
        echo -e "${YW}Fix:${CL}"
        echo -e "  Check Docker repository support for this Ubuntu release, or update Script 5 fallback policy."
        exit 1
    fi

    msg_ok "DOCKER PACKAGES AVAILABLE"
}

# =========================================================
#  INITIALIZATION
# =========================================================

# --- 25. ROOT / SUDO DETECTION ---
# Uses sudo when not root.
function detect_root_or_sudo() {
    if [ "$EUID" -eq 0 ]; then
        SUDO_CMD=""
    else
        SUDO_CMD="sudo"
    fi
}

# --- 26. SUDO VALIDATION ---
# Validates sudo once near the start so authentication failures happen before changes.
function validate_sudo_access() {
    if [ -n "$SUDO_CMD" ]; then
        echo -e "${YW}Sudo privileges are required for Docker Setup.${CL}"

        # Script 3.5 creates an SSH-key-only user with NOPASSWD sudo.
        # Test that path first so the script never asks for a password unnecessarily.
        if "$SUDO_CMD" -n true >/dev/null 2>&1; then
            echo -e " ${CM} ${GN}PASSWORDLESS SUDO CONFIRMED${CL}"
            return 0
        fi

        # Fallback for manually-created Ubuntu users that do have a normal sudo password.
        if "$SUDO_CMD" -v; then
            echo -e " ${CM} ${GN}SUDO ACCESS CONFIRMED${CL}"
            return 0
        fi

        echo -e "${RD}ERROR:${CL} Sudo authentication failed."
        exit 1
    fi
}

# --- 27. LOGGING INITIALIZATION ---
# Logs output and reports failing line. Uses sudo tee when not running as root.
function init_logging() {
    if [ -n "$SUDO_CMD" ]; then
        # Avoid piping interactive output through sudo tee.
        # Prompt functions write to /dev/tty and normal output is logged to a temp file first.
        RUNTIME_LOG_FILE="$(mktemp /tmp/docker-setup-log.XXXXXX)"
        TEMP_FILES+=("$RUNTIME_LOG_FILE")
        exec > >(tee -a "$RUNTIME_LOG_FILE") 2>&1
    else
        RUNTIME_LOG_FILE="$LOG_FILE"
        exec > >(tee -a "$LOG_FILE") 2>&1
    fi
}

# --- 28. SCRIPT INITIALIZATION ---
# Starts sudo, logging, traps, banner and validation.
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

# =========================================================
#  ENVIRONMENT / RERUN SAFETY
# =========================================================

# --- 29. ENVIRONMENT DETECTION ---
# Detects VM, LXC/container, or unknown host.
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
        fi
    fi

    if [ "$IS_CONTAINER" == "yes" ]; then
        CONFIGURE_UFW="n"
        DISABLE_SWAP="n"
        msg_ok "ENVIRONMENT DETECTED (${VIRT_TYPE} container)"
    elif [ "$IS_VM" == "yes" ]; then
        CONFIGURE_UFW="y"
        DISABLE_SWAP="y"
        msg_ok "ENVIRONMENT DETECTED (${VIRT_TYPE} VM)"
    else
        CONFIGURE_UFW="y"
        DISABLE_SWAP="y"
        msg_warn "Environment is not clearly VM/LXC (${VIRT_TYPE}); continuing with VM-style defaults"
        IS_VM="yes"
    fi
}

# --- 30. PREVIOUS MARKER CHECK ---
# Warns if Docker Setup was already completed previously.
function marker_display_value() {
    local label="$1"
    local file="$2"
    local value=""

    if root_path_exists "$file"; then
        value="$(root_cat_file "$file" 2>/dev/null | awk -F': ' -v label="$label" '$1 == label { $1=""; sub(/^: /, ""); print; exit }' | xargs || true)"
    fi

    [ -n "$value" ] || value="unknown"
    echo "$value"
}

function marker_key_value() {
    local key="$1"
    local file="$2"
    local value=""

    if root_path_exists "$file"; then
        value="$(root_cat_file "$file" 2>/dev/null | awk -F= -v key="$key" '$1 == key { $1=""; sub(/^=/, ""); print; exit }' | xargs || true)"
    fi

    echo "$value"
}

function show_previous_marker_compact_summary() {
    local marker_file="$1"
    local virt_type=""
    local is_container=""
    local is_vm=""
    local environment="unknown"

    virt_type="$(marker_display_value "Virt Type" "$marker_file")"
    is_container="$(marker_display_value "Container" "$marker_file")"
    is_vm="$(marker_display_value "VM" "$marker_file")"

    if [ "$is_container" == "yes" ]; then
        environment="Container (${virt_type})"
    elif [ "$is_vm" == "yes" ]; then
        environment="VM (${virt_type})"
    elif [ "$virt_type" != "unknown" ]; then
        environment="$virt_type"
    fi

    echo -e "${YW}Existing setup:${CL}"
    echo -e "  ${BL}Completed:${CL} ${GN}$(marker_display_value "Docker Setup completed on" "$marker_file")${CL}"
    echo -e "  ${BL}Target user:${CL} ${GN}$(marker_display_value "Target user" "$marker_file")${CL}"
    echo -e "  ${BL}Environment:${CL} ${GN}${environment}${CL}"
    echo -e "  ${BL}Docker installed:${CL} ${GN}$(marker_display_value "Docker installed" "$marker_file")${CL}"
    echo -e "  ${BL}Docker service:${CL} ${GN}$(marker_display_value "Docker service enabled" "$marker_file")${CL}"
    echo -e "  ${BL}containerd service:${CL} ${GN}$(marker_display_value "containerd service enabled" "$marker_file")${CL}"
    echo -e "  ${BL}User in docker group:${CL} ${GN}$(marker_display_value "User added to docker group" "$marker_file")${CL}"
    echo -e "  ${BL}Docker GC timer:${CL} ${GN}$(marker_display_value "Docker GC timer" "$marker_file")${CL}"
    echo -e "  ${BL}Redis overcommit:${CL} ${GN}$(marker_display_value "Redis overcommit configured" "$marker_file")${CL}"
    echo -e "  ${BL}UFW firewall:${CL} ${GN}$(marker_display_value "UFW result" "$marker_file")${CL}"
    echo -e "  ${BL}Verify log:${CL} ${GN}$(marker_display_value "Verify log" "$marker_file")${CL}"
}

function previous_marker_action_menu() {
    local action=""
    local action_label=""

    while true; do
        tty_println "  ${YW}1)${CL} Verify existing setup"
        tty_println "  ${YW}2)${CL} Re-run Docker setup"
        tty_println "  ${YW}3)${CL} Exit"
        tty_println ""
        tty_print "${YW}Select action [default: 1]: ${CL}"

        if [ -r /dev/tty ]; then
            IFS= read -r action < /dev/tty || action=""
        else
            IFS= read -r action || action=""
        fi

        action="$(printf '%s' "$action" | tr -d '\r\n' | xargs || true)"
        [ -z "$action" ] && action="1"

        case "$action" in
            1) action_label="Verify existing setup" ;;
            2) action_label="Re-run Docker setup" ;;
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

# --- 30. PREVIOUS MARKER CHECK ---
# Offers verification-only rerun mode when Docker Setup was already completed previously.
function check_previous_marker() {
    local marker_action=""

    if root_path_exists "$COMPLETED_MARKER"; then
        section "PREVIOUS DOCKER SETUP MARKER DETECTED"

        DOCKER_MARKER_FOUND="yes"
        show_previous_marker_compact_summary "$COMPLETED_MARKER"
        echo ""
        echo -e "${YW}Action:${CL}"

        marker_action="$(previous_marker_action_menu)"

        case "$marker_action" in
            1) run_verify_only_mode; exit 0 ;;
            2) return 0 ;;
            3) exit 0 ;;
            *) return 0 ;;
        esac
    fi

    return 0
}

# --- 31. EXISTING SETUP DETECTION ---
# Detects current Docker state and shows exactly what was found.
function detect_existing_setup() {
    local continue_existing_yn=""

    section "EXISTING SETUP CHECK"

    msg_info "Checking for existing Docker setup"

    command -v docker >/dev/null 2>&1 && DOCKER_CLI_FOUND="yes" || DOCKER_CLI_FOUND="no"
    root_path_exists "/etc/docker/daemon.json" && DOCKER_DAEMON_CONFIG_FOUND="yes" || DOCKER_DAEMON_CONFIG_FOUND="no"
    root_path_exists "$COMPLETED_MARKER" && DOCKER_MARKER_FOUND="yes" || DOCKER_MARKER_FOUND="no"

    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet docker 2>/dev/null; then
        DOCKER_SERVICE_ACTIVE="yes"
    else
        DOCKER_SERVICE_ACTIVE="no"
    fi

    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet containerd 2>/dev/null; then
        CONTAINERD_SERVICE_ACTIVE="yes"
    else
        CONTAINERD_SERVICE_ACTIVE="no"
    fi

    if [ "$DOCKER_CLI_FOUND" == "yes" ] || [ "$DOCKER_DAEMON_CONFIG_FOUND" == "yes" ] || [ "$DOCKER_MARKER_FOUND" == "yes" ]; then
        EXISTING_SETUP="yes"
    else
        EXISTING_SETUP="no"
    fi

    msg_ok "EXISTING SETUP CHECK COMPLETE"

    echo ""
    echo -e "${BL}DETECTED STATE:${CL}"
    echo -e "DOCKER CLI FOUND:        ${GN}${DOCKER_CLI_FOUND}${CL}"
    echo -e "DAEMON CONFIG FOUND:     ${GN}${DOCKER_DAEMON_CONFIG_FOUND}${CL}"
    echo -e "COMPLETION MARKER FOUND: ${GN}${DOCKER_MARKER_FOUND}${CL}"
    echo -e "DOCKER SERVICE ACTIVE:   ${GN}${DOCKER_SERVICE_ACTIVE}${CL}"
    echo -e "CONTAINERD ACTIVE:       ${GN}${CONTAINERD_SERVICE_ACTIVE}${CL}"
    echo ""

    if [ "$EXISTING_SETUP" == "yes" ]; then
        echo -e "${RD}WARNING: Existing Docker setup detected.${CL}"
        echo -e "${YW}The script is mostly safe to rerun, but it can update packages, rewrite Docker daemon settings, and reapply firewall rules.${CL}"
        echo ""

        continue_existing_yn="$(timed_yes_no "Continue with existing Docker setup?" "n")"

        if [[ "$continue_existing_yn" =~ ^[Nn] ]]; then
            echo -e "${YW}Docker Setup cancelled. Existing files were left untouched.${CL}"
            exit 0
        fi
    fi
}

# --- 32. START CONFIRMATION ---
# Starts Docker installation after environment and existing setup checks.
function start_confirmation() {
    local lxc_continue_yn=""
    local start_yn=""

    section "START"

    echo -e "${YW}This script will install and configure Docker Engine, Docker CLI, containerd, Compose plugin and Buildx plugin.${CL}"

    if [ "$IS_CONTAINER" == "yes" ]; then
        echo ""
        echo -e "${RD}LXC/container mode detected.${CL}"
        echo -e "${YW}Docker inside LXC requires Proxmox host support such as nesting, cgroups and suitable container privileges.${CL}"
        echo -e "${YW}Swap handling, UFW and reboot are skipped/defaulted to safer container settings.${CL}"
        echo ""

        lxc_continue_yn="$(timed_yes_no "Continue Docker install inside LXC/container?" "n")"

        if [[ "$lxc_continue_yn" =~ ^[Nn] ]]; then
            exit 0
        fi
    fi

    start_yn="$(timed_yes_no "Start the Docker Setup Script?" "y")"

    if [[ "$start_yn" =~ ^[Nn] ]]; then
        exit 0
    fi

    return 0
}

# =========================================================
#  USER OPTIONS
# =========================================================

# --- 33. USER OPTIONS ---
# Lets user confirm target user, swap behaviour, UFW baseline and optional docker-gc install.
function collect_user_options() {
    local swap_yn=""
    local gc_yn=""
    local ufw_yn=""
    local reboot_yn=""

    section "SETUP OPTIONS"

    while true; do
        TARGET_USER="$(timed_text_input "Enter Linux user to add to docker group" "$TARGET_USER")"

        if validate_linux_username "$TARGET_USER"; then
            break
        fi

        msg_warn "Invalid username. Use lowercase Linux username format, for example: orik"
    done

    if ! id "$TARGET_USER" >/dev/null 2>&1; then
        msg_error "Target user ${TARGET_USER} does not exist. Run script 4 first or create the user."
    fi

    if [ "$IS_CONTAINER" == "yes" ]; then
        swap_yn="$(timed_yes_no "Disable swap in /etc/fstab? LXC default is no" "n")"
    else
        swap_yn="$(timed_yes_no "Disable swap in /etc/fstab?" "y")"
    fi
    if [[ "$swap_yn" =~ ^[Nn] ]]; then
        DISABLE_SWAP="n"
    else
        DISABLE_SWAP="y"
    fi

    if [ "$IS_CONTAINER" == "yes" ]; then
        ufw_yn="$(timed_yes_no "Configure UFW firewall inside LXC/container?" "n")"
    else
        ufw_yn="$(timed_yes_no "Configure UFW firewall baseline?" "y")"
    fi
    if [[ "$ufw_yn" =~ ^[Nn] ]]; then
        CONFIGURE_UFW="n"
    else
        CONFIGURE_UFW="y"
    fi

    gc_yn="$(timed_yes_no "Install safe Docker cleanup helper and weekly systemd timer?" "y")"
    if [[ "$gc_yn" =~ ^[Yy] ]]; then
        INSTALL_DOCKER_GC="y"
    else
        INSTALL_DOCKER_GC="n"
    fi

    if [ "$IS_CONTAINER" == "yes" ]; then
        REBOOT_AFTER_FINISH="n"
    else
        reboot_yn="$(timed_yes_no "Reboot automatically after Docker setup finishes?" "y")"
        if [[ "$reboot_yn" =~ ^[Nn] ]]; then
            REBOOT_AFTER_FINISH="n"
        else
            REBOOT_AFTER_FINISH="y"
        fi
    fi
}


# --- READY TO APPLY SUMMARY ---
# Shows all collected answers before any Docker/system-changing actions are applied.
function show_ready_to_apply() {
    local apply_yn=""

    section "SETUP PLAN"

    echo -e "${YW}Docker:${CL}"
    echo -e "  ${BL}Target user:${CL} ${ANS}${TARGET_USER}${CL}"
    echo -e "  ${BL}Existing Docker setup:${CL} ${ANS}${EXISTING_SETUP}${CL}"
    echo -e "  ${BL}Docker firewall mode:${CL} ${ANS}${DOCKER_FIREWALL_MODE}${CL}"
    echo ""
    echo -e "${YW}System:${CL}"
    echo -e "  ${BL}Disable swap:${CL} ${ANS}$(yes_no_label "$DISABLE_SWAP")${CL}"
    echo -e "  ${BL}Configure UFW:${CL} ${ANS}$(yes_no_label "$CONFIGURE_UFW")${CL}"
    echo -e "  ${BL}Redis overcommit:${CL} ${ANS}yes${CL}"
    echo -e "  ${BL}Docker cleanup timer:${CL} ${ANS}$(yes_no_label "$INSTALL_DOCKER_GC")${CL}"
    echo -e "  ${BL}Reboot:${CL} ${ANS}$(yes_no_label "$REBOOT_AFTER_FINISH")${CL}"
    echo ""
    echo -e "${YW}After confirmation, Docker setup changes will be applied.${CL}"
    echo ""

    apply_yn="$(timed_yes_no "Apply this Docker setup plan?" "y")"

    if [[ "$apply_yn" =~ ^[Nn] ]]; then
        echo -e "${YW}Docker Setup cancelled. No Docker/system-changing actions were applied.${CL}"
        exit 0
    fi

    return 0
}

# =========================================================
#  APPLY FUNCTIONS
# =========================================================

# --- 34. SWAP HANDLING ---
# Disables swap for Docker/database stability if selected.
# Backs up /etc/fstab before editing and avoids double-commenting lines.
function handle_swap() {
    apply_group_header "System"

    if [ "$DISABLE_SWAP" != "y" ]; then
        SWAP_DISABLED="no"
        msg_skip "SWAP WAS NOT DISABLED BECAUSE USER CHOSE NO"
        return 0
    fi

    if [ "$IS_CONTAINER" == "yes" ]; then
        msg_warn "Swap handling inside LXC/container may be controlled by the Proxmox host"
    fi

    msg_info "Backing up /etc/fstab"
    run_optional cp -n /etc/fstab /etc/fstab.docker-setup.bak
    msg_ok "FSTAB BACKUP CREATED OR ALREADY EXISTS"

    msg_info "Turning off active swap"
    run_optional swapoff -a
    msg_ok "ACTIVE SWAP TURNED OFF OR NOT ACTIVE"

    msg_info "Commenting swap entries in /etc/fstab"
    run_cmd "commenting swap entries in /etc/fstab" sed -i -E '/[[:space:]]swap[[:space:]]/ s/^([^#])/#\1/' /etc/fstab
    msg_ok "FSTAB SWAP ENTRIES DISABLED"

    SWAP_DISABLED="yes"

    msg_ok "SWAP DISABLED"
}

# --- 35. DOCKER REPOSITORY DEPENDENCIES ---
# Installs packages needed to add Docker's official Ubuntu repository.
function install_repository_dependencies() {
    apply_group_header "Docker repository"

    msg_info "Updating APT package lists"
    wait_for_apt_locks
    run_cmd "updating APT package lists" apt-get update
    msg_ok "APT PACKAGE LISTS UPDATED"

    msg_info "Installing Docker repository dependencies"
    wait_for_apt_locks
    run_cmd "installing Docker repository dependencies" env DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg
    msg_ok "DOCKER REPOSITORY DEPENDENCIES INSTALLED"
}

# --- 36. DOCKER APT REPOSITORY ---
# Adds Docker's official Ubuntu apt repository using docker.sources and docker.asc keyring.
function configure_docker_repository() {
    local key_tmp=""
    local sources_tmp=""

    apply_group_header "Docker repository"

    msg_info "Detecting Ubuntu codename and architecture"

    if [ ! -f /etc/os-release ]; then
        msg_error "/etc/os-release not found. Cannot configure Docker repository."
    fi

    # shellcheck disable=SC1091
    . /etc/os-release

    UBUNTU_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    ARCHITECTURE="$(dpkg --print-architecture)"

    if [ -z "$UBUNTU_CODENAME" ]; then
        msg_error "Could not detect Ubuntu codename from /etc/os-release."
    fi

    msg_ok "UBUNTU REPOSITORY TARGET DETECTED (${UBUNTU_CODENAME}, ${ARCHITECTURE})"

    msg_info "Creating Docker apt keyring directory"
    run_cmd "creating /etc/apt/keyrings" install -m 0755 -d /etc/apt/keyrings
    msg_ok "DOCKER APT KEYRING DIRECTORY READY"

    msg_info "Downloading Docker official GPG key"
    key_tmp="$(mktemp)"
    TEMP_FILES+=("$key_tmp")
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$key_tmp"
    run_cmd "installing Docker official GPG key" install -m 0644 "$key_tmp" /etc/apt/keyrings/docker.asc
    msg_ok "DOCKER OFFICIAL GPG KEY INSTALLED"

    msg_info "Writing Docker apt source"
    sources_tmp="$(mktemp)"
    TEMP_FILES+=("$sources_tmp")

    cat > "$sources_tmp" <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME}
Components: stable
Architectures: ${ARCHITECTURE}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    run_cmd "installing Docker apt source" install -m 0644 "$sources_tmp" /etc/apt/sources.list.d/docker.sources
    msg_ok "DOCKER APT SOURCE WRITTEN"

    msg_info "Updating APT package lists with Docker repository"
    wait_for_apt_locks
    run_cmd "updating APT after Docker repository setup" apt-get update
    msg_ok "APT PACKAGE LISTS UPDATED WITH DOCKER REPOSITORY"

    msg_info "Validating Docker package availability"
    validate_docker_package_availability
}

# --- 37. DOCKER ENGINE INSTALL ---
# Installs Docker CE, Docker CLI, containerd, Buildx plugin and Compose plugin.
function install_docker_engine() {
    apply_group_header "Docker"

    msg_info "Installing Docker Engine and plugins"
    wait_for_apt_locks
    run_cmd "installing Docker Engine and plugins" env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    DOCKER_INSTALLED="yes"

    msg_ok "DOCKER ENGINE AND PLUGINS INSTALLED"

    if command -v systemctl >/dev/null 2>&1; then
        msg_info "Enabling containerd service"

        if systemctl list-unit-files containerd.service >/dev/null 2>&1; then
            run_cmd "enabling containerd service" systemctl enable --now containerd
            CONTAINERD_SERVICE_ENABLED="yes"
            msg_ok "CONTAINERD SERVICE ENABLED"
        else
            CONTAINERD_SERVICE_ENABLED="not-found"
            msg_warn "containerd systemd unit not found"
        fi

        msg_info "Enabling Docker service"

        if systemctl list-unit-files docker.service >/dev/null 2>&1; then
            run_cmd "enabling Docker service" systemctl enable --now docker
            DOCKER_SERVICE_ENABLED="yes"
            msg_ok "DOCKER SERVICE ENABLED"
        else
            DOCKER_SERVICE_ENABLED="not-found"
            msg_warn "Docker systemd unit not found"
        fi
    else
        CONTAINERD_SERVICE_ENABLED="no-systemctl"
        DOCKER_SERVICE_ENABLED="no-systemctl"
        msg_warn "systemctl not available; Docker services were not enabled automatically"
    fi
}

# --- 38. DOCKER GROUP CONFIGURATION ---
# Ensures docker group exists and adds selected user to it.
function configure_docker_group() {
    apply_group_header "Docker"

    msg_info "Checking docker group"

    if ! getent group docker >/dev/null 2>&1; then
        run_cmd "creating docker group" groupadd docker
    fi

    DOCKER_GROUP_READY="yes"
    msg_ok "DOCKER GROUP READY"

    msg_info "Adding ${TARGET_USER} to docker group"
    run_cmd "adding ${TARGET_USER} to docker group" usermod -aG docker "$TARGET_USER"
    USER_ADDED_TO_DOCKER="yes"
    msg_ok "USER ADDED TO DOCKER GROUP"
}

# --- 39. DOCKER DAEMON CONFIGURATION ---
# Writes Docker daemon.json with iptables enabled, log rotation and live-restore.
function configure_docker_daemon() {
    apply_group_header "Docker"

    msg_info "Creating /etc/docker directory"
    run_cmd "creating /etc/docker directory" mkdir -p /etc/docker
    msg_ok "DOCKER CONFIG DIRECTORY READY"

    msg_info "Writing Docker daemon config"

    write_root_file /etc/docker/daemon.json <<EOF
{
  "iptables": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true
}
EOF

    msg_ok "DOCKER DAEMON CONFIG WRITTEN"

    msg_info "Validating Docker daemon config"

    if validate_docker_daemon_json; then
        msg_ok "DOCKER DAEMON CONFIG VALID"
    else
        msg_error "Docker daemon config validation failed."
    fi

    if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files docker.service >/dev/null 2>&1; then
        msg_info "Restarting Docker service"
        run_cmd "restarting Docker service" systemctl restart docker
        msg_ok "DOCKER SERVICE RESTARTED"
    else
        msg_warn "Docker service restart skipped because systemd Docker service was not detected"
    fi

    msg_ok "DOCKER FIREWALL MODE CONFIGURED (${DOCKER_FIREWALL_MODE})"
}

# --- 40. UFW BASELINE ---
# Allows SSH, HTTP and HTTPS on the Ubuntu VM.
# Warns clearly that Docker-published ports can bypass UFW through Docker-managed iptables.
function configure_ufw_firewall() {
    apply_group_header "Firewall"

    echo -e "${YW}Docker manages its own firewall/NAT rules.${CL}"
    echo -e "${YW}UFW protects the host, but Docker-published container ports may still be reachable unless controlled later with DOCKER-USER rules.${CL}"
    echo -e "${YW}For this project, avoid publishing random ports directly; expose public services through Traefik on 80/443.${CL}"
    echo ""

    if [ "$CONFIGURE_UFW" != "y" ]; then
        UFW_ENABLED="no"
        msg_skip "UFW FIREWALL WAS NOT CONFIGURED BECAUSE USER CHOSE NO"
        return 0
    fi

    if [ "$IS_CONTAINER" == "yes" ]; then
        msg_warn "LXC/container mode detected. UFW may fail without container netfilter permissions."
    fi

    msg_info "Installing UFW"
    wait_for_apt_locks
    run_cmd "installing UFW" env DEBIAN_FRONTEND=noninteractive apt-get install -y ufw
    msg_ok "UFW INSTALLED"

    msg_info "Setting UFW default policies"
    run_optional ufw default deny incoming
    run_optional ufw default allow outgoing
    msg_ok "UFW DEFAULT POLICIES CONFIGURED"

    msg_info "Allowing SSH, HTTP and HTTPS"
    run_optional ufw allow OpenSSH
    run_optional ufw allow 80/tcp
    run_optional ufw allow 443/tcp
    msg_ok "UFW ALLOW RULES ADDED"

    msg_info "Enabling UFW"

    if [ -n "$SUDO_CMD" ]; then
        if "$SUDO_CMD" ufw --force enable >/dev/null 2>&1; then
            UFW_ENABLED="yes"
            msg_ok "UFW ENABLED"
        else
            UFW_ENABLED="failed"
            msg_warn "UFW failed to enable. This can happen inside restricted LXC containers."
        fi
    else
        if ufw --force enable >/dev/null 2>&1; then
            UFW_ENABLED="yes"
            msg_ok "UFW ENABLED"
        else
            UFW_ENABLED="failed"
            msg_warn "UFW failed to enable. This can happen inside restricted LXC containers."
        fi
    fi

    msg_ok "UFW FIREWALL CONFIGURED"
}

# --- 41. REDIS HOST TUNING ---
# Persists and applies vm.overcommit_memory=1 for Redis stability.
# Redis warns when this is not enabled because background save/replication can fail under memory pressure.
function configure_redis_host_tuning() {
    apply_group_header "System"

    if [ "$IS_CONTAINER" == "yes" ]; then
        msg_warn "Container mode detected. sysctl may be controlled by the host. Attempting safe configuration anyway."
    fi

    msg_info "Writing Redis overcommit sysctl config"

    write_root_file /etc/sysctl.d/99-redis-overcommit.conf <<'EOF'
# Redis background save/replication stability
# Managed by 5-dockerSetup.sh
vm.overcommit_memory=1
EOF

    msg_ok "REDIS SYSCTL CONFIG WRITTEN"

    msg_info "Applying vm.overcommit_memory=1 immediately"

    if [ -n "$SUDO_CMD" ]; then
        if "$SUDO_CMD" sysctl -w vm.overcommit_memory=1 >/dev/null 2>&1; then
            REDIS_OVERCOMMIT_CONFIGURED="yes"
            msg_ok "REDIS OVERCOMMIT APPLIED"
        else
            REDIS_OVERCOMMIT_CONFIGURED="failed"
            msg_warn "Failed to apply vm.overcommit_memory immediately. It may apply after reboot."
        fi
    else
        if sysctl -w vm.overcommit_memory=1 >/dev/null 2>&1; then
            REDIS_OVERCOMMIT_CONFIGURED="yes"
            msg_ok "REDIS OVERCOMMIT APPLIED"
        else
            REDIS_OVERCOMMIT_CONFIGURED="failed"
            msg_warn "Failed to apply vm.overcommit_memory immediately. It may apply after reboot."
        fi
    fi

    REDIS_OVERCOMMIT_VALUE="$(sysctl -n vm.overcommit_memory 2>/dev/null || echo unknown)"

    if [ "$REDIS_OVERCOMMIT_VALUE" == "1" ]; then
        REDIS_OVERCOMMIT_CONFIGURED="yes"
        msg_ok "REDIS HOST TUNING VERIFIED"
    else
        msg_warn "Redis overcommit value is ${REDIS_OVERCOMMIT_VALUE}; expected 1"
    fi
}

# --- 42. DOCKER-GC OPTIONAL INSTALL ---
# Creates a safe host-side Docker cleanup helper and optional weekly systemd timer.
# This intentionally avoids any Docker socket-proxy permission expansion and never prunes volumes.
function install_docker_gc_helper() {
    apply_group_header "Cleanup"

    if [ "$INSTALL_DOCKER_GC" != "y" ]; then
        DOCKER_GC_INSTALLED="no"
        DOCKER_GC_TIMER_INSTALLED="no"
        msg_skip "DOCKER CLEANUP HELPER WAS NOT INSTALLED BECAUSE USER CHOSE NO"
        return 0
    fi

    msg_info "Writing safe Docker cleanup helper"

    write_root_file /usr/local/sbin/docker-gc-safe <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/docker-gc-safe.log"
LOCK_FILE="/run/docker-gc-safe.lock"

mkdir -p "$(dirname "$LOG_FILE")"

touch "$LOG_FILE"
chmod 0644 "$LOG_FILE" 2>/dev/null || true

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "[$(date -Is)] Another docker-gc-safe run is already active. Exiting." >> "$LOG_FILE"
    exit 0
fi

{
    echo "============================================================"
    echo "Docker safe cleanup started: $(date -Is)"
    echo "Hostname: $(hostname)"
    echo ""

    if ! command -v docker >/dev/null 2>&1; then
        echo "ERROR: docker command not found."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        echo "ERROR: Docker daemon is not reachable."
        exit 1
    fi

    echo "Before cleanup:"
    docker system df || true
    echo ""

    echo "Pruning stopped containers only..."
    docker container prune -f || true
    echo ""

    echo "Pruning unused Docker networks..."
    docker network prune -f || true
    echo ""

    echo "Pruning dangling images..."
    docker image prune -f || true
    echo ""

    echo "Pruning unused images older than 7 days..."
    docker image prune -a -f --filter "until=168h" || true
    echo ""

    echo "Pruning old BuildKit/build cache older than 7 days..."
    docker builder prune -f --filter "until=168h" || true
    echo ""

    echo "IMPORTANT: Docker volumes are intentionally never pruned by this helper."
    echo ""

    echo "After cleanup:"
    docker system df || true
    echo ""
    echo "Docker safe cleanup finished: $(date -Is)"
    echo "============================================================"
    echo ""
} >> "$LOG_FILE" 2>&1
EOF

    msg_ok "DOCKER CLEANUP HELPER WRITTEN"

    msg_info "Making docker cleanup helper executable"
    run_cmd "making docker cleanup helper executable" chmod 0755 /usr/local/sbin/docker-gc-safe
    msg_ok "DOCKER CLEANUP HELPER MADE EXECUTABLE"

    DOCKER_GC_INSTALLED="yes"

    if command -v systemctl >/dev/null 2>&1; then
        msg_info "Writing docker-gc-safe systemd service"

        write_root_file /etc/systemd/system/docker-gc-safe.service <<'EOF'
[Unit]
Description=Safe Docker cleanup helper
Documentation=man:docker-system-prune(1)
Wants=docker.service
After=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/docker-gc-safe
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7
EOF

        msg_ok "DOCKER CLEANUP SERVICE WRITTEN"

        msg_info "Writing docker-gc-safe weekly timer"

        write_root_file /etc/systemd/system/docker-gc-safe.timer <<'EOF'
[Unit]
Description=Run safe Docker cleanup weekly

[Timer]
OnCalendar=Sun *-*-* 04:00:00
Persistent=true
RandomizedDelaySec=30m
Unit=docker-gc-safe.service

[Install]
WantedBy=timers.target
EOF

        msg_ok "DOCKER CLEANUP TIMER WRITTEN"

        msg_info "Enabling docker-gc-safe timer"
        run_cmd "reloading systemd for docker cleanup timer" systemctl daemon-reload
        run_cmd "enabling docker cleanup timer" systemctl enable --now docker-gc-safe.timer
        DOCKER_GC_TIMER_INSTALLED="yes"
        msg_ok "DOCKER CLEANUP TIMER ENABLED"
    else
        DOCKER_GC_TIMER_INSTALLED="no-systemctl"
        msg_warn "systemctl not available; cleanup helper installed without timer"
    fi

    msg_ok "SAFE DOCKER CLEANUP INSTALLED"
}

# =========================================================
#  VERIFICATION / MARKER / SUMMARY
# =========================================================

# --- 42. DOCKER VERIFICATION ---
# Checks Docker daemon, Docker CLI and Compose plugin through sudo so verification works before docker group re-login.
function verify_docker_installation() {
    apply_group_header "Marker / verification"

    msg_info "Checking Docker CLI"
    run_cmd "checking Docker CLI" docker --version
    msg_ok "DOCKER CLI VERIFIED"

    msg_info "Checking Docker daemon"
    run_cmd "checking Docker daemon" docker info
    msg_ok "DOCKER DAEMON VERIFIED"

    msg_info "Checking Docker Compose plugin"
    run_cmd "checking Docker Compose plugin" docker compose version
    msg_ok "DOCKER COMPOSE VERIFIED"

    msg_ok "DOCKER VERIFIED"
}

# --- 43. VERIFICATION REPORT ---
# Writes a detailed Docker verification report to /var/log/docker-setup-verify.log.
function create_verification_report() {
    if [ "${VERIFY_ONLY_MODE:-no}" != "yes" ]; then
        apply_group_header "Marker / verification"
    fi

    msg_info "Writing Docker verification report"

    local report_body=""
    local docker_version=""
    local compose_version=""
    local ufw_status=""

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

    verify_pass() { VERIFY_PASS_COUNT="$(( VERIFY_PASS_COUNT + 1 ))"; echo "✓ PASS - $1" >> "$report_body"; }
    verify_warn() { local check="$1" reason="${2:-warning condition detected}" fix="${3:-review ${VERIFY_LOG}}"; VERIFY_WARN_COUNT="$(( VERIFY_WARN_COUNT + 1 ))"; verify_record_first_issue "Warning" "$check" "$reason" "$fix"; echo "! WARN - ${check}: ${reason}" >> "$report_body"; }
    verify_fail() { local check="$1" reason="${2:-check failed}" fix="${3:-review ${VERIFY_LOG}}"; VERIFY_FAIL_COUNT="$(( VERIFY_FAIL_COUNT + 1 ))"; verify_record_first_issue "Failure" "$check" "$reason" "$fix"; echo "✗ FAIL - ${check}: ${reason}" >> "$report_body"; }
    verify_info() { echo "- INFO - $1" >> "$report_body"; }

    if command -v docker >/dev/null 2>&1; then verify_pass "Docker CLI exists"; else verify_fail "Docker CLI exists" "docker command missing" "install Docker Engine packages"; fi
    if docker_version="$(docker --version 2>/dev/null || { [ -n "$SUDO_CMD" ] && "$SUDO_CMD" docker --version 2>/dev/null; } || true)" && [ -n "$docker_version" ]; then verify_pass "docker --version works"; else verify_fail "docker --version" "docker --version failed" "check Docker CLI installation"; fi
    if compose_version="$(docker compose version 2>/dev/null || { [ -n "$SUDO_CMD" ] && "$SUDO_CMD" docker compose version 2>/dev/null; } || true)" && [ -n "$compose_version" ]; then verify_pass "Docker Compose plugin works"; else verify_fail "Docker Compose plugin" "docker compose version failed" "install docker-compose-plugin"; fi
    if docker info >/dev/null 2>&1 || { [ -n "$SUDO_CMD" ] && "$SUDO_CMD" docker info >/dev/null 2>&1; }; then verify_pass "Docker daemon reachable"; else verify_fail "Docker daemon reachable" "docker info failed" "check docker service status and logs"; fi

    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet docker 2>/dev/null; then verify_pass "Docker service active"; else verify_warn "Docker service active" "service is not active or unavailable" "run sudo systemctl status docker"; fi
        if systemctl is-active --quiet containerd 2>/dev/null; then verify_pass "containerd service active"; else verify_warn "containerd service active" "service is not active or unavailable" "run sudo systemctl status containerd"; fi
    else
        verify_info "systemctl unavailable"
    fi

    if [ -f /etc/docker/daemon.json ]; then verify_pass "daemon.json exists"; else verify_fail "daemon.json exists" "/etc/docker/daemon.json missing" "rerun daemon config step"; fi
    if validate_docker_daemon_json; then verify_pass "daemon.json valid"; else verify_fail "daemon.json valid" "daemon config validation failed" "inspect /etc/docker/daemon.json"; fi

    if [ -f /etc/sysctl.d/99-redis-overcommit.conf ]; then verify_pass "Redis overcommit sysctl file exists"; else verify_fail "Redis overcommit sysctl file exists" "sysctl file missing" "rerun Redis host tuning step"; fi
    if [ "$(sysctl -n vm.overcommit_memory 2>/dev/null || echo unknown)" = "1" ]; then verify_pass "vm.overcommit_memory=1 active"; else verify_warn "vm.overcommit_memory=1 active" "current value is $(sysctl -n vm.overcommit_memory 2>/dev/null || echo unknown)" "run sudo sysctl -w vm.overcommit_memory=1"; fi

    if [ "$INSTALL_DOCKER_GC" == "y" ]; then
        if [ -x /usr/local/sbin/docker-gc-safe ]; then verify_pass "docker-gc-safe helper exists"; else verify_fail "docker-gc-safe helper exists" "helper missing" "rerun cleanup helper install step"; fi
        if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files docker-gc-safe.timer >/dev/null 2>&1; then verify_pass "docker-gc-safe.timer exists"; else verify_warn "docker-gc-safe.timer exists" "timer not found" "run sudo systemctl status docker-gc-safe.timer"; fi
    else
        verify_info "docker-gc-safe helper not selected"
        verify_info "docker-gc-safe.timer not selected"
    fi

    if getent group docker >/dev/null 2>&1; then verify_pass "docker group exists"; else verify_fail "docker group exists" "docker group missing" "run sudo groupadd docker"; fi
    if id -nG "$TARGET_USER" 2>/dev/null | grep -qw docker; then verify_pass "target user is in docker group"; else verify_warn "target user docker group" "membership not confirmed" "run sudo usermod -aG docker ${TARGET_USER}, then re-login"; fi

    if [ "$DISABLE_SWAP" == "y" ]; then
        if swapon --show 2>/dev/null | grep -q .; then verify_warn "no active swap detected" "active swap still detected" "review /etc/fstab and run sudo swapoff -a"; else verify_pass "no active swap detected"; fi
    else
        verify_info "swap disable not selected"
    fi

    if [ "$CONFIGURE_UFW" == "y" ]; then
        ufw_status="$(ufw status 2>/dev/null || { [ -n "$SUDO_CMD" ] && "$SUDO_CMD" ufw status 2>/dev/null; } || true)"
        if grep -qi "Status:[[:space:]]*active" <<< "$ufw_status"; then verify_pass "UFW active"; else verify_warn "UFW active" "UFW not active or unavailable" "run sudo ufw status verbose"; fi
        if grep -Eq '22/tcp|OpenSSH' <<< "$ufw_status"; then verify_pass "UFW SSH rule present"; else verify_warn "UFW SSH rule" "OpenSSH/22 rule not confirmed" "run sudo ufw allow OpenSSH"; fi
        if grep -Eq '80/tcp' <<< "$ufw_status"; then verify_pass "UFW HTTP rule present"; else verify_warn "UFW HTTP rule" "80/tcp rule not confirmed" "run sudo ufw allow 80/tcp"; fi
        if grep -Eq '443/tcp' <<< "$ufw_status"; then verify_pass "UFW HTTPS rule present"; else verify_warn "UFW HTTPS rule" "443/tcp rule not confirmed" "run sudo ufw allow 443/tcp"; fi
    else
        verify_info "UFW setup not selected"
    fi

    if root_path_exists "$COMPLETED_MARKER"; then verify_pass "Completion marker exists"; else verify_warn "Completion marker exists" "marker missing" "rerun marker write step"; fi

    if [ "$VERIFY_FAIL_COUNT" -gt 0 ]; then
        VERIFY_STATUS="FAIL"
    elif [ "$VERIFY_WARN_COUNT" -gt 0 ]; then
        VERIFY_STATUS="PASS_WITH_WARNINGS"
    else
        VERIFY_STATUS="PASS"
    fi

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" bash -c "cat > '$VERIFY_LOG'" <<EOF
--- DOCKER SETUP VERIFICATION REPORT ---
Date: $(date)
Target user: $TARGET_USER
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

Docker versions:
${docker_version:-unknown}
${compose_version:-unknown}
EOF
    else
        cat > "$VERIFY_LOG" <<EOF
--- DOCKER SETUP VERIFICATION REPORT ---
Date: $(date)
Target user: $TARGET_USER
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

Docker versions:
${docker_version:-unknown}
${compose_version:-unknown}
EOF
    fi

    rm -f "$report_body"
    msg_ok "DOCKER VERIFICATION REPORT WRITTEN"
}

# --- 44. COMPLETION MARKER ---
# Creates marker showing setup completed.
function write_completion_marker() {
    apply_group_header "Marker / verification"

    msg_info "Writing completion marker"

    POST_REBOOT_VERIFY_MARKER="/home/${TARGET_USER}/.docker-setup-verify-displayed"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" bash -c "cat > '$COMPLETED_MARKER'" <<EOF
Docker Setup completed on: $(date)
Target user: $TARGET_USER
Virt Type: $VIRT_TYPE
Container: $IS_CONTAINER
LXC: $IS_LXC
VM: $IS_VM
Swap disabled selected: $DISABLE_SWAP
Swap disabled result: $SWAP_DISABLED
Docker installed: $DOCKER_INSTALLED
Docker service enabled: $DOCKER_SERVICE_ENABLED
containerd service enabled: $CONTAINERD_SERVICE_ENABLED
Docker group ready: $DOCKER_GROUP_READY
User added to docker group: $USER_ADDED_TO_DOCKER
Docker GC helper: $DOCKER_GC_INSTALLED
Docker GC timer: $DOCKER_GC_TIMER_INSTALLED
Redis overcommit configured: $REDIS_OVERCOMMIT_CONFIGURED
Redis overcommit value: $REDIS_OVERCOMMIT_VALUE
Docker firewall mode: $DOCKER_FIREWALL_MODE
UFW configured selected: $CONFIGURE_UFW
UFW result: $UFW_ENABLED
Daemon config valid: $DAEMON_CONFIG_VALID
Existing setup detected: $EXISTING_SETUP
Verify log: $VERIFY_LOG
SCRIPT5_STATUS=completed
SCRIPT5_VERSION=$SCRIPT_VERSION
SCRIPT5_BUILD=$SCRIPT_BUILD
SCRIPT5_VERIFY_STATUS=$VERIFY_STATUS
SCRIPT5_VERIFY_LOG=$VERIFY_LOG
SCRIPT5_VERIFY_DISPLAY_LOG=$VERIFY_DISPLAY_LOG
SCRIPT5_POST_REBOOT_DISPLAY_HOOK=$POST_REBOOT_VERIFY_HOOK
SCRIPT5_POST_REBOOT_DISPLAY_MARKER=$POST_REBOOT_VERIFY_MARKER
SCRIPT5_TARGET_USER=$TARGET_USER
SCRIPT5_DOCKER_INSTALLED=$DOCKER_INSTALLED
SCRIPT5_DOCKER_SERVICE_ENABLED=$DOCKER_SERVICE_ENABLED
SCRIPT5_CONTAINERD_SERVICE_ENABLED=$CONTAINERD_SERVICE_ENABLED
SCRIPT5_USER_ADDED_TO_DOCKER=$USER_ADDED_TO_DOCKER
SCRIPT5_DOCKER_GC_TIMER=$DOCKER_GC_TIMER_INSTALLED
SCRIPT5_REDIS_OVERCOMMIT=$REDIS_OVERCOMMIT_CONFIGURED
SCRIPT5_UFW_ENABLED=$UFW_ENABLED
SCRIPT5_DAEMON_CONFIG_VALID=$DAEMON_CONFIG_VALID
EOF
    else
        cat > "$COMPLETED_MARKER" <<EOF
Docker Setup completed on: $(date)
Target user: $TARGET_USER
Virt Type: $VIRT_TYPE
Container: $IS_CONTAINER
LXC: $IS_LXC
VM: $IS_VM
Swap disabled selected: $DISABLE_SWAP
Swap disabled result: $SWAP_DISABLED
Docker installed: $DOCKER_INSTALLED
Docker service enabled: $DOCKER_SERVICE_ENABLED
containerd service enabled: $CONTAINERD_SERVICE_ENABLED
Docker group ready: $DOCKER_GROUP_READY
User added to docker group: $USER_ADDED_TO_DOCKER
Docker GC helper: $DOCKER_GC_INSTALLED
Docker GC timer: $DOCKER_GC_TIMER_INSTALLED
Redis overcommit configured: $REDIS_OVERCOMMIT_CONFIGURED
Redis overcommit value: $REDIS_OVERCOMMIT_VALUE
Docker firewall mode: $DOCKER_FIREWALL_MODE
UFW configured selected: $CONFIGURE_UFW
UFW result: $UFW_ENABLED
Daemon config valid: $DAEMON_CONFIG_VALID
Existing setup detected: $EXISTING_SETUP
Verify log: $VERIFY_LOG
SCRIPT5_STATUS=completed
SCRIPT5_VERSION=$SCRIPT_VERSION
SCRIPT5_BUILD=$SCRIPT_BUILD
SCRIPT5_VERIFY_STATUS=$VERIFY_STATUS
SCRIPT5_VERIFY_LOG=$VERIFY_LOG
SCRIPT5_VERIFY_DISPLAY_LOG=$VERIFY_DISPLAY_LOG
SCRIPT5_POST_REBOOT_DISPLAY_HOOK=$POST_REBOOT_VERIFY_HOOK
SCRIPT5_POST_REBOOT_DISPLAY_MARKER=$POST_REBOOT_VERIFY_MARKER
SCRIPT5_TARGET_USER=$TARGET_USER
SCRIPT5_DOCKER_INSTALLED=$DOCKER_INSTALLED
SCRIPT5_DOCKER_SERVICE_ENABLED=$DOCKER_SERVICE_ENABLED
SCRIPT5_CONTAINERD_SERVICE_ENABLED=$CONTAINERD_SERVICE_ENABLED
SCRIPT5_USER_ADDED_TO_DOCKER=$USER_ADDED_TO_DOCKER
SCRIPT5_DOCKER_GC_TIMER=$DOCKER_GC_TIMER_INSTALLED
SCRIPT5_REDIS_OVERCOMMIT=$REDIS_OVERCOMMIT_CONFIGURED
SCRIPT5_UFW_ENABLED=$UFW_ENABLED
SCRIPT5_DAEMON_CONFIG_VALID=$DAEMON_CONFIG_VALID
EOF
    fi

    msg_ok "COMPLETION MARKER WRITTEN"
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
    local docker_lines=""
    local user_lines=""
    local system_lines=""
    local other_lines=""
    local line=""

    display_tmp="$(mktemp)"
    TEMP_FILES+=("$display_tmp")

    if root_path_exists "$VERIFY_LOG"; then
        result_lines="$(root_cat_file "$VERIFY_LOG" 2>/dev/null | awk '/^Results:/{flag=1; next} /^Docker versions:/{flag=0} flag {print}' || true)"
    fi

    docker_lines="$(printf '%s\n' "$result_lines" | grep -E 'Docker CLI exists|docker --version works|Docker Compose plugin works|Docker daemon reachable|Docker service active|containerd service active|daemon.json exists|daemon.json valid' || true)"
    user_lines="$(printf '%s\n' "$result_lines" | grep -E 'docker group exists|target user is in docker group' || true)"
    system_lines="$(printf '%s\n' "$result_lines" | grep -E 'no active swap detected|vm.overcommit_memory=1 active|Redis overcommit sysctl file exists|UFW active|UFW SSH rule|UFW HTTP rule|UFW HTTPS rule|Completion marker exists|docker-gc-safe' || true)"
    other_lines="$(printf '%s\n' "$result_lines" | grep -Ev 'Docker CLI exists|docker --version works|Docker Compose plugin works|Docker daemon reachable|Docker service active|containerd service active|daemon.json exists|daemon.json valid|docker group exists|target user is in docker group|no active swap detected|vm.overcommit_memory=1 active|Redis overcommit sysctl file exists|UFW active|UFW SSH rule|UFW HTTP rule|UFW HTTPS rule|Completion marker exists|docker-gc-safe' || true)"

    {
        echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
        echo -e "${BL}SCRIPT 5 POST-REBOOT VERIFICATION${CL}"
        echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
        echo ""
        echo -e "${YW}Docker:${CL}"
        if [ -n "$docker_lines" ]; then while IFS= read -r line; do [ -n "$line" ] && colorize_verify_line "$line"; done <<< "$docker_lines"; else echo -e "  ${BL}- INFO - No Docker verification lines recorded${CL}"; fi
        echo ""
        echo -e "${YW}User / Group:${CL}"
        if [ -n "$user_lines" ]; then while IFS= read -r line; do [ -n "$line" ] && colorize_verify_line "$line"; done <<< "$user_lines"; else echo -e "  ${BL}- INFO - No user/group verification lines recorded${CL}"; fi
        echo ""
        echo -e "${YW}System:${CL}"
        if [ -n "$system_lines" ]; then while IFS= read -r line; do [ -n "$line" ] && colorize_verify_line "$line"; done <<< "$system_lines"; else echo -e "  ${BL}- INFO - No system verification lines recorded${CL}"; fi
        if [ -n "$other_lines" ]; then while IFS= read -r line; do [ -n "$line" ] && colorize_verify_line "$line"; done <<< "$other_lines"; fi
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
        echo -e "  ${BL}Verify log:${CL} ${GN}${VERIFY_LOG}${CL}"
        echo ""
        echo -e "${YW}Next Step:${CL}"
        echo -e "  ${YW}Run ${ANS}Script 6${YW}.${CL}"
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
    local display_marker="/home/${TARGET_USER}/.docker-setup-verify-displayed"

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
TARGET_USER="$TARGET_USER"

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

/usr/local/sbin/circl8-script5-post-reboot-verify 2>/dev/null || true
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

function update_completion_marker_script5_fields() {
    local marker_tmp=""
    local existing_marker=""
    local display_marker="/home/${TARGET_USER}/.docker-setup-verify-displayed"

    POST_REBOOT_VERIFY_MARKER="$display_marker"
    marker_tmp="$(mktemp)"
    TEMP_FILES+=("$marker_tmp")

    if root_path_exists "$COMPLETED_MARKER"; then
        existing_marker="$(root_cat_file "$COMPLETED_MARKER" 2>/dev/null | grep -Ev '^SCRIPT5_' || true)"
    fi

    {
        [ -n "$existing_marker" ] && printf '%s\n' "$existing_marker"
        echo "SCRIPT5_STATUS=completed"
        echo "SCRIPT5_VERSION=$SCRIPT_VERSION"
        echo "SCRIPT5_BUILD=$SCRIPT_BUILD"
        echo "SCRIPT5_VERIFY_STATUS=$VERIFY_STATUS"
        echo "SCRIPT5_VERIFY_LOG=$VERIFY_LOG"
        echo "SCRIPT5_VERIFY_DISPLAY_LOG=$VERIFY_DISPLAY_LOG"
        echo "SCRIPT5_POST_REBOOT_DISPLAY_HOOK=$POST_REBOOT_VERIFY_HOOK"
        echo "SCRIPT5_POST_REBOOT_DISPLAY_MARKER=$display_marker"
        echo "SCRIPT5_TARGET_USER=$TARGET_USER"
        echo "SCRIPT5_DOCKER_INSTALLED=$DOCKER_INSTALLED"
        echo "SCRIPT5_DOCKER_SERVICE_ENABLED=$DOCKER_SERVICE_ENABLED"
        echo "SCRIPT5_CONTAINERD_SERVICE_ENABLED=$CONTAINERD_SERVICE_ENABLED"
        echo "SCRIPT5_USER_ADDED_TO_DOCKER=$USER_ADDED_TO_DOCKER"
        echo "SCRIPT5_DOCKER_GC_TIMER=$DOCKER_GC_TIMER_INSTALLED"
        echo "SCRIPT5_REDIS_OVERCOMMIT=$REDIS_OVERCOMMIT_CONFIGURED"
        echo "SCRIPT5_UFW_ENABLED=$UFW_ENABLED"
        echo "SCRIPT5_DAEMON_CONFIG_VALID=$DAEMON_CONFIG_VALID"
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

function load_state_from_completion_marker() {
    local marker_file="$COMPLETED_MARKER"
    local value=""

    value="$(marker_display_value "Target user" "$marker_file")"; [ "$value" != "unknown" ] && TARGET_USER="$value"
    value="$(marker_display_value "Virt Type" "$marker_file")"; [ "$value" != "unknown" ] && VIRT_TYPE="$value"
    value="$(marker_display_value "Container" "$marker_file")"; [ "$value" != "unknown" ] && IS_CONTAINER="$value"
    value="$(marker_display_value "LXC" "$marker_file")"; [ "$value" != "unknown" ] && IS_LXC="$value"
    value="$(marker_display_value "VM" "$marker_file")"; [ "$value" != "unknown" ] && IS_VM="$value"
    value="$(marker_display_value "Swap disabled selected" "$marker_file")"; [ "$value" != "unknown" ] && DISABLE_SWAP="$value"
    value="$(marker_display_value "Docker installed" "$marker_file")"; [ "$value" != "unknown" ] && DOCKER_INSTALLED="$value"
    value="$(marker_display_value "Docker service enabled" "$marker_file")"; [ "$value" != "unknown" ] && DOCKER_SERVICE_ENABLED="$value"
    value="$(marker_display_value "containerd service enabled" "$marker_file")"; [ "$value" != "unknown" ] && CONTAINERD_SERVICE_ENABLED="$value"
    value="$(marker_display_value "User added to docker group" "$marker_file")"; [ "$value" != "unknown" ] && USER_ADDED_TO_DOCKER="$value"
    value="$(marker_display_value "Docker GC timer" "$marker_file")"; [ "$value" != "unknown" ] && DOCKER_GC_TIMER_INSTALLED="$value"
    value="$(marker_display_value "Redis overcommit configured" "$marker_file")"; [ "$value" != "unknown" ] && REDIS_OVERCOMMIT_CONFIGURED="$value"
    value="$(marker_display_value "UFW configured selected" "$marker_file")"; [ "$value" != "unknown" ] && CONFIGURE_UFW="$value"
    value="$(marker_display_value "UFW result" "$marker_file")"; [ "$value" != "unknown" ] && UFW_ENABLED="$value"
    value="$(marker_display_value "Daemon config valid" "$marker_file")"; [ "$value" != "unknown" ] && DAEMON_CONFIG_VALID="$value"

    if [ "$DOCKER_GC_TIMER_INSTALLED" == "yes" ]; then INSTALL_DOCKER_GC="y"; else INSTALL_DOCKER_GC="n"; fi
    POST_REBOOT_VERIFY_MARKER="/home/${TARGET_USER}/.docker-setup-verify-displayed"
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
    echo -e "  ${YW}Run ${ANS}Script 6${YW}.${CL}"
}

function run_verify_only_mode() {
    VERIFY_ONLY_MODE="yes"
    load_state_from_completion_marker
    create_verification_report
    write_verify_display_log
    update_completion_marker_script5_fields
    show_verify_only_summary
    exit 0
}

# --- 45. FINAL SUMMARY ---
# Displays installed versions and next step using script 1-style output.
function show_final_summary() {
    local docker_version=""
    local compose_version=""

    section_flash_success "     ━━━━━━━━━━━━━━━━━    FINISHED    ━━━━━━━━━━━━━━━━━"

    if [ -n "$SUDO_CMD" ]; then
        docker_version="$($SUDO_CMD docker --version 2>/dev/null || true)"
        compose_version="$($SUDO_CMD docker compose version 2>/dev/null || true)"
    else
        docker_version="$(docker --version 2>/dev/null || true)"
        compose_version="$(docker compose version 2>/dev/null || true)"
    fi

    echo -e "${YW}Docker:${CL}"
    echo -e "  ${BL}Docker version:${CL} ${GN}${docker_version:-unknown}${CL}"
    echo -e "  ${BL}Compose version:${CL} ${GN}${compose_version:-unknown}${CL}"
    echo -e "  ${BL}Docker service:${CL} ${GN}${DOCKER_SERVICE_ENABLED}${CL}"
    echo -e "  ${BL}containerd service:${CL} ${GN}${CONTAINERD_SERVICE_ENABLED}${CL}"
    echo -e "  ${BL}Target user:${CL} ${GN}${TARGET_USER}${CL}"
    echo -e "  ${BL}User in docker group:${CL} ${GN}${USER_ADDED_TO_DOCKER}${CL}"

    echo ""
    echo -e "${YW}System:${CL}"
    detail_line "ENVIRONMENT" "$([ "$IS_CONTAINER" == "yes" ] && echo "LXC/Container (${VIRT_TYPE})" || echo "VM (${VIRT_TYPE})")"
    detail_line "SWAP DISABLED" "$SWAP_DISABLED"
    detail_line "DOCKER-GC HELPER" "$DOCKER_GC_INSTALLED"
    detail_line "DOCKER-GC TIMER" "$DOCKER_GC_TIMER_INSTALLED"
    detail_line "REDIS OVERCOMMIT" "${REDIS_OVERCOMMIT_CONFIGURED} (${REDIS_OVERCOMMIT_VALUE})"
    detail_line "UFW FIREWALL" "$UFW_ENABLED"
    detail_line "DAEMON CONFIG VALID" "$DAEMON_CONFIG_VALID"

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
    echo -e "${BL}SECURITY NOTE:${CL}"
    echo -e "${YW}Docker can publish container ports using Docker-managed firewall rules. Keep public exposure limited to Traefik/80/443 unless intentionally needed.${CL}"
    echo -e "${YW}Safe Docker cleanup uses host-side /usr/local/sbin/docker-gc-safe and never prunes volumes automatically.${CL}"
    echo ""
    echo -e "${BL}Next Step${CL}"
    echo ""
    if [ "$REBOOT_AFTER_FINISH" == "y" ]; then
        echo -e "${YW}Reboot the VM, SSH back in, then run ${ANS}Script 6${YW}.${CL}"
        echo -e "${DGN}Current file: 6-dockerENVsetup-circl8.sh${CL}"
    else
        echo -e "${YW}Option A - ${GN}reboot first:${CL}"
        echo -e "  ${YW}Reboot the VM, SSH back in, then run ${ANS}Script 6${YW}.${CL}"
        echo ""
        echo -e "${YW}Option B - ${GN}continue after re-login:${CL}"
        echo -e "  ${YW}Log out/in or start a new SSH session so docker group membership applies, then run ${ANS}Script 6${YW}.${CL}"
        echo -e "  ${DGN}Current file: 6-dockerENVsetup-circl8.sh${CL}"
    fi
    echo ""
}

# --- 46. REBOOT OPTION ---
# Uses the same single-countdown reboot flow as script 1/script 4.
# ENTER/Y = reboot now. SPACE/N = cancel. Timeout = reboot automatically.
function reboot_prompt() {
    section "REBOOT"

    if [ "$REBOOT_AFTER_FINISH" != "y" ]; then
        msg_skip "AUTO REBOOT SKIPPED"
        echo -e "${YW}Reboot was disabled during question collection. Reboot manually when ready.${CL}"
        return 0
    fi

    if [ "$IS_CONTAINER" == "yes" ]; then
        echo -e "${YW}Container mode detected. Restart may be controlled from the Proxmox host.${CL}"
        echo -e "${YW}Reboot skipped. Log out/in or restart the container from Proxmox if needed.${CL}"
        return 0
    fi

    echo -e "${YW}Docker group membership usually requires logout/login or reboot before using Docker without sudo.${CL}"
    echo ""

    if timed_reboot_countdown "$REBOOT_T"; then
        if [ -n "$SUDO_CMD" ]; then
            "$SUDO_CMD" reboot
        else
            reboot
        fi
    fi

    return 0
}

# =========================================================
#  MAIN ORCHESTRATION
# =========================================================

# --- 47. MAIN FUNCTION ---
# Runs the full setup in validation -> option collection -> install -> verify order.
function main() {
    init_script

    detect_environment
    check_previous_marker
    detect_existing_setup
    start_confirmation
    collect_user_options
    show_ready_to_apply

    handle_swap
    configure_redis_host_tuning
    install_repository_dependencies
    configure_docker_repository
    install_docker_engine
    configure_docker_group
    configure_docker_daemon
    configure_ufw_firewall
    install_docker_gc_helper

    verify_docker_installation
    write_completion_marker
    create_verification_report
    write_verify_display_log
    install_post_reboot_verify_hook
    update_completion_marker_script5_fields
    show_final_summary
    reboot_prompt

    exit 0
}

main "$@"
