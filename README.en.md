# dotfiles

[中文](README.md)

A demo of syncing dotfiles across machines using **GitHub + GNU Stow**.

Setting up a new machine from scratch is tedious. This approach puts all config files under Git, and uses GNU Stow to deploy them as symlinks, enabling:

- **Single source of truth**: one copy of every config — `git push` syncs it everywhere, no drift between machines
- **Deploy what you need**: servers get server packages, local machines get local packages — no interference
- **Fast migration**: `git clone` + `stow` is all it takes to restore your full environment on a new machine
- **Full history**: every change is a commit, fully reversible
- **AI tool config sync**: Claude Code's user-level `CLAUDE.md`, custom skills / agents / rules, and `settings.json` (including the plugin enable list) are all versioned alongside everything else — consistent AI assistance on every machine

For a detailed walkthrough of the design, see the [blog post](https://fomalhaut647.com/posts/dotfiles).

## Concept

```
GitHub repo
    │
    ├─ git clone ──▶ Machine A (local Mac)
    ├─ git clone ──▶ Machine B (remote Ubuntu server)
    └─ git clone ──▶ Machine C (...)
```

- All machines share the same config, synced via `git pull / push`
- `stow` deploys files from the repo to `~` as symlinks
- Each machine only stows the packages it needs

### Why not sync `.bashrc`?

`.bashrc` contains machine-specific settings (paths, environment variables, etc.) that vary significantly across machines. Instead:

- **Synced**: `bash/.bash_aliases` — shared aliases and functions for all machines
- **Not synced**: `.bashrc` — managed per machine; the repo keeps a copy of the Ubuntu default `.bashrc` as a reference backup
- `.bashrc` only needs these lines to load aliases:
  ```bash
  if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
  fi
  ```
  Ubuntu's default `.bashrc` already includes this, so no extra steps needed.

---

## Repository Structure

Each directory is a standalone **stow package** that can be deployed independently:

```
dotfiles/
├── bash/               # Bash config
│   └── .bash_aliases   #   Shared aliases and functions (synced across machines)
├── zsh/                # Zsh config
│   ├── .zshrc
│   └── .zsh_aliases
├── git/                # Git config
│   ├── .gitconfig
│   └── .gitignore_global
├── ssh/                # SSH client config
│   └── .ssh/config
├── tmux/               # tmux config
│   └── .tmux.conf
├── proxy/              # Proxy environment variables
│   └── .bash_proxy
├── vscode/             # VS Code Remote-SSH server-side settings
│   └── .vscode-server/data/Machine/settings.json
├── claude/             # Claude Code config
│   └── .claude/
│       ├── CLAUDE.md       # user-level preferences & collaboration rules
│       ├── settings.json   # plugin enable list, statusline, permissions
│       ├── statusline.sh   # custom status bar script
│       ├── commands/       # custom commands (placeholder)
│       ├── skills/         # custom skills (e.g. pixi)
│       ├── agents/         # custom subagents (placeholder)
│       └── rules/          # custom rules (placeholder)
├── .gitignore          # Just `.claude/*` — prevents Claude Code's session state
│                       #   (projects/, todos/) from leaking into commits when the
│                       #   repo root is opened as a project
└── .bashrc             # Backup only — not deployed via stow
```

---

## Usage

### 1. Install stow

```bash
# Ubuntu / Debian
sudo apt install stow

# macOS
brew install stow
```

### 2. Clone the repo

```bash
git clone git@github.com:<your-username>/dotfiles ~/dotfiles
cd ~/dotfiles
```

### 3. Deploy packages

```bash
# Deploy selected packages, e.g.:
stow -t ~ bash git tmux

# Deploy all
stow -t ~ bash zsh git ssh tmux proxy vscode claude
```

`stow` creates symlinks in `~` pointing to the corresponding files in the repo.

### 4. Undeploy

```bash
stow -D -t ~ bash   # Remove symlinks for the bash package
```

---

## Daily Sync Workflow

```bash
# After editing config on any machine, commit and push
cd ~/dotfiles
git add -A
git commit -m "update: ..."
git push

# On another machine, pull the latest config
cd ~/dotfiles
git pull
# Symlinks already exist — changes take effect immediately, no need to re-stow
```

---

## Stow Notes

### Conflict Behavior

When deploying, stow creates a symlink if the target path **does not exist** or **is already a symlink to the same file**. If the target **exists and differs**, stow exits with an error — it never overwrites.

This approach avoids conflicts by design: only files that don't pre-exist on a fresh machine (e.g. `.bash_aliases`) are synced. Files that already exist per-machine (e.g. `.bashrc`) are intentionally excluded.

### Directory Folding

stow uses a **minimum-link principle**: it links at the highest possible level rather than symlinking individual files. For nested paths, stow walks down the target tree and creates a symlink at **the deepest level that doesn't yet exist** — that one symlink then takes over everything below it.

Take `claude/.claude/skills/pixi/SKILL.md` as an example:

| `~/.claude` | `~/.claude/skills` | stow behavior |
|:-----------:|:------------------:|---------------|
| does not exist | — | symlinks the entire `.claude/` directory |
| exists | does not exist | symlinks the entire `skills/` directory |
| exists | exists | only links `skills/pixi/` (and recurses by existence below) |

**Implications for the `claude` package:**

- **Deploy `claude` only after Claude Code is installed.** Claude Code creates `~/.claude/` and writes runtime files (conversation history, etc.) into it. If you `stow claude` beforehand, `~/.claude/` doesn't exist yet and stow will link the entire directory into the repo — causing Claude Code's runtime files to land inside your repo.

- **Subdirectories (`commands/`, `skills/`, `agents/`, `rules/`) must not exist at deploy time.** When a subdirectory is absent, stow links the whole directory, so any new files added to the repo later are automatically available on all machines. If the subdirectory already exists (e.g. created by Claude Code or a plugin), stow can only link files individually — new additions won't sync automatically. Fix: remove `~/.claude/<dir>/` and re-run `stow claude`. A conservative approach is **`stow claude` first, then install plugins**, so stow grabs the whole-directory link first.

---

## Claude Code Configuration

The `claude` package versions not just `CLAUDE.md` and `settings.json`, but also custom skills / agents / rules and the statusline script.

### Auto-enabled plugins

The `enabledPlugins` and `extraKnownMarketplaces` fields in `settings.json` are auto-reconciled by Claude Code at startup:

```jsonc
{
  "enabledPlugins": {
    "claude-md-management@claude-plugins-official": true,
    "superpowers@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "context7@claude-plugins-official": true
    // ...
  },
  "extraKnownMarketplaces": {
    "<your-marketplace>": {
      "source": { "source": "github", "repo": "<owner>/<repo>" }
    }
  }
}
```

This means **you don't need to manually run `/plugin install ...` or `/plugin marketplace add ...` on a new machine**: once `stow claude` is done, the next Claude Code launch will install every plugin listed in `settings.json`. To add/remove plugins, just edit `settings.json`.

### Host-side runtime dependencies

LSP plugins like `pyright-lsp` / `typescript-lsp` don't ship language-server binaries; install them on the host:

```bash
npm install -g pyright                                # for pyright-lsp
npm install -g typescript-language-server typescript  # for typescript-lsp
```

The `statusline.sh` script depends on `jq`:

```bash
sudo apt install jq    # Ubuntu / Debian
brew install jq        # macOS
```

### Files intentionally not stowed

`~/.claude.json` is Claude Code's CLI state file (oauth account, caches, projects, feature flags, onboarding flags) — it changes every few seconds during a session. The vast majority is state; only a small fragment (e.g. `mcpServers`) is user config. **Don't sync the whole file** — it causes constant git conflicts and account-identity pollution across machines.

---

## Proxy (Optional)

`proxy/.bash_proxy` sets HTTP/SOCKS5 proxy environment variables (`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, etc.) on shell startup, pointing to `127.0.0.1:7890`. It also keeps a `no_proxy` allowlist covering common mirror sources (cloud providers, education-network mirrors, AI model mirrors, toolchain registries) so mirror traffic skips the proxy.

To forward a local proxy to a remote server, enable `RemoteForward` in `ssh/.ssh/config` for the target host:

```sshconfig
Host my-server
  HostName <server IP>
  User <username>
  RemoteForward 7890 127.0.0.1:7890
```

Then deploy the proxy package on the server:

```bash
stow -t ~ proxy
```

---

## Appendix: Ubuntu Server Setup

### Basic Setup

If you've connected to this IP before, clear `known_hosts` after reinstalling the OS:

```zsh
ssh-keygen -R server_ip
```

Update apt:

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

Post-reboot cleanup:

```bash
sudo apt autoremove -y
sudo apt clean
```

Set timezone:

```bash
sudo timedatectl set-timezone Asia/Shanghai
```

### Install `code` / `cursor` CLI

1. Open the command palette with `Cmd/Ctrl + Shift + P`
2. Type `shell`
3. Select `Shell Command: Install 'code'/'cursor' command`

### Deploy dotfiles

```bash
git clone git@github.com:<your-username>/dotfiles
cd dotfiles
sudo apt install stow jq
stow -t ~ bash git
```

> `jq` is required by the `claude` package's `statusline.sh` script; skip it if you don't deploy `claude`.

#### Proxy (Optional)

If using a proxy, enable `RemoteForward` in your local `ssh/.ssh/config` (see the Proxy section above), then deploy the proxy package on the server:

```bash
stow -t ~ proxy
```

### VS Code Extensions

Open the VS Code sidebar and install the desired extensions.

### GitHub CLI

```bash
(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y
```

Verify and log in:

```bash
gh --version
gh auth login
```

### tmux

```bash
sudo apt install tmux
stow -t ~ tmux
```

### Claude Code

```bash
curl -fsSL https://claude.ai/install.sh | bash
stow -t ~ claude
# After launching Claude Code, every plugin in settings.json's enabledPlugins
# auto-installs. Then npm install -g pyright / typescript-language-server typescript
# as needed.
```

### Pixi

```bash
# Linux
curl -fsSL https://pixi.sh/install.sh | sh

# macOS
brew install pixi
```
