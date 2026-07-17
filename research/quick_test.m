%% QUICK_TEST.M
%  Quick sanity check: optimize a few key subsets to verify the pipeline
%  works before running the full exhaustive analysis.
%
%  Usage:
%    >> cd('research')
%    >> quick_test
%

clc; close all;
fprintf('========================================\n');
fprintf('  QUICK TEST - Verify Pipeline\n');
fprintf('========================================\n\n');

%% SETUP %%
var_config = define_variables();
opts.MaxIterations = 80;
opts.TolFun = 0.5;
opts.TolX = 0.1;
opts.NumRestarts = 1;
opts.Display = 'off';

%% RUN BASELINE %%
fprintf('Running baseline...\n');
baseline_aircraft = AircraftSpecsPkg.A320Neo;
tic;
[baseline_aircraft, ~] = Main(baseline_aircraft, @MissionProfilesPkg.A320);
baseline_time = toc;
baseline_fuel = baseline_aircraft.Mission.History.SI.Weight.Fburn(end);
fprintf('Baseline fuel burn: %.1f kg (%.1f s)\n\n', baseline_fuel, baseline_time);

%% TEST 1: Single variable - Aspect Ratio (index 2) %%
fprintf('--- Test 1: Single variable (Aspect Ratio) ---\n');
tic;
[x_opt, fval] = optimize_subset(var_config, [2], baseline_aircraft, ...
    @MissionProfilesPkg.A320, opts);
t1 = toc;
fprintf('  AR baseline: %.2f -> optimized: %.2f\n', var_config.baseline(2), x_opt);
fprintf('  Fuel burn: %.1f kg (%.1f%% reduction)\n', fval, (1 - fval/baseline_fuel)*100);
fprintf('  Runtime: %.1f s\n\n', t1);

%% TEST 2: Two variables - AR + Wing Area (indices 1,2) %%
fprintf('--- Test 2: Two variables (Wing Loading + AR) ---\n');
tic;
[x_opt, fval] = optimize_subset(var_config, [1, 2], baseline_aircraft, ...
    @MissionProfilesPkg.A320, opts);
t2 = toc;
fprintf('  Wing loading: %.1f -> %.1f kg/m^2\n', var_config.baseline(1), x_opt(1));
fprintf('  AR: %.2f -> %.2f\n', var_config.baseline(2), x_opt(2));
fprintf('  Fuel burn: %.1f kg (%.1f%% reduction)\n', fval, (1 - fval/baseline_fuel)*100);
fprintf('  Runtime: %.1f s\n\n', t2);

%% TEST 3: Three variables - AR + Wing Area + Fuel Fraction (indices 1,2,7) %%
fprintf('--- Test 3: Three variables (WL + AR + Taper) ---\n');
tic;
[x_opt, fval] = optimize_subset(var_config, [1, 2, 7], baseline_aircraft, ...
    @MissionProfilesPkg.A320, opts);
t3 = toc;
fprintf('  Wing loading: %.1f -> %.1f kg/m^2\n', var_config.baseline(1), x_opt(1));
fprintf('  AR: %.2f -> %.2f\n', var_config.baseline(2), x_opt(2));
fprintf('  Taper: %.3f -> %.3f\n', var_config.baseline(7), x_opt(7));
fprintf('  Fuel burn: %.1f kg (%.1f%% reduction)\n', fval, (1 - fval/baseline_fuel)*100);
fprintf('  Runtime: %.1f s\n\n', t3);

%% SUMMARY %%
fprintf('========================================\n');
fprintf('  PIPELINE TEST RESULTS\n');
fprintf('========================================\n');
fprintf('Baseline:           %.1f kg\n', baseline_fuel);
fprintf('1 variable (AR):    %.1f kg  (%.1f%% reduction, %.1f s)\n', ...
    fval, (1 - fval/baseline_fuel)*100, t1);
fprintf('2 variables:        %.1f kg  (%.1f%% reduction, %.1f s)\n', ...
    fval, (1 - fval/baseline_fuel)*100, t2);
fprintf('3 variables:        %.1f kg  (%.1f%% reduction, %.1f s)\n', ...
    fval, (1 - fval/baseline_fuel)*100, t3);

fprintf('\nIf these look reasonable, run: run_all_subsets\n');
