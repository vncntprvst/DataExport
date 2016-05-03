function [rec,data,Trials] = LoadEphysData(fname,dname)
wb = waitbar( 0, 'Reading Data File...' );
try
    cd(dname);
    rec.expname=regexp(strrep(dname,'-','_'),'\\\w+','match');
    disp(['loading ' dname fname]);
    if strfind(fname,'continuous')
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
    elseif strfind(fname,'raw.kwd')
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
        rec.dur=rawInfo.Groups.Datasets.Dataspace.Size;
        rec.samplingRate=h5readatt(fname,rawInfo.Groups.Name,'sample_rate');
        rec.bitDepth=h5readatt(fname,rawInfo.Groups.Name,'bit_depth');
        %   rec.numSpikeChan= size(chanInfo.Groups.Groups,1); %number of channels with recored spikes
        
        %     rec.numRecChan=rawInfo.Groups.Datasets.Dataspace.Size;
        rec.numRecChan=rawInfo.Groups.Datasets.Dataspace.Size-3;  %number of raw data channels.
        % Last 3 are headstage's AUX channels (e.g accelerometer)
        %load data (only recording channels)
        tic;
        %     data=h5read(fname,'/recordings/0/data',[1 1],[1 rec.numRecChan(2)]);
        data=h5read(fname,'/recordings/0/data',[1 1],[rec.numRecChan(1) Inf]);
        disp(['took ' num2str(toc) ' seconds to load data']);
    elseif strfind(fname,'kwik')
        %% Kwik format - spikes
        disp('Check out OE_proc_disp instead');
        return
    elseif strfind(fname,'nex')
        %% TBSI format
        %     disp('Only TBSI_proc_disp available right now');
        %     return
        dirlisting = dir(dname);
        dirlisting = {dirlisting(:).name};
        dirlisting=dirlisting(cellfun('isempty',cellfun(@(x) strfind('.',x(end)),dirlisting,'UniformOutput',false)));
        %get experiment info from note.txt file
        fileID = fopen('note.txt');
        noteInfo=textscan(fileID,'%s');
        rec.expname{end}=[rec.expname{end}(1) noteInfo{1}{:} '_' rec.expname{end}(2:end)];
        %get data info from Analog file
        analogFile=dirlisting(~cellfun('isempty',cellfun(@(x) strfind(x,'Analog'),dirlisting,'UniformOutput',false)));
        analogData=readNexFile(analogFile{:});
        rec.dur=size(analogData.contvars{1, 1}.data,1);
        rec.samplingRate=analogData.freq;
        rawfiles=find(~cellfun('isempty',cellfun(@(x) strfind(x,'RAW'),dirlisting,'UniformOutput',false)));
        rec.numRecChan=length(rawfiles);
        data=nan(rec.numRecChan,rec.dur);
        for fnum=1:rec.numRecChan
            richData=readNexFile(dirlisting{rawfiles(fnum)});
            data(fnum,:)=(richData.contvars{1, 1}.data)';
        end
    elseif strfind(fname,'.ns')
        %% Blackrock raw data
        tic;
        data = openNSxNew(fname);
        %     analogData = openNSxNew([fname(1:end-1) '2']);
        %get basic info about recording
        rec.dur=data.MetaTags.DataPoints;
        rec.samplingRate=data.MetaTags.SamplingFreq;
        rec.numRecChan=data.MetaTags.ChannelCount;  %number of raw data channels.
        rec.date=[cell2mat(regexp(data.MetaTags.DateTime,'^.+\d(?= )','match')) '_' cell2mat(regexp(data.MetaTags.DateTime,'(?<= )\d.+','match'))];
        rec.date=regexprep(rec.date,'\W','_');
        % keep only raw data in data variable
        data=data.Data;
        disp(['took ' num2str(toc) ' seconds to load data']);
    end
    waitbar( 0.9, wb, 'getting TTL times and structure');
    %% get TTL times and structure
    Trials=struct('start',[],'end',[],'interval',[],'sampleRate',[],'continuous',[]);
    if strfind(fname,'raw.kwd')
        %% Kwik format - raw data
        fileListing=dir;
        fname=regexp(fname,'^\w+\d\_','match');fname=fname{1}(1:end-1);
        %making sure it exists
        fname=fileListing(~cellfun('isempty',cellfun(@(x) strfind(x,[fname '.kwe']),{fileListing.name},'UniformOutput',false))).name;
        Trials=getOE_Trials(fname);
%        h5readatt(fname,'/recordings/0/','start_time')==0
        Trials.startClockTime=h5read(fname,'/event_types/Messages/events/time_samples');
        Trials.startClockTime= Trials.startClockTime(1);
         % '/recordings/0/','start_time' has systematic
         % difference with '/event_types/Messages/events/time_samples',
         % because of the time it takes to open files. 
    elseif strfind(fname,'continuous')
        %% Open Ephys old format
        Trials=getOE_Trials('all_channels.events');
    elseif strfind(fname,'nex')
        %% TBSI format
        % not coded yet
    elseif strfind(fname,'.ns')
        %% Blackrock raw data
        try
            analogChannel = openNSxNew([fname(1:end-1) '2']);
            samplingRate=1000;
            Trials.continuous=analogChannel.Data;
        catch
            analogChannel = openNSxNew([fname(1:end-1) '3']);
            samplingRate=2000;
            Trials.continuous=analogChannel.Data;
        end
        Trials.sampleRate=analogChannel.MetaTags.SamplingFreq;
        Trials.continuous=Trials.continuous(end,:)-min(Trials.continuous(end,:));
        TTL_times=uint64(find(diff(Trials.continuous>rms(Trials.continuous)*5)))';
        if min(diff(TTL_times))<median(diff(TTL_times))-2
            %remove spurious pulses
            return
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
catch
    close(wb);
end
close(wb);
end
