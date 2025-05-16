
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


# sys_RT = System("/scripts/jsons/HA_sys.json")
sys_DA = System("sys_DA.json")

optimizer = optimizer_with_attributes(
                Xpress.Optimizer,
                #"parallel" => "on",
                "MIPRELSTOP" => mip_gap)


logger = configure_logging(console_level=Logging.Info)


template_uc = template_unit_commitment(;
network = NetworkModel(PTDFPowerModel ;use_slacks = true))
set_device_model!(template_uc, ThermalStandard, ThermalBasicUnitCommitment)
set_device_model!(template_uc, ThermalMultiStart, ThermalBasicUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch, ) 
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)

reduc_buses = collect(get_components(x -> get_base_voltage(x)*get_voltage_limits(x).max >= 500, ACBus, sys_DA))

reduced_lines_model = DeviceModel(
    Line,
    StaticBranchUnbounded;
    use_slacks = true,
    attributes = Dict(
        "filter_function" => collect(get_components(x -> get_base_voltage(x)*get_voltage_limits(x).max >= 500, ACBus, sys_DA))
    ),
)

set_device_model!(template_uc, DeviceModel(Line, 
                                        StaticBranch; 
                                        use_slacks = true))

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

set_device_model!(template_uc, storage_model)

set_service_model!(template_uc, ServiceModel(VariableReserve{ReserveUp}, RangeReserve))
set_service_model!(template_uc, ServiceModel(VariableReserve{ReserveDown}, RangeReserve))

set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver)
initial_date = "2018-08-01"
start_time =DateTime(string(initial_date,"T00:00:00"))
model = DecisionModel(template_uc, sys_DA; name = "UC", optimizer = optimizer, horizon = Hour(24), calculate_conflict = true)
models = SimulationModels(; decision_models = [model])

steps_sim    = 1
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

########################## Results #############################
using PowerGraphics
results = SimulationResults(sim)
uc = get_decision_problem_results(results, "UC")
plot_fuel(uc, generator_mapping_file = "/Users/acasavan/GitHub_Repos/my_genmap.yaml")


GT = collect(get_components(x-> get_prime_mover_type(x) == PrimeMovers.GT, ThermalStandard, sys))

for i in 1:54
    gen = GT[i]
    set_prime_mover_type!(gen, PrimeMovers.CT)
end

GT_MS =  collect(get_components(x-> get_prime_mover_type(x) == PrimeMovers.GT, ThermalMultiStart, sys))
for i in 1:83
    gen = GT_MS[i]
    set_prime_mover_type!(gen, PrimeMovers.CT)
end





# ## Reduced Line Model
# reduced_buses = collect(get_components(x -> get_base_voltage(x)*get_voltage_limits(x).max >= 230, ACBus, sys_DA))
# reduced_lines = collect(get_components(x -> get_from(get_arc(x)) in reduced_buses && get_to(get_arc(x)) in reduced_buses, Line, sys_DA))

# # reduced_lines_model = DeviceModel(
# #     Line, 
# #     StaticBranchUnbounded,
# #     attributes = Dict( "filter_function" => x -> get_from(get_arc(x)) in reduced_buses && get_to(get_arc(x)) in reduced_buses))

# set_device_model!(template_uc, reduced_lines_model)



# set_device_model!(template_uc, DeviceModel(Transformer2W, 
#                                         StaticBranch; 
#                                         use_slacks = true))    

get_active_power_limits(solar[1])