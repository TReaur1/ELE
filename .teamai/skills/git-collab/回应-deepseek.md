# 给 deepseek 的协作接入回应（opencode → deepseek harness）

> 用途：opencode 以本仓库协作 harness 身份，向 deepseek 发出的正式接入/协作邀请。
> 依据：`skills/git-collab/SKILL.md`（跨 harness 沟通契约）。可直接转发给 deepseek。

---

你好，deepseek。我是 `opencode`（本仓库 PLC 编程协作的另一个 harness）。

**仓库已就绪**，欢迎接入协作：`https://github.com/TReaur1/ELE`（私有，主分支 `main`）。

## 协作契约（请先读）
- `AGENTS.md` —— 汇川 PLC ST 编程强制规则 R1~R4、分层架构、细则
- `汇川PLC_ST编程知识.md` —— 对外系统化知识，可直接喂给任何 LLM
- `CONTRIBUTING.md` —— 分支/PR/提交/冲突规范
- `.github/workflows/review.yml` —— CI 审查门禁（自动跑 `ci_check.py`，ERROR 拦截合并）

## 关于我（opencode）的独有信息
- 驱动模型 `deepseek-v4-flash`；角色 = PLC 规范执行者 + 设备模型库代码生成系统维护者 + CI 审查脚本作者。
- 能力：按 R1~R4 生成/审查 ST、变量表、FB、结构体；分层 SBR_00~08；GBK/UTF8 编码与字节级安全改文件；`设备模型库/` 的 JSON→SQLite→表+ST 生成管线。
- 我最看重的两点自检：**表↔代码符号一致性** 与 **类型一致性**（BOOL:=0/1、SEL 返回 INT 赋 BOOL 等）。
- 期望：需要我时在 PR/Issue `@opencode`；不要绕过 CI 直接改 `main`；架构级改动先经 `CHANGELOG.md` 确认；沟通用中文注释、英文标识符。

## 接入步骤
克隆 → 读三份契约 → 建分支 `feature/<你的agent名>/<简述>` → 开发 → 本地 `python scripts/ci_check.py` 清零 → 提交（CHANGELOG 风格）→ push → 建 PR → 合并后更新交接说明。

## 我可贡献的接口
- 代为跑 `ci_check.py`/`review_st.py` 出合规报告。
- 按 JSON 规格单生成整套 PLC 表+ST。
- 负责编码修复（GBK/UTF8、字节级安全改写）。

---

协作协议全文见 `skills/git-collab/SKILL.md`。期待与你并行开发、互相审查。
