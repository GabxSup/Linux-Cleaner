# Universal Linux System Cleaner & Updater

A simple, robust bash script to automate system updates and cleanup for various Linux distributions. Created to be shared with the community.

## Features

- **Auto-Detect Distro**: Automatically identifies your Linux distribution.
- **Multi-Package Manager Support**:
  - `apt` (Debian, Ubuntu, Kali, Mint, Pop!_OS)
  - `dnf` (Fedora, RHEL, CentOS)
  - `pacman` (Arch, Manjaro)
  - `zypper` (OpenSUSE)
- **Safe Cleaning**:
  - Removes unused dependencies (autoremove).
  - Clears package caches.
  - Vacuums systemd journal logs (> 3 days).
- **Logging**: Keeps a log of operations in `/var/log/system_cleaner.log`.

## Usage

1.  **Download** or clone this repository.
    ```bash
    git clone https://github.com/your-username/linux-cleaner.git
    cd linux-cleaner
    ```

2.  **Make executable**:
    ```bash
    chmod +x cleaner.sh
    ```

3.  **Run with sudo**:
    ```bash
    sudo ./cleaner.sh
    ```

## Disclaimer

This script performs system administration tasks. While intended to be safe, **always review scripts before running them with root privileges**. Use at your own risk.

## License

MIT License. See [LICENSE](LICENSE) for details.
