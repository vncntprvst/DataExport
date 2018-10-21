function BatchExport
% not finalized yet
% must not be run as root (so start Matlab from /bin/matlab as user)
% Vincent Prevosto 10/16/2018

if ~isdir('SpikeSortingFolder')
    %create export directory
    mkdir('SpikeSortingFolder');
end
dataFiles = cellfun(@(fileFormat) dir([cd filesep '**' filesep fileFormat]),...
    {'*.dat','*raw.kwd','*RAW‐Ch*.nex','*.ns*'},'UniformOutput', false);
dataFiles=vertcat(dataFiles{~cellfun('isempty',dataFiles)}); 
% just in case other export / spike sorting has been performed, do not include those files
dataFiles=dataFiles(~cellfun(@(flnm) contains(flnm,{'_export';'_TTLs';'_all_sc'}),...
    {dataFiles.name}));
exportDir=([cd filesep 'SpikeSortingFolder']);
for fileNum=1:size(dataFiles,1)
    try
    [recInfo,data,trials] = LoadEphysData(dataFiles(fileNum).name,dataFiles(fileNum).folder);
    catch 
        continue
    end
    % need to export TTLs
    %% get recording name 
    % (in case they're called 'continuous' or some bland thing like this)
    % basically, Open Ephys
    if contains(dataFiles(fileNum).name,'continuous') 
        foldersList=regexp(strrep(dataFiles(fileNum).folder,'-','_'),'(?<=/).+?(?=/)','match');
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
end