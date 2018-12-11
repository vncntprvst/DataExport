function [dataFiles,allRecInfo]=BatchExport(exportDir)
% not finalized yet
% if export for SC, must not be run as root (so start Matlab from /bin/matlab as user)
% Vincent Prevosto 10/16/2018

if ~isdir('SpikeSortingFolder')
    %create export directory
    mkdir('SpikeSortingFolder');
end
dataFiles = cellfun(@(fileFormat) dir([cd filesep '**' filesep fileFormat]),...
    {'*.dat','*raw.kwd','*RAW*Ch*.nex','*.ns6'},'UniformOutput', false);
dataFiles=vertcat(dataFiles{~cellfun('isempty',dataFiles)});
% just in case other export / spike sorting has been performed, do not include those files
dataFiles=dataFiles(~cellfun(@(flnm) contains(flnm,{'_export';'_TTLs'; '_trialTTLs'; '_vSyncTTLs';...
    'temp_wh';'_nopp.dat';'_all_sc';'_VideoFrameTimes'}),...
    {dataFiles.name})); %by filename
dataFiles=dataFiles(~cellfun(@(flnm) contains(flnm,{'_SC';'_JR';'_ML'}),...
    {dataFiles.folder})); % by folder name
if ~exist('exportDir','var')
    exportDir=([cd filesep 'SpikeSortingFolder']);
end
%also check if there are video frame times to export
% cd(exportDir); cd '..'
videoFiles = cellfun(@(fileFormat) dir([cd filesep '**' filesep fileFormat]),...
    {'*.mp4','*.avi'},'UniformOutput', false);
videoFiles=vertcat(videoFiles{~cellfun('isempty',videoFiles)});
allRecInfo=cell(size(dataFiles,1),1);

%% find / ask for probe file when exporting and copy to export folder
[probeFileName,probePathName] = uigetfile('*.mat','Select the .mat probe file',...
    '/home/wanglab/Code/EphysDataProc/DataExport/probemaps');
copyfile(fullfile(probePathName,probeFileName),fullfile(cd,'SpikeSortingFolder',probeFileName));
    
%% export each file
for fileNum=1:size(dataFiles,1)
    try
        [recInfo,data,trials] = LoadEphysData(dataFiles(fileNum).name,dataFiles(fileNum).folder);
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
        folderIdx=regexp(dataFiles(fileNum).folder,'(?<=\w\/).+?');
        recordingName=strrep(dataFiles(fileNum).folder(folderIdx(end):end),'-','_');
    else
        recordingName=dataFiles(fileNum).name(1:end-4);
    end
    %     continue
    
    %% get video sync TLLs
    %     check if there's a corresponding video file
    nameCheck=cellfun(@(vflnm) sum(ismember(recordingName,vflnm(1:end-4))),...
        {videoFiles.name});
    if logical(find(nameCheck>length(recordingName)*0.9,1))
        try
            correspondingVideoFileName= videoFiles(nameCheck==max(nameCheck)).name(1:end-4);
        catch
            correspondingVideoFileName=recordingName;
        end
    else
    end
    try
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
                vSyncDelay=mean(trials.TTLtimes/trials.samplingRate*1000-...
                    videoFrameTimes.frameTime_ms(videoFrameTimes.TTLFrames(...
                    [true;diff(videoFrameTimes.TTLFrames)>1]))');
            catch % different number of TTLs. Possibly "laser" sync. Assuming first 20 correct
                videoIndexing=[true;diff(videoFrameTimes.TTLFrames)>1];
                videoIndexing(max(find(videoIndexing,20))+1:end)=false;
                vSyncDelay=mean(trials.TTLtimes(1:20)/trials.samplingRate*1000-...
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
    
    %% check that recordingName doesn't have special characters
    recordingName=regexprep(recordingName,'\W','');
    allRecInfo{fileNum}.recordingName=recordingName;
    
    cd(exportDir)
    
    %% save data
    fileID = fopen([recordingName '_export.dat'],'w');
    fwrite(fileID,data,'int16');
    fclose(fileID);
    
    %% save vSyncTTL file
    if exist('trials','var') && ~isempty(trials.start)
        fileID = fopen([recordingName '_vSyncTTLs.dat'],'w');
        if size(trials.start,1)==1 && size(trials.start,2)>size(trials.start,1)
            fwrite(fileID,[trials.start;trials.end],'int32');
        else
            fwrite(fileID,[trials.start(:,2)';trials.end(:,2)'],'int32');
        end
        fclose(fileID);
    end
    %% save data info
    save([recordingName '_recInfo'],'recInfo','-v7.3');
    
    %% save video frame time file
    cd(exportDir); cd (['..' filesep 'WhiskerTracking'])
    if exist('frameCaptureTime','var') && ~isempty(frameCaptureTime)
        fileID = fopen([correspondingVideoFileName '_VideoFrameTimes.dat'],'w');
        fwrite(fileID,frameCaptureTime,'double');
        fclose(fileID);
    end
    
end


