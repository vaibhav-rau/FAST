# FAST Codebase Knowledge Base
## Complete Technical Reference

Generated: 2026-07-09

---

# TABLE OF CONTENTS

1. [Project Overview](#1-project-overview)
2. [Architecture & Data Flow](#2-architecture--data-flow)
3. [Aircraft Data Structure](#3-aircraft-data-structure)
4. [Main Entry Point & Sizing Loop](#4-main-entry-point--sizing-loop)
5. [Propulsion Architecture System](#5-propulsion-architecture-system)
6. [Engine Modeling System](#6-engine-modeling-system)
7. [Aerodynamics System](#7-aerodynamics-system)
8. [Battery Modeling System](#8-battery-modeling-system)
9. [Mission Segments & Profiles](#9-mission-segments--profiles)
10. [Weight Estimation (OEW)](#10-weight-estimation-oew)
11. [Database & Regression System](#11-database--regression-system)
12. [Constraint Diagram System](#12-constraint-diagram-system)
13. [Safety / Fault Tree Analysis](#13-safety--fault-tree-analysis)
14. [Visualization System](#14-visualization-system)
15. [Auxiliary Systems](#15-auxiliary-systems)
16. [File Inventory](#16-file-inventory)
17. [Key Algorithms & Equations](#17-key-algorithms--equations)
18. [Naming Conventions & Code Style](#18-naming-conventions--code-style)

---

# 1. PROJECT OVERVIEW

**FAST** = Future Aircraft Sizing Tool  
**Version:** 0.6.0 (04 Jun 2026)  
**Language:** MATLAB (R2019b minimum)  
**License:** Apache 2.0  
**Developed by:** IDEAS Lab, University of Michigan  
**PI:** Dr. Gokcin Cinar  
**Principal Authors:** Paul Mokotoff, Max Arnson

### Purpose
FAST performs **on-design (sizing + performance)** and **off-design (performance only)** analysis of user-prescribed aircraft on user-prescribed mission profiles. It supports:
- Conventional aircraft (turbofan, turboprop)
- Hybrid-electric, series hybrid, turboelectric, parallel electric architectures
- Fully electric aircraft
- Retrofit studies (electrifying existing aircraft)
- Battery lifecycle analysis (aging, degradation, replacement cost)
- Fault tree safety analysis
- Constraint diagram generation (FAA Part 25)

### Key Innovation
The **graph-based matrix representation** of propulsion architectures (Arch, OperUps, OperDwn, EtaUps, EtaDwn matrices) allows FAST to model **any arbitrary propulsion topology** with a single unified framework. This is documented in: *Cinar, G., Garcia, E., & Mavris, D. N. (2020). A framework for electrified propulsion architecture and operation analysis.*

### No External Toolboxes Required
All functionality runs with base MATLAB only.

---

# 2. ARCHITECTURE & DATA FLOW

## High-Level Flow

```
User Aircraft Spec Function  ───>  Main.m
                                       │
                                       ├── InputAircraft()        [user-defined]
                                       │
                                       ├── PreSpecProcessing()    [fill NaN defaults]
                                       │
                                       ├── SpecProcessing()       [regressions for unknowns]
                                       │       └── NLGPR()        [Gaussian Process Regression]
                                       │       └── KPPProjection() [S-curve projections]
                                       │       └── EngineSpecProcessing() [auto engine creation]
                                       │
                                       ├── CreatePropArch()       [graph-based prop architecture]
                                       │
                                       ├── PropArchConnections()  [identify parallel connections]
                                       │
                                       ├── ProfileFxn()           [user-defined mission profile]
                                       │
                                       ├── ProcessProfile()       [validate mission segments]
                                       │
                                       └── EAPAnalysis()          [iterative sizing loop]
                                               │
                                               ├── InitMissionHistory()
                                               ├── PropulsionSizing()       [iter 0 only]
                                               ├── OEWIteration()           [iter > 0, on-design]
                                               ├── ClearMission()
                                               ├── FlyMission()
                                               │       ├── EvalTakeoff()
                                               │       ├── EvalClimb()
                                               │       ├── EvalCruise()
                                               │       ├── EvalDescent()
                                               │       └── EvalLanding()
                                               ├── ResizeBattery()
                                               └── CyclAging()             [off-design only]
```

## Analysis Modes
- **Type = +1:** On-design (sizing + performance). Iterates MTOW, fuel weight, battery weight until convergence. Uses regressions to fill unknowns.
- **Type = -1:** Off-design (performance only). Flies mission with fixed weights.
- **Type = -2:** Retrofit mode. Fixed battery weight. Used by RetrofitPkg.

## Convergence
The sizing loop in `EAPAnalysis.m` checks relative tolerance on:
- Fuel weight change: `|dWfuel| / Wfuel`
- Battery weight change: `|dWbatt| / Wbatt`
- MTOW change: `|dmtow| / MTOW`

All must be below **EPS = 1.0e-3**. Maximum iterations default: 50.

---

# 3. AIRCRAFT DATA STRUCTURE

The `Aircraft` struct is the central data structure passed through all functions. Key branches:

```
Aircraft
├── Settings
│   ├── Analysis.Type          (+1 on-design, -1 off-design, -2 retrofit)
│   ├── Analysis.MaxIter       (max sizing iterations, default 50)
│   ├── Converged              (1 if converged, 0 if not)
│   ├── Plotting               (1 to plot, 0 to not)
│   ├── Table                  (1 to return mission history table)
│   ├── VisualizeAircraft      (1 to show geometry)
│   └── DetailedBatt           (1 if cell-level battery model)
│
├── Specs
│   ├── TLAR                   (Top-Level Aircraft Requirements)
│   │   ├── EIS                (Entry Into Service year)
│   │   ├── Class              ("Turbofan" or "Turboprop")
│   │   └── MaxPax             (max passengers)
│   │
│   ├── Performance
│   │   ├── Vels.Tko           (takeoff velocity, m/s)
│   │   ├── Vels.Crs           (cruise velocity, m/s)
│   │   ├── Alts.Tko           (takeoff altitude, m)
│   │   ├── Alts.Crs           (cruise altitude, m)
│   │   ├── RCMax              (max rate of climb, m/s)
│   │   └── Range              (mission range, m)
│   │
│   ├── Aero
│   │   ├── L_D                (lift-to-drag ratios)
│   │   │   ├── Method         ("Constant" or other)
│   │   │   ├── Clb            (L/D during climb)
│   │   │   ├── Crs            (L/D during cruise)
│   │   │   └── Des            (L/D during descent)
│   │   ├── W_S.SLS            (wing loading at sea level static, N/m^2)
│   │   └── S                  (wing reference area, m^2)
│   │
│   ├── Weight
│   │   ├── MTOW               (max takeoff weight, kg)
│   │   ├── OEW                (operating empty weight, kg)
│   │   ├── Fuel               (fuel weight, kg) -- can be vector for multiple tanks
│   │   ├── Batt               (battery weight, kg) -- can be vector for multiple batteries
│   │   ├── Payload            (payload weight, kg)
│   │   ├── Crew               (crew weight, kg)
│   │   ├── EM                 (electric motor weight, kg)
│   │   ├── EG                 (electric generator weight, kg)
│   │   ├── Engines            (total engine weight, kg)
│   │   ├── Airframe           (airframe weight, kg)
│   │   └── WairfCF            (airframe weight correction factor)
│   │
│   ├── Propulsion
│   │   ├── Engine             (engine specification struct, from EngineSpecsPkg or auto-generated)
│   │   ├── NumEngines         (number of engines)
│   │   ├── T_W.SLS            (thrust-to-weight ratio at SLS)
│   │   ├── Thrust.SLS         (SLS thrust per engine, N)
│   │   ├── T_W                (thrust-to-weight ratio)
│   │   ├── Eta.Prop           (propeller efficiency)
│   │   ├── MDotCF             (core flow correction factor)
│   │   ├── InletArea          (engine inlet area, m^2)
│   │   └── PropArch           (propulsion architecture)
│   │       ├── Type           ("C", "E", "PHE", "SHE", "TE", "PE", "O")
│   │       ├── Arch           (architecture matrix)
│   │       ├── SrcType        (source type: 1=fuel, 0=battery)
│   │       ├── TrnType        (transmitter type: 1=engine, 2=propeller)
│   │       ├── ESType         (energy source type vector)
│   │       └── PSType         (power source type vector)
│   │
│   ├── Power
│   │   ├── SLS                (total power at SLS, W)
│   │   ├── SpecEnergy.Fuel    (fuel specific energy, J/kg)
│   │   ├── SpecEnergy.Batt    (battery specific energy, J/kg)
│   │   ├── Eta                (efficiencies)
│   │   │   ├── EM             (electric motor efficiency)
│   │   │   ├── EG             (electric generator efficiency)
│   │   │   └── Propeller      (propeller efficiency)
│   │   ├── P_W                (power-to-weight ratios)
│   │   │   ├── SLS            (system level)
│   │   │   ├── EM             (electric motor)
│   │   │   └── EG             (electric generator)
│   │   ├── LamUps             (power split UPSTREAM, per flight phase)
│   │   │   ├── SLS, Tko, Clb, Crs, Des, Lnd
│   │   ├── LamDwn             (power split DOWNSTREAM, per flight phase)
│   │   │   ├── SLS, Tko, Clb, Crs, Des, Lnd
│   │   ├── Battery
│   │   │   ├── ParCells       (cells in parallel)
│   │   │   ├── SerCells       (cells in series)
│   │   │   └── BegSOC         (beginning SOC)
│   │   └── Windmill           (windmilling engines per flight phase)
│   │       ├── Tko, Clb, Crs, Des, Lnd
│   │
│   └── Battery                (cell-level battery specs)
│       ├── NomVolCell         (nominal cell voltage, V)
│       ├── MaxExtVolCell      (max external voltage, V)
│       ├── CapCell            (cell capacity, Ah)
│       ├── IntResist          (internal resistance, ohm)
│       ├── ExpVol             (exponential voltage, V)
│       ├── ExpCap             (exponential capacity factor)
│       ├── MinSOC             (minimum state of charge)
│       ├── MaxAllowCRate      (max allowable C-rate)
│       ├── Chem               (1=NMC, 2=LFP)
│       ├── GroundT            (ground time, hours)
│       ├── Cpower             (charging power, W)
│       ├── FEC                (full equivalence cycles, vector)
│       ├── SOH                (state of health, vector)
│       └── OpTemp             (operating temperature, deg C)
│
├── Mission
│   ├── Profile                (mission profile data)
│   │   ├── SegName            (segment names: "takeoff", "climb", "cruise", etc.)
│   │   ├── SegType            (segment types)
│   │   ├── SegStart           (start indices)
│   │   ├── SegEnd             (end indices)
│   │   └── SegData            (segment-specific parameters)
│   ├── ProfileFxn             (function handle to mission profile, stored after sizing)
│   └── History                (mission history)
│       ├── SI                 (SI unit history)
│       │   ├── Performance    (Time, Dist, TAS, EAS, RC, Alt, Acc, FPA, Mach, Rho, Ps)
│       │   ├── Aero           (CL, CD, L_D, Dwm)
│       │   ├── Propulsion     (TSFC, MDotFuel, MDotAir, FanDiam, ExitMach)
│       │   ├── Weight         (CurWeight, Fburn)
│       │   ├── Power          (TV, DV, Req, LamUps, LamDwn, SOC, Pav, Preq, Tav, Treq,
│       │   │                  Pout, Tout, Voltage, Current, Capacity, Windmill)
│       │   └── Energy         (KE, PE, E_ES, Eleft_ES)
│       └── Segment            (string array of segment names per point)
│
├── HistData                   (historical database search results for regressions)
│   └── Eng                    (engine data for regressions)
│
├── Geometry                   (visualization geometry, if enabled)
│   ├── Preset                 (function handle to geometry configuration)
│   ├── Wing                   (lifting surface component)
│   ├── Fuselage               (blunt body component)
│   ├── Engine                 (engine component)
│   └── ...                    (additional components like Htail, Vtail)
│
└── LengthSet                  (prescribed fuselage length, m)
```

## PreSpecProcessing (PreSpecProcessing.m)
This function (608 lines) creates every possible field in the Aircraft struct with NaN defaults. It is called before any analysis to ensure no field is ever missing. The deep nesting mirrors the Aircraft struct tree, checking `isfield()` at each level.

## SpecProcessing (SpecProcessing.m)
For on-design analysis, this fills NaN values using:
- **Gaussian Process Regressions** from historical database (RegressionPkg.NLGPR)
- **S-curve projections** for future technology (ProjectionPkg.KPPProjection)
- **Engine specification processing** if no engine file provided (DataStructPkg.EngineSpecProcessing)

---

# 4. MAIN ENTRY POINT & SIZING LOOP

## Main.m (154 lines)

**Signature:** `[Aircraft, MissionHistory] = Main(InputAircraft, ProfileFxn)`

### Steps:
1. **Cleanup:** `clc, close all`
2. **Call aircraft spec:** `Aircraft = InputAircraft` (user-defined function)
3. **PreSpecProcessing:** Fill missing fields with NaN defaults
4. **Check analysis type:** Default to on-design (+1) if not provided
5. **SpecProcessing:** For on-design, use regressions to fill unknowns
6. **CreatePropArch:** Build graph-based propulsion architecture
7. **PropArchConnections:** Identify parallel connections
8. **ProcessProfile:** Validate mission segments
9. **EAPAnalysis:** Run iterative sizing loop
10. **PlotMission:** Optionally plot results
11. **MissionHistTable:** Optionally return table

## EAPAnalysis.m (386 lines)

**Signature:** `[Aircraft] = EAPAnalysis(Aircraft, Type, MaxIter)`

### Initialization:
- Extract MTOW, fuel weight, battery weight, wing loading
- Detect detailed battery model (if SerCells and ParCells are set)
- Initialize wing area: `S = MTOW / W_S`
- Set convergence tolerance: `EPS = 1.0e-3`

### Iteration Loop:
```
iter = 0
while iter < MaxIter:
    if iter == 0:
        PropulsionSizing()          # Size all propulsion components
    else:
        if Type > 0: OEWIteration() # Iterate OEW (on-design only)
        ClearMission()              # Reset mission history
        if visualizing: GeometryDriver()  # Update geometry visualization
    
    FlyMission()                    # Fly the entire mission profile
    
    Fburn = Mission.History.SI.Weight.Fburn(end)
    dWfuel = Fburn - Wfuel
    
    if Type != -2:                  # Resize battery (not in retrofit mode)
        ResizeBattery()
        dWbatt = NewBatt - OldBatt
    
    mtow_new = MTOW + dWfuel + sum(dWbatt)
    dmtow = mtow_new - MTOW
    
    # Check convergence (relative)
    fuel_conv = |dWfuel| / Wfuel
    batt_conv = |dWbatt| / Wbatt
    mtow_conv = |dmtow| / MTOW
    
    # Update weights
    Wfuel += dWfuel
    Wbatt += dWbatt
    Aircraft.Specs.Weight.MTOW = mtow_new
    Aircraft.Specs.Weight.OEW = mtow_new - sum(Wfuel) - sum(Wbatt) - Wpax - Wcrew
    
    # Check convergence
    if all([fuel_conv, batt_conv, mtow_conv] < EPS): break
    
    iter += 1

# Post-sizing cleanup
Remove temporary geometry fields (LengthSet, Preset, RefParts, TempParts)

# Battery degradation (off-design only)
if Type != 1 && degradation enabled:
    CyclAging() → update SOH and FEC
```

### Key Points:
- **Fuel weight can be a vector** (multiple fuel tanks)
- **Battery weight can be a vector** (multiple batteries)
- `sum()` is used on fuel/batt weights to get total
- `dWbatt` uses `sum()` for vector battery weights
- NaN fuel/batt convergence values are set to 0 (no component present)
- Off-design modes (Type < 0) compute MTOW from sum of components before flying
- Off-design mode -2 (retrofit) fixes battery weight (dWbatt = 0)

---

# 5. PROPULSION ARCHITECTURE SYSTEM

## Core Concept: Graph-Based Matrix Representation

Any propulsion architecture is represented by **5 matrices**:

### 1. Architecture Matrix (`Arch`)
An (N×N) adjacency matrix where N = number of components. Components are ordered:
- **Sources** (energy sources: fuel tanks, batteries) -- first nsrc entries
- **Transmitters** (power converters: engines, motors, generators, propellers) -- next ntrn entries
- **Sinks** (power sinks: thrust producers) -- last nsnk entries

`Arch(i,j) = 1` means component j receives power from component i.

### 2. Source Types (`SrcType`)
Vector of length nsrc. Values:
- `1` = fuel (gas turbine)
- `0` = battery (electric)

### 3. Transmitter Types (`TrnType`)
Vector of length ntrn. Values:
- `1` = gas turbine engine
- `2` = propeller
- `3` = electric motor
- `4` = electric generator
- `5` = other

### 4. Operational Splits - Upstream (`OperUps`)
Function handles that define how power is split at **upstream** junctions (where multiple sources feed into one transmitter).

### 5. Operational Splits - Downstream (`OperDwn`)
Function handles that define how power is split at **downstream** junctions (where one transmitter feeds multiple sinks).

### 6. Efficiencies - Upstream (`EtaUps`)
Matrix of transmission efficiencies for upstream connections.

### 7. Efficiencies - Downstream (`EtaDwn`)
Matrix of transmission efficiencies for downstream connections.

## CreatePropArch.m (631 lines)

Builds all architecture matrices from user inputs. Supports these architecture types:

| Type | Name | Description |
|------|------|-------------|
| `C`  | Conventional | Fuel engines only |
| `E`  | Electric | Battery + electric motors only |
| `PHE` | Parallel Hybrid Electric | Fuel engines + electric motors, both provide thrust |
| `SHE` | Series Hybrid Electric | Fuel engine → generator → electric motors → thrust |
| `TE` | Turboelectric | Fuel engine → generator, separate fuel engines for thrust |
| `PE` | Parallel Electric | Similar to PHE with specific topology |
| `O`  | Other/Custom | User-defined via matrices |

### Supported Configurations:
- 1-6 engines
- Turbofan or Turboprop class
- Any combination of the above types

### Output Matrices:
The function populates these into `Aircraft.Specs.Propulsion.PropArch`:
- `Arch` -- adjacency matrix
- `OperUps` -- upstream power split function handles
- `OperDwn` -- downstream power split function handles
- `EtaUps` -- upstream efficiencies
- `EtaDwn` -- downstream efficiencies
- `SrcType` -- source types
- `TrnType` -- transmitter types

## PropArchConnections.m (89 lines)

Identifies **parallel connections** in the architecture -- cases where multiple transmitters (e.g., engines + motors) drive the same propeller. Stores connection pairs in `Aircraft.Specs.Propulsion.PropArch.ParConns`.

## PowerFlow.m (113 lines)

Propagates power through the architecture matrices iteratively. Starting from energy sources (fuel/batteries), it computes power available at each component by:
1. Applying upstream splits at junctions
2. Multiplying by transmission efficiencies
3. Applying downstream splits at junctions
4. Iterating until power values stabilize

## PowerAvailable.m (250 lines)

Computes total thrust power available from the entire propulsion system. Calls `PowerFlow` to get component-level power, then sums thrust power across all thrust-producing components. Handles both simple (conventional) and complex (hybrid) architectures.

## PropulsionSizing.m (322 lines)

Sizes all propulsion components at the start of the sizing loop (iter 0):
- Computes total required thrust/power from wing loading and flight conditions
- Splits thrust/power through the architecture matrices
- Sizes engines, electric motors, generators, propellers based on their share
- Uses `EngineLapse.m` for altitude effects on gas turbine performance

## EngineLapse.m (69 lines)

Estimates how thrust/power changes with altitude using density ratio method:
`T_actual = T_SLS * (rho / rho_SL)`

For turbofans, the lapse rate is typically:
`T = T_SLS * sigma^n` where sigma = rho/rho_SL and n depends on Mach and altitude.

## PowerSupplementCheck.m (122 lines)

Checks if any component in the architecture is **siphoning** or **supplying** power from/to gas turbine engines. This is relevant for turboelectric architectures where a turbine drives a generator that powers electric motors.

## PropAnalysis.m (715 lines)

The main propulsion analysis function called during each mission segment. For each timestep:
1. Determines which engines are operating vs windmilling
2. Computes thrust/power required at each engine
3. Evaluates power splits (upstream and downstream)
4. Computes fuel flow (for gas turbines) and electrical power (for batteries/motors)
5. Updates battery SOC
6. Records all propulsion history data

## ProcessPropArch.m (153 lines)

Finds gas-turbine-to-propeller connections and computes hybridization coefficients (HE coefficients). These relate how much of a propeller's power comes from the gas turbine vs from electric motors.

## RecomputeSplits.m (135 lines)

Re-computes operational power splits for "full throttle" conditions during specific mission phases (e.g., takeoff at maximum power). Overrides the default splits when needed.

## EvalSplit.m (49 lines)

Simple utility that evaluates a split function handle with given parameter values.

---

# 6. ENGINE MODELING SYSTEM

## Overview

The engine modeling system is the largest subsystem with 6 sub-packages:
- `+CycleModelPkg` -- thermodynamic cycle models
- `+ComponentOnPkg` -- on-design engine components
- `+ComponentOffPkg` -- off-design engine components
- `+IsenRelPkg` -- isentropic relations
- `+SpecHeatPkg` -- specific heat / gas property models
- `+EngineSpecsPkg` -- 20 pre-defined engine specifications

## Top-Level Engine Functions

### TurbofanLinearSizing.m (230 lines)
Linear (simplified) turbofan sizing based on:
- Overall Pressure Ratio (OPR)
- Fan Pressure Ratio (FPR)
- Bypass Ratio (BPR)
- Design thrust
Uses correlations to size compressor stages, turbine stages, etc.

### TurbofanNonlinearSizing.m (196 lines)
Nonlinear turbofan sizing using the full thermodynamic cycle model. Iterates component performance until the cycle closes. More accurate but slower than linear.

### TurbopropLinearSizing.m (145 lines)
Linear turboprop sizing similar to turbofan but for propeller-driven engines.

### TurbopropNonlinearSizing.m (191 lines)
Nonlinear turboprop sizing using thermodynamic cycle.

### TurbofanOffDesign.m (209 lines)
Off-design turbofan analysis -- given an engine designed at one condition, compute its performance at a different (altitude, Mach) condition. Uses match conditions:
- Fan match
- Core turbine match
- Bypass turbine match

### SimpleOffDesign.m (149 lines)
Simplified off-design analysis using BADA (Base of Aircraft Data) coefficients. Uses fuel flow model:
`fuel_flow = Cff1 * (V/C1)^Cff2 + Cff3`

### TF_OD_MapMaker.m (68 lines)
Creates off-design performance maps for turbofans across altitude and Mach ranges.

### TurbofanOffDesignDriver.m (35 lines)
Driver function that calls the appropriate off-design method.

## Cycle Models (+CycleModelPkg)

### TurbofanOnDesignCycle.m (308 lines)
Full thermodynamic cycle analysis for turbofan on-design:
1. Inlet/diffuser (isentropic compression)
2. Fan system (compression + bypass split)
3. Core compressor stages
4. Burner (constant pressure combustion)
5. Turbine stages (drives fan + compressor)
6. Core and bypass nozzles (expand to ambient)

Iterates to close the cycle: turbine work = compressor + fan work.

### TurbopropOnDesignCycle.m (244 lines)
Similar to turbofan but for turboprop. Includes power turbine that drives the propeller.

### TurbofanOffDesignCycle2.m (309 lines)
Off-design cycle analysis. Given fixed geometry from on-design, find operating point at new flight condition by matching:
- Pressure ratios
- Mass flow through components
- Work balance

## Engine Components (+ComponentOnPkg)

Each component models a specific part of the gas turbine:

### Diffuser.m (78 lines)
- Isentropic deceleration
- Pressure recovery factor
- Output: total pressure, total temperature at combustor entry

### Compressor.m (134 lines)
- Multi-stage compression
- Polytropic efficiency → isentropic efficiency
- Stage-by-stage pressure rise
- Input: OPR, efficiency, bleed flows

### CompStg.m (138 lines)
- Individual compressor stage model
- Accounts for blade geometry, work input, losses

### FanSystem.m (128 lines)
- Fan + bypass duct model
- Splits flow into core and bypass streams
- FPR determines bypass stream compression

### Burner.m (133 lines)
- Constant pressure combustion
- Combustion efficiency (typically 0.995)
- Pressure loss factor
- Fuel-air ratio calculation
- Outlet temperature limited by Tt4Max

### Turbine.m (115 lines)
- Expansion through turbine
- Extracts work to drive compressor/fan
- Polytropic efficiency model

### TurbStg.m (143 lines)
- Individual turbine stage model
- Stage loading, flow coefficient

### PerfExNozzle.m (132 lines)
- Perfect expansion nozzle
- Determines if flow is choked
- Computes exit Mach, thrust

## Off-Design Components (+ComponentOffPkg)

### Nozzle.m (38 lines)
- Simple nozzle model for off-design
- Handles choked/unchoked conditions

## Isentropic Relations (+IsenRelPkg)

Standard compressible flow relations:
- `A_Astar.m` -- area ratio to Mach number
- `Astar_A.m` -- Mach number to area ratio
- `MassFlowParam.m` -- mass flow parameter
- `NewGamma.m` -- updated gamma for gas mixtures
- `Ps_Pt.m` -- static to total pressure ratio
- `Pt_Ps.m` -- total to static pressure ratio
- `rhos_rhot.m` -- static to total density ratio
- `Ts_Tt.m` -- static to total temperature ratio
- `Tt_Ts.m` -- total to static temperature ratio

## Specific Heat Models (+SpecHeatPkg)

### CpAir.m (176 lines)
Cp of air as a function of temperature using polynomial fit. Accounts for temperature-dependent specific heat.

### CpJetA.m (108 lines)
Cp of Jet-A fuel combustion products as a function of temperature.

### CvAir.m (137 lines)
Cv of air (constant volume specific heat).

### LocalEfficiency.m (17 lines)
Local component efficiency correction.

### LocalReynolds.m (20 lines)
Local Reynolds number calculation for boundary layer effects.

### NewtonRaphsonTt1.m / NewtonRaphsonTt3.m (54 lines each)
Newton-Raphson solvers for finding total temperature given static conditions and specific heat model. "Tt1" is for one temperature, "Tt3" is for three-temperature blend.

## Engine Specifications (+EngineSpecsPkg)

20 pre-defined engines with complete specifications:

### Turbofan Engines:
| Engine | File | Key Specs |
|--------|------|-----------|
| LEAP-1A26 | LEAP_1A26.m (126 lines) | Modern narrowbody, ~120kN SLS |
| CF34-8E5 | CF34_8E5.m (133 lines) | Regional jet engine |
| CF6-80C2/B7F | CF6_80C2_B7F.m (120 lines) | Widebody engine |
| RB211-22B-02 | RB211_22B_02.m (104 lines) | Classic widebody |
| Trent 970B/84 | Trent_970B_84.m (103 lines) | A380 engine |
| PW2037 | PW_2037.m (103 lines) | 757 engine |
| PW1919G | PW_1919G.m (105 lines) | Geared turbofan |
| AE3007A | AE3007A.m (124 lines) | Regional jet turbofan |
| CeRAS | CeRAS.m (131 lines) | Research aircraft engine |

### Turboprop Engines:
| Engine | File | Key Specs |
|--------|------|-----------|
| AE2100-D3 | AE2100_D3.m (67 lines) | Modern turboprop |
| PT6A-114A | PT6A_114A.m (56 lines) | Classic PT6 variant |
| PW123 | PW_123.m (58 lines) | Regional turboprop |
| PW127M | PW_127M.m (58 lines) | ATR engine |
| TPE331-14GR-805H | TPE331_14GR_805H.m (49 lines) | Small turboprop |
| Allison 250-C30G | Allison_250_C30G.m (30 lines) | Helicopter/small turboprop |
| AE501D-22G | AE501D_22G.m (47 lines) | Military turboprop |

### Example/Generic Engines:
- `ExampleTF.m` (101 lines) -- example turbofan
- `ExampleTP.m` (42 lines) -- example turboprop

### Engine Spec Structure Fields:
```matlab
Engine.Mach              % design Mach number
Engine.Alt               % design altitude (m)
Engine.DesignThrust      % design thrust (N) [turbofan]
Engine.ReqPower          % design power (W) [turboprop]
Engine.Tt4Max            % max turbine inlet temperature (K)
Engine.NoSpools          % number of spools (2 for most)
Engine.OPR               % overall pressure ratio
Engine.FPR               % fan pressure ratio
Engine.BPR               % bypass ratio
Engine.NPR               % nozzle pressure ratio [turboprop]
Engine.RPMs              % [LP, HP] RPM values
Engine.FanGearRatio      % fan gear ratio (NaN if none)
Engine.FanBoosters       % fan boosters (bool)
Engine.MaxIter           % max iterations for cycle convergence
Engine.CoreFlow          % bleed/leakage/cooling fractions
Engine.EtaPoly           % polytropic efficiencies for each component
Engine.Cff1,Cff2,Cff3,Cffch  % BADA off-design coefficients
Engine.HEcoeff           % hybridization coefficient (1 for conventional)
```

---

# 7. AERODYNAMICS SYSTEM

## Overview
Empirical drag buildup adapted from NASA's Aviary tool. No lifting-line or panel methods -- uses correlations.

## DragPolar.m (115 lines)
Main function that assembles the complete drag polar:
`CD = CD0 + CDi + CDc + CDtr + CDwm`

Where:
- CD0 = zero-lift (skin friction) drag
- CDi = induced (lift-dependent) drag
- CDc = compressibility drag
- CDtr = trim drag
- CDwm = windmilling drag

### Inputs:
- Mach number
- Altitude
- Lift coefficient CL
- Wing geometry (AR, sweep, taper, t/c)
- Reynolds number

### Outputs:
- CD (total drag coefficient)
- CD0, CDi, CDc, CDtr, CDwm (individual contributions)
- L/D (lift-to-drag ratio)

## SkinFrictionDrag.m (128 lines)
Computes zero-lift drag using flat plate skin friction correlations:
- Accounts for wetted area
- Reynolds number dependent
- Transition from laminar to turbulent
- Uses turbulence intensity factor
- Includes form factor for fuselage

## InducedDrag.m (97 lines)
Computes induced drag:
`CDi = CL^2 / (pi * AR * e)`
Where e = Oswald efficiency factor (typically 0.7-0.9)

## CompressibilityDrag.m (495 lines)
Drag rise due to compressibility effects at transonic speeds:
- Korn equation for drag divergence Mach number
- Wave drag buildup approaching Mdd
- Accounts for sweep effects
- Critical Mach number calculation

## LiftDependentDrag.m (557 lines)
Detailed lift-dependent drag that goes beyond simple CDi:
- Non-planar lifting surface effects
- Interference drag
- Lift-dependent fuselage drag

## TrimDrag.m (153 lines)
Drag due to longitudinal trim (elevator deflection to maintain CL):
- Depends on tail volume ratio
- Tail lift coefficient
- Tail efficiency

## WindmillDrag.m (113 lines)
Additional drag when an engine is windmilling (not producing thrust but creating drag):
- Uses lookup tables from WindmillingDrag.mat
- Different for turbofan vs turboprop
- Depends on flight condition (takeoff, climb, cruise, descent, landing)

## ConstantLD.m (64 lines)
Returns constant L/D values when the user specifies constant aerodynamics (L_D.Method = "Constant").

## WindmillingDragTables.m (53 lines)
Loads and processes windmilling drag tables from the MAT/XLSX data files.

---

# 8. BATTERY MODELING SYSTEM

## Overview
Two battery models:
1. **Simple model:** Uses specific energy (Wh/kg) directly. No cell-level detail.
2. **Detailed model:** Uses cell-level parameters (SerCells, ParCells set). Models voltage, SOC, degradation.

## Discharging.m (260 lines)

Models battery discharge during flight using an equivalent circuit model:

### Voltage Model:
`V_terminal = OCV(SOC) - I * R_internal`

Where:
- `OCV(SOC)` = Open Circuit Voltage as function of state of charge
- `I` = current draw
- `R_internal` = internal resistance

### OCV Model:
Uses exponential + polynomial fit:
`OCV(SOC) = K0 + K1*SOC + K2*ln(SOC) + K3*ln(1-SOC) + K4*SOC^2`

Parameters K0-K4 derived from cell specifications (NomVolCell, ExpVol, ExpCap).

### Energy Balance:
`E_remaining = E_remaining - P_draw * dt`

### Outputs:
- Terminal voltage
- Current
- SOC
- Power output
- Capacity remaining

## Charging.m (260 lines)

Models battery charging on the ground:
- Constant current / constant voltage (CC/CV) charging profile
- Charging limited by MaxAllowCRate and Cpower
- SOC update during charging
- Voltage and current tracking

## GroundCharge.m (210 lines)

Models ground charging between flights:
- Takes starting SOC, charges to maximum SOC
- Accounts for charging time
- Updates battery temperature
- Returns final SOC and charging energy consumed

## ResizeBattery.m (250 lines)

Called each iteration of the sizing loop to resize batteries based on:
1. **Energy requirement:** Total energy needed for mission
2. **Power requirement:** Maximum power draw during any mission segment

### Energy Sizing:
`W_batt_energy = E_required / (SpecEnergy * SOC_range * DOD * SOH)`

### Power Sizing:
`W_batt_power = P_max / (SpecPower * SOH)`

### Final Battery Weight:
`W_batt = max(W_batt_energy, W_batt_power)`

Also resizes cells in series/parallel if detailed model is used.

## CyclAging.m (150 lines)

Computes battery cycling aging (degradation from charge/discharge cycles):
- Full Equivalent Cycles (FEC) tracking
- State of Health (SOH) prediction
- Uses calendar aging model
- Accounts for depth of discharge
- Temperature effects on degradation rate

## BattAgingOffDesign.m (215 lines)

Off-design battery aging analysis:
- Runs after sizing is complete
- Tracks FEC and SOH across multiple missions
- Models calendar aging between flights
- Accounts for charging rate effects on degradation

---

# 9. MISSION SEGMENTS & PROFILES

## Mission Profiles (+MissionProfilesPkg)

25+ pre-defined mission profiles. Each is a function that takes an Aircraft struct and returns it with mission segments added.

### Profile Structure:
```matlab
Aircraft.Mission.Profile.SegName  = ["takeoff", "climb", "cruise", ...]
Aircraft.Mission.Profile.SegType  = ["takeoff", "climb", "cruise", ...]
Aircraft.Mission.Profile.SegStart = [1, 11, 51, ...]
Aircraft.Mission.Profile.SegEnd   = [10, 50, 200, ...]
Aircraft.Mission.Profile.SegData  = {...}
```

### SegData Structure:
Each segment type has specific parameters:

**Takeoff:**
```matlab
SegData{iseg}.VLOF     % liftoff velocity (m/s)
SegData{iseg}.V2       % takeoff safety speed (m/s)
SegData{iseg}.AltTko   % takeoff altitude (m)
SegData{iseg}.Sgr      % ground roll distance (m)
```

**Climb:**
```matlab
SegData{iseg}.MachC    % climb Mach number
SegData{iseg}.AltEnd   % ending altitude (m)
SegData{iseg}.RCMax    % maximum rate of climb (m/s)
SegData{iseg}.gamma    % flight path angle (deg) [alternative to RC]
```

**Cruise:**
```matlab
SegData{iseg}.MachC    % cruise Mach number
SegData{iseg}.AltCrs   % cruise altitude (m)
SegData{iseg}.DistCrs  % cruise distance (m) OR
SegData{iseg}.Range    % total mission range (m)
```

**Descent:**
```matlab
SegData{iseg}.MachD    % descent Mach number
SegData{iseg}.AltStart % starting altitude (m)
SegData{iseg}.gamma    % descent flight path angle (deg)
SegData{iseg}.RCMax    % max rate of descent (m/s)
```

**Landing:**
```matlab
SegData{iseg}.Vapp     % approach speed (m/s)
SegData{iseg}.SFL      % landing field length (m)
```

### Example Mission Profiles:

| Profile | Description |
|---------|-------------|
| NotionalMission00 | Simple parameterized mission |
| RegionalJetMission00/01/02 | Regional jet with detailed phases |
| TurbopropMission00/01/02 | Turboprop-specific profiles |
| A320.m | A320-style mission |
| ATR42_600.m | ATR 42-600 mission |
| ERJ.m | ERJ-175 mission |
| LM100J.m | LM-100J mission |
| CeRAS.m | CeRAS research mission |
| StandardTurbofanProfile.m | Generic turbofan mission |
| ParametricRegional.m | Parametric regional jet |
| E9XMission.m | Elysian E9X mission |

## Mission Segment Evaluation (+MissionSegsPkg)

### FlyMission.m (224 lines)
Main driver that loops through all segments in order:
```matlab
for iseg = 1:nsegs
    SegmentName = SegName{iseg}
    switch SegmentName
        case "takeoff": EvalTakeoff()
        case "climb":   EvalClimb()
        case "cruise":  EvalCruise()
        case "descent": EvalDescent()
        case "landing": EvalLanding()
    end
end
```

### ProcessProfile.m (325 lines)
Validates the mission profile before flying:
- Checks segment ordering (takeoff must come first, etc.)
- Ensures altitude continuity between segments
- Validates velocity constraints
- Computes segment indices and control points

### EvalTakeoff.m (235 lines)
Evaluates takeoff segment:
- Ground roll (constant acceleration model)
- Rotation and liftoff
- Transition to climb
- Computes thrust required, fuel burn
- Accounts for ground effect

### EvalDetailedTakeoff.m (321 lines)
More detailed takeoff model including:
- Segment 1 (ground roll to VLOF)
- Segment 2 (rotation to V2)
- Segment 3 (takeoff climb to 35ft or 400ft)

### EvalClimb.m (504 lines)
Evaluates climb segment:
- Constant Mach climb (for jet aircraft)
- Constant speed climb
- Computes altitude gain per timestep
- Accounts for thrust lapse with altitude
- Updates weight as fuel burns
- Computes fuel flow at each point
- Uses step-climb approximation

Key equations:
```
RC = (T - D) * V / W
dh = RC * dt
dDist = V * cos(gamma) * dt
dW = -SFC * T * dt  [turbofan]
dW = -SFC * P * dt  [turboprop]
```

### EvalCruise.m (426 lines)
Evaluates cruise segment:
- Constant altitude, constant Mach
- Breguet range equation (iterative or step-by-step)
- Accounts for weight change due to fuel burn
- Computes range achieved vs range required
- Convergence on cruise distance

Key Breguet equation:
```
R = (V / SFC) * (L/D) * ln(W_start / W_end)
```

### EvalCruiseBRE.m (734 lines)
Extended cruise evaluation using Breguet Range Equation:
- Supports multiple cruise segments
- Handles step climbs during cruise
- Accounts for wind (headwind/tailwind)
- More detailed than EvalCruise

### EvalDescent.m (482 lines)
Evaluates descent segment:
- Constant Mach or constant speed descent
- Accounts for windmilling drag
- Computes fuel flow (low, may be near zero for descent)
- Altitude loss per timestep

### EvalLanding.m (253 lines)
Evaluates landing segment:
- Approach and flare
- Rollout
- Computes landing field length
- Final weight update

### ComputeFltCon.m (130 lines)
Computes flight conditions from basic parameters:
- True airspeed from Mach and altitude
- Dynamic pressure
- Reynolds number
- Density from atmosphere model

### StdAtm.m (190 lines)
Standard atmosphere model (ISA):
- Computes temperature, pressure, density as function of altitude
- Handles troposphere (0-11km), stratosphere (11-20km), etc.
- Returns rho (density), T (temperature), P (pressure)

Key formulas:
```
T = T0 - L*h              [troposphere]
P = P0 * (T/T0)^(g/(R*L))
rho = P / (R*T)
```

### Gravity.m (47 lines)
Gravity as function of latitude and altitude:
`g = g0 * (1 - 0.0026373 * cos(2*lat) + 0.0000059 * cos^2(2*lat)) * (R_e / (R_e + h))^2`

---

# 10. WEIGHT ESTIMATION (OEW)

## OEWIteration.m (288 lines)

Iterates on Operating Empty Weight during on-design sizing:

### Process:
1. Start with current OEW estimate
2. Call FLOPS_OEW() to compute new OEW from components
3. Compare with previous OEW
4. If not converged, update and repeat (up to max iterations)

### Convergence:
Relative tolerance on OEW change: `|OEW_new - OEW_old| / OEW_old < tol`

### Key Insight:
OEW depends on MTOW (through component scaling), but MTOW depends on OEW (through weight balance). This creates a nested iteration inside the main sizing loop.

## FLOPS_OEW.m (397 lines)

Weight estimation using the FLOPS (Flight Optimization System) method from NASA:

### Component Weight Breakdown:
```
OEW = W_airframe + W_propulsion + W_systems + W_furnish

W_airframe:
  W_wing      = K_wing * S^0.758 * W_fuel^0.043 * AR^0.338 * (1+taper)^0.363 * T_c^0.896 * (Nz*W_dg)^0.491 * S_WS^0.537
  W_htail     = K_ht * S_ht^0.87 * (1+dh/S_ht)^0.111 * AR_ht^0.417 * t_c_ht^0.069 * (1+V_ht/S_ht)^0.363 * (Nz*W_dg)^0.378 * S_WS^0.121
  W_vtail     = similar to htail
  W_fuselage  = K_fus * L^0.5 * D^2.063 * W_dg^0.177 * Nz^0.242 * L_D_fus^0.989
  W_lgear     = K_lg * W_dg^0.404 * L_m^0.481 * N_s^0.434 * N_e^0.052 * (V_sto/1.49)^0.538

W_propulsion:
  W_engines   = N_eng * W_eng (from regression or engine spec)
  W_nacelle   = K_nac * F_nac^0.522 * N_f^0.156 * N_c^0.0069 * (W_eng/1000)^0.911

W_systems:
  W_flight_ctrl, W_avionics, W_hydraulics, W_electrical, W_acpressurization
  Each uses FLOPS correlations

W_furnish:
  W_seat, W_cargo, W_food, W_cabin_finish, W_lavatory, W_emergency
```

### Key Variables:
- `W_dg` = design gross weight
- `Nz` = ultimate load factor (typically 3.75 for transport)
- `S_WS` = wing structural weight parameter
- `AR` = aspect ratio
- `V_ht` = horizontal tail volume ratio
- `L_m` = main landing gear moment arm
- `N_s` = number of struts
- `N_e` = number of engines

### Electric Aircraft Modifications:
Additional terms for:
- `W_EG` = electric generator weight
- `W_EM` = electric motor weight (from ElectricMachineWeight.m)
- Battery weight handled separately

## ElectricMachineWeight.m (in OEWPkg)

Estimates weight of electric motors/generators using:
`W_em = P_em / (P_W_em * eta_em)`

Where P_W_em is power-to-weight ratio (kW/kg) from user input or regression.

---

# 11. DATABASE & REGRESSION SYSTEM

## Historical Database (+DatabasePkg)

### IDEAS_DB.mat
Contains data for 450+ historical aircraft including:
- Geometric parameters (wing area, span, AR, sweep, etc.)
- Weight breakdown (MTOW, OEW, fuel capacity, etc.)
- Engine data (type, thrust, bypass ratio, OPR, etc.)
- Performance data (range, speed, ceiling, etc.)
- Classification (turbofan, turboprop, piston, etc.)

### ElectricMotorPkg/IDEAS_EM_DB.mat
Hobby-scale electric motor database for regressions on motor specific power.

## Database Functions

### InitializeDatabase.m
Loads and initializes the IDEAS_DB.mat database into MATLAB workspace variables.

### SearchDB.m (172 lines)
Searches the database for aircraft matching given criteria:
```matlab
[results, data] = SearchDB(Database, fields_to_extract, conditions...)
```
- Can filter by class, engine type, etc.
- Returns matching aircraft indices and their data values
- Used before regressions to get relevant training data

### RandomizeDB.m
Randomizes/shuffles database entries for cross-validation.

### TreeBranch.m / StructTreeSearch.m
Tree-based search through database hierarchy. Allows hierarchical filtering (e.g., first by class, then by engine type).

### CalcFanVals.m / CalcPropVals.m
Calculate derived values for fan and propeller engines from raw database data.

## Regression System (+RegressionPkg)

### NLGPR.m (130 lines)
**Non-Linear Gaussian Process Regression** -- the core regression engine:

```matlab
[prediction, variance] = NLGPR(Database, IOSpace, target)
```

- **Database:** Training data from IDEAS_DB
- **IOSpace:** Cell array defining input-output mapping
  - Example: `{["Thrust_SLS"], ["BPR"]}` means: predict BPR from Thrust_SLS
  - Example: `{["Thrust_SLS", "OPR", "BPR"], ["Cff1"]}` means: predict Cff1 from (Thrust, OPR, BPR)
- **target:** Input values to predict at

### Algorithm:
1. Extract input/output columns from database
2. Normalize data
3. Fit Gaussian Process with squared exponential kernel
4. Predict at target point
5. Return mean prediction and variance

### SquareExKernel.m
Squared exponential kernel function:
`k(x1, x2) = sigma_f^2 * exp(-|x1-x2|^2 / (2 * l^2))`

Where:
- `sigma_f` = signal variance (learned)
- `l` = length scale (learned)

### PriorCalculation.m
Computes prior mean and variance from database before GP regression.

### BuildData.m
Prepares data for regression by extracting and formatting columns.

### RegProcessing.m
Post-processes regression results, un-normalizes predictions.

### VaryUserInputs.m
Handles parametric studies by varying input values for regression.

## Engine Spec Processing (DataStructPkg/EngineSpecProcessing.m, 135 lines)

When no engine specification file is provided, this function auto-generates engine specs using regressions:

### For Turbofan:
1. Search database for two-spool turbofan engines
2. Regress LP and HP RPM from design thrust
3. Regress OPR, BPR, FPR from design thrust
4. Set default efficiencies (eta_fan=0.95, eta_comp=0.95, etc.)
5. Set default core flows (bleed=0.03, leakage=0.01, cooling=0.2)
6. Regress BADA off-design coefficients from ICAO data

### For Turboprop:
1. Search database for turboprop engines
2. Regress OPR, RPM from design power
3. Set default efficiencies and core flows

---

# 12. CONSTRAINT DIAGRAM SYSTEM

## ConstraintDiagram.m (212 lines)

Main function that generates T/W vs W/S (or P/W vs W/S) constraint diagrams:

```matlab
ConstraintDiagram(Aircraft, constraints, FlightCond)
```

### Process:
1. Define range of W/S values
2. For each constraint function, compute required T/W at each W/S
3. Plot all constraints on same axes
4. Shade feasible/infeasible regions
5. Mark the design point

### Constraint Functions:

Each returns the minimum T/W (or P/W) required to satisfy the constraint:

| Function | Constraint | FAR Reference |
|----------|------------|---------------|
| JetTOFL.m | Takeoff field length | FAR 25.113 |
| JetLFL.m | Landing field length | FAR 25.123 |
| JetCrs.m | Cruise performance | -- |
| JetCeil.m | Service ceiling | FAR 25.65 |
| JetApp.m | Approach speed | FAR 25.125 |
| JetAEOClimb.m | AEO takeoff climb | FAR 25.111 |
| Jet25_111.m | OEI takeoff climb | FAR 25.111 |
| Jet25_119.m | Balked landing climb AEO | FAR 25.119 |
| Jet25_121a.m | Transition climb OEI | FAR 25.121(a) |
| Jet25_121b.m | Second segment climb OEI | FAR 25.121(b) |
| Jet25_121c.m | Enroute climb OEI | FAR 25.121(c) |
| Jet25_121d.m | Landing climb OEI | FAR 25.121(d) |
| JetDiv.m | Diversion cruise | -- |

### Helper Functions:
- **Sigmoid.m (42 lines):** Smooth transition for OEI (one engine inoperative) constraints using sigmoid function
- **OEIMultiplier.m (49 lines):** Returns the OEI thrust multiplier based on number of engines

## Constraint Specs (+ConstraintSpecsPkg)
Aircraft-specific constraint parameters:
- Boeing777.m, ElysianE9X.m, SUSAN.m
- Define Vapp, field lengths, climb requirements, etc.

---

# 13. SAFETY / FAULT TREE ANALYSIS

## Overview
Fault Tree Analysis (FTA) for assessing safety of propulsion architectures. Uses the graph-based architecture representation to identify failure modes.

## FaultTreeAnalysis.m
Main driver for FTA:
1. Takes the propulsion architecture matrices
2. Identifies all possible failure modes
3. Generates cut sets
4. Computes probability of each cut set
5. Determines system-level failure probability

## EnumerateFailures.m
Enumerates all possible single, double, triple... component failures. For N components, generates all combinations of k failures (k=1,2,3,...).

## CreateCutSets.m
Generates minimal cut sets from the failure enumeration:
- Removes supersets (if {A,B} is a cut set, {A,B,C} is not minimal)
- Applies Boolean algebra laws (idempotent, absorption)

## FailureModel.m
Models the probability of each component failing:
- Uses failure rates from ARP4761 (Figure G-16)
- Component failure probabilities based on type and operating condition

## ComponentDatabase.m
Maps component types to failure rates and failure models.

## Boolean Algebra:
- **IdempotentLaw.m:** A OR A = A
- **LawOfAbsorption.m:** A OR (A AND B) = A
- **CompareCols.m:** Compare columns for redundancy

## Test Cases (+TestCasesPkg)
11 example FTA cases (Example00.mat through Example10.mat) with pre-built architectures and expected results.

---

# 14. VISUALIZATION SYSTEM

## Overview
3D wireframe geometry and propulsion architecture schematics.

## GeometryDriver.m (281 lines)
Main driver for integrated geometry visualization:
1. Takes aircraft structure with Geometry sub-structure
2. Iterates through components (liftingSurface, bluntBody, Engine)
3. Scales components based on current sizing iteration
4. Creates 3D coordinates
5. Plots three-view and isometric view

### Component Types:
- **liftingSurface:** Wings, horizontal/vertical tails
  - Parameters: area, AR, taper, sweep, dihedral, position, orientation, airfoil
- **bluntBody:** Fuselage
  - Parameters: Length, Style (superellipse .dat file)
- **Engine:** Nacelle/pylon
  - Parameters: Length, EngineInletRadii, EngineOutletRadii, Filename

## CreateWing.m (381 lines)
Generates 3D wing coordinates:
1. Create NACA 4-digit airfoil at root and tip
2. Scale by root and tip chords
3. Apply sweep, dihedral, taper
4. Generate three-view projections (top, side, front)
5. Handle symmetric and asymmetric wings

## CreateFuselage.m
Generates fuselage coordinates from superellipse cross-sections:
1. Read .dat file with cross-section parameters
2. Generate superellipses at each station
3. Connect stations to form 3D surface
4. Create three-view projections

## CreateEngine.m
Generates engine nacelle geometry from .dat files with position, scale factors, and type (turbofan/turboprop).

## CreateAirfoil.m (178 lines)
NACA 4-digit airfoil generator:
- Parses airfoil code (e.g., "2412")
- Computes camber line and thickness distribution
- Generates upper and lower surface coordinates
- Uses cosine spacing for points

## SuperEllipse.m (107 lines)
Generates superellipse coordinates:
```matlab
x(t) = r_e * cos(t)^(2/n_ne)    [1st quadrant]
y(t) = r_n * sin(t)^(2/n_ne)
```
Where r_n, r_e, r_s, r_w are radii and n_ne, n_nw, n_sw, n_se are superellipse powers.

## GeoPlot.m
Plots the 3D geometry in three-view and isometric projection.

## PropulsionArchitecture.m / PlotArchitecture.m
Plots the propulsion architecture as a schematic diagram showing energy sources, power converters, and thrust producers with connections.

## Geometry Specifications (+GeometrySpecsPkg)
Pre-defined geometry configurations:
- LM100J.dat, Transport.m, LargeTurbofan.m, LargeTurboprop.m
- SmallTurboprop.m, SmallDoubleAisleTurbofan.m
- DeltaCanard.m, DoubleDeckFuselage.dat, PittsSpecial.m
- SimpleGeometry.m

### .dat File Format:
**Fuselage files:** Header (NoseEnd, TailBeg, TLength, SuperEllipseNum) followed by cross-section parameters (radii, powers, centers, view flags).

**Engine files:** Header (NumberOfEngines) followed by engine parameters (name, position, length/radius scales, type).

---

# 15. AUXILIARY SYSTEMS

## Cost Estimation (+CostPkg)

### BattRepCost.m (129 lines)
Battery replacement cost over lifecycle:
```matlab
Cost = (1 + BMS_lambda/100) * C_E_rep * E_rat / (1+DiscRate)^Lifespan
```
Where:
- `BMS_lambda` = BMS cost fraction (2-3.5% depending on year)
- `C_E_rep` = unit capacity cost ($/kWh, decreasing with year)
- `E_rat` = battery rated capacity (kWh)
- `DiscRate` = discount rate (7%)
- `Lifespan` = years until EOL

Supports NMC and LFP chemistries with year-dependent cost projections.

## KPP Projection (+ProjectionPkg)

### KPPProjection.m (125 lines)
Projects Key Performance Parameters into the future using **S-curve functions**:
```matlab
sig(yr) = low + (high - low) / (1 + exp(-gr * (yr - inf)))
```

| KPP | Class | Inflection Year | Low Asymptote | High Asymptote |
|-----|-------|----------------|---------------|----------------|
| Cruise SFC | Turbofan | 1992 | 0.3335 | 0.851 |
| Cruise SFC | Turboprop | 1993 | 0.3335 | 0.6 |
| T/MTOW | Turbofan | 1980 | 0.15 | 0.3465 |
| T/MTOW | Turboprop | 2011 | 0.3 | 0.9 |
| OEW/MTOW | Both | -- | 0.5123/0.6284 | -- |
| M(L/D) | Turboprop | 2010 | 1 | 10 |
| Battery Specific Energy | Both | 2030.8 | 0 | 801.8 Wh/kg |
| Motor Specific Power | Both | 2030 | 0 | 37.8 kW/kg |

## Retrofit System (+RetrofitPkg)

### Retrofit.m (396 lines)
Electrifies an existing conventional aircraft:
1. Takes a sized conventional aircraft
2. Removes payload proportional to PayDecrease
3. Adds electric motors and batteries in parallel architecture
4. Iterates to find new equilibrium

### Options:
```matlab
Options.NumMotors     % number of electric motors replacing engines
Options.ThrustSplit   % % of thrust from electric (0-1)
Options.PayDecrease   % % payload reduction (0-1)
Options.BattSpecEnergy % battery specific energy (kWh/kg)
Options.PW_EM         % motor power-to-weight ratio (kW/kg)
Options.SavingsType   % "Fuel", "Range", or "Payload"
```

### Savings Types:
- **Fuel:** Iterate battery weight until TOGW = original MTOW. Fuel savings reported.
- **Range:** Iterate range until TOGW = original MTOW. Range increase reported.
- **Payload:** Iterate payload until TOGW = original MTOW. Payload recovery reported.

## Plotting (+PlotPkg)

### PlotMission.m (288 lines)
Generates multiple figures with mission history:
1. **Performance:** Altitude, Distance, Airspeed, Rate of Climb (2×2)
2. **Weights:** Altitude, Distance, Weight, Fuel Burn (2×2)
3. **Propulsion:** Altitude, Power Output, Fuel Flow, SFC (2×2)
4. **Power Detail:** Altitude, Airspeed, R/C, Power Available/Required, Thrust Available/Required, Thrust/Power Output (3×3)
5. **Energy:** Altitude, Specific Excess Power, Total Power Available/Required (2×2)

### PlotPerfParam.m (107 lines)
Utility to plot a single parameter with proper formatting. Handles both continuous and step-like (instantaneous) quantities.

## Unit Conversion (+UnitConversionPkg)

12 conversion functions:
- `ConvForce.m` -- N, lbf, kgf, dyn
- `ConvLength.m` -- m, ft, in, km, mi, naut mi
- `ConvMass.m` -- kg, lbm, slugs, g, oz
- `ConvTemp.m` -- K, degC, degF, degR
- `ConvVel.m` -- m/s, kts, ft/min, mph, km/h, Mach
- `ConvTSFC.m` -- various SFC units

## MissionHistTable.m (135 lines)
Converts mission history to MATLAB timetable with 27 columns including all performance, propulsion, weight, power, and energy quantities. Creates stacked plots for quick visualization.

---

# 16. FILE INVENTORY

## Source Files by Package

| Package | Files | Lines (approx) |
|---------|-------|----------------|
| Root (Main, EAPAnalysis, etc.) | 8 | ~800 |
| +AerodynamicsPkg | 13 | ~2,200 |
| +AircraftSpecsPkg | 13 | ~4,000 |
| +BatteryPkg | 12 | ~2,200 |
| +ConstraintDiagramPkg | 18 | ~2,300 |
| +CostPkg | 3 | ~150 |
| +DatabasePkg | 12 | ~800 |
| +DataStructPkg | 8 | ~1,500 |
| +EngineModelPkg (top) | 10 | ~1,500 |
| +EngineModelPkg/+CycleModelPkg | 5 | ~900 |
| +EngineModelPkg/+ComponentOnPkg | 10 | ~1,100 |
| +EngineModelPkg/+ComponentOffPkg | 2 | ~45 |
| +EngineModelPkg/+IsenRelPkg | 11 | ~350 |
| +EngineModelPkg/+SpecHeatPkg | 9 | ~600 |
| +EngineModelPkg/+EngineSpecsPkg | 20 | ~1,800 |
| +EngineModelPkg/+SurrogateOffDesignPkg | 4 | ~400 |
| +MissionProfilesPkg | 27 | ~2,500 |
| +MissionSegsPkg | 14 | ~3,700 |
| +OEWPkg | 4 | ~1,100 |
| +OptimizationPkg | 15 | ~3,000 |
| +PlotPkg | 3 | ~450 |
| +ProjectionPkg | 3 | ~180 |
| +PropulsionPkg | 15 | ~5,500 |
| +RegressionPkg | 9 | ~800 |
| +RetrofitPkg | 3 | ~500 |
| +SafetyPkg | 10 | ~1,200 |
| +TutorialsPkg | 12 | ~1,500 |
| +UnitConversionPkg | 12 | ~600 |
| +VisualizationPkg | 12 | ~2,500 |

## Data Files

| File | Purpose |
|------|---------|
| IDEAS_DB.mat | Historical aircraft database (450+ aircraft) |
| IDEAS_EM_DB.mat | Electric motor database |
| ARP4761-FigG16.mat | Safety failure rate data |
| GraphPaths.mat | Graph path data for propulsion analysis |
| WindmillingDrag.mat | Windmilling drag lookup tables |
| ICAO_DATA.mat | ICAO emissions data for off-design engine modeling |
| Tutorial012-SizedAircraft.mat | Pre-sized aircraft for tutorials |
| 5× LM100J*.mat | Wireframe coordinates for LM100J visualization |
| 11× Example*.mat | Safety test cases |

---

# 17. KEY ALGORITHMS & EQUATIONS

## Iterative Sizing (EAPAnalysis)
```
MTOW_{n+1} = MTOW_n + dWfuel_n + dWbatt_n
Wfuel_{n+1} = Wfuel_n + dWfuel_n
Wbatt_{n+1} = Wbatt_n + dWbatt_n
OEW_{n+1} = MTOW_{n+1} - Wfuel_{n+1} - Wbatt_{n+1} - Wpax - Wcrew
```

## Breguet Range Equation
```
R = (V * L/D) / SFC * ln(W_start / W_end)
```

## Mission Weight Balance
```
MTOW = OEW + Payload + Crew + Fuel + Battery
```

## Battery Discharge
```
V = OCV(SOC) - I * R_internal
P = V * I
dE = P * dt
SOC_new = SOC - dE / E_capacity
```

## Battery Sizing
```
W_batt = max(E_required / (SE * DOD * SOH), P_required / (SP * SOH))
```
Where SE = specific energy, SP = specific power, DOD = depth of discharge

## OEW Regression (FLOPS)
```
W_wing = C_w * S^0.758 * W_fuel^0.043 * AR^0.338 * ...
W_fus = C_f * L^0.5 * D^2.063 * W_dg^0.177 * ...
W_eng = N_eng * W_eng_single
OEW = W_airframe + W_propulsion + W_systems + W_furnish
```

## Gaussian Process Regression
```
f*(x*) = k(x*)^T * (K + sigma_n^2 * I)^(-1) * y
var(f*) = k(x*,x*) - k(x*)^T * (K + sigma_n^2 * I)^(-1) * k(x*)
```
Where K = kernel matrix, k = kernel vector, y = training outputs

## Standard Atmosphere
```
T(h) = T_0 - L*h                           [troposphere]
P(h) = P_0 * (T(h)/T_0)^(g/(R*L))
rho(h) = P(h) / (R*T(h))
```

## Specific Excess Power
```
Ps = V * (T - D) / W = V * (T/W - 1/(L/D))
```

## Thrust Lapse
```
T(h,M) = T_SL * sigma(h)^n * f(M)
```
Where sigma = rho/rho_SL and n depends on engine type (typically 0.7-0.9)

---

# 18. NAMING CONVENTIONS & CODE STYLE

## Function Names
- **PascalCase**: `EvalClimb`, `CreatePropArch`, `ResizeBattery`
- Abbreviations in UPPER: `EvalCruiseBRE`, `ConvMass`, `PlotPerfParam`

## Variable Names
- **PascalCase** for most: `Aircraft`, `MissionHistory`, `DesignThrust`
- **UPPERCASE** for abbreviations: `MTOW`, `OEW`, `TAS`, `EAS`, `SFC`, `TSFC`
- **lowercase** for loop counters and small variables: `i`, `j`, `iter`, `npnt`
- **Underscore** for fractions: `W_S` (wing loading), `P_W` (power-to-weight)

## Code Organization
- Section headers: `%% SECTION NAME %%` with `%%%%%%%%%%%%%%%` dividers
- Sub-sections within sections
- Function headers with standard format (author, date, inputs/outputs with size/type/units)
- Comments explain *what*, not *why* (mostly)

## Package Structure
- `+PkgName/` directories for MATLAB packages
- Import with `import PkgName.*`
- Each package has `Contents.m` and `README.m`
- All `README.m` files follow standard template (copyright, overview, warning)

## File Naming
- Functions: PascalCase matching function name
- Test files: `Test<FunctionName>.m`
- Data files: `UPPER_CASE.mat` or `PascalCase.xlsx`
- Geometry files: `<Name>.dat` or `<Name>.DAT`

---

*End of FAST Codebase Knowledge Base*
