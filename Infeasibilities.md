# Infeasibilities Investigation — Hydro UB (upper-bound) violations

Date: 2025-10-22

Summary
-------
This note records the diagnostics performed after reproducing an infeasible day-ahead Unit Commitment (UC) model. The solver IIS and logs indicate that many (if not all) hydro components are implicated via upper-bound time-series constraints named

`ActivePowerVariableTimeSeriesLimitsConstraint__HydroDispatch__ub`

A test was performed by temporarily removing the `MARBLE FALLS_6` hydro component to verify whether hydro timeseries feedforward constraints are the primary cause of infeasibility. Othe infeasibilities in other hydro plants pop up. 

Key numerical findings
----------------------
- The device active power upper bound for `MARBLE FALLS_6` (from system JSON) is 2.470035778175313 MW.
- Raw telemetry CSV used for MARBLE FALLS mapping: `scripts/input_data/Hydropower/HYDRO/MARBFA_MARBFAG2.csv`:
  - Numeric rows: 70,180
  - min = 0.0, max = 21.1
  - mean ≈ 1.0562, std ≈ 4.0940
  - Count of values > device bound (2.470035778175313): 5,052 (~7.2%)
- Consolidated day-ahead HDF5 dataset used by the pipeline: `scripts/input_data/Hydropower/hydro_power_da.h5` group `"MARBLE FALLS 2 6"`:
  - shape (365, 36) → 13,140 entries
  - min = 0.0, max ≈ 0.9693, mean ≈ 0.0447
- Where both CSV and HDF5 entries were nonzero and aligned by timestamp, the CSV values are ~83× larger than the HDF5 values (mean ratio ≈ 83.5).

Interpretation / hypothesis
---------------------------
- The solver IIS implicates a hydro timeseries upper-bound constraint for `MARBLE FALLS_6` which suggests that the DecisionModel used timeseries with values larger than the equipment limit.
- There is a strong mismatch between raw CSV telemetry and the consolidated HDF5 DA dataset: the CSV contains some values substantially greater than the device limit while the HDF5 DA dataset values are well below the limit. This points to either:
  1. The DecisionModel was fed the raw CSV values (unscaled) for `MARBLE FALLS_6`, or
  2. The DecisionModel used the HDF5 dataset but mapping assigned the wrong dataset (or the dataset got rescaled incorrectly earlier in processing).

Action taken: temporary removal test
----------------------------------
- I added a temporary removal of `"MARBLE FALLS_6"`, other infeasibilites

How I changed the repository (temporary)
----------------------------------------
- Edited `scripts/build_system_script.jl` to insert the following temporary block right after `sys = System("pre_thermal_sys.json")`:

```julia
# TEMPORARY DEBUG: remove MARBLE FALLS_6 hydro component to test if hydro timeseries caused infeasibility
try
    marble = get_component(HydroDispatch, sys, "MARBLE FALLS_6")
    if !isnothing(marble)
        @info "Temporarily removing component MARBLE FALLS_6 to test infeasibility impact"
        remove_component!(sys, marble)
        to_json(sys, "pre_thermal_sys_no_marblefalls6.json", force = true)
    else
        @info "Component MARBLE FALLS_6 not found in pre_thermal_sys.json; no removal performed"
    end
catch e
    @error "Error while attempting to remove MARBLE FALLS_6: $e"
end
```

Test result (what to run locally)
----------------------------------
I did not run a full UC/ED pipeline here to avoid long runs. To execute the quick local check yourself (or I can run it if you want), do the following in the project root:

```bash
# from project root
julia --project=. -e 'include("scripts/build_system_script.jl")'
```

Expected outcomes:
- The script will create `pre_thermal_sys_no_marblefalls6.json` if the component existed and was successfully removed. The log will contain an info message about removing the component.
- After the removal, re-run the single-stage reproduction (or full pipeline) using the modified pre-thermal system. If the previous infeasibility was caused by MARBLE FALLS_6 timeseries values, the UC should now be feasible (or at least the same IIS should not reappear). If other infeasibilities remain, the solver will report them and new artifacts will be persisted.

Recorded results (please run locally / I can run next)
------------------------------------------------------
- I inserted the removal and created this `Infeasibilities.md` file that documents the steps and expected test command. I did not execute the long model runs in this session.

Next steps
----------
1. Run the local test (above) to produce `pre_thermal_sys_no_marblefalls6.json` and then run the single-stage DecisionModel to verify whether the infeasibility disappears.
2. If the infeasibility is resolved after removal, the fix options are:
   - Re-process the raw CSV to ensure consistent units/scale, or
   - Use the consolidated HDF5 datasets (confirmed safe) for DecisionModel inputs, or
   - Add a per-component scaling factor during ingestion so raw telemetry aligns with device bounds.
3. If infeasibilities persist, repeat the targeted extraction from `infeasible_UC.json` and `optimization_container_metadata.bin` to map variables/constraints to timeseries identifiers; then repeat the A/B test on the next implicated component.

Appendix: locations of interest
-------------------------------
- Persisted infeasible model + logs: `simulation_debug/singlestage_2025-10-22_103835/`
- Raw hydro CSVs: `scripts/input_data/Hydropower/HYDRO/` (e.g. `MARBFA_MARBFAG2.csv`)
- Consolidated DA timeseries: `scripts/input_data/Hydropower/hydro_power_da.h5`
- Hydro mapping CSV: `scripts/input_data/Hydropower/hydro_mapping.csv`
- Pipeline ingestion: `scripts/make_day_ahead_data.jl`

If you'd like, I can now (choose one):
- Run the quick removal test locally and then execute the single-stage DecisionModel to check feasibility; or
- Parse `infeasible_UC.json` more precisely (extract the minimal mapping piece that links MARBLE FALLS_6 variables to the actual timeseries identifier in the model), which will let us decide whether to rescale ingestion or correct mapping.


---
Generated by the investigation workflow on 2025-10-22.
