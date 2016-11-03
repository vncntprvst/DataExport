function phyData=Load_phyResults(phyOutputFolder)
curDir=cd; %keep current directory in memory 
cd(phyOutputFolder);

%list files in phy GUI outputs
dirListing=dir(phyOutputFolder);

%keep npy files
dirListing=dirListing(~cellfun('isempty',cellfun(@(x) strfind(x,'.npy'),...
    {dirListing.name},'UniformOutput',false)));

%read each file into a data structure
phyData=struct;
for fileNum=1:size(dirListing,1)
    phyData.(dirListing(fileNum).name(1:end-4))=readNPY(dirListing(fileNum).name);
end

%go back to original directory
cd(curDir);