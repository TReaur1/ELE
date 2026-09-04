(* ════════════════════════════════════════════════════════════════════
   SBR_status 状态呈现 - demo_seq
   职责: 对外呈现 (AGENTS 四模块·状态层, v2.0.0 新增):
     上位机状态区回写 —— 上报实际状态而非命令回声 (主调度最后执行)
   范围(v2.0.0 定稿): 最小集 = 通用四项(报警字/模式/就绪/通讯健康);
     每轴 Position/StateMachine/MoveDone 寄存器为"预留未回写",
     接工艺时在本块按 host_Rcv_<轴>_* 逐项补真实值映射。
   报警字回写: DINT->INT 须 TO_INT 显式转换 (位定义限于 bit0~15, 细则R4)
   ════════════════════════════════════════════════════════════════════ *)
(* 通讯健康三态 (细则18): COMMST_NORMAL/DEGRADED/LOST *)
host_Rcv_CommState := COMMST_NORMAL;
IF con_CommDegraded THEN
    host_Rcv_CommState := COMMST_DEGRADED;
END_IF;
IF con_CommLost THEN
    host_Rcv_CommState := COMMST_LOST;
END_IF;