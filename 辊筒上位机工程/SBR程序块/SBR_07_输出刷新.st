(* ════════════════════════════════════════════════════════════════════
   SBR_07 输出刷新 (主调度最后一步)
   辊筒双向 FB 调用(端子FWD/REV启停 速度走RS485见SBR_rtu)
   + 三色灯 + 手自动切换继电器 + C20 CLR复位端子
   末段统一输出映像(汇川 ST 显式映射 Yn := 逻辑量)
   ════════════════════════════════════════════════════════════════════ *)

(* 辊筒 FB: 双向端子控制(FWD/REV互锁), 速度经RS485设定(SBR_rtu) *)
Roller_1(FwdInput   := bRollerRun,
         RevInput   := bRollerRev,
         SpeedLevel := 1,
         SpeedLow   := 100,
         SpeedMid   := 75,
         SpeedHigh  := 50,
         Enable     := bRemoteEn,
         Reset      := con_ResetCmd);

(* ── 逻辑量刷新: 显式默认 FALSE 无许可强制安全态 (细则13) ── *)
out_LampYellow  := FALSE;
out_LampGreen   := FALSE;
out_LampRed     := FALSE;
out_Buzzer      := FALSE;
out_AutoModeSw  := FALSE;
out_CylUp       := FALSE;
out_CylDn       := FALSE;
out_RollerFwd   := FALSE;
out_RollerRev   := FALSE;
out_RollerRst   := FALSE;

(* 三色灯蜂鸣: 报警随动 无需许可门控(报警指示必须可见 细则1) *)
out_LampRed    := Tower_1.LightRed;
out_LampYellow := Tower_1.LightYellow;
out_LampGreen  := Tower_1.LightGreen;
out_Buzzer     := Tower_1.Buzzer;

IF bRemoteEn THEN
    out_CylUp     := bCylUpOn;        (* 保持至升到位磁开 *)
    out_CylDn     := bCylDnOn;        (* 保持至降到位磁开 *)
    out_RollerFwd := Roller_1.FwdOut;
    out_RollerRev := Roller_1.RevOut;
END_IF;

(* 手自动切换继电器: 跟随旋钮状态输出(外部回路切换用) *)
out_AutoModeSw := bModeAuto;

(* C20 CLR复位端子: 远程命令脉冲(不受许可门控 故障恢复通道) *)
out_RollerRst := bDrvRstPulse;

(* ═══ 输出映像: 逻辑量 -> 物理输出 (地址对照唯一真源) ═══
     Y0  out_LampYellow 三色灯黄(手动)          ┐ 本体
     Y1  out_LampGreen  三色灯绿(自动)          │
     Y2  out_LampRed    三色灯红(报警)          │
     Y3  out_Buzzer     蜂鸣器                  │
     Y4  out_AutoModeSw 手自动切换继电器        │
     Y5  out_CylUp      阀升线圈                │
     Y6  out_CylDn      阀降线圈                ┘
     Y10 out_RollerFwd  C20正转FWD  ┐ 扩展输出模块
     Y11 out_RollerRev  C20反转REV  │ (8点继电器型)
     Y12 out_RollerRst  C20复位CLR  ┘ 断FWD/REV即停机 ══ *)
Y0  := out_LampYellow;
Y1  := out_LampGreen;
Y2  := out_LampRed;
Y3  := out_Buzzer;
Y4  := out_AutoModeSw;
Y5  := out_CylUp;
Y6  := out_CylDn;
Y10 := out_RollerFwd;
Y11 := out_RollerRev;
Y12 := out_RollerRst;
