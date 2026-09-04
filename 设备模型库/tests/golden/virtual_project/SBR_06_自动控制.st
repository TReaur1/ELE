(* ════════════════════════════════════════════════════════════════════
   SBR_06 自动控制 - virtual_project (原型: host_driven)
   上位机命令解析: 防重放 / 握手锁存 / 位置查表 / 超时监视 / 命令回执
   无线链路适应: 降级冻结新命令, 已锁存动作继续完成 (SBR_03 判定 con_CommDegraded)
   ════════════════════════════════════════════════════════════════════ *)
(* 横移 自动定位: 防重放序号门控 + host 命令握手 (细则3, 禁电平直驱) + 位置查表 *)
Handshake_Cross(Cmd := (host_Send_Cross_Start = 1)
    AND (host_Send_CmdSeq <> con_LastCmdSeq) AND NOT con_CommDegraded,
    Done := M1_Cross_Status.MoveAbsolute.Done, Timeout := TIMEOUT_CMD_HANDSHAKE,
    Abort := (NOT con_AutoEnable) OR con_EstopActive);
M1_Cross_Cmd.Absolute_Execute := con_AutoEnable AND Handshake_Cross.Latched;
IF Handshake_Cross.Expired THEN
    con_TimeoutReq := TRUE;           (* 命令超时 -> SBR_03 锁存报警 *)
END_IF;
CASE host_Send_Cross_PosNo OF    1: M1_Cross_Cmd.Absolute_Position := 0.0;    2: M1_Cross_Cmd.Absolute_Position := 100.0;    3: M1_Cross_Cmd.Absolute_Position := 200.0;    4: M1_Cross_Cmd.Absolute_Position := 300.0;    5: M1_Cross_Cmd.Absolute_Position := 400.0;ELSE
    M1_Cross_Cmd.Absolute_Position := 0.0;
END_CASE;
(* 旋转 自动定位: 防重放序号门控 + host 命令握手 (细则3, 禁电平直驱) + 位置查表 *)
Handshake_Rot(Cmd := (host_Send_Rot_Start = 1)
    AND (host_Send_CmdSeq <> con_LastCmdSeq) AND NOT con_CommDegraded,
    Done := M2_Rot_Status.MoveAbsolute.Done, Timeout := TIMEOUT_CMD_HANDSHAKE,
    Abort := (NOT con_AutoEnable) OR con_EstopActive);
M2_Rot_Cmd.Absolute_Execute := con_AutoEnable AND Handshake_Rot.Latched;
IF Handshake_Rot.Expired THEN
    con_TimeoutReq := TRUE;           (* 命令超时 -> SBR_03 锁存报警 *)
END_IF;
CASE host_Send_Rot_PosNo OF    1: M2_Rot_Cmd.Absolute_Position := 0.0;    2: M2_Rot_Cmd.Absolute_Position := 90.0;    3: M2_Rot_Cmd.Absolute_Position := 180.0;    4: M2_Rot_Cmd.Absolute_Position := 270.0;    5: M2_Rot_Cmd.Absolute_Position := 360.0;ELSE
    M2_Rot_Cmd.Absolute_Position := 0.0;
END_CASE;
(* 提升 自动定位: 防重放序号门控 + host 命令握手 (细则3, 禁电平直驱) + 位置查表 *)
Handshake_Lift(Cmd := (host_Send_Lift_Start = 1)
    AND (host_Send_CmdSeq <> con_LastCmdSeq) AND NOT con_CommDegraded,
    Done := M3_Lift_Status.MoveAbsolute.Done, Timeout := TIMEOUT_CMD_HANDSHAKE,
    Abort := (NOT con_AutoEnable) OR con_EstopActive);
M3_Lift_Cmd.Absolute_Execute := con_AutoEnable AND Handshake_Lift.Latched;
IF Handshake_Lift.Expired THEN
    con_TimeoutReq := TRUE;           (* 命令超时 -> SBR_03 锁存报警 *)
END_IF;
CASE host_Send_Lift_PosNo OF    1: M3_Lift_Cmd.Absolute_Position := 0.0;    2: M3_Lift_Cmd.Absolute_Position := 150.0;    3: M3_Lift_Cmd.Absolute_Position := 300.0;    4: M3_Lift_Cmd.Absolute_Position := 450.0;    5: M3_Lift_Cmd.Absolute_Position := 600.0;ELSE
    M3_Lift_Cmd.Absolute_Position := 0.0;
END_CASE;
(* 对中 自动定位: 防重放序号门控 + host 命令握手 (细则3, 禁电平直驱) + 位置查表 *)
Handshake_Center(Cmd := (host_Send_Center_Start = 1)
    AND (host_Send_CmdSeq <> con_LastCmdSeq) AND NOT con_CommDegraded,
    Done := M4_Center_Status.MoveAbsolute.Done, Timeout := TIMEOUT_CMD_HANDSHAKE,
    Abort := (NOT con_AutoEnable) OR con_EstopActive);
M4_Center_Cmd.Absolute_Execute := con_AutoEnable AND Handshake_Center.Latched;
IF Handshake_Center.Expired THEN
    con_TimeoutReq := TRUE;           (* 命令超时 -> SBR_03 锁存报警 *)
END_IF;
CASE host_Send_Center_PosNo OF    1: M4_Center_Cmd.Absolute_Position := 0.0;    2: M4_Center_Cmd.Absolute_Position := 50.0;    3: M4_Center_Cmd.Absolute_Position := 100.0;    4: M4_Center_Cmd.Absolute_Position := 150.0;    5: M4_Center_Cmd.Absolute_Position := 200.0;ELSE
    M4_Center_Cmd.Absolute_Position := 0.0;
END_CASE;
(* 防重放: 任一命令被受理后记忆序号, 同序号重发不再触发 (无线网络会重发/乱序) *)IF Handshake_Cross.Latched OR Handshake_Rot.Latched OR Handshake_Lift.Latched OR Handshake_Center.Latched THEN
    con_LastCmdSeq := host_Send_CmdSeq;
END_IF;

(* 命令回执状态字 (CMDST_: 0空闲/2执行中/3完成/4超时, 超时保持至下条命令):
   上位机在收到回执前不得认为命令已生效, 也不得以"发送成功"作为执行依据 *)IF Handshake_Cross.Expired THEN
    host_Rcv_Cross_CmdState := CMDST_EXPIRED;
ELSIF Handshake_Cross.Latched THEN
    host_Rcv_Cross_CmdState := CMDST_EXEC;
ELSIF M1_Cross_Status.MoveAbsolute.Done THEN
    host_Rcv_Cross_CmdState := CMDST_DONE;
ELSE
    host_Rcv_Cross_CmdState := CMDST_IDLE;
END_IF;IF Handshake_Rot.Expired THEN
    host_Rcv_Rot_CmdState := CMDST_EXPIRED;
ELSIF Handshake_Rot.Latched THEN
    host_Rcv_Rot_CmdState := CMDST_EXEC;
ELSIF M2_Rot_Status.MoveAbsolute.Done THEN
    host_Rcv_Rot_CmdState := CMDST_DONE;
ELSE
    host_Rcv_Rot_CmdState := CMDST_IDLE;
END_IF;IF Handshake_Lift.Expired THEN
    host_Rcv_Lift_CmdState := CMDST_EXPIRED;
ELSIF Handshake_Lift.Latched THEN
    host_Rcv_Lift_CmdState := CMDST_EXEC;
ELSIF M3_Lift_Status.MoveAbsolute.Done THEN
    host_Rcv_Lift_CmdState := CMDST_DONE;
ELSE
    host_Rcv_Lift_CmdState := CMDST_IDLE;
END_IF;IF Handshake_Center.Expired THEN
    host_Rcv_Center_CmdState := CMDST_EXPIRED;
ELSIF Handshake_Center.Latched THEN
    host_Rcv_Center_CmdState := CMDST_EXEC;
ELSIF M4_Center_Status.MoveAbsolute.Done THEN
    host_Rcv_Center_CmdState := CMDST_DONE;
ELSE
    host_Rcv_Center_CmdState := CMDST_IDLE;
END_IF;