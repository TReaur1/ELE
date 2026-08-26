(* ════════════════════════════════════════════════════════════════════
   SBR_03 安全回路 (主调度最先执行)
   急停锁存闭环 + 通讯联锁(TONR看门狗直调) + 全局运行许可 RunOK
   ════════════════════════════════════════════════════════════════════ *)

(* 急停语义: in_eStop=TRUE 为释放(安全) 取反得按下状态 *)
bEstopPressed := NOT in_eStop;

(* 复位边沿: 本地按钮 + 上位机急停复位命令 并联 (细则6 边沿时序由R_TRIG内部保证) *)
r_ResetBtn(CLK := in_Reset);
r_HostReset(CLK := (host_Send_EstopReset = 1));
con_ResetCmd := r_ResetBtn.Q OR r_HostReset.Q;

(* 急停锁存: 按下置位; 解除需 急停已物理释放+复位边沿 (细则2 锁存闭环) *)
Latch_Estop(FaultSrc := bEstopPressed,
            ResetCmd  := con_ResetCmd AND (NOT bEstopPressed));

(* ── 入向心跳看门狗: TONR 直调(不命名实例 细则5)
      变化拍断 IN 重启计时; 无变化持续计时 满 TIMEOUT 置断讯, 心跳恢复自动解除 ── *)
bHeartChanged := host_Send_Heart <> con_HeartPrev;
IF bHeartChanged THEN
    con_HeartPrev := host_Send_Heart;
END_IF;
IF bHeartChanged THEN
    bHeartTiming := FALSE;
ELSE
    bHeartTiming := TRUE;
END_IF;
TONR(IN := bHeartTiming,
     PT := COMM_HEART_TIMEOUT,
     Q  => con_CommLost);

(* 气缸到位超时锁存: 超时源由 SBR_05 置位 此处锁存 (细则2 闭环) *)
Latch_Cyl(FaultSrc := con_CylTimeout,
          ResetCmd  := con_ResetCmd AND (NOT con_CylTimeout));

(* 全局运行许可: 无急停锁存 且 无气缸超时锁存 且 通讯正常 *)
bRunOK := Latch_Estop.AlarmOut = FALSE
      AND Latch_Cyl.AlarmOut = FALSE
      AND con_CommLost = FALSE;
