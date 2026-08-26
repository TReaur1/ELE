(* ════════════════════════════════════════════════════════════════════
   FB_AlarmLatch —— 故障锁存
   变量声明: 全部见同文件夹 FB_AlarmLatch_变量.csv
   本文件  : 仅程序逻辑体 (禁止在此声明变量)
   ════════════════════════════════════════════════════════════════════ *)
IF FaultSrc THEN
    bLatched := TRUE;
ELSIF ResetCmd AND (NOT FaultSrc) THEN
    bLatched := FALSE;      (* 复位需故障源已消除 不允许带故障复位 *)
END_IF;
AlarmOut := bLatched;
