function BatchExport
% quick and dirty function - to be improved
% works only on binary files (.dat).
if ~isdir('SpikeSortingFolder')
    %create export directory
    mkdir('SpikeSortingFolder');
end
dataFiles = dir([cd filesep '**' filesep '*.dat']); % add other formats kwd, nsx
dataFiles=dataFiles(~cellfun(@(flnm) contains(flnm,'_export'),{dataFiles.name}));
dataFiles=dataFiles(~cellfun(@(flnm) contains(flnm,'_all_sc'),{dataFiles.name}));
exportDir=([cd filesep 'SpikeSortingFolder']);
for fileNum=1:size(dataFiles,1)
    [recInfo,data,trials] = LoadEphysData(dataFiles(fileNum).name,dataFiles(fileNum).folder);
    % need to export TTLs
    %% get recording name 
    % (in case they're called 'continuous' or some idiotic thing like this)
    % basically, Open Ephys
    if contains(dataFiles(fileNum).name,'continuous') 
        foldersList=regexp(strrep(dataFiles(fileNum).folder,'-','_'),'(?<=/).+?(?=/)','match');
        expNum=foldersList{cellfun(@(fl) contains(fl,'experiment'),foldersList)}(end);
        recNum=foldersList{cellfun(@(fl) contains(fl,'recording'),foldersList)}(end);
        recordingName=foldersList{find(cellfun(@(fl) contains(fl,'experiment'),foldersList))-1};
        recordingName=[recordingName '_' expNum '_' recNum];
    elseif contains(dataFiles(fileNum).name,'experiment') 
        % code that
    else
        recordingName=dataFiles(fileNum).name(1:end-4);
    end
    
    %% find / ask for probe file when exporting and copy to export folder
    
    
    %% save data
    cd(exportDir)
    fileID = fopen([recordingName '_export.dat'],'w');
    fwrite(fileID,data,'int16');
    fclose(fileID);
    %% save data info
    save([recordingName '_recInfo'],'recInfo','-v7.3');
end