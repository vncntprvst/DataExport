function data=openLongNSx(path,fname,splitNum)
if splitNum>9
    splitNum=9; % upper limit
end
fileNames=dir(path);
isSplitFiles=cellfun(@(fnames) strcmp(fnames,[fname(1:end-4)...
    '-s001' fname(end-3:end)]), {fileNames.name},'UniformOutput',false);
if sum([isSplitFiles{:}])==0
   splitThatNSx(splitNum,fname,path);
end
data=struct('MetaTags',[],'Data',[],'RawData',[],'ElectrodesInfo',[]);

for splitFile=1:splitNum
    data(splitFile) = openNSx([path fname(1:end-4) '-s00' num2str(splitFile)...
        fname(end-3:end)]);
end
data=struct('MetaTags',data(1).MetaTags,'Data',[data.Data],'RawData',...
    data(1).RawData,'ElectrodesInfo',data(1).ElectrodesInfo);
data.MetaTags.DataPoints=size(data.Data,2);
data.MetaTags.Filename=fname;

path='E:\Data\raw\Blackrock\Lifeng\';
fname='CNO_06062016001.ns6';
fileHeader=openNSx([path fname],'noread');
fileSamples=fileHeader.MetaTags.DataPoints;
% max(fileSamples)/fileHeader.MetaTags.SamplingFreq/3600
splitVector=round(linspace(1,max(fileSamples),4));
splitVector(end)=max(fileSamples); %just to be sure
foo=openNSx([path fname],['t:1:' num2str(splitVector(2))] , 'sample');