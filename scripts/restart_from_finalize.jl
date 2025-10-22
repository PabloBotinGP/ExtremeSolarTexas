#!/usr/bin/env julia
# Restart build from finalization step (after thermal processing complete)
# Resumes from line 736 of build_system_script.jl
# Activate the main project environment (not the scripts subdirectory)

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))  # Activate parent directory (ExtremeSolarTexas)

using PowerSystems
include("system_build_functions.jl")
include("file_pointers.jl")
include("manual_data_entries.jl")

# Load the intermediate system (before services were added)
println("Loading intermediate_sys.json (before adding reserves)...")
sys = System("intermediate_sys.json")

# Add ancillary services (reserves)
println("Adding ancillary services (reserves)...")
include("add_services.jl")

# Save the system with services added
println("Saving intermediate_sys_w_services.json...")
to_json(sys, "intermediate_sys_w_services.json", force = true)

# Now create market timeframe systems
println("Creating market timeframe systems...")
include("make_day_ahead_data.jl")    # Creates and saves DA_sys.json + scenarios
include("make_hour_ahead_data.jl")   # Creates and saves jsons/HA_sys.json
include("make_real_time_data.jl")    # Creates and saves jsons/RT_sys.json

println("\n✓ Build complete! Systems created:")
println("  - intermediate_sys.json (loaded)")
println("  - intermediate_sys_w_services.json (with reserves)")
println("  - DA_sys.json (day-ahead deterministic)")
println("  - DA_sys_31_scenarios.json (day-ahead 31 scenarios)")
println("  - DA_sys_84_scenarios.json (day-ahead 84 scenarios)")
println("  - HA_sys.json (hour-ahead market)")
println("  - RT_sys.json (real-time market)")
