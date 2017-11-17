function [paramFStatus,cmdout]=GenerateKSConfigFile(fName, dName, userParams)
% Creates configuration file for KiloSort

% read parameters and delete file
fid  = fopen('GenericKSConfig.txt','r');
dftParams=fread(fid,'*char')';
fclose(fid);

% replace parameters with user values

dftParams = regexprep(dftParams,'(?<=ops.GPU\s+=\s)useGPU(?=;)', userParams.useGPU);
dftParams = regexprep(dftParams,'fpath', ['''' strrep(dName,filesep,[filesep filesep]) '''']); % format directory name
dftParams = regexprep(dftParams,'fName', ['''' fName  '.dat''']);

% write new params file
fid  = fopen(['config_' fName '.m'],'w');
fprintf(fid,'%s',dftParams);
fclose(fid);

cmdout='configuration file generated';
paramFStatus=1;