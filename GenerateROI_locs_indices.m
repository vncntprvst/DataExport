cd('E:\Bonsai\config')
fileID = fopen('ROI_indices_locs_full.txt','w');

for colNum=0:13 %14 columns
    if colNum==1 || colNum==2 || colNum==7
        fprintf(fileID,'\t\t\t<Expression xsi:type="Combinator">\r');
        fprintf(fileID,'\t\t\t\t<Combinator xsi:type="Zip" />\r');
        fprintf(fileID,'\t\t\t</Expression>\r');
    end
    fprintf(fileID,'\t\t\t<Expression xsi:type="NestedWorkflow">\r');
    fprintf(fileID,'\t\t\t\t<Name>ROIs</Name>\r');
    fprintf(fileID,'\t\t\t\t<Workflow>\r');
    fprintf(fileID,'\t\t\t\t\t<Nodes>\r');
    fprintf(fileID,'\t\t\t\t\t\t<Expression xsi:type="Combinator">\r');
    fprintf(fileID,'\t\t\t\t\t\t\t<Combinator xsi:type="Zip" />\r');
    fprintf(fileID,'\t\t\t\t\t\t</Expression>\r');
    
    for rowNum=0:5 %6 groups of *7 rows per column
        fprintf(fileID,'\t\t\t\t\t\t<Expression xsi:type="NestedWorkflow">\r');
        fprintf(fileID,'\t\t\t\t\t\t\t<Workflow>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t<Nodes>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t<Expression xsi:type="Combinator">\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<Combinator xsi:type="Zip" />\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t</Expression>\r');        
        for grpmtidx=0:6
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t<Expression xsi:type="Combinator">\r');
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<Combinator xsi:type="q1:RoiActivityDetected">\r');
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t\t<q1:Index>%i</q1:Index>\r',grpmtidx+(7*rowNum)+(42*colNum));
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t\t<q1:Threshold>%i</q1:Threshold>\r',150);
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t</Combinator>\r');
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t</Expression>\r');
        end
        
        %% edges
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t<Expression xsi:type="WorkflowInput">\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<Name>Source1</Name>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t</Expression>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t<Expression xsi:type="WorkflowOutput" />\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t</Nodes>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t<Edges>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t<Edge>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<From>0</From>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<To>9</To>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<Label>Source1</Label>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t\t\t</Edge>\r');
        for egdidx=1:7
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t<Edge>\r');
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<From>%i</From>\r',egdidx);
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<To>0</To>\r');
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<Label>Source%i</Label>\r',egdidx+11);
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t</Edge>\r');
        end
        numorder=[5 4 3 2 1 6 7];
        for egdidx=1:7
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t<Edge>\r');
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<From>8</From>\r');
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<To>%i</To>\r',numorder(egdidx));
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t\t<Label>Source1</Label>\r');
            fprintf(fileID,'\t\t\t\t\t\t\t\t\t</Edge>\r');
        end
        fprintf(fileID,'\t\t\t\t\t\t\t\t</Edges>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t</Workflow>\r');
        fprintf(fileID,'\t\t\t\t\t\t</Expression>\r');
    end
    
    fprintf(fileID,'\t\t\t\t\t\t<Expression xsi:type="Combinator">\r');
    fprintf(fileID,'\t\t\t\t\t\t\t<Combinator xsi:type="q1:RoiActivity">\r');
    fprintf(fileID,'\t\t\t\t\t\t\t\t<q1:Regions>\r');
    
    for cols=1:14 %Zip's max item being 7, simpler to use multiples of 7
        for rows=1:42
            
            XVal=[(cols-1)*45+1 cols*45 cols*45 (cols-1)*45+1];
            YVal=[(rows-1)*10+1 (rows-1)*10+1 rows*10 rows*10];
            
            if cols==14 %bigger one
                XVal(2)=XVal(2)+10;
                XVal(3)=XVal(3)+10;
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
    fprintf(fileID,'\t\t\t\t\t\t\t\t</q1:Regions>\r');
    fprintf(fileID,'\t\t\t\t\t\t\t</Combinator>\r');
    fprintf(fileID,'\t\t\t\t\t\t</Expression>\r');
    fprintf(fileID,'\t\t\t\t\t\t<Expression xsi:type="WorkflowInput">\r');
    fprintf(fileID,'\t\t\t\t\t\t\t<Name>Source1</Name>\r');
    fprintf(fileID,'\t\t\t\t\t\t</Expression>\r');
    fprintf(fileID,'\t\t\t\t\t\t<Expression xsi:type="WorkflowOutput" />\r');
    fprintf(fileID,'\t\t\t\t\t</Nodes>\r');
    fprintf(fileID,'\t\t\t\t\t<Edges>\r');
    fprintf(fileID,'\t\t\t\t\t\t<Edge>\r');
    fprintf(fileID,'\t\t\t\t\t\t\t<From>0</From>\r');
    fprintf(fileID,'\t\t\t\t\t\t\t<To>9</To>\r');
    fprintf(fileID,'\t\t\t\t\t\t\t<Label>Source1</Label>\r');
    fprintf(fileID,'\t\t\t\t\t\t</Edge>\r');
    sourceOrder=[1 2 3 4 5 6];
    for egdidx=1:6
        fprintf(fileID,'\t\t\t\t\t\t<Edge>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t<From>%i</From>\r',egdidx);
        fprintf(fileID,'\t\t\t\t\t\t\t<To>0</To>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t<Label>Source%i</Label>\r',sourceOrder(egdidx));
        fprintf(fileID,'\t\t\t\t\t\t</Edge>\r');
    end
    numorder=[1 2 3 4 5 6];
    for egdidx=1:6
        fprintf(fileID,'\t\t\t\t\t\t<Edge>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t<From>7</From>\r');
        fprintf(fileID,'\t\t\t\t\t\t\t<To>%i</To>\r',numorder(egdidx));
        fprintf(fileID,'\t\t\t\t\t\t\t<Label>Source1</Label>\r');
        fprintf(fileID,'\t\t\t\t\t\t</Edge>\r');
    end
    fprintf(fileID,'\t\t\t\t\t\t<Edge>\r');
    fprintf(fileID,'\t\t\t\t\t\t\t<From>8</From>\r');
    fprintf(fileID,'\t\t\t\t\t\t\t<To>7</To>\r');
    fprintf(fileID,'\t\t\t\t\t\t\t<Label>Source1</Label>\r');
    fprintf(fileID,'\t\t\t\t\t\t</Edge>\r');
    fprintf(fileID,'\t\t\t\t\t</Edges>\r');
    fprintf(fileID,'\t\t\t\t</Workflow>\r');
    fprintf(fileID,'\t\t\t</Expression>\r');
end
%% close
fclose(fileID);


