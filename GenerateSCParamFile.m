function [paramFStatus,cmdout]=GenerateSCParamFile(dataFileList,exportDirList,inputParams,userinfo)

% Creates parameter file for Spyking Circus
% (see http://spyking-circus.readthedocs.io/ for info)
% Environment variables (defined in "userinfo" structure), as well as
% processing parameters ("userParams") need to be adjusted by user.
% Data file (exportFile) naming convention is as follow:
% {Subject}_{Session}_{[opt]Condition}_{RecordingSystem}_{ChannelNumber}_{PreProcessing}
% e.g.: PrV77_63_ManualStim_Bet_BR_16Ch_nopp. Can be changed when defining
% "subjectName". subjectName=regexp(strrep(exportFile,'_','-'),'^\w+\d+(?=-)','match');
% See also https://github.com/vncntprvst/DataExport for DataExportGUI, to
% export data files from Matlab.
% Probe IDs are listed with their respective subject in a implant list
% ("ImplantList.mat"). Adapt "probeID" and "probeFile" to your own needs
% accordingly.
% Runs on Windows 7, may require modifications on other platforms
% Written by Vincent Prevosto, May 2016

paramFStatus=0;
switch nargin
    case 0
        exportDir=cd;
        %select most recent .dat file
        dataFile=dir;
        [~,fDateIdx]=sort([dataFile.datenum],'descend');
        dataFile=dataFile(fDateIdx);
        dataFile=dataFile(~cellfun('isempty',cellfun(@(x) strfind(x,'.dat'),...
            {dataFile.name},'UniformOutput', false))).name;
        userinfo=UserDirInfo;
        userParams={'raw_binary';'30000';'int16';'32';'';'False';... %False to keep original binary file as is
            '';'3';'7';'both';'True';'True';'15';'True';'True';...
            '0.975';'2, 5';'0.9';'True';'True';'True';'True';'0.1'};
    case 2
        userinfo=UserDirInfo;
        userParams={'raw_binary';'30000';'int16';'32';'';'False';... %False to keep original binary file as is
            '';'3';'7';'both';'True';'True';'15';'True';'True';...
            '0.975';'2, 5';'0.9';'True';'True';'True';'True';'0.1'};
    case 3
        userinfo=UserDirInfo;
        parameterNames={inputParams.parameterNames};
        userParams={inputParams.userParams};
    case 4
        parameterNames={inputParams.parameterNames};
        userParams={inputParams.userParams};
    otherwise
        disp('missing argument for GenerateParamFile')
        return
end
for fileNum=1:size(dataFileList,2)
    dataFile=dataFileList{fileNum}(1:end-4); exportDir=exportDirList{fileNum}; 
    %% load implant list and find probe file name
    if strcmp(userParams{5},'')
        load([userinfo.probemap filesep 'ImplantList.mat']);
%         try first identifying subject through data file name
        subjectIndex=cellfun(@(x) sum(strfind(dataFile,x)),{implantList.Mouse}, 'UniformOutput',true);
        if ~sum(subjectIndex) % no luck - try directory instead
            subjectIndex=cellfun(@(x) sum(strfind(exportDir,x)),{implantList.Mouse}, 'UniformOutput',true);
        end
        subjectName=implantList(subjectIndex==max(subjectIndex)).Mouse;
        if isempty(subjectName)  % different naming convention
            subjectName=regexp(strrep(dataFile,'_','-'),'^\w+?(?=-)','match');
            if isempty(subjectName)
                subjectName=regexp(dataFile,'^\S+?(?=\W)','match');
            end
        end
        try
            probeID=implantList(contains(strrep({implantList.Mouse},'-',''),subjectName,'IgnoreCase',true)).Probe;
        catch %'default'
            probeID=implantList(contains(strrep({implantList.Mouse},'-',''),'default','IgnoreCase',true)).Probe;
        end
        %     probeFile=['C:\\Users\\' userinfo.user '\\spyking-circus\\probes\\' probeID '.prb'];
        %     if ~contains(computer('arch'),'win')
        %         PATH = getenv('PATH')
        %         setenv('PATH', [PATH ':/home/wanglab/Programs/anaconda3/envs/spyking-circus']);
        %         setenv('PATH', [PATH ':/home/wanglab/Programs/anaconda3/envs']);
        %         setenv('PATH', [PATH ':/home/wanglab/Programs/anaconda3/bin']);
        %     end
        [~,scDirectory]=system('conda info -e'); % if that returns 
%           '/bin/bash: conda: command not found', 
%           need to be added to path, such as 
%           setenv('PATH', [PATH ':/home/anaconda3/bin']);
%           type 'conda info -e' in terminal to find path
        scDirectory=strtrim(cell2mat(regexp(scDirectory,...
            ['(?<=' userinfo.circusEnv '\s+)\S+?(?=\n)'],'match')));
        if isempty(scDirectory)
            [~,scDirectory]=system('conda info -e');
            scDirectory=cell2mat(regexp(scDirectory,'(?<=root                  \*  ).+?(?=\n)','match'));
        end
        % find probes directory
        dSep=[filesep filesep];
        if exist ([userinfo.probemap filesep probeID '.prb'],'file')
            probeFile=[userinfo.probemap filesep probeID '.prb'];
        elseif exist([scDirectory filesep 'data' filesep 'spyking-circus' filesep 'probes'],'dir')
            probeFile=[regexprep(scDirectory,['\' filesep],['\' dSep]) dSep 'data' dSep 'spyking-circus' dSep 'probes' dSep probeID '.prb'];
        elseif exist([userinfo.circusHomeDir filesep 'probes'],'dir')
            probeFile=[regexprep(userinfo.circusHomeDir,['\' filesep],['\' dSep]) dSep 'probes' dSep probeID '.prb'];
        else
            probesDir= uigetdir(cd,'Select folder where probe mapings are located');
            probeFile=[probesDir dSep probeID '.prb'];
        end
        userParams{5}=probeFile;
    end
    
    if ~isdir(exportDir)
        %create export directory
        mkdir(exportDir);
    end
    cd(exportDir);
    
    if exist([dataFile '.params'],'file')==2
        %% remove pre-existing parameter file
        delete([dataFile '.params'])
    end
    
    %% generate template params file
    if contains(computer('arch'),'win')
%         condaActivation='activate ';
        [status,cmdout] = system(['cd ' userinfo.envScriptDir ' &'...
            ... %'activate ' userinfo.circusEnv ' &'...
            'spyking-circus ' ...
            exportDir filesep dataFile '.dat <' userinfo.ypipe ' &'... % echo y doesn't work on Windows, so passing file with y as sole content
            'exit &']); %  final ' &' makes command run in background outside Matlab
    else
        %         condaActivation='source activate ';
        [status,cmdout] = system(['echo y | '... %'cd ' userinfo.envScriptDir ' &' condaActivation userinfo.circusEnv ' &'...
            'spyking-circus ' exportDir filesep dataFile '.dat &'...
            'exit &']); %  final ' &' makes command run in background outside Matlab
    end
        
    if status~=0
        return
    end
    tic;
    accuDelay=0;
    disp('Writing generic parameter file')
    while ~exist([dataFile '.params'],'file')
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
    fid  = fopen([dataFile '.params'],'r');
    dftParams=fread(fid,'*char')';
    fclose(fid);
    delete([dataFile '.params'])
    
    %% replace parameters with user values
    % dftParams = regexprep(dftParams,'(?<=data_offset\s+=\s)\w+(?=\s)',userParams{1});
    dftParams = regexprep(dftParams,'(?<=file_format\s+=\s)\s+(?=#)',[userParams{1} '\r\n'...
        'sampling_rate  = ' userParams{2} '\r\n'...
        'data_dtype     = ' userParams{3} '\r\n'...
        'nb_channels    = ' userParams{4} ' ']);
    dftParams = regexprep(dftParams,'(?<=mapping\s+=\s)~/probes/mea_252.prb(?=\s)', userParams{5});
    dftParams = regexprep(dftParams,'(?<=overwrite\s+=\s)\w+(?=\s)',userParams{6}); %Default: 5; Try: 2
    %     dftParams = regexprep(dftParams,'(?<=output_dir\s+=\s) no need (?=\s)',userParams{6}); %Default: 5; Try: 2
    dftParams = regexprep(dftParams,'(?<=N_t\s+=\s)\w+(?=\s)',userParams{8}); %Default: 5; Try: 2
    dftParams = regexprep(dftParams,'(?<=spike_thresh\s+=\s)\w+(?=\s)',userParams{9}); %Default: 6; Try: 8
    dftParams = regexprep(dftParams,'(?<=peaks\s+=\s)\w+(?=\s)',userParams{10}); %Default: negative; Try: both
    dftParams = regexprep(dftParams,'(?<=isolation\s+=\s)\w+(?=\s)',userParams{11}); %Default: negative; Try: both
    dftParams = regexprep(dftParams,'(?<=remove_median\s+=\s)\w+(?=\s)',userParams{12}); %Default: False; Try: True
    %     dftParams = regexprep(dftParams,'(?<=max_elts\s+=\s)\w+(?=\s)',userParams{10}); %Default: 10000; Try: 10000 (20000)
    %     dftParams = regexprep(dftParams,'(?<=nclus_min\s+=\s)\w.\w+(?=\s)',userParams{11}); %Default: 0.002; Try 0.005 (0.0001 0.01)
    dftParams = regexprep(dftParams,'(?<=max_clusters\s+=\s)\w+(?=\s)',userParams{13}); %Default: False; Try: True
    dftParams = regexprep(dftParams,'(?<=smart_search\s+=\s)\w+(?=\s)',userParams{14}); %Default: True; Try: True
    dftParams = regexprep(dftParams,'(?<=smart_select\s+=\s)\w+(?=\s)',userParams{15}); %Default: False; Try: True
    dftParams = regexprep(dftParams,'(?<=cc_merge\s+=\s)\w.\w+(?=\s)',userParams{16}); %Default: 0.975; Try: 1
    dftParams = regexprep(dftParams,'(?<=dispersion\s+=\s\()\w+, \w+(?=\) )',userParams{17}); %Default: (5, 5); Try: 5, 5
    dftParams = regexprep(dftParams,'(?<=noise_thr\s+=\s)\w.\w+(?=\s)',userParams{18}); %Default: 0.8; Try: 0.9
    dftParams = regexprep(dftParams,'(?<=make_plots\s+=\s)\w+(?=\s)',userParams{19}); %Default: False; Try: True
    dftParams = regexprep(dftParams,'(?<=gpu_only\s+=\s)\w+(?=\s)',userParams{20}); %Default: False; Try: True
    dftParams = regexprep(dftParams,'(?<=collect_all\s+=\s)\w+(?=\s)',userParams{21}); %Default: False; Try: True
    dftParams = regexprep(dftParams,'(?<=correct_lag\s+=\s)\w+(?=\s)',userParams{22}); %Default: True; Try: True
    dftParams = regexprep(dftParams,'(?<=auto_mode\s+=\s)\w+(?=\s)',userParams{23}); %Default: False; Try: True

    %% write new params file
    fid  = fopen([dataFile '.params'],'w');
    fprintf(fid,'%s',dftParams);
    fclose(fid);
end
cmdout='parameter file(s) generated';
paramFStatus=1;