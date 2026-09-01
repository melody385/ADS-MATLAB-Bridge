%% ========================================================================
% ADS-MATLAB Bridge
% run_baseline.m
%
% Version: 0.5.0
%
% One-click baseline workflow:
%   baseline_doctor -> read_ads_raw -> analyze_baseline
%
% Optional target configuration can be added in cfg below.
% Generic GitHub default = no hard design target.
% ========================================================================

clc;

fprintf('\n============================================================\n');
fprintf(' ADS-MATLAB BRIDGE - RUN BASELINE  v0.5.0\n');
fprintf('============================================================\n');

cfg = struct();

% Example only:
% cfg.passbandGHz = [0.5 3.0];
% cfg.stopbandGHz = [4.0 10.0];
% cfg.s11MaxdB    = -12;
% cfg.s21MinPBdB  = -1;
% cfg.s21MaxSBdB  = -18;

baseline_doctor;

if ~exist('ADS_BASELINE_REPORT','var')
    error('baseline_doctor did not create ADS_BASELINE_REPORT.');
end

if ~ADS_BASELINE_REPORT.step4Passed
    error('Step 4 did not pass. Baseline analysis will not continue.');
end

rawFile = ADS_BASELINE_REPORT.rawFile;
resultDir = fullfile(fileparts(rawFile),'Result');

fprintf('\n[OK] Baseline RAW ready:\n%s\n',rawFile);

BASELINE_RESULT = analyze_baseline(rawFile,resultDir,cfg);

fprintf('\n============================================================\n');
fprintf(' BASELINE WORKFLOW FINISHED\n');
fprintf('============================================================\n');
fprintf('\nADS -> RAW -> MATLAB -> plot/data/save is complete.\n');

if BASELINE_RESULT.sParameterDetected
    fprintf('\nS-parameter plot detected and visualized.\n');
end

fprintf('\nResult folder:\n%s\n',resultDir);
fprintf('\nNext development branch:\n');
fprintf('  Parameter writer + objective function + optimizer\n');
fprintf('============================================================\n');
