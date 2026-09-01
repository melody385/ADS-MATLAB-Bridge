function TARGET = validate_filter_targets(targetFile)
%VALIDATE_FILTER_TARGETS Load and validate generic S-parameter targets.
%
% Version: 0.4.0

if nargin < 1 || isempty(targetFile)
    error('An sp_targets.m path is required.');
end

targetFile = char(targetFile);

if ~isfile(targetFile)
    error('Target configuration does not exist: %s',targetFile);
end

TARGET = [];
run(targetFile);

if ~exist('TARGET','var') || ~isstruct(TARGET)
    error('sp_targets.m did not create TARGET.');
end

if ~isfield(TARGET,'bands')
    error('TARGET.bands is missing.');
end

if ~isfield(TARGET,'special')
    error('TARGET.special is missing.');
end

bands = TARGET.bands;

if ~istable(bands)
    error('TARGET.bands must be a table.');
end

requiredBandCols = { ...
    'Name','Fstart_GHz','Fstop_GHz', ...
    'S11_Min_dB','S11_Max_dB', ...
    'S21_Min_dB','S21_Max_dB'};

assertColumns(bands,requiredBandCols,'TARGET.bands');

if height(bands) == 0
    error('TARGET.bands must contain at least one target row.');
end

for k = 1:height(bands)

    name = strtrim(string(bands.Name(k)));
    f1 = bands.Fstart_GHz(k);
    f2 = bands.Fstop_GHz(k);

    if strlength(name) == 0
        error('TARGET.bands row %d has an empty Name.',k);
    end

    if ~isFiniteScalar(f1) || ~isFiniteScalar(f2) || f1 < 0 || f2 <= f1
        error('TARGET.bands row %d has an invalid frequency range.',k);
    end

    s11Min = bands.S11_Min_dB(k);
    s11Max = bands.S11_Max_dB(k);
    s21Min = bands.S21_Min_dB(k);
    s21Max = bands.S21_Max_dB(k);

    validateLimitPair(s11Min,s11Max,sprintf('TARGET.bands row %d S11',k));
    validateLimitPair(s21Min,s21Max,sprintf('TARGET.bands row %d S21',k));

    if all(isnan([s11Min s11Max s21Min s21Max]))
        error('TARGET.bands row %d contains no active S-parameter limit.',k);
    end
end

special = TARGET.special;

if ~istable(special)
    error('TARGET.special must be a table.');
end

requiredSpecialCols = {'Parameter','Frequency_GHz','Min_dB','Max_dB'};
assertColumns(special,requiredSpecialCols,'TARGET.special');

for k = 1:height(special)

    parameter = upper(strtrim(string(special.Parameter(k))));
    freqGHz = special.Frequency_GHz(k);
    minDB = special.Min_dB(k);
    maxDB = special.Max_dB(k);

    if parameter ~= "S11" && parameter ~= "S21"
        error('TARGET.special row %d Parameter must be S11 or S21.',k);
    end

    if ~isFiniteScalar(freqGHz) || freqGHz < 0
        error('TARGET.special row %d has an invalid frequency.',k);
    end

    validateLimitPair(minDB,maxDB,sprintf('TARGET.special row %d',k));

    if isnan(minDB) && isnan(maxDB)
        error('TARGET.special row %d contains no active limit.',k);
    end
end

fprintf('\n============================================================\n');
fprintf(' GENERIC S-PARAMETER TARGETS VALIDATED\n');
fprintf('============================================================\n');

fprintf('\nFrequency-band targets: %d\n',height(bands));
disp(bands);

fprintf('Special-point targets: %d\n',height(special));

if height(special) > 0
    disp(special);
end

fprintf('============================================================\n');

end


function assertColumns(T,required,label)

for k = 1:numel(required)
    if ~ismember(required{k},T.Properties.VariableNames)
        error('%s is missing required column: %s',label,required{k});
    end
end

end


function validateLimitPair(minVal,maxVal,label)

if ~(isNumericScalarOrNaN(minVal) && isNumericScalarOrNaN(maxVal))
    error('%s limits must be finite numeric scalars or NaN.',label);
end

if ~isnan(minVal) && ~isnan(maxVal) && minVal > maxVal
    error('%s has Min > Max.',label);
end

end


function tf = isFiniteScalar(x)
tf = isnumeric(x) && isscalar(x) && isfinite(x);
end


function tf = isNumericScalarOrNaN(x)
tf = isnumeric(x) && isscalar(x) && (isfinite(x) || isnan(x));
end
