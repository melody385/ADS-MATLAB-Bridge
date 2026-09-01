function [value,plotIndex,varIndex] = ads_raw_get(raw,varName,plotSelector)
%ADS_RAW_GET Retrieve one RAW variable by its original ADS name.
%
% value = ads_raw_get(raw,'S[2,1]')
% value = ads_raw_get(raw,'freq')
% value = ads_raw_get(raw,'Vload',2)

if nargin < 2
    error('Usage: ads_raw_get(raw,varName[,plotSelector])');
end

varName = char(varName);

if nargin < 3 || isempty(plotSelector)
    candidatePlots = 1:raw.plotCount;
elseif isnumeric(plotSelector)
    candidatePlots = plotSelector;
else
    selector = lower(char(plotSelector));
    candidatePlots = [];

    for k = 1:raw.plotCount
        if contains(lower(raw.plots(k).plotName),selector)
            candidatePlots(end+1) = k; %#ok<AGROW>
        end
    end
end

for p = candidatePlots

    if p < 1 || p > raw.plotCount
        continue;
    end

    P = raw.plots(p);

    for k = 1:numel(P.variables)

        if strcmp(P.variables(k).name,varName)

            varIndex = P.variables(k).index + 1;

            if varIndex <= size(P.values,2)
                value = P.values(:,varIndex);
                plotIndex = p;
                return;
            end

        end

    end

end

error('Variable "%s" was not found in selected RAW plot(s).',varName);

end
