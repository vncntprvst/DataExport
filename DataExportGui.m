function varargout = DataExportGui(varargin)
% MATLAB code for DataExportGui.fig
% Exports ephys data from Open Ephys / Blackrock / TBSI systems
%     Data can be exported as
%         * continuous data (raw or pre-processed), in .dat and/or .mat format
%         * spike data, from online sorting or offline threshold
%     In addition, parameter and configuration files for offline spike sorting can be generated
%     Can also export excerpt, instead of full data file
%
% When opening, will use most recent folder in user's data directory as root
% Written by Vincent Prevosto, 2016/2017
% Last Modified by GUIDE v2.5 16-Nov-2017 12:21:32

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
function DataExportGui_OpeningFcn(hObject, ~, handles, varargin)
% This function has no output args, see OutputFcn.

% Choose default command line output for DataExportGui
handles.output = hObject;
try
    handles.userinfo=UserDirInfo;
catch
    handles.userinfo=[];
    handles.userinfo.user=getenv('username');
    handles.userinfo.directory=cd;
end

%% define to data folder
if isfield(handles,'dname') && ~isempty(handles.dname)
    dataFolder=handles.dname;
elseif isfield(handles.userinfo,'directory') && ~isempty(handles.userinfo.directory)
    dataFolder=handles.userinfo.directory;
% elseif ~isempty(handles.userinfo) %% get most recently changed data folder
%     dataDir=handles.userinfo.directory;
%     dataDirListing=dir(dataDir);
%     %removing dots
%     dataDirListing=dataDirListing(cellfun('isempty',cellfun(@(x) strfind(x,'.'),...
%         {dataDirListing.name},'UniformOutput',false)));
%     %removing other folders
% %     dataDirListing=dataDirListing(cellfun('isempty',cellfun(@(x)...
% %         regexp('Behav | DB | ImpedanceChecks | Video | export | example-klusters_neuroscope',x),...
% %         {dataDirListing.name},'UniformOutput',false)));
%     [~,fDateIdx]=sort([dataDirListing.datenum],'descend');
%     recentDataFolder=[dataDir filesep dataDirListing(fDateIdx(1)).name filesep];
%     %get most recent data folder in that folder if there is one
%     dataDirListing=dir(recentDataFolder);
%     %removing dots
%     dataDirListing=dataDirListing(cellfun('isempty',cellfun(@(x) strfind(x,'.'),...
%         {dataDirListing.name},'UniformOutput',false)));
%     if size(dataDirListing,1)>0
%         [~,fDateIdx]=sort([dataDirListing.datenum],'descend');
%         %     recentDataFolder=[recentDataFolder filesep dataDirListing(fDateIdx(1)).name filesep];
%         dataFolder=[recentDataFolder dataDirListing(fDateIdx(1)).name filesep];
%     end
else
    dataFolder=cd;
end

%% Get file path
[handles.fname,handles.dname] = uigetfile({'*.continuous;*.kwik;*.kwd;*.kwx;*.nex;*.ns*','All Data Formats';...
    '*.*','All Files' },'Select data file to export',dataFolder);
if handles.fname==0
    handles.fname='';
    handles.dname=dataFolder;
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
    
    %% Load data
    [handles.rec_info,handles.rawData,handles.trials]=LoadEphysData(handles.fname,handles.dname);
    
    %% parallel loading
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
    %         [handles.rec_info,handles.rawData,handles.trials]=LoadEphysData(handles.fname,handles.dname);
    %     end
    % end
    
    set(handles.FileName,'string',[handles.dname handles.fname])
    % disp(['loading ' dname fname]);

    handles.keepChannels=(1:size(handles.rawData,1))';
    
    %% Plot raw data excerpt
    dataOneSecSample=handles.rawData(:,round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate:round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate);
    axes(handles.Axes_traces); hold on;
    cla(handles.Axes_traces);
    set(handles.Axes_traces,'Visible','on');
    BaseShift=int32(max(abs(max(dataOneSecSample))));
    %     subplot(1,2,1);
    for ChN=1:size(handles.rawData,1)
        ShiftUp=(BaseShift*ChN)-...
            int32(median(median(dataOneSecSample(ChN,:))));
        plot(handles.Axes_traces,int32(dataOneSecSample(ChN,:))+...
            ShiftUp);
    end
    set(handles.Axes_traces,'xtick',linspace(0,handles.rec_info.samplingRate*2,4),...
        'xticklabel',round(linspace(round((round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate)/handles.rec_info.samplingRate),...
        round((round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate)/handles.rec_info.samplingRate),4)),'TickDir','out');
    set(handles.Axes_traces,'ytick',linspace(single(BaseShift),single(ShiftUp+...
        int32(median(median(dataOneSecSample(ChN,:))))),...
        single(size(dataOneSecSample,1))),'yticklabel',...
        cellfun(axis_name, num2cell(1:size(dataOneSecSample,1)), 'UniformOutput', false))
    %   set(gca,'ylim',[-1000,10000],'xlim',[0,1800000])
    axis('tight');box off;
    set(handles.Axes_traces,'ylim',[-1000,BaseShift...
        *int32(size(handles.keepChannels,1))+BaseShift]);
    xlabel(handles.Axes_traces,'2 sec mid-recording')
    ylabel(handles.Axes_traces,'Raw signal')
    set(handles.Axes_traces,'Color','white','FontSize',12,'FontName','calibri');
    
    %% Plot pre-processed excerpt
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
        case 'LFP Lowpass'
            preprocOption={'LFP'};
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

%% Remap channels
function PB_remap_Callback(hObject, eventdata, handles)
if isfield(handles,'remapped') && handles.remapped==true
    disp('Channels already remapped');
    return;
end

% find probe mappings directory
if ~isfield(handles.userinfo,'probemap')
    if ~exist('probemaps', 'dir')
        probemapDir = uigetdir(cd,'select location to store probe mappings');
        handles.userinfo.probemap=[probemapDir filesep 'probemaps'];
        mkdir(handles.userinfo.probemap);
        path(handles.userinfo.probemap,path)
    else
        allPathDirs=strsplit(path,pathsep);
        handles.userinfo.probemap=allPathDirs{find(cellfun(@(pathdir) contains(pathdir,'probemaps'),allPathDirs),1)};
    end
end
% cd(handles.userinfo.probemap);

% setting subject name, expecting Letter/Digit combination (e.g. PrV50)
subjectName=regexp(strrep(handles.fname,'_','-'),'^\w+\d+(\w)?','match');
if isempty(subjectName) || contains(subjectName,'experiment') % regexp(subjectName,'^experiment','match')
    subjectName=regexp(strrep(handles.dname,'_','-'),['(?<=\' filesep ')\w+\d+\w(?=\W)'],'match');
end
if size(subjectName,2)>1 %loading from dedicated subject directory
    subjectName=subjectName(1);
end
if isempty(subjectName)
    subjectName=handles.fname;
end

subjectName=subjectName{:};

%% load or create channel mapping
if exist([handles.userinfo.probemap filesep 'ImplantList.mat'],'file') %the implant list contains
    %                                                                    a structure with .Probe and .Mouse fields
    %                                                                    that associates each mouse to its implant number
    %                                                                    (and thus the probe map)
    load([handles.userinfo.probemap filesep 'ImplantList.mat']);
else
    implantList=struct('Mouse',[],'Probe',[]);
end

% find Probe ID
try
    probeID=implantList(contains(strrep({implantList.Mouse},'-',''),subjectName,'IgnoreCase',true)).Probe;
    makeProbeFile=0;
catch
    probeID=['default_' num2str(handles.rec_info.numRecChan) 'Channels'];
    makeProbeFile=1;
end

remapdlg=inputdlg({'Subject Name','Probe map'},'Enter Subject and Probe identifiers',...
    1,{subjectName,probeID});

subjectName=remapdlg(1);
probeID=remapdlg{2};

if makeProbeFile
    implantList(size(implantList.Mouse,1)+1).Mouse=subjectName;
    implantList(size(implantList.Mouse,1)).Probe=probeID;
    cd([handles.userinfo.probemap filesep])
    save('ImplantList.mat','implantList');
    %make probe map file
    eval([probeID '=struct(''Shank'',[],'...
        '''Electrode'',[],'...
        '''IntanHS'',[],'...
        '''OEChannel'',[],'...
        '''BlackrockChannel'',[],'...
        '''Label'',[])'])
    for chNum=1:handles.rec_info.numRecChan
        eval([probeID '(chNum).Shank = chNum']);
        eval([probeID '(chNum).Electrode = chNum']);
        eval([probeID '(chNum).IntanHS = chNum']);
        eval([probeID '(chNum).OEChannel = chNum+1']);
        eval([probeID '(chNum).BlackrockChannel = chNum']);
    end
    handles.rec_info.probeLayout=probeID;
    eval(['save(''' probeID '.mat'',''probeID'')']);
    %     makeProbeFile=0;
end

load([handles.userinfo.probemap filesep probeID '.mat']);
wsVars=who;
handles.rec_info.probeLayout=eval(wsVars{contains(wsVars,'Probe')});
handles.rec_info.subjectName=subjectName;
handles.rec_info.probeID=probeID;

%remove un-labeled and EMG channels
if isfield(handles.rec_info.probeLayout,'Label')
    labeledChans=~cellfun(@(chLabel)contains(chLabel,'chan') |...
        contains(chLabel,'EMG'), {handles.rec_info.probeLayout.Label});
    handles.rec_info.probeLayout=handles.rec_info.probeLayout(labeledChans);
    handles.rawData=handles.rawData(labeledChans,:);
end
%map channels to electrodes
if ~isfield(handles.rec_info,'sys')  
    handles.rec_info.sys=handles.rec_info.dirBranch{cellfun(@(folders) ...
        contains(folders,'OpenEphys') || contains(folders,'Blackrock') ,handles.rec_info.dirBranch)};
    handles.rec_info.sys=regexprep(handles.rec_info.sys,'\W','');
end
switch handles.rec_info.sys
    case 'OpenEphys'
        channelMap=[handles.rec_info.probeLayout.OEChannel];
%         In case shank and electrodes order are scrambled:
%         electrodeMap=[handles.rec_info.probeLayout.Electrode]; [~,electrodeOrder]=sort(electrodeMap);
%         handles.rec_info.probeLayout=handles.rec_info.probeLayout(electrodeOrder,:); 
        channelMap=channelMap(channelMap>0); %remove duplicates
        [~,chMap]=sort(channelMap);[~,chMap]=sort(chMap);
        try
            handles.rawData=handles.rawData(chMap,:);
        catch
            goodChId=[handles.rec_info.probeLayout.Shank]~=0;
            allCh=[handles.rec_info.probeLayout.OEChannel];
            goodCh=allCh(goodChId);
            chMap=chMap(ismember(chMap,goodCh));
            try
                handles.rawData=handles.rawData(chMap,:);
            catch
                [~,chMap]=sort(chMap);[~,chMap]=sort(chMap);
                handles.rawData=handles.rawData(chMap,:);
            end
        end
        %remove floating channels
        floatCh=[handles.rec_info.probeLayout([handles.rec_info.probeLayout.Shank]==0).OEChannel];
        if ~isempty(floatCh)
            floatChIdx=ismember(channelMap,floatCh); floatChIdx(chMap);
            handles.rawData=handles.rawData(~floatChIdx,:);
            handles.rec_info.numRecChan=sum(~floatChIdx);
        end
    case 'Blackrock'
        % check if already mapped
        if sum(diff(handles.rec_info.chanID)>0)==numel(handles.rec_info.chanID)-1
            channelMap=[handles.rec_info.probeLayout.BlackrockChannel];  
            if isfield(handles.rec_info,'chanID')
                [~,chMap]=sort(channelMap(ismember(channelMap,handles.rec_info.chanID)));
                [~,chMap]=sort(chMap);
                try
                    handles.rawData=handles.rawData(chMap,:);
                catch
                end
            else
                channelMap=channelMap(channelMap>0); %remove duplicates
                [~,chMap]=sort(channelMap);[~,chMap]=sort(chMap);
                try
                    handles.rawData=handles.rawData(chMap,:);
                catch
                    goodChId=[handles.rec_info.probeLayout.Shank]~=0;
                    allCh=[handles.rec_info.probeLayout.BlackrockChannel];
                    goodCh=allCh(goodChId);
                    chMap=chMap(ismember(chMap,goodCh));
                    try
                        handles.rawData=handles.rawData(chMap,:);
                    catch
                        [~,chMap]=sort(chMap);[~,chMap]=sort(chMap);
                        handles.rawData=handles.rawData(chMap,:);
                    end
                end
                %remove floating channels
                floatCh=[handles.rec_info.probeLayout([handles.rec_info.probeLayout.Shank]==0).BlackrockChannel];
                if ~isempty(floatCh)
                    floatChIdx=ismember(channelMap,floatCh); floatChIdx(chMap);
                    handles.rawData=handles.rawData(~floatChIdx,:);
                    handles.rec_info.numRecChan=sum(~floatChIdx);
                end
            end
        end
    otherwise
        %stay as it is
        disp('no channel mapping available')
end

handles.keepChannels=(1:size(handles.rawData,1))';
handles.remapped=true;

LB_ProcessingType_Callback(handles.LB_ProcessingType, eventdata, handles);

%%  Update handles structure
guidata(hObject, handles);

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
    case 'LFP Lowpass'
        preprocOption={'LFP'};
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

%% --- Executes on button press in RB_ExportSpikes_OfflineSort.
function RB_ExportSpikes_OfflineSort_Callback(hObject, eventdata, handles)

%% --- Executes on button press in RB_ExportRaw_dat.
function RB_ExportRaw_dat_Callback(hObject, eventdata, handles)

set(handles.CB_CreateSCParamsFile,'value',get(handles.RB_ExportRaw_dat,'value'));

%% --- Executes on button press in CB_AddTTLChannel.
function CB_AddTTLChannel_Callback(hObject, eventdata, handles)
 
% --- Executes on button press in CB_ExportTTL.
function CB_ExportTTL_Callback(hObject, eventdata, handles)

%% --- Executes on button press in CB_SpecifyDir.
function CB_SpecifyDir_Callback(hObject, eventdata, handles)

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

%% --- Executes during object creation, after setting all properties.
function LB_ThresholdSide_CreateFcn(hObject, eventdata, handles)

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%% --- Executes on button press in CB_SpecifyName.
function CB_SpecifyName_Callback(hObject, eventdata, handles)

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

function TxEdit_SampleDuration_Callback(hObject, eventdata, handles)

%% --- Executes during object creation, after setting all properties.
function TxEdit_SampleDuration_CreateFcn(hObject, eventdata, handles)

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%% --- Executes on button press in PB_ExportAll.
function PB_ExportAll_Callback(hObject, eventdata, handles)

handles.batchExport=1;
%export raw data first
set(handles.LB_ProcessingType,'value',1);
set(handles.RB_ExportRaw_dat,'value',1);
set(handles.RB_ExportRaw_mat,'value',0);
set(handles.RB_ExportRaw_NEV,'value',0);
set(handles.CB_CreateSCParamsFile,'value',1);
set(handles.RB_ExportSpikes_OnlineSort,'value',0);
set(handles.RB_ExportSpikes_OfflineSort,'value',0);
set(handles.CB_SpecifyName,'value',0);
set(handles.CB_SpecifyDir,'value',1);
ExportData(hObject, eventdata, handles);

% then HP filtered data
set(handles.LB_ProcessingType,'value',2);
set(handles.RB_ExportRaw_dat,'value',0);
set(handles.RB_ExportRaw_mat,'value',1);
set(handles.RB_ExportRaw_NEV,'value',0);
set(handles.CB_CreateSCParamsFile,'value',0);
set(handles.RB_ExportSpikes_OnlineSort,'value',1);
set(handles.RB_ExportSpikes_OfflineSort,'value',1);
set(handles.CB_SpecifyName,'value',0);
set(handles.CB_SpecifyDir,'value',1);
ExportData(hObject, eventdata, handles);

% then LFP
set(handles.LB_ProcessingType,'value',5);
set(handles.RB_ExportRaw_dat,'value',0);
set(handles.RB_ExportRaw_mat,'value',1);
set(handles.RB_ExportRaw_NEV,'value',0);
set(handles.CB_CreateSCParamsFile,'value',0);
set(handles.RB_ExportSpikes_OnlineSort,'value',0);
set(handles.RB_ExportSpikes_OfflineSort,'value',0);
set(handles.CB_SpecifyName,'value',0);
set(handles.CB_SpecifyDir,'value',1);
ExportData(hObject, eventdata, handles);

%% --- Executes on button press in RB_ExportOnlySample.
function RB_ExportOnlySample_Callback(hObject, eventdata, handles)

%% --- Executes on button press in RB_ExportRaw_mat.
function RB_ExportRaw_mat_Callback(hObject, eventdata, handles)

%% --- Executes on button press in RB_ExportWithNoSignalCutout.
function RB_ExportWithNoSignalCutout_Callback(hObject, eventdata, handles)

%% --- Executes on button press in CB_CreateSCParamsFile.
function CB_CreateSCParamsFile_Callback(hObject, eventdata, handles)

% --- Executes on button press in CB_KSChannelMap.
function CB_KSChannelMap_Callback(hObject, eventdata, handles)

% --- Executes on button press in CB_KSConfigurationFile.
function CB_KSConfigurationFile_Callback(hObject, eventdata, handles)

% --- Executes on button press in CB_JRClustProbeFile.
function CB_JRClustProbeFile_Callback(hObject, eventdata, handles)

% --- Executes on button press in RB_ExportRaw_NEV.
function RB_ExportRaw_NEV_Callback(hObject, eventdata, handles)
if get(handles.RB_ExportRaw_NEV,'value')
    set(handles.RB_ExportSpikes_OnlineSort,'value',0);
    set(handles.RB_ExportSpikes_OfflineSort,'value',0);
    set(handles.RB_ExportRaw_dat,'value',0);
    set(handles.RB_ExportRaw_mat,'value',0);
    set(handles.CB_CreateSCParamsFile,'value',0);
end

%% --- Executes on selection change in LB_ExportSampleLocation.
function LB_ExportSampleLocation_Callback(hObject, eventdata, handles)

%% --- Executes during object creation, after setting all properties.
function LB_ExportSampleLocation_CreateFcn(hObject, eventdata, handles)

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in PB_exit.
function PB_exit_Callback(hObject, eventdata, handles)
close(handles.DataExportFigure);
clearvars;

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
    try
        handles.spikeFile=handles.spikeFile{bestFit};
    catch
        handles.spikeFile=handles.spikeFile{1};
    end
else
    if ~isempty(handles.spikeFile)
        handles.spikeFile=handles.spikeFile{:};
    end
end

hfields = fieldnames(handles);
hdata = struct2cell(handles);
hkeep = logical(cell2mat(cellfun(@(x) sum(~cellfun('isempty',...
    strfind({'fname';'dname';'rec_info';'Trials';'exportDir';'spikeFile'},x))),...
    hfields,'UniformOutput', false)));
htransfer = cell2struct(hdata(hkeep), hfields(hkeep));

SpikeVisualizationGUI(htransfer);

% --- Executes on button press in PB_spike_sorting.
function PB_spike_sorting_Callback(hObject, eventdata, handles)
if isfield(handles,'exportType') && contains(handles.exportType,'SC')
    if isfield(handles.userinfo,'circusEnv')
        activation=['activate ' handles.userinfo.circusEnv ' & '];
    else
        activation='';
    end
    try
        if contains(getenv('OS'),'Windows')
            system([activation 'runas /user:' getenv('computername') '\' getenv('username') ...
                ' spyking-circus-launcher & exit &']);
        else
            system([activation 'sudo �u ' getenv('username') ...
                ' spyking-circus-launcher & exit &']); %UNTESTED !
        end
    catch
        system('spyking-circus-launcher & exit &'); %  will only be able to edit params, not run spike sorting
    end
elseif isfield(handles,'exportType') && contains(handles.exportType,'ML')
elseif isfield(handles,'exportType') && contains(handles.exportType,'KS')
    %make "master" file and run it
elseif isfield(handles,'exportType') && contains(handles.exportType,'JR')
    % find parameter file
    dirListing=dir(cd);
    parameterFileName=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'.prm'),...
        {dirListing.name},'UniformOutput',false))).name;
    jrc('spikesort',parameterFileName);
else
    %need user input dialog
end

% --- Executes on mouse press over axes background.
function Axes_PreProcessedData_ButtonDownFcn(hObject, eventdata, handles)
if contains (get(gcf,'SelectionType'),'alt')
    figure; hold on
    axis_name= @(x) sprintf('Chan %.0f',x);
    preprocOption={'CAR','all'};
    dataOneSecSample=handles.rawData(handles.keepChannels,round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate:round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate);
    [dataOneSecSample_preproc,handles.channelSelection]=PreProcData(dataOneSecSample,handles.rec_info.samplingRate,preprocOption);
    
    BaseShift=int32(max(abs(max(dataOneSecSample_preproc))));
    set(gca,'ylim',[-1000,BaseShift...
        *int32(size(handles.keepChannels,1))+BaseShift])
    
    for ChN=1:size(handles.keepChannels,1)
        ShiftUp=(BaseShift*ChN)-...
            int32(median(median(dataOneSecSample_preproc(ChN,:))));
        plot(gca,int32(dataOneSecSample_preproc(ChN,:))+...
            ShiftUp);
    end
    try
        set(gca,'ytick',linspace(single(BaseShift),single(ShiftUp+...
            int32(median(median(dataOneSecSample_preproc(ChN,:))))),...
            single(size(dataOneSecSample_preproc,1))),'yticklabel',...
            cellfun(axis_name, num2cell(1:size(dataOneSecSample_preproc,1)), 'UniformOutput', false))
    catch
        set(gca,'ytick',linspace(0,double(int16(ChN-1)),(size(dataOneSecSample_preproc,1))),'yticklabel',...
            cellfun(axis_name, num2cell(1:size(dataOneSecSample_preproc,1)), 'UniformOutput', false))
    end
    xlabel(gca,['Processing option: ' preprocOption{1}])
    box off; axis tight
end

% --- Executes on button press in PB_SpikesExport.
function PB_SpikesExport_Callback(hObject, eventdata, handles)

% set(handles.LB_ProcessingType,'value',2); Doesn't matter
set(handles.RB_ExportRaw_dat,'value',0);
set(handles.RB_ExportRaw_mat,'value',0);
set(handles.RB_ExportRaw_NEV,'value',0);
set(handles.CB_CreateSCParamsFile,'value',0);
set(handles.CB_KSChannelMap,'value',0);
set(handles.CB_KSConfigurationFile,'value',0);  
set(handles.CB_JRClustProbeFile,'value',0);
set(handles.RB_ExportSpikes_OnlineSort,'value',1);
set(handles.RB_ExportSpikes_OfflineSort,'value',0);
set(handles.CB_SpecifyName,'value',0);
set(handles.CB_SpecifyDir,'value',1);
handles.exportType='OnlineSort';
ExportData(hObject, eventdata, handles);
guidata(hObject, handles);

% --- Executes on button press in PB_ExcerptExport.
function PB_ExcerptExport_Callback(hObject, eventdata, handles)

% --- Executes on button press in PB_SCExport.
function PB_SCExport_Callback(hObject, eventdata, handles)

set(handles.LB_ProcessingType,'value',1);
set(handles.RB_ExportRaw_dat,'value',1);
set(handles.RB_ExportRaw_mat,'value',0);
set(handles.RB_ExportRaw_NEV,'value',0);
set(handles.CB_CreateSCParamsFile,'value',1);
set(handles.CB_KSChannelMap,'value',0);
set(handles.CB_KSConfigurationFile,'value',0);  
set(handles.CB_JRClustProbeFile,'value',0);
set(handles.RB_ExportSpikes_OnlineSort,'value',0);
set(handles.RB_ExportSpikes_OfflineSort,'value',0);
set(handles.CB_SpecifyName,'value',0);
set(handles.CB_SpecifyDir,'value',1);
handles.exportType='SC';
ExportData(hObject, eventdata, handles);
guidata(hObject, handles);

% --- Executes on button press in PB_MatlabExport.
function PB_MatlabExport_Callback(hObject, eventdata, handles)

% set(handles.LB_ProcessingType,'value',2); Use whichever is selected
set(handles.RB_ExportRaw_dat,'value',0);
set(handles.RB_ExportRaw_mat,'value',1);
set(handles.RB_ExportRaw_NEV,'value',0);
set(handles.CB_CreateSCParamsFile,'value',0);
set(handles.CB_KSChannelMap,'value',0);
set(handles.CB_KSConfigurationFile,'value',0);  
set(handles.CB_JRClustProbeFile,'value',0);
set(handles.RB_ExportSpikes_OnlineSort,'value',0);
set(handles.RB_ExportSpikes_OfflineSort,'value',0);
set(handles.CB_SpecifyName,'value',0);
set(handles.CB_SpecifyDir,'value',1);
handles.exportType='ML';
ExportData(hObject, eventdata, handles);
guidata(hObject, handles);

% --- Executes on button press in PB_KiloSortExport.
function PB_KiloSortExport_Callback(hObject, eventdata, handles)

set(handles.LB_ProcessingType,'value',1);
set(handles.RB_ExportRaw_dat,'value',1);
set(handles.RB_ExportRaw_mat,'value',0);
set(handles.RB_ExportRaw_NEV,'value',0);
set(handles.CB_CreateSCParamsFile,'value',0);
set(handles.CB_KSChannelMap,'value',1);
set(handles.CB_KSConfigurationFile,'value',1);
set(handles.CB_JRClustProbeFile,'value',0);
set(handles.RB_ExportSpikes_OnlineSort,'value',0);
set(handles.RB_ExportSpikes_OfflineSort,'value',0);
set(handles.CB_SpecifyName,'value',0);
set(handles.CB_SpecifyDir,'value',1);
handles.exportType='KS';
ExportData(hObject, eventdata, handles);
guidata(hObject, handles);

% --- Executes on button press in PB_JRClustExport.
function PB_JRClustExport_Callback(hObject, eventdata, handles)
set(handles.LB_ProcessingType,'value',1);
set(handles.RB_ExportRaw_dat,'value',1);
set(handles.RB_ExportRaw_mat,'value',0);
set(handles.RB_ExportRaw_NEV,'value',0);
set(handles.CB_CreateSCParamsFile,'value',0);
set(handles.CB_KSChannelMap,'value',0);
set(handles.CB_KSConfigurationFile,'value',0);
set(handles.CB_JRClustProbeFile,'value',1);
set(handles.RB_ExportSpikes_OnlineSort,'value',0);
set(handles.RB_ExportSpikes_OfflineSort,'value',0);
set(handles.CB_SpecifyName,'value',0);
set(handles.CB_SpecifyDir,'value',1);
handles.exportType='JR';
ExportData(hObject, eventdata, handles);
guidata(hObject, handles);

%% --- Export data function
function ExportData(hObject, eventdata, handles)
if ~isfield(handles,'batchExport')
    handles.batchExport=0;
end
tic;
wb = waitbar( 0, 'Exporting Data' );
set(wb,'Name','Exporting','Color',[0 0.4471 0.7412]);

cd(handles.dname); %in case some other file was exported before

if get(handles.CB_ExportWhichChannel,'value')==0
    try
    handles.rawData=handles.rawData(handles.keepChannels,:);
    catch
        %keep as it is
    end
end
handles.rec_info.exportedChan=handles.keepChannels;
guidata(hObject, handles);
% export only excerpt
if get(handles.RB_ExportOnlySample,'value')==1
    if get(handles.LB_ExportSampleLocation,'value')==1
        handles.rawData=handles.rawData(:,1:handles.rec_info.samplingRate*60*str2double(get(handles.TxEdit_SampleDuration,'String')));
    elseif get(handles.LB_ExportSampleLocation,'value')==2
        handles.rawData=handles.rawData(:,...
            round(size(handles.rawData,2)/2)-handles.rec_info.samplingRate*30*str2double(get(handles.TxEdit_SampleDuration,'String')):...
            round(size(handles.rawData,2)/2)+handles.rec_info.samplingRate*30*str2double(get(handles.TxEdit_SampleDuration,'String')));
    elseif get(handles.LB_ExportSampleLocation,'value')==3
        handles.rawData=handles.rawData(:,end-handles.rec_info.samplingRate*60*str2double(get(handles.TxEdit_SampleDuration,'String')):end);
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
    case 'LFP Lowpass'
        preprocOption={'LFP'};
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
if get(handles.RB_ExportRaw_dat,'value') || ...
        get(handles.RB_ExportRaw_mat,'value') || get(handles.RB_ExportRaw_NEV,'value')
    waitbar( 0.1, wb, ['Pre-processing Data: ' handles.preprocOption]);
    handles.rawData=PreProcData(handles.rawData,handles.rec_info.samplingRate,preprocOption);
    
    if ~isa(handles.rawData,'int16')
        handles.rawData=int16(handles.rawData);
    end
end

if get(handles.RB_ExportSpikes_OnlineSort,'value')==1
    %% Online sorted spikes
    % find file format from directory listing
    dirlisting = dir(handles.dname);
    dirlisting = {dirlisting(:).name};
    dirlisting=dirlisting(cellfun('isempty',cellfun(@(x) strfind('.',x(end)),dirlisting,'UniformOutput',false)));
    fileformats={'continuous','kwe','kwik','nex','ns6'};
    whichformat=cellfun(@(x) find(~cellfun('isempty',strfind(fileformats,x(end-2:end)))),dirlisting,'UniformOutput',false);
    whichformat=fileformats(unique([whichformat{~cellfun('isempty',whichformat)}]));
    waitbar( 0.5, wb, 'Getting spikes from online sorting');
    switch whichformat{:}
        case 'continuous'
        case {'kwe','kwik'}
            % KWX contains the spike data
            % h5disp('experiment1.kwx')
            ChanInfo=h5info('experiment1.kwx');
            
            %KWD contains the continuous data for a given processor in the /recordings/#/data dataset, where # is the recording number, starting at 0
            RawInfo=h5info('experiment1_100.raw.kwd');
            if size(RawInfo.Groups.Groups,1)>1
                recToExport = inputdlg('Multiple recordings. Which one do you want to load?',...
                    'Recording', 1);
                recToExport = str2num(recToExport{:});
            else
                recToExport = 1;
            end
            RawInfo=h5info('experiment1_100.raw.kwd',['/recordings/' num2str(recToExport-1) '/data']);
            RecDur=RawInfo.Dataspace.Size;
            
            %Keep info on ADC resolution
            %             Spikes.Online_Sorting.Resolution=
            
            %Keep list of channels with > 1Hz firing rate
            %             GoodChans=cell(size(ChanInfo.Groups.Groups,1),1);
            for ChExN=1:size(ChanInfo.Groups.Groups,1)
                if ChanInfo.Groups.Groups(ChExN).Datasets(2).Dataspace.Size/...
                        (RecDur(2)/handles.rec_info.samplingRate)>1
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
            if sum([SpikeData.ElectrodesInfo([handles.rec_info.probeLayout.BlackrockChannel]).ElectrodeID]-...
                    uint16([SpikeData.ElectrodesInfo([handles.rec_info.probeLayout.BlackrockChannel]).ConnectorPin]))==0
                % recording wasn't mapped
                GoodChans=[handles.rec_info.probeLayout.BlackrockChannel];
            else
                GoodChans=[handles.rec_info.probeLayout.Electrode];
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
        %         figure; hold on;
        %         midRec=round(size(handles.rawData(Spikes.Offline_Threshold.electrode(ChExN),:),2)/2);
        %         plotWin=5*Spikes.Offline_Threshold.samplingRate;
        %         plot(handles.rawData(Spikes.Offline_Threshold.electrode(ChExN),midRec-plotWin:midRec+plotWin));
        %         % plot(handles.rawData(Spikes.Offline_Threshold.electrode,:)+1500);
        %         % thd10=rms((handles.rawData(10,:)));
        %         thld=rms(handles.rawData(Spikes.Offline_Threshold.electrode(ChExN),:));
        %         plot(-5*thld*ones(1,size(midRec-plotWin:midRec+plotWin,2)));
        %         plot(-40*thld*ones(1,size(midRec-plotWin:midRec+plotWin,2)));
        %         % plot(1500-4*thd*ones(1,size(handles.rawData,2)));
        %         % foo=handles.rawData(Spikes.Offline_Threshold.electrode(ChExN),:)>(-40*thld);
        
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
if ~isfield(handles.trials,'startClockTime') | isempty(handles.trials.startClockTime)
    waitbar( 0.7, wb, 'Getting clock time');
    if strfind(handles.fname,'raw.kwd')
        % to check Software Time and Processor Time, run h5read('experiment1.kwe','/event_types/Messages/events/user_data/Text')
        % don't use
        % h5readatt(handles.fname,'/recordings/0/','start_time').That
        % start_time happens earlier (like 20ms before). The difference is
        % due to the time it takes to open files
        handles.trials.startClockTime=h5read('experiment1.kwe','/event_types/Messages/events/time_samples');
        handles.trials.startClockTime=handles.trials.startClockTime(1);
        
    elseif strfind(handles.fname,'continuous')
        handles.trials.startClockTime=handles.rec_info.startClockTime.ts;
    else
        handles.trials.startClockTime=0; %Recording and TTL times already sync'ed
    end
end

%% Export
% userinfo=UserDirInfo;
waitbar( 0.9, wb, 'Exporting data');

%% define export name
if contains(handles.fname,'experiment') % OpenEphys kwik format
    customFileName=regexp(strrep(handles.dname,'_','-'),['(?<=\' filesep ')\S+?(?=\' filesep ')'],'match');
    customFileName=customFileName(end);
else
    customFileName=regexp(handles.fname,'.+(?=\..+$)','match');
end
if get(handles.CB_SpecifyName,'value')==0
    if handles.batchExport==0
        handles.rec_info.exportname=inputdlg('Enter export file name','File Name',1,customFileName);
        handles.rec_info.exportname=handles.rec_info.exportname{:};
    else
        handles.rec_info.exportname=customFileName{:};
    end
else
    handles.rec_info.exportname=customFileName{:};
end

if size(handles.rec_info.exportname,2)>50
    handles.rec_info.exportname=inputdlg('Reduce file name''s length','File Name',1,{handles.rec_info.exportname(1:50)});
    handles.rec_info.exportname=handles.rec_info.exportname{:};
end

%% create export folder (if needed), go there and save info
exportDir=fullfile(cd,[handles.rec_info.exportname '_' handles.exportType]);
if get(handles.CB_SpecifyDir,'value')==0
    try
        exportDir=regexprep(handles.userinfo.directory,['\' filesep '\w+$'],['\' filesep 'export']);
    catch
        exportDir=cd;
    end
    exportDir=uigetdir(exportDir,'Select export directory');

else
    if ~exist(exportDir,'dir')
        mkdir(exportDir);
    end
%     if ~isdir(handles.rec_info.exportname)
%         mkdir(handles.rec_info.exportname); %create dir name without preprocOption
%     end
%     cd(handles.rec_info.exportname);
end
cd(exportDir)
set(handles.PB_SpikePanel,'UserData',cd);

%% [optional] adding a TTL Channel to exported data
if get(handles.CB_AddTTLChannel,'value')
    if isfield(handles.trials,'continuous')
        TTL_reSampled = handles.trials.continuous - median(handles.trials.continuous);
        TTL_reSampled = resample(double(TTL_reSampled),30,1);
        TTL_reSampled = TTL_reSampled(1:size(handles.rawData,2));
        handles.rawData=[handles.rawData;TTL_reSampled];
    else %need to create one
    end
    %     if isdatetime(handles.rec_info.date)
    %         handles.rec_info.date=datestr(handles.rec_info.date,'yyyy-mm-dd');
    %     end
    handles.rec_info.exportname=[handles.rec_info.exportname '_WithTTL_' handles.preprocOption];
else
    handles.rec_info.exportname=[handles.rec_info.exportname '_' handles.preprocOption];
end

%% saving info about file and export
save([handles.rec_info.exportname '_info'],'-struct','handles','rec_info','-v7.3');
fileID = fopen([handles.rec_info.exportname '.txt'],'w');
if ischar(handles.rec_info.date)
    if ~isempty(regexp(handles.dname,'(?<=\d+_\d+_).+(?=\\)','match'))
        handles.rec_info.date=regexp(handles.dname,'(?<=\d+_\d+_).+(?=\\)','match');
        handles.rec_info.date=handles.rec_info.date{:};
    end
    fprintf(fileID,['%21s\t %' num2str(length(handles.rec_info.date)) 's\r'],...
        'recording date       ',handles.rec_info.date);
else
    fprintf(fileID,['%21s\t %' num2str(length(datestr(handles.rec_info.date))) 's\r'],...
        'recording date       ',datestr(handles.rec_info.date));
end
fprintf(fileID,'%21s\t\t\t %12u\r','sampling rate        ',handles.rec_info.samplingRate);
fprintf(fileID,'%21s\t\t\t %12u\r','duration (rec. clock)',handles.rec_info.dur);
fprintf(fileID,'%21s\t\t\t %12.4f\r','duration (s.)        ',handles.rec_info.dur/handles.rec_info.samplingRate);
fprintf(fileID,'%21s\t\t\t %12u\r','number of rec. chans ',length(handles.rec_info.exportedChan));
fprintf(fileID,['%21s\t\t %' num2str(length(num2str(handles.keepChannels'))) 's\r'],...
    'exported channels    ',num2str(handles.keepChannels'));
fclose(fileID);
%     dataExcerpt=PreProcData(foo,30000,{'CAR','all'}); figure;plot(dataExcerpt(15,:))

%% [optional] export a flat dat file
if get(handles.RB_ExportRaw_dat,'value')
    if isfield(handles.rec_info,'partialRead') && handles.rec_info.partialRead && ...
            ~get(handles.RB_ExportOnlySample,'value')==1
        exportBigFile([handles.dname handles.fname],...
            [handles.rec_info.exportname '.dat'],handles.rec_info.probeLayout,handles.keepChannels);
    else
        fileID = fopen([handles.rec_info.exportname '.dat'],'w');
        fwrite(fileID,handles.rawData,'int16');
        % fprintf(fileID,'%d\n',formatdata);
        fclose(fileID);
    end
end

%% [optional] export data into a .mat file
if get(handles.RB_ExportRaw_mat,'value')
    save([handles.rec_info.exportname '_traces'],'-struct','handles','rawData','-v7.3');
end

%% [optional] save Blackrock NEV file
% cd(handles.dname)
if get(handles.RB_ExportRaw_NEV,'value')
    data = openNSxNew([handles.dname handles.fname]);
    data.Data=flipud(handles.rawData);
    saveNSx(data,[handles.rec_info.exportname '_CAR' handles.fname(end-3:end)])
end

%% [optional] export spikes
if get(handles.RB_ExportSpikes_OfflineSort,'value')==1 || get(handles.RB_ExportSpikes_OnlineSort,'value')==1
    save([handles.rec_info.exportname '_spikes'],'Spikes','-v7.3');
    save([handles.rec_info.exportname '_trials'],'-struct','handles','trials','-v7.3');
end

%% [optional] create .params file for Spyking Circus
if get(handles.CB_CreateSCParamsFile,'value')==1
    if ~isfield(handles.rec_info,'probeID')
        handles.rec_info.probeID ='';
    end
    userParams={'raw_binary';num2str(handles.rec_info.samplingRate);'int16';...
        num2str(length(handles.rec_info.exportedChan));handles.rec_info.probeID;'2';'8';'both';'True';'10000';...
        '0.002';'True';'0.98';'2, 5';'0.8';'True';'True'};
    if handles.batchExport==0
        [status,cmdout]=RunSpykingCircus(cd,handles.rec_info.exportname,{'paramsfile';userParams});
    else
        [status,cmdout]=RunSpykingCircus(cd,handles.rec_info.exportname,{'paramsfile_noInputdlg';userParams});
    end
    if status~=1
        disp('problem generating the parameter file')
    else
        disp(cmdout)
    end
end

%% [optional] create configuration file for KiloSort
if get(handles.CB_KSConfigurationFile,'value')==1
    useGPU=1;
    userParams.useGPU=num2str(useGPU);
    
    [status,cmdout]=GenerateKSConfigFile(handles.rec_info.exportname,cd,userParams);
    if status~=1
        disp('problem generating the configuration file')
    else
        disp(cmdout)
    end
end

%% [optional] create ChannelMap file for KiloSort
if get(handles.CB_KSChannelMap,'value')==1
    probeInfo.numChannels=length(handles.rec_info.exportedChan);
    if isfield(handles.rec_info,'probeLayout')
        if isfield(handles,'remapped') && handles.remapped==true
            probeInfo.chanMap=1:probeInfo.numChannels;
        else
            switch handles.rec_info.sys
                case 'OpenEphys'
                    probeInfo.chanMap=[handles.rec_info.probeLayout.OEChannel];
                case 'Blackrock'
                    probeInfo.chanMap=[handles.rec_info.probeLayout.BlackrockChannel];
            end
        end
        probeInfo.connected=true(probeInfo.numChannels,1);
        probeInfo.connected(isnan([handles.rec_info.probeLayout.Shank]))=0;
        probeInfo.kcoords=[handles.rec_info.probeLayout.Shank];
        probeInfo.kcoords=probeInfo.kcoords(~isnan([handles.rec_info.probeLayout.Shank]));
        probeInfo.xcoords = zeros(1,probeInfo.numChannels);
        probeInfo.ycoords = 200 * ones(1,probeInfo.numChannels);
        groups=unique(probeInfo.kcoords);
        for elGroup=1:length(groups) 
            if isnan(groups(elGroup))
                continue;
            end
            groupIdx=find(probeInfo.kcoords==groups(elGroup));
            probeInfo.xcoords(groupIdx(2:2:end))=20;
            probeInfo.xcoords(groupIdx)=probeInfo.xcoords(groupIdx)+(0:length(groupIdx)-1);
            probeInfo.ycoords(groupIdx)=...
            probeInfo.ycoords(groupIdx)*(elGroup-1);
            probeInfo.ycoords(groupIdx(round(end/2)+1:end))=...
                probeInfo.ycoords(groupIdx(round(end/2)+1:end))+20;
        end
    end
    
    [status,cmdout]=GenerateKSChannelMap(handles.rec_info.exportname,cd,probeInfo,handles.rec_info.samplingRate);
    if status~=1
        disp('problem generating the configuration file')
    else
        disp(cmdout)
    end
end


close(wb);
disp(['took ' num2str(toc) ' seconds to export data']);

%% [optional] create probe and parameter files for JRClust
if get(handles.CB_JRClustProbeFile,'value')==1
    if contains(handles.rec_info.probeID,'CN32ChProbe')
        probeFile='cnt_32_500.prb';
        copyfile(['C:\Code\EphysDataProc\DataExport\probemaps\' probeFile],...
            cd);
        % Specify the site numbers to exclude
        ref_sites = handles.rec_info.chanID(~(ismember(handles.rec_info.chanID,...
            handles.rec_info.exportedChan)))'; 
        % change manually for now
        
         status=1;
         cmdout='copied existing probe file';
    else
        probeParams.numChannels=size(handles.rec_info.exportedChan,1); %handles.rec_info.numRecChan; %number of channels
        probeParams.pads=[15 15];% Dimensions of the recording pad (height by width in micrometers).
        probeParams.maxSite=4; % Max number of sites to consider for merging
        if isfield(handles.rec_info,'probeLayout')
            if isfield(handles,'remapped') && handles.remapped==true
                probeParams.chanMap=1:probeParams.numChannels;
            else
                switch handles.rec_info.sys
                    case 'OpenEphys'
                        probeParams.chanMap=[handles.rec_info.probeLayout.OEChannel];
                    case 'Blackrock'
                        probeParams.chanMap=[handles.rec_info.probeLayout.BlackrockChannel];
                end
            end
            
            %geometry:
            %         Location of each site in micrometers. The first column corresponds
            %         to the width dimension and the second column corresponds to the depth
            %         dimension (parallel to the probe shank).
            
            probeParams.shanks=[handles.rec_info.probeLayout.Shank];
            probeParams.shanks=probeParams.shanks(~isnan([handles.rec_info.probeLayout.Shank]));
            xcoords = zeros(1,probeParams.numChannels);
            ycoords = 200 * ones(1,probeParams.numChannels);
            groups=unique(probeParams.shanks);
            for elGroup=1:length(groups)
                if isnan(groups(elGroup)) || groups(elGroup)==0
                    continue;
                end
                groupIdx=find(probeParams.shanks==groups(elGroup));
                xcoords(groupIdx(2:2:end))=20;
                xcoords(groupIdx)=xcoords(groupIdx)+(0:length(groupIdx)-1);
                ycoords(groupIdx)=...
                    ycoords(groupIdx)*(elGroup-1);
                ycoords(groupIdx(round(end/2)+1:end))=...
                    ycoords(groupIdx(round(end/2)+1:end))+20;
            end
            
            probeParams.geometry=[xcoords;ycoords]';
            
        else
        end
        [status,cmdout]=GenerateJRClustProbeFile(probeParams); %handles.rec_info.exportname
    end
    if status~=1
        disp('problem generating the probe file')
    else
        disp(cmdout)
        disp('creating parameter file for JRClust')
        % keep the GUI's directory because JRClust will revert the
        % environment to its native state
        exportGUIDir=mfilename('fullpath');
        % find data and probe files
        dirListing=dir(cd);
        exportFileName=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'.dat'),...
            {dirListing.name},'UniformOutput',false))).name;
        probeFileName=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'.prb'),...
            {dirListing.name},'UniformOutput',false))).name;
        jrc('makeprm',exportFileName,probeFileName);
        % set the GUI's path back
        addpath(cell2mat(regexp(exportGUIDir,['.+(?=\' filesep ')'],'match')));
    end

end


% --------------------------------------------------------------------
function SignalExportContextMenu_Callback(hObject, eventdata, handles)

% --------------------------------------------------------------------
function helpwithexport_Callback(hObject, eventdata, handles)




