function [rec,data,trials] = LoadEphysData(fname,dname)
wb = waitbar( 0, 'Reading Data File...' );
cd(dname);
try
    rec.dirBranch=regexp(strrep(dname,'-','_'),['\' filesep '\w+'],'match');
    disp(['loading ' dname fname]);
    if contains(fname,'continuous')
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
        rec.dirBranch{end}=[rec.dirBranch{end}(1) noteInfo{1}{:} '_' rec.dirBranch{end}(2:end)];
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
        memoryInfo=memory;
        fileSize=dir(fname);fileSize=fileSize.bytes/10^9;
        if fileSize>memoryInfo.MemAvailableAllArrays/10^9-2 % too big, read only part of it
            rec.partialRead=true;
            data = openLongNSx([cd filesep], fname);
%             % alternatively read only part of the file
%             fileHeader=openNSx([dname fname],'noread');
%             rec.fileSamples=fileHeader.MetaTags.DataPoints;
%             % max(fileSamples)/fileHeader.MetaTags.SamplingFreq/3600
%             splitVector=round(linspace(1,max(rec.fileSamples),round(fileSize/(5*10^3))));
%             data=openNSx([dname fname],['t:1:' num2str(splitVector(2))] , 'sample');
        else
            data = openNSx([cd filesep fname]);
        end
        if iscell(data.Data) && size(data.Data,2)>1 %gets splitted into two cells sometimes for no reason
            data.Data=[data.Data{:}]; %remove extra data.Data=data.Data(:,1:63068290);
                                      %data.MetaTags.DataPoints=63068290;
                                      %data.MetaTags.DataDurationSec=data.MetaTags.DataDurationSec(1)-(data.MetaTags.DataDurationSec(1)-(63068290/30000))
                                      %data.MetaTags.Timestamp=0;
                                      %data.MetaTags.DataPointsSec=data.MetaTags.DataDurationSec;
        end
%         data = openNSxNew(fname);
        
        %     analogData = openNSxNew([fname(1:end-1) '2']);
        %get basic info about recording
        rec.dur=data.MetaTags.DataPoints;
        rec.samplingRate=data.MetaTags.SamplingFreq;
        rec.bitResolution=0.25; % �8 mV @ 16-Bit => 16000/2^16 = 0.2441 ?V 
        rec.chanID=data.MetaTags.ChannelID;
        rec.numRecChan=data.MetaTags.ChannelCount;  %number of raw data channels.
        rec.date=[cell2mat(regexp(data.MetaTags.DateTime,'^.+\d(?= )','match'))...
            '_' cell2mat(regexp(data.MetaTags.DateTime,'(?<= )\d.+','match'))];
        rec.date=regexprep(rec.date,'\W','_');
        % keep only raw data in data variable
        data=data.Data;
        disp(['took ' num2str(toc) ' seconds to load data']);
        rec.sys='Blackrock';
    end
    waitbar( 0.9, wb, 'getting TTL times and structure');
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% get TTL times and structure
    try
        trials = LoadTTL(fname);
    catch
        trials = [];
    end
catch
    close(wb);
end
close(wb);
end
