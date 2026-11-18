# AGENTS.md

本文件同时被 OpenCode 与 DeepSeek Harness (dsh) 加载，作为本仓库的工作约定。

## 项目

**Java4Shell Detector** —— Godot 4.7.2 桌面工具：检测本机 Java 版本与 CPU 指令集，输出检测报告。

| 组成 | 位置 | 说明 |
| --- | --- | --- |
| 主场景 / UI | `main.tscn`、`script/*.gd` | `script/report.gd`、`quit.gd` 为按钮脚本；`data_core.gd` 持有结果数据 |
| Python 检测逻辑 | `script/python/checkJavaVer.py`、`checkCpuSet.py` | 由 PyBundle 打包的 Python 解释器执行 |
| 运行时桥接 | `addons/PyBundle/`、`addons/BinBundle/` | `PyRunner` autoload 负责启动 Python 子进程并读取输出 |
| 本地化 | `i18n.xlsx` → `i18n/*.translation` | 文案改动应回到 xlsx，不要手改 `.translation` |
| 导出 | `export_presets.cfg`、`build/` | `build/` 与 `.godot/` 已在 `.gitignore` |

引擎：`4.7.2.stable.official`，可执行文件 `/home/jerryhan3/App/Godot/Godot_v4.7.2-stable_linux.x86_64`（项目 `config/features` 已声明 `"4.7"`）。渲染后端为 `mobile`。

## Agent 工具链

环境搭建与验证细节见 `.agents/README.md`，这里只写使用约定。

- **godot MCP 服务器**（OpenCode 与 dsh 均已接入）：提供 157 个 Godot 工具，含 `validate_script`、`run_project`、`stop_project`、`get_debug_output`、场景增删节点、`get_project_info` 等。dsh 中工具名为 `mcp__godot__<tool>`。
  - 改完 GDScript 先 `validate_script`，再 `run_project` + `get_debug_output` 验证运行时行为——不要只靠“看起来对”。
  - 工具接收的 `project_path` 传本仓库绝对路径。
- **godot-master Skill**：`Godot 4.7+` 架构与性能知识库（`SKILL.md` + `references/` + `scripts/`）。涉及场景/节点架构、状态机、性能预算、2D/3D 选型、UI 容器、导出与平台适配时先读它，再动手；纯文案或小 bug 修复不必加载。
- **自检**：`python3 .agents/bin/mcp-smoke.py`（握手 + 157 工具 + 版本 + 项目信息）。OpenCode 侧另可 `opencode mcp list`。

## 约定

- 所有路径用 `res://`；运行时可写数据只放 `user://`（PyBundle 解释器解压到 `user://Python/`）。
- GDScript 用 4.x 写法：`signal_name.connect(callable)`、`_physics_process` 做物理、`%UniqueName` 取节点。
- 不要提交 `build/`、`.godot/`、`.venv/`；不要手改 `*.uid`。
- 触碰导出配置、`project.godot` 的 autoload/插件列表，或删除用户文件前，先说明影响并征得同意。
- `game_*` 运行时工具需要项目内 autoload `McpInteractionServer`，**当前未安装**（会变成产品行为变更）；需要时先确认。
