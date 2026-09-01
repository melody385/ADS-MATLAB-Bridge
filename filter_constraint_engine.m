function OUTPUT = filter_constraint_engine(mode,varargin)
%FILTER_CONSTRAINT_ENGINE Validate or evaluate user parameter constraints.
%
% Version: 0.2.0
%
% This single backend module replaces:
%   validate_filter_constraints.m
%   evaluate_filter_constraints.m
%
% Usage:
%
%   CONSTRAINTS = filter_constraint_engine( ...
%       "validate", constraintFile, FILTER_VARS);
%
%   RESULT = filter_constraint_engine( ...
%       "evaluate", varNames, varValues, CONSTRAINTS);
%
% Users normally do NOT run this file manually.
% sp_optimizer.m calls it automatically.

mode = lower(strtrim(string(mode)));

switch mode

    case "validate"

        if numel(varargin) ~= 2
            error(['Validate mode requires: ' ...
                   'constraintFile, FILTER_VARS.']);
        end

        OUTPUT = validateConstraints(varargin{1},varargin{2});

    case "evaluate"

        if numel(varargin) ~= 3
            error(['Evaluate mode requires: ' ...
                   'varNames, varValues, CONSTRAINTS.']);
        end

        OUTPUT = evaluateConstraints( ...
            varargin{1}, ...
            varargin{2}, ...
            varargin{3});

    otherwise

        error('Unsupported filter_constraint_engine mode: %s',mode);
end

end


%% ========================================================================
% VALIDATION MODE
% ========================================================================

function CONSTRAINTS = validateConstraints(constraintFile,FILTER_VARS)

if nargin < 1 || isempty(constraintFile)
    error('An sp_constraints.m path is required.');
end

if nargin < 2 || ~istable(FILTER_VARS)
    error('FILTER_VARS table is required.');
end

constraintFile = char(constraintFile);

if ~isfile(constraintFile)
    error('Constraint configuration does not exist: %s',constraintFile);
end

CONSTRAINTS = [];
run(constraintFile);

if ~exist('CONSTRAINTS','var') || ~istable(CONSTRAINTS)
    error('sp_constraints.m did not create a CONSTRAINTS table.');
end

required = { ...
    'Name', ...
    'LeftExpression', ...
    'Operator', ...
    'RightExpression', ...
    'Enable'};

for k = 1:numel(required)

    if ~ismember(required{k},CONSTRAINTS.Properties.VariableNames)
        error('CONSTRAINTS is missing required column: %s',required{k});
    end
end

if ~islogical(CONSTRAINTS.Enable)

    try
        CONSTRAINTS.Enable = logical(CONSTRAINTS.Enable);
    catch
        error('CONSTRAINTS.Enable must contain true/false values.');
    end
end

varNames = strtrim(string(FILTER_VARS.Name));

if numel(unique(varNames)) ~= numel(varNames)
    error('FILTER_VARS contains duplicate variable names.');
end

for k = 1:numel(varNames)

    if ~isvarname(char(varNames(k)))

        error([ ...
            'Parameter "%s" is not a valid MATLAB identifier. ' ...
            'Constraint expressions cannot reference it safely.'], ...
            varNames(k));
    end
end

allowedOperators = ["<=",">=","<",">"];

for k = 1:height(CONSTRAINTS)

    name = strtrim(string(CONSTRAINTS.Name(k)));
    leftExpr = strtrim(string(CONSTRAINTS.LeftExpression(k)));
    op = strtrim(string(CONSTRAINTS.Operator(k)));
    rightExpr = strtrim(string(CONSTRAINTS.RightExpression(k)));

    if strlength(name) == 0
        error('CONSTRAINTS row %d has an empty Name.',k);
    end

    % Disabled rows are examples/notes only.
    if ~CONSTRAINTS.Enable(k)
        continue;
    end

    if strlength(leftExpr) == 0 || strlength(rightExpr) == 0
        error('CONSTRAINTS row %d has an empty expression.',k);
    end

    if ~any(op == allowedOperators)
        error('CONSTRAINTS row %d has unsupported operator "%s".',k,op);
    end

    validateExpression( ...
        leftExpr, ...
        varNames, ...
        k, ...
        'LeftExpression');

    validateExpression( ...
        rightExpr, ...
        varNames, ...
        k, ...
        'RightExpression');
end

fprintf('\n============================================================\n');
fprintf(' FILTER CONSTRAINTS VALIDATED\n');
fprintf('============================================================\n');

fprintf('Rows             : %d\n',height(CONSTRAINTS));
fprintf('Enabled          : %d\n',nnz(CONSTRAINTS.Enable));

if nnz(CONSTRAINTS.Enable) == 0

    fprintf('Active constraints: NONE\n');

else

    disp(CONSTRAINTS(CONSTRAINTS.Enable,:));
end

fprintf('============================================================\n');

end


function validateExpression(expr,varNames,rowIndex,columnName)

expr = char(expr);

% Only arithmetic syntax and identifiers are allowed.
if isempty(regexp(expr,'^[A-Za-z0-9_+\-*/^().,\s]+$','once'))

    error([ ...
        'CONSTRAINTS row %d %s contains unsupported characters. ' ...
        'Use parameter names, numbers, arithmetic operators, and ' ...
        'abs/min/max/sqrt only.'], ...
        rowIndex, ...
        columnName);
end

tokens = regexp(expr,'[A-Za-z_]\w*','match');

allowedFunctions = ["abs","min","max","sqrt"];

for t = 1:numel(tokens)

    token = string(tokens{t});

    if any(token == varNames)
        continue;
    end

    if any(lower(token) == allowedFunctions)
        continue;
    end

    error([ ...
        'CONSTRAINTS row %d %s references unknown identifier "%s". ' ...
        'Use exact parameter names from sp_variables.m.'], ...
        rowIndex, ...
        columnName, ...
        token);
end

end


%% ========================================================================
% EVALUATION MODE
% ========================================================================

function RESULT = evaluateConstraints(varNames,varValues,CONSTRAINTS)

varNames = strtrim(string(varNames(:)));
varValues = varValues(:);

if numel(varNames) ~= numel(varValues)
    error('varNames and varValues must have the same length.');
end

if any(~isfinite(varValues))
    error('Constraint variable values must be finite.');
end

if ~istable(CONSTRAINTS)
    error('CONSTRAINTS must be a table.');
end

active = find(CONSTRAINTS.Enable);

if isempty(active)

    RESULT = emptyResult();
    return;
end

% Create design-parameter variables in this function workspace.
% Expressions are validated before reaching this stage.
for k = 1:numel(varNames)

    name = char(varNames(k));

    if ~isvarname(name)
        error('Parameter "%s" is not a valid MATLAB identifier.',name);
    end

    eval(sprintf('%s = varValues(%d);',name,k));
end

nameCol = strings(0,1);
leftExprCol = strings(0,1);
operatorCol = strings(0,1);
rightExprCol = strings(0,1);

leftValueCol = zeros(0,1);
rightValueCol = zeros(0,1);
violationCol = zeros(0,1);
passedCol = false(0,1);

for q = 1:numel(active)

    k = active(q);

    constraintName = strtrim(string(CONSTRAINTS.Name(k)));
    leftExpr = strtrim(string(CONSTRAINTS.LeftExpression(k)));
    op = strtrim(string(CONSTRAINTS.Operator(k)));
    rightExpr = strtrim(string(CONSTRAINTS.RightExpression(k)));

    try

        leftValue = eval(char(leftExpr));
        rightValue = eval(char(rightExpr));

    catch ME

        error( ...
            'Constraint "%s" could not be evaluated: %s', ...
            constraintName, ...
            ME.message);
    end

    if ~isnumeric(leftValue) || ...
            ~isscalar(leftValue) || ...
            ~isfinite(leftValue)

        error( ...
            'Constraint "%s" left expression must return one finite number.', ...
            constraintName);
    end

    if ~isnumeric(rightValue) || ...
            ~isscalar(rightValue) || ...
            ~isfinite(rightValue)

        error( ...
            'Constraint "%s" right expression must return one finite number.', ...
            constraintName);
    end

    tol = 1e-12 * max(1,max(abs([leftValue rightValue])));

    switch op

        case "<="

            violation = max(0,leftValue-rightValue);

        case ">="

            violation = max(0,rightValue-leftValue);

        case "<"

            violation = max(0,leftValue-rightValue+tol);

        case ">"

            violation = max(0,rightValue-leftValue+tol);

        otherwise

            error('Unsupported constraint operator: %s',op);
    end

    nameCol(end+1,1) = constraintName; %#ok<AGROW>
    leftExprCol(end+1,1) = leftExpr; %#ok<AGROW>
    operatorCol(end+1,1) = op; %#ok<AGROW>
    rightExprCol(end+1,1) = rightExpr; %#ok<AGROW>

    leftValueCol(end+1,1) = leftValue; %#ok<AGROW>
    rightValueCol(end+1,1) = rightValue; %#ok<AGROW>
    violationCol(end+1,1) = violation; %#ok<AGROW>
    passedCol(end+1,1) = violation <= tol; %#ok<AGROW>
end

details = table( ...
    nameCol, ...
    leftExprCol, ...
    operatorCol, ...
    rightExprCol, ...
    leftValueCol, ...
    rightValueCol, ...
    violationCol, ...
    passedCol, ...
    'VariableNames',{ ...
    'Name', ...
    'LeftExpression', ...
    'Operator', ...
    'RightExpression', ...
    'LeftValue', ...
    'RightValue', ...
    'Violation', ...
    'Passed'});

RESULT = struct();

RESULT.version = '0.2.0';
RESULT.constraintCount = height(details);

RESULT.passCount = nnz(details.Passed);
RESULT.failCount = RESULT.constraintCount - RESULT.passCount;

RESULT.totalViolation = sum(details.Violation);
RESULT.maxViolation = max(details.Violation);

RESULT.objective = ...
    sum(details.Violation.^2) + ...
    1e-3*RESULT.totalViolation;

RESULT.allPassed = all(details.Passed);
RESULT.details = details;

end


function RESULT = emptyResult()

RESULT = struct();

RESULT.version = '0.2.0';

RESULT.constraintCount = 0;
RESULT.passCount = 0;
RESULT.failCount = 0;

RESULT.totalViolation = 0;
RESULT.maxViolation = 0;
RESULT.objective = 0;

RESULT.allPassed = true;
RESULT.details = table();

end
