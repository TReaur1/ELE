(* ════════════════════════════════════════════════════════════════════
   SBR_05 手动控制 - demo_seq (原型: internal_seq)
   手动 Jog/步进/辊筒 + 手动单步(步进)功能
   ════════════════════════════════════════════════════════════════════ *)
(* 横移 Jog: M1_Cross_Cmd *)
M1_Cross_Cmd.JogForward := con_ManualEnable AND hmi_JogP_M1;
M1_Cross_Cmd.JogBackward := con_ManualEnable AND hmi_JogN_M1;
(* 提升 Jog: M2_Lift_Cmd *)
M2_Lift_Cmd.JogForward := con_ManualEnable AND hmi_JogP_M2;
M2_Lift_Cmd.JogBackward := con_ManualEnable AND hmi_JogN_M2;
(* 夹爪 手动: Stepper_Gripper *)
Stepper_Gripper.ManForward := con_ManualEnable AND hmi_StepP_Gripper;
Stepper_Gripper.ManBackward := con_ManualEnable AND hmi_StepN_Gripper;
(* 辊筒手动 *)
con_RollerFwd_Manual := con_ManualEnable AND hmi_Roller_Fwd;
con_RollerRev_Manual := con_ManualEnable AND hmi_Roller_Rev;

(* 手动单步: 手动模式下每按一次前进一个工步 (人工按需) *)
IF con_ManualEnable AND r_StepFwd.Q THEN
    con_Step_No := con_Step_No + 1;
END_IF;