# Universal Linux System Cleaner & Updater

![Version](https://img.shields.io/badge/version-2.1.0-blue.svg) ![License](https://img.shields.io/badge/license-MIT-green.svg)

An advanced, automated bash script to keep your Linux system fresh, updated, clean, and secure. Features an interactive **progress bar**, **detailed task summaries**, extended package/container pruning, and a dedicated **Security Clean & Privacy Sweep** module.

## What's New in v2.3 (Pro)

- **Security Clean & Privacy Sweep**:
  - **Memory & Crash Dump Sanitization**: Vacuums coredumps (`coredumpctl`) and removes `/var/crash/*` to prevent plaintext secrets or memory artifacts from lingering.
  - **Stale Auth Sockets**: Cleans abandoned SSH and GPG agent sockets in `/tmp` and `/var/tmp` from severed sessions.
  - **Privacy Sweep**: Clears sensitive CLI history and artifact files (`.lesshst`, `.wget-hsts`, `.viminfo`, `.mysql_history`, and root shell history).
  - **Permission & Security Audit**: Detects unowned system files and strips world-writable permissions from critical configuration files in `/etc`.
  - **Security Patch Advisories**: Automatically scans and logs pending distribution-specific security advisories (APT, DNF, Zypper, Arch).
  - **Credential Flush**: Automatically flushes cached `sudo` timestamp tokens on completion.
- **Execution Modes**: Run full maintenance or target specific jobs (`--all`, `--security`, `--clean-only`, `--update-only`).
- ⚡ **Accurate Progress Engine**: Dynamic step calculation and polished terminal presentation.

## Core Features

- **Interactive UI**: Real-time progress bar `[####....] 60%` keeps you informed during execution.
- **Task Summary**: Clear post-run checklist showing which tasks succeeded ✔ and which failed ✘.
- **Extended Cleaning**:
  - **Docker**: Prunes unused containers, dangling volumes, and builder cache.
  - **Snap & Flatpak**: Updates packages and removes unused Flatpak runtimes.
  - **Developer Caches**: Cleans NPM and PIP cache directories.
  - **Systemd Journals**: Vacuums old system journals to reclaim disk space.
- **Smart Detection**: Detects your distribution and installed tools automatically.

## Supported Systems

The script automatically detects and adapts to:

- **Debian / Ubuntu / Kali / Linux Mint / Pop!_OS** (`apt`)
- **Fedora / RHEL / CentOS / AlmaLinux / Rocky** (`dnf`)
- **Arch Linux / Manjaro / EndeavourOS** (`pacman`)
- **OpenSUSE / SLES** (`zypper`)

## Usage

1. **Clone the repository**:
   ```bash
   git clone https://github.com/GabxSup/Linux-Cleaner.git
   cd Linux-Cleaner
   ```

2. **Make executable**:
   ```bash
   chmod +x cleaner.sh
   ```

3. **Run with sudo**:
   ```bash
   # Full maintenance (Updates + System Clean + Deep Clean + Security Clean)
   sudo ./cleaner.sh

   # Security & Privacy clean only
   sudo ./cleaner.sh --security

   # Disk clean only (skip updates)
   sudo ./cleaner.sh --clean-only

   # System updates only (skip cleaner)
   sudo ./cleaner.sh --update-only
   ```

### Command-Line Options

| Flag | Description |
| :--- | :--- |
| `--all` | Runs full suite: Updates, System Clean, Deep Clean, and Security Clean (Default) |
| `--security` | Runs Security Clean & Privacy audit only |
| `--clean-only` | Runs system cache and junk cleaning without running updates |
| `--update-only` | Runs package updates without system cleaning |
| `-v, --version` | Displays version information |
| `-h, --help` | Displays help message and examples |

## Logging

All technical details and command outputs are logged to:
```
/var/log/system_cleaner.log
```
This keeps your terminal clean while preserving complete logs for audits and troubleshooting.

## Disclaimer

This script performs system administration and cleanup tasks with root privileges. While engineered with safe defaults, **always review scripts before running them on production environments**.

## License

MIT License. See [LICENSE](LICENSE) for details.
