#!/usr/bin/env julia
# System Active Power Analysis Script
# Loads a PowerSystems snapshot and computes active power totals by category

using Pkg
Pkg.activate(".")

using PowerSystems
using Printf
using DataFrames

# Configuration
const SYS_FILE = "run1_results/DA_sys.json"
const OUTPUT_FILE = "run1_results/sys_analysis_output.txt"

println("=" ^ 80)
println("SYSTEM ACTIVE POWER ANALYSIS")
println("=" ^ 80)
println("Loading system from: $SYS_FILE")
println()

# Load system
sys = System(SYS_FILE)

# Open output file
output = open(OUTPUT_FILE, "w")

function log_line(msg)
    println(msg)
    println(output, msg)
end

log_line("System Summary")
log_line("=" ^ 80)
log_line("System Base Power: $(get_base_power(sys))")
log_line("Total Components: $(length(get_components(Component, sys)))")
log_line("")

# ============================================================================
# RENEWABLE DISPATCH ANALYSIS (by prime mover type)
# ============================================================================
log_line("RENEWABLE DISPATCH ANALYSIS")
log_line("-" ^ 80)

renewables = collect(get_components(RenewableDispatch, sys))
log_line("Total RenewableDispatch count: $(length(renewables))")
log_line("")

# Group by prime mover type
renewable_by_type = Dict{String, Vector{RenewableDispatch}}()
for g in renewables
    pmt = string(get_prime_mover_type(g))
    if !haskey(renewable_by_type, pmt)
        renewable_by_type[pmt] = RenewableDispatch[]
    end
    push!(renewable_by_type[pmt], g)
end

# Print per-type totals
log_line("Capacity by Renewable Type:")
total_renewable_base = 0.0

for (pmt, gens) in sort(collect(renewable_by_type), by=x->x[1])
    sum_base = sum(get_base_power.(gens))
    global total_renewable_base += sum_base
    @printf("  %-15s: count=%3d, capacity=%.2f MW\n", 
            pmt, length(gens), sum_base)
    @printf(output, "  %-15s: count=%3d, capacity=%.2f MW\n", 
            pmt, length(gens), sum_base)
end

log_line("")
@printf("Total Renewable Capacity: %.2f MW\n", total_renewable_base)
@printf(output, "Total Renewable Capacity: %.2f MW\n", total_renewable_base)
log_line("")

# ============================================================================
# HYDRO DISPATCH ANALYSIS
# ============================================================================
log_line("HYDRO DISPATCH ANALYSIS")
log_line("-" ^ 80)

hydro = collect(get_components(HydroDispatch, sys))
log_line("Total HydroDispatch count: $(length(hydro))")

hydro_base = sum(get_base_power.(hydro))

@printf("Total Hydro Capacity: %.2f MW\n", hydro_base)
@printf(output, "Total Hydro Capacity: %.2f MW\n", hydro_base)
log_line("")

# ============================================================================
# THERMAL ANALYSIS (ThermalMultiStart + ThermalStandard)
# ============================================================================
log_line("THERMAL GENERATION ANALYSIS")
log_line("-" ^ 80)

thermal_multi = collect(get_components(ThermalMultiStart, sys))
thermal_std = collect(get_components(ThermalStandard, sys))

log_line("ThermalMultiStart count: $(length(thermal_multi))")
log_line("ThermalStandard count: $(length(thermal_std))")

thermal_multi_base = sum(get_base_power.(thermal_multi))
thermal_std_base = sum(get_base_power.(thermal_std))

total_thermal_base = thermal_multi_base + thermal_std_base

@printf("ThermalMultiStart Capacity: %.2f MW\n", thermal_multi_base)
@printf(output, "ThermalMultiStart Capacity: %.2f MW\n", thermal_multi_base)

@printf("ThermalStandard Capacity: %.2f MW\n", thermal_std_base)
@printf(output, "ThermalStandard Capacity: %.2f MW\n", thermal_std_base)

@printf("Total Thermal Capacity: %.2f MW\n", total_thermal_base)
@printf(output, "Total Thermal Capacity: %.2f MW\n", total_thermal_base)
log_line("")

# ============================================================================
# LOAD ANALYSIS
# ============================================================================
log_line("LOAD ANALYSIS")
log_line("-" ^ 80)

loads = collect(get_components(PowerLoad, sys))
log_line("PowerLoad count: $(length(loads))")

# Loads use max_active_power
load_max = sum(get_max_active_power.(loads))

@printf("Total Load (max demand): %.2f MW\n", load_max)
@printf(output, "Total Load (max demand): %.2f MW\n", load_max)
log_line("")

# ============================================================================
# RESERVE SERVICES ANALYSIS
# ============================================================================
log_line("RESERVE SERVICES ANALYSIS")
log_line("-" ^ 80)

# Get reserve services
reserves_up = collect(get_components(VariableReserve{ReserveUp}, sys))
reserves_dn = collect(get_components(VariableReserve{ReserveDown}, sys))
reserves_nonspin = collect(get_components(VariableReserveNonSpinning, sys))

log_line("VariableReserve{ReserveUp} count: $(length(reserves_up))")
log_line("VariableReserve{ReserveDown} count: $(length(reserves_dn))")
log_line("VariableReserveNonSpinning count: $(length(reserves_nonspin))")

# Reserve services use 'requirement' field
req_up = sum([get_requirement(r) for r in reserves_up])
req_dn = sum([get_requirement(r) for r in reserves_dn])
req_nonspin = sum([get_requirement(r) for r in reserves_nonspin])
total_reserves = req_up + req_dn + req_nonspin

@printf("Reserve Up requirement: %.2f MW\n", req_up)
@printf(output, "Reserve Up requirement: %.2f MW\n", req_up)
@printf("Reserve Down requirement: %.2f MW\n", req_dn)
@printf(output, "Reserve Down requirement: %.2f MW\n", req_dn)
@printf("Reserve NonSpin requirement: %.2f MW\n", req_nonspin)
@printf(output, "Reserve NonSpin requirement: %.2f MW\n", req_nonspin)
@printf("Total Reserve requirement: %.2f MW\n", total_reserves)
@printf(output, "Total Reserve requirement: %.2f MW\n", total_reserves)
log_line("")

# ============================================================================
# SUMMARY TABLE - Formatted for copy/paste
# ============================================================================
log_line("SUMMARY - Capacity (Max Active Power)")
log_line("=" ^ 80)

# Get individual renewable type capacities
wind_cap = 0.0
hydro_cap = hydro_base
solar_cap = 0.0

for (pmt, gens) in renewable_by_type
    sum_base = sum(get_base_power.(gens))
    if pmt == "WT"
        global wind_cap = sum_base
    elseif pmt == "PVe"
        global solar_cap = sum_base
    end
end

# Renewables includes hydro
total_renewables_with_hydro = total_renewable_base + hydro_base
total_capacity = total_renewables_with_hydro + total_thermal_base

# Output in table order
log_line("")
log_line("Renewables\t$(round(total_renewables_with_hydro, digits=2))")
log_line("Thermal\t$(round(total_thermal_base, digits=2))")
log_line("Total Capacity\t$(round(total_capacity, digits=2))")
log_line("")
log_line("Wind\t$(round(wind_cap, digits=2))")
log_line("Hydro\t$(round(hydro_cap, digits=2))")
log_line("Solar\t$(round(solar_cap, digits=2))")
log_line("Total Renewables\t$(round(total_renewables_with_hydro, digits=2))")
log_line("")
log_line("Generation\t$(round(total_capacity, digits=2))")
log_line("Load\t$(round(load_max, digits=2))")
log_line("Reserves\t$(round(total_reserves, digits=2))")

log_line("")
log_line("=" ^ 80)
log_line("Analysis complete. Output saved to: $OUTPUT_FILE")

close(output)

println()
println("Done! View results:")
println("  cat $OUTPUT_FILE")
