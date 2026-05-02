# 🐍 Sudosoc-Env Pro

> **The Python virtual environment manager built for security engineers — not just developers.**

![Version](https://img.shields.io/badge/version-3.0.0-blueviolet?style=flat-square)
![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh-informational?style=flat-square)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-lightgrey?style=flat-square)
![Maintained](https://img.shields.io/badge/maintained-yes-brightgreen?style=flat-square)

Sudosoc-Env Pro replaces the bare `python -m venv` workflow with a full shell-injection system that drops a suite of productivity commands directly into every environment you create. One command in, one command out — everything else is automated.

Designed for **Offensive Security**, **Defensive Operations**, and **Digital Forensics** engineers who live in the terminal and can't afford the overhead of a broken or untracked Python environment.

---

## ✨ Key Features

- 🏠 **Centralized Storage (`SUDOSOC_HOME`)** — All environments live in `~/.sudosoc_envs` by default. Access any environment from any directory, no more hunting through project folders.
- ⇥ **Tab Completion** — Full argument and environment-name completion for both Bash and Zsh, installed automatically.
- 🪝 **Lifecycle Hooks** — Drop executable scripts into `<env>/.sudosoc/` and they run automatically on `on_create`, `on_activate`, and `on_exit`. Auto-start a VPN, export secrets, run a healthcheck — anything.
- 🐳 **`sudosoc-docker`** — One command generates a production-ready `Dockerfile` from the active environment, using the exact Python version, correct requirements file, and detected entry point.
- 🔒 **`sudosoc-lock`** — Writes a `requirements.lock` with exact `==` pinned versions alongside your `requirements.txt`, ensuring reproducible builds across machines.
- 🩺 **`sudosoc-doctor`** — Health check that validates Python, pip, the activate script, requirements sync state, disk usage, and outdated package count in a single scan.
- 📋 **History Logging** — Every `create`, `activate`, and `delete` is timestamped and logged to `~/.sudosoc_history`.
- ⚡ **Lazy pip Upgrade** — pip is only upgraded if it hasn't been touched in 7 days, keeping environment creation fast.
- 🔍 **`sudosoc-search`** — Query PyPI's API directly from the shell without opening a browser.
- 🎨 **Prompt Themes** — Switch the terminal prompt style with `--theme classic | minimal | neon | pastel`.
- 🐍 **pyenv Integration** — If the requested Python version isn't in `PATH`, the installer falls back to a pyenv lookup automatically.

---

## 📦 Installation

```bash
git clone https://github.com/sudosoc/sudosoc-env.git
cd sudosoc-env
sudo chmod +x install.sh
sudo bash install.sh
source ~/.zshrc   # or source ~/.bashrc
```

The installer handles everything automatically:

- Installs the binary to `/usr/local/bin/sudosoc-env` (available system-wide)
- Creates `~/.sudosoc_envs` with correct ownership for your user
- Copies completion files to `~/.sudosoc/`
- Detects your login shell from `/etc/passwd` and appends `SUDOSOC_HOME` and the `source` line to the correct rc file (`.zshrc` or `.bashrc`), with duplicate-entry protection

> **Note:** The installer uses `$SUDO_USER` to target your real user account — it never writes files into root's home directory.

---

## 🚀 Usage

### Creating & Entering an Environment

```bash
# Create a new environment (uses current directory by default)
sudosoc-env recon-tools

# Create in SUDOSOC_HOME (~/.sudosoc_envs/) for global access
sudosoc-env --home malware-lab

# Create with a specific Python version
sudosoc-env --python python3.11 forensics-env

# Create and immediately install requirements.txt
sudosoc-env -r exploit-dev

# Apply a custom prompt theme
sudosoc-env --theme neon red-team
```

### Activating an Existing Environment

```bash
# Activate by name (searches current dir, then SUDOSOC_HOME)
sudosoc-env -a recon-tools

# Activate a global environment
sudosoc-env --home -a malware-lab
```

### Listing Environments

```bash
# List environments in the current directory
sudosoc-env --list

# List all global environments in SUDOSOC_HOME
sudosoc-env --global-list
```

Output example:

```
🌐 Global Environments in '/home/sudosoc/.sudosoc_envs':
  🟢 malware-lab     Py 3.11.4  |  12 pkgs  |  created: 2026-05-01 14:22
  🟢 recon-tools     Py 3.10.12 |   8 pkgs  |  created: 2026-04-28 09:15
  🟢 forensics-env   Py 3.12.0  |  31 pkgs  |  created: 2026-03-17 18:04
```

### Deleting an Environment

```bash
# With confirmation prompt
sudosoc-env -d old-env

# Skip the confirmation (for scripting/CI)
sudosoc-env -d old-env --force
```

---

## 🔧 Internal Commands

These commands are injected into your shell the moment you enter an environment. They are only available while the environment is active.

| Command | Description |
|---|---|
| `sudosoc-exit` | Runs the `on_exit` hook, deactivates the environment, and exits the subshell cleanly |
| `sudosoc-save` | Freezes all locally installed packages to `requirements.txt` |
| `sudosoc-lock` | Generates `requirements.lock` with exact `==` pinned versions |
| `sudosoc-add <pkg>` | Installs one or more packages and immediately updates `requirements.txt` |
| `sudosoc-reset` | Uninstalls all local packages, returning the environment to a clean state |
| `sudosoc-update` | Upgrades all outdated local packages in a single operation |
| `sudosoc-clone <name>` | Clones the current environment (with all packages) into a new one in `SUDOSOC_HOME` |
| `sudosoc-run` | Auto-detects and runs `main.py`, `app.py`, or `manage.py` |
| `sudosoc-info` | Displays Python version, package count, disk size, path, and creation date |
| `sudosoc-check` | Lists all outdated packages without upgrading them |
| `sudosoc-doctor` | Full environment health check — Python, pip, requirements sync, disk, outdated packages |
| `sudosoc-search <pkg>` | Searches PyPI and returns version, summary, author, license, and recent releases |
| `sudosoc-note [text]` | Adds a timestamped note to the environment, or displays existing notes |
| `sudosoc-docker` | Generates a production-ready `Dockerfile` based on the current environment |
| `sudosoc-bench` | Runs a Python micro-benchmark and reports results with a visual bar graph |

---

## 🪝 Advanced: Using Hooks

Hooks are executable shell scripts placed inside the `<env>/.sudosoc/` directory. They are called automatically at specific points in the environment's lifecycle.

| Hook file | Triggered when |
|---|---|
| `on_create.sh` | Immediately after the environment is first created |
| `on_activate.sh` | Every time the environment is entered |
| `on_exit.sh` | Every time `sudosoc-exit` is called |

### Example: Offensive Security Environment

A common use case for red teamers — automatically connect to an engagement VPN and load API keys when entering a dedicated environment:

```bash
# File: ~/.sudosoc_envs/red-team-op/.sudosoc/on_activate.sh
#!/bin/bash

# Load engagement secrets from an encrypted vault
export SHODAN_API_KEY="$(pass show engagements/shodan)"
export VT_API_KEY="$(pass show engagements/virustotal)"

# Connect to engagement VPN if not already up
if ! ip link show tun0 &>/dev/null; then
    echo "[*] Bringing up engagement VPN..."
    sudo openvpn --config ~/vpn/engagement.ovpn --daemon
fi

echo "[+] Red team environment ready."
```

```bash
# File: ~/.sudosoc_envs/red-team-op/.sudosoc/on_exit.sh
#!/bin/bash

# Unset secrets on exit so they don't persist in shell history
unset SHODAN_API_KEY
unset VT_API_KEY

echo "[*] Secrets cleared. Environment closed."
```

Make the hooks executable before use:

```bash
chmod +x ~/.sudosoc_envs/red-team-op/.sudosoc/on_activate.sh
chmod +x ~/.sudosoc_envs/red-team-op/.sudosoc/on_exit.sh
```

### Example: Digital Forensics Case Environment

```bash
# File: ~/.sudosoc_envs/case-2026-042/.sudosoc/on_activate.sh
#!/bin/bash

export CASE_ID="2026-042"
export EVIDENCE_PATH="/mnt/evidence/${CASE_ID}"
export CHAIN_OF_CUSTODY_LOG="${EVIDENCE_PATH}/chain_of_custody.log"

echo "[*] Case ${CASE_ID} environment active."
echo "[*] Evidence path: ${EVIDENCE_PATH}"
echo "$(date '+%Y-%m-%d %H:%M:%S') — Environment accessed by ${USER}" >> "$CHAIN_OF_CUSTODY_LOG"
```

---

## ⚙️ CLI Reference

```
sudosoc-env [OPTIONS] <ENV_NAME>

Options:
  -a, --activate  <name>    Activate an existing environment
  -r, --requirements        Install requirements.txt on entry
  -p, --python    <ver>     Python interpreter (e.g., python3.11)
  -l, --list                List environments in current directory
      --global-list         List all environments in SUDOSOC_HOME
  -d, --delete    <name>    Delete an environment (with confirmation)
      --force               Skip delete confirmation
      --home                Create/find environment in SUDOSOC_HOME
      --local               Force current directory
      --no-system-pkgs      Isolate from system site-packages
      --version-pin         Also write requirements.lock on save
      --theme   <name>      PS1 theme: classic | minimal | neon | pastel
  -v, --version             Show version number
  -h, --help                Show help menu

Environment variable:
  SUDOSOC_HOME              Override the global env directory (default: ~/.sudosoc_envs)
```

---

## 🗑️ Uninstallation

```bash
sudo bash install.sh --uninstall
```

This removes:
- The binary at `/usr/local/bin/sudosoc-env`
- The completion files in `~/.sudosoc/`
- The `SUDOSOC_HOME` export and `source` lines from `.bashrc` / `.zshrc` (a `.sudosoc.bak` backup is created automatically)

> **Your environments in `~/.sudosoc_envs` are never deleted.** They are your data. Remove them manually if needed:
> ```bash
> rm -rf ~/.sudosoc_envs
> ```

---

## 📁 Repository Structure

```
sudosoc-env/
├── sudosoc-env.sh                  # Main script
├── sudosoc-env-completion.bash     # Bash tab completion
├── sudosoc-env-completion.zsh      # Zsh tab completion
├── install.sh                      # Installer / uninstaller
└── README.md
```

---

## 🛡️ Designed For

| Track | Example Use Case |
|---|---|
| **Offensive Security** | Isolated per-engagement environments with automatic secret loading via hooks |
| **Defensive / SOC** | Reproducible analysis environments with locked dependencies for consistent tooling |
| **Digital Forensics** | Immutable case environments with chain-of-custody logging via `on_activate.sh` |
| **Malware Analysis** | Sandboxed environments with no system packages (`--no-system-pkgs`) and Docker export |

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">
  <sub>Built with 🖤 by <a href="https://github.com/sudosoc">SUDOSOC</a></sub>
</div>
