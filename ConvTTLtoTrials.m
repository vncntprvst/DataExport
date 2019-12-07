function Trials=ConvTTLtoTrials(TTLtimes,TTLdur,samplingRate)

if nargin==2
    samplingRate=1000; %assuming 1kHz sampling rate if not specified
end

Trials.TTLtimes=TTLtimes;
Trials.samplingRate=samplingRate;

% TTL sequence (in ms)
TTLseq=diff(Trials.TTLtimes)./(Trials.samplingRate/1000); % convert to ms
% [~,occurence,~]=unique(TTLseq);

if length(TTLseq)>10 && mode(TTLseq(1:5))>=250 && mode(TTLseq(1:5))~=mode(TTLseq) %mixed TTL pattern, e.g., vSync +behavior trials
    startSeq=find(TTLseq ~= mode(TTLseq(1:5)),1)+1;
    TTLtimes=TTLtimes(startSeq:end); Trials.TTLtimes=TTLtimes;
    TTLdur=TTLdur(startSeq:end);
    TTLseq=diff(Trials.TTLtimes)./(Trials.samplingRate/1000); % convert to ms
end
if sum(TTLseq==mode(TTLseq))/length(TTLseq)*100>50 % stimulations or sync signal
    % in Stimulation recordings, there are only Pulse onsets, i.e., no
    % double TTL to start, and no TTL to end
    Trials.start=Trials.TTLtimes;
    Trials.end=Trials.start+TTLdur;
    Trials.interval=Trials.start(2:end)-Trials.end(1:end-1);
elseif mode(TTLseq)>=250 && numel(TTLseq)<20 %  max(unique(TTLseq))/TTLtimes>0.9 % video sync at beginning and end of recording
    Trials.start=Trials.TTLtimes;
    Trials.end=Trials.start+TTLdur;
    Trials.interval=Trials.start(2:end)-Trials.end(1:end-1);
else % task trials
    
    %     % In behavioral recordings, task starts with double TTL (e.g., two 10ms
    %     % TTLs, with 10ms interval). These pulses are sent at the begining of
    %     % each trial(e.g.,head through front panel). One pulse is sent at the
    %     % end of each trial. With sampling rate of 30kHz, that interval should
    %     % be 601 samples (20ms*30+1). Or 602 accounting for jitter.
    %     % onTTL_seq at native sampling rate should thus read as:
    %     %   601
    %     %   end of trial time
    %     %   inter-trial interval
    %     %   601 ... etc
    %
    %     %NEW CODE, UNTESTED
        TTLlength=mode(TTLdur); %in ms
    
        if TTLseq(1)>=TTLlength*2+10 %missed first trial initiation, discard times
            TTLidx=find(TTLseq<=TTLlength*2+10,1)-1;
            Trials.TTLtimes=Trials.TTLtimes([TTLidx TTLidx(end)+1]);
            TTLdur=TTLdur([TTLidx TTLidx(end)+1]);
            TTLseq=TTLseq(TTLidx,end);
        end
        if TTLseq(end)<=TTLlength*2+10  %unfinished last trial
            TTLidx=find(TTLseq<=TTLlength*2+10,1,'last')-1;
            Trials.TTLtimes=Trials.TTLtimes([TTLidx TTLidx(end)+1]);
            TTLdur=TTLdur([TTLidx TTLidx(end)+1]);
        end
    
        Trials.start=Trials.TTLtimes(1:3:end);
        Trials.end=Trials.TTLtimes(3:3:end);
        Trials.interval=Trials.start(2:end)-Trials.end(1:end-1);
end

if size(Trials.start,1) > size(Trials.start,2)
    Trials.TTLtimes=Trials.TTLtimes';
    Trials.start=Trials.start';
    Trials.end=Trials.end';
    Trials.interval=Trials.interval';
end

%convert to ms
if samplingRate~=1000
    Trials.start(2,:)=Trials.start(1,:)./(Trials.samplingRate/1000);
    Trials.end(2,:)=Trials.end(1,:)./(Trials.samplingRate/1000);
end