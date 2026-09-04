(* ════════════════════════════════════════════════════════════════════
   SBR_04 模式管理 - demo_seq (原型: internal_seq)
   手动/自动互斥 + 自动子态(回零/单步/连续) + 启动/停止/步进控制
   ════════════════════════════════════════════════════════════════════ *)

(* 模式互斥: 手动/自动 *)
con_ManualEnable := in_Manual AND NOT con_AutoEnable;
con_AutoEnable   := in_Auto   AND NOT con_ManualEnable;

(* 切换检测: 边沿 *)
con_ModeChanged := (con_AutoEnable XOR con_ManualEnable) AND NOT con_Mode_Prev;
con_Mode_Prev   := con_AutoEnable OR con_ManualEnable;

(* 自动子态 (非标准工艺, 人工按需调整): 回零/单步/连续 *)
(* 无线适应: 启动/回零命令经防重放序号门控 + 降级冻结; 停止命令永不拦截 *)
con_Step_Init := con_AutoEnable AND host_Send_Home AND (host_Send_CmdSeq <> con_LastCmdSeq)
    AND NOT con_CommDegraded AND NOT con_EstopActive AND NOT con_StepRun;
con_Start     := con_AutoEnable AND host_Send_Start AND (host_Send_CmdSeq <> con_LastCmdSeq)
    AND NOT con_CommDegraded AND NOT con_EstopActive AND NOT con_StepRun;
con_Stop      := NOT con_AutoEnable OR host_Send_Stop;
IF con_Start OR con_Step_Init THEN
    con_LastCmdSeq := host_Send_CmdSeq;   (* 受理即记忆序号, 同序号重发不二次触发 *)
END_IF;