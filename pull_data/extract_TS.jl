# This script extracts deterministic time-series (e.g. max_active_power) for PV
# generators stored in an old PowerSystems System file (`RT_sys.json`) and
# writes each component's timeseries into a separate HDF5 file named after the
# component. Output files are placed in the `Solar_fromOldSys` directory.

# Activate environment
import Pkg as pkg
pkg.activate(@__DIR__)
# Load packages
using PowerSystems
using HDF5
using Dates

# Load system
# sys = System("RT_sys.json")
sys = System("HA_sys_UC_experiment.json")

# Helper to sanitize filenames while keeping them human-friendly (preserve spaces)
function filename_safe(s::AbstractString; maxlen::Int=80)
    # Replace characters invalid in filenames with underscore
    clean = replace(s, r"[\/\:\*\?\"<>\|]" => "_")
    # collapse multiple spaces
    clean = replace(clean, r"\s+" => " ")
    clean = strip(clean)
    if isempty(clean)
        # fallback to hashed name
        clean = "pv_" * string(abs(hash(s)))
    end
    if length(clean) > maxlen
        clean = first(clean, maxlen)
    end
    return clean
end

# Extract a friendly human name from the generator object
function friendly_gen_name(gen)
    # Try get_id(gen) first
    try
        id = get_id(gen)
        s = string(id)
        s = strip(s)
        if !isempty(s)
            return s
        end
    catch
        # ignore and fallback
    end
    # Fallback: parse the string representation like "RenewableDispatch(Name, true, Bus(... )"
    s = string(gen)
    m = match(r"^[^(]*\(\s*([^,\)]+)", s)
    if m !== nothing && length(m.captures) >= 1
        name = strip(m.captures[1])
        if !isempty(name)
            return name
        end
    end
    # Last resort: scrub the string and take a prefix
    s2 = replace(s, r"^RenewableDispatch_?" => "")
    s2 = replace(s2, r"[(),]" => " ")
    s2 = replace(s2, r"\s+" => " ")
    s2 = strip(s2)
    if isempty(s2)
        return "pv_" * string(abs(hash(s)))
    end
    return first(s2, 60)
end

# Directory to store output HDF5 files
outdir = joinpath(@__DIR__, "HA_time_series_files")
if isdir(outdir)
    # warn if directory exists and contains files; do not delete automatically
    existing = readdir(outdir)
    if !isempty(existing)
        println("Warning: $outdir already exists and contains $(length(existing)) files.\nIf you want a fresh run, please remove that folder before running this script.\nThis run will overwrite files with the same friendly names.")
    end
else
    mkpath(outdir)
end

# Collect PV generators (prime mover PVe under RenewableDispatch)
pv_gens = collect(get_components(x-> get_prime_mover(x) == PrimeMovers.PVe, RenewableDispatch, sys))

println("Found $(length(pv_gens)) PV generator components. Writing to: $outdir")

# manifest rows: (original, friendly, filename)
manifest_rows = Vector{Tuple{String,String,String}}()

for gen in pv_gens
    orig_repr = string(gen)
    gen_name = friendly_gen_name(gen)
    println("Processing: ", gen_name)
    # Attempt to get the deterministic time series 'max_active_power'
    local_ts = nothing
    try
        local_ts = get_time_series(Deterministic, gen, "max_active_power")
    catch e
        @warn "Could not read time series for $gen_name: $e"
        continue
    end

    if local_ts === nothing
        @warn "Time series for $gen_name is empty/nothing — skipping"
        continue
    end

    data = local_ts.data
    # Convert to arrays suitable for HDF5
    keys_vec = collect(keys(data))
    vals_vec = collect(values(data))

    times = string.(keys_vec)

    if isempty(vals_vec)
        values_mat = Array{Float64}(undef, 0, 0)
    else
        ncols = length(vals_vec[1])
        nrows = length(vals_vec)
        values_mat = Array{Float64}(undef, nrows, ncols)
        for (i, v) in enumerate(vals_vec)
            values_mat[i, :] = Float64.(v)
        end
    end

    # create a user-friendly filename, ensure uniqueness in the output dir
    basefname = filename_safe(gen_name)
    fname = basefname * ".h5"
    outpath = joinpath(outdir, fname)
    k = 1
    while isfile(outpath)
        # if file exists, append numeric suffix
        fname = string(basefname, " (", k, ").h5")
        outpath = joinpath(outdir, fname)
        k += 1
    end
    h5open(outpath, "w") do file
        write(file, "times", times)
        write(file, "Power", values_mat)
    end
    println("Wrote: ", outpath, " (", size(times,1), " timestamps, ", size(values_mat,2), " cols)")
    push!(manifest_rows, (orig_repr, gen_name, fname))
end

# Write manifest mapping originals to friendly filenames
manifest_path = joinpath(outdir, "rename_manifest.csv")
open(manifest_path, "w") do io
    println(io, "original,friendly,filename")
    for (orig, friendly, fname) in manifest_rows
        # simple CSV quoting
            o = replace(orig, '"' => "\"\"")
            f = replace(friendly, '"' => "\"\"")
            println(io, "\"" * o * "\",\"" * f * "\",\"" * fname * "\"")
    end
end
println("Wrote manifest: ", manifest_path)