# Research Optimization Framework

## Files Created (`research/`)

| File                      | Purpose                                                                                                                                                         |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `define_variables.m`      | Defines the 8 design variables, including baseline values, bounds, names, and corresponding FAST field paths.                                                   |
| `apply_design_vars.m`     | Maps a vector of optimization variables onto the `Aircraft` structure, including any required unit conversions.                                                 |
| `objective_fn.m`          | Wraps FAST's `Main()` function into a scalar objective function that returns fuel burn (or `Inf` if the analysis fails).                                        |
| `optimize_subset.m`       | Optimizes any selected subset of variables using **Nelder–Mead (`fminsearch`)** with a logit transformation for bound enforcement and optional random restarts. |
| `run_baseline.m`          | Runs the baseline A320neo configuration and stores the reference fuel burn.                                                                                     |
| `quick_test.m`            | Performs quick 1-, 2-, and 3-variable optimization tests to verify the optimization pipeline.                                                                   |
| `single_variable_sweep.m` | Optimizes each variable independently to estimate individual importance.                                                                                        |
| `run_all_subsets.m`       | Performs exhaustive subset optimization (default subset sizes 1–4) with incremental checkpoint saving and optional parallel execution.                          |
| `analyze_results.m`       | Processes optimization results and generates publication-quality figures, tables, and summary statistics.                                                       |

---

# Design Variables

| # | Variable           | Baseline        | Bounds           | FAST Field                    |
| - | ------------------ | --------------- | ---------------- | ----------------------------- |
| 1 | Wing Loading       | **624.5 kg/m²** | 480–800 kg/m²    | `Specs.Aero.W_S.SLS`          |
| 2 | Aspect Ratio       | **10.13**       | 7–15             | `Specs.Aero.Wing.AR`          |
| 3 | Wing Sweep         | **26.9°**       | 15–40°           | `Specs.Aero.Wing.Sweep`       |
| 4 | Cruise Altitude    | **35,000 ft**   | 28,000–42,000 ft | `Specs.Performance.Alts.Crs`  |
| 5 | Cruise Mach        | **0.82**        | 0.75–0.88        | `Specs.Performance.Vels.Crs`  |
| 6 | Engine Thrust      | **237 kN**      | 180–300 kN       | `Specs.Propulsion.Thrust.SLS` |
| 7 | Wing Taper Ratio   | **0.27**        | 0.15–0.50        | `Specs.Aero.Wing.TR`          |
| 8 | Vertical Tail Area | **22.76 m²**    | 15–35 m²         | `Specs.Aero.Vtail.S`          |

---

# Recommended Execution Order

```matlab
cd('research')

% 1. Verify the optimization pipeline
quick_test              % ~2–5 min

% 2. Rank individual variable importance
single_variable_sweep   % ~10–15 min

% 3. Generate baseline reference
run_baseline            % ~30 s

% 4. Run exhaustive subset optimization
run_all_subsets         % Hours (incremental saving enabled)

% 5. Generate publication figures and tables
analyze_results         % Seconds
```

---

# Methodology

## Optimization Algorithm

* MATLAB `fminsearch` (Nelder–Mead simplex)
* No Optimization Toolbox required
* Logit variable transformation guarantees all variables remain within their prescribed bounds
* Optional random restarts improve robustness against local minima

---

## Performance Metric

The optimization performance is evaluated using the **Recovered Benefit** metric:

[
\text{Recovered Benefit (%)} =
\frac{F_{\mathrm{baseline}}-F_{\mathrm{subset}}}
{F_{\mathrm{baseline}}-F_{\mathrm{full}}}
\times100
]

where

* (F_{\mathrm{baseline}}) = baseline aircraft fuel burn
* (F_{\mathrm{subset}}) = optimized fuel burn using a selected variable subset
* (F_{\mathrm{full}}) = optimized fuel burn using all design variables

This metric directly quantifies how much of the total possible improvement is recovered by optimizing only a subset of variables.

---

# Default Analysis Settings

| Setting                              | Value                                |
| ------------------------------------ | ------------------------------------ |
| Variables                            | 8                                    |
| Default subset sizes                 | 1–4                                  |
| Total optimizations                  | 162 subsets                          |
| Maximum possible subsets (all sizes) | 255                                  |
| Checkpoint frequency                 | Every 5 runs                         |
| Parallel support                     | `parfor` (set `use_parallel = true`) |

---

# Key Design Decisions

* **No Optimization Toolbox dependency** (base MATLAB only).
* **Bound handling** implemented via a logit transformation rather than penalty functions.
* **Incremental checkpoint saving** enables recovery after interruptions.
* **Parallel execution** is supported through `parfor` for large studies.
* **Wing area** is implicitly determined through wing loading (`W/S`) within FAST's sizing loop, rather than treated as an independent design variable.
* The framework is easily extensible to larger design spaces by increasing `max_subset_size` in `run_all_subsets.m`.
