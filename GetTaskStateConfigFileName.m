%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function task_state_config_file_name = GetTaskStateConfigFileName( )
%   task_state_config_file_name = GetTaskStateConfigFileName( )
%   
%   OUTPUT: task_state_config_file_name = file name from XM.config.state_task_config_files
%   
%   Looks in XM.config.task_state_config_schedule and figures out what file
%   name index in XM.config.task_state_config_files should be used
%   Then returns the file name corresponding to that index

    global XM;
    
    task_state_config_file_name      = XM.config.task_state_config_file;