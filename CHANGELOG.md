# CHANGELOG — AGENTS 规范演进记录

> 每次精进 = 1 个条目 + 1 次 git 提交。格式：`[版本] 日期 — 变更摘要`。

## v1.4.1 — 2026-08-26

- **工程解读生成器落地**（project-explainer skill 重构）：由"互动陪读"改为**纯静态文档生成器**，伴随每个 PLC 工程交付自动生成《工程解读.md》；内置六节权威模板（是什么/设备点位/信号流/程序结构/安全逻辑反例驱动/动手实操 + 速查卡 + 附录自测题）、初级电气适配原则（类比先行/术语随给/不贴长码）、事实溯源与交叉校验规则。
- **首份产物**：`辊筒上位机工程\工程解读.md`——面向初级电气人员，含设备连接图/信号流图/程序分层图三张 Mermaid、3 道自测题、速查卡；技术事实全部对齐 C20 混合模式现状。
- **连带纠偏（术语更正漏网之鱼）**：`host_Send_InvReset`→`host_Send_DrvReset`（host 表+SBR_host）；通讯字表速度行 0.01Hz/0~5000 → **1RPM/0~3000(2001H)**；采集表06 DRV_SPD_REG 8192/H2000 → **8193/H2001**；通讯字表.xlsx 待办公软件释放后重生成（CSV 已为准）。

## v1.4.0 — 2026-08-26

- **ST程序包生成体系落地**：采集表范本（6 张中文列 CSV，grill-me 四阶段决策：双用途/CSV→JSON 转换/空范本+examples/fail-fast）+ examples/滚筒阻挡 实例；首例实战交付 **辊筒上位机工程**（采集表范例+变量表+FB 文件夹+SBR_00~08+SBR_host/SBR_rtu+通讯字表 CSV/XLSX）。
- **C20-400HR 直流无刷驱动器接入**（非变频器）：端子 FWD/REV 启停(Y10/Y11) + CLR 复位脉冲(Y12) + RS485 仅速度给定（2001H，0~3000 RPM）；MB_Master 混合模式（F00.01=1/F00.02=3）；传感器 X3~X7 接入，阀控制升级为输出保持至磁开到位+超时锁存闭环；SEL 表达式实参经变量中转（LiteST 指令实参限制 LRN-20260826-001）。
- **三大强制规则全局变更**（AGENTS.md 固化 + ci_check 拦截 + 负向验证）：
  - FB 交付形式：每 FB 一文件夹（变量表 CSV 上方声明 / 纯逻辑 ST 下方，禁 VAR 声明块）；第五张桌面基准 汇川规范FB变量表.csv
  - TONR 直调：禁命名实例；节拍自翻转/看门狗单点合并两模式
  - IO 显式映像：SBR_02 输入映像 + SBR_07 输出映像为地址对照唯一真源
- **ci_check 审计增强**：CSV 列数一致性、通讯字表专项与 host 表一致性、FB 形式违规、TONR 命名实例拦截（均负向验证）
- **记忆沉淀**：LRN-20260824-001（通讯字表规则）、20260825-001~003、20260826-001~004（LiteST 实参限制/C20 要点/三大规则/工作流范式）；cloud_brain 工程实体
- **协作基建**（v1.3.x 期间）：collab-relay 四通道实时协作中心、agent_daemon 后台常驻、SSH over 443 推送通道、DSH 对接完成

## v1.3.1 — 2026-08-14

- **DSH 自动回复打通（headless 挂 preset）**：headless profile `cordis.patch.yml` 插入 `agent-presets`（default=electrical-assistant）；`dsh-headless` 包 runner setup 打补丁（`lib/index.js`，备份 `.bak-ele`）在创建 agent 时 `presets.mount(agentCtx, $DSH_HEADLESS_PRESET ?? defaultId)`。实测：headless 回答汇川 R1 问题正确（标识符仅英文），persona 生效（主动写 worklog.md），MCP 正常拉起。注意：npm 包补丁在 DSH 升级时会被覆盖，需重新应用。
- **DSH 完成 SSH 通道对接**：公钥已加 GitHub（人工完成），remote 切 `git@github.com:TReaur1/ELE.git`，`ls-remote`/push 验证通过。
- **DSH 后台守护运行**：`agent_daemon.py --mode notify --agent DSH`（修复版带 30s 心跳）常驻，消息/任务落盘 `collab/inbox_DSH.md`。

## v1.3.0 — 2026-08-14

- **多 Agent 实时协作中心（collab-relay）**：新增 `collab/`（纯标准库，同机 localhost:8790）——消息（@定向/广播+长轮询 25s）、状态（心跳 60s 判离线）、任务（open→claim→done 认领互斥）、git 代理四通道；`mcp_tools.py` 暴露 11 个 MCP 工具（opencode.json 已注册）。
- **后台常驻响应（agent_daemon）**：notify（消息/任务落盘 inbox）与 auto（认领→执行→完成→广播）双模式；心跳修复为 30s 周期上报；test_daemon 僵尸进程清理。
- **git 推送通道**：HTTPS 443 间歇性阻断 → 生成 SSH 密钥 + `~/.ssh/config`（ssh.github.com:443），remote 切换 SSH 推送（稳定）。
- **唤醒信号约定（协议 7.1）**：topic=wake / 新建 assignee 任务 / blocked 求救三种触发落 inbox。
- **relay 协作闭环（与 DSH 实时协作）**：处理 DSH 接入确认、watcher 设计议题（=agent_daemon notify，已落地）、auto 回复探索（headless 无 preset 硬伤 → notify 默认 + run-cmd 可挂 preset）；任务 #1/#2 完成。
- 记忆 keeper 经验（LRN-20260814-003~008）继续生效：字节级改文件、编码识别、审查正则、表↔代码一致性、双份同步。
- **经验沉淀（9 条，keeper LRN-20260814-009~017）**：SSH over 443 稳定通道 / PowerShell 后台用 subprocess / SQLite 保留字列名 / 守护短轮询 wait=0 / 周期心跳 / 测试子进程全清理 / auto 回复受 preset 限制 / 多 agent 协作标准模式 / detached HEAD 陷阱。
- **agent_daemon 工程加固（auto 链路实测）**：`_run` 改列表参数（shlex 拆分 + `shutil.which` 解析 .cmd，避免 cmd shell 中文乱码）+ `--workdir` 参数 + 超时后 `taskkill /T` 清理 dsh 进程树；test_daemon 回归 ALL PASS。
- **实测发现（并发冲突根因）**：DSH 与 opencode 同时以 auto 模式跑 `dsh --profile headless` 时，多个 dsh 实例并发争抢 MCP（cloud_brain/Obsidian）资源互相卡死（任务超时 180s 未完成，单实例 29s 可完成）。结论：**auto 模式全局同时只允许一个实例执行 dsh**（任务认领互斥只防任务重复，不防 dsh 进程并发）；测试协调已广播，DSH 独占验证中。

## v1.2.2 — 2026-08-14

- **new plc 工程优化并同步原程序**：`C:\Users\kaanh\Desktop\new plc` AGV 输送线项目按 AGENTS 规则优化产出 `优化\` 副本（5 表 + 5 SBR + 常量/实例表），并将改名（`in_Rest→in_Reset`、`host_Rcv_Rest→host_Rcv_Reset`、`hmi_*Volecity→Velocity`、`BlockUP→BlockUp`）与类型修复（`mc_Lift*Execute := 0/1 → TRUE/FALSE`）以**字节级替换**同步回原程序。
- **事故与恢复**：首轮"解码→重写"脚本使 `sbr_host.md` 截断为 0 字节；通过 gb18030 逆向编码（`encode('gbk')` 还原被误解码的 UTF8 字节、处理 .NET 解码产生的 PUA 字符）完整恢复。
- **经验复盘（用户确认全项）**：
  - 就地改 GBK/UTF8 原文件**禁止解码重写**（`open('wb')` 先截断、编码失败即丢数据），必须字节级 `.replace()`
  - 操作前确认每文件实际编码（.md 可能 UTF8、CSV 可能 GBK），勿按扩展名想当然
  - GBK 误解码的 UTF8 备份可用 gb18030 逆向还原（处理 PUA）
  - 审查脚本注释正则须 `(\(\*[\s\S]*?\*\)|//[^\n]*)`（禁 `//.*`+re.S），并加 BOOL:=0/1、SEL() 返回 INT 的类型一致性硬检查（已内置 `设备模型库/scripts/review_st.py` 与 new plc 审查脚本）
  - 审查应覆盖"表↔代码符号一致性"，不止查新增符号（本次发现 host 表 Rest vs 代码 Reset、BlockUP vs BlockUp 的项目自身不一致）
  - 双份（原程序/优化副本）修改须两边同步 + 旧名残留检查
- **注**：6 条经验已全部补录记忆 keeper（LRN-20260814-003~008）。**keeper deposit 修复**：根因=fastembed 模型权重缺失（blobs 空、HF/国内镜像均不可达，download 卡住导致 MCP deposit 超时）；对策=config `embed_backend` 降级为 `lexical`（无 BOM），经验经 CLI deposit 写入成功；MCP server 进程缓存旧 fastembed 状态，需重启 opencode/MCP 后 deposit 完全恢复。

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
