# Data Dimensionality Fix

## Problem
The scripts were attempting to read all solar time series data as 3D arrays, but only Day-Ahead files have a 3rd dimension (percentiles). Hour-Ahead and Real-Time files are 2D.

## Data Structure by Market Timeframe

### Day-Ahead (DA)
- **File Structure**: 3D array
- **Dimensions**: `(366, 36, 99)` = [days, hours, percentiles]
- **Keys**: `["Issue_index", "Percentile", "Power", "Step_index"]`
- **Percentile array**: `[1.0, 2.0, ..., 99.0]`
- **Usage**: Code extracts only 1st percentile for deterministic forecast

### Hour-Ahead (HA)
- **File Structure**: 2D array
- **Dimensions**: `(8760, 24)` = [hourly windows, forecast horizon points]
- **Keys**: `["Power", "times"]`
- **No 3rd dimension**: Direct deterministic forecasts

### Real-Time (RT)
- **File Structure**: 2D array
- **Dimensions**: `(105120, 24)` = [5-minute intervals, forecast horizon points]
- **Keys**: `["Power", "times"]`
- **No 3rd dimension**: Direct deterministic forecasts

## Changes Made

### make_hour_ahead_data.jl (Lines 186-201)
**Before:**
```julia
power_output = read(file, "Power")
peak_power = maximum(power_output[:, :, 1])  # Assumed 3D
normalized_power = power_output[ix, :, 1]    # Extracted "first scenario"
```

**After:**
```julia
power_output = read(file, "Power")
peak_power = maximum(power_output)           # 2D array
normalized_power = power_output[ix, :]       # Direct extraction
```

### make_real_time_data.jl (Lines 108-111)
**Before:**
```julia
power_output = read(file, "Power")[:, :, 50]  # Tried to extract 50th "scenario"
```

**After:**
```julia
power_output = read(file, "Power")            # 2D array, no indexing needed
```

## Why This Matters

1. **DA files** contain quantile regression outputs (99 percentiles representing forecast uncertainty)
2. **HA and RT files** contain single deterministic forecasts (no percentiles or scenarios)
3. The previous code was trying to access non-existent 3rd dimensions in HA/RT files
4. This would cause indexing errors: `BoundsError: attempt to access 2D array with 3D indexing`

## Verification

Run `julia scripts/understand_scenarios.jl` to see the actual file structures:
- DA: `Power: (366, 36, 99)`
- HA: `Power: (8760, 24)`
- RT: `Power: (105120, 24)`
