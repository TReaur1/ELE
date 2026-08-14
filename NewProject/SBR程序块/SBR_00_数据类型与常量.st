(* ════════════════════════════════════════════════════════════════════
   SBR_00 数据类型与常量 (文档说明)
   本文件仅作说明, 不含声明 (R2: PROGRAM 零声明 / LRN-027: 类型不进 SBR)
   声明位置:
   - 结构体类型 -> Structure\StructureTable_*.csv
   - 常量      -> Variable\VariableTable_const.csv (掉电保持)
   - 全局标量  -> Variable\VariableTable_io/host/hmi/con.csv
   - FB 实例   -> Variable\功能块实例.csv (含 TON/R_TRIG 成员展开)
   ════════════════════════════════════════════════════════════════════ *)

(* ── 第一章 结构体 (定义在 Structure 结构体表) ────────────────────
   AxisControlData  轴命令结构   : 成员见 StructureTable_AxisControlData.csv
   AxisStatusData   轴状态结构   : 成员见 StructureTable_AxisStatusData.csv
   ST_AxisPower     使能子结构   : 成员见 StructureTable_ST_AxisPower.csv
   ST_MC_Status     运动子结构   : 成员见 StructureTable_ST_MC_Status.csv
   ST_Stepper       步进控制结构 : 成员见 StructureTable_ST_Stepper.csv *)

(* ── 第二章 常量 (定义在 VariableTable_const.csv, DINT ms / REAL / INT) ──
   FILTER_TIME_MATERIAL / FILTER_TIME_LIMIT   滤波时间
   TIMEOUT_AXIS_MOVE / TIMEOUT_CMD_HANDSHAKE / TIMEOUT_STEPPER / WATCHDOG_TIMEOUT
   ROLLER_SPEED_LOW / MID / HIGH              辊筒三档
   AXIS_JOG_* / AXIS_HOME_* / AXIS_MOVE_*     轴速度/加减速
   ERRID_*                                    故障码位 (DINT 位编码) *)

(* ── 第三章 命名规范 (速查) ──────────────────────────────────────
   in_/out_ 物理IO  hmi_ 触摸屏  host_ 上位机(_Send/_Rcv)  con_ 内部控制
   Mx_ 伺服轴  Stepper_ 步进  AxisControl_ 轴控FB实例  db 滤波实例  r/ton 边沿/定时 *)
