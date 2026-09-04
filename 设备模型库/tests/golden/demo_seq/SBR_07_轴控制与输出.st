(* ════════════════════════════════════════════════════════════════════
   SBR_07 轴控制与输出 - demo_seq
   伺服FB / 步进FB / 辊筒FB + 最后写物理端子 + 急停安全切断
   ════════════════════════════════════════════════════════════════════ *)
(* 横移 伺服FB调用: AxisControl_M1_Cross *)
(* R3b: 命令实体全成员传参 (14命令接口完整通路) *)
AxisControl_M1_Cross(Axis := Axis_M1_Cross,
    PowerEnable := M1_Cross_Cmd.PowerEnable,
    Stop := M1_Cross_Cmd.Stop,
    Reset := M1_Cross_Cmd.Reset,
    Home := M1_Cross_Cmd.Home,
    JogForward := M1_Cross_Cmd.JogForward,
    JogBackward := M1_Cross_Cmd.JogBackward,
    Jogvelocity := M1_Cross_Cmd.Jogvelocity,
    JogAcceleration := M1_Cross_Cmd.JogAcceleration,
    JogDeceleration := M1_Cross_Cmd.JogDeceleration,
    Absolute_Execute := M1_Cross_Cmd.Absolute_Execute,
    Absolute_Position := M1_Cross_Cmd.Absolute_Position,
    Absolute_Velocity := M1_Cross_Cmd.Absolute_Velocity,
    Absolute_Acceleration := M1_Cross_Cmd.Absolute_Acceleration,
    Absolute_Deceleration := M1_Cross_Cmd.Absolute_Deceleration,
    Timeout := TIMEOUT_AXIS_MOVE,
    Absolute_MoveAbsoluteDone => M1_Cross_Status.MoveAbsolute.Done,
    AxisStatusData => M1_Cross_Status);
(* 提升 伺服FB调用: AxisControl_M2_Lift *)
(* R3b: 命令实体全成员传参 (14命令接口完整通路) *)
AxisControl_M2_Lift(Axis := Axis_M2_Lift,
    PowerEnable := M2_Lift_Cmd.PowerEnable,
    Stop := M2_Lift_Cmd.Stop,
    Reset := M2_Lift_Cmd.Reset,
    Home := M2_Lift_Cmd.Home,
    JogForward := M2_Lift_Cmd.JogForward,
    JogBackward := M2_Lift_Cmd.JogBackward,
    Jogvelocity := M2_Lift_Cmd.Jogvelocity,
    JogAcceleration := M2_Lift_Cmd.JogAcceleration,
    JogDeceleration := M2_Lift_Cmd.JogDeceleration,
    Absolute_Execute := M2_Lift_Cmd.Absolute_Execute,
    Absolute_Position := M2_Lift_Cmd.Absolute_Position,
    Absolute_Velocity := M2_Lift_Cmd.Absolute_Velocity,
    Absolute_Acceleration := M2_Lift_Cmd.Absolute_Acceleration,
    Absolute_Deceleration := M2_Lift_Cmd.Absolute_Deceleration,
    Timeout := TIMEOUT_AXIS_MOVE,
    Absolute_MoveAbsoluteDone => M2_Lift_Status.MoveAbsolute.Done,
    AxisStatusData => M2_Lift_Status);
(* 夹爪 步进: Stepper_Gripper *)
Stepper_Gripper(ManForward := Stepper_Gripper.ManForward, ManBackward := Stepper_Gripper.ManBackward,
    Enable := con_RunOK, Stop := con_EstopPressed);