function Executive(ConfigFile, mm_ip)

% ExecutiveModule( ConfigFile, mm_ip)
%
% ConfigFile is the file name of the main config file that should be
% loaded from the config/ directory
%
% mm_ip is the network address of the MessageManager
%
% Meel Velliste 8/10/2008
% Emrah Diril 9/10/2011

dbstop if error;

global XM;
global COMMAND_LINE_ARGUMENTS;
global EVENT_MAP;

global RTMA_runtime;

RTMA_BaseDir = getenv('RTMA');
App_SourceDir = getenv('VRSRC');
App_IncludeDir = getenv('VRINC');

addpath([RTMA_BaseDir '/lang/matlab']);
addpath([App_SourceDir '/Common/Matlab']);

if ~exist( 'ConfigFile', 'var') || isempty(ConfigFile) || strcmpi(ConfigFile, 'none')
    error( 'Missing ConfigFile argument');
end

COMMAND_LINE_ARGUMENTS.ConfigFile = ConfigFile;

ModuleID = 'EXEC_MOD';
MessageConfigFile = [App_IncludeDir 'RTMA_config.mat'];
MessageTypes = {...
    'KEYBOARD'...
    'XM_START_SESSION'...
    'XM_ABORT_SESSION'...
    'EM_READY'...
    'EM_FROZEN'...
    'EM_ALREADY_FROZEN'...
    'EM_ADAPT_DONE'...
    'EM_ADAPT_FAILED'...
    'PAUSE_EXPERIMENT'...
    'RESUME_EXPERIMENT'...
    'EXIT'...
    };

ConnectArgs = {ModuleID, '', MessageConfigFile};
if exist('mm_ip','var') && ~isempty(mm_ip)
    ConnectArgs{end+1} = ['-server_name ' mm_ip];
end
ConnectToMMM(ConnectArgs{:})
Subscribe(MessageTypes{:})

RTMA_runtime.EventHook = @VR_EventHook;

SetupSession();

SendModuleReady();

SendModuleVersion('executive');

% run until all reps are done
while (1)
    
    % run until all targets are done
    while(1)
        SetupTrial();
        
        if ~XM.pausing_experiment
            
            num_task_states = length(XM.config.task_state_config.state_names);
            ts = 1;
            while ( ts <= num_task_states )
                try
                    task_state_config = GetTaskStateConfig(ts);
                    fprintf('|%s| ', task_state_config.state_names);
                    
                    if (task_state_config.skip_state == 1)
                        fprintf('skipped\n');
                        ts = ts+1;
                        continue;
                    end
                    
                    [target Cori] = DecideWhatTheCurrentTargetIs(task_state_config);
                    MoveVRToPresentationPos(task_state_config);
                    RunTaskState(task_state_config, target, Cori);
                    ConfigureTaskStateEvents(task_state_config);
                    ConfigureSimpleJudge(ts, task_state_config, target, Cori);
                catch ME
                    fprintf('\n>>> ERROR: %s\n', ME.message);
                    fprintf('\nPlease fix the problem and hit ENTER to continue\n');
                    pause;
                    ts = num_task_states + 1;   % start a brand new trial
                end
                if (ts <= num_task_states)
                    try
                        RcvEvent = [];
                        if (~isempty(fieldnames(EVENT_MAP)))
                            ExpectedEvents = fieldnames(EVENT_MAP);
                            RcvEvent = WaitFor(ts, ExpectedEvents{:});
                        end
                        
                        if (XM.aborting_session)
                            disp('Aborting session...');
                            break;
                        end
                        
                        next_state = HandleTaskStateEnded(ts, RcvEvent, task_state_config);
                        
                        if (next_state > 0)
                            ts = next_state;
                        else
                            ts = ts+1;
                        end
                    catch ME
                        fprintf('\n>>> ERROR: %s\n', ME.message);
                        fprintf('\nPlease fix the problem and hit ENTER to continue\n');
                        pause;
                        
                        ts = num_task_states;  % skip to InterTrial state
                    end
                end
            end
        end
        
        InterTrial();
        
        if (isempty(XM.combos_to_be_tried) || XM.aborting_session)
            break;
        end
    end
    
    if ((XM.rep_num >= XM.config.num_reps) || XM.aborting_session)
        disp('Finished all reps, will quit now (or someone aborted session)');
        %--- Stop Analog Stream
        SendSignal IO_STOP_STREAM;
        break;
    end
end
DoExit();

    function [TgtPos CoriMtx] = DecideWhatTheCurrentTargetIs(task_state_config)
        
        global XM;
        switch task_state_config.reach_target
            case 'home'
                TgtPos = zeros(1,7);
            case 'tgt'                
                tgt = XM.CPacks(XM.active_combo_index,:);
                TgtPos = [tgt(1:3) 0 tgt(4:6)];
        end
        CoriMtx = ypr2mat(TgtPos(4:6));
        CoriMtx = CoriMtx(:)';
        
        
    function ConfigureSimpleJudge(id, task_state_config, target, Cori)

        global RTMA;
        global XM;

        Timeout = CalcTaskStateTimeout(task_state_config);

        trans_threshold = nan;
        if (~strcmp(task_state_config.trans_threshold, '-'))
            trans_threshold = str2num(task_state_config.trans_threshold);
        end
        
        ori_threshold = nan;
        if (strcmpi(task_state_config.reach_tgt,'tgt'))
            ori_threshold = XM.ori_threshold;
        end
        trans_judge = task_state_config.trans_judge;
        reach_type = task_state_config.reach_type;
        msg = RTMA.MDF.TASK_STATE_CONFIG;
        msg.id = int32(id);
        msg.rep_num = int32(XM.rep_num);
        msg.use_for_calib = int32(task_state_config.use_for_calibration(1));
        msg.target_combo_index = int32(XM.active_combo_index);
        msg.timed_out_conseq = int32(task_state_config.timed_out_conseq);
        msg.ts_time = GetAbsTime();
        msg.target = target;
        msg.coriMatrix = Cori;
        msg.trans_threshold = trans_threshold;
        msg.ori_threshold = ori_threshold;
        msg.dims = XM.config.dims;
        msg.tgt_sz = XM.tgt_sz;
        msg.timeout = double(Timeout);
        msg.trans_judge(1:length(trans_judge)) = int8(trans_judge);
        msg.reach_type(1:length(reach_type)) = int8(reach_type);
        if isfield(task_state_config, 'tags')
            tags = task_state_config.tags;
            if iscell(tags)
                tags(2:end) = cellfun(@(x) sprintf(' %s',x), tags(2:end), 'un', false);
                tags = cell2mat(tags);
            end
            msg.tags(1:length(tags)) = tags;
        end
        SendMessage('TASK_STATE_CONFIG', msg);
        
    function next_state = HandleTaskStateEnded(id, rcv_event, task_state_config)

        global XM;
        global EVENT_MAP;
        global RTMA;

        next_state = 0;
        if (isempty(rcv_event))
            return;
        end
        
        if (strcmp(rcv_event.msg_type, 'JUDGE_VERDICT'))
            %fprintf('(%s)', rcv_event.data.reason);
            if any(strcmp(rcv_event.data.reason, {'HIT','THRESHOLD'}))
                % if SimpleJudge didn't timeout, invert JUDGE_VERDICT consequence
                % (because ConfigureTaskStateEvents configures it for timeout)
                EVENT_MAP.JUDGE_VERDICT = ~task_state_config.timed_out_conseq;
            end
        end
        
        msg = RTMA.MDF.END_TASK_STATE;
        msg.id = int32(id);
        msg.outcome = int32(EVENT_MAP.(rcv_event.msg_type));
        text = rcv_event.msg_type;
        msg.reason = [int8(str2num(sprintf('%d ', text))) zeros(1, 64-length(text))];
        SendMessage('END_TASK_STATE',msg);
        
        [task_state_config.reward, valid] = CalculateReward(task_state_config.reward);
        if ~valid, fprintf('WARNING: task_state_config.reward is invalid!\n'); end
        
        [task_state_config.consolation, valid] = CalculateReward(task_state_config.consolation);
        if ~valid, fprintf('WARNING: task_state_config.consolation is invalid!\n'); end
        
        switch(EVENT_MAP.(rec_event.msg_type))
            case 0 % failed
                if (XM.runtime.cancel_button_pressed == 1)
                    FailedToStart_state();
                else
                    XM.penalty_time = task_state_config.time_penalty;
                    
                    GiveReward(task_state_config.consolation);
                    
                    if (XM.trial_started)
                        Failed_state();
                    else
                        FailedToStart_state();
                    end
                    
                    if isfield(task_state_config, 'play_sound') && ...
                            (strcmpi(task_state_config.play_sound, 'f') ...
                            || strcmpi(task_state_config.play_sound, 'sf'))
                        msg = RTMA.MDF.PLAY_SOUND;
                        msg.id = int32(1);
                        SendMessage('PLAY_SOUND',msg);
                    end
                end
                next_state = SkipToTaskEndState();
                
            case 1 % success/completion
                % A trial is considered to begin for real when we succeed
                % in a task state thas has been marked "trial_begins"
                if (task_state_config.trial_begins)
                    if (~XM.trial_started)
                        XM.trial_started = true;
                        fprintf('\n Trial started\n');
                    end
                end
                
                % A trial is considered complete after we complete the task state that
                % has been configured as "trial_complete"
                if( task_state_config.trial_complete)
                    fprintf('\n Trial complete\n');
                    Success_state();
                end
                
                % Implement a per task state reward
                GiveReward( task_state_config.reward);
                
                if isfield(task_state_config, 'play_sound') && ...
                        (strcmpi(task_state_config.play_sound, 's') || strcmpi(task_state_config.play_sound, 'sf') )
                    msg = RTMA.MDF.PLAY_SOUND;
                    msg.id = int32(2);
                    SendMessage( 'PLAY_SOUND',msg);
                end
        end

    function ConfigureTaskStateEvents(task_state_config)

        global XM;
        global EVENT_MAP;
        
        %
        % EVENT_MAP.<event name> = <outcome> (0=fail, 1=success)
        %
        EVENT_MAP = struct();
        
        % setup JUDGE_VERDICT msg for reason=TIMED_OUT
        EVENT_MAP.JUDGE_VERDICT = task_state_config.timed_out_conseq;
        
        events = fieldnames(task_state_config.event_mappings);
        for i = 1:length(events)
            event = events{i};
            
            if (strcmpi(task_state_config.event_mappings.(event), 's'))
                EVENT_MAP.(event) = 1;
            elseif (strcmpi(task_state_config.event_mappings.(event), 'f'))
                EVENT_MAP.(event) = 0;
            end
        end
        
        switch (upper(task_state_config.manual_proceed))
            case '-' %% means not configured for manual proceed, so do not add any mapping
            case 'A'  % means manual proceed allowed, so add a mapping for it
                EVENT_MAP.PROCEED_TO_NextState = 1;
            case 'R'  % means manual proceed REQUIRED, so replace all other mappings
                EVENT_MAP = struct();
                EVENT_MAP.PROCEED_TO_NextState = 1;
            otherwise
                error( 'Invalid value for task_state_config.manual_proceed');
        end
        
        switch( upper(task_state_config.manual_cancel))
            case '-'  % means not configured for manual cancel, so do not add any mapping
            case 'A'  % means manual cancel allowed, so add a mapping for it
                EVENT_MAP.PROCEED_TO_Failure = 0;
            otherwise
                error( 'Invalid value for task_state_config.manual_cancel');
        end
        
        if ( ~isempty(fieldnames(EVENT_MAP)))
            EVENT_MAP.XM_ABORT_SESSION = 0;
        end
        
        function idx = SkipToTaskEndState()
            global XM;
            idx = find(XM.config.task_state_config.task_end_state == 1,1,'first');