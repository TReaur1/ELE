# 综合复用模板 - 制表交付总结

本文件记录依据 `SBR程序块/SBR_00~SBR_08` 生成的变量表 / FB 表 / 结构体表交付说明，遵循 AGENTS.md R1~R4 与第八节制表规则。

> 本次优化详情见同目录 **`优化报告.md`**（含通讯看门狗修复、超时故障接入锁存、死代码清理等）。

---

## 一、类型与命名规范

1. **时间参数统一 DINT(ms)**（R4）：`IN_FILTER_MS=20`、`TIMEOUT_AXIS_MOVE=10000`、`TIMEOUT_ACTION=5000`、`COMM_TIMEOUT=3000`、`ESTOP_RESET_PULSE_MS=300`、`ST_Stepper.AutoDuration`、FB 接口 `FilterTime/Timeout/Duration`。
2. **con 变量统一 `con_` 前缀**；`in_Auto / in_Manual` 保持原名（用户确认）。
3. **实例在 CSV 声明**（R2）：FB 实例 / TON / 边沿全在 `VariableTable_inst.csv`，PROGRAM 零变量声明。

## 二、优化摘要

| 项 | 内容 |
|---|---|
| 通讯看门狗 | 修复永不触发 BUG：`host_Rcv_Heart` 只由上位机写，PLC 检测变化；PLC 存活心跳独立为 `host_Send_Heart` |
| 超时故障 | 新增 `Latch_Timeout` 接入 `ERRID_TIMEOUT`(bit9) 与 `con_ErrorBit`（原只置位不锁存） |
| 死代码 | 移除 `Fault_Prev/Timer_TO/Timer_Reset/Done_Prev`、`Latched:=Latched` 空操作、`con_MoveStart` |

## 三、交付文件清单（`Tables/`，英文命名、GBK 编码）

### 变量表 `Tables/Variable/`（共 212 个变量）
| 文件 | 数量 | 软元件地址 |
|---|---|---|
| `VariableTable_io.csv` | 47 | in_→X0~X45，out_→Y0~Y40 |
| `VariableTable_host.csv` | 53 | D0~D52（含 host_Send_Heart） |
| `VariableTable_hmi.csv` | 35 | S200~S221 / D1000~D1012 |
| `VariableTable_con.csv` | 22 | D2000~D2021（con_*） |
| `VariableTable_inst.csv` | 55 | FB 实例/定时器/边沿，无地址 |

### FB 表 `Tables/FB/`（共 59 行）
`FBTable_FB_Debounce(5) / FB_AlarmLatch(6) / FB_CmdHandshake(10) / FB_TimedAction(8) / FB_StepperDrive(16) / FB_Roller(7) / FB_TowerLight(7)`

### 结构体表 `Tables/Structure/`（共 43 行）
`StructureTable_ST_AxisCmd(18) / ST_AxisStatus(10) / ST_Stepper(15)`

### 其他
- `StructureInstances_AxisHandles.st` — 结构体父变量（`AxisCmd/AxisStatus/Stepper_*`）、轴句柄（`Axis_M*_*`）、厂商轴控 FB（`AxisControl_M*`），R3 人工创建。
- `Delivery_Summary.md` / `优化报告.md` — 本文件与优化报告。

## 四、校验结果

- 变量表 212 + FB 59 + 结构体 43；inst 表 55 实例与 FB 表、SBR_03 使用逐一对应。
- ST 无 PROGRAM VAR；con/host/io 引用与 CSV 一一对应；无残留死代码。
- CSV 均 GBK 编码、无 `0x3F`；含逗号注释已加引号，导入无错位。

## 五、待人工处理项

1. `AxisCmd/AxisStatus/Stepper_*`、`Axis_M*_*`、`AxisControl_M*` 按 `StructureInstances_AxisHandles.st` 人工创建。
2. D/S 地址按项目寄存器表核对；心跳协议（Rcv/Send）与上位机报文对齐。
3. 建议接入 `in_SafetyGate`（安全门）与 `in_Roller_Err`（辊筒故障）到故障锁存（详见优化报告遗留建议）。

*生成日期：2026-08-11*
