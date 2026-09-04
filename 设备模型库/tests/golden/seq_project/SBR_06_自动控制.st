(* ════════════════════════════════════════════════════════════════════
   SBR_06 自动控制 - seq_project (原型: internal_seq)
   步状态机框架 (非标准工步: 人工填写工步体)
   结构: 启动/停止门控 + 步号(STEP_NO) + CASE 分发 + 转移
   公共模式: 定位超时(TIMEOUT_AXIS_MOVE) / 到位 / 限位 / 互锁 已备好
   工步体由工程师按工艺填写, 转移条件触发 STEP_NO 递增
   ════════════════════════════════════════════════════════════════════ *)

(* ── 启动 / 停止门控 (由 SBR_04 派生 con_Start/Stop/Step_Init) ── *)
IF con_Start AND NOT con_StepRun THEN
    con_StepRun := TRUE;
    con_Step_No := 1;                 (* 从头开始 *)
END_IF;
IF con_Stop OR NOT con_AutoEnable THEN
    con_StepRun := FALSE;
END_IF;
IF con_Step_Init THEN
    con_StepRun := FALSE;
    con_Step_No := 0;
END_IF;

(* ── 步状态机 (工步体人工填写) ── *)
IF con_StepRun THEN
    CASE con_Step_No OF        (* 工步 1: 横移 动作 *)
        (* 填写: 命令实体赋值 *)
        M1_Cross_Cmd.Absolute_Execute := FALSE;
        (* 转移条件: 到位/定时/限位 -> 递增 *)
        IF M1_Cross_Status.MoveAbsolute.Done THEN
            con_Step_No := con_Step_No + 1;
        END_IF;
        (* 定位超时 (细则11): 启动后限时未见 Done -> 置超时源, SBR_03 锁存报警 *)
        (* TONR 保持型: R 在命令撤除时复位累计值, 保证每次启动重新计时 *)
        TONR(IN := M1_Cross_Cmd.Absolute_Execute AND NOT M1_Cross_Status.MoveAbsolute.Done,
            PT := TIMEOUT_AXIS_MOVE, R := NOT M1_Cross_Cmd.Absolute_Execute, Q => con_TimeoutQ);
        IF con_TimeoutQ THEN
            con_TimeoutReq := TRUE;
        END_IF;        (* 工步 2: 旋转 动作 *)
        (* 填写: 命令实体赋值 *)
        M2_Rot_Cmd.Absolute_Execute := FALSE;
        (* 转移条件: 到位/定时/限位 -> 递增 *)
        IF M2_Rot_Status.MoveAbsolute.Done THEN
            con_Step_No := con_Step_No + 1;
        END_IF;
        (* 定位超时 (细则11): 启动后限时未见 Done -> 置超时源, SBR_03 锁存报警 *)
        (* TONR 保持型: R 在命令撤除时复位累计值, 保证每次启动重新计时 *)
        TONR(IN := M2_Rot_Cmd.Absolute_Execute AND NOT M2_Rot_Status.MoveAbsolute.Done,
            PT := TIMEOUT_AXIS_MOVE, R := NOT M2_Rot_Cmd.Absolute_Execute, Q => con_TimeoutQ);
        IF con_TimeoutQ THEN
            con_TimeoutReq := TRUE;
        END_IF;        (* 工步 3: 提升 动作 *)
        (* 填写: 命令实体赋值 *)
        M3_Lift_Cmd.Absolute_Execute := FALSE;
        (* 转移条件: 到位/定时/限位 -> 递增 *)
        IF M3_Lift_Status.MoveAbsolute.Done THEN
            con_Step_No := con_Step_No + 1;
        END_IF;
        (* 定位超时 (细则11): 启动后限时未见 Done -> 置超时源, SBR_03 锁存报警 *)
        (* TONR 保持型: R 在命令撤除时复位累计值, 保证每次启动重新计时 *)
        TONR(IN := M3_Lift_Cmd.Absolute_Execute AND NOT M3_Lift_Status.MoveAbsolute.Done,
            PT := TIMEOUT_AXIS_MOVE, R := NOT M3_Lift_Cmd.Absolute_Execute, Q => con_TimeoutQ);
        IF con_TimeoutQ THEN
            con_TimeoutReq := TRUE;
        END_IF;        (* 工步 4: 对中 动作 *)
        (* 填写: 命令实体赋值 *)
        M4_Center_Cmd.Absolute_Execute := FALSE;
        (* 转移条件: 到位/定时/限位 -> 递增 *)
        IF M4_Center_Status.MoveAbsolute.Done THEN
            con_Step_No := con_Step_No + 1;
        END_IF;
        (* 定位超时 (细则11): 启动后限时未见 Done -> 置超时源, SBR_03 锁存报警 *)
        (* TONR 保持型: R 在命令撤除时复位累计值, 保证每次启动重新计时 *)
        TONR(IN := M4_Center_Cmd.Absolute_Execute AND NOT M4_Center_Status.MoveAbsolute.Done,
            PT := TIMEOUT_AXIS_MOVE, R := NOT M4_Center_Cmd.Absolute_Execute, Q => con_TimeoutQ);
        IF con_TimeoutQ THEN
            con_TimeoutReq := TRUE;
        END_IF;        ELSE
            (* 全部工步完成 *)
            con_StepRun := FALSE;
            con_Step_No := 0;
    END_CASE;
END_IF;

(* ── 状态反馈 host_Rcv_* ── *)
host_Rcv_Step_No := con_Step_No;
host_Rcv_StepRun := con_StepRun;