using HDF5 
using Logging 


# log_file = "Non_Convex.txt"

# ### Pull in SCED Data
# include("file_pointers.jl")
# include("system_build_functions.jl")
# #ercot_fuel, sced_data = get_sced_data(thermal_sced_h5_file, "DDPEC_CC1_2")




# function median_energy(sced_data)
# # PiecewiseIncrementalCurve
#     piecewise_median_values_x = []
#     tranche_count = get_tranche_count(sced_data)
#     for i in 1:tranche_count
#         column_data = sced_data[:, Symbol("Submitted_TPO_MW$i")]
#         filtered_x = [filter(!isnan, column_data)]
#         median_value_x = median!(filtered_x)
#         push!(piecewise_median_values_x, median_value_x)
#         #pushfirst!(piecewise_median_values_x, 0)
#     end
#     return piecewise_median_values_x
#             if !issorted(piecewise_median_values_x)
#                 println("Non convex SCED Data")
#                 @info ("Non convex SCED Data")
#             end
# end




# function median_prices(sced_data)
# median_values_m = []
# tranche_count = get_tranche_count(sced_data)
# for i in 1:tranche_count
#     column_data = sced_data[:, Symbol("Submitted_TPO_Price$i")]
#     filtered_m = [filter(!isnan, column_data)]
#     median_value_m = median!(filtered_m)
#     push!(median_values_m, median_value_m)    
# end  
# return median_values_m
# println(median_values_m)
# end

# # function cost_from_LSL_HSL(sced_data)
# #     return sced_data
# #     LSL = sced_data[:, "LSL"]
# #     HSL = sced_data[:, "HSL"]
# #     get_linear_model(sced_data, LSL, HSL)
# # end


# function build_curve(sced_data)
#     my_median_energy = median_energy(sced_data)
#     print(my_median_energy)
#     my_median_price = median_prices(sced_data)
#     println(my_median_price)
#     bad_sced_data = []
#     med_energ = median_energy(sced_data)
#     med_pric = median_prices(sced_data)
#     if !issorted(med_energ)
#         push!(bad_sced_data, get_name(gen))
#     end
#     # Log the bad_sced_data if it's not empty
#     if !isempty(bad_sced_data)
#         open("bad_data_energ_pric.txt", "a") do file
#             for data in bad_sced_data
#                 # Join the elements of med_energ into a string to represent the vector
#                 med_energ_str = join(string.(med_energ), ", ") 
#                 med_pric_str = join(string.(med_pric), ", ") 
#                  # Converts elements to string and joins them
#                 # Write the data and the vector to the file in one line
#                 println(file, "Bad Data: $data, energy: $med_energ_str")
#                 println(file, "Bad Data: $data, energy: $med_pric_str")
#             end
#         end
#     end
#     start_up_value, no_load_value = start_up_no_load(sced_data)
#     pushfirst!(my_median_energy, no_load_value)

#     if length(my_median_energy) > 3 && issorted(my_median_energy)
#         value_curve = PiecewiseIncrementalCurve(no_load_value, my_median_energy, my_median_price)
#         cost_curve = CostCurve(value_curve)
#         s_u = 0.0
#         shut_down = 0.0
#         fixed = 0.0
#         operation_cost = ThermalGenerationCost(cost_curve, fixed, s_u, shut_down)
#         return operation_cost
#     elseif length(my_median_energy) == 2 && issorted(my_median_energy)
#         value_curve = LinearCurve(LSL, my_median_price)
#         cost_curve = CostCurve(value_curve)
#         s_u = 0.0
#         shut_down = 0.0
#         fixed = 0.0
#         operation_cost = ThermalGenerationCost(cost_cost, fixed, s_u, shut_down)
#     else
#         operation_cost = ThermalGenerationCost(nothing)
#         return operation_cost 
#     end
#     return no_load, start_up
# end

function start_up_no_load(sced_data)
    no_load = median!(sced_data[:, "LSL"])
    start_up = make_start_up_costs(sced_data) 
    return start_up, no_load
end

# function bad_sced_data(sced_data)
#     bad_sced_data = []
#     med_energ = median_energy(sced_data)
#     if !issorted(med_energ)
#         push!(bad_sced_data, get_name(gen))
#     end
#     return bad_sced_data
# end


############################################ NEW APPROACH ########################################################

## convert all data to input output
function get_all_x_m_values(sced_data::DataFrame)
tranche_count = get_tranche_count(sced_data)
x_values = []
m_values = []
for i in 1:tranche_count
    m_column_data = sced_data[:, Symbol("Submitted_TPO_Price$i")]
    filtered_m = replace(m_column_data, NaN=>missing)
    push!(m_values, filtered_m)
    x_column_data = sced_data[:, Symbol("Submitted_TPO_MW$i")]
    filtered_x = replace(x_column_data, NaN=>missing)
    push!(x_values, filtered_x)
end
return x_values, m_values, tranche_count
end

function get_x_m_matrix(sced_data::DataFrame)
    x_values, m_values, tranche_count = get_all_x_m_values(sced_data)
    m_matrix = Float64[]
    for i in 1:tranche_count
        if i ==1 
            m_matrix = m_values[i]
        else
            m_matrix = hcat(m_matrix, m_values[i])
        end
    end
    x_matrix = Float64[]
    for i in 1:tranche_count
        if i ==1 
            x_matrix = x_values[i]
        else
            x_matrix = hcat(x_matrix, x_values[i])
        end
    end
    return x_matrix, m_matrix
end

function gen_coords(x_coords::Vector{<:Union{Missing, Float64}})
    filtered_x = filter(x -> !ismissing(x), x_coords)
    return filtered_x
end

function price_coords(m_coords::Vector{<:Union{Missing, Float64}})
    filtered_m = filter(x -> !ismissing(x), m_coords)
    return filtered_m
end

function piecewise_value_curve(sced_data::DataFrame)
    x_matrix, m_matrix = get_x_m_matrix(sced_data)
    value_curves = []
    points = x_matrix[:, 1]
    LSL = minimum(sced_data[sced_data.LSL .> 1, :][!, "LSL"]) 
    for i in 1:length(points)
        x_coords = x_matrix[i, :]
        x_coords = Vector{Float64}(gen_coords(x_coords))
        m_coords = m_matrix[i, :]
        m_coords = Vector{Float64}(price_coords(m_coords))
        
        if length(x_coords) > 1
            if LSL <= minimum(x_coords)
                pushfirst!(x_coords, LSL)  # Push to the front if LSL is the smallest
            else
                insert_pos = findfirst(x -> x > LSL, x_coords)
                if isnothing(insert_pos)
                    push!(x_coords, LSL)  # Append to the end if no position is found
                else
                    insert!(x_coords, insert_pos, LSL)
                end
            end
        end  # End of the if length(x_coords) > 1 block
        
        if length(x_coords) >= 2 && length(m_coords) >= 1 
            if "Min_Gen_Cost" in names(sced_data)
                min_gen_cost = sced_data[:, "Min_Gen_Cost"]
                min_gen = minimum(min_gen_cost[.!isnan.(min_gen_cost)])
                value_curve = PiecewiseIncrementalCurve(min_gen, x_coords, m_coords)
                push!(value_curves, value_curve)
        else 
            value_curve = PiecewiseIncrementalCurve(0, x_coords, m_coords)
            push!(value_curves, value_curve)
        end
        elseif length(x_coords) == 1 && length(m_coords) == 1
            value_curve = LinearCurve(x_coords[1], m_coords[1])
            push!(value_curves, value_curve)
        end  # End of the if-elseif block
    end  # End of the for loop
    
    return value_curves
end

function input_output(sced_data::DataFrame)
    value_curves = piecewise_value_curve(sced_data)
    num_curves = length(value_curves)
    io_curves = []
    total_x_points = []
    for i in 1:num_curves
        piecewise_curve = value_curves[i]
        if piecewise_curve isa PiecewiseIncrementalCurve
            io_curve = InputOutputCurve(piecewise_curve)
            all_xs = get_x_coords(io_curve)
            append!(total_x_points, all_xs)
            push!(io_curves, io_curve)
         end
        
    end
return io_curves, total_x_points
end

function y_values(sced_data::DataFrame)
piecewises, all_xs = input_output(sced_data)
value_curves = piecewise_value_curve(sced_data)
all_xs = unique(sort(all_xs))
ys = []
for current_x in all_xs
    current_y = []
        for curve in piecewises
            append!(current_y, lookup_point(curve, current_x))
            end
            push!(ys, current_y)
end
return ys, all_xs
end

function lookup_point(curve::PiecewisePointCurve, x_coord::Float64)
    # Get the x-coordinates and y-coordinates from the curve
    x_vals = get_x_coords(curve)
    y_vals = get_y_coords(curve)
    # Check if x_coord is within the valid range of x values
    if x_coord > maximum(x_vals)
        # If x_coord is larger than the maximum x value, return Ing
        return Inf  
    end
    # Find the points surrounding x_coord
    for i in 1:length(x_vals) - 1
        # println(i)
        if x_vals[i] <= x_coord && x_coord <= x_vals[i+1]
            # Linear interpolation between the two points
            # slope = (y_vals[i+1] - y_vals[i]) / (x_vals[i+1] - x_vals[i])
            # y_point = y_vals[i] + slope * (x_coord - x_vals[i])
            y_point = y_vals[i]+((y_vals[i+1]-y_vals[i])/(x_vals[i+1]-x_vals[i]))*(x_coord - x_vals[i])
            return y_point  # Return the interpolated y-value
        end
        if x_coord <= minimum(x_vals)
            # If x_coord is less than the minimum x value, return the first y-value (extrapolation or clamping)
            y_point = y_vals[i]+((y_vals[i+1]-y_vals[i])/(x_vals[i+1]-x_vals[i]))*(x_coord - x_vals[i])
            return y_vals[1]  
        end
    end
end

function median_y_values(sced_data::DataFrame)
    ys, all_xs = y_values(sced_data)
    y_nums = length(ys)
    ys_valids = []
    for i in 1:y_nums 
        valid_indices = findall(x -> !isnan(x), ys[i])
        ys_valid = ys[i][valid_indices]
        if !isempty(ys_valid)
        push!(ys_valids, ys_valid)
        end
    end
    y_nums = length(ys_valids)
    y_median_values = []
    for i in 1:y_nums
        y_median_value = median(ys_valids[i])
        push!(y_median_values, y_median_value)
    end
    #y_median_values = [median(ys[i]) for i in 1:length(ys)]
    #y_median_values = Vector{Float64}(filter_out_inf(y_median_values))
    y_median_values = Vector{Float64}(filter_out_inf(Vector{Float64}(y_median_values)))
    all_xs = Vector{Float64}(all_xs[1:length(y_median_values)])
    # if isnan(y_median_values[1])
    #     y_median_values = y_median_values[2:end]
    #     all_xs = all_xs[2:end]
    # end
    if "Min_Gen_Cost" in names(sced_data)
        min_gen_cost = sced_data[:, "Min_Gen_Cost"]
        fixed = min_gen_cost[.!isnan.(min_gen_cost)]
    else 
        fixed = 0
    end
    ppc_data = collect(zip(all_xs, y_median_values))
    ppc = PiecewisePointCurve(ppc_data)
    pic = IncrementalCurve(ppc)
    return pic, fixed
end

### Maybe don't need this ###################

function filter_out_inf(y_median_values::Vector{Float64})
    # Use filter to keep only finite numbers (not Inf or -Inf)
    return filter(isfinite, y_median_values)
end

function incremental_cost(sced_data::DataFrame)
    pic, fixed = median_y_values(sced_data)
    slopes = get_slopes(pic)
    xs = get_x_coords(pic)
    i = 1
    tolerance = 0.01
    while length(xs) > 10
        i = 1
        while i < length(slopes)
        # Check if the difference between consecutive slopes is smaller than the tolerance
        if abs(slopes[i+1] - slopes[i])*(xs[i+1]-xs[i]) < tolerance
            # Average the two slopes and delete the second slope
            slopes[i] = max(slopes[i], slopes[i+1])#(slopes[i] + slopes[i+1]) / 2
            deleteat!(slopes, i+1)
            deleteat!(xs, i+1)
        else
            # Move to the next pair if the difference is not small
            i += 1
        end
    end
    tolerance = tolerance + 10
end
    return xs, slopes
end

function build_thermal_cost(sced_data::DataFrame)
    if "Min_Gen_Cost" in names(sced_data)
        min_gen_cost = sced_data[:, "Min_Gen_Cost"]
        fixed = min_gen_cost[.!isnan.(min_gen_cost)]
        fixed_min = minimum(fixed)
    else 
        fixed_min = 0
    end
    ys, all_xs= y_values(sced_data)
    xs, slopes = incremental_cost(sced_data)
    var_cost = PiecewiseIncrementalCurve(fixed_min, xs, slopes )
    cost_curve = CostCurve(var_cost)
    start_up = start_up = make_start_up_costs(sced_data) 
    shut_down = 0.0 # maybe need to change
    op_cost = ThermalGenerationCost(cost_curve, fixed_min, start_up, shut_down)
    return op_cost
end


# include("C:/Users/acasavan/GitHub_Repos/market-bid-cost-scratch/plot_cost_functions.jl")
# Note: Commented out hardcoded path from another developer's machine


