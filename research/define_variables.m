function [var_config] = define_variables()
%
% [var_config] = define_variables()
%
% Define the design variables, bounds, and baseline values for the
% exhaustive variable subset analysis.
%
% OUTPUTS:
%     var_config - struct containing:
%       .names        - cell array of variable display names
%       .symbols      - cell array of LaTeX-style symbols
%       .field_paths  - cell array of Aircraft struct field paths
%       .bounds       - Nx2 matrix [lb, ub] in native FAST units
%       .baseline     - N-vector of baseline (A320neo) values
%       .units        - cell array of unit strings
%       .n_vars       - total number of design variables
%

%% VARIABLE DEFINITIONS %%

var_config.names = {
    'Wing Area (via Wing Loading)'
    'Aspect Ratio'
    'Wing Sweep'
    'Cruise Altitude'
    'Cruise Mach'
    'Engine Thrust (SLS)'
    'Wing Taper Ratio'
    'Vertical Tail Area'
};

var_config.symbols = {
    'W_S'
    'AR'
    'Lambda'
    'h_crs'
    'M_crs'
    'T_SLS'
    'lambda_w'
    'S_vtail'
};

var_config.units = {
    'kg/m^2'
    '-'
    'deg'
    'ft'
    '-'
    'kN'
    '-'
    'm^2'
};

%% FIELD PATHS %%
% These map each variable to its location in the Aircraft struct.

var_config.field_paths = {
    'Specs.Aero.W_S.SLS'
    'Specs.Aero.Wing.AR'
    'Specs.Aero.Wing.Sweep'
    'Specs.Performance.Alts.Crs'
    'Specs.Performance.Vels.Crs'
    'Specs.Propulsion.Thrust.SLS'
    'Specs.Aero.Wing.TR'
    'Specs.Aero.Vtail.S'
};

%% BASELINE VALUES %%
% Values from AircraftSpecsPkg.A320Neo

% Wing loading: 79000 / 126.5 = 624.5059 kg/m^2
% Aspect ratio: 10.1315
% Wing sweep: 26.9085 deg
% Cruise altitude: 35000 ft = 10668 m
% Cruise Mach: 0.82
% Engine thrust: 237000 N = 237 kN
% Wing taper: 0.2702
% Vtail area: 22.7550 m^2

var_config.baseline = [
    79000 / 126.5    % wing loading (kg/m^2)
    10.1315          % aspect ratio
    26.9085          % wing sweep (deg)
    35000            % cruise altitude (ft)
    0.82             % cruise Mach
    237              % engine thrust (kN)
    0.2702           % wing taper ratio
    22.7550          % vertical tail area (m^2)
];

%% BOUNDS %%
% [lb, ub] in the same units as baseline values
% Bounds are chosen to be physically reasonable for a 737/A320-class aircraft

var_config.bounds = [
    480,  800      % wing loading (kg/m^2) -> wing area ~99-165 m^2 at 79t MTOW
    7,    15       % aspect ratio
    15,   40       % wing sweep (deg)
    28000, 42000   % cruise altitude (ft)
    0.75, 0.88     % cruise Mach
    180,  300      % engine thrust (kN)
    0.15, 0.50     % wing taper ratio
    15,   35       % vertical tail area (m^2)
];

%% CONVERSION FLAGS %%
% Some variables need unit conversion before applying to the Aircraft struct.
% 1 = needs conversion (handled in apply_design_vars), 0 = use directly.

var_config.needs_conversion = [ ...
    0, ...  % wing loading: kg/m^2 (native)
    0, ...  % aspect ratio: dimensionless
    0, ...  % sweep: degrees (FAST uses degrees)
    1, ...  % cruise altitude: ft -> m
    0, ...  % Mach: dimensionless
    1, ...  % thrust: kN -> N
    0, ...  % taper: dimensionless
    0, ...  % vtail area: m^2 (native)
];

%% TOTAL COUNT %%
var_config.n_vars = length(var_config.names);

end
