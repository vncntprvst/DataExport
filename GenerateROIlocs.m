cd('E:\Bonsai\config')
fileID = fopen('ROIlocs.txt','w');

for cols=1:13
    for rows=1:20
        
        XVal=[(cols-1)*50+1 cols*50 cols*50 (cols-1)*50+1];
        YVal=[(rows-1)*10+1 (rows-1)*10+1 rows*10 rows*10];
        
        if cols==13 %smaller one
            XVal(2)=XVal(2)-10;
            XVal(3)=XVal(3)-10;
        end
        
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t<q1:ArrayOfPoint>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<q1:Point>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t\t<q1:X>%i</q1:X>\r',XVal(1));
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t\t<q1:Y>%i</q1:Y>\r',YVal(1));
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t</q1:Point>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<q1:Point>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t\t<q1:X>%i</q1:X>\r',XVal(2));
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t\t<q1:Y>%i</q1:Y>\r',YVal(2));
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t</q1:Point>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<q1:Point>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t\t<q1:X>%i</q1:X>\r',XVal(3));
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t\t<q1:Y>%i</q1:Y>\r',YVal(3));
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t</q1:Point>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<q1:Point>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t\t<q1:X>%i</q1:X>\r',XVal(4));
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t\t<q1:Y>%i</q1:Y>\r',YVal(4));
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t</q1:Point>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t</q1:ArrayOfPoint>\r');
        
    end
end
fclose(fileID);

fileID = fopen('ROIIndices.txt','w');
for idx=0:20*13-1
    if idx>0 && mod(idx,20)==0
        fprintf(fileID,'\r');
    end
    fprintf(fileID,'\t\t\t\t\t\t\t\t\t<Expression xsi:type="Combinator">\r');
    fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<Combinator xsi:type="q1:RoiActivityDetected">\r');
    fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t\t<q1:Index>%i</q1:Index>\r',idx);
    fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t\t<q1:Threshold>%i</q1:Threshold>\r',150);
    fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t</Combinator>\r');
    fprintf(fileID,'\t\t\t\t\t\t\t\t\t</Expression>\r');
end
fclose(fileID);
                      
                    
                  