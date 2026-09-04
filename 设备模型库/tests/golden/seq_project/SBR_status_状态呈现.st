(* ════════════════════════════════════════════════════════════════════
   SBR_status 状态呈现 - seq_project
   职责: 对外呈现 (AGENTS 四模块·状态层, v2.0.0 新增):
     上位机状态区回写 —— 上报实际状态而非命令回声 (主调度最后执行)
   范围(v2.0.0 定稿): 最小集 = 通用四项(报警字/模式/就绪/通讯健康);
     每轴 Position/StateMachine/MoveDone 寄存器为"预留未回写",
     接工艺时在本块按 host_Rcv_<轴>_* 逐项补真实值映射。
   报警字回写: DINT->INT 须 TO_INT 显式转换 (位定义限于 bit0~15, 细则R4)
   ════════════════════════════════════════════════════════════════════ *)
(* ═══ 报警索引: 当前最高优先级活跃报警编号 (0=无) ═══
   编号 = 活跃 bit 位序 + 1; 多报警同发时编号小者(位序低, 定义早)优先显示。
   触摸屏"文本列表"控件绑定 con_AlarmIndex, 汉字文本对照见 报警对照表.csv;
   HMI 报警历史/列表控件仍按 con_AlarmWord 位映射。 *)
con_AlarmIndex := 0;IF (con_AlarmWord AND ERRID_TIMEOUT) <> 0 THEN
    con_AlarmIndex := ERRIDX_TIMEOUT;
END_IF;IF (con_AlarmWord AND ERRID_COMM) <> 0 THEN
    con_AlarmIndex := ERRIDX_COMM;
END_IF;IF (con_AlarmWord AND ERRID_ESTOP) <> 0 THEN
    con_AlarmIndex := ERRIDX_ESTOP;
END_IF;
(* 报警字: con_AlarmWord 位编码 bit0~15 上报 (0=无报警) *)
host_Rcv_Alarm := TO_INT(con_AlarmWord);
(* 运行模式: 0=手动 1=自动 *)
IF con_AutoEnable THEN
    host_Rcv_Mode := 1;
ELSE
    host_Rcv_Mode := 0;
END_IF;
(* 通讯健康三态 (细则18): COMMST_NORMAL/DEGRADED/LOST *)
host_Rcv_CommState := COMMST_NORMAL;
IF con_CommDegraded THEN
    host_Rcv_CommState := COMMST_DEGRADED;
END_IF;
IF con_CommLost THEN
    host_Rcv_CommState := COMMST_LOST;
END_IF;