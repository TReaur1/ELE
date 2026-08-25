(* ════════════════════════════════════════════════════════════════════
   SBR_host 上位机通讯 (Modbus TCP, 字表见 通讯字表.csv)
   状态映射回写 + 命令清0回执 + 双心跳看门狗 (心跳入/出向分离 细则9)
   ════════════════════════════════════════════════════════════════════ *)

(* ── 入向心跳: 变化检测 -> 看门狗; 超时判通讯丢失 (接 RunOK 联锁) ── *)
IF host_Send_Heart <> con_HeartPrev THEN
    con_HeartPrev := host_Send_Heart;        (* 检测到变化: 复位看门狗输入 *)
END_IF;
ton_CommWatch(IN := NOT (host_Send_Heart <> con_HeartPrev), PT := COMM_HEART_TIMEOUT);
IF ton_CommWatch.Q THEN
    con_CommLost := TRUE;                    (* 超时未变化 -> 通讯丢失 *)
ELSE
    con_CommLost := FALSE;
END_IF;

(* ── 出向心跳: 每 COMM_HEART_TICK 自增1 写回上位机 (PLC存活示警) ── *)
ton_HeartTick(IN := TRUE, PT := COMM_HEART_TICK);
IF ton_HeartTick.Q THEN
    con_HeartOut := con_HeartOut + 1;
END_IF;

(* ── 命令清0回执协议: 动作确认后由 PLC 清零命令字, 防重复触发 ──
   阻挡升降: 到位(磁开)即清 | 报警复位: 边沿消费后清 | 滚筒停止: 停稳后清 *)
IF in_BlockUpSns AND (host_Send_BlockUp = 1) THEN
    host_Send_BlockUp := 0;
END_IF;
IF in_BlockDnSns AND (host_Send_BlockDn = 1) THEN
    host_Send_BlockDn := 0;
END_IF;
IF r_HostReset.Q THEN
    host_Send_AlarmReset := 0;
END_IF;
IF (host_Send_RollerStop = 1) AND (NOT Roller_1.FwdOut) THEN
    host_Send_RollerStop := 0;
END_IF;

(* ── 状态区回写 (INT 化, BOOL->0/1 显式转换) ── *)
host_Rcv_Mode     := SEL(bModeAuto, 0, 1);
host_Rcv_Estop    := SEL(bEstopPressed, 0, 1);
host_Rcv_Alarm    := SEL(con_Alarm, 0, 1);
host_Rcv_Running  := SEL(Roller_1.FwdOut, 0, 1);
host_Rcv_BlockUp  := SEL(in_BlockUpSns, 0, 1);
host_Rcv_AutoStep := con_AutoStep;
host_Rcv_CycleCnt := con_CycleCnt;
host_Rcv_HeartOut := con_HeartOut;
