function [paramFStatus,cmdout]=GenerateJRCParamFile(exportFileName,...
    probeFileName,inputParams)


%% generate parameter file
% global fDebug_ui; fDebug_ui=1; % so that fAsk =0 (removes warnings and prompts)
jrc('bootstrap',[exportFileName(1:end-4) '.meta'],'-noconfirm','-advanced');
% clear global
paramFileName=[exportFileName(1:end-4) '.prm']; %[exportFileName(1:end-4) '_' probeFileName(1:end-4) '.prm']
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

%% replace parameters with user values (if any)
if exist('inputParams','var') && ~isempty(inputParams)

    % read parameters and delete file
    fid  = fopen(paramFileName,'r');
    paramsContent=fread(fid,'*char')';
    fclose(fid);
    delete(paramFileName)
    
    % replace parameters
    for paramNum=1:size(inputParams,1)
        paramsContent = regexprep(paramsContent,...
            ['(?<=' inputParams{paramNum,1} ' = ).+?(?=;)'],...
            inputParams{paramNum,2});
    end
    
    % write new parameter file
    fid  = fopen(paramFileName,'w');
    fprintf(fid,'%s',paramsContent);
    fclose(fid);
end

cmdout='parameter file generated';
paramFStatus=1;