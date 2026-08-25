(* ════════════════════════════════════════════════════════════════════
   SBR_06 自动控制 (步进状态机)
   步0 待机启动 -> 步1 阻挡输送(定时+磁开确认) -> 步2 放行(定时+磁开确认) -> 回步1
   气缸到位看门狗: 超时未到位 -> con_CylTimeout 接报警锁存闭环
   与 SBR_05 按 bModeAuto 互斥; 非自动/许可丢失时显式切断全部命令 (细则13)
   ════════════════════════════════════════════════════════════════════ *)
IF bModeAuto AND bRunOK THEN
    CASE con_AutoStep OF
        0:  (* 待机: 滚筒先转, 进入输送节拍 *)
            con_BlockUpCmd   := FALSE;
            con_RollerRunCmd := TRUE;
            con_AutoStep     := 1;

        1:  (* 阻挡输送: 升阻挡截停工件, 滚筒持续 *)
            con_BlockUpCmd   := TRUE;
            con_RollerRunCmd := TRUE;
            ton_BlockHold(IN := TRUE, PT := BLOCK_HOLD_TIME);
            ton_CylWatch(IN  := TRUE, PT := CYL_TIMEOUT);
            IF ton_CylWatch.Q AND (NOT in_BlockUpSns) THEN
                con_CylTimeout := TRUE;      (* 升不到位 -> 报警源, 锁存于安全回路 *)
            END_IF;
            IF in_BlockUpSns AND ton_BlockHold.Q THEN
                con_AutoStep := 2;           (* 磁开确认 + 保持时间到 -> 放行 *)
                ton_BlockHold(IN := FALSE, PT := BLOCK_HOLD_TIME);
                ton_CylWatch(IN  := FALSE, PT := CYL_TIMEOUT);
            END_IF;

        2:  (* 放行: 降阻挡放行工件, 滚筒持续 *)
            con_BlockUpCmd   := FALSE;
            con_RollerRunCmd := TRUE;
            ton_PassTime(IN  := TRUE, PT := BLOCK_PASS_TIME);
            ton_CylWatch(IN  := TRUE, PT := CYL_TIMEOUT);
            IF ton_CylWatch.Q AND (NOT in_BlockDnSns) THEN
                con_CylTimeout := TRUE;      (* 降不到位 -> 报警源 *)
            END_IF;
            IF in_BlockDnSns AND ton_PassTime.Q THEN
                con_AutoStep := 1;           (* 磁开确认 + 放行时间到 -> 下一节拍 *)
                con_CycleCnt := con_CycleCnt + 1;   (* 完成一次放行: 节拍计数+1(掉电保持) *)
                ton_PassTime(IN := FALSE, PT := BLOCK_PASS_TIME);
                ton_CylWatch(IN  := FALSE, PT := CYL_TIMEOUT);
            END_IF;

        ELSE
            con_AutoStep := 0;               (* 非法步号兜底回待机 *)
    END_CASE;
ELSE
    (* 显式安全切断: 手动模式/急停/报警/许可丢失 -> 全部命令清零+计时器复位 (细则13) *)
    con_AutoStep     := 0;
    con_BlockUpCmd   := FALSE;
    con_RollerRunCmd := FALSE;
    con_CylTimeout   := FALSE;
    ton_BlockHold(IN := FALSE, PT := BLOCK_HOLD_TIME);
    ton_PassTime(IN  := FALSE, PT := BLOCK_PASS_TIME);
    ton_CylWatch(IN  := FALSE, PT := CYL_TIMEOUT);
END_IF;
