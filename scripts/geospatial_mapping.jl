using PowerSystems
using CSV
using DataFrames
using Plots

###################################### GeoSpatial Plotting #################


line_geo = CSV.read("line_coords_original.csv", DataFrame)
line_geo_dict = Dict{String, Dict{String, Any}}()
for row in eachrow(line_geo)
    name = row[:name]
    # Create a sub-dictionary with all fields *except* name
    sub_dict = Dict{String, Any}()
    for (col, val) in zip(names(row), row)
        if col != :name
            sub_dict[string(col)] = val
        end
    end
    # Assign the sub-dictionary to the name key
    line_geo_dict[name] = sub_dict
end

lines = collect(get_components(Line, sys_DA))
for line in lines
    name = get_name(line)
    if haskey(line_geo_dict, name)
    set_ext!(line, line_geo_dict[get_name(line)])
    end
end

trans = collect(get_components(Transformer2W, sys_DA))
for tran in trans
    name = get_name(tran)
    if haskey(line_geo_dict, name)
        set_ext!(tran, line_geo_dict[get_name(tran)])
    end
end

function parse_linestring(wkt::String)
    # Remove the "LINESTRING (" prefix and ")" suffix
    coords_str = replace(wkt, r"LINESTRING\s*\(|\)" => "")
    # Split into coordinate pairs
    coord_pairs = split(coords_str, ",")
    # Convert each pair to a tuple of floats
    coords = [Tuple(parse.(Float64, split(strip(pair)))) for pair in coord_pairs]
    return coords
end

geo_data = []
for line in lines
    name = get_name(line)
    bus_from = get_from(get_arc(line))
    if haskey(line_geo_dict, name)
        geo = parse_linestring(line_geo_dict[name]["line"])
        x1, y1 = geo[1]
        x2, y2 = geo[2]
        component = 1
        push!(geo_data, (
            component = component,
            name = name,
            x1 = x1,
            y1 = y1,
            x2 = x2,
            y2 = y2,
            rating = get_base_voltage(bus_from)
        ))
    end
end

for tran in trans
    name = get_name(tran)
    bus_from = get_from(get_arc(tran))
    if haskey(line_geo_dict, name)
        geo = parse_linestring(line_geo_dict[name]["line"])
        x1, y1 = geo[1]
        x2, y2 = geo[2]
        component = 2
        push!(geo_data, (component = 2, name = name, x1 = x1, y1 = y1, x2 = x2, y2 = y2, rating = get_base_voltage(bus_from)))
    end
end


using Plots

geo_df = DataFrame(geo_data)

# Assuming geo_df has columns: x1, y1, x2, y2
# Start with a blank plot
p = plot(; xlabel = "Longitude", ylabel = "Latitude", title = "Line Segments", size = [1000,1000])

# Loop over each row and plot a line
for row in eachrow(geo_df)
    coords = [(row["x1"], row["y1"]), (row["x2"], row[:"y2"])]
    (x1, y1) = coords[1]
    (x2, y2) = coords[2]
    if row["rating"] == 500 && row["component"] == 1
        plot!(p, [x1, x2], [y1, y2], seriestype = :line, marker = :none, lw = 2, label = false, linecolor = "pink")
    elseif row["rating"] == 230 && row["component"] == 1
        plot!(p, [x1, x2], [y1, y2], seriestype = :line, marker = :none, lw = 2, label = false, linecolor = "green")
    elseif row["rating"] == 115 && row["component"] == 1
        plot!(p, [x1, x2], [y1, y2], seriestype = :line, marker = :none, lw = 2, label = false, linecolor = "blue")
    elseif row["rating"] == 161 && row["component"] == 1
        plot!(p, [x1, x2], [y1, y2], seriestype = :line, marker = :none, lw = 2, label = false, linecolor = "purple")
    else 
        plot!(p, [x1, x2], [y1, y2], seriestype = :line, marker = :none, lw = 2, label = false, linecolor = "red")

    end
end

savefig("EST_transmission.png")

# Show the final plot
display(p)

