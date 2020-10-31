function [rec,data,spikes,TTLs] = LoadEphysData(fname,dname)
wb = waitbar( 0, 'Reading Data File...' );
currDir=cd;
cd(dname);
spikes=struct('clusters',[],'electrodes',[],'spikeTimes',[],'waveForms',[],'metadata',[]);
try
    dirBranch=regexp(strrep(dname,'-','_'),['\' filesep '\w+'],'match');
    rec.dirName=dname;
    rec.fileName=fname;
    disp(['loading ' dname filesep fname]);
    if contains(fname,'.bin')
        %% Binary file from Intan/Paul's Julia interface
        prompt = {'Enter number of recorded channels:'};
        title = 'Channel list';
        dims = [1 32];
        definput = {'1'};
        rec.numRecChan = str2double(cell2mat(inputdlg(prompt,title,dims,definput)));
        %             rec.numRecChan=1:32; % need to ask user
        traces = memmapfile(fullfile(dname,fname),'Format','int16');
        data=traces.Data;
        if ~logical(mod(length(data),8)) % 8 analog channels
            rec.dur=int32(length(data)/8);
            data=reshape(data,[8 rec.dur]);
            data=data(1:rec.numRecChan,:);
        elseif ~logical(mod(length(data),numel(rec.numRecChan))) %presumed single channel
            rec.dur=int32(length(data)/(numel(rec.numRecChan)));
            data=reshape(data,[numel(rec.numRecChan) rec.dur]);
            data=data(1:rec.numRecChan,:);
        else
            disp('unexpected number of samples. Abort')
            return
        end
        if strcmp(fname,'v.bin') && exist(fullfile(dname,'ts.bin'),'file')
            rec.sys='Intan';
            % load timestamps
            sampleTimes=memmapfile(fullfile(dname,'ts.bin'),'Format','int64');
            rec.timeStamps=sampleTimes.Data;
            rec.recordingStartTime=rec.timeStamps(1);
            rec.samplingRate=30000; % SampleRateString="30.0 kS/s" Duh
            rec.bitResolution=0.195;
            FileInfo = dir(fname);
            rec.data = FileInfo.date;
        end
    elseif contains(fname,'.dat')
        %% Binary file (e.g., exported data or Open Ephys binary)
        % need to know how many channels
        try
            rec = readOpenEphysXMLSettings(['..' filesep '..' filesep ...
                '..' filesep '..' filesep 'settings.xml']);
            ephysChannelsIdx=cellfun(@(x) str2double(x), rec.signals.channelInfo.channelGain)>0.1;
            rec.numRecChan=rec.signals.channelInfo.channelNumber(ephysChannelsIdx)+1;
            if isfield(rec.signals.channelInfo,'Mapping')
                rec.channelMapping=rec.signals.channelInfo.Mapping(ephysChannelsIdx);
            else %no mapping module
                rec.channelMapping=rec.signals.channelInfo.channelNumber(ephysChannelsIdx);
            end
            rec.date=rec.setupinfo.date;
            rec.samplingRate=30000; % SampleRateString="30.0 kS/s" Duh
            rec.bitResolution=0.195; %(2.45 V)/(2^16)  =  37.4 ?V.  amplifier  gain  of  192 -> 0.195 ?V
            rec.sys='OpenEphys';
            % load timestamps
            rec.timeStamps=readNPY('timestamps.npy');
            rec.recordingStartTime=rec.timeStamps(1); % should be the same as start time in sync_messages.txt
        catch
            prompt = {'Enter number of recorded channels:'};
            title = 'Channel list';
            dims = [1 32];
            definput = {'1:32'};
            rec.numRecChan = str2double(cell2mat(inputdlg(prompt,title,dims,definput)));
            %             rec.numRecChan=1:32; % need to ask user
            rec.date='';
            rec.samplingRate=30000;
            rec.bitResolution=0.195; %assuming Intan / OpenEphys
            rec.sys='';
        end
        traces = memmapfile(fullfile(dname,fname),'Format','int16');
        data=traces.Data;
        if ~logical(mod(length(data),numel(rec.numRecChan)))
            rec.dur=int32(length(data)/(numel(rec.numRecChan)));
            data=reshape(data,[numel(rec.numRecChan) rec.dur]);
        elseif ~logical(mod(length(data),numel(rec.numRecChan)+3)) %AUX channels in data array
            rec.dur=int32(length(data)/(numel(rec.numRecChan)+3));
            data=reshape(data,[numel(rec.numRecChan)+3 rec.dur]);
        else
            disp('unexpected number of samples. Abort')
            return
        end
        if numel(rec.numRecChan)==1
            data=data(1:rec.numRecChan,:);
        else
            data=data(rec.numRecChan,:);
        end
        %% get spike data
        try
            %             cd(['..' filesep '..' filesep ])
            %             cd spikes
            spikeFiles = cellfun(@(fileFormat) dir(['..' filesep '..' filesep 'spikes'...
                filesep '**' filesep fileFormat]),...
                {'*.npy'},'UniformOutput', false);
            clusFIdx=cellfun(@(x) contains(x,'spike_clusters'), {spikeFiles{1, 1}.name});
            spikes.clusters=readNPY(fullfile(spikeFiles{1, 1}(clusFIdx).folder,...
                spikeFiles{1, 1}(clusFIdx).name));
            electrodeFIdx=cellfun(@(x) contains(x,'spike_electrode'), {spikeFiles{1, 1}.name});
            spikes.electrodes=readNPY(fullfile(spikeFiles{1, 1}(electrodeFIdx).folder,...
                spikeFiles{1, 1}(electrodeFIdx).name));
            spikeTimeFIdx=cellfun(@(x) contains(x,'spike_times'), {spikeFiles{1, 1}.name});
            spikes.spikeTimes=readNPY(fullfile(spikeFiles{1, 1}(spikeTimeFIdx).folder,...
                spikeFiles{1, 1}(spikeTimeFIdx).name));
            waveformsFIdx=cellfun(@(x) contains(x,'spike_waveforms'), {spikeFiles{1, 1}.name});
            spikes.waveForms=readNPY(fullfile(spikeFiles{1, 1}(waveformsFIdx).folder,...
                spikeFiles{1, 1}(waveformsFIdx).name));
            metadataFIdx=cellfun(@(x) contains(x,'metadata'), {spikeFiles{1, 1}.name});
            spikes.metadata=readNPY(fullfile(spikeFiles{1, 1}(metadataFIdx).folder,...
                spikeFiles{1, 1}(metadataFIdx).name));
        catch
        end
    elseif contains(fname,'continuous')
        %% Open Ephys old format
        %list all .continuous data files
        fileListing=dir;
        fileChNum=regexp({fileListing.name},'(?<=CH)\d+(?=.cont)','match');
        trueFileCh=~cellfun('isempty',fileChNum);
        fileListing=fileListing(trueFileCh);
        [~,fileChOrder]=sort(cellfun(@(x) str2double(x{:}),fileChNum(trueFileCh)));
        fileListing=fileListing(fileChOrder);
        %     for chNum=1:size(fileListing,1)
        [data(chNum,:), timestamps(chNum,:), recinfo(chNum)] = load_open_ephys_multi_data({fileListing.name});
        %     end
        %get basic info about recording
        rec.dur=timestamps(1,end);
        rec.clockTimes=recinfo(1).ts;
        rec.samplingRate=recinfo(1).header.sampleRate;
        rec.numRecChan=chNum;
        rec.date=recinfo(1).header.date_created;
        rec.sys='OpenEphys';
    elseif contains(fname,'raw.kwd')
        %% Kwik format - raw data
        % The last number in file name from Open-Ephys recording is Node number
        % e.g., experiment1_100.raw.kwd is "raw" recording from Node 100 for
        % experiment #1 in that session.
        % Full recording parameters can be recovered from settings.xml file.
        % -<SIGNALCHAIN>
        %     -<PROCESSOR NodeId="100" insertionPoint="1" name="Sources/Rhythm FPGA">
        %         -<CHANNEL_INFO>
        %             ...
        %     -<CHANNEL name="0" number="0">
        %         <SELECTIONSTATE audio="0" record="1" param="1"/>
        %             ...
        %   ...
        %     -<PROCESSOR NodeId="105" insertionPoint="1" name="Filters/Bandpass Filter">
        %         -<CHANNEL name="0" number="0">
        %            <SELECTIONSTATE audio="0" record="1" param="1"/>
        %                <PARAMETERS shouldFilter="1" lowcut="1" highcut="600"/>
        
        %general info: h5disp(fname)
        rawInfo=h5info(fname);%'/recordings/0/data'
        rawInfo=h5info(fname,rawInfo.Groups.Name);
        %   chanInfo=h5info([regexp(fname,'^[a-z]+1','match','once') '.kwx']);
        %get basic info about recording
        % if more than one recording, ask which to load
        if size(rawInfo.Groups,1)>1
            recToLoad = inputdlg('Multiple recordings. Which one do you want to load?',...
                'Recording', 1);
            recToLoad = str2num(recToLoad{:});
        else
            recToLoad =1;
        end
        rec.dur=rawInfo.Groups(recToLoad).Datasets.Dataspace.Size;
        dirlisting = dir(dname);
        rec.date=dirlisting(cell2mat(cellfun(@(x) contains(x,fname),{dirlisting(:).name},...
            'UniformOutput',false))).date;
        rec.samplingRate=h5readatt(fname,rawInfo.Groups(recToLoad).Name,'sample_rate');
        rec.bitResolution=0.195; %see Intan RHD2000 Series documentation
        rec.bitDepth=h5readatt(fname,rawInfo.Groups(recToLoad).Name,'bit_depth');
        %   rec.numSpikeChan= size(chanInfo.Groups.Groups,1); %number of channels with recored spikes
        
        %     rec.numRecChan=rawInfo.Groups.Datasets.Dataspace.Size;
        rec.numRecChan=rawInfo.Groups(recToLoad).Datasets.Dataspace.Size-3;  %number of raw data channels.
        % Last 3 are headstage's AUX channels (e.g accelerometer)
        %load data (only recording channels)
        tic;
        %     data=h5read(fname,'/recordings/0/data',[1 1],[1 rec.numRecChan(2)]);
        data=h5read(fname,'/recordings/0/data',[1 1],[rec.numRecChan(1) Inf]);
        disp(['took ' num2str(toc) ' seconds to load data']);
        rec.sys='OpenEphys';
    elseif contains(fname,'kwik')
        %% Kwik format - spikes
        disp('Check out OE_proc_disp instead');
        return
    elseif contains(fname,'nex')
        %% TBSI format
        %     disp('Only TBSI_proc_disp available right now');
        %     return
        dirlisting = dir(dname);
        dirlisting = {dirlisting(:).name};
        dirlisting=dirlisting(cellfun('isempty',cellfun(@(x) contains('.',x(end)),dirlisting,'UniformOutput',false)));
        %get experiment info from note.txt file
        fileID = fopen('note.txt');
        noteInfo=textscan(fileID,'%s');
        dirBranch{end}=[dirBranch{end}(1) noteInfo{1}{:} '_' dirBranch{end}(2:end)];
        %get data info from Analog file
        analogFile=dirlisting(~cellfun('isempty',cellfun(@(x) contains(x,'Analog'),dirlisting,'UniformOutput',false)));
        analogData=readNexFile(analogFile{:});
        rec.dur=size(analogData.contvars{1, 1}.data,1);
        rec.samplingRate=analogData.freq;
        rawfiles=find(~cellfun('isempty',cellfun(@(x) contains(x,'RAW'),dirlisting,'UniformOutput',false)));
        rec.numRecChan=length(rawfiles);
        data=nan(rec.numRecChan,rec.dur);
        for fnum=1:rec.numRecChan
            richData=readNexFile(dirlisting{rawfiles(fnum)});
            data(fnum,:)=(richData.contvars{1, 1}.data)';
        end
        rec.sys='TBSI';
    elseif contains(fname,'.ns')
        %% Blackrock raw data
        tic;
        %         infoPackets = openCCF([fname(1:end-3) 'ccf'])
        %         memoryInfo=memory;
        %         fileSize=dir(fname);fileSize=fileSize.bytes/10^9;
        %         if fileSize>memoryInfo.MemAvailableAllArrays/10^9-2 % too big, read only part of it
        %             rec.partialRead=true;
        %             data = openLongNSx([cd filesep], fname);
        % %             % alternatively read only part of the file
        % %             fileHeader=openNSx([dname fname],'noread');
        % %             rec.fileSamples=fileHeader.MetaTags.DataPoints;
        % %             % max(fileSamples)/fileHeader.MetaTags.SamplingFreq/3600
        % %             splitVector=round(linspace(1,max(rec.fileSamples),round(fileSize/(5*10^3))));
        % %             data=openNSx([dname fname],['t:1:' num2str(splitVector(2))] , 'sample');
        %         else
        data = openNSx(fullfile(cd,fname));
        %         end
        if iscell(data.Data) && size(data.Data,2)>1 %gets splitted into two cells sometimes for no reason
            data.Data=[data.Data{:}]; %remove extra data.Data=data.Data(:,1:63068290);
            %data.MetaTags.DataPoints=63068290;
            %data.MetaTags.DataDurationSec=data.MetaTags.DataDurationSec(1)-(data.MetaTags.DataDurationSec(1)-(63068290/30000))
            %data.MetaTags.Timestamp=0;
            %data.MetaTags.DataPointsSec=data.MetaTags.DataDurationSec;
        end
        %         data = openNSxNew(fname);
        
        % Get channel info and spike data
        eventData=openNEV([cd filesep fname(1:end-3) 'nev']);
        spikes.clusters=eventData.Data.Spikes.Unit;
        spikes.electrodes=eventData.Data.Spikes.Electrode;
        spikes.spikeTimes=eventData.Data.Spikes.TimeStamp;
        spikes.waveForms=eventData.Data.Spikes.Waveform;
        
        if ~isfield(data,'ElectrodesInfo') %depend on file format version
            data=CatStruct(data,rmfield(eventData,{'Data','MetaTags'}));
        end
        %     analogData = openNSxNew([fname(1:end-1) '2']);
        %get basic info about recording
        rec.duration_sec=data.MetaTags.DataDurationSec;
        rec.dataPoints= data.MetaTags.DataPoints;
        rec.samplingRate=data.MetaTags.SamplingFreq;
        rec.bitResolution=0.25; % +/-8 mV @ 16-Bit => 16000/2^16 = 0.2441 uV
        rec.chanID=data.MetaTags.ChannelID;
        [~,rec.chanList]=sort(rec.chanID); [~,rec.chanList]=sort(rec.chanList); 
        if ~isfield(data.ElectrodesInfo,'Label') || ...
                (isfield(data.ElectrodesInfo,'Label') && ...
                ~sum(cellfun(@(x) contains(x,'ainp1'),{data.ElectrodesInfo.Label})))
            % maybe no Analog channels were recorded but caution: they may be
            % labeled as any digital channel. Check Connector banks
            analogChannels=cellfun(@(x) contains(x,'D'),{data.ElectrodesInfo.ConnectorBank});
            rec.chanID=rec.chanID(ismember(rec.chanList,find(~analogChannels)));
            data.Data=data.Data(ismember(rec.chanList,find(~analogChannels)),:);
        end
        rec.numRecChan=size(data.Data,1); %data.MetaTags.ChannelCount;  %number of raw data channels.
%         rec.date=[cell2mat(regexp(data.MetaTags.DateTime,'^.+\d(?= )','match'))...
%             '_' cell2mat(regexp(data.MetaTags.DateTime,'(?<= )\d.+','match'))];
%         rec.date=regexprep(rec.date,'\W','_');
        rec.date=data.MetaTags.DateTime;
        rec.start_time=datevec(data.MetaTags.DateTime);
        if ~isempty(data.MetaTags.DateTimeRaw)
            rec.start_time=[rec.start_time(4:6),data.MetaTags.DateTimeRaw(end)];
        else
            rec.start_time=[rec.start_time(4:6)];
        end
        % keep only raw data in data variable
        data=data.Data;
        disp(['took ' num2str(toc) ' seconds to load data']);
        rec.sys='Blackrock';
    end
    waitbar( 0.9, wb, 'getting TTL times and structure');
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% get TTL times and structure
    try
        TTLs = LoadTTL(fname);
    catch
        TTLs = [];
    end
catch
    %close(wb);
    disp('Failed loading ephys data');
end
cd(currDir);
close(wb);
end
