(* ════════════════════════════════════════════════════════════════════
   SBR_04 模式管理 - virtual_project (原型: host_driven)
   手动/自动互斥, 切换检测, 清零
   ════════════════════════════════════════════════════════════════════ *)

(* 模式互斥: 手动/自动 *)
con_ManualEnable := in_Manual AND NOT con_AutoEnable;
con_AutoEnable   := in_Auto   AND NOT con_ManualEnable;

(* 切换检测: 边沿 *)
con_ModeChanged := (con_AutoEnable XOR con_ManualEnable) AND NOT con_Mode_Prev;
con_Mode_Prev   := con_AutoEnable OR con_ManualEnable;