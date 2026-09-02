function FILTER_VARS = validate_filter_variables(configFile)
%VALIDATE_FILTER_VARIABLES Load and validate sp_variables.m.
% Internal module: sp/internal/validate_filter_variables.m
%
% FILTER_VARS = validate_filter_variables(configFile)
%
% Version: 0.2.0
%
% This function never changes the user's configuration. It only checks it.

if nargin < 1 || isempty(configFile)
    error('An sp_variables.m path is required.');
end

configFile = char(configFile);

if ~isfile(configFile)
    error('Variable configuration does not exist: %s',configFile);
end

FILTER_VARS = [];

run(configFile);

if ~exist('FILTER_VARS','var') || ~istable(FILTER_VARS)
    error('sp_variables.m did not create a FILTER_VARS table.');
end

required = {'Name','Initial','Lower','Upper','Step','Enable'};

for k = 1:numel(required)
    if ~ismember(required{k},FILTER_VARS.Properties.VariableNames)
        error('FILTER_VARS is missing required column: %s',required{k});
    end
end

FILTER_VARS.Name = strtrim(string(FILTER_VARS.Name));

n = height(FILTER_VARS);

if n == 0
    error('FILTER_VARS is empty.');
end

if any(strlength(FILTER_VARS.Name) == 0)
    error('One or more variable names are empty.');
end

if numel(unique(lower(FILTER_VARS.Name))) ~= n
    error('Duplicate variable names were found in FILTER_VARS.');
end

numericCols = {'Initial','Lower','Upper','Step'};

for k = 1:numel(numericCols)
    col = FILTER_VARS.(numericCols{k});
    if ~isnumeric(col) || numel(col) ~= n
        error('%s must be a numeric column.',numericCols{k});
    end
end

if ~islogical(FILTER_VARS.Enable)
    try
        FILTER_VARS.Enable = logical(FILTER_VARS.Enable);
    catch
        error('Enable must contain true/false values.');
    end
end

for k = 1:n

    name = FILTER_VARS.Name(k);
    x0 = FILTER_VARS.Initial(k);
    lb = FILTER_VARS.Lower(k);
    ub = FILTER_VARS.Upper(k);
    st = FILTER_VARS.Step(k);
    en = FILTER_VARS.Enable(k);

    if ~isfinite(x0)
        error('%s: Initial must be finite.',name);
    end

    if ~isfinite(lb) || ~isfinite(ub)
        error('%s: Lower and Upper must be finite.',name);
    end

    if lb > ub
        error('%s: Lower (%.12g) is greater than Upper (%.12g).',name,lb,ub);
    end

    tol = 1e-12 * max(1,max(abs([x0 lb ub])));

    if x0 < lb-tol || x0 > ub+tol
        error(['%s: Initial %.12g is outside the user range ' ...
               '[%.12g, %.12g].'],name,x0,lb,ub);
    end

    if en
        if ~isfinite(st) || st <= 0
            error('%s: Step must be > 0 when Enable=true.',name);
        end
    end

end

fprintf('\n[OK] sp_variables.m validated: %d variables, %d enabled.\n', ...
    n,nnz(FILTER_VARS.Enable));

end
