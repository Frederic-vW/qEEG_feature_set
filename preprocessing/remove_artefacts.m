%-------------------------------------------------------------------------------
% remove_artefacts: simple procedure to remove artefacts
%
% Syntax: data=remove_artefacts(data,ch_labels,Fs)
%
% Inputs: 
%     data,ch_labels,Fs - 
%
% Outputs: 
%     data - 
%
% Example:
%     
%

% John M. O' Toole, University College Cork
% Started: 05-04-2016
%
% last update: Time-stamp: <2016-04-05 16:39:57 (otoolej)>
%-------------------------------------------------------------------------------
function data=remove_artefacts(data,ch_labels,Fs)
if(nargin<3), error('requires 3 input arguments.'); end



[N_channels,N]=size(data);


%---------------------------------------------------------------------
% 1. look for electrode short:
%---------------------------------------------------------------------
if(N_channels>4)
    [ileft,iright]=channel_left_or_right(ch_labels);

    x_means=zeros(1,N_channels);

    x_filt=zeros(N_channels,N);
    for n=1:N_channels
        x_filt(n,:)=filt_butterworth(data(n,:),Fs,20,0.5,5);
    end


    for n=1:N_channels
        x_means(n)=nanmean( abs( x_filt(n,:) ).^2 );
        
        A{n,1}=x_means(n);
        A{n,2}=ch_labels{n};
    end
    clear x_filt;
    data_no=data; [M,N]=size(data);

    % 1/4 of the median of channel energy:
    cut_off_left=median(x_means(ileft))/4;
    cut_off_right=median(x_means(iright))/4;


    ishort_left=find(x_means(ileft)<cut_off_left);
    ishort_right=find(x_means(iright)<cut_off_right);

    ishort=[ileft(ishort_left) iright(ishort_right)];
    if(~isempty(ishort))
        fprintf(':: remove channels: %s\n',ch_labels{ishort});
        data_no(ishort,:)=NaN;
    end
end

% all other artefacts are on a channel-by-channel basis:
irem=[];
for n=1:N_channels
    data(n,:)=art_per_channel(data(n,:),Fs);
    
    irem=[irem find(isnan(data(n,:)))];
end

% remove artefacts across all channels
data(:,unique(irem))=NaN;



function x=art_per_channel(x,Fs)
%---------------------------------------------------------------------
% remove artefacts on a per-channel basis
%---------------------------------------------------------------------
quant_feats_parameters;

DBverbose=1;

N=length(x);

%---------------------------------------------------------------------
% 1. high-amplitude artefacts
%---------------------------------------------------------------------
art_coll=ART_TIME_COLLAR*Fs;
irem=zeros(1,N);    

x_hilbert=abs( hilbert(x) );    

thres_upper=ART_HIGH_VOLT;
ihigh=find(x_hilbert>thres_upper);
if(~isempty(ihigh))
    for p=1:length(ihigh)
        irun=(ihigh(p)-art_coll):(ihigh(p)+art_coll);
        irun(irun<1)=1;  irun(irun>N)=N;               
        irem(irun)=1;
    end
end
x(irem==1)=NaN;
if(any(irem==1) && DBverbose)
    fprintf('length of high-amplitude artefacts: %.2f\n', ...
            100*length(find(irem==1))/length(x));
end


%---------------------------------------------------------------------
% 2. electrode-checks (continuous row of zeros)
%---------------------------------------------------------------------
x_channel=x;
x_channel(x_channel~=0)=1;
irem=zeros(1,N);    
[lens,istart,iend]=len_cont_zeros(x_channel,0);
ielec=find(lens>=(ART_ELEC_CHECK*Fs));
if(~isempty(ielec) && DBverbose)
    fprintf(['electrode check at time(s): ' repmat('%g ',1,length(ielec))  ...
             ' \n'],istart(ielec)./Fs);
end
for m=ielec
    irun=[istart(m)-1:iend(m)+1];
    irun(irun<1)=1; irun(irun>=N)=N;
    irem(irun)=1;
    x(irun)=NaN;
end
if(any(irem==1) && DBverbose)
    fprintf('continuous row of zeros: %.2f\n', ...
            100*length(find(irem==1))/length(x));
end



%---------------------------------------------------------------------
% 3. continuous constant values (i.e. artefacts)
%---------------------------------------------------------------------
art_coll=ART_DIFF_TIME_COLLAR*Fs;
x_diff_all=zeros(1,N);
irem=zeros(1,N);    

x_diff_all=[diff(x) 0];        
x_diff=x_diff_all;
x_diff(x_diff~=0)=1;
[lens,istart,iend]=len_cont_zeros(x_diff,0);

% if exactly constant for longer than . then remove:
ielec=find(lens>=(ART_DIFF_MIN_TIME*Fs));
% $$$ if(~isempty(ielec))
% $$$     fprintf(['channel: %s; flat voltage at time(s): ' repmat('%g ',1,length(ielec))  ...
% $$$              ' \n'],bi_mont{n},istart(ielec)./Fs);
% $$$ end
for m=ielec
    irun=[(istart(m)-art_coll):(iend(m)+art_coll)];
    irun(irun<1)=1; irun(irun>=N)=N;
    irem(irun)=1;
    x(irun)=NaN;
end
if(any(irem==1) && DBverbose)
    fprintf('continuous row of constant values: %.2f\n', ...
            100*length(find(irem==1))/length(x));
end


%---------------------------------------------------------------------
% 4. sudden jumps in amplitudes or constant values (i.e. artefacts)
%---------------------------------------------------------------------
art_coll=ART_DIFF_TIME_COLLAR*Fs;
irem=zeros(1,N);    
x_diff=x_diff_all;    
    
ihigh=find(abs(x_diff)>200);
if(~isempty(ihigh))
    for p=1:length(ihigh)
        irun=(ihigh(p)-art_coll):(ihigh(p)+art_coll);
        irun(irun<1)=1;  irun(irun>N)=N;               
        irem(irun)=1;
    end
end
x(irem==1)=NaN;
if(any(irem==1) && DBverbose)
    fprintf('length of sudden-jump artefacts: %.2f\n', ...
            100*length(find(irem==1))/length(x));
end
