function [traces,timestamps,info]=Load_OE_Traces(fileName,channels,options)
% channels=[18  19  20  23  26  28  30  31] -1;
% options.refCh=1;
% options.filter={[300 6000],'bandpass'};
% options.CAR=true;
% 
% fileName='100_CH19.continuous';

fileNameInit=regexp(fileName,'\d+.\D+(?=\d+.continuous)','match','once');

recData=struct('data',[],'timestamps',[],'info',[]);

for chNum=1:length(channels)
    [recData(chNum).data, recData(chNum).timestamps, recData(chNum).info] =...
        load_open_ephys_data([fileNameInit num2str(channels(chNum)) '.continuous']);
end

traces=[recData.data]';
timestamps=[recData.timestamps]';

if ~isempty(options.refCh)
    traces=traces-traces(options.refCh,:);
    timestamps=timestamps(setxor(1:size(traces,1),options.refCh),:);
    traces=traces(setxor(1:size(traces,1),options.refCh),:);
end

if ~isempty(options.filter)
    for chNum=1:size(traces,1)
        traces(chNum,:)=FilterTrace(traces(chNum,:),options.filter{1},...
            recData(chNum).info.header.sampleRate,options.filter{2});
    end
end

if options.CAR
    traces=traces-mean(traces);
end

% figure; plot(timestamps(1,:),data(1,:))

info=[recData.info]';

% gain factor: - 32768 then / unique(info.gain) * 1000 
