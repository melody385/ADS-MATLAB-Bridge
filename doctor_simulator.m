%% ========================================================================
% ADS-MATLAB Bridge
% doctor_simulator.m
%
% Version: 0.3.1
%
% STEP 3:
%   ADS Runtime / DLL Environment Doctor
%
% Run order:
%   1) doctor_ads.m
%   2) doctor_workspace.m
%   3) doctor_simulator.m
%
% Design:
%   Stage A - Apply the standard ADS command-line environment:
%       HPEESOF_DIR = ADS_ROOT
%       COMPL_DIR   = ADS_ROOT
%       SIMARCH     = win32_64
%
%       PATH candidates (only if they exist):
%       <ADS>\bin\win32_64
%       <ADS>\bin
%       <ADS>\lib\win32_64
%       <ADS>\circuit\lib.win32_64
%       <ADS>\adsptolemy\lib.win32_64
%
%   Stage B - Test hpeesofsim -h
%
%   Stage C - Only if Stage B fails:
%       scan ONLY ADS_ROOT for newer-version runtime folders
%       (Python/FEM/Momentum/TCD/DLL folders), add them temporarily,
%       and test again.
%
% Important:
%   - No permanent Windows environment changes.
%   - No whole-computer scan.
%   - No ADS installation modification.
%   - PATH changes affect only the current MATLAB session.
% ========================================================================

clc;

%% Bootstrap the public Bridge Core for this MATLAB session only

BRIDGE_REPO_ROOT = fileparts(mfilename('fullpath'));
BRIDGE_CORE_DIR = fullfile(BRIDGE_REPO_ROOT,'core');

if ~isfolder(BRIDGE_CORE_DIR)
    error('Bridge Core folder does not exist: %s',BRIDGE_CORE_DIR);
end

addpath(BRIDGE_CORE_DIR,'-begin');

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' ADS-MATLAB BRIDGE - RUNTIME DOCTOR  v0.3.1\n');
fprintf('====================================================================\n');


%% ========================================================================
% 1. Get ADS root from Step 1
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
    error('ADS_ROOT is unavailable. Run doctor_ads.m first.');
end

ADS_ROOT = char(ADS_ROOT);

if isempty(ADS_ROOT)
    error('ADS_ROOT is empty. Run doctor_ads.m first.');
end

if ~isfolder(ADS_ROOT)
    error('ADS_ROOT does not exist: %s',ADS_ROOT);
end

fprintf('\n[OK] ADS root\n');
fprintf('     %s\n',ADS_ROOT);


%% ========================================================================
% 2. Locate simulator
% ========================================================================

ADS_SIM = fullfile(ADS_ROOT,'bin','hpeesofsim.exe');

if ~isfile(ADS_SIM)
    
    fprintf('\n[INFO] Default simulator path not found.\n');
    fprintf('       Searching only inside ADS_ROOT...\n');
    
    simHits = dir(fullfile(ADS_ROOT,'**','hpeesofsim.exe'));
    
    validSim = {};
    
    for k = 1:numel(simHits)
        
        if simHits(k).isdir
            continue;
        end
        
        validSim{end+1,1} = ...
            fullfile(simHits(k).folder,simHits(k).name); %#ok<SAGROW>
        
    end
    
    if isempty(validSim)
        error('hpeesofsim.exe was not found inside ADS_ROOT.');
    end
    
    ADS_SIM = validSim{1};
    
end

fprintf('\n[OK] ADS simulator\n');
fprintf('     %s\n',ADS_SIM);


%% ========================================================================
% 3. Standard ADS command-line environment
%
% These are the canonical simulator environment variables.
% ========================================================================

fprintf('\n');
fprintf('--------------------------------------------------------------------\n');
fprintf(' Applying standard ADS command-line environment\n');
fprintf('--------------------------------------------------------------------\n');

setenv('HPEESOF_DIR',ADS_ROOT);
setenv('COMPL_DIR',ADS_ROOT);
setenv('SIMARCH','win32_64');

fprintf('[SET] HPEESOF_DIR = %s\n',getenv('HPEESOF_DIR'));
fprintf('[SET] COMPL_DIR   = %s\n',getenv('COMPL_DIR'));
fprintf('[SET] SIMARCH     = %s\n',getenv('SIMARCH'));


%% ========================================================================
% 4. Canonical ADS runtime directories
% ========================================================================

systemRoot = getenv('SystemRoot');

if isempty(systemRoot)
    systemRoot = 'C:\Windows';
end

standardDirs = {
    fullfile(systemRoot,'System32')
    fullfile(ADS_ROOT,'bin','win32_64')
    fullfile(ADS_ROOT,'bin')
    fullfile(ADS_ROOT,'lib','win32_64')
    fullfile(ADS_ROOT,'circuit','lib.win32_64')
    fullfile(ADS_ROOT,'adsptolemy','lib.win32_64')
    };

fprintf('\nStandard runtime directories:\n');

originalPATH = getenv('PATH');
currentPATH = originalPATH;

standardDirsAdded = {};
standardDirsPresent = {};

for k = 1:numel(standardDirs)
    
    d = standardDirs{k};
    
    if ~isfolder(d)
        
        fprintf('  [MISS] %s\n',d);
        continue;
        
    end
    
    standardDirsPresent{end+1,1} = d; %#ok<SAGROW>
    
    pathParts = strsplit(currentPATH,';');
    alreadyThere = false;
    
    for j = 1:numel(pathParts)
        
        a = strtrim(pathParts{j});
        b = d;
        
        a = strrep(a,'/','\');
        b = strrep(b,'/','\');
        
        while ~isempty(a)
            if a(end) == '\'
                a(end) = [];
            else
                break;
            end
        end
        
        while ~isempty(b)
            if b(end) == '\'
                b(end) = [];
            else
                break;
            end
        end
        
        if strcmpi(a,b)
            alreadyThere = true;
            break;
        end
        
    end
    
    if alreadyThere
        
        fprintf('  [KEEP] %s\n',d);
        
    else
        
        currentPATH = [d ';' currentPATH];
        standardDirsAdded{end+1,1} = d; %#ok<SAGROW>
        
        fprintf('  [ADD]  %s\n',d);
        
    end
    
end

setenv('PATH',currentPATH);


%% ========================================================================
% 5. Test after STANDARD environment setup
% ========================================================================

fprintf('\n');
fprintf('--------------------------------------------------------------------\n');
fprintf(' Standard environment startup test\n');
fprintf('--------------------------------------------------------------------\n');

startupCommand = sprintf('"%s" -h',ADS_SIM);

fprintf('Command:\n');
fprintf('  %s\n\n',startupCommand);

tic;
[standardStatus,standardOutput] = system(startupCommand);
standardTime = toc;

fprintf('Exit status : %d\n',standardStatus);
fprintf('Elapsed     : %.3f s\n',standardTime);

DLL_ERROR = -1073741515;

adaptiveRepairAttempted = false;
adaptiveRepairSucceeded = false;
adaptiveDirsAdded = {};

finalStatus = standardStatus;
finalOutput = standardOutput;


%% ========================================================================
% 6. If standard setup works: finish immediately
% ========================================================================

if standardStatus == 0
    
    fprintf('\n[OK] Standard ADS runtime environment is sufficient.\n');
    fprintf('     Adaptive repair is NOT required.\n');
    
    adaptiveRepairSucceeded = true;
    
else
    
    fprintf('\n[FAIL] Standard environment was not sufficient.\n');
    
    if standardStatus == DLL_ERROR
        fprintf('       Windows error 0xC0000135 is still present.\n');
    else
        fprintf('       hpeesofsim returned non-zero status %d.\n',standardStatus);
    end
    
    fprintf('       Starting adaptive ADS_ROOT-only repair...\n');
    
    adaptiveRepairAttempted = true;
    
    
    %% ====================================================================
    % 7. Adaptive discovery for newer / different ADS layouts
    % ====================================================================
    
    fprintf('\n');
    fprintf('--------------------------------------------------------------------\n');
    fprintf(' Adaptive runtime discovery inside ADS_ROOT\n');
    fprintf('--------------------------------------------------------------------\n');
    
    candidateDirs = {};
    
    % Core Python locations
    directCandidates = {
        fullfile(ADS_ROOT,'tools','bin')
        fullfile(ADS_ROOT,'tools','python')
        fullfile(ADS_ROOT,'tools','python','Scripts')
        fullfile(ADS_ROOT,'tools','python','DLLs')
        };
    
    for k = 1:numel(directCandidates)
        
        d = directCandidates{k};
        
        if isfolder(d)
            candidateDirs{end+1,1} = d; %#ok<SAGROW>
        end
        
    end
    
    % Important DLL-containing directories
    dllPatterns = {
        'ptgem.dll'
        'python*.dll'
        'vcruntime*.dll'
        'msvcp*.dll'
        'libcrypto*.dll'
        'libssl*.dll'
        };
    
    for p = 1:numel(dllPatterns)
        
        pattern = dllPatterns{p};
        
        fprintf('[SCAN DLL] %s\n',pattern);
        
        hits = dir(fullfile(ADS_ROOT,'**',pattern));
        
        for k = 1:numel(hits)
            
            if hits(k).isdir
                continue;
            end
            
            d = hits(k).folder;
            
            if isfolder(d)
                candidateDirs{end+1,1} = d; %#ok<SAGROW>
            end
            
        end
        
    end
    
    % Common Python/runtime folders
    dirNames = {
        'DLLs'
        'numpy.libs'
        'pandas.libs'
        'pywin32_system32'
        'edb'
        };
    
    for p = 1:numel(dirNames)
        
        targetName = dirNames{p};
        
        fprintf('[SCAN DIR] %s\n',targetName);
        
        hits = dir(fullfile(ADS_ROOT,'**',targetName));
        
        for k = 1:numel(hits)
            
            if ~hits(k).isdir
                continue;
            end
            
            d = fullfile(hits(k).folder,hits(k).name);
            
            if isfolder(d)
                candidateDirs{end+1,1} = d; %#ok<SAGROW>
            end
            
        end
        
    end
    
    % Versioned FEM / Momentum / TCD bin folders
    familyRoots = {
        fullfile(ADS_ROOT,'fem')
        fullfile(ADS_ROOT,'Momentum')
        fullfile(ADS_ROOT,'tcd')
        };
    
    for f = 1:numel(familyRoots)
        
        familyRoot = familyRoots{f};
        
        if ~isfolder(familyRoot)
            continue;
        end
        
        binHits = dir(fullfile(familyRoot,'**','bin'));
        
        for k = 1:numel(binHits)
            
            if ~binHits(k).isdir
                continue;
            end
            
            d = fullfile(binHits(k).folder,binHits(k).name);
            
            if isfolder(d)
                candidateDirs{end+1,1} = d; %#ok<SAGROW>
            end
            
        end
        
    end
    
    
    %% ====================================================================
    % 8. Deduplicate candidates by exact normalized path
    % ====================================================================
    
    uniqueCandidates = {};
    
    for k = 1:numel(candidateDirs)
        
        d = candidateDirs{k};
        d = strrep(d,'/','\');
        
        while ~isempty(d)
            if d(end) == '\'
                d(end) = [];
            else
                break;
            end
        end
        
        duplicate = false;
        
        for j = 1:numel(uniqueCandidates)
            
            if strcmpi(d,uniqueCandidates{j})
                duplicate = true;
                break;
            end
            
        end
        
        if ~duplicate
            uniqueCandidates{end+1,1} = d; %#ok<SAGROW>
        end
        
    end
    
    candidateDirs = uniqueCandidates;
    
    
    %% ====================================================================
    % 9. Add adaptive directories using exact PATH entry matching
    % ====================================================================
    
    currentPATH = getenv('PATH');
    
    fprintf('\nAdaptive candidate directories found: %d\n', ...
        numel(candidateDirs));
    
    for k = 1:numel(candidateDirs)
        
        d = candidateDirs{k};
        
        if ~isfolder(d)
            continue;
        end
        
        pathParts = strsplit(currentPATH,';');
        alreadyThere = false;
        
        for j = 1:numel(pathParts)
            
            a = strtrim(pathParts{j});
            b = d;
            
            a = strrep(a,'/','\');
            b = strrep(b,'/','\');
            
            while ~isempty(a)
                if a(end) == '\'
                    a(end) = [];
                else
                    break;
                end
            end
            
            while ~isempty(b)
                if b(end) == '\'
                    b(end) = [];
                else
                    break;
                end
            end
            
            if strcmpi(a,b)
                alreadyThere = true;
                break;
            end
            
        end
        
        if ~alreadyThere
            
            currentPATH = [d ';' currentPATH];
            adaptiveDirsAdded{end+1,1} = d; %#ok<SAGROW>
            
            fprintf('  [ADD] %s\n',d);
            
        end
        
    end
    
    setenv('PATH',currentPATH);
    
    
    %% ====================================================================
    % 10. Final retest
    % ====================================================================
    
    fprintf('\n');
    fprintf('--------------------------------------------------------------------\n');
    fprintf(' Final startup test after adaptive repair\n');
    fprintf('--------------------------------------------------------------------\n');
    
    tic;
    [finalStatus,finalOutput] = system(startupCommand);
    finalTime = toc;
    
    fprintf('Exit status : %d\n',finalStatus);
    fprintf('Elapsed     : %.3f s\n',finalTime);
    
    if finalStatus == 0
        
        adaptiveRepairSucceeded = true;
        
        fprintf('\n[OK] Adaptive runtime repair succeeded.\n');
        
    else
        
        adaptiveRepairSucceeded = false;
        
        fprintf('\n[FAIL] hpeesofsim still cannot start.\n');
        
        if finalStatus == DLL_ERROR
            fprintf('       0xC0000135 is still present.\n');
        end
        
        fprintf('\nSimulator output:\n');
        fprintf('%s\n',finalOutput);
        
    end
    
end


%% ========================================================================
% 11. Final report
% ========================================================================

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' RUNTIME DOCTOR RESULT\n');
fprintf('====================================================================\n');

fprintf('\nADS Root:\n');
fprintf('  %s\n',ADS_ROOT);

fprintf('\nSimulator:\n');
fprintf('  %s\n',ADS_SIM);

fprintf('\nEnvironment:\n');
fprintf('  HPEESOF_DIR = %s\n',getenv('HPEESOF_DIR'));
fprintf('  COMPL_DIR   = %s\n',getenv('COMPL_DIR'));
fprintf('  SIMARCH     = %s\n',getenv('SIMARCH'));

fprintf('\nStandard ADS runtime directories found:\n');
fprintf('  %d\n',numel(standardDirsPresent));

fprintf('\nStandard directories added to PATH:\n');
fprintf('  %d\n',numel(standardDirsAdded));

fprintf('\nStatus after standard setup:\n');
fprintf('  %d\n',standardStatus);

fprintf('\nAdaptive repair attempted:\n');

if adaptiveRepairAttempted
    fprintf('  YES\n');
else
    fprintf('  NO\n');
end

fprintf('\nAdaptive directories added:\n');
fprintf('  %d\n',numel(adaptiveDirsAdded));

fprintf('\nFinal startup status:\n');
fprintf('  %d\n',finalStatus);


%% ========================================================================
% 12. Expose report for Step 4
% ========================================================================

ADS_RUNTIME_REPORT = struct();

ADS_RUNTIME_REPORT.version = '0.3.1';

ADS_RUNTIME_REPORT.adsRoot = ADS_ROOT;
ADS_RUNTIME_REPORT.simulator = ADS_SIM;

ADS_RUNTIME_REPORT.hpeesofDir = getenv('HPEESOF_DIR');
ADS_RUNTIME_REPORT.complDir = getenv('COMPL_DIR');
ADS_RUNTIME_REPORT.simarch = getenv('SIMARCH');

ADS_RUNTIME_REPORT.standardDirsPresent = standardDirsPresent;
ADS_RUNTIME_REPORT.standardDirsAdded = standardDirsAdded;

ADS_RUNTIME_REPORT.standardStatus = standardStatus;
ADS_RUNTIME_REPORT.standardOutput = standardOutput;

ADS_RUNTIME_REPORT.adaptiveRepairAttempted = adaptiveRepairAttempted;
ADS_RUNTIME_REPORT.adaptiveRepairSucceeded = adaptiveRepairSucceeded;
ADS_RUNTIME_REPORT.adaptiveDirsAdded = adaptiveDirsAdded;

ADS_RUNTIME_REPORT.finalStatus = finalStatus;
ADS_RUNTIME_REPORT.finalOutput = finalOutput;

ADS_RUNTIME_REPORT.step3Passed = (finalStatus == 0);


%% ========================================================================
% 13. Pass / fail
% ========================================================================

if finalStatus == 0
    
    fprintf('\n');
    fprintf('--------------------------------------------------------------------\n');
    fprintf(' STEP 3 PASSED\n');
    fprintf('--------------------------------------------------------------------\n');
    
    if standardStatus == 0
        
        fprintf('\nStandard ADS command-line environment was sufficient.\n');
        
    else
        
        fprintf('\nAdaptive runtime repair was required and succeeded.\n');
        
    end
    
    fprintf('\nNext development step:\n');
    fprintf('  Baseline netlist / RAW interface test\n');
    
else
    
    fprintf('\n');
    fprintf('--------------------------------------------------------------------\n');
    fprintf(' STEP 3 NEEDS ATTENTION\n');
    fprintf('--------------------------------------------------------------------\n');
    
    fprintf('\nThe simulator still cannot start correctly.\n');
    fprintf('Do NOT continue to baseline simulation yet.\n');
    
end

fprintf('\n====================================================================\n');
