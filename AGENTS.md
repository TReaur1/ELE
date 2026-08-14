# AGENTS.md — PLC ST 编程规则（综合复用模板）

本文件为**汇川 PLC（Inovance / AutoShop）ST 语言**工程设计的编程规范，由"综合复用模板"项目经验总结而来。任何 PLC 重构 / 新工程开发都必须遵守本规则。

**三阶段总计划**：本文件承载**阶段1（编程）**核心规则；阶段2（自动化成套图纸）见 `AGENTS.drawing.md`，阶段3（电气成套选型）见 `AGENTS.selection.md`。阶段规范经第九节复盘闭环填充与演进。

---

## 一、强制规则（最高优先级，覆盖其他一切约定）

### R1 标识符仅允许英文（强制）

- 所有标识符（变量名、FB 名、STRUCT 名、TYPE 名、实例名、常量名）**只准使用英文字母 / 数字 / 下划线**。
- **禁止**在标识符中出现中文、拼音、中英混排（如 `M1_横移伺服`、`act夹爪FWD`、`in_夹爪步进电机错误` 均不合规）。
- 代码注释、变量表"注释"列、文档说明**一律使用中文**。
- 若源工程 / 导入 CSV 已含中文标识符，必须映射为英文后再写入逻辑（CSV 名可保留中文，逻辑 ST 用英文别名，二者通过变量表注释对应）。

### R2 变量声明边界（强制）

- **PROGRAM 中禁止声明标量 / 结构体变量**（中间变量、锁存 / 许可 / 边沿标志）：这些集中定义在 AutoShop CSV 变量表的 `con` 类，ST 引用的每个标量符号都必须能在变量表中找到，二者一一对应。
- **FB 实例、定时器（TON）、边沿检测（R_TRIG/F_TRIG）在 `inst_功能块实例.csv` 变量表声明，ST 中直接引用**：每行一个实例，`数据类型` 列填 FB 名（如 `FB_Debounce`）或 `TON` / `TRIG.R_TRIG`；TON/R_TRIG 实例需展开成员行（TON: IN/PT/Q/ET，PT/ET 为 DINT；R_TRIG: CLK/Q/M）。ST 各 PROGRAM 直接调用实例名，不再在局部 `VAR` 重复声明。每个实例只在其所在 PROGRAM 内使用，扫描间状态自动保持。
- **批量 FB 调用采用「逐实例独立接口」模式**：
  - FB 库（SBR_01）内每个 FB 用独立 `VAR_INPUT` / `VAR_OUTPUT` 接口（如 FB_Debounce: In/FilterTime→Out；FB_CmdHandshake: Cmd/Done/Timeout/Abort→Latched/Busy/Expired/Aborted），内部状态（TON/R_TRIG）留在 FB 内部。
  - 同一 FB 的多份实例在 `inst_功能块实例.csv` 逐行声明并独立命名（如 `Db_Gripper_Err`、`Latch_Estop`、`Handshake_Axis1`、`TimedAct_GripFwd`），ST 逐实例调用 `实例名(参数 := 实参)`。
  - 不使用「实参结构体 + 数组」模式（不建 ST_*Data 结构体、不用 VAR_IN_OUT 打包实参）。
- 变量表分类（仅存全局标量 / 结构体 / 通讯 / HMI / IO）：
  - `io`    —— 物理输入输出（X / Y 映射变量）
  - `host`  —— 上位机通讯（host_Send_* / host_Rcv_*）
  - `hmi`   —— 触摸屏变量
  - `con`   —— 内部控制：标量、结构体、锁存 / 许可 / 边沿标志（统一 `con_` 前缀）
  - `mc`    —— Modbus 主站 / 预留
  - `AxisControl` —— 伺服轴命令结构（AxisControlData）与状态结构（AxisStatusData）
- **FB（FUNCTION_BLOCK）内部允许声明变量**：接口（VAR_INPUT/VAR_OUTPUT）与内部状态属于功能块定义机制，不属于"PROGRAM 声明"。

### R3 允许结构体整合变量（强制）

- 允许使用 **STRUCT / TYPE** 将一组功能相关的变量封装为一个结构体，压缩变量表条目数（典型：轴命令组、轴状态组、步进控制组、报警组、工艺参数组）。
- **必须注明结构体带有哪些变量**：结构体定义处须列出全部成员，每个成员带中文注释；ST 中以 `实例名.成员` 访问，成员名遵循 R1（英文）。
- 结构体类型定义放在 **SBR_00（数据类型与常量）** 或 CSV 变量表的"类型"列；结构体实例按 R2 分类进入对应变量表（如 `con` / `AxisControl`）。
- **结构体父变量不写入变量表**：含有多个成员的结构体实例（如 `AxisCmd[1..4]`、`AxisStatus[1..4]`、`Stepper_*`）以及汇川自带形式（如 `_sMCAXIS_INFO` 轴句柄、`AxisControlData/AxisStatusData`）在生成变量表时**不放入 CSV**，而是**写入对应 `.st` 文件并注释掉**，由人工创建（需 TYPE / DUT 定义或工程设备配置）。
- 成员按功能分组、前缀一致，禁止把无关变量塞入同一结构体；结构体跨层传递时同步更新定义注释。

### R3b 轴控实体模式（强制，EtherCAT 伺服专用）

- **适用边界**：仅 EtherCAT 通讯伺服。脉冲步进仍用 `FB_StepperDrive + ST_Stepper`，不混用。
- **四层结构**（每伺服一组）：命令实体 `M1_Cross_Cmd : AxisControlData`、状态实体 `M1_Cross_Status : AxisStatusData`（con 变量表，数据类型列填结构体名）；FB 实例 `AxisControl_M1 : FB_EtherCAT_Axis_ST`（inst 表）；轴句柄 `Axis_M1_Cross : _sMCAXIS_INFO`（工程设备配置）。
- **结构体**：`AxisControlData`（命令：PowerEnable/Stop/Reset/Home/JogForward/JogBackward/Jogvelocity/JogAcceleration/JogDeceleration/Absolute_Execute/Absolute_Position/Absolute_Velocity/Absolute_Acceleration/Absolute_Deceleration）；`AxisStatusData`（状态：Power/Stop/Reset/Home/Jog/MoveAbsolute/MoveRelative/MoveVelocity/Halt 九子结构 + Position/Velocity/Torque/AxisState/Error/AxisErrorID/ReturnHomeDone 等标量）。
- **FB 封装**：`FB_EtherCAT_Axis_ST` 为厂商轴控 FB 封装，内部直接调用 `MC_Power/MC_Reset/MC_Stop/MC_Home/MC_JOG/MC_MoveAbsolute/MC_ReadStatus/MC_ReadAxisError`，**MC_* 厂商函数不改写**；接口 = Axis(IN_OUT) + 14 命令输入 → AxisStatusData(OUT) + Absolute_MoveAbsoluteDone(OUT)。
- **调用规范**：先给命令实体赋值，再调用实例（`:=` 传命令、`=>` 连输出）：
  `AxisControl_M1(Axis := Axis_M1_Cross, PowerEnable := M1_Cross_Cmd.PowerEnable, ... , Absolute_MoveAbsoluteDone => M1_Cross_Status.MoveAbsolute.Done, AxisStatusData => M1_Cross_Status);`
  状态经状态实体回读（`M1_Cross_Status.Error/AxisState/MoveAbsolute.Done/ReturnHomeDone/...`），不另建中间变量。
- 命名注意：`AxisControlData` 成员为 `Jogvelocity`（小写 v）；回零完成用 `ReturnHomeDone`；状态机 `AxisState`（0断/1错误停/2停止中/3静止/4离散运动/5连续运动/6同步/7回零）；回零使能需 `AxisState=3` 静止。

### R4 汇川类型与结构体命名（强制）

- **汇川（AM / H5U 等）不存在 TIME 类型变量**：所有定时 / 延时 / 超时参数一律用 `DINT`（单位 ms）或 `REAL`（单位 s）表达；禁止在变量表与结构体中使用 `TIME` 数据类型及 `T#` 字面量。FB 接口中的定时参数（滤波时间、动作时长、超时阈值）同样改用数值类型。
- **汇川结构体不支持 DWORD，统一用 `DINT`**：结构体成员、全局变量、常量一律禁止 `DWORD` 数据类型（AutoShop 结构体表无 DWORD 可选，导入报错）；位编码 / 故障码 / 状态字用 `DINT`（32 位有符号，位编码值 ≤0x7FFFFFFF 均容纳），如 `ErrorID : DINT`、`ERRID_* : DINT`。
- **结构体名即变量数据类型**：变量若使用结构体，其"数据类型"列填结构体名；因此结构体名必须符合 R1（仅英文字母 / 数字 / 下划线，且不以数字开头），结构体成员名同样符合 R1。
- 结构体名与成员名避免与全局变量重名，命名直观反映用途（如轴命令组 / 轴状态组 / 步进组）。

---

## 二、命名规范

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

### 结构与 FB 成员命名（simpleFB 规范）

**FB 变量类别**（汇川规范FB 表"类别"列）：
| 类别 | 含义 |
|---|---|
| `IN` | 输入（VAR_INPUT） |
| `OUT` | 输出（VAR_OUTPUT） |
| `INOUT` | 输入输出（VAR_IN_OUT） |
| `VAR` | 内部变量 |

**FB 接口参数（IN/OUT/INOUT）命名**——采用描述式英文命名，不带类型前缀，与 FBst 示例一致（如 `PowerEnable` / `Stop` / `Home` / `JogForward` / `Absolute_Execute` / `Absolute_Position`）。

**结构体成员与 FB 内部变量命名（匈牙利式类型前缀）**：
| 前缀 | 数据类型 | 示例 |
|---|---|---|
| `b` | BOOL | bPowerOn / bHome / bJogP |
| `f` | REAL | fActPosition / fTarVelocity |
| `d` | DINT | dSetPosition / dMaxVelocity |
| `w` | WORD / INT（16 位） | wPLCOpenState / wStatusword |
| `i` | INT | iEncoderMode / iHomeMethod |
| `s` | 结构体成员（子结构） | sConfig（`_sMCAXIS_CONFIG`） |

**数据类型命名**：
- 基础类型用 IEC 大写：`BOOL / BYTE / INT / DINT / REAL / STRING / POINTER / IP`。
- 库类型：`库名.类型名`（如 `TRIG.R_TRIG`、`TRIG.F_TRIG`、`AXIS_CTRL.AXIS_CTRL`）。
- 结构体类型：系统结构 `_s` 前缀 + 大驼峰（`_sMCAXIS_INFO`、`_sMCAXIS_CONFIG`、`_sPID_GeneralConfig`）；库结构 `库名.S结构名`（`AXIS_CTRL.SUSERAXIS`）。
- 数组：`类型[长度]`、多维 `类型[行,列]`（如 `DINT[14]`、`BOOL[1,1]`）。
- 字符串：`STRING` 或定长 `STRING<长度>`。

急停语义：`in_eStop=TRUE` 表示**急停释放（安全）**；`EstopPressed := NOT in_eStop`。

---

## 三、分层架构与程序块

分层：**IO 层 → 安全层 → 逻辑层（模式/手动/自动）→ 执行层（轴）→ 输出刷新**，各层只读写全局变量表，互不直接调用。

| 程序块 | 内容 |
|---|---|
| SBR_00 | 数据类型与常量 |
| SBR_01 | 通用 FB 库（7 个可复用 FB） |
| SBR_02 | IO 映射（滤波 + 映射） |
| SBR_03 | 安全回路（锁存 / 复位 / 许可 / 看门狗 / 三色灯） |
| SBR_04 | 模式管理（互斥 / 清零 / 切换检测） |
| SBR_05 | 手动控制（Jog / 步进 / 辊筒） |
| SBR_06 | 自动控制（握手 / 查表 / 定时 / 超时 / 反馈） |
| SBR_07 | 轴控制与输出（伺服 FB / 步进 FB / 辊筒 FB） |
| SBR_08 | 主调度（STEP0~5 统一调用顺序） |

主调度扫描顺序：安全回路 STEP1 最先执行，输出 STEP5 最后刷新；无许可时强制安全态。

---

## 四、通用 FB 库（SBR_01）

统一封装可复用功能块，禁止在程序中复制粘贴逻辑：

- `FB_Debounce` —— 输入滤波（替代 TONR 裸用）
- `FB_AlarmLatch` —— 故障锁存（边沿置位，故障消除 + 复位命令才清除）
- `FB_CmdHandshake` —— 上位机命令握手（边沿锁存，完成 / 超时 / 中止复位）
- `FB_TimedAction` —— 定时动作（边沿启动，定时 / 到位 / 限位终止）
- `FB_StepperDrive` —— 步进驱动（手动 + 自动合并，正反转互锁，复位 / 停止输出）
- `FB_Roller` —— 电辊筒（方向 / 速度档合并，三档 50/75/100%）
- `FB_TowerLight` —— 三色灯 + 蜂鸣（优先级 故障 > 自动 > 手动）

可选：`FB_CommGuard` —— 通讯看门狗（心跳变化判断在线，超时置 CommLost）。

---

## 五、编程规范细则

1. **安全优先**：安全回路最先执行，输出最后刷新；`RunOK` 作为全局运行许可（急停 OK 且无报警且通讯正常）。
2. **故障锁存**：故障 SET / RESET；复位需"上升沿 + 故障源已消除"确认，不允许故障仍存在时复位成功。**检测结果必须接入锁存闭环**（置位 → 锁存 → ErrorID/ErrorBit → 运行许可），只置位不锁存 = 形同虚设（如超时报警只写不读、不参与联锁）。
3. **命令握手**：上位机命令必须经 `FB_CmdHandshake` 锁存，完成 / 超时才复位；避免电平命令被误当边沿、漏动作。
4. **消除重复**：CASE + 数组 / 结构查表替代 IF/ELSIF 长链，FB 封装替代复制粘贴；同一逻辑只写一次。相关变量优先用结构体整合（见 R3），压缩变量表。
5. **常量化**：加减速系数、超时时间、滤波时间、速度档位、轴状态字一律用 `CONST`，禁止硬编码魔法数字。
6. **边沿检测时序**：先读旧值 → 判断变化 → 后更新旧值，保证一个扫描周期内一致。
7. **互锁原则**：正反转 `AND NOT` 互斥且定义优先级；模式互斥；三色灯用 ELSIF / 状态表互斥，禁止靠顺序叠 IF。
8. **输入滤波（汇川自带内置滤波优先）**：汇川 PLC 输入自带滤波——仅 X0~X7 数字滤波可调（0~60ms，对应 D8020 / REFF），其余端口为硬件 RC 滤波约 10ms 不可调，高速计数 / 输入中断所用端口自动取最短滤波。据此：
   - **急停不滤波**：分配 X0~X7 并设最短滤波 / 直通，安全响应最快。
   - **物料检测 / 限位等**：优先用**内置滤波**（分配 X0~X7 设数字滤波 0~60ms），而非软件滤波。
   - **FB_Debounce 降级为可选额外消抖**：仅当内置滤波不足（需更长消抖、软件侧去抖、或 X0~X7 不够用）时才用 `FB_Debounce`，不再作为默认 20ms 必配。
   - 安全与高速信号**优先分配 X0~X7**，否则即使软件不滤波也受约 10ms 硬件延迟限制。
9. **通讯联锁**：Modbus TCP 断开 → `CommLost=TRUE` → `RunOK=0` → 自动停止，不依赖上位机主动停机。**心跳寄存器必须分离**：入向心跳（上位机→PLC，PLC 检测变化判在线）与出向心跳（PLC→上位机，PLC 自增示存活）不可复用同一寄存器，否则看门狗失效。
10. **回零前置**：自动模式启动要求所有轴回零完成（用 `AxisStatusData.ReturnHomeDone` 或等价状态字判断）。
11. **定位超时**：`MoveAbsolute` 必须配超时（`TIMEOUT_AXIS_MOVE`），超时置报警，防止卡死。
12. **步进自动锁存**：自动挡步进输出用 `FB_TimedAction` 定时或限位终止，禁止"单扫描脉冲"驱动。
13. **显式安全切断**：无许可时输出必须显式复位（如辊筒 `A=0 B=0 Dir=0`、步进路径 `=0`、伺服 `Execute=0`），不依赖 `ELSE` 分支的隐式默认。
14. **电机输出互锁时序**：方向与使能输出都经过许可门控后再刷新到 Y 点。

---

## 六、避免原程序常见缺陷（重构检查清单）

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

**技术依据（AutoShop 手册，梯形图系 H3U 定位经验，ST 系 H5U 参考）**：
- 定位指令（DRVI/DRVA/PLSR）**能流断开即减速停止，且完成标志 M8029 不动作**；因此"停止"与"完成"必须分开判断，超时逻辑以"启动后限时未见完成标志"为准（对应第 5 条）。
- 同端口定位指令并发 → 端口冲突错误、无脉冲输出；需"端口初始化标志"释放抢占（H3U 系 M8351 等）。编程上保证**同一高速端口同一时刻只有一条定位指令能流有效**。
- 定位参数运行中修改**本次不生效，下次启动生效**——在线改参后必须重新触发指令。
- 回零 DOG 信号**用 X 输入及时性最好**（M/S 输入有延迟）；回零完成以完成标志 + 输出中监控复位为准（对应第 6 条）。
- 高速比较输出（HSCS 等）选 **Y0~Y17 立即输出**，Y20 以后要等扫描结束才输出；同时驱动数量受限（H3U 系总计 ≤8 条）。

---

## 七、交付与验证方式

- 每个程序文件只含语句；先给出（或确认）变量表（CSV），再写 ST，二者一一对应。
- 交付内容含：`00_说明`、变量表分类说明、FB 库、程序块、主调度。
- 变量表格式（汇川规范变量表）：`序号,变量名,数据类型,隐藏初始值,初始值,掉电保持,网络公开,注释,软元件地址`；结构体表格式（汇川规范结构体）：`序号,成员变量名,数据类型,注释`；FB 表格式（汇川规范FB）：`序号,类别,名称,数据类型,隐藏初始值,初始值,掉电保持,注释`，类别用 `IN / OUT / INOUT / VAR`。
- 验证：核对变量表 ↔ ST 符号一致性；检查无 `PROGRAM` 内声明；检查安全回路 / 锁存 / 握手 / 超时 / 互锁 / 显式切断是否齐全；核对结构体定义处成员清单与 ST 实际使用一致（R3）；核对 FB 成员命名符合类型前缀（b/f/d/w/i/s）；中文注释、英文标识符。
- 移植注意：厂商 FB 实例、轴句柄、Modbus 从站对象属工程设备配置，需核对实例名与形参；中文注释以 GBK 编码导入 AutoShop。

---

## 八、制表规则（仅汇川程序使用）

**适用范围：仅汇川 PLC 工程（Inovance / AutoShop）制表时使用此规则；非汇川程序（如西门子 / 三菱 / 倍福等）不适用。**

**制表细则由 `table-expert` skill 承载**（含三种规范表头、结构体数组成员格式、校验清单、GBK 编码约定）：

- 变量表 / FB 表 / 结构体表三种表头的**唯一权威基准**为桌面 `C:\Users\kaanh\Desktop\汇川表` 内三个规范 CSV，列顺序不可调换、表头不可改名、末尾保留逗号。
- 触发方式：制表 / 校验 / 转换时调用 `table-expert`（或说"生成变量表 / 校验CSV / 制表"）。
- 强制要点速记：序号从 1 递增；标识符仅英文（R1）；注释全中文；FB 类别仅 `IN/OUT/INOUT/VAR`；结构体逐成员注释（R3）；CSV 以 GBK 编码导入 AutoShop。
- 规则沉淀：新规则经用户确认后写入 skill 的规则库，不直接改本文件。

---

## 九、复盘-精进闭环（强制）

本文件与阶段规范文件（`AGENTS.drawing.md` / `AGENTS.selection.md`）通过**复盘闭环**持续演进。任何工程 / 重构 / 制表 / 交付完成后触发：

1. **触发**：每次实质性工作完成后，主动提出复盘（不等待用户要求）。
2. **盘点**：从本次实践中提炼候选经验（踩过的坑、新约束、更优做法、命名/类型/时序问题）。
3. **逐条询问确认**：向用户说明每条候选的适用范围与内容，**必须逐条征得确认，严禁贸然总结规则**；被否定的不写入。
4. **落盘**：确认项写入对应文件——
   - 强制条款 → 本文件相应章节
   - 阶段规范 → `AGENTS.drawing.md` / `AGENTS.selection.md`
   - 操作细则 → 对应 skill（如 `table-expert` 规则库）
   - 经验留档 → 记忆 keeper（`deposit`）
5. **记录**：`CHANGELOG.md` 追加条目 + git 提交（版本递增）。
6. **版本管理**：每次精进 = 1 个 CHANGELOG 条目 + 1 次提交；重大变更递增次版本号。

文件分工总则：**强制条款进 AGENTS.md，操作细则进 skill，经验留档进记忆 keeper，阶段规范进对应阶段文件。**
