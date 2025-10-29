# Import necessary packages.
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
#using HiGHS # Use this solver if no Xpress license is available.
using Xpress
#using PowerGraphics # Not available atm.

# Configure logging
logger = configure_logging(console_level=Logging.Info)

# Load Day Ahead system - use absolute path to ensure it works from any directory
sys = System("DA_sys.json")

# Define Storage Model. 
storage_model = DeviceModel(
    EnergyReservoirStorage,
    StorageDispatchWithReserves;
    attributes=Dict(
        "reservation" => false,
        "energy_target" => false,
        "cycling_limits" => false,
        "regularization" => true,
    ), # Why these? How can I find more info about attributes? 
)

# Define Unit Commitment template. 
# Creates a ProblemTemplate with default DeviceModels for a Unit Commitment problem.
template_uc = template_unit_commitment(;
# network = NetworkModel(CopperPlatePowerModel; use_slacks = true)) # Establishes the model for the network as a copper plate with slacks.\
network = NetworkModel(CopperPlatePowerModel;))
# Injection Device Formulations. 
set_device_model!(template_uc, ThermalStandard, ThermalBasicUnitCommitment) # TBUC; No ramping constraints
set_device_model!(template_uc, ThermalMultiStart, ThermalBasicUnitCommitment)
set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
set_device_model!(template_uc, HydroDispatch, HydroDispatchRunOfRiver) 
set_device_model!(template_uc, PowerLoad, StaticPowerLoad)
set_device_model!(template_uc, storage_model)
set_service_model!(template_uc, ServiceModel(VariableReserve{ReserveUp}, RangeReserve; use_slacks = true,))
set_service_model!(template_uc, ServiceModel(VariableReserve{ReserveDown}, RangeReserve; use_slacks = true,))
# No device model for lines and transformers because it is a copper plate.
# Activate slacks on reserves to try to solve infeasibility issues. Didnt do it but I am leaving them anyway. 

################## Simulation Setup ####################
# Define an optimizer instance upfront. 
mip_gap = 0.1
solver = optimizer_with_attributes(
                Xpress.Optimizer,
                "MIPRELSTOP" => mip_gap) # Relaxed MIP gap (ratioGap) setting to improve speed.
# Relative MIP gap tolerance of 10% (coarse). The solver may stop earlier for speed.  
# Create Decision Model. 
problem = DecisionModel(
                        template_uc, 
                        sys;
                        name = "UC",
                        optimizer = solver,       
                        optimizer_solve_log_print = true,
                        calculate_conflict = true,
                        store_variable_names = true,
)

# Set up time variables. 
# initial_date = "2018-08-01"
# start_time =DateTime(string(initial_date,"T00:00:00"))
# steps_sim = 1 # Number of days to simulate
# current_date = string(today())

# problem = DecisionModel(template_uc, sys; optimizer = solver, horizon = Hour(24)) # Previously defined, but it works with this? 
timestamp = Dates.format(now(), "yyyy-mm-dd_HHMMSS")
out_dir = joinpath(@__DIR__, "..", "simulation_debug", "singlestage_$(timestamp)")
isdir(out_dir) || mkpath(out_dir)
build!(problem; output_dir = out_dir)
solve!(problem)

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