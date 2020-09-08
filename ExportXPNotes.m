function ExportXPNotes(fileName, fileDir)
% fileDir='C:\Sync\Box Sync\Home Folder vp35\Sync\Wang Lab\Manips\vIRt47';
% fileName='Experiment Note Sheet - vIRt47.xlsx';
%% Convert notes spreadsheet to json file

%% First read header
opts = spreadsheetImportOptions("NumVariables", 9);
opts.DataRange = "A2:I2";
opts.VariableNames = ["SubjectID", "VarName2", "VarName3", "Goal", "Type", "Sex", "DOB", "Tag", "Cagecard"];
opts.VariableTypes = ["char", "double", "double", "char", "char", "char", "datetime", "categorical", "double"];
opts.MissingRule = "omitvar";
opts = setvaropts(opts, ["SubjectID", "Goal", "Type", "Sex"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["SubjectID", "Goal", "Type", "Sex", "Tag"], "EmptyFieldRule", "auto");
opts = setvaropts(opts, ["VarName2", "VarName3", "Cagecard", "DOB"], "TreatAsMissing", '');
opts = setvaropts(opts, "DOB", "InputFormat", "MM/dd/uu");

% Import data
xpNotesHeader = readtable(fullfile(fileDir, fileName), opts, "UseExcel", false);

clear opts

%% Now read experiment notes
opts = spreadsheetImportOptions("NumVariables", 8);
opts.DataRange = 5; % Starting at row 5
opts.VariableNames = ["Procedure", "Date", "Depth", "Notes", "StimPower", "StimFreq", "PulseDur", "Device", "Comments"];
opts.VariableTypes = ["categorical", "datetime", "double", "string", "double", "double", "double", "categorical", "string"];
opts = setvaropts(opts, ["Notes", "Comments"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Procedure", "Notes", "Device", "Comments"], "EmptyFieldRule", "auto");
opts = setvaropts(opts, "Date", "InputFormat", "MM/dd/uu");

% Import  data
xpNotes = readtable(fullfile(fileDir, fileName), opts, "UseExcel", false);

%% Write notes to json file
% adjust variables
xpNotesHeader.Cagecard=num2str(xpNotesHeader.Cagecard);
if xpNotesHeader.DOB < '01-Jan-2015'; xpNotesHeader.DOB(1)=''; end
% find procedures and sessions 
%procedures= categories(xpNotes.Procedure)
procedureIdx=~isundefined(xpNotes.Procedure);
sessionIdx=xpNotes.Procedure=='R';
procedureIdx=find(procedureIdx & ~sessionIdx);
sessionIdx=find(sessionIdx);

% open file
fid  = fopen(fullfile(fileDir,[char(xpNotesHeader.SubjectID) '_notes.json']),'w');
fprintf(fid,'{\r\n');
% first print header variables
headerFields=xpNotesHeader.Properties.VariableNames;
fprintf(fid,'\t"Header": {\r\n');
for fldNum=1:numel(headerFields)
    try 
        str=jsonencode(xpNotesHeader.(headerFields{fldNum}){:});
    catch
        str=jsonencode(xpNotesHeader.(headerFields{fldNum}));
    end
    if fldNum<numel(headerFields)
        fprintf(fid,['\t\t"' headerFields{fldNum} '": %s,\r\n'],str);
    else
        fprintf(fid,['\t\t"' headerFields{fldNum} '": %s\r\n\t},\r\n'],str);
    end
end
% then print notes
procedureRange=[];
fprintf(fid,'\t"Procedures": [\r\n');
for procNum=1:numel(procedureIdx)
    if any(ismember(procedureRange,procNum))
        continue
    end
    % find row range of procedure
    if ismember(xpNotes.Procedure(procedureIdx(procNum)),'injection')
        notinjectionsIdx=procedureIdx(...
        ~contains(string(xpNotes.Procedure(procedureIdx)),'injection'));
        procedureRange=procedureIdx(procNum):...
            notinjectionsIdx(find(notinjectionsIdx>procedureIdx(procNum),1))-1;
    else
        if procNum<numel(procedureIdx)
            procedureRange=procedureIdx(procNum):procedureIdx(procNum+1)-1;
        else
            procedureRange=procedureIdx(procNum):numel(xpNotes.Procedure);
        end
    end
    % print procedure type, date and head comment
    fprintf(fid,'\t\t{\r\n\t\t\t"Procedure": "%s",\r\n',xpNotes.Procedure(procedureIdx(procNum))); 
    fprintf(fid,'\t\t\t"Date": "%s",\r\n',xpNotes.Date(procedureIdx(procNum))); 
    fprintf(fid,'\t\t\t"Comment": "%s"', xpNotes.Notes(procedureIdx(procNum))); 
    % if there are other notes, add them
    if numel(procedureRange)>1 
        if any(ismember(procedureIdx,procedureRange(2:end)))
            fprintf(fid,',\r\n\t\t\t"Subprocedures": [\r\n');
            subprocIdx=procedureIdx(ismember(procedureIdx,procedureRange(2:end)));
            for subprocNum=1:numel(subprocIdx)
                fprintf(fid,'\t\t\t\t\t{\r\n');
                fprintf(fid,['\t\t\t\t\t"Part' num2str(subprocNum) '": "%s",\r\n'],...
                    xpNotes.Procedure(subprocIdx(subprocNum)));
                if subprocNum<numel(subprocIdx)
%                     fprintf(fid,',\r\n');
                    subprocRange=subprocIdx(subprocNum+1)-1;
                else
%                     fprintf(fid,'\r\n');
                    subprocRange=procedureIdx(find(procedureIdx>subprocIdx(end),1))-1;
                end
                notes=xpNotes.Notes(subprocIdx(subprocNum)+1:subprocRange);
                notes=[notes{:}];
                fprintf(fid,['\t\t\t\t\t"Part' num2str(subprocNum) ' Notes": "%s"\r\n}'],notes);
                if subprocNum<numel(subprocIdx); fprintf(fid,','); end
            end
            fprintf(fid,'\t\t\t\t]\r\n');
        else
            notes=xpNotes.Notes(procedureRange(2:end));
            notes=[notes{:}];
            fprintf(fid,',\r\n\t\t\t"Notes": "%s"\r\n',notes);
        end     
    else
        fprintf(fid,'\r\n');
    end
    if procNum<numel(procedureIdx)
        fprintf(fid,'\t\t},\r\n');
    else
        fprintf(fid,'\t\t}\r\n');
    end
end
fprintf(fid,'\t]\r\n');
 
%close file
fprintf(fid,'}');
fclose(fid);

