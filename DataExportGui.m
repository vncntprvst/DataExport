function varargout = DataExportGui(varargin)
% MATLAB code for DataExportGui.fig
% Exports ephys data from Open Ephys / Blackrock / TBSI systems
%     Data can be exported as 
%         * continuous data (raw or pre-processed), in .dat and/or .mat format'
%         * spike data, from online sorting or offline threshold
%     In addition, parameter file for offline spike sorting can be generated
%     Can also export excerpt, instead of full data file
%
% When opening, will use most recent folder in user's data directory as root
% Written by Vincent Prevosto, 2016
% Last Modified by GUIDE v2.5 17-Jun-2016 11:59:27

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @DataExportGui_OpeningFcn, ...
    'gui_OutputFcn',  @DataExportGui_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


%% --- Executes just before DataExportGui is made visible.
function DataExportGui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.

% Choose default command line output for DataExportGui
handles.output = hObject;
userinfo=UserDirInfo;
%% get most recently changed data folder
dataDir=userinfo.directory;
dataDirListing=dir(dataDir);
%removing dots
dataDirListing=dataDirListing(cellfun('isempty',cellfun(@(x) strfind(x,'.'),...
    {dataDirListing.name},'UniformOutput',false)));
%removing other folders
dataDirListing=dataDirListing(cellfun('isempty',cellfun(@(x)...
    regexp('Behav | DB | ImpedanceChecks | Video | export | example-klusters_neuroscope',x),...
    {dataDirListing.name},'UniformOutput',false)));
[~,fDateIdx]=sort([dataDirListing.datenum],'descend');
recentDataFolder=[dataDir userinfo.slash dataDirListing(fDateIdx(1)).name userinfo.slash];
%get most recent data folder in that folder if there is one 
dataDirListing=dir(recentDataFolder);
%removing dots
dataDirListing=dataDirListing(cellfun('isempty',cellfun(@(x) strfind(x,'.'),...
    {dataDirListing.name},'UniformOutput',false)));
if size(dataDirListing,1)>0
    [~,fDateIdx]=sort([dataDirListing.datenum],'descend');
    recentDataFolder=[recentDataFolder userinfo.slash dataDirListing(fDateIdx(1)).name userinfo.slash];
end

%% Get file path
[handles.fname,handles.dname] = uigetfile({'*.continuous;*.kwik;*.kwd;*.kwx;*.nex;*.ns*','All Data Formats';...
    '*.*','All Files' },'Most recent data',recentDataFolder);
if handles.fname==0
    handles.fname='';
    handles.dname=recentDataFolder;
end
handles=LoadData(handles);

%%  Update handles structure
guidata(hObject, handles);

%% Load data function
function handles=LoadData(handles)
    % function declaration
    axis_name= @(x) sprintf('Chan %.0f',x);
if strcmp(handles.fname,'')
    set(handles.FileName,'string','')
else
    cd(handles.dname);
    userinfo=UserDirInfo;
    set(handles.FileName,'string',[handles.dname handles.fname])
    % disp(['loading ' dname fname]);

    % load channel mapping
    subjectName=regexp(strrep(handles.dname,'_','-'),'(?<=\\)\w+\d+','match');
    if isempty(subjectName)
        subjectName=regexp(strrep(handles.fname,'_','-'),'^\w+\d+','match');
        if isempty(subjectName)
           subjectName=inputdlg('Enter subject name','Subject Name',1,{handles.fname});
        end
    end
    load([userinfo.probemap userinfo.slash 'ImplantList.mat']);
    probeID=implantList(~cellfun('isempty',...
        strfind(strrep({implantList.Mouse},'-',''),subjectName{:}))).Probe;
    load([userinfo.probemap userinfo.slash probeID '.mat']);
    wsVars=who;
    handles.probeLayout=eval(wsVars{~cellfun('isempty',strfind(wsVars,'Probe'))});
    
    %% Load data
    [handles.rec_info,handles.rawData,handles.Trials]=LoadEphysData(handles.fname,handles.dname);
    % parpool(2)
    % parfor tasknum = 1:2
    %     foo=[];
    %     if tasknum == 1
    %                 %assuming loading speed at 20Mb/s
    %         tStart=tic; lStart=tic; barlevel=0;
    %         wb = waitbar( barlevel, 'Reading Data File...' );
    %         while isempty(foo) & toc(tStart)<3600
    %             if toc(lStart)>5
    %                 barlevel=barlevel+0.12;
    %                 waitbar( min([1 1+barlevel]), wb, 'still reading');
    %             end
    %         end
    %         close(wb);
    %     elseif tasknum == 2
    %         [handles.rec_info,handles.rawData,handles.Trials]=LoadEphysData(handles.fname,handles.dname);
    %     end
    % end
    
    %map channels to electrodes
    switch handles.rec_info.expname{cell2mat(cellfun(@(x) strfind(x,'raw'), handles.rec_info.expname,'UniformOutput',false))+1}(2:end)
        case 'OpenEphys'
            [~,chMap]=sort([handles.probeLayout.OEChannel]);[~,chMap]=sort(chMap);
            handles.rawData=handles.rawData(chMap,:);   
        case 'Blackrock'
            [~,chMap]=sort([handles.probeLayout.BlackrockChannel]);[~,chMap]=sort(chMap);
            handles.rawData=handles.rawData(chMap,:);
        otherwise
            %stay as it is
            disp('no channel mapping available')
    end
    handles.keepChannels=(1:size(handles.rawData,1))';
    
    %% Plot raw data excerpt
    dataOneSecSample=handles.rawData(:,round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate:round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate);
    axes(handles.Axes_RawData); hold on;
    cla(handles.Axes_RawData);
    set(handles.Axes_RawData,'Visible','on');
    BaseShift=int32(max(abs(max(dataOneSecSample))));
    %     subplot(1,2,1);
    for ChN=1:size(handles.rawData,1)
        ShiftUp=(BaseShift*ChN)-...
            int32(median(median(dataOneSecSample(ChN,:))));
        plot(handles.Axes_RawData,int32(dataOneSecSample(ChN,:))+...
            ShiftUp);
    end
    set(handles.Axes_RawData,'xtick',linspace(0,handles.rec_info.samplingRate*2,4),...
        'xticklabel',round(linspace(round((round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate)/handles.rec_info.samplingRate),...
        round((round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate)/handles.rec_info.samplingRate),4)),'TickDir','out');
    set(handles.Axes_RawData,'ytick',linspace(single(BaseShift),single(ShiftUp+...
            int32(median(median(dataOneSecSample(ChN,:))))),...
            single(size(dataOneSecSample,1))),'yticklabel',...
            cellfun(axis_name, num2cell(1:size(dataOneSecSample,1)), 'UniformOutput', false))
    %   set(gca,'ylim',[-1000,10000],'xlim',[0,1800000])
    axis('tight');box off;
    set(handles.Axes_RawData,'ylim',[-1000,BaseShift...
    *int32(size(handles.keepChannels,1))+BaseShift]);
    xlabel(handles.Axes_RawData,'2 sec mid-recording')
    ylabel(handles.Axes_RawData,'Raw signal')
    set(handles.Axes_RawData,'Color','white','FontSize',12,'FontName','calibri');
    
    %% Plot pre-proc excerpt
    preprocMenu=get(handles.LB_ProcessingType,'string');
    preprocOption=get(handles.LB_ProcessingType,'value');
    preprocOption=preprocMenu(preprocOption);
    switch preprocOption{:}
        case 'No pre-processing'
            preprocOption={'nopp'};
        case 'BP - CAR (all channels)       ' 
            preprocOption={'CAR','all'};
        case 'BP - CAR'
            preprocOption={'CAR'};
        case 'LP - CAR'
            preprocOption={'CAR','LP'};
        case 'Bandpass (500 - 6000)'
            preprocOption={'bandpass'};
        case 'Bandpass - other'
            preprocOption={'bandpass','select'};
        case 'Normalization'
            preprocOption={'norm'};
        case 'Differential filtering'
            preprocOption={'difffilt'};
        case 'Lowpass 6000'
            preprocOption={'lowpass'};
        case 'Highpass 500'
            preprocOption={'highpass'};
        case 'Substract Moving Average'
            preprocOption={'movav_sub'};
        case 'Multi-step filtering'
            preprocOption={'multifilt'};
        case 'CAR subset only'
            preprocOption={'CAR_subset'};
    end
    
    dataOneSecSample_preproc=PreProcData(dataOneSecSample,handles.rec_info.samplingRate,preprocOption);
    axes(handles.Axes_PreProcessedData); hold on;
    cla(handles.Axes_PreProcessedData);
    set(handles.Axes_PreProcessedData,'Visible','on');
    BaseShift=int32(max(abs(max(dataOneSecSample_preproc))));
    %     subplot(1,2,2);  hold on;
    for ChN=1:size(handles.rawData,1)
        ShiftUp=(BaseShift*ChN)-...
            int32(median(median(dataOneSecSample_preproc(ChN,:))));
        plot(handles.Axes_PreProcessedData,int32(dataOneSecSample_preproc(ChN,:))+...
            ShiftUp);
    end
    set(handles.Axes_PreProcessedData,'xtick',linspace(0,handles.rec_info.samplingRate*2,4),...
        'xticklabel',round(linspace(round((round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate)/handles.rec_info.samplingRate),...
        round((round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate)/handles.rec_info.samplingRate),4)),'TickDir','out');
    try
        set(handles.Axes_PreProcessedData,'ytick',linspace(single(BaseShift),single(ShiftUp+...
            int32(median(median(dataOneSecSample_preproc(ChN,:))))),...
            single(size(dataOneSecSample_preproc,1))),'yticklabel',...
            cellfun(axis_name, num2cell(1:size(dataOneSecSample_preproc,1)), 'UniformOutput', false))
    catch
        set(handles.Axes_PreProcessedData,'ytick',linspace(0,double(int16(ChN-1)),(size(dataOneSecSample_preproc,1))),'yticklabel',...
            cellfun(axis_name, num2cell(1:size(dataOneSecSample_preproc,1)), 'UniformOutput', false))
    end
    %   set(gca,'ylim',[-1000,10000],'xlim',[0,1800000])
    axis('tight');box off;
    set(handles.Axes_PreProcessedData,'ylim',[-1000,BaseShift...
    *int32(size(handles.keepChannels,1))+BaseShift]);
    xlabel(handles.Axes_PreProcessedData,['Processing option: ' preprocOption{1}])
    ylabel(handles.Axes_PreProcessedData,'Pre-processed signal')
    set(handles.Axes_PreProcessedData,'Color','white','FontSize',12,'FontName','calibri');
end

%% --- Outputs from this function are returned to the command line.
function varargout = DataExportGui_OutputFcn(hObject, eventdata, handles)

% Get default command line output from handles structure
varargout{1} = handles.output;


%% --- Executes on selection change in LB_ProcessingType.
function LB_ProcessingType_Callback(hObject, eventdata, handles)
% function declaration
axis_name= @(x) sprintf('Chan %.0f',x);

preprocMenu=get(handles.LB_ProcessingType,'string');
preprocOption=preprocMenu(get(hObject,'value'));
switch preprocOption{:}
    case 'No pre-processing'
        preprocOption={'nopp'};
    case 'BP - CAR (all channels)       '
        preprocOption={'CAR','all'};
    case 'BP - CAR'
        preprocOption={'CAR'};
    case 'LP - CAR'
        preprocOption={'CAR','LP'};
    case 'Bandpass (500 - 6000)'
        preprocOption={'bandpass'};
    case 'Bandpass - other'
        preprocOption={'bandpass','select'};
    case 'Normalization'
        preprocOption={'norm'};
    case 'Differential filtering'
        preprocOption={'difffilt'};
    case 'Lowpass 6000'
        preprocOption={'lowpass'};
    case 'Highpass 500'
        preprocOption={'highpass'};
    case 'Substract Moving Average'
        preprocOption={'movav_sub'};
    case 'Multi-step filtering'
        preprocOption={'multifilt'};
    case 'CAR subset only'
        preprocOption={'CAR_subset'};
end

%% Plot pre-proc excerpt
dataOneSecSample=handles.rawData(handles.keepChannels,round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate:round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate);
[dataOneSecSample_preproc,handles.channelSelection]=PreProcData(dataOneSecSample,handles.rec_info.samplingRate,preprocOption);
cla(handles.Axes_PreProcessedData); %hold on;
% set(handles.Axes_PreProcessedData,'Visible','on');
%     subplot(1,2,2);  hold on;
BaseShift=int32(max(abs(max(dataOneSecSample_preproc))));
set(handles.Axes_PreProcessedData,'ylim',[-1000,BaseShift...
    *int32(size(handles.keepChannels,1))+BaseShift])

for ChN=1:size(handles.keepChannels,1)
    ShiftUp=(BaseShift*ChN)-...
        int32(median(median(dataOneSecSample_preproc(ChN,:))));
    plot(handles.Axes_PreProcessedData,int32(dataOneSecSample_preproc(ChN,:))+...
        ShiftUp);
end
% set(handles.Axes_PreProcessedData,'xtick',linspace(0,handles.rec_info.samplingRate*2,4),...
%     'xticklabel',round(linspace(round((round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate)/handles.rec_info.samplingRate),...
%     round((round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate)/handles.rec_info.samplingRate),4)),'TickDir','out');
try
set(handles.Axes_PreProcessedData,'ytick',linspace(single(BaseShift),single(ShiftUp+...
    int32(median(median(dataOneSecSample_preproc(ChN,:))))),...
    single(size(dataOneSecSample_preproc,1))),'yticklabel',...
    cellfun(axis_name, num2cell(1:size(dataOneSecSample_preproc,1)), 'UniformOutput', false))
catch
    set(handles.Axes_PreProcessedData,'ytick',linspace(0,double(int16(ChN-1)),(size(dataOneSecSample_preproc,1))),'yticklabel',...
    cellfun(axis_name, num2cell(1:size(dataOneSecSample_preproc,1)), 'UniformOutput', false))
end
% %   set(gca,'ylim',[-1000,10000],'xlim',[0,1800000])
% axis('tight');box off;
xlabel(handles.Axes_PreProcessedData,['Processing option: ' preprocOption{1}])
% ylabel(handles.Axes_PreProcessedData,'Pre-processed signal')
% set(handles.Axes_PreProcessedData,'Color','white','FontSize',12,'FontName','calibri');

%%  Update handles structure
guidata(hObject, handles);

%% --- Executes during object creation, after setting all properties.
function LB_ProcessingType_CreateFcn(hObject, eventdata, handles)

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%% --- Executes on button press in RB_ExportSpikes_OnlineSort.
function RB_ExportSpikes_OnlineSort_Callback(hObject, eventdata, handles)

% Hint: get(hObject,'Value') returns toggle state of RB_ExportSpikes_OnlineSort


%% --- Executes on button press in RB_ExportSpikes_OfflineSort.
function RB_ExportSpikes_OfflineSort_Callback(hObject, eventdata, handles)

% Hint: get(hObject,'Value') returns toggle state of RB_ExportSpikes_OfflineSort


%% --- Executes on button press in RB_ExportRaw_dat.
function RB_ExportRaw_dat_Callback(hObject, eventdata, handles)

set(handles.CB_CreateParamsFile,'value',get(handles.RB_ExportRaw_dat,'value'));


%% --- Executes on button press in CB_AddTTLChannel.
function CB_AddTTLChannel_Callback(hObject, eventdata, handles)

% Hint: get(hObject,'Value') returns toggle state of CB_AddTTLChannel


%% --- Executes on button press in PB_Export.
function PB_Export_Callback(hObject, eventdata, handles)
tic;
wb = waitbar( 0, 'Exporting Data' );
set(wb,'Name','Exporting','Color',[0 0.4471 0.7412]);

cd(handles.dname); %in case some other file was exported before

if get(handles.CB_ExportWhichChannel,'value')==0
    handles.rawData=handles.rawData(handles.keepChannels,:);
end

% export only excerpt
if get(handles.RB_ExportOnlySample,'value')==1
    if get(handles.LB_ExportSampleLocation,'value')==1
        handles.rawData=handles.rawData(:,1:30000*60*str2double(get(handles.TxEdit_SampleDuration,'String')));
    elseif get(handles.LB_ExportSampleLocation,'value')==2  
        handles.rawData=handles.rawData(:,...
            round(size(handles.rawData,2)/2)-30000*30*str2double(get(handles.TxEdit_SampleDuration,'String')):...
            round(size(handles.rawData,2)/2)+30000*30*str2double(get(handles.TxEdit_SampleDuration,'String')));
    elseif get(handles.LB_ExportSampleLocation,'value')==3
        handles.rawData=handles.rawData(:,end-30000*60*str2double(get(handles.TxEdit_SampleDuration,'String')):end);
    end
end
if get(handles.RB_ExportWithNoSignalCutout,'value')==1
    signalRegions=bwlabel(diff(handles.rawData(1,:)));
    handles.rawData=handles.rawData(:,1:length(signalRegions)-find(signalRegions(end:-1:1)>0,1));
end

%% pre-process data
preprocMenu=get(handles.LB_ProcessingType,'string');
preprocOption=get(handles.LB_ProcessingType,'value');
preprocOption=preprocMenu(preprocOption);
switch preprocOption{:}
    case 'No pre-processing'
        preprocOption={'nopp'};
    case 'BP - CAR (all channels)       ' 
            preprocOption={'CAR','all'};
    case 'BP - CAR'
            preprocOption={'CAR',num2str(handles.channelSelection)};
    case 'LP - CAR'
            preprocOption={'CAR','LP'};
    case 'Bandpass (500 - 6000)'
        preprocOption={'bandpass'}; 
    case 'Bandpass - other'
        preprocOption={'bandpass','select'}; 
    case 'Normalization'
        preprocOption={'norm'};
    case 'Differential filtering'
        preprocOption={'difffilt'};
    case 'Lowpass 6000'
        preprocOption={'lowpass'};
    case 'Highpass 500'
        preprocOption={'highpass'};
    case 'Substract Moving Average'
        preprocOption={'movav_sub'};
    case 'Multi-step filtering'
        preprocOption={'multifilt'};
    case 'CAR subset only'
        preprocOption={'CAR_subset'};
end
handles.preprocOption=preprocOption{1};
waitbar( 0.1, wb, ['Pre-processing Data: ' handles.preprocOption]);  
handles.rawData=PreProcData(handles.rawData,handles.rec_info.samplingRate,preprocOption);

if ~isa(handles.rawData,'int16')
    handles.rawData=int16(handles.rawData);
end

%% Online sorted spikes
% find file format from directory listing
dirlisting = dir(handles.dname);
dirlisting = {dirlisting(:).name};
dirlisting=dirlisting(cellfun('isempty',cellfun(@(x) strfind('.',x(end)),dirlisting,'UniformOutput',false)));
fileformats={'continuous','kwe','kwik','nex','ns6'};
whichformat=cellfun(@(x) find(~cellfun('isempty',strfind(fileformats,x(end-2:end)))),dirlisting,'UniformOutput',false);
whichformat=fileformats(unique([whichformat{~cellfun('isempty',whichformat)}]));

if get(handles.RB_ExportSpikes_OnlineSort,'value')==1
    waitbar( 0.5, wb, 'Getting spikes from online sorting');
    switch whichformat{:}
        case 'continuous'
        case {'kwe','kwik'}
            % KWX contains the spike data
            % h5disp('experiment1.kwx')
            ChanInfo=h5info('experiment1.kwx');
            
            %KWD contains the continuous data for a given processor in the /recordings/#/data dataset, where # is the recording number, starting at 0
            RawInfo=h5info('experiment1_100.raw.kwd','/recordings/0/data');
            RecDur=RawInfo.Dataspace.Size;
            
            %Keep info on ADC resolution 
%             Spikes.Online_Sorting.Resolution=
            
            %Keep list of channels with > 1Hz firing rate
%             GoodChans=cell(size(ChanInfo.Groups.Groups,1),1);
            for ChExN=1:size(ChanInfo.Groups.Groups,1)
                if ChanInfo.Groups.Groups(ChExN).Datasets(2).Dataspace.Size/(RecDur(2)/handles.rec_info.samplingRate)>1
                    Spikes.Online_Sorting.GoodChans(ChExN)=regexp(ChanInfo.Groups.Groups(ChExN).Name,'\d+$','match');
                end
            end
            
            for ChExN=1:size(handles.rawData,1)
                Spikes.Online_Sorting.electrode(ChExN)=ChExN;
                Spikes.Online_Sorting.samplingRate(ChExN,1)=handles.rec_info.samplingRate;
                try
                    Spikes.Online_Sorting.Units{ChExN,1}=h5read('experiment1.kwx',['/channel_groups/' num2str(ChExN-1) '/recordings']);
                    Spikes.Online_Sorting.SpikeTimes{ChExN,1}=h5read('experiment1.kwx',['/channel_groups/' num2str(ChExN-1) '/time_samples']);
                    Spikes.Online_Sorting.Waveforms{ChExN,1}=h5read('experiment1.kwx',['/channel_groups/' num2str(ChExN-1) '/waveforms_filtered']);
                catch
                    Spikes.Online_Sorting.Units{ChExN,1}=[];
                    Spikes.Online_Sorting.SpikeTimes{ChExN,1}=[];
                    Spikes.Online_Sorting.Waveforms{ChExN,1}=[];
                end
            end
        case 'nex'
        case 'ns6' % Blackrock
            SpikeData = openNEV([handles.dname handles.fname(1:end-3) 'nev']); 
            % ADC resolution is 0.25uV per bit. Divide values by 4 to convert to uV 
            Spikes.Online_Sorting.Resolution={0.25, 'uV per bit'};
%             GoodChans=unique(SpikeData.Data.Spikes.Electrode);
%             if size(handles.rawData,1)~=length(GoodChans)
%                 disp('not as many spiking channels as raw data')
%             end
            if sum([SpikeData.ElectrodesInfo([handles.probeLayout.BlackrockChannel]).ElectrodeID]-...
               uint16([SpikeData.ElectrodesInfo([handles.probeLayout.BlackrockChannel]).ConnectorPin]))==0
                % recording wasn't mapped
                GoodChans=[handles.probeLayout.BlackrockChannel];
            else
                GoodChans=[handles.probeLayout.Electrode];
            end
           
            for ChExN=1:size(GoodChans,2)
                Spikes.Online_Sorting.electrode(ChExN)=ChExN;
                Spikes.Online_Sorting.samplingRate(ChExN,1)=SpikeData.MetaTags.SampleRes;
                try
                    Spikes.Online_Sorting.Units{ChExN,1}=int8(SpikeData.Data.Spikes.Unit...
                        (SpikeData.Data.Spikes.Electrode==GoodChans(ChExN)));
                    Spikes.Online_Sorting.SpikeTimes{ChExN,1}=SpikeData.Data.Spikes.TimeStamp...
                        (SpikeData.Data.Spikes.Electrode==GoodChans(ChExN));
                    Spikes.Online_Sorting.Waveforms{ChExN,1}=SpikeData.Data.Spikes.Waveform...
                        (:,SpikeData.Data.Spikes.Electrode==GoodChans(ChExN));
                catch
                    Spikes.Online_Sorting.Units{ChExN,1}=[];
                    Spikes.Online_Sorting.SpikeTimes{ChExN,1}=[];
                    Spikes.Online_Sorting.Waveforms{ChExN,1}=[];
                end
            end
        otherwise
    end
end
%% Spike thresholding 
if get(handles.RB_ExportSpikes_OfflineSort,'value')==1
    waitbar( 0.5, wb, 'Getting spike times from RMS threshold'); 
    for ChExN=1:size(handles.rawData,1)
        Spikes.Offline_Threshold.electrode(ChExN)=ChExN;
        Spikes.Offline_Threshold.samplingRate(ChExN,1)=handles.rec_info.samplingRate;
        thld=rms((handles.rawData(Spikes.Offline_Threshold.electrode(ChExN),:)));
        Spikes.Offline_Threshold.RMS_Threshold=str2double(get(handles.TxEdit_RMSLevel,'String'));
        
        %% get spike times
        switch get(handles.LB_ThresholdSide,'value')
            case 1
                Spikes.Offline_Threshold.Threshold_Side='upper';
                Spikes.Offline_Threshold.data{ChExN,1}=diff(handles.rawData(Spikes.Offline_Threshold.electrode(ChExN),:)>Spikes.Offline_Threshold.RMS_Threshold*thld)==1;
            case 2
                Spikes.Offline_Threshold.Threshold_Side='lower';
                Spikes.Offline_Threshold.data{ChExN,1}=diff(handles.rawData(Spikes.Offline_Threshold.electrode(ChExN),:)<-Spikes.Offline_Threshold.RMS_Threshold*thld)==1;
        end
        Spikes.Offline_Threshold.type{ChExN,1}='nativeData';
        
        % plots
        % figure; hold on;
        % plot(handles.rawData(Spikes.Offline_Threshold.electrode(ChExN),1:300*Spikes.Offline_Threshold.samplingRate));
        % % plot(handles.rawData(Spikes.Offline_Threshold.electrode,:)+1500);
        % % thd10=rms((handles.rawData(10,:)));
        % plot(-7*thld*ones(1,size(1:300*Spikes.Offline_Threshold.samplingRate,2)));
        % plot(-40*thld*ones(1,size(1:300*Spikes.Offline_Threshold.samplingRate,2)));
        % % plot(1500-4*thd*ones(1,size(handles.rawData,2)));
        % % foo=handles.rawData(Spikes.Offline_Threshold.electrode(ChExN),:)>(-40*thld);
        
        % plot(Spikes.Offline_Threshold.nativeData*500);
        
        %% downsample to 1 millisecond bins
        Spikes.Offline_Threshold.samplingRate(ChExN,2)=1000;
        Spikes.Offline_Threshold.type{ChExN,2}='downSampled';
        spikeTimeIdx=zeros(1,size(Spikes.Offline_Threshold.data{ChExN,1},2));
        spikeTimeIdx(Spikes.Offline_Threshold.data{ChExN,1})=1;
        spikeTimes=find(Spikes.Offline_Threshold.data{ChExN,1});
        binSize=1;
        numBin=ceil(size(spikeTimeIdx,2)/(Spikes.Offline_Threshold.samplingRate(ChExN,1)/Spikes.Offline_Threshold.samplingRate(ChExN,2))/binSize);
        % binspikeTime = histogram(double(spikeTimes), numBin); %plots directly histogram
        [Spikes.Offline_Threshold.data{ChExN,2},Spikes.Offline_Threshold.binEdges{ChExN}] = histcounts(double(spikeTimes), linspace(0,size(spikeTimeIdx,2),numBin));
        Spikes.Offline_Threshold.data{ChExN,2}(Spikes.Offline_Threshold.data{ChExN,2}>1)=1; %no more than 1 spike per ms
        
        % figure;
        % bar(Spikes.Offline_Threshold.binEdges(1:end-1)+round(mean(diff(Spikes.Offline_Threshold.binEdges))/2),Spikes.Offline_Threshold.downSampled,'hist');
    end
end

%% get clock time (time at which recording started, to sync with TTLs)
if ~isfield(handles.Trials,'startClockTime') | isempty(handles.Trials.startClockTime)
    waitbar( 0.7, wb, 'Getting clock time');  
    if strfind(handles.fname,'raw.kwd')
        % to check Software Time and Processor Time, run h5read('experiment1.kwe','/event_types/Messages/events/user_data/Text')
        % don't use
        % h5readatt(handles.fname,'/recordings/0/','start_time').That
        % start_time happens earlier (like 20ms before). The difference is
        % due to the time it takes to open files
            handles.Trials.startClockTime=h5read('experiment1.kwe','/event_types/Messages/events/time_samples');
            handles.Trials.startClockTime=handles.Trials.startClockTime(1);

    elseif strfind(handles.fname,'continuous')
            handles.Trials.startClockTime=handles.rec_info.startClockTime.ts;
    else
            handles.Trials.startClockTime=0; %Recording and TTL times already sync'ed
    end
end
%% Export
userinfo=UserDirInfo;
waitbar( 0.9, wb, 'Exporting data');

% if strfind(handles.rec_info.expname{end}(2:end),'LY') %regexp(handles.rec_info.expname{end}(2:end),'\_\d\d\d\d\_')
%     uname='Leeyup';
% else
%     uname=getenv('username');
% end

if regexp(handles.rec_info.expname{end}(2:end),'\_\d\d\d\d\_') %Open Ephys date format
    dateStart=regexp(handles.rec_info.expname{end}(2:end),'\_\d\d\d\d\_');
elseif regexp(handles.rec_info.expname{end}(2:end),'^\d\d\d\d')
    dateStart=0;
elseif regexp(handles.rec_info.expname{end}(2:end),'\_\d\d\d\d')
    dateStart=regexp(handles.rec_info.expname{end}(2:end),'\_\d\d\d\d');
else
    try
        fileListing=dir(handles.dname);
        handles.rec_info.date=fileListing(~cellfun('isempty',strfind({fileListing.name},handles.fname))).date;
        handles.rec_info.date=datetime(handles.rec_info.date,'Format','yyyy-MM-dd');
        if strfind(handles.fname,'ns')
            sessionNum=cell2mat(regexp(handles.fname,'(?<=^\w+\_)\d+(?=\_)','match'));
            handles.rec_info.expname{end}=[handles.rec_info.expname{end} '_' sessionNum];
        end
        dateStart=size(handles.rec_info.expname{end},2);
    catch
        return;
    end
end
if ~isfield(handles.rec_info,'date')
    dateItems=regexp(handles.rec_info.expname{end}(2+dateStart:end),'\d+','match');
    try
        handles.rec_info.date=[dateItems{1:3} '_' dateItems{4:6}];
    catch
        handles.rec_info.date=[dateItems{1} '_' dateItems{2:end}];
    end
else
%     dateItems=regexp(handles.rec_info.date,'\d+','match');
%     try
%         handles.rec_info.date=[dateItems{1:3} '_' dateItems{4:6}];
%     catch
%         handles.rec_info.date=[dateItems{1} '_' dateItems{2:end}];
%     end
end

handles.rec_info.sys=handles.rec_info.expname{end-1}(2:end);
switch handles.rec_info.sys
    case 'OpenEphys'
        handles.rec_info.sys='OEph';
    case 'TBSI'
        handles.rec_info.sys='TBSI';
    case 'Blackrock'
        handles.rec_info.sys='BR';
    otherwise
            switch cell2mat(regexp(handles.fname,'(?<=^\w+\.)\w\w','match'))
                case 'ns'
                    handles.rec_info.sys='BR';
                case 'ra'
                    handles.rec_info.sys='OEph';
                case 'kw'
                    handles.rec_info.sys='OEph';
                case 'co'
                    handles.rec_info.sys='OEph';
                case 'ne'
                    handles.rec_info.sys='TBSI';
            end
end

if get(handles.CB_AddTTLChannel,'value') %adding a TTL Channel to exported data
    if isfield(handles.Trials,'continuous')
        TTL_reSampled = handles.Trials.continuous - median(handles.Trials.continuous);
        TTL_reSampled = resample(double(TTL_reSampled),30,1);
        TTL_reSampled = TTL_reSampled(1:size(handles.rawData,2));
        handles.rawData=[handles.rawData;TTL_reSampled];
    else %need to create one
    end
%     if isdatetime(handles.rec_info.date)
%         handles.rec_info.date=datestr(handles.rec_info.date,'yyyy-mm-dd');
%     end
    handles.rec_info.expname=[handles.rec_info.expname{end}(2:dateStart) '_'...
        handles.rec_info.sys '_' num2str(size(handles.rawData,1)) 'Ch_SyncCh_'  handles.preprocOption];
else
    handles.rec_info.expname=[handles.rec_info.expname{end}(2:dateStart) '_'...
        handles.rec_info.sys '_' num2str(size(handles.rawData,1)) 'Ch_'  handles.preprocOption];
end

if get(handles.CB_SpecifyName,'value')==0
    switch cell2mat(regexp(handles.fname,'(?<=^\w+\.)\w\w','match'))
        case 'ns'
            fNameBegin=cell2mat(regexp(handles.fname,'\w+(?=([a-z]|\_)\d+\.\w+$)','match'));
        case 'ra'
            fNameBegin=strrep([cell2mat(regexp(handles.rec_info.expname,'\w+(?=_OEph)','match')) ...
                cell2mat(regexp(handles.dname,'(?<=_\d\d-\d\d-\d\d_).+(?=\\$)','match'))],' ','');
        case 'kw'
        case 'co'
        case 'ne'
    end
    fNameEnds=cell2mat(regexp(handles.rec_info.expname,['(?<=' cell2mat(...
        regexp(handles.rec_info.expname,['\w+(?=' handles.rec_info.sys ')'],'match')) ')\w+'],...
        'match')); % ^^
    if regexp(handles.fname,['(?<=' fNameBegin ')\_\d+']) %for BR recordings mostly
        sessionRecNum=cell2mat(regexp(handles.fname,['(?<=' fNameBegin '\_)\d'],'match'));
        customFileName=[fNameBegin sessionRecNum '_' fNameEnds];
    else
        customFileName=[fNameBegin '_' fNameEnds];
    end
    handles.rec_info.exportname=inputdlg('Enter export file name','File Name',1,{customFileName});
    handles.rec_info.exportname=handles.rec_info.exportname{:};
else
    handles.rec_info.exportname=handles.rec_info.expname;
end

%% create export folder (if needed), go there and save info
exportDir=regexprep(userinfo.directory,'\\\w+$','\\export');
if get(handles.CB_SpecifyDir,'value')==0
    exportDir=uigetdir(exportDir,'Select export directory');
    cd(exportDir)
else
    cd(exportDir);
    if ~isdir(cell2mat(regexp(handles.rec_info.expname,'\w+(?=_\w+$)','match')))
        mkdir(cell2mat(regexp(handles.rec_info.expname,'\w+(?=_\w+$)','match'))); %create dir name without preprocOption
    end
    cd(cell2mat(regexp(handles.rec_info.expname,'\w+(?=_\w+$)','match')));
end
set(handles.PB_SpikePanel,'UserData',cd);

save([handles.rec_info.exportname '_info'],'-struct','handles','rec_info','-v7.3');
fileID = fopen([handles.rec_info.exportname '.txt'],'w'); 
if ischar(handles.rec_info.date)
    handles.rec_info.date=regexp(handles.dname,'(?<=\d+_\d+_).+(?=\\)','match');
    handles.rec_info.date=handles.rec_info.date{:};
    fprintf(fileID,['%21s\t %' num2str(length(handles.rec_info.date)) 's\r'],...
        'recording date       ',handles.rec_info.date);
else
    fprintf(fileID,['%21s\t %' num2str(length(datestr(handles.rec_info.date))) 's\r'],...
        'recording date       ',datestr(handles.rec_info.date));
end
fprintf(fileID,'%21s\t\t\t %12u\r','sampling rate        ',handles.rec_info.samplingRate);
fprintf(fileID,'%21s\t\t\t %12u\r','duration (rec. clock)',handles.rec_info.dur);
fprintf(fileID,'%21s\t\t\t %12.4f\r','duration (s.)        ',handles.rec_info.dur/handles.rec_info.samplingRate);
fprintf(fileID,'%21s\t\t\t %12u\r','number of rec. chans ',handles.rec_info.numRecChan);
fprintf(fileID,['%21s\t\t %' num2str(length(num2str(handles.keepChannels'))) 's\r'],...
    'exported channels    ',num2str(handles.keepChannels'));
fclose(fileID);

if get(handles.RB_ExportRaw_dat,'value')
    fileID = fopen([handles.rec_info.exportname '.dat'],'w');
    fwrite(fileID,handles.rawData,'int16');
    % fprintf(fileID,'%d\n',formatdata);
    fclose(fileID);
end

if get(handles.RB_ExportRaw_mat,'value')
    save([handles.rec_info.exportname '_raw'],'-struct','handles','rawData','-v7.3'); 
end

if get(handles.RB_ExportSpikes_OfflineSort,'value')==1 || get(handles.RB_ExportSpikes_OnlineSort,'value')==1
    save([handles.rec_info.exportname '_spikes'],'Spikes','-v7.3');
    save([handles.rec_info.exportname '_trials'],'-struct','handles','Trials','-v7.3');
end

if get(handles.CB_CreateParamsFile,'value')==1
    [status,cmdout]=RunSpykingCircus(cd,handles.rec_info.exportname,'paramsfile');
    if status~=1
        disp('problem generating the parameter file')
    else
        disp(cmdout)
    end
end

cd(handles.dname)
if get(handles.RB_ExportRaw_NEV,'value') 
   data = openNSxNew([handles.dname handles.fname]);
   data.Data=flipud(handles.rawData);
   saveNSx(data,[handles.rec_info.exportname '_CAR' handles.fname(end-3:end)])
end

close(wb);
disp(['took ' num2str(toc) ' seconds to export data']);

%% --- Executes on button press in CB_SpecifyDir.
function CB_SpecifyDir_Callback(hObject, eventdata, handles)

% Hint: get(hObject,'Value') returns toggle state of CB_SpecifyDir


%% --- Executes on button press in CB_ExportWhichChannel.
function CB_ExportWhichChannel_Callback(hObject, eventdata, handles)
% hObject    handle to CB_ExportWhichChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if get(hObject,'Value')==0
    % channel string
   chStr= num2str(linspace(1,size(handles.rawData,1),size(handles.rawData,1))');
   handles.keepChannels= (listdlg('PromptString',...
        'select channels to keep:','ListString',chStr))';
else
    handles.keepChannels=(1:size(handles.rawData,1))';
end

LB_ProcessingType_Callback(handles.LB_ProcessingType, eventdata, handles);

%%  Update handles structure
guidata(hObject, handles);

%% --- Executes on selection change in LB_ThresholdSide.
function LB_ThresholdSide_Callback(hObject, eventdata, handles)

% Hints: contents = cellstr(get(hObject,'String')) returns LB_ThresholdSide contents as cell array
%        contents{get(hObject,'Value')} returns selected item from LB_ThresholdSide

%% --- Executes during object creation, after setting all properties.
function LB_ThresholdSide_CreateFcn(hObject, eventdata, handles)

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%% --- Executes on button press in CB_SpecifyName.
function CB_SpecifyName_Callback(hObject, eventdata, handles)

% Hint: get(hObject,'Value') returns toggle state of CB_SpecifyName

%% --- Executes on button press in PB_SpikePanel.
function PB_SpikePanel_Callback(hObject, eventdata, handles)
handles.exportDir=hObject.UserData;
exportDirListing=dir(handles.exportDir);
handles.spikeFile={exportDirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'_spikes.'),...
                {exportDirListing.name},'UniformOutput',false))).name};
if size(handles.spikeFile,2)>1
    bestFit=sum(cell2mat(cellfun(@(name) ismember(handles.fname(1:end-4),name(1:size(handles.fname(1:end-4),2))),...
        handles.spikeFile,'UniformOutput',false)'),2);
    bestFit=bestFit==max(bestFit);
    handles.spikeFile=handles.spikeFile{bestFit};
else
    handles.spikeFile=handles.spikeFile{:};
end

hfields = fieldnames(handles);
hdata = struct2cell(handles);
hkeep = logical(cell2mat(cellfun(@(x) sum(~cellfun('isempty',...
    strfind({'fname';'dname';'rec_info';'Trials';'exportDir';'spikeFile'},x))),...
    hfields,'UniformOutput', false)));
htransfer = cell2struct(hdata(hkeep), hfields(hkeep));

SpikeVisualizationGUI(htransfer);

%% --- Executes on button press in PB_LoadFile.
function PB_LoadFile_Callback(hObject, eventdata, handles)

[handles.fname,handles.dname] = uigetfile({'*.continuous;*.kwik;*.kwd;*.kwx;*.nex;*.ns*','All Data Formats';...
    '*.*','All Files' },'Most recent data',handles.dname);
if handles.fname==0
    handles.fname='';
    handles.dname='C:\Data';
end
handles=LoadData(handles);
%%  Update handles structure
guidata(hObject, handles);

%% --- Executes on selection change in LB_ExportSampleLocation.
function LB_ExportSampleLocation_Callback(hObject, eventdata, handles)

% Hints: contents = cellstr(get(hObject,'String')) returns LB_ExportSampleLocation contents as cell array
%        contents{get(hObject,'Value')} returns selected item from LB_ExportSampleLocation


%% --- Executes during object creation, after setting all properties.
function LB_ExportSampleLocation_CreateFcn(hObject, eventdata, handles)

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function TxEdit_SampleDuration_Callback(hObject, eventdata, handles)

% Hints: get(hObject,'String') returns contents of TxEdit_SampleDuration as text
%        str2double(get(hObject,'String')) returns contents of TxEdit_SampleDuration as a double


%% --- Executes during object creation, after setting all properties.
function TxEdit_SampleDuration_CreateFcn(hObject, eventdata, handles)

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


%% --- Executes on button press in RB_ExportOnlySample.
function RB_ExportOnlySample_Callback(hObject, eventdata, handles)

% Hint: get(hObject,'Value') returns toggle state of RB_ExportOnlySample


%% --- Executes on button press in RB_ExportRaw_mat.
function RB_ExportRaw_mat_Callback(hObject, eventdata, handles)

% Hint: get(hObject,'Value') returns toggle state of RB_ExportRaw_mat


%% --- Executes on button press in RB_ExportWithNoSignalCutout.
function RB_ExportWithNoSignalCutout_Callback(hObject, eventdata, handles)

% Hint: get(hObject,'Value') returns toggle state of RB_ExportWithNoSignalCutout


%% --- Executes on button press in CB_CreateParamsFile.
function CB_CreateParamsFile_Callback(hObject, eventdata, handles)

% Hint: get(hObject,'Value') returns toggle state of CB_CreateParamsFile


% --- Executes on button press in RB_ExportRaw_NEV.
function RB_ExportRaw_NEV_Callback(hObject, eventdata, handles)
if get(handles.RB_ExportRaw_NEV,'value')
    set(handles.RB_ExportSpikes_OnlineSort,'value',0);
    set(handles.RB_ExportSpikes_OfflineSort,'value',0);
    set(handles.RB_ExportRaw_dat,'value',0);
    set(handles.RB_ExportRaw_mat,'value',0); 
    set(handles.CB_CreateParamsFile,'value',0);
end


