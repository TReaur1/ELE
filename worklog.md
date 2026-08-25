# 工作日志

## 2026-05-12 汇川PLC标识符命名规则问答

- **任务**：解答"汇川 PLC 标识符命名规则？能否用中文变量名？"
- **结论**：按 AGENTS.md R1 强制规则，**禁止中文变量名**，标识符仅英文字母/数字/下划线；中文只允许出现在注释与变量表"注释"列；源工程中文标识符须映射为英文别名。
- **配套规则速记**：功能前缀（in_/out_/hmi_/host_/con_/Mx_/Stepper_/AxisControl_）；结构体成员匈牙利前缀（b/f/d/w/i/s）；FB 接口描述式英文不带前缀；汇川无 TIME 类型（用 DINT/ms）、结构体禁 DWORD（用 DINT）。
- **未决事项**：AutoShop 软件本身是否支持中文变量名未检索到权威结论，不臆测；但规范层面 R1 已强制仅英文，与软件支持与否无关。

## 2026-08-14 协作任务#9 重测:汇川急停输入分配与滤波

- **任务**：collab 协作中心任务#9（DSH-daemon 认领）：急停信号分配端口范围、滤波设置、物料检测/限位滤波方式（依据 AGENTS.md 细则8），并对仓库实际实现做重测验证。
- **结论（全部通过）**：
  1. spec 层（virtual/seq/demo 三个 json）：`in_EStop` 均分配 X0（X0~X7 范围内），filter_mode=none。
  2. 模板 SBR_02_IO映射.st.j2 只对 filter_mode=debounce 的点调用 FB_Debounce，none 直接映射；生成的 SBR_02 中 `in_EStop := X0;` 无消抖调用。
  3. 变量表 io.csv：in_EStop=X0，注释含"(滤波:none)"；安全门 X1(builtin)。
  4. 安全层 SBR_03：`con_EstopPressed := NOT in_EStop`（常闭取反锁存）；`con_RunOK := in_EStop AND NOT con_ErrorBit AND NOT con_CommLost`。
  5. 主调度 SBR_08：sbr_io(STEP0)→sbr_safety(STEP1) 最先执行。
  6. 常量备有 FILTER_TIME_MATERIAL/LIMIT=20ms（FB_Debounce 备用）。
  7. verify_consistency.py / verify_counts.py 运行通过（host_Send_Start/Stop/Home 三个变量 ST 未用属 seq 自动程序待完善，非本次范围）。
- **观察项**：限位点目前分配在 X20~X25（X0~X7 之外，硬件 RC 约10ms 不可调），符合"X0~X7 不够用"的规则允许，但对限位响应要求高的场合可考虑挪入 X0~X7。
- **需人工确认**：X0~X7 数字滤波实际值（D8020/REFF）属 AutoShop 工程设备配置，spec 的 filter_mode=none 只约束生成代码不滤波，硬件滤波值需在工程中设最短。
- **遗留**：NewProject 的 VariableTable_io.csv 为空表（仅表头），后续建表时急停须按细则8分配 X0~X7 且不滤波。

## 2026-08-14 18:12 协作任务#11 验证:汇川定位指令超时判定

- **任务**：collab 协作中心任务#11（DSH-daemon 认领）：按 AGENTS.md 细则11+技术依据+细则2，验证设备模型库三个 spec（virtual_project/host_driven、seq_project/internal_seq、demo_seq）生成的 ST 对定位指令超时判定的实现。
- **结论（不通过，核心缺陷 6 项）**：
  1. TIMEOUT_AXIS_MOVE=5000ms 常量已声明（spec+const 表），但 ST 全库零引用——只声明不用。
  2. FB_EtherCAT_Axis_ST 无定位超时判定：MoveAbsolute 仅 Done/Busy/Active/CommandAborted/Error 直通，无 TON/Expired。
  3. host_driven SBR_06：`Absolute_Execute := con_AutoEnable AND host_Send_*_Start` 电平直驱，无 FB_CmdHandshake 锁存、无超时；host 撤 Start 即减速停、Done 永不置位（正是技术依据警示场景），无兜底。
  4. internal_seq SBR_06：步转移只等 MoveAbsolute.Done，无超时转移，定位卡死=永久停步不报警；注释称 TIMEOUT_STEPPER 已备好但全库无该常量/逻辑（注释失实）。
  5. 超时报警未入锁存闭环：SBR_03 故障锁存段为空白占位；con_TimeoutAlarm(D2018)/con_ErrorID/con_ErrorBit/ERRID_TIMEOUT 均无人写，con_RunOK 的 NOT con_ErrorBit 恒真 → 联锁形同虚设（违反细则2）。
  6. 功能块实例表无 Handshake 实例/定位超时 TON 实例（R2 要求实例进表）。
- **通过项**：TIMEOUT_AXIS_MOVE、ERRID_TIMEOUT(16#40)、con_TimeoutAlarm 均已声明；FB_CmdHandshake 自带"启动沿锁存→限时未见 Done→Expired"通用机制；ST_MC_Status 有 Done/CommandAborted 分离（"停止与完成分开判断"的数据基础具备）。
- **观察项**：SBR_07 调用仅传 PowerEnable/Execute/Position，Velocity/Acceleration/Deceleration 未传（R3b 要求 14 命令全传）；host_Send_*_Start 为 INT 与 BOOL 做 AND 依赖隐式转换；demo_seq spec 缺 ERRID_TIMEOUT 常量与其他 spec 不一致。
- **修复建议（待确认后实施，未擅改仓库）**：①FB_EtherCAT_Axis_ST 增 Timeout(DINT) 输入 + Expired(BOOL) 输出（R_TRIG 捕获 Execute 上升沿起 TON，Done/CommandAborted 复位）；②host_driven 每轴配 FB_CmdHandshake+TON 实例，Expired→con_TimeoutAlarm；③internal_seq 步机加"启动限时未见 Done"超时转移；④SBR_03 用 FB_AlarmLatch 锁存→ErrorID|=ERRID_TIMEOUT→ErrorBit→RunOK 联锁。
- **遗留**：是否实施修复方案待用户/仓库维护方确认；NewProject 不在本次范围。
