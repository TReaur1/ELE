(* ════════════════════════════════════════════════════════════════════
   SBR_00 数据类型与常量 (文档块)
   ════════════════════════════════════════════════════════════════════
   本工程无结构体类型; 常量在独立常量表声明(汇川规范):
     VariableTable_const.csv:
       CYL_TIMEOUT             : DINT = 3000  气缸到位超时阈值(ms, 设备域)
       COMM_HEART_TIMEOUT      : DINT = 3000  通讯失联阈值(ms, 通讯域 超时安全停)
       COMM_DEGRADED_TIMEOUT   : DINT = 1000  通讯降级阈值(ms, 冻结新命令 动作继续)
       COMM_HEART_TICK         : DINT = 1000  出向心跳自增周期(ms)
       ROLLER_SPEED_LEVEL/LOW/MID/HIGH : FB_Roller 速度档参数(常量化 禁魔法数字)
       RTU_PORT            : INT  = 0     RS485端口号(COM0) 需配置ModbusRTU主站
       DRV_ADDR            : INT  = 1     C20驱动器从站站号(F08.00)
       DRV_SPD_REG         : DINT = 8193  转速设定寄存器(H2001, 0~3000 单位1RPM)
       DRV_RST_PULSE       : DINT = 500   CLR复位端子脉冲宽(ms)
   设备构成: C20-400HR 直流无刷驱动器带动电机传动辊筒
             (端子FWD/REV启停 Y10/Y11; CLR复位 Y12; RS485仅速度给定) +
             二位五通单电控电磁阀阻挡气缸(Y5线圈 得电=升/失电=弹簧降)
   传感器  : X3/X4/X5 位置检测(进料段/中段/出料段 光电)
             X6/X7   阻挡气缸升降到位磁开
   控制方式: 纯上位机控制(无自动工步), 手自动旋钮=自动位时远程命令生效
   无线适应: 防重放序号(host_Send_CmdSeq)+降级冻结(con_CommDegraded)+三级看门狗
             (AGENTS 细则15/17/18, 见 SBR_host 段1/段3/段4/段7)
   阀控制  : 命令后线圈输出保持至磁开到位; CYL_TIMEOUT 超时未到位接锁存报警闭环
   速度设定: 上位机写 host_Send_RollerSpeed(1RPM) -> SBR_host 经 MB_Master 写 2001H
   变量表分类: io(X0~X7/Y0~Y12) const con inst host(通讯字见 通讯字表.csv)
   程序四模块: SBR_io(IO映射) -> SBR_con(控制逻辑) ->
               SBR_host(通讯主站) -> SBR_status(状态呈现); 主调度见 SBR_08
   ════════════════════════════════════════════════════════════════════ *)
