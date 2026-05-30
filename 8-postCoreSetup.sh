#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# =========================================================
#  Project Crea - Post-Core Production/Add-on Setup
# =========================================================
# Current module: n8n Automation
# Future modules can be added using the same detect/prompt/deploy/repair/verify pattern.
# Script 8 is additive and service-aware: it must not touch working core stacks
# from Scripts 1-7 unless a current add-on service explicitly requires a read-only check.

# --- 1. COLOR VARIABLES ---
YW="$(printf '\033[33m')"
BL="$(printf '\033[36m')"
RD="$(printf '\033[01;31m')"
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

SCRIPT_SOURCE="8-postCoreSetup.sh"
SCRIPT_VERSION="v1.0.19"
SCRIPT_UPDATED="2026-05-30"
SCRIPT_BUILD="authentik-app-exact-slug-lookup"

# --- 2. GLOBAL VARIABLES ---
T=15

LOG_FILE="/var/log/crea-post-core-setup.log"
RUNTIME_LOG_FILE=""
VERIFY_LOG="/var/log/crea-post-core-setup-verify.log"
COMPLETED_MARKER="/root/.crea-post-core-setup-completed"

DEFAULT_DOCKER_USER="${SUDO_USER:-orik}"
DOCKER_USER="${DOCKER_USER:-$DEFAULT_DOCKER_USER}"
DOCKER_DIR="${DOCKER_DIR:-/home/${DOCKER_USER}/docker}"
COMPOSE_DIR="${COMPOSE_DIR:-${DOCKER_DIR}/compose}"
ENV_FILE="${ENV_FILE:-${DOCKER_DIR}/.env}"
GITHUB_RAW_BASE="${GITHUB_RAW_BASE:-https://raw.githubusercontent.com/Orik999/circl8/refs/heads/main/docker}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


DOMAIN=""
ADMIN_UI="unknown"
DOCKER_NEEDS_SUDO="no"
SUDO_CMD=""
LOGGING_ENABLED="no"

# n8n module constants. User-facing UI must use friendly service names; internal filenames stay internal.
N8N_SERVICE_NAME="n8n Automation"
N8N_STACK_FILE="13-n8n-compose.yml"
N8N_STACK_URL_OVERRIDE="${N8N_STACK_URL:-}"
N8N_STACK_URL="${N8N_STACK_URL_OVERRIDE:-${GITHUB_RAW_BASE}/${N8N_STACK_FILE}}"
N8N_PROJECT="n8n"
N8N_COMPOSE_FILE=""
N8N_FLAT_COMPOSE_FILE=""
N8N_APPDATA_DIR=""
N8N_BUNDLED_COMPOSE_FILE=""
N8N_COMPOSE_SOURCE="unknown"
N8N_ENV_MAY_EDIT="no"
N8N_ENV_BACKUP_CREATED="no"
N8N_ENV_BACKUP_PATH=""
ENV_BACKED_UP_THIS_RUN="no"
N8N_DB_IDENTIFIER_STATUS="not-checked"
N8N_SECRET_STATUS_LINES=()
N8N_APPDATA_OWNER=""
N8N_MAIN_HEALTH="unknown"
N8N_WORKER_HEALTH="unknown"
N8N_ROUTE_WARNING="not-checked"

# n8n state and results.
N8N_STATE="unknown"
N8N_ACTION="not-run"
N8N_ENV_READY="no"
N8N_APPDATA_READY="no"
N8N_DB_READY="no"
N8N_REDIS_READY="no"
N8N_COMPOSE_READY="no"
N8N_DEPLOYED="no"
N8N_MAIN_RUNNING="no"
N8N_WORKER_RUNNING="no"
N8N_UI_ROUTE_OK="no"
N8N_WEBHOOK_ROUTE_OK="no"
N8N_VERIFIED="no"
N8N_TOUCHED="no"

TEMP_FILES=()
GENERATED_SECRET_LINES=()
SUMMARY_LINES=()

# =========================================================
#  OUTPUT HELPERS
# =========================================================

function header_info() {
echo -e "${BL}
██████╗  ██████╗ ███████╗████████╗      ██████╗ ██████╗ ██████╗ ███████╗
██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝     ██╔════╝██╔═══██╗██╔══██╗██╔════╝
██████╔╝██║   ██║███████╗   ██║        ██║     ██║   ██║██████╔╝█████╗
██╔═══╝ ██║   ██║╚════██║   ██║        ██║     ██║   ██║██╔══██╗██╔══╝
██║     ╚██████╔╝███████║   ██║        ╚██████╗╚██████╔╝██║  ██║███████╗
╚═╝      ╚═════╝ ╚══════╝   ╚═╝         ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
${CL}"
}

function show_script_version() {
    echo -e "${GN}SCRIPT VERSION: ${SCRIPT_VERSION} | UPDATED: ${SCRIPT_UPDATED} | BUILD: ${SCRIPT_BUILD}${CL}"
    echo -e "${BL}SOURCE: ${SCRIPT_SOURCE}${CL}"
}

function msg_info() { echo -ne " ${HOLD} ${YW}$1...${CL}"; }
function msg_ok() { echo -e "${BFR} ${CM} ${GN}$1${CL}"; }
function msg_warn() { echo -e "${BFR} ${WARN} ${YW}$1${CL}"; }
function msg_skip() { echo -e "${BFR} ${WARN} ${YW}$1${CL}"; }
function msg_error() { echo -e "${BFR} ${CROSS} ${RD}$1${CL}"; exit 1; }
function clear_transient_line() { tty_print "${BFR}"; }

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

function detail_line() {
    local label="$1"
    local value="$2"
    echo -e " ${BL}━━━━━▶${CL} ${label}: ${GN}${value}${CL}"
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

# =========================================================
#  CLEANUP / ERROR HANDLING
# =========================================================

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

function on_error() {
    local line_no="$1"
    echo -e "${RD}ERROR:${CL} Script failed at line ${line_no}. Check ${LOG_FILE}"
}

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
            echo -e "${YW}Command arguments hidden for secret safety.${CL}"
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
            echo -e "${YW}Command arguments hidden for secret safety.${CL}"
            echo ""
            echo -e "${RD}Real error:${CL}"
            cat "$err_file"
            rm -f "$err_file"
            exit 1
        fi
    fi

    rm -f "$err_file"
}

function run_optional() {
    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" "$@" >/dev/null 2>&1 || true
    else
        "$@" >/dev/null 2>&1 || true
    fi
}

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
#  PROMPT HELPERS
# =========================================================

function flush_input_buffer() {
    local junk=""
    local i=""
    [ -r /dev/tty ] || return 0
    for i in {1..20}; do
        if ! IFS= read -rsn1 -t 0.02 junk < /dev/tty 2>/dev/null; then
            break
        fi
    done
}

function yes_no_label() {
    local value="$1"
    if [[ "$value" =~ ^[Yy]$ ]]; then echo "yes"; else echo "no"; fi
}

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
        if [ "$remaining" -le 0 ]; then answer="$default"; break; fi
        tty_print "${BFR}${YW}${prompt} (${default_label}) [${remaining}s]${CL} "

        if [ -r /dev/tty ]; then
            if IFS= read -rsn1 -t 1 key < /dev/tty; then
                if [[ "$key" == " " ]]; then answer="$(tty_read_yes_no_blocking "$prompt" "$default")"; break
                elif [[ "$key" =~ ^[YyNn]$ ]]; then answer="$key"; break
                elif [[ -z "$key" ]]; then answer="$default"; break
                fi
            fi
        else
            if IFS= read -rsn1 -t 1 key; then
                if [[ "$key" == " " ]]; then answer="$(tty_read_yes_no_blocking "$prompt" "$default")"; break
                elif [[ "$key" =~ ^[YyNn]$ ]]; then answer="$key"; break
                elif [[ -z "$key" ]]; then answer="$default"; break
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
            "") [ -z "$answer" ] && answer="$default"; tty_print "${BFR}"; echo "$answer"; flush_input_buffer; return 0 ;;
            $'\177'|$'\b') answer="${answer%?}" ;;
            *) answer+="$key" ;;
        esac
    done
}

function timed_text_input() {
    local prompt="$1"
    local default="$2"
    local answer=""
    answer="$(editable_input_loop "$prompt" "$default" "")"
    [ -z "$answer" ] && answer="$default"
    tty_print "${BFR}"
    tty_println "${CM} ${GN}${prompt} ${answer}${CL}"
    flush_input_buffer 2>/dev/null || true
    echo "$answer"
}

# --- 40. LANDING PAGE HELPERS ---
function validate_astro_project() {
    local p="$1"
    # must be a dir
    if [ -z "$p" ] || [ ! -d "$p" ]; then
        return 1
    fi
    # must contain package.json
    if [ ! -f "$p/package.json" ]; then
        return 1
    fi
    # must have astro config file
    if ls "$p"/astro.config.* >/dev/null 2>&1 || [ -f "$p/astro.config.mjs" ]; then
        return 0
    fi
    return 1
}

function collect_landing_source_path() {
    section "LANDING SOURCE"
    # Ensure VM-side folders exist
    mkdir -p "${DOCKER_DIR}/projects/landing"
    mkdir -p "${DOCKER_DIR}/appdata/landing"
    mkdir -p "${DOCKER_DIR}/compose/landing"

    local vm_path="${DOCKER_DIR}/projects/landing"
    # Check for an existing Astro project in the VM destination
    if validate_astro_project "$vm_path"; then
        LANDING_SOURCE_PATH="$vm_path"
        msg_ok "Landing source found on VM: ${LANDING_SOURCE_PATH}"
        return 0
    fi

    msg_warn "No Astro landing source found at ${vm_path}"
    echo -e "${YW}${CLF}LANDING SOURCE REQUIRED${CL}"
    echo -e "${YW}Copy your Astro project from your laptop to the VM:${CL}"
    echo ""
    echo -e "  ${GN}scp -r /path/to/circl8_astro/* <vm-user>@<vm-ip>:${vm_path}/${CL}"
    echo ""
    echo -e "${YW}Replace <vm-user> and <vm-ip> with your VM login and address.${CL}"
    echo -e "${YW}After copying, return here and press Enter to re-check; or type 's' then Enter to skip deployment.${CL}"

    while true; do
        printf "Press Enter to re-check, or type 's' to skip: "
        read -r _ans
        if [[ "$_ans" =~ ^[sS]$ ]]; then
            msg_skip "Landing deployment skipped by user"
            return 1
        fi
        if validate_astro_project "$vm_path"; then
            LANDING_SOURCE_PATH="$vm_path"
            msg_ok "Landing source detected: ${LANDING_SOURCE_PATH}"
            return 0
        fi
        msg_warn "Still no valid Astro project at ${vm_path}."
        echo -e "${YW}If you copied files, ensure they include package.json and astro.config.mjs or astro.config.*.${CL}"
        echo -e "${YW}You can copy again with:${CL}"
        echo ""
        echo -e "  ${GN}scp -r /path/to/circl8_astro/* <vm-user>@<vm-ip>:${vm_path}/${CL}"
        echo ""
        echo -e "${YW}Or type 's' then Enter to skip landing deployment.${CL}"
    done
}
function backup_existing_landing() {
    local ts
    ts="$(date +%Y%m%d%H%M%S)"
    if [ -d "${DOCKER_DIR}/appdata/landing" ]; then
        mv "${DOCKER_DIR}/appdata/landing" "${DOCKER_DIR}/backups/landing-backup-${ts}" || true
    fi
}

function copy_dist_to_appdata() {
    local src_dist="$1"
    local dest="${DOCKER_DIR}/appdata/landing"
    mkdir -p "${DOCKER_DIR}/appdata" || true
    mkdir -p "${DOCKER_DIR}/appdata/landing.new"
    # portable copy via tar stream
    tar -C "$src_dist" -cf - . | tar -C "${DOCKER_DIR}/appdata/landing.new" -xpf -
    # rotate
    if [ -d "$dest" ]; then
        backup_existing_landing
    fi
    mv "${DOCKER_DIR}/appdata/landing.new" "$dest"
    chown -R "${DOCKER_USER}:${DOCKER_USER}" "$dest" 2>/dev/null || true
}

function build_landing_ephemeral_docker() {
    local src="$1"
    local builder_uid=""
    local builder_gid=""

    msg_info "Building landing site in ephemeral Docker container"
    if ! command -v docker >/dev/null 2>&1; then
        msg_warn "Docker not available; cannot use ephemeral builder"
        return 2
    fi

    run_cmd "cleaning stale landing build output" rm -rf "${src}/dist" "${src}/.astro"

    builder_uid="$(id -u "$DOCKER_USER" 2>/dev/null || id -u)"
    builder_gid="$(id -g "$DOCKER_USER" 2>/dev/null || id -g)"

    run_cmd "building landing (docker)" docker run --rm \
        --user "${builder_uid}:${builder_gid}" \
        -e PUBLIC_LANDING_HOST="${LANDING_HOST}" \
        -e PUBLIC_LANDING_WWW_HOST="${LANDING_WWW_HOST}" \
        -e PUBLIC_POSTIZ_HOST="${POSTIZ_HOST}" \
        -v "${src}:/src" \
        -w /src \
        node:22-bookworm \
        bash -lc '
            set -e
            if [ -f package-lock.json ] || [ -f npm-shrinkwrap.json ]; then
                npm ci --no-audit --no-fund
            else
                npm install --no-audit --no-fund
            fi
            npm run build
        '
    return 0
}

function build_landing_host_node() {
    local src="$1"
    if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
        msg_warn "Host Node/npm not available"
        return 2
    fi

    run_cmd "cleaning stale landing build output" rm -rf "${src}/dist" "${src}/.astro"

    (
        cd "$src"
        if [ -f package-lock.json ] || [ -f npm-shrinkwrap.json ]; then
            npm ci --no-audit --no-fund
        else
            npm install --no-audit --no-fund
        fi
        PUBLIC_LANDING_HOST="${LANDING_HOST}" PUBLIC_LANDING_WWW_HOST="${LANDING_WWW_HOST}" PUBLIC_POSTIZ_HOST="${POSTIZ_HOST}" npm run build
    )
}

function landing_compose_file() {
    printf '%s' "${DOCKER_DIR}/compose/landing/compose.yaml"
}

function landing_container_running() {
    docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -Eq '^(crea-landing|landing)$'
}

function render_landing_compose() {
    local template="${SCRIPT_DIR}/docker/14-landing-compose.yml"
    local out_compose=""
    out_compose="$(landing_compose_file)"

    run_cmd "creating landing compose directory" mkdir -p "$(dirname "$out_compose")"

    if [ -f "$template" ]; then
        envsubst < "$template" > "$out_compose"
    else
        cat > "$out_compose" <<EOF_LANDING_COMPOSE
services:
  crea-landing:
    image: nginx:alpine
    container_name: crea-landing
    restart: unless-stopped
    volumes:
      - ${DOCKER_DIR}/appdata/landing:/usr/share/nginx/html:ro
    networks:
      - t2_proxy
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=t2_proxy"
      - "traefik.http.routers.crea-landing.rule=Host(\`${LANDING_WWW_HOST}\`) || Host(\`${LANDING_HOST}\`)"
      - "traefik.http.routers.crea-landing.entrypoints=https"
      - "traefik.http.routers.crea-landing.tls=true"
      - "traefik.http.routers.crea-landing.middlewares=chain-secure@file"
      - "traefik.http.services.crea-landing.loadbalancer.server.port=80"

networks:
  t2_proxy:
    external: true
EOF_LANDING_COMPOSE
    fi

    run_cmd "setting landing compose ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$out_compose"
    run_cmd "setting landing compose permissions" chmod 640 "$out_compose"
    msg_ok "LANDING RUNTIME COMPOSE READY"
    detail_line "Landing compose" "$out_compose"
}

function deploy_landing_compose() {
    local compose_file=""
    compose_file="$(landing_compose_file)"

    [ -f "$compose_file" ] || render_landing_compose

    msg_info "Validating landing runtime compose"
    run_docker_cmd "validating landing runtime compose" compose -f "$compose_file" config -q
    msg_ok "LANDING RUNTIME COMPOSE VALID"

    msg_info "Deploying landing runtime container"
    run_docker_cmd "deploying landing runtime container" compose -f "$compose_file" up -d
    msg_ok "LANDING RUNTIME CONTAINER DEPLOYED"
}

function verify_landing_runtime() {
    local compose_file=""
    local route_code=""
    local host=""
    local attempt=""
    local ok="no"
    local hosts=()

    compose_file="$(landing_compose_file)"

    [ -f "${DOCKER_DIR}/appdata/landing/index.html" ] || return 1
    [ -f "$compose_file" ] || return 1
    landing_container_running || return 1

    [ -n "${LANDING_HOST:-}" ] && hosts+=("$LANDING_HOST")
    if [ -n "${LANDING_WWW_HOST:-}" ] && [ "${LANDING_WWW_HOST:-}" != "${LANDING_HOST:-}" ]; then
        hosts+=("$LANDING_WWW_HOST")
    fi

    for attempt in 1 2 3; do
        ok="no"
        for host in "${hosts[@]}"; do
            route_code="$(http_code_for_url "$(https_url_for_host "$host")/")"
            detail_line "Landing route" "$(https_url_for_host "$host")/ -> ${route_code:-none}"
            case "$route_code" in
                200|301|302|303|307|308)
                    ok="yes"
                    ;;
            esac
        done

        if [ "$ok" == "yes" ]; then
            return 0
        fi

        [ "$attempt" -lt 3 ] && sleep 5
    done

    return 1
}

function landing_deployment_appears_working() {
    if verify_landing_runtime; then
        return 0
    fi

    if [ -f "${DOCKER_DIR}/appdata/landing/index.html" ]; then
        msg_warn "Landing files exist but runtime route/container needs repair"
    fi

    return 1
}

function run_landing_module() {
    section "LANDING MODULE"

    : "${LANDING_HOST:=}"
    : "${LANDING_WWW_HOST:=}"
    : "${POSTIZ_HOST:=}"

    detail_line "Runtime path" "${DOCKER_DIR}/appdata/landing"
    detail_line "Source path" "${DOCKER_DIR}/projects/landing"

    if landing_deployment_appears_working; then
        echo -e "${GN}Landing Page appears deployed and working.${CL}"
        echo -e "${YW}Default is to skip and leave the working landing deployment untouched.${CL}"
        if [[ "$(timed_yes_no 'Skip Landing Page and continue?' 'y')" =~ ^[Yy]$ ]]; then
            msg_skip "Landing Page skipped; existing deployment left untouched"
            return 0
        fi
        echo ""
        msg_warn "Landing Page rebuild selected by user"
    else
        msg_warn "Landing Page is missing or needs review"
        if [ -f "${DOCKER_DIR}/appdata/landing/index.html" ]; then
            msg_info "Repairing landing runtime before rebuild"
            render_landing_compose
            deploy_landing_compose
            if verify_landing_runtime; then
                msg_ok "LANDING PAGE RUNTIME REPAIRED"
                return 0
            fi
            msg_warn "Landing runtime repair did not fully verify; rebuild may be needed"
        fi
    fi

    if ! collect_landing_source_path; then
        msg_skip "Landing: no source provided; skipping"
        return 0
    fi

    if [[ "$(timed_yes_no 'Build landing site now?' 'Y')" =~ ^[Nn]$ ]]; then
        msg_skip "Landing build skipped by user"
        return 0
    fi

    if build_landing_ephemeral_docker "$LANDING_SOURCE_PATH"; then
        :
    else
        if build_landing_host_node "$LANDING_SOURCE_PATH"; then :; else
            msg_error "Landing build failed (no builder available)"
            return 1
        fi
    fi

    if [ ! -d "${LANDING_SOURCE_PATH}/dist" ]; then
        msg_error "Landing build did not produce dist/"
    fi

    copy_dist_to_appdata "${LANDING_SOURCE_PATH}/dist"
    msg_ok "Landing deployed to ${DOCKER_DIR}/appdata/landing"

    render_landing_compose
    deploy_landing_compose

    if verify_landing_runtime; then
        msg_ok "LANDING PAGE RUNTIME VERIFIED"
    else
        msg_warn "Landing files deployed, but route still needs review. Check Traefik and DNS."
    fi

    return 0
}

# =========================================================
# Admin Dashboard module
# =========================================================
function detect_admin_dashboard_state() {
        section "ADMIN DASHBOARD DETECTION"
        local compose_file="${DOCKER_DIR}/compose/admin-dashboard/compose.yaml"
        if [ -f "$compose_file" ]; then
                detail_line "Runtime compose" "$compose_file"
                echo "installed"
                return 0
        fi
        # detect containers
        if docker_cmd ps --format '{{.Names}}' | grep -q '^admin-'; then
                echo "installed"
                return 0
        fi
        echo "missing"
        return 0
}

function prompt_admin_dashboard_selection() {
        # This function is called via command substitution:
        #   choice="$(prompt_admin_dashboard_selection)"
        # Therefore every UI line must go to /dev/tty/stderr, and stdout must
        # contain only the selected value.
        tty_println ""
        tty_println "${BORDER}"
        tty_println "${BL}ADMIN DASHBOARD${CL}"
        tty_println "${BORDER}"
        tty_println "${BL}Select the admin dashboard to deploy:${CL}"
        tty_println "  ${YW}1)${CL} ${GN}Homepage${CL} ${DGN}(default - lightweight links)${CL}"
        tty_println "  ${YW}2)${CL} ${GN}Glance${CL}"
        tty_println "  ${YW}3)${CL} ${GN}Homarr${CL}"
        tty_println "  ${YW}4)${CL} ${GN}Dashy${CL}"
        tty_println "  ${YW}5)${CL} ${YW}Skip${CL}"
        tty_println ""
        local choice
        choice="$(read_menu_choice "Choose dashboard" "1")"
        tty_println ""
        printf '%s\n' "$choice"
}
function prepare_admin_dashboard_dirs() {
        mkdir -p "${DOCKER_DIR}/compose/admin-dashboard"
        mkdir -p "${DOCKER_DIR}/appdata/admin-dashboard/config"
        mkdir -p "${DOCKER_DIR}/appdata/admin-dashboard/config/homepage"
        mkdir -p "${DOCKER_DIR}/appdata/admin-dashboard/config/homepage/logs"
        mkdir -p "${DOCKER_DIR}/appdata/admin-dashboard/homarr"
        mkdir -p "${DOCKER_DIR}/appdata/admin-dashboard/dashy"
        chown -R "${DOCKER_USER}:${DOCKER_USER}" "${DOCKER_DIR}/appdata/admin-dashboard" 2>/dev/null || true
        chmod 755 "${DOCKER_DIR}/appdata/admin-dashboard/config/homepage" "${DOCKER_DIR}/appdata/admin-dashboard/config/homepage/logs" 2>/dev/null || true
}
function generate_admin_links_config() {
        local sel="$1"
        local cfgdir="${DOCKER_DIR}/appdata/admin-dashboard/config"
        local landing_url=""
        local postiz_url=""
        local authentik_url=""
        local traefik_url=""
        local admin_ui_url=""
        local n8n_url=""
        local filebrowser_url=""
        local vscode_url=""

        landing_url="$(https_url_for_host "${LANDING_HOST}")"
        postiz_url="$(https_url_for_host "${POSTIZ_HOST}")"
        authentik_url="$(https_url_for_host "${AUTHENTIK_HOST}")"
        traefik_url="$(https_url_for_host "${TRAEFIK_HOST}")"
        admin_ui_url="$(https_url_for_host "${ADMIN_UI_HOST}")"
        n8n_url="$(https_url_for_host "${N8N_HOST}")"
        filebrowser_url="$(https_url_for_host "${FILEBROWSER_HOST}")"
        vscode_url="$(https_url_for_host "${VSCODE_HOST}")"

        mkdir -p "$cfgdir"
        case "$sel" in
                1)
                        mkdir -p "${cfgdir}/homepage/logs"
                        cat > "${cfgdir}/homepage/services.yaml" <<EOF
- Public / Customer:
    - Landing Page:
        href: "${landing_url}"
    - Circl8 App:
        href: "${postiz_url}"
- Identity / Admin:
    - Authentik User Portal:
        href: "${authentik_url}"
    - Authentik Admin:
        href: "${authentik_url}/if/admin/"
- Admin Tools:
    - Traefik:
        href: "${traefik_url}"
    - Admin UI:
        href: "${admin_ui_url}"
    - n8n:
        href: "${n8n_url}"
    - Files:
        href: "${filebrowser_url}"
    - VS Code:
        href: "${vscode_url}"
EOF

                        cat > "${cfgdir}/homepage/settings.yaml" <<EOF
title: "Admin Links"
theme: "default"
EOF

                        cat > "${cfgdir}/homepage/bookmarks.yaml" <<EOF
- Circl8:
    - Circl8 App:
        - href: "${postiz_url}"
EOF

                        cat > "${cfgdir}/homepage/widgets.yaml" <<EOF
[]
EOF
                        ;;
                2)
                        cat > "${cfgdir}/glance.yml" <<EOF
pages:
  - title: "Admin"
    columns:
      - widgets:
          - type: "links"
            title: "Important Links"
            items:
              - title: "Landing Page"
                url: "${landing_url}"
              - title: "Circl8 App"
                url: "${postiz_url}"
              - title: "Authentik"
                url: "${authentik_url}"
EOF
                        ;;
                3)
                        mkdir -p "${DOCKER_DIR}/appdata/admin-dashboard/homarr"
                        ;;
                4)
                        mkdir -p "${cfgdir}/dashy"
                        cat > "${cfgdir}/dashy/conf.yml" <<EOF
pageInfo:
  title: "Admin Dashboard"
sections:
  - title: "Links"
    items:
      - title: "Landing Page"
        type: "link"
        url: "${landing_url}"
      - title: "Circl8 App"
        type: "link"
        url: "${postiz_url}"
      - title: "Authentik"
        type: "link"
        url: "${authentik_url}"
EOF
                        ;;
        esac

        chown -R "${DOCKER_USER}:${DOCKER_USER}" "${DOCKER_DIR}/appdata/admin-dashboard/config" 2>/dev/null || true
}
function render_admin_compose() {
        local sel="$1"
        local template=""
        case "$sel" in
                1) template="${SCRIPT_DIR}/docker/16-[1]-homepage-compose.yml" ;;
                2) template="${SCRIPT_DIR}/docker/16-[2]-glance-compose.yml" ;;
                3) template="${SCRIPT_DIR}/docker/16-[3]-homarr-compose.yml" ;;
                4) template="${SCRIPT_DIR}/docker/16-[4]-dashy-compose.yml" ;;
                *) return 1 ;;
        esac
    local out_compose="${DOCKER_DIR}/compose/admin-dashboard/compose.yaml"
    mkdir -p "${DOCKER_DIR}/compose/admin-dashboard"

    # Prefer local template when available
    if [ -f "$template" ]; then
        envsubst < "$template" > "$out_compose"
        return 0
    fi

    # Fallback: attempt to download raw template from GitHub
    local filename
    filename="$(basename "$template")"
    # URL-encode square brackets for raw GitHub URL (replace [ -> %5B, ] -> %5D)
    local raw_filename
    raw_filename="${filename//\[/%5B}"
    raw_filename="${raw_filename//\]/%5D}"
    local raw_url
    raw_url="https://raw.githubusercontent.com/Orik999/circl8/refs/heads/main/docker/${raw_filename}"

    local tmpf
    tmpf="$(mktemp)"
    if command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL -g "$raw_url" -o "$tmpf"; then
            rm -f "$tmpf"
            msg_error "Failed to download template from $raw_url"
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -qO "$tmpf" "$raw_url"; then
            rm -f "$tmpf"
            msg_error "Failed to download template from $raw_url"
            return 1
        fi
    else
        msg_error "Neither curl nor wget available to fetch remote template"
        return 1
    fi

    envsubst < "$tmpf" > "$out_compose"
    rm -f "$tmpf"
    return 0
}


function https_url_for_host() {
    local host="$1"
    host="${host#https://}"
    host="${host#http://}"
    printf 'https://%s' "$host"
}

function show_admin_dashboard_ready() {
    local sel_name="$1"
    local will_generate_homarr_key="$2"
    local landing_url=""
    local postiz_url=""
    local authentik_url=""
    local traefik_url=""
    local admin_ui_url=""
    local n8n_url=""
    local files_url=""
    local vscode_url=""
    local yn=""

    landing_url="$(https_url_for_host "${LANDING_HOST}")"
    postiz_url="$(https_url_for_host "${POSTIZ_HOST}")"
    authentik_url="$(https_url_for_host "${AUTHENTIK_HOST}")"
    traefik_url="$(https_url_for_host "${TRAEFIK_HOST}")"
    admin_ui_url="$(https_url_for_host "${ADMIN_UI_HOST}")"
    n8n_url="$(https_url_for_host "${N8N_HOST}")"
    files_url="$(https_url_for_host "${FILEBROWSER_HOST}")"
    vscode_url="$(https_url_for_host "${VSCODE_HOST}")"

    echo ""
    echo -e "${BORDER}"
    echo -e "${BL}ADMIN DASHBOARD SUMMARY${CL}"
    echo -e "${BORDER}"
    detail_line "Selected dashboard" "$sel_name"
    detail_line "Host" "$ADMIN_DASHBOARD_HOST"
    detail_line "Runtime compose" "${DOCKER_DIR}/compose/admin-dashboard/compose.yaml"
    detail_line "Appdata path" "${DOCKER_DIR}/appdata/admin-dashboard"
    echo ""

    echo -e "${BL}Planned link/config files:${CL}"
    case "$sel_name" in
        Homepage)
            echo -e " ${YW}-${CL} ${DOCKER_DIR}/appdata/admin-dashboard/config/homepage/ ${DGN}(bookmarks/widgets/logs)${CL}"
            ;;
        Glance)
            echo -e " ${YW}-${CL} ${DOCKER_DIR}/appdata/admin-dashboard/config/glance.yml"
            ;;
        Homarr)
            echo -e " ${YW}-${CL} ${DOCKER_DIR}/appdata/admin-dashboard/homarr/ ${DGN}(persistent appdata)${CL}"
            if [ "$will_generate_homarr_key" = "yes" ]; then
                echo -e " ${YW}-${CL} Homarr secret key will be generated and stored securely."
            else
                echo -e " ${YW}-${CL} Existing Homarr secret.key will be reused if present."
            fi
            ;;
        Dashy)
            echo -e " ${YW}-${CL} ${DOCKER_DIR}/appdata/admin-dashboard/config/dashy/conf.yml"
            ;;
        *)
            msg_error "Unknown admin dashboard selection: ${sel_name}"
            ;;
    esac

    echo ""
    echo -e "${BL}Dashboard links that will be configured:${CL}"
    echo -e " ${YW}-${CL} ${GN}Landing Page:${CL} ${landing_url}"
    echo -e " ${YW}-${CL} ${GN}Circl8 App:${CL} ${postiz_url}"
    echo -e " ${YW}-${CL} ${GN}Authentik User Portal:${CL} ${authentik_url}"
    echo -e " ${YW}-${CL} ${GN}Authentik Admin:${CL} ${authentik_url}/if/admin/"
    echo -e " ${YW}-${CL} ${GN}Traefik:${CL} ${traefik_url}"
    echo -e " ${YW}-${CL} ${GN}Admin UI:${CL} ${admin_ui_url}"
    echo -e " ${YW}-${CL} ${GN}n8n:${CL} ${n8n_url}"
    echo -e " ${YW}-${CL} ${GN}Files:${CL} ${files_url}"
    echo -e " ${YW}-${CL} ${GN}VS Code:${CL} ${vscode_url}"
    echo ""

    read -r -p "Proceed with these changes? (y/N): " yn
    echo ""
    case "$yn" in
        [Yy]*) return 0 ;;
        *) msg_skip "User aborted admin dashboard action"; return 1 ;;
    esac
}
function sensitive_line_input() {
    local prompt="$1"
    local val=""
    if [ -r /dev/tty ]; then
        tty_print "${BFR}${YW}${prompt}: ${CL}"
        IFS= read -rs val < /dev/tty || true
        tty_print "\n"
    else
        read -rs val || true
        echo
    fi
    val="$(printf '%s' "$val" | tr -d '\r')"
    printf '%s' "$val"
}

function authentik_api_token_value() {
    local token=""

    token="${AUTHENTIK_API_TOKEN:-}"
    [ -n "$token" ] && { printf '%s' "$token"; return 0; }

    token="$(env_get AUTHENTIK_API_TOKEN)"
    [ -n "$token" ] && { printf '%s' "$token"; return 0; }

    token="$(env_get AUTHENTIK_BOOTSTRAP_TOKEN)"
    [ -n "$token" ] && { printf '%s' "$token"; return 0; }

    return 1
}

function prompt_filebrowser_oidc_action() {
    local has_api_token="$1"
    local choice=""

    tty_println "${BL}Select FileBrowser OIDC setup method:${CL}"
    if [ "$has_api_token" == "yes" ]; then
        tty_println "  ${YW}1)${CL} ${GN}Auto-create FileBrowser OIDC in Authentik${CL}"
        tty_println "  ${YW}2)${CL} ${GN}Paste saved FileBrowser OIDC credentials${CL}"
        tty_println "  ${YW}3)${CL} ${YW}Skip FileBrowser for now${CL}"
        choice="$(read_menu_choice "Choose FileBrowser OIDC action" "1")"
        tty_println ""
        case "$choice" in
            1) printf '%s\n' "auto" ;;
            2) printf '%s\n' "paste" ;;
            3|s|S|skip) printf '%s\n' "skip" ;;
            *) printf '%s\n' "auto" ;;
        esac
    else
        tty_println "  ${YW}1)${CL} ${GN}Paste saved FileBrowser OIDC credentials${CL}"
        tty_println "  ${YW}2)${CL} ${YW}Skip FileBrowser for now${CL}"
        choice="$(read_menu_choice "Choose FileBrowser OIDC action" "1")"
        tty_println ""
        case "$choice" in
            1) printf '%s\n' "paste" ;;
            2|s|S|skip) printf '%s\n' "skip" ;;
            *) printf '%s\n' "paste" ;;
        esac
    fi
}

function auto_create_filebrowser_oidc_with_authentik() {
    local api_token="$1"
    local result_file=""
    local parsed_file=""
    local authentik_base=""
    local issuer_url=""
    local callback_url=""
    local launch_url=""

    authentik_base="$(https_url_for_host "$AUTHENTIK_HOST")"
    issuer_url="${authentik_base}/application/o/filebrowser-quantum/"
    callback_url="$(https_url_for_host "$FILEBROWSER_HOST")/api/auth/oidc/callback"
    launch_url="$(https_url_for_host "$FILEBROWSER_HOST")"

    result_file="$(mktemp)"
    chmod 600 "$result_file" 2>/dev/null || true
    TEMP_FILES+=("$result_file")

    msg_info "Creating/updating FileBrowser Authentik OIDC provider"
    if ! docker_cmd exec \
        -e AUTHENTIK_API_TOKEN="$api_token" \
        -e FILEBROWSER_OIDC_ISSUER_URL="$issuer_url" \
        -e FILEBROWSER_OIDC_CALLBACK_URL="$callback_url" \
        -e FILEBROWSER_OIDC_LAUNCH_URL="$launch_url" \
        authentik-server python - > "$result_file" 2>&1 <<'PY_AUTHENTIK_OIDC'
import json
import os
import secrets
import string
import urllib.error
import urllib.parse
import urllib.request

BASE = "http://localhost:9000"
TOKEN = os.environ["AUTHENTIK_API_TOKEN"]
ISSUER = os.environ["FILEBROWSER_OIDC_ISSUER_URL"]
CALLBACK = os.environ["FILEBROWSER_OIDC_CALLBACK_URL"]
LAUNCH = os.environ["FILEBROWSER_OIDC_LAUNCH_URL"]
NAME = "FileBrowser Quantum"
SLUG = "filebrowser-quantum"

def req(method, path, data=None):
    body = None
    headers = {"Authorization": f"Bearer {TOKEN}", "Accept": "application/json"}
    if data is not None:
        body = json.dumps(data).encode()
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(BASE + path, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read().decode()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode(errors="replace")
        raise SystemExit(f"AUTHENTIK_API_ERROR {method} {path} HTTP {exc.code}: {raw}")

def first_result(path):
    data = req("GET", path)
    results = data.get("results", []) if isinstance(data, dict) else []
    return results[0] if results else None

def find_application_by_slug(slug):
    # Authentik's list endpoint may not filter correctly with ?slug=...
    # Fetch and match the exact slug in Python to avoid updating the wrong app.
    page = 1
    while True:
        data = req("GET", "/api/v3/core/applications/?" + urllib.parse.urlencode({"page": page, "page_size": 100}))
        results = data.get("results", []) if isinstance(data, dict) else []
        for item in results:
            if item.get("slug") == slug:
                return item
        pagination = data.get("pagination", {}) if isinstance(data, dict) else {}
        if not pagination.get("next"):
            return None
        page += 1

def find_flow(*slugs):
    for slug in slugs:
        flow = first_result("/api/v3/flows/instances/?" + urllib.parse.urlencode({"slug": slug}))
        if flow:
            return flow.get("pk")
    raise SystemExit("AUTHENTIK_API_ERROR could not find required default Authentik flow")

def scope_mapping_pks():
    data = req("GET", "/api/v3/propertymappings/provider/scope/?page_size=200")
    results = data.get("results", []) if isinstance(data, dict) else []
    wanted = {"openid", "email", "profile", "groups"}
    pks = []
    for item in results:
        scope = str(item.get("scope_name", "")).lower()
        name = str(item.get("name", "")).lower()
        if scope in wanted or any(w in name for w in wanted):
            pk = item.get("pk")
            if pk and pk not in pks:
                pks.append(pk)
    return pks

def rand_secret(length=64):
    alphabet = string.ascii_letters + string.digits + "_-"
    return "".join(secrets.choice(alphabet) for _ in range(length))

def shq(value):
    return "'" + str(value).replace("'", "'\"'\"'") + "'"

auth_flow = find_flow("default-provider-authorization-explicit-consent", "default-provider-authorization-implicit-consent")
invalid_flow = find_flow("default-provider-invalidation-flow")
client_id = "filebrowser_quantum_" + rand_secret(24)
client_secret = rand_secret(72)
provider = first_result("/api/v3/providers/oauth2/?" + urllib.parse.urlencode({"search": SLUG}))
provider_mode = "created"
provider_payload = {
    "name": NAME,
    "authorization_flow": auth_flow,
    "invalidation_flow": invalid_flow,
    "property_mappings": scope_mapping_pks(),
    "client_type": "confidential",
    "client_id": client_id,
    "client_secret": client_secret,
    "redirect_uris": [{"matching_mode": "strict", "url": CALLBACK}],
    "signing_key": None,
    "sub_mode": "hashed_user_id",
    "issuer_mode": "per_provider",
    "include_claims_in_id_token": True,
    "access_code_validity": "minutes=1",
    "access_token_validity": "minutes=5",
    "refresh_token_validity": "days=30",
}
if provider:
    provider_pk = provider.get("pk")
    req("PATCH", f"/api/v3/providers/oauth2/{provider_pk}/", provider_payload)
    provider_mode = "updated"
else:
    provider = req("POST", "/api/v3/providers/oauth2/", provider_payload)
    provider_pk = provider.get("pk")
application = find_application_by_slug(SLUG)
app_payload = {"name": NAME, "slug": SLUG, "provider": provider_pk, "meta_launch_url": LAUNCH, "open_in_new_tab": True}
if application:
    app_slug = application.get("slug") or SLUG
    req("PATCH", f"/api/v3/core/applications/{app_slug}/", app_payload)
    app_mode = "updated"
else:
    application = req("POST", "/api/v3/core/applications/", app_payload)
    app_mode = "created"
print("FILEBROWSER_OIDC_ISSUER_URL=" + shq(ISSUER))
print("FILEBROWSER_OIDC_CLIENT_ID=" + shq(client_id))
print("FILEBROWSER_OIDC_CLIENT_SECRET=" + shq(client_secret))
print("FILEBROWSER_OIDC_PROVIDER_MODE=" + shq(provider_mode))
print("FILEBROWSER_OIDC_APPLICATION_MODE=" + shq(app_mode))
PY_AUTHENTIK_OIDC
    then
        echo ""
        echo -e "${RD}Authentik OIDC automation failed.${CL}"
        echo -e "${YW}The Authentik API token was not printed. Redacted error output:${CL}"
        sed -E 's/(token|secret|password)([=: ][^[:space:]]+)/\1=REDACTED/Ig' "$result_file" || true
        return 1
    fi

    parsed_file="$(mktemp)"
    chmod 600 "$parsed_file" 2>/dev/null || true
    TEMP_FILES+=("$parsed_file")
    grep '^FILEBROWSER_OIDC_[A-Z_]*=' "$result_file" > "$parsed_file" || true

    # shellcheck disable=SC1090
    . "$parsed_file"

    if [ -z "${FILEBROWSER_OIDC_CLIENT_ID:-}" ] || [ -z "${FILEBROWSER_OIDC_CLIENT_SECRET:-}" ] || [ -z "${FILEBROWSER_OIDC_ISSUER_URL:-}" ]; then
        echo ""
        echo -e "${RD}FileBrowser OIDC auto-create returned incomplete output.${CL}"
        echo -e "${YW}Redacted raw output follows:${CL}"
        sed -E 's/(client_secret|CLIENT_SECRET|token|secret|password)([=: ][^[:space:]]+)/\1=REDACTED/Ig' "$result_file" || true
        return 1
    fi

    msg_ok "FILEBROWSER AUTHENTIK OIDC PROVIDER READY"
    detail_line "Provider" "${FILEBROWSER_OIDC_PROVIDER_MODE:-unknown}"
    detail_line "Application" "${FILEBROWSER_OIDC_APPLICATION_MODE:-unknown}"

    record_generated_secret "FILEBROWSER_OIDC_ISSUER_URL" "$FILEBROWSER_OIDC_ISSUER_URL" "auto-created"
    record_generated_secret "FILEBROWSER_OIDC_CLIENT_ID" "$FILEBROWSER_OIDC_CLIENT_ID" "auto-created"
    record_generated_secret "FILEBROWSER_OIDC_CLIENT_SECRET" "$FILEBROWSER_OIDC_CLIENT_SECRET" "auto-created"
}

function show_filebrowser_quantum_instructions() {
    section "FILEBROWSER OIDC CONFIG"

    echo -e "${BL}FileBrowser Quantum requires an Authentik OAuth2/OIDC provider.${CL}"
    echo ""
    echo -e "${BL}Required settings:${CL}"
    echo -e " ${YW}-${CL} ${GN}Provider type:${CL} OAuth2/OIDC"
    echo -e " ${YW}-${CL} ${GN}Suggested provider slug:${CL} filebrowser-quantum"
    echo -e " ${YW}-${CL} ${GN}Callback URI:${CL} $(https_url_for_host "${FILEBROWSER_HOST}")/api/auth/oidc/callback"
    echo -e " ${YW}-${CL} ${GN}Scopes:${CL} openid, email, profile, groups"
    echo -e " ${YW}-${CL} ${GN}User identifier:${CL} preferred_username"
    echo ""
}

function text_input() {
    local prompt="$1"
    local default="$2"
    local answer=""

    flush_input_buffer
    tty_print "${YW}${prompt} [default: ${default}]: ${CL}"
    if [ -r /dev/tty ]; then
        IFS= read -r answer < /dev/tty || true
    else
        IFS= read -r answer || true
    fi
    answer="${answer:-$default}"
    tty_println ""
    printf '%s' "$answer"
}

function collect_filebrowser_oidc_vars() {
    : "${AUTHENTIK_HOST:=}"

    local authentik_base=""
    local default_issuer=""
    local api_token=""
    local has_api_token="no"
    local oidc_action=""

    authentik_base="$(https_url_for_host "$AUTHENTIK_HOST")"
    default_issuer="${authentik_base}/application/o/filebrowser-quantum/"

    show_filebrowser_quantum_instructions

    if api_token="$(authentik_api_token_value)"; then
        has_api_token="yes"
        msg_ok "Authentik API token found in environment/.env"
    else
        has_api_token="no"
        msg_warn "Authentik API token not found; auto-create is unavailable"
    fi

    oidc_action="$(prompt_filebrowser_oidc_action "$has_api_token")"

    case "$oidc_action" in
        auto)
            echo ""
            echo -e "${YW}${CLF}FILEBROWSER OIDC AUTO-CREATE WARNING${CL}"
            echo -e "${YW}Auto-create will create the FileBrowser Authentik provider/application if missing.${CL}"
            echo -e "${YW}If an existing filebrowser-quantum provider is found, Script 8 will update it and rotate the FileBrowser OIDC client secret.${CL}"
            echo -e "${YW}Choose no if you want to preserve an existing provider secret and paste saved credentials instead.${CL}"
            if [[ "$(timed_yes_no 'Continue with FileBrowser OIDC auto-create/update?' 'n')" =~ ^[Nn]$ ]]; then
                msg_skip "FileBrowser OIDC auto-create skipped by user"
                return 1
            fi
            if ! auto_create_filebrowser_oidc_with_authentik "$api_token"; then
                msg_error "FileBrowser OIDC auto-create failed. You can rerun Script 8 and choose paste/skip."
            fi
            ;;
        paste)
            FILEBROWSER_OIDC_ISSUER_URL="$(text_input 'FILEBROWSER_OIDC_ISSUER_URL' "$default_issuer")"
            FILEBROWSER_OIDC_CLIENT_ID="$(text_input 'FILEBROWSER_OIDC_CLIENT_ID' '')"
            disable_logging
            FILEBROWSER_OIDC_CLIENT_SECRET="$(sensitive_line_input 'FILEBROWSER_OIDC_CLIENT_SECRET (input hidden)')"
            enable_logging

            FILEBROWSER_OIDC_ISSUER_URL="$(printf '%s' "$FILEBROWSER_OIDC_ISSUER_URL" | sed -E 's#^https://https://#https://#; s#^http://https://#https://#')"

            if [ -z "$FILEBROWSER_OIDC_ISSUER_URL" ] || [ -z "$FILEBROWSER_OIDC_CLIENT_ID" ] || [ -z "$FILEBROWSER_OIDC_CLIENT_SECRET" ]; then
                echo ""
                msg_error "OIDC issuer URL, client ID, and client secret are required."
            fi

            record_generated_secret "FILEBROWSER_OIDC_ISSUER_URL" "$FILEBROWSER_OIDC_ISSUER_URL" "pasted"
            record_generated_secret "FILEBROWSER_OIDC_CLIENT_ID" "$FILEBROWSER_OIDC_CLIENT_ID" "pasted"
            record_generated_secret "FILEBROWSER_OIDC_CLIENT_SECRET" "$FILEBROWSER_OIDC_CLIENT_SECRET" "pasted"
            ;;
        skip|*)
            msg_skip "FileBrowser Quantum deployment skipped; OIDC credentials not ready"
            return 1
            ;;
    esac
}
function prepare_filebrowser_dirs() {
    msg_info "Creating FileBrowser directories"
    mkdir -p "${DOCKER_DIR}/appdata/filebrowser-quantum/data"
    mkdir -p "${DOCKER_DIR}/compose/filebrowser-quantum"
    chown -R "${DOCKER_USER}:${DOCKER_USER}" "${DOCKER_DIR}/appdata/filebrowser-quantum" 2>/dev/null || true
    msg_ok "Prepared FileBrowser appdata and compose dirs"
}

function backup_filebrowser_appdata() {
    local fb_dir="${DOCKER_DIR}/appdata/filebrowser-quantum"
    if [ -d "$fb_dir" ]; then
        mkdir -p "${DOCKER_DIR}/backups"
        local ts
        ts="$(date +%Y%m%d-%H%M%S)"
        local archive="${DOCKER_DIR}/backups/filebrowser-quantum-${ts}.tar.gz"
        if tar -czf "$archive" -C "${DOCKER_DIR}" "appdata/filebrowser-quantum" >/dev/null 2>&1; then
            msg_ok "Backed up existing FileBrowser appdata to $archive"
        else
            msg_warn "Failed to back up existing FileBrowser appdata to $archive"
            rm -f "$archive" 2>/dev/null || true
        fi
    fi
}

function render_filebrowser_config() {
    local cfg_dir="${DOCKER_DIR}/appdata/filebrowser-quantum/data"
    local tmpf
    tmpf="$(mktemp)" || msg_error "Failed to create temporary file for config"
    umask 077
    cat > "$tmpf" <<-EOF
server:
  port: 80

auth:
  oidc:
    enabled: true
    issuerUrl: "${FILEBROWSER_OIDC_ISSUER_URL}"
    clientId: "${FILEBROWSER_OIDC_CLIENT_ID}"
    clientSecret: "${FILEBROWSER_OIDC_CLIENT_SECRET}"
    scopes:
      - openid
      - email
      - profile
      - groups
    userIdentifier: "preferred_username"
EOF
    mkdir -p "$cfg_dir"
    mv "$tmpf" "${cfg_dir}/config.yaml"
    chown "${DOCKER_USER}:${DOCKER_USER}" "${cfg_dir}/config.yaml" 2>/dev/null || true
    chmod 0600 "${cfg_dir}/config.yaml" || true
    msg_ok "Wrote FileBrowser config.yaml to ${cfg_dir}/config.yaml"
}

function render_filebrowser_compose() {
    local local_template="${SCRIPT_DIR}/docker/15-filebrowser-quantum-compose.yml"
    local remote_url="https://raw.githubusercontent.com/Orik999/circl8/refs/heads/main/docker/15-filebrowser-quantum-compose.yml"
    local out_compose="${DOCKER_DIR}/compose/filebrowser-quantum/compose.yaml"
    local template_file=""
    local downloaded="no"

    if [ -f "$local_template" ]; then
        template_file="$local_template"
    else
        template_file="$(mktemp)" || msg_error "Failed to create temp file for remote template"
        downloaded="yes"
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL -g "$remote_url" -o "$template_file" || { rm -f "$template_file"; msg_error "Failed to download remote FileBrowser compose template"; }
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$template_file" "$remote_url" || { rm -f "$template_file"; msg_error "Failed to download remote FileBrowser compose template"; }
        else
            rm -f "$template_file"
            msg_error "Neither curl nor wget available to fetch remote FileBrowser compose template"
        fi
    fi

    envsubst < "$template_file" > "$out_compose" || { rm -f "$out_compose"; [ "$downloaded" = "yes" ] && rm -f "$template_file"; msg_error "Failed to render FileBrowser compose"; }
    [ "$downloaded" = "yes" ] && rm -f "$template_file"
    msg_ok "Rendered FileBrowser compose to $out_compose"
}

function validate_filebrowser_compose() {
    local compose_file="${DOCKER_DIR}/compose/filebrowser-quantum/compose.yaml"
    msg_info "Validating FileBrowser compose"
    if ! docker_cmd compose -f "$compose_file" config >/dev/null 2>&1; then
        msg_error "docker compose config failed for $compose_file"
    fi
    msg_ok "FileBrowser compose validated"
}

function deploy_filebrowser_compose() {
    local compose_file="${DOCKER_DIR}/compose/filebrowser-quantum/compose.yaml"

    msg_info "Deploying FileBrowser stack"
    if docker_cmd compose up --help 2>/dev/null | grep -q -- '--quiet-pull'; then
        run_docker_cmd "deploying FileBrowser stack" compose -f "$compose_file" up -d --quiet-pull
    else
        run_docker_cmd "deploying FileBrowser stack" compose -f "$compose_file" up -d
    fi
    msg_ok "FileBrowser stack started"
}

function verify_filebrowser_deploy() {
    msg_info "Verifying FileBrowser deployment"
    docker_cmd ps --filter "name=filebrowser" --format 'table {{.Names}}\t{{.Status}}'
    docker_cmd compose -f "${DOCKER_DIR}/compose/filebrowser-quantum/compose.yaml" logs --tail 80 || true
    local fb_route_code=""
    fb_route_code="$(http_code_for_url "https://${FILEBROWSER_HOST}/")"
    case "$fb_route_code" in
        200|301|302|303|307|308|401|403)
            msg_ok "FILEBROWSER ROUTE RESPONDED WITH HTTP ${fb_route_code}"
            ;;
        *)
            msg_warn "FileBrowser route returned HTTP ${fb_route_code:-none}; verify Traefik/router after DNS propagation"
            ;;
    esac
    detail_line "FileBrowser route" "https://${FILEBROWSER_HOST}/ -> ${fb_route_code:-none}"
    msg_warn "Browser-based OIDC login flow must be tested manually. Visit https://${FILEBROWSER_HOST} and confirm Authentik redirect and successful login."
}

function prompt_filebrowser_action() {
    local compose_file="${DOCKER_DIR}/compose/filebrowser-quantum/compose.yaml"
    local choice=""
    local deploy_yn=""

    if [ -f "$compose_file" ]; then
        tty_println "${BL}Existing FileBrowser Quantum compose detected:${CL} ${compose_file}"
        tty_println "${BL}Choose FileBrowser Quantum action:${CL}"
        tty_println "  ${YW}1)${CL} ${GN}Skip${CL}"
        tty_println "  ${YW}2)${CL} ${GN}Recreate${CL} ${DGN}(backup then overwrite compose/config)${CL}"
        tty_println "  ${YW}3)${CL} ${GN}Reset${CL} ${DGN}(backup, remove appdata and compose, then deploy fresh)${CL}"
        tty_println "  ${YW}4)${CL} ${GN}Deploy existing compose${CL}"
        choice="$(read_menu_choice 'Select FileBrowser action' '1')"
        tty_println ""
        case "$choice" in
            1) printf '%s\n' "skip" ;;
            2) printf '%s\n' "recreate" ;;
            3) printf '%s\n' "reset" ;;
            4) printf '%s\n' "deploy" ;;
            *) printf '%s\n' "skip" ;;
        esac
    else
        tty_println "${YW}FileBrowser Quantum is not currently deployed.${CL}"
        deploy_yn="$(timed_yes_no 'Deploy FileBrowser Quantum now?' 'y')"
        if [[ "$deploy_yn" =~ ^[Yy]$ ]]; then
            printf '%s\n' "deploy"
        else
            printf '%s\n' "skip"
        fi
    fi
}

function run_filebrowser_quantum_module() {
    section "FILEBROWSER QUANTUM MODULE"
    : "${DOCKER_DIR:=/home/${DOCKER_USER}/docker}"
    : "${FILEBROWSER_HOST:=files.${DOMAIN}}"

    local compose_file="${DOCKER_DIR}/compose/filebrowser-quantum/compose.yaml"
    local action
    action="$(prompt_filebrowser_action)"
    if [ "$action" = "skip" ]; then
        msg_skip "FileBrowser Quantum action skipped by user"
        return 0
    fi

    if [ "$action" = "reset" ]; then
        backup_filebrowser_appdata
        rm -rf "${DOCKER_DIR}/appdata/filebrowser-quantum" "${DOCKER_DIR}/compose/filebrowser-quantum" 2>/dev/null || true
    elif [ "$action" = "recreate" ]; then
        backup_filebrowser_appdata
    fi

    if [ "$action" = "deploy" ] && [ -f "$compose_file" ]; then
        msg_ok "Using existing FileBrowser compose at $compose_file"
        validate_filebrowser_compose
        deploy_filebrowser_compose
        refresh_cf_companion_dns_for_host_if_needed "filebrowser quantum" "$FILEBROWSER_HOST"
        sleep 3
        verify_filebrowser_deploy
        return 0
    fi

    if ! collect_filebrowser_oidc_vars; then
        return 0
    fi
    echo ""
    echo "READY TO APPLY FileBrowser Quantum"
    echo " - FileBrowser host: https://${FILEBROWSER_HOST}"
    echo " - Runtime config: ${DOCKER_DIR}/appdata/filebrowser-quantum/data/config.yaml"
    echo " - Runtime compose: ${DOCKER_DIR}/compose/filebrowser-quantum/compose.yaml"
    echo " - Compose template: ${SCRIPT_DIR}/docker/15-filebrowser-quantum-compose.yml"
    echo ""
    if [[ "$(timed_yes_no 'Proceed and apply FileBrowser Quantum deployment now?' 'Y')" =~ ^[Nn]$ ]]; then
        msg_skip "FileBrowser Quantum deployment skipped by user"
        return 0
    fi

    prepare_filebrowser_dirs
    render_filebrowser_config
    render_filebrowser_compose
    validate_filebrowser_compose
    if [[ "$(timed_yes_no 'Deploy FileBrowser Quantum now with docker compose up -d?' 'Y')" =~ ^[Nn]$ ]]; then
        msg_skip "FileBrowser Quantum deployment aborted after validation"
        return 0
    fi
    deploy_filebrowser_compose
    refresh_cf_companion_dns_for_host_if_needed "filebrowser quantum" "$FILEBROWSER_HOST"
    sleep 3
    verify_filebrowser_deploy
}
function validate_admin_compose() {
        docker_cmd compose -f "${DOCKER_DIR}/compose/admin-dashboard/compose.yaml" config >/dev/null 2>&1
}

function deploy_admin_compose() {
        local compose_file="${DOCKER_DIR}/compose/admin-dashboard/compose.yaml"

        msg_info "Deploying admin dashboard stack"
        if docker_cmd compose up --help 2>/dev/null | grep -q -- '--quiet-pull'; then
            run_docker_cmd "deploying admin dashboard stack" compose -f "$compose_file" up -d --quiet-pull
        else
            run_docker_cmd "deploying admin dashboard stack" compose -f "$compose_file" up -d
        fi
        msg_ok "ADMIN DASHBOARD STACK DEPLOYED"
}

function verify_admin_dashboard() {
        if ! docker_cmd ps --format '{{.Names}}' | grep -q '^admin-'; then
                msg_warn "No admin dashboard container running"
                return 1
        fi
        if curl -fsSI "https://${ADMIN_DASHBOARD_HOST}" >/dev/null 2>&1; then
                return 0
        else
                msg_warn "Admin dashboard route not responding at https://${ADMIN_DASHBOARD_HOST}"
                return 1
        fi
}

function show_admin_dashboard_recent_logs() {
        local compose_file="${DOCKER_DIR}/compose/admin-dashboard/compose.yaml"
        local containers=""
        local c=""

        msg_warn "Showing recent admin dashboard logs for HTTP 500 diagnosis"
        containers="$(docker_cmd compose -f "$compose_file" ps --format '{{.Name}}' 2>/dev/null || true)"
        if [ -z "$containers" ]; then
            containers="$(docker_cmd ps -a --format '{{.Names}}' | grep '^admin-' || true)"
        fi

        if [ -z "$containers" ]; then
            msg_warn "No admin dashboard containers found for log collection"
            return 0
        fi

        while IFS= read -r c; do
            [ -z "$c" ] && continue
            echo ""
            echo -e "${BL}Recent logs for ${c}:${CL}"
            docker_cmd logs --tail=80 "$c" 2>&1 | sed -E 's/(clientSecret|secret|token|password)([=: ][^[:space:]]+)/\1=REDACTED/Ig' || true
        done <<< "$containers"
}

function run_admin_dashboard_module() {
        : "${ADMIN_DASHBOARD_HOST:=}"
        if [ -z "$ADMIN_DASHBOARD_HOST" ]; then
                ADMIN_DASHBOARD_HOST="admin.${DOMAIN}"
        fi

        local state
        state="$(detect_admin_dashboard_state)"

        local choice
        choice="$(prompt_admin_dashboard_selection)"
        choice="$(printf '%s' "$choice" | tail -n1 | tr -d '[:space:]')"
        [ -z "$choice" ] && choice="1"

        case "$choice" in
            1|2|3|4|5|skip) ;;
            *)
                msg_warn "Invalid admin dashboard selection captured: ${choice}; defaulting to Homepage"
                choice="1"
                ;;
        esac

        if [ "$choice" == "5" ] || [ "$choice" == "skip" ]; then
            msg_skip "Admin dashboard: skipped by user"
            return 0
        fi

        prepare_admin_dashboard_dirs

        local sel_name
        case "$choice" in
            1) sel_name="Homepage" ;;
            2) sel_name="Glance" ;;
            3) sel_name="Homarr" ;;
            4) sel_name="Dashy" ;;
            *) sel_name="Unknown" ;;
        esac

        local compose_file="${DOCKER_DIR}/compose/admin-dashboard/compose.yaml"
        if [ -f "$compose_file" ]; then
            echo "An admin dashboard compose already exists at $compose_file"
            echo "Options: [s]kip, [r]ecreate (backup then overwrite), [o]verwrite (no backup)"
            read -r -p "Choose action (s/r/o) [s]: " act
            act="${act:-s}"
            case "$act" in
                s|S)
                    msg_skip "User chose to skip admin dashboard changes"
                    return 0
                    ;;
                r|R)
                    if [ -d "${DOCKER_DIR}/appdata/admin-dashboard" ]; then
                        local ts
                        ts="$(date +%Y%m%d-%H%M%S)"
                        mkdir -p "${DOCKER_DIR}/backups"
                        local bfile="${DOCKER_DIR}/backups/admin-dashboard-${ts}.tar.gz"
                        tar -czf "$bfile" -C "${DOCKER_DIR}" "appdata/admin-dashboard" || true
                        msg_ok "Backed up existing appdata to $bfile"
                    fi
                    ;;
                o|O)
                    ;;
                *) msg_skip "Invalid choice, skipping"; return 0 ;;
            esac
        fi

        local will_gen_homarr_key="no"
        if [ "$choice" == "3" ]; then
            local homarr_dir="${DOCKER_DIR}/appdata/admin-dashboard/homarr"
            mkdir -p "$homarr_dir"
            local keyfile="$homarr_dir/secret.key"
            if [ ! -f "$keyfile" ]; then
                if command -v openssl >/dev/null 2>&1; then
                    HOMARR_SECRET_ENCRYPTION_KEY="$(openssl rand -base64 32)"
                else
                    HOMARR_SECRET_ENCRYPTION_KEY="$(head -c 32 /dev/urandom | base64)"
                fi
                umask 077
                printf "%s" "$HOMARR_SECRET_ENCRYPTION_KEY" > "$keyfile"
                chmod 600 "$keyfile" || true
                will_gen_homarr_key="yes"
            else
                HOMARR_SECRET_ENCRYPTION_KEY="$(cat "$keyfile")"
            fi
            export HOMARR_SECRET_ENCRYPTION_KEY
        fi

        generate_admin_links_config "$choice"

        if ! show_admin_dashboard_ready "$sel_name" "$will_gen_homarr_key"; then
            return 1
        fi

        if ! render_admin_compose "$choice"; then
            msg_error "Failed to render admin dashboard compose"
            return 1
        fi

        if ! validate_admin_compose; then
            msg_error "Rendered admin dashboard compose is invalid"
            return 1
        fi

        deploy_admin_compose
        refresh_cf_companion_dns_for_host_if_needed "admin dashboard" "$ADMIN_DASHBOARD_HOST"

        if docker_cmd compose -f "$compose_file" ps --quiet >/dev/null 2>&1 && [ -n "$(docker_cmd compose -f "$compose_file" ps --quiet 2>/dev/null)" ]; then
            msg_ok "Admin dashboard container(s) appear to be running"
        else
            msg_warn "Admin dashboard containers do not appear to be running; check 'docker compose -f $compose_file ps'"
        fi

        local admin_route_code=""
        admin_route_code="$(http_code_for_url "https://${ADMIN_DASHBOARD_HOST}/")"
        case "$admin_route_code" in
            200|301|302|303|307|308|401|403)
                msg_ok "ADMIN DASHBOARD ROUTE RESPONDED WITH HTTP ${admin_route_code}"
                msg_warn "Browser-based Authentik protection verification is still required."
                ;;
            500)
                msg_warn "Admin dashboard route reached the service but returned HTTP 500; checking dashboard app logs"
                show_admin_dashboard_recent_logs
                ;;
            *)
                msg_warn "Admin dashboard route returned HTTP ${admin_route_code:-none}; verify Traefik/router after DNS propagation"
                ;;
        esac
        detail_line "Admin dashboard route" "https://${ADMIN_DASHBOARD_HOST}/ -> ${admin_route_code:-none}"

        return 0
}
function read_menu_choice() {
    local prompt="$1"
    local default="$2"
    local answer=""
    flush_input_buffer
    tty_print "${YW}${prompt} [default: ${default}]: ${CL}"
    if [ -r /dev/tty ]; then
        IFS= read -r answer < /dev/tty || true
    else
        IFS= read -r answer || true
    fi
    answer="${answer:-$default}"
    printf '%s' "$answer"
}

# =========================================================
#  INIT / VALIDATION
# =========================================================

function detect_root_or_sudo() {
    if [ "$EUID" -eq 0 ]; then SUDO_CMD=""; else SUDO_CMD="sudo"; fi
}

function validate_sudo_access() {
    if [ -n "$SUDO_CMD" ]; then
        msg_info "Validating sudo access"
        if "$SUDO_CMD" -n true >/dev/null 2>&1; then msg_ok "PASSWORDLESS SUDO CONFIRMED"; return 0; fi
        if "$SUDO_CMD" -v; then msg_ok "SUDO ACCESS CONFIRMED"; return 0; fi
        msg_error "Sudo authentication failed. Script cancelled."
    fi
}

function init_logging() {
    exec 3>&1
    exec 4>&2
    if [ -n "$SUDO_CMD" ]; then
        RUNTIME_LOG_FILE="$(mktemp /tmp/crea-post-core-log.XXXXXX)"
        TEMP_FILES+=("$RUNTIME_LOG_FILE")
        exec > >(tee -a "$RUNTIME_LOG_FILE") 2>&1
    else
        RUNTIME_LOG_FILE="$LOG_FILE"
        exec > >(tee -a "$LOG_FILE") 2>&1
    fi
    LOGGING_ENABLED="yes"
}

function validate_dependencies() {
    local required_commands=(awk cat chmod cp curl date docker envsubst grep head id mkdir mktemp openssl python3 rm sed sort tee tr)
    local cmd=""
    for cmd in "${required_commands[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || msg_error "Required command not found: ${cmd}"
    done
    if [ -n "$SUDO_CMD" ]; then command -v sudo >/dev/null 2>&1 || msg_error "sudo is required when not running as root."; fi
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
    validate_dependencies
}

function detect_docker_access() {
    section "DOCKER ACCESS CHECK"
    msg_info "Checking Docker access"
    if docker ps >/dev/null 2>&1; then
        DOCKER_NEEDS_SUDO="no"
        msg_ok "DOCKER ACCESS CONFIRMED"
        detail_line "Docker mode" "current user"
        return 0
    fi
    if [ -n "$SUDO_CMD" ] && "$SUDO_CMD" docker ps >/dev/null 2>&1; then
        DOCKER_NEEDS_SUDO="yes"
        msg_ok "DOCKER ACCESS CONFIRMED WITH SUDO"
        detail_line "Docker mode" "sudo fallback"
        return 0
    fi
    msg_error "Docker daemon is not reachable. Run core Docker setup first."
}

function docker_cmd() {
    if [ "$DOCKER_NEEDS_SUDO" == "yes" ]; then "$SUDO_CMD" docker "$@"; else docker "$@"; fi
}

function run_docker_cmd() {
    local description="$1"
    shift
    local err_file=""
    err_file="$(mktemp)"
    TEMP_FILES+=("$err_file")
    if ! docker_cmd "$@" >/dev/null 2>"$err_file"; then
        echo ""
        echo -e "${RD}Docker command failed during:${CL} ${description}"
        echo -e "${YW}Docker command arguments hidden for secret safety.${CL}"
        echo ""
        echo -e "${RD}Real error:${CL}"
        cat "$err_file"
        rm -f "$err_file"
        exit 1
    fi
    rm -f "$err_file"
}

# =========================================================
#  PROJECT CONFIG / ENV HELPERS
# =========================================================

function load_env_file() {
    section "PROJECT CONFIG"

    DOCKER_USER="$(timed_text_input "Enter Docker Linux user" "$DOCKER_USER")"
    DOCKER_DIR="$(timed_text_input "Enter Docker directory" "$DOCKER_DIR")"
    COMPOSE_DIR="$(timed_text_input "Enter compose directory" "$COMPOSE_DIR")"
    ENV_FILE="$(timed_text_input "Enter Docker .env path" "$ENV_FILE")"
    GITHUB_RAW_BASE="$(timed_text_input "Enter GitHub raw compose base" "$GITHUB_RAW_BASE")"

    [ -f "$ENV_FILE" ] || msg_error ".env file not found: ${ENV_FILE}. Run Script 6 first."

    # shellcheck disable=SC1090
    set -a
    . "$ENV_FILE"
    set +a

    DOMAIN="${DOMAIN:-}"
    [ -n "$DOMAIN" ] || msg_error "DOMAIN is missing from ${ENV_FILE}."

    DOCKER_DIR="${DOCKER_DIR:-/home/${DOCKER_USER}/docker}"
    COMPOSE_DIR="${COMPOSE_DIR:-${DOCKER_DIR}/compose}"
    ENV_FILE="${ENV_FILE:-${DOCKER_DIR}/.env}"
    N8N_STACK_URL="${N8N_STACK_URL_OVERRIDE:-${GITHUB_RAW_BASE}/${N8N_STACK_FILE}}"
    N8N_FLAT_COMPOSE_FILE="${COMPOSE_DIR}/${N8N_STACK_FILE}"
    N8N_BUNDLED_COMPOSE_FILE="${SCRIPT_DIR}/docker/${N8N_STACK_FILE}"
    N8N_APPDATA_DIR="${DOCKER_DIR}/appdata/n8n"

    export DOCKER_DIR COMPOSE_DIR ENV_FILE DOMAIN

    detail_line "Docker user" "$DOCKER_USER"
    detail_line "Docker dir" "$DOCKER_DIR"
    detail_line "Compose dir" "$COMPOSE_DIR"
    detail_line "Domain" "$DOMAIN"
    detail_line "GitHub raw base" "$GITHUB_RAW_BASE"
}

function env_get() {
    local key="$1"
    awk -F= -v k="$key" '
        $0 ~ "^[[:space:]]*#" {next}
        $1 == k {
            v=$0; sub("^[^=]*=", "", v); gsub(/^\"|\"$/, "", v); print v; exit
        }
    ' "$ENV_FILE" 2>/dev/null || true
}

function env_key_exists() {
    local key="$1"
    grep -Eq "^${key}=" "$ENV_FILE"
}

function backup_env_once() {
    local backup="${ENV_FILE}.bak.$(date +%Y%m%d%H%M%S)"

    if [ "$ENV_BACKED_UP_THIS_RUN" == "yes" ]; then
        return 0
    fi

    run_cmd "backing up .env before Script 8 edits" cp -a "$ENV_FILE" "$backup"
    run_cmd "setting env backup ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$backup"
    ENV_BACKED_UP_THIS_RUN="yes"
    N8N_ENV_BACKUP_CREATED="yes"
    N8N_ENV_BACKUP_PATH="$backup"
    msg_ok ".ENV BACKUP CREATED"
    detail_line "Backup" "$backup"
}

function env_set_or_update() {
    local key="$1"
    local value="$2"
    local tmp=""
    backup_env_once
    N8N_ENV_MAY_EDIT="yes"
    tmp="$(mktemp)"
    TEMP_FILES+=("$tmp")

    if env_key_exists "$key"; then
        awk -v k="$key" -v v="$value" 'BEGIN{done=0} $0 ~ "^[[:space:]]*#" {print; next} $1 ~ "^" k "=" {print k "=" v; done=1; next} {print} END{if(done==0) print k "=" v}' "$ENV_FILE" > "$tmp"
    else
        cat "$ENV_FILE" > "$tmp"
        {
            echo ""
            echo "# n8n Automation - managed by Script 8"
            echo "${key}=${value}"
        } >> "$tmp"
    fi

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" install -m 0600 -o "$DOCKER_USER" -g "$DOCKER_USER" "$tmp" "$ENV_FILE"
    else
        install -m 0600 -o "$DOCKER_USER" -g "$DOCKER_USER" "$tmp" "$ENV_FILE"
    fi
}

function record_generated_secret() {
    local key="$1"
    local value="$2"
    local mode="$3"
    GENERATED_SECRET_LINES+=("${key}|${value}|${mode}")
    N8N_SECRET_STATUS_LINES+=("${key}:${mode}")
}

function record_secret_reused() {
    local key="$1"
    N8N_SECRET_STATUS_LINES+=("${key}:existing-reused")
}

function generate_secret() {
    local length="${1:-48}"
    python3 - "$length" <<'PY_SECRET'
import secrets, string, sys
length = int(sys.argv[1])
alphabet = string.ascii_letters + string.digits + "_-"
print(''.join(secrets.choice(alphabet) for _ in range(length)))
PY_SECRET
}

function ensure_env_value() {
    local key="$1"
    local default_value="$2"
    local current=""
    current="$(env_get "$key")"
    if [ -n "$current" ]; then
        return 0
    fi
    env_set_or_update "$key" "$default_value"
}

function ensure_secret_env_value() {
    local key="$1"
    local generated_length="$2"
    local critical_message="$3"
    local current=""
    local paste_yn=""
    local value=""

    current="$(env_get "$key")"
    if [ -n "$current" ]; then
        record_secret_reused "$key"
        return 0
    fi

    echo -e "${YW}${key} is missing from ${ENV_FILE}.${CL}"
    [ -n "$critical_message" ] && echo -e "${YW}${critical_message}${CL}"
    paste_yn="$(timed_yes_no "Paste a previously saved value for ${key}?" "n")"

    if [[ "$paste_yn" =~ ^[Yy] ]]; then
        disable_logging
        value="$(sensitive_line_input "Paste ${key}")"
        enable_logging
        value="$(printf '%s' "$value" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -n "$value" ] || msg_error "No value pasted for ${key}."
        env_set_or_update "$key" "$value"
        record_generated_secret "$key" "$value" "pasted"
        return 0
    fi

    value="$(generate_secret "$generated_length")"
    env_set_or_update "$key" "$value"
    record_generated_secret "$key" "$value" "generated"
}

# =========================================================
#  CORE CHECKS
# =========================================================

function detect_admin_ui() {
    section "ADMIN UI DETECTION"
    msg_info "Detecting selected admin UI"
    if docker_cmd ps -a --format '{{.Names}}' | grep -qx 'dockge'; then
        ADMIN_UI="dockge"
    elif docker_cmd ps -a --format '{{.Names}}' | grep -qx 'komodo-core'; then
        ADMIN_UI="komodo"
    elif docker_cmd ps -a --format '{{.Names}}' | grep -qx 'dockhand'; then
        ADMIN_UI="dockhand"
    elif docker_cmd ps -a --format '{{.Names}}' | grep -qx 'portainer'; then
        ADMIN_UI="portainer"
    else
        ADMIN_UI="unknown"
    fi
    msg_ok "ADMIN UI DETECTION COMPLETE"
    detail_line "Admin UI" "$ADMIN_UI"
}

function verify_core_services_read_only() {
    section "CORE SERVICE READ-ONLY CHECK"
    local required_containers=(postgres redis traefik authentik-server)
    local required_networks=(database t2_proxy)
    local item=""

    for item in "${required_containers[@]}"; do
        msg_info "Checking ${item}"
        if docker_cmd ps --format '{{.Names}}' | grep -qx "$item"; then
            msg_ok "${item} RUNNING"
        else
            msg_error "${item} is not running. Script 8 requires Scripts 6/6.5/7 to be complete first."
        fi
    done

    for item in "${required_networks[@]}"; do
        msg_info "Checking Docker network ${item}"
        if docker_cmd network inspect "$item" >/dev/null 2>&1; then
            msg_ok "NETWORK ${item} EXISTS"
        else
            msg_error "Docker network ${item} is missing. Run core deployment first."
        fi
    done
}

# =========================================================
#  COMPOSE PATH / DOCKGE LAYOUT HELPERS
# =========================================================

function n8n_dockge_compose_file() {
    printf '%s' "${COMPOSE_DIR}/n8n/compose.yaml"
}

function resolve_n8n_compose_file() {
    local dockge_path=""
    dockge_path="$(n8n_dockge_compose_file)"
    if [ "$ADMIN_UI" == "dockge" ] && [ -f "$dockge_path" ]; then
        printf '%s' "$dockge_path"
        return 0
    fi
    if [ -f "$N8N_FLAT_COMPOSE_FILE" ]; then
        printf '%s' "$N8N_FLAT_COMPOSE_FILE"
        return 0
    fi
    if [ "$ADMIN_UI" == "dockge" ]; then
        printf '%s' "$dockge_path"
    else
        printf '%s' "$N8N_FLAT_COMPOSE_FILE"
    fi
}

function sync_n8n_compose_for_dockge() {
    local target_dir="${COMPOSE_DIR}/n8n"
    local target_file="${target_dir}/compose.yaml"

    if [ "$ADMIN_UI" != "dockge" ]; then
        N8N_COMPOSE_FILE="$N8N_FLAT_COMPOSE_FILE"
        return 0
    fi

    run_cmd "creating Dockge n8n compose folder" mkdir -p "$target_dir"
    run_cmd "syncing n8n compose into Dockge layout" cp "$N8N_FLAT_COMPOSE_FILE" "$target_file"
    run_cmd "setting Dockge n8n compose ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$target_file"
    run_cmd "setting Dockge n8n compose permissions" chmod 640 "$target_file"
    N8N_COMPOSE_FILE="$target_file"
    msg_ok "DOCKGE COMPOSE READY FOR N8N AUTOMATION"
    detail_line "Compose" "$target_file"
}

function download_n8n_compose_if_needed() {
    local mode="$1"
    determine_n8n_compose_source "$mode"

    case "$mode" in
        update)
            msg_info "Downloading updated ${N8N_SERVICE_NAME} compose"
            run_cmd "creating compose directory" mkdir -p "$COMPOSE_DIR"
            if [ -f "$N8N_FLAT_COMPOSE_FILE" ]; then
                run_cmd "backing up existing n8n compose" cp -a "$N8N_FLAT_COMPOSE_FILE" "${N8N_FLAT_COMPOSE_FILE}.bak.$(date +%Y%m%d%H%M%S)"
            fi
            if ! curl --globoff -fsSL "$N8N_STACK_URL" -o "$N8N_FLAT_COMPOSE_FILE"; then
                msg_error "Could not download ${N8N_STACK_FILE} from ${N8N_STACK_URL}. Upload it to GitHub or set N8N_STACK_URL."
            fi
            run_cmd "setting n8n compose ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$N8N_FLAT_COMPOSE_FILE"
            run_cmd "setting n8n compose permissions" chmod 640 "$N8N_FLAT_COMPOSE_FILE"
            N8N_COMPOSE_SOURCE="remote-downloaded"
            sync_n8n_compose_for_dockge
            msg_ok "N8N AUTOMATION COMPOSE DOWNLOADED"
            ;;
        deploy|repair|recreate)
            case "$N8N_COMPOSE_SOURCE" in
                existing-runtime)
                    N8N_COMPOSE_FILE="${N8N_COMPOSE_FILE:-$(resolve_n8n_compose_file)}"
                    msg_ok "N8N AUTOMATION COMPOSE ALREADY PRESENT"
                    detail_line "Compose source" "$N8N_COMPOSE_SOURCE"
                    detail_line "Compose" "$N8N_COMPOSE_FILE"
                    ;;
                bundled-local)
                    msg_info "Installing bundled ${N8N_SERVICE_NAME} compose"
                    run_cmd "creating compose directory" mkdir -p "$COMPOSE_DIR"
                    run_cmd "copying bundled n8n compose" cp "$N8N_BUNDLED_COMPOSE_FILE" "$N8N_FLAT_COMPOSE_FILE"
                    run_cmd "setting n8n compose ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$N8N_FLAT_COMPOSE_FILE"
                    run_cmd "setting n8n compose permissions" chmod 640 "$N8N_FLAT_COMPOSE_FILE"
                    sync_n8n_compose_for_dockge
                    msg_ok "BUNDLED N8N AUTOMATION COMPOSE INSTALLED"
                    ;;
                remote-missing-local)
                    msg_info "n8n compose missing locally; downloading"
                    run_cmd "creating compose directory" mkdir -p "$COMPOSE_DIR"
                    if ! curl --globoff -fsSL "$N8N_STACK_URL" -o "$N8N_FLAT_COMPOSE_FILE"; then
                        msg_error "Could not download ${N8N_STACK_FILE} from ${N8N_STACK_URL}."
                    fi
                    run_cmd "setting n8n compose ownership" chown "${DOCKER_USER}:${DOCKER_USER}" "$N8N_FLAT_COMPOSE_FILE"
                    run_cmd "setting n8n compose permissions" chmod 640 "$N8N_FLAT_COMPOSE_FILE"
                    N8N_COMPOSE_SOURCE="remote-downloaded"
                    sync_n8n_compose_for_dockge
                    msg_ok "N8N AUTOMATION COMPOSE DOWNLOADED"
                    ;;
            esac
            ;;
        *)
            N8N_COMPOSE_FILE="$(resolve_n8n_compose_file)"
            ;;
    esac
}

# =========================================================
#  N8N MODULE: DETECT / PROMPT / PREPARE / DEPLOY / VERIFY
# =========================================================

function is_valid_pg_identifier() {
    local ident="$1"
    # Conservative PostgreSQL identifier policy for .env-managed database/user names.
    # Keeps SQL idempotent and prevents unsafe interpolation from edited/restored .env files.
    [[ "$ident" =~ ^[A-Za-z_][A-Za-z0-9_]{0,62}$ ]]
}

function require_valid_pg_identifier() {
    local key="$1"
    local ident="$2"
    if ! is_valid_pg_identifier "$ident"; then
        msg_error "${key} must be a safe PostgreSQL identifier: letters, numbers, underscores, max 63 chars, starting with letter/underscore."
    fi
}

function n8n_secret_status_for() {
    local key="$1"
    local line=""
    for line in "${N8N_SECRET_STATUS_LINES[@]:-}"; do
        case "$line" in
            "${key}:"*) printf '%s' "${line#*:}"; return 0 ;;
        esac
    done
    if [ -n "$(env_get "$key")" ]; then
        printf '%s' "existing-reused"
    else
        printf '%s' "missing"
    fi
}

function n8n_container_health_state() {
    local name="$1"
    local health=""
    health="$(docker_cmd inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$name" 2>/dev/null || true)"
    printf '%s' "${health:-unknown}"
}

function n8n_redis_ping_readonly() {
    local redis_db="${N8N_REDIS_DB:-$(env_get N8N_REDIS_DB)}"
    redis_db="${redis_db:-2}"
    [ -n "${REDIS_PASSWORD:-}" ] || return 1
    docker_cmd exec -e REDISCLI_AUTH="$REDIS_PASSWORD" redis redis-cli -n "$redis_db" ping 2>/dev/null | grep -q PONG
}

function n8n_db_login_readonly() {
    local db="${N8N_POSTGRES_DB:-$(env_get N8N_POSTGRES_DB)}"
    local user="${N8N_POSTGRES_USER:-$(env_get N8N_POSTGRES_USER)}"
    local password="${N8N_POSTGRES_PASSWORD:-$(env_get N8N_POSTGRES_PASSWORD)}"
    db="${db:-n8n}"
    user="${user:-n8n}"
    [ -n "$password" ] || return 1
    is_valid_pg_identifier "$db" || return 1
    is_valid_pg_identifier "$user" || return 1
    docker_cmd exec -i -e PGPASSWORD="$password" postgres psql -U "$user" -d "$db" -v ON_ERROR_STOP=1 -c 'SELECT 1;' >/dev/null 2>&1
}

function determine_n8n_compose_source() {
    local mode="$1"
    local existing=""
    local dockge_path=""
    dockge_path="$(n8n_dockge_compose_file)"

    if [ "$ADMIN_UI" == "dockge" ] && [ -f "$dockge_path" ]; then
        existing="$dockge_path"
    elif [ -f "$N8N_FLAT_COMPOSE_FILE" ]; then
        existing="$N8N_FLAT_COMPOSE_FILE"
    else
        existing=""
    fi

    case "$mode" in
        update)
            N8N_COMPOSE_SOURCE="remote-update"
            N8N_COMPOSE_FILE="${existing:-$(resolve_n8n_compose_file)}"
            ;;
        deploy|repair|recreate|detect)
            if [ -n "$existing" ]; then
                N8N_COMPOSE_SOURCE="existing-runtime"
                N8N_COMPOSE_FILE="$existing"
            elif [ -f "$N8N_BUNDLED_COMPOSE_FILE" ]; then
                N8N_COMPOSE_SOURCE="bundled-local"
                N8N_COMPOSE_FILE="$N8N_FLAT_COMPOSE_FILE"
            else
                N8N_COMPOSE_SOURCE="remote-missing-local"
                N8N_COMPOSE_FILE="$N8N_FLAT_COMPOSE_FILE"
            fi
            ;;
        *)
            N8N_COMPOSE_SOURCE="not-needed"
            N8N_COMPOSE_FILE="$(resolve_n8n_compose_file)"
            ;;
    esac
}

function show_n8n_ready_to_apply() {
    section "READY TO APPLY - N8N AUTOMATION"

    local db="${N8N_POSTGRES_DB:-$(env_get N8N_POSTGRES_DB)}"
    local user="${N8N_POSTGRES_USER:-$(env_get N8N_POSTGRES_USER)}"
    local redis_db="${N8N_REDIS_DB:-$(env_get N8N_REDIS_DB)}"
    db="${db:-n8n}"
    user="${user:-n8n}"
    redis_db="${redis_db:-2}"
    require_valid_pg_identifier "N8N_POSTGRES_DB" "$db"
    require_valid_pg_identifier "N8N_POSTGRES_USER" "$user"
    N8N_DB_IDENTIFIER_STATUS="valid-planned"

    detail_line "Service" "$N8N_SERVICE_NAME"
    detail_line "Selected action" "$N8N_ACTION"
    detail_line ".env path" "$ENV_FILE"
    detail_line ".env may be edited" "yes, only missing n8n keys/secrets"
    detail_line ".env backup" "once before first edit in this run"
    detail_line "n8n appdata" "$N8N_APPDATA_DIR"
    detail_line "Permission scope" "${N8N_APPDATA_DIR} only"
    detail_line "PostgreSQL database" "$db"
    detail_line "PostgreSQL user" "$user"
    detail_line "Redis DB" "$redis_db"
    detail_line "Compose source" "$N8N_COMPOSE_SOURCE"
    detail_line "Compose target" "${N8N_COMPOSE_FILE:-$(resolve_n8n_compose_file)}"
    if [ "$ADMIN_UI" == "dockge" ]; then
        detail_line "Dockge compose target" "$(n8n_dockge_compose_file)"
    fi
    detail_line "Affected containers" "n8n, n8n-worker"
    detail_line "Route" "https://n8n.${DOMAIN}/"
    detail_line "UI protection" "Authentik via chain-authentik@file"
    detail_line "Public production webhook" "https://n8n.${DOMAIN}/webhook/..."
    detail_line "webhook-test" "not public by default; remains behind Authentik UI route"

    echo ""
    echo -e "${YW}No Scripts 1-7 core infrastructure will be changed.${CL}"
    echo -e "${YW}No n8n data reset, database drop, appdata delete, or encryption-key regeneration will be performed.${CL}"
    echo ""

    local apply_yn=""
    apply_yn="$(timed_yes_no "Apply this ${N8N_SERVICE_NAME} plan?" "y")"
    if [[ "$apply_yn" =~ ^[Nn] ]]; then
        N8N_ACTION="skip"
        msg_skip "N8N AUTOMATION PLAN CANCELLED; EXISTING SETUP LEFT UNTOUCHED"
        return 1
    fi
    return 0
}

function prepare_n8n_env_values() {
    section "N8N AUTOMATION ENVIRONMENT"

    ensure_env_value "N8N_IMAGE" "docker.n8n.io/n8nio/n8n:latest"
    ensure_env_value "N8N_HOST" "n8n.${DOMAIN}"
    ensure_env_value "N8N_URL" "https://n8n.${DOMAIN}"
    ensure_env_value "N8N_WEBHOOK_URL" "https://n8n.${DOMAIN}/"
    ensure_env_value "N8N_POSTGRES_DB" "n8n"
    ensure_env_value "N8N_POSTGRES_USER" "n8n"
    ensure_env_value "N8N_EXECUTIONS_MODE" "queue"
    ensure_env_value "N8N_WORKER_CONCURRENCY" "5"
    ensure_env_value "N8N_REDIS_DB" "2"
    ensure_env_value "N8N_LOG_LEVEL" "info"

    ensure_secret_env_value "N8N_POSTGRES_PASSWORD" "48" "This password is for the n8n PostgreSQL role only. Existing values are always preserved."
    ensure_secret_env_value "N8N_ENCRYPTION_KEY" "64" "CRITICAL: Never regenerate this after n8n has stored credentials unless you intentionally reset n8n data."

    # Reload .env after updates.
    # shellcheck disable=SC1090
    set -a
    . "$ENV_FILE"
    set +a

    N8N_ENV_READY="yes"
    msg_ok "N8N ENVIRONMENT VALUES READY"
}

function prepare_n8n_appdata() {
    section "N8N AUTOMATION DIRECTORIES"

    local owner_uid="${N8N_APPDATA_UID:-1000}"
    local owner_gid="${N8N_APPDATA_GID:-1000}"
    N8N_APPDATA_OWNER="${owner_uid}:${owner_gid}"

    # Service-scoped permissions only. Never blanket chown/chmod ${DOCKER_DIR}/appdata.
    # The official n8n image stores data under /home/node/.n8n and is expected to run as node (UID/GID 1000).
    # Optional N8N_APPDATA_UID/N8N_APPDATA_GID may override this without changing the compose user model.
    run_cmd "creating n8n appdata directory" mkdir -p "$N8N_APPDATA_DIR" "${N8N_APPDATA_DIR}/files" "${N8N_APPDATA_DIR}/backups"
    run_cmd "setting n8n appdata ownership" chown -R "$N8N_APPDATA_OWNER" "$N8N_APPDATA_DIR"
    run_cmd "setting n8n appdata permissions" chmod 750 "$N8N_APPDATA_DIR"
    run_cmd "setting n8n child directory permissions" chmod 750 "${N8N_APPDATA_DIR}/files" "${N8N_APPDATA_DIR}/backups"

    N8N_APPDATA_READY="yes"
    msg_ok "N8N AUTOMATION DIRECTORIES READY"
    detail_line "n8n appdata" "$N8N_APPDATA_DIR"
    detail_line "n8n appdata owner" "$N8N_APPDATA_OWNER"
}

function postgres_exec_sql() {
    local sql="$1"
    docker_cmd exec -i -e PGPASSWORD="${POSTGRES_PASSWORD}" postgres psql -U postgres -d postgres -v ON_ERROR_STOP=1 <<< "$sql"
}

function ensure_n8n_database() {
    section "N8N AUTOMATION DATABASE"

    local db="${N8N_POSTGRES_DB:-n8n}"
    local user="${N8N_POSTGRES_USER:-n8n}"
    local password="${N8N_POSTGRES_PASSWORD:-}"
    local escaped_password=""
    local sql=""

    [ -n "$password" ] || msg_error "N8N_POSTGRES_PASSWORD is empty after environment preparation."
    [ -n "${POSTGRES_PASSWORD:-}" ] || msg_error "POSTGRES_PASSWORD is missing from ${ENV_FILE}."
    require_valid_pg_identifier "N8N_POSTGRES_DB" "$db"
    require_valid_pg_identifier "N8N_POSTGRES_USER" "$user"
    N8N_DB_IDENTIFIER_STATUS="valid"

    escaped_password="${password//\'/\'\'}"

    msg_info "Creating/updating n8n PostgreSQL role and database"
    sql="DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${user}') THEN
        EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', '${user}', '${escaped_password}');
    ELSE
        EXECUTE format('ALTER ROLE %I WITH LOGIN PASSWORD %L', '${user}', '${escaped_password}');
    END IF;
END
\$\$;
SELECT format('CREATE DATABASE %I OWNER %I', '${db}', '${user}') WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db}')\\gexec
SELECT format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', '${db}', '${user}')\\gexec"

    if postgres_exec_sql "$sql" >/dev/null 2>&1; then
        msg_ok "N8N POSTGRESQL DATABASE READY"
    else
        msg_error "Failed to create/update n8n PostgreSQL database/user."
    fi

    msg_info "Verifying n8n PostgreSQL login"
    if docker_cmd exec -i -e PGPASSWORD="$password" postgres psql -U "$user" -d "$db" -v ON_ERROR_STOP=1 -c 'SELECT 1;' >/dev/null 2>&1; then
        N8N_DB_READY="yes"
        msg_ok "N8N POSTGRESQL LOGIN VERIFIED"
    else
        msg_error "n8n PostgreSQL login verification failed."
    fi
}

function verify_redis_for_n8n() {
    section "N8N AUTOMATION REDIS CHECK"

    [ -n "${REDIS_PASSWORD:-}" ] || msg_error "REDIS_PASSWORD is missing from ${ENV_FILE}."

    msg_info "Checking Redis queue backend"
    if docker_cmd exec -e REDISCLI_AUTH="$REDIS_PASSWORD" redis redis-cli -n "${N8N_REDIS_DB:-2}" ping 2>/dev/null | grep -q PONG; then
        N8N_REDIS_READY="yes"
        msg_ok "REDIS QUEUE BACKEND VERIFIED"
    else
        msg_error "Redis queue backend check failed."
    fi
}

function validate_n8n_compose() {
    section "N8N AUTOMATION COMPOSE VALIDATION"
    N8N_COMPOSE_FILE="$(resolve_n8n_compose_file)"
    [ -f "$N8N_COMPOSE_FILE" ] || msg_error "n8n compose file not found: ${N8N_COMPOSE_FILE}"

    export DOCKER_DIR COMPOSE_DIR ENV_FILE DOMAIN
    msg_info "Validating n8n compose"
    run_docker_cmd "validating n8n compose" compose --env-file "$ENV_FILE" -p "$N8N_PROJECT" -f "$N8N_COMPOSE_FILE" config -q
    N8N_COMPOSE_READY="yes"
    msg_ok "N8N AUTOMATION COMPOSE VALID"
}

function deploy_n8n_stack() {
    section "N8N AUTOMATION DEPLOYMENT"

    N8N_COMPOSE_FILE="$(resolve_n8n_compose_file)"
    [ -f "$N8N_COMPOSE_FILE" ] || msg_error "n8n compose file not found: ${N8N_COMPOSE_FILE}"

    msg_info "Deploying n8n Automation"
    run_docker_cmd "deploying n8n Automation" compose --env-file "$ENV_FILE" -p "$N8N_PROJECT" -f "$N8N_COMPOSE_FILE" up -d
    N8N_DEPLOYED="yes"
    N8N_TOUCHED="yes"
    msg_ok "N8N AUTOMATION DEPLOYED"
}

function recreate_n8n_containers() {
    section "N8N AUTOMATION RECREATE"

    N8N_COMPOSE_FILE="$(resolve_n8n_compose_file)"
    [ -f "$N8N_COMPOSE_FILE" ] || msg_error "n8n compose file not found: ${N8N_COMPOSE_FILE}"

    echo -e "${YW}This recreates n8n containers only. It does not delete n8n database, appdata, or encryption key.${CL}"
    echo -e "${YW}Destructive data reset is intentionally not part of this safe Script 8 flow.${CL}"
    echo ""
    local confirm=""
    confirm="$(timed_yes_no "Recreate n8n containers now?" "n")"
    if [[ "$confirm" =~ ^[Nn] ]]; then
        N8N_ACTION="recreate-skipped"
        msg_skip "N8N CONTAINER RECREATE SKIPPED"
        return 0
    fi

    msg_info "Recreating n8n containers"
    run_docker_cmd "recreating n8n containers" compose --env-file "$ENV_FILE" -p "$N8N_PROJECT" -f "$N8N_COMPOSE_FILE" up -d --force-recreate
    N8N_DEPLOYED="yes"
    N8N_TOUCHED="yes"
    msg_ok "N8N CONTAINERS RECREATED"
}

function http_code_for_url() {
    local url="$1"
    curl -ksS -o /dev/null -w '%{http_code}' "$url" || true
}

function host_dns_resolves() {
    local host="$1"

    if [ -z "$host" ]; then
        return 1
    fi

    if command -v getent >/dev/null 2>&1; then
        getent hosts "$host" >/dev/null 2>&1 && return 0
    fi

    if command -v dig >/dev/null 2>&1; then
        [ -n "$(dig +short "$host" 2>/dev/null | head -n1)" ] && return 0
    fi

    return 1
}

function refresh_cf_companion_dns_for_host_if_needed() {
    local service_label="$1"
    local expected_host="$2"
    local cf_log_file=""
    local found_records=""
    local created_records=""
    local existing_records=""
    local updated_records=""
    local warn_lines=""

    [ -n "$expected_host" ] || return 0

    section "${service_label^^} CLOUDFLARE DNS CHECK"

    if host_dns_resolves "$expected_host"; then
        msg_ok "DNS already resolves: ${expected_host}"
        msg_ok "cf-companion restart skipped"
        msg_ok "${service_label^^} DNS CHECK COMPLETE"
        return 0
    fi

    if ! docker_cmd ps --format '{{.Names}}' 2>/dev/null | grep -qx 'cf-companion'; then
        msg_warn "cf-companion not present; skipping DNS rescan for ${expected_host}"
        return 0
    fi

    msg_info "Restarting cf-companion for ${service_label} DNS rescan"
    docker_cmd restart cf-companion >/dev/null 2>&1 || true
    sleep 15
    msg_ok "cf-companion restarted for ${service_label} DNS rescan"

    cf_log_file="$(mktemp)"
    TEMP_FILES+=("$cf_log_file")
    docker_cmd logs --tail=200 cf-companion 2>/dev/null >"$cf_log_file" || true

    found_records="$(grep -Ei 'Found Service ID:.*Hostname' "$cf_log_file" | sed -E 's/.*Hostname[[:space:]]*([^[:space:]]+).*/\1/' | grep -Fx "$expected_host" | sort -u || true)"
    created_records="$(grep -Ei 'Created new record:' "$cf_log_file" | sed -E 's/.*Created new record:[[:space:]]*([^[:space:]]+).*/\1/' | grep -Fx "$expected_host" | sort -u || true)"
    existing_records="$(grep -Ei 'Existing record:' "$cf_log_file" | sed -E 's/.*Existing record:[[:space:]]*([^[:space:]]+).*/\1/' | grep -Fx "$expected_host" | sort -u || true)"
    updated_records="$(grep -Ei 'Updated record:' "$cf_log_file" | sed -E 's/.*Updated record:[[:space:]]*([^[:space:]]+).*/\1/' | grep -Fx "$expected_host" | sort -u || true)"

    if [ -n "$found_records" ] || [ -n "$created_records" ] || [ -n "$existing_records" ] || [ -n "$updated_records" ]; then
        echo ""
        echo -e " ${CM} DNS discovery/action summary:${CL}"
        [ -n "$found_records" ] && echo -e "   - Found: ${expected_host}"
        [ -n "$created_records" ] && echo -e "   - Created: ${expected_host}"
        [ -n "$existing_records" ] && echo -e "   - Existing: ${expected_host}"
        [ -n "$updated_records" ] && echo -e "   - Updated: ${expected_host}"
    else
        msg_warn "No DNS discovery/action lines found for ${expected_host}"
    fi

    warn_lines="$(grep -Ei 'error|denied|unauthorized|authentication failed|invalid token|missing token|permission denied' "$cf_log_file" | head -n20 || true)"
    if [ -n "$warn_lines" ]; then
        msg_warn "cf-companion warnings/errors detected during ${service_label} DNS check"
        printf '%s\n' "$warn_lines"
    fi

    if host_dns_resolves "$expected_host"; then
        msg_ok "DNS now resolves: ${expected_host}"
    else
        msg_warn "DNS still does not resolve yet: ${expected_host}"
    fi

    msg_ok "${service_label^^} DNS CHECK COMPLETE"
}
function verify_n8n_routes() {
    local ui_code=""
    local webhook_code=""
    local ui_url="https://${N8N_HOST:-n8n.${DOMAIN}}/"
    local webhook_url="https://${N8N_HOST:-n8n.${DOMAIN}}/webhook/crea-script8-health-check"

    msg_info "Checking protected n8n UI route"
    ui_code="$(http_code_for_url "$ui_url")"
    case "$ui_code" in
        200|301|302|303|307|308|401|403)
            N8N_UI_ROUTE_OK="yes"
            N8N_ROUTE_WARNING="none"
            msg_ok "N8N PROTECTED UI ROUTE RESPONDED WITH HTTP ${ui_code}"
            ;;
        *)
            N8N_UI_ROUTE_OK="no"
            N8N_ROUTE_WARNING="ui-route-http-${ui_code:-none}"
            msg_warn "N8N UI ROUTE NEEDS REVIEW: HTTP ${ui_code:-none}. Review DNS/Traefik/AuthentiK."
            ;;
    esac

    msg_info "Checking public n8n webhook route"
    webhook_code="$(http_code_for_url "$webhook_url")"
    case "$webhook_code" in
        200|400|404|405)
            N8N_WEBHOOK_ROUTE_OK="yes"
            msg_ok "N8N WEBHOOK ROUTE REACHED N8N WITH HTTP ${webhook_code}"
            ;;
        301|302|303|307|308)
            N8N_WEBHOOK_ROUTE_OK="maybe-auth-protected"
            msg_warn "n8n webhook route redirected with HTTP ${webhook_code}. Ensure external webhooks are not blocked by Authentik."
            ;;
        *)
            N8N_WEBHOOK_ROUTE_OK="no"
            msg_warn "n8n webhook route returned HTTP ${webhook_code:-none}."
            ;;
    esac

    detail_line "n8n UI" "${ui_url} -> ${ui_code:-none}"
    detail_line "n8n webhook" "${webhook_url} -> ${webhook_code:-none}"
}

function verify_n8n_stack() {
    section "N8N AUTOMATION VERIFICATION"

    msg_info "Checking n8n container"
    if docker_cmd ps --format '{{.Names}}' | grep -qx 'n8n'; then
        N8N_MAIN_RUNNING="yes"
        msg_ok "N8N CONTAINER RUNNING"
    else
        N8N_MAIN_RUNNING="no"
        msg_warn "n8n container is not running"
    fi

    msg_info "Checking n8n worker container"
    if docker_cmd ps --format '{{.Names}}' | grep -qx 'n8n-worker'; then
        N8N_WORKER_RUNNING="yes"
        msg_ok "N8N WORKER RUNNING"
    else
        N8N_WORKER_RUNNING="no"
        msg_warn "n8n-worker container is not running"
    fi

    verify_redis_for_n8n
    # Database login was already checked during deploy/repair. Re-check read-only here.
    if n8n_db_login_readonly; then
        N8N_DB_READY="yes"
        msg_ok "N8N DATABASE LOGIN STILL WORKS"
    else
        N8N_DB_READY="no"
        msg_warn "n8n database login check failed"
    fi

    verify_n8n_routes

    if [ "$N8N_MAIN_RUNNING" == "yes" ] && [ "$N8N_WORKER_RUNNING" == "yes" ] && [ "$N8N_DB_READY" == "yes" ] && [ "$N8N_REDIS_READY" == "yes" ]; then
        N8N_VERIFIED="yes"
        msg_ok "N8N AUTOMATION CORE VERIFIED"
        if [ "$N8N_UI_ROUTE_OK" != "yes" ]; then
            msg_warn "N8N UI route is not verified; core backend checks passed only."
        fi
    else
        N8N_VERIFIED="no"
        msg_warn "N8N AUTOMATION NEEDS REVIEW"
    fi
}

function detect_n8n_state() {
    section "N8N AUTOMATION DETECTION"

    local compose_exists="no"
    local env_ok="no"
    local appdata_exists="no"
    local main_exists="no"
    local main_running="no"
    local worker_running="no"
    local db_readonly="no"
    local redis_readonly="no"
    local compose_path=""

    determine_n8n_compose_source "detect"
    compose_path="$(resolve_n8n_compose_file)"
    [ -f "$compose_path" ] && compose_exists="yes"
    [ -d "$N8N_APPDATA_DIR" ] && appdata_exists="yes"
    if [ -n "$(env_get N8N_POSTGRES_PASSWORD)" ] && [ -n "$(env_get N8N_ENCRYPTION_KEY)" ]; then env_ok="yes"; fi
    docker_cmd ps -a --format '{{.Names}}' | grep -qx 'n8n' && main_exists="yes"
    docker_cmd ps --format '{{.Names}}' | grep -qx 'n8n' && main_running="yes"
    docker_cmd ps --format '{{.Names}}' | grep -qx 'n8n-worker' && worker_running="yes"

    if [ "$main_running" == "yes" ]; then
        N8N_MAIN_HEALTH="$(n8n_container_health_state n8n)"
    else
        N8N_MAIN_HEALTH="not-running"
    fi
    if [ "$worker_running" == "yes" ]; then
        N8N_WORKER_HEALTH="$(n8n_container_health_state n8n-worker)"
    else
        N8N_WORKER_HEALTH="not-running"
    fi

    if [ "$env_ok" == "yes" ] && n8n_db_login_readonly; then db_readonly="yes"; fi
    if [ "$env_ok" == "yes" ] && n8n_redis_ping_readonly; then redis_readonly="yes"; fi

    detail_line "Compose file" "${compose_exists} (${compose_path})"
    detail_line "Compose source" "$N8N_COMPOSE_SOURCE"
    detail_line "Appdata" "$appdata_exists"
    detail_line "Secrets present" "$env_ok"
    detail_line "n8n container exists" "$main_exists"
    detail_line "n8n running" "$main_running"
    detail_line "n8n health" "$N8N_MAIN_HEALTH"
    detail_line "n8n worker running" "$worker_running"
    detail_line "n8n worker health" "$N8N_WORKER_HEALTH"
    detail_line "DB login read-only check" "$db_readonly"
    detail_line "Redis read-only check" "$redis_readonly"
    detail_line "Route check" "not used for healthy detection; checked during verification only"

    if [ "$compose_exists" == "yes" ]         && [ "$appdata_exists" == "yes" ]         && [ "$env_ok" == "yes" ]         && [ "$main_running" == "yes" ]         && [ "$worker_running" == "yes" ]         && [[ "$N8N_MAIN_HEALTH" != "unhealthy" ]]         && [[ "$N8N_WORKER_HEALTH" != "unhealthy" ]]         && [ "$db_readonly" == "yes" ]         && [ "$redis_readonly" == "yes" ]; then
        N8N_STATE="installed-appears-healthy"
        N8N_DB_READY="yes"
        N8N_REDIS_READY="yes"
    elif [ "$main_exists" == "yes" ] || [ "$compose_exists" == "yes" ] || [ "$appdata_exists" == "yes" ]; then
        N8N_STATE="installed-needs-review"
    else
        N8N_STATE="missing"
    fi

    msg_ok "N8N DETECTION COMPLETE"
    detail_line "Detected state" "$N8N_STATE"
}

function prompt_n8n_action() {
    section "N8N AUTOMATION PLAN"

    local skip_yn=""
    local choice=""

    case "$N8N_STATE" in
        missing)
            echo -e "${YW}${N8N_SERVICE_NAME} is not deployed yet.${CL}"
            skip_yn="$(timed_yes_no "Deploy ${N8N_SERVICE_NAME} now?" "y")"
            if [[ "$skip_yn" =~ ^[Nn] ]]; then N8N_ACTION="skip"; else N8N_ACTION="deploy"; fi
            ;;
        installed-appears-healthy)
            echo -e "${GN}${N8N_SERVICE_NAME} appears deployed and running.${CL}"
            echo -e "${YW}Default is to skip and leave the working setup untouched.${CL}"
            skip_yn="$(timed_yes_no "Skip ${N8N_SERVICE_NAME} and continue?" "y")"
            if [[ "$skip_yn" =~ ^[Yy] ]]; then
                N8N_ACTION="skip"
            else
                echo ""
                echo -e "${BL}Choose action:${CL}"
                echo -e "${YW}1) Check/repair ${N8N_SERVICE_NAME} and continue${CL}"
                echo -e "${YW}2) Update/redeploy compose for ${N8N_SERVICE_NAME}${CL}"
                echo -e "${YW}3) Recreate ${N8N_SERVICE_NAME} containers only${CL}"
                echo -e "${YW}4) Skip${CL}"
                choice="$(read_menu_choice "Select action" "4")"
                case "$choice" in
                    1) N8N_ACTION="repair" ;;
                    2) N8N_ACTION="update" ;;
                    3) N8N_ACTION="recreate" ;;
                    *) N8N_ACTION="skip" ;;
                esac
            fi
            ;;
        *)
            echo -e "${YW}${N8N_SERVICE_NAME} has existing files/containers but is not fully healthy.${CL}"
            echo ""
            echo -e "${BL}Choose action:${CL}"
            echo -e "${YW}1) Check/repair ${N8N_SERVICE_NAME} and continue${CL}"
            echo -e "${YW}2) Update/redeploy compose for ${N8N_SERVICE_NAME}${CL}"
            echo -e "${YW}3) Recreate ${N8N_SERVICE_NAME} containers only${CL}"
            echo -e "${YW}4) Skip and leave untouched${CL}"
            choice="$(read_menu_choice "Select action" "1")"
            case "$choice" in
                1) N8N_ACTION="repair" ;;
                2) N8N_ACTION="update" ;;
                3) N8N_ACTION="recreate" ;;
                *) N8N_ACTION="skip" ;;
            esac
            ;;
    esac

    detail_line "Selected action" "$N8N_ACTION"
}

function run_n8n_module() {
    detect_n8n_state
    prompt_n8n_action

    if [ "$N8N_ACTION" == "skip" ]; then
        SUMMARY_LINES+=("${N8N_SERVICE_NAME}|skipped|existing setup left untouched")
        msg_skip "${N8N_SERVICE_NAME} SKIPPED; EXISTING SETUP LEFT UNTOUCHED"
        return 0
    fi

    determine_n8n_compose_source "$N8N_ACTION"
    if ! show_n8n_ready_to_apply; then
        SUMMARY_LINES+=("${N8N_SERVICE_NAME}|skipped|plan cancelled before changes")
        return 0
    fi

    prepare_n8n_env_values
    prepare_n8n_appdata
    ensure_n8n_database
    verify_redis_for_n8n

    case "$N8N_ACTION" in
        deploy)
            download_n8n_compose_if_needed deploy
            validate_n8n_compose
            deploy_n8n_stack
            ;;
        repair)
            download_n8n_compose_if_needed repair
            validate_n8n_compose
            deploy_n8n_stack
            ;;
        update)
            download_n8n_compose_if_needed update
            validate_n8n_compose
            deploy_n8n_stack
            ;;
        recreate)
            download_n8n_compose_if_needed repair
            validate_n8n_compose
            recreate_n8n_containers
            ;;
        *)
            msg_skip "Unknown n8n action; skipping"
            return 0
            ;;
    esac

    refresh_cf_companion_dns_for_host_if_needed "n8n automation" "${N8N_HOST:-n8n.${DOMAIN}}"
    verify_n8n_stack
    SUMMARY_LINES+=("${N8N_SERVICE_NAME}|${N8N_ACTION}|verified=${N8N_VERIFIED}")
}

# =========================================================
#  REPORTING
# =========================================================

function write_verification_report() {
    section "VERIFICATION REPORT"

    msg_info "Writing post-core verification report"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" bash -c "cat > '$VERIFY_LOG'" <<EOF_REPORT
--- CREA POST-CORE SETUP VERIFICATION REPORT ---
Date: $(date)
Docker user: $DOCKER_USER
Docker dir: $DOCKER_DIR
Compose dir: $COMPOSE_DIR
Domain: $DOMAIN
Admin UI: $ADMIN_UI

n8n Automation:
State: $N8N_STATE
Action: $N8N_ACTION
Touched: $N8N_TOUCHED
Compose source: $N8N_COMPOSE_SOURCE
Env backup created this run: $N8N_ENV_BACKUP_CREATED
Env backup path: ${N8N_ENV_BACKUP_PATH:-none}
N8N_POSTGRES_PASSWORD status: $(n8n_secret_status_for N8N_POSTGRES_PASSWORD)
N8N_ENCRYPTION_KEY status: $(n8n_secret_status_for N8N_ENCRYPTION_KEY)
PostgreSQL identifier status: $N8N_DB_IDENTIFIER_STATUS
Env ready: $N8N_ENV_READY
Appdata ready: $N8N_APPDATA_READY
DB ready: $N8N_DB_READY
Redis ready: $N8N_REDIS_READY
Compose ready: $N8N_COMPOSE_READY
Deployed: $N8N_DEPLOYED
Main running: $N8N_MAIN_RUNNING
Worker running: $N8N_WORKER_RUNNING
UI route OK: $N8N_UI_ROUTE_OK
Webhook route OK: $N8N_WEBHOOK_ROUTE_OK
Verified: $N8N_VERIFIED
Compose file: ${N8N_COMPOSE_FILE:-$(resolve_n8n_compose_file)}
Appdata: $N8N_APPDATA_DIR
Appdata owner: ${N8N_APPDATA_OWNER:-not-set}
Main health: $N8N_MAIN_HEALTH
Worker health: $N8N_WORKER_HEALTH
Route warning: $N8N_ROUTE_WARNING
EOF_REPORT
    else
        cat > "$VERIFY_LOG" <<EOF_REPORT
--- CREA POST-CORE SETUP VERIFICATION REPORT ---
Date: $(date)
Docker user: $DOCKER_USER
Docker dir: $DOCKER_DIR
Compose dir: $COMPOSE_DIR
Domain: $DOMAIN
Admin UI: $ADMIN_UI

n8n Automation:
State: $N8N_STATE
Action: $N8N_ACTION
Touched: $N8N_TOUCHED
Compose source: $N8N_COMPOSE_SOURCE
Env backup created this run: $N8N_ENV_BACKUP_CREATED
Env backup path: ${N8N_ENV_BACKUP_PATH:-none}
N8N_POSTGRES_PASSWORD status: $(n8n_secret_status_for N8N_POSTGRES_PASSWORD)
N8N_ENCRYPTION_KEY status: $(n8n_secret_status_for N8N_ENCRYPTION_KEY)
PostgreSQL identifier status: $N8N_DB_IDENTIFIER_STATUS
Env ready: $N8N_ENV_READY
Appdata ready: $N8N_APPDATA_READY
DB ready: $N8N_DB_READY
Redis ready: $N8N_REDIS_READY
Compose ready: $N8N_COMPOSE_READY
Deployed: $N8N_DEPLOYED
Main running: $N8N_MAIN_RUNNING
Worker running: $N8N_WORKER_RUNNING
UI route OK: $N8N_UI_ROUTE_OK
Webhook route OK: $N8N_WEBHOOK_ROUTE_OK
Verified: $N8N_VERIFIED
Compose file: ${N8N_COMPOSE_FILE:-$(resolve_n8n_compose_file)}
Appdata: $N8N_APPDATA_DIR
Appdata owner: ${N8N_APPDATA_OWNER:-not-set}
Main health: $N8N_MAIN_HEALTH
Worker health: $N8N_WORKER_HEALTH
Route warning: $N8N_ROUTE_WARNING
EOF_REPORT
    fi

    msg_ok "POST-CORE VERIFICATION REPORT WRITTEN"
    detail_line "Verify log" "$VERIFY_LOG"
}

function write_completion_marker() {
    section "COMPLETION MARKER"
    msg_info "Writing completion marker"

    if [ -n "$SUDO_CMD" ]; then
        "$SUDO_CMD" bash -c "cat > '$COMPLETED_MARKER'" <<EOF_MARKER
Crea Post-Core Setup completed on: $(date)
Docker user: $DOCKER_USER
Docker dir: $DOCKER_DIR
Compose dir: $COMPOSE_DIR
Domain: $DOMAIN
n8n action: $N8N_ACTION
n8n verified: $N8N_VERIFIED
Verify log: $VERIFY_LOG
EOF_MARKER
    else
        cat > "$COMPLETED_MARKER" <<EOF_MARKER
Crea Post-Core Setup completed on: $(date)
Docker user: $DOCKER_USER
Docker dir: $DOCKER_DIR
Compose dir: $COMPOSE_DIR
Domain: $DOMAIN
n8n action: $N8N_ACTION
n8n verified: $N8N_VERIFIED
Verify log: $VERIFY_LOG
EOF_MARKER
    fi

    msg_ok "COMPLETION MARKER WRITTEN"
}

function show_secret_summary() {
    if [ "${#GENERATED_SECRET_LINES[@]}" -eq 0 ]; then
        section "SAVE THESE NEW OR PASTED SECRETS"
        echo -e "${GN}No new or pasted secrets were created in this run.${CL}"
        echo -e "${YW}Existing secrets were reused and not displayed.${CL}"
        return 0
    fi

    disable_logging
    section "SAVE THESE NEW OR PASTED SECRETS"
    echo -e "${YW}Store these values in your password manager. Do not commit them to GitHub.${CL}"
    echo -e "${YW}This secret summary is displayed only on the terminal and is not written to the script log.${CL}"
    echo ""
    local line=""
    local key=""
    local value=""
    local mode=""
    for line in "${GENERATED_SECRET_LINES[@]}"; do
        IFS='|' read -r key value mode <<< "$line"
        detail_line "${key} (${mode})" "$value"
    done
    enable_logging
}
function show_final_summary() {
    section_flash_success "     ━━━━━━━━━━━━━━━━━    POST-CORE SETUP FINISHED    ━━━━━━━━━━━━━━━━━"

    detail_line "DOMAIN" "$DOMAIN"
    detail_line "ADMIN UI" "$ADMIN_UI"
    detail_line "N8N STATE" "$N8N_STATE"
    detail_line "N8N ACTION" "$N8N_ACTION"
    detail_line "N8N TOUCHED" "$N8N_TOUCHED"
    detail_line "N8N VERIFIED" "$N8N_VERIFIED"
    detail_line "N8N COMPOSE SOURCE" "$N8N_COMPOSE_SOURCE"
    detail_line "ENV BACKUP THIS RUN" "$N8N_ENV_BACKUP_CREATED"
    detail_line "N8N UI ROUTE" "$N8N_UI_ROUTE_OK"
    detail_line "N8N WEBHOOK ROUTE" "$N8N_WEBHOOK_ROUTE_OK"
    detail_line "VERIFY LOG" "$VERIFY_LOG"

    echo ""
    if [ "$N8N_ACTION" == "skip" ]; then
        echo -e "${GN}${N8N_SERVICE_NAME} was skipped and left untouched.${CL}"
    elif [ "$N8N_VERIFIED" == "yes" ]; then
        echo -e "${GN}${N8N_SERVICE_NAME} is deployed and core checks passed.${CL}"
        echo -e "${YW}UI/editor:${CL} https://n8n.${DOMAIN}/"
        echo -e "${YW}Production webhooks:${CL} https://n8n.${DOMAIN}/webhook/..."
    else
        echo -e "${YW}${N8N_SERVICE_NAME} completed with warnings. Review the verification report and container logs.${CL}"
    fi
    echo ""
}

# =========================================================
#  MAIN
# =========================================================

function start_confirmation() {
    section "START"
    echo -e "${YW}This script manages post-core production add-on services for Project Crea.${CL}"
    echo -e "${YW}It does not touch working Scripts 1-7 core infrastructure unless a selected add-on service requires a read-only check.${CL}"
    echo ""
    echo -e "${BL}Current module:${CL} ${N8N_SERVICE_NAME}"
    echo ""
    local start_yn=""
    start_yn="$(timed_yes_no "Start Post-Core Setup?" "y")"
    if [[ "$start_yn" =~ ^[Nn] ]]; then exit 0; fi
}

function main() {
    init_script
    detect_docker_access
    load_env_file
    detect_admin_ui
    verify_core_services_read_only
    start_confirmation

    run_n8n_module
    run_landing_module
    run_admin_dashboard_module
    run_filebrowser_quantum_module

    write_verification_report
    write_completion_marker
    show_secret_summary
    show_final_summary

    exit 0
}

main "$@"
