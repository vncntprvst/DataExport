function phyData=Load_phyResults(phyOutputFolder)
curDir=cd; %keep current directory in memory 
cd(phyOutputFolder);

%list files in phy GUI outputs
dirListing=dir(phyOutputFolder);

%keep npy files
npyListing=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'.npy'),...
    {dirListing.name},'UniformOutput',false)));

%read each file into a data structure
phyData=struct;
for fileNum=1:size(npyListing,1)
    phyData.(npyListing(fileNum).name(1:end-4))=readNPY(npyListing(fileNum).name);
end

%get cluster_id	group from csv file
csvFile=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'.csv'),...
    {dirListing.name},'UniformOutput',false)));
formatSpec = '%s%[^\n\r]';
startRow = 2;
fileID = fopen(csvFile.name,'r');
phyData.cluster_ids = textscan(fileID, formatSpec, 'HeaderLines' ,startRow-1);
fclose(fileID);
phyData.cluster_ids =[phyData.cluster_ids{:}];

%go back to original directory
cd(curDir);