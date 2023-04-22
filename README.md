# ABAQUS input file (.inp) writer

A package for writing the ABAQUS input files directly using `julia` interface.

ABAQUS is a general-purpose computational tool to perform finite element analysis, but this package is designed (at least now) to analyse certain classes of problems. 


**At present, `.inp` files are wrritten for the following applications**

+ Homgenization of RVE with the following features
    + Periodic boundary conditions
    + Fibres with [cross-sections](https://github.com/338rajesh/UnitCellModelling.jl#acceptable-inclusion-shapes) as supported by UnitCellModelling.jl
    + 
    

## Installation

> Before starting installation, ensure that julia is added to the path. To check this, execute `julia`  in terminal or command prompt. If you get any error, then `julia` is not added to path properly. You can follow [these steps](https://julialang.org/downloads/platform/) for adding `julia` to the path.

From command prompt run [`install_maif.jl`](/install_maif.jl). This will install the all the necessary packages and then MakeAbaqusInputFile.jl at the end.
> Note: If you want to use different `gmsh`, please change accordingly in `install_maif.jl` file. But, it is recommended to keep it unchanged as in some version, we found that mesh periodicity is failing.

## Tutorial

See `tutorials` directory at the root of this package. For example, ABAQUS input file for homogenization of fibre-reinforced composites using 3D RVE can be prepared using `/tutorials/RVE_3D/prep_inp_file.jl`.

```julia
using MakeAbaqusInputFile

include("rve_inp_options.jl")

incl_data = Dict("CIRCLE" => [0.0 0.0 0.25])

bbox = (-0.5, -0.5, -0.1, 0.5, 0.5, 0.1,)

write_3D_rve_inp(
    bbox, 
    incl_data;
    options=INP_FILE_OPTIONS,
    verbose = 1,
    add_abs_paths=false,
)
```

`write_3D_rve_inp()` takes the following arguments

+ `bbox` bounding box of RVE as `Tuple` of six `Float64` values. It should be in the form of `(x_min, y_min, z_min, x_max, y_max, z_max)`.
+ `incl_data` is a Julia dictionary wherein key-value pairs are of `String` and `Matrix{Float64}` type. Keys is a fibre cross-section shape identifier and values are inclusion's positional information. The following table lists the possible shape identifiers and theur values.
    
    | Inclusion shape Identifier| Data Matrix Representation                                | Data matrix shape     |
    |---------------------------|-----------------------------------------------------------| ----------------------|
    | CIRCLE                    |       `[x  | y  | radius]`                                | (n, 3)                |
    | CAPSULE                   | `[x  | y  | theta  | smjx \| smnx]`                       | (n, 5)                |
    | ELLIPSE                   | `[x  | y  | theta  | smjx \| smnx]`                       | (n, 5)                |
    | RECTANGLE                 | `[x  | y  | theta  | smjx \| smnx \| c_radius]`           | (n, 6)                |
    | CSHAPE                    | `[x  | y  | theta  | ro ri \| alpha]`                     | (n, 6)                |
    | RPOLYGON                  | `[x  | y  | theta  | side_len \| c_radius \| num_sides]`  | (n, 6)                |
    | NLOBE                     | `[x  | y  | theta  | ro \| lobe_radius \| num_lobes]`     | (n, 6)                |
    | nSTAR                     | `[x  | y  | theta  | ro \| rb \| rt \| rbf \| num_tips]`  | (n, 8)                |
    ||||||

    > Note: `smjx` and `smnx` are semi-major and semi-minor axes lengths. Will update the details of geometry soon.

+ `options` is a Julia dictionary. Here, `INP_FILE_OPTIONS` is defined in `rve_inp_options.jl` that is placed in the same directory as `prep_inp_file.jl`. `INP_FILE_OPTIONS` contains user options which overwrite the [default options](/src/apps/default_rve_inp_options.jl). If you have messed up this user options file while editing, you can get a fresh copy of default options [here](/src/apps/default_rve_inp_options.jl).
+ `verbose` controls the amount of text printed while writing the input files (complete details will be added soon!)
+ add_abs_paths
Then, 


