
subjectDir=cd; 

% List session directories
expDirs= dir(subjectDir);
expDirs = expDirs([expDirs.isdir]);
expDirs = expDirs(~cellfun(@(folderName) any(strcmp(folderName,...
    {'.','..'})),{expDirs.name}));

for sessionNum=1:numel(expDirs)
    try
    cd(fullfile(expDirs(sessionNum).folder,expDirs(sessionNum).name));
    BatchExport
    catch
        disp(['error exporting data for '...
            fullfile(expDirs(sessionNum).folder,expDirs(sessionNum).name)])
        continue
    end
end

cd(subjectDir)
