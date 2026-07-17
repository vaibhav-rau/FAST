function [x_opt, fval, history] = optimize_subset(var_config, var_indices, baseline_aircraft, mission_handle, opts)
%
% [x_opt, fval, history] = optimize_subset(var_config, var_indices, baseline_aircraft, mission_handle, opts)
%
% Optimize a subset of design variables using Nelder-Mead (fminsearch)
% with bound handling via logit transformation.
%
% INPUTS:
%     var_config        - variable configuration from define_variables()
%     var_indices       - vector of which variables to optimize (indices)
%     baseline_aircraft - the baseline A320 struct
%     mission_handle    - function handle for mission profile
%     opts              - (optional) struct with optimization options:
%       .MaxIterations  - max fminsearch iterations (default: 200)
%       .TolFun         - function tolerance (default: 1e-1)
%       .TolX           - variable tolerance (default: 1e-2)
%       .NumRestarts    - number of random restarts (default: 1)
%       .Display        - 'iter' or 'off' (default: 'off')
%
% OUTPUTS:
%     x_opt    - optimal variable values (display units)
%     fval     - optimal fuel burn (kg)
%     history  - struct with optimization history
%

%% DEFAULT OPTIONS %%
if nargin < 5
    opts = struct();
end
if ~isfield(opts, 'MaxIterations'), opts.MaxIterations = 200; end
if ~isfield(opts, 'TolFun'),        opts.TolFun = 1e-1;       end
if ~isfield(opts, 'TolX'),          opts.TolX = 1e-2;         end
if ~isfield(opts, 'NumRestarts'),   opts.NumRestarts = 1;     end
if ~isfield(opts, 'Display'),       opts.Display = 'off';     end

n_sub = length(var_indices);

% extract bounds for the subset
lb = var_config.bounds(var_indices, 1)';
ub = var_config.bounds(var_indices, 2)';

% starting point: baseline values (clamped to bounds)
x0 = var_config.baseline(var_indices);
x0 = max(lb, min(ub, x0));

%% SETUP FMINSEARCH %%
fms_opts = optimset( ...
    'MaxIter', opts.MaxIterations, ...
    'MaxFunEvals', opts.MaxIterations * (n_sub + 1) * 2, ...
    'TolFun', opts.TolFun, ...
    'TolX', opts.TolX, ...
    'Display', opts.Display ...
);

%% RUN OPTIMIZATION %%
% Objective: transform from unconstrained t to bounded x via logit
obj_fn = @(t) objective_bounded(t, lb, ub, var_config, var_indices, ...
    baseline_aircraft, mission_handle);

best_fval = Inf;
best_x = x0;
all_restarts = {};

for r = 1:opts.NumRestarts
    
    if r == 1
        t0 = logit_transform(x0, lb, ub);
    else
        % random restart within bounds
        x_rand = lb + (ub - lb) .* rand(1, n_sub);
        t0 = logit_transform(x_rand, lb, ub);
    end
    
    [t_opt, fval, exitflag, output] = fminsearch(obj_fn, t0, fms_opts);
    
    x_candidate = inv_logit_transform(t_opt, lb, ub);
    
    all_restarts{r}.x = x_candidate;
    all_restarts{r}.fval = fval;
    all_restarts{r}.output = output;
    all_restarts{r}.exitflag = exitflag;
    
    if fval < best_fval
        best_fval = fval;
        best_x = x_candidate;
    end
end

%% OUTPUT %%
x_opt = best_x;
fval = best_fval;

history.x_all = best_x;
history.fval_all = best_fval;
history.restarts = all_restarts;
history.n_evals = sum(cellfun(@(r) r.output.funcCount, all_restarts));

end


%% HELPER: OBJECTIVE WITH BOUND TRANSFORMATION %%
function f = objective_bounded(t, lb, ub, var_config, var_indices, baseline_aircraft, mission_handle)
    
    % transform from unconstrained to bounded
    x = inv_logit_transform(t, lb, ub);
    
    % evaluate
    f = objective_fn(x, var_config, var_indices, baseline_aircraft, mission_handle);
    
end


%% HELPER: LOGIT TRANSFORM (bounded -> unbounded) %%
function t = logit_transform(x, lb, ub)
    % x in [lb, ub] -> t in (-inf, inf)
    % using scaled logit: t = log((x - lb) / (ub - x))
    x_s = (x - lb) ./ (ub - lb);  % normalize to [0, 1]
    x_s = max(1e-6, min(1 - 1e-6, x_s));  % avoid log(0)
    t = log(x_s ./ (1 - x_s));
end


%% HELPER: INVERSE LOGIT (unbounded -> bounded) %%
function x = inv_logit_transform(t, lb, ub)
    % t in (-inf, inf) -> x in [lb, ub]
    s = 1 ./ (1 + exp(-t));  % sigmoid, output in (0, 1)
    x = lb + (ub - lb) .* s;
end
