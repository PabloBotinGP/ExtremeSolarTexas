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