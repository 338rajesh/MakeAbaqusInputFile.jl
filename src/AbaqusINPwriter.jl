module AbaqusINPwriter
    using DelimitedFiles
    using UnitCellModelling    
    using Materials
    import FEPreProcessing: FENodePair
    #
    include("utils.jl")
    include("gmsh2abaqus.jl")
    include("corebase.jl")
    include("auxbase.jl")
    include("historybase.jl")
    #
    include("apps/default_rve_inp_options.jl")
    include("apps/rve_inp.jl")


    export write_3D_rve_inp, MaterialPhase, write_2D_unit_cell_inp

end
