%% Setup reproa
%addpath /home/akk/tools/reproanalysis
%reproaSetup('extensions',{'meeg', 'fsl'});

%% Required files
global reproacache
EL = reproacache('toolbox.eeglab');
EL.load;
CHANNELFILE = fullfile(EL.dipfitPath,'standard_BESA','standard-10-5-cap385.elp');
EL.unload;

%%
rap = reproaWorkflow('meeg_rest.xml');

rap.options.wheretoprocess = 'batch';
rap.options.parallelresources.numberofworkers = 4;

rap = addFile(rap,'study',[],'channellayout',CHANNELFILE);
rap.directoryconventions.T1template = fullfile(rap.directoryconventions.fsldir,'data/standard/MNI152_T1_1mm.nii.gz');

rap.tasksettings.reproa_fromnifti_structural.sfxformodality = 'T1w'; % suffix for structural
rap.tasksettings.reproa_fromnifti_structural.reorienttotemplate = 0;

rap.tasksettings.reproa_converttoeeglab_meeg.removechannel = '';
rap.tasksettings.reproa_converttoeeglab_meeg.downsample = 250;
rap.tasksettings.reproa_converttoeeglab_meeg.diagnostics.freqrange = [1 120];
rap.tasksettings.reproa_converttoeeglab_meeg.diagnostics.freq = [6 10 50];


%% DATA
rap.directoryconventions.rawdatadir = '/media/Data/eeg/BIDS';
rap.acqdetails.input.selectedsubjects = {'030786' '057533' '072143' '087143'};

rap = processBIDS(rap);

%% RESULTS
rap.acqdetails.root = '/media/Data/eeg';
rap.directoryconventions.analysisid = 'reproa';

%% RUN
processWorkflow(rap);
