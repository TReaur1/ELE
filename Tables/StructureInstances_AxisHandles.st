//=============================================================
// 文件名: StructureInstances_AxisHandles.st
// 对应: SBR_00~SBR_08 (结构体父变量/厂商FB实例/轴句柄)
// 说明: 按 AGENTS.md R3, 以下父变量不写入 CSV 变量表,
//       需在 AutoShop 中人工创建 (需 TYPE/DUT 定义或工程设备配置)
//       导入时保留注释状态, 由人工取消注释并核对形参
//=============================================================

// --- 轴命令结构组 (ST_AxisCmd, 成员见 StructureTable_ST_AxisCmd.csv) ---
// AxisCmd : ARRAY[1..4] OF ST_AxisCmd;   // 轴命令结构组(M1横移/M2旋转/M3提升/M4对中)

// --- 轴状态结构组 (ST_AxisStatus, 成员见 StructureTable_ST_AxisStatus.csv) ---
// AxisStatus : ARRAY[1..4] OF ST_AxisStatus;  // 轴状态结构组(M1横移/M2旋转/M3提升/M4对中)

// --- 步进控制组 (ST_Stepper, 成员见 StructureTable_ST_Stepper.csv) ---
// Stepper_Gripper : ST_Stepper;   // 夹爪步进控制组
// Stepper_LBlock  : ST_Stepper;   // 左阻挡步进控制组
// Stepper_RBlock  : ST_Stepper;   // 右阻挡步进控制组

// --- 伺服轴句柄 (工程设备配置, _sMCAXIS_INFO) ---
// Axis_M1_Cross  : _sMCAXIS_INFO;  // M1横移伺服轴句柄
// Axis_M2_Rot    : _sMCAXIS_INFO;  // M2旋转伺服轴句柄
// Axis_M3_Lift   : _sMCAXIS_INFO;  // M3提升伺服轴句柄
// Axis_M4_Center : _sMCAXIS_INFO;  // M4对中伺服轴句柄

// --- 厂商轴控FB实例 (库类型 AXIS_CTRL.AXIS_CTRL) ---
// AxisControl_M1 : AXIS_CTRL.AXIS_CTRL;  // M1横移轴控FB实例
// AxisControl_M2 : AXIS_CTRL.AXIS_CTRL;  // M2旋转轴控FB实例
// AxisControl_M3 : AXIS_CTRL.AXIS_CTRL;  // M3提升轴控FB实例
// AxisControl_M4 : AXIS_CTRL.AXIS_CTRL;  // M4对中轴控FB实例

//=============================================================
// 文件结束
//=============================================================
