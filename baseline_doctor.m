%% ========================================================================
% ADS-MATLAB Bridge
% baseline_doctor.m
%
% Version: 0.4.0
%
% STEP 4:
%   Baseline Netlist / RAW Interface Doctor
%
% Recommended run order:
%   1) ads_doctor.m
%   2) workspace_doctor.m
%   3) runtime_doctor.m
%   4) baseline_doctor.m
%
% What this script does:
%   1. Uses ADS_ROOT / ADS_SIM / ADS_WORKSPACE from previous steps
%   2. Lets the user select an ADS-generated netlist
%   3. Inspects the netlist (top design, simulation controller, sweep hints)
%   4. NEVER modifies the original netlist
%   5. Creates a temporary command-line compatible CASE netlist
%   6. Enables Nutmeg RAW output in the temporary CASE
%   7. Removes LinearCollapse ONLY from the temporary CASE when detected
%   8. Runs hpeesofsim from the ADS workspace root
%   9. Verifies that a RAW file is generated
%  10. Inspects the first RAW plot/header and lists returned variables
%  11. Rechecks that the original netlist is unchanged
%
% Important:
%   - This is a baseline/interface test, NOT an optimizer.
%   - No permanent Windows environment changes are made here.
%   - The formal ADS netlist is read-only from this script's perspective.
% ========================================================================

clc;

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' ADS-MATLAB BRIDGE - BASELINE DOCTOR  v0.4.0\n');
fprintf('====================================================================\n');


%% ========================================================================
% 1. Recover ADS_ROOT
% ========================================================================

if ~exist('ADS_ROOT','var')

    envADS = strtrim(getenv('HPEESOF_DIR'));

    if ~isempty(envADS)
        if isfolder(envADS)
            ADS_ROOT = envADS;
        end
    end

end

if ~exist('ADS_ROOT','var')
    error('ADS_ROOT is unavailable. Run ads_doctor.m first.');
end

ADS_ROOT = char(ADS_ROOT);

if isempty(ADS_ROOT)
    error('ADS_ROOT is empty. Run ads_doctor.m first.');
end

if ~isfolder(ADS_ROOT)
    error('ADS_ROOT does not exist: %s',ADS_ROOT);
end

fprintf('\n[OK] ADS root\n');
fprintf('     %s\n',ADS_ROOT);


%% ========================================================================
% 2. Recover ADS simulator
% ========================================================================

if ~exist('ADS_SIM','var')
    ADS_SIM = fullfile(ADS_ROOT,'bin','hpeesofsim.exe');
end

ADS_SIM = char(ADS_SIM);

if ~isfile(ADS_SIM)

    hits = dir(fullfile(ADS_ROOT,'**','hpeesofsim.exe'));

    foundSimulator = '';

    for k = 1:numel(hits)

        if hits(k).isdir
            continue;
        end

        foundSimulator = fullfile(hits(k).folder,hits(k).name);
        break;

    end

    if isempty(foundSimulator)
        error('hpeesofsim.exe was not found inside ADS_ROOT.');
    end

    ADS_SIM = foundSimulator;

end

fprintf('\n[OK] ADS simulator\n');
fprintf('     %s\n',ADS_SIM);


%% ========================================================================
% 3. Recover / select ADS workspace
% ========================================================================

if ~exist('ADS_WORKSPACE','var')

    fprintf('\n[INFO] ADS_WORKSPACE was not found in the MATLAB session.\n');
    fprintf('       Select the ADS workspace folder.\n');

    ADS_WORKSPACE = uigetdir(pwd,'Select ADS Workspace Folder');

    if isequal(ADS_WORKSPACE,0)
        error('Workspace selection cancelled.');
    end

end

ADS_WORKSPACE = char(ADS_WORKSPACE);

if ~isfolder(ADS_WORKSPACE)
    error('ADS workspace does not exist: %s',ADS_WORKSPACE);
end

fprintf('\n[OK] ADS workspace\n');
fprintf('     %s\n',ADS_WORKSPACE);


%% ========================================================================
% 4. Verify command-line runtime before baseline
% ========================================================================

fprintf('\n');
fprintf('--------------------------------------------------------------------\n');
fprintf(' Runtime readiness check\n');
fprintf('--------------------------------------------------------------------\n');

runtimeReady = false;

if exist('ADS_RUNTIME_REPORT','var')

    try
        runtimeReady = logical(ADS_RUNTIME_REPORT.step3Passed);
    catch
        runtimeReady = false;
    end

end

if runtimeReady

    fprintf('[OK] Step 3 runtime report says simulator is ready.\n');

else

    fprintf('[INFO] No valid Step 3 pass report found.\n');
    fprintf('       Performing a direct hpeesofsim startup check...\n');

    startupCmd = sprintf('"%s" -h',ADS_SIM);

    [startupStatus,~] = system(startupCmd);

    if startupStatus ~= 0

        fprintf('\n[FAIL] hpeesofsim startup status = %d\n',startupStatus);

        error(['Simulator runtime is not ready. ' ...
               'Run runtime_doctor.m before baseline_doctor.m.']);

    end

    fprintf('[OK] hpeesofsim startup check passed.\n');

end


%% ========================================================================
% 5. Select ADS-generated netlist
% ========================================================================

fprintf('\n');
fprintf('--------------------------------------------------------------------\n');
fprintf(' Select ADS-generated netlist\n');
fprintf('--------------------------------------------------------------------\n');

defaultNetlist = fullfile(ADS_WORKSPACE,'netlist.log');

if isfile(defaultNetlist)

    fprintf('Default netlist found:\n');
    fprintf('  %s\n',defaultNetlist);

    answer = input('Use this netlist? [Y/n]: ','s');

    if isempty(answer)
        useDefault = true;
    else
        useDefault = strcmpi(strtrim(answer),'y') || ...
                     strcmpi(strtrim(answer),'yes');
    end

else

    useDefault = false;

end

if useDefault

    FORMAL_NETLIST = defaultNetlist;

else

    [fileName,filePath] = uigetfile( ...
        {'*.log;*.net;*.ckt;*.cir','ADS / circuit netlists'; ...
         '*.*','All files'}, ...
        'Select ADS-generated Netlist', ...
        ADS_WORKSPACE);

    if isequal(fileName,0)
        error('Netlist selection cancelled.');
    end

    FORMAL_NETLIST = fullfile(filePath,fileName);

end

if ~isfile(FORMAL_NETLIST)
    error('Selected netlist does not exist: %s',FORMAL_NETLIST);
end

fprintf('\n[OK] Formal netlist\n');
fprintf('     %s\n',FORMAL_NETLIST);


%% ========================================================================
% 6. Read and inspect formal netlist
% ========================================================================

FORMAL_TEXT_BEFORE = fileread(FORMAL_NETLIST);

if isempty(strtrim(FORMAL_TEXT_BEFORE))
    error('Selected netlist is empty.');
end

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' NETLIST INSPECTION\n');
fprintf('====================================================================\n');

% Top design
topDesign = '';

tok = regexp( ...
    FORMAL_TEXT_BEFORE, ...
    'TopDesignName\s*=\s*"([^"]+)"', ...
    'tokens','once');

if ~isempty(tok)
    topDesign = tok{1};
end

if isempty(topDesign)

    tok = regexp( ...
        FORMAL_TEXT_BEFORE, ...
        '(?m)^\s*;\s*Top Design:\s*"([^"]+)"', ...
        'tokens','once');

    if ~isempty(tok)
        topDesign = tok{1};
    end

end

if isempty(topDesign)
    fprintf('Top design       : <not detected>\n');
else
    fprintf('Top design       : %s\n',topDesign);
end

% Simulation controllers
simTypes = {};

controllerPatterns = {
    'S_Param:'     'S-Parameter'
    'HB:'          'Harmonic Balance'
    'LSSP:'        'Large-Signal S-Parameter'
    'Transient:'   'Transient'
    'Tran:'        'Transient'
    'AC:'          'AC'
    'DC:'          'DC'
    'CircuitEnvelope:' 'Circuit Envelope'
    };

for k = 1:size(controllerPatterns,1)

    tokenText = controllerPatterns{k,1};
    labelText = controllerPatterns{k,2};

    if contains(FORMAL_TEXT_BEFORE,tokenText)

        duplicate = false;

        for j = 1:numel(simTypes)

            if strcmp(simTypes{j},labelText)
                duplicate = true;
                break;
            end

        end

        if ~duplicate
            simTypes{end+1,1} = labelText; %#ok<SAGROW>
        end

    end

end

if isempty(simTypes)

    fprintf('Simulation       : <not detected>\n');

else

    fprintf('Simulation       : ');

    for k = 1:numel(simTypes)

        if k > 1
            fprintf(', ');
        end

        fprintf('%s',simTypes{k});

    end

    fprintf('\n');

end

% Sweep plans
sweepLines = regexp( ...
    FORMAL_TEXT_BEFORE, ...
    '(?m)^\s*SweepPlan:[^\r\n]+', ...
    'match');

fprintf('SweepPlan count  : %d\n',numel(sweepLines));

for k = 1:min(numel(sweepLines),5)
    fprintf('  %s\n',strtrim(sweepLines{k}));
end

% Basic parameter assignments near top-level netlist
paramTokens = regexp( ...
    FORMAL_TEXT_BEFORE, ...
    '(?m)^[ \t]*([A-Za-z_]\w*)[ \t]*=[ \t]*([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)', ...
    'tokens');

parameterNames = {};

for k = 1:numel(paramTokens)

    name = paramTokens{k}{1};

    % Exclude a few common simulator/config assignments
    skip = false;

    skipNames = {
        'Start'
        'Stop'
        'Step'
        'Center'
        'Span'
        };

    for j = 1:numel(skipNames)

        if strcmpi(name,skipNames{j})
            skip = true;
            break;
        end

    end

    if ~skip

        duplicate = false;

        for j = 1:numel(parameterNames)

            if strcmp(parameterNames{j},name)
                duplicate = true;
                break;
            end

        end

        if ~duplicate
            parameterNames{end+1,1} = name; %#ok<SAGROW>
        end

    end

end

fprintf('Numeric parameters: %d detected\n',numel(parameterNames));

if ~isempty(parameterNames)

    nShow = min(numel(parameterNames),20);

    fprintf('  ');

    for k = 1:nShow

        if k > 1
            fprintf(', ');
        end

        fprintf('%s',parameterNames{k});

    end

    if numel(parameterNames) > nShow
        fprintf(', ...');
    end

    fprintf('\n');

end


%% ========================================================================
% 7. Prepare bridge baseline run directory
% ========================================================================

RUN_ROOT = fullfile(ADS_WORKSPACE,'ADS_MATLAB_BRIDGE_Run');
RUN_DIR  = fullfile(RUN_ROOT,'Baseline');

if ~isfolder(RUN_ROOT)
    mkdir(RUN_ROOT);
end

if ~isfolder(RUN_DIR)
    mkdir(RUN_DIR);
end

[~,formalStem,~] = fileparts(FORMAL_NETLIST);

CASE_FILE = fullfile(RUN_DIR,[formalStem '_BRIDGE_CASE.log']);
RAW_FILE  = fullfile(RUN_DIR,[formalStem '_BRIDGE_BASELINE.raw']);
LOG_FILE  = fullfile(RUN_DIR,[formalStem '_BRIDGE_BASELINE_output.txt']);

fprintf('\nRun directory:\n');
fprintf('  %s\n',RUN_DIR);


%% ========================================================================
% 8. Build TEMPORARY command-line compatible CASE
% ========================================================================

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' TEMPORARY CASE PREPARATION\n');
fprintf('====================================================================\n');

CASE_TEXT = FORMAL_TEXT_BEFORE;

nutmegPatched = false;
linearCollapseDetected = false;
linearCollapseRemoved = false;

% ------------------------------------------------------------------------
% 8.1 Enable Nutmeg RAW only in temporary CASE
% ------------------------------------------------------------------------

if ~isempty(regexpi(CASE_TEXT,'UseNutmegFormat\s*=\s*no','once'))

    CASE_TEXT = regexprep( ...
        CASE_TEXT, ...
        'UseNutmegFormat\s*=\s*no', ...
        'UseNutmegFormat=yes', ...
        'ignorecase');

    nutmegPatched = true;

    fprintf('[PATCH] UseNutmegFormat: no -> yes\n');

elseif ~isempty(regexpi(CASE_TEXT,'UseNutmegFormat\s*=\s*yes','once'))

    fprintf('[KEEP]  UseNutmegFormat already yes\n');

else

    fprintf('[WARN]  UseNutmegFormat option was not found.\n');
    fprintf('        hpeesofsim -r will still be attempted.\n');

end


% ------------------------------------------------------------------------
% 8.2 Remove LinearCollapse from TEMP CASE only when present
% ------------------------------------------------------------------------

if contains(CASE_TEXT,'LinearCollapse')

    linearCollapseDetected = true;

    fprintf('[DETECT] LinearCollapse found in formal netlist.\n');

    beforePatch = CASE_TEXT;

    CASE_TEXT = regexprep( ...
        CASE_TEXT, ...
        '(?m)^[ \t]*#load[ \t]+"python"[ \t]*,[ \t]*"LinearCollapse"[ \t]*\r?\n?', ...
        '');

    CASE_TEXT = regexprep( ...
        CASE_TEXT, ...
        '(?m)^[ \t]*Component[ \t]+Module[ \t]*=[ \t]*"LinearCollapse"[^\r\n]*\r?\n?', ...
        '');

    if ~strcmp(beforePatch,CASE_TEXT)
        linearCollapseRemoved = true;
        fprintf('[PATCH] LinearCollapse removed from TEMP CASE only.\n');
    else
        fprintf('[WARN]  LinearCollapse was detected but exact patch lines were not matched.\n');
    end

else

    fprintf('[OK]    LinearCollapse not present.\n');

end


%% ========================================================================
% 9. Remove previous baseline files
% ========================================================================

oldFiles = {
    CASE_FILE
    RAW_FILE
    LOG_FILE
    };

for k = 1:numel(oldFiles)

    f = oldFiles{k};

    if isfile(f)

        try
            delete(f);
        catch ME
            error('Cannot delete previous baseline file:\n%s\n%s', ...
                f,ME.message);
        end

    end

end


%% ========================================================================
% 10. Write TEMP CASE
% ========================================================================

fid = fopen(CASE_FILE,'w');

if fid < 0
    error('Cannot create temporary CASE netlist: %s',CASE_FILE);
end

fwrite(fid,CASE_TEXT,'char');
fclose(fid);

fprintf('\n[OK] Temporary CASE created\n');
fprintf('     %s\n',CASE_FILE);


%% ========================================================================
% 11. Run ADS from workspace root
% ========================================================================

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' BASELINE ADS SIMULATION\n');
fprintf('====================================================================\n');

oldMATLABDir = pwd;

cdCleanup = onCleanup(@() cd(oldMATLABDir));

cd(ADS_WORKSPACE);

fprintf('Working directory:\n');
fprintf('  %s\n',pwd);

ADS_COMMAND = sprintf( ...
    '"%s" -r "%s" "%s"', ...
    ADS_SIM, ...
    RAW_FILE, ...
    CASE_FILE);

fprintf('\nCommand:\n');
fprintf('  %s\n\n',ADS_COMMAND);

tic;
[ADS_STATUS,ADS_OUTPUT] = system(ADS_COMMAND);
ADS_TIME = toc;

fprintf('Exit status : %d\n',ADS_STATUS);
fprintf('Elapsed     : %.3f s\n',ADS_TIME);

% Save simulator output with MATLAB itself (no cmd.exe redirection)
fid = fopen(LOG_FILE,'w');

if fid >= 0

    fprintf(fid,'ADS-MATLAB Bridge baseline run\n');
    fprintf(fid,'Version: 0.4.0\n\n');
    fprintf(fid,'Command:\n%s\n\n',ADS_COMMAND);
    fprintf(fid,'Exit status: %d\n',ADS_STATUS);
    fprintf(fid,'Elapsed: %.6f s\n\n',ADS_TIME);
    fprintf(fid,'================ ADS OUTPUT ================\n\n');
    fprintf(fid,'%s',ADS_OUTPUT);

    fclose(fid);

end

if ADS_STATUS ~= 0

    fprintf('\n');
    fprintf('====================================================================\n');
    fprintf(' ADS BASELINE FAILED\n');
    fprintf('====================================================================\n');

    if ~isempty(strtrim(ADS_OUTPUT))
        fprintf('%s\n',ADS_OUTPUT);
    end

    fprintf('\nSaved simulator output:\n');
    fprintf('  %s\n',LOG_FILE);

    error('Baseline ADS simulation failed with exit status %d.',ADS_STATUS);

end

fprintf('\n[OK] ADS process returned status 0.\n');


%% ========================================================================
% 12. Verify RAW file
% ========================================================================

fprintf('\n');
fprintf('--------------------------------------------------------------------\n');
fprintf(' RAW file verification\n');
fprintf('--------------------------------------------------------------------\n');

if ~isfile(RAW_FILE)
    error(['ADS returned status 0 but the requested RAW file ' ...
           'was not generated.']);
end

rawInfo = dir(RAW_FILE);

if rawInfo.bytes <= 0
    error('RAW file exists but is empty.');
end

fprintf('[OK] RAW generated\n');
fprintf('     %s\n',RAW_FILE);
fprintf('     Size: %.3f KB\n',rawInfo.bytes/1024);


%% ========================================================================
% 13. Inspect first RAW plot/header
%
% We do NOT fully decode all numerical data in Step 4.
% Step 4 only proves:
%   ADS -> RAW -> MATLAB can recognize RAW structure.
% ========================================================================

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' RAW INTERFACE INSPECTION\n');
fprintf('====================================================================\n');

fid = fopen(RAW_FILE,'rb');

if fid < 0
    error('Cannot open generated RAW file.');
end

maxHeaderBytes = min(rawInfo.bytes,2*1024*1024);

rawBytes = fread(fid,maxHeaderBytes,'*uint8').';

fclose(fid);

binaryMarker = uint8('Binary:');
valuesMarker = uint8('Values:');

binaryPos = strfind(rawBytes,binaryMarker);
valuesPos = strfind(rawBytes,valuesMarker);

rawMode = '';
headerEnd = 0;

if ~isempty(binaryPos)

    headerEnd = binaryPos(1)-1;
    rawMode = 'Binary';

elseif ~isempty(valuesPos)

    headerEnd = valuesPos(1)-1;
    rawMode = 'ASCII Values';

else

    % Fallback: inspect what was read as text.
    headerEnd = numel(rawBytes);
    rawMode = 'Unknown';

end

RAW_HEADER = char(rawBytes(1:headerEnd));

% Strip NUL characters if present
RAW_HEADER(RAW_HEADER == char(0)) = ' ';

titleText = '';
plotName = '';
flagsText = '';
nVariables = NaN;
nPoints = NaN;

tok = regexp(RAW_HEADER, ...
    '(?m)^Title:\s*(.*?)\s*$', ...
    'tokens','once');

if ~isempty(tok)
    titleText = strtrim(tok{1});
end

tok = regexp(RAW_HEADER, ...
    '(?m)^Plotname:\s*(.*?)\s*$', ...
    'tokens','once');

if ~isempty(tok)
    plotName = strtrim(tok{1});
end

tok = regexp(RAW_HEADER, ...
    '(?m)^Flags:\s*(.*?)\s*$', ...
    'tokens','once');

if ~isempty(tok)
    flagsText = strtrim(tok{1});
end

tok = regexp(RAW_HEADER, ...
    'No\.\s*Variables:\s*(\d+)', ...
    'tokens','once');

if ~isempty(tok)
    nVariables = str2double(tok{1});
end

tok = regexp(RAW_HEADER, ...
    'No\.\s*Points:\s*(\d+)', ...
    'tokens','once');

if ~isempty(tok)
    nPoints = str2double(tok{1});
end

fprintf('RAW mode         : %s\n',rawMode);

if isempty(titleText)
    fprintf('Title            : <not detected>\n');
else
    fprintf('Title            : %s\n',titleText);
end

if isempty(plotName)
    fprintf('Plotname         : <not detected>\n');
else
    fprintf('Plotname         : %s\n',plotName);
end

if isempty(flagsText)
    fprintf('Flags            : <not detected>\n');
else
    fprintf('Flags            : %s\n',flagsText);
end

if isnan(nVariables)
    fprintf('No. Variables    : <not detected>\n');
else
    fprintf('No. Variables    : %d\n',nVariables);
end

if isnan(nPoints)
    fprintf('No. Points       : <not detected>\n');
else
    fprintf('No. Points       : %d\n',nPoints);
end


%% ========================================================================
% 14. Extract variable names from first RAW header
% ========================================================================

rawVariableNames = {};

varTokens = regexp( ...
    RAW_HEADER, ...
    '(?m)(?:^Variables:\s*|^[ \t]*)(\d+)[ \t]+(\S+)[ \t]+([^\r\n]+)', ...
    'tokens');

if ~isempty(varTokens)

    variableIndex = [];
    variableNamesTemp = {};

    for k = 1:numel(varTokens)

        idx = str2double(varTokens{k}{1});
        name = strtrim(varTokens{k}{2});

        if isnan(idx)
            continue;
        end

        % Keep indices within declared variable count when available
        if ~isnan(nVariables)

            if idx < 0
                continue;
            end

            if idx >= nVariables
                continue;
            end

        end

        duplicate = false;

        for j = 1:numel(variableIndex)

            if variableIndex(j) == idx
                duplicate = true;
                break;
            end

        end

        if ~duplicate

            variableIndex(end+1,1) = idx; %#ok<SAGROW>
            variableNamesTemp{end+1,1} = name; %#ok<SAGROW>

        end

    end

    if ~isempty(variableIndex)

        [variableIndex,order] = sort(variableIndex);
        variableNamesTemp = variableNamesTemp(order);

        rawVariableNames = variableNamesTemp;

    end

end

fprintf('\nReturned variables detected: %d\n',numel(rawVariableNames));

if isempty(rawVariableNames)

    fprintf('  <none parsed from first RAW header>\n');

else

    nShow = min(numel(rawVariableNames),40);

    for k = 1:nShow
        fprintf('  [%d] %s\n',k-1,rawVariableNames{k});
    end

    if numel(rawVariableNames) > nShow
        fprintf('  ...\n');
    end

end


%% ========================================================================
% 15. Verify formal netlist remained unchanged
% ========================================================================

fprintf('\n');
fprintf('--------------------------------------------------------------------\n');
fprintf(' Formal netlist protection check\n');
fprintf('--------------------------------------------------------------------\n');

FORMAL_TEXT_AFTER = fileread(FORMAL_NETLIST);

formalUnchanged = strcmp(FORMAL_TEXT_BEFORE,FORMAL_TEXT_AFTER);

if formalUnchanged

    fprintf('[OK] Original netlist is unchanged.\n');

else

    fprintf('[FAIL] Original netlist content changed unexpectedly.\n');

end


%% ========================================================================
% 16. Decide Step 4 pass / attention
% ========================================================================

rawHeaderRecognized = ...
    ~isempty(plotName) && ...
    ~isnan(nVariables) && ...
    ~isnan(nPoints);

step4Passed = ...
    (ADS_STATUS == 0) && ...
    isfile(RAW_FILE) && ...
    (rawInfo.bytes > 0) && ...
    rawHeaderRecognized && ...
    formalUnchanged;


%% ========================================================================
% 17. Export report for later parser / optimizer branches
% ========================================================================

ADS_BASELINE_REPORT = struct();

ADS_BASELINE_REPORT.version = '0.4.0';

ADS_BASELINE_REPORT.adsRoot = ADS_ROOT;
ADS_BASELINE_REPORT.simulator = ADS_SIM;
ADS_BASELINE_REPORT.workspace = ADS_WORKSPACE;

ADS_BASELINE_REPORT.formalNetlist = FORMAL_NETLIST;
ADS_BASELINE_REPORT.caseNetlist = CASE_FILE;
ADS_BASELINE_REPORT.rawFile = RAW_FILE;
ADS_BASELINE_REPORT.outputLog = LOG_FILE;

ADS_BASELINE_REPORT.topDesign = topDesign;
ADS_BASELINE_REPORT.simulationTypes = simTypes;
ADS_BASELINE_REPORT.sweepPlans = sweepLines;
ADS_BASELINE_REPORT.parameterNames = parameterNames;

ADS_BASELINE_REPORT.nutmegPatched = nutmegPatched;
ADS_BASELINE_REPORT.linearCollapseDetected = linearCollapseDetected;
ADS_BASELINE_REPORT.linearCollapseRemoved = linearCollapseRemoved;

ADS_BASELINE_REPORT.adsStatus = ADS_STATUS;
ADS_BASELINE_REPORT.adsElapsed = ADS_TIME;

ADS_BASELINE_REPORT.rawMode = rawMode;
ADS_BASELINE_REPORT.rawTitle = titleText;
ADS_BASELINE_REPORT.rawPlotname = plotName;
ADS_BASELINE_REPORT.rawFlags = flagsText;
ADS_BASELINE_REPORT.rawVariableCount = nVariables;
ADS_BASELINE_REPORT.rawPointCount = nPoints;
ADS_BASELINE_REPORT.rawVariableNames = rawVariableNames;

ADS_BASELINE_REPORT.formalNetlistUnchanged = formalUnchanged;
ADS_BASELINE_REPORT.step4Passed = step4Passed;


%% ========================================================================
% 18. Final result
% ========================================================================

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' BASELINE DOCTOR RESULT\n');
fprintf('====================================================================\n');

fprintf('\nFormal netlist:\n');
fprintf('  %s\n',FORMAL_NETLIST);

fprintf('\nTemporary CASE:\n');
fprintf('  %s\n',CASE_FILE);

fprintf('\nRAW output:\n');
fprintf('  %s\n',RAW_FILE);

fprintf('\nADS exit status:\n');
fprintf('  %d\n',ADS_STATUS);

fprintf('\nRAW header recognized:\n');

if rawHeaderRecognized
    fprintf('  YES\n');
else
    fprintf('  NO\n');
end

fprintf('\nOriginal netlist unchanged:\n');

if formalUnchanged
    fprintf('  YES\n');
else
    fprintf('  NO\n');
end

if step4Passed

    fprintf('\n');
    fprintf('--------------------------------------------------------------------\n');
    fprintf(' STEP 4 PASSED\n');
    fprintf('--------------------------------------------------------------------\n');

    fprintf('\nADS -> temporary netlist -> hpeesofsim -> RAW -> MATLAB\n');
    fprintf('baseline interface is working.\n');

    fprintf('\nBridge Core status:\n');
    fprintf('  Step 1  ADS / simulator detection       : READY\n');
    fprintf('  Step 2  Workspace / library detection   : READY\n');
    fprintf('  Step 3  Runtime / DLL environment        : READY\n');
    fprintf('  Step 4  Baseline / RAW interface         : READY\n');

    fprintf('\nNext branch:\n');
    fprintf('  Generic RAW parser and optimization algorithms\n');

else

    fprintf('\n');
    fprintf('--------------------------------------------------------------------\n');
    fprintf(' STEP 4 NEEDS ATTENTION\n');
    fprintf('--------------------------------------------------------------------\n');

    fprintf('\nThe ADS process may have run, but the complete baseline interface\n');
    fprintf('was not verified. Inspect the report above before continuing.\n');

end

fprintf('\n====================================================================\n');
