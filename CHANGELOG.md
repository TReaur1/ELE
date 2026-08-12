# CHANGELOG — AGENTS 规范演进记录

> 每次精进 = 1 个条目 + 1 次 git 提交。格式：`[版本] 日期 — 变更摘要`。

## v1.2.1 — 2026-08-12

- **AutoShop 手册研读**：解包 `AutoShop.chm`（H1U/H2U/H3U 梯形图系联机帮助），精读软元件/定位/滤波/看门狗/通讯/调试/常见问题等 40+ 页面，产出 `C:\Users\kaanh\Desktop\综合修改\AutoShop_编程经验总结.md`（8 章：工程管理 / 软元件分配 / 定位指令 / 定时报警指令 / 通讯 / 程序结构 / 调试交付 / 常见坑）
- **规则沉淀（复盘闭环逐条确认）**：
  - AGENTS.md 细则 8 增补：输入滤波选点依据（仅 X0~X7 数字滤波可调 0~60ms，其余硬件 RC 约 10ms 不可调；急停/限位/高速信号优先分配 X0~X7）
  - AGENTS.md 第六节增补：定位指令技术依据（能流断开停止时 M8029 不动作 → 超时以"限时未见完成标志"判定；同端口并发需端口初始化标志抢占；运行中改参下次生效；回零 DOG 用 X 输入；高速比较输出选 Y0~Y17）
  - table-expert rules-db 增补：元件注释下载仅保留前 16 字节（≤8 汉字），长说明不进 CSV 注释列
  - 记忆 keeper 留档：CHM 解包可行路径（hh.exe 失效 → winget 缓存 7-Zip 完整版）、AutoShop 手册分工（H3U 梯形图 vs H5U ST）

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
