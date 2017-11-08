function [TTLtimes,TTLdur]=ContinuousToTTL(continuousTrace)

TTLs=logical(continuousTrace>rms(continuousTrace)*5);
TTLsProperties=regionprops(TTLs,'Area','PixelIdxList');

%remove artifacts
pulseDur=mode([TTLsProperties.Area]);
TTLsProperties=TTLsProperties([TTLsProperties.Area]>=max([(pulseDur-1) 2]) & [TTLsProperties.Area]<=(pulseDur+1));
TTLtimes=cellfun(@(timeIndex) timeIndex(1), {TTLsProperties.PixelIdxList});
TTLdur=[TTLsProperties.Area];

% diffTTL=diff(TTLtimes);
% if mode(diff(TTLtimes))> 20 %likely stimulation trial
%     %                 ampVals=continuousTrace(TTL_times);
%     %                 TTL_times(unique(ampVals));
% else
%     if min(diffTTL(diffTTL<20))<median(diffTTL(diffTTL<20))
%         %remove spurious pulses
%         spurPulses=find(diffTTL(diffTTL<20)<median(diffTTL(diffTTL<20)));
%         spurPulses=sort([spurPulses+1; spurPulses]); %remove also time point before
%         TTLtimes(spurPulses)=0;
%         TTLtimes=TTLtimes(logical(TTLtimes));
%     end
% end

% if mode(diff(TTLtimes))==1 || isempty(TTLtimes) %no trials, just artifacts
%     [TTLstart, TTLend,TTLid]=deal(0);
% else
%     TTLstart=find(diff(continuousTrace>rms(continuousTrace)*5)==1);
%     TTLend=find(diff(continuousTrace<rms(continuousTrace)*5)==1);
%     TTLid=zeros(size(TTLtimes,1),1);
%     if Trials.end(1)-Trials.start(1)>0 %as it should
%         TTLid(1:2:end)=1;
%     else
%         TTLid(2:2:end)=1;
%     end
% end
%     
%     
%     %                 if diff(continuousTrace(TTL_times([find(TTL_ID,1)-1, find(TTL_ID,1)])))<0
%     %                     figure; plot(continuousTrace(TTL_times(1)-1000:TTL_times(2)+1000))
%     %                 end
%     
%     
%     %                     figure; plot(analogChannel.Data(1,Trials.TTL_times(1)-100:Trials.TTL_times(2)+100))