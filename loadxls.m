function tableData=loadxls(xlsfile,format)
% Import data from spreadsheet

%% Import the data

tableData = readtable([cd '\' xlsfile]);

%% convert to structure if needed
if strcmp(format,'struct')
    tableData=table2struct(tableData);
end