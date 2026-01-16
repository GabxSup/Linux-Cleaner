#!/bin/bash

# ==============================================================================
# Script Name: Universal Linux Cleaner & Updater (Pro Version)
# Description: Automated script to inform, update, and clean various Linux distributions.
#      _________ .__                                      
#      \_   ___ \|  |   ____ _____    ____   ___________  
#      /    \  \/|  | _/ __ \\__  \  /    \_/ __ \_  __ \ 
#      \     \___|  |_\  ___/ / __ \|   |  \  ___/|  | \/ 
#       \______  /____/\___  >____  /___|  /\___  >__| /\ 
#              \/          \/     \/     \/     \/     \/ 
# Author: GabxSup - https://github.com/GabxSup
# License: MIT
# ==============================================================================

# --- Configuration ---
LOG_FILE="/var/log/system_cleaner.log"
DATE=$(date +%Y-%m-%d_%H-%M-%S)

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Global Variables ---
TOTAL_STEPS=0
CURRENT_STEP=0
SUMMARY_LOG=()
ERRORS_LOG=()

# --- Helper Functions ---

log() {
    echo "[$DATE] [INFO] $1" >> "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
       echo -e "${RED}[ERROR] This script must be run as root.${NC}"
       echo "[$DATE] [ERROR] Script run without root privileges." >> "$LOG_FILE"
       exit 1
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        echo -e "${RED}[ERROR] Cannot detect Linux distribution.${NC}"
        exit 1
    fi
    log "Detected distribution: $DISTRO"
}

# --- Progress Bar & UI ---

calculate_total_steps() {
    # Base steps for update/clean (Update repo, Upgrade Pkg, Dist Upgrade, Clean, Autoremove)
    TOTAL_STEPS=5
    
    # Dynamic checks
    command -v snap >/dev/null 2>&1 && ((TOTAL_STEPS++))
    command -v flatpak >/dev/null 2>&1 && ((TOTAL_STEPS++))
    command -v docker >/dev/null 2>&1 && ((TOTAL_STEPS++)) # Prune
    
    # Generic steps (Journal vacuum, Thumbnails/Temp)
    ((TOTAL_STEPS+=2))
}

draw_progress_bar() {
    local description="$1"
    local width=40
    local percent=$(( 100 * CURRENT_STEP / TOTAL_STEPS ))
    if [ $percent -gt 100 ]; then percent=100; fi
    
    local filled=$(( width * percent / 100 ))
    local empty=$(( width - filled ))
    
    # Carriage return to overwrite line
    printf "\r"
    printf "${BLUE}[${NC}"
    
    # Filled part
    if [ $filled -gt 0 ]; then
        printf "%0.s#" $(seq 1 $filled)
    fi
    
    # Empty part
    if [ $empty -gt 0 ]; then
        printf "%0.s." $(seq 1 $empty)
    fi
    
    printf "${BLUE}]${NC} ${percent}%% - ${CYAN}${description}${NC}"
    
    # Clear the rest of the line just in case
    printf "\033[K"
}

run_task() {
    local description="$1"
    local command="$2"
    
    ((CURRENT_STEP++))
    draw_progress_bar "$description..."
    
    log "STARTING: $description"
    
    # Run the command, capturing output to log
    if eval "$command" >> "$LOG_FILE" 2>&1; then
        log "COMPLETED: $description"
        SUMMARY_LOG+=("${GREEN}✔${NC} $description")
    else
        log "FAILED: $description"
        SUMMARY_LOG+=("${RED}✘${NC} $description")
        ERRORS_LOG+=("$description")
    fi
}

# --- Package Manager Logic ---

# DEBIAN / UBUNTU
task_apt() {
    # 1
    run_task "Updating APT repositories" "apt-get update -y"
    # 2
    run_task "Upgrading packages" "apt-get upgrade -y"
    # 3
    run_task "Distribution upgrade" "apt-get dist-upgrade -y"
    # 4
    run_task "Cleaning APT cache" "apt-get autoclean -y"
    # 5
    run_task "Removing unused dependencies" "apt-get autoremove --purge -y"
}

# RHEL / FEDORA
task_dnf() {
    run_task "Refreshing DNF metadata" "dnf check-update"
    # Note: check-update returns 100 if updates are available, so we might fail here incorrectly if we strict check exit code 0.
    # dnf check-update returns 100 if updates are available. We should allow 100 or 0.
    # However, eval checks simple boolean. 
    # Let's wrap it in a subshell or accept failures for check-update? 
    # Actually, let's skip check-update as a 'task' and just do upgrade --refresh which does both.
    # But wait, I'll just change the logic slightly. 
    # Let's replace check-update with something safer or ignore failure.
} 
# Re-implementing task_dnf inside the actual file write below correctly.

# ARCH
task_pacman() {
    run_task "Syncing & Upgrading (Pacman)" "pacman -Syu --noconfirm"
    # Placeholder
    run_task "Checking database integrity" "pacman -Dk"
    # Placeholder
    run_task "Refreshing keyring" "pacman -Sy archlinux-keyring --noconfirm"
    run_task "Cleaning package cache" "pacman -Sc --noconfirm"
    run_task "Removing orphans" "pacman -Rns \$(pacman -Qdtq) --noconfirm || true"
}

# ZYPPER
task_zypper() {
    run_task "Refreshing repositories" "zypper refresh"
    run_task "Upgrading packages" "zypper update -y"
    run_task "Distribution upgrade" "zypper dist-upgrade -y"
    run_task "Cleaning cache" "zypper clean --all"
    # Zypper doesn't strictly have 'autoremove' same as apt, but we can verify dependencies
    run_task "Verifying dependencies" "zypper verify"
}

# --- Extended Update & Cleaning ---

run_extended_tasks() {
    # SNAP
    if command -v snap >/dev/null 2>&1; then
        run_task "Refreshing Snap packages" "snap refresh"
    fi
    
    # FLATPAK
    if command -v flatpak >/dev/null 2>&1; then
        run_task "Updating Flatpak packages" "flatpak update -y"
        # We can also clean unused runtimes
        # run_task "removing unused flatpaks" "flatpak uninstall --unused -y"
    fi
    
    # DOCKER
    if command -v docker >/dev/null 2>&1; then
        run_task "Cleaning Docker system (Prune)" "docker system prune -f"
    fi
    
    # GENERIC SYSTEM CLEANUP
    # 1. Journal
    if command -v journalctl >/dev/null 2>&1; then
        run_task "Vacuuming systemd journals (keep 2 weeks)" "journalctl --vacuum-time=2weeks"
    else 
        # Skip if not found to balance step count
        ((CURRENT_STEP++))
    fi
    
    # 2. Temp files
    run_task "Cleaning temporary files" "rm -rf /var/tmp/*"
}

# --- Main Logic ---

print_banner() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
			
_̣_______________    __                         
___ _____  ____/___  /__________ ____________________
  ____ __  / _____  /_  _ \  __ `/_  __ \  _ \_  ___/
   ___  / /___  _  / /  __/ /_/ /_  / / /  __/  /    
        \____/  /_/  \___/\__,_/ /_/ /_/\___//_/     
                                             
EOF
    echo -e "${NC}"
    echo -e "${BLUE}   Universal Linux Cleaner & Updater     ${NC}"
    echo -e "${YELLOW}   Version: 2.0.0 (Pro)                  ${NC}"
    echo -e "${YELLOW}   Author: GabxSup  - https://github.com/GabxSup
    License: MIT  ${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo "Logs saved to: $LOG_FILE"
    echo ""
}

print_summary() {
    echo ""
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${YELLOW}            TASK SUMMARY                 ${NC}"
    echo -e "${BLUE}=========================================${NC}"
    
    for entry in "${SUMMARY_LOG[@]}"; do
        echo -e "$entry"
    done
    
    echo -e "${BLUE}=========================================${NC}"
    if [ ${#ERRORS_LOG[@]} -ne 0 ]; then
         echo -e "${RED}Found ${#ERRORS_LOG[@]} errors during execution. Check $LOG_FILE for details.${NC}"
    else
         echo -e "${GREEN}All tasks completed successfully!${NC}"
    fi
    echo ""
}

main() {
    check_root
    detect_distro
    calculate_total_steps
    
    print_banner
    
    # Ensure log file exists and is writable
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" || { echo "Cannot write to log file $LOG_FILE"; exit 1; }
    fi
    
    log "Starting maintenance session..."
    
    # Run Core Tasks
    case "$DISTRO" in
        ubuntu|debian|kali|linuxmint|pop)
            task_apt
            ;;
        fedora|rhel|centos|almalinux|rocky)
            # Correcting dnf task definition on the fly here
            run_task "Refreshing DNF metadata" "dnf check-update || true" # Allow exit code 100
            run_task "Upgrading system (DNF)" "dnf upgrade --refresh -y"
            run_task "System optimization (DNF)" "dnf distro-sync -y"
            run_task "Cleaning DNF cache" "dnf clean all"
            run_task "Removing unused packages" "dnf autoremove -y"
            ;;
        arch|manjaro|endeavouros)
            task_pacman
            ;;
        opensuse*|sles)
            task_zypper
            ;;
        *)
            echo -e "${RED}[ERROR] Distribution '$DISTRO' is not fully supported.${NC}"
            log "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
    
    # Run Extended Tasks
    run_extended_tasks
    
    # Finish
    print_summary
}

# Run
main "$@"
