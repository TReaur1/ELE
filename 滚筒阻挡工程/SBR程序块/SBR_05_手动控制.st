(* ════════════════════════════════════════════════════════════════════
   SBR_05 手动控制
   手动模式: 本地复位键翻转阻挡 + 上位机远程命令(通讯字表 写区)
   优先级: 远程命令 > 本地按键; 通讯丢失时远程命令失效 (细则9)
   与 SBR_06 自动控制按 bModeAuto 互斥, 每周期只有一方写命令量 (细则7)
   ════════════════════════════════════════════════════════════════════ *)
IF (NOT bModeAuto) AND bRunOK THEN
    (* ── 滚筒: 远程正转/停止 (写1触发, 停止优先; 无远程命令时保持停) ── *)
    IF con_CommLost THEN
        con_RollerRunCmd := FALSE;
    ELSIF host_Send_RollerStop = 1 THEN
        con_RollerRunCmd := FALSE;
    ELSIF host_Send_RollerFwd = 1 THEN
        con_RollerRunCmd := TRUE;
    ELSE
        con_RollerRunCmd := FALSE;
    END_IF;

    (* ── 阻挡: 远程升/降优先, 无远程命令时本地复位键翻转仍可用 ── *)
    IF con_CommLost THEN
        con_BlockUpCmd := FALSE;
    ELSIF host_Send_BlockUp = 1 THEN
        con_BlockUpCmd := TRUE;
    ELSIF host_Send_BlockDn = 1 THEN
        con_BlockUpCmd := FALSE;
    ELSE
        r_ManBlock(CLK := in_Reset);
        IF r_ManBlock.Q THEN
            bManBlockTgl := NOT bManBlockTgl;
        END_IF;
        con_BlockUpCmd := bManBlockTgl;
    END_IF;
ELSE
    bManBlockTgl := FALSE;
END_IF;

