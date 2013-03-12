function MoveVRToPresentationPos(task_state_config)

% MoveDensoToPresentationPos( task_state_config)
%
% Moves DENSO robot to the presentation position that has been selected for
% the current trial

global XM;

if strcmp(task_state_config.present_target, '-') == 0
    
    if strcmp(task_state_config.present_target, 'tgt')
        tgt = XM.CPacks(XM.active_combo_index,:);
        target = [tgt(1:3) 0 tgt(4:6)];
        Cori = ypr2mat(tgt(4:6));
        Cori = Cori(:)';
        MoveTarget('Present', target, Cori);
    elseif strcmp(task_state_config.present_tgt, 'home')
        target = zeros(1,7);
        Cori = eye(3);
        Cori = Cori(:)';
        MoveTarget('Home', target, Cori);
    end
end