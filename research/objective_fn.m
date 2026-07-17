function [fuel_burn, Aircraft] = objective_fn(x, var_config, var_indices, baseline_aircraft, mission_handle)
%
% [fuel_burn, Aircraft] = objective_fn(x, var_config, var_indices, baseline_aircraft, mission_handle)
%
% Objective function for the optimization. Takes a vector of design variable
% values, applies them to the baseline aircraft, runs FAST, and returns fuel burn.
%
% INPUTS:
%     x                 - vector of design variable values (display units)
%     var_config        - variable configuration from define_variables()
%     var_indices       - which variables are being optimized
%     baseline_aircraft - the baseline A320 struct (unmodified copy)
%     mission_handle    - function handle for the mission profile
%
% OUTPUTS:
%     fuel_burn         - total mission fuel burn (kg), or Inf if failed
%     Aircraft          - sized aircraft struct (empty if failed)
%

try
    % apply design variables to a fresh copy of the baseline
    Ac = apply_design_vars(baseline_aircraft, var_config, x, var_indices);
    
    % run FAST sizing + mission analysis
    % suppress warnings to keep output clean
    warning('off', 'all');
    [Ac, ~] = Main(Ac, mission_handle);
    warning('on', 'all');
    
    % check convergence
    if isfield(Ac.Settings, 'Converged') && Ac.Settings.Converged == 0
        fuel_burn = Inf;
        Aircraft = [];
        return;
    end
    
    % extract fuel burn
    fuel_burn = Ac.Mission.History.SI.Weight.Fburn(end);
    
    % sanity check
    if isnan(fuel_burn) || isinf(fuel_burn) || fuel_burn <= 0
        fuel_burn = Inf;
        Aircraft = [];
        return;
    end
    
    Aircraft = Ac;
    
catch ME
    %fprintf('  Optimization failed: %s\n', ME.message);
    fuel_burn = Inf;
    Aircraft = [];
end

end
