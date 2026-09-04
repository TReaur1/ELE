(* ════════════════════════════════════════════════════════════════════
   SBR_io IO 映射 —— 四模块架构·物理层
   ════════════════════════════════════════════════════════════════════
   职责: 物理点 <-> 逻辑量 纯透传映射, 不含任何控制逻辑。
   io 表变量不直接绑定地址, 地址对照以本块为唯一真源。
   主调度最先执行: 输入映像取本周期新值;
   输出映像透传上一周期 con/status 门控完成的逻辑量(纯透传无中间态)。

   滤波: X0 急停最短滤波/直通(安全响应最快); 其余内置滤波约10ms。
   硬件: 本体 X0~X7; 输出扩展模块 Y10~Y13(继电器型)。

   输入地址对照:
     X0 in_eStop     急停按钮 常闭(TRUE=释放)
     X1 in_Reset     复位按钮 常开
     X2 in_ModeAuto  手自动旋钮 常开(TRUE=自动位)
     X3 in_Pos1Sns   位置检测1 光电 进料段
     X4 in_Pos2Sns   位置检测2 光电 中段
     X5 in_Pos3Sns   位置检测3 光电 出料段
     X6 in_CylUpSns  阻挡升到位磁开
     X7 in_CylDnSns  阻挡降到位磁开
   ════════════════════════════════════════════════════════════════════ *)

(* ── 输入映像: 物理输入 -> 逻辑变量 ── *)
in_eStop    := X0;
in_Reset    := X1;
in_ModeAuto := X2;
in_Pos1Sns  := X3;
in_Pos2Sns  := X4;
in_Pos3Sns  := X5;
in_CylUpSns := X6;
in_CylDnSns := X7;

(* ═══ 输出映像: 逻辑量 -> 物理输出 (地址对照唯一真源) ═══
      Y0  out_LampYellow 三色灯黄(手动)          ┐ 本体
      Y1  out_LampGreen  三色灯绿(自动)          │
      Y2  out_LampRed    三色灯红(报警)          │
      Y3  out_Buzzer     蜂鸣器                  │
      Y4  out_AutoModeSw 手自动切换继电器        │
      Y5  out_CylValve   阀线圈(单电控 得电=升)  ┘
      Y10 out_RollerFwd  C20正转FWD  ┐ 扩展输出模块
      Y11 out_RollerRev  C20反转REV  │ (8点继电器型)
      Y12 out_RollerRst  C20复位CLR  ┘ 断FWD/REV即停机 ═══ *)
Y0  := out_LampYellow;
Y1  := out_LampGreen;
Y2  := out_LampRed;
Y3  := out_Buzzer;
Y4  := out_AutoModeSw;
Y5  := out_CylValve;
Y10 := out_RollerFwd;
Y11 := out_RollerRev;
Y12 := out_RollerRst;
