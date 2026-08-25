(* ════════════════════════════════════════════════════════════════════
   SBR_00 数据类型与常量 (文档块)
   ════════════════════════════════════════════════════════════════════
   本工程无结构体类型; 常量在独立常量表声明(汇川规范, 非 VAR_GLOBAL CONSTANT):
     VariableTable_const.csv:
       FILTER_TIME_INPUT : DINT = 20    输入软件消抖(ms, 备用)
       BLOCK_HOLD_TIME   : DINT = 3000  自动阻挡保持输送时长(ms)
       BLOCK_PASS_TIME   : DINT = 5000  自动放行时长(ms)
       CYL_TIMEOUT       : DINT = 2000  气缸到位超时阈值(ms)
   变量表分类:
       io 表   X0~X4 / Y0~Y1 物理点位
       const 表 常量(掉电保持)
       con 表  内部控制量(bEstopPressed/bRunOK/bModeAuto/con_* )
       inst 表 FB 实例(Latch_Alarm/Roller_1) + 边沿(r_ResetBtn/r_ManBlock) + 定时(ton_* )
   程序块分层: SBR_02 IO -> SBR_03 安全 -> SBR_04 模式 ->
               SBR_05 手动 -> SBR_06 自动 -> SBR_07 输出刷新
   ════════════════════════════════════════════════════════════════════ *)
