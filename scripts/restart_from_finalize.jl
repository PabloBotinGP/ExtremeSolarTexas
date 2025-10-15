#!/usr/bin/env julia
# Restart build from finalization step (after thermal processing complete)
# Resumes from line 736 of build_system_script.jl

# Change to script directory to ensure relative paths work
cd(dirname(@__FILE__))

using PowerSystems
include("scripts/system_build_functions.jl")
include("scripts/file_pointers.jl")
include("scripts/manual_data_entries.jl")

println("Loading post_thermal_sys.json...")
sys = System("post_thermal_sys.json")

println("Running finalize_system...")
finalize_system(sys)

println("Loading base_sys.json...")
sys = System("base_sys.json")

# Save as intermediate_sys.json for add_services.jl
println("Preparing system for service addition...")
to_json(sys, "intermediate_sys.json", force = true)

# Add ancillary services (reserves)
println("Adding ancillary services (reserves)...")
include("scripts/add_services.jl")

println("Creating market timeframe systems...")
include("scripts/make_day_ahead_data.jl")    # Creates sys_DA
# include("scripts/make_real_time_data.jl")  # Skipped: requires quantile solar data not in repo

println("Exporting final market systems...")
to_json(sys_DA, "sys_da.json", force = true)
# to_json(sys_RT, "sys_rt.json", force = true)  # Skipped: RT system not created

println("\n✓ Build complete! Systems created:")
println("  - base_sys.json")
println("  - intermediate_sys_w_services.json (with reserves)")
println("  - sys_da.json (day-ahead market)")
# println("  - sys_rt.json (real-time market)")  # Skipped
