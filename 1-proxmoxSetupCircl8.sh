#!/usr/bin/env bash
set -euo pipefail
export LVM_SUPPRESS_FD_WARNINGS=1
shopt -s inherit_errexit nullglob

# =========================================================
#  PVE9 Post Install
# =========================================================

# --- 1. COLOR VARIABLES ---
# Provides consistent terminal colours, success/error icons, flashing text, and reusable clear-line control.
YW="$(printf '\033[33m')"
BL="$(printf '\033[36m')"
RD="$(printf '\033[01;31m')"
BGN="$(printf '\033[4;92m')"
GN="$(printf '\033[1;92m')"
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

SCRIPT_SOURCE="1-proxmoxSetupCircl8.sh"
SCRIPT_VERSION="v1.3.7"
SCRIPT_UPDATED="2026-05-30"
SCRIPT_BUILD="script1-final-display-polish"

# --- 2. GLOBAL VARIABLES ---
# Stores timer values, logs, detected hardware state, user-selected options, and install results.
T=15
REBOOT_T=60
LOG_FILE="/var/log/pve9-postinstall.log"
VERIFY_LOG="/var/log/pve9-postinstall-verify.log"
COMPLETED_MARKER="/root/.pve9-postinstall-completed"

HOSTNAME_SHORT="$(hostname -s)"
SYSTEM_TYPE="Unknown"
CHASSIS="Unknown"
IS_VM="no"
IS_SSD="no"
IS_FRESH="yes"

CPU_TYPE=""
IOMMU_FLAG=""

DEFAULT_IFACE=""
LAN_CIDR=""
REALTEK_IFACE=""
REALTEK_OPTIMIZED="no"

GPU_ALL=""
IGPU_LINES=""
DGPU_LINES=""
IGPU_FOUND="no"
DGPU_FOUND="no"
DGPU_IDS=""
DGPU_BDFS=""
DGPU_VENDOR_IDS=""
GPU_SUMMARY=""

STORAGE_SUMMARY=""
ROOT_FS_TYPE=""
ROOT_SOURCE=""

ENABLE_PASSTHROUGH="n"
ENABLE_PERFORMANCE="n"
ENABLE_CROWDSEC="y"
ALLOW_PUBLIC_WEB="n"

SSH_HARDENING_APPLIED="no"
SSH_ROOT_KEY_FILE=""
SSH_ROOT_KEY_COUNT="0"
SSH_ROOT_KEY_TARGET=""
SSH_ROOT_KEY_OWNER=""
SSH_ROOT_KEY_MODE=""
SSH_EFFECTIVE_AUTHORIZED_KEYS=""
SSH_EFFECTIVE_PERMIT_ROOT=""
SSH_EFFECTIVE_PASSWORD_AUTH=""
SSH_EFFECTIVE_PUBKEY_AUTH=""
SSH_EFFECTIVE_KBD_AUTH=""
SSH_KEY_ONLY_HARDENING_REQUESTED="no"
PVE_FIREWALL_APPLIED="no"
CROWDSEC_BOUNCER_PACKAGE="none"
CROWDSEC_CONSOLE_ENROLLMENT="no"
CROWDSEC_CONSOLE_ENGINE_NAME=""
CROWDSEC_CONSOLE_ENROLLMENT_REQUESTED="no"
CROWDSEC_CONSOLE_ENROLLMENT_KEY=""
NUMLOCK_CONFIGURED="no"

STORAGE_LAYOUT_MODE="unselected"
ROOT_DISK_SIZE_GB="0"
LOCAL_LVM_EXISTS="no"
LOCAL_LVM_STORAGE_EXISTS="no"
LOCAL_LVM_CFG_EXISTS="no"
PVE_DATA_EXISTS="no"
PVE_DATA_IS_THINPOOL="no"
DECIMAL_GB_BYTES=1000000000
MIB_BYTES=1048576
CURRENT_ROOT_SIZE_GB="0"
CURRENT_ROOT_SIZE_MIB="0"
CURRENT_PVE_FREE_GB="0"
CURRENT_PVE_FREE_MIB="0"
TARGET_ROOT_SIZE_GB="100"
TARGET_ROOT_SIZE_MIB="0"
ROOT_LV_ALLOCATION_GB="100"
ROOT_LV_ALLOCATION_MIB="0"
ROOT_GROWTH_GB="0"
ROOT_GROWTH_MIB="0"
PVE_FREE_RESERVE_GB="1"
PVE_FREE_RESERVE_MIB="0"
CREATE_LOCAL_LVM="y"
LOCAL_LVM_SIZE_GB="0"
LOCAL_LVM_SIZE_MIB="0"
LOCAL_LVM_DEFAULT_SIZE_GB="0"
LOCAL_LVM_DEFAULT_SIZE_MIB="0"

TEMP_FILES=()

# =========================================================
#  OUTPUT / LOGGING FUNCTIONS
# =========================================================

# --- 3. HEADER FUNCTION ---
# Displays the one-line PVE9 Post Install ASCII banner.
function header_info {
echo -e "${RD}
██████╗ ██╗   ██╗███████╗ █████╗     ██████╗  ██████╗ ███████╗████████╗    ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     
██╔══██╗██║   ██║██╔════╝██╔══██╗    ██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     
██████╔╝██║   ██║█████╗  ╚██████║    ██████╔╝██║   ██║███████╗   ██║       ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     
██╔═══╝ ╚██╗ ██╔╝██╔══╝   ╚═══██║    ██╔═══╝ ██║   ██║╚════██║   ██║       ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     
██║      ╚████╔╝ ███████╗ █████╔╝    ██║     ╚██████╔╝███████║   ██║       ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
╚═╝       ╚═══╝  ╚══════╝ ╚════╝     ╚═╝      ╚═════╝ ╚══════╝   ╚═╝       ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝
${CL}"
}

# --- 4. MESSAGE HELPER FUNCTIONS ---
# Provides clean display -> apply -> success status lines.
function msg_info() { echo -ne " ${HOLD} ${YW}$1...${CL}"; }
function msg_ok() { echo -e "${BFR} ${CM} ${GN}$1${CL}"; }
function msg_warn() { echo -e "${BFR} ${WARN} ${YW}$1${CL}"; }
function msg_error() { echo -e "${BFR} ${CROSS} ${RD}$1${CL}"; exit 1; }

# --- SCRIPT VERSION DISPLAY ---
# Prints the currently running script version immediately under the ASCII banner.
function show_script_version() {
    echo -e "${GN}SCRIPT VERSION: ${SCRIPT_VERSION} | UPDATED: ${SCRIPT_UPDATED} | BUILD: ${SCRIPT_BUILD}${CL}"
    echo -e "${BL}SOURCE: ${SCRIPT_SOURCE}${CL}"
}

# --- 5. SECTION HEADER HELPER ---
# Prevents messy repeated msg_info output by giving each major stage a clean heading.
function section() {
    echo ""
    echo -e "${BORDER}"
    echo -e "${BL}$1${CL}"
    echo -e "${BORDER}"
}

# --- FLASHING SUCCESS SECTION HEADER HELPER ---
# Uses the standard final success layout with bold flashing green text.
function section_flash_success() {
    echo ""
    echo -e "${BORDER}"
    echo -e "${GN}${CLF}$1${CL}"
    echo -e "${BORDER}"
}

# --- DETAIL LINE HELPER ---
# Prints clean script 1-style detail lines for summaries and audit output.
function detail_line() {
    local label="$1"
    local value="$2"
    echo -e " ${BL}━━━━━▶${CL} ${label}: ${GN}${value}${CL}"
}

# --- 6. TTY PRINT HELPER ---
# Prints directly to the active terminal even when a function returns a value through stdout.
# This prevents command substitution from hiding countdown prompts and Y/n questions.
function tty_print() {
    if [ -w /dev/tty ]; then
        echo -ne "$*" > /dev/tty
    else
        echo -ne "$*" >&2
    fi
}

# --- 7. TTY PRINTLN HELPER ---
# Prints a full line directly to the active terminal.
# Used for visible final answers and clean user-facing messages.
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
# Removes temporary files created by run_cmd error capture.
function cleanup() {
    local exit_code="$?"

    for file in "${TEMP_FILES[@]:-}"; do
        [ -n "$file" ] && [ -f "$file" ] && rm -f "$file" 2>/dev/null || true
    done

    exit "$exit_code"
}

# --- 9. ERROR TRAP HELPER ---
# Shows the failing line number and points to the log file.
function on_error() {
    local line_no="$1"
    echo -e "${RD}ERROR:${CL} Script failed at line ${line_no}. Check ${LOG_FILE}"
}

# --- 10. COMMAND RUNNER ---
# Runs critical commands quietly, but shows real stderr if they fail.
# Use this for boot-critical or host-critical commands that must not silently fail.
function run_cmd() {
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

# --- 11. OPTIONAL COMMAND RUNNER ---
# Runs non-critical commands quietly and never stops the script.
function run_optional() {
    "$@" > /dev/null 2>&1 || true
}

# =========================================================
#  PROMPT FUNCTIONS
# =========================================================

# --- 12. YES/NO LABEL HELPER ---
# Converts raw Y/N input into clean visible yes/no wording.
function yes_no_label() {
    local value="${1:-}"

    if [[ "$value" =~ ^([Yy]|yes|YES|true|TRUE|1)$ ]]; then
        echo "yes"
    else
        echo "no"
    fi
}

# --- 13. BLOCKING YES/NO HELPER ---
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

# --- 14. TIMED YES/NO PROMPT HELPER ---
# Shows a wall-clock countdown for Y/n prompts.
# ENTER accepts default.
# Timeout accepts default.
# SPACE pauses countdown and waits for Y/N/ENTER.
# Final answer remains visible.
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

    echo "$answer"
}

# --- 15. REBOOT COUNTDOWN HELPER ---
# Shows a two-line wall-clock reboot countdown without creating a new line every second.
# ENTER/Y = reboot immediately.
# SPACE/N = stop countdown and do not reboot.
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
            if IFS= read -rsn1 -t 1 key; then
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
        fi
    done
}

# =========================================================
#  CONFIG HELPERS
# =========================================================

# --- 16. SPACE CONFIG HELPER ---
# Updates config files that use "Key Value" format.
# If the key exists, it replaces the value. If not, it appends the key/value.
function set_or_append_space_config() {
    local file="$1"
    local key="$2"
    local value="$3"

    touch "$file"

    if grep -Eq "^[#[:space:]]*${key}[[:space:]]+" "$file"; then
        sed -i -E "s|^[#[:space:]]*${key}[[:space:]].*|${key} ${value}|" "$file"
    else
        echo "${key} ${value}" >> "$file"
    fi
}

# --- 17. EQUALS CONFIG HELPER ---
# Updates config files that use "Key=Value" format.
# If the key exists, it replaces the value. If not, it appends the key/value.
function set_or_append_equals_config() {
    local file="$1"
    local key="$2"
    local value="$3"

    touch "$file"

    if grep -Eq "^[#[:space:]]*${key}=.*" "$file"; then
        sed -i -E "s|^[#[:space:]]*${key}=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}

# --- 18. GRUB ARGUMENT HELPER ---
# Safely appends a kernel argument to GRUB_CMDLINE_LINUX_DEFAULT without removing existing arguments.
function append_grub_arg() {
    local arg="$1"
    local grub_file="/etc/default/grub"

    grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_file" || echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet"' >> "$grub_file"

    if ! grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_file" | grep -qw "$arg"; then
        sed -i -E "s|^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"|\1 ${arg}\"|" "$grub_file"
    fi
}

# --- 19. COUNTDOWN EXIT HELPER ---
# Displays a safety reason, waits briefly, and exits.
function countdown_exit() {
    local seconds="$1"
    local reason="$2"

    echo ""
    echo -e "${RD}${reason}${CL}"
    echo -e "${YW}Exiting in ${seconds} seconds...${CL}"
    sleep "$seconds"
    exit 1
}

# =========================================================
#  HARDWARE DETECTION HELPERS
# =========================================================

# --- 20. PCI VENDOR NAME HELPER ---
# Converts PCI vendor IDs into readable vendor names without using lspci.
function pci_vendor_name() {
    local vendor="$1"

    case "$vendor" in
        0x8086) echo "Intel" ;;
        0x10de) echo "NVIDIA" ;;
        0x1002) echo "AMD" ;;
        0x1022) echo "AMD" ;;
        *) echo "Unknown" ;;
    esac
}

# --- 21. GPU TYPE CLASSIFIER ---
# Classifies GPUs using sysfs vendor/class/boot_vga instead of fragile lspci text matching.
# This avoids misclassifying AMD APUs as passthrough dGPUs on laptops.
function classify_gpu_type() {
    local vendor="$1"
    local class="$2"
    local boot_vga="$3"
    local gpu_count="$4"

    if [ "$vendor" == "0x10de" ]; then
        echo "discrete"
        return 0
    fi

    if [ "$vendor" == "0x8086" ]; then
        if [ "$gpu_count" -gt 1 ] && [ "$boot_vga" != "1" ] && [ "$class" != "0x030000" ]; then
            echo "discrete"
        else
            echo "integrated"
        fi
        return 0
    fi

    if [ "$vendor" == "0x1002" ] || [ "$vendor" == "0x1022" ]; then
        if [ "$gpu_count" -gt 1 ] && [ "$SYSTEM_TYPE" == "Laptop" ] && [ "$boot_vga" == "1" ]; then
            echo "integrated"
        else
            echo "discrete"
        fi
        return 0
    fi

    if [ "$boot_vga" == "1" ]; then
        echo "integrated"
    else
        echo "unknown"
    fi
}

# --- 22. SYSFS GPU DETECTION HELPER ---
# Detects GPUs through /sys/bus/pci/devices instead of lspci.
# This avoids lspci hangs on some fresh Proxmox/laptop PCI states.
function detect_gpus_sysfs() {
    local dev=""
    local bdf=""
    local class=""
    local vendor=""
    local device=""
    local boot_vga=""
    local vendor_name=""
    local gpu_type=""
    local line=""
    local gpu_records=""
    local gpu_count="0"
    local gpu_slot=""
    local func=""
    local func_vendor=""
    local func_device=""
    local id=""

    GPU_ALL=""
    IGPU_LINES=""
    DGPU_LINES=""
    IGPU_FOUND="no"
    DGPU_FOUND="no"
    DGPU_IDS=""
    DGPU_BDFS=""
    DGPU_VENDOR_IDS=""
    GPU_SUMMARY=""

    for dev in /sys/bus/pci/devices/*; do
        [ -e "$dev/class" ] || continue
        [ -e "$dev/vendor" ] || continue
        [ -e "$dev/device" ] || continue

        class="$(cat "$dev/class" 2>/dev/null || true)"

        case "$class" in
            0x030000|0x030200|0x038000)
                bdf="$(basename "$dev")"
                vendor="$(cat "$dev/vendor" 2>/dev/null || true)"
                device="$(cat "$dev/device" 2>/dev/null || true)"
                boot_vga="0"

                if [ -r "$dev/boot_vga" ]; then
                    boot_vga="$(cat "$dev/boot_vga" 2>/dev/null || echo 0)"
                fi

                gpu_records+="${bdf}|${vendor}|${device}|${class}|${boot_vga}"$'\n'
                gpu_count=$((gpu_count + 1))
                ;;
        esac
    done

    while IFS='|' read -r bdf vendor device class boot_vga; do
        [ -z "$bdf" ] && continue

        vendor_name="$(pci_vendor_name "$vendor")"
        gpu_type="$(classify_gpu_type "$vendor" "$class" "$boot_vga" "$gpu_count")"
        line="${bdf} ${vendor_name} GPU [${vendor#0x}:${device#0x}] boot_vga=${boot_vga}"

        GPU_ALL+="${line}"$'\n'

        if [ "$gpu_type" == "integrated" ]; then
            IGPU_LINES+="${line}"$'\n'
            IGPU_FOUND="yes"
        elif [ "$gpu_type" == "discrete" ]; then
            DGPU_LINES+="${line}"$'\n'
            DGPU_BDFS+="${bdf} "
            DGPU_FOUND="yes"
            DGPU_VENDOR_IDS+="${vendor} "

            gpu_slot="${bdf%.*}"

            for func in /sys/bus/pci/devices/${gpu_slot}.*; do
                [ -e "$func/vendor" ] || continue
                [ -e "$func/device" ] || continue

                func_vendor="$(cat "$func/vendor" 2>/dev/null || true)"
                func_device="$(cat "$func/device" 2>/dev/null || true)"
                id="${func_vendor#0x}:${func_device#0x}"

                if [[ "$id" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$ ]]; then
                    if [[ ",${DGPU_IDS}," != *",${id},"* ]]; then
                        DGPU_IDS+="${id},"
                    fi
                fi
            done
        fi
    done <<< "$gpu_records"

    DGPU_IDS="${DGPU_IDS%,}"
}

# --- 23. GPU SUMMARY HELPER ---
# Builds a user-friendly integrated/discrete GPU summary from detected sysfs records.
function build_gpu_summary() {
    local out=""

    if [ -n "$IGPU_LINES" ]; then
        while read -r line; do
            [ -z "$line" ] && continue
            out+="Integrated: ${line}; "
        done <<< "$IGPU_LINES"
    fi

    if [ -n "$DGPU_LINES" ]; then
        while read -r line; do
            [ -z "$line" ] && continue
            out+="Discrete: ${line}; "
        done <<< "$DGPU_LINES"
    fi

    echo "${out%; }"
}

# --- 24. STORAGE SUMMARY HELPER ---
# Detects attached disks and displays SSD/HDD summary for the user.
function build_storage_summary() {
    local out=""

    while read -r name rota type; do
        [ "$type" != "disk" ] && continue

        if [ "$rota" == "0" ]; then
            out+="SSD(${name}) "
        else
            out+="HDD(${name}) "
        fi
    done < <(lsblk -dn -o NAME,ROTA,TYPE)

    echo "$out" | xargs
}


# --- LAN CIDR HELPER ---
# Converts a host IPv4/prefix such as 192.168.1.11/24 into the real network CIDR 192.168.1.0/24.
function calculate_ipv4_network_cidr() {
    local host_cidr="$1"
    local ip=""
    local prefix=""
    local o1=""
    local o2=""
    local o3=""
    local o4=""
    local ip_int=""
    local mask=""
    local network=""

    ip="${host_cidr%/*}"
    prefix="${host_cidr#*/}"

    IFS='.' read -r o1 o2 o3 o4 <<< "$ip"

    if ! [[ "$o1" =~ ^[0-9]+$ && "$o2" =~ ^[0-9]+$ && "$o3" =~ ^[0-9]+$ && "$o4" =~ ^[0-9]+$ && "$prefix" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if [ "$o1" -gt 255 ] || [ "$o2" -gt 255 ] || [ "$o3" -gt 255 ] || [ "$o4" -gt 255 ] || [ "$prefix" -lt 0 ] || [ "$prefix" -gt 32 ]; then
        return 1
    fi

    ip_int=$(( (o1 << 24) + (o2 << 16) + (o3 << 8) + o4 ))

    if [ "$prefix" -eq 0 ]; then
        mask=0
    else
        mask=$(( (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF ))
    fi

    network=$(( ip_int & mask ))
    printf '%d.%d.%d.%d/%d\n' \
        $(( (network >> 24) & 255 )) \
        $(( (network >> 16) & 255 )) \
        $(( (network >> 8) & 255 )) \
        $(( network & 255 )) \
        "$prefix"
}

# --- 25. MACHINE/GPU LABEL HELPER ---
# Builds adaptive system-aware GPU detection labels.
function detected_machine_gpu_label() {
    local system_label=""

    case "$SYSTEM_TYPE" in
        Laptop) system_label="laptop" ;;
        "Virtual Machine") system_label="virtual machine" ;;
        "PC/Workstation") system_label="PC/workstation" ;;
        *) system_label="system" ;;
    esac

    if [ "$IGPU_FOUND" == "yes" ] && [ "$DGPU_FOUND" == "yes" ]; then
        echo "Detected ${system_label} with integrated + discrete GPU"
    elif [ "$IGPU_FOUND" == "yes" ]; then
        echo "Detected ${system_label} with integrated GPU"
    elif [ "$DGPU_FOUND" == "yes" ]; then
        echo "Detected ${system_label} with discrete GPU"
    else
        echo "Detected ${system_label} with no GPU passthrough target"
    fi
}

# --- GPU DETAIL DISPLAY HELPER ---
# Prints integrated/discrete GPU records in readable grouped blocks without changing detection logic.
function print_gpu_detail_group() {
    local title="$1"
    local lines="$2"
    local line=""

    [ -n "$lines" ] || return 0

    echo ""
    echo -e "${BL}${title}:${CL}"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo -e "  ${GN}${line}${CL}"
    done <<< "$lines"
}

# --- 26. REALTEK NIC DETECTION HELPER ---
# Detects common Realtek Linux drivers so unstable offload features can be disabled safely.
function detect_realtek_iface() {
    local iface=""
    local iface_name=""

    for iface in /sys/class/net/*; do
        iface_name="$(basename "$iface")"
        [ "$iface_name" = "lo" ] && continue

        if ethtool -i "$iface_name" 2>/dev/null | grep -qiE "driver: r8169|driver: r8168|driver: r8125|driver: r8126"; then
            echo "$iface_name"
            return 0
        fi
    done

    return 1
}

# =========================================================
#  VALIDATION / INITIALIZATION
# =========================================================

# --- 27. DEPENDENCY VALIDATION ---
# Validates critical commands early so failures happen before changes are made.
function validate_dependencies() {
    local required_commands=(
        apt-cache
        apt-get
        awk
        basename
        cat
        chmod
        cp
        curl
        cut
        date
        df
        env
        findmnt
        grep
        hostname
        ip
        lsblk
        lvcreate
        lvdisplay
        lvextend
        lvs
        mkdir
        pct
        pve-firewall
        pvesm
        pvs
        qm
        reboot
        readlink
        resize2fs
        rm
        sed
        sleep
        sort
        sshd
        stat
        sysctl
        systemctl
        tee
        touch
        update-grub
        update-initramfs
        vgs
        xargs
    )

    for cmd in "${required_commands[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || msg_error "Required command not found: ${cmd}"
    done
}

# --- 28. PROXMOX VERSION VALIDATION ---
# Validates that this is a Proxmox VE 9+ host before showing fresh-install warnings.
function validate_proxmox() {
    local pve_major=""

    if ! command -v pveversion >/dev/null 2>&1; then
        msg_error "This system is not Proxmox VE. Script cancelled."
    fi

    pve_major="$(pveversion | cut -d'/' -f2 | cut -d'.' -f1)"

    if ! [[ "$pve_major" =~ ^[0-9]+$ ]]; then
        msg_error "Could not detect Proxmox VE version. Script cancelled."
    fi

    if [ "$pve_major" -lt 9 ]; then
        msg_error "Requires Proxmox VE 9+. Detected Proxmox VE ${pve_major}. Script Cancelled."
    fi
}

# --- 29. SCRIPT INITIALIZATION ---
# Starts logging, installs traps, clears screen and validates root/proxmox/dependencies.
function init_script() {
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
}

# =========================================================
#  PRE-INSTALL VALIDATION AND AUDIT
# =========================================================

# --- 30. FRESH INSTALL WARNING ---
# Shows flashing warning only after confirming this is Proxmox VE 9+.
function show_fresh_install_warning() {
    echo -e "${YW}This script will perform PVE9 post-install routines.${CL}"
    echo -e "${YW}${CLF}Intended for FRESH Proxmox VE 9 installs only.${CL}"
}

# --- 31. PRE-INSTALL HARDWARE AUDIT ---
# Detects CPU vendor, chassis/system type, virtual machine state, SSD presence, LAN CIDR and storage summary.
function audit_hardware() {
    local local_host_cidr=""

    section "PRE-INSTALL HARDWARE AUDIT"

    msg_info "Auditing host hardware"

    CPU_TYPE="$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}' || true)"

    if [ "$CPU_TYPE" == "GenuineIntel" ]; then
        IOMMU_FLAG="intel_iommu=on"
    else
        IOMMU_FLAG="amd_iommu=on"
    fi

    if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --quiet; then
        IS_VM="yes"
    fi

    if command -v dmidecode >/dev/null 2>&1; then
        CHASSIS="$(dmidecode -s chassis-type 2>/dev/null || echo "Unknown")"
    fi

    if [[ "$CHASSIS" =~ (Laptop|Notebook|Portable) ]]; then
        SYSTEM_TYPE="Laptop"
    elif [ "$IS_VM" == "yes" ]; then
        SYSTEM_TYPE="Virtual Machine"
    else
        SYSTEM_TYPE="PC/Workstation"
    fi

    if lsblk -dn -o ROTA | grep -q "^0$"; then
        IS_SSD="yes"
    fi

    DEFAULT_IFACE="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}' || true)"

    if [ -n "$DEFAULT_IFACE" ]; then
        local_host_cidr="$(ip -o -4 addr show dev "$DEFAULT_IFACE" | awk '{print $4; exit}' || true)"
        if [ -n "$local_host_cidr" ]; then
            LAN_CIDR="$(calculate_ipv4_network_cidr "$local_host_cidr" || true)"
        fi
    fi

    STORAGE_SUMMARY="$(build_storage_summary)"
    ROOT_FS_TYPE="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"
    ROOT_SOURCE="$(findmnt -n -o SOURCE / 2>/dev/null || true)"

    msg_ok "HOST HARDWARE AUDITED"
}

# --- 32. FRESH INSTALL DETECTION ---
# Blocks reruns on systems that already have VM/CT state or script artefacts from prior execution.
function check_fresh_install_state() {
    local vm_count=""
    local ct_count=""
    local custom_bridges=""
    local marker=""

    section "FRESH INSTALL SAFETY CHECK"

    msg_info "Checking for fresh install state"

    vm_count="$(qm list 2>/dev/null | awk 'NR>1 {count++} END {print count+0}')"
    ct_count="$(pct list 2>/dev/null | awk 'NR>1 {count++} END {print count+0}')"
    custom_bridges="$(grep -Ec "^auto vmbr[1-9]" /etc/network/interfaces 2>/dev/null || true)"

    if [ "$vm_count" -gt 0 ] || [ "$ct_count" -gt 0 ] || [ "$custom_bridges" -gt 0 ]; then
        IS_FRESH="no"
    fi

    for marker in \
        "$COMPLETED_MARKER" \
        "/var/log/pve9-postinstall-verify.log" \
        "/usr/local/sbin/pve-no-nag-patch.sh" \
        "/etc/apt/apt.conf.d/no-nag-script" \
        "/etc/sysctl.d/99-pve9-hardening-network.conf" \
        "/etc/systemd/system/pve-numlock.service" \
        "/etc/systemd/system/realtek-optimize.service" \
        "/etc/profile.d/pve-postinstall-verify-display.sh"
    do
        if [ -e "$marker" ]; then
            IS_FRESH="no"
        fi
    done

    if [ "$IS_FRESH" == "no" ]; then
        echo ""
        echo -e "${RD}WARNING: This does not look like a fresh install.${CL}"
        echo -e "${YW}Detected VMs: ${vm_count}, LXCs: ${ct_count}, extra bridges: ${custom_bridges}.${CL}"
        countdown_exit 30 "For safety this script will not continue on a non-fresh-looking node."
    fi

    msg_ok "FRESH INSTALL CHECK PASSED"
}

# --- 33. GPU DETECTION AND PROMPT ---
# Detects integrated and discrete GPUs before displaying adaptive GPU messages.
function detect_gpu_and_collect_choice() {
    local gpu_yn=""

    section "GPU DETECTION"

    msg_info "Detecting GPU hardware"
    detect_gpus_sysfs
    GPU_SUMMARY="$(build_gpu_summary)"
    msg_ok "$(detected_machine_gpu_label)"

    if [ -n "${IGPU_LINES}${DGPU_LINES}" ]; then
        print_gpu_detail_group "Integrated GPU" "$IGPU_LINES"
        print_gpu_detail_group "Discrete GPU" "$DGPU_LINES"
        echo ""
    else
        echo -e " ${BL}━━━━━▶${CL} No GPU details detected"
    fi

    ENABLE_PASSTHROUGH="n"

    if [ "$DGPU_FOUND" == "yes" ]; then
        if [ "$SYSTEM_TYPE" == "Laptop" ] && [ "$IGPU_FOUND" == "yes" ]; then
            echo -e "${YW}Integrated GPU will be kept for laptop screen.${CL}"
            echo -e "${YW}Only the discrete GPU and same-slot function devices will be isolated.${CL}"
        else
            echo -e "${YW}Only the discrete GPU and same-slot function devices will be isolated.${CL}"
        fi

        echo ""
        gpu_yn="$(timed_yes_no "Isolate discrete GPU for VM passthrough?" "y")"

        if [[ "$gpu_yn" =~ ^[Yy] ]]; then
            ENABLE_PASSTHROUGH="y"
            msg_ok "Discrete GPU passthrough will be activated"
        else
            ENABLE_PASSTHROUGH="n"
            msg_warn "Discrete GPU passthrough will not be activated"
        fi
    else
        msg_ok "No discrete GPU detected. GPU passthrough will be skipped"
    fi
}

# --- 34. STORAGE DETECTION DISPLAY ---
# Displays detected disk type summary before final start prompt.
function show_storage_detection() {
    section "STORAGE DETECTION"

    msg_ok "DETECTED STORAGE TYPE"
    echo -e " ${BL}━━━━━▶${CL} ${STORAGE_SUMMARY:-No disk summary detected}"
    echo -e " ${BL}━━━━━▶${CL} ROOT FILESYSTEM: ${ROOT_FS_TYPE:-unknown} (${ROOT_SOURCE:-unknown})"
}

# --- 35. USER OPTION COLLECTION ---
# Collects optional choices using timed prompts.

# --- STORAGE LAYOUT STATUS HELPERS ---
# These helpers only read Proxmox/LVM state. They must never create, remove or resize storage.
# They are written defensively for set -e/pipefail so detection failures return 1 instead of exiting.
function storage_id_in_pvesm_status() {
    local storage_id="$1"

    if pvesm status 2>/dev/null | awk -v sid="$storage_id" 'NR>1 && $1 == sid { found=1 } END { exit found ? 0 : 1 }'; then
        return 0
    fi

    return 1
}

function storage_cfg_has_local_lvm() {
    if grep -Eq '^lvmthin:[[:space:]]+local-lvm$' /etc/pve/storage.cfg 2>/dev/null; then
        return 0
    fi

    return 1
}

function pve_vg_exists() {
    if vgs pve >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

function pve_root_lv_exists() {
    if lvs pve/root >/dev/null 2>&1 || lvdisplay /dev/pve/root >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

function pve_data_lv_exists() {
    if lvdisplay /dev/pve/data >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

function pve_data_thinpool_exists() {
    local lv_attr=""

    lv_attr="$(lvs --noheadings -o lv_attr pve/data 2>/dev/null | awk 'NF {print $1; exit}' || true)"
    if [ -n "$lv_attr" ]; then
        case "$lv_attr" in
            t*) return 0 ;;
            *) return 1 ;;
        esac
    fi

    return 1
}

function detect_installer_local_lvm_layout() {
    if storage_id_in_pvesm_status "local" && \
       storage_id_in_pvesm_status "local-lvm" && \
       storage_cfg_has_local_lvm && \
       pve_vg_exists && \
       pve_root_lv_exists && \
       pve_data_thinpool_exists; then
        return 0
    fi

    return 1
}

function get_lvm_size_bytes() {
    local lv_path="$1"
    local raw=""

    raw="$(lvs --noheadings --units b --nosuffix -o lv_size "$lv_path" 2>/dev/null | awk 'NF { gsub(/[^0-9]/, "", $1); print $1; exit }' || true)"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        echo "$raw"
    else
        echo "0"
    fi
}

function get_pve_free_bytes() {
    local raw=""

    raw="$(vgs --noheadings --units b --nosuffix -o vg_free pve 2>/dev/null | awk 'NF { gsub(/[^0-9]/, "", $1); print $1; exit }' || true)"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        echo "$raw"
    else
        echo "0"
    fi
}

function decimal_gb_to_mib_floor() {
    local gb="$1"
    echo $(( (gb * DECIMAL_GB_BYTES) / MIB_BYTES ))
}

function root_visible_gb_to_allocation_gb() {
    local visible_gb="$1"

    case "${ROOT_FS_TYPE:-unknown}" in
        ext2|ext3|ext4)
            echo $(( (visible_gb * 102 + 99) / 100 ))
            ;;
        *)
            echo "$visible_gb"
            ;;
    esac
}

function mib_to_decimal_gb_floor() {
    local mib="$1"
    echo $(( (mib * MIB_BYTES) / DECIMAL_GB_BYTES ))
}

function bytes_to_mib_floor() {
    local bytes="$1"
    echo $(( bytes / MIB_BYTES ))
}

function bytes_to_decimal_gb_floor() {
    local bytes="$1"
    echo $(( bytes / DECIMAL_GB_BYTES ))
}

function bytes_to_decimal_gb_ceil() {
    local bytes="$1"
    if [ "$bytes" -le 0 ]; then
        echo "0"
    else
        echo $(( (bytes + DECIMAL_GB_BYTES - 1) / DECIMAL_GB_BYTES ))
    fi
}

function read_storage_gb_input() {
    local prompt="$1"
    local default_value="$2"
    local allow_zero="${3:-no}"
    local value=""

    while true; do
        tty_print "${YW}${prompt} [${default_value}]: ${CL}"
        if [ -r /dev/tty ]; then
            IFS= read -r value < /dev/tty || true
        else
            IFS= read -r value || true
        fi

        value="${value:-$default_value}"
        value="$(printf '%s' "$value" | xargs || true)"

        if [[ "$value" =~ ^[0-9]+$ ]]; then
            if [ "$allow_zero" == "yes" ] || [ "$value" -gt 0 ]; then
                echo "$value"
                return 0
            fi
        fi

        tty_println "${RD}Enter a whole number greater than zero.${CL}"
    done
}

# --- STORAGE LAYOUT DETECTION HELPER ---
# Detects installer-created local-lvm state and reads current pve/root and pve VG free sizes.
function detect_storage_layout_options() {
    LOCAL_LVM_EXISTS="no"
    LOCAL_LVM_STORAGE_EXISTS="no"
    LOCAL_LVM_CFG_EXISTS="no"
    PVE_DATA_EXISTS="no"
    PVE_DATA_IS_THINPOOL="no"
    ROOT_DISK_SIZE_GB="0"
    CURRENT_ROOT_SIZE_GB="0"
    CURRENT_ROOT_SIZE_MIB="0"
    CURRENT_PVE_FREE_GB="0"
    CURRENT_PVE_FREE_MIB="0"

    if storage_id_in_pvesm_status "local-lvm"; then
        LOCAL_LVM_STORAGE_EXISTS="yes"
    fi

    if storage_cfg_has_local_lvm; then
        LOCAL_LVM_CFG_EXISTS="yes"
    fi

    if pve_data_lv_exists; then
        PVE_DATA_EXISTS="yes"
    fi

    if pve_data_thinpool_exists; then
        PVE_DATA_IS_THINPOOL="yes"
    fi

    if detect_installer_local_lvm_layout; then
        LOCAL_LVM_EXISTS="yes"
    fi

    local root_size_bytes=""
    local pve_free_bytes=""

    root_size_bytes="$(get_lvm_size_bytes /dev/pve/root)"
    pve_free_bytes="$(get_pve_free_bytes)"

    CURRENT_ROOT_SIZE_MIB="$(bytes_to_mib_floor "$root_size_bytes")"
    CURRENT_ROOT_SIZE_GB="$(bytes_to_decimal_gb_ceil "$root_size_bytes")"
    CURRENT_PVE_FREE_MIB="$(bytes_to_mib_floor "$pve_free_bytes")"
    CURRENT_PVE_FREE_GB="$(bytes_to_decimal_gb_floor "$pve_free_bytes")"
    ROOT_DISK_SIZE_GB="$CURRENT_ROOT_SIZE_GB"

    return 0
}

function validate_storage_conflict_state() {
    if [ "$LOCAL_LVM_EXISTS" == "yes" ]; then
        return 0
    fi

    if [ "$LOCAL_LVM_STORAGE_EXISTS" == "yes" ] || [ "$LOCAL_LVM_CFG_EXISTS" == "yes" ]; then
        msg_error "local-lvm storage config exists but the expected pve/data thinpool was not detected. Manual storage review required."
    fi

    if [ "$PVE_DATA_EXISTS" == "yes" ]; then
        msg_error "/dev/pve/data exists but local-lvm is not registered as the expected installer layout. Manual storage review required."
    fi
}

function calculate_storage_plan() {
    TARGET_ROOT_SIZE_MIB="$(decimal_gb_to_mib_floor "$TARGET_ROOT_SIZE_GB")"
    ROOT_LV_ALLOCATION_GB="$(root_visible_gb_to_allocation_gb "$TARGET_ROOT_SIZE_GB")"
    ROOT_LV_ALLOCATION_MIB="$(decimal_gb_to_mib_floor "$ROOT_LV_ALLOCATION_GB")"
    PVE_FREE_RESERVE_MIB="$(decimal_gb_to_mib_floor "$PVE_FREE_RESERVE_GB")"
    ROOT_GROWTH_MIB="0"
    ROOT_GROWTH_GB="0"
    LOCAL_LVM_DEFAULT_SIZE_MIB="0"
    LOCAL_LVM_DEFAULT_SIZE_GB="0"

    if [ "$ROOT_LV_ALLOCATION_MIB" -gt "$CURRENT_ROOT_SIZE_MIB" ]; then
        ROOT_GROWTH_MIB="$(( ROOT_LV_ALLOCATION_MIB - CURRENT_ROOT_SIZE_MIB ))"
        ROOT_GROWTH_GB="$(mib_to_decimal_gb_floor "$ROOT_GROWTH_MIB")"
    fi

    LOCAL_LVM_DEFAULT_SIZE_MIB="$(( CURRENT_PVE_FREE_MIB - ROOT_GROWTH_MIB - PVE_FREE_RESERVE_MIB ))"
    if [ "$LOCAL_LVM_DEFAULT_SIZE_MIB" -lt 0 ]; then
        LOCAL_LVM_DEFAULT_SIZE_MIB="0"
    fi
    LOCAL_LVM_DEFAULT_SIZE_GB="$(mib_to_decimal_gb_floor "$LOCAL_LVM_DEFAULT_SIZE_MIB")"
}

function validate_storage_builder_plan() {
    local total_required_mib="0"
    local total_required_gb="0"

    if [ "$PVE_FREE_RESERVE_GB" -lt 0 ]; then
        msg_error "Requested pve VG reserve cannot be negative."
    fi

    LOCAL_LVM_SIZE_MIB="0"
    if [ "$CREATE_LOCAL_LVM" == "y" ]; then
        if [ "$LOCAL_LVM_SIZE_GB" -le 0 ]; then
            msg_error "local-lvm size must be greater than zero when local-lvm creation is selected."
        fi
        LOCAL_LVM_SIZE_MIB="$(decimal_gb_to_mib_floor "$LOCAL_LVM_SIZE_GB")"
    fi

    total_required_mib="$(( ROOT_GROWTH_MIB + PVE_FREE_RESERVE_MIB + LOCAL_LVM_SIZE_MIB ))"
    total_required_gb="$(mib_to_decimal_gb_floor "$total_required_mib")"

    if [ "$total_required_mib" -gt "$CURRENT_PVE_FREE_MIB" ]; then
        msg_error "Storage plan needs about ${total_required_gb}GB decimal but only ${CURRENT_PVE_FREE_GB}GB decimal pve VG free space is available."
    fi
}

function show_storage_plan() {
    echo ""
    echo -e "${BL}Storage plan:${CL}"
    detail_line "storage mode" "$STORAGE_LAYOUT_MODE"

    case "$STORAGE_LAYOUT_MODE" in
        preserve_local_lvm)
            detail_line "local-lvm detected" "yes"
            detail_line "root/local expansion" "skipped"
            detail_line "local-lvm creation" "skipped"
            ;;
        build_local_lvm)
            detail_line "current root/local" "${CURRENT_ROOT_SIZE_GB}GB"
            detail_line "target local visible size" "${TARGET_ROOT_SIZE_GB}GB"
            detail_line "root LV allocation target" "${ROOT_LV_ALLOCATION_GB}GB"
            detail_line "root growth needed" "${ROOT_GROWTH_GB}GB"
            detail_line "current pve free" "${CURRENT_PVE_FREE_GB}GB"
            detail_line "reserve free VG space" "${PVE_FREE_RESERVE_GB}GB"
            detail_line "create local-lvm" "yes"
            detail_line "local-lvm size" "${LOCAL_LVM_SIZE_GB}GB"
            ;;
        extend_root_only)
            detail_line "current root/local" "${CURRENT_ROOT_SIZE_GB}GB"
            detail_line "target local visible size" "${TARGET_ROOT_SIZE_GB}GB"
            detail_line "root LV allocation target" "${ROOT_LV_ALLOCATION_GB}GB"
            detail_line "root growth needed" "${ROOT_GROWTH_GB}GB"
            detail_line "create local-lvm" "no"
            detail_line "reserve free VG space" "${PVE_FREE_RESERVE_GB}GB"
            ;;
        skip_root_expansion)
            detail_line "root/local expansion" "skipped"
            detail_line "local-lvm creation" "skipped"
            ;;
    esac
}

# --- STORAGE LAYOUT OPTION COLLECTOR ---
# Preserves installer-created local-lvm or builds the requested root/local + local-lvm layout from free pve VG space.
function collect_storage_layout_option() {
    local create_lvm_yn=""
    local default_target="100"

    section "STORAGE LAYOUT OPTION"

    detect_storage_layout_options

    detail_line "Current root/local size" "${CURRENT_ROOT_SIZE_GB}GB"
    detail_line "Current pve VG free" "${CURRENT_PVE_FREE_GB}GB"
    detail_line "local-lvm detected" "$LOCAL_LVM_EXISTS"

    if [ "$LOCAL_LVM_EXISTS" == "yes" ]; then
        STORAGE_LAYOUT_MODE="preserve_local_lvm"
        msg_ok "Detected installer-created local-lvm storage"
        echo -e "${YW}Preserving Proxmox installer disk layout.${CL}"
        echo -e "${YW}Root/local will not be expanded to 100%FREE.${CL}"
        show_storage_plan
        return 0
    fi

    validate_storage_conflict_state

    if [ "$CURRENT_PVE_FREE_GB" -le 0 ]; then
        STORAGE_LAYOUT_MODE="skip_root_expansion"
        msg_warn "No free pve VG space detected. Root/local expansion and local-lvm creation will be skipped."
        show_storage_plan
        return 0
    fi

    echo ""
    echo -e "${YW}No installer-created local-lvm storage was detected.${CL}"
    echo -e "${YW}Script 1 can build root/local target sizing and snapshot-ready local-lvm from free pve VG space.${CL}"
    echo ""

    if [ "$CURRENT_ROOT_SIZE_GB" -gt "$default_target" ]; then
        default_target="$CURRENT_ROOT_SIZE_GB"
    fi

    TARGET_ROOT_SIZE_GB="$(read_storage_gb_input "Set Proxmox root/local target size in GB" "$default_target" "no")"
    PVE_FREE_RESERVE_GB="$(read_storage_gb_input "Reserve free pve VG space in GB" "1" "yes")"

    calculate_storage_plan

    create_lvm_yn="$(timed_yes_no "Create snapshot-ready local-lvm from remaining free space?" "y")"
    if [[ "$create_lvm_yn" =~ ^[Nn] ]]; then
        CREATE_LOCAL_LVM="n"
        LOCAL_LVM_SIZE_GB="0"
    else
        CREATE_LOCAL_LVM="y"
        if [ "$LOCAL_LVM_DEFAULT_SIZE_GB" -le 0 ]; then
            msg_error "No pve VG space remains for local-lvm after root target growth and reserve. Reduce target root size or reserve, or choose not to create local-lvm."
        fi
        LOCAL_LVM_SIZE_GB="$(read_storage_gb_input "Allocate local-lvm size in GB [all available: ${LOCAL_LVM_DEFAULT_SIZE_GB}GB]" "$LOCAL_LVM_DEFAULT_SIZE_GB" "no")"
    fi

    validate_storage_builder_plan

    if [ "$CREATE_LOCAL_LVM" == "y" ]; then
        STORAGE_LAYOUT_MODE="build_local_lvm"
    elif [ "$ROOT_GROWTH_GB" -gt 0 ]; then
        STORAGE_LAYOUT_MODE="extend_root_only"
    else
        STORAGE_LAYOUT_MODE="skip_root_expansion"
    fi

    show_storage_plan
    return 0
}

function collect_user_options() {
    local cpu_yn=""
    local crowdsec_yn=""
    local public_web_yn=""
    local enroll_yn=""
    local harden_yn=""
    local engine_name=""

    section "POST-INSTALL OPTIONS"

    cpu_yn="$(timed_yes_no "Set CPU Governor to PERFORMANCE?" "n")"

    if [[ "$cpu_yn" =~ ^[Yy] ]]; then
        ENABLE_PERFORMANCE="y"
    else
        ENABLE_PERFORMANCE="n"
    fi

    crowdsec_yn="$(timed_yes_no "Install CrowdSec Security Suite?" "y")"

    if [[ "$crowdsec_yn" =~ ^[Nn] ]]; then
        ENABLE_CROWDSEC="n"
        CROWDSEC_CONSOLE_ENROLLMENT_REQUESTED="no"
        CROWDSEC_CONSOLE_ENROLLMENT="no"
        CROWDSEC_CONSOLE_ENGINE_NAME="proxmox-${HOSTNAME_SHORT}"
    else
        ENABLE_CROWDSEC="y"
        CROWDSEC_CONSOLE_ENGINE_NAME="proxmox-${HOSTNAME_SHORT}"
        enroll_yn="$(timed_yes_no "Enroll Proxmox CrowdSec in CrowdSec Console?" "n")"
        if [[ "$enroll_yn" =~ ^[Yy] ]]; then
            CROWDSEC_CONSOLE_ENROLLMENT_REQUESTED="yes"
            CROWDSEC_CONSOLE_ENROLLMENT="requested"
            engine_name="$(read_text_from_tty "CrowdSec Console engine name" "$CROWDSEC_CONSOLE_ENGINE_NAME")"
            CROWDSEC_CONSOLE_ENGINE_NAME="${engine_name:-$CROWDSEC_CONSOLE_ENGINE_NAME}"
            msg_ok "CrowdSec Console engine name set: ${CROWDSEC_CONSOLE_ENGINE_NAME}"
            CROWDSEC_CONSOLE_ENROLLMENT_KEY="$(read_secret_from_tty "Paste CrowdSec Console enrollment key")"
            if [ -z "$CROWDSEC_CONSOLE_ENROLLMENT_KEY" ]; then
                CROWDSEC_CONSOLE_ENROLLMENT_REQUESTED="no"
                CROWDSEC_CONSOLE_ENROLLMENT="error"
                msg_warn "CrowdSec Console enrollment key was empty; enrollment will be skipped"
            else
                msg_ok "CrowdSec Console enrollment key captured"
            fi
        else
            CROWDSEC_CONSOLE_ENROLLMENT_REQUESTED="no"
            CROWDSEC_CONSOLE_ENROLLMENT="no"
        fi
    fi

    echo ""
    echo -e "${BL}SSH KEY CHECK${CL}"
    detect_root_ssh_key_state
    print_root_ssh_key_report
    if [ "${SSH_ROOT_KEY_COUNT:-0}" -gt 0 ]; then
        harden_yn="$(timed_yes_no "Enable SSH key-only root login hardening?" "y")"
        if [[ "$harden_yn" =~ ^[Nn] ]]; then
            SSH_KEY_ONLY_HARDENING_REQUESTED="no"
            SSH_HARDENING_APPLIED="audit-only"
        else
            SSH_KEY_ONLY_HARDENING_REQUESTED="yes"
            SSH_HARDENING_APPLIED="key-only-root"
        fi
    else
        SSH_KEY_ONLY_HARDENING_REQUESTED="no"
        SSH_HARDENING_APPLIED="audit-only"
        msg_warn "SSH key-only hardening skipped to avoid lockout"
    fi

    echo ""
    echo -e "${BL}PROXMOX HOST WEB PORTS${CL}"
    echo -e "${YW}Traefik normally handles public HTTP/HTTPS from inside the Ubuntu VM.${CL}"
    echo -e "${YW}For this setup, router port-forwarding should usually point to the VM, not the Proxmox host.${CL}"
    public_web_yn="$(timed_yes_no "Expose public HTTP/HTTPS 80/443 on Proxmox host firewall:" "n")"

    if [[ "$public_web_yn" =~ ^[Yy] ]]; then
        ALLOW_PUBLIC_WEB="y"
    else
        ALLOW_PUBLIC_WEB="n"
    fi
}

# --- 36. FINAL START PROMPT ---
# Starts post-install only after detection and user choices are collected.
function final_start_prompt() {
    local start_yn=""

    section "READY TO APPLY"

    echo -e "SYSTEM TYPE: ${GN}${SYSTEM_TYPE}${CL}"
    echo -e "ROOT FS: ${GN}${ROOT_FS_TYPE:-unknown}${CL}"
    echo -e "STORAGE: ${GN}${STORAGE_SUMMARY:-unknown}${CL}"
    echo ""
    echo -e "${BL}Storage:${CL}"
    case "${STORAGE_LAYOUT_MODE:-unselected}" in
        preserve_local_lvm)
            echo -e "  storage mode: ${GN}preserve_local_lvm${CL}"
            echo -e "  local-lvm detected: ${GN}yes${CL}"
            echo -e "  root/local expansion: ${GN}skipped${CL}"
            echo -e "  local-lvm creation: ${GN}skipped${CL}"
            ;;
        build_local_lvm)
            echo -e "  current root/local: ${GN}${CURRENT_ROOT_SIZE_GB}GB${CL}"
            echo -e "  target local visible size: ${GN}${TARGET_ROOT_SIZE_GB}GB${CL}"
            echo -e "  root LV allocation target: ${GN}${ROOT_LV_ALLOCATION_GB}GB${CL}"
            echo -e "  root growth needed: ${GN}${ROOT_GROWTH_GB}GB${CL}"
            echo -e "  current pve free: ${GN}${CURRENT_PVE_FREE_GB}GB${CL}"
            echo -e "  reserve free VG space: ${GN}${PVE_FREE_RESERVE_GB}GB${CL}"
            echo -e "  create local-lvm: ${GN}yes${CL}"
            echo -e "  local-lvm size: ${GN}${LOCAL_LVM_SIZE_GB}GB${CL}"
            echo -e "  storage mode: ${GN}build_local_lvm${CL}"
            ;;
        extend_root_only)
            echo -e "  storage mode: ${GN}extend_root_only${CL}"
            echo -e "  current root/local: ${GN}${CURRENT_ROOT_SIZE_GB}GB${CL}"
            echo -e "  target local visible size: ${GN}${TARGET_ROOT_SIZE_GB}GB${CL}"
            echo -e "  root LV allocation target: ${GN}${ROOT_LV_ALLOCATION_GB}GB${CL}"
            echo -e "  root growth needed: ${GN}${ROOT_GROWTH_GB}GB${CL}"
            echo -e "  create local-lvm: ${GN}no${CL}"
            ;;
        skip_root_expansion)
            echo -e "  storage mode: ${GN}skip_root_expansion${CL}"
            echo -e "  root/local expansion: ${GN}skipped${CL}"
            echo -e "  local-lvm creation: ${GN}skipped${CL}"
            ;;
        *)
            echo -e "  storage mode: ${GN}${STORAGE_LAYOUT_MODE:-unselected}${CL}"
            ;;
    esac
    echo ""
    echo -e "DEFAULT IFACE: ${GN}${DEFAULT_IFACE:-unknown}${CL}"
    echo -e "LAN CIDR ALLOWED FOR SSH/WEBUI: ${GN}${LAN_CIDR:-not-detected}${CL}"
    echo -e "GPU PASSTHROUGH: ${GN}$(yes_no_label "$ENABLE_PASSTHROUGH")${CL}"
    echo -e "CPU PERFORMANCE: ${GN}$(yes_no_label "$ENABLE_PERFORMANCE")${CL}"
    echo -e "PUBLIC HOST 80/443: ${GN}$(yes_no_label "$ALLOW_PUBLIC_WEB")${CL}"
    echo ""
    echo -e "${BL}SSH:${CL}"
    echo -e "  root keys detected: ${GN}$([ "${SSH_ROOT_KEY_COUNT:-0}" -gt 0 ] && echo yes || echo no), ${SSH_ROOT_KEY_COUNT:-0} key line(s)${CL}"
    echo -e "  hardening: ${GN}${SSH_HARDENING_APPLIED:-audit-only}${CL}"
    echo ""
    echo -e "${BL}CrowdSec:${CL}"
    echo -e "  install: ${GN}$(yes_no_label "$ENABLE_CROWDSEC")${CL}"
    echo -e "  firewall bouncer: ${GN}$(yes_no_label "$ENABLE_CROWDSEC")${CL}"
    echo -e "  console enrollment: ${GN}$(yes_no_label "${CROWDSEC_CONSOLE_ENROLLMENT_REQUESTED:-no}")${CL}"
    echo -e "  console engine name: ${GN}${CROWDSEC_CONSOLE_ENGINE_NAME:-proxmox-${HOSTNAME_SHORT}}${CL}"
    echo ""

    start_yn="$(timed_yes_no "Start the PVE9 Post Install Script?" "y")"

    if [[ "$start_yn" =~ ^[Nn] ]]; then
        exit 0
    fi

    clear
    header_info
    show_script_version

    return 0
}

# =========================================================
#  APPLY FUNCTIONS
# =========================================================

# --- 37. STORAGE LAYOUT APPLY ---
# Applies the selected storage plan without destructive local-lvm removal.
# Root/local is only extended to an explicit target size; +100%FREE is never used.
function resize_root_filesystem() {
    ROOT_FS_TYPE="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"

    case "$ROOT_FS_TYPE" in
        ext2|ext3|ext4)
            msg_info "Resizing root ext filesystem"
            run_cmd "resizing ext root filesystem" resize2fs /dev/mapper/pve-root
            msg_ok "Root filesystem resized"
            ;;
        xfs)
            if command -v xfs_growfs >/dev/null 2>&1; then
                msg_info "Resizing root XFS filesystem"
                run_cmd "resizing XFS root filesystem" xfs_growfs /
                msg_ok "Root XFS filesystem resized"
            else
                msg_warn "Root filesystem is XFS but xfs_growfs is unavailable; filesystem resize skipped"
            fi
            ;;
        *)
            msg_warn "Unknown root filesystem type (${ROOT_FS_TYPE:-unknown}); filesystem resize skipped"
            ;;
    esac
}

function apply_root_target_growth() {
    if [ "${ROOT_GROWTH_GB:-0}" -le 0 ]; then
        msg_ok "Root/local already at or above target size"
        return 0
    fi

    msg_info "Extending root LV allocation to ${ROOT_LV_ALLOCATION_GB}GB decimal for ${TARGET_ROOT_SIZE_GB}GB visible target"
    run_cmd "extending root LV allocation to ${ROOT_LV_ALLOCATION_GB}GB decimal" lvextend -L "${ROOT_LV_ALLOCATION_MIB}M" /dev/pve/root
    msg_ok "Root/local extended to target visible size"

    resize_root_filesystem
}

function create_local_lvm_thinpool() {
    if storage_id_in_pvesm_status "local-lvm" || storage_cfg_has_local_lvm || pve_data_lv_exists; then
        msg_error "local-lvm or /dev/pve/data already exists. Refusing to create or reuse storage automatically."
    fi

    msg_info "Creating local-lvm thinpool (${LOCAL_LVM_SIZE_GB}GB decimal)"
    run_cmd "creating local-lvm thinpool" lvcreate --type thin-pool -L "${LOCAL_LVM_SIZE_MIB}M" -n data pve
    msg_ok "local-lvm thinpool created"

    msg_info "Registering local-lvm in Proxmox"
    run_cmd "registering local-lvm storage" pvesm add lvmthin local-lvm --vgname pve --thinpool data --content images,rootdir
    msg_ok "local-lvm registered in Proxmox"
}

function apply_storage_merge() {
    section "STORAGE LAYOUT APPLY"

    case "${STORAGE_LAYOUT_MODE:-unselected}" in
        preserve_local_lvm)
            msg_ok "STORAGE LAYOUT MODE: PRESERVE INSTALLER LOCAL-LVM"
            echo -e "${YW}local-lvm remains available as snapshot-capable VM storage.${CL}"
            echo -e "${YW}Root/local expansion skipped to preserve Proxmox installer disk layout.${CL}"
            return 0
            ;;
        build_local_lvm)
            apply_root_target_growth
            create_local_lvm_thinpool
            msg_ok "Requested free VG reserve preserved"
            ;;
        extend_root_only)
            apply_root_target_growth
            msg_ok "local-lvm creation skipped by user choice"
            msg_ok "Requested free VG reserve preserved"
            ;;
        skip_root_expansion)
            msg_ok "Root/local expansion skipped"
            msg_ok "local-lvm creation skipped"
            return 0
            ;;
        merge_all)
            msg_error "Legacy destructive merge_all mode is disabled in normal Script 1 flow. Refusing storage changes."
            ;;
        *)
            msg_error "Storage layout mode was not selected. Refusing storage changes."
            ;;
    esac

    msg_info "Verifying local storage path"
    if df -h /var/lib/vz &>/dev/null; then
        msg_ok "LOCAL STORAGE PATH VERIFIED (/var/lib/vz)"
    else
        msg_warn "Local storage path /var/lib/vz could not be verified"
    fi
}

# --- 38. DNS REDUNDANCY ---
# Adds Cloudflare DNS redundancy before package updates.
# On standard Proxmox installs, /etc/resolv.conf is the persistent resolver file.
function apply_dns_redundancy() {
    section "DNS REDUNDANCY"

    msg_info "Backing up current DNS resolver config"
    cp -n /etc/resolv.conf /etc/resolv.conf.pve9-postinstall.bak 2>/dev/null || true
    msg_ok "DNS CONFIG BACKUP CREATED"

    if [ -L /etc/resolv.conf ]; then
        msg_warn "/etc/resolv.conf is a symlink; replacing it with static Proxmox resolver file"
        rm -f /etc/resolv.conf
    fi

    msg_info "Writing Cloudflare DNS resolver config"
    cat <<EOF > /etc/resolv.conf
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF

    msg_ok "DNS RESOLVERS CONFIGURED (DNS1 = 1.1.1.1, DNS2 = 1.0.0.1)"
}

# --- 39. REPOSITORIES & UPDATES ---
# Removes enterprise repositories, enables no-subscription repo and updates packages with hidden output.
function apply_repositories_and_updates() {
    section "REPOSITORIES & UPDATES"

    msg_info "Removing enterprise repository files"
    rm -f /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/ceph.sources
    msg_ok "ENTERPRISE / CEPH ENTERPRISE REPOSITORY FILES REMOVED"

    msg_info "Writing Proxmox no-subscription repository"
    cat <<EOF > /etc/apt/sources.list.d/proxmox.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    msg_ok "PROXMOX NO-SUBSCRIPTION REPOSITORY CONFIGURED"

    msg_info "Updating APT package lists"
    run_cmd "updating APT package lists" env DEBIAN_FRONTEND=noninteractive apt-get update
    msg_ok "APT PACKAGE LISTS UPDATED"

    msg_info "Upgrading system packages"
    run_cmd "upgrading system packages" env DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade
    msg_ok "SYSTEM PACKAGES UPGRADED"

    msg_info "Cleaning unused packages"
    run_optional env DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
    msg_ok "UNUSED PACKAGES REMOVED"

    msg_ok "SYSTEM UPDATED & CLEANED"
}

# --- 40. UI NAG REMOVAL ---
# Installs a persistent helper and dpkg hook to remove the Proxmox no-subscription popup after toolkit updates.
function apply_no_nag_patch() {
    section "WEBUI NAG PATCH"

    msg_info "Writing no-nag patch helper"
    cat <<'EOF' > /usr/local/sbin/pve-no-nag-patch.sh
#!/usr/bin/env bash
set -euo pipefail

FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
[ -f "$FILE" ] || exit 0

cp -n "$FILE" "${FILE}.orig" 2>/dev/null || true

if grep -q "res.data.status.toLowerCase() !== 'active'" "$FILE"; then
    sed -i "s/if (res === null || res === undefined || !res || res.data.status.toLowerCase() !== 'active') {/if (false) {/" "$FILE"
fi

if ! grep -q "if (false)\|NoMoreNagging" "$FILE"; then
    sed -i "/res.data.status/{s/!//;s/active/NoMoreNagging/g;s/Active/NoMoreNagging/g}" "$FILE" || true
fi
EOF

    chmod +x /usr/local/sbin/pve-no-nag-patch.sh
    msg_ok "NO-NAG PATCH HELPER INSTALLED"

    msg_info "Writing no-nag dpkg post-invoke hook"
    cat <<'EOF' > /etc/apt/apt.conf.d/no-nag-script
DPkg::Post-Invoke { "/usr/local/sbin/pve-no-nag-patch.sh && systemctl restart pveproxy >/dev/null 2>&1 || true"; };
EOF
    msg_ok "NO-NAG DPKG POST-INVOKE HOOK INSTALLED"

    msg_info "Reinstalling Proxmox widget toolkit"
    run_cmd "reinstalling proxmox-widget-toolkit" env DEBIAN_FRONTEND=noninteractive apt-get --reinstall install -y proxmox-widget-toolkit
    msg_ok "PROXMOX WIDGET TOOLKIT REINSTALLED"

    msg_info "Applying no-subscription nag patch"
    run_optional /usr/local/sbin/pve-no-nag-patch.sh
    msg_ok "NO-SUBSCRIPTION NAG PATCH APPLIED"

    msg_info "Restarting pveproxy"
    run_optional systemctl restart pveproxy
    msg_ok "PVEPROXY RESTARTED"

    msg_ok "WEBUI NAG REMOVED"
}

# --- 41. POWER & CHASSIS OPTIMIZATION ---
# Masks sleep states and ignores laptop lid close on laptop hardware.
function apply_power_settings() {
    section "POWER & CHASSIS OPTIMIZATION"

    msg_info "Masking sleep, suspend, hibernate and hybrid-sleep targets"
    run_optional systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
    msg_ok "SLEEP / SUSPEND / HIBERNATE TARGETS MASKED"

    if [ "$SYSTEM_TYPE" == "Laptop" ]; then
        msg_info "Setting laptop lid close behaviour to ignore"
        set_or_append_equals_config /etc/systemd/logind.conf "HandleLidSwitch" "ignore"
        set_or_append_equals_config /etc/systemd/logind.conf "HandleLidSwitchDocked" "ignore"
        set_or_append_equals_config /etc/systemd/logind.conf "LidSwitchIgnoreInhibited" "no"
        run_optional systemctl restart systemd-logind
        msg_ok "LAPTOP LID SETTINGS CONFIGURED"
    else
        msg_ok "LAPTOP LID SETTINGS NOT REQUIRED"
    fi

    msg_ok "POWER SETTINGS OPTIMIZED"
}

# --- 42. GRUB & IOMMU ---
# Adds IOMMU, passthrough mode and console blanking without removing existing kernel args.
function apply_grub_iommu() {
    section "GRUB & IOMMU"

    msg_info "Configuring CPU IOMMU flag"
    append_grub_arg "$IOMMU_FLAG"
    msg_ok "CPU IOMMU FLAG CONFIGURED (${IOMMU_FLAG})"

    msg_info "Configuring IOMMU passthrough mode"
    append_grub_arg "iommu=pt"
    msg_ok "IOMMU PASSTHROUGH MODE CONFIGURED"

    msg_info "Configuring console blanking"
    append_grub_arg "consoleblank=60"
    msg_ok "CONSOLE BLANKING CONFIGURED"

    msg_info "Updating GRUB configuration"
    run_cmd "updating GRUB configuration" update-grub
    msg_ok "GRUB CONFIG UPDATED"

    msg_ok "GRUB UPDATED"
}

# --- 43. GPU ISOLATION (VFIO) ---
# Loads VFIO modules and binds only discrete GPU IDs to vfio-pci.
# Driver blacklisting is vendor-aware to avoid breaking AMD APUs when only NVIDIA passthrough is selected.
function apply_gpu_isolation() {
    local module=""
    local vendor=""

    section "GPU ISOLATION"

    if [ "$ENABLE_PASSTHROUGH" != "y" ]; then
        msg_ok "GPU PASSTHROUGH NOT SELECTED"
        return 0
    fi

    if [ -z "$DGPU_IDS" ]; then
        msg_warn "Passthrough selected but no safe discrete GPU IDs were found. Skipping VFIO."
        return 0
    fi

    msg_info "Adding VFIO modules to /etc/modules"
    for module in vfio vfio_iommu_type1 vfio_pci vfio_virqfd; do
        grep -qxF "$module" /etc/modules || echo "$module" >> /etc/modules
    done
    msg_ok "VFIO MODULES ADDED TO /ETC/MODULES"

    msg_info "Writing host GPU driver blacklist"
    : > /etc/modprobe.d/pve-blacklist.conf

    for vendor in $DGPU_VENDOR_IDS; do
        case "$vendor" in
            0x10de)
                cat <<EOF >> /etc/modprobe.d/pve-blacklist.conf
blacklist nvidia
blacklist nouveau
blacklist nvidiafb
blacklist nvidia-gpu
EOF
                ;;
            0x1002|0x1022)
                cat <<EOF >> /etc/modprobe.d/pve-blacklist.conf
blacklist radeon
blacklist amdgpu
EOF
                ;;
        esac
    done

    sort -u /etc/modprobe.d/pve-blacklist.conf -o /etc/modprobe.d/pve-blacklist.conf
    msg_ok "HOST GPU DRIVERS BLACKLISTED FOR SELECTED DGPU VENDOR"

    msg_info "Writing VFIO PCI device IDs"
    echo "options vfio-pci ids=$DGPU_IDS disable_vga=1" > /etc/modprobe.d/vfio.conf
    msg_ok "VFIO PCI DEVICE IDS CONFIGURED ($DGPU_IDS)"

    msg_info "Updating initramfs for VFIO"
    run_cmd "updating initramfs for VFIO" update-initramfs -u -k all
    msg_ok "INITRAMFS UPDATED FOR VFIO"

    msg_ok "GPU ISOLATED"
}


function resolve_authorized_keys_path() {
    local pattern="$1"

    case "$pattern" in
        /*) echo "$pattern" ;;
        *) echo "/root/${pattern}" ;;
    esac
}

function count_authorized_key_lines() {
    local file="$1"

    if [ -s "$file" ]; then
        grep -Ev '^[[:space:]]*(#|$)' "$file" 2>/dev/null | wc -l | xargs || echo "0"
    else
        echo "0"
    fi
}

function describe_authorized_keys_file() {
    local file="$1"
    local key_count="$2"
    local target=""
    local owner="unknown"
    local mode="unknown"

    if [ -L "$file" ]; then
        target="$(readlink -f "$file" 2>/dev/null || true)"
    else
        target="$file"
    fi

    if [ -n "$target" ] && [ -e "$target" ]; then
        owner="$(stat -Lc '%U:%G' "$target" 2>/dev/null || echo unknown)"
        mode="$(stat -Lc '%a' "$target" 2>/dev/null || echo unknown)"

        if [ "$file" != "$target" ]; then
            echo -e "  ${GN}${file} -> ${target}${CL}"
            echo -e "  ${GN}target: present, ${owner}, mode ${mode}, ${key_count} key line(s)${CL}"
        else
            echo -e "  ${GN}${file}: present, ${owner}, mode ${mode}, ${key_count} key line(s)${CL}"
        fi
    else
        echo -e "  ${YW}${file}: missing/empty${CL}"
    fi
}

# --- 44. SSH SECURITY ---
# Detects root SSH keys during preflight and applies key-only hardening only when safe.
function detect_root_ssh_key_state() {
    local effective_config=""
    local effective_authorized_keys=""
    local effective_permit_root=""
    local effective_password_auth=""
    local effective_pubkey_auth=""
    local effective_kbd_auth=""
    local key_pattern=""
    local key_file=""
    local key_count="0"
    local total_key_count="0"
    local first_key_file=""
    local primary_key_file="/root/.ssh/authorized_keys"
    local primary_key_count="0"

    effective_config="$(sshd -T -C user=root,host=localhost,addr=127.0.0.1 2>/dev/null || true)"
    effective_authorized_keys="$(awk '$1=="authorizedkeysfile" {for (i=2; i<=NF; i++) printf "%s ", $i}' <<< "$effective_config" | xargs 2>/dev/null || true)"
    effective_permit_root="$(awk '$1=="permitrootlogin" {print $2; exit}' <<< "$effective_config")"
    effective_password_auth="$(awk '$1=="passwordauthentication" {print $2; exit}' <<< "$effective_config")"
    effective_pubkey_auth="$(awk '$1=="pubkeyauthentication" {print $2; exit}' <<< "$effective_config")"
    effective_kbd_auth="$(awk '$1=="kbdinteractiveauthentication" {print $2; exit}' <<< "$effective_config")"

    SSH_EFFECTIVE_AUTHORIZED_KEYS="${effective_authorized_keys:-.ssh/authorized_keys .ssh/authorized_keys2}"
    SSH_EFFECTIVE_PERMIT_ROOT="${effective_permit_root:-unknown}"
    SSH_EFFECTIVE_PASSWORD_AUTH="${effective_password_auth:-unknown}"
    SSH_EFFECTIVE_PUBKEY_AUTH="${effective_pubkey_auth:-unknown}"
    SSH_EFFECTIVE_KBD_AUTH="${effective_kbd_auth:-unknown}"

    SSH_ROOT_KEY_FILE="not-detected"
    SSH_ROOT_KEY_COUNT="0"
    SSH_ROOT_KEY_TARGET="not-detected"
    SSH_ROOT_KEY_OWNER="unknown"
    SSH_ROOT_KEY_MODE="unknown"

    primary_key_count="$(count_authorized_key_lines "$primary_key_file")"
    if [ "$primary_key_count" -gt 0 ]; then
        total_key_count="$primary_key_count"
        first_key_file="$primary_key_file"
    else
        for key_pattern in $SSH_EFFECTIVE_AUTHORIZED_KEYS; do
            key_file="$(resolve_authorized_keys_path "$key_pattern")"
            key_count="$(count_authorized_key_lines "$key_file")"
            if [ "$key_count" -gt 0 ]; then
                total_key_count="$(( total_key_count + key_count ))"
                [ -z "$first_key_file" ] && first_key_file="$key_file"
            fi
        done
    fi

    SSH_ROOT_KEY_COUNT="$total_key_count"
    if [ "$total_key_count" -gt 0 ]; then
        SSH_ROOT_KEY_FILE="$first_key_file"
        SSH_ROOT_KEY_TARGET="$(readlink -f "$first_key_file" 2>/dev/null || echo "$first_key_file")"
        SSH_ROOT_KEY_OWNER="$(stat -Lc '%U:%G' "$SSH_ROOT_KEY_TARGET" 2>/dev/null || echo unknown)"
        SSH_ROOT_KEY_MODE="$(stat -Lc '%a' "$SSH_ROOT_KEY_TARGET" 2>/dev/null || echo unknown)"
    fi
}

function print_root_ssh_key_report() {
    if [ "${SSH_ROOT_KEY_COUNT:-0}" -gt 0 ]; then
        msg_ok "Root SSH keys detected: ${SSH_ROOT_KEY_COUNT} key line(s)"
        if [ "${SSH_ROOT_KEY_FILE:-not-detected}" != "not-detected" ] && [ "${SSH_ROOT_KEY_TARGET:-not-detected}" != "not-detected" ]; then
            if [ "$SSH_ROOT_KEY_FILE" != "$SSH_ROOT_KEY_TARGET" ]; then
                echo -e "  ${BL}${SSH_ROOT_KEY_FILE}${CL} -> ${GN}${SSH_ROOT_KEY_TARGET}${CL}"
            else
                echo -e "  ${BL}${SSH_ROOT_KEY_FILE}${CL}"
            fi
            echo -e "  ${BL}target:${CL} ${GN}${SSH_ROOT_KEY_OWNER:-unknown}, mode ${SSH_ROOT_KEY_MODE:-unknown}${CL}"
        fi
    else
        msg_warn "No root SSH authorized keys detected"
    fi
}

function reload_ssh_service() {
    systemctl reload ssh >/dev/null 2>&1 && return 0
    systemctl reload sshd >/dev/null 2>&1 && return 0
    systemctl restart ssh >/dev/null 2>&1 && return 0
    systemctl restart sshd >/dev/null 2>&1 && return 0
    return 1
}

function apply_ssh_key_only_hardening() {
    local dropin="/etc/ssh/sshd_config.d/99-circl8-hardening.conf"
    local backup=""
    local effective_config=""
    local effective_permit_root=""
    local effective_password_auth=""
    local effective_pubkey_auth=""
    local effective_kbd_auth=""

    if [ "${SSH_ROOT_KEY_COUNT:-0}" -le 0 ]; then
        SSH_HARDENING_APPLIED="audit-only"
        msg_warn "No root SSH authorized keys detected; SSH key-only hardening skipped to avoid lockout"
        return 0
    fi

    mkdir -p /root/.ssh /etc/ssh/sshd_config.d
    chmod 700 /root/.ssh 2>/dev/null || true
    if [ -n "${SSH_ROOT_KEY_TARGET:-}" ] && [ "${SSH_ROOT_KEY_TARGET}" != "not-detected" ] && [ -e "$SSH_ROOT_KEY_TARGET" ]; then
        chmod 600 "$SSH_ROOT_KEY_TARGET" 2>/dev/null || true
    fi

    if [ -f "$dropin" ]; then
        backup="${dropin}.bak.$(date +%s)"
        cp -p "$dropin" "$backup"
    fi

    msg_info "Writing SSH key-only hardening drop-in"
    cat <<'EOF' > "$dropin"
# Project circl8 SSH hardening
# Root login remains allowed with SSH keys only; password and keyboard-interactive auth are disabled.
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin prohibit-password
EOF
    msg_ok "SSH hardening drop-in written"

    msg_info "Validating SSH configuration"
    if ! sshd -t; then
        if [ -n "$backup" ] && [ -f "$backup" ]; then
            cp -p "$backup" "$dropin"
        else
            rm -f "$dropin"
        fi
        SSH_HARDENING_APPLIED="error"
        msg_warn "SSH hardening drop-in failed validation and was rolled back"
        return 0
    fi
    msg_ok "SSH config validated"

    msg_info "Reloading SSH service"
    if reload_ssh_service; then
        msg_ok "SSH reloaded"
    else
        SSH_HARDENING_APPLIED="warning - reload failed"
        msg_warn "SSH config is valid but service reload failed; review manually before closing this session"
        return 0
    fi

    effective_config="$(sshd -T -C user=root,host=localhost,addr=127.0.0.1 2>/dev/null || true)"
    effective_permit_root="$(awk '$1=="permitrootlogin" {print $2; exit}' <<< "$effective_config")"
    effective_password_auth="$(awk '$1=="passwordauthentication" {print $2; exit}' <<< "$effective_config")"
    effective_pubkey_auth="$(awk '$1=="pubkeyauthentication" {print $2; exit}' <<< "$effective_config")"
    effective_kbd_auth="$(awk '$1=="kbdinteractiveauthentication" {print $2; exit}' <<< "$effective_config")"

    SSH_EFFECTIVE_PERMIT_ROOT="${effective_permit_root:-unknown}"
    SSH_EFFECTIVE_PASSWORD_AUTH="${effective_password_auth:-unknown}"
    SSH_EFFECTIVE_PUBKEY_AUTH="${effective_pubkey_auth:-unknown}"
    SSH_EFFECTIVE_KBD_AUTH="${effective_kbd_auth:-unknown}"

    if [ "$SSH_EFFECTIVE_PASSWORD_AUTH" == "no" ] \
        && [ "$SSH_EFFECTIVE_PUBKEY_AUTH" == "yes" ] \
        && [ "$SSH_EFFECTIVE_KBD_AUTH" == "no" ] \
        && [[ "$SSH_EFFECTIVE_PERMIT_ROOT" =~ ^(prohibit-password|without-password)$ ]]; then
        SSH_HARDENING_APPLIED="key-only-root"
        msg_ok "SSH key-only root login enabled"
    else
        SSH_HARDENING_APPLIED="warning - effective config mismatch"
        msg_warn "SSH hardening applied but effective root SSH settings should be reviewed"
    fi
}

function apply_ssh_security() {
    section "SSH SECURITY"

    msg_info "Auditing SSH configuration"
    run_cmd "validating current sshd config" sshd -t
    detect_root_ssh_key_state
    print_root_ssh_key_report

    if [ "${SSH_ROOT_KEY_COUNT:-0}" -gt 0 ]; then
        msg_ok "ROOT SSH KEYS DETECTED (${SSH_ROOT_KEY_COUNT} key line(s))"
    else
        msg_warn "No root SSH authorized keys detected; SSH policy hardening remains audit-only to avoid lockout"
    fi

    if [ "${SSH_KEY_ONLY_HARDENING_REQUESTED:-no}" == "yes" ]; then
        apply_ssh_key_only_hardening
    else
        SSH_HARDENING_APPLIED="audit-only"
        msg_ok "SSH CONFIG VALIDATED"
        echo -e "  ${DGN}SSH key-only hardening not selected during preflight${CL}"
        echo -e "  ${DGN}SSH LOCKOUT RISK AVOIDED${CL}"
    fi

    msg_ok "SSH SECURITY COMPLETE"
}

# --- 45. SYSCTL HARDENING & NETWORK TUNING ---
# Adds kernel hardening and high-traffic tuning for reverse proxy / VM workloads.
function apply_sysctl_tuning() {
    section "SYSCTL HARDENING & NETWORK TUNING"

    msg_info "Writing sysctl hardening and network tuning file"
    cat <<EOF > /etc/sysctl.d/99-pve9-hardening-network.conf
# PVE9 security hardening
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1

# High traffic reverse proxy / upload-download tuning
fs.file-max = 2097152
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 250000
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 5
net.netfilter.nf_conntrack_max = 1048576
EOF
    msg_ok "SYSCTL HARDENING / NETWORK TUNING FILE WRITTEN"

    msg_info "Applying sysctl settings"
    run_optional sysctl --system
    msg_ok "SYSCTL SETTINGS APPLIED"

    msg_ok "SYSCTL HARDENING APPLIED"
}

# --- 46. REALTEK NIC OPTIMIZATION ---
# Detects Realtek NICs and disables problematic offloads persistently.
function apply_realtek_optimization() {
    section "REALTEK NIC OPTIMIZATION"

    msg_info "Installing or verifying ethtool"
    run_optional env DEBIAN_FRONTEND=noninteractive apt-get install -y ethtool
    msg_ok "ETHTOOL INSTALLED / VERIFIED"

    msg_info "Detecting Realtek network interface"
    REALTEK_IFACE="$(detect_realtek_iface || true)"

    if [ -n "$REALTEK_IFACE" ]; then
        msg_info "Applying Realtek offload settings"
        run_optional ethtool -K "$REALTEK_IFACE" tso off gso off gro off
        msg_ok "REALTEK OFFLOAD SETTINGS APPLIED ($REALTEK_IFACE)"

        msg_info "Writing Realtek optimization systemd service"
        cat <<EOF > /etc/systemd/system/realtek-optimize.service
[Unit]
Description=Realtek NIC Optimization for Docker/Reverse Proxy Stability
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -K ${REALTEK_IFACE} tso off gso off gro off
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        msg_ok "REALTEK OPTIMIZATION SYSTEMD SERVICE WRITTEN"

        run_cmd "reloading systemd daemon" systemctl daemon-reload
        run_cmd "enabling Realtek optimization service" systemctl enable realtek-optimize.service

        REALTEK_OPTIMIZED="yes"

        msg_ok "REALTEK NIC OPTIMIZED ($REALTEK_IFACE)"
    else
        REALTEK_OPTIMIZED="no"
        msg_ok "NO REALTEK NIC OPTIMIZATION NEEDED"
    fi
}

# --- 47. PROXMOX FIREWALL BASELINE ---
# Enables Proxmox firewall with LAN-only SSH/WebUI access.
# Public 80/443 is optional and disabled by default for VM-reverse-proxy architecture.
function apply_proxmox_firewall() {
    local firewall_status=""

    section "PROXMOX FIREWALL BASELINE"

    msg_info "Creating or verifying Proxmox firewall directories"
    mkdir -p "/etc/pve/nodes/${HOSTNAME_SHORT}"
    mkdir -p /etc/pve/firewall
    msg_ok "PROXMOX FIREWALL DIRECTORIES VERIFIED"

    if [ -z "$LAN_CIDR" ]; then
        PVE_FIREWALL_APPLIED="warning - no LAN CIDR"
        msg_warn "Could not calculate LAN network CIDR. Proxmox firewall rules skipped to avoid invalid config or lockout."
        return 0
    fi

    msg_info "Enabling datacenter firewall"
    if grep -q "^firewall:" /etc/pve/datacenter.cfg 2>/dev/null; then
        sed -i 's/^firewall:.*/firewall: 1/' /etc/pve/datacenter.cfg
    else
        echo "firewall: 1" >> /etc/pve/datacenter.cfg
    fi
    msg_ok "DATACENTER FIREWALL ENABLED"

    msg_info "Writing cluster firewall enable file"
    cat <<EOF > /etc/pve/firewall/cluster.fw
[OPTIONS]
enable: 1
EOF
    msg_ok "CLUSTER FIREWALL ENABLE FILE WRITTEN"

    msg_info "Writing node firewall rules"
    cat <<EOF > "/etc/pve/nodes/${HOSTNAME_SHORT}/host.fw"
[OPTIONS]
enable: 1

[RULES]
IN ACCEPT -source ${LAN_CIDR} -p tcp -dport 22 -log nolog
IN ACCEPT -source ${LAN_CIDR} -p tcp -dport 8006 -log nolog
IN ACCEPT -p icmp -log nolog
EOF

    if [ "$ALLOW_PUBLIC_WEB" == "y" ]; then
        cat <<EOF >> "/etc/pve/nodes/${HOSTNAME_SHORT}/host.fw"
IN ACCEPT -p tcp -dport 80 -log nolog
IN ACCEPT -p tcp -dport 443 -log nolog
EOF
        msg_ok "NODE FIREWALL RULES WRITTEN WITH PUBLIC 80/443"
    else
        msg_ok "NODE FIREWALL RULES WRITTEN WITHOUT PUBLIC 80/443"
    fi

    msg_info "Validating Proxmox firewall configuration"
    firewall_status="$(pve-firewall status 2>&1 || true)"
    if echo "$firewall_status" | grep -qiE "can't parse|errors in rule parameters|invalid IP address|syntax error"; then
        echo ""
        echo -e "${RD}Proxmox firewall validation reported parser errors:${CL}"
        echo "$firewall_status"
        PVE_FIREWALL_APPLIED="warning - parser error"
        msg_error "Proxmox firewall config validation failed. Refusing to enable invalid firewall rules."
    fi
    msg_ok "PROXMOX FIREWALL CONFIG VALIDATED"

    msg_info "Enabling and restarting pve-firewall"
    run_optional systemctl enable --now pve-firewall
    run_optional systemctl restart pve-firewall

    firewall_status="$(pve-firewall status 2>&1 || true)"
    if echo "$firewall_status" | grep -qiE "can't parse|errors in rule parameters|invalid IP address|syntax error"; then
        echo ""
        echo -e "${RD}Proxmox firewall status reported parser errors after restart:${CL}"
        echo "$firewall_status"
        PVE_FIREWALL_APPLIED="warning - parser error"
        msg_error "Proxmox firewall did not validate after restart."
    fi

    if echo "$firewall_status" | grep -q "Status: enabled/running"; then
        PVE_FIREWALL_APPLIED="enabled/running"
        msg_ok "PVE-FIREWALL STATUS ENABLED/RUNNING"
    else
        echo ""
        echo -e "${YW}Proxmox firewall status was not enabled/running:${CL}"
        echo "$firewall_status"
        PVE_FIREWALL_APPLIED="warning - not enabled/running"
        msg_warn "PVE-firewall is not enabled/running; review firewall status manually"
        return 0
    fi

    msg_ok "PROXMOX FIREWALL ENABLED"
}


function read_text_from_tty() {
    local prompt="$1"
    local default="${2:-}"
    local value=""

    if [ -r /dev/tty ] && [ -w /dev/tty ]; then
        printf '%b' "${YW}${prompt} [default: ${default}]: ${CL}" > /dev/tty
        IFS= read -r value < /dev/tty || true
        printf '\033[1A\r\033[K' > /dev/tty
    else
        IFS= read -r -p "${prompt} [default: ${default}]: " value || true
    fi

    printf '%s' "${value:-$default}"
}

function read_secret_from_tty() {
    local prompt="$1"
    local value=""

    if [ -r /dev/tty ] && [ -w /dev/tty ]; then
        printf '%b' "${YW}${prompt}: ${CL}" > /dev/tty
        IFS= read -r value < /dev/tty || true
        printf '\033[1A\r\033[K' > /dev/tty
    else
        IFS= read -r -p "${prompt}: " value || true
    fi

    printf '%s' "$value"
}

function enroll_crowdsec_console() {
    local err_file=""

    if [ "${CROWDSEC_CONSOLE_ENROLLMENT_REQUESTED:-no}" != "yes" ]; then
        CROWDSEC_CONSOLE_ENROLLMENT="no"
        msg_ok "CROWDSEC CONSOLE ENROLLMENT SKIPPED"
        return 0
    fi

    if ! command -v cscli >/dev/null 2>&1; then
        CROWDSEC_CONSOLE_ENROLLMENT="unavailable"
        msg_warn "cscli not found; CrowdSec Console enrollment skipped"
        CROWDSEC_CONSOLE_ENROLLMENT_KEY=""
        unset CROWDSEC_CONSOLE_ENROLLMENT_KEY || true
        return 0
    fi

    if [ -z "${CROWDSEC_CONSOLE_ENROLLMENT_KEY:-}" ]; then
        CROWDSEC_CONSOLE_ENROLLMENT="error"
        msg_warn "CrowdSec Console enrollment was requested but no enrollment key is available"
        unset CROWDSEC_CONSOLE_ENROLLMENT_KEY || true
        return 0
    fi

    CROWDSEC_CONSOLE_ENGINE_NAME="${CROWDSEC_CONSOLE_ENGINE_NAME:-proxmox-${HOSTNAME_SHORT}}"
    err_file="$(mktemp)"
    TEMP_FILES+=("$err_file")

    msg_info "Enrolling CrowdSec engine in Console as ${CROWDSEC_CONSOLE_ENGINE_NAME}"
    if cscli console enroll --name "$CROWDSEC_CONSOLE_ENGINE_NAME" "$CROWDSEC_CONSOLE_ENROLLMENT_KEY" > /dev/null 2> "$err_file"; then
        msg_ok "CROWDSEC CONSOLE ENROLLMENT REQUESTED"
        CROWDSEC_CONSOLE_ENROLLMENT="pending"
        run_optional cscli console enable --all
        if cscli console status > /dev/null 2>&1; then
            msg_ok "CROWDSEC CONSOLE STATUS CHECKED"
        else
            msg_warn "CrowdSec Console status is not confirmed yet; accept the engine in the CrowdSec Console"
        fi
        echo -e "${YW}Validate/accept this engine in https://app.crowdsec.net${CL}"
    else
        msg_warn "CrowdSec Console enrollment failed; review cscli console status manually"
        CROWDSEC_CONSOLE_ENROLLMENT="error"
    fi

    CROWDSEC_CONSOLE_ENROLLMENT_KEY=""
    unset CROWDSEC_CONSOLE_ENROLLMENT_KEY || true
    rm -f "$err_file"
}

# --- 48. CROWDSEC & AUTO UPDATES ---
# Installs CrowdSec, firewall bouncer, Proxmox/Linux collections and unattended upgrades.
function apply_crowdsec_security() {
    section "CROWDSEC & AUTO UPDATES"

    if [ "$ENABLE_CROWDSEC" != "y" ]; then
        msg_ok "CROWDSEC SECURITY SUITE NOT SELECTED"
        return 0
    fi

    msg_info "Installing CrowdSec dependency packages"
    run_optional env DEBIAN_FRONTEND=noninteractive apt-get install -y curl gnupg ca-certificates
    msg_ok "SECURITY INSTALL DEPENDENCIES INSTALLED"

    if command -v curl >/dev/null 2>&1; then
        msg_info "Running CrowdSec repository installer"
        curl -fsSL https://install.crowdsec.net | sh &>/dev/null || true
        msg_ok "CROWDSEC REPOSITORY INSTALLER EXECUTED"
    fi

    msg_info "Updating APT package lists for CrowdSec"
    run_optional env DEBIAN_FRONTEND=noninteractive apt-get update
    msg_ok "APT PACKAGE LISTS UPDATED FOR CROWDSEC"

    msg_info "Installing CrowdSec and unattended-upgrades"
    run_optional env DEBIAN_FRONTEND=noninteractive apt-get install -y crowdsec unattended-upgrades
    msg_ok "CROWDSEC AND UNATTENDED-UPGRADES INSTALLED"

    msg_info "Checking available CrowdSec firewall bouncer package"
    if apt-cache show crowdsec-firewall-bouncer-nftables &>/dev/null; then
        run_optional env DEBIAN_FRONTEND=noninteractive apt-get install -y crowdsec-firewall-bouncer-nftables
        CROWDSEC_BOUNCER_PACKAGE="crowdsec-firewall-bouncer-nftables"
        msg_ok "CROWDSEC NFTABLES FIREWALL BOUNCER INSTALLED"
    elif apt-cache show crowdsec-firewall-bouncer-iptables &>/dev/null; then
        run_optional env DEBIAN_FRONTEND=noninteractive apt-get install -y crowdsec-firewall-bouncer-iptables
        CROWDSEC_BOUNCER_PACKAGE="crowdsec-firewall-bouncer-iptables"
        msg_ok "CROWDSEC IPTABLES FIREWALL BOUNCER INSTALLED"
    else
        CROWDSEC_BOUNCER_PACKAGE="none"
        msg_warn "CrowdSec firewall bouncer package not found"
    fi

    if command -v cscli >/dev/null 2>&1; then
        msg_info "Installing CrowdSec collections"
        run_optional cscli collections install crowdsecurity/linux
        run_optional cscli collections install crowdsecurity/sshd
        run_optional cscli collections install crowdsecurity/proxmox
        run_optional cscli collections install crowdsecurity/http-cve
        msg_ok "CROWDSEC COLLECTIONS INSTALLED"
    else
        msg_warn "cscli not found after install; CrowdSec collection install skipped"
    fi

    msg_info "Enabling CrowdSec service"
    run_optional systemctl enable --now crowdsec
    run_optional systemctl restart crowdsec
    msg_ok "CROWDSEC SERVICE ENABLED"

    msg_info "Checking CrowdSec firewall bouncer service"
    if systemctl list-unit-files 'crowdsec-firewall-bouncer*' --no-pager --no-legend 2>/dev/null | grep -q "crowdsec-firewall-bouncer"; then
        run_optional systemctl enable --now crowdsec-firewall-bouncer
        run_optional systemctl restart crowdsec-firewall-bouncer
        msg_ok "CROWDSEC FIREWALL BOUNCER ENABLED"
    else
        msg_warn "CrowdSec firewall bouncer service was not found after install"
    fi

    enroll_crowdsec_console

    msg_info "Writing unattended-upgrades config"
    cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
    msg_ok "UNATTENDED UPGRADES CONFIGURED"

    msg_ok "SECURITY INSTALLED"
}

# --- 49. PROXMOX FIREWALL SERVICE REINFORCEMENT ---
# Ensures the firewall service remains enabled now and at boot.
function reinforce_pve_firewall_service() {
    local firewall_status=""

    section "PROXMOX FIREWALL SERVICE REINFORCEMENT"

    msg_info "Restarting Proxmox firewall service"
    run_optional systemctl enable --now pve-firewall
    run_optional systemctl restart pve-firewall

    firewall_status="$(pve-firewall status 2>&1 || true)"
    if echo "$firewall_status" | grep -q "Status: enabled/running"; then
        PVE_FIREWALL_APPLIED="enabled/running"
        msg_ok "PROXMOX FIREWALL SERVICE ENABLED/RUNNING"
    else
        PVE_FIREWALL_APPLIED="warning - not enabled/running"
        msg_warn "Proxmox firewall service is not enabled/running after reinforcement"
    fi
}

# --- 50. PERFORMANCE & TRIM ---
# Optionally enables performance CPU governor and enables fstrim.timer when SSD is detected.
function apply_performance_and_trim() {
    section "PERFORMANCE & TRIM"

    if [ "$ENABLE_PERFORMANCE" == "y" ]; then
        msg_info "Installing cpufrequtils"
        run_optional env DEBIAN_FRONTEND=noninteractive apt-get install -y cpufrequtils
        msg_ok "CPUFREQUTILS INSTALLED"

        msg_info "Writing performance governor default"
        echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
        msg_ok "CPU GOVERNOR DEFAULT SET TO PERFORMANCE"

        if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
            msg_info "Applying live CPU performance governor"
            for r in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo "performance" > "$r" 2>/dev/null || true
            done
            msg_ok "LIVE CPU GOVERNOR SET TO PERFORMANCE"
        else
            msg_warn "CPUFREQ sysfs path not found; live governor change skipped"
        fi

        run_optional systemctl restart cpufrequtils
        msg_ok "CPU PERFORMANCE ACTIVE"
    else
        msg_ok "CPU PERFORMANCE GOVERNOR NOT SELECTED"
    fi

    if [ "$IS_SSD" == "yes" ]; then
        msg_info "Enabling and starting fstrim timer"
        run_cmd "enabling fstrim timer" systemctl enable --now fstrim.timer
        msg_ok "SSD TRIM ENABLED"
    else
        msg_ok "SSD TRIM NOT REQUIRED FOR DETECTED STORAGE"
    fi
}

# --- 51. NUMLOCK BOOT SERVICE ---
# Enables NumLock on Linux consoles at boot when console tools support it.
function apply_numlock_service() {
    section "NUMLOCK BOOT SERVICE"

    msg_info "Installing or verifying kbd package"
    run_optional env DEBIAN_FRONTEND=noninteractive apt-get install -y kbd
    msg_ok "KBD PACKAGE INSTALLED / VERIFIED"

    msg_info "Writing NumLock helper script"
    cat <<'EOF' > /usr/local/sbin/pve-numlock-on.sh
#!/usr/bin/env bash
set +e

for tty in /dev/tty1 /dev/tty2 /dev/tty3 /dev/tty4 /dev/tty5 /dev/tty6; do
    [ -w "$tty" ] && /usr/bin/setleds -D +num < "$tty" >/dev/null 2>&1 || true
done

exit 0
EOF

    chmod +x /usr/local/sbin/pve-numlock-on.sh
    msg_ok "NUMLOCK HELPER SCRIPT INSTALLED"

    msg_info "Writing NumLock systemd service"
    cat <<EOF > /etc/systemd/system/pve-numlock.service
[Unit]
Description=Enable NumLock on Linux Consoles
After=getty.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/pve-numlock-on.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    msg_ok "NUMLOCK SYSTEMD SERVICE WRITTEN"

    run_cmd "reloading systemd daemon" systemctl daemon-reload
    run_cmd "enabling NumLock service" systemctl enable pve-numlock.service

    NUMLOCK_CONFIGURED="yes"

    msg_ok "NUMLOCK BOOT SERVICE CONFIGURED"
}

# --- 52. AUTO-VERIFY GHOST SCRIPT ---
# Creates one-time verifier that runs after reboot, writes a detailed log, self-deletes, and leaves a login display helper.
# The systemd service logs to journal only, not the physical Proxmox console, so the report is shown upon root SSH login instead.
function create_auto_verifier() {
    section "AUTO-VERIFY GHOST SCRIPT"

    msg_info "Writing auto-verify script"
    cat <<EOF > /root/pve_verify.sh
#!/usr/bin/env bash
set +e

VERIFY_LOG="$VERIFY_LOG"
: > "\$VERIFY_LOG"
exec > >(tee -a "\$VERIFY_LOG") 2>&1

GN="\033[32m"
RD="\033[31m"
YW="\033[33m"
BL="\033[36m"
CL="\033[0m"

INSTALL_SYSTEM_TYPE="$SYSTEM_TYPE"
INSTALL_IS_SSD="$IS_SSD"
INSTALL_IGPU_FOUND="$IGPU_FOUND"
INSTALL_DGPU_FOUND="$DGPU_FOUND"
INSTALL_DGPU_BDFS="$DGPU_BDFS"
INSTALL_DGPU_IDS="$DGPU_IDS"
INSTALL_ENABLE_PASSTHROUGH="$ENABLE_PASSTHROUGH"
INSTALL_ENABLE_PERFORMANCE="$ENABLE_PERFORMANCE"
INSTALL_ENABLE_CROWDSEC="$ENABLE_CROWDSEC"
INSTALL_ALLOW_PUBLIC_WEB="$ALLOW_PUBLIC_WEB"
INSTALL_SSH_HARDENING_APPLIED="$SSH_HARDENING_APPLIED"
INSTALL_PVE_FIREWALL_APPLIED="$PVE_FIREWALL_APPLIED"
INSTALL_IOMMU_FLAG="$IOMMU_FLAG"
INSTALL_CROWDSEC_BOUNCER_PACKAGE="$CROWDSEC_BOUNCER_PACKAGE"
INSTALL_CROWDSEC_CONSOLE_ENROLLMENT="$CROWDSEC_CONSOLE_ENROLLMENT"
INSTALL_CROWDSEC_CONSOLE_ENGINE_NAME="$CROWDSEC_CONSOLE_ENGINE_NAME"
INSTALL_REALTEK_IFACE="$REALTEK_IFACE"
INSTALL_REALTEK_OPTIMIZED="$REALTEK_OPTIMIZED"
INSTALL_NUMLOCK_CONFIGURED="$NUMLOCK_CONFIGURED"
INSTALL_STORAGE_LAYOUT_MODE="$STORAGE_LAYOUT_MODE"
INSTALL_CURRENT_ROOT_SIZE_GB="$CURRENT_ROOT_SIZE_GB"
INSTALL_TARGET_ROOT_SIZE_GB="$TARGET_ROOT_SIZE_GB"
INSTALL_ROOT_LV_ALLOCATION_GB="$ROOT_LV_ALLOCATION_GB"
INSTALL_ROOT_GROWTH_GB="$ROOT_GROWTH_GB"
INSTALL_CREATE_LOCAL_LVM="$CREATE_LOCAL_LVM"
INSTALL_LOCAL_LVM_SIZE_GB="$LOCAL_LVM_SIZE_GB"
INSTALL_DEFAULT_IFACE="$DEFAULT_IFACE"
INSTALL_LAN_CIDR="$LAN_CIDR"
INSTALL_SSH_ROOT_KEY_FILE="$SSH_ROOT_KEY_FILE"
INSTALL_SSH_ROOT_KEY_COUNT="$SSH_ROOT_KEY_COUNT"
INSTALL_SSH_ROOT_KEY_TARGET="$SSH_ROOT_KEY_TARGET"
INSTALL_SSH_ROOT_KEY_OWNER="$SSH_ROOT_KEY_OWNER"
INSTALL_SSH_ROOT_KEY_MODE="$SSH_ROOT_KEY_MODE"
INSTALL_SSH_EFFECTIVE_AUTHORIZED_KEYS="$SSH_EFFECTIVE_AUTHORIZED_KEYS"
INSTALL_SSH_EFFECTIVE_PERMIT_ROOT="$SSH_EFFECTIVE_PERMIT_ROOT"
INSTALL_SSH_EFFECTIVE_PASSWORD_AUTH="$SSH_EFFECTIVE_PASSWORD_AUTH"
INSTALL_SSH_EFFECTIVE_PUBKEY_AUTH="$SSH_EFFECTIVE_PUBKEY_AUTH"
INSTALL_SSH_EFFECTIVE_KBD_AUTH="$SSH_EFFECTIVE_KBD_AUTH"

PASS() { echo -e "\${GN}✓ PASS\${CL} - \$1"; }
FAIL() { echo -e "\${RD}✗ FAIL\${CL} - \$1"; }
WARN() { echo -e "\${YW}! WARN\${CL} - \$1"; }
INFO() { echo -e "\${BL}- INFO\${CL} - \$1"; }
YESNO() {
    case "\${1:-}" in
        y|Y|yes|YES|true|TRUE|1) echo "yes" ;;
        n|N|no|NO|false|FALSE|0|"") echo "no" ;;
        *) echo "\$1" ;;
    esac
}

echo ""
echo -e "\${BL}--- PVE9 POST-INSTALL VERIFICATION REPORT ---\${CL}"
echo "Date: \$(date)"
echo "Host: \$(hostname)"
echo ""

INFO "System type detected during install: \$INSTALL_SYSTEM_TYPE"
INFO "SSD detected during install: \$INSTALL_IS_SSD"
INFO "Integrated GPU detected during install: \$INSTALL_IGPU_FOUND"
INFO "Discrete GPU detected during install: \$INSTALL_DGPU_FOUND"
INFO "Discrete GPU passthrough selected: \$(YESNO "\$INSTALL_ENABLE_PASSTHROUGH")"
INFO "CPU performance selected: \$(YESNO "\$INSTALL_ENABLE_PERFORMANCE")"
INFO "SSH hardening applied during install: \$INSTALL_SSH_HARDENING_APPLIED"
INFO "CrowdSec selected during install: \$(YESNO "\$INSTALL_ENABLE_CROWDSEC")"
INFO "CrowdSec bouncer package: \$INSTALL_CROWDSEC_BOUNCER_PACKAGE"
INFO "CrowdSec Console enrollment: \${INSTALL_CROWDSEC_CONSOLE_ENROLLMENT:-no}"
INFO "CrowdSec Console engine name: \${INSTALL_CROWDSEC_CONSOLE_ENGINE_NAME:-not-set}"
INFO "Proxmox firewall applied during install: \$INSTALL_PVE_FIREWALL_APPLIED"
INFO "Public host 80/443 selected: \$(YESNO "\$INSTALL_ALLOW_PUBLIC_WEB")"
INFO "Realtek NIC optimized during install: \$(YESNO "\$INSTALL_REALTEK_OPTIMIZED")"
INFO "Realtek interface: \$INSTALL_REALTEK_IFACE"
INFO "NumLock service configured: \$(YESNO "\$INSTALL_NUMLOCK_CONFIGURED")"
INFO "Storage layout mode: \$INSTALL_STORAGE_LAYOUT_MODE"
INFO "Default network interface during install: \${INSTALL_DEFAULT_IFACE:-unknown}"
INFO "LAN CIDR allowed for SSH/WebUI during install: \${INSTALL_LAN_CIDR:-not-detected}"
INFO "Root SSH key file detected during install: \${INSTALL_SSH_ROOT_KEY_FILE:-not-detected}"
INFO "Root SSH key target during install: \${INSTALL_SSH_ROOT_KEY_TARGET:-not-detected}"
INFO "Effective AuthorizedKeysFile during install: \${INSTALL_SSH_EFFECTIVE_AUTHORIZED_KEYS:-unknown}"

echo ""

sleep 5

# Core Proxmox service checks.
if pveversion >/dev/null 2>&1; then PASS "Proxmox command tools available"; else FAIL "Proxmox command tools missing"; fi
if systemctl is-active --quiet pveproxy; then PASS "pveproxy active"; else FAIL "pveproxy inactive"; fi
if systemctl is-active --quiet pvedaemon; then PASS "pvedaemon active"; else FAIL "pvedaemon inactive"; fi
if systemctl is-active --quiet pvestatd; then PASS "pvestatd active"; else FAIL "pvestatd inactive"; fi
if systemctl is-active --quiet pve-cluster; then PASS "pve-cluster active"; else FAIL "pve-cluster inactive"; fi

# DNS checks.
if grep -q "nameserver 1.1.1.1" /etc/resolv.conf && grep -q "nameserver 1.0.0.1" /etc/resolv.conf; then
    PASS "DNS redundancy configured"
else
    WARN "DNS redundancy not detected"
fi

# Repository and package health checks.
if grep -q "pve-no-subscription" /etc/apt/sources.list.d/proxmox.sources 2>/dev/null; then PASS "No-subscription repository configured"; else FAIL "No-subscription repository missing"; fi
if [ ! -f /etc/apt/sources.list.d/pve-enterprise.sources ]; then PASS "Enterprise repository disabled"; else FAIL "Enterprise repository still present"; fi
if apt-get check >/dev/null 2>&1; then PASS "APT package database healthy"; else FAIL "APT package database has problems"; fi

# Storage layout checks.
case "\$INSTALL_STORAGE_LAYOUT_MODE" in
    preserve_local_lvm)
        if grep -q "local-lvm" /etc/pve/storage.cfg 2>/dev/null; then PASS "local-lvm preserved in Proxmox storage config"; else FAIL "local-lvm missing from Proxmox storage config"; fi
        if lvdisplay /dev/pve/data >/dev/null 2>&1; then PASS "/dev/pve/data preserved for local-lvm"; else FAIL "/dev/pve/data missing after preserve mode"; fi
        ;;
    build_local_lvm)
        if grep -q "local-lvm" /etc/pve/storage.cfg 2>/dev/null; then PASS "local-lvm present in Proxmox storage config"; else FAIL "local-lvm missing from Proxmox storage config"; fi
        if pvesm status 2>/dev/null | awk 'NR>1 && \$1 == "local-lvm" {found=1} END {exit found ? 0 : 1}'; then PASS "pvesm lists local-lvm"; else FAIL "pvesm does not list local-lvm"; fi
        if lvdisplay /dev/pve/data >/dev/null 2>&1; then PASS "/dev/pve/data exists for local-lvm"; else FAIL "/dev/pve/data missing after build mode"; fi
        if lvs --noheadings -o lv_attr pve/data 2>/dev/null | awk 'NF {exit substr(\$1,1,1)=="t" ? 0 : 1}'; then PASS "pve/data is a thinpool"; else WARN "pve/data thinpool attribute not confirmed"; fi
        INFO "Root visible target during install: \${INSTALL_TARGET_ROOT_SIZE_GB}GB; root LV allocation: \${INSTALL_ROOT_LV_ALLOCATION_GB}GB; local-lvm size: \${INSTALL_LOCAL_LVM_SIZE_GB}GB"
        ;;
    extend_root_only)
        INFO "Root/local extension selected without local-lvm creation"
        INFO "Root visible target during install: \${INSTALL_TARGET_ROOT_SIZE_GB}GB; root LV allocation: \${INSTALL_ROOT_LV_ALLOCATION_GB}GB; root growth requested: \${INSTALL_ROOT_GROWTH_GB}GB"
        ;;
    skip_root_expansion)
        INFO "Root/local expansion skipped; local-lvm creation skipped; storage state intentionally unchanged by Script 1"
        ;;
    *)
        WARN "Unknown storage layout mode: \$INSTALL_STORAGE_LAYOUT_MODE"
        ;;
esac
if df -h /var/lib/vz >/dev/null 2>&1; then PASS "local storage path /var/lib/vz is accessible"; else FAIL "local storage path /var/lib/vz is not accessible"; fi

# GRUB and IOMMU checks.
if grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | grep -qw "\$INSTALL_IOMMU_FLAG"; then PASS "GRUB contains \$INSTALL_IOMMU_FLAG"; else FAIL "GRUB missing \$INSTALL_IOMMU_FLAG"; fi
if grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | grep -qw "iommu=pt"; then PASS "GRUB contains iommu=pt"; else FAIL "GRUB missing iommu=pt"; fi
if grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | grep -qw "consoleblank=60"; then PASS "GRUB contains consoleblank=60"; else WARN "GRUB missing consoleblank=60"; fi
if grep -q "consoleblank=60" /proc/cmdline; then PASS "Screen blanking active in running kernel"; else WARN "Screen blanking not visible in running kernel"; fi
if dmesg | grep -Ei "IOMMU|DMAR|AMD-Vi" | grep -qi "enabled"; then PASS "IOMMU appears enabled after reboot"; else WARN "IOMMU not clearly detected in dmesg"; fi

# GPU passthrough checks.
if [ "\$INSTALL_DGPU_FOUND" == "yes" ]; then
    if [ "\$INSTALL_ENABLE_PASSTHROUGH" == "y" ]; then
        if find /sys/bus/pci/drivers/vfio-pci -maxdepth 1 -type l 2>/dev/null | grep -q .; then
            PASS "vfio-pci has bound PCI devices"
        else
            WARN "GPU passthrough was selected but vfio-pci binding was not clearly detected"
        fi

        if [ -f /etc/modprobe.d/vfio.conf ] && grep -q "\$INSTALL_DGPU_IDS" /etc/modprobe.d/vfio.conf 2>/dev/null; then
            PASS "vfio.conf contains selected discrete GPU IDs"
        else
            FAIL "vfio.conf missing selected discrete GPU IDs"
        fi
    else
        WARN "Discrete GPU present but passthrough was not selected"
    fi
else
    INFO "No discrete GPU detected during install, GPU passthrough check skipped"
fi

# SSD TRIM checks.
if [ "\$INSTALL_IS_SSD" == "yes" ]; then
    if systemctl is-enabled --quiet fstrim.timer && systemctl is-active --quiet fstrim.timer; then PASS "SSD TRIM timer enabled and active"; else FAIL "SSD TRIM timer not enabled/active"; fi
else
    INFO "No SSD detected during install, TRIM check skipped"
fi

# CPU governor checks.
if [ "\$INSTALL_ENABLE_PERFORMANCE" == "y" ]; then
    if grep -q "performance" /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null; then PASS "CPU governor is performance"; else FAIL "CPU governor is not performance"; fi
else
    INFO "CPU performance governor was not selected, check skipped"
fi

# SSH audit checks.
if [ "\$INSTALL_SSH_HARDENING_APPLIED" == "key-only-root" ]; then
    ROOT_SSHD_EFFECTIVE="\$(sshd -T -C user=root,host=localhost,addr=127.0.0.1 2>/dev/null || true)"
    ROOT_AUTH_KEYS="\$(echo "\$ROOT_SSHD_EFFECTIVE" | awk '\$1=="authorizedkeysfile" {for (i=2; i<=NF; i++) printf "%s ", \$i}')"

    if echo "\$ROOT_SSHD_EFFECTIVE" | grep -q "^passwordauthentication no"; then PASS "SSH password authentication disabled for root context"; else FAIL "SSH password authentication still enabled for root context"; fi
    if echo "\$ROOT_SSHD_EFFECTIVE" | grep -Eq "^permitrootlogin (without-password|prohibit-password)"; then PASS "Root SSH password login disabled while key login remains allowed"; else FAIL "Root SSH password login not hardened"; fi
    if echo "\$ROOT_SSHD_EFFECTIVE" | grep -q "^pubkeyauthentication yes"; then PASS "Root public-key authentication enabled"; else FAIL "Root public-key authentication not enabled"; fi
    if echo "\$ROOT_SSHD_EFFECTIVE" | grep -q "^kbdinteractiveauthentication no"; then PASS "Keyboard-interactive SSH authentication disabled"; else WARN "Keyboard-interactive SSH authentication not confirmed disabled"; fi
    if [ -n "\$ROOT_AUTH_KEYS" ]; then PASS "AuthorizedKeysFile effective path present: \$ROOT_AUTH_KEYS"; else FAIL "AuthorizedKeysFile effective path missing"; fi
elif [ "\$INSTALL_SSH_HARDENING_APPLIED" == "audit-only" ]; then
    INFO "SSH policy was left audit-only during Script 1"
    if [ "\${INSTALL_SSH_ROOT_KEY_COUNT:-0}" -gt 0 ] && [ -n "\$INSTALL_SSH_ROOT_KEY_FILE" ] && [ "\$INSTALL_SSH_ROOT_KEY_FILE" != "not-detected" ]; then
        PASS "Root SSH authorized keys detected during install: \${INSTALL_SSH_ROOT_KEY_COUNT} key line(s) in \$INSTALL_SSH_ROOT_KEY_FILE"
        INFO "Root SSH key target: \${INSTALL_SSH_ROOT_KEY_TARGET:-not-detected}; owner: \${INSTALL_SSH_ROOT_KEY_OWNER:-unknown}; mode: \${INSTALL_SSH_ROOT_KEY_MODE:-unknown}"
    else
        WARN "No root SSH authorized keys were detected during install; SSH policy remained audit-only"
    fi
else
    WARN "SSH hardening status unknown: \$INSTALL_SSH_HARDENING_APPLIED"
fi

# Realtek NIC optimization checks.
if [ "\$INSTALL_REALTEK_OPTIMIZED" == "yes" ]; then
    if systemctl is-enabled --quiet realtek-optimize.service; then PASS "Realtek optimization service enabled"; else WARN "Realtek optimization service not enabled"; fi
    if [ -n "\$INSTALL_REALTEK_IFACE" ] && [ -r "/sys/class/net/\$INSTALL_REALTEK_IFACE/statistics/rx_packets" ]; then PASS "Realtek interface still present"; else WARN "Realtek interface not found after reboot"; fi
else
    INFO "No Realtek optimization was applied"
fi

# Proxmox firewall checks.
FIREWALL_STATUS="\$(pve-firewall status 2>&1 || true)"
if echo "\$FIREWALL_STATUS" | grep -q "Status: enabled/running"; then PASS "Proxmox firewall status enabled/running"; else FAIL "Proxmox firewall status is not enabled/running: \$FIREWALL_STATUS"; fi
if systemctl is-active --quiet pve-firewall; then PASS "Proxmox firewall service active"; else FAIL "Proxmox firewall service inactive"; fi
if [ -f /etc/pve/firewall/cluster.fw ] && grep -q "enable: 1" /etc/pve/firewall/cluster.fw 2>/dev/null; then PASS "Cluster firewall enable file present"; else FAIL "Cluster firewall enable file missing"; fi
if grep -q "firewall: 1" /etc/pve/datacenter.cfg 2>/dev/null; then PASS "Datacenter firewall enabled"; else FAIL "Datacenter firewall not enabled"; fi
if [ -f "/etc/pve/nodes/\$(hostname -s)/host.fw" ]; then PASS "Node firewall file exists"; else WARN "Node firewall file missing"; fi

if [ "\$INSTALL_ALLOW_PUBLIC_WEB" == "y" ]; then
    if grep -q "dport 80" "/etc/pve/nodes/\$(hostname -s)/host.fw" 2>/dev/null && grep -q "dport 443" "/etc/pve/nodes/\$(hostname -s)/host.fw" 2>/dev/null; then
        PASS "Public 80/443 firewall rules present"
    else
        WARN "Public 80/443 was selected but rules were not detected"
    fi
else
    INFO "Public host 80/443 was not selected"
fi

# CrowdSec checks.
if [ "\$INSTALL_ENABLE_CROWDSEC" == "y" ]; then
    if systemctl is-active --quiet crowdsec; then PASS "CrowdSec active"; else FAIL "CrowdSec inactive"; fi

    if systemctl list-unit-files 'crowdsec-firewall-bouncer*' --no-pager --no-legend 2>/dev/null | grep -q "crowdsec-firewall-bouncer"; then
        if systemctl is-active --quiet crowdsec-firewall-bouncer; then PASS "CrowdSec firewall bouncer active"; else WARN "CrowdSec bouncer installed but inactive"; fi
    else
        WARN "CrowdSec firewall bouncer service not found"
    fi
else
    INFO "CrowdSec was not selected, check skipped"
fi

# NumLock checks.
if [ "\$INSTALL_NUMLOCK_CONFIGURED" == "yes" ]; then
    if systemctl is-enabled --quiet pve-numlock.service; then PASS "NumLock boot service enabled"; else WARN "NumLock boot service not enabled"; fi
else
    INFO "NumLock was not configured"
fi

# UI nag and sysctl checks.
if grep -q "if (false)\\|NoMoreNagging" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js 2>/dev/null; then PASS "Subscription nag patch detected"; else WARN "Subscription nag patch not detected"; fi
if [ -f /etc/sysctl.d/99-pve9-hardening-network.conf ]; then PASS "Sysctl hardening file present"; else FAIL "Sysctl hardening file missing"; fi
if sysctl net.ipv4.tcp_syncookies 2>/dev/null | grep -q "= 1"; then PASS "TCP SYN cookies enabled"; else FAIL "TCP SYN cookies not enabled"; fi
if sysctl net.core.somaxconn 2>/dev/null | awk '{print \$3}' | grep -Eq "^[0-9]+$"; then PASS "Network tuning sysctl readable"; else WARN "Network tuning sysctl not readable"; fi

echo ""
echo -e "\${YW}Verification complete. Log saved to \$VERIFY_LOG\${CL}"
echo -e "\${YW}Removing ghost verifier and systemd service...\${CL}"

systemctl disable pve-postinstall-verify.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/pve-postinstall-verify.service
rm -f /root/pve_verify.sh
systemctl daemon-reload >/dev/null 2>&1 || true

echo -e "\${GN}Ghost verifier deleted successfully.\${CL}"
EOF

    chmod +x /root/pve_verify.sh
    msg_ok "AUTO-VERIFY SCRIPT WRITTEN"

    msg_info "Writing auto-verify systemd service"
    cat <<EOF > /etc/systemd/system/pve-postinstall-verify.service
[Unit]
Description=PVE9 Post Install One-Time Verification
After=multi-user.target network-online.target ssh.service pve-cluster.service pveproxy.service pvedaemon.service pvestatd.service
Wants=network-online.target pve-cluster.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 60
ExecStart=/bin/bash /root/pve_verify.sh
StandardOutput=journal
StandardError=journal
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF
    msg_ok "AUTO-VERIFY SYSTEMD SERVICE WRITTEN"

    msg_info "Writing auto-verify login display helper"
    cat <<'EOF' > /etc/profile.d/pve-postinstall-verify-display.sh
#!/usr/bin/env bash

VERIFY_LOG="/var/log/pve9-postinstall-verify.log"
DISPLAY_MARKER="/root/.pve9-postinstall-verify-displayed"

YW=$'\033[33m'
BL=$'\033[36m'
GN=$'\033[1;92m'
CL=$'\033[m'

if [ "$(id -u)" -ne 0 ]; then
    return 0 2>/dev/null || exit 0
fi

if [ -f "$DISPLAY_MARKER" ]; then
    return 0 2>/dev/null || exit 0
fi

if [ -s "$VERIFY_LOG" ]; then
    echo ""
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo -e "${GN} PVE9 POST-INSTALL VERIFICATION REPORT${CL}"
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    cat "$VERIFY_LOG"
    echo -e "${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""

    touch "$DISPLAY_MARKER"
    rm -f /etc/profile.d/pve-postinstall-verify-display.sh
else
    echo ""
    echo -e "${YW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo -e "${YW} PVE9 POST-INSTALL VERIFICATION PENDING${CL}"
    echo -e "${YW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo -e "${YW} PVE9 post-install verification report is not ready yet.${CL}"
    echo -e "${YW} It will be displayed automatically on your next root SSH login.${CL}"
    echo -e "${YW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
    echo ""
fi
EOF

    chmod +x /etc/profile.d/pve-postinstall-verify-display.sh
    msg_ok "AUTO-VERIFY LOGIN DISPLAY HELPER INSTALLED"

    run_cmd "reloading systemd daemon" systemctl daemon-reload
    run_cmd "enabling auto-verify systemd service" systemctl enable pve-postinstall-verify.service

    msg_ok "AUTO-VERIFY GHOST SCRIPT CREATED"
}

# --- 53. COMPLETION MARKER ---
# Writes a completion marker so future reruns are blocked by fresh-install detection.
function write_completion_marker() {
    section "COMPLETION MARKER"

    msg_info "Writing PVE9 post-install completion marker"
    cat <<EOF > "$COMPLETED_MARKER"
PVE9 Post Install completed on: $(date)
System Type: $SYSTEM_TYPE
SSD Detected: $IS_SSD
Root FS Type: $ROOT_FS_TYPE
GPU Passthrough: $(yes_no_label "$ENABLE_PASSTHROUGH")
CPU Performance: $(yes_no_label "$ENABLE_PERFORMANCE")
CrowdSec: $(yes_no_label "$ENABLE_CROWDSEC")
CrowdSec Console Enrollment: $CROWDSEC_CONSOLE_ENROLLMENT
CrowdSec Console Engine Name: ${CROWDSEC_CONSOLE_ENGINE_NAME:-not-set}
Allow Public Host 80/443: $(yes_no_label "$ALLOW_PUBLIC_WEB")
Default Interface: ${DEFAULT_IFACE:-unknown}
LAN CIDR Allowed For SSH/WebUI: ${LAN_CIDR:-not-detected}
SSH Hardening: $SSH_HARDENING_APPLIED
Root SSH Key File: ${SSH_ROOT_KEY_FILE:-not-detected}
Root SSH Key Target: ${SSH_ROOT_KEY_TARGET:-not-detected}
Root SSH Key Owner: ${SSH_ROOT_KEY_OWNER:-unknown}
Root SSH Key Mode: ${SSH_ROOT_KEY_MODE:-unknown}
Root SSH Key Lines: ${SSH_ROOT_KEY_COUNT:-0}
Effective AuthorizedKeysFile: ${SSH_EFFECTIVE_AUTHORIZED_KEYS:-unknown}
Effective PermitRootLogin: ${SSH_EFFECTIVE_PERMIT_ROOT:-unknown}
Effective PasswordAuthentication: ${SSH_EFFECTIVE_PASSWORD_AUTH:-unknown}
Effective PubkeyAuthentication: ${SSH_EFFECTIVE_PUBKEY_AUTH:-unknown}
Effective KbdInteractiveAuthentication: ${SSH_EFFECTIVE_KBD_AUTH:-unknown}
Proxmox Firewall: $PVE_FIREWALL_APPLIED
Realtek Optimized: $(yes_no_label "$REALTEK_OPTIMIZED")
NumLock: $(yes_no_label "$NUMLOCK_CONFIGURED")
Storage Layout Mode: $STORAGE_LAYOUT_MODE
Current Root Size GB: $CURRENT_ROOT_SIZE_GB
Target Root/Local Visible GB: $TARGET_ROOT_SIZE_GB
Root LV Allocation GB: $ROOT_LV_ALLOCATION_GB
Root Growth GB: $ROOT_GROWTH_GB
Create Local LVM: $(yes_no_label "$CREATE_LOCAL_LVM")
Local LVM Size GB: $LOCAL_LVM_SIZE_GB
EOF

    msg_ok "PVE9 POST-INSTALL COMPLETION MARKER WRITTEN"
}


# --- FINAL SUMMARY ---
# Shows a visible finished marker before reboot so the user can confirm the script completed.
function show_final_summary() {
    section_flash_success "     ━━━━━━━━━━━━━━━━━    FINISHED    ━━━━━━━━━━━━━━━━━"

    detail_line "SYSTEM TYPE" "$SYSTEM_TYPE"
    detail_line "STORAGE LAYOUT MODE" "$STORAGE_LAYOUT_MODE"
    detail_line "GPU PASSTHROUGH" "$(yes_no_label "$ENABLE_PASSTHROUGH")"
    detail_line "CPU PERFORMANCE" "$(yes_no_label "$ENABLE_PERFORMANCE")"
    detail_line "CROWDSEC" "$(yes_no_label "$ENABLE_CROWDSEC")"
    detail_line "PROXMOX FIREWALL" "$PVE_FIREWALL_APPLIED"
    detail_line "SSH HARDENING" "$SSH_HARDENING_APPLIED"
    detail_line "REALTEK OPTIMIZED" "$(yes_no_label "$REALTEK_OPTIMIZED")"
    detail_line "NUMLOCK" "$(yes_no_label "$NUMLOCK_CONFIGURED")"
    detail_line "VERIFY LOG" "$VERIFY_LOG"

    if [ "${CROWDSEC_CONSOLE_ENROLLMENT:-no}" == "pending" ] || { [ "${CROWDSEC_CONSOLE_ENROLLMENT_REQUESTED:-no}" == "yes" ] && [ "${CROWDSEC_CONSOLE_ENROLLMENT:-no}" != "no" ]; }; then
        echo ""
        echo -e "${BL}CROWDSEC CONSOLE NEXT STEP${CL}"
        echo -e "  ${YW}Validate/accept CrowdSec engine in https://app.crowdsec.net${CL}"
        echo -e "  Engine name: ${GN}${CROWDSEC_CONSOLE_ENGINE_NAME:-proxmox-${HOSTNAME_SHORT}}${CL}"
    fi
    echo ""
}

# --- 54. FINAL REBOOT COUNTDOWN ---
# ENTER/Y reboots immediately.
# SPACE/N cancels reboot.
# Timeout reboots automatically.
function final_reboot_prompt() {
    section "REBOOT"

    if timed_reboot_countdown "$REBOOT_T"; then
        reboot
    fi
}

# =========================================================
#  MAIN ORCHESTRATION
# =========================================================

# --- 55. MAIN FUNCTION ---
# Runs the full script in clear validation -> audit -> prompt -> apply order.
function main() {
    init_script

    show_fresh_install_warning
    audit_hardware
    check_fresh_install_state
    detect_gpu_and_collect_choice
    show_storage_detection
    collect_storage_layout_option
    collect_user_options
    final_start_prompt

    apply_storage_merge
    apply_dns_redundancy
    apply_repositories_and_updates
    apply_no_nag_patch
    apply_power_settings
    apply_grub_iommu
    apply_gpu_isolation
    apply_ssh_security
    apply_sysctl_tuning
    apply_realtek_optimization
    apply_proxmox_firewall
    apply_crowdsec_security
    reinforce_pve_firewall_service
    apply_performance_and_trim
    apply_numlock_service
    create_auto_verifier
    write_completion_marker
    show_final_summary
    final_reboot_prompt

    exit 0
}

main "$@"
