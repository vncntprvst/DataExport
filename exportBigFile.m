function exportBigFile(dataFile,exportFile,probeLayout,keepChannels)

switch nargin
    case 2
        probeLayout=[];
    case 3
        keepChannels=[];
end
fileSize=dir(dataFile);fileSize=fileSize.bytes/10^6;

if strfind(dataFile,'.ns')
    
    fileHeader=openNSx(dataFile,'noread');
    fileSamples=fileHeader.MetaTags.DataPoints;
    splitVector=round(linspace(1,max(fileSamples),round(fileSize/(5*10^3))));
    for dataChunk=2:length(splitVector)
        if dataChunk==2
            rawData=openNSx(dataFile,['t:1:' num2str(splitVector(2))] , 'sample');
        else
            rawData=openNSx(dataFile,['t:' num2str(splitVector(dataChunk-1))...
                ':' num2str(splitVector(dataChunk))], 'sample');
        end
        if iscell(rawData.Data) && size(rawData.Data,2)>1
            rawData=[rawData.Data{:}];
        else
            rawData=rawData.Data;
        end
        
        %remove un-labeled and EMG channels
        if ~isempty(probeLayout)
            if isfield(probeLayout,'Label')
                labeledChans=~cellfun(@(chLabel)~isempty(strfind(chLabel,'chan')) |...
                    ~isempty(strfind(chLabel,'EMG')), {probeLayout.Label});
                probeLayout=probeLayout(labeledChans);
                rawData=rawData(labeledChans,:);
            end
            [~,chMap]=sort([probeLayout.BlackrockChannel]);[~,chMap]=sort(chMap);
            if sum(chMap-(min(chMap):max(chMap)))>0 %that is, there's a mapping
                rawData=rawData(chMap,:);
            end
        end
        
        if ~isempty(keepChannels)
            rawData=rawData(keepChannels,:);
        end
        if dataChunk==2
            fileID = fopen(exportFile,'w');
        else
            fileID = fopen(exportFile,'a');
        end
        fwrite(fileID,rawData,'int16');
        fclose(fileID);
    end
end

