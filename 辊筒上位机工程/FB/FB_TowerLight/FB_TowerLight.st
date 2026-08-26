(* ════════════════════════════════════════════════════════════════════
   FB_TowerLight —— 三色灯 + 蜂鸣
   变量声明: 全部见同文件夹 FB_TowerLight_变量.csv
   本文件  : 仅程序逻辑体 (禁止在此声明变量)
   优先级  : 故障 > 自动 > 手动 (细则7 禁止顺序叠IF冲突)
   ════════════════════════════════════════════════════════════════════ *)
IF Fault THEN
    LightRed := TRUE;
    LightYellow := FALSE;
    LightGreen := FALSE;
    Buzzer := TRUE;
ELSIF Auto THEN
    LightRed := FALSE;
    LightYellow := FALSE;
    LightGreen := TRUE;
    Buzzer := FALSE;
ELSIF Manual THEN
    LightRed := FALSE;
    LightYellow := TRUE;
    LightGreen := FALSE;
    Buzzer := FALSE;
ELSE
    LightRed := FALSE;
    LightYellow := FALSE;
    LightGreen := FALSE;
    Buzzer := FALSE;
END_IF;
