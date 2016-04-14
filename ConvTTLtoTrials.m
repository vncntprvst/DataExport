function Trials=ConvTTLtoTrials(TTL_times,samplingRate,TTL_ID)

% TTL_ID is a succession of pairs of 1 0 ... marking ON OFF ID 
Trials.TTL_times=TTL_times;
Trials.samplingRate{1}=samplingRate;

% keep absolute time of TTL onset
% Trials.TTL_times=Trials.TTL_times(diff([0;TTL_ID])>0);
% TTL sequence (in ms)
Trials.samplingRate{2} = 1000;
TTL_seq=diff(Trials.TTL_times)./uint64(Trials.samplingRate{1}/Trials.samplingRate{2}); % convert to ms
TTLlength=mode(TTL_seq); %in ms

onTTL_seq=diff(Trials.TTL_times(diff([0;TTL_ID])>0))./uint64(Trials.samplingRate{1}/Trials.samplingRate{2});
    % In behavioral recordings, task starts with double TTL (e.g., two 10ms
    % TTLs, with 10ms interval). These pulses are sent at the begining of 
    % each trial(e.g.,head through front panel). One pulse is sent at the 
    % end of each trial. With sampling rate of 30kHz, that interval should
    % be 601 samples (20ms*30+1). Or 602 accounting for jitter.
    % onTTL_seq at native sampling rate should thus read as:
    %   601
    %   end of trial time
    %   inter-trial interval
    %   601 ... etc
    % in Stimulation recordings, there are only Pulse onsets, i.e., no
    % double TTL to start, and no TTL to end
    
if TTL_seq(1)>=TTLlength+10 %missed first trial initiation, discard times
    TTL_seq(1)=TTLlength+300;
    onTTL_seq(1)=TTLlength+300;
end
if TTL_seq(end-1)<=TTLlength+10 %unfinished last trial
    TTL_seq(end)=TTLlength+300;
    onTTL_seq(end)=TTLlength+300;
end

allTrialTimes=Trials.TTL_times([1; find(bwlabel([0;diff(TTL_seq)]))+1]);
if  size(unique(onTTL_seq),1)>1 & diff([min(onTTL_seq) max(onTTL_seq)])>1 %behavioral recordings start: ON/OFF ON/OFF .... end: ON/OFF
    Trials.start=allTrialTimes(1:2:end);
    Trials.end=allTrialTimes(2:2:end);
    try
        Trials.interval=Trials.end(1:end-1)-Trials.start(2:end);
    catch
        Trials.interval=[]; %
    end
elseif  size(unique(onTTL_seq),1)<=2 %stimulation recordings: trial ends when stimulation ends start: ON, end: OFF
    Trials.start=Trials.TTL_times([TTL_seq<=TTLlength*2+10;false]);%Trials.start=Trials.start./uint64(SamplingRate/1000)
    Trials.end=Trials.TTL_times([false;TTL_seq<=TTLlength*2+10]);
    Trials.interval=onTTL_seq; %
end

%convert to ms
Trials.start(:,2)=Trials.start(:,1)./uint64(Trials.samplingRate{1}/Trials.samplingRate{2});
Trials.end(:,2)=Trials.end(:,1)./uint64(Trials.samplingRate{1}/Trials.samplingRate{2});