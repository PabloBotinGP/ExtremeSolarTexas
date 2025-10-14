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
```julia
get_cost_data_from_gen(gen, name, LSL, HSL)  # 'gen' undefined!
```

But the function parameter is named `original_gen`, not `gen`.

#### Fix Applied
**File:** `scripts/system_build_functions.jl`  
**Lines:** 860 and 863

#### Validation
Pre-flight test script (`test_thermal_processing.jl`) designed to catch this exact scenario:
- ✅ Test 1: CC_CT with SCED data → PASSED
- ✅ Test 2: CC_CA with SCED data → PASSED
- ❌ Test 3: ST without SCED data → FAILED (exposed bug)
- ⏳ Test 3 (after fix): Expected to PASS
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