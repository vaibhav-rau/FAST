%% RUN_ALL_SUBSETS.M
%  Exhaustive Variable Subset Analysis for Preliminary Aircraft Optimization
%
%  For every subset of design variables (sizes 1 through N), optimize fuel
%  burn and record the result. This generates the data needed to answer:
%    - At what point do returns diminish?
%    - Which variables matter most?
%    - How much of full optimization is recovered with fewer variables?
%
%  Usage: run from the FAST root directory or research/ directory.
%         >> cd('research')
%         >> run_all_subsets
%
%  Results are saved incrementally to results/subset_results.mat
%

clc; close all;
fprintf('================================================\n');
fprintf('  EXHAUSTIVE VARIABLE SUBSET ANALYSIS\n');
fprintf('  A320neo - Minimize Fuel Burn\n');
fprintf('================================================\n\n');

%% CONFIGURATION %%
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end

% optimization options
opts.MaxIterations = 150;   % fminsearch max iterations
opts.TolFun        = 1e-1;  % fuel burn tolerance (kg)
opts.TolX          = 1e-2;  % variable tolerance
opts.NumRestarts   = 2;     % random restarts per subset (1 = no restarts)
opts.Display       = 'off'; % 'iter' to see progress, 'off' for silent

% which subset sizes to evaluate (set to 1:var_config.n_vars for full)
max_subset_size = 4;  % increase to 5-8 if you have time/compute

% parallel execution (set to true for parfor)
use_parallel = false;

%% LOAD VARIABLE DEFINITIONS %%
var_config = define_variables();
N = var_config.n_vars;

fprintf('Variables: %d\n', N);
fprintf('Subset sizes: 1 to %d\n', max_subset_size);
fprintf('Optimization restarts per subset: %d\n', opts.NumRestarts);
fprintf('Parallel: %d\n\n', use_parallel);

%% LOAD OR CREATE BASELINE %%
baseline_file = fullfile(results_dir, 'baseline.mat');
if exist(baseline_file, 'file')
    load(baseline_file, 'baseline_fuel', 'Aircraft');
    fprintf('Loaded baseline: %.1f kg fuel burn\n', baseline_fuel);
else
    fprintf('No baseline found. Running baseline...\n');
    Aircraft = AircraftSpecsPkg.A320Neo;
    [Aircraft, ~] = Main(Aircraft, @MissionProfilesPkg.A320);
    baseline_fuel = Aircraft.Mission.History.SI.Weight.Fburn(end);
    save(baseline_file, 'baseline_fuel', 'Aircraft', 'var_config');
    fprintf('Baseline: %.1f kg fuel burn\n', baseline_fuel);
end

baseline_aircraft = Aircraft;

%% LOAD EXISTING RESULTS (for crash recovery) %%
results_file = fullfile(results_dir, 'subset_results.mat');
if exist(results_file, 'file')
    load(results_file, 'all_results');
    fprintf('Loaded %d existing results. Will skip completed subsets.\n', ...
        length(all_results));
else
    all_results = struct('subset_size', {}, 'var_indices', {}, ...
        'var_names', {}, 'fuel_burn', {}, 'runtime', {}, ...
        'n_evals', {}, 'optimal_values', {}, 'converged', {});
end

% build a set of already-completed subsets for quick lookup
completed_subsets = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for i = 1:length(all_results)
    key = subset_key(all_results(i).var_indices);
    completed_subsets(key) = true;
end

%% GENERATE ALL SUBSETS %%
total_runs = 0;
for sz = 1:max_subset_size
    total_runs = total_runs + nchoosek(N, sz);
end
fprintf('\nTotal subsets to evaluate: %d\n', total_runs);
fprintf('Estimated time: %.0f - %.0f minutes\n\n', ...
    total_runs * 0.5, total_runs * 3);

%% MAIN LOOP %%
run_count = 0;
start_time = tic;

for sz = 1:max_subset_size
    
    subsets = nchoosek(1:N, sz);
    n_subsets = size(subsets, 1);
    
    fprintf('--- Subset size %d: %d combinations ---\n', sz, n_subsets);
    
    if use_parallel
        % PARALLEL VERSION (parfor)
        results_this_size = cell(n_subsets, 1);
        
        parfor s = 1:n_subsets
            idx = subsets(s, :);
            results_this_size{s} = run_single_subset(idx, var_config, ...
                baseline_aircraft, opts);
        end
        
        for s = 1:n_subsets
            run_count = run_count + 1;
            r = results_this_size{s};
            all_results(end+1) = r; %#ok<SAGROW>
            print_progress(r, run_count, total_runs, start_time);
        end
        
    else
        % SERIAL VERSION
        for s = 1:n_subsets
            idx = subsets(s, :);
            
            % skip if already done
            key = subset_key(idx);
            if ismember(key, keys(completed_subsets))
                run_count = run_count + 1;
                fprintf('[%d/%d] SKIP (size %d, vars %s)\n', ...
                    run_count, total_runs, sz, mat2str(idx));
                continue;
            end
            
            run_count = run_count + 1;
            r = run_single_subset(idx, var_config, baseline_aircraft, opts);
            
            all_results(end+1) = r; %#ok<SAGROW>
            completed_subsets(key) = true;
            
            print_progress(r, run_count, total_runs, start_time);
            
            % save incrementally every 5 runs
            if mod(run_count, 5) == 0
                save(results_file, 'all_results', 'baseline_fuel', ...
                    'var_config', 'max_subset_size');
            end
        end
    end
    
    fprintf('  Size %d complete.\n\n', sz);
end

%% FINAL SAVE %%
save(results_file, 'all_results', 'baseline_fuel', ...
    'var_config', 'max_subset_size');

total_time = toc(start_time);
fprintf('\n========================================\n');
fprintf('  ANALYSIS COMPLETE\n');
fprintf('  Total runs: %d\n', length(all_results));
fprintf('  Total time: %.1f minutes\n', total_time / 60);
fprintf('  Results saved to: %s\n', results_file);
fprintf('========================================\n');
fprintf('\nNext step: run analyze_results.m to generate figures and tables.\n');


%% ======================================================================== %%
%  LOCAL FUNCTIONS                                                         %%
%  =========================================================================  %%

function r = run_single_subset(var_indices, var_config, baseline_aircraft, opts)
% Run optimization for a single variable subset.
    
    t_start = tic;
    
    [x_opt, fval, history] = optimize_subset(var_config, var_indices, ...
        baseline_aircraft, @MissionProfilesPkg.A320, opts);
    
    r.subset_size    = length(var_indices);
    r.var_indices    = var_indices;
    r.var_names      = {var_config.names{var_indices}};
    r.fuel_burn      = fval;
    r.runtime        = toc(t_start);
    r.n_evals        = history.n_evals;
    r.optimal_values = x_opt;
    r.converged      = isfinite(fval);
    
end


function print_progress(r, run_count, total_runs, start_time)
% Print progress update.
    
    elapsed = toc(start_time);
    rate = run_count / elapsed;
    eta = (total_runs - run_count) / rate;
    
    if r.converged
        status = 'OK';
    else
        status = 'FAIL';
    end
    
    fprintf('[%d/%d] size=%d vars=[%s] fuel=%.1f kg  time=%.0fs  ETA=%.0fm  %s\n', ...
        run_count, total_runs, r.subset_size, ...
        strjoin(r.var_names, ','), r.fuel_burn, r.runtime, ...
        eta / 60, status);
    
end


function key = subset_key(indices)
% Create a unique string key for a variable subset.
    key = strjoin(arrayfun(@num2str, indices, 'UniformOutput', false), '_');
end
