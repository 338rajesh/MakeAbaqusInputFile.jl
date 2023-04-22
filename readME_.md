# ABAQUS .inp file preparation using `AbaqusINPwriter.jl`

The `AbaqusINPwriter.jl` julia package prepares ABAQUS input files which can be run directly submitted to solver.

> **NOTE**: This package is developed for a very specific case of uni-directional composite materials RVE analysis. There are no plans in the past and future to extend this package for writing input files of generic problems.

## Installation

### Install the dependencies

+ Open Julia REPL
+ Enter into package manager by typing ] in REPL
+ `gmsh` installation
	+ `add https://github.com/338rajesh/gmsh.jl`
	+ Exit from the package manager by typing backspace
	+ In Julia REPL, execute the following to complete `gmsh` setup
		~~~
		using gmsh
		gmsh.setup.run(;req_version="4.9.4")  # replace 4.9.4 with version of interest
		~~~
		Re-start the REPL to finish the gmsh installation
+ Enter back into package manager by typing ] in REPL
+ `Materials.jl` package installation
	+ `add https://github.com/338rajesh/Materials.jl`
+ `FEPreProcessing.jl` package installation
	+ `add https://github.com/338rajesh/FEPreProcessing.jl`

### Installing `AbaqusINPwriter.jl`

+ `add https://github.com/338rajesh/AbaqusINPwriter.jl`


	

## Writing the `prep_inp_file.jl`

### adding packages
~~~
using UnitCellModelling
using FEPreProcessing
using Materials
using AbaqusINPwriter
~~~

## preparing RVE data

