function Raw2MatJ(Name,Date,Blocks)
%------------------------------------%
%| Save raw as .mat file  |
%
% Reading from RS4 and saving on Minnie
%
%------------------------------------%

%% Parameters
fmt = 'float32';
samp_freq = 24414.0625;

%% channel idx
chidx = [
    1 10 11 12 13 14 15 16 17 18 19 ...
    2 20 21 22 23 24 25 26 27 28 29 ...
    3 30 31 32 33 34 35 36 37 38 39 ...
    4 40 41 42 43 44 45 46 47 48 49 ...
    5 50 51 52 53 54 55 56 57 58 59 ...
    6 60 61 62 63 64 65 66 67 68 69 ...
    7 70 71 72 73 74 75 76 77 78 79 ...
    8 80 81 82 83 84 85 86 87 88 89 ...
    9 90 91 92 93 94 95 96 97 98];

%% Block
for i=1:length(Blocks)
    block = Blocks(i);
    
    % identify location of raw (.sev) files and save directory
    if ispc
        datadir=fullfile('\\minnie.cin.ucsf.edu\data2\PairedStimJalapeno\TDT_Blocks',...
            Name,Date,'RawData',sprintf('%s_%s_Session%i',Date,Name,block));
        savedir = fullfile('\\minnie.cin.ucsf.edu\data2\PairedStimJalapeno\TDT_Blocks',...
            Name,Date,'MatFiles',sprintf('Session%i',block));
    elseif ismac
        datadir=fullfile('/Volumes/data2/PairedStimJalapeno/TDT_Blocks',...
            Name,Date,'RawData',sprintf('%s_%s_Session%i',Date,Name,block));
        savedir = fullfile('/Volumes/data2/PairedStimJalapeno/TDT_Blocks',...
            Name,Date,'MatFiles',sprintf('Session%i',block));
    end
    msg = '';

    % try M1 array
    files = dir(fullfile(datadir,'*M1*.sev'));
    if ~isempty(files),
        fprintf('\nConverting M1... ')
        sd = fullfile(savedir,'M1');
        if ~exist(sd,'dir'), mkdir(sd), end

        for j=1:length(files),
            ch = chidx(j);
            fprintf(repmat('\b',1,length(msg)))
            msg = sprintf('ch%02i',j);
            fprintf(msg)
            
            % load data for each channel
            fn = fullfile(datadir,files(j).name);
            fid = fopen(fn, 'rb');
            fread(fid, 40, 'char'); % ignore the header
            data = fread(fid, inf, fmt); % read the streaming data
            fclose(fid);

            % save data for each channel
            sf = fullfile(sd,sprintf('broadband_ch%02i',ch));
            savefast(sf,'data','samp_freq');
        end
    end
    
    % try S1 array
    files = dir(fullfile(datadir,'*S1*.sev'));
    if ~isempty(files),
        fprintf('\nConverting S1... ')
        sd = fullfile(savedir,'S1');
        if ~exist(sd,'dir'), mkdir(sd), end
        
        for j=1:96, % first 96 are broadband data
            ch = chidx(j);
            fprintf(repmat('\b',1,length(msg)))
            msg = sprintf('ch%02i',j);
            fprintf(msg)
            
            % load data for each channel
            fn = fullfile(datadir,files(j).name);
            fid = fopen(fn, 'rb');
            fread(fid, 40, 'char'); % ignore the header
            data = fread(fid, inf, fmt); % read the streaming data
            fclose(fid);

            % save data for each channel
            sf = fullfile(sd,sprintf('broadband_ch%02i',ch));
            savefast(sf,'data','samp_freq');
        end
        
        % try laser
        fprintf('\nConverting LOUT... ')
        sd = fullfile(savedir,'LOUT');
        if ~exist(sd,'dir'), mkdir(sd), end
        
        for j=97:98, % next two channels are laser output
            fprintf(repmat('\b',1,length(msg)))
            msg = sprintf('ch%02i',j-96);
            fprintf(msg)
            
            % load data for each channel
            fn = fullfile(datadir,files(j).name);
            fid = fopen(fn, 'rb');
            fread(fid, 40, 'char'); % ignore the header
            data = fread(fid, inf, fmt); % read the streaming data
            fclose(fid);

            % save data for each channel
            sf = fullfile(sd,sprintf('laser%02i',j-96));
            savefast(sf,'data','samp_freq');
        end
    end
    
    % try LOUT
    files = dir(fullfile(datadir,'*LOUT*.sev'));
    if ~isempty(files),
        fprintf('\nConverting LOUT... ')
        sd = fullfile(savedir,'LOUT');
        if ~exist(sd,'dir'), mkdir(sd), end
        
        for j=1:2,
            fprintf(repmat('\b',1,length(msg)))
            msg = sprintf('ch%02i',j);
            fprintf(msg)
            % load data for each channel
            fn = fullfile(datadir,files(j).name);
            [fid] = fopen(fn, 'rb');
            data = fread(fid, 1e9, fmt)*dVoltsToIntScale;
            fclose(fid);

             % save data for each channel
            sf = fullfile(sd,sprintf('laser%02i',j));
            savefast(sf,'data','samp_freq');
        end
    end
    
end

