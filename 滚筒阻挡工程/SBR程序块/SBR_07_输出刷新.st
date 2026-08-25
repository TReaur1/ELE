(* ════════════════════════════════════════════════════════════════════
   SBR_07 输出刷新 (主调度最后一步)
   辊筒 FB 调用 + 物理输出统一刷新: 先显式默认, 再经 RunOK 许可门控 (细则13/14)
   ════════════════════════════════════════════════════════════════════ *)

(* 滚筒 FB: 本工程单速正向, 三档速度经输入参数传入 (速度档不作 FB 内常量) *)
Roller_1(FwdInput   := con_RollerRunCmd,
         RevInput   := FALSE,
         SpeedLevel := 1,
         SpeedLow   := 100,
         SpeedMid   := 75,
         SpeedHigh  := 50,
         Enable     := bRunOK,
         Reset      := con_ResetCmd);

(* 物理输出刷新: 显式默认 FALSE, 无许可强制安全态 *)
out_RollerRun := FALSE;
out_BlockUp   := FALSE;
IF bRunOK THEN
    out_RollerRun := Roller_1.FwdOut;
    out_BlockUp   := con_BlockUpCmd;
END_IF;
