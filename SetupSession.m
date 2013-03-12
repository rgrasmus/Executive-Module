function SetupSession

    % XM is a global structure that serves as a storage container for
    % everything that the eXecutive Module needs to run, including
    % configuration data and run-time data
    global XM;
    global RTMA;
    global COMMAND_LINE_ARGUMENTS;

    rand('twister',sum(100*clock))

    % Here we initialize XM
    XM = [];

	% init runtime
	XM.runtime = [];

	DisplayMessageToUser('Initializing XM structure');
    
    %--- Command line parameters
    XM.RobotAppDir = getenv('ROBOTAPP'); 
    XM.RobotConfigDir = getenv('ROBOT_CONFIG'); 
    XM.RobotDataDir = getenv('ROBOTDATA'); 
    
    
    %--- config file
    XM.config_file_name  = COMMAND_LINE_ARGUMENTS.ConfigFile;
    main_config_file_dir = fileparts( XM.config_file_name);
    XM.config_files_dir  = GetAbsoluteDir( [main_config_file_dir '/']);
    XM.last_subject_file = [XM.config_files_dir '/last_subject.txt'];

    
    %--- session configuration
    XM.session_type      = 0;  % selected session type
    XM.session_num       = 0;
    XM.subject_name      = []; % [string] name of the subject to use
    XM.config            = []; % [structure] data read from XM config file (see below)
    XM.load_calibration  = [];
    XM.calib_session_id  = [];
    XM.prev_session_dir  = [];
    
    %--- data logging and buffering
    XM.data_dir         = GetAbsoluteDir( [XM.RobotDataDir '/']);
    XM.session_dir      = [];
    XM.session_datafile_basepath = [];

    
    %--- session variables
    XM.num_times_tried_combo = []; % [1 x num_combos] number of times each target was tried
    XM.combos_to_be_tried    = []; % initially [1 x num_combos],
                                    % then targets could be dropped
                                    % from this array: indices of
                                    % targets that are yet to be
                                    % tried
    XM.cur_tgt_num       = [];
    XM.ori_threshold     = [];
    XM.tgt_sz            = [];
    
    XM.num_reps    = []; % total number of reps (sent via XM_START_SESSION)
    XM.rep_num     = 0;  % current repetition number (have to complete all targets in order to go to the next rep)
    XM.trial_num   = 0;  % trial number only advances for real trials (i.e. ones that get past the "trial_begins" state)
    XM.file_num    = 1;  % used for file names, increments continuously (not correlated with trial numbers)
    XM.aborting_session = false; % [bool] whether or not we have received a signal to abort the session

   
    %--- trial variables
    XM.active_combo_index       = -1;
    XM.active_tool_id           = -1;
    XM.trial_started = false;% indicates whether the current trial started for real
    XM.penalty_time = 0; % Penalty time in the InterTrial_state
    
    %--- vr variables
    XM.VR_TGT = [];
    XM.VR_TGT.CurrentMoveID = 0;
    %XM.Denso.MoveInProgress = false;

    
    % Set a new random seed for each and store it in case we need to replicate the pseudo-random sequence offline later.
    % (Determines the sequence of target presentation and other pseudo-random values).
    XM.random_method = 'state';
    rand( XM.random_method, sum(1000*clock));
    XM.random_seed = rand( XM.random_method);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % CONFIG FILE PARAMETERS (default values are specified below- so you can copy them to create a config file) %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %---
    XM.config.num_reps                 =  0;  % how many repetitions should we do over the whole targets array
    XM.config.max_num_tries_per_target = 1; % what is the maximal
                                             % number of tries for
                                             % a target, before it
                                             % will never be shown
                                             % again. -1 means try
                                             % this target forever
                                             % until succeeded
    XM.config.do_video = 0;

 
    %--- Task state config files
    XM.config.task_state_config_file     = ''; % [cell array] holding string names of task state config files

    
    %--- Task state configuration  - relates to LOGICAL task states, not
    %    the actual state functions. It is saved in XM.<task description>.task_state.config
    XM.config.task_state_config             = [];% [structure] current task state configuration loaded from the file

    %--- Robot config
    XM.config.vr_control_mode    = '';   % A string of 'V'-s and 'P'-s for velocity or position control
    XM.EM_used_dimensions = [];
    XM.new_config = [];  % When GUI module sends an updated config, EventHook puts it in here, so we can apply it in SetupTrial

    %----- load config file
    CallFailSafe('LoadXMConfigFile', XM.config_file_name);

    if( isfield( XM.config, 'manual_session_start') && XM.config.manual_session_start)
    
        %--- Read the last_subject file to see which subject's config to load
        XM.LatestSubject = strtrim( fileread(XM.last_subject_file));
        if( isempty( XM.LatestSubject))
           XM.subject_name = strtrim(input( ['Please enter the name of the subject: '], 's'));
        else
           response = strtrim(input(['\nThe last subject was ' XM.LatestSubject ...
                                     ', press ENTER to keep the same subject ' ...
                                     'or type a different subject name: '], 's'));
           if( isempty( response))
               XM.subject_name = XM.LatestSubject;
           else
               XM.subject_name = response;
           end
        end

    else

        % Wait for appman_gui to send parameters
        disp 'Waiting for XM_START_SESSION.. (if not using appman_gui, set XM.config.manual_session_start to 1)'
        ExpectedEvents = {'XM_START_SESSION', 'PING'};
        while(1)
            RcvMsg = WaitFor(100, ExpectedEvents{:});
            if strcmp(RcvMsg.msg_type, 'XM_START_SESSION'),  break;  end
        end

        XM.subject_name = deblank(char(RcvMsg.data.subject_name));

        disp(['Subject: "' XM.subject_name '"']);
        
        % from XM_START_SESSION message (appman_gui)
        XM.load_calibration = RcvMsg.data.load_calibration;
        XM.calib_session_id = RcvMsg.data.calib_session_id;

        if (XM.load_calibration == 1)
            disp(['Loading calibration data from session #' num2str(XM.calib_session_id)]);
            prev_session_basepath = [XM.data_dir '/' XM.subject_name '/Raw/' XM.subject_name '.DK'];
            prev_session_num_str = num2str(XM.calib_session_id,'%.5d');
            XM.prev_session_dir = [prev_session_basepath '.' prev_session_num_str];
        end

        if (RcvMsg.data.num_reps > 0)
            XM.num_reps = RcvMsg.data.num_reps;
        end
    end
    
    XM.max_reps = sum((XM.config.task_state_start_tgts):(XM.config.task_state_stop_tgts))*XM.config.num_rep_per_state_tgt;
    
    %----- pick the next session number by looking at the last session number
    %      in the exising data files. Also constructs a base file name for data files ofsnd
    %      this session. Diffent extensions will be tacked on the base name elsewhere
    %      in this module to form file names for different kinds of data files.
    [XM.session_num, XM.session_dir, XM.session_datafile_basepath, XM.last_session_num] = DetermineSessionNumber(); % 

    %---- Create directory for data files for this session
    [Success, Message, MessageID] = mkdir( XM.session_dir);
    if( ~Success), error( 'Could not create session data directory'); end
    switch( MessageID)
       case 'MATLAB:MKDIR:DirectoryExists', error( 'Session data directory already exists!');
    end

    RTMA_FilePath = [XM.session_datafile_basepath 'RTMA_config.mat'];
    save( RTMA_FilePath, 'RTMA');

 	FlushQuickLogger();    

    % Write the selected subject to file, so the same choice can be
    % presented next time
    f = fopen( XM.last_subject_file, 'wt');
    fprintf( f, '%s', XM.subject_name);
    fclose( f);        

    % send out session information for other modules to use
    fprintf('Sending SESSION_CONFIG\n');
    sc = RTMA.MDF.SESSION_CONFIG;
    sc.data_dir(1:length(XM.session_dir)) = XM.session_dir;
    SendMessage('SESSION_CONFIG', sc);

    DisplayMessageToUser( ['This is session #' num2str(XM.session_num)]);

    % if executive was started with config file, 
    % initialize XM.load_calibration and XM.load_calibration
    % (ie ask about loading prev session's calibration data)
    if isempty(XM.load_calibration)
        done = false;
        while ~done
            response = strtrim(input('\nLoad existing calibration? (ENTER=No, (L)ast session, ###=specific session): ', 's'));

            if ~isempty( response)
                session_no = str2num(response);
                
                if ~isempty(session_no)
                    XM.calib_session_id = session_no;
                    XM.load_calibration = 1;
                    disp(['Loading calibration data from session #' num2str(session_no)]);
                elseif strcmpi(response, 'L')
                    XM.calib_session_id = XM.last_session_num;
                    XM.load_calibration = 1;
                    disp(['Loading calibration data from last session (#' num2str(XM.last_session_num) ')']);
                else
                    fprintf('ERROR: I didn''t get that, please try again\n');
                end
                
                prev_session_basepath = [XM.data_dir '/' XM.subject_name '/Raw/' XM.subject_name '.DK'];
                prev_session_num_str = num2str(XM.calib_session_id,'%.5d');
                XM.prev_session_dir = [prev_session_basepath '.' prev_session_num_str];
                
                if ~exist(XM.prev_session_dir, 'dir')                
                   fprintf('ERROR: Session number you selected doesn''t exist\n');
                else
                   done = true;
                end
            else
                XM.load_calibration = 0;
                done = true;
            end
        end
    end
    
    % Now XM.load_calibration and XM.load_calibration should both be initialized 
    % no matter how executive was started (ie, with or without config)
    if (XM.load_calibration == 1)
       data_file_pattern = [XM.prev_session_dir '/CM*'];

       % Get a listing of CM files and find the final calibration file
       file_list = mv_dir( data_file_pattern);            
       if ~isempty(file_list)
           rep_nos = regexp(strcat(file_list{:}), 'CM\.rep\.(\d+).mat', 'tokens');
           rep_nos = [rep_nos{:}];
           rep_nos = cellfun(@(x) str2num(x), rep_nos);
           calib_file = [XM.prev_session_dir '/CM.rep.' num2str(max(rep_nos)) '.mat'];

           % Tell CM to load it and update EM as well
           fprintf('Sending LOAD_DECODER_CONFIG\n');
           ldc = RTMA.MDF.LOAD_DECODER_CONFIG;
           ldc.full_path(1:length(calib_file)) = calib_file;
           SendMessage('LOAD_DECODER_CONFIG', ldc);

           % Advance XM.rep_num to the end of calibration reps
           % (when SetupTrial() runs, it will update it to right after calibration)
           XM.rep_num = XM.config.task_state_config_schedule(end) - 1;
       else
           error('ERROR: The session you selected has no calibration files\n');
       end
       
    else
        disp('Starting new calibration');

    end

    %--- Initialize video
    if(XM.config.do_video)
        system(['echo exit | nc -q 0 ' XM.config.camera_ip ' ' num2str(XM.config.camera_port)]);
        pause(1.0);
        system(['echo ' XM.subject_name '.DK.' num2str(XM.session_num)  '| nc -q 0 ' XM.config.camera_ip ' ' int2str(XM.config.camera_port)]);
    end


    XM.pausing_experiment = false;
end

