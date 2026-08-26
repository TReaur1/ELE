(* ════════════════════════════════════════════════════════════════════
   SBR_05 命令执行
   远程控制允许计算 + 双电控阀输出控制(保持至磁开到位/TONR超时报警)
   + 三色灯蜂鸣 + 驱动器CLR复位端子脉冲(TONR直调)
   ════════════════════════════════════════════════════════════════════ *)

(* 远程控制允许: 运行许可 且 旋钮在自动位 (手动位=本地安全待机 输出全断) *)
bRemoteEn := bRunOK AND bModeAuto;

(* ── 阀输出控制: 命令后线圈保持输出 直至磁开到位确认;
      悬挂未到位期间 TONR 计时, CYL_TIMEOUT 到 -> con_CylTimeout -> 锁存闭环 ── *)
bCylUpOn := FALSE;
bCylDnOn := FALSE;
bCylPending := FALSE;
IF NOT bRemoteEn THEN
    con_CylCmd := 0;
END_IF;

IF bRemoteEn AND con_CylCmd = 1 THEN
    IF in_CylUpSns THEN
        con_CylCmd := 0;            (* 已到位: 结束命令 记忆阀位 *)
        bCylPos := 1;
    ELSE
        bCylUpOn := TRUE;           (* 未到位: 保持输出 悬挂计时 *)
        bCylPending := TRUE;
    END_IF;
ELSIF bRemoteEn AND con_CylCmd = 2 THEN
    IF in_CylDnSns THEN
        con_CylCmd := 0;
        bCylPos := 2;
    ELSE
        bCylDnOn := TRUE;
        bCylPending := TRUE;
    END_IF;
END_IF;

(* 气缸到位看门狗: TONR 直调(悬挂计时 到位/无命令自动清) *)
TONR(IN := bCylPending,
     PT := CYL_TIMEOUT,
     Q  => bCylWatchQ);
con_CylTimeout := bCylPending AND bCylWatchQ;   (* 超时源 -> Latch_Cyl 锁存闭环 *)



(* ── C20 CLR复位端子: 远程命令触发 DRV_RST_PULSE 脉冲 (TONR直调) ── *)
bDrvRstPulse := FALSE;
IF r_DrvReset.Q THEN
    bDrvRstHold := TRUE;
END_IF;
TONR(IN := bDrvRstHold,
     PT := DRV_RST_PULSE,
     Q  => bDrvRstEnd);
bDrvRstPulse := bDrvRstHold AND (NOT bDrvRstEnd);
IF bDrvRstEnd THEN
    bDrvRstHold := FALSE;       (* IN 断开后 Q 自动回 OFF *)
END_IF;
