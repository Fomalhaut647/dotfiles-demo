# Dotfiles

GNU Stow 管理的跨机器配置文件同步 demo —— 一份 Git 仓库统一管理多台机器的 dotfiles。本文档面向需要在该仓库内执行任务的 agent / 协作者；面向人类读者的快速上手见 `README.md`。

## 仓库结构

每个顶层目录是一个 stow package，`stow -t ~ <package>` 会将其内容符号链接到 `$HOME`：

| Package | 部署目标 | 说明 |
|---------|---------|------|
| `bash` | `~/.bash_aliases` | Bash 别名与工具函数（`ex()` 解压、代理加载、pixi 集成） |
| `zsh` | `~/.zshrc`, `~/.zsh_aliases` | Zsh 配置与别名 |
| `git` | `~/.gitconfig`, `~/.gitignore_global` | Git 用户/别名/全局忽略 |
| `ssh` | `~/.ssh/config` | SSH 主机配置（demo 仓库内仅保留占位 host，需自行替换为真实服务器） |
| `proxy` | `~/.bash_proxy` | HTTP/SOCKS 代理环境变量（端口 7890）+ `no_proxy` 镜像源白名单（按"云厂商"/"教育网"/"AI 模型镜像"/"工具链 registry"四组维护；注意 no_proxy 是后缀匹配，非对称命名的子域如 `pypi.tuna.tsinghua.edu.cn` 必须单独列） |
| `tmux` | `~/.tmux.conf` | tmux 配置 |
| `claude` | `~/.claude/{settings.json,CLAUDE.md,statusline.sh,commands/,skills/,agents/,rules/}` | Claude Code 全局配置/指令 + statusline 脚本 + 自定义 commands/skills/subagents/rules |
| `vscode` | `~/.vscode-server/data/Machine/settings.json` | VS Code Remote-SSH server 端的 Machine-level 设置（仅服务器侧生效） |

根目录的 `.bashrc` **不属于任何 stow package**，是参考/备份文件。

## 常用命令

```bash
# 部署基础配置
stow -t ~ bash git

# 部署所有 package
stow -t ~ bash git ssh proxy tmux claude zsh

# 移除某个 package 的链接
stow -D -t ~ <package>

# 模拟部署（不实际创建链接）
stow -n -t ~ <package>
```

## Stow tree folding 行为（最少链接原则）

Stow 创建 symlink 时遵循「最少链接原则」（官方术语 *tree folding*）：从 package 内的相对路径出发，沿目标侧逐级向上找，**最深的不存在的层级**就是 symlink 落脚点，该层级及以下全部由这一个 symlink 接管。

举例：源端 `claude/.claude/commands/foo.md` 部署到 `~/`：

| 目标侧状态 | 创建的 symlink | 效果 |
|-----------|---------------|------|
| `~/.claude/` 不存在 | `~/.claude` → 源端 `.claude` | 整个 `.claude/` 由 symlink 接管 |
| `~/.claude/` 存在、`~/.claude/commands/` 不存在 | `~/.claude/commands` → 源端 `commands` | 整个 `commands/` 接管，源端新增文件**自动出现**在目标侧 |
| `~/.claude/commands/` 已存在 | 逐文件 link，仅 `~/.claude/commands/foo.md` | 源端后续新增 `bar.md` **不会**自动出现，必须重跑 `stow claude` |

**核心 gotcha**：想让某个子目录的"内容"持续与源端同步（典型如 `commands/`、未来的 `skills/`），**首次部署前必须保证目标侧同名目录不存在**。常见踩坑场景：先装 Claude Code plugin 让其在 `~/.claude/skills/` 自动建目录，再 `stow claude`，此时 `skills/` 只能逐文件 link，源端任何新增都需手动 re-stow。

应对：
- 部署顺序：先 `stow claude` 再 `/plugin install ...`，让 stow 先抢占整目录 link 权。
- 已落入逐文件 link 状态时：`stow -D claude && rm -rf ~/.claude/<dir>` 后重 stow（前提：该目录里没有未追踪到 stow 的内容）。
- 多个 package 都要往同一目标目录贡献内容时（无法 fold 同一目录），用 `stow --no-folding <pkg>` 主动禁止整目录 link，让所有 package 都走逐文件 link 模式。
- 反向机制 *tree unfolding*：往已 fold 的目录里加第二个 package 的同名目录时，stow 会自动把已有的整目录 symlink 拆成"目录 + 子文件 symlink"形式腾出空间，所以 fold/unfold 是按需自动发生，不需要手动管。

## 编辑规范

- 新增配置文件：在对应 package 目录下按 `$HOME` 的相对路径放置（如 `ssh/.ssh/config`）
- 新增 package：创建新顶层目录，内部结构镜像 `$HOME` 的目标路径
- bash 和 zsh 的别名/函数分别维护在各自的 aliases 文件中，两者有重复的通用部分
- SSH 配置包含端口转发规则，修改时注意不要暴露敏感信息
- `.gitignore_global` 由 git package 管理，覆盖 Linux/macOS/VSCode/Python 场景

### Claude Code 资源约定（claude package）

- **自定义 skill** 走 `claude/.claude/skills/<name>/SKILL.md`（标准目录结构 + frontmatter `name`/`description`），不要在 `commands/` 下写裸 `.md`
- **自定义 subagent** 走 `claude/.claude/agents/<name>.md`（frontmatter `name`/`description`/`tools` 等）
- **自定义 rule** 走 `claude/.claude/rules/<name>.md` —— YAML frontmatter `paths` 字段做 glob 匹配（仅 Read/Edit 命中匹配文件时加载）；省略 `paths` 字段时行为同 CLAUDE.md fragment（session 启动全局加载）
- `commands/` 用 `.gitkeep` 占位 —— Claude Code 对 `commands/` 下走「每个 .md 都是 skill、path-as-namespace」解析，对 `skills/` 下走「每个目录是一个 skill，必须含 SKILL.md」解析，两套规则不通用；新增 skill 一律走 `skills/`
- 当前自带 reference skill：`pixi`（Python 项目管理）
- **Plugin 与 marketplace 清单 = `settings.json` 的 `enabledPlugins` + `extraKnownMarketplaces` 字段**。Claude Code 启动时会自动按这两个字段安装/启用 plugin 和注册 marketplace，**不需要手动 `/plugin install ...` 或 `/plugin marketplace add ...`**。增删 plugin 直接改 `settings.json` 即可，stow 部署后下次 Claude Code 启动会自动 reconcile
- **LSP plugin 的运行时依赖**：`pyright-lsp` / `typescript-lsp` 需要分别 `npm install -g pyright` 和 `npm install -g typescript-language-server typescript`；statusline 脚本依赖 `jq`。这些 runtime 依赖不通过 plugin 自带，必须宿主系统已装（README 已列出）

### 不纳入 stow 的 Claude Code 文件

- `~/.claude.json`：CLI state file（含 oauth account / cache / projects / feature flags / onboarding 旗标），每会话秒级变动。绝大部分是 state、极少量才是用户配置（`mcpServers` 字段）。整文件不要 sync —— 跨机器同步会引发持续 git 冲突 + 账户身份污染。如需跨机器复用 user-level MCP servers，建议把 `mcpServers` 字段抽到独立文件、启动时脚本合并写回 `~/.claude.json`，而非整文件同步

### 仓库根的 `.gitignore`

`.gitignore` 只有一行 `.claude/*`。它防止 **dotfiles 仓库根**被 Claude Code 当成项目时自动创建的 `.claude/` session state（projects/、todos/ 等）误入提交。这与 stow 部署到 `~/.claude/` 的源端（`claude/.claude/`）无关。
