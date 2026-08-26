(* ════════════════════════════════════════════════════════════════════
   SBR_01 通用 FB 库
   功能: 统一封装可复用功能块, 禁止在程序中复制粘贴逻辑
   分类: 7 个通用 FB + 1 个轴控 FB (FB_EtherCAT_Axis_ST)
   FB 接口/内部变量对应 FB\FbTable_*.csv (类别 IN/OUT/INOUT/VAR)
   定时用 TON, 边沿用 TRIG.R_TRIG, 时间参数 DINT(ms)
   ════════════════════════════════════════════════════════════════════ *)


(* ── FB1 输入滤波: 替代 TONR 裸用 ──────────────────────────────── *)
FUNCTION_BLOCK FB_Debounce
VAR_INPUT
    RawIn       : BOOL;     (* 原始输入信号 *)
    FilterTime  : DINT;     (* 滤波时间(ms) *)
    xFilterQ  : BOOL;   (* TONR直调滤波输出Q *)
END_VAR
VAR_OUTPUT
    FilteredOut : BOOL;     (* 滤波后输出 *)
END_VAR
VAR
END_VAR
TONR(IN := RawIn, PT := FilterTime, Q => xFilterQ);
FilteredOut := xFilterQ;


(* ── FB2 故障锁存: 边沿置位, 故障消除+复位才清除 ───────────────── *)
FUNCTION_BLOCK FB_AlarmLatch
VAR_INPUT
    FaultIn  : BOOL;        (* 故障源输入 *)
    Reset    : BOOL;        (* 复位命令(上升沿) *)
END_VAR
VAR_OUTPUT
    Latched  : BOOL;        (* 故障锁存输出 *)
END_VAR
VAR
    bLatched : BOOL;        (* 锁存状态 *)
    r_Fault  : TRIG.R_TRIG; (* 故障边沿检测 *)
END_VAR
r_Fault(CLK := FaultIn);
IF r_Fault.Q THEN
    bLatched := TRUE;
END_IF;
IF Reset AND NOT FaultIn THEN
    bLatched := FALSE;
END_IF;
Latched := bLatched;


(* ── FB3 命令握手: 边沿锁存, 完成/超时/中止复位 ───────────────── *)
FUNCTION_BLOCK FB_CmdHandshake
VAR_INPUT
    Cmd     : BOOL;         (* 命令输入(上升沿) *)
    Done    : BOOL;         (* 完成反馈 *)
    Timeout : DINT;         (* 超时时间(ms) *)
    Abort   : BOOL;         (* 中止命令 *)
    xTimeoutQ : BOOL;   (* TONR直调超时输出Q *)
END_VAR
VAR_OUTPUT
    Latched : BOOL;         (* 命令已锁存 *)
    Busy    : BOOL;         (* 命令执行中 *)
    Expired : BOOL;         (* 超时标志 *)
    Aborted : BOOL;         (* 已中止标志 *)
END_VAR
VAR
    bLatched    : BOOL;
    bExpired    : BOOL;
    bAborted    : BOOL;
    r_Cmd       : TRIG.R_TRIG;
END_VAR
r_Cmd(CLK := Cmd);
IF r_Cmd.Q THEN
    bLatched := TRUE;
    bExpired := FALSE;
    bAborted := FALSE;
END_IF;
IF Abort THEN
    bAborted := TRUE;
    bLatched := FALSE;
END_IF;
IF bLatched AND Done THEN
    bLatched := FALSE;
END_IF;
TONR(IN := bLatched, PT := Timeout, Q => xTimeoutQ);
IF xTimeoutQ THEN
    bExpired := TRUE;
    bLatched := FALSE;
END_IF;
Latched := bLatched;
Busy    := bLatched;
Expired := bExpired;
Aborted := bAborted;


(* ── FB4 定时动作: 边沿启动, 定时/到位/限位终止 ───────────────── *)
FUNCTION_BLOCK FB_TimedAction
VAR_INPUT
    Start  : BOOL;          (* 启动输入(上升沿) *)
    Time   : DINT;          (* 动作时长(ms) *)
    InPos  : BOOL;          (* 到位信号 *)
    Limit  : BOOL;          (* 限位信号 *)
    xTimeQ    : BOOL;   (* TONR直调定时输出Q *)
END_VAR
VAR_OUTPUT
    Running    : BOOL;      (* 动作执行中 *)
    Done       : BOOL;      (* 动作完成 *)
    Terminated : BOOL;      (* 限位终止 *)
END_VAR
VAR
    bRunning : BOOL;
    r_Start  : TRIG.R_TRIG;
END_VAR
r_Start(CLK := Start);
IF r_Start.Q THEN
    bRunning := TRUE;
END_IF;
TONR(IN := bRunning, PT := Time, Q => xTimeQ);
IF bRunning AND (xTimeQ OR InPos) THEN
    bRunning := FALSE;
    Done := TRUE;
END_IF;
IF bRunning AND Limit THEN
    bRunning := FALSE;
    Terminated := TRUE;
END_IF;
IF NOT bRunning THEN
    Done := FALSE;
    Terminated := FALSE;
END_IF;
Running := bRunning;


(* ── FB5 步进驱动: 手动+自动合并, 正反转互锁, 复位/停止输出 ──── *)
FUNCTION_BLOCK FB_StepperDrive
VAR_INPUT
    ManForward  : BOOL;     (* 手动正向 *)
    ManBackward : BOOL;     (* 手动反向 *)
    AutoForward : BOOL;     (* 自动正向 *)
    AutoBackward: BOOL;     (* 自动反向 *)
    Reset       : BOOL;     (* 故障复位 *)
    Stop        : BOOL;     (* 停止 *)
    Enable      : BOOL;     (* 运行许可 *)
END_VAR
VAR_OUTPUT
    Forward  : BOOL;        (* 正向输出 *)
    Backward : BOOL;        (* 反向输出 *)
    Busy     : BOOL;        (* 运行中 *)
    Done     : BOOL;        (* 完成 *)
    Error    : BOOL;        (* 故障 *)
END_VAR
VAR
    bForward  : BOOL;
    bBackward : BOOL;
    bError    : BOOL;
END_VAR
IF Enable AND NOT Stop THEN
    IF ManForward OR AutoForward THEN
        bForward := TRUE;
        bBackward := FALSE;
    ELSIF ManBackward OR AutoBackward THEN
        bBackward := TRUE;
        bForward := FALSE;
    END_IF;
END_IF;
IF Stop THEN
    bForward := FALSE;
    bBackward := FALSE;
END_IF;
IF Reset THEN
    bError := FALSE;
END_IF;
Forward  := bForward;
Backward := bBackward;
Busy     := bForward OR bBackward;
Done     := NOT (bForward OR bBackward);
Error    := bError;


(* ── FB6 电辊筒: 方向/速度档合并, 三档 50/75/100% ─────────────── *)
FUNCTION_BLOCK FB_Roller
VAR_INPUT
    RunFwd     : BOOL;      (* 正转启动 *)
    RunRev     : BOOL;      (* 反转启动 *)
    SpeedLevel : INT;       (* 速度档(1/2/3) *)
    SpeedLow   : INT;       (* 低速档(%) *)
    SpeedMid   : INT;       (* 中速档(%) *)
    SpeedHigh  : INT;       (* 高速档(%) *)
END_VAR
VAR_OUTPUT
    A     : BOOL;           (* 方向A输出 *)
    B     : BOOL;           (* 方向B输出 *)
    Speed : INT;            (* 速度值(%) *)
END_VAR
VAR
    bFwd : BOOL;
    bRev : BOOL;
END_VAR
IF RunFwd AND NOT RunRev THEN
    bFwd := TRUE;
    bRev := FALSE;
ELSIF RunRev AND NOT RunFwd THEN
    bRev := TRUE;
    bFwd := FALSE;
ELSE
    bFwd := FALSE;
    bRev := FALSE;
END_IF;
A := bFwd;
B := bRev;
CASE SpeedLevel OF
    1: Speed := SpeedLow;
    2: Speed := SpeedMid;
    3: Speed := SpeedHigh;
ELSE
    Speed := 0;
END_CASE;


(* ── FB7 三色灯: 优先级 故障 > 自动 > 手动 ────────────────────── *)
FUNCTION_BLOCK FB_TowerLight
VAR_INPUT
    Fault  : BOOL;          (* 故障状态 *)
    Auto   : BOOL;          (* 自动模式 *)
    Manual : BOOL;          (* 手动模式 *)
    RunOK  : BOOL;          (* 运行许可 *)
END_VAR
VAR_OUTPUT
    Red    : BOOL;          (* 红灯 *)
    Yellow : BOOL;          (* 黄灯 *)
    Green  : BOOL;          (* 绿灯 *)
    Buzzer : BOOL;          (* 蜂鸣器 *)
END_VAR
IF Fault THEN
    Red := TRUE; Yellow := FALSE; Green := FALSE; Buzzer := TRUE;
ELSIF Auto THEN
    Red := FALSE; Yellow := FALSE; Green := TRUE; Buzzer := FALSE;
ELSIF Manual THEN
    Red := FALSE; Yellow := TRUE; Green := FALSE; Buzzer := FALSE;
ELSE
    Red := FALSE; Yellow := FALSE; Green := FALSE; Buzzer := FALSE;
END_IF;


(* ════════════════════════════════════════════════════════════════════
   FB_EtherCAT_Axis_ST 轴控 FB (EtherCAT 伺服专用, R3b)
   内部封装厂商 MC_* 函数 (不改写 MC_* )
   MC_* 形参名需对照目标 AutoShop 库版本校验
   接口: Axis(IN_OUT) + 14 命令输入 → AxisStatusData(OUT) + 完成(OUT)
   ════════════════════════════════════════════════════════════════════ *)
FUNCTION_BLOCK FB_EtherCAT_Axis_ST
VAR_IN_OUT
    Axis : _sMCAXIS_INFO;   (* 轴句柄 *)
END_VAR
VAR_INPUT
    PowerEnable            : BOOL;   (* 轴使能 *)
    Stop                   : BOOL;   (* 轴停止 *)
    Reset                  : BOOL;   (* 故障复位 *)
    Home                   : BOOL;   (* 回零启动 *)
    JogForward             : BOOL;   (* 正向点动 *)
    JogBackward            : BOOL;   (* 反向点动 *)
    Jogvelocity            : REAL;   (* 点动速度 *)
    JogAcceleration        : REAL;   (* 点动加速度 *)
    JogDeceleration        : REAL;   (* 点动减速度 *)
    Absolute_Execute       : BOOL;   (* 绝对定位启动 *)
    Absolute_Position      : REAL;   (* 目标位置 *)
    Absolute_Velocity      : REAL;   (* 定位速度 *)
    Absolute_Acceleration  : REAL;   (* 定位加速度 *)
    Absolute_Deceleration  : REAL;   (* 定位减速度 *)
END_VAR
VAR_OUTPUT
    AxisStatusData          : AxisStatusData;  (* 轴状态结构 *)
    Absolute_MoveAbsoluteDone : BOOL;          (* 绝对定位完成 *)
END_VAR
VAR
    fb_Power        : MC_Power;
    fb_Reset        : MC_Reset;
    fb_Stop         : MC_Stop;
    fb_Home         : MC_Home;
    fb_Jog          : MC_JOG;
    fb_MoveAbsolute : MC_MoveAbsolute;
    fb_ReadStatus   : MC_ReadStatus;
    fb_ReadAxisError: MC_ReadAxisError;
    r_HomeStart     : TRIG.R_TRIG;
    r_HomeDone      : TRIG.R_TRIG;
    bErrorStop      : BOOL;
    bDisabled       : BOOL;
    bStopping       : BOOL;
    bStandStill     : BOOL;
    bDiscreteMotion : BOOL;
    bContinuousMotion : BOOL;
    bSyncMotion     : BOOL;
    bHoming         : BOOL;
END_VAR

(* 轴使能 *)
fb_Power(
    Axis := Axis,
    Enable := PowerEnable,
    Enable_Positive := TRUE,
    Enable_Negative := TRUE,
    Status => AxisStatusData.Power.Status,
    Busy => AxisStatusData.Power.Busy,
    Active => AxisStatusData.Power.Active,
    Error => AxisStatusData.Power.Error,
    ErrorID => AxisStatusData.Power.ErrorID);

(* 故障复位 *)
fb_Reset(
    Axis := Axis,
    Execute := Reset,
    Done => AxisStatusData.Reset.Done,
    Busy => AxisStatusData.Reset.Busy,
    Error => AxisStatusData.Reset.Error,
    ErrorID => AxisStatusData.Reset.ErrorID);

(* 轴停止 *)
fb_Stop(
    Axis := Axis,
    Execute := Stop,
    Deceleration := JogDeceleration,
    Done => AxisStatusData.Stop.Done,
    Busy => AxisStatusData.Stop.Busy,
    Active => AxisStatusData.Stop.Active,
    CommandAborted => AxisStatusData.Stop.CommandAborted,
    Error => AxisStatusData.Stop.Error,
    ErrorID => AxisStatusData.Stop.ErrorID);

(* 回零 *)
fb_Home(
    Axis := Axis,
    Execute := Home,
    Position := 0.0,
    Done => AxisStatusData.Home.Done,
    Busy => AxisStatusData.Home.Busy,
    Active => AxisStatusData.Home.Active,
    CommandAborted => AxisStatusData.Home.CommandAborted,
    Error => AxisStatusData.Home.Error,
    ErrorID => AxisStatusData.Home.ErrorID);

(* 点动 *)
fb_Jog(
    Axis := Axis,
    JogForward := JogForward,
    JogBackward := JogBackward,
    Velocity := Jogvelocity,
    Acceleration := JogAcceleration,
    Deceleration := JogDeceleration,
    InVelocity => AxisStatusData.Jog.Done,
    Busy => AxisStatusData.Jog.Busy,
    Active => AxisStatusData.Jog.Active,
    CommandAborted => AxisStatusData.Jog.CommandAborted,
    Error => AxisStatusData.Jog.Error,
    ErrorID => AxisStatusData.Jog.ErrorID);

(* 绝对定位 *)
fb_MoveAbsolute(
    Axis := Axis,
    Execute := Absolute_Execute,
    Position := Absolute_Position,
    Velocity := Absolute_Velocity,
    Acceleration := Absolute_Acceleration,
    Deceleration := Absolute_Deceleration,
    Done => AxisStatusData.MoveAbsolute.Done,
    Busy => AxisStatusData.MoveAbsolute.Busy,
    Active => AxisStatusData.MoveAbsolute.Active,
    CommandAborted => AxisStatusData.MoveAbsolute.CommandAborted,
    Error => AxisStatusData.MoveAbsolute.Error,
    ErrorID => AxisStatusData.MoveAbsolute.ErrorID);
Absolute_MoveAbsoluteDone := AxisStatusData.MoveAbsolute.Done;

(* 读轴状态 *)
fb_ReadStatus(
    Axis := Axis,
    Enable := TRUE,
    ErrorStop => bErrorStop,
    Disabled => bDisabled,
    Stopping => bStopping,
    StandStill => bStandStill,
    DiscreteMotion => bDiscreteMotion,
    ContinuousMotion => bContinuousMotion,
    SynchronizedMotion => bSyncMotion,
    Homing => bHoming);

(* 读轴故障 *)
fb_ReadAxisError(
    Axis := Axis,
    Enable := TRUE,
    AxisErrorID => AxisStatusData.AxisErrorID);

(* 状态机映射 0断/1错误停/2停止中/3静止/4离散/5连续/6同步/7回零 *)
IF bErrorStop THEN
    AxisStatusData.AxisState := 1;
ELSIF bHoming THEN
    AxisStatusData.AxisState := 7;
ELSIF bDiscreteMotion THEN
    AxisStatusData.AxisState := 4;
ELSIF bContinuousMotion THEN
    AxisStatusData.AxisState := 5;
ELSIF bSyncMotion THEN
    AxisStatusData.AxisState := 6;
ELSIF bStopping THEN
    AxisStatusData.AxisState := 2;
ELSIF bStandStill THEN
    AxisStatusData.AxisState := 3;
ELSE
    AxisStatusData.AxisState := 0;
END_IF;

(* 回零完成锁存: 回零启动清除, 回零完成置位 *)
r_HomeStart(CLK := Home);
r_HomeDone(CLK := AxisStatusData.Home.Done);
IF r_HomeStart.Q THEN
    AxisStatusData.ReturnHomeDone := FALSE;
END_IF;
IF r_HomeDone.Q THEN
    AxisStatusData.ReturnHomeDone := TRUE;
END_IF;

(* 汇总状态 *)
AxisStatusData.PowerStatus := AxisStatusData.Power.Status;
AxisStatusData.Error := AxisStatusData.Power.Error
                     OR AxisStatusData.MoveAbsolute.Error
                     OR AxisStatusData.Home.Error
                     OR AxisStatusData.Jog.Error;
AxisStatusData.Position := 0.0;
AxisStatusData.Velocity := 0.0;
AxisStatusData.Torque := 0.0;