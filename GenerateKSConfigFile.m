function [paramFStatus,cmdout,configFName]=GenerateKSConfigFile(fName, fDir, userParams)
% Creates configuration file for KiloSort
KS2dir='V:\Code\SpikeSorting\Kilosort2';
configFName=[fName '_KSconfigFile.m'];
copyfile(fullfile(KS2dir,'configFiles','StandardConfig_MOVEME.m'),...
    fullfile(fDir,configFName));

%% read parameters and delete file
fileID  = fopen(fullfile(fDir,configFName),'r');
dftParams=fread(fileID,'*char')';
fclose(fileID);

%% replace parameters with user values
dftParams = regexprep(dftParams,'(?<=ops.chanMap\s+=\s'')\S+?(?='';)', strrep(userParams.chanMap,filesep,[filesep filesep]));
dftParams = regexprep(dftParams,'(?<=ops.fs\s+=\s)\S+(?=;)', strtrim(sprintf('%d ',userParams.fs)));
dftParams = regexprep(dftParams,'(?<=ops.GPU\s+=\s)\S(?=;)', strtrim(sprintf('%d ',userParams.useGPU)));

%% write new params file
fileID  = fopen(fullfile(fDir,configFName),'w');
fprintf(fileID,'%% the raw data binary file is in this folder\r');
fprintf(fileID,'ops.exportDir = ''%s'';\r\r', userParams.exportDir); 
fprintf(fileID,'%% path to temporary binary file (same size as data, should be on fast SSD)\r');
fprintf(fileID,'ops.tempDir = ''%s'';\r\r', userParams.tempDir); 
fprintf(fileID,'%% name of binary file\r');
fprintf(fileID,'ops.fbinary = ''%s'';\r\r', userParams.fbinary); 
fprintf(fileID,'%% total number of channels in your recording\r');
fprintf(fileID,'ops.NchanTOT = %d;\r\r',userParams.NchanTOT);
fprintf(fileID,'%% time range to sort\r');
fprintf(fileID,'ops.trange = [%d %d];\r\r',userParams.trange(1),userParams.trange(end));
fprintf(fileID,'%s',dftParams);
fclose(fileID);

%% confirmation output
paramFStatus=1; cmdout='configuration file generated';
