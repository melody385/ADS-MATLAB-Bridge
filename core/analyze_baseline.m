function result = analyze_baseline(rawInput,outDir)
%ANALYZE_BASELINE Save and summarize a generic ADS RAW baseline result.
% Core module: core/analyze_baseline.m
%
% result = analyze_baseline(rawFile)
% result = analyze_baseline(rawFile,outDir)
%
% Version: 0.6.0
%
% This MAIN/Core analyzer is deliberately simulation-type agnostic.
% It does NOT interpret application-specific quantities or metrics.
%
% Generic outputs:
%   baseline_raw_data.mat
%   baseline_inventory.csv
%   baseline_summary.txt
%   baseline_result.mat
%
% Application-specific branches should use the parsed RAW structure and
% ads_raw_get.m to perform their own calculations and visualizations.

%% ------------------------------------------------------------------------
% 1. Read RAW
% -------------------------------------------------------------------------

if nargin < 1 || isempty(rawInput)
    raw = read_ads_raw();
elseif isstruct(rawInput)
    raw = rawInput;
else
    raw = read_ads_raw(rawInput);
end

if nargin < 2 || isempty(outDir)
    outDir = fullfile(fileparts(raw.file),'Baseline_Result');
end

if ~isfolder(outDir)
    mkdir(outDir);
end

%% ------------------------------------------------------------------------
% 2. Build generic result structure
% -------------------------------------------------------------------------

result = struct();
result.version = '0.6.0';
result.outputDir = outDir;
result.rawFile = raw.file;
result.plotCount = raw.plotCount;
result.raw = raw;

%% ------------------------------------------------------------------------
% 3. Save complete parsed RAW data
% -------------------------------------------------------------------------

save(fullfile(outDir,'baseline_raw_data.mat'),'raw','-v7.3');

%% ------------------------------------------------------------------------
% 4. Build generic variable inventory for every RAW plot
% -------------------------------------------------------------------------

plotCol = [];
plotNameCol = strings(0,1);
varIndexCol = [];
varNameCol = strings(0,1);
varTypeCol = strings(0,1);

for p = 1:raw.plotCount
    
    vars = raw.plots(p).variables;
    
    for k = 1:numel(vars)
        
        plotCol(end+1,1) = p; %#ok<AGROW>
        plotNameCol(end+1,1) = string(raw.plots(p).plotName); %#ok<AGROW>
        varIndexCol(end+1,1) = vars(k).index; %#ok<AGROW>
        varNameCol(end+1,1) = string(vars(k).name); %#ok<AGROW>
        varTypeCol(end+1,1) = string(vars(k).type); %#ok<AGROW>
        
    end
    
end

inventory = table( ...
    plotCol, ...
    plotNameCol, ...
    varIndexCol, ...
    varNameCol, ...
    varTypeCol, ...
    'VariableNames', ...
    {'Plot','PlotName','VariableIndex','VariableName','VariableType'});

writetable(inventory,fullfile(outDir,'baseline_inventory.csv'));

result.inventory = inventory;

%% ------------------------------------------------------------------------
% 5. Write generic text summary
% -------------------------------------------------------------------------

summaryFile = fullfile(outDir,'baseline_summary.txt');

fid = fopen(summaryFile,'w');

if fid < 0
    error('Cannot create baseline summary file: %s',summaryFile);
end

summaryCleanup = onCleanup(@() safeClose(fid));

fprintf(fid,'ADS-MATLAB Bridge Generic Baseline Summary\n');
fprintf(fid,'Version: 0.6.0\n\n');

fprintf(fid,'RAW file: %s\n',raw.file);
fprintf(fid,'RAW size: %d bytes\n',raw.fileBytes);
fprintf(fid,'Plots: %d\n',raw.plotCount);
fprintf(fid,'Inventory rows: %d\n\n',height(inventory));

for p = 1:raw.plotCount
    
    P = raw.plots(p);
    
    fprintf(fid,'============================================================\n');
    fprintf(fid,'Plot %d\n',p);
    fprintf(fid,'============================================================\n');
    
    fprintf(fid,'Title: %s\n',P.title);
    fprintf(fid,'Date: %s\n',P.date);
    fprintf(fid,'Plotname: %s\n',P.plotName);
    fprintf(fid,'Mode: %s\n',P.mode);
    fprintf(fid,'Flags: %s\n',P.flags);
    fprintf(fid,'Variables: %d\n',P.nVariables);
    fprintf(fid,'Points: %d\n',P.nPoints);
    
    fprintf(fid,'\nReturned variables:\n');
    
    if isempty(P.variables)
        
        fprintf(fid,'  <none>\n');
        
    else
        
        for k = 1:numel(P.variables)
            
            fprintf(fid,'  [%d] %s    %s\n', ...
                P.variables(k).index, ...
                P.variables(k).name, ...
                P.variables(k).type);
            
        end
        
    end
    
    fprintf(fid,'\n');
    
end

fprintf(fid,'============================================================\n');
fprintf(fid,'No application-specific metric was calculated.\n');
fprintf(fid,'Use an application branch (for example sp-filter or hb-pa)\n');
fprintf(fid,'to interpret the returned RAW variables.\n');
fprintf(fid,'============================================================\n');

fclose(fid);
clear summaryCleanup;

%% ------------------------------------------------------------------------
% 6. Save generic result structure
% -------------------------------------------------------------------------

save(fullfile(outDir,'baseline_result.mat'),'result','-v7.3');

%% ------------------------------------------------------------------------
% 7. Console report
% -------------------------------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' GENERIC BASELINE ANALYSIS RESULT\n');
fprintf('============================================================\n');

fprintf('Output folder:\n%s\n',outDir);

fprintf('\nRAW plots parsed : %d\n',raw.plotCount);
fprintf('Variables listed : %d\n',height(inventory));

fprintf('\nSaved:\n');
fprintf('  baseline_raw_data.mat\n');
fprintf('  baseline_inventory.csv\n');
fprintf('  baseline_summary.txt\n');
fprintf('  baseline_result.mat\n');

fprintf('\nNo application-specific metric\n');
fprintf('was calculated in the Bridge Core.\n');

fprintf('============================================================\n');

end


function safeClose(fid)
%SAFECLOSE Close a file only when the identifier is still valid.

if isnumeric(fid) && isscalar(fid) && fid > 0
    try
        fclose(fid);
    catch
    end
end

end
