function rap = reproa_getfile_meeg(rap,command,subj,run)

switch command
    case 'report'
        reportStore = sprintf('sub%d',subj);
        for fn = cellstr(spm_select('FPList',getPathByDomain(rap,'meegrun',[subj,run]),'^diagnostic_.*jpg$'))'
            addReport(rap,reportStore,'<table><tr><td>');
            rap = addReportMedia(rap,reportStore,fn{1},'scaling',0.5,'displayFileName',false);
            addReport(rap,reportStore,'</td></tr></table>');
        end
    case 'doit'
        infname = getFileByStream(rap,'meegrun',[subj run],'meeg');

        global reproacache
        EL = reproacache('toolbox.eeglab');
        EL.load;

        % read data -> first successful
        EEG = [];
        for i = 1:numel(infname)
            try
                EEG = pop_fileio(infname{i});
                [~,res] = eeg_checkset(EEG);
                if isempty(res), break;
                else, throw(res); end
            catch err
                E(i) = err;
            end
        end
        if isempty(EEG)
            logging.error('reading %s - %s',infname{i}, strjoin({E.message},'\n'));
        end

        % channel layout
        EEG = pop_chanedit(EEG,'lookup',char(getFileByStream(rap,'study',[],'channellayout')));

        % remove channel
        if ~isempty(getSetting(rap,'removechannel'))
            chns = strsplit(getSetting(rap,'removechannel'),':');
            EEG = pop_select(EEG, 'nochannel', cellfun(@(x) find(strcmp({EEG.chanlocs.labels}, x)), chns));
        end

        % downsample
        if ~isempty(getSetting(rap,'downsample'))
            sRate = getSetting(rap,'downsample');
            if sRate ~= EEG.srate, EEG = pop_resample( EEG, sRate); end
        end

        % edit
        % - specify operations
        toEditsetting = getSetting(rap,'toEdit');
        toEditsubj = toEditsetting(...
            cellfun(@(x) any(strcmp(x,rap.acqdetails.subjects(subj).subjname)),{toEditsetting.subject}) | ...
            strcmp({toEditsetting.subject},'*')...
            );
        toEdit = struct('type',{},'operation',{});
        for s = 1:numel(toEditsubj)
            runnames = regexp(toEditsubj(s).run,':','split');
            if any(strcmp(runnames,getRunName(rap,run))) || runnames{1} == '*'
                toEdit = horzcat(toEdit,toEditsubj(s).event);
            end
        end

        % - do it
        if ~isempty(toEdit)
            for e = toEdit
                if ischar(e.type)
                    ind = ~cellfun(@isempty, regexp({EEG.event.type},e.type));
                elseif isnumeric(e.type)
                    ind = e.type;
                end
                op = strsplit(e.operation,':');
                if ~any(ind) && ~strcmp(op{1},'insert'), continue; end
                switch op{1}
                    case 'remove'
                        EEG.event(ind) = [];
                        EEG.urevent(ind) = [];
                    case 'keep'
                        EEG.event = EEG.event(ind);
                        EEG.urevent = EEG.urevent(ind);
                    case 'rename'
                        for i = find(ind)
                            EEG.event(i).type = op{2};
                            EEG.urevent(i).type = op{2};
                        end
                    case 'unique'
                        ex = [];
                        switch op{2}
                            case 'first'
                                for i = 2:numel(ind)
                                    if ind(i) && ind(i-1), ex(end+1) = i; end
                                end
                            case 'last'
                                for i = 1:numel(ind)-1
                                    if ind(i) && ind(i+1), ex(end+1) = i; end
                                end
                        end
                        EEG.event(ex) = [];
                        EEG.urevent(ex) = [];
                    case 'iterate'
                        ind = cumsum(ind).*ind;
                        for i = find(ind)
                            EEG.event(i).type = sprintf('%s%02d',EEG.event(i).type,ind(i));
                            EEG.urevent(i).type = sprintf('%s%02d',EEG.urevent(i).type,ind(i));
                        end
                    case 'insert'
                        loc = str2num(op{2});
                        newE = EEG.event(loc);
                        for i = 1:numel(newE)
                            newE(i).type = e.type;
                        end
                        events = EEG.event(1:loc(1)-1);
                        for i = 1:numel(loc)-1
                            events = [events newE(i) EEG.event(loc(i):loc(i+1)-1)];
                        end
                        if isempty(i), i = 0; end
                        events = [events newE(i+1) EEG.event(loc(i+1):end)];
                        EEG.event = events;
                        EEG.urevent = rmfield(events,'urevent');
                    case 'ignorebefore'
                        EEG = pop_select(EEG,'nopoint',[0 EEG.event(ind(1)).latency-1]);
                        beInd = find(strcmp({EEG.event.type},'boundary'),1,'first');
                        samplecorr = EEG.event(beInd).duration;
                        EEG.event(beInd) = [];
                        ureindcorr = EEG.event(1).urevent -1;

                        % adjust events
                        for i = 1:numel(EEG.event)
                            EEG.event(i).urevent = EEG.event(i).urevent - ureindcorr;
                        end
                        EEG.urevent(1:ureindcorr) = [];

                        % adjust time
                        for i = 1:numel(EEG.urevent)
                            EEG.urevent(i).latency = EEG.urevent(i).latency - samplecorr;
                        end
                    case 'ignoreafter'
                        EEG = pop_select(EEG,'nopoint',[EEG.event(ind(end)).latency EEG.pnts]);
                        ureindcorr = EEG.event(end).urevent;

                        % adjust events
                        EEG.urevent(ureindcorr+1:end) = [];
                    otherwise
                        logging.warning('Operation %s not yet implemented',op{1});
                end
                % update events
                for i = 1:numel(EEG.event)
                    urind = find(strcmp({EEG.urevent.type},EEG.event(i).type) & [EEG.urevent.latency]==EEG.event(i).latency);
                    EEG.event(i).urevent = urind(1);
                end
            end
        end

        % diagnostics
        diagpath = fullfile(getPathByDomain(rap,'meegrun',[subj,run]),['diagnostic_' mfilename '_raw.jpg']);
        meeg_diagnostics_continuous(EEG,getSetting(rap,'diagnostics'),'Raw',diagpath);

        fnameroot = 'eeg';
        while ~isempty(spm_select('List',getPathByDomain(rap,'meegrun',[subj,run]),[fnameroot '.*']))
            fnameroot = ['reproa_' fnameroot];
        end

        pop_saveset(EEG,'filepath',getPathByDomain(rap,'meegrun',[subj,run]),'filename',fnameroot);
        outfname = spm_select('FPList',getPathByDomain(rap,'meegrun',[subj,run]),[fnameroot '.*']);

        EL.unload;

        %% Describe outputs
        putFileByStream(rap,'meegrun',[subj run],'meeg',outfname);
end
