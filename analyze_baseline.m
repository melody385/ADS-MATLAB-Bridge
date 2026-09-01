function result = analyze_baseline(rawInput,outDir,cfg)
%ANALYZE_BASELINE Save and visualize a baseline ADS RAW result.
%
% result = analyze_baseline(rawFile)
% result = analyze_baseline(rawFile,outDir)
% result = analyze_baseline(rawFile,outDir,cfg)
%
% Generic outputs:
%   baseline_raw_data.mat
%   baseline_inventory.csv
%   baseline_summary.txt
%
% If an S-parameter plot is detected:
%   baseline_sparameters.csv
%   baseline_sparameters.mat
%   baseline_sparameters.png
%   baseline_sparameters.fig
%
% Optional cfg:
%   cfg.passbandGHz = [f1 f2]
%   cfg.stopbandGHz = [f1 f2]
%   cfg.s11MaxdB    = -12
%   cfg.s21MinPBdB  = -1
%   cfg.s21MaxSBdB  = -18

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

if nargin < 3 || isempty(cfg)
    cfg = struct();
end

if ~isfolder(outDir)
    mkdir(outDir);
end

result = struct();
result.version = '0.5.0';
result.outputDir = outDir;
result.raw = raw;
result.sParameterDetected = false;
result.metrics = struct();

save(fullfile(outDir,'baseline_raw_data.mat'),'raw','-v7.3');

plotCol = [];
plotNameCol = strings(0,1);
varIndexCol = [];
varNameCol = strings(0,1);
varTypeCol = strings(0,1);

for p = 1:raw.plotCount
    for k = 1:numel(raw.plots(p).variables)

        plotCol(end+1,1) = p; %#ok<AGROW>
        plotNameCol(end+1,1) = string(raw.plots(p).plotName); %#ok<AGROW>
        varIndexCol(end+1,1) = raw.plots(p).variables(k).index; %#ok<AGROW>
        varNameCol(end+1,1) = string(raw.plots(p).variables(k).name); %#ok<AGROW>
        varTypeCol(end+1,1) = string(raw.plots(p).variables(k).type); %#ok<AGROW>

    end
end

inventory = table(plotCol,plotNameCol,varIndexCol,varNameCol,varTypeCol, ...
    'VariableNames',{'Plot','PlotName','VariableIndex','VariableName','VariableType'});

writetable(inventory,fullfile(outDir,'baseline_inventory.csv'));

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

summaryFile = fullfile(outDir,'baseline_summary.txt');
fid = fopen(summaryFile,'w');

fprintf(fid,'ADS-MATLAB Bridge Baseline Summary\n');
fprintf(fid,'Version: 0.5.0\n\n');
fprintf(fid,'RAW file: %s\n',raw.file);
fprintf(fid,'Plots: %d\n\n',raw.plotCount);

for p = 1:raw.plotCount
    fprintf(fid,'Plot %d: %s\n',p,raw.plots(p).plotName);
    fprintf(fid,'  Flags: %s\n',raw.plots(p).flags);
    fprintf(fid,'  Variables: %d\n',raw.plots(p).nVariables);
    fprintf(fid,'  Points: %d\n\n',raw.plots(p).nPoints);
end

if spPlot > 0

    result.sParameterDetected = true;
    result.sParameterPlot = spPlot;

    freq = ads_raw_get(raw,'freq',spPlot);

    S11 = getAny(raw,spPlot,{'S[1,1]','S(1,1)','S11'});
    S21 = getAny(raw,spPlot,{'S[2,1]','S(2,1)','S21'});

    freqGHz = normalizeFrequencyGHz(real(freq));

    S11dB = 20*log10(max(abs(S11),1e-15));
    S21dB = 20*log10(max(abs(S21),1e-15));

    T = table(freqGHz,S11,S21,S11dB,S21dB, ...
        'VariableNames',{'Frequency_GHz','S11','S21','S11_dB','S21_dB'});

    writetable(T,fullfile(outDir,'baseline_sparameters.csv'));

    save(fullfile(outDir,'baseline_sparameters.mat'), ...
        'freqGHz','S11','S21','S11dB','S21dB');

    fig = figure('Name','ADS-MATLAB Baseline S-Parameters','Color','w');

    plot(freqGHz,S11dB,'LineWidth',1.5);
    hold on;
    plot(freqGHz,S21dB,'LineWidth',1.5);

    grid on;
    box on;

    xlabel('Frequency (GHz)');
    ylabel('Magnitude (dB)');
    title('Baseline S-Parameters');
    legend('S11','S21','Location','best');

    saveas(fig,fullfile(outDir,'baseline_sparameters.png'));
    savefig(fig,fullfile(outDir,'baseline_sparameters.fig'));

    result.freqGHz = freqGHz;
    result.S11 = S11;
    result.S21 = S21;
    result.S11dB = S11dB;
    result.S21dB = S21dB;

    metrics = struct();
    metrics.globalWorstS11dB = max(S11dB);
    metrics.globalMinS21dB = min(S21dB);

    fprintf(fid,'S-parameter baseline detected in plot %d.\n',spPlot);
    fprintf(fid,'Frequency range: %.6f to %.6f GHz\n',min(freqGHz),max(freqGHz));
    fprintf(fid,'Points: %d\n',numel(freqGHz));
    fprintf(fid,'Global worst S11: %.6f dB\n',metrics.globalWorstS11dB);
    fprintf(fid,'Global minimum S21: %.6f dB\n\n',metrics.globalMinS21dB);

    if isfield(cfg,'passbandGHz') && numel(cfg.passbandGHz) == 2

        pb = freqGHz >= cfg.passbandGHz(1) & ...
             freqGHz <= cfg.passbandGHz(2);

        if any(pb)

            metrics.passbandGHz = cfg.passbandGHz;
            metrics.pbWorstS11dB = max(S11dB(pb));
            metrics.pbWorstS21dB = min(S21dB(pb));
            metrics.pbS21RippledB = max(S21dB(pb))-min(S21dB(pb));

            fprintf(fid,'Passband %.6f to %.6f GHz\n', ...
                cfg.passbandGHz(1),cfg.passbandGHz(2));

            fprintf(fid,'  Worst S11: %.6f dB\n',metrics.pbWorstS11dB);
            fprintf(fid,'  Worst S21: %.6f dB\n',metrics.pbWorstS21dB);
            fprintf(fid,'  S21 ripple: %.6f dB\n',metrics.pbS21RippledB);

        end

    end

    if isfield(cfg,'stopbandGHz') && numel(cfg.stopbandGHz) == 2

        sb = freqGHz >= cfg.stopbandGHz(1) & ...
             freqGHz <= cfg.stopbandGHz(2);

        if any(sb)

            metrics.stopbandGHz = cfg.stopbandGHz;
            metrics.sbWorstS21dB = max(S21dB(sb));
            metrics.sbMeanS21dB = mean(S21dB(sb));

            fprintf(fid,'\nStopband %.6f to %.6f GHz\n', ...
                cfg.stopbandGHz(1),cfg.stopbandGHz(2));

            fprintf(fid,'  Worst S21: %.6f dB\n',metrics.sbWorstS21dB);
            fprintf(fid,'  Mean S21: %.6f dB\n',metrics.sbMeanS21dB);

        end

    end

    checks = {};
    passes = [];

    if isfield(metrics,'pbWorstS11dB') && isfield(cfg,'s11MaxdB')
        checks{end+1,1} = sprintf('Passband S11 <= %.3f dB',cfg.s11MaxdB); %#ok<AGROW>
        passes(end+1,1) = metrics.pbWorstS11dB <= cfg.s11MaxdB; %#ok<AGROW>
    end

    if isfield(metrics,'pbWorstS21dB') && isfield(cfg,'s21MinPBdB')
        checks{end+1,1} = sprintf('Passband S21 >= %.3f dB',cfg.s21MinPBdB); %#ok<AGROW>
        passes(end+1,1) = metrics.pbWorstS21dB >= cfg.s21MinPBdB; %#ok<AGROW>
    end

    if isfield(metrics,'sbWorstS21dB') && isfield(cfg,'s21MaxSBdB')
        checks{end+1,1} = sprintf('Stopband S21 <= %.3f dB',cfg.s21MaxSBdB); %#ok<AGROW>
        passes(end+1,1) = metrics.sbWorstS21dB <= cfg.s21MaxSBdB; %#ok<AGROW>
    end

    if ~isempty(checks)

        fprintf(fid,'\nTarget checks:\n');

        for k = 1:numel(checks)

            if passes(k)
                state = 'PASS';
            else
                state = 'FAIL';
            end

            fprintf(fid,'  [%s] %s\n',state,checks{k});

        end

        metrics.targetChecks = checks;
        metrics.targetPass = passes;
        metrics.allTargetsPassed = all(passes);

    end

    result.metrics = metrics;

else

    fprintf(fid,'No standard S-parameter plot was detected.\n');
    fprintf(fid,'Generic RAW data and inventory were still saved.\n');

end

fclose(fid);

save(fullfile(outDir,'baseline_result.mat'),'result','-v7.3');

fprintf('\n============================================================\n');
fprintf(' BASELINE ANALYSIS RESULT\n');
fprintf('============================================================\n');
fprintf('Output folder:\n%s\n',outDir);

fprintf('\nSaved:\n');
fprintf('  baseline_raw_data.mat\n');
fprintf('  baseline_inventory.csv\n');
fprintf('  baseline_summary.txt\n');

if result.sParameterDetected
    fprintf('  baseline_sparameters.csv\n');
    fprintf('  baseline_sparameters.mat\n');
    fprintf('  baseline_sparameters.png\n');
    fprintf('  baseline_sparameters.fig\n');
end

fprintf('  baseline_result.mat\n');
fprintf('============================================================\n');

end


function value = getAny(raw,plotIndex,names)

for k = 1:numel(names)

    try
        value = ads_raw_get(raw,names{k},plotIndex);
        return;
    catch
    end

end

error('None of the requested variable names were found.');

end


function freqGHz = normalizeFrequencyGHz(freq)

freq = real(freq(:));

if max(abs(freq)) > 1e6
    freqGHz = freq/1e9;
else
    freqGHz = freq;
end

end
