#!/bin/bash

# ==============================================================================
# Script Name: Universal Linux Cleaner & Updater
# Description: Automated script to update and clean various Linux distributions.
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
NC='\033[0m' # No Color

# --- Helper Functions ---

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$DATE] [INFO] $1" >> "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$DATE] [SUCCESS] $1" >> "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$DATE] [WARNING] $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$DATE] [ERROR] $1" >> "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
       error "This script must be run as root."
       exit 1
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        error "Cannot detect Linux distribution."
        exit 1
    fi
    log "Detected distribution: $DISTRO"
}

# --- Package Manager Specific Functions ---

update_apt() {
    log "Updating APT repositories..."
    apt-get update -y
    
    log "Upgrading packages..."
    apt-get upgrade -y
    
    log "Performing distribution upgrade..."
    apt-get dist-upgrade -y
}

clean_apt() {
    log "Cleaning APT cache..."
    apt-get autoclean -y
    
    log "Removing unused dependencies..."
    apt-get autoremove -y
}

update_dnf() {
    log "Updating system with DNF..."
    dnf upgrade --refresh -y
}

clean_dnf() {
    log "Cleaning DNF cache..."
    dnf clean all
    
    log "Removing unused packages..."
    dnf autoremove -y
}

update_pacman() {
    log "Updating system with Pacman..."
    pacman -Syu --noconfirm
}

clean_pacman() {
    log "Cleaning Pacman cache..."
    # Keep installed packages, remove uninstalled
    pacman -Sc --noconfirm
    
    # Optional: Remove orphans
    if pacman -Qdtq > /dev/null 2>&1; then
        log "Removing orphan packages..."
        pacman -Rns $(pacman -Qdtq) --noconfirm
    else
        log "No orphans found."
    fi
}

update_zypper() {
    log "Updating system with Zypper..."
    zypper refresh
    zypper update -y
}

clean_zypper() {
    log "Cleaning Zypper cache..."
    zypper clean --all
}

# --- Main Logic ---

print_banner() {
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
    echo -e "${BLUE}   Universal Linux Cleaner & Updater     ${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

main() {
    print_banner

    check_root
    detect_distro

    # Ensure log file exists and is writable
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE" || { echo "Cannot write to log file $LOG_FILE"; exit 1; }
    fi

    echo ""
    log "Starting maintenance task..."
    
    case "$DISTRO" in
        ubuntu|debian|kali|linuxmint|pop)
            update_apt
            clean_apt
            ;;
        fedora|rhel|centos|almalinux|rocky)
            update_dnf
            clean_dnf
            ;;
        arch|manjaro|endeavouros)
            update_pacman
            clean_pacman
            ;;
        opensuse*|sles)
            update_zypper
            clean_zypper
            ;;
        *)
            error "Distribution '$DISTRO' is not fully supported by this script yet."
            exit 1
            ;;
    esac

    # Generic Cleanup (Safe)
    log "Performing generic cleanup..."
    
    # Clear journal logs older than 3 days
    if command -v journalctl >/dev/null 2>&1; then
        log "Vacuuming journal logs..."
        journalctl --vacuum-time=3d
    fi
    
    # Clear thumbnail cache for users (optional, usually in /home/user/.cache/thumbnails)
    # This is tricky as root, might skip to avoid permission issues in users home

    echo ""
    success "System maintenance complete!"
    echo -e "${BLUE}=========================================${NC}"
}

# Run execution
main "$@"
