function [paramFStatus,cmdout]=GenerateJRClustProbeFile(probeParams)
% Creates probe file for JRClust

% read parameters and delete file
fid  = fopen('GenericJRClustProbe.txt','r');
defaultProbe=fread(fid,'*char')';
fclose(fid);

%%
if ~isfield(probeParams,'chanMap')
    probeParams.chanMap = 1:probeParams.numChannels;
end

%% Define the horizontal (x) and vertical (y) coordinates (in ?m)

if ~isfield(probeParams,'geometry')
    xcoords = 20 * ones(1,probeParams.numChannels);
    ycoords = 200 * (1:probeParams.numChannels);
    probeParams.geometry=[xcoords;ycoords]';
end

%% Groups channels (e.g. electrodes from the same tetrode)
if ~isfield(probeParams,'shanks')
    probeParams.shanks = ones(1,probeParams.numChannels);
end

% replace parameters with user values
defaultProbe = regexprep(defaultProbe,'(?<=channels = [)\s(?=])', strtrim(sprintf('%d ',probeParams.chanMap)));
defaultProbe = regexprep(defaultProbe,'(?<=geometry = [)\s(?=])', ...
    [strtrim(sprintf('%d ',probeParams.geometry(:,1)')) ';' strtrim(sprintf('%d ',probeParams.geometry(:,2)))]); % format directory name
defaultProbe = regexprep(defaultProbe,'(?<=pad = [)\s(?=])', strtrim(sprintf('%d ',probeParams.pads)));
defaultProbe = regexprep(defaultProbe,'(?<=shank = [)\s(?=])', strtrim(sprintf('%d ',probeParams.shanks)));
defaultProbe = regexprep(defaultProbe,'(?<=maxSite = [)\s(?=])', strtrim(sprintf('%d ',probeParams.maxSite)));

% write new params file
fid  = fopen([num2str(probeParams.numChannels) 'Ch.prb'],'w'); %fName
fprintf(fid,'%s',defaultProbe);
fclose(fid);

cmdout='probe file generated';
paramFStatus=1;