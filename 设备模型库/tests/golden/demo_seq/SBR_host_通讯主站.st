(* ════════════════════════════════════════════════════════════════════
   SBR_host 通讯主站 - demo_seq
   职责: 通讯事务全归本块 (AGENTS 四模块·通讯层, v2.0.0 新增):
     段1 入向心跳三级看门狗 (降级冻结/失联断讯 细则18)
     段2 出向心跳周期自增 (独立寄存器 禁止回显入向 细则18)
     段3 通讯恢复沿: 清防重放序号记忆 (细则15)
     段4 急停命令注销: 断使能+清命令记忆 (细则13)
   依赖: con 层 con_EstopActive (安全层先于本块执行)
   被依赖: con_CommDegraded/con_CommLost 由 05/06 命令门控消费;
           con_CommLost 由安全层 RunOK 联锁消费
   超时分层: 通讯域 WATCHDOG 系列 与设备域 TIMEOUT_AXIS_MOVE 分开定值 (细则17)
   ════════════════════════════════════════════════════════════════════ *)

(* ═══ 段1 入向心跳三级看门狗 ════════════════════════════════════
      心跳变化判在线 (TONR直调 变化拍复位计时):
      静默超 WATCHDOG_DEGRADED -> con_CommDegraded (冻结新命令 已锁存动作继续)
      静默超 WATCHDOG_TIMEOUT  -> con_CommLost    (RunOK=0 显式安全停)
      心跳恢复自动解除; 降级不杀运行许可 仅冻结新命令受理 *)
TONR(IN := host_Rcv_Heart = con_Heart_Prev, PT := WATCHDOG_DEGRADED,
     R := host_Rcv_Heart <> con_Heart_Prev, Q => con_CommDegraded);
TONR(IN := host_Rcv_Heart = con_Heart_Prev, PT := WATCHDOG_TIMEOUT,
     R := host_Rcv_Heart <> con_Heart_Prev, Q => con_CommLost);
con_Heart_Prev := host_Rcv_Heart;

(* ═══ 段2 出向心跳: 周期自增 (R 复位自翻转 每周期一个扫描脉冲) ═══ *)
TONR(IN := TRUE, PT := HEART_PERIOD, R := con_HeartQ, Q => con_HeartQ);
IF con_HeartQ THEN
    con_Heart_Counter := con_Heart_Counter + 1;
END_IF;
host_Send_Heart := con_Heart_Counter;

(* ═══ 段3 通讯恢复沿: 清防重放序号记忆 ══════════════════════════
      防上位机重启后序号回绕导致命令被永久拒绝 (细则15) *)
r_CommLostF(CLK := con_CommLost);
IF r_CommLostF.Q THEN
    con_LastCmdSeq := -1;      (* -1 = 任意序号均可受理 *)
END_IF;

(* ═══ 段4 急停命令注销 (细则13): 断使能 + 清全部命令记忆位 ══════
      语义(v2.0.0 定稿): 安全转矩off + 命令不自恢复;
      悬停类负载如需"保使能受控停", 按现场将 PowerEnable 行改为置 Stop 命令;
      重新使能通道需人工/上位机显式接线, 不随急停复位自动恢复 *)IF con_EstopActive THEN
    M1_Cross_Cmd.PowerEnable := FALSE;
    M1_Cross_Cmd.Absolute_Execute := FALSE;
    M1_Cross_Cmd.Home := FALSE;
    M1_Cross_Cmd.JogForward := FALSE;
    M1_Cross_Cmd.JogBackward := FALSE;
END_IF;IF con_EstopActive THEN
    M2_Lift_Cmd.PowerEnable := FALSE;
    M2_Lift_Cmd.Absolute_Execute := FALSE;
    M2_Lift_Cmd.Home := FALSE;
    M2_Lift_Cmd.JogForward := FALSE;
    M2_Lift_Cmd.JogBackward := FALSE;
END_IF;
(* 夹爪 步进: 手动/自动记忆清零 (急停注销) *)
IF con_EstopActive THEN
    Stepper_Gripper.AutoForward := FALSE;
    Stepper_Gripper.AutoBackward := FALSE;
END_IF;