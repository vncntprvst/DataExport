function [paramFStatus,cmdout]=GenerateKSChannelMap(exportFile,exportDir,probeInfo,samplingRate)
% Creates Channel Map file for KiloSort

%% Channel order
% Kilosort reorders data such as data = data(chanMap, :).
if isfield(probeInfo,'chanMap')
    chanMap = probeInfo.chanMap;
else
    chanMap = 1:probeInfo.numChannels;
end

%% Declare which channels are "connected",
% meaning not dead or used for non-ephys data

if isfield(probeInfo,'connected')
    connected = probeInfo.connected;
else
    connected = true(probeInfo.numChannels, 1);
end

%% Define the horizontal (x) and vertical (y) coordinates (in ?m)
% For dead or non-ephys channels, values don't matter.

if isfield(probeInfo,'xcoords')
    xcoords = probeInfo.xcoords;
else
    xcoords = 20 * ones(1,probeInfo.numChannels);
end
if isfield(probeInfo,'ycoords')
    ycoords = probeInfo.ycoords;
else
    ycoords = 200 * (1:probeInfo.numChannels);
end

%% Groups channels (e.g. electrodes from the same tetrode)
% This helps the algorithm discard noisy templates shared across groups.
if isfield(probeInfo,'kcoords')
    kcoords = probeInfo.kcoords;
else
    kcoords = ones(1,probeInfo.numChannels);
end

%% sampling frequncy
fs = samplingRate;

%% save file
save(fullfile(exportDir,'chanMap.mat'), 'chanMap', 'connected', 'xcoords', 'ycoords', 'kcoords', 'fs');

paramFStatus= 'Channel map created';
cmdout=1;