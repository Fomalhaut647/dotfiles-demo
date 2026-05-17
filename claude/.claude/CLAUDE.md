# 用户偏好与协作规范

> 本文件是 maintainer 个人在使用的用户级 `~/.claude/CLAUDE.md` 示例 —— Claude Code 启动时会自动加载它，跨所有项目生效。下面是若干通用偏好规则，你可以基于此模板挑选 / 改写成自己的版本。

## 语言
使用中文与用户交流。

## 环境管理
如果项目语言是 Python，使用 Pixi 管理环境。

## 执行大型任务前
执行大型任务之前必须报告方案并请求批准，用户明确批准后才能开始执行。即使用户没有显式要求等待批准，即使用户已经提供了一版方案，只要判断当前任务耗时久，就要在用户批准后才执行，因为用户提供的方案可能有瑕疵，需要讨论后再执行。

## 回答问题的格式
回答普通问题时先给结论再解释。

## chat 输出特殊字符规则

**禁止**（chat 输出 / 代码 / 文档全适用）：
- **渲染不稳的字符**：圈数字 ①②③④⑤、⑴⑵⑶（终端字体缺失或字宽不固定）
- **键盘难输入的字符**（多选题选项标签场景特别关键）：希腊字母（α / β / γ / δ）、中文方括号 (【一】【二】)、圈字符 (①②③) 等需要切换输入法或敲多个键才能复述的字符

**替代**：列表 / 分级 / 多选题选项标签用 `1./2./3.`、`a)/b)/c)`、`A/B/C` 等纯 ASCII。

**理由**：用户回答 "选 β" 比 "选 2" 麻烦得多（要敲 `\beta` / 切输入法 / 复制粘贴）；圈数字在终端字宽异常对齐崩。永远站在"用户敲键盘选答案 + 我在终端读文本"的视角设计。

## 任务执行后的报告
执行任务后报告执行了哪些操作及其影响。执行长程任务的过程中多报告当前进度。如果执行了计划外的操作，不一定要申请批准但一定要报告，以便用户掌控任务进度。

## 完成大任务后自动更新项目文档
完成大任务（milestone 交付 / 重大 feature / 重构 / 子方案实施完毕等）后，**主动**更新项目级 `CLAUDE.md` 和 `README.md`，使之与代码当前状态保持一致。**不要等用户提醒** —— 文档腐烂的代价是下次会话误判。

更新粒度：incremental（改相关段落）而非全文重写，除非已大面积偏离实际。CLAUDE.md 给 agent 看（完整工作指引），README.md 给人类看（5 分钟上手），二者风格不同但内容真理保持一致。

## 信息获取操作
对于不会造成破坏的获取信息的操作，不需要用户批准。用户询问问题时，如果解决方法并不危险，直接执行该方法并返回结果，而不是告诉用户方法让其自己去执行。

## 并行偏好

派 subagent / 跑独立 tool calls / 做工作分发时，**默认尝试并行**而非串行：

- 多个独立 Read / Bash / Edit / Write 工具调用 → 同一 message 多 tool call 并行
- 多份独立文档撰写 → 并行 Write
- fan-out 子任务（多 fixture 各自构造、多 design 各自 explore、多模块各自实现）→ 派多个 subagent 并行执行

**例外**（必须串行）：
- 同一文件多次编辑（race condition）
- step 之间存在硬依赖（B 模块依赖 A 模块产出 = 不能并行）

判断标准是**依赖图**：两个任务无共享状态、无文件冲突、无顺序依赖 → 并行；否则串行。**默认假设可并行，只在确认有冲突时退回串行。**

## 派 background Agent 务必设 `name`

派 background / 长 turn agent 时**务必传 `name` 参数**。否则 agent 中途因 socket 关闭 / API 错误中断后，无法用 `SendMessage` 接续 —— 只能丢弃 in-flight 状态重新派。即便看起来是一次性任务，长 turn（数分钟以上）也可能中途断。

## Git 工作树意外状态
看到 git 工作树里的意外状态（`deleted`、未追踪文件、分支领先/落后、不熟悉的分支）时，不要本能地用 `git restore` / `reset --hard` / `clean -f` 等命令"撤销"——这些状态多半是用户的进行中工作（手动删除、移动、stash 恢复等）。先调查（`git log` / `git stash list` / 对比内容）或直接问用户，再决定动不动。

## Commit 粒度

commit 粒度**介于 squash（什么都合一起）和 rebase 保留每个 commit（什么都不合）之间**：**关联紧密的小改动合一个 commit，逻辑独立的大改动各自留独立 commit**。

**Commit 拆分判断标准**：未来 `git bisect` 时**单个 commit 失败应该能读出"哪个独立故事"**。一个 commit 同时干两件不相关的事 = bisect 不出有效信号。

- 反例：「typo fix + 加 feature + 改 docs」→ 不该合，应该三个独立 commit
- 正例：「重命名一个函数 + 同步 update callers + 改测试 fixture 命名」→ 同一改动的连带操作，合一个 commit
- 边界判断：如果改动 A 和改动 B **revert 其中一个不影响另一个**，→ 应该是两个 commit；如果 revert 一个会让另一个失去意义 / 破坏 build，→ 合一个

## PR merge 风格

- **默认** `gh pr merge --squash --delete-branch`：main 历史每行 = 一个 PR
- **PR 内多 commit 跨域且各自完整时** 改用 `gh pr merge --rebase --delete-branch` 保留 commit 粒度 + 线性历史
- **禁用 `--merge`**：merge commit 在 `git log --oneline --graph` 上制造三角形拓扑、增加噪声；PR 边界信号可由 squash commit message 自带的 `(#N)` 恢复
- **`gh pr merge --delete-branch` 前必先 `git checkout main` 切走当前 active branch**：否则本地分支被占用，删除失败，命令中断而远端 branch 也没删

## ssh non-interactive cwd 默认 $HOME

`ssh user@host "git pull"` non-interactive shell cwd 默认 $HOME 不是 ssh 之前 local 的 cwd。chained command 第一条是 git 操作时必须 `ssh user@host "cd <project> && git pull && ..."` 显式 cd。否则 `fatal: not a git repository`，整 chain 在第一条断。

## 反思要立即固化
当某次会话产生了值得未来复用的教训 / 规则 / 偏好时，**立刻**写入 CLAUDE.md，不要只在当前 chat 里说"值得记下"——chat 里的反思会随会话上下文消散，下次会话的我看不到，等于没记。默认写到**用户级** `~/.claude/CLAUDE.md`（跨项目通用）；只有当教训**确实只和当前项目相关**时，才写项目级 `<repo>/CLAUDE.md`。判断标准：换一个项目这条规则还成立吗？成立 → 用户级；只在本项目语境下才有意义 → 项目级。
