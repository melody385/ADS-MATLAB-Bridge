%% ========================================================================
% ADS-MATLAB Bridge
% workspace_doctor_v023.m
%
% Version: 0.2.3
%
% STEP 2:
%   Workspace / library detection
%
% This is intentionally a SCRIPT, not a function.
% Run ads_doctor.m first, then run this file directly.
%
% It NEVER modifies lib.defs or the ADS workspace.
% ========================================================================

clc;

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' ADS-MATLAB BRIDGE - WORKSPACE DOCTOR  v0.2.3\n');
fprintf('====================================================================\n');

%% 1. Get ADS root from Step 1

if ~exist('ADS_ROOT','var')
    ADS_ROOT = strtrim(getenv('HPEESOF_DIR'));
end

if isempty(ADS_ROOT)
    error('ADS_ROOT is unavailable. Run ads_doctor.m first.');
end

if ~isfolder(ADS_ROOT)
    error('ADS_ROOT does not exist: %s',ADS_ROOT);
end

fprintf('\n[OK] ADS root\n');
fprintf('     %s\n',ADS_ROOT);

%% 2. Select workspace

fprintf('\nSelect the ADS workspace folder (for example MyWorkspace_wrk).\n');

ADS_WORKSPACE = uigetdir(pwd,'Select ADS Workspace Folder');

if isequal(ADS_WORKSPACE,0)
    error('Workspace selection cancelled.');
end

if ~isfolder(ADS_WORKSPACE)
    error('Workspace does not exist: %s',ADS_WORKSPACE);
end

fprintf('\n[OK] Workspace\n');
fprintf('     %s\n',ADS_WORKSPACE);

%% 3. Check configuration files

fprintf('\n');
fprintf('--------------------------------------------------------------------\n');
fprintf(' Workspace configuration files\n');
fprintf('--------------------------------------------------------------------\n');

configNames = {
    'lib.defs'
    'hpeesofsim.cfg'
    'ADSlibconfig'
    'de_sim.cfg'
    };

configOK = false(numel(configNames),1);

for k = 1:numel(configNames)

    p = fullfile(ADS_WORKSPACE,configNames{k});

    configOK(k) = isfile(p);

    if configOK(k)
        fprintf('[OK]   %-18s %s\n',configNames{k},p);
    else
        fprintf('[MISS] %-18s %s\n',configNames{k},p);
    end

end

libDefsPath = fullfile(ADS_WORKSPACE,'lib.defs');

if ~isfile(libDefsPath)
    error('lib.defs was not found.');
end

%% 4. Read lib.defs

libText = fileread(libDefsPath);

if isempty(strtrim(libText))
    error('lib.defs is empty.');
end

lines = regexp(libText,'\r\n|\n|\r','split');

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' LIBRARY REFERENCES\n');
fprintf('====================================================================\n');

includeCount = 0;
defineCount = 0;
brokenCount = 0;

libraryReport = struct( ...
    'type',{}, ...
    'name',{}, ...
    'raw',{}, ...
    'resolved',{}, ...
    'category',{}, ...
    'exists',{});

%% 5. Parse each line

for i = 1:numel(lines)

    line = strtrim(lines{i});

    if isempty(line)
        continue;
    end

    upperLine = upper(line);

    % ---------------------------------------------------------------------
    % INCLUDE
    % ---------------------------------------------------------------------

    if startsWith(upperLine,'INCLUDE ')

        includeCount = includeCount + 1;

        rawPath = strtrim(line(8:end));

        % Remove surrounding "..." or '...'
        if numel(rawPath) >= 2

            firstCode = double(rawPath(1));
            lastCode  = double(rawPath(end));

            removeQuotes = false;

            if firstCode == 34
                if lastCode == 34
                    removeQuotes = true;
                end
            elseif firstCode == 39
                if lastCode == 39
                    removeQuotes = true;
                end
            end

            if removeQuotes
                rawPath = rawPath(2:end-1);
            end

        end

        resolved = rawPath;

        resolved = strrep(resolved,'${HPEESOF_DIR}',ADS_ROOT);
        resolved = strrep(resolved,'$HPEESOF_DIR',ADS_ROOT);
        resolved = strrep(resolved,'/',filesep);

        unresolved = contains(resolved,'$');

        if unresolved

            category = 'SYSTEM';
            pathOK = false;

        else

            isAbsolute = false;

            if numel(resolved) >= 3
                if resolved(2) == ':'
                    if resolved(3) == filesep
                        isAbsolute = true;
                    end
                end
            end

            if ~isAbsolute
                resolved = fullfile(ADS_WORKSPACE,resolved);
            end

            lowResolved = lower(resolved);
            lowADS = lower(ADS_ROOT);
            lowWRK = lower(ADS_WORKSPACE);

            if startsWith(lowResolved,lowADS)
                category = 'SYSTEM';
            elseif startsWith(lowResolved,lowWRK)
                category = 'LOCAL';
            else
                category = 'EXTERNAL';
            end

            pathOK = isfile(resolved);

        end

        fprintf('\n[%s] INCLUDE\n',category);
        fprintf('  Raw     : %s\n',rawPath);
        fprintf('  Resolved: %s\n',resolved);

        if pathOK
            fprintf('  Status  : [OK]\n');
        else
            fprintf('  Status  : [BROKEN]\n');
            brokenCount = brokenCount + 1;
        end

        e.type = 'INCLUDE';
        e.name = '';
        e.raw = rawPath;
        e.resolved = resolved;
        e.category = category;
        e.exists = pathOK;

        libraryReport(end+1) = e; %#ok<SAGROW>

        continue;

    end

    % ---------------------------------------------------------------------
    % DEFINE
    % ---------------------------------------------------------------------

    if startsWith(upperLine,'DEFINE ')

        defineCount = defineCount + 1;

        rest = strtrim(line(7:end));

        firstSpace = find(isspace(rest),1,'first');

        if isempty(firstSpace)

            fprintf('\n[BROKEN] DEFINE line cannot be parsed:\n');
            fprintf('  %s\n',line);

            brokenCount = brokenCount + 1;
            continue;

        end

        libName = strtrim(rest(1:firstSpace-1));
        rawPath = strtrim(rest(firstSpace+1:end));

        % Remove surrounding "..." or '...'
        if numel(rawPath) >= 2

            firstCode = double(rawPath(1));
            lastCode  = double(rawPath(end));

            removeQuotes = false;

            if firstCode == 34
                if lastCode == 34
                    removeQuotes = true;
                end
            elseif firstCode == 39
                if lastCode == 39
                    removeQuotes = true;
                end
            end

            if removeQuotes
                rawPath = rawPath(2:end-1);
            end

        end

        resolved = rawPath;

        resolved = strrep(resolved,'${HPEESOF_DIR}',ADS_ROOT);
        resolved = strrep(resolved,'$HPEESOF_DIR',ADS_ROOT);
        resolved = strrep(resolved,'/',filesep);

        isAbsolute = false;

        if numel(resolved) >= 3
            if resolved(2) == ':'
                if resolved(3) == filesep
                    isAbsolute = true;
                end
            end
        end

        if ~isAbsolute
            resolved = fullfile(ADS_WORKSPACE,resolved);
        end

        lowResolved = lower(resolved);
        lowADS = lower(ADS_ROOT);
        lowWRK = lower(ADS_WORKSPACE);

        if startsWith(lowResolved,lowADS)
            category = 'SYSTEM';
        elseif startsWith(lowResolved,lowWRK)
            category = 'LOCAL';
        else
            category = 'EXTERNAL';
        end

        pathOK = isfolder(resolved);

        if ~pathOK
            pathOK = isfile(resolved);
        end

        fprintf('\n[%s] %s\n',category,libName);
        fprintf('  Raw     : %s\n',rawPath);
        fprintf('  Resolved: %s\n',resolved);

        if pathOK
            fprintf('  Status  : [OK]\n');
        else
            fprintf('  Status  : [BROKEN]\n');
            brokenCount = brokenCount + 1;
        end

        e.type = 'DEFINE';
        e.name = libName;
        e.raw = rawPath;
        e.resolved = resolved;
        e.category = category;
        e.exists = pathOK;

        libraryReport(end+1) = e; %#ok<SAGROW>

        continue;

    end

end

%% 6. Summary

fprintf('\n');
fprintf('====================================================================\n');
fprintf(' WORKSPACE DOCTOR RESULT\n');
fprintf('====================================================================\n');

fprintf('\nWorkspace:\n');
fprintf('  %s\n',ADS_WORKSPACE);

fprintf('\nConfiguration:\n');

for k = 1:numel(configNames)

    if configOK(k)
        fprintf('  [OK]   %s\n',configNames{k});
    else
        fprintf('  [MISS] %s\n',configNames{k});
    end

end

fprintf('\nLibraries:\n');
fprintf('  INCLUDE references : %d\n',includeCount);
fprintf('  DEFINE references  : %d\n',defineCount);
fprintf('  Broken references  : %d\n',brokenCount);

ADS_WORKSPACE_REPORT = struct();
ADS_WORKSPACE_REPORT.version = '0.2.3';
ADS_WORKSPACE_REPORT.workspace = ADS_WORKSPACE;
ADS_WORKSPACE_REPORT.adsRoot = ADS_ROOT;
ADS_WORKSPACE_REPORT.configNames = configNames;
ADS_WORKSPACE_REPORT.configOK = configOK;
ADS_WORKSPACE_REPORT.libraries = libraryReport;
ADS_WORKSPACE_REPORT.brokenReferenceCount = brokenCount;

if brokenCount == 0

    ADS_WORKSPACE_REPORT.step2Passed = true;

    fprintf('\n');
    fprintf('--------------------------------------------------------------------\n');
    fprintf(' STEP 2 PASSED\n');
    fprintf('--------------------------------------------------------------------\n');

    fprintf('\nWorkspace and library references are valid.\n');
    fprintf('Next development step:\n');
    fprintf('  ADS Runtime / DLL environment setup\n');

else

    ADS_WORKSPACE_REPORT.step2Passed = false;

    fprintf('\n');
    fprintf('--------------------------------------------------------------------\n');
    fprintf(' STEP 2 NEEDS ATTENTION\n');
    fprintf('--------------------------------------------------------------------\n');

    fprintf('\nOne or more library references are broken.\n');

end

fprintf('\n====================================================================\n');
