# Rename messy HDF5 files in Solar_fromOldSys to friendly names.
# Usage: run from project folder: julia --project=. rename_solar_files.jl

using Printf
using CSV
using DataFrames
using Dates

basedir = joinpath(@__DIR__, "Solar_fromOldSys")
if !isdir(basedir)
    error("Directory not found: $basedir")
end

files = sort(readdir(basedir))
println("Found $(length(files)) files in $basedir")

# heuristics to extract friendly name from current filename
function friendly_name_from(filename::String)
    # remove extension
    name = replace(filename, r"\.h5$" => "")
    # remove common prefix like 'RenewableDispatch_'
    name = replace(name, r"^RenewableDispatch_" => "")
    # Remove parts after patterns like '_ true', '_ false', '_ tr', '_ tru', '_ Bus', '_ Bu', etc.
    name = replace(name, r"_\s*(true|false|tr|tru|t|Bus|Bu|B)\b.*$" => "")
    # Also cut trailing underscore-digit-hash patterns
    name = replace(name, r"_[0-9]{1,}\b.*$" => "")
    # Some names have multiple underscores where spaces should be
    name = replace(name, '_' => ' ')
    # Collapse multiple spaces
    name = replace(name, r"\s+" => " ")
    name = strip(name)
    # If empty fallback to original filename base
    if isempty(name)
        name = replace(filename, r"\.h5$" => "")
    end
    return name
end

mapping = String[]
rows = Vector{Dict{String,Any}}()
seen = Dict{String, Int}()

for f in files
    oldpath = joinpath(basedir, f)
    fnice = friendly_name_from(f)
    # ensure extension
    newname = fnice * ".h5"
    # if name already exists, append numeric suffix
    base = fnice
    i = get!(seen, base, 0)
    while isfile(joinpath(basedir, newname))
        i += 1
        newname = string(base, " (", i, ").h5")
    end
    seen[base] = i
    newpath = joinpath(basedir, newname)
    try
        mv(oldpath, newpath)
        push!(rows, Dict("old" => f, "new" => newname))
        println(@sprintf("Renamed: %-60s -> %s", f, newname))
    catch e
        @warn "Failed to rename $f -> $newname: $e"
    end
end

# Write manifest CSV
manifest = DataFrame(rows)
CSV.write(joinpath(basedir, "rename_manifest.csv"), manifest)
println("Wrote manifest: ", joinpath(basedir, "rename_manifest.csv"))
println("Done")
