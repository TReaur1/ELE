# CHANGELOG — AGENTS 规范演进记录

> 每次精进 = 1 个条目 + 1 次 git 提交。格式：`[版本] 日期 — 变更摘要`。

## v1.2.0 — 2026-08-12

- **制表交付**：新增 `Tables/` 全套交付（变量表 5 类 + FB 表 7 + 结构体表 3，英文命名 / GBK / 注释齐全）+ `优化报告.md` + `StructureInstances_AxisHandles.st`
- **优化落地**：通讯看门狗修复（心跳寄存器分离）、超时故障接入锁存、死代码清理、DWORD→DINT、CSV 含逗号注释加引号
- **规则沉淀（复盘闭环确认）**：
  - AGENTS.md R4 增补：汇川结构体/变量表禁止 DWORD，统一 DINT
  - AGENTS.md 细则 2/9 增补：故障检测必须接入锁存闭环；心跳寄存器入/出向分离
  - table-expert rules-db 增补：CSV 含逗号字段引号、FB 表列对齐校验
  - 记忆 keeper 留档：实例声明位置决策史（CSV→ST→CSV）、D/S 地址复用

## v1.0.0 — 2026-08-11

- 基线建立：AGENTS.md（PLC ST 编程规则，综合复用模板）+ opencode.json 首次提交
- 拆分文件架构：新增 `AGENTS.drawing.md`（阶段2 绘图占位）、`AGENTS.selection.md`（阶段3 选型占位）
- 新增复盘-精进闭环章节（AGENTS.md 第九节）：工程实践后触发 → 逐条询问确认 → 落盘 → 记录
- 制表规则去重：第八节细则移交 `table-expert` skill，AGENTS.md 保留引用
- 新增 `.gitignore`（.ai-memory / node_modules / 日志等）
