function [paramFStatus,cmdout]=GenerateJRCParamFile(exportFileName,...
    probeFileName,inputParams)


%% generate parameter file
global fDebug_ui; fDebug_ui=1; % so that fAsk =0 (removes warnings and prompts)
jrc('makeprm',exportFileName,probeFileName);
clear global
paramFileName=[exportFileName(1:end-4) '_' probeFileName(1:end-4) '.prm'];
tic;
accuDelay=0;
disp('creating parameter file for JRClust')
while ~exist(paramFileName,'file')
    timeElapsed=toc;
    if timeElapsed-accuDelay>1
        accuDelay=timeElapsed;
        fprintf('%s ', '*');
    end
    if timeElapsed>10
        fprintf('\nFailed to generate parameter file\n');
        break
    end
end

%% read parameters and delete file
fid  = fopen(paramFileName,'r');
paramsContent=fread(fid,'*char')';
fclose(fid);
delete(paramFileName)

%% replace parameters with user values (if any)
if exist('inputParams','var') && ~isempty(inputParams)
    for paramNum=1:2:length(inputParams)
        paramsContent = regexprep(paramsContent,...
            ['(?<=' inputParams{paramNum} ' = ).+?(?=;)'],...
            ['''' inputParams{paramNum+1} '''']);
    end
end

%% write new parameter file
fid  = fopen(paramFileName,'w');
fprintf(fid,'%s',paramsContent);
fclose(fid);

cmdout='parameter file generated';
paramFStatus=1;