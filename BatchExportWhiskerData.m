
subjectDir=cd; 

% List session directories
expDirs= dir(subjectDir);
expDirs = expDirs([expDirs.isdir]);
expDirs = expDirs(~cellfun(@(folderName) any(strcmp(folderName,...
    {'.','..'})),{expDirs.name}));

for sessionNum=1:numel(expDirs)
    try
    cd(fullfile(expDirs(sessionNum).folder,expDirs(sessionNum).name));
%     BindMeasurements;
%     ConvertWhiskerData;
    SaveWhiskerData(cd);
    catch ME
        disp(['error exporting whisker data for '...
            fullfile(expDirs(sessionNum).folder,expDirs(sessionNum).name)])
        disp(ME.identifier)
%       rethrow(ME)
        continue
    end
end

cd(subjectDir)
