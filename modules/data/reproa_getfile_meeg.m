function rap = reproa_getfile_meeg(rap,command,subj,run)

switch command
    case 'doit'
        %% Select
        series = horzcat(rap.acqdetails.subjects(subj).meegseries{:});
        if ~iscell(series) ...
                || (~isstruct(series{run}) ... % hdr+fname
                && ~ischar(series{run}) ... % fname
                && ~iscell(series{run})) % fname (4D)
            logging.error(['Was expecting list of struct(s) of fname+hdr or fname in cell array\n\n' help('addSubject')]);
        end
        series = series{run};

        %% File
        if isstruct(series)
            headerFn = series.hdr;
            imageFn = series.fname;
        end
        srcdir = spm_file(imageFn,'path');
        meegser = spm_file(imageFn,'filename');
        meegfile = fullfile(srcdir,meegser);

        if ~exist(meegfile,'file')
            logging.error('Subject %s has no session %s!',...
                rap.acqdetails.subjects(subj).subjname,...
                meegser);
        end

        %% Copy file ('f' -> overwrite)
        runpth = getPathByDomain(rap,'meegrun',[subj,run]);

        switch spm_file(meegser,'ext')
            case 'fif' % MEG Neuromag
                copyfile(meegfile,fullfile(runpth,meegser),'f');
            case {'eeg' 'vhdr' 'vmrk'} % EEG BrainVision
                baseFn = spm_file(meegser,'basename');
                meegser = {};
                for f = cellstr(spm_select('FPList',srcdir,['^' baseFn '.*']))'
                    meegser{end+1} = spm_file(f{1},'filename');
                    copyfile(f{1},fullfile(runpth,meegser{end}),'f');
                end
        end

        %% Describe outputs
        putFileByStream(rap,'meegrun',[subj run],'meeg',fullfile(runpth,meegser));
end
