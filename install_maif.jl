using Pkg
#
# 
GMSH_VERSION = "4.11.0"
TEMP_DIR = mkpath(joinpath(@__DIR__, "temp_"))

print_header(st:: String) = printstyled(
	repeat("*", length(st))*"\n$(st)\n"*repeat("*", length(st))*"\n";
	color=:yellow,
)

# =================================
# 		Installing gmsh
# =================================
#
print_header("Installing gmsh.jl")
Pkg.add(url="https://github.com/338rajesh/gmsh.jl")
using gmsh
gmsh.setup.run(req_version=GMSH_VERSION, scratch_dir=TEMP_DIR)
#
# =================================
# 		Installing Materials.jl
# =================================
#
print_header("Installing Materials.jl")
Pkg.add(url="https://github.com/338rajesh/Materials.jl")
# =========================================
# 		Installing UnitCellModelling.jl
# =========================================
#
println("Installing UnitCellModelling.jl")
Pkg.add(url="https://github.com/338rajesh/UnitCellModelling.jl")
#
# =========================================
# 		Installing FEPreProcessing.jl
# =========================================
#
println("Installing FEPreProcessing.jl")
Pkg.add(url="https://github.com/338rajesh/FEPreProcessing.jl")
#
# =========================================
# 		Installing AbaqusINPwriter.jl
# =========================================
#
println("Installing MakeAbaqusInputFile.jl")
Pkg.add(url="https://github.com/338rajesh/MakeAbaqusInputFile.jl")
#
printstyled("\n\tInstallation is complete!\n\n"; color=:yellow)

