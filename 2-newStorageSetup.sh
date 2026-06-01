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
CL="$(printf '\033[m')"
CLF="$(printf '\033[5m')"
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
WARN="${YW}!${CL}"
CROSS="${RD}✗${CL}"
BORDER="${BL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"

SCRIPT_SOURCE="2-newStorageSetup.sh"
SCRIPT_VERSION="v1.3.4"
SCRIPT_UPDATED="2026-05-30"
SCRIPT_BUILD="pve923-warning-dedupe-display-polish"

# --- 2. GLOBAL VARIABLES ---
# Stores timer values, logs, selected disk state, LVM/Proxmox storage values and tuning state.
T=15
LOG_FILE="/var/log/new-storage-setup.log"
VERIFY_FILE="/var/log/new-storage-setup-verify.log"
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
THIN_PERCENT="95"

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

TEMP_FILES=()

# =========================================================
#  OUTPUT / LOGGING FUNCTIONS
# =========================================================

# --- 3. HEADER FUNCTION ---
# Displays the New Storage Setup ASCII banner.
function header_info {
echo -e "${BL}
███╗   ██╗███████╗██╗    ██╗    ███████╗████████╗ ██████╗ ██████╗  █████╗  ██████╗ ███████╗
████╗  ██║██╔════╝██║    ██║    ██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗██╔══██╗██╔════╝ ██╔════╝
██╔██╗ ██║█████╗  ██║ █╗ ██║    ███████╗   ██║   ██║   ██║██████╔╝███████║██║  ███╗█████╗  
██║╚██╗██║██╔══╝  ██║███╗██║    ╚════██║   ██║   ██║   ██║██╔══██╗██╔══██║██║   ██║██╔══╝  
██║ ╚████║███████╗╚███╔███╔╝    ███████║   ██║   ╚██████╔╝██║  ██║██║  ██║╚██████╔╝███████╗
╚═╝  ╚═══╝╚══════╝ ╚══╝╚══╝     ╚══════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
${CL}"
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

# --- 19. TIMED TEXT INPUT HELPER ---
# Shows wall-clock countdown.
# SPACE pauses with empty editable buffer.
# Any typed character pauses with that character already inside the editable buffer.
# Backspace/Delete can delete every typed character, including the first.
function timed_text_input() {
    local prompt="$1"
    local default="$2"
    local answer=""

    # Text/path/name inputs are deliberately NOT timed.
    # Countdown prompts are reserved only for simple Y/n decisions.
    # This prevents defaults being accepted while the user is away and gives enough time to type/paste.
    answer="$(editable_input_loop "$prompt" "$default" "no" "1" "" "")"
    [ -z "$answer" ] && answer="$default"

    tty_print "${BFR}"
    tty_println "${CM} ${GN}${prompt} ${answer}${CL}"

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
    local answer=""

    # Numeric inputs are deliberately NOT timed.
    # Countdown prompts are reserved only for simple Y/n decisions.
    while true; do
        answer="$(editable_input_loop "$prompt" "$default" "yes" "$min_value" "$max_value" "")"
        [ -z "$answer" ] && answer="$default"

        if validate_number "$answer" "$min_value" "$max_value"; then
            tty_print "${BFR}"
            tty_println "${CM} ${GN}${prompt} ${answer}${CL}"
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

    echo -e "${BL}Data that will be removed:${CL}"

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

        echo ""
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
            echo -e "       ${YW}DATA RISK:${CL} existing metadata detected"
        else
            echo -e "       ${BL}MODE:${CL} ${GN}clean storage candidate${CL}"
            echo -e "       ${BL}DATA RISK:${CL} ${GN}none detected${CL}"
        fi
    done

    if [ "${#BLOCKED_DISKS[@]}" -gt 0 ]; then
        echo ""
        echo -e "${RD}BLOCKED DISKS:${CL}"

        for line in "${BLOCKED_DISKS[@]}"; do
            IFS='|' read -r name size tran rota model reason <<< "$line"
            echo ""
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

    disk_idx="$(timed_number_input "Select disk number to format" "1" "1" "${#SAFE_DISKS[@]}")"

    selected_entry="${SAFE_DISKS[$((disk_idx-1))]}"
    SELECTED_DISK_NAME="$(echo "$selected_entry" | cut -d'|' -f1)"
    SELECTED_DISK="/dev/${SELECTED_DISK_NAME}"
    selected_size="$(echo "$selected_entry" | cut -d'|' -f2)"
    selected_model="$(echo "$selected_entry" | cut -d'|' -f5)"
    SELECTED_DISK_ENTRY_TYPE="$(echo "$selected_entry" | cut -d'|' -f6)"
    SELECTED_DISK_REUSE_REASON="$(echo "$selected_entry" | cut -d'|' -f7-)"

    if [ ! -b "$SELECTED_DISK" ]; then
        msg_error "Selected disk is not a block device."
    fi

    if [ "$SELECTED_DISK_ENTRY_TYPE" == "destructive-reuse" ]; then
        msg_ok "Selected disk for destructive reuse: ${SELECTED_DISK} - ${selected_model:-unknown} - ${selected_size}"
    else
        msg_ok "Selected disk for storage creation: ${SELECTED_DISK} - ${selected_model:-unknown} - ${selected_size}"
    fi
}

# --- 36. SELECTED DISK SMART DETECTION ---
# Detects SSD/HDD, NVMe/SATA/USB, disk size and existing signatures.
function inspect_selected_disk() {
    local rota=""
    local tran=""

    section "SELECTED DISK INSPECTION"

    msg_info "Inspecting selected disk"

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

    msg_ok "SELECTED DISK INSPECTED"
}

# --- 37. SELECTED DISK SUMMARY ---
# Shows selected disk details and one detailed risk report.
function show_selected_disk_summary() {
    echo ""
    echo -e "${BL}SELECTED DISK:${CL}"
    echo -e " ${BL}━━━━━▶${CL} DISK: ${GN}${SELECTED_DISK}${CL}"
    echo -e " ${BL}━━━━━▶${CL} MODEL: ${GN}${DISK_MODEL:-unknown}${CL}"
    echo -e " ${BL}━━━━━▶${CL} TYPE/BUS: ${GN}${DISK_TYPE} / ${DISK_BUS}${CL}"
    echo -e " ${BL}━━━━━▶${CL} SIZE: ${GN}${DISK_SIZE_GB}GB${CL}"
    echo -e " ${BL}━━━━━▶${CL} SELECTION MODE: ${GN}${SELECTED_DISK_ENTRY_TYPE}${CL}"
    echo ""
    print_selected_data_risk_report "$DATA_RISK_REPORT"

    if [ "$HAS_DATA" == "yes" ]; then
        echo ""
        echo -e "${RD}WARNING: Continuing will erase/recreate storage on ${SELECTED_DISK}.${CL}"
    fi
}


# --- 38. FIRST DESTRUCTIVE CONFIRMATION ---
# If disk has data, default is NO. If disk looks empty, default is YES.
function first_destructive_confirmation() {
    local proceed_yn=""

    if [ "$HAS_DATA" == "yes" ]; then
        echo ""
        echo -e "${RD}WARNING: Existing data, partitions, signatures, or LVM metadata were detected on ${SELECTED_DISK}.${CL}"
        if [ -n "$EXISTING_VGS_ON_SELECTED_DISK" ]; then
            echo -e "${RD}Existing VG(s) on selected disk:${CL} ${YW}${EXISTING_VGS_ON_SELECTED_DISK}${CL}"
            echo -e "${RD}Old PV/VG/LV metadata on this disk will be destroyed if you continue.${CL}"
        fi
        proceed_yn="$(timed_yes_no "Destructively reuse ${SELECTED_DISK} for new Proxmox storage?" "n")"
        if [[ "$proceed_yn" =~ ^[Nn] ]]; then
            msg_error "Aborted by user."
        fi
    else
        proceed_yn="$(timed_yes_no "Create Proxmox storage on empty disk ${SELECTED_DISK}?" "y")"
        if [[ "$proceed_yn" =~ ^[Nn] ]]; then
            msg_error "Aborted by user."
        fi
    fi

    return 0
}

# =========================================================
#  STORAGE CONFIGURATION INPUTS
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

# --- 40. STORAGE NAME INPUTS ---
# Collects VG, thinpool and Proxmox storage ID with validation.
function collect_storage_names() {
    local valid_names="no"

    section "STORAGE CONFIGURATION"

    set_adaptive_storage_defaults

    while [ "$valid_names" != "yes" ]; do
        VG_NAME="$(timed_text_input "Enter VG name" "$VG_NAME_DEFAULT")"
        THINPOOL_NAME="$(timed_text_input "Enter thinpool name" "$THINPOOL_NAME_DEFAULT")"
        STORAGE_ID="$(timed_text_input "Enter Proxmox storage ID" "$STORAGE_ID_DEFAULT")"

        validate_name_or_error "VG name" "$VG_NAME" '^[a-zA-Z0-9_+.-]+$'
        validate_name_or_error "Thinpool name" "$THINPOOL_NAME" '^[a-zA-Z0-9_+.-]+$'
        validate_name_or_error "Storage ID" "$STORAGE_ID" '^[a-zA-Z0-9][a-zA-Z0-9_-]*$'

        reject_reserved_name_or_error "VG name" "$VG_NAME"
        reject_reserved_name_or_error "Thinpool name" "$THINPOOL_NAME"
        reject_reserved_name_or_error "Storage ID" "$STORAGE_ID"

        valid_names="yes"
    done
}

# --- 41. STORAGE CONFLICT CHECK ---
# Prevents naming collisions with existing Proxmox storage, VGs or LVs.
function check_storage_conflicts() {
    local proxmox_refs=""
    local vg=""
    local vg_parent_disks=""
    local mounted_lvs=""

    section "CONFLICT CHECK"

    msg_info "Checking for storage conflicts"

    if storage_id_exists "$STORAGE_ID"; then
        if storage_cfg_matches_expected "$STORAGE_ID" "$VG_NAME" "$THINPOOL_NAME" "$CONTENT_TYPES"; then
            msg_error "Proxmox storage ID ${STORAGE_ID} is already registered correctly. Refusing destructive path; rerun should use resume/success path instead."
        fi

        echo ""
        echo -e "${RD}Proxmox storage ID ${STORAGE_ID} already exists but does not match the requested target.${CL}"
        echo -e "${YW}Existing storage.cfg block:${CL}"
        print_storage_cfg_block "$STORAGE_ID" | sed 's/^/  /'
        msg_error "Remove or rename the existing Proxmox storage before reusing this ID."
    fi

    if [ -n "$EXISTING_VGS_ON_SELECTED_DISK" ]; then
        proxmox_refs="$(get_proxmox_storage_refs_for_vgs "$EXISTING_VGS_ON_SELECTED_DISK" | xargs || true)"
        if [ -n "$proxmox_refs" ]; then
            echo ""
            echo -e "${RD}Selected disk still backs existing Proxmox storage entries:${CL}"
            get_proxmox_storage_refs_for_vgs "$EXISTING_VGS_ON_SELECTED_DISK" | sed 's/^/  - /'
            echo ""
            echo -e "${YW}Remove those Proxmox storage entries first, for example:${CL}"
            echo -e "  ${GN}pvesm remove <storage-id>${CL}"
            msg_error "Refusing to wipe a disk referenced by existing Proxmox storage."
        fi

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

        echo ""
        echo -e "${BL}Selected disk cleanup planned:${CL}"
        for vg in $EXISTING_VGS_ON_SELECTED_DISK; do
            echo -e "  ${YW}-${CL} remove existing VG ${vg} from ${SELECTED_DISK}"
        done
        echo -e "  ${YW}-${CL} create new Proxmox storage using the names selected above"
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

    echo ""
    echo -e "${BL}New storage to create:${CL}"
    echo -e "  ${BL}VG:${CL} ${GN}${VG_NAME}${CL}"
    echo -e "  ${BL}Thinpool:${CL} ${GN}${THINPOOL_NAME}${CL}"
    echo -e "  ${BL}Proxmox storage ID:${CL} ${GN}${STORAGE_ID}${CL}"

    msg_ok "No blocking conflicts outside the selected disk."
}


# --- 42. THINPOOL ALLOCATION LOGIC ---
# Uses adaptive allocation to leave free VG space for metadata growth and repair.
# Validates the final value to avoid failure after disk wipe.
function collect_thinpool_allocation() {
    if [ "$DISK_SIZE_GB" -lt 256 ]; then
        THIN_PERCENT="95"
    elif [ "$DISK_SIZE_GB" -lt 1024 ]; then
        THIN_PERCENT="92"
    else
        THIN_PERCENT="90"
    fi

    THIN_PERCENT="$(timed_number_input "Enter thinpool allocation percent" "$THIN_PERCENT" "50" "98")"
}

# --- 43. CONTENT TYPE SELECTION ---
# Sets storage content types. Defaults support VM images, containers and backups.
function collect_content_types() {
    CONTENT_TYPES="$(timed_text_input "Enter Proxmox content types" "$CONTENT_TYPES")"
    CONTENT_TYPES="$(echo "$CONTENT_TYPES" | tr -d ' ' | sed 's/,,*/,/g; s/^,//; s/,$//')"

    validate_content_types_or_error "$CONTENT_TYPES"
}

# --- 44. FINAL DESTRUCTIVE CONFIRMATION ---
# Final destructive confirmation before wiping disk.
function final_destructive_confirmation() {
    local final_yn=""

    section "READY TO CREATE STORAGE"

    echo -e "${RD}FINAL WARNING: ALL DATA ON ${SELECTED_DISK} WILL BE DESTROYED.${CL}"
    echo ""
    echo -e "${BL}DISK SAFETY CONTEXT:${CL}"
    echo -e " ${BL}━━━━━▶${CL} ROOT / BOOT / PVE DISKS: ${GN}${ROOT_PARENT_DISKS:-none}${CL}"
    echo -e " ${BL}━━━━━▶${CL} MOUNTED DISKS: ${GN}${MOUNTED_PARENT_DISKS:-none}${CL}"
    echo -e " ${BL}━━━━━▶${CL} EXISTING LVM PV DISKS: ${GN}${PV_PARENT_DISKS:-none}${CL}"
    echo -e " ${BL}━━━━━▶${CL} SELECTED DISK EXISTING VG(S): ${GN}${EXISTING_VGS_ON_SELECTED_DISK:-none}${CL}"
    echo ""
    echo -e "${BL}SELECTED STORAGE TARGET:${CL}"
    echo -e " ${BL}━━━━━▶${CL} DISK: ${GN}${SELECTED_DISK}${CL}"
    echo -e " ${BL}━━━━━▶${CL} MODEL: ${GN}${DISK_MODEL:-unknown}${CL}"
    echo -e " ${BL}━━━━━▶${CL} SIZE: ${GN}${DISK_SIZE_GB}GB${CL}"
    echo -e " ${BL}━━━━━▶${CL} STORAGE ID: ${GN}${STORAGE_ID}${CL}"
    echo -e " ${BL}━━━━━▶${CL} VG / THINPOOL: ${GN}${VG_NAME} / ${THINPOOL_NAME}${CL}"
    echo -e " ${BL}━━━━━▶${CL} THIN ALLOCATION: ${GN}${THIN_PERCENT}%FREE${CL}"
    echo -e " ${BL}━━━━━▶${CL} CONTENT: ${GN}${CONTENT_TYPES}${CL}"
    echo ""

    final_yn="$(timed_yes_no "Proceed with disk wipe and storage creation?" "n")"
    if [[ "$final_yn" =~ ^[Nn] ]]; then
        msg_error "Aborted by user."
    fi

    return 0

    return 0
}


# --- 45. EXISTING LVM CLEANUP ---
# Removes old VG/PV metadata on the selected disk only after explicit destructive confirmation.
function destroy_existing_lvm_on_selected_disk() {
    local vg=""
    local pv=""

    [ -n "$EXISTING_VGS_ON_SELECTED_DISK" ] || [ -n "$EXISTING_PVS_ON_SELECTED_DISK" ] || return 0

    section "EXISTING LVM CLEANUP"

    echo -e "${RD}Removing old LVM metadata from selected disk only:${CL} ${GN}${SELECTED_DISK}${CL}"
    echo -e "${YW}Old VG(s):${CL} ${EXISTING_VGS_ON_SELECTED_DISK:-none}"
    echo -e "${YW}Old PV(s):${CL} ${EXISTING_PVS_ON_SELECTED_DISK:-unknown}"

    for vg in $EXISTING_VGS_ON_SELECTED_DISK; do
        run_cmd "removing existing volume group ${vg}" vgremove -ff -y "$vg"
    done

    # Also clear orphan PV metadata where a PV exists on the selected disk but no VG is attached.
    # This runs only after destructive confirmation and only for PV devices under SELECTED_DISK.
    for pv in $EXISTING_PVS_ON_SELECTED_DISK; do
        [ -b "$pv" ] || continue
        run_optional pvremove -ff -y "$pv"
    done

    run_optional pvscan --cache
    msg_ok "OLD LVM METADATA REMOVED"
}

# --- 46. DISK WIPE ---
# Clears old filesystem, partition and LVM signatures.
# Failures are critical and stop the script.
function wipe_selected_disk() {
    section "DISK WIPE"

    msg_info "Wiping filesystem signatures"
    run_cmd "wiping filesystem signatures on ${SELECTED_DISK}" wipefs -a "$SELECTED_DISK"
    msg_ok "FILESYSTEM SIGNATURES WIPED"

    msg_info "Zapping partition table"
    run_cmd "zapping partition table on ${SELECTED_DISK}" sgdisk --zap-all "$SELECTED_DISK"
    msg_ok "PARTITION TABLE ZAPPED"

    msg_info "Requesting kernel partition table reread"
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
    msg_ok "DISK PREPARED"
}


# --- 46. LVM PHYSICAL VOLUME ---
# Creates an aligned LVM physical volume on the whole disk.
function create_lvm_physical_volume() {
    section "LVM PHYSICAL VOLUME"

    msg_info "Creating LVM physical volume"
    run_cmd "creating LVM physical volume on ${SELECTED_DISK}" pvcreate -y --force "$SELECTED_DISK"
    PV_CREATED="yes"
    msg_ok "PHYSICAL VOLUME CREATED"
}

# --- 47. LVM VOLUME GROUP ---
# Creates dedicated VG for this secondary storage device.
function create_lvm_volume_group() {
    section "LVM VOLUME GROUP"

    msg_info "Creating LVM volume group"
    run_cmd "creating LVM volume group ${VG_NAME}" vgcreate -y "$VG_NAME" "$SELECTED_DISK"
    VG_CREATED="yes"
    msg_ok "VOLUME GROUP CREATED"
}

# --- 48. LVM THINPOOL CREATION ---
# Creates thinpool with adaptive free-space reserve and automatic metadata sizing.
function create_lvm_thinpool() {
    section "LVM THINPOOL"

    msg_info "Creating LVM thinpool"
    run_cmd "creating LVM thinpool ${VG_NAME}/${THINPOOL_NAME}" lvcreate -y -l "${THIN_PERCENT}%FREE" --thinpool "$THINPOOL_NAME" "$VG_NAME"
    THINPOOL_CREATED="yes"
    msg_ok "LVM THINPOOL CREATED"

    msg_info "Enabling LVM thinpool monitoring"
    run_optional lvchange --monitor y "${VG_NAME}/${THINPOOL_NAME}"
    msg_ok "LVM THINPOOL MONITORING ENABLED"

    msg_info "Backing up LVM metadata"
    run_cmd "backing up LVM metadata for ${VG_NAME}" vgcfgbackup "$VG_NAME"
    msg_ok "LVM METADATA BACKED UP"
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

        recover_action="$(timed_number_input "Select action [1/2/3]" "1" "1" "3")"

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
    section "PROXMOX STORAGE REGISTRATION"

    if storage_id_exists "$STORAGE_ID"; then
        msg_info "Proxmox storage ${STORAGE_ID} already exists; validating expected config"
        validate_registered_storage "$STORAGE_ID" "$VG_NAME" "$THINPOOL_NAME" "$CONTENT_TYPES"
        return 0
    fi

    msg_info "Registering storage in Proxmox"

    run_cmd "registering Proxmox storage ${STORAGE_ID}" \
        pvesm add lvmthin "$STORAGE_ID" \
        --vgname "$VG_NAME" \
        --thinpool "$THINPOOL_NAME" \
        --content "$CONTENT_TYPES"

    validate_registered_storage "$STORAGE_ID" "$VG_NAME" "$THINPOOL_NAME" "$CONTENT_TYPES"

    msg_ok "STORAGE REGISTERED"
}

# --- 50. SSD TRIM LOGIC ---
# Enables fstrim timer only for SSD/NVMe devices.
function apply_trim_logic() {
    section "SSD TRIM"

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

    section "IO SCHEDULER TUNING"

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

# --- 53. SWAPPINESS AND ZFS ARC TUNING ---
# Adds safe host-level memory defaults useful for VM/database workloads.
function apply_memory_tuning() {
    local total_mem_bytes=""
    local arc_max=""

    section "MEMORY TUNING"

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
    local verify_script="/root/new_storage_verify.sh"

    section "VERIFICATION"

    msg_info "Creating verification report"

    TEMP_FILES+=("$verify_script")

    cat <<EOF > "$verify_script"
#!/usr/bin/env bash
set +e
: > "$VERIFY_FILE"
exec > >(tee -a "$VERIFY_FILE") 2>&1

echo "--- NEW STORAGE SETUP VERIFICATION REPORT ---"
echo "Date: \$(date)"
echo "Disk: ${SELECTED_DISK}"
echo "Disk Type: ${DISK_TYPE}"
echo "Disk Bus: ${DISK_BUS}"
echo "Storage ID: ${STORAGE_ID}"
echo "VG: ${VG_NAME}"
echo "Thinpool: ${THINPOOL_NAME}"
echo ""

PASS() { echo "✓ PASS - \$1"; }
WARN() { echo "! WARN - \$1"; }
FAIL() { echo "✗ FAIL - \$1"; }

if pvesm status 2>/dev/null | awk '{print \$1, \$3}' | grep -q "^${STORAGE_ID} active"; then PASS "Proxmox storage is active"; else FAIL "Proxmox storage active state not confirmed"; fi
if awk '\$0 == "lvmthin: ${STORAGE_ID}" {found=1} END {exit found ? 0 : 1}' /etc/pve/storage.cfg 2>/dev/null; then PASS "storage.cfg block exists"; else FAIL "storage.cfg block missing"; fi
if awk '\$0 == "lvmthin: ${STORAGE_ID}" {in_block=1; next} in_block && /^[[:space:]]*$/ {in_block=0} in_block && /^[^[:space:]]/ {in_block=0} in_block && \$1 == "vgname" && \$2 == "${VG_NAME}" {found=1} END {exit found ? 0 : 1}' /etc/pve/storage.cfg 2>/dev/null; then PASS "storage.cfg vgname matches"; else FAIL "storage.cfg vgname mismatch"; fi
if awk '\$0 == "lvmthin: ${STORAGE_ID}" {in_block=1; next} in_block && /^[[:space:]]*$/ {in_block=0} in_block && /^[^[:space:]]/ {in_block=0} in_block && \$1 == "thinpool" && \$2 == "${THINPOOL_NAME}" {found=1} END {exit found ? 0 : 1}' /etc/pve/storage.cfg 2>/dev/null; then PASS "storage.cfg thinpool matches"; else FAIL "storage.cfg thinpool mismatch"; fi
if vgs "${VG_NAME}" >/dev/null 2>&1; then PASS "VG exists"; else FAIL "VG missing"; fi
if lvs "${VG_NAME}/${THINPOOL_NAME}" >/dev/null 2>&1; then PASS "Thinpool exists"; else FAIL "Thinpool missing"; fi
if lvs -o lv_monitor --noheadings "${VG_NAME}/${THINPOOL_NAME}" 2>/dev/null | grep -q monitored; then PASS "Thinpool monitoring enabled"; else WARN "Thinpool monitoring not confirmed"; fi
if [ -f "/etc/lvm/backup/${VG_NAME}" ]; then PASS "LVM metadata backup exists"; else WARN "LVM metadata backup not found"; fi

echo ""
echo "Proxmox storage status:"
pvesm status 2>/dev/null || true

echo ""
echo "Proxmox storage.cfg block:"
awk '\$0 == "lvmthin: ${STORAGE_ID}" {print; in_block=1; next} in_block && /^[[:space:]]*$/ {in_block=0} in_block && /^[^[:space:]]/ {in_block=0} in_block {print}' /etc/pve/storage.cfg 2>/dev/null || true

echo ""
echo "VG details:"
vgs -o vg_name,vg_size,vg_free "${VG_NAME}" 2>/dev/null || true

echo ""
echo "Thinpool usage:"
lvs -a -o lv_name,lv_size,data_percent,metadata_percent,lv_attr "${VG_NAME}" 2>/dev/null || true

echo ""
echo "Selected disk residual signatures after setup:"
wipefs -n "${SELECTED_DISK}" 2>/dev/null || true

echo ""
if [ "${IS_SSD}" == "yes" ]; then
    systemctl is-active --quiet fstrim.timer && PASS "SSD TRIM active" || FAIL "SSD TRIM inactive"
else
    WARN "SSD TRIM check skipped because selected disk is HDD"
fi

if [ -n "${IO_SCHEDULER_SERVICE}" ]; then
    systemctl is-enabled --quiet "${IO_SCHEDULER_SERVICE}" && PASS "IO scheduler service enabled" || WARN "IO scheduler service not enabled"
else
    WARN "IO scheduler service was not created"
fi

if [ -f "$COMPLETED_MARKER" ]; then PASS "Completion marker exists"; else WARN "Completion marker missing"; fi

echo ""
echo "Verification complete."
rm -f "$verify_script"
EOF

    chmod +x "$verify_script"
    run_optional "$verify_script"

    msg_ok "VERIFICATION REPORT CREATED"
}


# --- 55. COMPLETION MARKER ---
# Creates marker so later reruns can detect previous setup.
function write_completion_marker() {
    section "COMPLETION MARKER"

    msg_info "Writing New Storage Setup completion marker"

    cat <<EOF > "$COMPLETED_MARKER"
New Storage Setup completed on: $(date)
Disk: $SELECTED_DISK
Disk Type: $DISK_TYPE
Disk Bus: $DISK_BUS
Disk Model: ${DISK_MODEL:-unknown}
Disk Size GB: $DISK_SIZE_GB
Storage ID: $STORAGE_ID
VG: $VG_NAME
Thinpool: $THINPOOL_NAME
Thin Allocation: ${THIN_PERCENT}%FREE
Content Types: $CONTENT_TYPES
IO Scheduler: $IO_SCHEDULER
Verify Log: $VERIFY_FILE
EOF

    msg_ok "COMPLETION MARKER WRITTEN"
}

# --- 56. FINAL SUMMARY ---
# Shows final storage details.
function show_final_summary() {
    section_flash_success "     ━━━━━━━━━━━━━━━━━    FINISHED    ━━━━━━━━━━━━━━━━━"

    echo -e "${BL}NEW PROXMOX STORAGE CREATED:${CL}"
    echo -e " ${BL}━━━━━▶${CL} DISK: ${GN}${SELECTED_DISK}${CL}"
    echo -e " ${BL}━━━━━▶${CL} MODEL: ${GN}${DISK_MODEL:-unknown}${CL}"
    echo -e " ${BL}━━━━━▶${CL} TYPE/BUS/SIZE: ${GN}${DISK_TYPE} / ${DISK_BUS} / ${DISK_SIZE_GB}GB${CL}"
    echo -e " ${BL}━━━━━▶${CL} STORAGE ID: ${GN}${STORAGE_ID}${CL}"
    echo -e " ${BL}━━━━━▶${CL} VG / THINPOOL: ${GN}${VG_NAME} / ${THINPOOL_NAME}${CL}"
    echo -e " ${BL}━━━━━▶${CL} THIN ALLOCATION: ${GN}${THIN_PERCENT}%FREE${CL}"
    echo -e " ${BL}━━━━━▶${CL} CONTENT: ${GN}${CONTENT_TYPES}${CL}"
    echo -e " ${BL}━━━━━▶${CL} IO SCHEDULER: ${GN}${IO_SCHEDULER}${CL}"
    echo -e " ${BL}━━━━━▶${CL} VERIFY LOG: ${GN}${VERIFY_FILE}${CL}"
    echo ""
    echo -e "${YW}New Proxmox LVM-thin storage is ready for VM disks, containers and backups according to selected content types.${CL}"
    echo ""
}


# --- 57. MAIN FUNCTION ---
# Runs validation -> safe disk selection -> configuration -> destructive apply -> verification.
function main() {
    init_script
    check_previous_marker

    set_default_storage_values_for_resume
    handle_existing_storage_resume

    audit_disks
    select_disk
    inspect_selected_disk
    show_selected_disk_summary
    first_destructive_confirmation

    collect_storage_names
    check_storage_conflicts
    collect_thinpool_allocation
    collect_content_types
    final_destructive_confirmation

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
