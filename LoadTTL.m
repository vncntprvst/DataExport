function Trials = LoadTTL(fName)
% get TTL times and structure
% userinfo=UserDirInfo;
Trials=struct('start',[],'end',[],'interval',[],'sampleRate',[],'continuous',[]);
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
    Trials=getOE_Trials(fName);
    %        h5readatt(fName,'/recordings/0/','start_time')==0
    Trials.recordingStartTime=h5read(fName,'/event_types/Messages/events/time_samples');
    Trials.recordingStartTime=Trials.recordingStartTime(1);
    % '/recordings/0/','start_time' has systematic
    % difference with '/event_types/Messages/events/time_samples',
    % because of the time it takes to open files.
elseif contains(fName,'.mat')
    try
        load([fileName{:} '_trials.mat']);
    catch
        Trials=[];
    end
elseif contains(fName,'continuous')
    % Open Ephys format
    try 
        Trials=getOE_Trials('channel_states.npy');
    catch 
    % May be the old format
        Trials=getOE_Trials('all_channels.events');
    end
elseif contains(fName,'nex')
    %% TBSI format
    % not coded yet
elseif contains(fName,'.npy')
    %     cd('..\..');
    exportDirListing=dir(cd); %regexp(cd,'\w+$','match')
    Trials=importdata(exportDirListing(~cellfun('isempty',cellfun(@(x) contains(x,'_trials.'),...
        {exportDirListing.name},'UniformOutput',false))).name);
elseif contains(fName,'.ns') || contains(fName,'.nev')
    %% Blackrock raw data. File extension depends on sampling rate
    %         500 S/s: Records at 500 samples/second. Saved as NS1 file.
    %         1 kS/s: Records at 1k samples/second. Saved as NS2 file.
    %         2 kS/s: Records at 2k samples/second. Saved as NS3 file.
    %         10 kS/s: Records at 10k samples/second. Saved as NS4 file.
    %         30 kS/s: Records at 30k samples/second. Saved as NS5 file.
    %         Raw: Records the raw data at 30k samples/second. Saved as NS6 file.
    
    if contains(fName,'.nev')
        %         NEV=openNEV('read', [dirName filesep fName]);
        load([fName(1:end-3), 'mat'])
        Trials.sampleRate=NEV.MetaTags.SampleRes;
        %find which analog channel has inputs
        TTLChannel=cellfun(@(x) contains(x','ain'),{NEV.ElectrodesInfo.ElectrodeLabel}) & ...
            [NEV.ElectrodesInfo.DigitalFactor]>1000 & [NEV.ElectrodesInfo.HighThreshold]>0;
        if sum(TTLChannel)==0 %then assume TTL was AIN 1
            TTLChannel=cellfun(@(x) contains(x','ainp1'),{NEV.ElectrodesInfo.ElectrodeLabel}) & ...
                [NEV.ElectrodesInfo.DigitalFactor]>1000;
        end
        TTLChannel=NEV.ElectrodesInfo(TTLChannel).ElectrodeID;
        TTL_times=NEV.Data.Spikes.TimeStamp(NEV.Data.Spikes.Electrode==TTLChannel);
        TTL_shapes=NEV.Data.Spikes.Waveform(:,NEV.Data.Spikes.Electrode==TTLChannel);
        artifactsIdx=median(TTL_shapes)<mean(median(TTL_shapes))/10;
        %             figure; plot(TTL_shapes(:,~artifactsIdx));
        Trials.start=TTL_times(~artifactsIdx);
    else
        if contains(fName,filesep)
            analogChannel = openNSx(fName);
        else 
            dataDirListing=dir;
            dataDirListing=dataDirListing(~cellfun('isempty',cellfun(@(x)...
                strcmp(x(1:end-4),fName(1:end-4)) & strfind(x,'.nev'),... % ns2 -> assuming TTL recorded at 1kHz
                {dataDirListing.name},'UniformOutput',false)));
            if size({dataDirListing.name},2)==1
                syncfName=dataDirListing.name;
            else
                syncfName=strrep(fName,'ns6','ns4'); %'nev' ns4: analog channel recorded at 10kHz
            end
            analogChannel = openNSx([cd filesep syncfName]);
%               analogChannel = openNEV([cd filesep syncfName]);
        end
        % openNEV returns struct('MetaTags',[], 'ElectrodesInfo', [], 'Data', []);
        % openNSx returns  struct('MetaTags',[],'Data',[], 'RawData', []);
        % in some other version, openNSx also returned 'ElectrodesInfo'
%       %send sync TTL to AIN1, which is Channel 129 (AIN2 is 130)
        TTLchannelID = 130;
        if sum(ismember([analogChannel.MetaTags.ChannelID], TTLchannelID)) %check that it is present
            analogChannels=find(ismember([analogChannel.MetaTags.ChannelID], TTLchannelID));
%         if sum(cellfun(@(x)
%         contains(x,'ainp1'),{analogChannel.ElectrodesInfo.Label}));
%             analogChannels=cellfun(@(x) contains(x,'ainp1'),{analogChannel.ElectrodesInfo.Label})
        elseif sum(cellfun(@(x) contains(x,'D'),{analogChannel.ElectrodesInfo.ConnectorBank}))
            analogChannels=cellfun(@(x) contains(x,'D'),{analogChannel.ElectrodesInfo.ConnectorBank});
        end
        Trials.continuous=analogChannel.Data(analogChannels,:); 
        if ~isempty(Trials.continuous) && ~iscell(Trials.continuous)
            [TTLtimes,TTLdur]=ContinuousToTTL(Trials.continuous,'keepfirstonly');
            Trials=ConvTTLtoTrials(TTLtimes,TTLdur,analogChannel.MetaTags.SamplingFreq);
        end
    end
end

