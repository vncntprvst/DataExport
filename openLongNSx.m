function data=openLongNSx(path,fname) %splitNum
% if splitNum>9
%     splitNum=9; % upper limit
% end
fileNames=dir(path);
isSplitFiles=cellfun(@(fnames) strcmp(fnames,[fname(1:end-4)...
    '-s001' fname(end-3:end)]), {fileNames.name},'UniformOutput',false);
if sum([isSplitFiles{:}])==0
%    splitThatNSx(2,fname,path);
    splitNSxPauses([path fname]);
else %already split
    data = openNSx([path fname(1:end-4) '-s001' fname(end-3:end)]);
end
% data=struct('MetaTags',[],'Data',[],'RawData',[],'ElectrodesInfo',[]);

% for splitFile=1:splitNum
%     data(splitFile) = openNSx([path fname(1:end-4) '-s00' num2str(splitFile)...
%         fname(end-3:end)]);
% end
% data=struct('MetaTags',data(1).MetaTags,'Data',[data.Data],'RawData',...
%     data(1).RawData,'ElectrodesInfo',data(1).ElectrodesInfo);
% data.MetaTags.DataPoints=size(data.Data,2);
% data.MetaTags.Filename=fname;

