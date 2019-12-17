function [paramFStatus,cmdout]=ModifyJRCParamFile(fileName,generateFile,inputParams)

paramFileName=[fileName '.prm'];

if generateFile
    %% generate parameter file
    jrc('bootstrap',[fileName '.meta'],'-noconfirm','-advanced'); % -noconfirm removes warnings and prompts
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