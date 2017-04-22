function Trials = LoadTTL(fName)
% get TTL times and structure
userinfo=UserDirInfo;
Trials=struct('start',[],'end',[],'interval',[],'sampleRate',[],'continuous',[]);
if contains(fName,'raw.kwd')
    %% Kwik format - raw data
    fileListing=dir;
    fName=regexp(fName,'^\w+\d\_','match');fName=fName{1}(1:end-1);
    %making sure it exists
    fName=fileListing(~cellfun('isempty',cellfun(@(x) contains(x,[fName '.kwe']),{fileListing.name},'UniformOutput',false))).name;
    Trials=getOE_Trials(fName);
    %        h5readatt(fName,'/recordings/0/','start_time')==0
    Trials.startClockTime=h5read(fName,'/event_types/Messages/events/time_samples');
    Trials.startClockTime= Trials.startClockTime(1);
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
    %% Open Ephys old format
    Trials=getOE_Trials('all_channels.events');
elseif contains(fName,'nex')
    %% TBSI format
    % not coded yet
elseif contains(fName,'.npy')
    %     cd('..\..');
    exportDirListing=dir(cd); %regexp(cd,'\w+$','match')
    Trials=importdata(exportDirListing(~cellfun('isempty',cellfun(@(x) contains(x,'_trials.'),...
        {exportDirListing.name},'UniformOutput',false))).name);
elseif contains(fName,'.ns') | contains(fName,'.nev')
    %% Blackrock raw data. File extension depends on sampling rate
    %         500 S/s: Records at 500 samples/second. Saved as NS1 file.
    %         1 kS/s: Records at 1k samples/second. Saved as NS2 file.
    %         2 kS/s: Records at 2k samples/second. Saved as NS3 file.
    %         10 kS/s: Records at 10k samples/second. Saved as NS4 file.
    %         30 kS/s: Records at 30k samples/second. Saved as NS5 file.
    %         Raw: Records the raw data at 30k samples/second. Saved as NS6 file.
    
    if contains(fName,'.nev')
        %         NEV=openNEV('read', [dirName '\' fName]);
        load([fName(1:end-3), 'mat'])
        Trials.sampleRate=NEV.MetaTags.SampleRes;
        %find which analog channel has inputs
        TTLChannel=NEV.ElectrodesInfo(cellfun(@(x) contains(x','ain'),...
            {NEV.ElectrodesInfo.ElectrodeLabel}) & ...
            [NEV.ElectrodesInfo.DigitalFactor]>1000 & ...
            [NEV.ElectrodesInfo.HighThreshold]>0).ElectrodeID;
            TTL_times=NEV.Data.Spikes.TimeStamp(NEV.Data.Spikes.Electrode==TTLChannel);
            TTL_shapes=NEV.Data.Spikes.Waveform(:,NEV.Data.Spikes.Electrode==TTLChannel);
            artifactsIdx=median(TTL_shapes)<mean(median(TTL_shapes))/10;
%             figure; plot(TTL_shapes(:,~artifactsIdx));
            Trials.start=TTL_times(~artifactsIdx);
    else
        dataDirListing=dir;
        dataDirListing=dataDirListing(~cellfun('isempty',cellfun(@(x) strncmp(x,fName,8) & strfind(x,'.ns'),...
            {dataDirListing.name},'UniformOutput',false)));
        fName=dataDirListing.name;
        analogChannel = openNSx([cd userinfo.slash fName]);
        Trials.continuous=analogChannel.Data;
        if ~isempty(Trials.continuous) & ~iscell(Trials.continuous)
            Trials.sampleRate=analogChannel.MetaTags.SamplingFreq;
            Trials.continuous=Trials.continuous(end,:)-min(Trials.continuous(end,:));
            TTL_times=uint64(find(diff(Trials.continuous>rms(Trials.continuous)*5)))';
            if min(diff(TTL_times))<median(diff(TTL_times))-2
                %remove spurious pulses
                spurPulses=find(diff(TTL_times)<median(diff(TTL_times))-2);
                spurPulses=sort([spurPulses+1; spurPulses]); %remove also time point before
                TTL_times(spurPulses)=0;
                TTL_times=TTL_times(logical(TTL_times));
            end
            if mode(diff(TTL_times))==1 | isempty(TTL_times)%no trials, just artifacts
                [Trials.start, Trials.end,TTL_ID,Trials]=deal(0);
            else
                Trials.start=find(diff(Trials.continuous>rms(Trials.continuous)*5)==1);
                Trials.end=find(diff(Trials.continuous<rms(Trials.continuous)*5)==1);
                TTL_ID=zeros(size(TTL_times,1),1);
                if Trials.end(1)-Trials.start(1)>0 %as it should
                    TTL_ID(1:2:end)=1;
                else
                    TTL_ID(2:2:end)=1;
                end
                Trials=ConvTTLtoTrials(TTL_times,samplingRate,TTL_ID);
            end
        end
    end
end

