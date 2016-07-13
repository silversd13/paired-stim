clear, clc
if ispc, addpath C:\Users\dsilver\Documents\MATLAB\HelperFunctions; end

%% parameters

% which monkey?
name = 'Jalapeno';
delay = []; % all delays
sessions = get_sessions(name,[]);
sessions = sessions(end-12:end-9);

win = [10e-3 30e-3]; % window around each laser pulse for test blocks

% depending on monkey, data is in different spot
if strcmp(name,'Jalapeno'),
    if ismac,
        basesavedir = '/Volumes/data2/PairedStimJalapeno/TDT_Blocks/Jalapeno';
        basedatadir = '/Volumes/data2/PairedStimJalapeno/TDT_Blocks/Jalapeno';
    elseif ispc,
        basesavedir = '\\minnie.cin.ucsf.edu\data2\PairedStimJalapeno\TDT_Blocks\Jalapeno';
        basedatadir = '\\minnie.cin.ucsf.edu\data2\PairedStimJalapeno\TDT_Blocks\Jalapeno';
    end
elseif strcmp(name,'GT'),
    if ismac,
        basesavedir = '/Volumes/data2/PairedStimJalapeno/TDT_Blocks/GT';
        basedatadir = '/Volumes/data4/PairedStim/TDT_Blocks/GT';
    elseif ispc,
        basesavedir = '\\minnie.cin.ucsf.edu\data2\PairedStimJalapeno\TDT_Blocks\GT';
        basedatadir = '\\minnie.cin.ucsf.edu\data4\PairedStim\TDT_Blocks\GT';
    end
end

% decimate and filtering parameters
old_samp_freq = 24414.0625;
[b_n60,a_n60] = butter(2,[58,62]/(old_samp_freq/2),'Stop');
[b_n180,a_n180] = butter(2,[178,182]/(old_samp_freq/2),'Stop');

samp_freq = 24414.0625 / 8; % decimated sampling frequency
[b_lfp,a_lfp] = butter(2,[.1 500]/(samp_freq/2)); % lfp
[b_hg,a_hg] = butter(2,[60 200]/(samp_freq/2)); % high gamma

% error log
logid = fopen('error_log.txt','w');

%% go through each session, each channel, decimate, filter, split

for s=1:length(sessions),
    sess = sessions(s);
    disp(sess)
    try
        for a=1:length(sess.arrays),
            % directories for specific session
            if strcmp(name, 'Jalapeno')
                datadir = fullfile(basedatadir,sess.date,'MatFiles',sprintf('Session%i',sess.session),sess.arrays{a});
                tankdir = fullfile(basedatadir,sess.date,'Tanks',sprintf('%s_%s_Session%i',sess.date,name,sess.session));
            elseif strcmp(name, 'GT')
                datadir = fullfile(basedatadir,sess.date,'RS4');
                tankdir = fullfile(basedatadir,sess.date,'Tank',sprintf('%s_%s_%i',name,sess.date,sess.session));
            end

            % open tank data to get info for splitting
            tankid = matfile(fullfile(tankdir,'data.mat'));
            tank = tankid.data;

            % go through each channel, decimate, filter, split, save
            msg = '';
            for ch=1:96,
                fprintf(repmat('\b',1,length(msg)))
                msg = sprintf('--> ch%02i',ch);
                fprintf(msg)
                if strcmp(name,'Jalapeno'),
                    fid = load(fullfile(datadir,sprintf('broadband_ch%02i',ch)));
                    raw = fid.data;
                elseif strcmp(name,'GT'),
                    fid = load(fullfile(datadir,sprintf('%s_%s_%i_%s_ch%i.mat',name,sess.date,sess.session,sess.arrays{a},ch)));
                    raw = fid.lfp;
                end
                raw(1:10) = 0;

                % notch at 60 and 180
                notched = filtfilt(b_n60,a_n60,raw);
                notched = filtfilt(b_n180,a_n180,notched);

                % decimate
                broadband = decimate(notched,8);

                % filter
                lfp = filtfilt(b_lfp,a_lfp,broadband);
                hg = filtfilt(b_hg,a_hg,broadband);
                if ch==1, % assume time starts at 0 in rs4 & sampling rate is consistent
                    full_time = (0:1/samp_freq:length(lfp)/samp_freq-1/samp_freq)';
                end

                %%% split signal into blocks

                if strcmp(name,'Jalapeno'), % artifact check only exists for Jalapeno
                    % artifact check block1
                    savedir = fullfile(basesavedir,sess.date,'Processed',...
                        sprintf('Session%i',sess.session),sess.arrays{a},'Artifact');
                    if ~exist(savedir,'dir'), mkdir(savedir); end

                    sf = matfile(fullfile(savedir,'artifact_check1.mat'),'Writable',true);
                    if ch==1,
                        sf.samp_freq = samp_freq;
                    end
                    idx1 = find(tank.epocs.FRQ1.data~=150,1)-1;
                    idx2 = find(tank.epocs.FRQ2.data~=150,1)-1;
                    art_time1 = tank.epocs.AMP1.onset([1,idx1]);
                    art_time2 = tank.epocs.AMP2.onset([1,idx2]);
                    sf.(sprintf('lfp_laser1_ch%02i',ch)) = createdatamatc(lfp,art_time1(1),samp_freq,[.1 art_time1(end)-art_time1(1)])';
                    sf.(sprintf('lfp_laser2_ch%02i',ch)) = createdatamatc(lfp,art_time2(1),samp_freq,[.1 art_time2(end)-art_time2(1)])';
                    sf.(sprintf('hg_laser1_ch%02i',ch)) = createdatamatc(hg,art_time1(1),samp_freq,[.1 art_time1(end)-art_time1(1)])';
                    sf.(sprintf('hg_laser2_ch%02i',ch)) = createdatamatc(hg,art_time2(1),samp_freq,[.1 art_time2(end)-art_time2(1)])';
                    % artifact check block2
                    sf = matfile(fullfile(savedir,'artifact_check6.mat'),'Writable',true);
                    sf.samp_freq = samp_freq;
                    idx1 = find(tank.epocs.FRQ1.data~=150,1,'last')+1;
                    idx2 = find(tank.epocs.FRQ2.data~=150,1,'last')+1;
                    art_time1 = tank.epocs.AMP1.onset([idx1,end]);
                    art_time2 = tank.epocs.AMP2.onset([idx2,end]);
                    sf.(sprintf('lfp_laser1_ch%02i',ch)) = createdatamatc(lfp,art_time1(1),samp_freq,[0 art_time1(end)-art_time1(1)+.1])';
                    sf.(sprintf('lfp_laser2_ch%02i',ch)) = createdatamatc(lfp,art_time2(1),samp_freq,[0 art_time2(end)-art_time2(1)+.1])';
                    sf.(sprintf('hg_laser1_ch%02i',ch)) = createdatamatc(hg,art_time1(1),samp_freq,[0 art_time1(end)-art_time1(1)+.1])';
                    sf.(sprintf('hg_laser2_ch%02i',ch)) = createdatamatc(hg,art_time2(1),samp_freq,[0 art_time2(end)-art_time2(1)+.1])';
                end

                % recording blocks
                savedir = fullfile(basesavedir,sess.date,'Processed',...
                    sprintf('Session%i',sess.session),sess.arrays{a},'RecordingBlocks');
                if ~exist(savedir,'dir'), mkdir(savedir); end
                full_idx = find(tank.epocs.BLCK.data == 1);
                for rec_block=1:6,
                    % file for saving
                    sf = matfile(fullfile(savedir,sprintf('RecBlock%i',rec_block)),'Writable',true);

                    % get time in block
                    idx = full_idx(rec_block);
                    tstart = tank.epocs.BLCK.onset(idx);
                    tend = tank.epocs.BLCK.offset(idx);
                    tidx = (full_time > tstart & full_time < tend);

                    if ch==1, % don't need to redo for each channel
                        % save time info
                        sf.tstart = tstart;
                        sf.tend = tend;
                        sf.samp_freq = samp_freq;
                        sf.time = full_time(tidx);
                    end

                    % save signal within recording block
                    sf.(sprintf('lfp_ch%02i',ch)) = lfp(tidx);
                end % recording block

                % testing blocks
                savedir = fullfile(basesavedir,sess.date,'Processed',...
                    sprintf('Session%i',sess.session),sess.arrays{a},'TestBlocks');
                if ~exist(savedir,'dir'), mkdir(savedir); end
                full_idx = find(tank.epocs.BLCK.data == 2);
                for test_block=1:6,
                    % file for saving
                    sf = matfile(fullfile(savedir,sprintf('TestBlock%i',test_block)),'Writable',true);

                    % get stim times in block
                    idx = full_idx(test_block);
                    tstart = tank.epocs.BLCK.onset(idx);
                    tend = tank.epocs.BLCK.offset(idx);
                    stim1 = tank.epocs.AMP1.onset(tank.epocs.AMP1.onset > tstart & tank.epocs.AMP1.onset < tend & tank.epocs.FRQ1.data ~= 150);
                    stim2 = tank.epocs.AMP2.onset(tank.epocs.AMP2.onset > tstart & tank.epocs.AMP2.onset < tend & tank.epocs.FRQ2.data ~= 150);

                    if ch==1,
                        % save time info
                        sf.tstart = tstart;
                        sf.tend = tend;
                        sf.stim1 = stim1;
                        sf.stim2 = stim2;
                        sf.win = win;
                        sf.samp_freq = samp_freq;
                    end                

                    % save individual traces
                    sf.(sprintf('lfp_traces1_ch%02i',ch)) = createdatamatc(lfp,stim1,samp_freq,win)';
                    sf.(sprintf('lfp_traces2_ch%02i',ch)) = createdatamatc(lfp,stim2,samp_freq,win)';
                    sf.(sprintf('hg_traces1_ch%02i',ch)) = createdatamatc(hg,stim1,samp_freq,win)';
                    sf.(sprintf('hg_traces2_ch%02i',ch)) = createdatamatc(hg,stim2,samp_freq,win)';
                    % save avg traces
                    sf.(sprintf('mean_lfp_traces1_ch%02i',ch)) = mean(createdatamatc(lfp,stim1,samp_freq,win)');
                    sf.(sprintf('mean_lfp_traces2_ch%02i',ch)) = mean(createdatamatc(lfp,stim2,samp_freq,win)');
                    sf.(sprintf('mean_hg_traces1_ch%02i',ch)) = mean(createdatamatc(hg,stim1,samp_freq,win)');
                    sf.(sprintf('mean_hg_traces2_ch%02i',ch)) = mean(createdatamatc(hg,stim2,samp_freq,win)');
                end % testing blocks

                % conditioning blocks
                savedir = fullfile(basesavedir,sess.date,'Processed',...
                    sprintf('Session%i',sess.session),sess.arrays{a},'ConditioningBlocks');
                if ~exist(savedir,'dir'), mkdir(savedir); end
                full_idx = find(tank.epocs.BLCK.data == 3);
                for cond_block=1:5,
                    % file for saving
                    sf = matfile(fullfile(savedir,sprintf('CondBlock%i',cond_block)),'Writable',true);

                    % get time in block
                    idx = full_idx(cond_block);
                    tstart = tank.epocs.BLCK.onset(idx);
                    tend = tank.epocs.BLCK.offset(idx);
                    tidx = (full_time > tstart & full_time < tend);
                    stim1 = tank.epocs.AMP1.onset(tank.epocs.AMP1.onset > tstart & tank.epocs.AMP1.onset < tend & tank.epocs.FRQ1.data ~= 150);
                    stim2 = tank.epocs.AMP2.onset(tank.epocs.AMP2.onset > tstart & tank.epocs.AMP2.onset < tend & tank.epocs.FRQ2.data ~= 150);

                    if ch==1, % don't need to redo for each channel
                        % save time info
                        sf.tstart = tstart;
                        sf.tend = tend;
                        sf.stim1 = stim1;
                        sf.stim2 = stim2;
                        sf.samp_freq = samp_freq;
                        sf.time = full_time(tidx);
                    end

                    % save signal within conditioning block
                    sf.(sprintf('lfp_ch%02i',ch)) = lfp(tidx);
                    sf.(sprintf('hg_ch%02i',ch)) = hg(tidx);
                end % conditioning blocks

            end % channel
        end % each array
    catch
        fprintf(logid,'name: %s\n',sess.name);
        fprintf(logid,'date: %s\n',sess.date);
        fprintf(logid,'sess: %i\n',sess.session);
    end
end % each session
fclose(logid);