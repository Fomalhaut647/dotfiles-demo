# dotfiles

[English](README.en.md)

用 **GitHub + GNU Stow** 跨机器同步配置文件的方案 demo。

配置一台新机器往往要花费大量时间重新设置各种工具。该方案将所有配置文件统一纳入 Git 管理，利用 GNU Stow 以符号链接的方式部署到系统，实现：

- **零冗余**：配置文件只有一份，修改后 `git push` 即可同步到所有机器，不存在多份拷贝不一致的问题
- **按需部署**：服务器只装服务器需要的包，本地机器只装本地需要的包，互不干扰
- **易于迁移**：新机器 `git clone` + `stow` 两条命令即可还原全部配置
- **历史可追溯**：每次改动都有 commit 记录，可以随时回滚
- **AI 工具配置同步**：Claude Code 的用户级 `CLAUDE.md`、OpenClaw skills 等配置也纳入仓库统一管理，在任意机器上都能获得一致的 AI 辅助体验

关于该方案的详细介绍和设计思路，参见[博客文章](https://fomalhaut647.com/posts/dotfiles)。

## 思路

```
GitHub repo
    │
    ├─ git clone ──▶ 机器 A（本地 Mac）
    ├─ git clone ──▶ 机器 B（远程 Ubuntu 服务器）
    └─ git clone ──▶ 机器 C（...）
```

- 所有机器共享同一份配置，通过 `git pull / push` 同步变更
- 用 `stow` 把仓库里的配置文件以符号链接的形式部署到 `~`
- 每台机器只 `stow` 自己需要的包，不需要的跳过即可

### 为什么不同步 `.bashrc`？

`.bashrc` 包含大量机器相关的设置（路径、环境变量等），各机器差异大，强行统一反而麻烦。因此：

- **同步**：`bash/.bash_aliases`——通用 alias 和函数，所有机器共享
- **不同步**：`.bashrc`——机器自带，各自管理；仓库里保留一份 Ubuntu 默认 `.bashrc` 作参考备份
- `.bashrc` 里只需保留三行来加载 aliases：
  ```bash
  if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
  fi
  ```
  Ubuntu 默认 `.bashrc` 已经包含这一行，无需额外处理。

---

## 仓库结构

每个目录是一个独立的 **stow 包**，可以按需单独部署：

```
dotfiles/
├── bash/               # Bash 配置
│   └── .bash_aliases   #   通用 alias 和函数（跨机器同步）
├── zsh/                # Zsh 配置
│   ├── .zshrc
│   └── .zsh_aliases
├── git/                # Git 配置
│   ├── .gitconfig
│   └── .gitignore_global
├── ssh/                # SSH 客户端配置
│   └── .ssh/config
├── tmux/               # tmux 配置
│   └── .tmux.conf
├── proxy/              # 代理开关脚本
│   └── .bash_proxy
├── claude/             # Claude Code 配置
│   └── .claude/
│       ├── CLAUDE.md
│       ├── settings.json
│       └── commands/
└── .bashrc             # 仅备份，不通过 stow 部署
```

---

## 使用方法

### 1. 安装 stow

```bash
# Ubuntu / Debian
sudo apt install stow

# macOS
brew install stow
```

### 2. 克隆仓库

```bash
git clone git@github.com:<your-username>/dotfiles ~/dotfiles
cd ~/dotfiles
```

### 3. 部署配置

```bash
# 按需选择要部署的包，例如：
stow -t ~ bash git tmux

# 部署全部
stow -t ~ bash zsh git ssh tmux proxy claude
```

`stow` 会在 `~` 下创建符号链接，指向仓库中对应的文件。

### 4. 取消部署

```bash
stow -D -t ~ bash   # 删除 bash 包的符号链接
```

---

## 日常同步工作流

```bash
# 在任意机器上修改配置后，提交并推送
cd ~/dotfiles
git add -A
git commit -m "update: ..."
git push

# 在另一台机器上拉取最新配置
cd ~/dotfiles
git pull
# 符号链接已存在，配置立即生效，无需重新 stow
```

---

## Stow 注意事项

### 冲突规则

stow 部署时，若目标路径**不存在**或**已是指向同一文件的符号链接**，则正常创建链接；若目标路径**已存在且内容不同**，则报错退出（不会覆盖）。

该方案不会触发冲突，原因在于：仓库中只同步那些在新机器上本来就不存在的文件（如 `.bash_aliases`）；而各机器上本已存在的文件（如 `.bashrc`）则不纳入同步，从根本上避免了冲突。

### 目录折叠原则

stow 采用**最少链接原则**：它会尽量在最高层级创建链接，而不是逐个链接每个文件。对于带有多层目录的文件，stow 会自顺序检查各层目录是否存在，在第一个不存在的层级创建链接。

以 `claude/.claude/commands/openclaw.md` 为例：

| `~/.claude` | `~/.claude/commands` | stow 的行为 |
|:-----------:|:--------------------:|------------|
| 不存在 | — | 链接整个 `.claude/` 目录 |
| 已存在 | 不存在 | 链接整个 `commands/` 目录 |
| 已存在 | 已存在 | 仅链接 `openclaw.md` 文件 |

**对 `claude` 包的影响**：

- **应在安装 Claude Code 之后再部署 `claude` 包。** Claude Code 安装时会创建 `~/.claude/` 并写入自己的运行时文件（对话记录等）。若提前 `stow claude`，`~/.claude/` 还不存在，stow 会将整个目录链接到仓库，导致 Claude Code 的运行时文件也被写入仓库。

- **`commands/` 目录需在部署前不存在。** stow 会将整个 `commands/` 目录链接到仓库，后续在仓库中新增的 command 文件会自动在所有机器上生效。若 `commands/` 已存在（例如 Claude Code 自行创建），stow 只能逐个链接已有文件，新增文件不会自动同步——此时需先删除 `~/.claude/commands/`，再重新 `stow claude`。

---

## 代理（可选）

`proxy/.bash_proxy` 在 shell 启动时自动设置 HTTP/SOCKS5 代理环境变量（`HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY` 等），指向本地 `127.0.0.1:7890`。

如果需要把本地代理转发到远程服务器，在 `ssh/.ssh/config` 对应 Host 下开启 `RemoteForward`：

```sshconfig
Host my-server
  HostName <服务器 IP>
  User <用户名>
  RemoteForward 7890 127.0.0.1:7890
```

然后在服务器上部署 proxy 包：

```bash
stow -t ~ proxy
```

---

## 附：Ubuntu 服务器初始化流程

### 基础设置

如果之前连接过这个 IP，服务器重装系统后需要先清除 `known_hosts`：

```zsh
ssh-keygen -R server_ip
```

更新 apt：

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

重启后检查：

```bash
sudo apt autoremove -y
sudo apt clean
```

设置时区：

```bash
sudo timedatectl set-timezone Asia/Shanghai
```

### 安装 `code` / `cursor` 命令

1. `Cmd/Ctrl + Shift + P` 打开命令面板
2. 键入 `shell`
3. 选择 `Shell Command: Install 'code'/'cursor' command`

### 部署 dotfiles

```bash
git clone git@github.com:<your-username>/dotfiles
cd dotfiles
sudo apt install stow
stow -t ~ bash git
```

#### 代理（可选）

若走代理，本地 `ssh/.ssh/config` 对应 Host 需开启转发（见上方代理章节），然后在服务器上部署 proxy 包：

```bash
stow -t ~ proxy
```

### VS Code 扩展

打开 VS Code 侧栏，安装所需扩展。

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

验证版本并登录：

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
