# 多智能体协作规范（Contributing）

本仓库由多个智能体（Agent）经 GitHub 协作开发。请遵守以下规范，保证互不干扰、可审查、可回滚。

## 分支规范
- **主分支 `main`**：唯一受保护分支，合并入口。禁止直接 push。
- **开发分支**：每个 Agent 使用独立分支，命名 `feature/<agent名>/<简述>`（如 `feature/deepseek-harness/add-sbr05`）。
- 同步主分支：定期 `git pull origin main` 并入最新。

## PR 流程
1. 在 `feature/<agent名>/...` 分支完成开发并本地跑审查：`python scripts/ci_check.py`（通过后再提交）。
2. 推送分支 → 新建 Pull Request（目标 `main`）。
3. **CI 门禁**：`.github/workflows/review.yml` 会自动跑 PLC 规范审查（编码 / R1 英文标识符 / 魔法数字），**不合格（ERROR）自动拦截合并**。
4. 合并前须至少经 1 个其他 Agent 或人工审查（表↔代码符号一致性、类型一致性、互锁/锁存/握手/超时/显式切断齐全）。

## 提交规范
- 一次提交一个逻辑单元；信息遵循 `CHANGELOG.md` 风格：`[版本] 日期 — 变更摘要`。
- 提交前跑 `git status`/`git diff` 核对只含预期文件，**绝不提交密钥/凭证**。
- 每个精进 = 1 条 `CHANGELOG.md` 条目 + 1 次提交（见 AGENTS.md 第九节复盘闭环）。

## 编码 / 格式红线
- CSV 用 GBK、`.md`/`.st` 用 UTF8（无 BOM）；行尾 CRLF。
- 标识符仅英文（R1）、注释中文；结构体/常量/实例声明位置符合 AGENTS.md R2~R4。
- 就地改 GBK/UTF8 原文件用**字节级替换**，绝不解码重写（防 0 字节截断）。

## 冲突处理
- 与主分支冲突时：优先 rebase 到最新 `main` 解决；解决后重新跑 CI 审查。
- 大范围重构（轴控实体、变量表分类）属架构级变更，合并前先在 CHANGELOG 留档并确认。

> 详细编程规则见 `AGENTS.md`；对外知识见 `汇川PLC_ST编程知识.md`。
