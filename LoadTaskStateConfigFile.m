function LoadTaskStateConfigFile( FileName)
%   LoadTaskStateConfigFile( FileName)
%
%   Loads a task state config file, given by FileName into XM.config.task_state_config
%   FileName should be the file name (not path) of the config file. If
%   "mode" is 'verify' then loads the file and performs consistence checks
%   but does not assign them to XM. If no arguments are specified, then
%   just loads the task state config for the current rep.

    global XM;

    config_file_path = [XM.config_files_dir '/' FileName];
    VerifyFileExists(config_file_path);

    % DisplayMessageToUser( [caller_name '(): loading task_state_config file ' config_file_path]);
    fprintf('\nUsing task state config file: %s\n', FileName);
    c = LoadValidateConfigFile(config_file_path, {['task_state_config.' 'state_names,' ...
                                                                        'skip_state,' ...
                                                                        'trial_begins,' ...
                                                                        'trial_complete,' ...
                                                                        'task_end_state,' ...
                                                                        'manual_proceed,' ...
                                                                        'manual_cancel,' ...
                                                                        'reward,' ...
                                                                        'consolation,' ...
                                                                        'time_penalty,' ...
                                                                        'timeout,' ...
                                                                        'timeout_range_percent,' ...
                                                                        'timed_out_conseq,' ...
                                                                        'present_target,' ...
                                                                        'reach_target,' ...
                                                                        'trans_threshold,' ...
                                                                        'event_mappings,' ...
                                                                        'use_for_calibration,', ...
                                                                        'dim_domains,' ...
                                                                        'auto_command_fraction,' ...
                                                                        'vf_orth_impedance'] });


    % repmat the rows of start_collection and end_collection so we don't need to
    % have so many rows in config file - they're always kept the same anyway
    max_control_dims = length(XM.config.robot_control_dims);

    num_use_for_calibration_rows = size(c.task_state_config.use_for_calibration, 1);
    if num_use_for_calibration_rows == 1
        c.task_state_config.use_for_calibration = repmat(c.task_state_config.use_for_calibration, [max_control_dims, 1]);
    end

    row_cnt = length(c.task_state_config.dim_domains);
    max_col_cnt = length(c.task_state_config.state_names);

    auto_command_fraction = ones(max_control_dims, max_col_cnt);
    for r = 1 : row_cnt
        idx = c.task_state_config.dim_domains{r};
        if (ischar(idx)), idx = str2num(idx); end
        auto_command_fraction(idx, :) = repmat(c.task_state_config.auto_command_fraction(r, :), length(idx) ,1);
    end
    c.task_state_config.auto_command_fraction = auto_command_fraction;

    vf_orth_impedance = zeros(max_control_dims, max_col_cnt);
    for r = 1 : row_cnt
        idx = c.task_state_config.dim_domains{r};
        if (ischar(idx)), idx = str2num(idx); end
        vf_orth_impedance(idx, :) = repmat(c.task_state_config.vf_orth_impedance(r, :), length(idx) ,1);
    end
    c.task_state_config.vf_orth_impedance = vf_orth_impedance;

    XM.config.task_state_config = c.task_state_config;