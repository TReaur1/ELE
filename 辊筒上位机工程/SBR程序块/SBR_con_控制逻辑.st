(* ════════════════════════════════════════════════════════════════════
   SBR_con 控制逻辑 —— 四模块架构·控制层 (逻辑层最先执行)
   ════════════════════════════════════════════════════════════════════
   职责: 安全锁存 / 模式管理 / 远程许可 / 阀与辊筒控制 / 输出逻辑量。
   依赖: io 层输入映像(本周期); host 层命令记忆量(上一周期, 触发式无碍);
         host 层通讯状态 con_CommLost(上一周期)。
   产出: out_* 控制类逻辑量(经 bRemoteEn 门控) + 安全状态量。
   心跳看门狗检测在 SBR_host(通讯事务), 本块仅消费 con_CommLost。

   辊筒映射控制链(PLC控制辊筒):
     host命令字 --SBR_host--> bRollerRun/bRollerRev
     --本块FB调用--> Roller_1.FwdOut/RevOut --> out_RollerFwd/Rev
     --SBR_io 输出映像--> Y10/Y11 (端子FWD/REV启停 速度走RS485见SBR_host)
   ════════════════════════════════════════════════════════════════════ *)

(* ═══ 段1 安全回路 ════════════════════════════════════════════════
   急停语义: in_eStop=TRUE 为释放(安全) 取反得按下状态 *)
bEstopPressed := NOT in_eStop;

(* 复位边沿: 本地按钮 + 上位机急停复位命令 并联 (边沿时序由R_TRIG内部保证) *)
r_ResetBtn(CLK := in_Reset);
r_HostReset(CLK := (host_Send_EstopReset = 1));
con_ResetCmd := r_ResetBtn.Q OR r_HostReset.Q;

(* 急停锁存: 按下置位; 解除需 急停已物理释放+复位边沿 (锁存闭环) *)
Latch_Estop(FaultSrc := bEstopPressed,
            ResetCmd  := con_ResetCmd AND (NOT bEstopPressed));

(* 气缸到位超时锁存: 超时源由本块段4置位 此处锁存闭环 *)
Latch_Cyl(FaultSrc := con_CylTimeout,
          ResetCmd  := con_ResetCmd AND (NOT con_CylTimeout));

(* 全局运行许可: 无急停锁存 且 无气缸超时锁存 且 通讯正常 *)
bRunOK := Latch_Estop.AlarmOut = FALSE
      AND Latch_Cyl.AlarmOut = FALSE
      AND con_CommLost = FALSE;

(* ═══ 段2 模式管理 ════════════════════════════════════════════════
   手自动旋钮: 自动位(TRUE)=上位机远程命令生效; 手动位=本地安全待机(输出全断)
   纯上位机控制工程无本地动作机构 手动位即维修/调试安全态 (互斥) *)
bModeAuto := in_ModeAuto;

(* ═══ 段3 远程控制允许 ════════════════════════════════════════════
   运行许可 且 旋钮在自动位 (手动位=本地安全待机 输出全断) *)
bRemoteEn := bRunOK AND bModeAuto;

(* ═══ 段4 阀输出控制 ══════════════════════════════════════════════
   命令后线圈保持输出 直至磁开到位确认;
   悬挂未到位期间 TONR 计时, CYL_TIMEOUT 到 -> con_CylTimeout -> 锁存闭环 *)
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

(* ═══ 段5 驱动器CLR复位端子脉冲 ══════════════════════════════════
   远程命令触发(SBR_host 边沿) DRV_RST_PULSE 脉冲 (TONR直调) *)
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

(* ═══ 段6 辊筒 FB 调用 ════════════════════════════════════════════
   双向端子控制(FWD/REV互锁), 速度经RS485设定(SBR_host) *)
Roller_1(FwdInput   := bRollerRun,
         RevInput   := bRollerRev,
         SpeedLevel := 1,
         SpeedLow   := 100,
         SpeedMid   := 75,
         SpeedHigh  := 50,
         Enable     := bRemoteEn,
         Reset      := con_ResetCmd);

(* ═══ 段7 控制类输出逻辑量 ════════════════════════════════════════
   显式默认 FALSE 无许可强制安全态 (细则13);
   指示类输出(三色灯/蜂鸣)归 SBR_status *)
out_AutoModeSw  := FALSE;
out_CylUp       := FALSE;
out_CylDn       := FALSE;
out_RollerFwd   := FALSE;
out_RollerRev   := FALSE;
out_RollerRst   := FALSE;

IF bRemoteEn THEN
    out_CylUp     := bCylUpOn;        (* 保持至升到位磁开 *)
    out_CylDn     := bCylDnOn;        (* 保持至降到位磁开 *)
    out_RollerFwd := Roller_1.FwdOut;
    out_RollerRev := Roller_1.RevOut;
END_IF;

(* 手自动切换继电器: 跟随旋钮状态输出(外部回路切换用) *)
out_AutoModeSw := bModeAuto;

(* C20 CLR复位端子: 远程命令脉冲(不受许可门控 故障恢复通道) *)
out_RollerRst := bDrvRstPulse;

(* ═══ 段8 自动控制 (本工程占位) ══════════════════════════════════
   本工程为纯上位机控制(host_driven) 无自动工步序列;
   全部动作由上位机命令驱动, 见 SBR_host 与本块段4/段6。
   若日后增加自动节拍, 在此扩展 CASE 步进状态机。 *)
