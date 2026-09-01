# ADS-MATLAB Bridge

The repository root contains the three user-facing environment doctors:

1. `doctor_ads.m`
2. `doctor_workspace.m`
3. `doctor_simulator.m`

Run them in that order. Each doctor locates the repository from its own
file path and adds `core/` to the current MATLAB session path. No permanent
MATLAB path or Windows environment setting is changed.

After the doctors pass, run `run_baseline.m`. The public Bridge Core modules
are stored in `core/` and do not require manual path setup.
