using PowerSystems
const PSY = PowerSystems

include("file_pointers.jl")
include("system_build_functions.jl")
include("manual_data_entries.jl")

sys_base = System("intermediate_sys_w_services.json")
# sys_base = deepcopy(system)
clear_time_series!(sys_base)
PSY.IS.assign_new_uuid!(sys_base)
set_units_base_system!(sys_base, "SYSTEM_BASE")

####################################### Load Time Series ###################################
h5open(perfect_load_time_series_realtime, "r") do file
    for area in get_components(Area, sys_base)
        hour_ahead_forecast = Dict{Dates.DateTime, Vector{Float64}}()
        @show group_name = get_name(area)
        loads = get_components(x -> get_area(get_bus(x)) == area, PowerLoad, sys_base)
        peak_area_load = sum(get_max_active_power.(loads))
        #@assert get_peak_active_power(area) == peak_area_load
        full_table = read(file, group_name)
        for i in 22:-1:0
            full_table[105120 - i, :] = full_table[105120 - 23, :]
        end
        @assert !all(isnan.(full_table))
        for ix in 1:8760
            ix_ = 1 + (ix - 1) * 12
            hour_ahead_forecast[initial_time + (ix - 1) * hour_ahead_interval] =
                full_table[ix_, :] ./ (peak_area_load*get_base_power(sys_base))
        end
        forecast_data = Deterministic(
            name = "max_active_power",
            resolution = hour_ahead_resolution,
            data = hour_ahead_forecast,
            scaling_factor_multiplier = get_max_active_power
        )
        add_time_series!(sys_base, vcat(collect(loads), area), forecast_data)
    end
end

####################################### Hydro Time Series ##################################
h5open(hydro_time_series_ha, "r") do file
    for gen in get_components(HydroGen, sys_base)
        set_available!(gen, true)
        day_ahead_forecast = Dict{Dates.DateTime, Vector{Float64}}()
        bus_name = get_name(get_bus(gen))
        full_table = read(file, bus_name)
        for ix in 1:size(full_table)[2]
            day_ahead_forecast[initial_time + (ix - 1) * hour_ahead_interval] =
                full_table[:, ix]
        end
        forecast_data = Deterministic(
            name = "max_active_power",
            resolution = Minute(5),
            data = day_ahead_forecast,
            scaling_factor_multiplier = get_max_active_power
        )
        add_time_series!(sys_base, gen, forecast_data)
        ap = get_active_power(gen)
        p_lims_min = get_active_power_limits(gen).min
        if ap <= p_lims_min
            set_active_power!(gen, ap)
        end
        set_reactive_power!(gen, 0.0)
    end
end

####################################### Wind Time Series ##################################
h5open(wind_time_series_ha, "r") do file
    for (k, v) in area_number_wind_map
        area = get_component(Area, sys_base, k)
        day_ahead_wind_forecast = Dict{Dates.DateTime, Vector{Float64}}()
        full_table = max.(0.0, read(file, v))
        for ix in 1:size(full_table)[2]
            day_ahead_wind_forecast[initial_time + (ix - 1) * hour_ahead_interval] =
                full_table[:, ix]
        end
        forecast_data = Deterministic(
            name = "max_active_power",
            resolution = Minute(5),
            data = day_ahead_wind_forecast,
            scaling_factor_multiplier = get_max_active_power
        )
        renewables_in_area = make_selector(RenewableGen, typeof(area), get_name(area))
        wind_gens = get_components(x -> get_prime_mover_type(x) == PrimeMovers.WT, renewables_in_area, sys_base)
        add_time_series!(sys_base, wind_gens, forecast_data)
    end
end

################# Reserve Requirements Time Series ################################
regup_reserve = CSV.read(reg_up_reserve_2016, DataFrame)
regdn_reserve = CSV.read(reg_dn_reserve_2016, DataFrame)
spin = CSV.read(spin_reserve, DataFrame)
nonspin = CSV.read(nonspin_reserve_2016, DataFrame)

regup_reserve = CSV.read(reg_up_reserve_2016, DataFrame)
regdn_reserve = CSV.read(reg_dn_reserve_2016, DataFrame)
spin = CSV.read(spin_reserve, DataFrame)
nonspin_adj_solar = CSV.read(nonspin_adjustment_solar, DataFrame)
regup_reserve_adj_solar = CSV.read(reg_up_adjustment_solar, DataFrame)
regdn_reserve_adj_solar = CSV.read(reg_dn_adjustment_solar, DataFrame)

date_range = range(DateTime("2018-01-01T00:00:00"), step = Hour(1), length = day_count * 25)

regup_reserve_ts = Vector{Float64}(undef, day_count * 25)
regdn_reserve_ts = Vector{Float64}(undef, day_count * 25)
spin_ts = Vector{Float64}(undef, day_count * 25)
nonspin_ts = Vector{Float64}(undef, day_count * 25)

solar_gens = get_components(x -> get_prime_mover_type(x) == PrimeMovers.PVe,
            RenewableGen,
            sys_base
            
        )

total_solar = sum(get_max_active_power.(solar_gens))*0.1 # total in GW.

for (ix, datetime) in enumerate(date_range)
    regup_reserve_ts[ix] = regup_reserve[hour(datetime) + 1, month(datetime) + 1] + regup_reserve_adj_solar[hour(datetime) + 1, month(datetime) + 1].*total_solar
    regdn_reserve_ts[ix] = regdn_reserve[hour(datetime) + 1, month(datetime) + 1] + regdn_reserve_adj_solar[hour(datetime) + 1, month(datetime) + 1].*total_solar
    spin_ts[ix] = spin[hour(datetime) + 1, month(datetime) + 1]
    nonspin_ts[ix] = nonspin[hour(datetime) + 1, month(datetime) + 1] + nonspin_adj_solar[hour(datetime) + 1, month(datetime) + 1].*total_solar
end

reserve_map = Dict(
    ("REG_UP", VariableReserve{ReserveUp}) => regup_reserve_ts,
    ("SPIN", VariableReserve{ReserveUp}) => spin_ts,
    ("REG_DN", VariableReserve{ReserveDown}) => regdn_reserve_ts,
    ("NONSPIN", VariableReserveNonSpinning) => nonspin_ts,
)

for ((name, T), ts) in reserve_map
    peak = maximum(ts)
    hour_ahead_forecast = Dict{Dates.DateTime, Vector{Float64}}()
    for current_ix in 1:(day_count * 24)
        forecast = vcat(
            ts[current_ix] * ones(12),
            ts[current_ix + 1] * ones(12),
        )
        @assert !all(isnan.(forecast))
        @assert length(forecast) == hour_ahead_horizon
        hour_ahead_forecast[initial_time + (current_ix - 1) * hour_ahead_interval] =
            forecast ./ peak
    end
    forecast_data = Deterministic(
        name = "requirement",
        resolution = hour_ahead_resolution,
        data = hour_ahead_forecast,
        scaling_factor_multiplier = get_requirement
    )
    res = get_component(T, sys_base, name)
    set_requirement!(res, peak / 100)
    add_time_series!(sys_base, res, forecast_data)
end

sys_HA = deepcopy(sys_base)

####################################### Solar Time Series ##################################

# Original quantile data approach - NOT USING because quantile data files are not available
# We extracted the hour-ahead data from the old system and are reusing it here with individual H5 files

# Individual H5 files approach - using extracted data from old system
solar_time_series_ha = joinpath(SOURCE_DATA_DIR, "Solar", "HA_time_series_files")
file_names = readdir(solar_time_series_ha)

for gen in get_components(x -> get_prime_mover_type(x) == PrimeMovers.PVe, RenewableDispatch, sys_HA)
    plant_name = get_name(gen)
    
    # Handle naming conventions for generated plants
    if occursin(r"^gen", plant_name)
        _, number_ = split(plant_name, '-')
        number = parse(Int, number_) - 1
        file_name = "solar$(number).h5"
    else
        file_name = "$(plant_name).h5"
    end
    
    if file_name ∉ file_names
        @warn "File not found for solar plant: $(plant_name) (looking for $(file_name))"
        continue
    end
    
    # Read power output from H5 file (2D array: [time_windows, horizon_points])
    # HA files are 2D, not 3D like DA files
    power_output = h5open(joinpath(solar_time_series_ha, file_name), "r") do file
        return read(file, "Power")
    end
    
    # Calculate peak power from the 2D array
    peak_power = maximum(power_output)
    set_rating!(gen, peak_power)
    
    # Build hour-ahead forecasts from 2D data
    hour_ahead_forecast = Dict{Dates.DateTime, Vector{Float64}}()
    num_windows = min(size(power_output, 1), day_count * 24)  # Limit to day_count * 24 (8760) to match system
    
    for ix in 1:num_windows
        # Extract forecast data for this time window (no scenario dimension)
        normalized_power = power_output[ix, :]
        hour_ahead_forecast[initial_time + (ix - 1) * hour_ahead_interval] = normalized_power
    end
    
    forecast_data = Deterministic(
        name = "max_active_power",
        data = hour_ahead_forecast,
        resolution = hour_ahead_resolution,
        scaling_factor_multiplier = nothing
    )
    add_time_series!(sys_HA, gen, forecast_data)
end

to_json(sys_HA, "HA_sys.json", force=true)
