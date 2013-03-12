function MoveTarget(PosName, TgtLoc, Cori)

% MoveDenso( PosName, PosNumber)
%
% Move the DENSO robot to named position PosName.
% PosName can be 'Present', 'Away' or 'Hide'. If PosName
% is 'Present', then PosNumber is target_denso_moveID

    global XM;
    global RTMA;
    switch PosName
        case 'Present'
            SendMessage('JVR_HIDE_HOME');
            SendMessage('JVR_SHOW_TGT');
            vrm = RTMA.MDF.JVR_SET_TGT_POS;
            
            XM.VR_TGT.CurrentMoveID = XM.VR_TGT.CurrentMoveID + 1;
            
            vrm.sernum = uint32(XM.VR_TGT.CurrentMoveID);
            vrm.pos = TgtLoc(1:3);
            vrm.orimtx = Cori;
            SendMessage('JVR_SET_TGT_POS', vrm);
        case 'Home'            
            SendMessage('JVR_HIDE_TGT');
            SendMessage('JVR_SHOW_HOME');
            vrm = RTMA.MDF.JVR_SET_HOME_POS;
            XM.VR_TGT.CurrentMoveID = XM.VR_TGT.CurrentMoveID+1;
            
            vrm.sernum = uint32(XM.VR_TGT.CurrentMoveID);
            vrm.pos = TgtLoc(1:3);
            vrm.orimtx = Cori;
            SendMessage('JVR_SET_HOME_POS',vrm);
    end
    