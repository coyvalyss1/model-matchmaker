# Model Matchmaker for Droid (Factory)

将 Model Matchmaker 的智能模型路由能力移植到 [Factory Droid](https://docs.factory.ai)，并利用 Droid 特有的 `PreToolUse` / `PostToolUse` 事件实现增强功能。

## 功能概览

| Hook | 事件 | 功能 |
|------|------|------|
| `session-init.sh` | SessionStart | 注入模型意识上下文，让 AI 主动建议切换模型 |
| `model-advisor.sh` | UserPromptSubmit | 分类任务复杂度，阻止并推荐合适的模型 |
| `command-validator.sh` | PreToolUse[Execute] | 拦截 `rm -rf`、`sudo`、`git push --force` 等危险命令 |
| `usage-tracker.sh` | PostToolUse[*] | 记录所有工具调用日志，用于分析和优化 |

## 快速安装

### 方式一：项目级安装（推荐）

将 `.factory/` 目录复制到你的项目根目录：

```bash
cp -r .factory/ /path/to/your-project/.factory/
chmod +x /path/to/your-project/.factory/hooks/*.sh
```

Droid 启动时会自动加载 `.factory/settings.json` 中的 hooks 配置。

### 方式二：全局安装

将配置合并到全局 settings：

```bash
# 复制 hooks 脚本
mkdir -p ~/.factory/hooks
cp .factory/hooks/*.sh ~/.factory/hooks/
chmod +x ~/.factory/hooks/*.sh
```

然后将 `.factory/settings.json` 中的 hooks 配置合并到 `~/.factory/settings.json`，并将路径中的 `"$FACTORY_PROJECT_DIR"/.factory/hooks/` 替换为 `~/.factory/hooks/`。

## 配置说明

`.factory/settings.json` 定义了 4 个 hook 事件：

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "\"$FACTORY_PROJECT_DIR\"/.factory/hooks/session-init.sh", "timeout": 2 }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "\"$FACTORY_PROJECT_DIR\"/.factory/hooks/model-advisor.sh", "timeout": 2 }] }],
    "PreToolUse": [{ "matcher": "Execute", "hooks": [{ "type": "command", "command": "\"$FACTORY_PROJECT_DIR\"/.factory/hooks/command-validator.sh", "timeout": 2 }] }],
    "PostToolUse": [{ "matcher": ".*", "hooks": [{ "type": "command", "command": "\"$FACTORY_PROJECT_DIR\"/.factory/hooks/usage-tracker.sh", "timeout": 2 }] }]
  }
}
```

## 模型路由规则

### 需要设置环境变量

`model-advisor.sh` 通过环境变量 `DROID_MODEL` 获取当前模型信息。在启动 Droid 前设置：

```bash
export DROID_MODEL="claude-4-opus"   # 或 claude-4-sonnet, claude-4-haiku
droid
```

或在 shell 配置文件（`~/.zshrc` / `~/.bashrc`）中添加：

```bash
export DROID_MODEL="claude-4-sonnet"  # 你常用的默认模型
```

### 路由逻辑

| 当前模型 | 任务类型 | 动作 |
|----------|----------|------|
| Opus | 简单任务 (git, rename, format) | 阻止，建议 Haiku |
| Opus | 标准实现 (build, fix, debug) | 阻止，建议 Sonnet |
| Sonnet/Haiku | 架构/深度分析 | 阻止，建议 Opus |
| 任意 | 匹配当前模型 | 直接通过 |

### 覆盖机制

在提示词前加 `!` 绕过分类：

```
! just do it, I know what I'm doing
```

## 日志文件

所有日志写入 `.factory/hooks/` 目录：

```
.factory/hooks/model-advisor.log   # 模型路由决策日志
.factory/hooks/usage-stats.log     # 工具使用统计日志
```

查看日志：

```bash
# 查看模型路由日志
cat .factory/hooks/model-advisor.log
# [2026-03-06 15:00:01] model=claude-4-opus rec=haiku action=BLOCK prompt="git commit all chang..."

# 查看工具使用统计
cat .factory/hooks/usage-stats.log
# [2026-03-06 15:00:05] session=abc12345 tool=Edit cwd=/path/to/project
```

## 验证安装

在 Droid 中运行 `/hooks` 命令查看已注册的 hooks。

手动测试各脚本：

```bash
# 测试 session-init
echo '{}' | .factory/hooks/session-init.sh

# 测试 model-advisor (需设置 DROID_MODEL)
export DROID_MODEL="claude-4-opus"
echo '{"prompt": "git commit all changes"}' | .factory/hooks/model-advisor.sh

# 测试 command-validator
echo '{"tool_input": {"command": "rm -rf /"}}' | .factory/hooks/command-validator.sh

# 测试 usage-tracker
echo '{"session_id": "test", "tool_name": "Edit", "cwd": "/tmp"}' | .factory/hooks/usage-tracker.sh
```

## 与原版 Cursor/Claude Code 版本的区别

1. 配置格式从 `hooks.json` 改为 `.factory/settings.json`
2. 事件名从 `sessionStart` / `beforeSubmitPrompt` 改为 `SessionStart` / `UserPromptSubmit`
3. 模型信息从 stdin JSON 改为环境变量 `DROID_MODEL`
4. 日志路径从 `~/.cursor/hooks/` 改为 `.factory/hooks/`
5. 新增 `PreToolUse` 危险命令拦截
6. 新增 `PostToolUse` 工具使用统计
7. 使用 `$FACTORY_PROJECT_DIR` 确保路径正确
