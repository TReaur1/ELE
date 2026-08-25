(* ════════════════════════════════════════════════════════════════════
   SBR_01 通用 FB 库
   FB 接口/内部变量对应 变量表\FbTable_*.csv (类别 IN/OUT/INOUT/VAR)
   ════════════════════════════════════════════════════════════════════ *)

(* ── FB1 故障锁存: 边沿置位, 故障源消除+复位命令才清除 (细则2) ── *)
FUNCTION_BLOCK FB_AlarmLatch
VAR_INPUT
    FaultSrc : BOOL;        (* 故障源输入(电平) *)
    ResetCmd : BOOL;        (* 复位命令(外部已做上升沿) *)
END_VAR
VAR_OUTPUT
    AlarmOut : BOOL;        (* 报警锁存输出 *)
END_VAR
VAR
    bLatched : BOOL;        (* 内部锁存位 *)
END_VAR
IF FaultSrc THEN
    bLatched := TRUE;
ELSIF ResetCmd AND (NOT FaultSrc) THEN
    bLatched := FALSE;      (* 复位需故障源已消除, 不允许带故障复位 *)
END_IF;
AlarmOut := bLatched;

(* ── FB2 电辊筒: 方向互锁 + 三档速度经输入传入 (禁止 FB 内全局常量) ── *)
FUNCTION_BLOCK FB_Roller
VAR_INPUT
    FwdInput  : BOOL;       (* 正转启动 *)
    RevInput  : BOOL;       (* 反转启动(与正转互锁) *)
    SpeedLevel : INT;       (* 速度档(1低/2中/3高) *)
    SpeedLow  : INT;        (* 低速档百分比 *)
    SpeedMid  : INT;        (* 中速档百分比 *)
    SpeedHigh : INT;        (* 高速档百分比 *)
    Enable    : BOOL;       (* 运行许可(RunOK 门控) *)
    Reset     : BOOL;       (* 故障复位 *)
END_VAR
VAR_OUTPUT
    FwdOut    : BOOL;       (* 正转输出 *)
    RevOut    : BOOL;       (* 反转输出(预留) *)
    Error     : BOOL;       (* 故障标志 *)
END_VAR
VAR
    bRun   : BOOL;          (* 内部运行状态 *)
    iSpeed : INT;           (* 内部当前速度 *)
END_VAR
(* 复位清故障 *)
IF Reset THEN
    Error := FALSE;
END_IF;
(* 无许可强制停 (显式切断 细则13) *)
IF NOT Enable THEN
    bRun := FALSE;
END_IF;
(* 方向命令: 同发视为无效防误动, 单向有效 (互锁细则7) *)
IF FwdInput AND (NOT RevInput) THEN
    bRun := TRUE;
ELSIF RevInput AND (NOT FwdInput) THEN
    bRun := TRUE;
ELSIF (NOT FwdInput) AND (NOT RevInput) THEN
    bRun := FALSE;
END_IF;
(* 速度档查表 *)
CASE SpeedLevel OF
    1: iSpeed := SpeedLow;
    2: iSpeed := SpeedMid;
    3: iSpeed := SpeedHigh;
ELSE
    iSpeed := 0;
END_CASE;
(* 输出: 许可门控 + 反向互斥 *)
FwdOut := bRun AND Enable AND (NOT RevInput) AND (iSpeed > 0);
RevOut := FALSE;
