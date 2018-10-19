function BatchExport
% quick and dirty function - to be improved
% works only on binary files (.dat).
if ~isdir('SpikeSortingFolder')
    %create export directory
    mkdir('SpikeSortingFolder');
end
dataFiles = dir([cd filesep '**' filesep '*.dat']);
dataFiles=dataFiles(~cellfun(@(flnm) contains(flnm,'_export'),{dataFiles.name}));
dataFiles=dataFiles(~cellfun(@(flnm) contains(flnm,'_all_sc'),{dataFiles.name}));
exportDir=([cd filesep 'SpikeSortingFolder']);
for fileNum=1:size(dataFiles,1)
    [recInfo,data,trials] = LoadEphysData(dataFiles(fileNum).name,dataFiles(fileNum).folder);
    %% save data
    fileID = fopen([dataFiles(fileNum).name '_export.dat'],'w');
    fwrite(fileID,data,'int16');
    fclose(fileID);
    cd(exportDir)
    save('rec_info','recInfo','-v7.3');
end