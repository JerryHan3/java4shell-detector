# Agent 环境（本仓库）

为 **OpenCode** 与 **DeepSeek Harness (dsh)** 准备的 Godot 开发环境，包含两部分：

| 组件 | 内容 | 位置 |
| --- | --- | --- |
| `godot` MCP 服务器 | 157 个工具：场景读写、脚本校验、运行/调试输出、`game_eval` 运行时控制等 | 本机安装 `~/.local/share/godot-mcp` + 启动器 `.agents/bin/godot-mcp.sh` |
| `godot-master` Skill | Godot 4.7 架构/性能/模式知识库（92 个领域技能，374 篇参考） | `.agents/skills/godot-master/` |

两个 agent 都从 `.agents/` 读取，因此同一份配置同时生效：

- Skill：`<项目根>/.agents/skills`（OpenCode 与 dsh 都会扫描）
- MCP：OpenCode 用仓库根的 `opencode.json`；dsh 用 profile 补丁层（见下文）
- 指令：仓库根 `AGENTS.md` 同时被两者加载

---

## 1. 前置条件

| 依赖 | 版本/路径 | 说明 |
| --- | --- | --- |
| Godot | `4.7.2.stable` — `/home/jerryhan3/App/Godot/Godot_v4.7.2-stable_linux.x86_64` | 启动器会依次尝试 `GODOT_PATH` → `~/App/Godot/Godot_v4.7.2*` → `~/App/Godot/Godot_v4.6.1*` → `godot` / `godot4` |
| Node.js | ≥ 18（本机 v22.23.5） | MCP 服务器是 Node/TypeScript 程序 |
| Python | 3.8+（仅用于自检脚本） | 仓库已有 `.venv`，自检用系统 `python3` 即可 |

---

## 2. godot MCP 服务器

### 2.1 选型

`@tugcantopaloglu/godot-mcp` **3.1.0**（MIT），上游 <https://github.com/tugcantopaloglu/godot-mcp>，是 `Coding-Solo/godot-mcp` 的扩展分支：工具数 20 → 157，并修复了 Godot 4.4+ 的若干兼容问题，上游明确标注 *tested with Godot 4.7*。

选择它的原因：纯 stdio、无需在项目里装编辑器插件（不污染 `project.godot` / `addons/`）、按需 headless 调用 Godot CLI，且自带 `validate_script` / `run_project` / `get_debug_output` 这套“改完就能自检”的闭环。

> 备选（未采用）：`Coding-Solo/godot-mcp`（npm `@coding-solo/godot-mcp@0.1.1`，更旧、工具更少）；`@npgamedev/godot-mcp-server`、`@satelliteoflove/godot-mcp` 等编辑器内插件类方案（需要在 `addons/` 里安装插件）。

### 2.2 安装位置与重建

已安装在仓库外的用户目录，**不进入 git**：

```text
~/.local/share/godot-mcp/          # git clone + npm ci + npm run build 的结果（约 130 MB，含 node_modules）
~/.local/share/godot-mcp/build/index.js   # MCP 入口
```

当前检出的上游提交：`88f0fbc`（`npm ci` 时 `prepare` 脚本已自动执行 `tsc && node scripts/build.js`）。

重建/升级：

```bash
git clone --depth 1 https://github.com/tugcantopaloglu/godot-mcp.git ~/.local/share/godot-mcp
cd ~/.local/share/godot-mcp && npm ci --no-audit --no-fund
test -f build/index.js && echo "build ok"
```

### 2.3 启动器

`.agents/bin/godot-mcp.sh` 是唯一的启动入口，两个 agent 都调它：

| 变量 | 默认 | 作用 |
| --- | --- | --- |
| `GODOT_MCP_HOME` | `~/.local/share/godot-mcp` | MCP 服务器安装目录 |
| `GODOT_PATH` | 自动探测 | Godot 可执行文件 |
| `GODOT_MCP_ALLOWED_DIRS` | 未设置（不限制） | 可选：用 `:` 分隔的项目根白名单，限制文件类工具的作用范围 |

脚本只往 stderr 写诊断信息（stdio 传输要求 stdout 只承载协议）。

### 2.4 自检（不经过 agent）

```bash
python3 .agents/bin/mcp-smoke.py
```

期望输出：

```text
OK   handshake: godot-mcp 0.1.0
OK   tools: 157
OK   get_godot_version: 4.7.2.stable.official.ed1daf0bf
OK   get_project_info: Java4Shell Detector (4.7.2.stable.official.ed1daf0bf)
```

### 2.5 OpenCode 接入

仓库根 `opencode.json`：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "godot": {
      "type": "local",
      "command": [".agents/bin/godot-mcp.sh"],
      "cwd": ".",
      "enabled": true,
      "timeout": 60000
    }
  }
}
```

验证：

```bash
opencode mcp list          # 期望：✓ godot connected
opencode debug config      # 期望：mcp.godot 解析为本地命令
```

### 2.6 DeepSeek Harness 接入

dsh 的 MCP 服务器只能通过 **profile 补丁层**声明（没有项目级 MCP 配置）。已写入 `~/.dsh/profiles/web/cordis.patch.yml`：

```yaml
- insert:
    - id: mcp-godot
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: godot
        transport: stdio
        command: /home/jerryhan3/Code/Godot/java_4_shell_detector/.agents/bin/godot-mcp.sh
        cwd: /home/jerryhan3/Code/Godot/java_4_shell_detector
        toolCallTimeoutMs: 120000
```

- 模型侧工具名为 `mcp__godot__<tool>`，例如 `mcp__godot__run_project`、`mcp__godot__validate_script`。
- 该文件在修改前的备份：`~/.dsh/profiles/web/cordis.patch.yml.bak-20261118215427`。
- **作用范围**：`web` profile 全局（所有项目启动 `dsh web` 都会连上这个服务器）。服务器工具本身接受 `project_path` 参数，且默认工作目录固定为本仓库；若只想对某个项目生效，可把这段 YAML 存为项目内补丁文件，再用 `dsh web --patch <该文件>` 启动，同时从 profile 补丁里删除。
- 其他 profile（如 `headless`）如需同样能力，把上述 `insert` 条目追加到 `~/.dsh/profiles/<name>/cordis.patch.yml`，或写入对所有 profile 生效的 `~/.dsh/cordis.patch.yml`。

验证：

```bash
dsh --profile web --dump-config | grep -A8 mcp-godot    # 期望：条目被组合进插件树
dsh web --host 127.0.0.1 --port 0 --no-open             # 启动日志出现 Godot MCP server running on stdio
```

### 2.7 运行时工具（可选）

`game_*` 系列（`game_eval`、`game_get_property`、`game_call_method` …）需要游戏进程内有 TCP 交互服务器：把安装目录里的 `build/scripts/mcp_interaction_server.gd` 复制进项目并注册为 autoload `McpInteractionServer`（监听 `127.0.0.1:9090`）。

**默认未安装** —— 它会在导出版本里也带上调试端口，属于产品行为变更，需要你确认后再加。

---

## 3. godot-master Skill

```text
.agents/skills/godot-master/
├── SKILL.md        # 523 行入口：决策矩阵、Workflow、NEVER 清单、性能预算、Server API
├── references/     # 374 篇领域参考（架构、2D/3D、UI、网络、平台、类型模板…）
└── scripts/        # 1294 个可直接引用的 .gd/.gdshader/.py 片段
```

- 来源：Cherry Studio 技能库里的同名技能（上游 <https://github.com/thedivergentai/gd-agentic-skills>），整目录复制，未做修改。
- 体积约 8.5 MB / 1751 个文件，**已写入 `.gitignore`**（`.agents/skills/godot-master/`），不进入仓库；换机器或新克隆后需重新复制，本地使用不受影响：

```bash
cp -a /home/jerryhan3/.config/CherryStudio/Data/Skills/godot-master .agents/skills/
# 上游：https://github.com/thedivergentai/gd-agentic-skills
```

- 两个 agent 的发现路径：OpenCode 扫描 cwd 向上的 `.agents/skills`；dsh 的 `dsh-skill-filesystem` 以 rank 200 扫描 `<项目根>/.agents/skills`（项目根 = 最近的含 `.git` 的祖先目录）。

验证：

```bash
opencode debug skill | grep -A2 godot-master    # 期望：列出 name/description/location
```

---

## 4. 排错

| 现象 | 原因与处理 |
| --- | --- |
| `opencode mcp list` 显示 failed | 先跑 `python3 .agents/bin/mcp-smoke.py` 看服务器本身是否可用；再确认 `node -v ≥ 18` |
| 启动器报 `no Godot executable found` | 设置 `GODOT_PATH` 指向 Godot 4.x 可执行文件 |
| 工具调用返回 `Godot not found` | dsh 会清洗子进程环境，`GODOT_PATH` 需要在启动器的自动探测路径内，或改用绝对路径常量 |
| 技能未出现 | 确认 `SKILL.md` 的 YAML frontmatter 含 `name` + `description`；目录必须是 `.agents/skills/<name>/SKILL.md`（嵌套更深不会被发现） |
| `game_*` 工具报连接失败 | 属于预期：未安装 2.7 节的运行时 autoload |
| dsh 启动变慢 | MCP 服务器在启动时连接；只在需要的 profile 里声明，或设 `disabled: true` |

---

## 5. 回滚

```bash
# 1) 移除 dsh 补丁层
cp ~/.dsh/profiles/web/cordis.patch.yml.bak-20261118215427 ~/.dsh/profiles/web/cordis.patch.yml

# 2) 移除 OpenCode MCP 配置
rm opencode.json

# 3) 移除 Skill（以及启动器、自检脚本）
rm -rf .agents/skills/godot-master .agents/bin

# 4) 卸载 MCP 服务器（仓库外）
rm -rf ~/.local/share/godot-mcp
```

以上每一步都可独立执行，互不依赖。
