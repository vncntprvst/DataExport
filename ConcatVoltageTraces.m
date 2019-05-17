%%
clearvars
cd('Z:\all_staff\Wenxi\prv single unit recodings\WX007_22apr19\04_22_1_388932')
dataDirListing=dir(cd);

voltageFiles = cellfun(@(fileFormat) dir([cd filesep '**' filesep fileFormat]),...
    {'*_v.mat'},'UniformOutput', false);
voltageFiles=vertcat(voltageFiles{~cellfun('isempty',voltageFiles)});
all_voltages=cell(numel(voltageFiles),1);
for fileNum=1:numel(voltageFiles)
    load(fullfile(voltageFiles(fileNum).folder,...
        voltageFiles(fileNum).name));
    all_voltages{fileNum}=voltage; 
    clearvars voltage;
end
all_voltages=vertcat(all_voltages{:});
exportFileName=regexp(cd,['(?<=\w\' filesep ')\w+\d+'],'match','once')
fileIF=fopen([exportFileName '_all.bin'],'w');
fwrite(fileIF,all_voltages,'int16');
fclose(fileIF);
%%
clearvars
%load the exported spikes times
load('WX007_A_sorted_spikes.mat')

%%
spikeid = 5;
clusterIdx=WX002_all_Ch2.codes==spikeid;
spikeTimes_clus=WX002_all_Ch2.times(cluster3Idx);
waveForm_clus3=mean(WX002_all_Ch2.values(cluster3Idx,:));
figure; plot(waveForm_clus3)
%%
cluster4Idx=WX002_all_Ch2.codes==4;
spikeTimes_clus4=WX002_all_Ch2.times(cluster4Idx);
waveForm_clus4=mean(WX002_all_Ch2.values(cluster4Idx,:));
figure; hold on
plot(waveForm_clus3)
plot(waveForm_clus4)

