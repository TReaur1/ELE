(* ════════════════════════════════════════════════════════════════════
   SBR_host 通讯主站 —— 四模块架构·通讯层
   ════════════════════════════════════════════════════════════════════
   职责: 通讯事务全归本块 ——
     段1~2 通讯健康: 入向心跳看门狗(断讯判定) + 出向心跳自增
     段3~7 Modbus TCP 命令处理(触发式+清0回执) + 速度缓存
     段8   Modbus RTU 主站: RS485 速度转发至 C20 驱动器
   依赖: con 层 bRemoteEn(本周期, con 先于本块执行)。
   产出: 命令记忆量(bRollerRun/bRollerRev/con_CylCmd/...) 与
         con_SpeedTarget -> 由 con 层下一周期消费执行。
   C20-400HR 混合模式: 端子FWD/REV启停(见SBR_con/SBR_io) + RS485 仅速度给定
     2001H 转速设定: 0~3000 (单位1RPM) 转速变化时写单字(功能码06)
   使用前置(工程设备配置 人工):
     COM0 协议配置为 Modbus-RTU 主站;
     驱动器侧 F00.01=1(端子指令通道) F00.02=3(MODBUS速度给定)
              F08.00 站号 / F08.01 波特率19200 N-8-1
   ════════════════════════════════════════════════════════════════════ *)

(* ═══ 段1 入向心跳看门狗 (通讯事务) ══════════════════════════════
      变化拍断 IN 重启计时; 无变化持续计时 满 TIMEOUT 置断讯,
      心跳恢复自动解除; con_CommLost 由 con 层 RunOK 联锁消费 *)
bHeartChanged := host_Send_Heart <> con_HeartPrev;
IF bHeartChanged THEN
    con_HeartPrev := host_Send_Heart;
END_IF;
IF bHeartChanged THEN
    bHeartTiming := FALSE;
ELSE
    bHeartTiming := TRUE;
END_IF;
TONR(IN := bHeartTiming,
     PT := COMM_HEART_TIMEOUT,
     Q  => con_CommLost);

(* ═══ 段2 出向心跳: TONR 直调 IN取反自翻转 每 COMM_HEART_TICK 计数+1 ═══ *)
TONR(IN := NOT con_HeartTickQ,
     PT := COMM_HEART_TICK,
     Q  => con_HeartTickQ);
IF con_HeartTickQ THEN
    con_HeartOut := con_HeartOut + 1;
END_IF;

(* ═══ 段3 辊筒命令映射(PLC控制辊筒第一环) ═══════════════════════
      host命令字 -> 运行记忆量 触发式 三者互斥 仅自动位接受 执行后清0回执 *)
IF bRemoteEn THEN
    IF host_Send_RollerStart = 1
       AND host_Send_RollerStop <> 1 AND host_Send_RollerRev <> 1 THEN
        bRollerRun := TRUE;
        bRollerRev := FALSE;
        host_Send_RollerStart := 0;
    END_IF;
    IF host_Send_RollerRev = 1
       AND host_Send_RollerStop <> 1 AND host_Send_RollerStart <> 1 THEN
        bRollerRev := TRUE;
        bRollerRun := FALSE;
        host_Send_RollerRev := 0;
    END_IF;
    IF host_Send_RollerStop = 1 THEN
        bRollerRun := FALSE;
        bRollerRev := FALSE;
        host_Send_RollerStop := 0;
    END_IF;
ELSE
    (* 非自动位: 清运行记忆量(防切回自动位自恢复) + 拒绝命令并清字回执 *)
    bRollerRun := FALSE;
    bRollerRev := FALSE;
    IF host_Send_RollerStart = 1 THEN host_Send_RollerStart := 0; END_IF;
    IF host_Send_RollerStop = 1 THEN host_Send_RollerStop := 0; END_IF;
    IF host_Send_RollerRev = 1 THEN host_Send_RollerRev := 0; END_IF;
END_IF;

(* ═══ 段4 阀命令: 升/降触发式 互斥; 置 con_CylCmd 由 SBR_con 执行 ═══ *)
IF bRemoteEn THEN
    IF host_Send_CylUp = 1 AND host_Send_CylDn <> 1 THEN
        con_CylCmd := 1;
        host_Send_CylUp := 0;
    END_IF;
    IF host_Send_CylDn = 1 THEN
        con_CylCmd := 2;
        host_Send_CylDn := 0;
    END_IF;
ELSE
    (* 非自动位: 拒绝阀命令并清字回执 *)
    IF host_Send_CylUp = 1 THEN host_Send_CylUp := 0; END_IF;
    IF host_Send_CylDn = 1 THEN host_Send_CylDn := 0; END_IF;
END_IF;

(* ═══ 段5 驱动器故障复位: 触发式 置边沿 由 SBR_con 输出脉冲后清0回执 ═══ *)
r_DrvReset(CLK := (host_Send_DrvReset = 1) AND bRemoteEn);
IF r_DrvReset.Q THEN
    host_Send_DrvReset := 0;
END_IF;

(* ═══ 段6 远程复位命令: SBR_con 已消费边沿 此处清0回执 ═══ *)
IF r_HostReset.Q THEN
    host_Send_EstopReset := 0;
END_IF;

(* ═══ 段7 速度设定: 电平缓存式 上位机写目标值 本块段8经RS485转发 ═══ *)
con_SpeedTarget := host_Send_RollerSpeed;

(* ═══ 段8 RS485 主站: 速度转发 (Modbus RTU, MB_Master 指令) ══════ *)
(* 上电首扫基准对齐 (不主动下发 等待上位机设定/变化) *)
IF con_SpeedLast < 0 THEN
    con_SpeedLast := con_SpeedTarget;
END_IF;

(* 发送请求: 仅自动位接受新转速; 变化即请求 失败保留自动重试 *)
IF NOT bRemoteEn THEN
    IF con_SpeedTarget <> con_SpeedLast THEN
        con_SpeedTarget := con_SpeedLast;   (* 非自动位 回退目标为已写值 *)
    END_IF;
END_IF;
bRtuReq := (con_SpeedTarget <> con_SpeedLast);

(* 缓存装载 (仅自动位接受新转速) + 触发沿发起 写单字(功能码06) *)
IF bRtuReq THEN
    con_RTUBuf[0] := con_SpeedTarget;
    dwRtuDataAddr := DRV_SPD_REG;   (* 指令实参须为直接变量 表达式先落变量 *)
END_IF;
r_RtuSend(CLK := bRtuReq AND (NOT bRtuBusy));
MB_Master(Execute    := r_RtuSend.Q,
          iPort      := RTU_PORT,
          iAddr      := DRV_ADDR,
          iFuncCode  := 6,
          diDataAddr := dwRtuDataAddr,
          iDataNums  := 1,
          iDataBuf   := con_RTUBuf,
          xDone      => bRtuDone,
          xBusy      => bRtuBusy,
          xError     => bRtuError,
          dwErrorID  => dwRtuErrID);

(* 完成确认: 成功才更新基准; 失败保留请求 下周期自动重试 *)
IF bRtuDone AND (NOT bRtuError) THEN
    IF con_SpeedLast <> con_SpeedTarget THEN
        con_SpeedLast := con_SpeedTarget;
    END_IF;
END_IF;
