using MakeAbaqusInputFile

include("rve_inp_options.jl")

incl_data = Dict("CIRCLE" => [0.0 0.0 0.25])

bbox = (-0.5, -0.5, -0.1, 0.5, 0.5, 0.1,)

write_3D_rve_inp(
	bbox,
	incl_data;
	options=RVE_INP_FILE_OPTIONS
)
