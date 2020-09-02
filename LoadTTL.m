function TTLs = LoadTTL(fName)
% get TTL times and structure
% userinfo=UserDirInfo;
TTLs=struct('start',[],'end',[],'interval',[],'sampleRate',[],'continuous',[]);
if contains(fName,'raw.kwd')
    fNameArg=fName;
    %% Kwik format - raw data
    fName=regexp(fName,'^\w+\d\_','match');
    if isempty(fName)
        cd(regexp(fNameArg,['.+(?=\' filesep '.+$)'],'match','once'))
        fName='experiment1.kwe';
    else
        fileListing=dir;
        fName=fName{1}(1:end-1);
        %making sure it exists
        fName=fileListing(cellfun(@(x) contains(x,[fName '.kwe']),{fileListing.name},...
            'UniformOutput',true)).name;
    end
    TTLs=getOE_Trials(fName);
    %        h5readatt(fName,'/recordings/0/','start_time')==0
    TTLs.recordingStartTime=h5read(fName,'/event_types/Messages/events/time_samples');
    TTLs.recordingStartTime=TTLs.recordingStartTime(1);
    % '/recordings/0/','start_time' has systematic
    % difference with '/event_types/Messages/events/time_samples',
    % because of the time it takes to open files.
elseif contains(fName,'.mat')
    try
        load([fileName{:} '_trials.mat']);
    catch
        TTLs=[];
    end
elseif contains(fName,'continuous')
    % Open Ephys format
    try
        TTLs=getOE_Trials('channel_states.npy');
    catch
        % May be the old format
        TTLs=getOE_Trials('all_channels.events');
    end
elseif contains(fName,'.bin')
    TTLs = memmapfile(fullfile(cd,'ttl.bin'),'Offset',14,'Format','int8');
    TTLs = TTLs.Data(TTLs.Data~=0);
    figure; plot((TTLs(1:300000)))
    figure; plot(diff(TTLs(1:300000)))
    sum(diff(TTLs)==1)
elseif contains(fName,'nex')
    %% TBSI format
    % not coded yet
elseif contains(fName,'.npy')
    %     cd('..\..');
    exportDirListing=dir(cd); %regexp(cd,'\w+$','match')
    TTLs=importdata(exportDirListing(~cellfun('isempty',cellfun(@(x) contains(x,'_trials.'),...
        {exportDirListing.name},'UniformOutput',false))).name);
elseif contains(fName,'.ns') || contains(fName,'.nev')
    %% Blackrock raw data. File extension depends on sampling rate
    %         500 S/s: Records at 500 samples/second. Saved as NS1 file.
    %         1 kS/s: Records at 1k samples/second. Saved as NS2 file.
    %         2 kS/s: Records at 2k samples/second. Saved as NS3 file.
    %         10 kS/s: Records at 10k samples/second. Saved as NS4 file. e.g., TTLs
    %         30 kS/s: Records at 30k samples/second. Saved as NS5 file.
    %         Raw: Records the raw data at 30k samples/second. Saved as NS6 file.
    TTLchannelIDs = [129, 130, 131];
    
    %% check NEV file first, even if NS file is in argument
    % NEV files contain records of digital pin events, where TTL should be
    %     if contains(fName,'.nev')
    NEVdata=openNEV([fName(1:end-3), 'nev']);
    sampleRate=double(NEVdata.MetaTags.SampleRes);
    digInEvents=NEVdata.Data.SerialDigitalIO.UnparsedData;
    digInTimes=double(NEVdata.Data.SerialDigitalIO.TimeStamp); %TimeStampSec i interval in ms?
    
    % Given 2 inputs in Port 0 and 1
    % No input              => bin2dec('00') = 0
    % input on Port 0 only  => bin2dec('10') = 2
    % input on Port 1 only  => bin2dec('01') = 1
    % input on both ports   => bin2dec('11') = 3
    
    TTL_ID=logical(dec2bin(digInEvents)-'0');
    if ~isempty(TTL_ID)
        clear TTLs;
        for TTLChan=size(TTL_ID,2):-1:1
            TTLIdx=bwconncomp(TTL_ID(:,TTLChan));%'PixelIdxList'
            if ~isempty(TTLIdx)
                if TTLIdx.NumObjects==1 %e.g., when only camera sync TTL, no laser pulses
                    TTLdur=mode(diff(digInTimes(TTLIdx.PixelIdxList{1, 1})))/2; % assuming 50% cycle
                    TTLIdx=TTLIdx.PixelIdxList{:};
                else
                    TTLdur=mode(cellfun(@(pulse) digInTimes(pulse(end))-digInTimes(pulse(1))+1,...
                        TTLIdx.PixelIdxList));
                    TTLIdx=cellfun(@(pulse) pulse(1), TTLIdx.PixelIdxList);
                end
                try
                    TTLs{size(TTL_ID,2)-TTLChan+1}=...
                        ConvTTLtoTrials(digInTimes(TTLIdx),TTLdur,sampleRate);
                catch
                    continue;
                end
            else
                continue;
            end
        end
        
    elseif contains(fName,'.nev')
        %find which analog channel has inputs
        TTLChannel=cellfun(@(x) contains(x','ain'),{NEVdata.ElectrodesInfo.ElectrodeLabel}) & ...
            [NEVdata.ElectrodesInfo.DigitalFactor]>1000 & [NEVdata.ElectrodesInfo.HighThreshold]>0;
        if sum(TTLChannel)==0 %then assume TTL was AIN 1
            TTLChannel=cellfun(@(x) contains(x','ainp1'),{NEVdata.ElectrodesInfo.ElectrodeLabel}) & ...
                [NEVdata.ElectrodesInfo.DigitalFactor]>1000;
        end
        
        TTLChannel=NEVdata.ElectrodesInfo(TTLChannel).ElectrodeID;
        TTL_times=NEVdata.Data.Spikes.TimeStamp(NEVdata.Data.Spikes.Electrode==TTLChannel);
        TTL_shapes=NEVdata.Data.Spikes.Waveform(:,NEVdata.Data.Spikes.Electrode==TTLChannel);
        artifactsIdx=median(TTL_shapes)<mean(median(TTL_shapes))/10;
        %             figure; plot(TTL_shapes(:,~artifactsIdx));
        TTLs.start=TTL_times(~artifactsIdx);
    else % check analog channels in NS file
        if contains(fName,filesep)
            analogChannel = openNSx(fName);
        else
            try
                syncfName=strrep(fName,'ns6','ns4'); %'nev' ns4: analog channel recorded at 10kHz
                analogChannel = openNSx([cd filesep syncfName]);
            catch
                syncfName=strrep(fName,'ns6','ns2'); %ns2 -> TTL recorded at 1kHz (old setup)
                analogChannel = openNSx([cd filesep syncfName]);
            end
            %               analogChannel = openNEV([cd filesep syncfName]);
        end
        % openNEV returns struct('MetaTags',[], 'ElectrodesInfo', [], 'Data', []);
        % openNSx returns  struct('MetaTags',[],'Data',[], 'RawData', []);
        % in some other version, openNSx also returned 'ElectrodesInfo'
        %       %send sync TTL to AIN1, which is Channel 129. AIN2 is 130. AIN3 is 131
        
        if any(ismember([analogChannel.MetaTags.ChannelID], TTLchannelIDs)) %check that it is present
            analogChannels=find(ismember([analogChannel.MetaTags.ChannelID], TTLchannelIDs));
            %         if sum(cellfun(@(x)
            %         contains(x,'ainp1'),{analogChannel.ElectrodesInfo.Label}));
            %             analogChannels=cellfun(@(x) contains(x,'ainp1'),{analogChannel.ElectrodesInfo.Label})
        elseif any(cellfun(@(x) contains(x,'D'),{analogChannel.ElectrodesInfo.ConnectorBank}))
            analogChannels=cellfun(@(x) contains(x,'D'),{analogChannel.ElectrodesInfo.ConnectorBank});
        end
        analogTTLTrace=analogChannel.Data(analogChannels,:); %send sync TTL to AINP1
        if ~isempty(analogTTLTrace) && ~iscell(analogTTLTrace)
            clear TTLs;
            for TTLChan=1:size(analogTTLTrace,1)
                [TTLtimes,TTLdur]=ContinuousToTTL(analogTTLTrace(TTLChan,:),analogChannel.MetaTags.SamplingFreq,'keepfirstonly');
                if ~isempty(TTLtimes)
                    TTLs{TTLChan}=ConvTTLtoTrials(TTLtimes,TTLdur,analogChannel.MetaTags.SamplingFreq);
                end
            end
            if size(TTLs,2)==1
                TTLs=TTLs{1};
            end
        end
    end
end

