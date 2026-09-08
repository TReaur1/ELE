# 汇川 PLC ST 编程知识体系（Inovance AutoShop / ST 语言）

> 用途：供 deepseek-harness 等外部 Agent 系统化学习"汇川 PLC ST 工程"全链路知识。
> 来源：AGENTS.md 综合复用模板 + 记忆 keeper 24 条经验（LRN-20260812~20260814）+ 设备模型库实践经验。
> 更新时间：2026-08-14

---

## 一、领域与工具链

- 对象：汇川 PLC，AutoShop 开发环境，ST 语言（LiteST 语法）。
- 权威手册：`C:\Inovance Control\AutoShop\Manual\H5U&Easy_Manual\`（H5U&Easy 编程手册 894 页 + 指令手册 1037 页，覆盖 MC/ENC/轴指令）。`AutoShop.chm` 仅为 H1U/H2U/H3U 梯形图系（无 ST）。
- H5U 默认 IP = 192.168.1.88。
- 扫描周期：看门狗 100ms~30000ms；EtherCAT 任务周期 1000~10000us，最高优先级可抢占其他任务。

## 二、核心强制规则（R1~R4）

### R1 标识符仅英文
变量 / FB / 结构体 / 常量 / 实例名只用英文字母、数字、下划线；禁中文、拼音、中英混排。注释、变量表"注释"列、文档说明用中文。

### R2 变量声明边界
- PROGRAM 内**零声明**（无标量 / 结构体 / 定时器 / 边沿检测）；这些集中定义在各变量表。
- FB 实例、TON、R_TRIG / F_TRIG 在 `inst` 变量表逐行声明（每行一个实例，数据类型列填 FB 名 / `TON` / `TRIG.R_TRIG`；TON 展开 IN/PT/Q/ET 成员，PT/ET 为 DINT；R_TRIG 展开 CLK/Q/M），ST 中直接 `实例名(参数:=实参)` 调用，每个实例只在其所在 PROGRAM 内使用。
- 批量 FB 调用用"逐实例独立接口"模式：每个 FB 用独立 VAR_INPUT / VAR_OUTPUT 接口，内部状态（TON/R_TRIG）留在 FB 内部；不用"实参结构体 + 数组"模式（不建 ST_*Data 打包结构体、不用 VAR_IN_OUT 打包实参）。

### R3 结构体整合变量
- 功能相关的一组变量用 STRUCT 封装压缩变量表条目；结构体定义处须列出全部成员 + 每个成员中文注释；成员名符合 R1，前缀一致、按功能分组。
- 结构体类型定义放在**结构体表**（不在 SBR_00）；结构体实例在对应变量表（数据类型列 = 结构体名）；ST 中以 `实例名.成员` 访问。
- 结构体父变量（多成员实例，如轴组、步进组、汇川自带形式 `_sMCAXIS_INFO`、AxisControlData/AxisStatusData）不写入 CSV，写入对应 `.st` 文件并注释，由人工创建。

### R3b 轴控实体模式（EtherCAT 伺服专用）
- 适用边界：仅 EtherCAT 通讯伺服。脉冲步进仍用 `FB_StepperDrive + ST_Stepper`，不混用。
- 四层结构（每伺服一组）：命令实体 `M1_Cross_Cmd : AxisControlData`、状态实体 `M1_Cross_Status : AxisStatusData`（con 变量表）；FB 实例 `AxisControl_M1 : FB_EtherCAT_Axis_ST`（inst 表）；轴句柄 `Axis_M1_Cross : _sMCAXIS_INFO`（工程设备配置）。
- 结构体：
  - `AxisControlData`（命令）：PowerEnable / Stop / Reset / Home / JogForward / JogBackward / Jogvelocity / JogAcceleration / JogDeceleration / Absolute_Execute / Absolute_Position / Absolute_Velocity / Absolute_Acceleration / Absolute_Deceleration。
  - `AxisStatusData`（状态）：Power/Stop/Reset/Home/Jog/MoveAbsolute/MoveRelative/MoveVelocity/Halt 九子结构 + Position/Velocity/Torque/AxisState/Error/AxisErrorID/ReturnHomeDone 等标量。
- FB 封装：`FB_EtherCAT_Axis_ST` 内部直接调用厂商 `MC_Power/MC_Reset/MC_Stop/MC_Home/MC_JOG/MC_MoveAbsolute/MC_ReadStatus/MC_ReadAxisError`，**MC_* 厂商函数不改写**；接口 = Axis(IN_OUT) + 14 命令输入 → AxisStatusData(OUT) + Absolute_MoveAbsoluteDone(OUT)。
- 调用规范：先给命令实体赋值再调用实例：
  `AxisControl_M1(Axis := Axis_M1_Cross, PowerEnable := M1_Cross_Cmd.PowerEnable, ..., Absolute_MoveAbsoluteDone => M1_Cross_Status.MoveAbsolute.Done, AxisStatusData => M1_Cross_Status);`
  状态经状态实体回读，不另建中间变量。
- 命名注意：成员 `Jogvelocity`（小写 v）；回零完成用 `ReturnHomeDone`；状态机 AxisState（0断/1错误停/2停止中/3静止/4离散运动/5连续运动/6同步/7回零）；回零使能需 AxisState=3 静止。

### R4 类型约束
- 汇川**无 TIME 类型**：定时 / 延时 / 超时参数一律用 DINT（ms）或 REAL（s），禁止 `TIME` 与 `T#` 字面量（FB 接口参数同理）。
- 汇川结构体**不支持 DWORD，统一用 DINT**：位编码 / 故障码 / 状态字用 DINT（32 位有符号，≤0x7FFFFFFF 均容纳），如 `ErrorID : DINT`、`ERRID_* : DINT`。
- 结构体名即变量数据类型，须符合 R1（不以数字开头）；结构体名与成员名避免与全局变量重名。

## 三、命名规范

| 前缀 / 分类 | 含义 |
|---|---|
| `in_` / `out_` | 物理输入（滤波后）/ 物理输出 |
| `hmi_` | 触摸屏变量 |
| `host_` | 上位机变量（`_Send` 命令 / `_Rcv` 状态） |
| `con_` | 内部控制（锁存 / 许可 / 边沿 / 中间量） |
| `Mx_` | 伺服轴（命令结构 / 状态结构） |
| `Stepper_` | 步进控制块 |
| `AxisControl_` | 厂商轴控 FB 实例 |
| `db` 前缀 | 输入滤波实例（FB_Debounce） |
| `r` / `ton` 前缀 | 边沿检测 / 定时器实例 |

**类型前缀（结构体成员与 FB 内部变量）**：
| 前缀 | 数据类型 | 示例 |
|---|---|---|
| `b` | BOOL | bPowerOn / bHome |
| `f` | REAL | fActPosition |
| `d` | DINT | dSetPosition |
| `w` | WORD / INT | wPLCOpenState |
| `i` | INT | iHomeMethod |
| `s` | 子结构 | sConfig |

**急停语义**：`in_eStop=TRUE` 表示急停释放（安全）；`EstopPressed := NOT in_eStop`。

**子程序命名（小写前缀）**：`sbr_io / sbr_safety / sbr_mode / sbr_manual / sbr_auto / sbr_axis`。

## 四、分层架构 SBR_00~08

分层：IO 层 → 安全层 → 逻辑层（模式/手动/自动）→ 执行层（轴）→ 输出刷新。各层只读写全局变量表，互不直接调用。

| 程序块 | 内容 |
|---|---|
| SBR_00 | 数据类型与常量（doc-only 注释指向表） |
| SBR_01 | 通用 FB 库（7 个可复用 FB） |
| SBR_02 | IO 映射（滤波 + 映射） |
| SBR_03 | 安全回路（锁存 / 复位 / 许可 / 看门狗 / 三色灯） |
| SBR_04 | 模式管理（互斥 / 清零 / 切换检测） |
| SBR_05 | 手动控制（Jog / 步进 / 辊筒） |
| SBR_06 | 自动控制（握手 / 查表 / 定时 / 超时 / 反馈） |
| SBR_07 | 轴控制与输出（伺服 FB / 步进 FB / 辊筒 FB） |
| SBR_08 | 主调度（统一调用顺序） |

主调度调用顺序（main 中空括号无参、分号结尾）：
`sbr_io(); sbr_safety(); sbr_mode(); sbr_manual(); sbr_auto(); sbr_axis();`
安全回路 STEP1 最先执行，输出 STEP5 最后刷新；无许可时强制安全态。

## 五、通用 FB 库（SBR_01，禁止复制粘贴逻辑）

- `FB_Debounce` —— 输入滤波（仅内置滤波不足时的额外消抖，非默认 20ms 必配）。
- `FB_AlarmLatch` —— 故障锁存（边沿置位，故障消除 + 复位命令才清除）。
- `FB_CmdHandshake` —— 上位机命令握手（边沿锁存，完成 / 超时 / 中止复位）。
- `FB_TimedAction` —— 定时动作（边沿启动，定时 / 到位 / 限位终止）。
- `FB_StepperDrive` —— 步进驱动（手动 + 自动合并，正反转互锁，复位 / 停止输出）。
- `FB_Roller` —— 电辊筒（方向 / 速度档合并，三档 50/75/100%，速度档作输入参数）。
- `FB_TowerLight` —— 三色灯 + 蜂鸣（优先级 故障 > 自动 > 手动）。
- 可选：`FB_CommGuard` —— 通讯看门狗（心跳变化判断在线，超时置 CommLost）。

## 六、编程细则（18 条，15~18 为无线上位机链路适应 2026-09-04 定稿）

1. **安全优先**：安全回路最先执行、输出最后刷新；`RunOK` = 急停 OK 且无报警且通讯正常。
2. **故障锁存**：故障 SET / RESET；复位需"上升沿 + 故障源已消除"；检测结果必须接入锁存闭环（置位→锁存→ErrorID→运行许可），只置位不锁存 = 形同虚设。
3. **命令握手**：上位机命令经 FB_CmdHandshake 锁存，完成 / 超时才复位；避免电平命令被误当边沿。
4. **消除重复**：CASE + 数组 / 结构查表替代 IF/ELSIF 长链，FB 封装替代复制粘贴；同一逻辑只写一次。
5. **常量化**：加减速系数、超时、滤波时间、速度档位、轴状态字一律 CONST，禁硬编码魔法数字。
6. **边沿检测时序**：先读旧值→判断变化→后更新旧值（单扫描周期内一致）。
7. **互锁原则**：正反转 `AND NOT` 互斥且定优先级；模式互斥；三色灯用 ELSIF / 状态表互斥。
8. **输入滤波**：优先内置滤波（仅 X0~X7 数字滤波 0~60ms，其余硬件 RC 约 10ms）；急停不滤波、分配 X0~X7；安全 / 高速信号优先 X0~X7。
9. **通讯联锁**：Modbus TCP 断开→CommLost→RunOK=0→自动停；入向心跳（host→PLC，PLC 检测变化判在线）与出向心跳（PLC→host，PLC 自增）必须分离，不可复用同一寄存器。
10. **回零前置**：自动启动要求所有轴回零完成（`AxisStatusData.ReturnHomeDone` 或等价状态字）。
11. **定位超时**：MoveAbsolute 必须配超时，超时置报警防卡死。
12. **步进自动锁存**：自动挡步进输出用 FB_TimedAction 定时或限位终止，禁"单扫描脉冲"。
13. **显式安全切断**：无许可时输出显式复位，不依赖 ELSE 分支隐式默认。
14. **电机互锁时序**：方向与使能输出都经许可门控后再刷新到 Y 点。
15. **无线命令防重放**：无线上位机链路存在重发/乱序——每条命令携带递增序号（host_Send_CmdSeq），PLC 记忆最后受理序号（con_LastCmdSeq），同序号不二次触发；停止/急停类命令永不设防重放与降级门控；通讯恢复（con_CommLost 下降沿）时序号记忆清零，防上位机重启序号回绕导致命令被永久拒绝。
16. **命令回执状态字**：每命令通道提供 host_Rcv_*_CmdState（CMDST_ 常量：0空闲/2执行中/3完成/4超时，超时保持至下条命令）；上位机收到回执前不得认为命令已生效，禁止以"发送成功"作为执行依据。
17. **超时分层**：通讯域超时（命令握手、看门狗）与设备域超时（定位/动作）分开定值——通讯域含无线网络最坏延迟与抖动，须 ≥2× 设备域；设备域为纯有线确定域，按"最远行程/最低速度理论时间 ×1.5"校核。
18. **无线看门狗三级降级**：出向心跳独立周期自增（HEART_PERIOD，禁止回显入向心跳，否则看门狗失效）；入向心跳静默分级——降级（WATCHDOG_DEGRADED）：冻结新命令受理、已锁存动作继续完成；失联（WATCHDOG_TIMEOUT）：CommLost→RunOK=0→显式安全切断。

## 七、常见缺陷清单（15 条）+ 技术依据

**15 条缺陷**：
1. 自动步进单扫描脉冲漏动作
2. 故障未锁存导致复位无效
3. 模式被故障代码强行改写
4. 通讯无看门狗
5. 定位无超时
6. 回零未作自动前置条件
7. 急停 / 停止电平无锁存
8. 输入滤波时间过长（500ms）
9. 海量重复代码
10. 魔法数字散落
11. 正反转无集中互锁
12. 命名混乱 / 中英混排
13. 三色灯多 IF 顺序冲突
14. 位置号用散变量无法索引
15. Modbus 连接仅上屏不参与联锁

**技术依据（AutoShop 手册）**：
- 定位指令（DRVI/DRVA/PLSR）**能流断开即减速停止，且完成标志 M8029 不动作**；"停止"与"完成"分开判断，超时以"启动后限时未见完成标志"为准。
- 同端口定位指令并发 → 端口冲突、无脉冲输出；需"端口初始化标志"释放抢占。同一高速端口同一时刻只允许一条定位指令能流有效。
- 定位参数运行中修改**本次不生效、下次启动生效**——在线改参后必须重新触发指令。
- 回零 DOG 信号用 X 输入及时性最好（M/S 输入有延迟）。
- 高速比较输出（HSCS 等）选 Y0~Y17 立即输出，Y20 以后要等扫描结束才输出；同时驱动数量受限（H3U 系总计 ≤8 条）。

## 八、制表规则（汇川专用）

- 三种表头唯一基准 = 桌面 `C:\Users\kaanh\Desktop\汇川表` 内三个规范 CSV（列顺序不可调换、表头不可改名、末尾保留逗号）。
- 变量表：`序号,变量名,数据类型,隐藏初始值,初始值,掉电保持,网络公开,注释,软元件地址`。
- 结构体表：`序号,成员变量名,数据类型,注释`。
- FB 表：`序号,类别,名称,数据类型,隐藏初始值,初始值,掉电保持,注释`，类别仅 `IN / OUT / INOUT / VAR`。
- CSV 以 **GBK 编码**导入 AutoShop；序号从 1 递增；标识符仅英文（R1）；注释全中文。
- 数组：`类型[长度]`，多维 `类型[行,列]`；**0 基且索引 0 惯例留空**（4 轴声明为 `ST_AxisCmd[5]`、用 1..4）；代码中索引的变量必须按数组形式建表（数据类型列 = `Type[length]`），禁止标量。
- 结构体类型定义在**结构体表**（不在 SBR，SBR_00 仅作文档注释）；结构体实例在变量表（数据类型列 = 结构体名）。

## 九、通讯规则（Modbus TCP）

- 表格式：`服务器读写,通讯字名称[,变量名],Mobus地址,服务器地址,功能示意`。
- 语义：服务器读 = 状态（PLC→host，`host_Rcv_*`）；服务器写 = 命令（host→PLC，`host_Send_*`）。
- `Modbus 地址 = 40001 + 服务器偏移`。
- **REAL / DINT 占 2 个 16 位寄存器**：32 位项服务器偏移按 2 递增，否则相邻 32 位地址重叠（例：4 个 REAL 在 D24/D25/D26/D27 重叠 → 应 D24/D26/D28/D30）。
- 命令协议：位置号（1~5）+ 启动（=1 触发）配对，读完成后清启动；心跳入 / 出向分离。

## 十、代码生成系统（设备模型库）

- 架构：JSON 设备规格单 → SQLite 设备模型 → 生成 AutoShop 交付物（变量/FB/结构体表 CSV + 通讯表 XLSX + 完整 ST 逻辑 SBR_00~08）。
- 关键决策：
  1. 成功标准 = 表 + 完整 ST 逻辑；非目标 = 离线生成器（不做工程反读、不做部署同步）。
  2. 输入 = JSON 设备规格单（轴/步进/辊筒/IO/位置表/常量/原型）。
  3. 双原型：host_driven（全自动，上位机指挥）+ internal_seq（PLC 内部步状态机 + 人工填工步），差异仅 SBR_04~06，SBR_00/01/02/03/07/08 共享。
  4. cloud_brain 知识图由 SQLite 派生（非双维护）；实体名按 `工程:类型:名` 命名空间隔离。
  5. AGENTS.md 规则硬编码进生成器（schema CHECK + 模板）。
  6. 地址完全手填、生成器只校验（唯一性、REAL/DINT 占 2、类型）。
  7. 表用 openpyxl/pandas 生成，ST 用 Jinja2。
- 生成与审查脚本：`load_spec.py`（JSON→SQLite + 32 位重叠校验）、`generate_tables.py`、`generate_st.py`、`review_st.py`（审查）、`generate.py`（一键 load+tables+st+review）、`sync_cloudbrain.py`。

## 十一、文件操作与编码陷阱（重要）

- **就地改 GBK/UTF8 原文件禁止"解码→重写"**：`open(p,'wb').write(...encode('gbk'))` 的 `wb` 会先把文件截断成 0 字节，编码失败即数据永久丢失。必须 `read()` 原始字节 → 字节级 `.replace()` 就地替换 → 整体 `write` 回，全程不经过解码 / 编码往返。
- **操作前先按字节确认实际编码**（.md 可能 UTF8、CSV 可能 GBK），勿按扩展名想当然。
- **被 GBK 误解码的 UTF8 备份恢复**：读为 UTF8 后 `.encode('gb18030')` 逆向还原原始 UTF8 字节（处理 .NET 解码产生的 PUA 字符如 U+E62C）；严格 `gbk` 编码会失败。
- **审查正则**：注释匹配须 `(\(\*[\s\S]*?\*\)|//[^\n]*)`，禁 `//.*` + `re.S`（会把 `//` 后整段代码吞掉、漏检未声明符号）。
- **类型一致性**：BOOL 变量被赋 `0/1` 字面量（AutoShop 强转可行）或 `SEL(...)` 返回 INT 赋给 BOOL（报类型不匹配）为硬问题；正确写法 `BOOL := (host_Send_x = 1)` 或 `:= TRUE/FALSE`。
- **双份同步**：同时维护原程序与优化副本时，任何改名 / 类型修复都同步到两份，并跑旧名残留检查（in_Rest / BlockUP / AotuVolecity 等）防漏改。

## 十二、AutoShop 技术要点

- 常量在独立**常量表**声明（非 SBR VAR_GLOBAL CONSTANT），掉电保持、注释标记常量。
- **TON 用 TONR 指令**（`IN/PT/R/Q=>/ET=>`）直接写在 ST，非 FB 实例；用 R 补偿断电保持；可选参数可省略。
- **host 只发数值**（INT/REAL，`=1` 触发），不发 BOOL 通讯变量。
- FB 参数避用保留 / 常见名（用 `RawIn/FilteredOut` 而非 `In/Out`）。
- **LiteST 硬件异常保护**：除零自动将除数→1（Er5081）；数组越界自动检查但**静默容忍**（正向越界存末元素、负向越界存索引 0，Er5081/Er5083）→ 程序仍须保持下标合法，避免静默读错数据。
- 轴状态机 AxisState：0断 / 1错误停 / 2停止中 / 3静止 / 4离散运动 / 5连续运动 / 6同步 / 7回零；回零使能需 AxisState=3 静止。
- FB_EtherCAT_Axis_ST 参考体未实现 ReturnHomeDone，需在 FB 内加 R_TRIG 边沿补充（Home 启动沿清、Home.Done 沿置位），供自动模式回零前置判定。

---

## 附：deepseek-harness 系统化提示词建议

> 你正在学习一套"汇川 PLC ST 工程"知识。请按以下方式内化：
> 1. **识别规则层级**：区分「强制规则（R1~R4，必须遵守）」「架构约定（SBR 分层）」「操作细则（15 条）」「审查清单（15 缺陷 + 编码陷阱）」「技术事实（AutoShop 特性）」。
> 2. **产出任何工程前**：先列变量表（CSV）再写 ST，二者一一对应；PROGRAM 内零声明；标识符英文、注释中文。
> 3. **自检**：交付前核对——安全回路/锁存/握手/超时/互锁/显式切断是否齐全；表↔代码符号一致性；类型一致性；无魔法数字；无 PROGRAM 内声明。
> 4. **文件操作**：就地改 GBK/UTF8 原文件用字节级替换，绝不解码重写。
> 5. **代码生成**：遵循 JSON 规格单 → SQLite → 表 + ST 的生成管线，地址手填 + 校验。

---
*本知识体系为「编程 → 绘图 → 选型」总计划阶段 1（编程）的对外交付版本；阶段 2（绘图）见 AGENTS.drawing.md，阶段 3（选型）见 AGENTS.selection.md。*
