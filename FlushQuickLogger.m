%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function FlushQuickLogger( )

    global RTMA;
    global XM;

    fprintf('Flushing QuickLogger..');

    % Create file name for QuickLogger module
    QL_FilePath = [XM.session_datafile_basepath 'Flush.bin'];

    % Tell QuickLogger module to save its data
    saveinfo = RTMA.MDF.SAVE_MESSAGE_LOG;
    saveinfo.pathname(1:length(QL_FilePath)) = uint8(QL_FilePath);
    saveinfo.pathname_length = int32( length(QL_FilePath));
    SendMessage( 'SAVE_MESSAGE_LOG', saveinfo);

    ExpectedEvents = {'MESSAGE_LOG_SAVED'};
    WaitForAsync( 100, 20, ExpectedEvents{:});
    %WaitFor( 100, ExpectedEvents{:});
    
    fprintf('done\n');
