(* ════════════════════════════════════════════════════════════════════
   FB_Roller —— 辊筒电机 (C20-400HR 端子启停)
   变量声明: 全部见同文件夹 FB_Roller_变量.csv
   本文件  : 仅程序逻辑体 (禁止在此声明变量)
   ════════════════════════════════════════════════════════════════════ *)
(* 复位清故障 *)
IF Reset THEN
    Error := FALSE;
END_IF;
(* 无许可强制停 (显式切断 细则13) *)
IF NOT Enable THEN
    bRun := FALSE;
END_IF;
(* 方向命令: 同发视为无效防误动 单向有效 (互锁细则7) *)
IF FwdInput AND (NOT RevInput) THEN
    bRun := TRUE;
ELSIF RevInput AND (NOT FwdInput) THEN
    bRun := TRUE;
ELSIF (NOT FwdInput) AND (NOT RevInput) THEN
    bRun := FALSE;
END_IF;
(* 速度档查表 (速度值本身经RS485由SBR_rtu写入驱动器) *)
CASE SpeedLevel OF
    1: iSpeed := SpeedLow;
    2: iSpeed := SpeedMid;
    3: iSpeed := SpeedHigh;
ELSE
    iSpeed := 0;
END_CASE;
(* 输出: 许可门控 + 反向互斥 *)
FwdOut := bRun AND Enable AND (NOT RevInput) AND (iSpeed > 0);
RevOut := bRun AND Enable AND (NOT FwdInput) AND (iSpeed > 0);
