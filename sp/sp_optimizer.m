%% ========================================================================
% ADS-MATLAB Bridge - SP Filter Branch
% sp_optimizer.m
% Location: sp/sp_optimizer.m
%
% Version: 0.2.1
%
% USER ENTRY POINT
%
% Generic S-parameter PSO optimizer.
%
% This revision fixes MATLAB script/local-function scope isolation by
% explicitly passing all candidate-evaluation dependencies through CTX.
%
% Before running:
%   1. doctor_ads.m
%   2. doctor_workspace.m
%   3. doctor_simulator.m
%   4. sp_baseline.m
%      -> generates/opens sp_variables.m when needed
%   5. sp_check.m
%   6. edit sp_targets.m and sp_constraints.m
%
% Then run:
%   sp_optimizer.m
%
% Formal ADS netlist is NEVER modified.
% ========================================================================

clc;

%% Bootstrap Bridge Core and SP internals for this MATLAB session only

spDir = fileparts(mfilename('fullpath'));
repoDir = fileparts(spDir);
coreDir = fullfile(repoDir,'core');
internalDir = fullfile(spDir,'internal');

if ~isfolder(coreDir)
    error('Bridge Core folder does not exist: %s',coreDir);
end

if ~isfolder(internalDir)
    error('SP internal folder does not exist: %s',internalDir);
end

addpath(coreDir,'-begin');
addpath(internalDir,'-begin');

fprintf('\n============================================================\n');
fprintf(' ADS-MATLAB BRIDGE - SP OPTIMIZER  v0.2.1\n');
fprintf('============================================================\n');

%% ------------------------------------------------------------------------
% OPTIONAL ALGORITHM SETTINGS
%
% Keep the small values below for the first closed-loop test.
% After the workflow is verified, increase them for a formal optimization.
% -------------------------------------------------------------------------

OPT.swarmSize = 4;
OPT.maxIterations = 2;

OPT.inertia = 0.72;
OPT.cognitive = 1.49;
OPT.social = 1.49;

OPT.randomSeed = 1;
OPT.stopOnFirstPass = true;

% Any ADS / RAW / candidate-evaluation failure gets this large objective.
OPT.failedCaseObjective = 1e12;

% Geometry/parameter-constraint rejection happens BEFORE ADS.
% Rejected candidates receive a large but distinguishable penalty.
OPT.constraintPenaltyBase = 1e9;

rng(OPT.randomSeed,'twister');

%% ------------------------------------------------------------------------
% 1. Resolve common ADS environment
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
% 2. Load user variable configuration
% -------------------------------------------------------------------------

if exist('FILTER_VARIABLES_FILE','var') && isfile(char(FILTER_VARIABLES_FILE))
    variableFile = char(FILTER_VARIABLES_FILE);
else
    variableFile = fullfile( ...
        ADS_WORKSPACE, ...
        'ADS_MATLAB_BRIDGE_Run', ...
        'Config', ...
        'sp_variables.m');
end

FILTER_VARS = validate_filter_variables(variableFile);

enabledRows = find(FILTER_VARS.Enable);

if isempty(enabledRows)
    error('No optimization variable has Enable=true.');
end

VAR = FILTER_VARS(enabledRows,:);

names = strtrim(string(VAR.Name));
x0 = VAR.Initial(:).';
lb = VAR.Lower(:).';
ub = VAR.Upper(:).';
step = VAR.Step(:).';

nVar = numel(x0);

%% ------------------------------------------------------------------------
% 3. Load generic S-parameter target configuration
% -------------------------------------------------------------------------

targetFile = fullfile(spDir,'sp_targets.m');

if ~isfile(targetFile)
    error('sp_targets.m was not found: %s',targetFile);
end

TARGET = validate_filter_targets(targetFile);

%% ------------------------------------------------------------------------
% 3B. Load optional geometry / parameter constraints
% -------------------------------------------------------------------------

constraintFile = fullfile(spDir,'sp_constraints.m');

if ~isfile(constraintFile)
    error('sp_constraints.m was not found: %s',constraintFile);
end

CONSTRAINTS = filter_constraint_engine( ...
    "validate", ...
    constraintFile, ...
    FILTER_VARS);

%% ------------------------------------------------------------------------
% 4. Load SP baseline result
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

if isempty(baseline)
    error('SP baseline is unavailable. Run sp_baseline.m first.');
end

requiredBaselineFields = {'freqGHz','S11','S21','S11dB','S21dB'};

for k = 1:numel(requiredBaselineFields)
    if ~isfield(baseline,requiredBaselineFields{k})
        error('SP baseline is missing field: %s',requiredBaselineFields{k});
    end
end

%% ------------------------------------------------------------------------
% 5. Resolve baseline TEMP CASE
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
    error('Baseline TEMP CASE was not found. Run sp_baseline.m first.');
end

%% ------------------------------------------------------------------------
% 6. Verify target evaluator on current baseline
% -------------------------------------------------------------------------

BASELINE_TARGET_RESULT = evaluate_sp_filter( ...
    baseline.freqGHz, ...
    baseline.S11dB, ...
    baseline.S21dB, ...
    TARGET);

fprintf('\n------------------------------------------------------------\n');
fprintf(' CURRENT BASELINE VS TARGETS\n');
fprintf('------------------------------------------------------------\n');
fprintf('Active limits    : %d\n',BASELINE_TARGET_RESULT.constraintCount);
fprintf('Passed           : %d\n',BASELINE_TARGET_RESULT.passCount);
fprintf('Failed           : %d\n',BASELINE_TARGET_RESULT.failCount);
fprintf('Total violation  : %.9g dB\n',BASELINE_TARGET_RESULT.totalViolation);
fprintf('Maximum violation: %.9g dB\n',BASELINE_TARGET_RESULT.maxViolation);
fprintf('Objective        : %.9g\n',BASELINE_TARGET_RESULT.objective);

BASELINE_CONSTRAINT_RESULT = filter_constraint_engine( ...
    "evaluate", ...
    FILTER_VARS.Name, ...
    FILTER_VARS.Initial, ...
    CONSTRAINTS);

fprintf('\n------------------------------------------------------------\n');
fprintf(' CURRENT BASELINE VS GEOMETRY/PARAMETER CONSTRAINTS\n');
fprintf('------------------------------------------------------------\n');
fprintf('Active constraints : %d\n',BASELINE_CONSTRAINT_RESULT.constraintCount);
fprintf('Passed             : %d\n',BASELINE_CONSTRAINT_RESULT.passCount);
fprintf('Failed             : %d\n',BASELINE_CONSTRAINT_RESULT.failCount);

if BASELINE_CONSTRAINT_RESULT.failCount > 0
    fprintf('[INFO] The baseline violates one or more user constraints.\n');
    fprintf('       Optimization may still search for a feasible candidate.\n');
end

if BASELINE_TARGET_RESULT.allPassed && BASELINE_CONSTRAINT_RESULT.allPassed
    
    fprintf('\n[INFO] The current baseline already satisfies all configured targets and constraints.\n');
    
    if OPT.stopOnFirstPass
        fprintf('Optimization stopped because stopOnFirstPass = true.\n');
        fprintf('============================================================\n');
        return;
    end
end

%% ------------------------------------------------------------------------
% 7. Verify sp_variables Initial values match baseline CASE
% -------------------------------------------------------------------------

checkCaseInitialValues(baseCase,names,x0);

fprintf('\n[OK] Enabled-variable Initial values match the baseline CASE.\n');

%% ------------------------------------------------------------------------
% 8. Prepare optimization run directory
% -------------------------------------------------------------------------

stamp = datestr(now,'yyyymmdd_HHMMSS');

runDir = fullfile( ...
    ADS_WORKSPACE, ...
    'ADS_MATLAB_BRIDGE_Run', ...
    'SP_Filter', ...
    'Optimization', ...
    stamp);

workDir = fullfile(runDir,'Work');
bestDir = fullfile(runDir,'Best');

mkdir(workDir);
mkdir(bestDir);

workCase = fullfile(workDir,'SP_OPT_WORK_CASE.log');
workRaw = fullfile(workDir,'SP_OPT_WORK.raw');
workLog = fullfile(workDir,'SP_OPT_WORK_output.txt');

bestCase = fullfile(bestDir,'best_case.log');
bestRaw = fullfile(bestDir,'best.raw');
bestLog = fullfile(bestDir,'best_ads_output.txt');

fprintf('\nOptimization run folder:\n%s\n',runDir);

%% ------------------------------------------------------------------------
% 9. Build explicit candidate-evaluation context
%
% Local functions in MATLAB scripts DO NOT share the script workspace.
% Everything required by evaluateCandidate is therefore passed in CTX.
% -------------------------------------------------------------------------

CTX = struct();

CTX.version = '0.2.0';

CTX.OPT = OPT;

CTX.ADS_WORKSPACE = ADS_WORKSPACE;
CTX.ADS_SIM = ADS_SIM;

CTX.baseCase = baseCase;
CTX.names = names;
CTX.TARGET = TARGET;
CTX.CONSTRAINTS = CONSTRAINTS;

CTX.workCase = workCase;
CTX.workRaw = workRaw;
CTX.workLog = workLog;

%% ------------------------------------------------------------------------
% 10. Initialize PSO
% -------------------------------------------------------------------------

swarmSize = max(2,round(OPT.swarmSize));
maxIterations = max(1,round(OPT.maxIterations));

X = repmat(lb,swarmSize,1) + ...
    rand(swarmSize,nVar).*repmat(ub-lb,swarmSize,1);

% Force particle 1 to be the exact current/baseline parameter set.
X(1,:) = x0;

for i = 1:swarmSize
    X(i,:) = snapToUserGrid(X(i,:),x0,lb,ub,step);
end

Vmax = 0.25*(ub-lb);

V = (2*rand(swarmSize,nVar)-1).* ...
    repmat(Vmax,swarmSize,1);

PbestX = X;
PbestObj = inf(swarmSize,1);

GbestX = x0;
GbestObj = inf;
GbestResult = [];

GbestFreqGHz = [];
GbestS11 = [];
GbestS21 = [];
GbestS11dB = [];
GbestS21dB = [];

evalCount = 0;
failedCount = 0;
constraintRejectedCount = 0;
stopNow = false;

historyIteration = zeros(0,1);
historyBestObjective = zeros(0,1);
historyTotalViolation = zeros(0,1);
historyMaxViolation = zeros(0,1);
historyPassed = false(0,1);
historyEvalCount = zeros(0,1);

%% ------------------------------------------------------------------------
% 11. PSO iterations
% -------------------------------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' PSO START\n');
fprintf('============================================================\n');
fprintf('Variables  : %d\n',nVar);
fprintf('Particles  : %d\n',swarmSize);
fprintf('Iterations : %d\n',maxIterations);
fprintf('============================================================\n');

for iter = 1:maxIterations
    
    fprintf('\nIteration %d / %d\n',iter,maxIterations);
    
    for i = 1:swarmSize
        
        xi = snapToUserGrid(X(i,:),x0,lb,ub,step);
        
        % Build the complete parameter vector, including disabled/fixed
        % parameters, so constraints may reference ANY configured variable.
        allCandidateValues = FILTER_VARS.Initial;
        
        for kk = 1:numel(enabledRows)
            allCandidateValues(enabledRows(kk)) = xi(kk);
        end
        
        constraintResult = filter_constraint_engine( ...
            "evaluate", ...
            FILTER_VARS.Name, ...
            allCandidateValues, ...
            CONSTRAINTS);
        
        if ~constraintResult.allPassed
            
            % Hard pre-ADS rejection: no simulator call is spent.
            obj = OPT.constraintPenaltyBase + constraintResult.objective;
            evalResult = [];
            spData = struct();
            caseOK = false;
            failureMessage = "";
            constraintRejectedCount = constraintRejectedCount + 1;
            
            fprintf(['  Particle %d/%d : CONSTRAINT REJECTED, ' ...
                'violations=%d, total=%.6g\n'], ...
                i,swarmSize, ...
                constraintResult.failCount, ...
                constraintResult.totalViolation);
            
        else
            
            [obj,evalResult,spData,caseOK,failureMessage] = ...
                evaluateCandidate(xi,CTX);
            
            evalCount = evalCount + 1;
            
            if ~caseOK
                failedCount = failedCount + 1;
                
                fprintf('  Particle %d/%d : FAILED',i,swarmSize);
                
                if strlength(failureMessage) > 0
                    fprintf(' - %s',failureMessage);
                end
                
                fprintf('\n');
            else
                fprintf(['  Particle %d/%d : obj=%.6g, ' ...
                    'total=%.6g dB, max=%.6g dB\n'], ...
                    i,swarmSize,obj, ...
                    evalResult.totalViolation, ...
                    evalResult.maxViolation);
            end
        end
        
        if obj < PbestObj(i)
            PbestObj(i) = obj;
            PbestX(i,:) = xi;
        end
        
        if caseOK && obj < GbestObj
            
            GbestObj = obj;
            GbestX = xi;
            
            if caseOK
                
                GbestResult = evalResult;
                
                GbestFreqGHz = spData.freqGHz;
                GbestS11 = spData.S11;
                GbestS21 = spData.S21;
                GbestS11dB = spData.S11dB;
                GbestS21dB = spData.S21dB;
                
                copyfile(workCase,bestCase);
                copyfile(workRaw,bestRaw);
                
                if isfile(workLog)
                    copyfile(workLog,bestLog);
                end
                
                saveBestArtifacts( ...
                    bestDir, ...
                    FILTER_VARS, ...
                    enabledRows, ...
                    GbestX, ...
                    GbestObj, ...
                    GbestResult, ...
                    GbestFreqGHz, ...
                    GbestS11, ...
                    GbestS21, ...
                    GbestS11dB, ...
                    GbestS21dB);
            end
        end
        
        if caseOK && evalResult.allPassed && OPT.stopOnFirstPass
            stopNow = true;
            break;
        end
    end
    
    if isempty(GbestResult)
        
        bestTotal = NaN;
        bestMax = NaN;
        bestPassed = false;
        
    else
        
        bestTotal = GbestResult.totalViolation;
        bestMax = GbestResult.maxViolation;
        bestPassed = GbestResult.allPassed;
    end
    
    historyIteration(end+1,1) = iter;
    historyBestObjective(end+1,1) = GbestObj;
    historyTotalViolation(end+1,1) = bestTotal;
    historyMaxViolation(end+1,1) = bestMax;
    historyPassed(end+1,1) = bestPassed;
    historyEvalCount(end+1,1) = evalCount;
    
    fprintf('\n  Iteration best objective       : %.9g\n',GbestObj);
    fprintf('  Iteration best total violation : %.9g dB\n',bestTotal);
    fprintf('  Iteration best max violation   : %.9g dB\n',bestMax);
    fprintf('  ADS evaluations                : %d\n',evalCount);
    fprintf('  Failed ADS candidates          : %d\n',failedCount);
    fprintf('  Constraint-rejected candidates : %d\n',constraintRejectedCount);
    
    HISTORY = buildHistoryTable( ...
        historyIteration, ...
        historyBestObjective, ...
        historyTotalViolation, ...
        historyMaxViolation, ...
        historyPassed, ...
        historyEvalCount);
    
    writetable(HISTORY,fullfile(runDir,'optimization_history.csv'));
    
    if stopNow
        fprintf('\n[PASS] A candidate satisfying all configured targets was found.\n');
        break;
    end
    
    %% --------------------------------------------------------------------
    % Velocity / position update
    % ---------------------------------------------------------------------
    
    r1 = rand(swarmSize,nVar);
    r2 = rand(swarmSize,nVar);
    
    V = OPT.inertia*V + ...
        OPT.cognitive*r1.*(PbestX-X) + ...
        OPT.social*r2.*(repmat(GbestX,swarmSize,1)-X);
    
    V = min( ...
        max(V,-repmat(Vmax,swarmSize,1)), ...
        repmat(Vmax,swarmSize,1));
    
    X = X + V;
    
    X = min( ...
        max(X,repmat(lb,swarmSize,1)), ...
        repmat(ub,swarmSize,1));
    
    for i = 1:swarmSize
        X(i,:) = snapToUserGrid(X(i,:),x0,lb,ub,step);
    end
end

%% ------------------------------------------------------------------------
% 12. Final report
% -------------------------------------------------------------------------

if isempty(GbestResult)
    error(['No ADS candidate was evaluated successfully. ' ...
        'Inspect the Work output log in:\n%s'],workDir);
end

bestParameters = buildAllParameterTable( ...
    FILTER_VARS, ...
    enabledRows, ...
    GbestX);

HISTORY = buildHistoryTable( ...
    historyIteration, ...
    historyBestObjective, ...
    historyTotalViolation, ...
    historyMaxViolation, ...
    historyPassed, ...
    historyEvalCount);

SP_OPTIMIZATION_RESULT = struct();

SP_OPTIMIZATION_RESULT.version = '0.2.1';
SP_OPTIMIZATION_RESULT.options = OPT;
SP_OPTIMIZATION_RESULT.targets = TARGET;
SP_OPTIMIZATION_RESULT.constraints = CONSTRAINTS;

SP_OPTIMIZATION_RESULT.runDir = runDir;
SP_OPTIMIZATION_RESULT.variableFile = variableFile;
SP_OPTIMIZATION_RESULT.targetFile = targetFile;
SP_OPTIMIZATION_RESULT.constraintFile = constraintFile;

SP_OPTIMIZATION_RESULT.bestParameters = bestParameters;
SP_OPTIMIZATION_RESULT.bestEvaluation = GbestResult;
SP_OPTIMIZATION_RESULT.bestObjective = GbestObj;

SP_OPTIMIZATION_RESULT.evalCount = evalCount;
SP_OPTIMIZATION_RESULT.failedCount = failedCount;
SP_OPTIMIZATION_RESULT.constraintRejectedCount = constraintRejectedCount;
SP_OPTIMIZATION_RESULT.history = HISTORY;

save( ...
    fullfile(runDir,'SP_OPTIMIZATION_RESULT.mat'), ...
    'SP_OPTIMIZATION_RESULT', ...
    '-v7.3');

fprintf('\n============================================================\n');
fprintf(' SP OPTIMIZATION FINISHED\n');
fprintf('============================================================\n');

fprintf('ADS evaluations      : %d\n',evalCount);
fprintf('Failed ADS candidates : %d\n',failedCount);
fprintf('Constraint rejected   : %d\n',constraintRejectedCount);
fprintf('Best objective       : %.9g\n',GbestObj);
fprintf('Best total violation : %.9g dB\n',GbestResult.totalViolation);
fprintf('Best max violation   : %.9g dB\n',GbestResult.maxViolation);

if GbestResult.allPassed
    fprintf('ALL TARGETS PASSED    : YES\n');
else
    fprintf('ALL TARGETS PASSED    : NO\n');
end

fprintf('\nBest parameters:\n');
disp(bestParameters);

fprintf('Results saved to:\n%s\n',runDir);
fprintf('============================================================\n');


%% ========================================================================
% LOCAL FUNCTIONS
% ========================================================================

function [objective,evalResult,spData,ok,failureMessage] = ...
    evaluateCandidate(x,CTX)

evalResult = [];
spData = struct();
ok = false;
failureMessage = "";

objective = CTX.OPT.failedCaseObjective;

try
    
    %% --------------------------------------------------------------------
    % Clear previous working files
    % ---------------------------------------------------------------------
    
    files = {CTX.workCase,CTX.workRaw,CTX.workLog};
    
    for ff = 1:numel(files)
        
        if isfile(files{ff})
            delete(files{ff});
        end
    end
    
    %% --------------------------------------------------------------------
    % Write this particle into TEMP CASE
    % ---------------------------------------------------------------------
    
    write_ads_variables( ...
        CTX.baseCase, ...
        CTX.workCase, ...
        CTX.names, ...
        x(:));
    
    %% --------------------------------------------------------------------
    % Run ADS
    % ---------------------------------------------------------------------
    
    oldDir = pwd;
    cleanupDir = onCleanup(@() cd(oldDir));
    
    cd(CTX.ADS_WORKSPACE);
    
    cmd = sprintf( ...
        '"%s" -r "%s" "%s"', ...
        CTX.ADS_SIM, ...
        CTX.workRaw, ...
        CTX.workCase);
    
    tic;
    [status,output] = system(cmd);
    elapsed = toc;
    
    fid = fopen(CTX.workLog,'w');
    
    if fid >= 0
        
        fprintf(fid,'ADS-MATLAB Bridge SP optimization candidate\n');
        fprintf(fid,'Version: 0.2.1\n\n');
        
        fprintf(fid,'Command:\n%s\n\n',cmd);
        fprintf(fid,'Exit status: %d\n',status);
        fprintf(fid,'Elapsed: %.9f s\n\n',elapsed);
        
        fprintf(fid,'================ ADS OUTPUT ================\n\n');
        fprintf(fid,'%s',output);
        
        fclose(fid);
    end
    
    if status ~= 0
        
        failureMessage = sprintf('ADS exit status %d',status);
        return;
    end
    
    if ~isfile(CTX.workRaw)
        
        failureMessage = "ADS returned 0 but RAW was not generated";
        return;
    end
    
    %% --------------------------------------------------------------------
    % RAW -> S11/S21 -> target evaluator
    % ---------------------------------------------------------------------
    
    raw = read_ads_raw(CTX.workRaw);
    
    [freqGHz,S11,S21,S11dB,S21dB] = extractSP(raw);
    
    evalResult = evaluate_sp_filter( ...
        freqGHz, ...
        S11dB, ...
        S21dB, ...
        CTX.TARGET);
    
    spData.freqGHz = freqGHz;
    spData.S11 = S11;
    spData.S21 = S21;
    spData.S11dB = S11dB;
    spData.S21dB = S21dB;
    
    objective = evalResult.objective;
    ok = true;
    
catch ME
    
    objective = CTX.OPT.failedCaseObjective;
    failureMessage = string(ME.message);
    
    fid = fopen(CTX.workLog,'a');
    
    if fid >= 0
        
        fprintf(fid,'\n\nMATLAB candidate failure:\n%s\n', ...
            getReport(ME,'extended','hyperlinks','off'));
        
        fclose(fid);
    end
end

end


function xq = snapToUserGrid(x,xAnchor,lower,upper,gridStep)

x = min(max(x,lower),upper);

xq = xAnchor + ...
    round((x-xAnchor)./gridStep).*gridStep;

xq = min(max(xq,lower),upper);

% Avoid floating-point tails such as 0.659999999999997.
xq = round(xq,12);

end


function checkCaseInitialValues(caseFile,varNames,initialValues)

txt = fileread(caseFile);

numPattern = ...
    '[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?';

for kk = 1:numel(varNames)
    
    name = char(varNames(kk));
    escaped = regexptranslate('escape',name);
    
    pat = [ ...
        '(?m)^[ \t]*' ...
        escaped ...
        '[ \t]*=[ \t]*(' ...
        numPattern ...
        ')'];
    
    tok = regexp(txt,pat,'tokens');
    
    if numel(tok) ~= 1
        
        error( ...
            'Baseline CASE does not contain exactly one "%s" assignment.', ...
            name);
    end
    
    actual = str2double(tok{1}{1});
    expected = initialValues(kk);
    
    tol = 1e-10 * max(1,max(abs([actual expected])));
    
    if abs(actual-expected) > tol
        
        error([ ...
            'sp_variables Initial mismatch for %s: ' ...
            'config=%.15g, baseline CASE=%.15g. ' ...
            'Regenerate sp_variables.m from the current netlist.'], ...
            name, ...
            expected, ...
            actual);
    end
end

end


function [freqGHz,S11,S21,S11dB,S21dB] = extractSP(raw)

spPlot = 0;

for pp = 1:raw.plotCount
    
    varNames = string({raw.plots(pp).variables.name});
    
    hasFreq = any(strcmp(varNames,'freq'));
    
    hasS11 = ...
        any(strcmp(varNames,'S[1,1]')) || ...
        any(strcmp(varNames,'S(1,1)')) || ...
        any(strcmpi(varNames,'S11'));
    
    hasS21 = ...
        any(strcmp(varNames,'S[2,1]')) || ...
        any(strcmp(varNames,'S(2,1)')) || ...
        any(strcmpi(varNames,'S21'));
    
    if hasFreq && hasS11 && hasS21
        
        spPlot = pp;
        break;
    end
end

if spPlot == 0
    error('No RAW plot containing freq + S11 + S21 was found.');
end

freq = ads_raw_get(raw,'freq',spPlot);

S11 = getAny( ...
    raw, ...
    spPlot, ...
    {'S[1,1]','S(1,1)','S11'});

S21 = getAny( ...
    raw, ...
    spPlot, ...
    {'S[2,1]','S(2,1)','S21'});

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


function value = getAny(raw,plotIndex,candidates)

for kk = 1:numel(candidates)
    
    try
        
        value = ads_raw_get( ...
            raw, ...
            candidates{kk}, ...
            plotIndex);
        
        return;
        
    catch
    end
end

error('Requested S-parameter variable was not found.');

end


function saveBestArtifacts( ...
    bestDir, ...
    FILTER_VARS, ...
    enabledRows, ...
    GbestX, ...
    GbestObj, ...
    GbestResult, ...
    GbestFreqGHz, ...
    GbestS11, ...
    GbestS21, ...
    GbestS11dB, ...
    GbestS21dB)

bestParameters = buildAllParameterTable( ...
    FILTER_VARS, ...
    enabledRows, ...
    GbestX);

writetable( ...
    bestParameters, ...
    fullfile(bestDir,'best_parameters.csv'));

writetable( ...
    GbestResult.details, ...
    fullfile(bestDir,'best_target_details.csv'));

bestSP = table( ...
    GbestFreqGHz, ...
    GbestS11, ...
    GbestS21, ...
    GbestS11dB, ...
    GbestS21dB, ...
    'VariableNames',{ ...
    'Frequency_GHz', ...
    'S11', ...
    'S21', ...
    'S11_dB', ...
    'S21_dB'});

writetable( ...
    bestSP, ...
    fullfile(bestDir,'best_sparameters.csv'));

save( ...
    fullfile(bestDir,'best_result.mat'), ...
    'GbestX', ...
    'GbestObj', ...
    'GbestResult', ...
    'GbestFreqGHz', ...
    'GbestS11', ...
    'GbestS21', ...
    'GbestS11dB', ...
    'GbestS21dB', ...
    '-v7.3');

end


function T = buildAllParameterTable( ...
    FILTER_VARS, ...
    enabledRows, ...
    enabledValues)

finalValue = FILTER_VARS.Initial;

for kk = 1:numel(enabledRows)
    finalValue(enabledRows(kk)) = enabledValues(kk);
end

T = table( ...
    FILTER_VARS.Name, ...
    FILTER_VARS.Initial, ...
    finalValue, ...
    FILTER_VARS.Lower, ...
    FILTER_VARS.Upper, ...
    FILTER_VARS.Step, ...
    FILTER_VARS.Enable, ...
    'VariableNames',{ ...
    'Name', ...
    'Initial', ...
    'Best', ...
    'Lower', ...
    'Upper', ...
    'Step', ...
    'Enable'});

end


function T = buildHistoryTable( ...
    iteration, ...
    bestObjective, ...
    totalViolation, ...
    maxViolation, ...
    allPassed, ...
    adsEvaluations)

T = table( ...
    iteration, ...
    bestObjective, ...
    totalViolation, ...
    maxViolation, ...
    allPassed, ...
    adsEvaluations, ...
    'VariableNames',{ ...
    'Iteration', ...
    'BestObjective', ...
    'TotalViolation_dB', ...
    'MaxViolation_dB', ...
    'AllTargetsPassed', ...
    'ADSEvaluations'});

end
