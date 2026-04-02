# dotfiles

[中文](README.md)

A demo of syncing dotfiles across machines using **GitHub + GNU Stow**.

Setting up a new machine from scratch is tedious. This approach puts all config files under Git, and uses GNU Stow to deploy them as symlinks, enabling:

- **Single source of truth**: one copy of every config — `git push` syncs it everywhere, no drift between machines
- **Deploy what you need**: servers get server packages, local machines get local packages — no interference
- **Fast migration**: `git clone` + `stow` is all it takes to restore your full environment on a new machine
- **Full history**: every change is a commit, fully reversible
- **AI tool config sync**: Claude Code's user-level `CLAUDE.md` and OpenClaw skills are versioned alongside everything else — consistent AI assistance on every machine

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
├── claude/             # Claude Code config
│   └── .claude/
│       ├── CLAUDE.md
│       ├── settings.json
│       └── commands/
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
stow -t ~ bash zsh git ssh tmux proxy claude
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

stow uses a **minimum-link principle**: it links at the highest possible level rather than symlinking individual files. For nested paths, stow walks down the directory tree and creates a symlink at the first level that doesn't yet exist.

Take `claude/.claude/commands/openclaw.md` as an example:

| `~/.claude` | `~/.claude/commands` | stow behavior |
|:-----------:|:--------------------:|---------------|
| does not exist | — | symlinks the entire `.claude/` directory |
| exists | does not exist | symlinks the entire `commands/` directory |
| exists | exists | symlinks `openclaw.md` only |

**Implications for the `claude` package:**

- **Deploy `claude` only after Claude Code is installed.** Claude Code creates `~/.claude/` and writes runtime files (conversation history, etc.) into it. If you `stow claude` beforehand, `~/.claude/` doesn't exist yet and stow will link the entire directory into the repo — causing Claude Code's runtime files to land inside your repo.

- **`commands/` must not exist at deploy time.** When `commands/` is absent, stow links the whole directory, so any new command files added to the repo later are automatically available on all machines. If `commands/` already exists (e.g. created by Claude Code), stow can only link files individually — new additions won't sync automatically. Fix: remove `~/.claude/commands/` and re-run `stow claude`.

---

## Proxy (Optional)

`proxy/.bash_proxy` sets HTTP/SOCKS5 proxy environment variables (`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, etc.) on shell startup, pointing to `127.0.0.1:7890`.

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
sudo apt install stow
stow -t ~ bash git
```

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
```

### Pixi

```bash
# Linux
curl -fsSL https://pixi.sh/install.sh | sh

# macOS
brew install pixi
```
