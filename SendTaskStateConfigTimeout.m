function SendTaskStateConfigTimeout(id, timeout)
    
    global RTMA;
    global XM;

    msg = RTMA.MDF.TASK_STATE_CONFIG;
    msg.id = int32(id);
    msg.rep_num = int32(XM.rep_num);
    %msg.timed_out_conseq = int32(1);
    msg.ts_time = GetAbsTime( );
    msg.trans_threshold = nan;
    msg.ori_threshold = nan;
    msg.timeout = double(timeout);
    SendMessage( 'TASK_STATE_CONFIG', msg);