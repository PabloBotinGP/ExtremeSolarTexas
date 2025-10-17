using PowerSystems
const PSY = PowerSystems

include("file_pointers.jl")
include("system_build_functions.jl")
include("manual_data_entries.jl")

sys_base = System("intermediate_sys_w_services.json")
clear_time_series!(sys_base)
PSY.IS.assign_new_uuid!(sys_base)
set_units_base_system!(sys_base, "SYSTEM_BASE")

####################################### Load Time Series ###################################
h5open(perfect_load_time_series_realtime, "r") do file
    for area in get_components(Area, sys_base)
        println(area)
        real_time_load_forecast = Dict{Dates.DateTime, Vector{Float64}}()
        @show group_name = get_name(area)
        loads = get_components( x -> get_area(get_bus(x)) == area, PowerLoad, sys_base)
        peak_area_load = sum(get_max_active_power.(loads))
        #@assert get_peak_active_power(area) == peak_area_load
        full_table = read(file, group_name)
        for ix in 1:size(full_table)[1]
            real_time_load_forecast[initial_time + (ix - 1) * real_time_interval] =
                full_table[ix, :] ./(peak_area_load*get_base_power(sys_base))
        end
        forecast_data = Deterministic(
            name = "max_active_power",
            resolution = real_time_resolution,
            data = real_time_load_forecast,
            scaling_factor_multiplier = get_max_active_power
        )
        add_time_series!(sys_base, vcat(collect(loads), area), forecast_data)
    end
end

####################################### Hydro Time Series ##################################
h5open(hydro_time_series_rt, "r") do file
    for gen in get_components(HydroGen, sys_base)
        set_available!(gen, true)
        day_ahead_forecast = Dict{Dates.DateTime, Vector{Float64}}()
        bus_name = get_name(get_bus(gen))
        full_table = read(file, bus_name)
        gen_peak = maximum(full_table)
        @assert gen_peak > 0
        for ix in 1:size(full_table)[2]
            day_ahead_forecast[initial_time + (ix - 1) * real_time_interval] =
                full_table[:, ix] ./ gen_peak
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
h5open(wind_time_series_rt, "r") do file
    for (k, v) in area_number_wind_map
        area = get_component(Area, sys_base, k)
        day_ahead_wind_forecast = Dict{Dates.DateTime, Vector{Float64}}()
        full_table = max.(0.0, read(file, v))
        area_peak_wind = maximum(full_table)
        println(area)
        set_peak_active_power!(area, area_peak_wind)
        for ix in 1:size(full_table)[2]
            day_ahead_wind_forecast[initial_time + (ix - 1) * real_time_interval] =
                full_table[:, ix] ./ area_peak_wind
        end
        forecast_data = Deterministic(
            name = "max_active_power",
            resolution = Minute(5),
            data = day_ahead_wind_forecast,
            scaling_factor_multiplier = get_max_active_power
        )
        wind_gens = get_components(x -> (get_area(get_bus(x)) == area && get_prime_mover_type(x) == PrimeMovers.WT),
            RenewableDispatch,
            sys_base)
        add_time_series!(sys_base, wind_gens, forecast_data)
    end
end

####################################### Solar Time Series ##################################
# NOTE: Old hardcoded path no longer used - directory not found on this system
# file_names = readdir("/Volumes/VM_WIN/Quantile data")
# power_output = h5open(joinpath("/Volumes/VM_WIN/Quantile data", file_name), "r") do file

file_names = readdir(solar_time_series_rt)
for gen in get_components(x -> get_prime_mover_type(x) == PrimeMovers.PVe, RenewableGen, sys_base)
    plant_name = get_name(gen)
    if occursin(r"^gen", plant_name)
        _, number_ = split(plant_name, '-')
        number = parse(Int, number_) - 1
        file_name = "solar$(number).h5"
    else
        file_name = "$(plant_name).h5"
    end
    if file_name ∉ file_names
        @show plant_name
    end

    # Read power output from H5 file (2D array: [time_steps, horizon_points])
    # RT files are 2D, not 3D like DA files
    power_output = h5open(joinpath(solar_time_series_rt, file_name), "r") do file
        return read(file, "Power")
    end
    # NOTE: Original code appended last 60 rows, creating 105180 total
    # System expects exactly 105120 (365 days * 24 hours * 12 five-min intervals)
    # power_output = vcat(power_output, power_output[(end - 59):end, :])

    peak_power = maximum(power_output)
    @assert peak_power > 0
    @assert get_base_power(gen) <= get_base_power(gen)
    set_rating!(gen, peak_power / get_base_power(gen))
    normalized_power = power_output ./ maximum(power_output)
    real_time_forecast = Dict{Dates.DateTime, Vector{Float64}}()
    for ix in 1:size(power_output)[1]
        real_time_forecast[initial_time + (ix - 1) * real_time_interval] =
            normalized_power[ix, :]
    end
    forecast_data = Deterministic(
        name = "max_active_power",
        resolution = real_time_resolution,
        data = real_time_forecast,
        scaling_factor_multiplier = get_max_active_power
    )
    add_time_series!(sys_base, gen, forecast_data)
end

for g in get_components(RenewableGen, sys_base)
    @assert has_time_series(g)
end

################# Reserve Requirements Time Series ################################
regup_reserve = CSV.read(reg_up_reserve_2016, DataFrame)
regdn_reserve = CSV.read(reg_dn_reserve_2016, DataFrame)
spin = CSV.read(spin_reserve, DataFrame)
nonspin = CSV.read(nonspin_reserve_2016, DataFrame)

date_range =
    range(DateTime("2018-01-01T00:00:00"), step = Minute(5), length = day_count * 25 * 12)

regup_reserve_ts = Vector{Float64}(undef, day_count * 25 * 12)
regdn_reserve_ts = Vector{Float64}(undef, day_count * 25 * 12)
spin_ts = Vector{Float64}(undef, day_count * 25 * 12)
nonspin_ts = Vector{Float64}(undef, day_count * 25 * 12)

for (ix, datetime) in enumerate(date_range)
    regup_reserve_ts[ix] = regup_reserve[hour(datetime) + 1, month(datetime) + 1]
    regdn_reserve_ts[ix] = regdn_reserve[hour(datetime) + 1, month(datetime) + 1]
    spin_ts[ix] = spin[hour(datetime) + 1, month(datetime) + 1]
    nonspin_ts[ix] = nonspin[hour(datetime) + 1, month(datetime) + 1]
end

reserve_map = Dict(
    ("REG_UP", VariableReserve{ReserveUp}) => regup_reserve_ts,
    ("SPIN", VariableReserve{ReserveUp}) => spin_ts,
    ("REG_DN", VariableReserve{ReserveDown}) => regdn_reserve_ts,
    ("NONSPIN", VariableReserveNonSpinning) => nonspin_ts,
)

for ((name, T), ts) in reserve_map
    peak = maximum(ts)
    real_time_forecast = Dict{Dates.DateTime, Vector{Float64}}()
    for current_ix in 1:(day_count * 24 * 12)
        forecast = regup_reserve_ts[current_ix:(current_ix + real_time_horizon - 1)]
        @assert !all(isnan.(forecast))
        @assert length(forecast) == real_time_horizon
        real_time_forecast[initial_time + (current_ix - 1) * real_time_interval] =
            forecast ./ peak
    end
    forecast_data = Deterministic(
        name = "requirement",
        resolution = real_time_resolution,
        data = real_time_forecast,
        scaling_factor_multiplier = get_requirement
    )
    res = get_component(T, sys_base, name)
    set_requirement!(res, peak / 100)
    add_time_series!(sys_base, res, forecast_data)
end

to_json(sys_base, "RT_sys.json", force = true)
