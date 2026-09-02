%% ========================================================================
% ADS-MATLAB Bridge - SP Filter Branch
% generate_filter_variables.m
% Internal module: sp/internal/generate_filter_variables.m
%
% Version: 0.1.2
%
% Purpose:
%   Read numeric design parameters from the selected ADS formal netlist
%   and generate a HUMAN-READABLE editable optimization-variable file.
%
% Default suggestion rules:
%   Lower = Initial - 50% * abs(Initial)
%   Upper = Initial + 50% * abs(Initial)
%   Step  = 10% * abs(Initial)
%
% IMPORTANT:
%   These values are suggestions only.
%   The user should review/edit each row before optimization.
%
% Netlist selection priority:
%   1) ADS_BASELINE_REPORT.formalNetlist
%   2) FORMAL_NETLIST in current MATLAB workspace
%   3) <ADS_WORKSPACE>\netlist.log
%   4) Manual file selection
%
% Output:
%   <ADS_WORKSPACE>\ADS_MATLAB_BRIDGE_Run\Config\sp_variables.m
%
% The original ADS netlist is NEVER modified.
% ========================================================================

clc;

fprintf('\n============================================================\n');
fprintf(' ADS-MATLAB BRIDGE - GENERATE FILTER VARIABLES  v0.1.2\n');
fprintf('============================================================\n');

%% ------------------------------------------------------------------------
% 1. Resolve formal ADS netlist
% -------------------------------------------------------------------------

formalNetlist = '';

if exist('ADS_BASELINE_REPORT','var') && isstruct(ADS_BASELINE_REPORT)
    if isfield(ADS_BASELINE_REPORT,'formalNetlist')
        candidate = char(ADS_BASELINE_REPORT.formalNetlist);
        if isfile(candidate)
            formalNetlist = candidate;
            fprintf('\n[REUSE] Netlist from ADS_BASELINE_REPORT:\n%s\n',formalNetlist);
        end
    end
end

if isempty(formalNetlist) && exist('FORMAL_NETLIST','var')
    candidate = char(FORMAL_NETLIST);
    if isfile(candidate)
        formalNetlist = candidate;
        fprintf('\n[REUSE] Netlist from FORMAL_NETLIST:\n%s\n',formalNetlist);
    end
end

if isempty(formalNetlist) && exist('ADS_WORKSPACE','var')
    candidate = fullfile(char(ADS_WORKSPACE),'netlist.log');
    if isfile(candidate)
        formalNetlist = candidate;
        fprintf('\n[FOUND] Workspace default netlist:\n%s\n',formalNetlist);
    end
end

if isempty(formalNetlist)
    
    if exist('ADS_WORKSPACE','var') && isfolder(char(ADS_WORKSPACE))
        startFolder = char(ADS_WORKSPACE);
    else
        startFolder = pwd;
    end
    
    [fileName,filePath] = uigetfile( ...
        {'*.log;*.net;*.ckt;*.cir','ADS / circuit netlists'; ...
        '*.*','All files'}, ...
        'Select ADS-generated Netlist', ...
        startFolder);
    
    if isequal(fileName,0)
        error('Netlist selection cancelled.');
    end
    
    formalNetlist = fullfile(filePath,fileName);
end

if ~isfile(formalNetlist)
    error('Formal netlist does not exist: %s',formalNetlist);
end

FORMAL_NETLIST = formalNetlist;

%% ------------------------------------------------------------------------
% 2. Resolve ADS workspace
% -------------------------------------------------------------------------

if exist('ADS_WORKSPACE','var') && isfolder(char(ADS_WORKSPACE))
    workspace = char(ADS_WORKSPACE);
else
    workspace = fileparts(formalNetlist);
    ADS_WORKSPACE = workspace;
end

fprintf('\n[OK] ADS workspace:\n%s\n',workspace);
fprintf('\n[OK] Formal netlist:\n%s\n',formalNetlist);

%% ------------------------------------------------------------------------
% 3. Read numeric top-level parameter assignments
% -------------------------------------------------------------------------

netText = fileread(formalNetlist);

if isempty(strtrim(netText))
    error('Selected netlist is empty.');
end

tokens = regexp( ...
    netText, ...
    '(?m)^[ \t]*([A-Za-z_]\w*)[ \t]*=[ \t]*([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)', ...
    'tokens');

if isempty(tokens)
    error(['No top-level numeric parameter assignments were detected. ' ...
        'Confirm that the ADS design parameters are present in the generated netlist.']);
end

names = strings(0,1);
initial = zeros(0,1);

% Known ADS/internal/control assignments that are not design variables.
skipNames = [ ...
    "Start","Stop","Step","Center","Span", ...
    "SweepVar","SimInstanceName","UseNutmegFormat", ...
    "EquationNestLevel","SavedEquationNestLevel"];

for k = 1:numel(tokens)
    
    name = string(tokens{k}{1});
    value = str2double(tokens{k}{2});
    
    if isnan(value)
        continue;
    end
    
    if any(strcmpi(name,skipNames))
        continue;
    end
    
    if any(strcmp(names,name))
        continue;
    end
    
    names(end+1,1) = name; %#ok<SAGROW>
    initial(end+1,1) = value; %#ok<SAGROW>
end

if isempty(names)
    error('No usable numeric design parameters remained after inspection.');
end

%% ------------------------------------------------------------------------
% 4. Generate default suggestions
% -------------------------------------------------------------------------

rangePercent = 0.50;
stepPercent = 0.10;

delta = abs(initial) * rangePercent;

lower = initial - delta;
upper = initial + delta;
step = abs(initial) * stepPercent;

enable = true(size(initial));
needsReview = false(size(initial));

zeroMask = (initial == 0);

lower(zeroMask) = 0;
upper(zeroMask) = 0;
step(zeroMask) = NaN;
enable(zeroMask) = false;
needsReview(zeroMask) = true;

%% ------------------------------------------------------------------------
% 5. Prepare configuration directory
% -------------------------------------------------------------------------

configDir = fullfile(workspace,'ADS_MATLAB_BRIDGE_Run','Config');

if ~isfolder(configDir)
    mkdir(configDir);
end

configFile = fullfile(configDir,'sp_variables.m');

%% ------------------------------------------------------------------------
% 6. Protect existing user-edited config
% -------------------------------------------------------------------------

if isfile(configFile)
    
    fprintf('\n[ATTENTION] A variable configuration already exists:\n%s\n',configFile);
    
    answer = input('Overwrite it with a newly generated configuration? [y/N]: ','s');
    
    if isempty(answer) || ~(strcmpi(strtrim(answer),'y') || ...
            strcmpi(strtrim(answer),'yes'))
        
        FILTER_VARIABLES_FILE = configFile;
        
        fprintf('\nExisting configuration was kept unchanged.\n');
        fprintf('Open and edit:\n%s\n',configFile);
        fprintf('============================================================\n');
        return;
    end
end

%% ------------------------------------------------------------------------
% 7. Write HUMAN-READABLE configuration
% -------------------------------------------------------------------------

fid = fopen(configFile,'w');

if fid < 0
    error('Cannot create filter variable configuration: %s',configFile);
end

cleanupObj = onCleanup(@() safeClose(fid));

fprintf(fid,'%% ========================================================================\n');
fprintf(fid,'%% ADS-MATLAB Bridge - SP Filter Variable Configuration\n');
fprintf(fid,'%% AUTO-GENERATED by generate_filter_variables.m v0.1.2\n');
fprintf(fid,'%%\n');
fprintf(fid,'%% Source netlist:\n');
fprintf(fid,'%%   %s\n',formalNetlist);
fprintf(fid,'%%\n');
fprintf(fid,'%% DEFAULT SUGGESTIONS:\n');
fprintf(fid,'%%   Lower = Initial - 50%%\n');
fprintf(fid,'%%   Upper = Initial + 50%%\n');
fprintf(fid,'%%   Step  = 10%% of abs(Initial)\n');
fprintf(fid,'%%\n');
fprintf(fid,'%% USER ACTION:\n');
fprintf(fid,'%%   Edit each row below directly.\n');
fprintf(fid,'%%   Name / Initial / Lower / Upper / Step / Enable\n');
fprintf(fid,'%%   Enable = true  -> optimize this variable\n');
fprintf(fid,'%%   Enable = false -> keep this variable fixed\n');
fprintf(fid,'%% ========================================================================\n\n');

fprintf(fid,'%% ------------------------------------------------------------------------\n');
fprintf(fid,'%% EDIT THIS BLOCK\n');
fprintf(fid,'%% ------------------------------------------------------------------------\n');
fprintf(fid,'%% Name          Initial       Lower         Upper         Step          Enable\n');
fprintf(fid,'VAR_CFG = {\n');

% Determine alignment width, at least 12 chars.
nameWidth = max(12, max(strlength(names)) + 2);

for k = 1:numel(names)
    
    if isnan(step(k))
        stepText = 'NaN';
    else
        stepText = sprintf('%.12g',step(k));
    end
    
    if enable(k)
        enableText = 'true';
    else
        enableText = 'false';
    end
    
    quotedName = ['"' char(names(k)) '"'];
    fprintf(fid,'    %-*s,  %12s,  %12s,  %12s,  %12s,  %s;\n', ...
        nameWidth + 2, quotedName, ...
        sprintf('%.12g',initial(k)), ...
        sprintf('%.12g',lower(k)), ...
        sprintf('%.12g',upper(k)), ...
        stepText, ...
        enableText);
end

fprintf(fid,'};\n\n');

fprintf(fid,'%% ------------------------------------------------------------------------\n');
fprintf(fid,'%% DO NOT EDIT BELOW UNLESS YOU KNOW WHAT YOU ARE DOING\n');
fprintf(fid,'%% Convert the readable block above into the standard FILTER_VARS table.\n');
fprintf(fid,'%% ------------------------------------------------------------------------\n\n');

fprintf(fid,'FILTER_VARS = table( ...\n');
fprintf(fid,'    string(VAR_CFG(:,1)), ...\n');
fprintf(fid,'    cell2mat(VAR_CFG(:,2)), ...\n');
fprintf(fid,'    cell2mat(VAR_CFG(:,3)), ...\n');
fprintf(fid,'    cell2mat(VAR_CFG(:,4)), ...\n');
fprintf(fid,'    cell2mat(VAR_CFG(:,5)), ...\n');
fprintf(fid,'    cell2mat(VAR_CFG(:,6)), ...\n');
fprintf(fid,'    ''VariableNames'',{''Name'',''Initial'',''Lower'',''Upper'',''Step'',''Enable''});\n\n');
fprintf(fid,'clear VAR_CFG;\n');

if any(needsReview)
    fprintf(fid,'\n%% REVIEW REQUIRED:\n');
    idx = find(needsReview);
    for q = 1:numel(idx)
        k = idx(q);
        fprintf(fid,'%%   %s has Initial = 0. Set Lower / Upper / Step before enabling it.\n',names(k));
    end
end

fclose(fid);
clear cleanupObj;

FILTER_VARIABLES_FILE = configFile;

%% ------------------------------------------------------------------------
% 8. Console preview
% -------------------------------------------------------------------------

preview = table(names,initial,lower,upper,step,enable, ...
    'VariableNames',{'Name','Initial','Lower','Upper','Step','Enable'});

fprintf('\n============================================================\n');
fprintf(' FILTER VARIABLE CONFIGURATION GENERATED\n');
fprintf('============================================================\n\n');

disp(preview);

fprintf('Detected variables : %d\n',height(preview));
fprintf('Default range      : Initial +/- 50%%\n');
fprintf('Default step       : 10%% of abs(Initial)\n');

if any(needsReview)
    fprintf('\n[REVIEW REQUIRED] %d zero-valued parameter(s) were disabled.\n', ...
        nnz(needsReview));
end

fprintf('\nGenerated file:\n%s\n',configFile);

fprintf('\nNEXT ACTION:\n');
fprintf('  Open sp_variables.m and edit the row-wise variable table.\n');

fprintf('\nThe ADS formal netlist was NOT modified.\n');
fprintf('============================================================\n');


function safeClose(fid)

if isnumeric(fid) && isscalar(fid) && fid > 0
    try
        fclose(fid);
    catch
    end
end

end
