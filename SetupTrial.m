function SetupTrial()

    global XM;
    global RTMA;
    
    fprintf('\n');
   
    % Tell EM to reload its configuration file
    msg = RTMA.MDF.RELOAD_CONFIGURATION;
    SendMessage('RELOAD_CONFIGURATION', msg);

    %--- increment the trial number and attempted start number
    XM.trial_num = XM.trial_num + 1; % Increment the count of trial numbers
    XM.trial_started = false; % Reset the flag that tells the later task states whether the monkey succeeded at starting a trial

    CallFailSafe('LoadXMConfigFile', XM.config_file_name);

    % if recevied num_reps from XM_START_SESSION msg, use it
    if ~isempty(XM.num_reps)
        XM.config.num_reps = XM.num_reps;
    end
    
    XM.insert_alternate_state = false;
    if (isfield(XM.config, 'alternate_occurrence_freq'))
        if (rand < XM.config.alternate_occurrence_freq)
            [prob_list, orig_idx] = sort(XM.config.alternate_state_config_freq);
            prob = rand;
            for c = 1 : length(prob_list)
                if (prob <= sum(prob_list(1:c)))
                    alt_file_idx = orig_idx(c);
                    break;   
                end
            end
            alternate_state_config_file = XM.config.alternate_state_config_files{alt_file_idx};
            
            %DisplayMessageToUser(['--- Using alternate state config file: ' alternate_state_config_file]);

            %--- Reload all configuration files, so we can do live updates
            CallFailSafe('LoadTaskStateConfigFile', alternate_state_config_file);

            XM.insert_alternate_state = true;
        end
    end

 
    if ~XM.insert_alternate_state
        % Increment rep counter
        if( isempty( XM.combos_to_be_tried))
            XM.rep_num = XM.rep_num + 1;
        end

        fprintf('\n======= [ Trial #%d, Rep #%d ] =======\n', XM.trial_num, XM.rep_num);

        %--- Reload all configuration files, so we can do live updates
        CallFailSafe('LoadTaskStateConfigFile',  GetTaskStateConfigFileName());

        %--- Start a new rep if there are no targets left to be tried
        if( isempty( XM.combos_to_be_tried))
            if isempty(XM.cur_tgt_num)
                XM.cur_tgt_num = XM.config.task_state_start_tgts;
            else
                XM.cur_tgt_num = XM.cur_tgt_num+1;
            end
            idx = find(XM.cur_tgt_num==XM.config.Tgt_Sizes(:,1),1);
            XM.tgt_sz = XM.config.Tgt_Sizes(idx,2);
            if XM.config.dims ~= 4
                XM.ori_threshold = XM.tgt_sz;
            else
                XM.ori_threshold = XM.config.Tgt_sizes(idx,3);
            end
            XM.CPacks = XM.config.Tgt_packs{idx};
            
            tmpCombos = repmat(1:(XM.cur_tgt_num),[1 XM.config.num_rep_per_state_tgt]);
            mixidx = randperm(length(tmpCombos));
            XM.combos_to_be_tried = tmpCombos(mixidx);
            XM.num_times_tried_combo = zeros(1,length(tmpCombos));
        end
        
        XM.active_combo_index = XM.combos_to_be_tried(1);        

        if( XM.config.max_num_tries_per_target > 0 )
            num_tries_left = num2str(XM.config.max_num_tries_per_target - XM.num_times_tried_combo(XM.active_combo_index));
            DisplayMessageToUser([num_tries_left ' tries left for this combo']);
        else
            num_tries_left = 'INFINITE';
        end
    else
        num_combos = length(XM.config.task_state_config.target_configurations.combos.tool);
        combos_to_be_tried = 1 : num_combos;
        XM.active_combo_index = combos_to_be_tried(random('Discrete Uniform',length(combos_to_be_tried)));
    end    

    fprintf('Using combo index: %d\n', XM.active_combo_index);    

    % Tell SPM to flag the next sample as an alignment sample
    % So that we can get an alignment pulse from the robot controller
    % to get an unambiguous alignment between samples and timing pulses
    SendSignal RESET_SAMPLE_ALIGNMENT;

    if(isfield(XM, 'runtime'))
      XM.runtime.cancel_button_pressed = 0;
    end    

    XM.penalty_time = 0;

    %--- Send out informational message that says how this trial is configured (for anyone that cares)
    SendTrialConfig( );
