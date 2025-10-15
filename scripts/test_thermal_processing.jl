#!/usr/bin/env julia
# test_thermal_processing.jl
#
# Lightweight test script to validate all critical libraries and operations
# used in thermal_processing.jl BEFORE running the full multi-hour script.
#
# This script tests a minimal subset (3-4 generators) covering different types
# to ensure:
#   - HDF5 file reading works
#   - JuMP/Xpress solver instantiation and optimization works
#   - PowerSystems operations work
#   - JSON serialization works
#
# Run this before thermal_processing.jl to catch environment errors early:
#   julia --project=@ scripts/test_thermal_processing.jl

println("=" ^ 80)
println("Starting lightweight thermal processing test...")
println("=" ^ 80)

# Include dependencies (same as thermal_processing.jl)
include("file_pointers.jl")
include("system_build_functions.jl")
include("manual_data_entries.jl")
include("incrementalpiecewise.jl")

using CSV
using DataFrames

println("\n✓ Successfully loaded all includes and dependencies")

# Load the pre-thermal system
println("\nLoading pre_thermal_sys.json...")
sys = System("pre_thermal_sys.json")
set_units_base_system!(sys, "NATURAL_UNITS")
println("✓ System loaded successfully")

const MAKE_PLOTS = false

# Test a small representative sample of generators covering different types
test_generators = [
    # Test 1: CC_CT with SCED data
    (
        gen_name = "gen-26",
        sced_name = "OECCS_CC1_2",
        new_name = "TEST_ODESSA_ECTOR POWER1 CC2",
        prime_mover = "CC_CT",
        fuel = "NG",
    ),
    # Test 2: CC_CA with SCED data
    (
        gen_name = "gen-27",
        sced_name = "OECCS_CC1_4",
        new_name = "TEST_ODESSA_ECTOR POWER1 CC4",
        prime_mover = "CC_CA",
        fuel = "NG",
    ),
    # Test 3: Steam turbine without SCED (uses default cost)
    (
        gen_name = "gen-41",
        sced_name = nothing,
        new_name = "TEST_SAVOY STATION ST1",
        prime_mover = "ST",
        fuel = "NG",
    ),
    # Test 4: Steam turbine WITH SCED data (uses linear model via make_thermal_gen_st)
    # This test exercises the Xpress solver in get_mean_quadratic_model
    (
        gen_name = "gen-193",
        sced_name = "GRSES_UNIT1",
        new_name = "TEST_GRAHAM STG U1",
        prime_mover = "ST",
        fuel = "NG",
    ),
]

println("\nTesting $(length(test_generators)) representative generators...")
println("-" ^ 80)

for (idx, test_gen) in enumerate(test_generators)
    println("\nTest $idx/$(length(test_generators)): $(test_gen.gen_name) -> $(test_gen.new_name)")
    println("  Type: $(test_gen.prime_mover), Fuel: $(test_gen.fuel)")
    
    try
        # Get the original generator
        gen = get_component(ThermalStandard, sys, test_gen.gen_name)
        if isnothing(gen)
            @error "Generator $(test_gen.gen_name) not found in system!"
            continue
        end
        println("  ✓ Retrieved generator $(test_gen.gen_name)")
        
        # Prepare HSL/LSL and SCED data
        HSL = 0.0
        LSL = 0.0
        ercot_fuel = nothing
        sced_data = nothing
        
        if !isnothing(test_gen.sced_name)
            println("  → Loading SCED data from: $(test_gen.sced_name)")
            ercot_fuel, sced_data = get_sced_data(thermal_sced_h5_file, test_gen.sced_name)
            
            if !isempty(sced_data)
                # Extract HSL/LSL (same logic as thermal_processing.jl)
                HSL_ = sced_data[sced_data.HSL .> 1, :][!, "Submitted_TPO_MW10"]
                HSL = maximum(HSL_[.!isnan.(HSL_)])
                LSL = median(sced_data[sced_data.LSL .> 1, :][!, "LSL"])
                println("  ✓ SCED data loaded: HSL=$HSL, LSL=$LSL, ERCOT_FUEL=$ercot_fuel")
            else
                @warn "  SCED data empty for $(test_gen.sced_name)"
            end
        else
            # Use generator limits
            HSL = get_active_power_limits(gen).max
            LSL = get_active_power_limits(gen).min
            println("  → Using generator limits: HSL=$HSL, LSL=$LSL")
        end
        
        # Create the new thermal generator (THIS IS THE CRITICAL SOLVER TEST)
        println("  → Building thermal generator (calls JuMP/Xpress solver)...")
        
        # Use make_thermal_gen_st for ST generators with SCED data (linear model)
        # This exercises the Xpress solver in get_mean_quadratic_model
        if test_gen.prime_mover == "ST" && !isnothing(sced_data)
            new_thermal = make_thermal_gen_st(
                gen;
                name = test_gen.new_name,
                prime_mover = test_gen.prime_mover,
                fuel = test_gen.fuel,
                HSL = HSL,
                LSL = LSL,
                sced_data = sced_data,
                ercot_fuel = ercot_fuel,
                plot = MAKE_PLOTS,
            )
        else
            new_thermal = make_thermal_gen(
                gen;
                name = test_gen.new_name,
                prime_mover = test_gen.prime_mover,
                fuel = test_gen.fuel,
                HSL = HSL,
                LSL = LSL,
                sced_data = sced_data,
                ercot_fuel = ercot_fuel,
                plot = MAKE_PLOTS,
            )
        end
        println("  ✓ Thermal generator created successfully!")
        
        # Replace in system
        remove_component!(sys, gen)
        add_component!(sys, new_thermal)
        println("  ✓ Generator replaced in system")
        
    catch e
        @error "FAILED on generator $(test_gen.gen_name): $e"
        println("\nStacktrace:")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
        println("\n" * "=" ^ 80)
        println("TEST FAILED - Fix the error above before running thermal_processing.jl")
        println("=" ^ 80)
        exit(1)
    end
end

println("\n" * "-" ^ 80)
println("Testing system serialization (to_json)...")
try
    to_json(sys, "test_thermal_sys.json", force = true)
    println("✓ System serialized successfully")
    
    # Test reload
    test_sys = System("test_thermal_sys.json")
    println("✓ System deserialized successfully")
    
    # Cleanup test file
    rm("test_thermal_sys.json")
    rm("test_thermal_sys_time_series_storage.h5")
    rm("test_thermal_sys_validation_descriptors.json")
    println("✓ Test files cleaned up")
catch e
    @error "System serialization failed: $e"
    exit(1)
end

println("\n" * "=" ^ 80)
println("✅ ALL TESTS PASSED!")
println("=" ^ 80)
println("\nAll critical libraries and operations verified:")
println("  ✓ HDF5 file reading")
println("  ✓ JuMP/Xpress solver instantiation and optimization")
println("  ✓ PowerSystems component manipulation")
println("  ✓ JSON system serialization/deserialization")
println("\nYou can now run the full thermal_processing.jl with confidence.")
println("=" ^ 80)

exit(0)
