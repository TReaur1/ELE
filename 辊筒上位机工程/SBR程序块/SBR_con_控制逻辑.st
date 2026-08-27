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

(* 报警字汇编: 位编码 DINT (R4) 每 bit 一类报警 (报警机制第3环)
     LiteST 位运算字面量须用非十进制格式(2#) 禁十进制裸数字
     bit0(=2#0001) 急停锁存   bit1(=2#0010) 气缸到位超时锁存
     bit2(=2#0100) 通讯断讯(自动恢复随动上报)   预留 bit3+ 驱动器故障等
     位定义见 con 表 / 通讯字表 / 采集表06 注释 *)
con_AlarmWord := 0;
IF Latch_Estop.AlarmOut THEN con_AlarmWord := con_AlarmWord OR 2#0001; END_IF;
IF Latch_Cyl.AlarmOut   THEN con_AlarmWord := con_AlarmWord OR 2#0010; END_IF;
IF con_CommLost         THEN con_AlarmWord := con_AlarmWord OR 2#0100; END_IF;

(* 全局运行许可: 报警字为零才允许运行 (报警机制第4环 唯一真源) *)
bRunOK := (con_AlarmWord = 0);

(* 急停活跃标志: 按下或锁存活跃 -> 命令注销门控 (SBR_host 消费, 防释放复位后旧命令自恢复) *)
con_EstopActive := bEstopPressed OR Latch_Estop.AlarmOut;

(* ═══ 段2 模式管理 ════════════════════════════════════════════════
   手自动旋钮: 自动位(TRUE)=上位机远程命令生效; 手动位=本地安全待机(输出全断)
   纯上位机控制工程无本地动作机构 手动位即维修/调试安全态 (互斥) *)
bModeAuto := in_ModeAuto;

(* ═══ 段3 远程控制允许 ════════════════════════════════════════════
   运行许可 且 旋钮在自动位 (手动位=本地安全待机 输出全断) *)
bRemoteEn := bRunOK AND bModeAuto;

(* ═══ 段4 阀输出控制 (二位五通单电控) ══════════════════════════════
   单电控阀: 单线圈 得电=升(伸出) 失电=弹簧复位降(退回)
   无自保持 升位须持续得电维持; 降命令即失电弹簧回。
   命令 -> 阀状态锁存(bCylValveOn); 悬挂未到位 TONR 计时
   -> con_CylTimeout -> 锁存闭环 *)
IF NOT bRemoteEn THEN
    con_CylCmd  := 0;
    bCylValveOn := FALSE;          (* 无许可强制失电=降位(安全) *)
END_IF;

(* 命令 -> 阀状态: 升得电保持 降失电复位 *)
IF bRemoteEn AND con_CylCmd = 1 THEN
    bCylValveOn := TRUE;           (* 升: 得电 保持至降命令 *)
    con_CylCmd := 0;               (* 消费命令 *)
ELSIF bRemoteEn AND con_CylCmd = 2 THEN
    bCylValveOn := FALSE;          (* 降: 失电 弹簧复位 *)
    con_CylCmd := 0;
END_IF;

(* 到位判定 + 位置记忆 + 悬挂超时 *)
bCylPending := FALSE;
IF bCylValveOn THEN
    IF in_CylUpSns THEN
        bCylPos := 1;              (* 升到位 *)
    ELSE
        bCylPending := TRUE;       (* 升未到位 计时 *)
    END_IF;
ELSE
    IF in_CylDnSns THEN
        bCylPos := 2;              (* 降到位 *)
    ELSE
        bCylPending := TRUE;       (* 降未到位 计时 *)
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
out_CylValve    := FALSE;
out_RollerFwd   := FALSE;
out_RollerRev   := FALSE;
out_RollerRst   := FALSE;

IF bRemoteEn THEN
    out_CylValve  := bCylValveOn;      (* 单电控: 得电保持升位 *)
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
(* ═══ 段9 点动控制 (预留 暂不使用 注释掉) ══════════════════════════════
   功能: 触摸屏点动辊筒(正/反) + 触摸屏点动气缸(升/降) + 手动按钮点动辊筒
   模式: 仅手动位生效(NOT bRemoteEn) 自动位忽略点动输入(不与上位机命令冲突)
   变量: hmi_JogRollerFwd/Rev hmi_JogCylUp/Dn(hmi表) in_JogRollerFwd/Rev(io表 X10/X11 预留)
   ════════════════════════════════════════════════════════════════
   启用步骤(共4处, 逐项完成):
     [1] 删除本段外层块注释(本行上方起始符与下方结束符)
     [2] SBR_host 段3/段4 的 ELSE 手动位清命令分支 追加豁免:
           ELSE 改为 ELSIF NOT bJogActive  (急停注销块不受影响)
     [3] SBR_con 段4 强制失电豁免: IF NOT bRemoteEn THEN bCylValveOn := FALSE
           改为 IF NOT bRemoteEn AND NOT bJogActive THEN bCylValveOn := FALSE
     [4] SBR_con 段6 Roller_1 Enable 参数 bRemoteEn 改为 bRemoteEn OR bJogActive;
           段7 输出门控 IF bRemoteEn THEN 改为 IF bRemoteEn OR bJogActive THEN;
           并在 SBR_io 补映射: in_JogRollerFwd := X10; in_JogRollerRev := X11;
   ════════════════════════════════════════════════════════════════
   点动逻辑体(按下转 松开停; 气缸点动得电升/失电降 单电控):
   // 点动激活: 任一输入按下
   bJogActive := hmi_JogRollerFwd OR hmi_JogRollerRev
               OR in_JogRollerFwd OR in_JogRollerRev
               OR hmi_JogCylUp OR hmi_JogCylDn;

   IF bJogActive THEN
       // 辊筒点动: 正转优先 互斥 按下转 松开停
       IF (hmi_JogRollerFwd OR in_JogRollerFwd)
          AND NOT (hmi_JogRollerRev OR in_JogRollerRev) THEN
           bRollerRun := TRUE;
           bRollerRev := FALSE;
       ELSIF (hmi_JogRollerRev OR in_JogRollerRev)
             AND NOT (hmi_JogRollerFwd OR in_JogRollerFwd) THEN
           bRollerRev := TRUE;
           bRollerRun := FALSE;
       ELSE
           bRollerRun := FALSE;      // 松开即停
           bRollerRev := FALSE;
       END_IF;
       // 气缸点动: 升得电 降失电(单电控 弹簧回)
       IF hmi_JogCylUp THEN
           bCylValveOn := TRUE;
       ELSIF hmi_JogCylDn THEN
           bCylValveOn := FALSE;
       END_IF;
   END_IF;
   ════════════════════════════════════════════════════════════════ *)
