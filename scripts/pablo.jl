# =====================
# Package imports & dependencies
# =====================
include("file_pointers.jl")
include("system_build_functions.jl")
include("manual_data_entries.jl")
include("system_build_functions.jl")

println("Modules included")

# Control verbosity both in console and output file. 
# Set to 'Info' mode. Constant defined inside Julia Logging module.
# No need to import Logging? 
configure_logging(file_level = Logging.Info, console_level = Logging.Info)

println("Configured logging. \n")

# =====================
# System setup & initialization
# =====================
sys = System(TAMU_matpower_file)
# System initialized using ACTIVSg2000.m file, that contains the definition of many system components (buses and geenerators)
# It is the representation of a synthetic grid (not real) created for a data research project in 2018. 
println("System created")

# Attach x,y coordinates from a shapefile to matching buses in the system.
# In other words: it links buses in your network model to their spatial positions on a map.
add_bus_coords(sys, TAMU_shp_file) # Where is this function defined? 
println("Bus coordinates added")
# write_lines_geo_data(sys, "line_coords_original") # Originally commented. 
# This function exports generator data tied to bus coordinates into a CSV.
# The coordinates are written in WKT POINT format, which makes the output GIS-ready.  
write_gen_buses_geo_data(sys, "bus_gens_coords_original")
println("Generator coordinates written to CSV") 
# LAST LINE = 3205. Defined in Main. ???
get_ext(sys)["last_line"] = LAST_LINE
# Compute and fill missing characteristic impedance (Zc) values.
# How? Estimate based on other lines in the system? 
# Why would this data be incomplete if we are talking about a synthetic grid?
complete_lines_characteristic_impedance!(line_params, sys)
println("Completed missing line characteristic impedance values")

# Load solar and hydro data
solar = CSV.read(solar_metadata, DataFrames.DataFrame) # solar/plant_metadata.csv
hydro = CSV.read(hydro_mapping, DataFrames.DataFrame) # Hydropower/hydro_mapping.csv
println("Solar and hydro data loaded")

# Overwritte dictionary. Why? Is this here for easier editing later? 
get_ext(sys)["added_power"] = 0.0

# =====================
# Increase Q limits on all generators. Originally commented.
# =====================
# thermal_gens = get_components(ThermalStandard, sys)
# for i in thermal_gens
#     set_reactive_power_limits!(i, (-5,5))
# end
# ren_gens = get_components(RenewableDispatch, sys)
# for i in ren_gens
#     set_reactive_power_limits!(i, (-5,5))
# end
# hydro_gens = get_components(HydroDispatch, sys)
# for i in hydro_gens
#     set_reactive_power_limits!(i, (-5,5))
# end

# =====================
# Add new PV and Hydro generators.
# =====================
# add_line!(sys, (500, "PANHANDLE 2 0", "FRYE_SOLAR 0", 112))
# Adds a new line to the system; 
# If buses not found, it creates new ones. Is this legit? 
# 500kV? from bus PANHANDLE 2 0 to bus FRYE_SOLAR 0 with a length of 112 miles? 
# println("Added PANHANDLE 2 - FRYE_SOLAR line")

# add_line!(sys, (500, "FRYE_SOLAR 0", "LAMESA 1", 161))
# add_transformer!(sys, (500, 161, "FRYE_SOLAR 0", "FRYE_SOLAR 1"))
# add_pv_plant!(sys, ("Frye Solar", "FRYE_SOLAR 0"))
# add_hydro_plant!(sys, ("Marshall Ford 1", "MARSHALL FORD 1"))


for r in eachrow(solar)
    plant = get_component(RenewableDispatch, sys, r.site_ids)
    isnothing(plant) && continue
    bus = get_bus(plant)
    if !haskey(get_ext(bus), "x") && !haskey(get_ext(bus), "y")
        get_ext(bus)["x"] = r.longitude
        get_ext(bus)["y"] = r.latitude
    end
end

for t in get_components(TapTransformer, sys)
    arc = get_arc(t)
    from_bus = get_from(arc)
    to_bus = get_to(arc)
    if !haskey(get_ext(from_bus), "x") && !haskey(get_ext(to_bus), "y")
        @show get_name(t)
        continue
    end
    if !haskey(get_ext(from_bus), "x")
        get_ext(from_bus)["x"] = get_ext(to_bus)["x"]
        get_ext(from_bus)["y"] = get_ext(to_bus)["y"]
    end
    if !haskey(get_ext(to_bus), "x")
        get_ext(to_bus)["x"] = get_ext(from_bus)["x"]
        get_ext(to_bus)["y"] = get_ext(from_bus)["y"]
    end
end

# Renaming of areas
for area_no in 1:8
    area_number_as_text = string(area_no)
    area = get_component(Area, sys, area_number_as_text)
    group_name = area_name_number_map[area_number_as_text]
    set_name!(sys, area, group_name)
    area.internal.ext = Dict("area_number_as_text"=> area_number_as_text)
end


# Final commands 
to_json(sys, "intermediate_sys.json", force = true)
sys = System("intermediate_sys.json")

include("load_processing.jl")
include("wind_processing.jl")
include("hydro_processing.jl")
to_json(sys, "pre_thermal_sys.json", force = true)

sys = System("pre_thermal_sys.json")
include("incrementalpiecewise.jl")
include("thermal_processing.jl")


configure_logging(file_level = Logging.Info, console_level = Logging.Info)


to_json(sys, "intermediate_sys.json", force = true)
to_json(sys, "post_thermal_sys.json", force = true)

# include("add_services.jl")

write_lines_geo_data(sys, "line_coords_modified")
write_gen_buses_geo_data(sys, "bus_gens_coords_modified")

finalize_system(sys) 

include("make_hour_ahead_data.jl")
include("make_day_ahead_data.jl")

to_json(sys_DA, "sys_da.json", force = true)
to_json(sys_base, "sys_rt.json", force = true)

# Everything except for those documented errors seems to be working fine.
# After figuring out how to solve this errors which would be the next step? 
# A) Building the system including the real time data too? 
# B) Solving the PowerFlow? By uncommenting res commands? 