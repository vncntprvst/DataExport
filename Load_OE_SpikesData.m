function spikeData=Load_OE_SpikesData(fileName)

[data, timestamps, info] = load_open_ephys_data(fileName);

% figure; plot(mean(data(info.sortedId==1,:)))
% hold on
% plot(mean(data(info.sortedId==2,:)))
% plot(mean(data(info.sortedId==0,:)))

spikeData.waveForms=data';
spikeData.spikeTimes=timestamps*info.header.sampleRate;
spikeData.unitsIdx=info.sortedId;
spikeData.samplingRate=info.header.sampleRate;
spikeData.selectedUnits=unique(spikeData.unitsIdx);

% gain factor: - 32768 then / unique(info.gain) * 1000 
