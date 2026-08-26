(* ════════════════════════════════════════════════════════════════════
   SBR_rtu RS485 主站 (Modbus RTU, MB_Master 指令)
   C20-400HR 混合模式: 端子FWD/REV启停(见SBR_07) + RS485 仅速度给定
     2001H 转速设定: 0~3000 (单位1RPM) 转速变化时写单字(功能码06)
   ════════════════════════════════════════════════════════════════════
   使用前置(工程设备配置 人工):
     COM0 协议配置为 Modbus-RTU 主站;
     驱动器侧 F00.01=1(端子指令通道) F00.02=3(MODBUS速度给定)
              F08.00 站号 / F08.01 波特率19200 N-8-1
   ════════════════════════════════════════════════════════════════════ *)

(* ── 上电首扫基准对齐 (不主动下发 等待上位机设定/变化) ── *)
IF con_SpeedLast < 0 THEN
    con_SpeedLast := con_SpeedTarget;
END_IF;

(* ── 发送请求: 仅自动位接受新转速; 变化即请求 失败保留自动重试 ── *)
IF NOT bRemoteEn THEN
    IF con_SpeedTarget <> con_SpeedLast THEN
        con_SpeedTarget := con_SpeedLast;   (* 非自动位 回退目标为已写值 *)
    END_IF;
END_IF;
bRtuReq := (con_SpeedTarget <> con_SpeedLast);

(* ── 缓存装载 (仅自动位接受新转速) + 触发沿发起 写单字(功能码06) ── *)
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

(* ── 完成确认: 成功才更新基准; 失败保留请求 下周期自动重试 ── *)
IF bRtuDone AND (NOT bRtuError) THEN
    IF con_SpeedLast <> con_SpeedTarget THEN
        con_SpeedLast := con_SpeedTarget;
    END_IF;
END_IF;
