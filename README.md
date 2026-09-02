# ADS-MATLAB Bridge

The repository root contains the three user-facing environment doctors:

1. `doctor_ads.m`
2. `doctor_workspace.m`
3. `doctor_simulator.m`

Run them in that order. Each doctor locates the repository from its own
file path and adds `core/` to the current MATLAB session path. No permanent
MATLAB path or Windows environment setting is changed.

The public Bridge Core modules are stored in `core/` and do not require
manual path setup.

The S-parameter branch user workflow is stored in `sp/`:

1. `sp_baseline.m`
2. `sp_check.m`
3. Review `sp_targets.m` and `sp_constraints.m`
4. `sp_optimizer.m`

The three runnable SP scripts locate the repository from their own file
paths and add both `core/` and `sp/internal/` to the current MATLAB session.
They do not modify the permanent MATLAB path.

After a successful SP baseline, `sp_variables.m` is generated in the selected
ADS Workspace under `ADS_MATLAB_BRIDGE_Run/Config/`; it is not a repository
file.
