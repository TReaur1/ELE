# CHANGELOG — AGENTS 规范演进记录

> 每次精进 = 1 个条目 + 1 次 git 提交。格式：`[版本] 日期 — 变更摘要`。

## v1.8.0 — 2026-09-04

- **无线上位机链路延迟适应范例（待用户评测）：无线段容忍不确定 + 有线段利用确定**：
  - **超时分层**：`TIMEOUT_CMD_HANDSHAKE` 5000→15000ms（含无线上行网络段，注释标明须≥2×轴超时）；`TIMEOUT_AXIS_MOVE` 注释标明"纯设备有线域，不含网络"——命令路径与执行路径的超时预算分开。
  - **命令防重放**：通讯表新增 `host_Send_CmdSeq` 序号寄存器，PLC 记忆 `con_LastCmdSeq`，同序号重发不二次触发（无线网络重发/乱序防护）；host_driven 在 SBR_06 握手 Cmd 门控，internal_seq 在 SBR_04 对 Start/Home 门控；**停止命令永不拦截**。
  - **命令回执状态字**：host_driven 每轴新增 `host_Rcv_*_CmdState`（CMDST_ 常量 0空闲/2执行中/3完成/4超时，超时保持至下条命令），上位机收到回执前不得认为命令已生效。
  - **看门狗三级降级**：SBR_03 实装出向心跳（`HEART_PERIOD` 周期 TONR 翻转自增，**修正原模板"回显入向"违反细则9**）+ 入向双阈值看门狗——`WATCHDOG_DEGRADED`(1000ms) 降级：冻结新命令受理、已锁存动作继续完成（容忍无线漫游/抖动）；`WATCHDOG_TIMEOUT`(3000ms) 失联：con_CommLost→RunOK=0→显式安全切断。
  - **配套**：三份 spec 统一 13→17 常量（新增 WATCHDOG_DEGRADED/HEART_PERIOD/CMDST_*）；demo_seq 补齐入/出向心跳寄存器；con 表新增 con_Heart_Prev/con_CommDegraded/con_LastCmdSeq/con_HeartQ/con_HeartRst(D2022~26)。
  - **验证**：三工程 generate.py 全过、verify_counts/consistency OK、ci_check 错误 0。

## v1.7.0 — 2026-09-04

- **定位指令超时判定全面实施（worklog 任务#11 修复建议①~④落地，ZCode 编排器执行）**：
  - **①FB_EtherCAT_Axis_ST 超时接口**：新增 `Timeout(DINT)` 输入与 `Absolute_Expired(BOOL)` 输出——TON 内部监视，`Absolute_Execute` 启动沿清并起计时，Done/CommandAborted 复位，限时未完成置 Expired；FB 变量表同步 5 行；SBR_07 调用传 `TIMEOUT_AXIS_MOVE`（常量从"声明未用"变实际引用）。
  - **②host_driven 命令握手**：SBR_06 电平直驱改为每伺服 `FB_CmdHandshake` 握手锁存（`Cmd := host_Send_*_Start = 1` 显式比较消除 INT/BOOL 隐式转换；Done=状态机反馈；Timeout=TIMEOUT_CMD_HANDSHAKE；Abort=NOT con_AutoEnable），Expired→超时源；inst 表自动生成每轴 `Handshake_*` 行。
  - **③internal_seq 步机超时转移**：工步内 `TONR` 直调超时检测（IN=Execute AND NOT Done，PT=TIMEOUT_AXIS_MOVE，**R=NOT Execute 防保持型 ET 累积跨启动误报**），Q→超时源；修正失实注释 TIMEOUT_STEPPER→TIMEOUT_AXIS_MOVE。
  - **④SBR_03 锁存闭环**：空白占位改为 `Latch_Timeout(FB_AlarmLatch)` 锁存 → `con_TimeoutAlarm` → `con_ErrorID OR/AND NOT ERRID_TIMEOUT`（复位后跟随锁存清除）→ `con_ErrorBit` → `con_RunOK` 联锁；inst 表全原型补 `Latch_Timeout` 行。
  - **配套**：demo_seq.json 补齐 6 个缺失常量（与 virtual/seq 对齐）；新增 con 变量 `con_TimeoutReq`(D2020)/`con_AlarmReset`(D2021)/`con_TimeoutQ`(internal_seq 扩展)。
  - **验证**：三工程 `generate.py` 全过（review_st 无硬伤）、verify_counts/verify_consistency OK、ci_check 错误 0；遗留：con_AlarmReset 复位源待接 HMI/本地按钮，SBR_host 看门狗待实施。

## v1.6.0 — 2026-09-04

- **协作结构升级为编排者-执行者模式（collab-relay v1.1），ZCode 任编排器**：
  - relay：tasks 表新增 `role`（生成/审查/测试，空=不限）与验收字段（review/review_note/reviewed_by/reviewed_at），旧库 ALTER 幂等迁移；查询改显式列名（兼容新旧库列序差异）；新增 `POST /task/review` 编排器验收端点——approved 归档 / rejected 打回（任务自动回 open，保留驳回意见）。
  - agent_daemon：新增 `--roles 逗号列表` 角色过滤（只认领匹配任务）；被驳回任务重新认领时执行提示词自动附 review_note 驳回意见，针对性返工。
  - mcp_tools：新增 `review_task` 工具；create_task 支持 role；工具总数 12。
  - 契约更新：`skills/git-collab/SKILL.md` 新增第七节（编排者-执行者模式）；`实时协作协议.md` 升 v1.1（任务生命周期含 review 环节，complete ≠ 关闭，须编排器验收；验收不替代 PR/CI 门禁）。
  - 测试：test_all 新增 3.5 编排器验收段 8 项断言（驳回→回 open→重认领→返工→验收归档→幂等→role 字段），test_all / test_daemon / ci_check 全部通过。

## v1.5.0 — 2026-08-27

- **新增点动控制（预留，暂不使用，全部注释掉）**：触摸屏点动辊筒(正/反转)、触摸屏点动气缸(升/降)、手动按钮点动辊筒。
  - 新建 hmi 变量表：`hmi_JogRollerFwd/Rev`、`hmi_JogCylUp/Dn`（触摸屏点动按钮）。
  - io 表预留手动按钮点动辊筒输入：`in_JogRollerFwd`(X10)、`in_JogRollerRev`(X11)（本体 X0~X7 已满，需扩展输入模块，暂不接线）。
  - con 表加 `bJogActive`（点动激活标志）。
  - SBR_con 段9：完整点动逻辑体（按下转/松开停、正反转互斥、气缸点动得电升/失电降），**整段块注释包裹**，附 4 处启用步骤（host 清命令豁免、con 强制失电豁免、Roller Enable 门控、段7 输出门控 + SBR_io 补映射）。
  - 点动仅手动位生效（NOT bRemoteEn），自动位忽略点动输入，不与上位机命令冲突。
  - 变量总表.xlsx 增 hmi sheet。

## v1.4.9 — 2026-08-27

- **电磁阀更正为二位五通单电控（用户指正）**：原按双线圈（Y5 升 / Y6 降）设计，实际为**单线圈**——得电=升(伸出)，失电=弹簧复位降(退回)，无自保持，升位须持续得电维持。
  - io 表：`out_CylUp`→`out_CylValve`(Y5 单电控线圈)，删除 `out_CylDn`(Y6)；软元件 Y6 释放。
  - con 表：`bCylUpOn`→`bCylValveOn`(阀线圈输出状态 得电=升/失电=降)，删除 `bCylDnOn`；`con_CylCmd` 注释更新(1=升得电保持/2=降失电弹簧回)。
  - SBR_con 段4 重写为单电控逻辑：命令→阀状态锁存，升得电保持至降命令，降失电弹簧复位；到位判定+悬挂超时保留(升看X6/降看X7)。
  - SBR_con 段7：`out_CylValve := bCylValveOn`；SBR_io：Y5:=out_CylValve 删 Y6 映射；SBR_host 急停注销块补 `bCylValveOn:=FALSE`。
  - 同步：采集表 03/04、SBR_00 文档、通讯字表(.csv/.xlsx)、工程解读.md、变量总表.xlsx。
  - 校验：ci_check 0 ERROR，残留扫描无 `out_CylUp/out_CylDn/bCylUpOn/bCylDnOn/Y6/双电控`。

## v1.4.8 — 2026-08-27

- **新增急停命令注销功能（用户指出缺失）**：急停按下时仅切断输出是不够的——记忆中的命令(bRollerRun/con_CylCmd/con_SpeedTarget 等)仍在, 释放复位后旧命令会自恢复引发危险。
  - 控制层置 `con_EstopActive := bEstopPressed OR Latch_Estop.AlarmOut`(已入 con 变量表)。
  - 通讯层新增**段2.5 急停命令注销**块(命令处理前): 强制清零 `bRollerRun/bRollerRev/con_CylCmd/bCylPos/con_SpeedTarget` 并拒绝一切入向命令字(清0回执)。
  - 段3/段4/段7/段8 均加 `NOT con_EstopActive` 门控; 速度命令原无条件赋值改为受门控(修复漏清)。
- AGENTS.md 细则13 补强: 急停活跃须主动清零全部命令记忆, 不能仅靠 bRemoteEn 门控输出的隐式副作用。
- 工程解读.md 补充急停命令注销关键说明。

## v1.4.7 — 2026-08-27

- **变量表整理（可读性/美观）**：5 张表（io/const/con/host/功能块实例）统一注释模板——功能短语+括号补充、单位统一 (ms)/(1RPM)、取值统一 `0=x/1=y`、去 const 表冗余"常量"尾字；con 表按 7 功能组重排（安全许可→模式复位→心跳通讯→气缸超时→阀命令→辊筒CLR→速度RTU），序号重编。
- **功能块实例表**：主行编号 1~8，成员行序号留空（贴近汇川 FB 基准风格，主/成员视觉区分）。
- **新增变量总表.xlsx**：5 sheet 分组色带+冻结首行+列宽适配+关键列居中，作为美观可读载体；CSV 保持导入纯度（GBK+CRLF）不变。
- 校验：ci_check 0 ERROR；变量名集合与整理前逐表一致（零丢失）。

## v1.4.6 — 2026-08-27

- **DINT→INT 隐式赋值修正**（用户指正）：`host_Rcv_AlarmWord := con_AlarmWord` 类型不符（DINT 报警字 → INT 通讯字，LiteST 严格类型检查禁隐式转换）；SBR_status 改为 `TO_INT(con_AlarmWord)` 显式转换并注明位宽约束。
- AGENTS.md 报警机制第 3 环补强：报警位定义限于 bit0~15（上位机寄存器 16 位宽度），status 层回写须 TO_INT 显式转换；con 表注释同步。

## v1.4.5 — 2026-08-27

- **LiteST 位运算字面量规则**（用户指正）：`OR/AND/XOR` 整型位运算的操作数字面量**仅支持非十进制格式**（2#/8#/16#），十进制裸数字不合规；位编码一律写二进制 `2#`（bit 位置直观）。
  - SBR_con 报警字汇编修正：`OR 1/2/4` → `OR 2#0001 / 2#0010 / 2#0100`（注释位定义同步）
  - AGENTS.md R4 新增条款固化；BOOL 逻辑运算不受限
  - ci_check 新增 `check_bitop_literal` 拦截（正/负向验证通过）
  - keeper 记忆 LRN-20260827-001（汇川 LiteST 限制系列）

## v1.4.4 — 2026-08-27

- **AGENTS.md 写入架构设定**：第三节重构为四模块架构定稿（io 物理层/con 控制层/host 通讯层/status 状态层，模块职责表+扫描顺序+层间依赖规则），并新增**报警机制六环闭环强制条款**（报警源检测→锁存→con_AlarmWord 位编码汇编→bRunOK:=报警字为零唯一真源→呈现→复位）。
- **辊筒工程报警机制落地**（按新条款实施）：
  - con 表 +`con_AlarmWord:DINT`（bit0 急停/bit1 气缸超时/bit2 通讯断讯，预留 bit3+ 驱动器故障）
  - SBR_con 段1 末尾报警字汇编替代原三条件与式，`bRunOK := (con_AlarmWord = 0)` 成为运行许可唯一真源
  - host 表 +`host_Rcv_AlarmWord:D13`；通讯字表 +报警字行(40014/offset13)；SBR_status 回写；06_报警参数 +位定义 3 行；通讯字表.xlsx 重生成成功
  - 工程解读.md 第二节读区扩至 0~13、第五节新增"报警字：一根总线管全部报警"（位定义表+新增报警扩展路径）
- 验证：CI 0 ERROR、变量一致性全过（新增符号均有户口）。

## v1.4.3 — 2026-08-27

- **SBR 四模块架构重组**（用户指令：整理为 io/con/host/Status 四部分）：
  - 旧 8 个 SBR（02 IO映射/03 安全/04 模式/05 执行/06 自动/07 输出刷新/host 上位机/rtu RS485）→ 新 4 模块：`SBR_io`(物理层纯透射映射 X→in_* / out_*→Y)、`SBR_con`(控制层: 安全锁存/模式/bRemoteEn/阀看门狗/CLR脉冲/Roller FB/控制类输出)、`SBR_host`(通讯层: 入向心跳看门狗/出向心跳/TCP命令/RTU速度转发)、`SBR_status`(状态层: 三色灯FB/指示类输出/host_Rcv_*回写)
  - 主调度顺序 io→con→host→status（逻辑层安全最先、状态呈现最后；命令触发式晚一周期消费无碍；输出映像透传上周期门控结果）
  - **零遗漏证明**：脚本比对旧 8 文件全部有效语句 100% 存在于新 4 模块、无新增语句（纯结构重组零逻辑变化）；注释配对/变量一致性/CI 全过
  - SBR_00 文档块重写（纠旧点位 Y0~Y2/旧寄存器 8192·H2000·0.01Hz 残留，对齐四模块）
  - 工程解读.md 同步：四模块分层图+类比表、映射链四环指向新文件、信号流图、速查卡、练习引用

## v1.4.2 — 2026-08-26

- **辊筒映射控制链显式化 + 门控缺陷修复**（用户审查发现"缺少 PLC 映射控制辊筒部分"）：
  - 实质缺陷：SBR_host 辊筒正/反转/停止命令处理**未包 bRemoteEn 门控**——非自动位时命令被"消费回执但不执行"；已重构为 `IF bRemoteEn THEN 接单 ELSE 清运行记忆量+拒单清回执 END_IF`，并保留"许可丢失清记忆量"语义（防切回自动位辊筒自恢复）
  - SBR_07 头注释补完整四环映射链说明：host命令字(D20~D22) →①SBR_host→ bRollerRun/bRollerRev →②FB调用→ FwdOut/RevOut →③bRemoteEn门控→ out_RollerFwd/Rev →④输出映像→ Y10/Y11
  - 工程解读.md 第三节新增「PLC 内部映射链」小节：四环对照表(环/变量/所在文件) + 映射链 mermaid 图

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
