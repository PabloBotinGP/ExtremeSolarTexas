# =====================================================================================
# EXTREME SOLAR TEXAS POWER SYSTEM BUILDER
# =====================================================================================
# This script transforms the base TAMU ACTIVSg2000 synthetic Texas grid into a 
# detailed renewable energy system with extensive solar, wind, and hydro additions
# for studying extreme solar penetration scenarios.
# =====================================================================================

# =====================================================================================
# SECTION 1: SETUP AND INITIALIZATION
# =====================================================================================
@info "Active environment: $(Base.active_project())"

using PowerFlows
include("file_pointers.jl")
include("system_build_functions.jl")
include("manual_data_entries.jl")
include("system_build_functions.jl")

configure_logging(file_level = Logging.Info, console_level = Logging.Info)

# Load base system and initialize
sys = System(TAMU_matpower_file)
# Fix HydroDispatch active power limits to prevent UC infeasibility
fix_hydro_dispatch_limits!(sys)
# Add coordinates to buses
add_bus_coords(sys, TAMU_shp_file)
# write_lines_geo_data(sys, "line_coords_original")
write_gen_buses_geo_data(sys, "bus_gens_coords_original")
get_ext(sys)["last_line"] = LAST_LINE
complete_lines_characteristic_impedance!(line_params, sys)

solar = CSV.read(solar_metadata, DataFrames.DataFrame)
hydro = CSV.read(hydro_mapping, DataFrames.DataFrame)

get_ext(sys)["added_power"] = 0.0

# =====================================================================================
# SECTION 2: MASSIVE SOLAR PLANT ADDITION (~200+ PLANTS)
# =====================================================================================
# Pattern for each solar installation:
# 1. Remove existing transmission lines (if needed)
# 2. Add new transmission lines at appropriate voltage levels
# 3. Add transformers for voltage conversion
# 4. Add the solar PV plant
# =====================================================================================

####### Add new PV ####
add_line!(sys, (500, "PANHANDLE 2 0", "FRYE_SOLAR 0", 112))
add_line!(sys, (500, "FRYE_SOLAR 0", "LAMESA 1", 161))
add_transformer!(sys, (500, 161, "FRYE_SOLAR 0", "FRYE_SOLAR 1"))
add_pv_plant!(sys, ("Frye Solar", "FRYE_SOLAR 0"))
# res = solve_powerflow(ACPowerFlow(check_reactive_power_limits = false), sys)
# check_pf_results(res) && solve_ac_powerflow!(sys, check_reactive_power_limits = false )

add_line!(sys, (500, "DAWN_SOLAR 0", "FRYE_SOLAR 0", 68))
add_line!(sys, (500, "FRYE_SOLAR 0", "ANDREWS 1", 240))
add_line!(sys, (500, "PANHANDLE 2 0", "DAWN_SOLAR 0", 160))
add_pv_plant!(sys, ("Dawn Solar", "DAWN_SOLAR 0"))
# res = solve_powerflow(ACPowerFlow(), sys)
# check_pf_results(res) && solve_ac_powerflow!(sys)
add_line!(sys, (161, "SILVERTON 0", "CASTRO_SOLAR 0", 70))
add_line!(sys, (161, "CASTRO_SOLAR 0", "NAZARETH_SOLAR 0", 7))
add_line!(sys, (161, "NAZARETH_SOLAR 0", "FRYE_SOLAR 1", 8))
add_pv_plant!(sys, ("Castro Solar", "CASTRO_SOLAR 0"))
add_pv_plant!(sys, ("Nazareth Solar", "NAZARETH_SOLAR 0"))
# res = solve_powerflow(ACPowerFlow(), sys)
# check_pf_results(res) && solve_ac_powerflow!(sys)
add_line!(sys, (500, "LAMESA 1", "EUNICE_SOLAR 0", 85))
add_transformer!(sys, (500, 230, "LAMESA 1", "LAMESA 0"))
add_line!(sys, (500, "RALLS 1 0", "JUNO_SOLAR", 130))
add_line!(sys, (500, "JUNO_SOLAR", "GREEN_HOLLY", 16))
add_line!(sys, (500, "GREEN_HOLLY", "STANTON 1", 9))
add_line!(sys, (500, "STANTON 1", "COLORADO CITY 1", 90))
add_transformer!(sys, (500, 230, "COLORADO CITY 1", "COLORADO CITY 0"))
add_transformer!(sys, (500, 115, "LAMESA 1", "LAMESA 0"))
add_transformer!(sys, (500, 155, "STANTON 1", "STANTON 0"))
add_pv_plant!(sys, ("Eunice Solar", "EUNICE_SOLAR 0"))
add_pv_plant!(sys, ("Flatland Solar", "COLORADO CITY 1"))
add_pv_plant!(sys, ("Juno Solar", "JUNO_SOLAR"))
add_pv_plant!(sys, ("Green Holly Solar", "GREEN_HOLLY"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_ralls = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 2097)  && get_to(get_arc(x))== get_bus(sys, 3096), Line, sys))
remove_component!(sys, line_ralls[1])
add_line!(sys, (230, "RALLS 1 1", "WAKE_SOLAR", 27))
add_line!(sys, (230, "WAKE_SOLAR", "FLUVANNA 2 0", 57))
add_pv_plant!(sys, ("Wake Solar", "WAKE_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_miami = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 2127)  && get_to(get_arc(x))== get_bus(sys, 5164), Line, sys))
remove_component!(sys, line_miami[1])
add_line!(sys, (500, "MIAMI 0", "MISAE_SOLAR 1 0", 156))
add_line!(sys, (500, "MISAE_SOLAR 1 0", "DENTON 1 0", 287))
add_transformer!(sys, (500, 230, "MISAE_SOLAR 1 0", "MISAE_SOLAR 1 1"))
add_pv_plant!(sys, ("Misae Solar", "MISAE_SOLAR 1 1"))
add_line!(sys, (230, "MISAE_SOLAR 2 0", "MISAE_SOLAR 1 1", 10))
add_pv_plant!(sys, ("Misae Solar II", "MISAE_SOLAR 2 0"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
#drop_arc!(sys, (2054, 2127)) - this line doesn't exist
add_line!(sys, (500, "MIAMI 0", "SHORTON 2", 162))
add_line!(sys, (500, "SHORTON 2", "WICHITA FALLS 1 0", 159))
add_pv_plant!(sys, ("Shorthorn 2 Solar", "SHORTON 2"))
add_pv_plant!(sys, ("Opal Solar", "SHORTON 2"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_transformer!(sys, (500, 230, "MCCAMEY 1 2", "MCCAMEY 1 1"))
add_line!(sys, (500, "MCCAMEY 1 2", "SAN ANTONIO 50 0", 395))
remove_component!(Line, sys, "ROSCOE 5 2-ODESSA 1 8-i_117")
add_line!(sys, (500, "ROSCOE 5 2", "CHARBRAY_SOLAR", 29))
add_line!(sys, (500, "CHARBRAY_SOLAR", "COLORADO CITY 1", 9))
add_line!(sys, (500, "COLORADO CITY 1", "ODESSA 1 8", 148))
add_pv_plant!(sys, ("Charbray Solar", "CHARBRAY_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (500, "COLORADO CITY 1", "SAN ANGELO 1 1", 100))
add_line!(sys, (500, "SAN ANGELO 1 1", "LEANDER 1 0", 255))
add_transformer!(sys, (500, 115, "SAN ANGELO 1 1", "SAN ANGELO 1 0"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_transformer!(sys, (160, 115, "EARLY 0", "EARLY 1"))
add_line!(sys, (115, "RADIAN_INCREASE 1", "EARLY 1", 10))
add_pv_plant!(sys, ("Radian Increase", "RADIAN_INCREASE 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_west_columbia = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 7203)  && get_to(get_arc(x))== get_bus(sys, 7313), Line, sys))
remove_component!(sys, line_west_columbia[1])
add_line!(sys, (230, "ANGLETON 0", "WESTORIA_SOLAR 1", 10))
add_line!(sys, (230, "WESTORIA_SOLAR 1", "WAGYU_SOLAR 1", 12))
add_line!(sys, (230, "WAGYU_SOLAR 1", "WEST COLUMBIA 1", 2))
add_transformer!(sys, (230, 115, "WEST COLUMBIA 1", "WEST COLUMBIA 0"))
add_pv_plant!(sys, ("Wagyu Solar", "WAGYU_SOLAR 1"))
add_pv_plant!(sys, ("Westoria Solar", "WESTORIA_SOLAR 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_pv_plant!(sys, ("Myrtle Solar", "ANGLETON 0"))
add_pv_plant!(sys, ("San Bernard Solar", "NEWGULF 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_mount_pleasant = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 8105)  && get_to(get_arc(x))== get_bus(sys, 8127), Line, sys))
safe_remove_component!(sys, line_mount_pleasant, "Mount Pleasant (8105-8127)")
line_dike = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 8066)  && get_to(get_arc(x))== get_bus(sys, 8093), Line, sys))
safe_remove_component!(sys, line_dike, "Dike (8066-8093)")
add_line!(sys, (230, "MOUNT PLEASANT 2 0", "HOPKINS 1", 15))
add_line!(sys, (230, "HOPKINS 1", "MOUNT PLEASANT 1 1", 15))
add_pv_plant!(sys, ("Hopkins", "HOPKINS 1"))
safe_remove_component!(sys, [get_component(FixedAdmittance, sys, "12")], "FixedAdmittance: 12")
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_mount_vernon = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 8142)  && get_to(get_arc(x))== get_bus(sys, 8106), Line, sys))
safe_remove_component!(sys, line_mount_vernon, "Mount Vernon (8142-8106)")
add_line!(sys, (230, "IMPACT_SOLAR", "MOUNT PLEASANT 1 1", 13))
add_line!(sys, (230, "MOUNT PLEASANT 2 0", "PINE_FOREST_SOLAR 1", 22))
add_line!(sys, (230, "PINE_FOREST_SOLAR 1", "MOUNT VERNON 1", 5))
add_transformer!(sys, (230, 115, "MOUNT VERNON 1", "MOUNT VERNON 0"))
add_pv_plant!(sys, ("Impact Solar", "IMPACT_SOLAR"))
add_pv_plant!(sys, ("Pine Forest Solar", "PINE_FOREST_SOLAR 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_pv_plant!(sys, ("Delilah Solar 1", "MOUNT PLEASANT 1 3"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_pv_plant!(sys, ("Arroyo Del Bisonte Solar", "THOMPSONS 1"))
add_pv_plant!(sys, ("Pitts Dudik Solar", "MILFORD 0"))
add_pv_plant!(sys, ("Zier Solar", "BRACKETTVILLE 1 1"))
add_pv_plant!(sys, ("Irony Solar", "BRACKETTVILLE 1 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (115, "SOLEMIO 1", "SULPHUR SPRINGS 0", 9))
add_pv_plant!(sys, ("Solemio", "SOLEMIO 1"))
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
# Substitute static compensator with PV plant
#remove_component!(sys, get_component(FixedAdmittance, sys, "12"))
add_pv_plant!(sys, ("Tri-County Solar", "ODESSA 1 10"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_pv_plant!(sys, ("Vision Solar", "LANCASTER 1 0"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_yoakum = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 6030)  && get_to(get_arc(x))== get_bus(sys, 7274), Line, sys))
remove_component!(sys, line_yoakum[1])
add_line!(sys, (230, "YOAKUM 0", "TULSITA_SOLAR 1", 45))
add_line!(sys, (230, "TULSITA_SOLAR 1", "VICTORIA 3 0", 12))
add_pv_plant!(sys, ("Tulsita Solar", "TULSITA_SOLAR 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
sys = deepcopy(sys)
line_cushing = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 8097)  && get_to(get_arc(x))== get_bus(sys, 8004), Line, sys))
remove_component!(sys, line_cushing[1])
add_line!(sys, (230, "CUSHING 1 0", "ANGELINA_SOLAR 1", 50))
add_line!(sys, (230, "ANGELINA_SOLAR 1", "LUFKIN 3 0", 6))
add_pv_plant!(sys, ("Angelina Solar", "ANGELINA_SOLAR 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_pflugerville = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 6034)  && get_to(get_arc(x))== get_bus(sys, 6255), Line, sys))
remove_component!(sys, line_pflugerville[1])
add_line!(sys, (230, "PFLUGERVILLE 1", "PFLUGERVILLE_SOLAR 2", 3))
add_line!(sys, (230, "PFLUGERVILLE_SOLAR 2", "AUSTIN 2 1", 23))
add_pv_plant!(sys, ("Pflugerville 2 Solar", "PFLUGERVILLE_SOLAR 2"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (230, "OILTON 1", "ZORRO_SOLAR", 16))
add_line!(sys, (230, "ZORRO_SOLAR", "CORAZON_SOLAR", 8))
add_line!(sys, (230, "CORAZON_SOLAR", "CORPUS CHRISTI 3 0", 142))
add_pv_plant!(sys, ("El Zorro Solar", "ZORRO_SOLAR"))
add_pv_plant!(sys, ("Corazon Solar", "CORAZON_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_sarita = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 4140)  && get_to(get_arc(x))== get_bus(sys, 4196), Line, sys))
remove_component!(sys, line_sarita[1])
add_line!(sys, (230, "OILTON 1", "DOVE_RUN", 86))
add_line!(sys, (230, "DOVE_RUN", "SARITA 1 0", 4))
add_pv_plant!(sys, ("Dove Run", "DOVE_RUN"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop1 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 8068)  && get_to(get_arc(x))== get_bus(sys, 8083), Line, sys))
remove_component!(sys, line_drop1[1])
add_line!(sys, (230, "JEWETT 1 1", "ROSELAND_SOLAR", 8))
add_line!(sys, (230, "ROSELAND_SOLAR", "FRANKLIN 1", 36))
add_pv_plant!(sys, ("Roseland", "ROSELAND_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop2 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 4070)  && get_to(get_arc(x))== get_bus(sys, 4183), Line, sys))
remove_component!(sys, line_drop2[1])
add_line!(sys, (230, "BROWNSVILLE 2 0", "RAYOS_DEL_SOL", 44))
add_line!(sys, (230, "RAYOS_DEL_SOL", "ARROYO_SOLAR", 11))
add_line!(sys, (230, "ARROYO_SOLAR", "SAN PERLITA 0", 20))
add_pv_plant!(sys, ("Rayos Del Sol", "RAYOS_DEL_SOL"))
add_pv_plant!(sys, ("Arroyo Solar", "ARROYO_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (230, "MISSION 1 0", "FRONTON_SOLAR", 61))
add_line!(sys, (230, "FRONTON_SOLAR", "STARR_SOLAR", 9))
add_line!(sys, (230, "STARR_SOLAR", "LAREDO 4 0", 102))
add_pv_plant!(sys, ("Fronton Solar", "FRONTON_SOLAR"))
add_pv_plant!(sys, ("Starr Solar Ranch", "STARR_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")



add_pv_plant!(sys, ("Diamondback Solar", "MISSION 4 0"))
add_pv_plant!(sys, ("Half Moon Solar", "LA JOYA 0"))
add_pv_plant!(sys, ("Bacon Switch Solar", "WICHITA FALLS 1 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_pv_plant!(sys, ("Signal Ranch", "CADDO MILLS 0"))
add_pv_plant!(sys, ("Vancourt", "HARLINGEN 2 0"))
add_pv_plant!(sys, ("Ridge Solar", "PRESIDIO 1 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_pv_plant!(sys, ("Brightside Solar", "BEEVILLE 0"))
add_pv_plant!(sys, ("Kellam Solar", "VAN 0"))
add_pv_plant!(sys, ("Garnet Solar", "GRANGER 0"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop3 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 5191)  && get_to(get_arc(x))== get_bus(sys, 5407), Line, sys))
remove_component!(sys, line_drop3[1])
add_line!(sys, (161, "MERIDIAN 0", "OWENS_SOLAR", 9))
add_line!(sys, (161, "OWENS_SOLAR", "CLIFTON 2 0", 10))
add_pv_plant!(sys, ("Owens Solar", "OWENS_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_pv_plant!(sys, ("Smithland Texas Solar", "TEMPLE 3 0"))
add_pv_plant!(sys, ("Wang Solar", "RIESEL 1 2"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop4 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 8096)  && get_to(get_arc(x))== get_bus(sys, 8153), Line, sys))
remove_component!(sys, line_drop4[1])
add_line!(sys, (115, "EDGEWOOD 0", "GSE_ELEVEN", 15))
add_line!(sys, (115, "GSE_ELEVEN", "CANTON 0", 6))
add_pv_plant!(sys, ("GSE Eleven", "GSE_ELEVEN"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop5 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 5276)  && get_to(get_arc(x))== get_bus(sys, 5201), Line, sys))
remove_component!(sys, line_drop5[1])
add_line!(sys, (161, "COOLIDGE 0", "SUN_VALLEY 1", 14))
add_line!(sys, (161, "SUN_VALLEY 1", "MART 0", 6))
add_pv_plant!(sys, ("Sun Valley", "SUN_VALLEY 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop6 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 5071)  && get_to(get_arc(x))== get_bus(sys, 5359), Line, sys))
remove_component!(sys, line_drop6[1])
add_line!(sys, (161, "RIESEL 1 1", "SUN_VALLEY 2", 13))
add_line!(sys, (161, "SUN_VALLEY 2", "WACO 3 0", 13))
add_pv_plant!(sys, ("Sun Valley 2", "SUN_VALLEY 2"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop40 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 5389)  && get_to(get_arc(x))== get_bus(sys, 5393), Line, sys))
remove_component!(sys, line_drop40[1])
add_line!(sys, (161, "CHINA SPRING 0", "ANGUS_SOLAR", 6))
add_line!(sys, (161, "ANGUS_SOLAR", "WACO 2 1", 19))
add_pv_plant!(sys, ("Angus Solar", "ANGUS_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop7 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 5088)  && get_to(get_arc(x))== get_bus(sys, 5393), Line, sys))
remove_component!(sys, line_drop7[1])
add_line!(sys, (161, "CLIFTON 1 0", "MARKUM_SOLAR", 18))
add_line!(sys, (161, "MARKUM_SOLAR", "CHINA SPRING 0", 6))
add_pv_plant!(sys, ("Markum Solar", "MARKUM_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop8 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 4144)  && get_to(get_arc(x))== get_bus(sys, 4127), Line, sys))
remove_component!(sys, line_drop8[1])
add_line!(sys, (115, "ORANGE GROVE 0", "MILLHOUSE_SOLAR", 28))
add_line!(sys, (115, "MILLHOUSE_SOLAR", "ALICE 0", 9))
add_pv_plant!(sys, ("Millhouse Solar", "MILLHOUSE_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_transformer!(sys, (230, 115, "QUEMADO 1", "QUEMADO 0"))
add_line!(sys, (230, "QUEMADO 1", "TREVINO_SOLAR 1", 42))
add_line!(sys, (230, "TREVINO_SOLAR 1", "EAGLE PASS 0", 21))
add_pv_plant!(sys, ("Trevino Solar", "TREVINO_SOLAR 1"))
line_drop9 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 4188)  && get_to(get_arc(x))== get_bus(sys, 4015), Line, sys))
remove_component!(sys, line_drop9[1])
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (161, "SANDINE_SOLAR", "PADUCAH 0", 9))
add_line!(sys, (161, "OBSIDIAN_SOLAR", "PADUCAH 0", 11))
add_line!(sys, (161, "CITRINE_SOLAR", "PADUCAH 0", 12))
add_pv_plant!(sys, ("Sandine Solar", "SANDINE_SOLAR"))
add_pv_plant!(sys, ("Obsidian Solar", "OBSIDIAN_SOLAR"))
add_pv_plant!(sys, ("Citrine Solar", "CITRINE_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (115, "CAUSE_SOLAR", "SAN ANTONIO 22 1", 3))
add_line!(sys, (115, "STILLWATER_SOLAR", "CORPUS CHRISTI 18 0", 4))
add_pv_plant!(sys, ("Stillwater Solar", "STILLWATER_SOLAR"))
add_pv_plant!(sys, ("Cause Solar", "CAUSE_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop10 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 5280)  && get_to(get_arc(x))== get_bus(sys, 5461), Line, sys))
remove_component!(sys, line_drop10[1])
add_line!(sys, (161, "TEMPLE 1 1", "SPANISH CROWN 1", 9))
add_line!(sys, (161, "SPANISH CROWN 1", "TEMPLE 3 0", 9))
add_pv_plant!(sys, ("Spanish Crown", "SPANISH CROWN 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop11 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 5049)  && get_to(get_arc(x))== get_bus(sys, 2113), Line, sys))
remove_component!(sys, line_drop11[1])
line_drop12 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 2113)  && get_to(get_arc(x))== get_bus(sys, 2021), Line, sys))
remove_component!(sys, line_drop12[1])
add_line!(sys, (500, "GREENVILLE 1 0", "SAMSON SOLAR 3 0", 66))
add_line!(sys, (500, "SAMSON SOLAR 3 0", "PARIS 1 0", 12))
add_line!(sys, (500, "PARIS 1 0", "SAMSON SOLAR 1 0", 7))
add_line!(sys, (500, "SAMSON SOLAR 1 0", "PARIS 2 0", 6))
add_pv_plant!(sys, ("Samson Solar 2", "PARIS 1 0"))
add_pv_plant!(sys, ("Samson Solar 3", "SAMSON SOLAR 3 0"))
add_pv_plant!(sys, ("Samson Solar", "SAMSON SOLAR 1 0"))
add_pv_plant!(sys, ("Tyson Nick Solar", "SAMSON SOLAR 3 0"))
#res = solve_powerflow(ACPowerFlow(), sys)
##check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_pv_plant!(sys, ("Greyhound Solar 2", "ODESSA 1 10"))
line_drop13 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 1024)  && get_to(get_arc(x))== get_bus(sys, 1018), Line, sys))
remove_component!(sys, line_drop13[1])
add_transformer!(sys, (500, 115, "NOTREES 1", "NOTREES 0"))
add_pv_plant!(sys, ("Oberon Solar", "NOTREES 1"))
add_pv_plant!(sys, ("Sisters Solar", "NOTREES 1"))
line_drop15 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 1037)  && get_to(get_arc(x))== get_bus(sys, 1071), Line, sys))
remove_component!(sys, line_drop15[1])
add_line!(sys, (500, "ODESSA 5 1", "ODESSA 1 8", 16))
add_transformer!(sys, (500, 115, "ODESSA 5 1", "ODESSA 5 0"))
add_pv_plant!(sys, ("Greyhound Solar", "ODESSA 5 1"))
add_line!(sys, (500, "ODESSA 5 1", "NOTREES 1", 14))
line_drop16 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 1018)  && get_to(get_arc(x))== get_bus(sys, 1017), Line, sys))
remove_component!(sys, line_drop16[1])
add_transformer!(sys, (500, 115, "ODESSA 6 1", "ODESSA 6 0"))
add_line!(sys, (500, "NOTREES 1", "ODESSA 6 1", 20))
add_pv_plant!(sys, ("Oxy Solar", "ODESSA 6 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop17 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 3139)  && get_to(get_arc(x))== get_bus(sys, 3016), Line, sys))
remove_component!(sys, line_drop17[1])
add_line!(sys, (115, "WINTERS 0", "NORTON_SOLAR", 16))
add_line!(sys, (115, "NORTON_SOLAR", "BLACKWELL 0", 23))
add_pv_plant!(sys, ("Norton Solar", "NORTON_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop18 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 3024)  && get_to(get_arc(x))== get_bus(sys, 3019), Line, sys))
remove_component!(sys, line_drop18[1])
add_line!(sys, (115, "ELDORADO 0", "PRICKLY_PEAR", 15))
add_line!(sys, (115, "PRICKLY_PEAR", "CHRISTOVAL 1", 13))
add_pv_plant!(sys, ("Prickly Pear", "PRICKLY_PEAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop19 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 3058)  && get_to(get_arc(x))== get_bus(sys, 3053), Line, sys))
remove_component!(sys, line_drop19[1])
add_line!(sys, (230, "WINGATE 0", "BLUE_BELL 2 0", 77))
add_line!(sys, (230, "BLUE_BELL 2 0", "STERLING CITY 1 0", 13))
add_pv_plant!(sys, ("Blue Bell Solar II", "BLUE_BELL 2 0"))
add_transformer!(sys, (230, 115, "BLUE_BELL 2 0", "BLUE_BELL 2 1"))
add_line!(sys, (115, "BLUE_BELL", "BLUE_BELL 2 1", 15))
add_pv_plant!(sys, ("BlueBell Solar", "BLUE_BELL"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_pv_plant!(sys, ("Cutlass Solar", "MISSOURI CITY 2 0"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (500, "JUNO_SOLAR", "OXBOW_SOLAR", 27))
add_line!(sys, (500, "OXBOW_SOLAR", "GOODRANCH_SOLAR", 10))
add_line!(sys, (500, "GOODRANCH_SOLAR", "ROSCOE 5 2", 86))
add_pv_plant!(sys, ("Oxbow Solar", "OXBOW_SOLAR"))
add_pv_plant!(sys, ("Goodranch Solar", "GOODRANCH_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_transformer!(sys, (500, 115, "ANDREWS 1", "ANDREWS 0"))
set_angle!(get_component(Bus, sys, "ANDREWS 1"), 1.18)
add_line!(sys, (500, "ODESSA 6 1", "ANDREWS 1", 50))
add_line!(sys, (500, "ANDREWS 1", "EUNICE_SOLAR 0", 50))
line_drop20 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 1019)  && get_to(get_arc(x))== get_bus(sys, 1040), Line, sys))
remove_component!(sys, line_drop20[1])
line_drop21 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 1040)  && get_to(get_arc(x))== get_bus(sys, 1090), Line, sys))
remove_component!(sys, line_drop21[1])
add_pv_plant!(sys, ("Lapetus Solar 2", "ANDREWS 1"))
add_pv_plant!(sys, ("Prospero Solar II", "EUNICE_SOLAR 0"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop22 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 7126)  && get_to(get_arc(x))== get_bus(sys, 7305), Line, sys))
remove_component!(sys, line_drop22[1])
add_line!(sys, (230, "SUGAR LAND 2 1", "FIGHTING_JAYS", 14))
add_line!(sys, (230, "FIGHTING_JAYS", "WHARTON 1 1", 37))
add_pv_plant!(sys, ("Fighting Jays Solar", "FIGHTING_JAYS"))
add_line!(sys, (500, "ODESSA 1 8", "MCCAMEY 1 2", 80))
add_pv_plant!(sys, ("Ponwar Solar Farm", "MCCAMEY 1 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
# Ramsey Solar is really large, needs a power reduction
for g in get_components(ThermalStandard, sys)
    if g.active_power > 0.0
        g.active_power = max(g.active_power_limits.min, g.active_power * 0.97)
    end
end
add_line!(sys, (500, "WADSWORTH 0", "RAMSEY_SOLAR", 27))
add_line!(sys, (500, "RAMSEY_SOLAR", "WHARTON 1 0", 30))
add_pv_plant!(sys, ("Ramsey Solar", "RAMSEY_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop41 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 7304)  && get_to(get_arc(x))== get_bus(sys, 7095), Line, sys))
remove_component!(sys, line_drop41[1])
add_line!(sys, (500, "MCCAMEY 1 1", "QUEEN_SOLAR", 23))
add_pv_plant!(sys, ("Queen Solar", "QUEEN_SOLAR"))
add_line!(sys, (500, "QUEEN_SOLAR", "ODESSA 1 10", 47))
line_drop23 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 1033)  && get_to(get_arc(x))== get_bus(sys, 1081), Line, sys))
remove_component!(sys, line_drop23[1])
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (115, "HALLMARK_SOLAR", "GREENVILLE 1 3", 10))
add_pv_plant!(sys, ("Hallmark Solar", "HALLMARK_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (161, "DODD CITY 0", "PHOENIX_SOLAR", 14))
add_pv_plant!(sys, ("Phoenix Solar", "PHOENIX_SOLAR"))
add_line!(sys, (161, "PHOENIX_SOLAR", "TRENTON 0", 16))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop24 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 2081)  && get_to(get_arc(x))== get_bus(sys, 2129), Line, sys))
remove_component!(sys, line_drop24[1])
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (230, "ROSCOE 2 0", "HOLSTEIN 2", 26))
add_pv_plant!(sys, ("Holstein 2 Solar", "HOLSTEIN 2"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (230, "HOLSTEIN 2", "HOLSTEIN 1", 10))
add_pv_plant!(sys, ("Holstein Solar", "HOLSTEIN 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (230, "HOLSTEIN 1", "ABILENE 1 0", 63))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop25 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 3037)  && get_to(get_arc(x))== get_bus(sys, 3088), Line, sys))
remove_component!(sys, line_drop25[1])
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (230, "BAY CITY 0", "THICKGRASS SOLAR", 13))
add_pv_plant!(sys, ("Thickgrass Solar", "THICKGRASS SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (230, "THICKGRASS SOLAR", "WADSWORTH 1", 30))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop26 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 7261)  && get_to(get_arc(x))== get_bus(sys, 7096), Line, sys))
remove_component!(sys, line_drop26[1])
add_line!(sys, (161, "WHITNEY 0", "HILL_SOLAR", 9))
add_pv_plant!(sys, ("Hill Solar", "HILL_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (161, "HILL_SOLAR", "HILLSBORO 0", 12))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop27 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 5290)  && get_to(get_arc(x))== get_bus(sys, 5345), Line, sys))
remove_component!(sys, line_drop27[1])
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (115, "IOLA 0", "BLUE_JAY_SOLAR", 13))
add_pv_plant!(sys, ("Blue Jay Solar", "BLUE_JAY_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (115, "BLUE_JAY_SOLAR", "SHIRO 2", 15))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
line_drop28 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 8143)  && get_to(get_arc(x))== get_bus(sys, 8032), Line, sys))
remove_component!(sys, line_drop28[1])
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (161, "WOLFE CITY 0", "CONIGLIO_SOlAR", 13))
add_pv_plant!(sys, ("Coniglio Solar", "CONIGLIO_SOlAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (161, "CONIGLIO_SOlAR", "LEONARD 0", 13))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_transformer!(sys, (230, 115, "SABINAL 1", "SABINAL 0"))
add_transformer!(sys, (230, 115, "UVALDE 1", "UVALDE 0"))
add_line!(sys, (230, "HONDO 0", "SABINAL 1", 50))
add_line!(sys, (230, "SABINAL 1", "GLOVE_SOLAR", 13))
add_pv_plant!(sys, ("Glove Solar", "GLOVE_SOLAR"))
set_available!(get_component(RenewableGen, sys, "Glove Solar"), false)
add_line!(sys, (230, "GLOVE_SOLAR", "UVALDE 1", 31))
add_pv_plant!(sys, ("Kochab Solar", "SABINAL 1"))
add_line!(sys, (115, "FLUORITE_SOLAR", "SABINAL 0", 9))
add_pv_plant!(sys, ("Fluorite Solar", "FLUORITE_SOLAR"))
add_line!(sys, (115, "BASALT_SOLAR", "FLUORITE_SOLAR", 9))
add_pv_plant!(sys, ("Basalt Solar", "BASALT_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (115, "SPINEL_SOLAR", "HONDO 1", 16))
add_pv_plant!(sys, ("Spinel Solar", "SPINEL_SOLAR"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
to_json(sys, "intermediate_sys.json", force = true)
add_line!(sys, (115, "TRENT 2 0", "INDIGO_SOLAR", 8))
add_pv_plant!(sys, ("Indigo Solar", "INDIGO_SOLAR"))
add_line!(sys, (115, "INDIGO_SOLAR", "HAMLIN 0", 13))
line_drop29 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 3145)  && get_to(get_arc(x))== get_bus(sys, 3006), Line, sys))
remove_component!(sys, line_drop29[1])
add_line!(sys, (230, "HERMLEIGH 0", "CROWDED_STAR_SOLAR", 53))
add_transformer!(sys, (230, 115, "HAMLIN 1", "HAMLIN 0"))
add_line!(sys, (230, "CROWDED_STAR_SOLAR", "HAMLIN 1", 53))
add_pv_plant!(sys, ("Crowded Star Solar", "CROWDED_STAR_SOLAR"))
add_pv_plant!(sys, ("Anson Solar", "HAMLIN 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (115, "LUEDERS 0", "DISCO_SOLAR", 18))
add_pv_plant!(sys, ("Disco Solar", "DISCO_SOLAR"))
add_line!(sys, (115, "DISCO_SOLAR", "HASKELL 1", 12))
line_drop30 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 3021)  && get_to(get_arc(x))== get_bus(sys, 2131), Line, sys))
remove_component!(sys, line_drop30[1])
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_line!(sys, (230, "HAMLIN 1", "ELROND", 57))
add_pv_plant!(sys, ("Elrond", "ELROND"))
add_transformer!(sys, (230, 161, "ROCHESTER 1", "ROCHESTER 0"))
add_line!(sys, (230, "ELROND", "ROCHESTER 1", 26))
add_pv_plant!(sys, ("Quantum", "ROCHESTER 1"))
add_pv_plant!(sys, ("Quantum Increase", "ROCHESTER 1"))
add_transformer!(sys, (230, 161, "OLNEY 1 3", "OLNEY 1 1"))
add_line!(sys, (230, "ROCHESTER 1", "OLNEY 1 3", 86))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
to_json(sys, "intermediate_sys.json", force = true)
add_line!(sys, (161, "FRENCH_G_SOLAR 1", "GRAHAM 1", 6))
add_pv_plant!(sys, ("French Goldston Solar", "FRENCH_G_SOLAR 1"))
add_pv_plant!(sys, ("Prospero Solar", "ANDREWS 1"))
add_line!(sys, (115, "POINT COMFORT 2 2", "MUSTANG_CREEK", 20))
add_pv_plant!(sys, ("Mustang Creek Solar", "MUSTANG_CREEK"))
add_line!(sys, (115, "MUSTANG_CREEK", "BLESSING 0", 9))
line_drop31 = collect(get_components(x -> get_from(get_arc(x)) == get_bus(sys, 7129)  && get_to(get_arc(x))== get_bus(sys, 7060), Line, sys))
remove_component!(sys, line_drop31[1])
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")

# =====================================================================================
# SECTION 3: HYDROELECTRIC PLANT ADDITION
# =====================================================================================
# Add major Texas hydro facilities
# =====================================================================================

add_line!(sys, (230, "DEL RIO 0", "AMISTAD_HYDRO 0", 45))
get_ext(get_component(Bus, sys, "AMISTAD_HYDRO 0"))["x"] = -101.056020
get_ext(get_component(Bus, sys, "AMISTAD_HYDRO 0"))["y"] = 29.449520
add_line!(sys, (230, "AMISTAD_HYDRO 0", "EAGLE PASS 0", 145))
add_transformer!(sys, (230, 18, "AMISTAD_HYDRO 0", "AMISTAD_HYDRO 1 1"))
add_transformer!(sys, (230, 18, "AMISTAD_HYDRO 0", "AMISTAD_HYDRO 1 2"))
add_hydro_plant!(sys, ("Amistad 1", "AMISTAD_HYDRO 1 1"))
add_hydro_plant!(sys, ("Amistad 2", "AMISTAD_HYDRO 1 2"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_transformer!(sys, (115, 18, "BUCHANAN DAM 1 0", "BUCHANAN DAM 1 3"))
add_hydro_plant!(sys, ("Buchanan Dam 3", "BUCHANAN DAM 1 3"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_transformer!(sys, (115, 18, "BUCHANAN DAM 1 0", "INKS 1"))
add_hydro_plant!(sys, ("Inks Hydro", "INKS 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_transformer!(sys, (115, 18, "AUSTIN 35 0", "MARSHALL FORD 1"))
add_transformer!(sys, (115, 18, "AUSTIN 35 0", "MARSHALL FORD 2"))
add_transformer!(sys, (115, 18, "AUSTIN 35 0", "MARSHALL FORD 3"))
add_hydro_plant!(sys, ("Marshall Ford 1", "MARSHALL FORD 1"))
add_hydro_plant!(sys, ("Marshall Ford 2", "MARSHALL FORD 2"))
add_hydro_plant!(sys, ("Marshall Ford 3", "MARSHALL FORD 3"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")
add_transformer!(sys, (162, 18, "CLIFTON 1 0", "WHITNEY DAM 2"))
add_hydro_plant!(sys, ("Whitney Dam 2", "WHITNEY DAM 2"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) ? solve_powerflow(ACPowerFlow(), sys) : @error("PowerFlow Failed")


# =====================================================================================
# SECTION 4: EXISTING GENERATOR REPLACEMENT WITH SOLAR
# =====================================================================================
# Replace existing thermal generators with solar plants at the same locations
# =====================================================================================

################ Substitute Existing PV with new PV ###################
add_pv_plant!(sys, ("Piano Solar", "BRACKETTVILLE 1 1")) # gen-110
add_pv_plant!(sys, ("Error Solar", "BIG SPRING 6 1")) # gen -22
add_pv_plant!(sys, ("Bonus Solar", "BIG SPRING 6 2")) # gen - 23
add_pv_plant!(sys, ("Scene Solar", "ROUND ROCK 1 2")) # gen - 288
add_pv_plant!(sys, ("Photo Solar", "ROUND ROCK 1 1")) # gen - 287
add_pv_plant!(sys, ("Drama Solar", "ROUND ROCK 1 3")) # gen - 289
add_pv_plant!(sys, ("Tooth Solar", "ROUND ROCK 1 4")) # gen - 290
add_pv_plant!(sys, ("Hover Solar", "ROUND ROCK 1 5")) # gen - 291
add_pv_plant!(sys, ("Straw Solar", "ROUND ROCK 1 6")) # gen - 292
add_pv_plant!(sys, ("Troop Solar", "BAYTOWN 3 2"))
add_pv_plant!(sys, ("Mercy Solar", "BAYTOWN 3 3"))
add_pv_plant!(sys, ("Storm Solar", "BAYTOWN 3 4"))
add_pv_plant!(sys, ("Arena Solar", "BAYTOWN 3 5"))
add_pv_plant!(sys, ("Feign Solar", "BAYTOWN 3 6"))
add_pv_plant!(sys, ("Glass Solar", "BAYTOWN 3 7"))
add_pv_plant!(sys, ("Spray 2 Solar", "PORT LAVACA 2"))
add_pv_plant!(sys, ("Smoke Solar", "PORT LAVACA 3"))
add_pv_plant!(sys, ("Rebel Solar", "PORT LAVACA 4"))
add_pv_plant!(sys, ("Toast Solar", "PORT LAVACA 5"))
add_pv_plant!(sys, ("Blast Solar", "LUFKIN 1 1"))
add_pv_plant!(sys, ("Giant Solar", "CUSHING 1 2"))
add_pv_plant!(sys, ("River Solar", "PRESIDIO 1 1"))
#res = solve_powerflow(ACPowerFlow(), sys)
#check_pf_results(res) && solve_ac_powerflow!(sys)


# =====================================================================================
# SECTION 5: GEOSPATIAL DATA PROCESSING
# =====================================================================================
# Assign GPS coordinates to all system components for mapping and analysis
# =====================================================================================

# Assign real-world GPS coordinates to solar plant buses
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


# =====================================================================================
# SECTION 6: AREA NAMING AND ORGANIZATION
# =====================================================================================
# Rename system areas for better organization
# =====================================================================================

# Renaming of areas
for area_no in 1:8
    area_number_as_text = string(area_no)
    area = get_component(Area, sys, area_number_as_text)
    group_name = area_name_number_map[area_number_as_text]
    set_name!(sys, area, group_name)
    area.internal.ext = Dict("area_number_as_text"=> area_number_as_text)
end

# Save intermediate system state
to_json(sys, "intermediate_sys.json", force = true)

# =====================================================================================
# SECTION 7: TIME SERIES DATA PROCESSING
# =====================================================================================
# Add realistic time-varying data for loads, wind, and hydro resources
# =====================================================================================

# Load the intermediate system state.
sys = System("intermediate_sys.json")

include("load_processing.jl")      # Add electrical load time series
include("wind_processing.jl")      # Add wind generation profiles
include("hydro_processing.jl")     # Add hydro availability data
to_json(sys, "pre_thermal_sys.json", force = true) # Save pre-thermal system state

# =====================================================================================
# SECTION 8: THERMAL UNIT PROCESSING
# =====================================================================================
# Replace generic thermal units with detailed models using real ERCOT operational data
# Includes economics.
# =====================================================================================

sys = System("pre_thermal_sys.json")
include("thermal_processing.jl")     # Detailed thermal plant parameters
to_json(sys, "post_thermal_sys.json", force = true)

# =====================================================================================
# SECTION 9: SYSTEM FINALIZATION AND OUTPUT GENERATION
# =====================================================================================
# Finalize the system and create different market timeframe files
# =====================================================================================

include("add_services.jl")  # Add ancillary services (reserves)
# Produces intermediate_sys_w_services.json system.

# Export geographic data for visualization
write_lines_geo_data(sys, "line_coords_modified")
write_gen_buses_geo_data(sys, "bus_gens_coords_modified")

# Finalize system and prepare for simulation
finalize_system(sys)  # This saves to "base_sys.json" 

# =====================================================================================
# SECTION 10: MARKET DATA GENERATION
# =====================================================================================
# Create separate system files for different electricity market timeframes
# Each script automatically saves its output systems
# =====================================================================================

include("make_day_ahead_data.jl")    # Creates and saves DA_sys.json + scenarios
include("make_hour_ahead_data.jl")   # Creates and saves jsons/HA_sys.json
include("make_real_time_data.jl")    # Creates and saves jsons/RT_sys.json

# Market systems are automatically saved by their respective scripts:
#   - DA_sys.json (day-ahead deterministic)
#   - DA_sys_31_scenarios.json (day-ahead 31 scenarios)
#   - DA_sys_84_scenarios.json (day-ahead 84 scenarios)
#   - jsons/HA_sys.json (hour-ahead market)
#   - jsons/RT_sys.json (real-time market)
