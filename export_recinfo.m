%export recording info to Cicerone for MRI-based visualization

userInfo=SetUserDir;
cd(userInfo.syncdir);
cd('recInfo');

recLoc='dentate';

%% Cicerone site colors
% markerLoc={'striatum';...%	tan
% 'putamen';...%	red
% 'caudate';...%	banana
% 'stn';...%	raspberry
% 'zi';...%	ultramarine
% 'gpi';...%	blue
% 'gpe';...%	green
% 'sn';...%	plum
% 'snr';...%	lavender
% 'snc';...%	grey
% 'thalamus';...%	aquamarine
% 'thal_VLO';...%	yellow_ochre
% 'thal_VPLO';...%	cobalt_violet_deep
% 'thal_VLC';...%	maroon
% 'thal_VPLC';...%	tomato
% 'thal_Retic';...%	royal_blue
% 'optictract';...%	purple
% 'cortex';...%	turquoise
% 'background';...%	yellow
% 'quiet';...%	black
% 'border';...%	chocolate
% 'fiber';...%	lemon_chiffon
% 'other'};%	seashell
% keep only three letter location, to be able to generate file

markerLoc={...
'stn';...%	raspberry
'gpi';...%	blue
'gpe';...%	green
'snr';...%	lavender
'snc'};%	seashell

%% import recInfo.xls file as table and convert to structure
recInfo=loadxls('recInfo.xls','struct');
subjects=unique({recInfo.Monkey});

%% Check ML/AP columns
for recInfoEntry=1:size(recInfo,1)
    fileName=recInfo(recInfoEntry).Filename;
    coords=regexp(fileName,'(?<=^\w\d+)\w\d+\w\d+(?=_)','match','once');
    MLcoords=strfind(upper(coords),'M'); %comparing uppercase
    if isempty(MLcoords)
        MLcoords=strfind(upper(coords),'L');
        MLcoordSign=1; % Lateral is positive. e.g., L6 = 6
    else
        MLcoordSign=-1;
    end
    APcoords=strfind(upper(coords),'A');
    if isempty(APcoords)
        APcoords=strfind(upper(coords),'P');
        APcoordSign=-1;
    else
        APcoordSign=1; % Anterior is positive
    end
    if MLcoords<APcoords %as it should
        MLcoords=str2double(coords(MLcoords+1:APcoords-1))*MLcoordSign;
        APcoords=str2double(coords(APcoords+1:end))*APcoordSign;
    else
        APcoords=str2double(coords(APcoords+1:MLcoords-1))*APcoordSign;
        MLcoords=str2double(coords(MLcoords+1:end))*MLcoordSign;
    end
    
    if strcmp(fileName(1),'S') || strcmp(fileName(1),'H')
        MLcoords=-MLcoords; %Cb chamber on the right side
        % this should have been indicated in the 'grid' table
    end
    
    recInfo(recInfoEntry).M_L=MLcoords;
    recInfo(recInfoEntry).A_P=APcoords;
    
    %% correct rotation-adjusted coordinates
    rotation=recInfo(recInfoEntry).Rotation;
    thetaAngle= atand(APcoords/MLcoords)+ rotation;
    hypothLength= sqrt(APcoords^2+MLcoords^2);
    
    if thetaAngle<0
        rotAP=round(-sind(thetaAngle)*hypothLength,1);
    else
        rotAP=round(sind(thetaAngle)*hypothLength,1);
    end
    rotML=round(cosd(thetaAngle)*hypothLength,1);
    
    if MLcoords<0
        rotML=-rotML;
    end
    recInfo(recInfoEntry).Angle=thetaAngle;
    recInfo(recInfoEntry).Hypotenuse=hypothLength;
    recInfo(recInfoEntry).MLCoordinates=rotML;
    recInfo(recInfoEntry).APCoordinates=rotAP;
    
end


%% subject-specific export files
for subjectID=1:length(subjects)
    
    % go to appropriate folder
    cd(['C:\MonkeyCicerone\' subjects{subjectID} 'Folder\' subjects{subjectID} 'Recordings'])
    
    %% export "zero-depth" data at cardinal coordinates
%     
%     dataTable = table([1;2;3;4;5],...
%         [1;2;3;4;5],... % track is grid coordinates including rotation
%         [6;0;0;0;-6],...
%         [0;-6;0;6;0],...
%         ones(5,1)*2,...
%         ones(5,1),...
%         repmat(subjects{subjectID},[5,1]),...
%         repmat('None',[5,1]),...
%         repmat(regexprep(date,'-','/'),[5,1]),...
%         zeros(5,1),...
%         repmat('other',[5,1]),...
%         ['Ant';'Med';'Ctr';'Lat';'Pos'],...
%         repmat(' ',[5,1]),...
%         repmat(' ',[5,1]),...
%         repmat(' ',[5,1]),...
%         zeros(5,1),...
%         ones(5,1),... % electrode number is the particular session for a given track.
%         ... %Each electrode may have a different calibration
%         'VariableNames',{'SiteNumber','TrackNumber','AP','ML','Chamber',...
%         'MonkeyID','MonkeyName','TrackComment','Date','Depth','Location',...
%         'SiteComment','MotorResponse','MicrostimResponse','RecordFile',...
%         'ElectrodeCalibr','ElectrodeNumber'});
%     
%     writetable(dataTable,'ZeroDepth.txt','Delimiter','\t','WriteRowNames',true);
    
    %% export data
    subjectIdx=cellfun(@(name) strcmp(subjects{subjectID},name), {recInfo.Monkey});
    subjectIdxNum=find(subjectIdx);
    %% find unique track coordinates.
    % Adjust calibration in Cicerone (electrode panel) and update values
    % accordingly
    subjectRecInfo=recInfo(subjectIdx);
    subjectRecCoords=[[subjectRecInfo.MLCoordinates]',[subjectRecInfo.APCoordinates]'];
    [~,uniqueMLidx]=unique(subjectRecCoords,'rows');
    uniqueTracks=subjectRecCoords(uniqueMLidx,:);
    
    % add track and electrode numbering (and color, optional)
    for trackID=1:size(uniqueTracks,1)
        recInThatTrack=[recInfo(subjectIdx).MLCoordinates] == uniqueTracks(trackID,1) &...
            [recInfo(subjectIdx).APCoordinates] == uniqueTracks(trackID,2);
        for recEntry=1:sum(recInThatTrack)
            recInThatTrackIdxNum=find(recInThatTrack);
            recInfo(subjectIdxNum(recInThatTrackIdxNum(recEntry))).TrackNumber = trackID;
           % color by track:
%             recInfo(subjectIdxNum(recInThatTrackIdxNum(recEntry))).Location = markerLoc{mod(trackID,5)+1}; %this is a trick to obtain different track colors
            recInfo(subjectIdxNum(recInThatTrackIdxNum(recEntry))).ElectrodeNumber = recEntry; %although recording may come from same sessions. That could be changed
        end
    end
    
    % as a control: color by rotation
%     uniqueRotations=unique([recInfo(subjectIdxNum).Rotation]);
%     for recEntry=1:numel(subjectIdxNum)
%         rotationID=find(recInfo(subjectIdxNum(recEntry)).Rotation==uniqueRotations);
%         recInfo(subjectIdxNum(recEntry)).Location = markerLoc{mod(rotationID,5)+1};
%     end

    % color by cluster
    uniqueClusters=unique([recInfo(subjectIdxNum).ClusterID]);
    for recEntry=1:numel(subjectIdxNum)
        clusterID=find(recInfo(subjectIdxNum(recEntry)).ClusterID==uniqueClusters);
        recInfo(subjectIdxNum(recEntry)).Location = markerLoc{mod(clusterID,5)+1};
    end
    
    dataTable = table(...
        rot90(1:numel(subjectIdxNum),3),...
        [recInfo(subjectIdxNum).TrackNumber]',...
        [recInfo(subjectIdxNum).APCoordinates]',...
        [recInfo(subjectIdxNum).MLCoordinates]',...
        ones(numel(subjectIdxNum),1)*2,...
        repmat('Zero',[numel(subjectIdxNum),1]),...
        repmat(subjects{subjectID},[numel(subjectIdxNum),1]),...
        repmat('None',[numel(subjectIdxNum),1]),...
        repmat(regexprep(date,'-','/'),[numel(subjectIdxNum),1]),...
        -[recInfo(subjectIdxNum).Depth]'/1000,...
        vertcat(recInfo(subjectIdxNum).Location),... 
        repmat('None',[numel(subjectIdxNum),1]),...
        repmat(' ',[numel(subjectIdxNum),1]),...
        repmat(' ',[numel(subjectIdxNum),1]),...
        repmat('TBD',[numel(subjectIdxNum),1]),...
        ones(numel(subjectIdxNum),1)*-24,...
        [recInfo(subjectIdxNum).ElectrodeNumber]',... % electrode number is the particular session for a given track.
        ... %Each electrode may have a different calibration
        'VariableNames',{'SiteNumber','TrackNumber','AP','ML','Chamber',...
        'MonkeyID','MonkeyName','TrackComment','Date','Depth','Location',...
        'SiteComment','MotorResponse','MicrostimResponse','RecordFile',...
        'ElectrodeCalibr','ElectrodeNumber'});
    
    writetable(dataTable,[subjects{subjectID} '_' recLoc '.txt'],'Delimiter','\t','WriteRowNames',true)
    
end


