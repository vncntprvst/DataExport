function [paramFStatus,cmdout,chMapFName]=GenerateKSChannelMap(probeFile,exportDir,probeInfo,samplingRate)
% Creates Channel Map file for KiloSort

%% Channel order
% Kilosort reorders data such as data = data(chanMap, :).
if isfield(probeInfo,'chanMap')
    chanMap = probeInfo.chanMap;
else
    chanMap = 1:probeInfo.numChannels;
end
% zero-indexing to please computer science folks
chanMap0ind = chanMap - 1;

%% Declare which channels are "connected",
% meaning not dead or used for non-ephys data
if isfield(probeInfo,'connected')
    connected = probeInfo.connected;
else
    connected = true(probeInfo.numChannels, 1);
end

%% Define the horizontal (x) and vertical (y) coordinates (in um)
% For dead or non-ephys channels, values don't matter.
if isfield(probeInfo,'geometry')
    xcoords = probeInfo.geometry(:,1);
else
    xcoords = 20 * ones(1,probeInfo.numChannels);
end
if isfield(probeInfo,'geometry')
    ycoords = probeInfo.geometry(:,2);
else
    ycoords = 200 * (1:probeInfo.numChannels);
end

%% Groups channels (e.g. electrodes from the same tetrode)
% This helps the algorithm discard noisy templates shared across groups.
if isfield(probeInfo,'shanks')
    kcoords = probeInfo.shanks;
else
    kcoords = ones(1,probeInfo.numChannels);
end

%% sampling frequency
fs = samplingRate;

%% save file
chMapFName=[probeFile '_KSchanMap.mat'];
save(fullfile(exportDir,chMapFName),...
    'chanMap','connected', 'xcoords', 'ycoords', 'kcoords', 'chanMap0ind', 'fs')
%%

% kcoords is used to forcefully restrict templates to channels in the same
% channel group. An option can be set in the master_file to allow a fraction 
% of all templates to span more channel groups, so that they can capture shared 
% noise across all channels. This option is

% ops.criterionNoiseChannels = 0.2; 

% if this number is less than 1, it will be treated as a fraction of the total number of clusters

% if this number is larger than 1, it will be treated as the "effective
% number" of channel groups at which to set the threshold. So if a template
% occupies more than this many channel groups, it will not be restricted to
% a single channel group. 

paramFStatus= 'Channel map created';
cmdout=1;