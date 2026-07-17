%% SINGLE_VARIABLE_SWEEP.M
%  For each design variable individually, optimize fuel burn and record
%  the result. This produces a quick ranking of variable importance
%  before running the full exhaustive analysis.
%
%  Usage:
%    >> cd('research')
%    >> single_variable_sweep
%

clc; close all;
fprintf('========================================\n');
fprintf('  SINGLE VARIABLE SWEEP\n');
fprintf('========================================\n\n');

%% SETUP %%
var_config = define_variables();
N = var_config.n_vars;

opts.MaxIterations = 100;
opts.TolFun = 0.5;
opts.TolX = 0.05;
opts.NumRestarts = 3;  % more restarts for single-variable problems
opts.Display = 'off';

%% RUN BASELINE %%
fprintf('Running baseline...\n');
baseline_aircraft = AircraftSpecsPkg.A320Neo;
[baseline_aircraft, ~] = Main(baseline_aircraft, @MissionProfilesPkg.A320);
baseline_fuel = baseline_aircraft.Mission.History.SI.Weight.Fburn(end);
fprintf('Baseline fuel burn: %.1f kg\n\n', baseline_fuel);

%% SWEEP EACH VARIABLE %%
results = struct();
results.name = var_config.names;
results.symbols = var_config.symbols;
results.units = var_config.units;
results.baseline_val = var_config.baseline;
results.optimal_val = zeros(N, 1);
results.fuel_burn = zeros(N, 1);
results.reduction_pct = zeros(N, 1);
results.runtime = zeros(N, 1);

fprintf('%-5s %-35s %-12s %-12s %-12s %-10s\n', ...
    '#', 'Variable', 'Baseline', 'Optimized', 'Fuel(kg)', 'Reduc(%)');
fprintf('%s\n', repmat('-', 1, 90));

for i = 1:N
    
    fprintf('Optimizing variable %d/%d: %s ... ', i, N, var_config.names{i});
    
    tic;
    [x_opt, fval] = optimize_subset(var_config, [i], baseline_aircraft, ...
        @MissionProfilesPkg.A320, opts);
    t = toc;
    
    results.optimal_val(i) = x_opt;
    results.fuel_burn(i) = fval;
    results.reduction_pct(i) = (1 - fval / baseline_fuel) * 100;
    results.runtime(i) = t;
    
    fprintf('done (%.1f s)\n', t);
    
    fprintf('  %s: %.4f -> %.4f %s\n', ...
        var_config.symbols{i}, var_config.baseline(i), x_opt, var_config.units{i});
    fprintf('  Fuel burn: %.1f kg (%.1f%% reduction)\n\n', ...
        fval, results.reduction_pct(i));
end

%% SUMMARY TABLE %%
fprintf('\n========================================\n');
fprintf('  SINGLE VARIABLE RESULTS\n');
fprintf('========================================\n');

% sort by reduction
[~, sort_idx] = sort(results.reduction_pct, 'descend');

fprintf('%-5s %-35s %-15s %-15s %-12s %-10s\n', ...
    'Rank', 'Variable', 'Baseline', 'Optimized', 'Fuel(kg)', 'Reduc(%)');
fprintf('%s\n', repmat('-', 1, 95));

for rank = 1:N
    i = sort_idx(rank);
    fprintf('%-5d %-35s %-6.2f %-6.2f %-12.1f %-10.1f\n', ...
        rank, var_config.names{i}, ...
        results.baseline_val(i), results.optimal_val(i), ...
        results.fuel_burn(i), results.reduction_pct(i));
end

%% SAVE %%
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
save(fullfile(results_dir, 'single_variable_results.mat'), ...
    'results', 'baseline_fuel', 'var_config');

fprintf('\nResults saved to results/single_variable_results.mat\n');
fprintf('Use this to justify variable selection in the paper.\n');
