#!/usr/bin/env julia
# Deep inspection of H5 file structure

using Pkg
Pkg.activate(".")

using HDF5

# File paths
SOURCE_DATA_DIR = "scripts/input_data"
solar_time_series_da = joinpath(SOURCE_DATA_DIR, "Solar", "DA_time_series_files")
solar_time_series_ha = joinpath(SOURCE_DATA_DIR, "Solar", "HA_time_series_files")
solar_time_series_rt = joinpath(SOURCE_DATA_DIR, "Solar", "RT_time_series_files")

# Choose a common file
test_file = "Angelina Solar.h5"

println("="^80)
println("DETAILED H5 FILE STRUCTURE INSPECTION")
println("="^80)
println()

# Inspect DA file
println("📅 DAY-AHEAD FILE")
println("-"^80)
da_path = joinpath(solar_time_series_da, test_file)
h5open(da_path, "r") do file
    println("All keys/datasets in file: ", collect(keys(file)))
    
    # Check each key
    for key in keys(file)
        obj = file[key]
        println("\nKey: '$key'")
        println("  Type: $(typeof(obj))")
        if obj isa HDF5.Dataset
            println("  Shape: $(size(obj))")
            println("  Datatype: $(HDF5.get_jl_type(obj))")
            
            # Read and show sample
            data = read(obj)
            if ndims(data) == 3
                println("  3D Array: $(size(data, 1)) × $(size(data, 2)) × $(size(data, 3))")
            elseif ndims(data) == 2
                println("  2D Array: $(size(data, 1)) × $(size(data, 2))")
            elseif ndims(data) == 1
                println("  1D Array: $(size(data, 1)) elements")
                if length(data) <= 10
                    println("  Values: $data")
                else
                    println("  First 10 values: $(data[1:10])")
                end
            end
        end
    end
end
println()

# Inspect HA file
println("⏰ HOUR-AHEAD FILE")
println("-"^80)
ha_path = joinpath(solar_time_series_ha, test_file)
h5open(ha_path, "r") do file
    println("All keys/datasets in file: ", collect(keys(file)))
    
    for key in keys(file)
        obj = file[key]
        println("\nKey: '$key'")
        println("  Type: $(typeof(obj))")
        if obj isa HDF5.Dataset
            println("  Shape: $(size(obj))")
            println("  Datatype: $(HDF5.get_jl_type(obj))")
            
            # Check for attributes
            attrs = HDF5.attributes(obj)
            if !isempty(attrs)
                println("  Attributes:")
                for attr_name in keys(attrs)
                    attr_val = read(attrs[attr_name])
                    println("    $attr_name: $attr_val")
                end
            end
            
            data = read(obj)
            if ndims(data) == 3
                println("  3D Array: $(size(data, 1)) × $(size(data, 2)) × $(size(data, 3))")
            elseif ndims(data) == 2
                println("  2D Array: $(size(data, 1)) × $(size(data, 2))")
            elseif ndims(data) == 1
                println("  1D Array: $(size(data, 1))")
            end
        end
    end
end
println()

# Inspect RT file
println("⚡ REAL-TIME FILE")
println("-"^80)
rt_path = joinpath(solar_time_series_rt, test_file)
h5open(rt_path, "r") do file
    println("All keys/datasets in file: ", collect(keys(file)))
    
    for key in keys(file)
        obj = file[key]
        println("\nKey: '$key'")
        println("  Type: $(typeof(obj))")
        if obj isa HDF5.Dataset
            println("  Shape: $(size(obj))")
            println("  Datatype: $(HDF5.get_jl_type(obj))")
            
            # Check for attributes
            attrs = HDF5.attributes(obj)
            if !isempty(attrs)
                println("  Attributes:")
                for attr_name in keys(attrs)
                    attr_val = read(attrs[attr_name])
                    println("    $attr_name: $attr_val")
                end
            end
            
            data = read(obj)
            if ndims(data) == 3
                println("  3D Array: $(size(data, 1)) × $(size(data, 2)) × $(size(data, 3))")
            elseif ndims(data) == 2
                println("  2D Array: $(size(data, 1)) × $(size(data, 2))")
            elseif ndims(data) == 1
                println("  1D Array: $(size(data, 1))")
            end
        end
    end
end
println()

# Now let's check what the code actually uses
println("="^80)
println("HOW THE CODE USES THIS DATA")
println("="^80)
println()

println("From make_real_time_data.jl line 106:")
println("  power_output = read(file, \"Power\")[:, :, 50]")
println("  → This reads 3D array and extracts ONLY scenario/member 50")
println("  → So the 3rd dimension IS scenarios/ensemble members")
println()

println("Let me verify by checking if different scenarios have different values...")
println()

# Check DA scenarios
h5open(da_path, "r") do file
    key = haskey(file, "Power") ? "Power" : "values"
    data = read(file, key)
    
    if ndims(data) == 3 && size(data, 3) > 1
        println("DA File - Comparing scenarios at Day 1, Hour 12:")
        for s in 1:min(5, size(data, 3))
            println("  Scenario $s: $(round(data[1, 12, s], digits=4))")
        end
        println("  → Different values = YES, these ARE scenarios")
    end
end
println()

# Check HA scenarios
h5open(ha_path, "r") do file
    key = haskey(file, "Power") ? "Power" : "values"
    data = read(file, key)
    
    if ndims(data) == 3 && size(data, 3) > 1
        println("HA File - Comparing scenarios at Hour 1, Interval 6:")
        for s in 1:min(5, size(data, 3))
            println("  Scenario $s: $(round(data[1, 6, s], digits=4))")
        end
        println("  → Different values = YES, these ARE scenarios")
    end
end
println()

# Check RT scenarios
h5open(rt_path, "r") do file
    key = haskey(file, "Power") ? "Power" : "values"
    data = read(file, key)
    
    if ndims(data) == 3 && size(data, 3) > 1
        println("RT File - Checking if scenario 50 is special:")
        println("  Total scenarios: $(size(data, 3))")
        println("  Comparing scenarios at Time 100, Point 6:")
        for s in [1, 25, 49, 50, 51]
            if s <= size(data, 3)
                println("  Scenario $s: $(round(data[100, 6, s], digits=4))")
            end
        end
        println()
        println("  → The code uses [:, :, 50] specifically")
        println("  → This might be 'truth' or 'actual' realization")
        println("  → Other scenarios (1-49, 51+) might be ensemble forecasts")
    end
end
println()

println("="^80)
