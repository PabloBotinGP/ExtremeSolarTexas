# Run from main folder. 

using PowerSystems
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
using Xpress
#using PowerGraphics
mip_gap = 0.1

# Load all 3 systems (relative paths)
sys_DA = System("DA_sys.json")
sys_HA = System("HA_sys.json")
sys_RT = System("RT_sys.json")

logger = configure_logging(console_level=Logging.Info)

# Define Storage Model
storage_model = DeviceModel(
    EnergyReservoirStorage,
    StorageDispatchWithReserves;
    attributes=Dict(
        "reservation" => true,
        "energy_target" => false,
        "cycling_limits" => false,
        "regularization" => true,
    ),
)

# Define all 3 stage templates
# Unit Commitment (Day ahead)
template_uc = template_unit_commitment(;
network = NetworkModel(CopperPlatePowerModel; use_slacks = true))
set_device_model!(template_uc, ThermalStandard, ThermalBasicUnitCommitment) # TBUC; No ramping constraints
set_device_model!(template_uc, ThermalMultiStart, ThermalBasicUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver) 
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, storage_model)
set_service_model!(template_uc, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
set_service_model!(template_uc, ServiceModel(VariableReserve{ReserveDown}, RangeReserve))
# No device model for lines and transformers because it is a copper plate.

# Economic dispatch (Hour ahead)
template_ed = template_economic_dispatch(;
network = NetworkModel(CopperPlatePowerModel; use_slacks = true))
set_device_model!(template_ed, ThermalStandard, ThermalBasicUnitCommitment) 
set_device_model!(template_ed, ThermalMultiStart, ThermalBasicUnitCommitment)
set_device_model!(template_ed, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_ed, HydroDispatch, HydroDispatchRunOfRiver) 
set_device_model!(template_ed, PowerLoad, StaticPowerLoad)
set_device_model!(template_ed, storage_model)
set_service_model!(template_ed, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
set_service_model!(template_ed, ServiceModel(VariableReserve{ReserveDown}, RangeReserve))

# Real Time (RT)    
template_rt = template_economic_dispatch(;
network = NetworkModel(CopperPlatePowerModel; use_slacks = true))
set_device_model!(template_rt, ThermalStandard, ThermalBasicUnitCommitment)
set_device_model!(template_rt, ThermalMultiStart, ThermalBasicUnitCommitment)
set_device_model!(template_rt, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_rt, HydroDispatch, HydroDispatchRunOfRiver) 
set_device_model!(template_rt, PowerLoad, StaticPowerLoad)
set_device_model!(template_rt, storage_model)
set_service_model!(template_rt, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
set_service_model!(template_rt, ServiceModel(VariableReserve{ReserveDown}, RangeReserve))

################## Simulation Setup ####################
initial_date = "2018-08-01"
start_time =DateTime(string(initial_date,"T00:00:00"))
optimizer = optimizer_with_attributes(
                Xpress.Optimizer,
                #"parallel" => "on",
                "MIPRELSTOP" => mip_gap)
models = SimulationModels(; 
    decision_models = [DecisionModel(template_uc, sys_DA; optimizer = optimizer, name = "UC"), 
                        DecisionModel(template_ed, sys_HA; optimizer = optimizer, name = "ED"),
                        DecisionModel(template_rt, sys_RT; optimizer = optimizer, name = "RT"),]
)
steps_sim = 2 # Number of days to simulate
current_date = string(today())

# Feet Forward; Describes how info is passed between steps.
feedforward = Dict("ED" =>[SemiContinuousFeedforward(; component_type = ThermalStandard, source = OnVariable, affected_values = [ActivePowerVariable],), 
                           SemiContinuousFeedforward(; component_type = ThermalMultiStart, source = OnVariable, affected_values = [ActivePowerVariable],)],
                    "RT" =>[SemiContinuousFeedforward(; component_type = ThermalStandard, source = OnVariable, affected_values = [ActivePowerVariable],), 
                           SemiContinuousFeedforward(; component_type = ThermalMultiStart, source = OnVariable, affected_values = [ActivePowerVariable],)],)
# Are we not missing the UC? No because we start with the day ahead assumptions (unit commitment), then we pass info forward to ED and RT.

# Set up simulation sequence.
sequence = SimulationSequence(; models = models, ini_cond_chronology = InterProblemChronology(),feedforwards = feedforward,)

sim = Simulation(
    name = current_date * "_DR-test" * "_" * string(steps_sim)* "steps",
    steps = steps_sim,
    models = models,
    initial_time = DateTime(string(initial_date,"T00:00:00")),
    sequence = sequence,
    # Use a project-relative simulation folder so debug artifacts (infeasible problems)
    # are written inside the workspace and accessible for inspection.
    simulation_folder = joinpath(@__DIR__, "../tmp_sim_debug"),
)

build!(sim)
execute!(sim)

########################## Results #############################
# using PowerGraphics
# results = SimulationResults(sim)
# uc = get_decision_problem_results(results, "UC")
# plot_fuel(uc, generator_mapping_file = "/Users/acasavan/GitHub_Repos/my_genmap.yaml")


# GT = collect(get_components(x-> get_prime_mover_type(x) == PrimeMovers.GT, ThermalStandard, sys))

# for i in 1:54
#     gen = GT[i]
#     set_prime_mover_type!(gen, PrimeMovers.CT)
# end

# GT_MS =  collect(get_components(x-> get_prime_mover_type(x) == PrimeMovers.GT, ThermalMultiStart, sys))
# for i in 1:83
#     gen = GT_MS[i]
#     set_prime_mover_type!(gen, PrimeMovers.CT)
# end





# # ## Reduced Line Model
# # reduced_buses = collect(get_components(x -> get_base_voltage(x)*get_voltage_limits(x).max >= 230, ACBus, sys_DA))
# # reduced_lines = collect(get_components(x -> get_from(get_arc(x)) in reduced_buses && get_to(get_arc(x)) in reduced_buses, Line, sys_DA))

# # # reduced_lines_model = DeviceModel(
# # #     Line, 
# # #     StaticBranchUnbounded,
# # #     attributes = Dict( "filter_function" => x -> get_from(get_arc(x)) in reduced_buses && get_to(get_arc(x)) in reduced_buses))

# # set_device_model!(template_uc, reduced_lines_model)



# # set_device_model!(template_uc, DeviceModel(Transformer2W, 
# #                                         StaticBranch; 
# #                                         use_slacks = true))    

# get_active_power_limits(solar[1])