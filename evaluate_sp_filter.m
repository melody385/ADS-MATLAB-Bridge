function RESULT = evaluate_sp_filter(freqGHz,S11dB,S21dB,TARGET)
%EVALUATE_SP_FILTER Evaluate generic S-parameter requirements.
%
% RESULT = evaluate_sp_filter(freqGHz,S11dB,S21dB,TARGET)
%
% Version: 0.1.0
%
% TARGET.bands columns:
%   Name | Fstart_GHz | Fstop_GHz |
%   S11_Min_dB | S11_Max_dB | S21_Min_dB | S21_Max_dB
%
% TARGET.special columns:
%   Parameter | Frequency_GHz | Min_dB | Max_dB
%
% The evaluator does not assume low-pass/high-pass/band-pass/band-stop.
% It converts every active Min/Max requirement into a nonnegative
% violation in dB.
%
% RESULT.objective:
%   sum(violation_dB.^2) + 1e-3*sum(violation_dB)
%
% Therefore:
%   RESULT.objective == 0  <=>  all active targets are satisfied.

freqGHz = real(freqGHz(:));
S11dB = real(S11dB(:));
S21dB = real(S21dB(:));

if isempty(freqGHz)
    error('Frequency array is empty.');
end

if numel(freqGHz) ~= numel(S11dB) || numel(freqGHz) ~= numel(S21dB)
    error('freqGHz, S11dB, and S21dB must have the same length.');
end

if any(~isfinite(freqGHz)) || any(~isfinite(S11dB)) || any(~isfinite(S21dB))
    error('Frequency/S-parameter arrays contain non-finite values.');
end

[freqGHz,ord] = sort(freqGHz);
S11dB = S11dB(ord);
S21dB = S21dB(ord);

% Remove duplicate frequencies while keeping the first occurrence.
[freqGHz,uniqIdx] = unique(freqGHz,'stable');
S11dB = S11dB(uniqIdx);
S21dB = S21dB(uniqIdx);

if numel(freqGHz) < 2
    error('At least two unique frequency points are required.');
end

if ~isstruct(TARGET) || ~isfield(TARGET,'bands') || ~isfield(TARGET,'special')
    error('TARGET must contain bands and special.');
end

if ~istable(TARGET.bands) || ~istable(TARGET.special)
    error('TARGET.bands and TARGET.special must be tables.');
end

scopeCol = strings(0,1);
nameCol = strings(0,1);
parameterCol = strings(0,1);
limitTypeCol = strings(0,1);
fStartCol = zeros(0,1);
fStopCol = zeros(0,1);
limitCol = zeros(0,1);
observedCol = zeros(0,1);
violationCol = zeros(0,1);
passedCol = false(0,1);

%% ------------------------------------------------------------------------
% 1. Frequency-band targets
% -------------------------------------------------------------------------

for k = 1:height(TARGET.bands)

    bandName = string(TARGET.bands.Name(k));
    f1 = TARGET.bands.Fstart_GHz(k);
    f2 = TARGET.bands.Fstop_GHz(k);

    assertFrequencyCovered(f1,f2,freqGHz,sprintf('band "%s"',bandName));

    inside = freqGHz > f1 & freqGHz < f2;
    bandFreq = unique([f1; freqGHz(inside); f2]);

    bandS11 = interp1(freqGHz,S11dB,bandFreq,'linear');
    bandS21 = interp1(freqGHz,S21dB,bandFreq,'linear');

    % S11 minimum
    if ~isnan(TARGET.bands.S11_Min_dB(k))
        limit = TARGET.bands.S11_Min_dB(k);
        observed = min(bandS11);
        violation = max(0,limit-observed);

        appendConstraint("Band",bandName,"S11","Min", ...
            f1,f2,limit,observed,violation);
    end

    % S11 maximum
    if ~isnan(TARGET.bands.S11_Max_dB(k))
        limit = TARGET.bands.S11_Max_dB(k);
        observed = max(bandS11);
        violation = max(0,observed-limit);

        appendConstraint("Band",bandName,"S11","Max", ...
            f1,f2,limit,observed,violation);
    end

    % S21 minimum
    if ~isnan(TARGET.bands.S21_Min_dB(k))
        limit = TARGET.bands.S21_Min_dB(k);
        observed = min(bandS21);
        violation = max(0,limit-observed);

        appendConstraint("Band",bandName,"S21","Min", ...
            f1,f2,limit,observed,violation);
    end

    % S21 maximum
    if ~isnan(TARGET.bands.S21_Max_dB(k))
        limit = TARGET.bands.S21_Max_dB(k);
        observed = max(bandS21);
        violation = max(0,observed-limit);

        appendConstraint("Band",bandName,"S21","Max", ...
            f1,f2,limit,observed,violation);
    end
end

%% ------------------------------------------------------------------------
% 2. Special frequency-point targets
% -------------------------------------------------------------------------

for k = 1:height(TARGET.special)

    parameter = upper(strtrim(string(TARGET.special.Parameter(k))));
    f = TARGET.special.Frequency_GHz(k);

    assertFrequencyCovered(f,f,freqGHz, ...
        sprintf('special point %s @ %.12g GHz',parameter,f));

    if parameter == "S11"
        observed = interp1(freqGHz,S11dB,f,'linear');
    elseif parameter == "S21"
        observed = interp1(freqGHz,S21dB,f,'linear');
    else
        error('Unsupported special-point parameter: %s',parameter);
    end

    pointName = sprintf('%s@%.12gGHz',parameter,f);

    if ~isnan(TARGET.special.Min_dB(k))
        limit = TARGET.special.Min_dB(k);
        violation = max(0,limit-observed);

        appendConstraint("Special",pointName,parameter,"Min", ...
            f,f,limit,observed,violation);
    end

    if ~isnan(TARGET.special.Max_dB(k))
        limit = TARGET.special.Max_dB(k);
        violation = max(0,observed-limit);

        appendConstraint("Special",pointName,parameter,"Max", ...
            f,f,limit,observed,violation);
    end
end

if isempty(violationCol)
    error('No active S-parameter target was found.');
end

details = table( ...
    scopeCol,nameCol,parameterCol,limitTypeCol, ...
    fStartCol,fStopCol,limitCol,observedCol,violationCol,passedCol, ...
    'VariableNames',{ ...
    'Scope','Name','Parameter','LimitType', ...
    'Fstart_GHz','Fstop_GHz','Limit_dB','Observed_dB', ...
    'Violation_dB','Passed'});

RESULT = struct();
RESULT.version = '0.1.0';
RESULT.details = details;
RESULT.constraintCount = height(details);
RESULT.passCount = nnz(details.Passed);
RESULT.failCount = RESULT.constraintCount - RESULT.passCount;
RESULT.totalViolation = sum(details.Violation_dB);
RESULT.maxViolation = max(details.Violation_dB);
RESULT.objective = sum(details.Violation_dB.^2) + ...
    1e-3*RESULT.totalViolation;
RESULT.allPassed = all(details.Passed);

    function appendConstraint(scope,name,parameter,limitType, ...
            fStart,fStop,limit,observed,violation)

        scopeCol(end+1,1) = string(scope);
        nameCol(end+1,1) = string(name);
        parameterCol(end+1,1) = string(parameter);
        limitTypeCol(end+1,1) = string(limitType);
        fStartCol(end+1,1) = fStart;
        fStopCol(end+1,1) = fStop;
        limitCol(end+1,1) = limit;
        observedCol(end+1,1) = observed;
        violationCol(end+1,1) = violation;
        passedCol(end+1,1) = violation <= 1e-12;
    end

end


function assertFrequencyCovered(f1,f2,freqGHz,label)

tol = 1e-12 * max(1,max(abs(freqGHz)));

if f1 < min(freqGHz)-tol || f2 > max(freqGHz)+tol
    error(['Target %s is outside the simulated frequency range ' ...
           '[%.12g, %.12g] GHz.'], ...
           label,min(freqGHz),max(freqGHz));
end

end
