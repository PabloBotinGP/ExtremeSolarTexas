
using PowerSystems
#using PowerGraphics
using PowerSimulations
using PowerNetworkMatrices
using Dates
using CSV
using HydroPowerSimulations
using DataFrames
using Logging
using TimeSeries
using StorageSystemsSimulations
#using HiGHS #solver

mip_gap = 0.01
if !isempty(ARGS) && ARGS[1] == "gpu"
    import Pkg; Pkg.add("cuOpt")
    using cuOpt
    optimizer = optimizer_with_attributes(
        cuOpt.Optimizer,
        "CUOPT_MIP_RELATIVE_GAP" => mip_gap)

else
    using Xpress
    optimizer = optimizer_with_attributes(
        Xpress.Optimizer,
        "MAXMEMORYSOFT" => 600000,   # Set the maximum amount of memory the solver can use (in MB)
        "MIPRELSTOP" => mip_gap)
end

#using PowerGrap

sys_DA = System("DA_sys.json")


# south_nuclear1 = get_component(ThermalMultiStart, sys_DA, "SOUTH_TEXAS_NUCLEAR_U1")
# set_active_power_limits!(south_nuclear1, (min = 0.008334153846153845, max = 13.54) )
# south_nuclear2 = get_component(ThermalMultiStart, sys_DA, "SOUTH_TEXAS_NUCLEAR_U2")
# set_active_power_limits!(south_nuclear2, (min = 0.008334153846153845, max = 13.543) )
# comanche_1 = get_component(ThermalMultiStart, sys_DA, "COMANCHE_PEAK_U1")
# set_active_power_limits!(comanche_1, (min = 0.008333333333333333, max = 12.150) )
# comanche_2 = get_component(ThermalMultiStart, sys_DA, "COMANCHE_PEAK_U2")
# set_active_power_limits!(comanche_2, (min = 0.008333333333333333, max = 12.15) )




logger= configure_logging(console_level=Logging.Info)

#area_interchange_df = CSV.read("scripts\\input_data\\zonal_flow_params.csv", DataFrame)

# for row in eachrow(area_interchange_df)
#     name = row["name "]
#     flow_from =  row["flow_limit_from "]
#     flow_to = row["flow_limit_from "]
#     area_from = get_component(Area, sys_DA, row["from "])
#     area_to = get_component(Area, sys_DA, row["to "])
# area_interchange = AreaInterchange(
#     name = name,
#     available = true,
#     active_power_flow = flow_to,
#     from_area = area_from,
#     to_area = area_to,
#     flow_limits = (from_to = flow_to, to_from = flow_to)

# )
# #remove_component!(sys_DA, area_interchange)
# add_component!(sys_DA, area_interchange)
# end

template_uc = template_unit_commitment(;
network = NetworkModel(PTDFPowerModel))
set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)
set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
set_device_model!(template_uc, ThermalMultiStart, ThermalStandardUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch,)
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, DeviceModel(Line,
                                        StaticBranch;
                                        use_slacks =true))

set_device_model!(template_uc, DeviceModel(Transformer2W,
                                        StaticBranch;
                                        use_slacks =true))

# set_device_model!(template_uc, AreaInterchange, StaticBranch)

storage_model = DeviceModel(
    EnergyReservoirStorage,
    StorageDispatchWithReserves;
    attributes=Dict(
        "reservation" => true,
        "energy_target" => false,
        "cycling_limits" => false,
        "regularization" => false,
    ),
)
set_device_model!(template_uc, storage_model)

set_service_model!(template_uc, ServiceModel(VariableReserve{ReserveUp}, RangeReserve; use_slacks = true))
set_service_model!(template_uc, ServiceModel(VariableReserve{ReserveDown}, RangeReserve; use_slacks = true))
initial_date = "2018-03-15"
start_time = DateTime(string(initial_date,"T00:00:00"))
model = DecisionModel(template_uc, sys_DA; name = "UC",
optimizer = optimizer,
horizon = Hour(24),
calculate_conflict = true,
store_variable_names = true
)
models = SimulationModels(; decision_models = [model])

steps_sim    = 10
current_date = string( today() )
sequence = SimulationSequence(
    models = models,
    # ini_cond_chronology = InterProblemChronology(),
)

sim = Simulation(
    name = current_date * "_DR-test" * "_" * string(steps_sim)* "steps",
    steps = steps_sim,
    models = models,
    initial_time = DateTime(string(initial_date,"T00:00:00")),
    sequence = sequence,
    simulation_folder = tempdir()#".",
)

build!(sim)

execute!(sim)

results = SimulationResults(sim)
uc = get_decision_problem_results(results, "UC")
for v in list_variable_names(uc)
    read_realized_variable(uc, v)
end
#vre_power =read_realized_variable(uc, "ActivePowerVariable__RenewableDispatch")
#thermal_power = read_realized_variable(uc, "ActivePowerVariable__ThermalMultiStart")
#hermals_power = read_realized_variable(uc, "ActivePowerVariable__ThermalStandard")

#=
############################# RESULTS############################
results = SimulationResults(sim)
uc = get_decision_problem_results(results, "UC")
# plot_fuel(uc, ylim = (0, 4000), generator_mapping_file = "/Users/acasavan/GitHub_Repos/my_genmap.yaml")

vre_power =read_realized_variable(uc, "ActivePowerVariable__RenewableDispatch")
thermal_power = read_realized_variable(uc, "ActivePowerVariable__ThermalMultiStart")
thermals_power = read_realized_variable(uc, "ActivePowerVariable__ThermalStandard")

solar = get_component(RenewableDispatch, sys_DA, "Angelina Solar")
ts = get_time_series_array(Deterministic, solar, "max_active_power")

CSV.write("VRE_Power_Sim.csv", vre_power)
CSV.write("ThermalMulitStart_Power_Sim.csv", thermal_power)


lmp = read_realized_duals(uc)
uc_LMP_data = lmp["AreaParticipationAssignmentConstraint__ACBus"]

CSV.write("area_lmp.csv", uc_LMP_data)

plot_dataframe(vre_power)
=#
