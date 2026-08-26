(* ════════════════════════════════════════════════════════════════════
   SBR_host 上位机通讯 (Modbus TCP, 字表见 通讯字表.csv)
   命令处理(触发式+清0回执) + 出向心跳(TONR直调) + 状态区回写
   ════════════════════════════════════════════════════════════════════ *)

(* ── 三色灯蜂鸣: 优先级 故障 > 自动 > 手动 ── *)
Tower_1(Fault      := Latch_Estop.AlarmOut OR Latch_Cyl.AlarmOut OR con_CommLost,
        Auto       := bModeAuto,
        Manual     := NOT bModeAuto);

(* ── 出向心跳: TONR 直调 IN取反自翻转 每 COMM_HEART_TICK 计数+1 ── *)
TONR(IN := NOT con_HeartTickQ,
     PT := COMM_HEART_TICK,
     Q  => con_HeartTickQ);
IF con_HeartTickQ THEN
    con_HeartOut := con_HeartOut + 1;
END_IF;

(* ── 辊筒命令映射(PLC控制辊筒第一环):
      host命令字 -> 运行记忆量 触发式 三者互斥 仅自动位接受 执行后清0回执 ── *)
IF bRemoteEn THEN
    IF host_Send_RollerStart = 1
       AND host_Send_RollerStop <> 1 AND host_Send_RollerRev <> 1 THEN
        bRollerRun := TRUE;
        bRollerRev := FALSE;
        host_Send_RollerStart := 0;
    END_IF;
    IF host_Send_RollerRev = 1
       AND host_Send_RollerStop <> 1 AND host_Send_RollerStart <> 1 THEN
        bRollerRev := TRUE;
        bRollerRun := FALSE;
        host_Send_RollerRev := 0;
    END_IF;
    IF host_Send_RollerStop = 1 THEN
        bRollerRun := FALSE;
        bRollerRev := FALSE;
        host_Send_RollerStop := 0;
    END_IF;
ELSE
    (* 非自动位: 清运行记忆量(防切回自动位自恢复) + 拒绝命令并清字回执 *)
    bRollerRun := FALSE;
    bRollerRev := FALSE;
    IF host_Send_RollerStart = 1 THEN host_Send_RollerStart := 0; END_IF;
    IF host_Send_RollerStop = 1 THEN host_Send_RollerStop := 0; END_IF;
    IF host_Send_RollerRev = 1 THEN host_Send_RollerRev := 0; END_IF;
END_IF;

(* ── 阀命令: 升/降触发式 互斥; 置 con_CylCmd 由 SBR_05 执行, 到位看状态区 ── *)
IF bRemoteEn THEN
    IF host_Send_CylUp = 1 AND host_Send_CylDn <> 1 THEN
        con_CylCmd := 1;
        host_Send_CylUp := 0;
    END_IF;
    IF host_Send_CylDn = 1 THEN
        con_CylCmd := 2;
        host_Send_CylDn := 0;
    END_IF;
ELSE
    (* 非自动位: 拒绝阀命令并清字回执 *)
    IF host_Send_CylUp = 1 THEN host_Send_CylUp := 0; END_IF;
    IF host_Send_CylDn = 1 THEN host_Send_CylDn := 0; END_IF;
END_IF;

(* ── 驱动器故障复位: 触发式 置边沿 由 SBR_exec 输出脉冲后清0回执 ── *)
r_DrvReset(CLK := (host_Send_DrvReset = 1) AND bRemoteEn);
IF r_DrvReset.Q THEN
    host_Send_DrvReset := 0;
END_IF;

(* ── 远程复位命令: SBR_03 已消费边沿 此处清0回执 ── *)
IF r_HostReset.Q THEN
    host_Send_EstopReset := 0;
END_IF;

(* ── 速度设定: 电平缓存式 上位机写目标值 PLC经RS485转发(见SBR_rtu) ── *)
con_SpeedTarget := host_Send_RollerSpeed;

(* ── 状态区回写 (INT 化显式转换) ── *)
host_Rcv_Mode    := SEL(bModeAuto, 0, 1);
host_Rcv_Estop   := SEL(Latch_Estop.AlarmOut, 0, 1);
host_Rcv_Ready   := SEL(bRunOK, 0, 1);
host_Rcv_Running := SEL(Roller_1.FwdOut, 0, 1);   (* 正转端子实际输出 *)
host_Rcv_RevRun  := SEL(Roller_1.RevOut, 0, 1);   (* 反转端子实际输出 *)
host_Rcv_CylUp   := SEL(in_CylUpSns, 0, 1);
host_Rcv_CylDn   := SEL(in_CylDnSns, 0, 1);
host_Rcv_AlmCyl  := SEL(Latch_Cyl.AlarmOut, 0, 1);
host_Rcv_SnsPos1 := SEL(in_Pos1Sns, 0, 1);
host_Rcv_SnsPos2 := SEL(in_Pos2Sns, 0, 1);
host_Rcv_SnsPos3 := SEL(in_Pos3Sns, 0, 1);
host_Rcv_Speed   := con_SpeedTarget;
host_Rcv_HeartOut := con_HeartOut;
