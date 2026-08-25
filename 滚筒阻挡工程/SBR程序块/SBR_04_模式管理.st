(* ════════════════════════════════════════════════════════════════════
   SBR_04 模式管理
   手自动旋钮电平采集 + 切换瞬间清零 (互斥 细则7, 边沿时序 细则6)
   ════════════════════════════════════════════════════════════════════ *)

(* 先比较后更新: 检测到模式切换 -> 清自动步/手动翻转/命令量, 防残留误动作 *)
IF bModeAuto <> in_ModeAuto THEN
    con_AutoStep      := 0;
    bManBlockTgl      := FALSE;
    con_BlockUpCmd    := FALSE;
    con_RollerRunCmd  := FALSE;
END_IF;

(* 模式电平: TRUE=自动 FALSE=手动 *)
bModeAuto := in_ModeAuto;
