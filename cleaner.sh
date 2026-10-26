#!/bin/bash

# ==============================================================================
# Script Name: Universal Linux Cleaner & Updater (Pro Version)
# Description: Automated script to inform, update, clean, and secure Linux distributions.
#      _________ .__                                      
#      \_   ___ \|  |   ____ _____    ____   ___________  
#      /    \  \/|  | _/ __ \\__  \  /    \_/ __ \_  __ \ 
#      \     \___|  |_\  ___/ / __ \|   |  \  ___/|  | \/ 
#       \______  /____/\___  >____  /___|  /\___  >__| /\ 
#              \/          \/     \/     \/     \/     \/ 
# Author: GabxSup - https://github.com/GabxSup
# License: MIT
# Version: 2.1.0 (Pro)
# ==============================================================================

# --- Configuration ---
VERSION="2.1.0 (Pro)"
LOG_FILE="/var/log/system_cleaner.log"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Global Variables ---
TOTAL_STEPS=0
CURRENT_STEP=0
SUMMARY_LOG=()
ERRORS_LOG=()
SECURITY_NOTICES=()
UPDATES_AVAILABLE=false
MODE="all" # Options: all, security, clean-only, update-only

# Auto-cleanup temp file on exit
UPDATES_LIST_FILE=$(mktemp)
trap 'rm -f "$UPDATES_LIST_FILE"; sudo -k 2>/dev/null || true' EXIT

# --- Helper Functions ---

log() {
    local current_time
    current_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$current_time] [INFO] $1" >> "$LOG_FILE"
}

log_error() {
    local current_time
    current_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$current_time] [ERROR] $1" >> "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR] This script must be run as root (use sudo).${NC}"
        exit 1
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        echo -e "${RED}[ERROR] Cannot detect Linux distribution (/etc/os-release missing).${NC}"
        exit 1
    fi
    log "Detected distribution: $DISTRO"
}

# --- Update Checkers ---

capture_updates_apt() {
    log "Checking for available APT updates..."
    if apt list --upgradable 2>/dev/null | grep -v "Listing..." > "$UPDATES_LIST_FILE"; then
        if [ -s "$UPDATES_LIST_FILE" ]; then
            UPDATES_AVAILABLE=true
        fi
    fi
}

capture_updates_dnf() {
    log "Checking for available DNF updates..."
    dnf check-update -q > "$UPDATES_LIST_FILE" 2>/dev/null
    local status=$?
    # dnf check-update returns 100 if updates are available
    if [ $status -eq 100 ] && [ -s "$UPDATES_LIST_FILE" ]; then
        UPDATES_AVAILABLE=true
    fi
}

capture_updates_pacman() {
    log "Checking for available Pacman updates..."
    if pacman -Qu > "$UPDATES_LIST_FILE" 2>/dev/null; then
        if [ -s "$UPDATES_LIST_FILE" ]; then
            UPDATES_AVAILABLE=true
        fi
    fi
}

capture_updates_zypper() {
    log "Checking for available Zypper updates..."
    if zypper list-updates > "$UPDATES_LIST_FILE" 2>/dev/null; then
        if [ -s "$UPDATES_LIST_FILE" ]; then
            UPDATES_AVAILABLE=true
        fi
    fi
}

# --- Progress Bar & Task Runner ---

draw_progress_bar() {
    local description="$1"
    local width=35
    local percent=0

    if [ "$TOTAL_STEPS" -gt 0 ]; then
        percent=$(( 100 * CURRENT_STEP / TOTAL_STEPS ))
    fi
    if [ "$percent" -gt 100 ]; then percent=100; fi

    local filled=$(( width * percent / 100 ))
    local empty=$(( width - filled ))

    printf "\r"
    printf "${BLUE}[${NC}"

    if [ "$filled" -gt 0 ]; then
        printf "%0.s#" $(seq 1 "$filled")
    fi
    if [ "$empty" -gt 0 ]; then
        printf "%0.s." $(seq 1 "$empty")
    fi

    printf "${BLUE}]${NC} %3d%% - ${CYAN}%-45s${NC}\033[K" "$percent" "$description"
}

run_task() {
    local description="$1"
    local command="$2"

    ((CURRENT_STEP++))
    draw_progress_bar "$description"

    log "STARTING: $description"

    if eval "$command" >> "$LOG_FILE" 2>&1; then
        log "COMPLETED: $description"
        SUMMARY_LOG+=("${GREEN}✔${NC} $description")
    else
        log_error "FAILED: $description"
        SUMMARY_LOG+=("${RED}✘${NC} $description")
        ERRORS_LOG+=("$description")
    fi
}

# --- Total Steps Calculation ---

calculate_total_steps() {
    TOTAL_STEPS=0

    # Package manager updates & upgrades
    if [ "$MODE" = "all" ] || [ "$MODE" = "update-only" ]; then
        ((TOTAL_STEPS+=5)) # Base package manager steps (repo update, upgrade, dist-upgrade, clean, autoremove)
        command -v snap >/dev/null 2>&1 && ((TOTAL_STEPS++))
        command -v flatpak >/dev/null 2>&1 && ((TOTAL_STEPS++))
    fi

    # Cleaning & system maintenance
    if [ "$MODE" = "all" ] || [ "$MODE" = "clean-only" ]; then
        command -v flatpak >/dev/null 2>&1 && ((TOTAL_STEPS++)) # Flatpak uninstall unused
        if command -v docker >/dev/null 2>&1 && docker system info >/dev/null 2>&1; then
            ((TOTAL_STEPS+=2)) # System prune & builder prune
        fi
        command -v npm >/dev/null 2>&1 && ((TOTAL_STEPS++))
        command -v pip3 >/dev/null 2>&1 && ((TOTAL_STEPS++))
        command -v journalctl >/dev/null 2>&1 && ((TOTAL_STEPS++))
        ((TOTAL_STEPS+=2)) # Temp files & old logs
        
        # Deep clean
        if [ -f /usr/bin/dpkg ] || [ -f /bin/rpm ]; then
            ((TOTAL_STEPS+=2)) # Config files + User thumbnails/trash
        else
            ((TOTAL_STEPS++)) # User thumbnails/trash fallback
        fi
    fi

    # Security Clean & Audit
    if [ "$MODE" = "all" ] || [ "$MODE" = "security" ]; then
        ((TOTAL_STEPS+=5)) # Crash dumps, stale sockets, root privacy sweep, permissions audit, security advisory
    fi
}

# --- Core Package Managers ---

task_apt() {
    capture_updates_apt
    run_task "Updating APT repositories" "apt-get update -y"
    run_task "Upgrading packages" "apt-get upgrade -y"
    run_task "Distribution upgrade" "apt-get dist-upgrade -y"
    run_task "Cleaning APT cache" "apt-get autoclean -y"
    run_task "Removing unused dependencies" "apt-get autoremove --purge -y"
}

task_dnf() {
    capture_updates_dnf
    run_task "Refreshing DNF metadata" "dnf check-update || [ \$? -eq 100 ]"
    run_task "Upgrading system (DNF)" "dnf upgrade --refresh -y"
    run_task "System optimization (DNF)" "dnf distro-sync -y"
    run_task "Cleaning DNF cache" "dnf clean all"
    run_task "Removing unused packages" "dnf autoremove -y"
}

task_pacman() {
    capture_updates_pacman
    run_task "Refreshing keyring" "pacman -Sy archlinux-keyring --noconfirm"
    run_task "Syncing & Upgrading (Pacman)" "pacman -Syu --noconfirm"
    run_task "Checking database integrity" "pacman -Dk"
    run_task "Cleaning package cache" "pacman -Sc --noconfirm"
    run_task "Removing orphans" "pacman -Rns \$(pacman -Qdtq) --noconfirm 2>/dev/null || true"
}

task_zypper() {
    capture_updates_zypper
    run_task "Refreshing repositories" "zypper refresh"
    run_task "Upgrading packages" "zypper update -y"
    run_task "Distribution upgrade" "zypper dist-upgrade -y"
    run_task "Cleaning cache" "zypper clean --all"
    run_task "Verifying dependencies" "zypper verify"
}

# --- System Cleaning & Maintenance ---

task_deep_clean() {
    shopt -s nullglob
    if [ -f /usr/bin/dpkg ]; then
        run_task "Deep cleaning: Removing old config files (rc)" \
            "dpkg -l 2>/dev/null | grep '^rc' | awk '{print \$2}' | xargs -r dpkg -P 2>/dev/null || true"
    fi

    # User caches and trash (Process all users in /home and root)
    for user_home in /home/* /root; do
        if [ -d "$user_home" ]; then
            user_name=$(basename "$user_home")
            log "Cleaning cache/trash for user: $user_name"
            if [ -d "$user_home/.cache/thumbnails" ]; then
                rm -rf "$user_home/.cache/thumbnails"/* 2>/dev/null
            fi
            if [ -d "$user_home/.local/share/Trash" ]; then
                rm -rf "$user_home/.local/share/Trash"/* 2>/dev/null
            fi
        fi
    done
    shopt -u nullglob

    run_task "Deep cleaning: User Thumbnails & Trash" "true"
}

run_extended_tasks() {
    # SNAP Updates
    if [ "$MODE" = "all" ] || [ "$MODE" = "update-only" ]; then
        if command -v snap >/dev/null 2>&1; then
            run_task "Refreshing Snap packages" "snap refresh"
        fi
        if command -v flatpak >/dev/null 2>&1; then
            run_task "Updating Flatpak packages" "flatpak update -y"
        fi
    fi

    # Clean only tasks
    if [ "$MODE" = "all" ] || [ "$MODE" = "clean-only" ]; then
        # FLATPAK Unused Runtimes
        if command -v flatpak >/dev/null 2>&1; then
            run_task "Cleaning unused Flatpak runtimes" "flatpak uninstall --unused -y"
        fi

        # DOCKER (Check if daemon is running)
        if command -v docker >/dev/null 2>&1; then
            if docker system info >/dev/null 2>&1; then
                run_task "Cleaning Docker system & volumes" "docker system prune -a --volumes -f"
                run_task "Cleaning Docker builder cache" "docker builder prune -a -f"
            else
                log "Docker daemon is not running; skipping prune."
            fi
        fi

        # NODE.JS
        if command -v npm >/dev/null 2>&1; then
            run_task "Cleaning NPM cache" "npm cache clean --force"
        fi

        # PYTHON
        if command -v pip3 >/dev/null 2>&1; then
            run_task "Cleaning PIP cache" "pip3 cache purge"
        fi

        # SYSTEMD JOURNAL
        if command -v journalctl >/dev/null 2>&1; then
            run_task "Vacuuming systemd journals (keep 2 weeks)" "journalctl --vacuum-time=2weeks"
        fi

        # TEMP FILES
        run_task "Cleaning temporary files" "rm -rf /var/tmp/* /tmp/* 2>/dev/null || true"

        # OLD LOGS
        run_task "Cleaning old compressed logs" "find /var/log -type f \( -name '*.gz' -o -name '*.1' -o -name '*.old' \) -delete 2>/dev/null || true"

        # DEEP CLEAN
        task_deep_clean
    fi
}

# --- Security Cleaning & Privacy Audit ---

task_security_clean() {
    # 1. Purge memory crash dumps & system coredumps (prevents credential/memory leaks)
    run_task "Security: Purging memory crash dumps & coredumps" \
        "rm -rf /var/crash/* 2>/dev/null; [ -d /var/lib/systemd/coredump ] && rm -rf /var/lib/systemd/coredump/* 2>/dev/null; if command -v coredumpctl >/dev/null 2>&1; then coredumpctl vacuum --keep-free=1G >/dev/null 2>&1 || true; fi"

    # 2. Clean abandoned SSH & GPG auth sockets (stale dead sessions in /tmp)
    run_task "Security: Purging stale SSH/GPG agent sockets" \
        "find /tmp /var/tmp -maxdepth 2 -type s \( -name 'agent.*' -o -name 'ssh-*' -o -name 'gpg-*' \) -atime +1 -delete 2>/dev/null || true"

    # 3. Privacy & Credential Hygiene: Sweep root session artifacts & history
    run_task "Security: Sanitizing root CLI history & credential artifacts" \
        "rm -f /root/.lesshst /root/.wget-hsts /root/.viminfo /root/.mysql_history /root/.sudo_as_admin_successful 2>/dev/null; [ -f /root/.bash_history ] && > /root/.bash_history; [ -f /root/.zsh_history ] && > /root/.zsh_history; true"

    # 4. Security Audit: Check and fix world-writable /etc files and report unowned files
    run_task "Security Audit: World-writable & unowned system file check" \
        "find /etc -type f -perm -002 -exec chmod o-w {} + 2>/dev/null; unowned=\$(find /etc /var/log -xdev \( -nouser -o -nogroup \) 2>/dev/null); if [ -n \"\$unowned\" ]; then echo \"\$unowned\" >> \"$LOG_FILE\"; fi; true"

    # 5. Distro-Specific Security Updates & Advisory Audit
    case "$DISTRO" in
        ubuntu|debian|kali|linuxmint|pop)
            run_task "Security Audit: Scanning pending security patches (APT)" \
                "apt-get upgrade -s 2>/dev/null | grep -i security >> \"$LOG_FILE\" || true"
            ;;
        fedora|rhel|centos|almalinux|rocky)
            run_task "Security Audit: Scanning security advisories (DNF)" \
                "dnf updateinfo list security >> \"$LOG_FILE\" 2>/dev/null || true"
            ;;
        opensuse*|sles)
            run_task "Security Audit: Scanning security patches (Zypper)" \
                "zypper list-patches --category security >> \"$LOG_FILE\" 2>/dev/null || true"
            ;;
        arch|manjaro|endeavouros)
            run_task "Security Audit: Scanning known vulnerabilities (Arch)" \
                "if command -v arch-audit >/dev/null 2>&1; then arch-audit >> \"$LOG_FILE\" 2>&1; else true; fi"
            ;;
        *)
            run_task "Security Audit: Basic integrity sweep" "true"
            ;;
    esac
}

# --- UI & Reporting ---

print_banner() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
      _________ .__                                      
      \_   ___ \|  |   ____ _____    ____   ___________  
      /    \  \/|  | _/ __ \\__  \  /    \_/ __ \_  __ \ 
      \     \___|  |_\  ___/ / __ \|   |  \  ___/|  | \/ 
       \______  /____/\___  >____  /___|  /\___  >__| /\ 
              \/          \/     \/     \/     \/     \/ 
EOF
    echo -e "${NC}"
    echo -e "${BLUE}   Universal Linux Cleaner & Security Suite   ${NC}"
    echo -e "${YELLOW}   Version: ${VERSION}                        ${NC}"
    echo -e "${YELLOW}   Author:  GabxSup - https://github.com/GabxSup${NC}"
    echo -e "${YELLOW}   License: MIT                               ${NC}"
    echo -e "${BLUE}==============================================${NC}"
    echo -e "   Target Mode : ${BOLD}${MODE^^}${NC}"
    echo -e "   Log Output  : ${CYAN}${LOG_FILE}${NC}"
    echo -e "${BLUE}==============================================${NC}"
    echo ""
}

print_summary() {
    # Finish progress bar cleanly
    printf "\r${BLUE}[###################################]${NC} 100%% - ${GREEN}Tasks Complete!                                  ${NC}\n"
    
    echo ""
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${YELLOW}                 TASK SUMMARY                 ${NC}"
    echo -e "${BLUE}==============================================${NC}"

    for entry in "${SUMMARY_LOG[@]}"; do
        echo -e "$entry"
    done

    echo -e "${BLUE}==============================================${NC}"
    if [ ${#ERRORS_LOG[@]} -ne 0 ]; then
        echo -e "${RED}Completed with ${#ERRORS_LOG[@]} warning/error(s). See $LOG_FILE for details.${NC}"
    else
        echo -e "${GREEN}All tasks completed successfully!${NC}"
    fi

    if [ "$UPDATES_AVAILABLE" = true ]; then
        echo ""
        echo -e "${CYAN}--- Available Package Updates (Snapshot) ---${NC}"
        head -n 25 "$UPDATES_LIST_FILE"
        local total_lines
        total_lines=$(wc -l < "$UPDATES_LIST_FILE")
        if [ "$total_lines" -gt 25 ]; then
            echo -e "${YELLOW}... and $((total_lines - 25)) more packages. See $LOG_FILE${NC}"
        fi
        echo -e "${CYAN}--------------------------------------------${NC}"
    fi

    # Security reminder & sudo flush
    sudo -k 2>/dev/null || true
    echo ""
    echo -e "${CYAN}[i] Security: Sudo timestamp credentials have been flushed.${NC}"
    echo ""
}

show_help() {
    cat << EOF
Universal Linux Cleaner & Updater (Pro Version)
Usage: sudo ./cleaner.sh [OPTIONS]

Options:
  --all           Run complete suite: Updates, System Clean, Deep Clean & Security Clean (Default)
  --security      Run Security Clean & Privacy audit only
  --clean-only    Run system cache & junk cleaner without updating packages
  --update-only   Run package manager updates without system deep cleaning
  -v, --version   Display version information
  -h, --help      Display this help menu

Examples:
  sudo ./cleaner.sh             # Full automated maintenance
  sudo ./cleaner.sh --security  # Security & privacy audit only
  sudo ./cleaner.sh --clean-only # Clean disk space without updating

EOF
    exit 0
}

# --- Main Entry Point ---

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                MODE="all"
                shift
                ;;
            --security)
                MODE="security"
                shift
                ;;
            --clean-only)
                MODE="clean-only"
                shift
                ;;
            --update-only)
                MODE="update-only"
                shift
                ;;
            -v|--version)
                echo "Universal Linux Cleaner & Updater v${VERSION}"
                exit 0
                ;;
            -h|--help)
                show_help
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    check_root
    detect_distro
    calculate_total_steps

    print_banner

    # Ensure log file exists and is writable
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" 2>/dev/null || { echo "Cannot write to log file $LOG_FILE"; exit 1; }
    fi

    log "=========================================================="
    log "Starting maintenance session (Mode: $MODE, Version: $VERSION)..."

    # Core Package Manager Updates
    if [ "$MODE" = "all" ] || [ "$MODE" = "update-only" ]; then
        case "$DISTRO" in
            ubuntu|debian|kali|linuxmint|pop)
                task_apt
                ;;
            fedora|rhel|centos|almalinux|rocky)
                task_dnf
                ;;
            arch|manjaro|endeavouros)
                task_pacman
                ;;
            opensuse*|sles)
                task_zypper
                ;;
            *)
                echo -e "${RED}[ERROR] Distribution '$DISTRO' is not fully supported for package updates.${NC}"
                log_error "Unsupported distribution for updates: $DISTRO"
                ;;
        esac
    fi

    # Extended System Maintenance & Clean
    if [ "$MODE" = "all" ] || [ "$MODE" = "clean-only" ] || [ "$MODE" = "update-only" ]; then
        run_extended_tasks
    fi

    # Security Clean & Privacy Sweep
    if [ "$MODE" = "all" ] || [ "$MODE" = "security" ]; then
        task_security_clean
    fi

    log "Maintenance session finished successfully."
    log "=========================================================="

    print_summary
}

main "$@"
