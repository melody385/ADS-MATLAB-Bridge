%% ========================================================================
% ADS-MATLAB Bridge - SP Filter Branch
% sp_baseline.m
% Location: sp/sp_baseline.m
%
% Version: 0.1.0
%
% S-parameter baseline workflow:
%   Common Bridge Core run_baseline
%       ->
%   analyze_sparameters
%
% User entry point for the sp-filter branch.
% ========================================================================

clc;

%% Bootstrap Bridge Core and SP internals for this MATLAB session only

SP_DIR = fileparts(mfilename('fullpath'));
SP_REPO_ROOT = fileparts(SP_DIR);
SP_CORE_DIR = fullfile(SP_REPO_ROOT,'core');
SP_INTERNAL_DIR = fullfile(SP_DIR,'internal');

if ~isfolder(SP_CORE_DIR)
    error('Bridge Core folder does not exist: %s',SP_CORE_DIR);
end

if ~isfolder(SP_INTERNAL_DIR)
    error('SP internal folder does not exist: %s',SP_INTERNAL_DIR);
end

addpath(SP_CORE_DIR,'-begin');
addpath(SP_INTERNAL_DIR,'-begin');

fprintf('\n============================================================\n');
fprintf(' ADS-MATLAB BRIDGE - SP BASELINE  v0.1.0\n');
fprintf('============================================================\n');

%% ------------------------------------------------------------------------
% 1. Run the common Bridge Core baseline workflow
% -------------------------------------------------------------------------

run_baseline;

if ~exist('BASELINE_RESULT','var')
    error('Common run_baseline did not create BASELINE_RESULT.');
end

if ~isfield(BASELINE_RESULT,'raw') || isempty(BASELINE_RESULT.raw)
    error('BASELINE_RESULT does not contain parsed RAW data.');
end

%% ------------------------------------------------------------------------
% 2. Run S-parameter-specific analysis
% -------------------------------------------------------------------------

spResultDir = fullfile(BASELINE_RESULT.outputDir,'SP_Filter');

SP_BASELINE_RESULT = analyze_sparameters( ...
    BASELINE_RESULT.raw, ...
    spResultDir);

%% ------------------------------------------------------------------------
% 3. Ensure the user variable configuration exists
% -------------------------------------------------------------------------

variableFile = fullfile( ...
    char(ADS_WORKSPACE), ...
    'ADS_MATLAB_BRIDGE_Run', ...
    'Config', ...
    'sp_variables.m');

if isfile(variableFile)
    fprintf('\n[KEEP] Existing variable configuration was not changed:\n%s\n', ...
        variableFile);
else
    generatorFile = fullfile( ...
        SP_INTERNAL_DIR, ...
        'generate_filter_variables.m');

    if ~isfile(generatorFile)
        error('generate_filter_variables.m was not found: %s',generatorFile);
    end

    fprintf('\n[CREATE] sp_variables.m does not exist; generating it now.\n');
    run(generatorFile);
end

if ~isfile(variableFile)
    error('sp_variables.m was not generated: %s',variableFile);
end

FILTER_VARIABLES_FILE = variableFile;

%% ------------------------------------------------------------------------
% 4. Final status and open the user configuration
% -------------------------------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' SP BASELINE WORKFLOW FINISHED\n');
fprintf('============================================================\n');

fprintf('\nCommon Bridge Core : PASSED\n');
fprintf('S-parameter parser : PASSED\n');
fprintf('S11/S21 plot       : GENERATED\n');

fprintf('\nFrequency range : %.6f to %.6f GHz\n', ...
    min(SP_BASELINE_RESULT.freqGHz), ...
    max(SP_BASELINE_RESULT.freqGHz));

fprintf('\nSP result folder:\n%s\n',spResultDir);

fprintf('\nNext step:\n');
fprintf('  Review and edit sp_variables.m.\n');

fprintf('\nVariable configuration:\n%s\n',variableFile);

fprintf('============================================================\n');

try
    edit(variableFile);
catch ME
    fprintf('\n[NOTICE] MATLAB editor could not open sp_variables.m: %s\n', ...
        ME.message);
    fprintf('Open it manually:\n%s\n',variableFile);
end
