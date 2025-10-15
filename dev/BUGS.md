#### Error #1
```
Error: UndefVarError(:gen, 0x00000000000098f2, Main)
Stacktrace pointing to line 863 in system_build_functions.jl
```

#### Impact
- **Affected components:** Any generators without complete SCED data (e.g.: steam turbines).
- **When triggered:** At thermal_processing when first generator without SCED data is processed
- **Test results:** First 2 test generators (CC_CT, CC_CA with SCED) passed; 3rd generator (ST without SCED) exposed the bug

#### Root Cause
In the `make_thermal_gen()` function, the else branch for generators without SCED data called:
But the function parameter is named `original_gen`, not `gen`.

#### Fix Applied
**File:** `scripts/system_build_functions.jl`  
**Lines:** 860 and 863
---

#### Error #2
```
ERROR: LoadError: UndefVarError: `m` not defined in `Main`
Stacktrace:
  [1] get_mean_quadratic_model(gen::Vector{Float64}, price::Vector{Float64}, quad_term::Bool)
    @ Main ~/Documents/GPAC/Models/ExtremeSolarTexas/scripts/system_build_functions.jl:1117
  [2] get_linear_model(df::DataFrame, LSL::Float64, HSL::Float64)
    @ Main ~/Documents/GPAC/Models/ExtremeSolarTexas/scripts/system_build_functions.jl:1254
  [3] get_cost_data_from_sced_linear(sced_data::DataFrame, name::String, LSL::Float64, HSL::Float64, make_plots::Bool)
    @ Main ~/Documents/GPAC/Models/ExtremeSolarTexas/scripts/system_build_functions.jl:667
  [4] make_thermal_gen_st(...)
    @ Main ~/Documents/GPAC/Models/ExtremeSolarTexas/scripts/system_build_functions.jl:985
```

#### Impact
- **Affected components:** Steam Turbine generators with SCED data using linear cost models. 
- **When triggered:** During thermal_processing when processing ST generators with SCED data
- **Call chain:** `make_thermal_gen_st()` → `get_cost_data_from_sced_linear()` → `get_linear_model()` → `get_mean_quadratic_model()`

#### Root Cause
In both `get_mean_quadratic_model()` and `get_median_quadratic_model()` functions, the JuMP model variable `m` was created inside a try-catch block, but code using `m` (like `set_optimizer_attribute(m, ...)`) was placed **outside** the try block. 

When Xpress optimizer failed to instantiate:
1. Exception was caught and rethrown
2. If outer code caught this exception, execution could continue
3. Code at line 1117 tried to use undefined variable `m`
4. Result: `UndefVarError: m not defined`

**Original problematic code:**
```julia
function get_mean_quadratic_model(gen, price, quad_term::Bool = true)
    try
        m = Model(Xpress.Optimizer; )
    catch e
        @error "Failed to instantiate Xpress optimizer: $e"
        rethrow(e)
    end
    set_optimizer_attribute(m, "XPRS_MAXTIME", 10)  # Line 1117: m undefined if try block failed!
    # ... rest of function
```

#### Fix Applied
**File:** `scripts/system_build_functions.jl`  
**Functions affected:** `get_mean_quadratic_model()` (line ~1109) and `get_median_quadratic_model()` (line ~1157)

**Solution:**
1. Declare `m` in function scope with `local m`
2. Move optimizer setup inside try block to ensure `m` exists before use

**Fixed code:**
```julia
function get_mean_quadratic_model(gen, price, quad_term::Bool = true)
    local m  # Declare m in function scope
    try
        m = Model(Xpress.Optimizer; )
        set_optimizer_attribute(m, "XPRS_MAXTIME", 10)  # Now inside try block
    catch e
        @error "Failed to instantiate Xpress optimizer: $e"
        @error "Hint: the Xpress shared library (libxprs.dylib) was not found..."
        rethrow(e)
    end
    # ... rest of function uses m safely
```

Same fix applied to `get_median_quadratic_model()`.

---

#### Error #3: File Deletion Error in finalize_system()
```
ERROR: LoadError: IOError: unlink("intermediate_sys_time_series_storage.h5"): no such file or directory (ENOENT)
Stacktrace:
  [1] rm(path::String; force::Bool, recursive::Bool, allow_delayed_delete::Bool)
    @ Base.Filesystem ./file.jl:285
  [2] finalize_system(sys::System)
    @ Main ~/Documents/GPAC/Models/ExtremeSolarTexas/scripts/system_build_functions.jl:1263
  [3] top-level scope
    @ ~/Documents/GPAC/Models/ExtremeSolarTexas/scripts/build_system_script.jl:736
```

#### Impact
- **Affected components:** System finalization step at end of build_system_script.jl
- **When triggered:** After all processing complete, when attempting final cleanup
- **Result:** Script crashes, preventing creation of market timeframe files.

#### Root Cause
PowerSystems automatically deletes intermediate companion files when using `to_json(sys, "filename.json", force = true)` and creating new system files. The workflow:
1. Line 696: `to_json(sys, "intermediate_sys.json", force = true)` creates intermediate_sys.json + .h5 + _validation_descriptors.json
2. Line 710: `to_json(sys, "pre_thermal_sys.json", force = true)` creates new files; PowerSystems auto-deletes old intermediate_sys.* files
3. Line 721: `to_json(sys, "post_thermal_sys.json", force = true)` continues cleanup
4. Line 736: `finalize_system()` tries to manually delete already-deleted files → crash

#### Fix Applied
**File:** `scripts/system_build_functions.jl`, function `finalize_system()`

**Solution:** Check file existence before deletion to handle PowerSystems' automatic cleanup gracefully.

---

#### Error #4: Type Error in Scenario Time Series Construction
```
ERROR: LoadError: TypeError: in keyword argument data, expected DataStructures.SortedDict{DateTime, Matrix{Float64}}, got a value of type Dict{DateTime, Matrix{Float64}}
Stacktrace:
  [1] top-level scope
    @ ~/Documents/GPAC/Models/ExtremeSolarTexas/scripts/make_day_ahead_data.jl:265
  [2] include(mapexpr::Function, mod::Module, _path::String)
    @ Base ./Base.jl:307
  [3] top-level scope
    @ ~/Documents/GPAC/Models/ExtremeSolarTexas/restart_from_finalize.jl:7
```

#### Impact
- **Affected components:** Day-ahead scenario system creation (31-scenario and 84-scenario solar trajectory forecasts)
- **When triggered:** When adding scenario-based time series data to Area components
- **Result:** Script crashes during market data generation, preventing creation of scenario-based systems

#### Root Cause
The `Scenarios()` constructor in PowerSystems requires time series data to be provided as a `SortedDict` to ensure chronological ordering of timestamps. The code was using a regular `Dict{DateTime, Matrix{Float64}}` instead of `SortedDict{DateTime, Matrix{Float64}}`.

**Two locations affected:**
1. Line 261: 31-scenario solar trajectory system
2. Line 334: 84-scenario solar trajectory system

Both created dictionaries with:
```julia
hour_ahead_forecast = Dict{Dates.DateTime, Matrix{Float64}}()
```

PowerSystems requires sorted temporal data for validation and proper time series operations.

#### Fix Applied
**File:** `scripts/make_day_ahead_data.jl`

**Solution 1:** Install and import SortedDict from DataStructures package
```julia
using PowerSystems
using DataStructures: SortedDict  # Added import
const PSY = PowerSystems
```

**Solution 2:** Use SortedDict for scenario time series data (both occurrences)
```julia
# Changed from:
hour_ahead_forecast = Dict{Dates.DateTime, Matrix{Float64}}()

# Changed to:
hour_ahead_forecast = SortedDict{Dates.DateTime, Matrix{Float64}}()
```

Applied to both:
- 31-scenario system (line ~261)
- 84-scenario system (line ~334)

---

#### Error #5: Missing Reserve Services in System
```
ERROR: LoadError: MethodError: no method matching set_requirement!(::Nothing, ::Float64)
The function `set_requirement!` exists, but no method is defined for this combination of argument types.

Closest candidates are:
  set_requirement!(::ConstantReserveNonSpinning, ::Any)
  set_requirement!(::VariableReserveNonSpinning, ::Any)
  set_requirement!(::ConstantReserve, ::Any)
  ...

Stacktrace:
  [1] top-level scope
    @ ~/Documents/GPAC/Models/ExtremeSolarTexas/scripts/make_day_ahead_data.jl:147
  [2] include(mapexpr::Function, mod::Module, _path::String)
    @ Base ./Base.jl:307
  [3] top-level scope
    @ ~/Documents/GPAC/Models/ExtremeSolarTexas/restart_from_finalize.jl:26
```

#### Impact
- **Affected components:** Day-ahead market system creation, reserve time series assignment
- **When triggered:** When `make_day_ahead_data.jl` attempts to add reserve time series
- **Result:** Script crashes during market data generation before solar/load time series can be added

#### Root Cause
The `make_day_ahead_data.jl` script (lines 133-148) attempts to add time series data to reserve Service objects:
```julia
res = get_component(T, sys_base, name)
set_requirement!(res, peak/100)  # Crashes here when res is Nothing
```

However, the reserve services don't exist in the system because `add_services.jl` is commented out in `build_system_script.jl` (line 729):
```julia
# include("add_services.jl")  # Optional: Add ancillary services
```

When `get_component()` returns `Nothing` (service not found), calling `set_requirement!(Nothing, ...)` triggers a type error.

**Services expected but not found:**
- `REG_UP` (VariableReserve{ReserveUp})
- `REG_DN` (VariableReserve{ReserveDown})
- `SPIN` (VariableReserve{ReserveUp})
- `NONSPIN` (VariableReserveNonSpinning)

#### Fix Applied
**File:** `scripts/make_day_ahead_data.jl`, lines 133-151

**Solution:** Add existence check before attempting to set reserve requirements

```julia
for ((name, T), ts) in reserve_map
    # ... forecast data creation ...
    res = get_component(T, sys_base, name)
    if res !== nothing  # Only add time series if the service exists
        set_requirement!(res, peak/100)
        add_time_series!(sys_base, res, forecast_data)
    else
        @warn "Reserve service $name not found in system - skipping (services may not have been added)"
    end
end
```

This allows the script to continue running when ancillary services are not included in the system build.

#### Questions
- **Why are services commented out?** Is this intentional for the current model scope?
- **Impact of missing services:** What simulation capabilities are lost without ancillary services?
- **Should services be enabled?** Or should the reserve time series code be removed entirely from `make_day_ahead_data.jl`?

### Answer from Anna 
for the full model we would like to add ancillary services!
---
#### Error #6: Incomplete SCED Data for Reserve Service Assignment
```
┌ Error: ArgumentError("column name \"Telemetered_Resource_Status\" not found in the data frame since it has no columns")
└ @ Main ~/Documents/GPAC/Models/ExtremeSolarTexas/scripts/add_services.jl:82
┌ Error: There is something wrong with REG_UP
└ @ Main ~/Documents/GPAC/Models/ExtremeSolarTexas/scripts/add_services.jl:109
┌ Error: There is something wrong with SPIN
└ @ Main ~/Documents/GPAC/Models/ExtremeSolarTexas/scripts/add_services.jl:109
┌ Error: There is something wrong with REG_DN
└ @ Main ~/Documents/GPAC/Models/ExtremeSolarTexas/scripts/add_services.jl:109
```
#### Impact
- **Affected components:** Reserve service assignment (REG_UP, REG_DN, SPIN, NONSPIN)
- **When triggered:** During `add_services.jl` execution when analyzing SCED data
- **Result:** Fewer generators assigned to reserves than expected
- **Severity:** Minor - system builds successfully, but reserve adequacy may be reduced

#### Root Cause
Some generators lack complete SCED (market) data with `Telemetered_Resource_Status` column. The script uses historical SCED data to determine which generators can provide ancillary services, but generators without this data are excluded from reserve participation.

#### Current Status
- Reserve services ARE created (REG_UP, REG_DN, SPIN, NONSPIN)
- Only generators with complete SCED data participate
- System runs normally for energy-focused analysis

#### Solution
**For now:** Keep it like this, system is functional and only affects to the ancillary services. 

**For production:** Investigate missing SCED data or implement manual reserve assignment based on generator characteristics
---

```