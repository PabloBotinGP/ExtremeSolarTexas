# Questions

## PowerSystems TapTransformer type
### References
- Documentation:
    https://nrel-sienna.github.io/PowerSystems.jl/stable/model_library/generated_TapTransformer/#TapTransformer
- My code: 
    scripts/system_build_functions.jl:256
### Context
- In my original model, transformers were created with rating = 2000.0 (MVA).
- The new beta version requires both base_power and rating parameters. 
- I am trying to understand how do I set these parameters. 
- My guess is that the base_power is inherited from the system's basePower variable and the rating must be set in relation to that. 
- But this is just a guess and I will update this accordingly when I know. 
### Question
- Do you have documentation for #psy5? 
- Can you explain me the Tap Transformer's base_power - rating relationship? 

## Line
### Context
- Similar error, I included the base_voltage definition for when the bus did not exist and needs to be created. 
- Defined as the transmission line base_voltage (which is defined hen creating the line).
### Question
Verify whether this implementation logic is correct.

## Remove line
### Context
- Sometimes, before adding a PV plant, the line is removed using the remove_component function. 
- In some cases, this used to cause trouble because the line that was intended to be removed did not exist. 
### Question
- Why are we removing these lines? 
- Is this a good fix or shall I find a more fundamental fix? M






