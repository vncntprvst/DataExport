function varargout = DesignProbeFile(varargin)
% code for DesignProbeFile.fig

% Edit the above text to modify the response to help DesignProbeFile

% Last Modified by GUIDE v2.5 18-Sep-2017 18:51:52

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @DesignProbeFile_OpeningFcn, ...
                   'gui_OutputFcn',  @DesignProbeFile_OutputFcn, ...
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


% --- Executes just before DesignProbeFile is made visible.
function DesignProbeFile_OpeningFcn(hObject, eventdata, handles, varargin)

handles.output = hObject;

axis;
set(gca,'xlim',[0 600],'ylim',[0 400],'TickDir','out');
box off;
grid on;
handles.numTrodes=0;
% Update handles structure
guidata(hObject, handles);

% --- Outputs from this function are returned to the command line.
function varargout = DesignProbeFile_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
varargout{1} = handles.output;

% --- Executes on button press in PB_createTrode.
function PB_createTrode_Callback(hObject, eventdata, handles)
selectedTrodeType=get(handles.Panel_electrodeType,'SelectedObject'); 
switch selectedTrodeType.String
    case 'Single'
        handles.trodeHandles(handles.numTrodes+1)= impoint(handles.Ax_electrodeSpace,100,100);
        handles.numTrodes=handles.numTrodes+1;
    case 'Stereotrode'
        handles.trodeHandles(handles.numTrodes+1)= impoint(handles.Ax_electrodeSpace,100,100);
        handles.trodeHandles(handles.numTrodes+2)= impoint(handles.Ax_electrodeSpace,100,120);
        handles.numTrodes=handles.numTrodes+2;
    case 'Tetrode'
        handles.trodeHandles(handles.numTrodes+1)= impoint(handles.Ax_electrodeSpace,100,100);
        handles.trodeHandles(handles.numTrodes+2)= impoint(handles.Ax_electrodeSpace,100,120);
        handles.trodeHandles(handles.numTrodes+3)= impoint(handles.Ax_electrodeSpace,120,100);
        handles.trodeHandles(handles.numTrodes+4)= impoint(handles.Ax_electrodeSpace,120,120);
        handles.numTrodes=handles.numTrodes+4;
end

guidata(hObject, handles);

% --- Executes on button press in PB_saveProbeFile.
function PB_saveProbeFile_Callback(hObject, eventdata, handles)


% --- Executes on button press in PB_snap.
function PB_snap_Callback(hObject, eventdata, handles)
for trodNum=1:handles.numTrodes
pos = getPosition(handles.trodeHandles(trodNum));
setPosition(handles.trodeHandles(trodNum),round(pos/10)*10);
end

