%% ========================================================================
% ADS-MATLAB Bridge - SP Filter Branch
% sp_check.m
% Location: sp/sp_check.m
%
% Version: 0.2.0
%
% Automatic parameter-interface test:
%   1. Load and validate sp_variables.m
%   2. Automatically choose one enabled variable
%   3. Move it by exactly one user-defined Step
%   4. Write the value into a TEMP CASE only
%   5. Re-read the CASE and verify the value
%   6. Run ADS
%   7. Read the new S11/S21
%   8. Compare numerically with the baseline
%
% No plot is generated.
%
% PASS means:
%   parameter write -> ADS simulation -> RAW -> S-parameter result
%   all changed successfully.
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
fprintf(' ADS-MATLAB BRIDGE - SP PARAMETER INTERFACE TEST  v0.2.0\n');
fprintf('============================================================\n');

%% ------------------------------------------------------------------------
% 1. Required common environment
% -------------------------------------------------------------------------

if ~exist('ADS_WORKSPACE','var') || ~isfolder(char(ADS_WORKSPACE))
    error('ADS_WORKSPACE is unavailable. Run doctor_workspace.m first.');
end

ADS_WORKSPACE = char(ADS_WORKSPACE);

if ~exist('ADS_SIM','var') || ~isfile(char(ADS_SIM))
    error('ADS_SIM is unavailable. Run doctor_ads.m and doctor_simulator.m first.');
end

ADS_SIM = char(ADS_SIM);

%% ------------------------------------------------------------------------
% 2. Resolve user variable configuration
% -------------------------------------------------------------------------

if exist('FILTER_VARIABLES_FILE','var') && isfile(char(FILTER_VARIABLES_FILE))
    configFile = char(FILTER_VARIABLES_FILE);
else
    configFile = fullfile( ...
        ADS_WORKSPACE, ...
        'ADS_MATLAB_BRIDGE_Run', ...
        'Config', ...
        'sp_variables.m');
end

FILTER_VARS = validate_filter_variables(configFile);

%% ------------------------------------------------------------------------
% 3. Resolve baseline SP result
% -------------------------------------------------------------------------

baseline = [];

if exist('SP_BASELINE_RESULT','var') && isstruct(SP_BASELINE_RESULT)
    baseline = SP_BASELINE_RESULT;
else
    baselineFile = fullfile( ...
        ADS_WORKSPACE, ...
        'ADS_MATLAB_BRIDGE_Run', ...
        'Baseline', ...
        'Result', ...
        'SP_Filter', ...
        'sp_baseline_result.mat');

    if isfile(baselineFile)
        S = load(baselineFile,'result');
        baseline = S.result;
    end
end

requiredBaselineFields = {'freqGHz','S11','S21','S11dB','S21dB'};

if isempty(baseline)
    error('SP baseline result is unavailable. Run sp_baseline.m first.');
end

for k = 1:numel(requiredBaselineFields)
    if ~isfield(baseline,requiredBaselineFields{k})
        error('SP baseline is missing field: %s',requiredBaselineFields{k});
    end
end

%% ------------------------------------------------------------------------
% 4. Resolve the already-patched common baseline CASE
% -------------------------------------------------------------------------

baseCase = '';

if exist('ADS_BASELINE_REPORT','var') && isstruct(ADS_BASELINE_REPORT)
    if isfield(ADS_BASELINE_REPORT,'caseNetlist')
        candidate = char(ADS_BASELINE_REPORT.caseNetlist);
        if isfile(candidate)
            baseCase = candidate;
        end
    end
end

if isempty(baseCase)

    baselineDir = fullfile( ...
        ADS_WORKSPACE, ...
        'ADS_MATLAB_BRIDGE_Run', ...
        'Baseline');

    hits = dir(fullfile(baselineDir,'*_BRIDGE_CASE.log'));

    if ~isempty(hits)
        [~,idx] = max([hits.datenum]);
        baseCase = fullfile(hits(idx).folder,hits(idx).name);
    end
end

if isempty(baseCase) || ~isfile(baseCase)
    error('No baseline temporary CASE was found. Run sp_baseline.m first.');
end

%% ------------------------------------------------------------------------
% 5. Automatically choose one enabled variable and move by one Step
% -------------------------------------------------------------------------

enabledIdx = find(FILTER_VARS.Enable);

testIndex = 0;
testValue = NaN;
directionText = '';

for q = 1:numel(enabledIdx)

    k = enabledIdx(q);

    x0 = FILTER_VARS.Initial(k);
    st = FILTER_VARS.Step(k);
    lb = FILTER_VARS.Lower(k);
    ub = FILTER_VARS.Upper(k);

    tol = 1e-12 * max(1,max(abs([x0 st lb ub])));

    if x0 + st <= ub + tol
        testIndex = k;
        testValue = x0 + st;
        directionText = '+1 step';
        break;
    elseif x0 - st >= lb - tol
        testIndex = k;
        testValue = x0 - st;
        directionText = '-1 step';
        break;
    end
end

if testIndex == 0
    error(['No enabled variable has room for a one-step test move. ' ...
           'Edit Lower/Upper/Step in sp_variables.m.']);
end

testName = FILTER_VARS.Name(testIndex);
initialValue = FILTER_VARS.Initial(testIndex);
testStep = FILTER_VARS.Step(testIndex);

fprintf('\nAutomatic test variable:\n');
fprintf('  Name    : %s\n',testName);
fprintf('  Initial : %.12g\n',initialValue);
fprintf('  Step    : %.12g\n',testStep);
fprintf('  Test    : %.12g  (%s)\n',testValue,directionText);

%% ------------------------------------------------------------------------
% 6. Create and verify modified TEMP CASE
% -------------------------------------------------------------------------

testDir = fullfile( ...
    ADS_WORKSPACE, ...
    'ADS_MATLAB_BRIDGE_Run', ...
    'SP_Filter', ...
    'InterfaceTest');

if ~isfolder(testDir)
    mkdir(testDir);
end

testCase = fullfile(testDir,'SP_PARAMETER_TEST_CASE.log');
testRaw = fullfile(testDir,'SP_PARAMETER_TEST.raw');
testLog = fullfile(testDir,'SP_PARAMETER_TEST_output.txt');

filesToDelete = {testCase,testRaw,testLog};

for k = 1:numel(filesToDelete)
    if isfile(filesToDelete{k})
        delete(filesToDelete{k});
    end
end

WRITE_REPORT = write_ads_variables( ...
    baseCase, ...
    testCase, ...
    testName, ...
    testValue);

if ~WRITE_REPORT.passed
    error('Temporary CASE write verification did not pass.');
end

%% ------------------------------------------------------------------------
% 7. Run ADS
% -------------------------------------------------------------------------

oldDir = pwd;
cleanupDir = onCleanup(@() cd(oldDir));
cd(ADS_WORKSPACE);

ADS_COMMAND = sprintf( ...
    '"%s" -r "%s" "%s"', ...
    ADS_SIM, ...
    testRaw, ...
    testCase);

tic;
[ADS_STATUS,ADS_OUTPUT] = system(ADS_COMMAND);
ADS_TIME = toc;

fid = fopen(testLog,'w');

if fid >= 0
    fprintf(fid,'ADS-MATLAB Bridge SP parameter interface test\n');
    fprintf(fid,'Version: 0.2.0\n\n');
    fprintf(fid,'Variable: %s\n',testName);
    fprintf(fid,'Initial: %.15g\n',initialValue);
    fprintf(fid,'Test value: %.15g\n',testValue);
    fprintf(fid,'Step: %.15g\n\n',testStep);
    fprintf(fid,'Command:\n%s\n\n',ADS_COMMAND);
    fprintf(fid,'Exit status: %d\n',ADS_STATUS);
    fprintf(fid,'Elapsed: %.9f s\n\n',ADS_TIME);
    fprintf(fid,'================ ADS OUTPUT ================\n\n');
    fprintf(fid,'%s',ADS_OUTPUT);
    fclose(fid);
end

if ADS_STATUS ~= 0
    error('ADS test simulation failed with exit status %d. See: %s', ...
        ADS_STATUS,testLog);
end

if ~isfile(testRaw)
    error('ADS returned status 0 but the test RAW file was not generated.');
end

%% ------------------------------------------------------------------------
% 8. Parse new RAW and extract S11/S21 WITHOUT plotting
% -------------------------------------------------------------------------

testRawData = read_ads_raw(testRaw);

[testFreqGHz,testS11,testS21,testS11dB,testS21dB] = ...
    extractSP(testRawData);

baseFreqGHz = baseline.freqGHz(:);
baseS11 = baseline.S11(:);
baseS21 = baseline.S21(:);
baseS11dB = baseline.S11dB(:);
baseS21dB = baseline.S21dB(:);

if numel(testFreqGHz) ~= numel(baseFreqGHz)
    error('Baseline and test frequency grids have different point counts.');
end

freqTol = 1e-9 * max(1,max(abs(baseFreqGHz)));

if max(abs(testFreqGHz-baseFreqGHz)) > freqTol
    error('Baseline and test frequency grids are different.');
end

%% ------------------------------------------------------------------------
% 9. Numerically prove that the simulated result changed
% -------------------------------------------------------------------------

maxComplexS11Diff = max(abs(testS11-baseS11));
maxComplexS21Diff = max(abs(testS21-baseS21));

maxS11dBDiff = max(abs(testS11dB-baseS11dB));
maxS21dBDiff = max(abs(testS21dB-baseS21dB));

complexTol = 1e-10;
dBTol = 1e-6;

resultChanged = ...
    (maxComplexS11Diff > complexTol) || ...
    (maxComplexS21Diff > complexTol) || ...
    (maxS11dBDiff > dBTol) || ...
    (maxS21dBDiff > dBTol);

SP_PARAMETER_TEST_REPORT = struct();
SP_PARAMETER_TEST_REPORT.version = '0.2.0';
SP_PARAMETER_TEST_REPORT.variable = testName;
SP_PARAMETER_TEST_REPORT.initialValue = initialValue;
SP_PARAMETER_TEST_REPORT.testValue = testValue;
SP_PARAMETER_TEST_REPORT.step = testStep;
SP_PARAMETER_TEST_REPORT.caseFile = testCase;
SP_PARAMETER_TEST_REPORT.rawFile = testRaw;
SP_PARAMETER_TEST_REPORT.outputLog = testLog;
SP_PARAMETER_TEST_REPORT.adsStatus = ADS_STATUS;
SP_PARAMETER_TEST_REPORT.adsElapsed = ADS_TIME;
SP_PARAMETER_TEST_REPORT.maxComplexS11Diff = maxComplexS11Diff;
SP_PARAMETER_TEST_REPORT.maxComplexS21Diff = maxComplexS21Diff;
SP_PARAMETER_TEST_REPORT.maxS11dBDiff = maxS11dBDiff;
SP_PARAMETER_TEST_REPORT.maxS21dBDiff = maxS21dBDiff;
SP_PARAMETER_TEST_REPORT.resultChanged = resultChanged;
SP_PARAMETER_TEST_REPORT.passed = ...
    WRITE_REPORT.passed && ADS_STATUS == 0 && resultChanged;

save(fullfile(testDir,'SP_PARAMETER_TEST_REPORT.mat'), ...
    'SP_PARAMETER_TEST_REPORT');

%% ------------------------------------------------------------------------
% 10. Final result: no graph, only a clear verdict
% -------------------------------------------------------------------------

fprintf('\n============================================================\n');

if SP_PARAMETER_TEST_REPORT.passed

    fprintf(' SP PARAMETER INTERFACE TEST PASSED\n');
    fprintf('============================================================\n');
    fprintf('\nParameter write -> ADS -> RAW -> S11/S21 change verified.\n');
    fprintf('Tested variable: %s  %.12g -> %.12g\n', ...
        testName,initialValue,testValue);

else

    fprintf(' SP PARAMETER INTERFACE TEST FAILED\n');
    fprintf('============================================================\n');
    fprintf('\nThe parameter was written and ADS ran, but no measurable\n');
    fprintf('S11/S21 change was detected.\n');
    fprintf('\nTested variable: %s  %.12g -> %.12g\n', ...
        testName,initialValue,testValue);
    fprintf('Max |Delta S11|    : %.6g\n',maxComplexS11Diff);
    fprintf('Max |Delta S21|    : %.6g\n',maxComplexS21Diff);
    fprintf('Max Delta S11 dB   : %.6g dB\n',maxS11dBDiff);
    fprintf('Max Delta S21 dB   : %.6g dB\n',maxS21dBDiff);

end

fprintf('\nTest folder:\n%s\n',testDir);
fprintf('============================================================\n');

if ~SP_PARAMETER_TEST_REPORT.passed
    error('SP parameter interface test did not pass.');
end


function [freqGHz,S11,S21,S11dB,S21dB] = extractSP(raw)

spPlot = 0;

for p = 1:raw.plotCount

    names = string({raw.plots(p).variables.name});

    hasFreq = any(strcmp(names,'freq'));
    hasS11 = any(strcmp(names,'S[1,1]')) || ...
             any(strcmp(names,'S(1,1)')) || ...
             any(strcmpi(names,'S11'));
    hasS21 = any(strcmp(names,'S[2,1]')) || ...
             any(strcmp(names,'S(2,1)')) || ...
             any(strcmpi(names,'S21'));

    if hasFreq && hasS11 && hasS21
        spPlot = p;
        break;
    end
end

if spPlot == 0
    error('No RAW plot containing freq + S11 + S21 was found.');
end

freq = ads_raw_get(raw,'freq',spPlot);
S11 = getAny(raw,spPlot,{'S[1,1]','S(1,1)','S11'});
S21 = getAny(raw,spPlot,{'S[2,1]','S(2,1)','S21'});

freq = real(freq(:));

if max(abs(freq)) > 1e6
    freqGHz = freq/1e9;
else
    freqGHz = freq;
end

S11 = S11(:);
S21 = S21(:);

S11dB = 20*log10(max(abs(S11),1e-15));
S21dB = 20*log10(max(abs(S21),1e-15));

end


function value = getAny(raw,plotIndex,names)

for k = 1:numel(names)
    try
        value = ads_raw_get(raw,names{k},plotIndex);
        return;
    catch
    end
end

error('None of the requested S-parameter names were found.');

end
