function Raw2Mat(Name,Date,Blocks,Arrays,Channels)
%-------------------------------------%
%| Save raw as .mat file  |
%
% Reading from RS4 and saving on Minnie
%
%-------------------------------------%

%% Parameters
dMaxV = 5e-3; %from Serge's original file - for scaling purposes
iResolutionBits = 16;
dVoltsToIntScale = pow2(iResolutionBits-1)/dMaxV;
fmt = 'float32';
samp_freq = 24414.0625;

%% Block
for i=1:length(Blocks)
    block = Blocks(i);
    FolderName = sprintf('%s_%s_%i',Name,Date,block);
%     datadir = fullfile('\\RS4-41012\data\PairedStim',FolderName);
    datadir=fullfile('\\minnie.cin.ucsf.edu\data4\PairedStim\TDT_Blocks',...
        Name,Date,'RawData',sprintf('%s_%s_%i',Name,Date,block));
    for j=1:length(Arrays)
        array = Arrays{j};
        savedir = fullfile('\\minnie.cin.ucsf.edu\data4\PairedStim\TDT_Blocks',...
        Name,Date,'RS4');
%         fullfile('~','Projects','PairedStim','Data',Name,Date,num2str(block),array);
        if ~exist(savedir,'dir'), mkdir(savedir), end
        
        for ch=Channels
            datafile = sprintf('PairedStim_%s_%s_%s_%sxW_ch%i.sev',Name,Date,num2str(block),array,ch);
            fn = fullfile(datadir,datafile);
            fmt = 'float32';
            [fid] = fopen(fn, 'rb');

            lfp = fread(fid, 1e9, fmt)*dVoltsToIntScale;
            fclose(fid);

            fsave = fullfile(savedir,sprintf('%s_%s_%i_%s_ch%i.mat',Name,Date,block,array,ch));
            disp(['read ' num2str(size(lfp,1)) ' elements']);
            save(fsave, 'lfp');
        end
    end
end

