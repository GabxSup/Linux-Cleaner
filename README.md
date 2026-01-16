# Universal Linux System Cleaner & Updater

![Version](https://img.shields.io/badge/version-2.0.0-blue.svg) ![License](https://img.shields.io/badge/license-MIT-green.svg)

An advanced, automated bash script to keep your Linux system fresh, updated, and clean. Now featuring a **visual progress bar**, **detailed task summaries**, and extended support for modern container and package systems.

## 🚀 New Features (v2.0)

- **Interactive UI**: A sleek progress bar `[####....] 40%` keeps you informed of the current operation.
- **Task Summary**: Get a clear report at the end showing exactly which tasks succeeded ✔ and which failed ✘.
- **Extended Cleaning**:
  - **Docker**: Prunes unused containers, networks, and images (`docker system prune`).
  - **Snap & Flatpak**: Updates and cleans these package managers if detected.
  - **Systemd Journal**: Vacuums old logs to save disk space.
- **Smart Detection**: Automatically detects your distro and installed tools (Docker, Snap, etc.) to tailor the cleaning process.

## 📦 Supported Systems

The script automatically detects and adapts to the following package managers:

- **Debian / Ubuntu / Kali / Mint / Pop!_OS** (`apt`)
- **Fedora / RHEL / CentOS / AlmaLinux / Rocky** (`dnf`)
- **Arch Linux / Manjaro / EndeavourOS** (`pacman`)
- **OpenSUSE / SLES** (`zypper`)

## 🛠 Usage

1.  **Download** or clone this repository:
    ```bash
    git clone https://github.com/GabxSup/Linux-Cleaner.git
    cd Linux-Cleaner
    ```

2.  **Make executable**:
    ```bash
    chmod +x cleaner.sh
    ```

3.  **Run with sudo**:
    ```bash
    sudo ./cleaner.sh
    ```

## 📝 Logging

All technical details and command outputs are logged to:
`/var/log/system_cleaner.log`

This keeps your terminal clean while preserving all data for troubleshooting.

## ⚠️ Disclaimer

This script performs system administration tasks (updates, upgrades, cache cleaning). While tested and intended to be safe, **always review scripts before running them with root privileges**. Use at your own risk.

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.
