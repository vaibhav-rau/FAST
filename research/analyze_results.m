%% ANALYZE_RESULTS.M
%  Post-process the exhaustive subset analysis results.
%
%  Generates:
%    Figure 1: Performance vs subset size (best/mean/worst curves)
%    Figure 2: Boxplots of fuel burn by subset size
%    Figure 3: Variable importance (frequency in top-performing subsets)
%    Figure 4: Runtime vs subset size
%    Table 1:  Summary statistics by subset size
%    Table 2:  Variable frequency in top subsets
%
%  Usage:
%    >> cd('research')
%    >> analyze_results
%

clc; close all;

%% LOAD RESULTS %%
results_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
load(fullfile(results_dir, 'subset_results.mat'), ...
    'all_results', 'baseline_fuel', 'var_config', 'max_subset_size');

N = var_config.n_vars;

fprintf('Loaded %d subset results.\n', length(all_results));

%% COMPUTE RECOVERED BENEFIT %%
% Find the best (lowest fuel burn) result among ALL subsets.
% This serves as a proxy for "full optimization" if the full set was run,
% or the best achievable if subsets only go up to size k.

all_fuel = [all_results.fuel_burn];
all_sizes = [all_results.subset_size];
all_runtimes = [all_results.runtime];
all_converged = [all_results.converged];

% only consider converged results
valid = all_converged & isfinite(all_fuel);

% full optimization reference: best fuel burn across ALL results
% (if we ran all 8 variables, this IS the full optimization)
full_set_mask = all_sizes == N;
if any(full_set_mask & valid)
    full_fuel = min(all_fuel(full_set_mask & valid));
else
    % if full set wasn't run, use the best result overall
    full_fuel = min(all_fuel(valid));
end

% compute recovered benefit for each result
% Recovered Benefit = (F_baseline - F_subset) / (F_baseline - F_full) * 100
denom = baseline_fuel - full_fuel;
if denom > 0
    recovered_benefit = (baseline_fuel - all_fuel) ./ denom * 100;
else
    recovered_benefit = zeros(size(all_fuel));
end

fprintf('\nBaseline fuel burn:   %.1f kg\n', baseline_fuel);
fprintf('Full optimization:    %.1f kg\n', full_fuel);
fprintf('Total improvement:    %.1f kg (%.1f%%)\n', ...
    baseline_fuel - full_fuel, (baseline_fuel - full_fuel) / baseline_fuel * 100);

%% ======================================================================== %%
%  TABLE 1: Summary Statistics by Subset Size                              %%
%  =========================================================================  %%

fprintf('\n========================================\n');
fprintf('  TABLE 1: Optimization Summary\n');
fprintf('========================================\n');
fprintf('%-8s %-12s %-12s %-12s %-12s %-10s\n', ...
    'Size', 'Combinations', 'Best FB(kg)', 'Mean FB(kg)', 'Worst FB(kg)', 'Avg Time(s)');
fprintf('%s\n', repmat('-', 1, 70));

summary_data = struct();

for sz = 1:max_subset_size
    mask = (all_sizes == sz) & valid;
    if ~any(mask)
        continue;
    end
    
    fb = all_fuel(mask);
    rt = all_runtimes(mask);
    n_combos = nchoosek(N, sz);
    
    best_fb = min(fb);
    mean_fb = mean(fb);
    worst_fb = max(fb);
    avg_time = mean(rt);
    
    % compute recovered benefit stats
    rb = recovered_benefit(mask);
    best_rb = max(rb);
    mean_rb = mean(rb);
    
    summary_data(sz).size = sz;
    summary_data(sz).n_combos = n_combos;
    summary_data(sz).best_fuel = best_fb;
    summary_data(sz).mean_fuel = mean_fb;
    summary_data(sz).worst_fuel = worst_fb;
    summary_data(sz).avg_time = avg_time;
    summary_data(sz).best_recovered = best_rb;
    summary_data(sz).mean_recovered = mean_rb;
    
    fprintf('%-8d %-12d %-12.1f %-12.1f %-12.1f %-10.1f\n', ...
        sz, n_combos, best_fb, mean_fb, worst_fb, avg_time);
end

fprintf('%-8s %-12s %-12.1f\n', 'All', nchoosek(N, N), full_fuel);

%% ======================================================================== %%
%  FIGURE 1: Performance vs Subset Size (Best / Mean / Worst)             %%
%  =========================================================================  %%

figure('Position', [100 100 800 500], 'Color', 'w');

sizes_present = unique(all_sizes(valid));
best_vals = zeros(size(sizes_present));
mean_vals = zeros(size(sizes_present));
worst_vals = zeros(size(sizes_present));

for i = 1:length(sizes_present)
    sz = sizes_present(i);
    mask = (all_sizes == sz) & valid;
    fb = all_fuel(mask);
    best_vals(i) = min(fb);
    mean_vals(i) = mean(fb);
    worst_vals(i) = max(fb);
end

% convert to percentage of baseline
best_pct = (1 - best_vals / baseline_fuel) * 100;
mean_pct = (1 - mean_vals / baseline_fuel) * 100;
worst_pct = (1 - worst_vals / baseline_fuel) * 100;

hold on;
plot(sizes_present, best_pct, 'g-s', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'Best Subset');
plot(sizes_present, mean_pct, 'b-o', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'Mean of Subsets');
plot(sizes_present, worst_pct, 'r-^', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'Worst Subset');

% mark the full optimization
plot(N, (1 - full_fuel / baseline_fuel) * 100, 'k*', 'MarkerSize', 14, ...
    'LineWidth', 2, 'DisplayName', 'Full Optimization');

xlabel('Number of Design Variables Optimized', 'FontSize', 12);
ylabel('Fuel Burn Reduction from Baseline (%)', 'FontSize', 12);
title('Figure 1: Fuel Burn Improvement vs. Subset Size', 'FontSize', 14);
legend('Location', 'southeast', 'FontSize', 10);
grid on;
set(gca, 'FontSize', 11);
 xlim([0.5, max(sizes_present) + 0.5]);

savefig(fullfile(results_dir, 'fig1_performance_vs_size.fig'));
print(fullfile(results_dir, 'fig1_performance_vs_size'), '-dpng', '-r300');

%% ======================================================================== %%
%  FIGURE 2: Boxplots of Recovered Benefit by Subset Size                 %%
%  =========================================================================  %%

figure('Position', [100 100 800 500], 'Color', 'w');

% prepare data for boxplot
max_sz = max(sizes_present);
box_data = [];
box_groups = [];

for sz = sizes_present
    mask = (all_sizes == sz) & valid;
    rb = recovered_benefit(mask);
    rb = rb(rb >= 0 & rb <= 150);  % clip outliers
    box_data = [box_data; rb(:)]; %#ok<AGROW>
    box_groups = [box_groups; repmat(sz, length(rb), 1)]; %#ok<AGROW>
end

if length(unique(box_groups)) > 1
    boxplot(box_data, box_groups, 'Labels', arrayfun(@num2str, sizes_present, 'UniformOutput', false));
else
    % if only one size, just plot a point
    scatter(box_groups, box_data, 50, 'b', 'filled');
    set(gca, 'XTick', sizes_present);
end

xlabel('Number of Design Variables Optimized', 'FontSize', 12);
ylabel('Recovered Benefit (%)', 'FontSize', 12);
title('Figure 2: Distribution of Recovered Benefit by Subset Size', 'FontSize', 14);
grid on;
set(gca, 'FontSize', 11);
ylim([-5, 110]);

savefig(fullfile(results_dir, 'fig2_boxplots.fig'));
print(fullfile(results_dir, 'fig2_boxplots'), '-dpng', '-r300');

%% ======================================================================== %%
%  FIGURE 3: Variable Importance (Frequency in Top-Performing Subsets)     %%
%  =========================================================================  %%

figure('Position', [100 100 800 500], 'Color', 'w');

% count how often each variable appears in the top 10% of subsets
n_top = max(1, round(0.10 * sum(valid)));
[~, sort_idx] = sort(recovered_benefit(valid), 'descend');
top_indices = find(valid);
top_indices = top_indices(sort_idx(1:n_top));

freq = zeros(N, 1);
for i = 1:length(top_indices)
    r = all_results(top_indices(i));
    for j = r.var_indices
        freq(j) = freq(j) + 1;
    end
end

freq_pct = freq / n_top * 100;

% sort by frequency
[freq_sorted, sort_order] = sort(freq_pct, 'descend');
names_sorted = var_config.names(sort_order);

% horizontal bar chart
barh(freq_sorted, 'FaceColor', [0.2 0.4 0.8]);
set(gca, 'YTick', 1:N);
set(gca, 'YTickLabel', names_sorted);
xlabel('Frequency in Top 10% of Subsets (%)', 'FontSize', 12);
title('Figure 3: Variable Importance', 'FontSize', 14);
grid on;
set(gca, 'FontSize', 11);
xlim([0 110]);

% add percentage labels on bars
for i = 1:N
    text(freq_sorted(i) + 1, i, sprintf('%.0f%%', freq_sorted(i)), ...
        'VerticalAlignment', 'middle', 'FontSize', 10);
end

savefig(fullfile(results_dir, 'fig3_variable_importance.fig'));
print(fullfile(results_dir, 'fig3_variable_importance'), '-dpng', '-r300');

%% ======================================================================== %%
%  FIGURE 4: Runtime vs Subset Size                                        %%
%  =========================================================================  %%

figure('Position', [100 100 800 500], 'Color', 'w');

avg_runtimes = zeros(size(sizes_present));
max_runtimes = zeros(size(sizes_present));
min_runtimes = zeros(size(sizes_present));

for i = 1:length(sizes_present)
    sz = sizes_present(i);
    mask = (all_sizes == sz) & valid;
    rt = all_runtimes(mask);
    avg_runtimes(i) = mean(rt);
    max_runtimes(i) = max(rt);
    min_runtimes(i) = min(rt);
end

hold on;
fill([sizes_present fliplr(sizes_present)], ...
    [min_runtimes fliplr(max_runtimes)], ...
    [0.8 0.9 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5, ...
    'DisplayName', 'Min-Max Range');
plot(sizes_present, avg_runtimes, 'b-o', 'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'Mean Runtime');

xlabel('Number of Design Variables Optimized', 'FontSize', 12);
ylabel('Optimization Runtime (seconds)', 'FontSize', 12);
title('Figure 4: Runtime vs. Subset Size', 'FontSize', 14);
legend('Location', 'northwest', 'FontSize', 10);
grid on;
set(gca, 'FontSize', 11);

savefig(fullfile(results_dir, 'fig4_runtime_vs_size.fig'));
print(fullfile(results_dir, 'fig4_runtime_vs_size'), '-dpng', '-r300');

%% ======================================================================== %%
%  TABLE 2: Variable Frequency in Top Subsets                             %%
%  =========================================================================  %%

fprintf('\n========================================\n');
fprintf('  TABLE 2: Variable Importance\n');
fprintf('  (Frequency in top 10%% of all subsets)\n');
fprintf('========================================\n');
fprintf('%-35s %-10s\n', 'Variable', 'Freq (%)');
fprintf('%s\n', repmat('-', 1, 45));

for i = 1:N
    fprintf('%-35s %-10.1f\n', var_config.names{sort_order(i)}, freq_sorted(i));
end

%% ======================================================================== %%
%  RECOVERED BENEFIT TABLE BY SUBSET SIZE                                  %%
%  =========================================================================  %%

fprintf('\n========================================\n');
fprintf('  TABLE 3: Recovered Benefit by Size\n');
fprintf('========================================\n');
fprintf('%-8s %-12s %-12s %-12s\n', 'Size', 'Best (%)', 'Mean (%)', 'Worst (%)');
fprintf('%s\n', repmat('-', 1, 50));

for sz = sizes_present
    mask = (all_sizes == sz) & valid;
    rb = recovered_benefit(mask);
    fprintf('%-8d %-12.1f %-12.1f %-12.1f\n', ...
        sz, max(rb), mean(rb), min(rb));
end

%% ======================================================================== %%
%  TOP SUBSETS DETAIL                                                      %%
%  =========================================================================  %%

fprintf('\n========================================\n');
fprintf('  TOP 10 SUBSETS (by fuel burn)\n');
fprintf('========================================\n');

[~, top10_idx] = sort(all_fuel(valid), 'ascend');
valid_idx = find(valid);
top10_idx = valid_idx(top10_idx(1:min(10, length(top10_idx))));

fprintf('%-5s %-40s %-12s %-12s %-10s\n', ...
    'Rank', 'Variables', 'Fuel(kg)', 'Reduc(%)', 'Recov(%)');
fprintf('%s\n', repmat('-', 1, 85));

for rank = 1:length(top10_idx)
    i = top10_idx(rank);
    r = all_results(i);
    names_str = strjoin(r.var_names, ' + ');
    fb = r.fuel_burn;
    red_pct = (1 - fb / baseline_fuel) * 100;
    rec_pct = recovered_benefit(i);
    fprintf('%-5d %-40s %-12.1f %-12.1f %-10.1f\n', ...
        rank, names_str, fb, red_pct, rec_pct);
end

%% SUMMARY %%
fprintf('\n========================================\n');
fprintf('  KEY FINDINGS\n');
fprintf('========================================\n');
fprintf('Baseline fuel burn:     %.1f kg\n', baseline_fuel);
fprintf('Full optimization:      %.1f kg (%.1f%% reduction)\n', ...
    full_fuel, (1 - full_fuel / baseline_fuel) * 100);

% find the smallest subset that recovers >90% of improvement
for sz = sizes_present
    mask = (all_sizes == sz) & valid;
    rb = recovered_benefit(mask);
    if max(rb) >= 90
        fprintf('First size to recover >90%%: %d variables (%.1f%% best)\n', ...
            sz, max(rb));
        break;
    end
end

% find the smallest subset that recovers >95%
for sz = sizes_present
    mask = (all_sizes == sz) & valid;
    rb = recovered_benefit(mask);
    if max(rb) >= 95
        fprintf('First size to recover >95%%: %d variables (%.1f%% best)\n', ...
            sz, max(rb));
        break;
    end
end

fprintf('\nAll figures saved to: %s\n', results_dir);
