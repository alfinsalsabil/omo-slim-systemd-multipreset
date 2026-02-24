# omo-slim-systemd-multipreset

![License](https://img.shields.io/github/license/alfinsalsabil/omo-slim-systemd-multipreset)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20systemd-blue)
![OpenCode](https://img.shields.io/badge/OpenCode-compatible-success)

Hey there! 👋 I'm just a "vibecoding" enthusiast who loves using OpenCode. I wanted to run multiple `oh-my-opencode-slim` presets (like `low`, `mid`, and `maks`) at the same time on my server, but I kept running into annoying errors.

After a lot of trial, error, and some AI-assisted debugging, I finally found a setup that works perfectly. I'm sharing this repository in hopes that it helps fellow vibecoders out there!

## 🐛 The Headaches (The Problem)
If you try running multiple instances in the background, you'll probably hit these roadblocks:
1. **`Database is locked`**: SQLite panics because 3 presets are fighting over the exact same `opencode.db` file.
2. **`ProviderAuthError`**: You lose your login sessions because isolating the folders usually breaks the auth tokens.
3. **AI Typing Lag**: If you use Cloudflare Tunnels, the AI responses sometimes buffer and arrive all at once instead of streaming smoothly like they should.

## 💡 The "Aha!" Moment: Shared Config, Isolated Data
The trick to fixing all of this is a hybrid setup:
* **Isolated Data (`XDG_DATA_HOME`)**: We give each preset its own folder for chat history and databases. No more locked databases!
* **Shared Config (`XDG_CONFIG_HOME`)**: We let them share the main config and token pool (`antigravity-accounts.json`). This way, they automatically know about each other's rate-limits.

*(Note: I tested this heavily with the `opencode-ag-auth` and `opencode-antigravity-auth` plugins).*

---

## 🛠️ How to Use It

### The Easy Way: Auto Installer
I put together a bash script that handles the boring stuff (creating directories, fixing permissions, and making systemd files safely).

1. Clone this repo:
   ```bash
   git clone https://github.com/alfinsalsabil/omo-slim-systemd-multipreset.git
   cd omo-slim-systemd-multipreset
   ```
2. Run the installer (it asks for `sudo` to create the systemd services safely):
   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```
3. Just answer the prompts (WebUI password, API key vs OAuth).

### The Manual Way
If you prefer doing things by hand, check the `templates/` folder and copy the logic into your `/etc/systemd/system/` and `/etc/opencode/`.

---

## 🌐 Fixing the Cloudflare Lag (Crucial!)
If you use Cloudflare Tunnels (`cloudflared`), Server-Sent Events (SSE) get buffered by default.
You **must** add this to your `~/.cloudflared/config.yml` under **each** OpenCode hostname. (Check `cloudflare/config-snippet.yml` for an example).

```yaml
    originRequest:
      disableChunkedEncoding: true
      http2Origin: false
```

---

## 🔧 Cheat Sheet for Later

Since we split the config and data, here is how you manage things later on:

1. **Updating Plugins:**
   Just run `opencode plugin update <name>` normally, then restart the services: `sudo systemctl restart "opencode@*"`.
2. **Logging into a New Provider (OAuth/Token):**
   Run `opencode auth login` normally in your terminal. Then, copy the new session file to your background workers:
   ```bash
   cp ~/.local/share/opencode/auth.json ~/.local/share/opencode-low/opencode/auth.json
   cp ~/.local/share/opencode/auth.json ~/.local/share/opencode-mid/opencode/auth.json
   cp ~/.local/share/opencode/auth.json ~/.local/share/opencode-maks/opencode/auth.json
   sudo systemctl restart "opencode@*"
   ```
   *(Wondering why we copy instead of just using symlinks? It turns out OpenCode uses atomic renaming when refreshing tokens, which silently deletes symlinks! Learned that the hard way).*

## 🤝 Let's Make It Better
I'm not a DevOps guru, just enjoying the vibecoding life. If you see something that can be improved, feel free to open an Issue or a Pull Request. Let's build a cool setup together!
