(* ════════════════════════════════════════════════════════════════════
   SBR_03 安全回路 (主调度 STEP1 最先执行)
   急停状态 + 报警锁存闭环 + 全局运行许可 RunOK
   ════════════════════════════════════════════════════════════════════ *)

(* 急停语义: in_eStop=TRUE 为释放(安全), 取反得按下状态 *)
bEstopPressed := NOT in_eStop;

(* 复位按钮上升沿: R_TRIG 内部完成 读旧值->判变化->更新 时序 (细则6) *)
r_ResetBtn(CLK := in_Reset);

(* 远程复位: 上位机命令字 =1 为真, 经 R_TRIG 取边沿 (与本地复位并联) *)
r_HostReset(CLK := (host_Send_AlarmReset = 1));
con_ResetCmd := r_ResetBtn.Q OR r_HostReset.Q;

(* 气缸超时检测 -> 接入锁存闭环 (置位->锁存->许可 细则2, 检测结果不允许只写不读) *)
Latch_Alarm(FaultSrc := con_CylTimeout, ResetCmd := con_ResetCmd);
con_Alarm := Latch_Alarm.AlarmOut;

(* 全局运行许可: 急停OK 且 无锁存报警 且 通讯正常 (细则9: Modbus断开自动停) *)
bRunOK := (NOT bEstopPressed) AND (NOT con_Alarm) AND (NOT con_CommLost);
