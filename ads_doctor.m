%% ========================================================================
% ADS-MATLAB Bridge
% ads_doctor.m
%
% Version: 0.1
%
% Purpose:
%   Step 1 - Find Keysight ADS installation
%   Step 2 - Find hpeesofsim.exe
%
% This version intentionally DOES NOT scan the whole computer.
% ========================================================================

clear;
clc;

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' ADS-MATLAB BRIDGE DOCTOR  v0.1\n');
fprintf('====================================================================\n');


%% ========================================================================
% 1. Candidate Keysight installation roots
% ========================================================================

searchRoots = {
    'C:\Program Files\Keysight'
    'D:\Program Files\Keysight'
    'E:\Program Files\Keysight'
    
    'C:\Keysight'
    'D:\Keysight'
    'E:\Keysight'
    };


%% ========================================================================
% 2. Also inspect existing environment variables
% ========================================================================

fprintf('\n');
fprintf('--------------------------------------------------------------------\n');
fprintf(' Existing ADS environment variables\n');
fprintf('--------------------------------------------------------------------\n');

envNames = {
    'HPEESOF_DIR'
    'HPEESOF_ROOT'
    'ADS_HOME'
    };

envCandidates = {};

for k = 1:numel(envNames)
    
    value = strtrim(getenv(envNames{k}));
    
    if isempty(value)
        
        fprintf('[EMPTY] %-15s\n',envNames{k});
        
    else
        
        fprintf('[FOUND] %-15s = %s\n', ...
            envNames{k},value);
        
        if isfolder(value)
            envCandidates{end+1,1} = value; %#ok<SAGROW>
        end
        
    end
    
end


%% ========================================================================
% 3. Search normal Keysight directories
% ========================================================================

fprintf('\n');
fprintf('--------------------------------------------------------------------\n');
fprintf(' Searching standard Keysight installation locations\n');
fprintf('--------------------------------------------------------------------\n');

adsCandidates = {};

for r = 1:numel(searchRoots)
    
    rootDir = searchRoots{r};
    
    if ~isfolder(rootDir)
        
        fprintf('[SKIP] %s\n',rootDir);
        continue;
        
    end
    
    fprintf('[SCAN] %s\n',rootDir);
    
    % Only inspect direct children such as ADS2025 / ADS2027
    folders = dir(fullfile(rootDir,'ADS*'));
    
    for k = 1:numel(folders)
        
        if ~folders(k).isdir
            continue;
        end
        
        name = folders(k).name;
        
        % Ignore . and ..
        if strcmp(name,'.') || strcmp(name,'..')
            continue;
        end
        
        candidate = fullfile(folders(k).folder,name);
        
        % Must contain hpeesofsim.exe to count as valid ADS
        simPath = fullfile(candidate,'bin','hpeesofsim.exe');
        
        if isfile(simPath)
            
            adsCandidates{end+1,1} = candidate; %#ok<SAGROW>
            
            fprintf('       [ADS] %s\n',candidate);
            
        end
        
    end
    
end


%% ========================================================================
% 4. Add environment-variable candidates
% ========================================================================

for k = 1:numel(envCandidates)
    
    candidate = envCandidates{k};
    
    simPath = fullfile(candidate,'bin','hpeesofsim.exe');
    
    if isfile(simPath)
        
        adsCandidates{end+1,1} = candidate; %#ok<SAGROW>
        
    end
    
end


%% ========================================================================
% 5. Remove duplicates
% ========================================================================

if ~isempty(adsCandidates)
    
    adsCandidates = unique(adsCandidates,'stable');
    
end


%% ========================================================================
% 6. Report
% ========================================================================

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' ADS INSTALLATION RESULT\n');
fprintf('====================================================================\n');

if isempty(adsCandidates)
    
    fprintf('\n[FAIL] No valid ADS installation was found.\n');
    
    fprintf('\nSearched locations:\n');
    
    for k = 1:numel(searchRoots)
        fprintf('  %s\n',searchRoots{k});
    end
    
    fprintf('\nPossible reasons:\n');
    fprintf('  1. ADS is installed in a custom directory.\n');
    fprintf('  2. ADS installation is incomplete.\n');
    fprintf('  3. hpeesofsim.exe is missing.\n');
    
    error('ADS installation not found.');
    
end


fprintf('\nFound %d valid ADS installation(s):\n\n', ...
    numel(adsCandidates));


for k = 1:numel(adsCandidates)
    
    adsRoot = adsCandidates{k};
    
    simPath = fullfile( ...
        adsRoot, ...
        'bin', ...
        'hpeesofsim.exe');
    
    fprintf('[%d]\n',k);
    fprintf('ADS Root : %s\n',adsRoot);
    fprintf('Simulator: %s\n\n',simPath);
    
end


%% ========================================================================
% 7. Select ADS installation
% ========================================================================

if numel(adsCandidates) == 1
    
    selectedIndex = 1;
    
    fprintf('Only one valid ADS installation found.\n');
    fprintf('Automatically selected.\n');
    
else
    
    fprintf('Multiple ADS installations were found.\n');
    
    selectedIndex = input( ...
        sprintf('Select ADS installation [1-%d]: ', ...
        numel(adsCandidates)));
    
    if isempty(selectedIndex) || ...
            selectedIndex < 1 || ...
            selectedIndex > numel(adsCandidates) || ...
            floor(selectedIndex) ~= selectedIndex
        
        error('Invalid ADS selection.');
        
    end
    
end


ADS_ROOT = adsCandidates{selectedIndex};

ADS_SIM = fullfile( ...
    ADS_ROOT, ...
    'bin', ...
    'hpeesofsim.exe');


%% ========================================================================
% 8. Final verification
% ========================================================================

assert(isfolder(ADS_ROOT), ...
    'Selected ADS root does not exist.');

assert(isfile(ADS_SIM), ...
    'Selected hpeesofsim.exe does not exist.');


fprintf('\n');
fprintf('====================================================================\n');
fprintf(' ADS-MATLAB BRIDGE DOCTOR RESULT\n');
fprintf('====================================================================\n');

fprintf('\n[OK] ADS installation\n');
fprintf('     %s\n',ADS_ROOT);

fprintf('\n[OK] ADS simulator\n');
fprintf('     %s\n',ADS_SIM);

fprintf('\n--------------------------------------------------------------------\n');
fprintf(' STEP 1 PASSED\n');
fprintf('--------------------------------------------------------------------\n');

fprintf('\nNext development step:\n');
fprintf('  Workspace / library detection\n');

fprintf('\n====================================================================\n');