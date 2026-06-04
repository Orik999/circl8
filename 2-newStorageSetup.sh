#!/usr/bin/env bash
set -euo pipefail
export LVM_SUPPRESS_FD_WARNINGS=1
shopt -s inherit_errexit nullglob

# =========================================================
#  New Storage Setup
# =========================================================

# --- 1. COLOR VARIABLES (KEEP ALL FOR FUTURE MODIFICATIONS) ---
# Central visual theme for the full script.
YW="$(printf '\033[33m')"
BL="$(printf '\033[36m')"
RD="$(printf '\033[01;31m')"
BGN="$(printf '\033[4;92m')"
GN="$(printf '\033[1;92m')"
DGN="$(printf '\033[32m')"
ANS="$(printf '\033[1;95m')"
CL="$(printf '\033[m')"
CLF="$(printf '\033[5m')"
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
WARN="${YW}!${CL}"
CROSS="${RD}✗${CL}"
BORDER="${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"

SCRIPT_SOURCE="2-newStorageSetup.sh"
SCRIPT_VERSION="v1.4.6"
SCRIPT_UPDATED="2026-06-03"
SCRIPT_BUILD="input-config-verification-ui-polish"

# --- 2. GLOBAL VARIABLES ---
# Stores timer values, logs, selected disk state, LVM/Proxmox storage values and tuning state.
T=15
LOG_FILE="/var/log/new-storage-setup.log"
VERIFY_FILE="/var/log/new-storage-setup-verify.log"
VERIFY_STATUS="not-run"
VERIFY_PASS_COUNT="0"
VERIFY_WARN_COUNT="0"
VERIFY_FAIL_COUNT="0"
COMPLETED_MARKER="/root/.new-storage-setup-completed"

SELECTED_DISK=""
SELECTED_DISK_NAME=""
DISK_TYPE="unknown"
DISK_BUS="unknown"
DISK_MODEL="unknown"
DISK_SIZE_BYTES="0"
DISK_SIZE_GB="0"
HAS_DATA="no"
DATA_RISK_REPORT=""

VG_NAME_DEFAULT="vg_circl8_vm"
THINPOOL_NAME_DEFAULT="circl8_vm_thin"
STORAGE_ID_DEFAULT="circl8-vm"

VG_NAME=""
THINPOOL_NAME=""
STORAGE_ID=""
CONTENT_TYPES="images,rootdir"
THIN_PERCENT="legacy-unused"
THINPOOL_DATA_GB="0"
THINPOOL_METADATA_GB="1"
VG_RESERVE_GB="0"
VG_SAFETY_OVERHEAD_GB="1"
THINPOOL_DATA_MIB="0"
THINPOOL_METADATA_MIB="1024"
VG_RESERVE_MIB="0"
VG_SAFETY_OVERHEAD_MIB="1024"
THINPOOL_MAX_DATA_GB="0"
THINPOOL_MAX_DATA_MIB="0"
ACTUAL_VG_FREE_GB="0"
ACTUAL_VG_FREE_MIB="0"

IS_SSD="no"
IS_NVME="no"
IO_SCHEDULER="skip"
IO_SCHEDULER_SERVICE=""

ROOT_PARENT_DISKS=""
MOUNTED_PARENT_DISKS=""
PV_PARENT_DISKS=""
BLOCKED_PARENT_DISKS=""
SAFE_DISKS=()
BLOCKED_DISKS=()
SELECTED_DISK_ENTRY_TYPE="clean"
SELECTED_DISK_REUSE_REASON=""
EXISTING_VGS_ON_SELECTED_DISK=""
EXISTING_PVS_ON_SELECTED_DISK=""

PV_CREATED="no"
VG_CREATED="no"
THINPOOL_CREATED="no"
STORAGE_REGISTERED="no"

SELECTED_DISK_ACTION=""
SELECTED_DISK_STATUS="unknown"
SELECTED_EXISTING_STORAGE_ID=""
SELECTED_EXISTING_VG=""
SELECTED_EXISTING_THINPOOL=""
SELECTED_EXISTING_CONTENT=""
SELECTED_STORAGE_CONFLICT_REASON=""
RESET_SECTION_SHOWN="no"
CREATE_SECTION_SHOWN="no"
TUNING_SECTION_SHOWN="no"
STORAGE_CONFIG_COLLECTION_SHOWN="no"
COMPLETION_MARKER_WRITTEN="no"

TEMP_FILES=()

# =========================================================
#  OUTPUT / LOGGING FUNCTIONS
# =========================================================

# --- 3. HEADER FUNCTION ---
# Displays the New Storage Setup ASCII banner.
function header_info {
    echo -e ""
    echo -e "${DGN}  ███████╗ ████████╗  ██████╗  ██████╗   █████╗   ██████╗  ███████╗${CL}"
    echo -e "${DGN}  ██╔════╝ ╚══██╔══╝ ██╔═══██╗ ██╔══██╗ ██╔══██╗ ██╔════╝  ██╔════╝${CL}"
    echo -e "${DGN}  ███████╗    ██║    ██║   ██║ ██████╔╝ ███████║ ██║  ███╗ █████╗  ${CL}"
    echo -e "${DGN}  ╚════██║    ██║    ██║   ██║ ██╔══██╗ ██╔══██║ ██║   ██║ ██╔══╝  ${CL}"
    echo -e "${DGN}  ███████║    ██║    ╚██████╔╝ ██║  ██║ ██║  ██║ ╚██████╔╝ ███████╗${CL}"
    echo -e "${DGN}  ╚══════╝    ╚═╝     ╚═════╝  ╚═╝  ╚═╝ ╚═╝  ╚═╝  ╚═════╝  ╚══════╝${CL}"
    echo -e "${YW}${CLF}                             Storage Setup                    ${CL}"
    echo -e "${BL}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
}
# --- 4. MESSAGE HELPER FUNCTIONS ---
# Provides consistent status messages for display -> apply -> success flow.
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
# Keeps output clean and avoids repeated overwritten status messages.
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

# --- 9. FAILURE HELP FUNCTION ---
# Prints useful recovery commands when the script fails after destructive storage actions.
function print_failure_recovery_hint() {
    echo ""
    echo -e "${RD}New Storage Setup did not complete successfully.${CL}"
    echo -e "${YW}Current state:${CL}"
    echo "  SELECTED_DISK: ${SELECTED_DISK:-unknown}"
    echo "  PV_CREATED: ${PV_CREATED}"
    echo "  VG_CREATED: ${VG_CREATED}"
    echo "  THINPOOL_CREATED: ${THINPOOL_CREATED}"
    echo "  STORAGE_REGISTERED: ${STORAGE_REGISTERED}"
    echo ""
    echo -e "${YW}Useful inspection commands:${CL}"
    echo "  pvs"
    echo "  vgs"
    echo "  lvs -a"
    echo "  pvesm status"
    echo "  wipefs -n ${SELECTED_DISK:-/dev/<disk>}"
    echo "  lsblk -f"
    echo ""
    echo -e "${YW}Do not rerun blindly if a PV/VG/thinpool was already created. Inspect first.${CL}"
    echo ""
}

# --- 10. ERROR TRAP HELPER ---
# Shows the failing line number and, when relevant, storage recovery hints.
function on_error() {
    local line_no="$1"

    echo -e "${RD}ERROR:${CL} Script failed at line ${line_no}. Check ${LOG_FILE}"

    if [ "$PV_CREATED" == "yes" ] || [ "$VG_CREATED" == "yes" ] || [ "$THINPOOL_CREATED" == "yes" ] || [ "$STORAGE_REGISTERED" == "yes" ]; then
        print_failure_recovery_hint
    fi
}

# --- 11. COMMAND RUNNER ---
# Runs critical commands quietly, but shows real stderr if they fail.
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

# --- 12. OPTIONAL COMMAND RUNNER ---
# Runs non-critical commands quietly and never stops the script.
function run_optional() {
    "$@" > /dev/null 2>&1 || true
}

# =========================================================
#  PROMPT FUNCTIONS
# =========================================================

# --- 13. YES/NO LABEL HELPER ---
# Converts Y/N input into readable yes/no output.
function yes_no_label() {
    local value="$1"

    if [[ "$value" =~ ^[Yy]$ ]]; then
        echo "yes"
    else
        echo "no"
    fi
}

# --- 14. BLOCKING YES/NO HELPER ---
# Used when SPACE pauses a countdown and waits for Y/N/ENTER.
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

# --- 15. TIMED YES/NO PROMPT HELPER ---
# Uses wall-clock countdown.
# SPACE pauses and waits.
# ENTER accepts default.
# Timeout accepts default.
# Final answer stays visible.
function timed_yes_no() {
    local prompt="$1"
    local default="$2"
    local confirm_mode="${3:-show}"
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
    if [ "$confirm_mode" != "quiet" ]; then
        tty_println "${CM} ${BL}${prompt}:${CL} ${ANS}${final_label}${CL}"
    fi

    echo "$answer"
}

# --- 16. NUMERIC VALIDATION HELPER ---
# Validates numeric input against optional minimum and maximum values.
function validate_number() {
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

# --- 17. NUMERIC ERROR HELPER ---
# Shows a clear numeric validation error.
function print_number_error() {
    local min_value="${1:-1}"
    local max_value="${2:-}"

    if [ -n "$max_value" ]; then
        tty_println "${RD}Invalid input. Enter numbers only between ${min_value} and ${max_value}.${CL}"
    else
        tty_println "${RD}Invalid input. Enter numbers only. Minimum value is ${min_value}.${CL}"
    fi
}

# --- 18. EDITABLE INPUT LOOP HELPER ---
# Shared editable input system for text and numeric prompts.
# The initial key is passed into the same editable buffer, so Backspace/Delete can delete it.
function editable_input_loop() {
    local prompt="$1"
    local default="$2"
    local numeric_only="${3:-no}"
    local min_value="${4:-1}"
    local max_value="${5:-}"
    local initial_value="${6:-}"
    local display_default="${7:-$default}"
    local answer="$initial_value"
    local key=""

    while true; do
        tty_print "${BFR}${YW}${prompt} [default: ${display_default}]: ${CL}${answer}"

        if [ -r /dev/tty ]; then
            IFS= read -rsn1 key < /dev/tty || true
        else
            IFS= read -rsn1 key || true
        fi

        case "$key" in
            $'\e')
                # Ignore full terminal escape sequences, such as arrow keys.
                # A single Down arrow normally arrives as ESC [ B; without this,
                # numeric prompts report one invalid error for each byte.
                while true; do
                    if [ -r /dev/tty ]; then
                        IFS= read -rsn1 -t 0.01 key < /dev/tty || break
                    else
                        IFS= read -rsn1 -t 0.01 key || break
                    fi
                done
                ;;
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

# --- 19. TIMED TEXT INPUT HELPER ---
# Shows wall-clock countdown.
# SPACE pauses with empty editable buffer.
# Any typed character pauses with that character already inside the editable buffer.
# Backspace/Delete can delete every typed character, including the first.
function timed_text_input() {
    local prompt="$1"
    local default="$2"
    local confirm_mode="${3:-show}"
    local answer=""

    # Text/path/name inputs are deliberately NOT timed.
    # Countdown prompts are reserved only for simple Y/n decisions.
    # This prevents defaults being accepted while the user is away and gives enough time to type/paste.
    answer="$(editable_input_loop "$prompt" "$default" "no" "1" "" "")"
    [ -z "$answer" ] && answer="$default"

    tty_print "${BFR}"
    if [ "$confirm_mode" != "quiet" ]; then
        tty_println "${CM} ${BL}${prompt}:${CL} ${ANS}${answer}${CL}"
    fi

    echo "$answer"
}

# --- 20. TIMED NUMERIC INPUT HELPER ---
# Shows wall-clock countdown and validates numeric input.
# SPACE pauses with empty editable numeric buffer.
# Any typed digit pauses with that digit already inside the editable buffer.
# Timeout accepts default.
function timed_number_input() {
    local prompt="$1"
    local default="$2"
    local min_value="${3:-1}"
    local max_value="${4:-}"
    local confirm_mode="${5:-show}"
    local answer=""

    # Numeric inputs are deliberately NOT timed.
    # Countdown prompts are reserved only for simple Y/n decisions.
    while true; do
        answer="$(editable_input_loop "$prompt" "$default" "yes" "$min_value" "$max_value" "")"
        [ -z "$answer" ] && answer="$default"

        if validate_number "$answer" "$min_value" "$max_value"; then
            tty_print "${BFR}"
            if [ "$confirm_mode" != "quiet" ]; then
                tty_println "${CM} ${BL}${prompt}:${CL} ${ANS}${answer}${CL}"
            fi
            echo "$answer"
            return 0
        fi

        tty_print "${BFR}"
        print_number_error "$min_value" "$max_value"
    done
}

function timed_percent_input() {
    local prompt="$1"
    local default="$2"
    local min_value="${3:-1}"
    local max_value="${4:-}"
    local answer=""

    # Display-only percent wrapper; returned value remains a plain number.
    while true; do
        answer="$(editable_input_loop "$prompt" "$default" "yes" "$min_value" "$max_value" "" "${default}%")"
        [ -z "$answer" ] && answer="$default"

        if validate_number "$answer" "$min_value" "$max_value"; then
            tty_print "${BFR}"
            tty_println "${CM} ${GN}${prompt} ${answer}%${CL}"
            echo "$answer"
            return 0
        fi

        tty_print "${BFR}"
        print_number_error "$min_value" "$max_value"
    done
}

# =========================================================
#  VALIDATION HELPERS
# =========================================================

# --- 21. NAME VALIDATION HELPER ---
# Validates LVM and Proxmox storage names before destructive actions begin.
function validate_name_or_error() {
    local label="$1"
    local value="$2"
    local pattern="$3"

    if ! [[ "$value" =~ $pattern ]]; then
        msg_error "${label} contains invalid characters: ${value}"
    fi
}

# --- 22. RESERVED NAME VALIDATION HELPER ---
# Blocks names that are confusing or dangerous for this setup.
function reject_reserved_name_or_error() {
    local label="$1"
    local value="$2"

    case "$value" in
        local|local-lvm|pve|root|data|backup|iso|snippets)
            msg_error "${label} uses a reserved or confusing name: ${value}"
            ;;
    esac
}

# --- 23. CONTENT TYPE VALIDATION HELPER ---
# Validates Proxmox storage content type list.
function validate_content_types_or_error() {
    local value="$1"
    local item=""

    if [ -z "$value" ]; then
        msg_error "Content types cannot be empty."
    fi

    IFS=',' read -ra content_array <<< "$value"

    for item in "${content_array[@]}"; do
        item="$(echo "$item" | xargs)"

        case "$item" in
            images|rootdir|backup|iso|vztmpl|snippets|import)
                ;;
            *)
                msg_error "Invalid Proxmox content type: ${item}"
                ;;
        esac
    done
}

# =========================================================
#  DISK SAFETY HELPERS
# =========================================================

# --- 24. PARENT DISK HELPER ---
# Returns the parent disk name for a block path.
# Examples:
# /dev/sda2 -> sda
# /dev/nvme0n1p2 -> nvme0n1
# /dev/sdb -> sdb
function get_parent_disk_name() {
    local path="$1"
    local pkname=""
    local name=""

    [ -b "$path" ] || return 1

    pkname="$(lsblk -no PKNAME "$path" 2>/dev/null | head -n1 | xargs || true)"

    if [ -n "$pkname" ]; then
        echo "$pkname"
        return 0
    fi

    name="$(lsblk -no NAME "$path" 2>/dev/null | head -n1 | xargs || true)"

    if [ -n "$name" ]; then
        echo "$name"
        return 0
    fi

    basename "$path"
}

# --- 25. ADD UNIQUE WORD HELPER ---
# Maintains space-separated unique disk-name lists.
function add_unique_word() {
    local list="$1"
    local word="$2"

    [ -z "$word" ] && {
        echo "$list"
        return 0
    }

    if [[ " ${list} " == *" ${word} "* ]]; then
        echo "$list"
    else
        echo "${list} ${word}" | xargs
    fi
}

# --- 26. BUILD BLOCKED DISK LISTS ---
# Blocks OS/root/boot/EFI disks, mounted disks and existing PV-backed disks from being selectable.
function build_blocked_disk_lists() {
    local target=""
    local source=""
    local disk=""
    local pv=""
    local mounted_dev=""
    local type=""

    ROOT_PARENT_DISKS=""
    MOUNTED_PARENT_DISKS=""
    PV_PARENT_DISKS=""
    BLOCKED_PARENT_DISKS=""

    for target in / /boot /boot/efi /var/lib/vz; do
        source="$(findmnt -n -o SOURCE "$target" 2>/dev/null || true)"

        if [ -n "$source" ] && [ -b "$source" ]; then
            disk="$(get_parent_disk_name "$source" || true)"
            ROOT_PARENT_DISKS="$(add_unique_word "$ROOT_PARENT_DISKS" "$disk")"
        fi
    done

    while read -r mounted_dev type; do
        [ -z "$mounted_dev" ] && continue
        [ "$type" != "part" ] && [ "$type" != "disk" ] && continue

        if [ -b "$mounted_dev" ]; then
            disk="$(get_parent_disk_name "$mounted_dev" || true)"
            MOUNTED_PARENT_DISKS="$(add_unique_word "$MOUNTED_PARENT_DISKS" "$disk")"
        fi
    done < <(lsblk -rnpo NAME,TYPE,MOUNTPOINTS | awk '$3 != "" {print $1, $2}')

    while read -r pv; do
        [ -z "$pv" ] && continue

        if [ -b "$pv" ]; then
            disk="$(get_parent_disk_name "$pv" || true)"
            PV_PARENT_DISKS="$(add_unique_word "$PV_PARENT_DISKS" "$disk")"
        fi
    done < <(pvs --noheadings -o pv_name 2>/dev/null | xargs -n1 || true)

    for disk in $ROOT_PARENT_DISKS $MOUNTED_PARENT_DISKS; do
        BLOCKED_PARENT_DISKS="$(add_unique_word "$BLOCKED_PARENT_DISKS" "$disk")"
    done
}

# --- 27. DISK BLOCK REASON HELPER ---
# Explains why a disk was blocked from selection.
function get_disk_block_reason() {
    local disk="$1"
    local reason=""

    if [[ " ${ROOT_PARENT_DISKS} " == *" ${disk} "* ]]; then
        reason+="root/boot/proxmox-storage "
    fi

    if [[ " ${MOUNTED_PARENT_DISKS} " == *" ${disk} "* ]]; then
        reason+="mounted-child "
    fi

    if [[ " ${PV_PARENT_DISKS} " == *" ${disk} "* ]]; then
        reason+="existing-LVM-PV "
    fi

    echo "${reason:-unknown}" | xargs
}

# Returns existing PV devices that belong to the selected parent disk, including child partitions.
function get_pvs_for_disk() {
    local disk="$1"
    local pv=""
    local parent=""

    while read -r pv; do
        [ -z "$pv" ] && continue
        [ -b "$pv" ] || continue

        parent="$(get_parent_disk_name "$pv" || true)"
        if [ "$parent" == "$(basename "$disk")" ]; then
            echo "$pv"
        fi
    done < <(pvs --noheadings -o pv_name 2>/dev/null | xargs -n1 || true)
}

# Returns existing VG names that have PVs on the selected parent disk.
function get_vgs_for_disk() {
    local disk="$1"
    local pv=""
    local vg=""
    local parent=""

    while IFS='|' read -r pv vg; do
        pv="$(echo "${pv:-}" | xargs)"
        vg="$(echo "${vg:-}" | xargs)"
        [ -z "$pv" ] && continue
        [ -z "$vg" ] && continue
        [ -b "$pv" ] || continue

        parent="$(get_parent_disk_name "$pv" || true)"
        if [ "$parent" == "$(basename "$disk")" ]; then
            echo "$vg"
        fi
    done < <(pvs --noheadings --separator '|' -o pv_name,vg_name 2>/dev/null || true) | sort -u
}

# Returns parent disks used by every PV in a VG. Used to avoid destroying multi-disk VGs.
function get_parent_disks_for_vg() {
    local vg="$1"
    local pv=""
    local parent=""

    while read -r pv; do
        [ -z "$pv" ] && continue
        [ -b "$pv" ] || continue

        parent="$(get_parent_disk_name "$pv" || true)"
        [ -n "$parent" ] && echo "$parent"
    done < <(pvs --noheadings -o pv_name --select "vg_name=${vg}" 2>/dev/null | xargs -n1 || true) | sort -u
}

# Returns all Proxmox storage IDs declared in /etc/pve/storage.cfg.
function get_storage_ids_from_cfg() {
    [ -r /etc/pve/storage.cfg ] || return 0
    awk '/^[^[:space:]][^:]*:[[:space:]]/ { sub(/^[^:]+:[[:space:]]*/, ""); print }' /etc/pve/storage.cfg
}

# Returns the /etc/pve/storage.cfg block for a storage ID.
function get_storage_cfg_block() {
    local sid="$1"
    [ -r /etc/pve/storage.cfg ] || return 0

    awk -v sid="$sid" '
        /^[^[:space:]][^:]*:[[:space:]]/ {
            if (in_block) exit
            line=$0
            sub(/^[^:]+:[[:space:]]*/, "", line)
            if (line == sid) {
                in_block=1
                print $0
            }
            next
        }
        in_block && /^[[:space:]]*$/ { exit }
        in_block { print $0 }
    ' /etc/pve/storage.cfg
}

# Returns a single field value from a storage.cfg block.
function get_storage_cfg_field() {
    local sid="$1"
    local field="$2"

    get_storage_cfg_block "$sid" | awk -v field="$field" '$1 == field { $1=""; sub(/^[[:space:]]+/, ""); print; exit }'
}

# Returns the storage type for a storage.cfg block, for example lvmthin.
function get_storage_cfg_type() {
    local sid="$1"

    get_storage_cfg_block "$sid" | awk 'NR == 1 { sub(/:.*/, "", $1); print $1; exit }'
}

# Checks whether Proxmox status currently lists a storage ID.
function storage_id_in_pvesm_status() {
    local sid="$1"
    pvesm status 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fxq "$sid"
}

# Checks whether storage.cfg contains a storage ID block.
function storage_id_in_cfg() {
    local sid="$1"
    [ -n "$(get_storage_cfg_block "$sid" | head -n 1)" ]
}

# Checks whether storage exists either in pvesm status or storage.cfg.
function storage_id_exists() {
    local sid="$1"
    storage_id_in_pvesm_status "$sid" || storage_id_in_cfg "$sid"
}

# Checks that a comma-separated content list contains one requested item.
function storage_content_has_item() {
    local content="$1"
    local item="$2"

    echo "$content" | tr ',' '\n' | awk '{$1=$1; print}' | grep -Fxq "$item"
}

# Returns success only if storage.cfg matches the expected LVM-thin registration.
function storage_cfg_matches_expected() {
    local sid="$1"
    local expected_vg="$2"
    local expected_thinpool="$3"
    local expected_content="$4"
    local stype=""
    local vgname=""
    local thinpool=""
    local content=""
    local item=""

    stype="$(get_storage_cfg_type "$sid" | xargs || true)"
    vgname="$(get_storage_cfg_field "$sid" vgname | xargs || true)"
    thinpool="$(get_storage_cfg_field "$sid" thinpool | xargs || true)"
    content="$(get_storage_cfg_field "$sid" content | xargs || true)"

    [ "$stype" == "lvmthin" ] || return 1
    [ "$vgname" == "$expected_vg" ] || return 1
    [ "$thinpool" == "$expected_thinpool" ] || return 1

    for item in ${expected_content//,/ }; do
        storage_content_has_item "$content" "$item" || return 1
    done

    return 0
}

# Prints the storage.cfg block for troubleshooting mismatches.
function print_storage_cfg_block() {
    local sid="$1"
    local block=""

    block="$(get_storage_cfg_block "$sid")"
    if [ -n "$block" ]; then
        echo "$block"
    else
        echo "storage.cfg block for ${sid}: not found"
    fi
}

# Validates that Proxmox storage is registered and points to the expected VG/thinpool/content.
function validate_registered_storage() {
    local sid="${1:-$STORAGE_ID}"
    local expected_vg="${2:-$VG_NAME}"
    local expected_thinpool="${3:-$THINPOOL_NAME}"
    local expected_content="${4:-$CONTENT_TYPES}"

    if ! storage_id_in_pvesm_status "$sid"; then
        echo ""
        echo -e "${RD}Proxmox storage ${sid} is not listed by pvesm status.${CL}"
        pvesm status 2>/dev/null || true
        msg_error "Proxmox storage ${sid} is not active/registered."
    fi

    if ! storage_id_in_cfg "$sid"; then
        echo ""
        echo -e "${RD}Proxmox storage ${sid} is not present in /etc/pve/storage.cfg.${CL}"
        msg_error "Proxmox storage ${sid} has no storage.cfg block."
    fi

    if ! storage_cfg_matches_expected "$sid" "$expected_vg" "$expected_thinpool" "$expected_content"; then
        echo ""
        echo -e "${RD}Proxmox storage ${sid} exists but does not match expected settings.${CL}"
        echo -e "${YW}Expected:${CL} type=lvmthin vgname=${expected_vg} thinpool=${expected_thinpool} content includes ${expected_content}"
        echo -e "${YW}Actual storage.cfg block:${CL}"
        print_storage_cfg_block "$sid" | sed 's/^/  /'
        msg_error "Storage ${sid} mismatch. Refusing to continue."
    fi

    STORAGE_REGISTERED="yes"
    msg_ok "PROXMOX STORAGE ${sid} MATCHES EXPECTED CONFIG"
}

# Finds Proxmox storage entries that reference a VG on the selected disk.
function get_proxmox_storage_refs_for_vgs() {
    local vg_list="$1"
    local sid=""
    local vg=""
    local cfg_vg=""

    while read -r sid; do
        [ -z "$sid" ] && continue
        cfg_vg="$(get_storage_cfg_field "$sid" vgname | xargs || true)"
        [ -z "$cfg_vg" ] && continue

        for vg in $vg_list; do
            if [ "$cfg_vg" == "$vg" ]; then
                echo "$sid -> vgname ${vg}"
            fi
        done
    done < <(get_storage_ids_from_cfg || true)
}

# Escapes VG/LV components for /dev/mapper paths, matching LVM hyphen escaping.
function lvm_mapper_escape() {
    local value="$1"
    echo "${value//-/--}"
}

# Finds mounted logical volumes that belong to VG(s) on the selected disk.
# Destructive reuse must refuse mounted LVs; the script never auto-unmounts.
function get_mounted_lvs_for_vgs() {
    local vg_list="$1"
    local lv_path=""
    local lv_vg=""
    local lv_name=""
    local vg=""
    local match=""
    local source=""
    local canonical=""
    local mapper_path=""
    local mountpoint=""
    local escaped_vg=""
    local escaped_lv=""

    while IFS='|' read -r lv_path lv_vg lv_name; do
        lv_path="$(echo "${lv_path:-}" | xargs)"
        lv_vg="$(echo "${lv_vg:-}" | xargs)"
        lv_name="$(echo "${lv_name:-}" | xargs)"
        [ -z "$lv_vg" ] && continue
        [ -z "$lv_name" ] && continue

        match="no"
        for vg in $vg_list; do
            if [ "$lv_vg" == "$vg" ]; then
                match="yes"
                break
            fi
        done
        [ "$match" == "yes" ] || continue

        [ -n "$lv_path" ] || lv_path="/dev/${lv_vg}/${lv_name}"
        escaped_vg="$(lvm_mapper_escape "$lv_vg")"
        escaped_lv="$(lvm_mapper_escape "$lv_name")"
        mapper_path="/dev/mapper/${escaped_vg}-${escaped_lv}"

        for source in "$lv_path" "$mapper_path"; do
            [ -e "$source" ] || continue
            mountpoint="$(findmnt -rn -S "$source" -o TARGET 2>/dev/null | xargs || true)"
            if [ -n "$mountpoint" ]; then
                echo "${lv_vg}/${lv_name} mounted at ${mountpoint} via ${source}"
            fi

            canonical="$(readlink -f "$source" 2>/dev/null || true)"
            if [ -n "$canonical" ] && [ "$canonical" != "$source" ]; then
                mountpoint="$(findmnt -rn -S "$canonical" -o TARGET 2>/dev/null | xargs || true)"
                if [ -n "$mountpoint" ]; then
                    echo "${lv_vg}/${lv_name} mounted at ${mountpoint} via ${canonical}"
                fi
            fi
        done
    done < <(lvs --noheadings --separator '|' -o lv_path,vg_name,lv_name 2>/dev/null || true) | sort -u
}

# --- 28. DISK DATA RISK REPORT HELPER ---
# Builds a detailed risk report for existing signatures, partitions, PVs, mdraid and ZFS labels.
function build_data_risk_report() {
    local disk="$1"
    local report=""
    local child_count="0"

    if wipefs -n "$disk" 2>/dev/null | grep -q .; then
        report+="filesystem/partition signatures detected"$'\n'
    fi

    child_count="$(lsblk -nr "$disk" | awk 'NR>1 {count++} END {print count+0}')"

    if [ "$child_count" -gt 0 ]; then
        report+="child partitions/devices detected (${child_count})"$'\n'
    fi

    local lvm_pvs=""
    local lvm_vgs=""
    lvm_pvs="$(get_pvs_for_disk "$disk" | xargs || true)"
    lvm_vgs="$(get_vgs_for_disk "$disk" | xargs || true)"
    if [ -n "$lvm_vgs" ]; then
        report+="existing LVM PV/VG metadata detected (VGs: ${lvm_vgs}; PVs: ${lvm_pvs:-unknown})"$'\n'
    elif [ -n "$lvm_pvs" ]; then
        report+="existing LVM PV metadata detected (${lvm_pvs})"$'\n'
    fi

    if command -v mdadm >/dev/null 2>&1 && mdadm --examine "$disk" >/dev/null 2>&1; then
        report+="mdraid metadata detected"$'\n'
    fi

    if command -v zdb >/dev/null 2>&1 && zdb -l "$disk" >/dev/null 2>&1; then
        report+="possible ZFS label detected"$'\n'
    fi

    echo "$report"
}

# =========================================================
#  INITIALIZATION / ENVIRONMENT VALIDATION
# =========================================================

# --- 29. DEPENDENCY CHECK ---
# Ensures disk, LVM, Proxmox, systemd and tuning tools are available before any changes.
function validate_dependencies() {
    local required_commands=(
        awk
        basename
        blockdev
        cat
        chmod
        command
        cut
        date
        env
        findmnt
        grep
        head
        lsblk
        lvchange
        lvcreate
        lvs
        mkdir
        mktemp
        pvesm
        pvcreate
        pvremove
        pvs
        rm
        sed
        sgdisk
        sleep
        sort
        sysctl
        systemctl
        tee
        touch
        vgcfgbackup
        vgcreate
        vgremove
        vgs
        wipefs
        xargs
    )

    local cmd=""

    for cmd in "${required_commands[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || msg_error "Missing required command: $cmd"
    done
}


# --- 30. PROXMOX VALIDATION ---
# Confirms this is Proxmox VE 9+ before touching storage.
function validate_proxmox() {
    local pve_major=""

    if ! command -v pveversion >/dev/null 2>&1; then
        msg_error "This system is not Proxmox VE. Script cancelled."
    fi

    pve_major="$(pveversion | cut -d'/' -f2 | cut -d'.' -f1)"

    if ! [[ "$pve_major" =~ ^[0-9]+$ ]] || [ "$pve_major" -lt 9 ]; then
        msg_error "Requires Proxmox VE 9+."
    fi
}

# --- 31. SCRIPT INITIALIZATION ---
# Starts logging, installs traps, validates root/proxmox/dependencies and shows banner.
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

    validate_proxmox
    validate_dependencies
}

# --- 32. PREVIOUS RUN MARKER CHECK ---
# Warns if this setup was already completed before.
function check_previous_marker() {
    local continue_yn=""

    if [ -f "$COMPLETED_MARKER" ]; then
        section "PREVIOUS SETUP MARKER DETECTED"

        echo -e "${YW}A previous New Storage Setup marker exists:${CL} ${GN}${COMPLETED_MARKER}${CL}"
        echo ""
        cat "$COMPLETED_MARKER" 2>/dev/null || true
        echo ""

        continue_yn="$(timed_yes_no "Continue anyway?" "n")"

        if [[ "$continue_yn" =~ ^[Nn] ]]; then
            exit 0
        fi
    fi
}

# --- APPLY SECTION HELPERS ---
# Consolidates reset/recreate and new-storage progress into clean high-level sections.
function begin_reset_section_once() {
    if [ "$RESET_SECTION_SHOWN" != "yes" ]; then
        section "RESETTING / RECREATING DISK"
        echo -e "${YW}Resetting:${CL}"
        RESET_SECTION_SHOWN="yes"
    fi
}

function begin_create_section_once() {
    if [ "$RESET_SECTION_SHOWN" != "yes" ]; then
        section "RESETTING / RECREATING DISK"
        RESET_SECTION_SHOWN="yes"
    fi

    if [ "$CREATE_SECTION_SHOWN" != "yes" ]; then
        echo ""
        echo -e "${YW}Recreating:${CL}"
        CREATE_SECTION_SHOWN="yes"
    fi
}

function begin_tuning_section_once() {
    if [ "$TUNING_SECTION_SHOWN" != "yes" ]; then
        section "OPTIMIZING / TUNING STORAGE DRIVE"
        TUNING_SECTION_SHOWN="yes"
    fi
}

function selected_disk_action_label() {
    case "$SELECTED_DISK_ACTION" in
        create) echo "Create fresh storage" ;;
        recreate) echo "Wipe/Recreate" ;;
        validate-register) echo "Validate/Register existing" ;;
        *) echo "${SELECTED_DISK_ACTION:-unknown}" ;;
    esac
}

# --- SELECTED-DISK MARKER / ACTION HELPERS ---
# Previous run state is evaluated only after the user selects a target disk.
function marker_exists() {
    [ -f "$COMPLETED_MARKER" ]
}

function marker_value() {
    local field="$1"
    [ -r "$COMPLETED_MARKER" ] || return 0

    awk -F': ' -v field="$field" '$1 == field {print $2; exit}' "$COMPLETED_MARKER" 2>/dev/null | xargs || true
}

function marker_key_value() {
    local key="$1"
    [ -r "$COMPLETED_MARKER" ] || return 0

    awk -F'=' -v key="$key" '$1 == key {print $2; exit}' "$COMPLETED_MARKER" 2>/dev/null | xargs || true
}

function marker_disk_from_file() {
    local value=""
    value="$(marker_value "Disk")"
    [ -n "$value" ] || value="$(marker_key_value "SELECTED_DISK")"
    echo "$value"
}

function marker_storage_id_from_file() {
    local value=""
    value="$(marker_value "Storage ID")"
    [ -n "$value" ] || value="$(marker_key_value "STORAGE_ID")"
    echo "$value"
}

function marker_vg_from_file() {
    local value=""
    value="$(marker_value "VG")"
    [ -n "$value" ] || value="$(marker_key_value "VG_NAME")"
    echo "$value"
}

function marker_thinpool_from_file() {
    local value=""
    value="$(marker_value "Thinpool")"
    [ -n "$value" ] || value="$(marker_key_value "THINPOOL_NAME")"
    echo "$value"
}

function marker_content_from_file() {
    local value=""
    value="$(marker_value "Content Types")"
    echo "$value"
}

function marker_matches_selected_disk() {
    local marker_disk=""
    marker_disk="$(marker_disk_from_file)"
    [ -n "$marker_disk" ] || return 1
    [ "$marker_disk" == "$SELECTED_DISK" ]
}

function storage_id_for_vg_from_cfg() {
    local target_vg="$1"
    local sid=""
    local cfg_vg=""

    while read -r sid; do
        [ -z "$sid" ] && continue
        cfg_vg="$(get_storage_cfg_field "$sid" vgname | xargs || true)"
        if [ "$cfg_vg" == "$target_vg" ]; then
            echo "$sid"
            return 0
        fi
    done < <(get_storage_ids_from_cfg || true)
}

function thinpool_for_storage_from_cfg() {
    local sid="$1"
    get_storage_cfg_field "$sid" thinpool | xargs || true
}

function content_for_storage_from_cfg() {
    local sid="$1"
    get_storage_cfg_field "$sid" content | xargs || true
}

function selected_disk_expected_vg() {
    local marker_vg=""
    marker_vg="$(marker_vg_from_file)"
    if marker_matches_selected_disk && [ -n "$marker_vg" ]; then
        echo "$marker_vg"
        return 0
    fi

    if [[ " ${EXISTING_VGS_ON_SELECTED_DISK} " == *" ${VG_NAME_DEFAULT} "* ]]; then
        echo "$VG_NAME_DEFAULT"
        return 0
    fi

    echo ""
}

function selected_disk_has_existing_script2_storage() {
    local candidate_vg=""
    local candidate_thinpool=""

    candidate_vg="$(selected_disk_expected_vg)"
    [ -n "$candidate_vg" ] || return 1

    candidate_thinpool="$THINPOOL_NAME_DEFAULT"
    if marker_matches_selected_disk && [ -n "$(marker_thinpool_from_file)" ]; then
        candidate_thinpool="$(marker_thinpool_from_file)"
    fi

    [[ " ${EXISTING_VGS_ON_SELECTED_DISK} " == *" ${candidate_vg} "* ]] || return 1
    lvs "${candidate_vg}/${candidate_thinpool}" >/dev/null 2>&1
}

function selected_disk_storage_registered() {
    local candidate_vg="${1:-}"
    local sid=""

    [ -n "$candidate_vg" ] || candidate_vg="$(selected_disk_expected_vg)"
    [ -n "$candidate_vg" ] || return 1

    sid="$(storage_id_for_vg_from_cfg "$candidate_vg")"
    [ -n "$sid" ] || return 1
    storage_id_in_pvesm_status "$sid" || storage_id_in_cfg "$sid"
}

function detect_selected_disk_storage_context() {
    local marker_sid=""
    local marker_vg=""
    local marker_thinpool=""
    local marker_content=""
    local candidate_vg=""
    local cfg_sid=""
    local cfg_thinpool=""
    local cfg_content=""
    local proxmox_refs=""

    SELECTED_DISK_STATUS="unknown"
    SELECTED_EXISTING_STORAGE_ID=""
    SELECTED_EXISTING_VG=""
    SELECTED_EXISTING_THINPOOL=""
    SELECTED_EXISTING_CONTENT=""
    SELECTED_STORAGE_CONFLICT_REASON=""

    marker_sid="$(marker_storage_id_from_file)"
    marker_vg="$(marker_vg_from_file)"
    marker_thinpool="$(marker_thinpool_from_file)"
    marker_content="$(marker_content_from_file)"

    if marker_exists && marker_matches_selected_disk; then
        SELECTED_DISK_STATUS="previous-script2"
        SELECTED_EXISTING_STORAGE_ID="${marker_sid:-$STORAGE_ID_DEFAULT}"
        SELECTED_EXISTING_VG="${marker_vg:-$VG_NAME_DEFAULT}"
        SELECTED_EXISTING_THINPOOL="${marker_thinpool:-$THINPOOL_NAME_DEFAULT}"
        SELECTED_EXISTING_CONTENT="${marker_content:-$CONTENT_TYPES}"
        return 0
    fi

    candidate_vg="$(selected_disk_expected_vg)"
    if [ -n "$candidate_vg" ] && selected_disk_has_existing_script2_storage; then
        cfg_sid="$(storage_id_for_vg_from_cfg "$candidate_vg")"
        cfg_thinpool=""
        cfg_content=""
        if [ -n "$cfg_sid" ]; then
            cfg_thinpool="$(thinpool_for_storage_from_cfg "$cfg_sid")"
            cfg_content="$(content_for_storage_from_cfg "$cfg_sid")"
        fi

        SELECTED_DISK_STATUS="previous-script2"
        SELECTED_EXISTING_STORAGE_ID="${cfg_sid:-$STORAGE_ID_DEFAULT}"
        SELECTED_EXISTING_VG="$candidate_vg"
        SELECTED_EXISTING_THINPOOL="${cfg_thinpool:-$THINPOOL_NAME_DEFAULT}"
        SELECTED_EXISTING_CONTENT="${cfg_content:-$CONTENT_TYPES}"
        return 0
    fi

    if [ -n "$EXISTING_VGS_ON_SELECTED_DISK" ]; then
        proxmox_refs="$(get_proxmox_storage_refs_for_vgs "$EXISTING_VGS_ON_SELECTED_DISK" | xargs || true)"
        if [ -n "$proxmox_refs" ]; then
            SELECTED_DISK_STATUS="storage-conflict"
            SELECTED_STORAGE_CONFLICT_REASON="selected disk backs existing Proxmox storage: ${proxmox_refs}"
            return 0
        fi
    fi

    if [ "$HAS_DATA" == "yes" ]; then
        SELECTED_DISK_STATUS="data-detected"
    else
        SELECTED_DISK_STATUS="fresh"
    fi
}

function show_existing_storage_context() {
    echo -e "${YW}Existing storage:${CL}"
    echo -e "  ${BL}Disk:${CL} ${GN}${SELECTED_DISK}${CL}"
    echo -e "  ${BL}Storage ID:${CL} ${GN}${SELECTED_EXISTING_STORAGE_ID:-$STORAGE_ID_DEFAULT}${CL}"
    echo -e "  ${BL}VG:${CL} ${GN}${SELECTED_EXISTING_VG:-$VG_NAME_DEFAULT}${CL}"
    echo -e "  ${BL}Thinpool:${CL} ${GN}${SELECTED_EXISTING_THINPOOL:-$THINPOOL_NAME_DEFAULT}${CL}"
    echo -e "  ${BL}Content:${CL} ${GN}${SELECTED_EXISTING_CONTENT:-$CONTENT_TYPES}${CL}"
    if [ -n "${THINPOOL_DATA_GB:-}" ] && [ "$THINPOOL_DATA_GB" != "0" ]; then
        echo -e "  ${BL}Thinpool data:${CL} ${GN}${THINPOOL_DATA_GB} GB${CL}"
    fi
    if [ -n "${THINPOOL_METADATA_GB:-}" ] && [ "$THINPOOL_METADATA_GB" != "0" ]; then
        echo -e "  ${BL}Thinpool metadata:${CL} ${GN}${THINPOOL_METADATA_GB} GB${CL}"
    fi
}

function choose_selected_disk_action() {
    local action=""

    detect_selected_disk_storage_context

    section "SELECTED DISK / STATUS"
    echo -e " ${CM} ${GN}SELECTED DISK INSPECTED${CL}"
    echo ""

    echo -e "${YW}Disk:${CL}"
    echo -e "  ${BL}Path:${CL} ${ANS}${SELECTED_DISK}${CL}"
    echo -e "  ${BL}Model:${CL} ${GN}${DISK_MODEL:-unknown}${CL}"
    echo -e "  ${BL}Type/Bus:${CL} ${GN}${DISK_TYPE} / ${DISK_BUS}${CL}"
    echo -e "  ${BL}Size:${CL} ${GN}${DISK_SIZE_GB} GB${CL}"
    echo ""

    case "$SELECTED_DISK_STATUS" in
        fresh)
            echo -e "${YW}Status:${CL}"
            echo -e "  ${BL}State:${CL} ${GN}fresh disk${CL}"
            echo -e "  ${BL}Risk:${CL} ${GN}none detected${CL}"
            echo ""
            echo -e "${YW}Action:${CL}"
            echo -e "  ${BL}1)${CL} ${GN}LVM-thin VM storage, snapshot-ready recommended${CL}"
            echo -e "  ${BL}2)${CL} Cancel"
            echo ""
            action="$(timed_number_input "Select action" "1" "1" "2" "quiet")"
            echo -e "${BFR} ${CM} ${GN}Selected action:${CL} ${ANS}${action}${CL}"
            case "$action" in
                1) SELECTED_DISK_ACTION="create" ;;
                2) echo -e "${YW}No changes made.${CL}"; exit 0 ;;
            esac
            ;;
        data-detected)
            echo -e "${YW}Status:${CL}"
            echo -e "  ${BL}State:${CL} ${YW}data detected${CL}"
            echo -e "  ${BL}Risk:${CL} ${RD}Destructive Reuse / existing data${CL}"
            echo ""
            print_selected_data_risk_report "$DATA_RISK_REPORT"
            if [ -n "$EXISTING_VGS_ON_SELECTED_DISK" ]; then
                echo -e "  ${BL}Existing VG(s):${CL} ${YW}${EXISTING_VGS_ON_SELECTED_DISK}${CL}"
            fi
            if [ -n "$EXISTING_PVS_ON_SELECTED_DISK" ]; then
                echo -e "  ${BL}Existing PV(s):${CL} ${YW}${EXISTING_PVS_ON_SELECTED_DISK}${CL}"
            fi
            echo ""
            echo -e "${YW}Action:${CL}"
            echo -e "  ${BL}1)${CL} ${RD}Wipe/recreate this disk as fresh storage${CL}"
            echo -e "  ${BL}2)${CL} Cancel"
            echo ""
            action="$(timed_number_input "Select action" "2" "1" "2" "quiet")"
            echo -e "${BFR} ${CM} ${GN}Selected action:${CL} ${ANS}${action}${CL}"
            case "$action" in
                1) SELECTED_DISK_ACTION="recreate" ;;
                2) echo -e "${YW}No changes made.${CL}"; exit 0 ;;
            esac
            ;;
        previous-script2)
            echo -e "${YW}Status:${CL}"
            echo -e "  ${BL}State:${CL} ${GN}Previous Script 2 storage detected${CL}"
            echo -e "  ${BL}Risk:${CL} ${RD}Destructive Reuse ${BL}/${CL} ${YW}Existing storage${CL}"
            echo ""
            show_existing_storage_context
            echo ""
            echo -e "${YW}Action:${CL}"
            echo -e "  ${BL}1)${CL} ${GN}Validate/register existing storage without wiping${CL}"
            echo -e "  ${BL}2)${CL} ${RD}Wipe/recreate this disk as new storage${CL}"
            echo -e "  ${BL}3)${CL} Cancel"
            echo ""
            action="$(timed_number_input "Select action" "1" "1" "3" "quiet")"
            echo -e "${BFR} ${CM} ${GN}Selected action:${CL} ${ANS}${action}${CL}"
            case "$action" in
                1) SELECTED_DISK_ACTION="validate-register" ;;
                2) SELECTED_DISK_ACTION="recreate" ;;
                3) echo -e "${YW}No changes made.${CL}"; exit 0 ;;
            esac
            ;;
        storage-conflict)
            echo -e "${YW}Status:${CL}"
            echo -e "  ${BL}State:${CL} ${RD}storage conflict detected${CL}"
            echo -e "  ${BL}Reason:${CL} ${RD}${SELECTED_STORAGE_CONFLICT_REASON:-unknown}${CL}"
            echo ""
            echo -e "${YW}Recommended action:${CL} cancel and inspect manually."
            echo ""
            echo -e "${YW}Action:${CL}"
            echo -e "  ${BL}1)${CL} Cancel"
            echo ""
            action="$(timed_number_input "Select action" "1" "1" "1" "quiet")"
            echo -e "${BFR} ${CM} ${GN}Selected action:${CL} ${ANS}${action}${CL}"
            echo -e "${YW}No changes made.${CL}"
            exit 0
            ;;
        *)
            msg_error "Unable to determine selected disk action state."
            ;;
    esac
}
function prepare_names_from_existing_context() {
    VG_NAME="${SELECTED_EXISTING_VG:-$VG_NAME_DEFAULT}"
    THINPOOL_NAME="${SELECTED_EXISTING_THINPOOL:-$THINPOOL_NAME_DEFAULT}"
    STORAGE_ID="${SELECTED_EXISTING_STORAGE_ID:-$STORAGE_ID_DEFAULT}"
    CONTENT_TYPES="${SELECTED_EXISTING_CONTENT:-$CONTENT_TYPES}"
}

function run_existing_storage_validate_register_path() {
    local vg_parent_disks=""

    prepare_names_from_existing_context

    section "VALIDATE / REGISTER EXISTING STORAGE"

    if ! expected_vg_exists; then
        msg_error "Expected VG ${VG_NAME} is missing. Cancelled without wiping."
    fi

    if ! expected_thinpool_exists; then
        msg_error "Expected thinpool ${VG_NAME}/${THINPOOL_NAME} is missing. Cancelled without wiping."
    fi

    vg_parent_disks="$(get_parent_disks_for_vg "$VG_NAME" | xargs || true)"
    if [ "$vg_parent_disks" != "$SELECTED_DISK_NAME" ]; then
        msg_error "VG ${VG_NAME} is not backed only by selected disk ${SELECTED_DISK}. Actual parent disk(s): ${vg_parent_disks:-unknown}"
    fi

    if storage_id_exists "$STORAGE_ID"; then
        validate_registered_storage "$STORAGE_ID" "$VG_NAME" "$THINPOOL_NAME" "$CONTENT_TYPES"
    else
        register_proxmox_storage
    fi

    populate_selected_disk_from_expected_vg
    apply_trim_logic
    apply_io_scheduler_tuning
    apply_memory_tuning
    write_completion_marker
    create_verification_report
    show_final_summary
    exit 0
}

# =========================================================
#  DISK AUDIT / SELECTION
# =========================================================

# --- 33. DISK AUDIT BUILDER ---
# Builds safe and blocked disk lists.
# Root/boot/proxmox-storage and mounted disks are blocked from selection.
# Existing LVM PV-backed secondary disks are selectable only as destructive reuse candidates.
function audit_disks() {
    local name=""
    local size=""
    local type=""
    local tran=""
    local rota=""
    local model=""
    local line=""
    local reason=""
    local risk_report=""
    local risk_inline=""

    section "DISK AUDIT"

    msg_info "Building blocked disk safety list"
    build_blocked_disk_lists
    msg_ok "BLOCKED DISK SAFETY LIST BUILT"

    msg_info "Auditing available physical disks"

    SAFE_DISKS=()
    BLOCKED_DISKS=()

    while read -r line; do
        [ -z "$line" ] && continue

        name="$(echo "$line" | awk '{print $1}')"
        size="$(echo "$line" | awk '{print $2}')"
        type="$(echo "$line" | awk '{print $3}')"
        tran="$(echo "$line" | awk '{print $4}')"
        rota="$(echo "$line" | awk '{print $5}')"
        model="$(echo "$line" | cut -d' ' -f6- | xargs)"

        [ "$type" != "disk" ] && continue

        if [[ " ${BLOCKED_PARENT_DISKS} " == *" ${name} "* ]]; then
            reason="$(get_disk_block_reason "$name")"
            BLOCKED_DISKS+=("${name}|${size}|${tran:-unknown}|${rota}|${model:-unknown}|${reason}")
        else
            risk_report="$(build_data_risk_report "/dev/${name}" || true)"
            if [ -n "$risk_report" ]; then
                risk_inline="$(echo "$risk_report" | paste -sd ';' - | sed 's/;/; /g')"
                SAFE_DISKS+=("${name}|${size}|${tran:-unknown}|${rota}|${model:-unknown}|destructive-reuse|${risk_inline}")
            else
                SAFE_DISKS+=("${name}|${size}|${tran:-unknown}|${rota}|${model:-unknown}|clean|none")
            fi
        fi
    done < <(lsblk -dn -o NAME,SIZE,TYPE,TRAN,ROTA,MODEL)

    if [ "${#SAFE_DISKS[@]}" -eq 0 ]; then
        echo ""
        echo -e "${RD}No selectable physical disks were found.${CL}"
        echo -e "${YW}Blocked disks:${CL}"

        for line in "${BLOCKED_DISKS[@]}"; do
            IFS='|' read -r name size tran rota model reason <<< "$line"
            echo "  /dev/${name} | ${size} | ${model} | reason=${reason}"
        done

        msg_error "No selectable disk candidates available."
    fi

    msg_ok "DISK AUDIT COMPLETE"
}

# Prints readable risk bullets once in selected disk inspection.
function print_selected_data_risk_report() {
    local risk_report="$1"
    local warning=""
    local normalized=""

    echo -e "${YW}Data that will be removed:${CL}"

    if [ -z "$risk_report" ]; then
        echo -e "  ${GN}-${CL} none detected"
        return 0
    fi

    while IFS= read -r warning; do
        warning="$(echo "$warning" | xargs)"
        [ -z "$warning" ] && continue

        case "$warning" in
            "filesystem/partition signatures detected")
                normalized="filesystem/partition signatures"
                ;;
            "child partitions/devices detected ("*")")
                normalized="$(echo "$warning" | sed -E 's/child partitions\/devices detected \(([0-9]+)\)/child partitions\/devices: \1/')"
                ;;
            "existing LVM PV/VG metadata detected (VGs: "*")")
                normalized="$(echo "$warning" | sed -E 's/existing LVM PV\/VG metadata detected \(VGs: ([^;]+); PVs: ([^)]+)\)/existing LVM metadata: VG=\1, PV=\2/')"
                ;;
            "existing LVM PV metadata detected ("*")")
                normalized="$(echo "$warning" | sed -E 's/existing LVM PV metadata detected \(([^)]+)\)/existing LVM metadata: PV=\1/')"
                ;;
            *)
                normalized="$warning"
                ;;
        esac

        echo -e "  ${YW}-${CL} ${normalized}"
    done <<< "$risk_report"
}

# --- 34. DISK LIST DISPLAY ---
# Displays safe selectable disks and blocked disks as readable cards.
function show_disk_lists() {
    local name=""
    local size=""
    local tran=""
    local rota=""
    local model=""
    local reason=""
    local dtype=""
    local entry_type=""
    local risk=""
    local bus_label=""

    echo ""
    echo -e "${BL}SELECTABLE DISKS:${CL}"

    for i in "${!SAFE_DISKS[@]}"; do
        IFS='|' read -r name size tran rota model entry_type risk <<< "${SAFE_DISKS[$i]}"

        if [ "$rota" == "0" ]; then
            dtype="SSD"
        else
            dtype="HDD"
        fi
        bus_label="${tran:-unknown}"
        bus_label="${bus_label^^}"

        if [ "$i" -gt 0 ]; then
            echo ""
        fi

        if [ "$entry_type" == "destructive-reuse" ]; then
            echo -e "  ${YW}$((i+1))) /dev/${name}${CL}"
        else
            echo -e "  ${BL}$((i+1))) /dev/${name}${CL}"
        fi
        echo -e "       ${BL}SIZE:${CL} ${GN}${size}${CL}"
        echo -e "       ${BL}TYPE/BUS:${CL} ${GN}${dtype} / ${bus_label}${CL}"
        echo -e "       ${BL}MODEL:${CL} ${GN}${model:-unknown}${CL}"

        if [ "$entry_type" == "destructive-reuse" ]; then
            echo -e "       ${BL}MODE:${CL} ${RD}DESTRUCTIVE REUSE${CL}"
            echo -e "       ${YW}DATA RISK: ${BL}${YW}Existing Metadata Detected${CL}"
        else
            echo -e "       ${BL}MODE:${CL} ${GN}clean storage candidate${CL}"
            echo -e "       ${BL}DATA RISK:${CL} ${GN}none detected${CL}"
        fi
    done

    if [ "${#BLOCKED_DISKS[@]}" -gt 0 ]; then
        echo ""
        echo -e "${RD}BLOCKED DISKS:${CL}"

        for i in "${!BLOCKED_DISKS[@]}"; do
            line="${BLOCKED_DISKS[$i]}"
            IFS='|' read -r name size tran rota model reason <<< "$line"
            if [ "$i" -gt 0 ]; then
                echo ""
            fi
            echo -e "  ${YW}/dev/${name}${CL}"
            echo -e "     ${BL}SIZE:${CL} ${GN}${size}${CL}"
            echo -e "     ${BL}MODEL:${CL} ${GN}${model:-unknown}${CL}"
            echo -e "     ${YW}REASON:${CL} ${reason}"
        done
    fi
}

# --- 35. DISK SELECTION ---
# Selects a safe disk using numeric validation.
function select_disk() {
    local disk_idx=""
    local selected_entry=""
    local selected_size=""
    local selected_model=""

    show_disk_lists
    echo ""
    disk_idx="$(timed_number_input "Select disk number to format" "1" "1" "${#SAFE_DISKS[@]}" "quiet")"
    echo -e "${BFR} ${CM} ${GN}Selected disk:${CL} ${ANS}${disk_idx}${CL}"

    selected_entry="${SAFE_DISKS[$((disk_idx-1))]}"
    SELECTED_DISK_NAME="$(echo "$selected_entry" | cut -d'|' -f1)"
    SELECTED_DISK="/dev/${SELECTED_DISK_NAME}"
    selected_size="$(echo "$selected_entry" | cut -d'|' -f2)"
    selected_model="$(echo "$selected_entry" | cut -d'|' -f5)"
    SELECTED_DISK_ENTRY_TYPE="$(echo "$selected_entry" | cut -d'|' -f6)"
    SELECTED_DISK_REUSE_REASON="$(echo "$selected_entry" | cut -d'|' -f7-)"

    : "$selected_size" "$selected_model"

    if [ ! -b "$SELECTED_DISK" ]; then
        msg_error "Selected disk is not a block device."
    fi
}
# --- 36. SELECTED DISK SMART DETECTION ---
# Detects SSD/HDD, NVMe/SATA/USB, disk size and existing signatures.
function inspect_selected_disk() {
    local rota=""
    local tran=""

    rota="$(lsblk -dn -o ROTA "$SELECTED_DISK" | xargs)"
    tran="$(lsblk -dn -o TRAN "$SELECTED_DISK" | xargs || true)"
    DISK_MODEL="$(lsblk -dn -o MODEL "$SELECTED_DISK" | xargs || true)"
    DISK_SIZE_BYTES="$(blockdev --getsize64 "$SELECTED_DISK")"
    DISK_SIZE_GB="$(( DISK_SIZE_BYTES / 1024 / 1024 / 1024 ))"

    if [ "$rota" == "0" ]; then
        IS_SSD="yes"
        DISK_TYPE="SSD"
    else
        IS_SSD="no"
        DISK_TYPE="HDD"
    fi

    if [[ "$(basename "$SELECTED_DISK")" =~ ^nvme ]]; then
        IS_NVME="yes"
        DISK_BUS="NVME"
    elif [ -n "$tran" ]; then
        DISK_BUS="${tran^^}"
    else
        DISK_BUS="UNKNOWN"
    fi

    EXISTING_VGS_ON_SELECTED_DISK="$(get_vgs_for_disk "$SELECTED_DISK" | xargs || true)"
    EXISTING_PVS_ON_SELECTED_DISK="$(get_pvs_for_disk "$SELECTED_DISK" | xargs || true)"
    DATA_RISK_REPORT="$(build_data_risk_report "$SELECTED_DISK")"

    if [ -n "$DATA_RISK_REPORT" ]; then
        HAS_DATA="yes"
    else
        HAS_DATA="no"
    fi

}

# --- 37. SELECTED DISK SUMMARY ---
# Shows selected disk details and one detailed risk report.
function show_selected_disk_summary() {
    section "SELECTED DISK / STATUS"
    echo -e " ${CM} ${GN}SELECTED DISK INSPECTED${CL}"
    echo ""

    echo -e "${YW}Disk:${CL}"
    echo -e "  ${BL}Path:${CL} ${ANS}${SELECTED_DISK}${CL}"
    echo -e "  ${BL}Model:${CL} ${GN}${DISK_MODEL:-unknown}${CL}"
    echo -e "  ${BL}Type/Bus:${CL} ${GN}${DISK_TYPE} / ${DISK_BUS}${CL}"
    echo -e "  ${BL}Size:${CL} ${GN}${DISK_SIZE_GB} GB${CL}"
}

# --- 38. FIRST DESTRUCTIVE CONFIRMATION ---
# If disk has data, default is NO. If disk looks empty, default is YES.
function first_destructive_confirmation() {
    local proceed_yn=""

    if [ "$HAS_DATA" == "yes" ]; then
        proceed_yn="$(timed_yes_no "Destructively reuse ${SELECTED_DISK} for new Proxmox storage?" "n" "quiet")"
    else
        proceed_yn="$(timed_yes_no "Create Proxmox storage on empty disk ${SELECTED_DISK}?" "y" "quiet")"
    fi

    if [[ "$proceed_yn" =~ ^[Nn] ]]; then
        msg_error "Aborted by user."
    fi

    return 0
}

# =========================================================
#  STORAGE INPUTS
# =========================================================

# --- 39. ADAPTIVE STORAGE NAMING ---
# Generates defaults based on SSD/HDD/NVMe/SATA/USB.
function set_adaptive_storage_defaults() {
    # Keep Project circl8 fresh-deploy defaults stable regardless of disk type.
    # Snapshot readiness is handled by LVM-thin allocation/free-space reserve below,
    # not by changing the storage/VG/thinpool names per SSD/HDD/NVMe.
    VG_NAME_DEFAULT="vg_circl8_vm"
    THINPOOL_NAME_DEFAULT="circl8_vm_thin"
    STORAGE_ID_DEFAULT="circl8-vm"
}

function set_default_storage_values_for_resume() {
    set_adaptive_storage_defaults
    VG_NAME="$VG_NAME_DEFAULT"
    THINPOOL_NAME="$THINPOOL_NAME_DEFAULT"
    STORAGE_ID="$STORAGE_ID_DEFAULT"
    CONTENT_TYPES="images,rootdir"
}

# --- STORAGE CONFIG COLLECTION UI HELPERS ---
# Shows the collection header once, then clears that collection-only header before the final plan redraw.
function begin_storage_config_collection_once() {
    if [ "$STORAGE_CONFIG_COLLECTION_SHOWN" != "yes" ]; then
        section "STORAGE CONFIG / PLAN"
        STORAGE_CONFIG_COLLECTION_SHOWN="yes"
    fi
}

function clear_storage_config_collection_block() {
    [ "$STORAGE_CONFIG_COLLECTION_SHOWN" == "yes" ] || return 0

    if [ -w /dev/tty ]; then
        # Clear the collection-only section header: blank line, border, title, border.
        tty_print "\033[4A\033[K\033[1B\033[K\033[1B\033[K\033[1B\033[K\033[3A"
    fi

    STORAGE_CONFIG_COLLECTION_SHOWN="cleared"
}

# --- 40. STORAGE NAME INPUTS ---
# Collects VG, thinpool and Proxmox storage ID with validation.
function collect_storage_names() {
    local valid_names="no"

    begin_storage_config_collection_once

    set_adaptive_storage_defaults

    while [ "$valid_names" != "yes" ]; do
        VG_NAME="$(timed_text_input "Enter VG name" "$VG_NAME_DEFAULT" "quiet")"
        THINPOOL_NAME="$(timed_text_input "Enter thinpool name" "$THINPOOL_NAME_DEFAULT" "quiet")"
        STORAGE_ID="$(timed_text_input "Enter Proxmox storage ID" "$STORAGE_ID_DEFAULT" "quiet")"

        validate_name_or_error "VG name" "$VG_NAME" '^[a-zA-Z0-9_+.-]+$'
        validate_name_or_error "Thinpool name" "$THINPOOL_NAME" '^[a-zA-Z0-9_+.-]+$'
        validate_name_or_error "Storage ID" "$STORAGE_ID" '^[a-zA-Z0-9][a-zA-Z0-9_-]*$'

        reject_reserved_name_or_error "VG name" "$VG_NAME"
        reject_reserved_name_or_error "Thinpool name" "$THINPOOL_NAME"
        reject_reserved_name_or_error "Storage ID" "$STORAGE_ID"

        valid_names="yes"
    done
}

# --- 41. STORAGE SAFETY CHECK ---
# Prevents naming collisions with existing Proxmox storage, VGs or LVs.
function check_storage_conflicts() {
    local proxmox_refs=""
    local vg=""
    local vg_parent_disks=""
    local mounted_lvs=""

    if storage_id_exists "$STORAGE_ID"; then
        if storage_cfg_matches_expected "$STORAGE_ID" "$VG_NAME" "$THINPOOL_NAME" "$CONTENT_TYPES"; then
            if [ "$SELECTED_DISK_ACTION" == "recreate" ] && [[ " ${EXISTING_VGS_ON_SELECTED_DISK} " == *" ${VG_NAME} "* ]]; then
                :
            else
                msg_error "Proxmox storage ID ${STORAGE_ID} is already registered correctly. Choose validate/register existing storage instead of a destructive path."
            fi
        else
            echo ""
            echo -e "${RD}Proxmox storage ID ${STORAGE_ID} already exists but does not match the requested target.${CL}"
            echo -e "${YW}Existing storage.cfg block:${CL}"
            print_storage_cfg_block "$STORAGE_ID" | sed 's/^/  /'
            msg_error "Remove or rename the existing Proxmox storage before reusing this ID."
        fi
    fi

    if [ -n "$EXISTING_VGS_ON_SELECTED_DISK" ]; then
        for vg in $EXISTING_VGS_ON_SELECTED_DISK; do
            vg_parent_disks="$(get_parent_disks_for_vg "$vg" | xargs || true)"
            if [ "$vg_parent_disks" != "${SELECTED_DISK_NAME}" ]; then
                msg_error "Existing VG ${vg} spans disk(s): ${vg_parent_disks}. Refusing automatic destructive reuse; clean this VG manually first."
            fi
        done

        mounted_lvs="$(get_mounted_lvs_for_vgs "$EXISTING_VGS_ON_SELECTED_DISK")"
        if [ -n "$mounted_lvs" ]; then
            echo ""
            echo -e "${RD}Selected disk has mounted logical volume(s) in existing VG(s):${CL}"
            echo "$mounted_lvs" | sed 's/^/  - /'
            echo ""
            echo -e "${YW}Unmount/remove old mounts or clean the old VG manually first.${CL}"
            echo -e "${YW}This script will not auto-unmount mounted logical volumes.${CL}"
            msg_error "Refusing destructive reuse while selected-disk logical volumes are mounted."
        fi

        proxmox_refs="$(get_proxmox_storage_refs_for_vgs "$EXISTING_VGS_ON_SELECTED_DISK" | xargs || true)"
        if [ -n "$proxmox_refs" ]; then
            if [ "$SELECTED_DISK_ACTION" == "recreate" ]; then
                :
            else
                echo ""
                echo -e "${RD}Selected disk still backs existing Proxmox storage entries:${CL}"
                get_proxmox_storage_refs_for_vgs "$EXISTING_VGS_ON_SELECTED_DISK" | sed 's/^/  - /'
                echo ""
                echo -e "${YW}Choose validate/register existing storage or inspect manually before wiping.${CL}"
                msg_error "Refusing to wipe a disk referenced by existing Proxmox storage."
            fi
        fi
    fi

    if vgs "$VG_NAME" >/dev/null 2>&1; then
        if [[ " ${EXISTING_VGS_ON_SELECTED_DISK} " != *" ${VG_NAME} "* ]]; then
            msg_error "Volume group ${VG_NAME} already exists on another disk or unknown device."
        fi
    fi

    if lvs "${VG_NAME}/${THINPOOL_NAME}" >/dev/null 2>&1; then
        if [[ " ${EXISTING_VGS_ON_SELECTED_DISK} " != *" ${VG_NAME} "* ]]; then
            msg_error "Logical volume ${VG_NAME}/${THINPOOL_NAME} already exists outside the selected disk reuse scope."
        fi
    fi

}


# --- 42. EXPLICIT THINPOOL SIZING LOGIC ---
# Uses Script 1-style UI units: visible GB maps directly to LVM GiB-style units.
function ui_gb_to_lvm_mib() {
    local gb="$1"
    echo $(( gb * 1024 ))
}

function lvm_mib_to_ui_gb() {
    local mib="$1"
    echo $(( mib / 1024 ))
}

function get_actual_vg_free_mib() {
    local vg="${1:-$VG_NAME}"
    local raw=""

    raw="$(vgs --noheadings --units m --nosuffix -o vg_free "$vg" 2>/dev/null | awk 'NF {gsub(/[^0-9.]/, "", $1); printf "%d", $1; exit}' || true)"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        echo "$raw"
    else
        echo "0"
    fi
}

function get_actual_vg_free_gb() {
    lvm_mib_to_ui_gb "$(get_actual_vg_free_mib "${1:-$VG_NAME}")"
}

function get_thinpool_data_gb() {
    local vg="${1:-$VG_NAME}"
    local thinpool="${2:-$THINPOOL_NAME}"
    local raw=""

    raw="$(lvs --noheadings --units m --nosuffix -o lv_size "${vg}/${thinpool}" 2>/dev/null | awk 'NF {gsub(/[^0-9.]/, "", $1); printf "%d", $1; exit}' || true)"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        lvm_mib_to_ui_gb "$raw"
    else
        echo "0"
    fi
}

function get_thinpool_metadata_gb() {
    local vg="${1:-$VG_NAME}"
    local thinpool="${2:-$THINPOOL_NAME}"
    local raw=""

    raw="$(lvs -a --noheadings --units m --nosuffix -o lv_metadata_size "${vg}/${thinpool}" 2>/dev/null | awk 'NF {gsub(/[^0-9.]/, "", $1); printf "%d", $1; exit}' || true)"
    if ! [[ "$raw" =~ ^[0-9]+$ ]] || [ "$raw" -le 0 ]; then
        raw="$(lvs -a --noheadings --units m --nosuffix -o lv_size "${vg}/${thinpool}_tmeta" 2>/dev/null | awk 'NF {gsub(/[^0-9.]/, "", $1); printf "%d", $1; exit}' || true)"
    fi

    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        lvm_mib_to_ui_gb "$raw"
    else
        echo "0"
    fi
}

function default_vg_reserve_gb() {
    if [ "$DISK_SIZE_GB" -lt 256 ]; then
        echo "1"
    elif [ "$DISK_SIZE_GB" -lt 1024 ]; then
        echo "2"
    else
        echo "5"
    fi
}

function calculate_secondary_storage_plan() {
    local available_gb="${1:-$DISK_SIZE_GB}"

    THINPOOL_METADATA_MIB="$(ui_gb_to_lvm_mib "$THINPOOL_METADATA_GB")"
    VG_RESERVE_MIB="$(ui_gb_to_lvm_mib "$VG_RESERVE_GB")"
    VG_SAFETY_OVERHEAD_MIB="$(ui_gb_to_lvm_mib "$VG_SAFETY_OVERHEAD_GB")"
    THINPOOL_MAX_DATA_GB="$(( available_gb - THINPOOL_METADATA_GB - VG_RESERVE_GB - VG_SAFETY_OVERHEAD_GB ))"
    if [ "$THINPOOL_MAX_DATA_GB" -lt 0 ]; then
        THINPOOL_MAX_DATA_GB="0"
    fi
    THINPOOL_MAX_DATA_MIB="$(ui_gb_to_lvm_mib "$THINPOOL_MAX_DATA_GB")"

    if [ -z "${THINPOOL_DATA_GB:-}" ] || [ "$THINPOOL_DATA_GB" -le 0 ] || [ "$THINPOOL_DATA_GB" -gt "$THINPOOL_MAX_DATA_GB" ]; then
        THINPOOL_DATA_GB="$THINPOOL_MAX_DATA_GB"
    fi
    THINPOOL_DATA_MIB="$(ui_gb_to_lvm_mib "$THINPOOL_DATA_GB")"
}

function validate_secondary_storage_plan() {
    local available_gb="${1:-$DISK_SIZE_GB}"
    local total_gb="0"

    if [ "$THINPOOL_METADATA_GB" -le 0 ]; then
        msg_error "Thinpool metadata size must be greater than zero."
    fi

    if [ "$THINPOOL_DATA_GB" -le 0 ]; then
        msg_error "Thinpool data size must be greater than zero."
    fi

    total_gb="$(( THINPOOL_DATA_GB + THINPOOL_METADATA_GB + VG_RESERVE_GB + VG_SAFETY_OVERHEAD_GB ))"
    if [ "$total_gb" -gt "$available_gb" ]; then
        msg_error "Storage plan needs ${total_gb}GB including ${VG_SAFETY_OVERHEAD_GB}GB safety overhead, but only about ${available_gb}GB is available."
    fi
}

function display_storage_plan() {
    clear_storage_config_collection_block

    echo ""
    section "STORAGE CONFIG / PLAN"

    echo -e "${YW}Disk:${CL}"
    echo -e "  ${BL}Selected:${CL} ${ANS}${SELECTED_DISK}${CL}"
    echo -e "  ${BL}Model:${CL} ${GN}${DISK_MODEL:-unknown}${CL}"
    echo -e "  ${BL}Type/Bus:${CL} ${GN}${DISK_TYPE} / ${DISK_BUS}${CL}"
    echo -e "  ${BL}Size:${CL} ${GN}${DISK_SIZE_GB} GB${CL}"
    echo -e "  ${BL}Action:${CL} ${ANS}$(selected_disk_action_label)${CL}"
    if [ "$HAS_DATA" == "yes" ]; then
        echo -e "  ${BL}Data risk:${CL} ${RD}Destructive Reuse${CL}"
    else
        echo -e "  ${BL}Data risk:${CL} ${GN}None detected${CL}"
    fi
    echo ""

    echo -e "${YW}Storage:${CL}"
    echo -e "  ${BL}VG:${CL} ${ANS}${VG_NAME}${CL}"
    echo -e "  ${BL}Thinpool:${CL} ${ANS}${THINPOOL_NAME}${CL}"
    echo -e "  ${BL}Storage ID:${CL} ${ANS}${STORAGE_ID}${CL}"
    echo -e "  ${BL}Content:${CL} ${ANS}${CONTENT_TYPES}${CL}"
    echo ""

    echo -e "${YW}Sizing:${CL}"
    echo -e "  ${BL}Thinpool data:${CL} ${ANS}${THINPOOL_DATA_GB} GB${CL}"
    echo -e "  ${BL}Thinpool metadata:${CL} ${ANS}${THINPOOL_METADATA_GB} GB${CL}"
    echo -e "  ${BL}Reserve free VG:${CL} ${ANS}${VG_RESERVE_GB} GB${CL}"
    echo -e "  ${BL}Safety overhead:${CL} ${GN}${VG_SAFETY_OVERHEAD_GB} GB${CL}"
    echo -e "  ${BL}Max thinpool data:${CL} ${GN}${THINPOOL_MAX_DATA_GB} GB${CL}"
    echo ""

    echo -e "${YW}Final warning:${CL}"
    echo -e "  ${RD}All data on ${SELECTED_DISK} will be destroyed.${CL}"
    if [ "$SELECTED_DISK_ACTION" == "recreate" ]; then
        echo -e "  ${RD}Existing matching Proxmox storage on this disk will be replaced.${CL}"
    fi
}

function collect_thinpool_sizing() {
    local reserve_default=""

    begin_storage_config_collection_once

    reserve_default="$(default_vg_reserve_gb)"
    THINPOOL_METADATA_GB="$(timed_number_input "Set thinpool metadata size in GB" "1" "1" "" "quiet")"
    VG_RESERVE_GB="$(timed_number_input "Reserve free VG space in GB" "$reserve_default" "0" "" "quiet")"
    calculate_secondary_storage_plan "$DISK_SIZE_GB"

    if [ "$THINPOOL_MAX_DATA_GB" -le 0 ]; then
        msg_error "No space remains for thinpool data after ${THINPOOL_METADATA_GB}GB metadata and ${VG_RESERVE_GB}GB reserve."
    fi

    THINPOOL_DATA_GB="$(timed_number_input "Set thinpool data size in GB" "$THINPOOL_MAX_DATA_GB" "1" "$THINPOOL_MAX_DATA_GB" "quiet")"
    calculate_secondary_storage_plan "$DISK_SIZE_GB"
    validate_secondary_storage_plan "$DISK_SIZE_GB"
    display_storage_plan
}

function collect_thinpool_allocation() {
    collect_thinpool_sizing
}

# --- 43. CONTENT TYPE SELECTION ---
# Sets storage content types. Defaults support VM images, containers and backups.
function collect_content_types() {
    begin_storage_config_collection_once

    CONTENT_TYPES="$(timed_text_input "Enter Proxmox content types" "$CONTENT_TYPES" "quiet")"
    CONTENT_TYPES="$(echo "$CONTENT_TYPES" | tr -d ' ' | sed 's/,,*/,/g; s/^,//; s/,$//')"

    validate_content_types_or_error "$CONTENT_TYPES"
}

# --- 44. FINAL DESTRUCTIVE CONFIRMATION ---
# Final destructive confirmation before wiping disk.
function final_destructive_confirmation() {
    local final_yn=""

    echo ""
    final_yn="$(timed_yes_no "Proceed with disk wipe and storage creation?" "n")"
    if [[ "$final_yn" =~ ^[Nn] ]]; then
        msg_error "Aborted by user."
    fi

    return 0
}

# --- MATCHING STORAGE REGISTRATION REMOVAL FOR RECREATE ---
# Removes only Proxmox storage registrations that point to VG(s) on the selected disk after final confirmation.
function remove_matching_proxmox_storage_for_recreate() {
    local refs=""
    local ref=""
    local sid=""
    local vg=""
    local vg_parent_disks=""
    local mounted_lvs=""
    local removed="no"

    [ "$SELECTED_DISK_ACTION" == "recreate" ] || return 0

    begin_reset_section_once

    refs="$(get_proxmox_storage_refs_for_vgs "$EXISTING_VGS_ON_SELECTED_DISK" || true)"
    if [ -z "$refs" ]; then
        msg_ok "No old Proxmox storage registration to remove"
        return 0
    fi

    while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        sid="$(echo "$ref" | awk '{print $1}')"
        vg="$(echo "$ref" | awk '{print $4}')"
        [ -n "$sid" ] || continue
        [ -n "$vg" ] || msg_error "Could not determine VG for Proxmox storage reference: ${ref}"

        vg_parent_disks="$(get_parent_disks_for_vg "$vg" | xargs || true)"
        if [ "$vg_parent_disks" != "${SELECTED_DISK_NAME}" ]; then
            msg_error "Storage ${sid} points to VG ${vg} on disk(s) ${vg_parent_disks:-unknown}, not only ${SELECTED_DISK}."
        fi

        mounted_lvs="$(get_mounted_lvs_for_vgs "$vg")"
        if [ -n "$mounted_lvs" ]; then
            echo ""
            echo -e "${RD}Mounted logical volumes block safe storage removal:${CL}"
            echo "$mounted_lvs" | sed 's/^/  - /'
            msg_error "Refusing to remove storage ${sid} while logical volumes are mounted."
        fi

        msg_info "Removing old Proxmox storage registration"
        run_cmd "removing old Proxmox storage ${sid}" pvesm remove "$sid"
        msg_ok "Old Proxmox storage registration removed"
        removed="yes"
    done <<< "$refs"

    if [ "$removed" != "yes" ]; then
        msg_ok "No old Proxmox storage registration to remove"
    fi
}

# --- 45. EXISTING LVM CLEANUP ---
# Removes old VG/PV metadata on the selected disk only after explicit destructive confirmation.
function destroy_existing_lvm_on_selected_disk() {
    local vg=""
    local pv=""

    [ -n "$EXISTING_VGS_ON_SELECTED_DISK" ] || [ -n "$EXISTING_PVS_ON_SELECTED_DISK" ] || return 0

    begin_reset_section_once

    msg_info "Removing old LVM metadata"
    for vg in $EXISTING_VGS_ON_SELECTED_DISK; do
        run_cmd "removing existing volume group ${vg}" vgremove -ff -y "$vg"
    done

    for pv in $EXISTING_PVS_ON_SELECTED_DISK; do
        [ -b "$pv" ] || continue
        run_optional pvremove -ff -y "$pv"
    done

    run_optional pvscan --cache
    msg_ok "Old LVM metadata removed"
}
# --- 46. DISK WIPE ---
# Clears old filesystem, partition and LVM signatures.
# Failures are critical and stop the script.
function wipe_selected_disk() {
    begin_reset_section_once

    msg_info "Wiping filesystem signatures"
    run_cmd "wiping filesystem signatures on ${SELECTED_DISK}" wipefs -a "$SELECTED_DISK"
    msg_ok "Filesystem signatures wiped"

    msg_info "Zapping partition table"
    run_cmd "zapping partition table on ${SELECTED_DISK}" sgdisk --zap-all "$SELECTED_DISK"
    msg_ok "Partition table zapped"

    msg_info "Preparing disk"
    run_optional blockdev --rereadpt "$SELECTED_DISK"

    if command -v partprobe >/dev/null 2>&1; then
        run_optional partprobe "$SELECTED_DISK"
    fi

    if command -v udevadm >/dev/null 2>&1; then
        run_optional udevadm settle
    fi

    if command -v pvscan >/dev/null 2>&1; then
        run_optional pvscan --cache
    fi

    sleep 2
    msg_ok "Disk prepared"
}

# --- 46. LVM PHYSICAL VOLUME ---
# Creates an aligned LVM physical volume on the whole disk.
function create_lvm_physical_volume() {
    begin_create_section_once

    msg_info "Creating physical volume"
    run_cmd "creating LVM physical volume on ${SELECTED_DISK}" pvcreate -y --force "$SELECTED_DISK"
    PV_CREATED="yes"
    msg_ok "Physical volume created"
}
# --- 47. LVM VOLUME GROUP ---
# Creates dedicated VG for this secondary storage device.
function create_lvm_volume_group() {
    begin_create_section_once

    msg_info "Creating volume group"
    run_cmd "creating LVM volume group ${VG_NAME}" vgcreate -y "$VG_NAME" "$SELECTED_DISK"
    VG_CREATED="yes"
    msg_ok "Volume group created"
}
# --- 48. LVM THINPOOL CREATION ---
# Creates thinpool with adaptive free-space reserve and automatic metadata sizing.
function create_lvm_thinpool() {
    begin_create_section_once

    ACTUAL_VG_FREE_MIB="$(get_actual_vg_free_mib "$VG_NAME")"
    ACTUAL_VG_FREE_GB="$(lvm_mib_to_ui_gb "$ACTUAL_VG_FREE_MIB")"
    validate_secondary_storage_plan "$ACTUAL_VG_FREE_GB"

    msg_info "Creating thinpool"
    run_cmd "creating LVM thinpool ${VG_NAME}/${THINPOOL_NAME}" lvcreate -y -L "${THINPOOL_DATA_MIB}M" --poolmetadatasize "${THINPOOL_METADATA_GB}G" --thinpool "$THINPOOL_NAME" "$VG_NAME"
    THINPOOL_CREATED="yes"
    msg_ok "Thinpool created"

    msg_info "Enabling thinpool monitoring"
    run_optional lvchange --monitor y "${VG_NAME}/${THINPOOL_NAME}"
    msg_ok "Thinpool monitoring enabled"

    msg_info "Backing up LVM metadata"
    run_cmd "backing up LVM metadata for ${VG_NAME}" vgcfgbackup "$VG_NAME"
    msg_ok "LVM metadata backed up"
}

# --- 49. EXISTING STORAGE RESUME / IDEMPOTENCY ---
# Detects and handles the safe post-LVM/pre-registration recovery state.
function populate_selected_disk_from_expected_vg() {
    local pv=""
    local parent=""

    pv="$(pvs --noheadings -o pv_name --select "vg_name=${VG_NAME}" 2>/dev/null | xargs -n1 | head -n 1 || true)"
    [ -n "$pv" ] || return 0

    parent="$(get_parent_disk_name "$pv" || true)"
    [ -n "$parent" ] || return 0

    SELECTED_DISK_NAME="$parent"
    SELECTED_DISK="/dev/${parent}"

    if [ -b "$SELECTED_DISK" ]; then
        inspect_selected_disk
    fi

    if expected_thinpool_exists; then
        THINPOOL_DATA_GB="$(get_thinpool_data_gb "$VG_NAME" "$THINPOOL_NAME")"
        THINPOOL_METADATA_GB="$(get_thinpool_metadata_gb "$VG_NAME" "$THINPOOL_NAME")"
        THINPOOL_DATA_MIB="$(ui_gb_to_lvm_mib "${THINPOOL_DATA_GB:-0}")"
        THINPOOL_METADATA_MIB="$(ui_gb_to_lvm_mib "${THINPOOL_METADATA_GB:-0}")"
        ACTUAL_VG_FREE_GB="$(get_actual_vg_free_gb "$VG_NAME")"
        VG_RESERVE_GB="$ACTUAL_VG_FREE_GB"
        VG_RESERVE_MIB="$(ui_gb_to_lvm_mib "${VG_RESERVE_GB:-0}")"
    fi
}

function expected_vg_exists() {
    vgs "$VG_NAME" >/dev/null 2>&1
}

function expected_thinpool_exists() {
    lvs "${VG_NAME}/${THINPOOL_NAME}" >/dev/null 2>&1
}

function complete_existing_storage_success() {
    validate_registered_storage "$STORAGE_ID" "$VG_NAME" "$THINPOOL_NAME" "$CONTENT_TYPES"
    populate_selected_disk_from_expected_vg
    apply_trim_logic
    apply_io_scheduler_tuning
    apply_memory_tuning
    write_completion_marker
    create_verification_report
    show_final_summary
}

function handle_existing_storage_resume() {
    local recover_action=""

    section "EXISTING STORAGE RESUME CHECK"

    if storage_id_exists "$STORAGE_ID"; then
        msg_info "Found existing Proxmox storage ID ${STORAGE_ID}; validating"
        validate_registered_storage "$STORAGE_ID" "$VG_NAME" "$THINPOOL_NAME" "$CONTENT_TYPES"
        msg_ok "Existing storage ${STORAGE_ID} is already registered correctly. No destructive action required."
        complete_existing_storage_success
        exit 0
    fi

    if expected_vg_exists; then
        if ! expected_thinpool_exists; then
            msg_error "VG ${VG_NAME} exists but expected thinpool ${THINPOOL_NAME} is missing. Manual review required before rerun."
        fi

        echo ""
        echo -e "${YW}Existing VG/thinpool detected without Proxmox storage registration:${CL}"
        echo -e " ${BL}━━━━━▶${CL} VG: ${GN}${VG_NAME}${CL}"
        echo -e " ${BL}━━━━━▶${CL} THINPOOL: ${GN}${THINPOOL_NAME}${CL}"
        echo -e " ${BL}━━━━━▶${CL} STORAGE ID TO REGISTER: ${GN}${STORAGE_ID}${CL}"
        echo ""
        echo -e "${YW}Choose storage recovery action:${CL}"
        echo -e " ${BL}1)${CL} Register existing thinpool without wiping any disk"
        echo -e " ${BL}2)${CL} Wipe/recreate secondary disk storage"
        echo -e " ${BL}3)${CL} Exit without changes"
        echo ""

        recover_action="$(timed_number_input "Select action [1/2/3]" "1" "1" "3" "quiet")"

        case "$recover_action" in
            1)
                register_proxmox_storage
                complete_existing_storage_success
                exit 0
                ;;
            2)
                msg_ok "Wipe/recreate path selected."
                echo -e "${YW}Continuing to normal disk selection and wipe confirmation...${CL}"
                return 0
                ;;
            3)
                echo -e "${YW}No destructive action taken.${CL}"
                exit 0
                ;;
            *)
                msg_error "Invalid storage recovery action."
                ;;
        esac
    fi

    msg_ok "No existing ${STORAGE_ID}/${VG_NAME}/${THINPOOL_NAME} registration state detected; normal disk setup path will continue"
}

# --- 50. PROXMOX STORAGE REGISTRATION ---
# Registers the thinpool in Proxmox with selected content types.
function register_proxmox_storage() {
    if [ "$SELECTED_DISK_ACTION" == "validate-register" ]; then
        section "PROXMOX STORAGE REGISTRATION"
    else
        begin_create_section_once
    fi

    if storage_id_exists "$STORAGE_ID"; then
        msg_info "Proxmox storage ${STORAGE_ID} already exists; validating expected config"
        validate_registered_storage "$STORAGE_ID" "$VG_NAME" "$THINPOOL_NAME" "$CONTENT_TYPES"
        return 0
    fi

    msg_info "Registering Proxmox storage"

    run_cmd "registering Proxmox storage ${STORAGE_ID}" \
        pvesm add lvmthin "$STORAGE_ID" \
        --vgname "$VG_NAME" \
        --thinpool "$THINPOOL_NAME" \
        --content "$CONTENT_TYPES"

    validate_registered_storage "$STORAGE_ID" "$VG_NAME" "$THINPOOL_NAME" "$CONTENT_TYPES"

    msg_ok "Proxmox storage registered"
}
# --- 50. SSD TRIM LOGIC ---
# Enables fstrim timer only for SSD/NVMe devices.
function apply_trim_logic() {
    begin_tuning_section_once

    if [ "$IS_SSD" == "yes" ]; then
        msg_info "Enabling SSD TRIM"
        run_cmd "enabling fstrim.timer" systemctl enable --now fstrim.timer
        msg_ok "SSD TRIM ENABLED"
    else
        msg_ok "SSD TRIM NOT REQUIRED FOR HDD"
    fi
}

# --- 51. IO SCHEDULER SELECTOR ---
# Chooses a supported scheduler only when available.
function select_io_scheduler() {
    local dev_name="$1"
    local scheduler_file="/sys/block/${dev_name}/queue/scheduler"
    local supported=""

    IO_SCHEDULER="skip"

    if [ ! -e "$scheduler_file" ]; then
        return 0
    fi

    supported="$(cat "$scheduler_file" 2>/dev/null || true)"

    if [ "$IS_NVME" == "yes" ]; then
        if echo "$supported" | grep -qw "none"; then
            IO_SCHEDULER="none"
        elif echo "$supported" | grep -qw "mq-deadline"; then
            IO_SCHEDULER="mq-deadline"
        fi
    elif [ "$IS_SSD" == "yes" ]; then
        if echo "$supported" | grep -qw "mq-deadline"; then
            IO_SCHEDULER="mq-deadline"
        elif echo "$supported" | grep -qw "none"; then
            IO_SCHEDULER="none"
        fi
    else
        if echo "$supported" | grep -qw "mq-deadline"; then
            IO_SCHEDULER="mq-deadline"
        elif echo "$supported" | grep -qw "bfq"; then
            IO_SCHEDULER="bfq"
        fi
    fi
}

# --- 52. IO SCHEDULER LOGIC ---
# Applies and persists scheduler tuning only when the chosen scheduler is actually supported.
function apply_io_scheduler_tuning() {
    local dev_name=""
    local scheduler_file=""

    begin_tuning_section_once

    dev_name="$(basename "$SELECTED_DISK")"
    scheduler_file="/sys/block/${dev_name}/queue/scheduler"

    select_io_scheduler "$dev_name"

    if [ "$IO_SCHEDULER" == "skip" ]; then
        if [ -e "$scheduler_file" ]; then
            msg_warn "IO scheduler tuning skipped. Supported schedulers: $(cat "$scheduler_file" 2>/dev/null || echo unknown)"
        else
            msg_warn "IO scheduler tuning skipped. Scheduler file not present for ${dev_name}."
        fi
        return 0
    fi

    msg_info "Applying IO scheduler ${IO_SCHEDULER}"
    echo "$IO_SCHEDULER" > "$scheduler_file" 2>/dev/null || true
    msg_ok "IO SCHEDULER APPLIED (${IO_SCHEDULER})"

    IO_SCHEDULER_SERVICE="storage-${STORAGE_ID}-scheduler.service"

    msg_info "Writing IO scheduler systemd service"
    cat <<EOF > "/etc/systemd/system/${IO_SCHEDULER_SERVICE}"
[Unit]
Description=Apply IO Scheduler for ${STORAGE_ID}
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '[ -e /sys/block/${dev_name}/queue/scheduler ] && grep -qw "${IO_SCHEDULER}" /sys/block/${dev_name}/queue/scheduler && echo "${IO_SCHEDULER}" > /sys/block/${dev_name}/queue/scheduler || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    msg_ok "IO SCHEDULER SYSTEMD SERVICE WRITTEN"

    run_cmd "reloading systemd daemon" systemctl daemon-reload
    run_cmd "enabling ${IO_SCHEDULER_SERVICE}" systemctl enable "$IO_SCHEDULER_SERVICE"

    msg_ok "IO SCHEDULER TUNED (${IO_SCHEDULER})"
}

# --- 53. SWAPPINESS AND ZFS ARC SETTINGS ---
# Adds safe host-level memory defaults useful for VM/database workloads.
function apply_memory_tuning() {
    local total_mem_bytes=""
    local arc_max=""

    begin_tuning_section_once

    msg_info "Writing storage memory tuning sysctl file"
    cat <<EOF > /etc/sysctl.d/98-storage-memory-tuning.conf
vm.swappiness = 10
vm.vfs_cache_pressure = 100
EOF
    msg_ok "STORAGE MEMORY SYSCTL FILE WRITTEN"

    if [ -f /sys/module/zfs/parameters/zfs_arc_max ]; then
        msg_info "Writing ZFS ARC cap"
        total_mem_bytes="$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)"
        arc_max="$(( total_mem_bytes / 4 ))"

        cat <<EOF > /etc/modprobe.d/zfs-arc.conf
options zfs zfs_arc_max=${arc_max}
EOF
        msg_ok "ZFS ARC CAP WRITTEN"
    else
        msg_ok "ZFS ARC CAP NOT REQUIRED"
    fi

    msg_info "Applying sysctl settings"
    run_optional sysctl --system
    msg_ok "MEMORY TUNING APPLIED"
}

# =========================================================
#  VERIFICATION / MARKER / SUMMARY
# =========================================================

# --- 54. VERIFICATION SCRIPT ---
# Creates and runs a verification report after storage creation.
function create_verification_report() {
    local report_body=""
    local machine_log=""
    local selected_parent=""
    local pv_vg=""
    local vg_pvs=""
    local thin_attr=""
    local thin_active=""
    local thin_monitor=""
    local data_actual_mib="0"
    local metadata_actual_mib="0"
    local data_actual_gb="0"
    local metadata_actual_gb="0"
    local metadata_used_percent="unknown"
    local vg_free_mib="0"
    local vg_free_gb="0"
    local status_label=""
    local wipe_report=""
    local item=""
    local content_ok="yes"
    local scheduler_file=""
    local scheduler_actual="unknown"

    report_body="$(mktemp)"
    machine_log="$(mktemp)"
    TEMP_FILES+=("$report_body" "$machine_log")

    VERIFY_STATUS="PASS"
    VERIFY_PASS_COUNT="0"
    VERIFY_WARN_COUNT="0"
    VERIFY_FAIL_COUNT="0"

    verify_group() {
        echo "" >> "$report_body"
        echo -e "  ${YW}$1:${CL}" >> "$report_body"
    }

    verify_pass() {
        local key="$1"
        local label="$2"
        local actual="${3:-ok}"
        VERIFY_PASS_COUNT="$(( VERIFY_PASS_COUNT + 1 ))"
        echo "CHECK_${key}=PASS" >> "$machine_log"
        if [ -n "$actual" ]; then
            echo -e "    ${CM} ${GN}PASS${CL} - ${label}: ${GN}${actual}${CL}" >> "$report_body"
        else
            echo -e "    ${CM} ${GN}PASS${CL} - ${label}" >> "$report_body"
        fi
    }

    verify_warn() {
        local key="$1"
        local label="$2"
        local expected="$3"
        local actual="$4"
        local note="$5"
        VERIFY_WARN_COUNT="$(( VERIFY_WARN_COUNT + 1 ))"
        echo "CHECK_${key}=WARN" >> "$machine_log"
        echo "WARN_CHECK_${key}=expected ${expected}; actual ${actual}; note ${note}" >> "$machine_log"
        echo -e "    ${WARN} ${YW}WARN${CL} - ${label}" >> "$report_body"
        echo -e "      ${BL}expected:${CL} ${GN}${expected}${CL}" >> "$report_body"
        echo -e "      ${BL}actual:${CL} ${YW}${actual}${CL}" >> "$report_body"
        echo -e "      ${BL}note:${CL} ${YW}${note}${CL}" >> "$report_body"
    }

    verify_fail() {
        local key="$1"
        local label="$2"
        local expected="$3"
        local actual="$4"
        local fix="$5"
        VERIFY_FAIL_COUNT="$(( VERIFY_FAIL_COUNT + 1 ))"
        echo "CHECK_${key}=FAIL" >> "$machine_log"
        echo "FAIL_CHECK_${key}=expected ${expected}; actual ${actual}; fix ${fix}" >> "$machine_log"
        echo -e "    ${CROSS} ${RD}FAIL${CL} - ${label}" >> "$report_body"
        echo -e "      ${BL}expected:${CL} ${GN}${expected}${CL}" >> "$report_body"
        echo -e "      ${BL}actual:${CL} ${RD}${actual}${CL}" >> "$report_body"
        echo -e "      ${BL}fix:${CL} ${YW}${fix}${CL}" >> "$report_body"
    }

    size_close_mib() {
        local actual="$1"
        local expected="$2"
        local tolerance="${3:-128}"
        local diff="0"

        [ -z "$actual" ] && actual="0"
        [ -z "$expected" ] && expected="0"
        diff="$(( actual - expected ))"
        [ "$diff" -lt 0 ] && diff="$(( -diff ))"
        [ "$diff" -le "$tolerance" ]
    }

    get_lv_size_mib_for_verify() {
        local lv_path="$1"
        lvs --noheadings --units m --nosuffix -o lv_size "$lv_path" 2>/dev/null | awk 'NF {gsub(/[^0-9.]/, "", $1); printf "%d", $1; exit}' || true
    }

    get_thin_metadata_mib_for_verify() {
        local vg="$1"
        local thinpool="$2"
        local raw=""

        raw="$(lvs -a --noheadings --units m --nosuffix -o lv_metadata_size "${vg}/${thinpool}" 2>/dev/null | awk 'NF {gsub(/[^0-9.]/, "", $1); printf "%d", $1; exit}' || true)"
        if ! [[ "$raw" =~ ^[0-9]+$ ]] || [ "$raw" -le 0 ]; then
            raw="$(get_lv_size_mib_for_verify "${vg}/${thinpool}_tmeta")"
        fi
        if [[ "$raw" =~ ^[0-9]+$ ]]; then
            echo "$raw"
        else
            echo "0"
        fi
    }

    selected_parent="$(basename "$SELECTED_DISK")"
    pv_vg="$(pvs --noheadings -o vg_name "$SELECTED_DISK" 2>/dev/null | xargs || true)"
    vg_pvs="$(pvs --noheadings -o pv_name --select "vg_name=${VG_NAME}" 2>/dev/null | xargs || true)"
    thin_attr="$(lvs --noheadings -o lv_attr "${VG_NAME}/${THINPOOL_NAME}" 2>/dev/null | xargs || true)"
    thin_active="$(lvs --noheadings -o lv_active "${VG_NAME}/${THINPOOL_NAME}" 2>/dev/null | xargs || true)"
    thin_monitor="$(lvs --noheadings -o lv_monitor "${VG_NAME}/${THINPOOL_NAME}" 2>/dev/null | xargs || true)"
    data_actual_mib="$(get_lv_size_mib_for_verify "${VG_NAME}/${THINPOOL_NAME}")"
    metadata_actual_mib="$(get_thin_metadata_mib_for_verify "$VG_NAME" "$THINPOOL_NAME")"
    data_actual_gb="$(lvm_mib_to_ui_gb "${data_actual_mib:-0}")"
    metadata_actual_gb="$(lvm_mib_to_ui_gb "${metadata_actual_mib:-0}")"
    metadata_used_percent="$(lvs -a --noheadings -o metadata_percent "${VG_NAME}/${THINPOOL_NAME}" 2>/dev/null | awk 'NF {print $1; exit}' || true)"
    [ -n "$metadata_used_percent" ] || metadata_used_percent="unknown"
    vg_free_mib="$(get_actual_vg_free_mib "$VG_NAME")"
    vg_free_gb="$(lvm_mib_to_ui_gb "${vg_free_mib:-0}")"

    echo -e "${GN}NEW STORAGE SETUP VERIFICATION${CL}" >> "$report_body"
    echo "" >> "$report_body"
    echo -e "${YW}STORAGE TARGET:${CL}" >> "$report_body"
    echo -e "  ${BL}Disk:${CL} ${GN}${SELECTED_DISK}${CL}" >> "$report_body"
    echo -e "  ${BL}Model:${CL} ${GN}${DISK_MODEL:-unknown}${CL}" >> "$report_body"
    echo -e "  ${BL}Type/bus:${CL} ${GN}${DISK_TYPE} / ${DISK_BUS}${CL}" >> "$report_body"
    echo -e "  ${BL}Storage ID:${CL} ${GN}${STORAGE_ID}${CL}" >> "$report_body"
    echo -e "  ${BL}VG:${CL} ${GN}${VG_NAME}${CL}" >> "$report_body"
    echo -e "  ${BL}Thinpool:${CL} ${GN}${THINPOOL_NAME}${CL}" >> "$report_body"
    echo "" >> "$report_body"
    echo -e "${YW}SIZING:${CL}" >> "$report_body"
    echo -e "  ${BL}Thinpool data target:${CL} ${GN}${THINPOOL_DATA_GB} GB${CL}" >> "$report_body"
    echo -e "  ${BL}Thinpool data actual:${CL} ${GN}${data_actual_gb} GB${CL}" >> "$report_body"
    echo -e "  ${BL}Thinpool metadata target:${CL} ${GN}${THINPOOL_METADATA_GB} GB${CL}" >> "$report_body"
    echo -e "  ${BL}Thinpool metadata actual:${CL} ${GN}${metadata_actual_gb} GB${CL}" >> "$report_body"
    echo -e "  ${BL}Metadata usage:${CL} ${GN}${metadata_used_percent}${CL}" >> "$report_body"
    echo -e "  ${BL}Reserve free VG target:${CL} ${GN}${VG_RESERVE_GB} GB${CL}" >> "$report_body"
    echo -e "  ${BL}Safety overhead:${CL} ${GN}${VG_SAFETY_OVERHEAD_GB} GB${CL}" >> "$report_body"
    echo -e "  ${BL}VG free actual:${CL} ${GN}${vg_free_gb} GB${CL}" >> "$report_body"
    echo "" >> "$report_body"
    echo -e "${YW}SCRIPT 2 CHANGES VERIFIED:${CL}" >> "$report_body"

    verify_group "LVM changes"
    if [ -b "$SELECTED_DISK" ]; then
        verify_pass "SELECTED_DISK" "Selected disk" "block device exists"
    else
        verify_fail "SELECTED_DISK" "Selected disk" "${SELECTED_DISK} block device exists" "missing" "inspect disk path and rerun only after confirming hardware"
    fi

    if [ "$pv_vg" == "$VG_NAME" ]; then
        verify_pass "PV_EXISTS" "Physical volume" "created on selected disk"
    else
        verify_fail "PV_EXISTS" "Physical volume" "PV on ${SELECTED_DISK} assigned to ${VG_NAME}" "${pv_vg:-not found}" "inspect pvs/vgs before rerun"
    fi

    if vgs "$VG_NAME" >/dev/null 2>&1; then
        verify_pass "VG_EXISTS" "Volume group" "exists"
    else
        verify_fail "VG_EXISTS" "Volume group" "${VG_NAME} exists" "missing" "inspect LVM state before rerun"
    fi

    if echo "$vg_pvs" | grep -qw "$SELECTED_DISK"; then
        verify_pass "VG_ON_SELECTED_DISK" "Volume group disk" "uses selected disk"
    else
        verify_fail "VG_ON_SELECTED_DISK" "Volume group disk" "${VG_NAME} uses ${SELECTED_DISK}" "PVs: ${vg_pvs:-none}" "inspect pvs for unexpected devices"
    fi

    if lvs "${VG_NAME}/${THINPOOL_NAME}" >/dev/null 2>&1; then
        verify_pass "THINPOOL_EXISTS" "Thinpool" "exists"
    else
        verify_fail "THINPOOL_EXISTS" "Thinpool" "${VG_NAME}/${THINPOOL_NAME} exists" "missing" "inspect lvs before rerun"
    fi

    if [[ "$thin_attr" == t* ]]; then
        verify_pass "THINPOOL_ACTIVE" "Thinpool type" "thin pool attr ${thin_attr}"
    else
        verify_fail "THINPOOL_ACTIVE" "Thinpool type" "lv_attr begins with t" "${thin_attr:-unknown}" "inspect lvs -a and recreate manually if required"
    fi

    if [ "$thin_active" == "active" ]; then
        verify_pass "THINPOOL_LV_ACTIVE" "Thinpool active state" "active"
    else
        verify_fail "THINPOOL_LV_ACTIVE" "Thinpool active state" "active" "${thin_active:-unknown}" "run lvchange -ay after inspecting LVM state"
    fi

    if echo "$thin_monitor" | grep -qi monitored; then
        verify_pass "THINPOOL_MONITORING" "Thinpool monitoring" "enabled"
    else
        verify_warn "THINPOOL_MONITORING" "Thinpool monitoring" "monitored" "${thin_monitor:-unknown}" "enable with lvchange --monitor y ${VG_NAME}/${THINPOOL_NAME}"
    fi

    if [ -f "/etc/lvm/backup/${VG_NAME}" ]; then
        verify_pass "LVM_METADATA_BACKUP" "LVM metadata backup" "present"
    else
        verify_warn "LVM_METADATA_BACKUP" "LVM metadata backup" "backup file present" "missing" "run vgcfgbackup ${VG_NAME} after reviewing LVM state"
    fi

    verify_group "Proxmox storage changes"
    if pvesm status 2>/dev/null | awk '{print $1, $3}' | grep -q "^${STORAGE_ID} active"; then
        verify_pass "PVESM_STORAGE_ACTIVE" "pvesm storage" "active"
    else
        verify_fail "PVESM_STORAGE_ACTIVE" "pvesm storage" "${STORAGE_ID} active in pvesm status" "not active" "inspect pvesm status and storage.cfg"
    fi

    if storage_id_in_cfg "$STORAGE_ID"; then
        verify_pass "STORAGE_CFG_BLOCK" "storage.cfg block" "present"
    else
        verify_fail "STORAGE_CFG_BLOCK" "storage.cfg block" "lvmthin block for ${STORAGE_ID}" "missing" "register storage with pvesm add lvmthin"
    fi

    if [ "$(get_storage_cfg_field "$STORAGE_ID" vgname | xargs || true)" == "$VG_NAME" ]; then
        verify_pass "STORAGE_CFG_VGNAME" "storage.cfg vgname" "matches ${VG_NAME}"
    else
        verify_fail "STORAGE_CFG_VGNAME" "storage.cfg vgname" "${VG_NAME}" "$(get_storage_cfg_field "$STORAGE_ID" vgname | xargs || echo missing)" "fix storage.cfg or recreate registration"
    fi

    if [ "$(get_storage_cfg_field "$STORAGE_ID" thinpool | xargs || true)" == "$THINPOOL_NAME" ]; then
        verify_pass "STORAGE_CFG_THINPOOL" "storage.cfg thinpool" "matches ${THINPOOL_NAME}"
    else
        verify_fail "STORAGE_CFG_THINPOOL" "storage.cfg thinpool" "${THINPOOL_NAME}" "$(get_storage_cfg_field "$STORAGE_ID" thinpool | xargs || echo missing)" "fix storage.cfg or recreate registration"
    fi

    content_ok="yes"
    for item in ${CONTENT_TYPES//,/ }; do
        if ! storage_content_has_item "$(get_storage_cfg_field "$STORAGE_ID" content | xargs || true)" "$item"; then
            content_ok="no"
        fi
    done
    if [ "$content_ok" == "yes" ]; then
        verify_pass "STORAGE_CFG_CONTENT" "storage.cfg content" "matches ${CONTENT_TYPES}"
    else
        verify_fail "STORAGE_CFG_CONTENT" "storage.cfg content" "includes ${CONTENT_TYPES}" "$(get_storage_cfg_field "$STORAGE_ID" content | xargs || echo missing)" "update storage content list in Proxmox"
    fi

    verify_group "Sizing changes"
    if size_close_mib "${data_actual_mib:-0}" "$THINPOOL_DATA_MIB" "128"; then
        verify_pass "THINPOOL_DATA_SIZE" "Thinpool data size" "target ${THINPOOL_DATA_GB} GB, actual ${data_actual_gb} GB"
    else
        verify_fail "THINPOOL_DATA_SIZE" "Thinpool data size" "${THINPOOL_DATA_GB} GB" "${data_actual_gb} GB" "recreate or resize thinpool after reviewing LVM extents"
    fi

    if size_close_mib "${metadata_actual_mib:-0}" "$THINPOOL_METADATA_MIB" "128"; then
        verify_pass "THINPOOL_METADATA_SIZE" "Thinpool metadata size" "target ${THINPOOL_METADATA_GB} GB, actual ${metadata_actual_gb} GB"
    else
        verify_fail "THINPOOL_METADATA_SIZE" "Thinpool metadata size" "${THINPOOL_METADATA_GB} GB" "${metadata_actual_gb} GB" "recreate or extend thin metadata after reviewing LVM state"
    fi

    if [ "$metadata_used_percent" != "unknown" ]; then
        verify_pass "THINPOOL_METADATA_USAGE" "Thinpool metadata usage" "$metadata_used_percent"
    else
        verify_warn "THINPOOL_METADATA_USAGE" "Thinpool metadata usage" "readable metadata_percent" "unknown" "inspect lvs -a output"
    fi

    if [ "$vg_free_mib" -ge "$(( VG_RESERVE_MIB - 128 ))" ]; then
        verify_pass "VG_RESERVE" "VG reserve" "target ${VG_RESERVE_GB} GB, actual ${vg_free_gb} GB"
    elif [ "$vg_free_mib" -gt 0 ]; then
        verify_warn "VG_RESERVE" "VG reserve" ">= ${VG_RESERVE_GB} GB free" "${vg_free_gb} GB" "below display target but nonzero after ${VG_SAFETY_OVERHEAD_GB}GB safety overhead; inspect if future snapshots fail"
    else
        verify_fail "VG_RESERVE" "VG reserve" ">= ${VG_RESERVE_GB} GB free" "0 GB" "reduce thinpool size or extend VG"
    fi

    verify_group "Disk cleanup check"
    wipe_report="$(wipefs -n "$SELECTED_DISK" 2>/dev/null || true)"
    if echo "$wipe_report" | grep -Eiq 'ext[234]|xfs|zfs|linux_raid_member|mdraid|btrfs'; then
        verify_warn "DISK_RESIDUAL_SIGNATURES" "Residual old signatures" "only expected LVM metadata" "$(echo "$wipe_report" | tr '\n' ';' | cut -c1-180)" "review wipefs output; LVM signatures are expected, old filesystems are not"
    else
        verify_pass "DISK_RESIDUAL_SIGNATURES" "Residual old signatures" "no old filesystem/ZFS/mdraid signatures detected"
    fi

    verify_group "Tuning changes"
    if [ "$IS_SSD" == "yes" ]; then
        if systemctl is-enabled --quiet fstrim.timer && systemctl is-active --quiet fstrim.timer; then
            verify_pass "TRIM" "SSD TRIM" "enabled and active"
        else
            verify_fail "TRIM" "SSD TRIM" "fstrim.timer enabled and active" "not confirmed" "systemctl enable --now fstrim.timer"
        fi
    else
        verify_warn "TRIM" "SSD TRIM" "SSD/NVMe disk" "${DISK_TYPE}" "TRIM skipped for HDD; safe to continue"
    fi

    if [ "$IO_SCHEDULER" == "skip" ] || [ -z "$IO_SCHEDULER_SERVICE" ]; then
        verify_warn "IO_SCHEDULER" "IO scheduler" "supported scheduler" "skipped" "scheduler unsupported/unavailable; safe to continue"
    else
        if systemctl is-enabled --quiet "$IO_SCHEDULER_SERVICE"; then
            verify_pass "IO_SCHEDULER" "IO scheduler service" "enabled"
        else
            verify_warn "IO_SCHEDULER" "IO scheduler service" "${IO_SCHEDULER_SERVICE} enabled" "not enabled" "enable manually after checking scheduler support"
        fi

        scheduler_file="/sys/block/${SELECTED_DISK_NAME}/queue/scheduler"
        if [ -r "$scheduler_file" ]; then
            scheduler_actual="$(cat "$scheduler_file" 2>/dev/null || echo unknown)"
            if echo "$scheduler_actual" | grep -q "\[${IO_SCHEDULER}\]"; then
                verify_pass "IO_SCHEDULER_ACTIVE" "IO scheduler active value" "$IO_SCHEDULER"
            else
                verify_warn "IO_SCHEDULER_ACTIVE" "IO scheduler active value" "${IO_SCHEDULER}" "${scheduler_actual}" "service may apply on next boot or scheduler may be unavailable"
            fi
        else
            verify_warn "IO_SCHEDULER_ACTIVE" "IO scheduler active value" "readable scheduler file" "missing" "safe if device does not expose a scheduler file"
        fi
    fi

    if [ -f /etc/sysctl.d/98-storage-memory-tuning.conf ] && \
       grep -q '^vm\.swappiness[[:space:]]*=[[:space:]]*10' /etc/sysctl.d/98-storage-memory-tuning.conf && \
       grep -q '^vm\.vfs_cache_pressure[[:space:]]*=[[:space:]]*100' /etc/sysctl.d/98-storage-memory-tuning.conf; then
        verify_pass "MEMORY_TUNING" "Memory tuning" "sysctl file configured"
    else
        verify_fail "MEMORY_TUNING" "Memory tuning" "swappiness=10 and vfs_cache_pressure=100" "not confirmed" "re-run memory tuning or inspect /etc/sysctl.d/98-storage-memory-tuning.conf"
    fi

    if [ -f /sys/module/zfs/parameters/zfs_arc_max ]; then
        if [ -f /etc/modprobe.d/zfs-arc.conf ]; then
            verify_pass "ZFS_ARC" "ZFS ARC cap" "configured"
        else
            verify_warn "ZFS_ARC" "ZFS ARC cap" "zfs-arc.conf present" "missing" "ZFS module present; consider rerunning memory tuning"
        fi
    else
        verify_pass "ZFS_ARC" "ZFS ARC cap" "not required"
    fi

    verify_group "Marker"
    if [ -f "$COMPLETED_MARKER" ]; then
        if grep -q "STORAGE_ID=${STORAGE_ID}" "$COMPLETED_MARKER" && \
           grep -q "VG_NAME=${VG_NAME}" "$COMPLETED_MARKER" && \
           grep -q "THINPOOL_NAME=${THINPOOL_NAME}" "$COMPLETED_MARKER" && \
           grep -q "THINPOOL_DATA_GB=${THINPOOL_DATA_GB}" "$COMPLETED_MARKER" && \
           grep -q "THINPOOL_METADATA_GB=${THINPOOL_METADATA_GB}" "$COMPLETED_MARKER" && \
           grep -q "VG_RESERVE_GB=${VG_RESERVE_GB}" "$COMPLETED_MARKER" && \
           grep -q "VG_SAFETY_OVERHEAD_GB=${VG_SAFETY_OVERHEAD_GB}" "$COMPLETED_MARKER"; then
            verify_pass "COMPLETION_MARKER" "Completion marker" "present with sizing fields"
        else
            verify_warn "COMPLETION_MARKER" "Completion marker" "marker contains storage and sizing fields" "marker present but incomplete" "rewrite marker after confirming storage state"
        fi
    else
        verify_fail "COMPLETION_MARKER" "Completion marker" "$COMPLETED_MARKER present" "missing" "create marker after confirming storage state"
    fi

    if [ "$VERIFY_FAIL_COUNT" -gt 0 ]; then
        VERIFY_STATUS="${RD}FAIL${CL}"
    elif [ "$VERIFY_WARN_COUNT" -gt 0 ]; then
        VERIFY_STATUS="${YW}PASS_WITH_WARNINGS${CL}"
    else
        VERIFY_STATUS="${GN}PASS${CL}"
    fi

    {
        echo "SCRIPT2_VERIFY_VERSION=$SCRIPT_VERSION"
        echo "VERIFY_STATUS=$VERIFY_STATUS"
        echo "VERIFY_PASS_COUNT=$VERIFY_PASS_COUNT"
        echo "VERIFY_WARN_COUNT=$VERIFY_WARN_COUNT"
        echo "VERIFY_FAIL_COUNT=$VERIFY_FAIL_COUNT"
        echo "SCRIPT2_STATUS=completed"
        echo "SELECTED_DISK=$SELECTED_DISK"
        echo "DISK_TYPE=$DISK_TYPE"
        echo "DISK_BUS=$DISK_BUS"
        echo "DISK_MODEL=${DISK_MODEL:-unknown}"
        echo "DISK_SIZE_GB=$DISK_SIZE_GB"
        echo "STORAGE_ID=$STORAGE_ID"
        echo "VG_NAME=$VG_NAME"
        echo "THINPOOL_NAME=$THINPOOL_NAME"
        echo "THINPOOL_DATA_GB=$THINPOOL_DATA_GB"
        echo "THINPOOL_METADATA_GB=$THINPOOL_METADATA_GB"
        echo "THINPOOL_METADATA_USED_PERCENT=$metadata_used_percent"
        echo "VG_FREE_GB=$vg_free_gb"
        echo "VG_RESERVE_GB=$VG_RESERVE_GB"
        echo "VG_SAFETY_OVERHEAD_GB=$VG_SAFETY_OVERHEAD_GB"
        echo "CONTENT_TYPES=$CONTENT_TYPES"
        echo "IO_SCHEDULER=$IO_SCHEDULER"
        cat "$machine_log"
        echo "VERIFY_COMPLETE=yes"
        echo ""
        echo -e "${GN}NEW STORAGE SETUP VERIFICATION${CL}"
        echo ""
        echo -e "${YW}RESULT:${CL}"
        status_label="$VERIFY_STATUS"
        echo -e "  ${BL}Status:${CL} ${GN}${status_label}${CL}"
        echo -e "  ${BL}Failed checks:${CL} ${GN}${VERIFY_FAIL_COUNT}${CL}"
        echo -e "  ${BL}Warnings:${CL} ${GN}${VERIFY_WARN_COUNT}${CL}"
        cat "$report_body"
        echo ""
        echo -e "${YW}LOGS:${CL}"
        echo -e "  ${BL}Verify log:${CL} ${GN}${VERIFY_FILE}${CL}"
    } > "$VERIFY_FILE"

    rm -f "$report_body" "$machine_log"
}


# --- 55. COMPLETION MARKER ---
# Creates marker so later reruns can detect previous setup.
function write_completion_marker() {
    cat <<EOF > "$COMPLETED_MARKER"
New Storage Setup completed on: $(date)
Script 2 Marker Source of Truth: yes
Script Version: $SCRIPT_VERSION
Disk: $SELECTED_DISK
Disk Type: $DISK_TYPE
Disk Bus: $DISK_BUS
Disk Model: ${DISK_MODEL:-unknown}
Disk Size GB: $DISK_SIZE_GB
Selected Action: $(selected_disk_action_label)
Storage ID: $STORAGE_ID
VG: $VG_NAME
Thinpool: $THINPOOL_NAME
Thinpool Data GB: $THINPOOL_DATA_GB
Thinpool Metadata GB: $THINPOOL_METADATA_GB
Reserve Free VG GB: $VG_RESERVE_GB
Safety Overhead GB: $VG_SAFETY_OVERHEAD_GB
Content Types: $CONTENT_TYPES
IO Scheduler: $IO_SCHEDULER
Verify Log: $VERIFY_FILE
SCRIPT2_STATUS=completed
SELECTED_DISK_ACTION=$SELECTED_DISK_ACTION
STORAGE_ID=$STORAGE_ID
VG_NAME=$VG_NAME
THINPOOL_NAME=$THINPOOL_NAME
THINPOOL_DATA_GB=$THINPOOL_DATA_GB
THINPOOL_METADATA_GB=$THINPOOL_METADATA_GB
VG_RESERVE_GB=$VG_RESERVE_GB
VG_SAFETY_OVERHEAD_GB=$VG_SAFETY_OVERHEAD_GB
EOF

    COMPLETION_MARKER_WRITTEN="yes"
}

# --- 56. ISO NEXT STEP REMINDER ---
# Shows a non-blocking reminder before Script 3 / 3.5 so the Ubuntu Server ISO is ready.
function show_iso_next_step_reminder() {
    local proxmox_node="<proxmox-node>"
    local proxmox_ip=""

    proxmox_node="$(hostname -s 2>/dev/null || true)"
    [ -n "$proxmox_node" ] || proxmox_node="<proxmox-node>"

    if command -v ip >/dev/null 2>&1; then
        proxmox_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}' || true)"
    fi

    if [ -z "$proxmox_ip" ]; then
        proxmox_ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
    fi

    [ -n "$proxmox_ip" ] || proxmox_ip="<proxmox-ip>"

    section "Next Step"

    echo -e "${YW}Upload Ubuntu Server ISO:${CL}"
    echo ""
    echo -e "  ${BL}Proxmox Web UI:${CL}"
    echo -e "    ${GN}https://${proxmox_ip}:8006{CL}${DGN} > ${proxmox_node} > local > ISO Images > Upload${CL}"
    echo ""
    echo -e "  ${BL}Or copy from your laptop:${CL}"
    echo -e "    ${GN}scp /path/to/ubuntu-live-server.iso${CL} ${DGN}root@${proxmox_ip}:/var/lib/vz/template/iso/${CL}"
    echo ""
    echo -e "  ${YW}Then run Script 3.${CL}"
    echo ""
}
# --- 57. FINAL SUMMARY ---
# Shows final storage details.
function show_final_summary() {
    section_flash_success "FINISHED"

    if [ "$COMPLETION_MARKER_WRITTEN" == "yes" ]; then
        echo -e " ${CM} ${GN}COMPLETION MARKER WRITTEN${CL}"
    fi

    echo ""
    echo -e "${YW}Disk:${CL}"
    echo -e "  ${BL}Selected:${CL} ${GN}${SELECTED_DISK}${CL}"
    echo -e "  ${BL}Model:${CL} ${GN}${DISK_MODEL:-unknown}${CL}"
    echo -e "  ${BL}Type/Bus:${CL} ${GN}${DISK_TYPE} / ${DISK_BUS}${CL}"
    echo -e "  ${BL}Size:${CL} ${GN}${DISK_SIZE_GB} GB${CL}"
    echo -e "  ${BL}Action:${CL} ${ANS}$(selected_disk_action_label)${CL}"
    echo ""

    echo -e "${YW}Storage:${CL}"
    echo -e "  ${BL}VG:${CL} ${GN}${VG_NAME}${CL}"
    echo -e "  ${BL}Thinpool:${CL} ${GN}${THINPOOL_NAME}${CL}"
    echo -e "  ${BL}Storage ID:${CL} ${GN}${STORAGE_ID}${CL}"
    echo -e "  ${BL}Content:${CL} ${GN}${CONTENT_TYPES}${CL}"
    echo ""

    echo -e "${YW}Sizing:${CL}"
    echo -e "  ${BL}Thinpool data:${CL} ${GN}${THINPOOL_DATA_GB} GB${CL}"
    echo -e "  ${BL}Thinpool metadata:${CL} ${GN}${THINPOOL_METADATA_GB} GB${CL}"
    echo -e "  ${BL}Reserve free VG:${CL} ${GN}${VG_RESERVE_GB} GB${CL}"
    echo ""

    echo -e "${YW}Verification:${CL}"
    echo -e "  ${BL}Status:${CL} ${GN}${VERIFY_STATUS}${CL}"
    echo -e "  ${BL}Verify log:${CL} ${GN}${VERIFY_FILE}${CL}"

    show_iso_next_step_reminder
}

# --- 58. MAIN FUNCTION ---
# Runs validation -> safe disk selection -> configuration -> destructive apply -> verification.
function main() {
    init_script

    set_default_storage_values_for_resume

    audit_disks
    select_disk
    inspect_selected_disk
    choose_selected_disk_action

    if [ "$SELECTED_DISK_ACTION" == "validate-register" ]; then
        run_existing_storage_validate_register_path
    fi

    collect_storage_names
    check_storage_conflicts
    collect_content_types
    collect_thinpool_sizing
    final_destructive_confirmation

    remove_matching_proxmox_storage_for_recreate
    destroy_existing_lvm_on_selected_disk
    wipe_selected_disk
    create_lvm_physical_volume
    create_lvm_volume_group
    create_lvm_thinpool
    register_proxmox_storage

    apply_trim_logic
    apply_io_scheduler_tuning
    apply_memory_tuning

    write_completion_marker
    create_verification_report
    show_final_summary

    exit 0
}

main "$@"
