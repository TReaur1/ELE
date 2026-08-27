(* ════════════════════════════════════════════════════════════════════
   SBR_status 状态呈现 —— 四模块架构·状态层 (主调度最后执行)
   ════════════════════════════════════════════════════════════════════
   职责: 对外呈现 PLC 当前状态 ——
     段1 三色灯+蜂鸣 FB (优先级 故障 > 自动 > 手动)
     段2 指示类输出逻辑量 (out_Lamp*/out_Buzzer)
     段3 上位机状态区回写 (host_Rcv_* 上报实际输出而非命令回声)
   依赖: con 层本周期结果(RunOK/锁存/Roller_1实际输出) +
         host 层本周期通讯量(con_SpeedTarget/con_HeartOut)。

   报警指示不受许可门控: 报警必须可见 (细则1)
   ════════════════════════════════════════════════════════════════════ *)

(* ═══ 段1 三色灯蜂鸣 FB: 优先级 故障 > 自动 > 手动 ═══ *)
Tower_1(Fault      := Latch_Estop.AlarmOut OR Latch_Cyl.AlarmOut OR con_CommLost,
        Auto       := bModeAuto,
        Manual     := NOT bModeAuto);

(* ═══ 段2 指示类输出逻辑量 (显式默认 FALSE 细则13) ═══ *)
out_LampYellow := FALSE;
out_LampGreen  := FALSE;
out_LampRed    := FALSE;
out_Buzzer     := FALSE;

out_LampRed    := Tower_1.LightRed;
out_LampYellow := Tower_1.LightYellow;
out_LampGreen  := Tower_1.LightGreen;
out_Buzzer     := Tower_1.Buzzer;

(* ═══ 段3 状态区回写 (INT 化显式转换; 上报实际输出) ═══ *)
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
