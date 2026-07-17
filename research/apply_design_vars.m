function [Aircraft] = apply_design_vars(Aircraft, var_config, x, var_indices)
%
% [Aircraft] = apply_design_vars(Aircraft, var_config, x, var_indices)
%
% Apply a vector of design variable values to the Aircraft struct.
%
% INPUTS:
%     Aircraft     - aircraft struct (will be copied internally)
%     var_config   - variable configuration from define_variables()
%     x            - vector of variable values (in display units)
%     var_indices  - which variables (indices into var_config) are being set
%
% OUTPUTS:
%     Aircraft     - modified aircraft struct
%

% copy to avoid modifying the original
Aircraft = Aircraft;

for i = 1:length(var_indices)
    
    idx = var_indices(i);
    val = x(i);
    
    % get the field path and split into parts
    fpath = var_config.field_paths{idx};
    parts = strsplit(fpath, '.');
    
    % apply unit conversion if needed
    switch idx
        case 4
            % cruise altitude: ft -> m
            val = UnitConversionPkg.ConvLength(val, 'ft', 'm');
        case 6
            % engine thrust: kN -> N
            val = val * 1000;
    end
    
    % set nested field using dynamic reference
    % build the assignment: Aircraft.Specs.Aero.Wing.AR = val
    ref = 'Aircraft';
    for p = 1:length(parts)
        ref = [ref '.' parts{p}];
    end
    eval([ref ' = val;']);
    
end

% recompute wing area from wing loading and MTOW
% (EAPAnalysis does S = MTOW / W_S, but we set it here so
%  that the aero calculations use the correct value)
if any(var_indices == 1)
    idx_wl = find(var_indices == 1);
    wl_val = x(idx_wl);  % kg/m^2
    Aircraft.Specs.Aero.S = Aircraft.Specs.Weight.MTOW / wl_val;
    Aircraft.Specs.Aero.Wing.S = Aircraft.Specs.Aero.S;
    
    % scale wetted areas proportionally to wing area
    S_baseline = 126.5;  % A320neo baseline wing area
    scale = Aircraft.Specs.Aero.S / S_baseline;
    Aircraft.Specs.Aero.Components.Swet(4) = 200.0672 * scale;  % wing wetted area
    
    % keep wing loading consistent
    Aircraft.Specs.Aero.W_S.SLS = wl_val;
end

% update aspect ratio and recompute span-dependent quantities
if any(var_indices == 2)
    AR = Aircraft.Specs.Aero.Wing.AR;
    S = Aircraft.Specs.Aero.Wing.S;
    b = sqrt(AR * S);  % span
    % update fuselage diameter-to-span ratio
    diam = sqrt(4 * Aircraft.Specs.Aero.Fuse.Area / pi);
    Aircraft.Specs.Aero.Fuse.Diam_Span = diam / b;
end

% update T/W ratio when thrust changes
if any(var_indices == 6)
    T_SLS = Aircraft.Specs.Propulsion.Thrust.SLS;
    MTOW = Aircraft.Specs.Weight.MTOW;
    Aircraft.Specs.Propulsion.T_W.SLS = T_SLS / (MTOW * 9.81);
end

end
