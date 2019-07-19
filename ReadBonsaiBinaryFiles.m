
%% Read Bonsai binary output files %%
clearvars
dataDir='E:\Data\raw\Bonsai\vIRt23'; %'C:\Data\test';

%% Amplifier channels
% numDigChan=32; 
% fileName='amplifier.bin';
% dataFile = fopen(fullfile(dataDir,fileName));
% digitalSignals = fread(dataFile,[numDigChan,Inf],'uint16');
% fclose(dataFile);

%% Analog channels
numAnalogChan=8; %1
fileName='vIRt23_20181221-183555_AIN1.bin'; %'adc.bin';
dataFile = fopen(fullfile(dataDir,fileName));
analogSignals = fread(dataFile,[numAnalogChan,Inf],'uint16');
fclose(dataFile);

%% Sync TTLs
%8 channels but multiplexed
fileName='vIRt23_20181221-183555_TTL.bin'; %'sync.bin';
dataFile = fopen(fullfile(dataDir,fileName));
TTLSignals = fread(dataFile,[1,Inf],'uint8');
fclose(dataFile);

% demultiplex TTLs 
TTLChan=unique(TTLSignals(TTLSignals>0 & TTLSignals<=8));
numTTLChan=numel(TTLChan);
TTLSignals=demuxTTLchannel(TTLSignals,TTLChan);

%% Plots
figure; hold on
for chanNum=1 %:numDigChan
    plot(digitalSignals(chanNum,:))
end

figure; hold on 
for chanNum=1:numAnalogChan
    figure
    plot(analogSignals(chanNum,:))
end

figure; hold on
for chanNum=1:numTTLChan
    plot(TTLSignals(chanNum,:));
end
