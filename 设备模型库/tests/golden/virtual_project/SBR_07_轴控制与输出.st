(* ════════════════════════════════════════════════════════════════════
   SBR_07 轴控制与输出 - virtual_project
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
(* 旋转 伺服FB调用: AxisControl_M2_Rot *)
(* R3b: 命令实体全成员传参 (14命令接口完整通路) *)
AxisControl_M2_Rot(Axis := Axis_M2_Rot,
    PowerEnable := M2_Rot_Cmd.PowerEnable,
    Stop := M2_Rot_Cmd.Stop,
    Reset := M2_Rot_Cmd.Reset,
    Home := M2_Rot_Cmd.Home,
    JogForward := M2_Rot_Cmd.JogForward,
    JogBackward := M2_Rot_Cmd.JogBackward,
    Jogvelocity := M2_Rot_Cmd.Jogvelocity,
    JogAcceleration := M2_Rot_Cmd.JogAcceleration,
    JogDeceleration := M2_Rot_Cmd.JogDeceleration,
    Absolute_Execute := M2_Rot_Cmd.Absolute_Execute,
    Absolute_Position := M2_Rot_Cmd.Absolute_Position,
    Absolute_Velocity := M2_Rot_Cmd.Absolute_Velocity,
    Absolute_Acceleration := M2_Rot_Cmd.Absolute_Acceleration,
    Absolute_Deceleration := M2_Rot_Cmd.Absolute_Deceleration,
    Timeout := TIMEOUT_AXIS_MOVE,
    Absolute_MoveAbsoluteDone => M2_Rot_Status.MoveAbsolute.Done,
    AxisStatusData => M2_Rot_Status);
(* 提升 伺服FB调用: AxisControl_M3_Lift *)
(* R3b: 命令实体全成员传参 (14命令接口完整通路) *)
AxisControl_M3_Lift(Axis := Axis_M3_Lift,
    PowerEnable := M3_Lift_Cmd.PowerEnable,
    Stop := M3_Lift_Cmd.Stop,
    Reset := M3_Lift_Cmd.Reset,
    Home := M3_Lift_Cmd.Home,
    JogForward := M3_Lift_Cmd.JogForward,
    JogBackward := M3_Lift_Cmd.JogBackward,
    Jogvelocity := M3_Lift_Cmd.Jogvelocity,
    JogAcceleration := M3_Lift_Cmd.JogAcceleration,
    JogDeceleration := M3_Lift_Cmd.JogDeceleration,
    Absolute_Execute := M3_Lift_Cmd.Absolute_Execute,
    Absolute_Position := M3_Lift_Cmd.Absolute_Position,
    Absolute_Velocity := M3_Lift_Cmd.Absolute_Velocity,
    Absolute_Acceleration := M3_Lift_Cmd.Absolute_Acceleration,
    Absolute_Deceleration := M3_Lift_Cmd.Absolute_Deceleration,
    Timeout := TIMEOUT_AXIS_MOVE,
    Absolute_MoveAbsoluteDone => M3_Lift_Status.MoveAbsolute.Done,
    AxisStatusData => M3_Lift_Status);
(* 对中 伺服FB调用: AxisControl_M4_Center *)
(* R3b: 命令实体全成员传参 (14命令接口完整通路) *)
AxisControl_M4_Center(Axis := Axis_M4_Center,
    PowerEnable := M4_Center_Cmd.PowerEnable,
    Stop := M4_Center_Cmd.Stop,
    Reset := M4_Center_Cmd.Reset,
    Home := M4_Center_Cmd.Home,
    JogForward := M4_Center_Cmd.JogForward,
    JogBackward := M4_Center_Cmd.JogBackward,
    Jogvelocity := M4_Center_Cmd.Jogvelocity,
    JogAcceleration := M4_Center_Cmd.JogAcceleration,
    JogDeceleration := M4_Center_Cmd.JogDeceleration,
    Absolute_Execute := M4_Center_Cmd.Absolute_Execute,
    Absolute_Position := M4_Center_Cmd.Absolute_Position,
    Absolute_Velocity := M4_Center_Cmd.Absolute_Velocity,
    Absolute_Acceleration := M4_Center_Cmd.Absolute_Acceleration,
    Absolute_Deceleration := M4_Center_Cmd.Absolute_Deceleration,
    Timeout := TIMEOUT_AXIS_MOVE,
    Absolute_MoveAbsoluteDone => M4_Center_Status.MoveAbsolute.Done,
    AxisStatusData => M4_Center_Status);
(* 夹爪 步进: Stepper_Gripper *)
Stepper_Gripper(ManForward := Stepper_Gripper.ManForward, ManBackward := Stepper_Gripper.ManBackward,
    Enable := con_RunOK, Stop := con_EstopPressed);
(* 左阻挡 步进: Stepper_LBlock *)
Stepper_LBlock(ManForward := Stepper_LBlock.ManForward, ManBackward := Stepper_LBlock.ManBackward,
    Enable := con_RunOK, Stop := con_EstopPressed);
(* 右阻挡 步进: Stepper_RBlock *)
Stepper_RBlock(ManForward := Stepper_RBlock.ManForward, ManBackward := Stepper_RBlock.ManBackward,
    Enable := con_RunOK, Stop := con_EstopPressed);