function SendVRControlConfig( event_name, event_time, task_state_config, target, cori)

    global XM;
    global RTMA;

    rcc = RTMA.MDF.VR_CONTROL_CONFIG;
    rcc.trialEvent.event_code = int32(0); %int32( RTMA.defines.(event_full_name));
    rcc.trialEvent.event_time = event_time;

    % Get knob position and orientation and turn and pull target from current target configuration
	rcc.target = target;
	rcc.coriMatrix = cori;

    auto_cmd_fraction = task_state_config.auto_command_fraction;
    
    for i = 1 : length( XM.config.vr_control_mode)
        mode = XM.config.vr_control_mode(i);
        switch( mode)
          case 'V'
              if(XM.config.EM_used_dimensions(i))
                rcc.extrinsicVelControlled(i) = 1;
                rcc.importantDOF(i)  = 1;
              else
              
                rcc.importantDOF(i)  = 0;
                rcc.extrinsicVelControlled(i) = 0;
              end
            
              rcc.autoVelControlFraction(i) = auto_cmd_fraction(i);
              rcc.orthVelImpedance(i) = task_state_config.vf_orth_impedance(i);
          case 'P'
              if(XM.config.EM_used_dimensions(i))
                rcc.extrinsicPosControlled(i) = 1;
              else
                rcc.extrinsicPosControlled(i) = 0;
              end
              
              rcc.autoPosControlFraction(i) = auto_cmd_fraction(i);
              rcc.orthPosImpedance(i) = task_state_config.vf_orth_impedance(i);
          otherwise
              error( 'Unrecognized mode for vr_control_mode');
        end
    end

    rcc.autoControlParams.virtualPadPosition = zeros(1,RTMA.defines.MAX_CONTROL_DIMS);
    %rcc.autoControlParams.virtualPadPosition(1:length(XM.active_start_loc_configuration)) = XM.active_start_loc_configuration;
    
    SendMessage( 'VR_CONTROL_CONFIG', rcc);
