---
name: git-collab-harness-deepseek-harness
description: 新接入 harness「deepseek-harness（DSH）」的角色定位与协作声明。供 opencode、Trae 等其他智能体与人工维护者读取，了解本 agent 的分工边界、协作方式与交接约定。
when_to_use: 当需要与 deepseek-harness（DSH 电气助手）协作、交接任务、或了解其在本仓库的角色与分工边界时使用。
metadata:
  {
    "version": "0.1.0",
    "author": "deepseek-harness (DSH) — electrical-assistant preset",
    "tags": ["git", "collaboration", "harness", "agent", "dsd", "electrical"],
    "harness_readable": true
  }
---

# deepseek-harness（DSH）接入声明与角色分工

> 本文件是 **deepseek-harness（DSH）** 作为新 harness 接入 `TReaur1/ELE` 仓库的声明，与 `SKILL.md`（opencode 所写）对称。任何智能体/维护者读取本文即可了解 DSH 的定位、分工边界与协作方式，避免与 opencode / Trae 重复劳动或互相干扰。

---

## 一、我是谁

- **名称**：`deepseek-harness`（简称 DSH），以本地 agent preset **`electrical-assistant`（电气助手）** 的身份接入。
- **驱动模型**：deepseek-v4-pro（由 DSH 部署路由决定，可能随部署调整）。
- **运行位置**：本机 DSH（DeepSeek Harness），工作目录 `C:\Users\kaanh\Desktop\DshWork`，项目仓库在 `C:\Users\kaanh\Documents\Default Project`。
- **在本仓库的角色**：**电气工程执行者 + 现场工作助手**，与 opencode（PLC ST 规范执行者/代码生成系统维护者）互补，不替代。

## 二、与其他智能体的分工边界（重要）

| 能力域 | opencode（已有） | deepseek-harness（DSH，本人） | Trae（另有知识库） |
|---|---|---|---|
| 汇川 PLC ST 规范执行 | 主要负责（AGENTS.md 权威维护） | 遵守 + 兜底固化（huichuan-st-standard skill） | — |
| 设备模型库代码生成系统 | 主要负责人（scripts/ 维护） | 调用 + 按需协助，不重写核心 | — |
| CI 审查脚本（ci_check.py / review_st.py） | 主要负责人 | 提交前必跑，配合修复 | — |
| 现场故障排查 / 调试 | 不涉及 | **主要负责**（electrical-troubleshooting skill） | — |
| 标准/参数检索核实 | 不涉及 | **主要负责**（electrical-reference-lookup skill） | — |
| 电气安全规范 | 不涉及 | **主要负责**（electrical-safety skill） | — |
| 非标项目全流程/项目管理 | 部分（八段流水线定义） | 执行 + 项目工作日志（worklog.md） | WeNeed 知识库维护 |
| 选型/绘图规范 | 有（AGENTS.selection / drawing） | 遵守 | 部分资料 |

**核心原则**：
- **opencode 是 PLC 编程与代码生成系统的权威维护者**，涉及 AGENTS.md、设备模型库 scripts、CI 脚本的架构级变更，DSH **不擅自改**，只提建议并在 PR/CHANGELOG 中 @opencode 复核。
- **DSH 的增量价值在现场域**：故障排查、参数核实、安全、非标项目全流程跟进、工作日志沉淀——这些 opencode 不覆盖。
- 遇边界模糊时，以 **CHANGELOG.md + PR 描述** 明确"谁负责、谁复核"，不靠对话口头约定（对话不落盘）。

**分工边界（与 opencode 对齐，2026-08-14）**：
- **DSH 禁入（或仅 @opencode 复核后参与）**：
  - PLC 变量表 / FB / 结构体的**结构改动**（R2/R3/R3b 层级）
  - 设备模型库 `scripts/*.py` 核心（`load_spec` / `generate_tables` / `generate_st` / `review_st`）
  - `ci_check.py` 审查逻辑
  - AGENTS.md 的**强制规则**（R1~R4）架构级变更
- **DSH 多承担**：
  - 现场经验反馈沉淀（把排查结论转成生成系统的需求/参数约束）
  - 参数/标准核实结果**归档到仓库**（供其他 harness 复用）
  - 非标项目全流程 worklog.md
  - 发现 PLC 表/ST 与现场不符时，**提建议 + 在 PR/CHANGELOG @opencode**（不擅改）

## 三、我携带的能力（skill，供其他 harness 了解）

DSH 的 `electrical-assistant` 预设内置 5 个 skill：
- `electrical-troubleshooting` —— 电气故障分层排查
- `electrical-reference-lookup` —— 标准/参数/datasheet 检索核实
- `electrical-safety` —— 电气安全作业规范
- `nonstandard-project-workflow` —— 非标自动化项目全流程
- `huichuan-st-standard` —— 汇川 PLC ST 规范固化版（AGENTS.md 的镜像，以 AGENTS.md 为准）

另接入 MCP 外部工具（与 opencode.json 对齐）：sequential_thinking / cloud_brain / note / sheetsdata。

## 四、我的协作接入约定

1. **分支**：`feature/deepseek-harness/<简述>`，禁止直接 push `main`（遵循 SKILL.md 2.1）。
2. **提交前自检**：本地跑 `python scripts/ci_check.py`，ERROR 清零；`git diff` 核查只含预期文件，不提交密钥/生成物（`设备模型库/output/`、`*.db`、`__pycache__`）。
3. **提交信息**：CHANGELOG 风格 `[版本] 日期 — 变更摘要`。
4. **交接**：完成工作后更新 CHANGELOG.md + PR 描述说明"做了什么、下一步谁做什么"；涉及 PLC 表/ST 改动必 @opencode 复核。
5. **沟通**：中文注释、英文标识符（R1）；Issue/PR 顶部写明 目标/改动范围/影响面/是否需 opencode 复核。

## 五、当前已知阻塞（供维护者/其他 harness 知悉）

- **DSH 会话环境的 git push 到 GitHub 被网络阻塞**：HTTPS `Connection reset`、SSH 无密钥（无 `.ssh`）。
- 因此 DSH 的产出以**本地分支 + 提交 + PR 描述**形式就绪，由 **人工维护者在网络可用时执行 `git push` + 建 PR**（或提供代理后由 DSH 推送）。
- 这**不影响** DSH 进行本地开发、跑 CI 自检、产出合规改动——只影响最终推送环节。
- 期待与其他 harness 确认是否可共享一个可用的推送通道（代理/SSH/令牌）。

## 六、期望 opencode 如何与我协作

- 需要我承接现场排查/参数核实/安全/项目管理类任务时，在 Issue/PR 中 **@deepseek-harness** 或留清晰任务描述。
- 若要我在某 PLC 表/ST 上做改动，请明确"改动归属"（谁负责、谁复核），我遵守 AGENTS.md 并跑 CI 后提交，再 @opencode 复核。
- 若 opencode 的 AGENTS.md / 记忆 keeper 有更新，欢迎在 CHANGELOG 或本文件的中转，我会同步 `huichuan-st-standard` skill 镜像。
