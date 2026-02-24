# omo-slim-systemd-multipreset

![License](https://img.shields.io/github/license/alfinsalsabil/omo-slim-systemd-multipreset)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20systemd-blue)
![OpenCode](https://img.shields.io/badge/OpenCode-compatible-success)


High Availability architecture for running multiple `oh-my-opencode-slim` presets concurrently on a single server using systemd.

## 🚀 The Problem
Running multiple OpenCode presets (e.g., `low`, `mid`, `maks`) simultaneously as background services often leads to:
1. **`Database is locked`**: SQLite crashes because multiple instances write to the same `opencode.db`.
2. **`ProviderAuthError`**: Tokens are lost because isolation methods often break the auth paths.
3. **AI Typing Lag (SSE Buffering)**: AI responses appear broken or delayed when routed through Cloudflare Tunnels.

## 💡 The Solution: Shared Config, Isolated Data
This architecture uses an elegant hybrid approach:
* **Isolated Data (`XDG_DATA_HOME`)**: Each preset (`opencode-low`, `opencode-mid`, `opencode-maks`) gets its own isolated directory for chat history and SQLite databases, preventing locks.
* **Shared Config (`XDG_CONFIG_HOME`)**: Configurations and token pools (`antigravity-accounts.json`) remain in a shared directory, allowing instances to communicate rate-limits to each other without conflict.

*(Note: This architecture is fully tested with the `opencode-antigravity-auth` plugin and its fork `opencode-ag-auth`)*.

---

## 🛠️ Installation

### Method 1: Automated Script (Recommended)
We provide an interactive script that automatically handles directory isolation, file ownership, and systemd service generation without causing `EACCES` crashes.

1. Clone this repository:
   ```bash
   git clone https://github.com/alfinsalsabil/omo-slim-systemd-multipreset.git
   cd omo-slim-systemd-multipreset
   ```
2. Run the installer with `sudo` (It will safely detect your real user directory):
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```
3. Follow the on-screen prompts to configure your WebUI password and Authentication method (API Key vs OAuth Plugin).

### Method 2: Manual Installation
Refer to the `templates/` folder and manually copy the files into `/etc/systemd/system/` and `/etc/opencode/`.

---

## 🌐 Cloudflare Tunnel Fix (Crucial for AI Streaming)
By default, Cloudflare Tunnels buffer Server-Sent Events (SSE), making the AI appear to type erratically or stall.

You **must** add the following configuration to your `~/.cloudflared/config.yml` under **each** of your OpenCode ingress rules. See `cloudflare/config-snippet.yml` for an example.

```yaml
    originRequest:
      disableChunkedEncoding: true
      http2Origin: false
```
*Do not put this in the global config block; it must be under the specific `hostname` ingress.*

---

## 🔧 Maintenance Guide (Cheat Sheet)

Because of the "Shared Config, Isolated Data" architecture, follow these rules:

1. **Update a Plugin:**
   * Run `opencode plugin update <name>` normally in your terminal.
   * Run `sudo systemctl restart "opencode@*"` to load the new code into memory.
2. **Login to a New Provider (OAuth / Token):**
   * Run `opencode auth login` normally in your terminal.
   * Re-run the copy command to sync your session to the background workers:
     ```bash
     cp ~/.local/share/opencode/auth.json ~/.local/share/opencode-low/opencode/auth.json
     cp ~/.local/share/opencode/auth.json ~/.local/share/opencode-mid/opencode/auth.json
     cp ~/.local/share/opencode/auth.json ~/.local/share/opencode-maks/opencode/auth.json
     sudo systemctl restart "opencode@*"
     ```
   *(Why not symlink? Because `opencode` uses atomic rename (`fs.rename`) during token refreshes, which silently destroys symlinks and breaks your system!)*.

## 🤝 Contributing
Issues and Pull Requests are welcome. This architecture aims to provide the most bulletproof foundation for running OpenCode in production.