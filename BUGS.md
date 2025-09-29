# Bug Log

This file tracks bugs, errors, and fixes encountered while developing on this repo.  

---

## 2025-09-28 — `UndefKeywordError:` in `add_line!()` 
**Status:** Open 
**Location:**   
- Trigger: `add_line!()` called from `build_system_script.jl:38` 
- Error location: `system_build_functions.jl:219`
- Error: UndefKeywordError(:available)
**Notes:**  
- The error indicates that the keyword `available` was not recognized by the current version of PowerSystems. 
- fieldnames(PowerSystems.Line)
(:name, :available, :active_power_flow, :reactive_power_flow, :arc, :r, :x, :b, :rating, :angle_limits, :rating_b, :rating_c, :g, :services, :ext, :internal). 
- `available` is defined in the type so.. why not found?  
- Common error to all ACBranch types? 
---

## 2025-09-28 — `UndefKeywordError:` in `add_transformer!()`
**Status:** Open 
**Location:**   
- Trigger: `add_transformer!()` called from `build_system_script.jl:39` 
- Error location: `system_build_functions.jl:253`
- Error: UndefKeywordError(:available)
**Notes:**  
- The error indicates that the keyword `available` was not recognized by the current version of PowerSystems. 
- fieldnames(PowerSystems.TapTransformer)
(:name, :available, :active_power_flow, :reactive_power_flow, :arc, :r, :x, :b, :rating, :angle_limits, :rating_b, :rating_c, :g, :services, :ext, :internal) 'available' is defined.. 
- Common error to all ACBranch types? 
---

## 2025-09-28 — `MethodError:` in `add_pv_plant!()`
**Status:** 
Open  
**Location:** 
- Trigger: `add_pv_plant!()` called from `build_system_script.jl:40` 
- Error location: `system_build_functions.jl:296`
- ERROR: MethodError: no method matching set_bustype!(::Nothing, ::ACBusTypes)
The function `set_bustype!` exists, but no method is defined for this combination of argument types.
**Notes:**  
- `set_bustype!` expects an `ACBus`; first argument is `Nothing` at the time of call.
--

## 2025-09-28 — `MethodError:` in `add_hydro_plant!()`
**Status:** 
Open  
**Location:** 
- Trigger: `add_hydro_plant!()` called from `build_system_script.jl` 
- Error location: `system_build_functions.jl:330`
- MethodError: no method matching set_bustype!(::Nothing, ::ACBusTypes)
The function `set_bustype!` exists, but no method is defined for this combination of argument types.
**Notes:**  
- `set_bustype!` expects an `ACBus`; first argument is `Nothing` at the time of call.
--

## 2025-09-28 — `SystemError: opening file ... No such file or directory`
**Status:** Open  
**Location:**  
- Trigger: `/Users/acasavan/GitHub_Repos/market-bid-cost-scratch/plot_cost_functions.jl` called from `scripts/incrementalpiecewise.jl:363`  
- Error location: `./sysimg.jl:38` (during `include`)  
- Error: `SystemError: opening file "/Users/pbotin/Documents/GPAC/Models/ExtremeSolarTexas/ExtremeSolarTexas/scripts/C:/Users/acasavan/GitHub_Repos/market-bid-cost-scratch/plot_cost_functions.jl": No such file or directory`
**Notes:**  
- The constructed path incorrectly concatenates a **macOS absolute path** with a **Windows-style absolute path**, yielding an invalid mixed path.  
- Indicates an **environment-specific, hard-coded include path** being used on a different machine/OS.  
- Repro occurs when running `scripts/incrementalpiecewise.jl` at line 363 where the `include` is invoked.
- I should be able to figure this out easily. Will check it out tomorrow. 

## Template for new entries
### YYYY-MM-DD — <short title of the bug>
**Status:** Open / Fixed / Won’t fix  
**Location:** 
- Trigger:
- Error location: 
- Error:
**Notes:**  
**Fix**
