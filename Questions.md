# Questions

## Functions in `system_build_functions.jl`
**Status** 
Open
**Question:** Why are the functions in `system_build_functions.jl` defined exclusively for this system?
**Context:**  
  - `build_system_script.jl` calls into the helper functions defined in `system_build_functions.jl`.  
  - These functions appear to be project-specific utilities that wrap or extend standard `PowerSystems.jl` functionality.  
  - These are the functions that are causing trouble. 
**Comment:**  
  - It feels like some of these functions (e.g., `add_line!`, `add_pv_plant!`) are general enough that they could be part of `PowerSystems`’ own API.  
  - In the PowerSystems documentation I found `add_component!()`, used by these, but not these project-specific helpers.  
--

## Practical Questions
--
**Question:**
- Is it possible to access to PS documentation directly from VSCode Studio? 
**Context:** 
- I currently look for the types/methods/etc directly on the website. 
**Comment:**
- Would make debugging an easier task. 
--

## Topic 
**Status** 
**Question:**
**Context:** 
**Comment:**
**Answer:**


