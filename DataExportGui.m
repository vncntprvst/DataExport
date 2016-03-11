function varargout = DataExportGui(varargin)
% DATAEXPORTGUI MATLAB code for DataExportGui.fig
%      DATAEXPORTGUI, by itself, creates a new DATAEXPORTGUI or raises the existing
%      singleton*.
%
%      H = DATAEXPORTGUI returns the handle to a new DATAEXPORTGUI or the handle to
%      the existing singleton*.
%
%      DATAEXPORTGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in DATAEXPORTGUI.M with the given input arguments.
%
%      DATAEXPORTGUI('Property','Value',...) creates a new DATAEXPORTGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before DataExportGui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to DataExportGui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help DataExportGui

% Last Modified by GUIDE v2.5 04-Mar-2016 17:13:18

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


% --- Executes just before DataExportGui is made visible.
function DataExportGui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to DataExportGui (see VARARGIN)

% Choose default command line output for DataExportGui
handles.output = hObject;

% function declaration
axis_name= @(x) sprintf('Chan %.0f',x);

%% get most recently changed data folder
dataDir='C:\Data\';
dataDirListing=dir(dataDir);
dataDirListing=dataDirListing(3:end); %removing dots
[~,fDateIdx]=sort([dataDirListing.datenum],'descend');
recentDataFolder=[dataDir dataDirListing(fDateIdx(1)).name '\'];
%get most recent data folder in that folder
dataDirListing=dir(recentDataFolder);
[~,fDateIdx]=sort([dataDirListing.datenum],'descend');
recentDataFolder=[recentDataFolder dataDirListing(fDateIdx(1)).name '\'];

%% Get file path
[handles.fname,handles.dname] = uigetfile({'*.continuous;*.kwik;*.kwd;*.kwx;*.nex;*.ns*','All Data Formats';...
    '*.*','All Files' },'Most recent data',recentDataFolder);
cd(handles.dname);
set(handles.FileName,'string',handles.fname)
% disp(['loading ' dname fname]);

%% Load data
[handles.rec_info,handles.rawData,handles.trials]=LoadEphysData(handles.fname,handles.dname);
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
%         [foo,bla,bli]=LoadEphysData(handles.fname,handles.dname);
%     end
% end

%% Plot raw data excerpt
dataOneSecSample=handles.rawData(:,round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate:round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate);
axes(handles.Axes_RawData); hold on;
set(handles.Axes_RawData,'Visible','on');
%     subplot(1,2,1);
for ChN=1:size(handles.rawData,1)
    plot(handles.Axes_RawData,double(dataOneSecSample(ChN,:))+(max(abs(mean(dataOneSecSample)))*(ChN-1))-...
        mean(mean(dataOneSecSample(ChN,:))));
end
set(handles.Axes_RawData,'xtick',linspace(0,handles.rec_info.samplingRate*2,4),...
    'xticklabel',round(linspace(round((round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate)/handles.rec_info.samplingRate),...
    round((round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate)/handles.rec_info.samplingRate),4)),'TickDir','out');
set(handles.Axes_RawData,'ytick',linspace(0,double(max(abs(mean(dataOneSecSample)))*(ChN-1)),size(handles.rawData,1)),'yticklabel',...
    cellfun(axis_name, num2cell(1:size(handles.rawData,1)), 'UniformOutput', false))
%   set(gca,'ylim',[-1000,10000],'xlim',[0,1800000])
axis('tight');box off;
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
    case 'CAR (all channels)       '
        preprocOption={'CAR','all'};
    case 'CAR'
        preprocOption={'CAR'};
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
end

dataOneSecSample_preproc=PreProcData(dataOneSecSample,handles.rec_info.samplingRate,preprocOption);
axes(handles.Axes_PreProcessedData); hold on;
set(handles.Axes_PreProcessedData,'Visible','on');
%     subplot(1,2,2);  hold on;
for ChN=1:size(handles.rawData,1)
    plot(handles.Axes_PreProcessedData,(dataOneSecSample_preproc(ChN,:))+(max(abs(max(dataOneSecSample_preproc)))*(ChN-1))-...
        mean(mean(dataOneSecSample_preproc(ChN,:))));
end
set(handles.Axes_PreProcessedData,'xtick',linspace(0,handles.rec_info.samplingRate*2,4),...
    'xticklabel',round(linspace(round((round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate)/handles.rec_info.samplingRate),...
    round((round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate)/handles.rec_info.samplingRate),4)),'TickDir','out');
set(handles.Axes_PreProcessedData,'ytick',linspace(0,double(max(abs(max(dataOneSecSample_preproc)))*int16(ChN-1)),(size(dataOneSecSample_preproc,1))),'yticklabel',...
    cellfun(axis_name, num2cell(1:size(dataOneSecSample_preproc,1)), 'UniformOutput', false))
%   set(gca,'ylim',[-1000,10000],'xlim',[0,1800000])
axis('tight');box off;
xlabel(handles.Axes_PreProcessedData,['Processing option: ' preprocOption{1}])
ylabel(handles.Axes_PreProcessedData,'Pre-processed signal')
set(handles.Axes_PreProcessedData,'Color','white','FontSize',12,'FontName','calibri');

%%  Update handles structure
guidata(hObject, handles);

% --- Outputs from this function are returned to the command line.
function varargout = DataExportGui_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on selection change in LB_ProcessingType.
function LB_ProcessingType_Callback(hObject, eventdata, handles)
% hObject    handle to LB_ProcessingType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% function declaration
axis_name= @(x) sprintf('Chan %.0f',x);

preprocMenu=get(handles.LB_ProcessingType,'string');
preprocOption=preprocMenu(get(hObject,'value'));
switch preprocOption{:}
    case 'No pre-processing'
        preprocOption={'nopp'};
    case 'CAR (all channels)       '
        preprocOption={'CAR','all'};
    case 'CAR'
        preprocOption={'CAR'};
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
end

%% Plot pre-proc excerpt
dataOneSecSample=handles.rawData(:,round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate:round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate);
dataOneSecSample_preproc=PreProcData(dataOneSecSample,handles.rec_info.samplingRate,preprocOption);
cla(handles.Axes_PreProcessedData); %hold on;
% set(handles.Axes_PreProcessedData,'Visible','on');
%     subplot(1,2,2);  hold on;
set(handles.Axes_PreProcessedData,'ylim',[-1000,double(max(abs(max(dataOneSecSample_preproc)))*int16(size(handles.rawData,1)-1))+1000])

for ChN=1:size(handles.rawData,1)
    plot(handles.Axes_PreProcessedData,(dataOneSecSample_preproc(ChN,:))+(max(abs(max(dataOneSecSample_preproc)))*(ChN-1))-...
        mean(mean(dataOneSecSample_preproc(ChN,:))));
end
% set(handles.Axes_PreProcessedData,'xtick',linspace(0,handles.rec_info.samplingRate*2,4),...
%     'xticklabel',round(linspace(round((round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate)/handles.rec_info.samplingRate),...
%     round((round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate)/handles.rec_info.samplingRate),4)),'TickDir','out');
set(handles.Axes_PreProcessedData,'ytick',linspace(0,double(max(abs(max(dataOneSecSample_preproc)))*int16(ChN-1)),(size(dataOneSecSample_preproc,1))),'yticklabel',...
    cellfun(axis_name, num2cell(1:size(dataOneSecSample_preproc,1)), 'UniformOutput', false))
% %   set(gca,'ylim',[-1000,10000],'xlim',[0,1800000])
% axis('tight');box off;
xlabel(handles.Axes_PreProcessedData,['Processing option: ' preprocOption{1}])
% ylabel(handles.Axes_PreProcessedData,'Pre-processed signal')
% set(handles.Axes_PreProcessedData,'Color','white','FontSize',12,'FontName','calibri');

%%  Update handles structure
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function LB_ProcessingType_CreateFcn(hObject, eventdata, handles)
% hObject    handle to LB_ProcessingType (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in RB_ExportSpikes_OnlineSort.
function RB_ExportSpikes_OnlineSort_Callback(hObject, eventdata, handles)
% hObject    handle to RB_ExportSpikes_OnlineSort (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of RB_ExportSpikes_OnlineSort


% --- Executes on button press in RB_ExportSpikes_OfflineSort.
function RB_ExportSpikes_OfflineSort_Callback(hObject, eventdata, handles)
% hObject    handle to RB_ExportSpikes_OfflineSort (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of RB_ExportSpikes_OfflineSort


% --- Executes on button press in RB_ExportRawData.
function RB_ExportRawData_Callback(hObject, eventdata, handles)
% hObject    handle to RB_ExportRawData (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of RB_ExportRawData


% --- Executes on button press in CB_AddTTLChannel.
function CB_AddTTLChannel_Callback(hObject, eventdata, handles)
% hObject    handle to CB_AddTTLChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of CB_AddTTLChannel


% --- Executes on button press in PB_Export.
function PB_Export_Callback(hObject, eventdata, handles)
% hObject    handle to PB_Export (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
tic;
wb = waitbar( 0, 'Exporting Data' );
set(wb,'Name','Exporting','Color',[0 0.4471 0.7412]);
%% pre-process data
preprocMenu=get(handles.LB_ProcessingType,'string');
preprocOption=get(handles.LB_ProcessingType,'value');
preprocOption=preprocMenu(preprocOption);
switch preprocOption{:}
    case 'No pre-processing'
        preprocOption={'nopp'};
    case 'CAR (all channels)       '
        preprocOption={'CAR','all'};
    case 'CAR'
        preprocOption={'CAR'};
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
end
handles.preprocOption=preprocOption{1};
waitbar( 0.1, wb, ['Pre-processing Data: ' handles.preprocOption]);  
handles.rawData=PreProcData(handles.rawData,handles.rec_info.samplingRate,preprocOption);

if ~isa(handles.rawData,'int16')
    handles.rawData=int16(handles.rawData);
end

if get(handles.CB_ExportWhichChannel,'value')==0
    % channel string
    chStr= num2str(linspace(1,size(handles.rawData,1),size(handles.rawData,1))');

    ChExport= listdlg('PromptString',...
        'select channels to export:','ListString',chStr);
    handles.rawData=handles.rawData(ChExport,:);
end

%% Spike thresholding 
if get(handles.RB_ExportSpikes_OfflineSort,'value')==1
    waitbar( 0.5, wb, 'Getting spike times from RMS threshold');  
    for ChExN=1:size(handles.rawData,1)
        Spikes.Offline_Threshold.channel(ChExN)=ChExN;
        Spikes.Offline_Threshold.samplingRate(ChExN,1)=handles.rec_info.samplingRate;
        thld=rms((handles.rawData(Spikes.Offline_Threshold.channel(ChExN),:)));
        Spikes.Offline_Threshold.RMS_Threshold=str2double(get(handles.TxEdit_RMSLevel,'String'));
        
        %% get spike times
        switch get(handles.LB_ThresholdSide,'value')
            case 1
                Spikes.Offline_Threshold.Threshold_Side='upper';
                Spikes.Offline_Threshold.data{ChExN,1}=diff(handles.rawData(Spikes.Offline_Threshold.channel(ChExN),:)>Spikes.Offline_Threshold.RMS_Threshold*thld)==1;
            case 2
                Spikes.Offline_Threshold.Threshold_Side='lower';
                Spikes.Offline_Threshold.data{ChExN,1}=diff(handles.rawData(Spikes.Offline_Threshold.channel(ChExN),:)<-Spikes.Offline_Threshold.RMS_Threshold*thld)==1;
        end
        Spikes.Offline_Threshold.type{ChExN,1}='nativeData';
        
        % plots
        % figure; hold on;
        % plot(handles.rawData(Spikes.Offline_Threshold.channel(ChExN),1:300*Spikes.Offline_Threshold.samplingRate));
        % % plot(handles.rawData(Spikes.Offline_Threshold.channel,:)+1500);
        % % thd10=rms((handles.rawData(10,:)));
        % plot(-7*thld*ones(1,size(1:300*Spikes.Offline_Threshold.samplingRate,2)));
        % plot(-40*thld*ones(1,size(1:300*Spikes.Offline_Threshold.samplingRate,2)));
        % % plot(1500-4*thd*ones(1,size(handles.rawData,2)));
        % % foo=handles.rawData(Spikes.Offline_Threshold.channel(ChExN),:)>(-40*thld);
        
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
waitbar( 0.7, wb, 'Getting clock time');  
if strfind(handles.fname,'raw.kwd')
    % to check Software Time and Processor Time, run h5read('experiment1.kwe','/event_types/Messages/events/user_data/Text')
    if h5readatt(handles.fname,'/recordings/0/','start_time')==0
        Spikes.clockTimes=h5read('experiment1.kwe','/event_types/Messages/events/time_samples');
        Spikes.clockTimes=Spikes.clockTimes(1);
    else
        Spikes.clockTimes=h5readatt(handles.fname,'/recordings/0/','start_time');
    end
elseif strfind(handles.fname,'continuous')
        Spikes.clockTimes=handles.rec_info.clockTimes.ts;
else
        Spikes.clockTimes=0; %Recording and TTL times already sync'ed
end

%% Export
waitbar( 0.9, wb, 'Exporting data');
cd('C:\Data\export');
if strfind(handles.rec_info.expname{end}(2:end),'LY') %regexp(handles.rec_info.expname{end}(2:end),'\_\d\d\d\d\_')
    uname='Leeyup';
else
    uname=getenv('username');
end
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
        handles.rec_info.date=strrep(handles.rec_info.date,'-','_');
        handles.rec_info.date=strrep(handles.rec_info.date,' ','_');
        handles.rec_info.date=strrep(handles.rec_info.date,':','_');
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
    dateItems=regexp(handles.rec_info.date,'\d+','match');
    try
        handles.rec_info.date=[dateItems{1:3} '_' dateItems{4:6}];
    catch
        handles.rec_info.date=[dateItems{1} '_' dateItems{2:end}];
    end
end

handles.rec_info.sys=handles.rec_info.expname{end-1}(2:end);
switch handles.rec_info.sys
    case 'OpenEphys'
        handles.rec_info.sys='OEph';
    case 'TBSI'
        handles.rec_info.sys='TBSI';
    case 'Blackrock'
        handles.rec_info.sys='BR';
end

if get(handles.CB_AddTTLChannel,'value')
    TTL_reSampled = handles.trials.continuous - median(handles.trials.continuous);
    TTL_reSampled = resample(double(TTL_reSampled),30,1);
    TTL_reSampled = TTL_reSampled(1:size(handles.rawData,2));
    handles.rawData=[handles.rawData;TTL_reSampled];
    
    handles.rec_info.expname=[handles.rec_info.expname{end}(2:dateStart) '_'...
        handles.rec_info.date '_' handles.rec_info.sys '_' ...
        num2str(size(handles.rawData,1)) 'Ch_SyncCh_'  handles.preprocOption];
else
    handles.rec_info.expname=[handles.rec_info.expname{end}(2:dateStart) '_'...
        handles.rec_info.date '_' handles.rec_info.sys '_' ...
        num2str(size(handles.rawData,1)) 'Ch_'  handles.preprocOption];
end

if get(handles.RB_ExportRawData,'value')
    fileID = fopen([handles.rec_info.expname '.dat'],'w');
    fwrite(fileID,handles.rawData,'int16');
    % fprintf(fileID,'%d\n',formatdata);
    fclose(fileID);
end

if get(handles.RB_ExportSpikes_OfflineSort,'value')==1 || get(handles.RB_ExportSpikes_OnlineSort,'value')==1
    Trials=handles.trials;
    save(handles.rec_info.expname,'Spikes','Trials'); 
end
close(wb);
disp(['took ' num2str(toc) ' seconds to export data']);

% --- Executes on button press in CB_SpecifyDir.
function CB_SpecifyDir_Callback(hObject, eventdata, handles)
% hObject    handle to CB_SpecifyDir (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of CB_SpecifyDir


% --- Executes on button press in CB_ExportWhichChannel.
function CB_ExportWhichChannel_Callback(hObject, eventdata, handles)
% hObject    handle to CB_ExportWhichChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of CB_ExportWhichChannel


% --- Executes on selection change in LB_ThresholdSide.
function LB_ThresholdSide_Callback(hObject, eventdata, handles)
% hObject    handle to LB_ThresholdSide (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns LB_ThresholdSide contents as cell array
%        contents{get(hObject,'Value')} returns selected item from LB_ThresholdSide


% --- Executes during object creation, after setting all properties.
function LB_ThresholdSide_CreateFcn(hObject, eventdata, handles)
% hObject    handle to LB_ThresholdSide (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
