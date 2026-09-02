function result = analyze_sparameters(rawInput,outDir)
%ANALYZE_SPARAMETERS Extract, save, and visualize S11/S21 from ADS RAW.
% Internal module: sp/internal/analyze_sparameters.m
%
% result = analyze_sparameters(rawFile)
% result = analyze_sparameters(rawStruct)
% result = analyze_sparameters(rawInput,outDir)
%
% Version: 0.1.0
%
% This function belongs to the sp-filter branch.
% It performs only S-parameter-specific baseline analysis.
%
% Outputs:
%   sp_baseline_sparameters.csv
%   sp_baseline_sparameters.mat
%   sp_baseline_sparameters.png
%   sp_baseline_sparameters.fig
%   sp_baseline_summary.txt
%   sp_baseline_result.mat
%
% No optimization targets are applied here. Target definitions belong to
% the later filter-target / objective-function layer.

%% ------------------------------------------------------------------------
% 1. Read or reuse parsed RAW
% -------------------------------------------------------------------------

if nargin < 1 || isempty(rawInput)
    raw = read_ads_raw();
elseif isstruct(rawInput)
    raw = rawInput;
else
    raw = read_ads_raw(rawInput);
end

if nargin < 2 || isempty(outDir)
    outDir = fullfile(fileparts(raw.file),'SP_Filter');
end

if ~isfolder(outDir)
    mkdir(outDir);
end

%% ------------------------------------------------------------------------
% 2. Find a plot containing freq, S11, and S21
% -------------------------------------------------------------------------

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

    fprintf('\nAvailable RAW plots and variables:\n');

    for p = 1:raw.plotCount

        fprintf('\nPlot %d: %s\n',p,raw.plots(p).plotName);

        vars = raw.plots(p).variables;

        for k = 1:numel(vars)
            fprintf('  [%d] %s\n',vars(k).index,vars(k).name);
        end

    end

    error(['No RAW plot containing freq + S11 + S21 was found. ' ...
           'Confirm that the selected ADS netlist is an S-parameter simulation.']);

end

%% ------------------------------------------------------------------------
% 3. Extract S-parameter data
% -------------------------------------------------------------------------

freq = ads_raw_get(raw,'freq',spPlot);

S11 = getAny(raw,spPlot,{'S[1,1]','S(1,1)','S11'});
S21 = getAny(raw,spPlot,{'S[2,1]','S(2,1)','S21'});

freqGHz = normalizeFrequencyGHz(real(freq));

freqGHz = freqGHz(:);
S11 = S11(:);
S21 = S21(:);

if numel(freqGHz) ~= numel(S11) || numel(freqGHz) ~= numel(S21)
    error('Frequency, S11, and S21 arrays do not have matching lengths.');
end

S11dB = 20*log10(max(abs(S11),1e-15));
S21dB = 20*log10(max(abs(S21),1e-15));

%% ------------------------------------------------------------------------
% 4. Save S-parameter data
% -------------------------------------------------------------------------

T = table( ...
    freqGHz, ...
    S11, ...
    S21, ...
    S11dB, ...
    S21dB, ...
    'VariableNames', ...
    {'Frequency_GHz','S11','S21','S11_dB','S21_dB'});

csvFile = fullfile(outDir,'sp_baseline_sparameters.csv');
matFile = fullfile(outDir,'sp_baseline_sparameters.mat');

writetable(T,csvFile);

save(matFile, ...
    'freqGHz','S11','S21','S11dB','S21dB','spPlot');

%% ------------------------------------------------------------------------
% 5. Plot S11 and S21
% -------------------------------------------------------------------------

fig = figure( ...
    'Name','ADS-MATLAB Bridge - SP Baseline', ...
    'Color','w');

plot(freqGHz,S11dB,'LineWidth',1.5);
hold on;
plot(freqGHz,S21dB,'LineWidth',1.5);

grid on;
box on;

xlabel('Frequency (GHz)');
ylabel('Magnitude (dB)');
title('Baseline S-Parameters');
legend('S11','S21','Location','best');

pngFile = fullfile(outDir,'sp_baseline_sparameters.png');
figFile = fullfile(outDir,'sp_baseline_sparameters.fig');

saveas(fig,pngFile);
savefig(fig,figFile);

%% ------------------------------------------------------------------------
% 6. Build result structure
% -------------------------------------------------------------------------

result = struct();

result.version = '0.1.0';
result.outputDir = outDir;
result.rawFile = raw.file;
result.plotIndex = spPlot;
result.plotName = raw.plots(spPlot).plotName;

result.freqGHz = freqGHz;
result.S11 = S11;
result.S21 = S21;
result.S11dB = S11dB;
result.S21dB = S21dB;

result.globalWorstS11dB = max(S11dB);
result.globalMinimumS21dB = min(S21dB);

result.csvFile = csvFile;
result.matFile = matFile;
result.pngFile = pngFile;
result.figFile = figFile;

%% ------------------------------------------------------------------------
% 7. Write SP-specific summary
% -------------------------------------------------------------------------

summaryFile = fullfile(outDir,'sp_baseline_summary.txt');

fid = fopen(summaryFile,'w');

if fid < 0
    error('Cannot create SP baseline summary: %s',summaryFile);
end

cleanupObj = onCleanup(@() safeClose(fid));

fprintf(fid,'ADS-MATLAB Bridge - SP Baseline Summary\n');
fprintf(fid,'Version: 0.1.0\n\n');

fprintf(fid,'RAW file: %s\n',raw.file);
fprintf(fid,'RAW plot index: %d\n',spPlot);
fprintf(fid,'RAW plot name: %s\n\n',raw.plots(spPlot).plotName);

fprintf(fid,'Frequency range: %.9f to %.9f GHz\n', ...
    min(freqGHz),max(freqGHz));

fprintf(fid,'Points: %d\n',numel(freqGHz));
fprintf(fid,'Global worst S11: %.9f dB\n',result.globalWorstS11dB);
fprintf(fid,'Global minimum S21: %.9f dB\n',result.globalMinimumS21dB);

fprintf(fid,'\nNo passband, stopband, or optimization target was applied.\n');

fclose(fid);
clear cleanupObj;

result.summaryFile = summaryFile;

resultFile = fullfile(outDir,'sp_baseline_result.mat');
result.resultFile = resultFile;

save(resultFile,'result','-v7.3');

%% ------------------------------------------------------------------------
% 8. Console report
% -------------------------------------------------------------------------

fprintf('\n============================================================\n');
fprintf(' S-PARAMETER BASELINE RESULT\n');
fprintf('============================================================\n');

fprintf('RAW plot : %d\n',spPlot);
fprintf('Plot name: %s\n',raw.plots(spPlot).plotName);

fprintf('\nFrequency range : %.6f to %.6f GHz\n', ...
    min(freqGHz),max(freqGHz));

fprintf('Points          : %d\n',numel(freqGHz));
fprintf('Worst S11      : %.6f dB\n',result.globalWorstS11dB);
fprintf('Minimum S21    : %.6f dB\n',result.globalMinimumS21dB);

fprintf('\nSaved:\n');
fprintf('  sp_baseline_sparameters.csv\n');
fprintf('  sp_baseline_sparameters.mat\n');
fprintf('  sp_baseline_sparameters.png\n');
fprintf('  sp_baseline_sparameters.fig\n');
fprintf('  sp_baseline_summary.txt\n');
fprintf('  sp_baseline_result.mat\n');

fprintf('============================================================\n');

end


function value = getAny(raw,plotIndex,names)
%GETANY Return the first matching ADS RAW variable name.

for k = 1:numel(names)

    try
        value = ads_raw_get(raw,names{k},plotIndex);
        return;
    catch
    end

end

error('None of the requested S-parameter variable names were found.');

end


function freqGHz = normalizeFrequencyGHz(freq)
%NORMALIZEFREQUENCYGHZ Convert ADS frequency values to GHz when needed.

freq = real(freq(:));

if isempty(freq)
    error('Frequency array is empty.');
end

if max(abs(freq)) > 1e6
    freqGHz = freq/1e9;
else
    freqGHz = freq;
end

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
