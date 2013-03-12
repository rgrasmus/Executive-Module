function Message = DoExit()
    SendSignal XM_END_OF_SESSION
    SendSignal EXIT_ACK
    DisconnectFromMMM
    exit