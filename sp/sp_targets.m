%% ========================================================================
% ADS-MATLAB Bridge - Generic S-Parameter Optimization Targets
% sp_targets.m
% Location: sp/sp_targets.m
%
% Version: 0.4.0
%
% USER CONFIGURATION FILE
%
% Add / delete rows directly.
% Use NaN when one side of a limit is not required.
% ========================================================================

%% 1. FREQUENCY-BAND TARGETS

TARGET.bands = cell2table({
    "Band_1",  1.0,  3.0,   NaN,  -15,  -0.3,  NaN;
    "Band_2",  4.0, 10.0,    -3,  NaN,   NaN,  -22;
}, 'VariableNames', { ...
    'Name', 'Fstart_GHz', 'Fstop_GHz', ...
    'S11_Min_dB', 'S11_Max_dB', ...
    'S21_Min_dB', 'S21_Max_dB'});


%% 2. SPECIAL FREQUENCY-POINT TARGETS

TARGET.special = cell2table({
    "S21",  3.10,  NaN,  -3;
}, 'VariableNames', { ...
    'Parameter', 'Frequency_GHz', 'Min_dB', 'Max_dB'});
