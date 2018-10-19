userinfo=UserDirInfo;
subjectName='vIRt22'

%% load or create channel mapping
if exist([userinfo.probemap filesep 'ImplantList.mat'],'file') %the implant list contains
    %                                                                    a structure with .Probe and .Mouse fields
    %                                                                    that associates each mouse to its implant number
    %                                                                    (and thus the probe map)
    load([userinfo.probemap filesep 'ImplantList.mat']);
else
    implantList=struct('Mouse',[],'Probe',[]);
end

% find Probe ID
try
    probeID=implantList(contains(strrep({implantList.Mouse},'-',''),subjectName,'IgnoreCase',true)).Probe;
    makeProbeFile=0;
catch
    probeID=['default_' num2str(recInfo.numRecChan) 'Channels'];
    makeProbeFile=1;
end

remapdlg=inputdlg({'Subject Name','Probe map'},'Enter Subject and Probe identifiers',...
    1,{subjectName,probeID});
subjectName=remapdlg(1);
probeID=remapdlg{2};

if makeProbeFile
    implantList(size(implantList.Mouse,1)+1).Mouse=subjectName;
    implantList(size(implantList.Mouse,1)).Probe=probeID;
    cd([userinfo.probemap filesep])
    save('ImplantList.mat','implantList');
    %make probe map file
    eval([probeID '=struct(''Shank'',[],'...
        '''Electrode'',[],'...
        '''IntanHS'',[],'...
        '''OEChannel'',[],'...
        '''BlackrockChannel'',[],'...
        '''Label'',[])'])
    for chNum=1:recInfo.numRecChan
        eval([probeID '(chNum).Shank = chNum']);
        eval([probeID '(chNum).Electrode = chNum']);
        eval([probeID '(chNum).IntanHS = chNum']);
        eval([probeID '(chNum).OEChannel = chNum+1']);
        eval([probeID '(chNum).BlackrockChannel = chNum']);
    end
    recInfo.probeLayout=probeID;
    eval(['save(''' probeID '.mat'',''probeID'')']);
    %     makeProbeFile=0;
end

load([userinfo.probemap filesep probeID '.mat']);
wsVars=who;
recInfo.probeLayout=eval(wsVars{contains(wsVars,'Probe')});
recInfo.subjectName=subjectName;
recInfo.probeID=probeID;
recSys={'Blackrock','OpenEphys'};
recSysIndex = listdlg('PromptString','Select Recording System:',...
    'SelectionMode','single',...
    'ListString',recSys);
recInfo.sys=recSys{recSysIndex};

%% Aggregate probe info
probeInfo.radius=100;
if isfield(recInfo,'probeLayout')
    probeInfo.numChannels=size(recInfo.probeLayout,1);
    
    switch recInfo.sys
        case 'OpenEphys'
            probeInfo.chanMap=[recInfo.probeLayout.OEChannel];
        case 'Blackrock'
            probeInfo.chanMap=[recInfo.probeLayout.BlackrockChannel];
    end
    
    probeInfo.connected=true(probeInfo.numChannels,1);
    probeInfo.connected(isnan([recInfo.probeLayout.Shank]))=0;
    probeInfo.kcoords=[recInfo.probeLayout.Shank];
    probeInfo.kcoords=probeInfo.kcoords(~isnan([recInfo.probeLayout.Shank]));
    if isfield(recInfo.probeLayout,'x_geom')
        probeInfo.xcoords = [recInfo.probeLayout.x_geom];
        probeInfo.ycoords = [recInfo.probeLayout.y_geom];
        probeInfo.radius=250;
    else % set coordinates by group, as if tetrodes
        probeInfo.xcoords = zeros(1,probeInfo.numChannels);
        probeInfo.ycoords = 200 * ones(1,probeInfo.numChannels);
        groups=unique(probeInfo.kcoords);
        for elGroup=1:length(groups)
            if isnan(groups(elGroup))
                continue;
            end
            groupIdx=find(probeInfo.kcoords==groups(elGroup));
            probeInfo.xcoords(groupIdx(2:2:end))=20;
            probeInfo.xcoords(groupIdx)=probeInfo.xcoords(groupIdx)+(0:length(groupIdx)-1);
            probeInfo.ycoords(groupIdx)=...
                probeInfo.ycoords(groupIdx)*(elGroup-1);
            probeInfo.ycoords(groupIdx(round(end/2)+1:end))=...
                probeInfo.ycoords(groupIdx(round(end/2)+1:end))+20;
        end
    end
end

%% [optional] remap
remapping=true;
if remapping
    probeInfo.xcoords=probeInfo.xcoords(probeInfo.chanMap);
    probeInfo.ycoords=probeInfo.ycoords(probeInfo.chanMap);
    disp('Creating probe file with remapped channels');
    
    switch recInfo.sys
        case 'OpenEphys'
            probeID=[probeID '_OpenEphysMapping'];
        case 'Blackrock'
            probeID=[probeID '_BlackrockMapping'];
    end
end

%% save file
cd([userinfo.probemap filesep])
fileID = fopen([probeID '.prb'],'w');
fprintf(fileID,'total_nb_channels = %d\r',probeInfo.numChannels  );
fprintf(fileID,'radius            = %d\r\r',probeInfo.radius);
fprintf(fileID,'channel_groups = {\r');
fprintf(fileID,'\t1: {\r');
% fprintf(fileID,'\t\t''channels'': [%s],\r',regexprep(strtrim(sprintf('%d, ',...
%     sort(probeInfo.chanMap))),',$',''));
fprintf(fileID,'\t\t''channels'': list(range(%d)),\r',probeInfo.numChannels);
fprintf(fileID,'\t\t''geometry'': {\r');
fprintf(fileID,'\t\t\t%s\r',strtrim(sprintf('\t\t\t%d: [%0.1f, %0.1f],\r',...
    reshape([(1:length(probeInfo.chanMap))-1;probeInfo.xcoords;probeInfo.ycoords],...
    [length(probeInfo.chanMap)*3,1])))); % -1 because of 0 indexing
fprintf(fileID,'\t\t},\r');
fprintf(fileID,'\t\t''graph'' : []\r');
fprintf(fileID,'\t}\r}');

fclose(fileID);





