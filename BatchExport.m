function [dataFiles,allRecInfo]=BatchExport(exportDir)
% not finalized yet
% if export for SC, must not be run as root (so start Matlab from /bin/matlab as user)
% Vincent Prevosto 10/16/2018
rootDir=cd;
if ~isfolder('SpikeSorting')
    %create export directory
    mkdir('SpikeSorting');
end
dataFiles = cellfun(@(fileFormat) dir([cd filesep '**' filesep fileFormat]),...
    {'*.dat','*raw.kwd','*RAW*Ch*.nex','*.ns6'},'UniformOutput', false);
dataFiles=vertcat(dataFiles{~cellfun('isempty',dataFiles)});
% just in case other export / spike sorting has been performed, do not include those files
dataFiles=dataFiles(~cellfun(@(flnm) contains(flnm,{'_export';'_TTLs'; '_trialTTLs'; '_vSyncTTLs';...
    'temp_wh';'_nopp.dat';'_all_sc';'_VideoFrameTimes';'_Wheel'}),...
    {dataFiles.name})); %by filename
dataFiles=dataFiles(~cellfun(@(flnm) contains(flnm,{'_SC';'_JR';'_ML'}),...
    {dataFiles.folder})); % by folder name
if ~exist('exportDir','var')
    exportDir=(fullfile(rootDir,'SpikeSorting'));
end

%also check if there are video frame times to export
videoFiles = cellfun(@(fileFormat) dir([cd filesep '**' filesep fileFormat]),...
    {'*.mp4','*.avi'},'UniformOutput', false);
videoFiles=vertcat(videoFiles{~cellfun('isempty',videoFiles)});
if ~isempty(videoFiles)
    videoFiles=videoFiles(~cellfun(@(flnm) contains(flnm,{'WhiskerTracking'}),... %don't include WhiskerTracking folder
        {videoFiles.folder})); %by filename
end

allRecInfo=cell(size(dataFiles,1),1);

%% find / ask for probe file when exporting and copy to export folder
probeFile = cellfun(@(fileFormat) dir(fullfile(rootDir,'SpikeSorting', fileFormat)),...
    {'*.json'},'UniformOutput', false);
if ~isempty(probeFile{:})
    probeFileName=probeFile{1, 1}.name;
    probePathName=probeFile{1, 1}.folder;
else
    filePath  = mfilename('fullpath');
    filePath = regexp(filePath,['.+(?=\' filesep '.+$)'],'match','once'); %removes filename
    [probeFileName,probePathName] = uigetfile('*.json','Select the .json probe file',...
        fullfile(filePath, 'probemaps'));
    copyfile(fullfile(probePathName,probeFileName),fullfile(cd,'SpikeSorting',probeFileName));
end

%% export each file
for fileNum=1:size(dataFiles,1)
    try 
        [recInfo,recordings,spikes,TTLdata] = LoadEphysData(dataFiles(fileNum).name,dataFiles(fileNum).folder);
        switch size(TTLdata,2) %% Convention : 1 - Laser / 2 - Camera 1 / 3 - Session trials
            case 1
                if isfield(TTLdata,'TTLChannel')
                    switch TTLdata.TTLChannel
                        case 1
                            laserTTL=TTLdata;
                            videoTTL=0;
                        case 2
                            videoTTL=TTLdata;
                            clear laserTTL
                    end
                else
                    laserTTL=TTLdata{1}; %might be laser stim or behavior
                    videoTTL=[];
                end
            case 2
                laserTTL=TTLdata{1}; %used to be behavior trials in older recordings
                videoTTL=TTLdata{2};
            case 3 %third is superfluous for now
                laserTTL=[]; 
                videoTTL=TTLdata{2};
            otherwise
                if ~iscell(TTLdata)
                    videoTTL=TTLdata;
                    clear laserTTL
                end
        end
        allRecInfo{fileNum}=recInfo;
    catch
        continue
    end
    vSyncTTLDir=cd;
    %% get recording name
    % (in case they're called 'continuous' or some bland thing like this)
    % basically, Open Ephys
    if contains(dataFiles(fileNum).name,'continuous')
        foldersList=regexp(strrep(dataFiles(fileNum).folder,'-','_'),...
            ['(?<=\' filesep ').+?(?=\' filesep ')'],'match');
        expNum=foldersList{cellfun(@(fl) contains(fl,'experiment'),foldersList)}(end);
        recNum=foldersList{cellfun(@(fl) contains(fl,'recording'),foldersList)}(end);
        recordingName=foldersList{find(cellfun(@(fl) contains(fl,'experiment'),foldersList))-1};
        recordingName=[recordingName '_' expNum '_' recNum];
    elseif contains(dataFiles(fileNum).name,'experiment')
        folderIdx=regexp(dataFiles(fileNum).folder,['(?<=\w\' filesep ').+?']);
        if isempty(folderIdx)
            folderIdx=1;
        end
        recordingName=strrep(dataFiles(fileNum).folder(folderIdx(end):end),'-','_');
    else
        recordingName=dataFiles(fileNum).name(1:end-4);
    end
    
    % collect info 
    recInfo.dataPoints=int32(recInfo.dataPoints);
    recInfo.baseName=recordingName;
    recNameComp=regexp(strrep(recordingName,'_','-'),'\w+','match');
    recInfo.subject=recNameComp{1};
    recInfo.shortDate=recNameComp{2};
    recInfo.probeDepth=recNameComp{3};
    
    %% get video sync TLLs
    if ~exist('vSyncTTL','var') && isempty(videoTTL)
        try % this should already be performed by LoadTTL, called from LoadEphysData above
            cd(vSyncTTLDir); dirListing=dir(vSyncTTLDir);
            % see LoadTTL - change function if needed
            if contains(dataFiles(fileNum).name, 'continuous.dat')
                cd(['..' filesep '..' filesep 'events' filesep 'Rhythm_FPGA-100.0' filesep 'TTL_1']);
                videoSyncTTLFileName='channel_states.npy';
            elseif contains(dataFiles(fileNum).name, 'raw.kwd')
                videoSyncTTLFileName=dirListing(cellfun(@(x) contains(x,'kwe'),...
                    {dirListing.name})).name;
            end
            frameCaptureTime=GetTTLFrameTime(videoSyncTTLFileName); %timestamps are actually sample count
            % convert to seconds dividing by sample rate
            %             cd(exportDir); cd (['..' filesep 'WhiskerTracking'])
            %         save([recordingName '_VideoFrameTimes'],'frameCaptureTime')
            %         continue;
            %             [recInfo,data,trials] = LoadEphysData(dataFiles(fileNum).name,dataFiles(fileNum).folder);
        catch
            %  if no vSyncTTL channel, then video sync was likely done with
            % flashing a LED. Need to first export TTLsync csv using Bonsai script.
            % Folder should then have two csv file for each video file:
            % Frame times and _TTLOnset
            videoFrameTimeFileName=dirListing(cellfun(@(fName) ...
                strcmp(regexprep(fName,'\d+\-\d+',''),[recordingName '_HSCam.csv']),...
                {dirListing.name})).name;
            if ~isempty(videoFrameTimeFileName)
                videoFrameTimes=ReadVideoFrameTimes(videoFrameTimeFileName);
                % synchronize based on trial structure
                try
                    vSyncDelay=mean(videoTTL.TTLtimes/videoTTL.samplingRate*1000-...
                        videoFrameTimes.frameTime_ms(videoFrameTimes.TTLFrames(...
                        [true;diff(videoFrameTimes.TTLFrames)>1]))');
                catch % different number of TTLs. Possibly "laser" sync. Assuming first 20 correct
                    videoIndexing=[true;diff(videoFrameTimes.TTLFrames)>1];
                    videoIndexing(max(find(videoIndexing,20))+1:end)=false;
                    vSyncDelay=mean(videoTTL.TTLtimes(1:20)/videoTTL.samplingRate*1000-...
                        videoFrameTimes.frameTime_ms(videoFrameTimes.TTLFrames(...
                        videoIndexing))');
                end
                % keep an array of timestamp (converted into sample count)
                % if video started before ephys recording (typical case)
                % then early times and thus frame count will be negative
                videoFrameTimes.frameTime_ms=videoFrameTimes.frameTime_ms+vSyncDelay;
                frameCaptureTime=int64(videoFrameTimes.frameTime_ms'*recInfo.samplingRate/1000);
                % second row keeps TTL pulse indices
                frameCaptureTime(2,:)=zeros(1,length(frameCaptureTime));
                frameCaptureTime(2,videoFrameTimes.TTLFrames)=1;
            else
                frameCaptureTime=[];
            end
        end
    end
    %% check that recordingName doesn't have special characters
    recordingName=regexprep(recordingName,'\W','');
    allRecInfo{fileNum}.recordingName=recordingName;
    
    cd(exportDir)
    if ~isfolder(recordingName)
        %create export directory
        mkdir(recordingName);
    end
    cd(recordingName)
    recInfo.export.directory=fullfile(exportDir,recordingName);
    
    %% save data
    fileID = fopen([recordingName '_export.bin'],'w'); %dat
    fwrite(fileID,recordings,'int16');
    fclose(fileID);
    recInfo.export.binFile=[recordingName '_export.bin'];
    
    %% save spikes
    if ~isempty(spikes.clusters)
        save([recordingName '_spikes'],'-struct','spikes');
        recInfo.export.spikesFile=[recordingName '_spikes.mat'];
    end
    
    %% save trial/stim TTLs in ms resolution
    if exist('trialTTL','var') && ~isempty(laserTTL) && ~isempty(laserTTL.start)
        if size(laserTTL.start,1)<size(laserTTL.start,2) %swap dimensions
            laserTTL.start=laserTTL.start';
            laserTTL.end=laserTTL.end';
        end
        % save binary file in ms units
        fileID = fopen([recordingName '_TTLs.dat'],'w');
%         TTLtimes=nan(2,size(trialTTL.start,1));
%         TTLtimes(1,:)=[round(trialTTL.start(1,1)/trialTTL.samplingRate*1000);...
%             round(trialTTL.start(1,1)/trialTTL.samplingRate*1000)+...
%             cumsum(round(diff(trialTTL.start(:,1)/trialTTL.samplingRate*1000)))]'; %exact rounding
%         TTLtimes(2,:)=[round(trialTTL.end(1,1)/trialTTL.samplingRate*1000);...
%             round(trialTTL.end(1,1)/trialTTL.samplingRate*1000)+...
%             cumsum(round(diff(trialTTL.end(:,1)/trialTTL.samplingRate*1000)))]'; %exact rounding
%         fwrite(fileID,TTLtimes,'int32'); % [trialTTL.start(:,2);trialTTL.end(:,2)].1 ms resolution
        fwrite(fileID,[laserTTL.start(:,end)';laserTTL.end(:,end)'],'double');
        fclose(fileID);
        %save timestamps in seconds units as .csv
        dlmwrite([recordingName '_trial.csv'],laserTTL.start(:,end)/1000,...
            'delimiter', ',', 'precision', '%5.5f');
        %save timestamps in seconds units as .mat (not required)
%         times=trialTTL.start(:,2)/1000;
%         save([recordingName '_export_trial.mat'],'times');
        recInfo.export.TTLs={[recordingName '_TTLs.dat'];[recordingName '_trial.csv']}; %[recordingName '_export_trial.mat']};
    end
      
    %% save video sync TTL data, in ms resolution
    if exist('vSyncTTL','var') || (exist('frameCaptureTime','var') && ~isempty(frameCaptureTime))
        fileID = fopen([recordingName '_vSyncTTLs.dat'],'w');
        if exist('vSyncTTL','var') && isfield(videoTTL,'start') && ~isempty(videoTTL.start)
            if size(videoTTL.start,2)>size(videoTTL.start,1) %we want vertical arrays
                videoTTL.start=videoTTL.start';
            end
            TTLtimes=videoTTL.start(:,size(videoTTL.start,2));
            frameCaptureTime=TTLtimes;
%             frameCaptureTime=[round(TTLtimes(1));round(TTLtimes(1))+cumsum(round(diff(TTLtimes)))]; %exact rounding 
        elseif exist('vSyncTTL','var')
            frameCaptureTime=videoTTL;
        elseif exist('frameCaptureTime','var') && ~isempty(frameCaptureTime)
            % save video frame time file (vSync TTLs prefered method)
            frameCaptureTime=frameCaptureTime(1,frameCaptureTime(2,:)<0)';
%             frameCaptureTime=[round(frameCaptureTime(1));round(frameCaptureTime(1))+cumsum(round(diff(frameCaptureTime)))];
        end
        fwrite(fileID,frameCaptureTime,'double'); %'int32' %just save one single column
        fclose(fileID);
        recInfo.export.vSync=[recordingName '_vSyncTTLs.dat'];
        copyfile([recordingName '_vSyncTTLs.dat'],fullfile(rootDir,[recordingName '_vSyncTTLs.dat']));
    end
    
    %% try to find likely companion video file
    if ~isempty(videoFiles)
        fileComp=cellfun(@(vfileName) intersect(regexp(dataFiles(fileNum).name,'[a-zA-Z0-9]+','match'),...
            regexp(vfileName,'[a-zA-Z0-9]+','match'),'stable'), {videoFiles.name},'un',0);
        fileMatchIdx=cellfun(@numel,fileComp)==max(cellfun(@numel,fileComp));
        if any(fileMatchIdx)==1
            %likely match
            recInfo.likelyVideoFile=videoFiles(fileMatchIdx).name;
        end
    end
    %% save data info
    % save as .mat file (will be discontinued)
    save([recordingName '_recInfo'],'recInfo','-v7.3');
    
    % save a json file in the root folder for downstream pipeline ingest    
    fid  = fopen(fullfile(rootDir,[recordingName '_info.json']),'w');
    fprintf(fid,'{\r\n');
    
    %% write session info
    fldNames=fieldnames(recInfo);
    for fldNum=1:numel(fldNames)
        str=jsonencode(recInfo.(fldNames{fldNum}));
        if contains(fldNames{fldNum},'export')
            str=regexprep(str,'(?<={)"','\r\n\t\t"');
            str=regexprep(str,'(?<=,)"','\r\n\t\t"');
        end
        fprintf(fid,['\t"' fldNames{fldNum} '": %s,'],str);
%         if fldNum<numel(fldNames); fprintf(fid,','); end
        fprintf(fid,'\r\n');
    end
    
    %% get info about recording location, laser, etc from notes
    ephys=struct('probe', [],'adapter', [],'AP', [], 'ML', [],'depth', []);
    photoStim=struct('protocolNum', [], 'stimPower', [], 'stimFreq', [],...
        'pulseDur', [], 'stimDevice', [], 'trainLength', []);
    
    notesFile=fullfile(regexp(rootDir,['.+(?=\' filesep '.+$)'],'match','once'),...
        [recInfo.subject  '_notes.json']);
    if any(exist(notesFile,'file'))
        notes=jsondecode(fileread(notesFile));
        % get info about that session
        sessionIdx=contains({notes.Sessions.baseName}, recInfo.baseName);
        session=notes.Sessions(sessionIdx);
        % allocate data
        if ~isempty(session)
            ephys=session; ephys=rmfield(ephys,{'baseName','date','stimPower',...
                'stimFreq','pulseDur', 'stimDevice'});ephys=ephys(1);
            photoStim=session; photoStim=rmfield(photoStim,{'baseName','date',...
                'probe','adapter','AP', 'ML','depth'});
            for protocolNum=1:size(photoStim,2) % in case there are multiple stimulation protocols
                photoStim(protocolNum).protocolNum=protocolNum-1;
            end
        end
    end
    % update with available real data
    if exist('laserTTL','var') && ~isempty(laserTTL)
        for protocolNum=1:size(laserTTL,2)
        photoStim(protocolNum).pulseDur=round(mode(diff([laserTTL(protocolNum).start(2,:);laserTTL(protocolNum).end(2,:)])))/1000;
        photoStim(protocolNum).stimFreq=1/(round(mode(diff(laserTTL(protocolNum).start(2,:))))/1000);
        photoStim.trainLength=numel(laserTTL(protocolNum).start(2,:));%'pulses_per_train'
        end
    elseif exist('laserTTL','var') && isempty(laserTTL)
        photoStim.trainLength=[];
        photoStim.protocolNum=-1;
    end
    str=strrep(jsonencode(ephys),',"',sprintf(',\r\n\t\t"'));
    str=regexprep(str,'(?<={)"','\r\n\t\t"');
    fprintf(fid,'\t"ephys": %s,\r\n',str);
    str=strrep(jsonencode(photoStim),',"',sprintf(',\r\n\t\t"'));
    str=regexprep(str,'(?<={)"','\r\n\t\t"');
    fprintf(fid,'\t"photoStim": %s,\r\n',str);
    
    %% add trial data
    clearvars trials
    trials = {};
        % if there's no task but no-stim / stim epochs create two trials:
        if exist('trialTTL','var')
            %
        else
            if exist('laserTTL','var') && ~isempty(laserTTL)
                for stimN=1:size(laserTTL,2)
                    trials((stimN)*2-1).trialNum=(stimN)*2-2; 
                    if stimN ==1; trials((stimN)*2-1).start=0; else...
                            trials((stimN)*2-1).start=laserTTL(stimN-1).end(2,end)/1000; end
                    trials((stimN)*2-1).stop=laserTTL(stimN).start(2,1)/1000;
                    trials((stimN)*2-1).isphotostim=false;
                    trials((stimN)*2).trialNum=(stimN)*2-1;
                    trials((stimN)*2).start=laserTTL(stimN).start(2,1)/1000;
                    trials((stimN)*2).stop=laserTTL(stimN).end(2,end)/1000;
                    trials((stimN)*2).isphotostim=true;
                end
                if laserTTL(end).end(2,end)/1000 < recInfo.duration_sec
                    trials((stimN)*2+1).trialNum=(stimN)*2; 
                    trials((stimN)*2+1).start=laserTTL(stimN).end(2,end)/1000; 
                    trials((stimN)*2+1).stop=recInfo.duration_sec;
                    trials((stimN)*2+1).isphotostim=false;
                end
            end
        end
     
    str=strrep(jsonencode(trials),',"',sprintf(',\r\n\t\t"'));
    str=regexprep(str,'(?<={)"','\r\n\t\t"');
    str=regexprep(str,'},{','},\r\n\t\t{');
    fprintf(fid,'\t"trials": %s\r\n',str); 
    
% close file
    fprintf(fid,'}');
    fclose(fid);

%    %To read the file:
%     foo = fileread(fullfile(rootDir,[recordingName '_recInfo.json']));
%     foo = jsondecode(foo);

    % TBD: insert session info in pipeline right here
    
end
cd ..


