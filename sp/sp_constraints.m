%% ========================================================================
% ADS-MATLAB Bridge - Generic Geometry / Parameter Constraints
% sp_constraints.m
% Location: sp/sp_constraints.m
%
% Version: 0.1.0
%
% USER CONFIGURATION FILE
%
% One row = one relationship between design parameters.
% Add / delete rows directly.
%
% Supported operators:
%   <=   >=   <   >
%
% Expressions may use:
%   parameter names, numbers, + - * / ^ ( )
%   abs(), min(), max(), sqrt()
%
% Examples:
%   W1 + W2 + L1/2 <= 6.5
%   L3 < L1
%   abs(L7-L8) <= 1.0
%
% Set Enable=false to keep a row as a note/example without enforcing it.
% ========================================================================

CONSTRAINTS = cell2table({
    "Example_Clearance",  "W1 + W2 + L1/2",  "<=",  "3",  true;
    "Example_Length",     "L3",               "<",   "L1",   false;
}, 'VariableNames', { ...
    'Name', 'LeftExpression', 'Operator', 'RightExpression', 'Enable'});
