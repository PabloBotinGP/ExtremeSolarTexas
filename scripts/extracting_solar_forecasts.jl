using JSON3
using JSON
using HDF5
using TimeSeries
using PowerSystems
using Dates

json_data = open("scripts/input_data/Solar/HA_time_series_files/HA_sys_UC_experiment.json", "r") do io
    data = JSON3.read(io)
    return data
end

h5data = h5open("scripts/input_data/Solar/HA_time_series_files/HA_sys_UC_experiment_time_series_storage.h5", "r") do file
    # In HDF5, data is organized into datasets and groups.
    # This is a basic example that attempts to load all top-level datasets and groups into a dictionary.
    # You might need to customize this part depending on the structure of your HDF5 file.

    loaded_data = Dict{String, Any}()
    for name in keys(file) # Iterate through top-level names (datasets and groups)
        try
            loaded_data[name] = read(file[name]) # Read the data associated with each name
        catch e
            println("Warning: Could not read dataset or group '$name'. Skipping.")
            println("Error details: $e")
        end
    end
    return loaded_data
end

ts_assignment = Dict{String, Any}()
for (ix, c) in enumerate(json_data[:data][:components])
    if haskey(c, :prime_mover_type) && c[:prime_mover_type] == "PVe"
        try
            ts_uuid = c[:time_series_container][1]
            ts_uuid = c[:time_series_container][1]["time_series_uuid"]["value"]
            ts_resolution = Minute(c[:time_series_container][1]["resolution"]["value"])
            ts_interval = Millisecond(c[:time_series_container][1]["interval"]["value"])
            ts_horizon = c[:time_series_container][1]["horizon"]
            initial_date = DateTime(c[:time_series_container][1]["initial_timestamp"])
            raw_ts_data = h5data["time_series"][ts_uuid]["data"]
            forecast_ts = Dict{Dates.DateTime, TimeSeries.TimeArray}()
            for col in 1:size(raw_ts_data)[2]
                forecast_ts[initial_date] = TimeArray(
                collect(range(initial_date, step = ts_resolution, length = ts_horizon)),
                raw_ts_data[:, col]
                )
                initial_date += ts_interval
            end
            ts_assignment[c[:name]] = Deterministic(
                "max_active_power",
                forecast_ts;
                scaling_factor_multiplier = get_max_active_power
            )
        catch e
            #@error "failed making $(c[:name])"
        end
    end
end

