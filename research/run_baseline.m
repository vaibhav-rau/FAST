%% RUN_BASELINE.M
%  Establish the baseline fuel burn for the A320neo before any optimization.
%  This is the reference point for computing "recovered benefit" in the
%  exhaustive subset analysis.
%
%  Usage: run this script from the FAST root directory or the research/ dir.
%         >> cd('research')
%         >> run_baseline
%

clc; close all;
fprintf('========================================\n');
fprintf('  BASELINE A320neo - NO OPTIMIZATION\n');
fprintf('========================================\n\n');

%% RUN BASELINE %%
tic;

Aircraft = AircraftSpecsPkg.A320Neo;
[Aircraft, ~] = Main(Aircraft, @MissionProfilesPkg.A320);

baseline_time = toc;

%% EXTRACT RESULTS %%
baseline_fuel = Aircraft.Mission.History.SI.Weight.Fburn(end);
baseline_MTOW = Aircraft.Specs.Weight.MTOW;
baseline_OEW  = Aircraft.Specs.Weight.OEW;
baseline_S    = Aircraft.Specs.Aero.S;

fprintf('\n--- BASELINE RESULTS ---\n');
fprintf('Fuel Burn:      %.1f kg  (%.1f lbm)\n', baseline_fuel, ...
    UnitConversionPkg.ConvMass(baseline_fuel, 'kg', 'lbm'));
fprintf('MTOW:           %.1f kg  (%.1f lbm)\n', baseline_MTOW, ...
    UnitConversionPkg.ConvMass(baseline_MTOW, 'kg', 'lbm'));
fprintf('OEW:            %.1f kg  (%.1f lbm)\n', baseline_OEW, ...
    UnitConversionPkg.ConvMass(baseline_OEW, 'kg', 'lbm'));
fprintf('Wing Area:      %.2f m^2  (%.1f ft^2)\n', baseline_S, ...
    baseline_S * UnitConversionPkg.ConvLength(1, 'm', 'ft')^2);
fprintf('Runtime:        %.1f s\n', baseline_time);

%% SAVE %%
var_config = define_variables();

results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

save(fullfile(results_dir, 'baseline.mat'), ...
    'baseline_fuel', 'baseline_MTOW', 'baseline_OEW', 'baseline_S', ...
    'baseline_time', 'var_config', 'Aircraft');

fprintf('\nBaseline saved to results/baseline.mat\n');
