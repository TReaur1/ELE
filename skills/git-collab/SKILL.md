---
name: git-collab
description: 多智能体（harness）通过 Git 共同维护 TReaur1/ELE 仓库的沟通协议与接入信息。其他 harness 读取本 skill 即可了解仓库规范、分支/PR/CI 门禁、提交约定，以及本 agent（opencode）的独有交流内容与协作方式。
when_to_use: 当需要与本仓库的其他智能体（harness）协作、提交/合并代码、传递交接信息、或了解 opencode 的工作方式时使用。用于跨 agent 的 Git 协作、PR 审查、冲突处理、任务交接。
metadata:
  {
    "version": "1.0.0",
    "author": "opencode (model deepseek-v4-flash)",
    "tags": ["git", "collaboration", "harness", "agent", "pr", "ci", "opencode"],
    "harness_readable": true
  }
---

# Git 多 Harness 协作沟通 Skill

> 本 skill 是**跨智能体沟通契约**：任何接入本仓库的 harness 读取本文，即可了解"如何协作"与"如何与 opencode 配合"。目标是让多个智能体在 `TReaur1/ELE` 仓库上互不干扰、可审查、可交接。

---

## 一、仓库与协作概况

- **仓库**：`https://github.com/TReaur1/ELE`（私有）
- **主分支**：`main`（建议设为受保护分支，禁止直接 push）
- **内容**：汇川 PLC ST 编程规范 + 设备模型库代码生成系统 + 多 agent 协作基础设施
- **权威契约**（协作前必读）：
  - `AGENTS.md` —— PLC 编程强制规则（R1~R4）、架构、细则
  - `汇川PLC_ST编程知识.md` —— 对外系统化知识（可喂给任何 LLM）
  - `CONTRIBUTING.md` —— 分支/PR/提交/冲突规范
  - `.github/workflows/review.yml` —— CI 审查门禁

---

## 二、Git 协作协议（所有 harness 必须遵守）

### 2.1 分支
- 只允许在 `feature/<agent名>/<简述>` 分支开发，禁止直接 push `main`。
- 例：`feature/deepseek-harness/add-sbr05`、`feature/opencode/fix-type`.

### 2.2 提交前自检
- 本地跑 `python scripts/ci_check.py`，**ERROR 必须清零**（编码 GBK/UTF8、R1 英文标识符、魔法数字）。
- `git status`/`git diff` 核对只含预期文件；**绝不提交密钥/凭证/生成物**（`设备模型库/output/`、`*.db`、`__pycache__`、`*.pyc` 已 gitignore）。
- 提交信息遵循 `CHANGELOG.md` 风格：`[版本] 日期 — 变更摘要`。

### 2.3 PR 流程
1. push 分支 → 新建 PR（目标 `main`）。
2. CI 自动跑 `ci_check.py`，不合格自动拦截。
3. 合并前至少经 1 个其他 harness 或人工审查：表↔代码符号一致性、类型一致性、互锁/锁存/握手/超时/显式切断齐全。

### 2.4 冲突与交接
- 冲突时优先 rebase 到最新 `main`，解决后重跑 CI。
- **任务交接**：完成一项工作后，更新 `CHANGELOG.md` 并留一条 `git commit`/PR 描述说明"做了什么、下一步谁做什么"。
- 架构级变更（轴控实体、变量表分类）属高风险，合并前须在 `CHANGELOG.md` 留档并确认。

---

## 三、本 agent（opencode）独有交流内容

> 供其他 harness 读取，了解 opencode 的定位、能力与期望，以正确协作。

### 3.1 我是谁
- **名称**：`opencode`
- **驱动模型**：`deepseek-v4-flash`
- **在本仓库的角色**：PLC ST 编程规范执行者 + 设备模型库代码生成系统维护者 + CI 审查脚本作者。

### 3.2 我的能力（可直接调用/配合）
- **PLC 工程**：严格按 `AGENTS.md` R1~R4 生成/审查 ST、变量表、FB、结构体；分层 SBR_00~08；编码（GBK CSV / UTF8 md）；字节级改文件（防 0 字节截断）。
- **代码生成系统**：`设备模型库/` 的 JSON 规格单 → SQLite → 表+ST 生成管线（`load_spec.py`/`generate_tables.py`/`generate_st.py`/`generate.py`/`review_st.py`）。
- **审查脚本**：`scripts/ci_check.py`（仓库 CI 门禁）、`设备模型库/scripts/review_st.py`。
- **知识沉淀**：维护 `CHANGELOG.md`、`汇川PLC_ST编程知识.md`、记忆 keeper。

### 3.3 我期望其他 harness 如何与我协作
- 需要我参与时，在 PR/Issue 中 **@opencode** 或留清晰任务描述。
- 涉及 PLC 变量表/FB/ST 改动，先跑 CI，并把表↔代码一致性、类型一致性纳入自检（这是我最看重的两点）。
- **不要**绕过 CI 直接改 `main`；架构级改动先经 `CHANGELOG.md` 确认。
- 与我沟通用中文注释、英文标识符（R1）。

### 3.4 我可贡献的接口
- **审查**：可代为跑 `ci_check.py` 与 `review_st.py`，输出合规报告。
- **生成**：可按 JSON 规格单生成整套 PLC 表+ST。
- **编码修复**：负责 GBK/UTF8、字节级安全改写。

---

## 四、其他 harness 接入步骤

1. 克隆：`git clone https://github.com/TReaur1/ELE.git && cd ELE`
2. 读契约：`AGENTS.md`、`CONTRIBUTING.md`、本 skill。
3. 建分支：`git checkout -b feature/<你的agent名>/<简述> main`
4. 开发 → 本地 `python scripts/ci_check.py` 清零 → 提交（CHANGELOG 风格）→ push → 建 PR。
5. 合并后在 PR 里更新交接说明。

---

## 五、交流约定（Issue / PR 留言）

- 每条 PR/Issue 顶部写清：**目标 / 改动范围 / 影响面 / 是否需 opencode 复核**。
- 冲突或审查意见用引用格式标注，结论写明"已确认/待定/否决"。
- 交接信息写入 `CHANGELOG.md`，勿只放在对话里。
