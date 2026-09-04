(* ════════════════════════════════════════════════════════════════════
   SBR_05 手动控制 - seq_project (原型: internal_seq)
   手动 Jog/步进/辊筒 + 手动单步(步进)功能
   ════════════════════════════════════════════════════════════════════ *)
(* 横移 Jog: M1_Cross_Cmd *)
M1_Cross_Cmd.JogForward := con_ManualEnable AND hmi_JogP_M1;
M1_Cross_Cmd.JogBackward := con_ManualEnable AND hmi_JogN_M1;
(* 旋转 Jog: M2_Rot_Cmd *)
M2_Rot_Cmd.JogForward := con_ManualEnable AND hmi_JogP_M2;
M2_Rot_Cmd.JogBackward := con_ManualEnable AND hmi_JogN_M2;
(* 提升 Jog: M3_Lift_Cmd *)
M3_Lift_Cmd.JogForward := con_ManualEnable AND hmi_JogP_M3;
M3_Lift_Cmd.JogBackward := con_ManualEnable AND hmi_JogN_M3;
(* 对中 Jog: M4_Center_Cmd *)
M4_Center_Cmd.JogForward := con_ManualEnable AND hmi_JogP_M4;
M4_Center_Cmd.JogBackward := con_ManualEnable AND hmi_JogN_M4;
(* 夹爪 手动: Stepper_Gripper *)
Stepper_Gripper.ManForward := con_ManualEnable AND hmi_StepP_Gripper;
Stepper_Gripper.ManBackward := con_ManualEnable AND hmi_StepN_Gripper;
(* 左阻挡 手动: Stepper_LBlock *)
Stepper_LBlock.ManForward := con_ManualEnable AND hmi_StepP_LBlock;
Stepper_LBlock.ManBackward := con_ManualEnable AND hmi_StepN_LBlock;
(* 右阻挡 手动: Stepper_RBlock *)
Stepper_RBlock.ManForward := con_ManualEnable AND hmi_StepP_RBlock;
Stepper_RBlock.ManBackward := con_ManualEnable AND hmi_StepN_RBlock;
(* 辊筒手动 *)
con_RollerFwd_Manual := con_ManualEnable AND hmi_Roller_Fwd;
con_RollerRev_Manual := con_ManualEnable AND hmi_Roller_Rev;

(* 手动单步: 手动模式下每按一次前进一个工步 (人工按需) *)
IF con_ManualEnable AND r_StepFwd.Q THEN
    con_Step_No := con_Step_No + 1;
END_IF;