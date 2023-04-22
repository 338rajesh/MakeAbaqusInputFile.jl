# ABAQUS input file (.inp) writer

A package for writing the ABAQUS input files directly. 

ABAQUS is a general-purpose computational tool to perform finite element analysis, but this package is designed (at least now) to analyse certain classes of problems. 


<span style="color:blue">**At present, `.inp` files are wrritten for the following applications**</span>

+ Homgenization of RVE with the following features
    + Periodic boundary conditions
    + Fibres with [cross-sections](https://github.com/338rajesh/UnitCellModelling.jl#acceptable-inclusion-shapes) as supported by UnitCellModelling.jl
    + 
    

## Installation

> before starting ensure that 

+ 

<!-- 
Here, you find the methods/definitions for writing Abaqus input files directly for RVE based analysis.

> Still, the work and documentation are in progress!

This module works interms of different applications as list below

## RVE ABAQUS input file writer

It exports `write_3D_rve_inp()` function with the following arguments

+ `uc_data`:: `Dict{String, Any}`, it must contain the following information
    + `"side_lengths"`=> `NTuple{3, Float64}`, 
    + `"mesh_data"` => `Dict{String, Any}`,
        + `"ntags"` => `Vectror{Int}`
        + `"ncoor"` => `Matrix{Float64}`
    + `"phases"` => `Vector{MaterialPhase}`. Each element of `MaterialPhase` type contains a tag, material and element connectivity

+ `options`:: `Dict`
    + `:id` => `String`, "RVE" is default ID
        + `:req_properties` => `Vector{String}`
            + 3D-Thermo-elastic properties: 
                `["E11_3D", "E22_3D", "E33_3D", "G23_3D", "G31_3D", "G12_3D", "CTE_3D"]`
            + 3D-Thermal conduction properties:
                `["TC11_3D", "TC22_3D", "TC33_3D",]`
        + `:model_name` => `String`
        + `:job_name` => `String`
        + `:model_summary` => `String`
        + `:pbc` => `Bool`, Should it apply periodic boundary conditions
        + `:matrix_material` => `Materials.Material`
        + `:inclusions_material` => `Materials.Material`
        + `:strain_values` => `Dict()`
        + `:step_times` => `NTuple{4, Float64}`
        + `:field_nor_mech` => `NTuple{String}`
        + `:field_nor_thermal` => `NTuple{String}`
        + `:field_eor_mech` => `NTuple{String}`
        + `:field_eor_thermal` => `NTuple{String}`
        + `:nlgeom` => `Bool`
        + `:max_far_field_strain` => `Float64`
        + `:init_temp` => `Float64`
        + `:trans_thermal_analysis` => `Bool`
        + `:eps` => `Float64`
+ `dir`:: `String`
+ `verbose`:: `Int`, 0 by default for silent writing.
+ `add_abs_paths`:: `String`

#### NOTE:
+ `BASE_DIR::String` is used as root directory for writing inp files.
+ For every RVE analysis, a input file is required but the most of the information like nodal information, element connectivity..etc are repetitive. Hence, first the common part of the inp file is written in separate files and are called in every RVE analysis inp file. These are stored in `COMMON_DATA_DIR` =>`options[:id]*"_inp_files_common_data"` directory
    + By default, the contents of `COMMON_DATA_DIR` are removed before writing next set of equations.
    + `nodes_info.inp`, for writing nodal information
    + `Matrix-ele_conn_x.inp` where `x` denotes the type of element
    + `constraint_eqns_y.inp` where `y` denotes the type of analysis.

+ For writing nodal data,

## Finding Effective Elastic Tensor

## Finding Effective Thermal Expansion Coefficients

## Finding Effective Thermal Conduction Tensor
 -->