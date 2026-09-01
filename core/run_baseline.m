%% ========================================================================
% ADS-MATLAB Bridge
% run_baseline.m
% Core entry: core/run_baseline.m
%
% Version: 0.6.0
%
% Generic one-click baseline workflow:
%   baseline_doctor -> read_ads_raw -> analyze_baseline
%
% This MAIN/Core version is simulation-type agnostic.
% It does NOT calculate or plot application-specific quantities.
% ========================================================================

clc;

%% Bootstrap the public Bridge Core for this MATLAB session only

BRIDGE_CORE_DIR = fileparts(mfilename('fullpath'));

if ~isfolder(BRIDGE_CORE_DIR)
    error('Bridge Core folder does not exist: %s',BRIDGE_CORE_DIR);
end

addpath(BRIDGE_CORE_DIR,'-begin');

fprintf('\n============================================================\n');
fprintf(' ADS-MATLAB BRIDGE - RUN BASELINE  v0.6.0\n');
fprintf('============================================================\n');

%% ------------------------------------------------------------------------
% 1. Run generic ADS baseline/interface doctor
% -------------------------------------------------------------------------

baseline_doctor;

if ~exist('ADS_BASELINE_REPORT','var')
    error('baseline_doctor did not create ADS_BASELINE_REPORT.');
end

if ~isfield(ADS_BASELINE_REPORT,'step4Passed') || ...
        ~ADS_BASELINE_REPORT.step4Passed
    error('Step 4 did not pass. Baseline analysis will not continue.');
end

%% ------------------------------------------------------------------------
% 2. Parse and summarize the generated RAW file
% -------------------------------------------------------------------------

rawFile = ADS_BASELINE_REPORT.rawFile;
resultDir = fullfile(fileparts(rawFile),'Result');

fprintf('\n[OK] Baseline RAW ready:\n%s\n',rawFile);

BASELINE_RESULT = analyze_baseline(rawFile,resultDir);

%% ------------------------------------------------------------------------
% 3. Final status
% -------------------------------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' BASELINE WORKFLOW FINISHED\n');
fprintf('============================================================\n');

fprintf('\nADS -> temporary CASE -> hpeesofsim -> RAW -> MATLAB\n');
fprintf('generic baseline workflow is complete.\n');

fprintf('\nRAW plots parsed : %d\n',BASELINE_RESULT.plotCount);
fprintf('Variables listed : %d\n',height(BASELINE_RESULT.inventory));

fprintf('\nResult folder:\n%s\n',resultDir);

fprintf('\nBridge Core is ready for application-specific branches.\n');
fprintf('============================================================\n');
