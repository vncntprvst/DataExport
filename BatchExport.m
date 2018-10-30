function BatchExport(exportDir)
% not finalized yet
% if export for SC, must not be run as root (so start Matlab from /bin/matlab as user)
% Vincent Prevosto 10/16/2018

if ~isdir('SpikeSortingFolder')
    %create export directory
    mkdir('SpikeSortingFolder');
end
dataFiles = cellfun(@(fileFormat) dir([cd filesep '**' filesep fileFormat]),...
    {'*.dat','*raw.kwd','*RAW*Ch*.nex','*.ns*'},'UniformOutput', false);
dataFiles=vertcat(dataFiles{~cellfun('isempty',dataFiles)});
% just in case other export / spike sorting has been performed, do not include those files
dataFiles=dataFiles(~cellfun(@(flnm) contains(flnm,{'_export';'_TTLs';'_all_sc';'_VideoFrameTimes'}),...
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

for fileNum=1:size(dataFiles,1)
    try
        [recInfo,data,trials] = LoadEphysData(dataFiles(fileNum).name,dataFiles(fileNum).folder);
    catch
        continue
    end
    TTLDir=cd;
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
    
    %% find / ask for probe file when exporting and copy to export folder
    
    cd(exportDir)
    %% save data
    fileID = fopen([recordingName '_export.dat'],'w');
    fwrite(fileID,data,'int16');
    fclose(fileID);
    %% save TTL file
    if exist('trials','var') && ~isempty(trials.start)
        fileID = fopen([recordingName '_TTLs.dat'],'w');
        fwrite(fileID,[trials.start(:,2)';trials.end(:,2)'],'int32');
        fclose(fileID);
    end
    %% save data info
    save([recordingName '_recInfo'],'recInfo','-v7.3');
    
    %% check if there's a corresponding video file
    nameCheck=cellfun(@(vflnm) sum(ismember(recordingName,vflnm(1:end-4))),...
        {videoFiles.name});
    if logical(find(nameCheck>length(recordingName)*0.9,1))
        cd(TTLDir)
        try
            correspondingVideoFileName= videoFiles(nameCheck==max(nameCheck)).name(1:end-4);
        catch
            correspondingVideoFileName=recordingName;
        end
        
        try
            % see LoadTTL - change function if needed
            if contains(dataFiles(fileNum).name, 'continuous.dat')
                cd(['..' filesep '..' filesep 'events' filesep 'Rhythm_FPGA-100.0' filesep 'TTL_1']);
                videoTTLFileName='channel_states.npy';
            elseif contains(dataFiles(fileNum).name, 'raw.kwd')
                videoTTLFileName='';
            end
            frameCaptureTime=GetTTLFrameTime(videoTTLFileName);
            %             [recInfo,data,trials] = LoadEphysData(dataFiles(fileNum).name,dataFiles(fileNum).folder);
        catch
            %     if no TTL channel, check csv files
            %     videoFrameTimes=ReadVideoFrameTimes(dirName)
            
        end
    else
        frameCaptureTime=[];
    end
    %% save video frame time file
    cd(exportDir); cd (['..' filesep 'WhiskerTracking'])
    if exist('frameCaptureTime','var') && ~isempty(frameCaptureTime)
        fileID = fopen([correspondingVideoFileName '_VideoFrameTimes.dat'],'w');
        fwrite(fileID,frameCaptureTime,'double');
        fclose(fileID);
    end
    
end

