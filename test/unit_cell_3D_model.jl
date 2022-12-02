using UnitCellGenerator
using UnitCellModelling
using FEPreProcessing
using AbaqusINPwriter
using Materials



vol_fraction:: Float64 = 0.50
eq_radius::Float64 = 5.0
nf::Int = 1
uc_side_length::Float64 = eq_radius*sqrt(π*(nf/vol_fraction))
asp_ratios::Vector{Float64} = [1.0, ]  #  1.0, 1.5, 2.0, 2.5, 3.0, 3.5,
ruc_bounds::NTuple{4, Float64} = ((-1.0, -1.0, 1.0, 1.0) .* (uc_side_length/2))
lz::Float64 = 2.0*eq_radius

working_dir = mkpath(joinpath(@__DIR__, "tests_output"))
try
	# ============================================
	#       UNIT CELL GENERATION
	# ============================================   
	inclusions_data::Dict{String, Matrix{Float64}} = Dict{String, Matrix{Float64}}(
		"Circle" => [0.0 0.0 eq_radius]
	)
	# ============================================
	#       MODELLING and MESHING in GMESH
	# ============================================
	udc_3d = UnitCellModelling.UDC3D(
		UnitCellModelling.BBox3D(
			ruc_bounds[1], ruc_bounds[2], -0.5*lz,
			ruc_bounds[3], ruc_bounds[4], 0.5*lz,
		),
		inclusions_data,
	)
	ruc_model_data = make_unit_cell_model(
		udc_3d,
		mesh_periodicity=true,
		element_types=(:C3D6, :C3D8),
		geom_export_paths=(),
		extr_dir_num_ele=Int64[10,],
		extr_dir_cum_heights=Float64[1.0,],
		extr_dir_recombine_ele=true,
		min_ele_size_factor=1/10,  #FIXME
		max_ele_size_factor=1/5,
		mesh_opt_algorithm="Netgen",
		show_mesh_stats=true,
		show_rve=false,
	)
	# ============================================
	#       Write ABAQUS inp file(s)
	# ============================================
	
	inp_file_options = Dict(
		:id => "RVE",
		:req_properties => ["E11_3D", "E22_3D",  "E33_3D", "CTE_3D"],  # "G12_3D", "G13_3D", "G23_3D",
		:model_name => "MODEL",
		:job_name => "JOB",
		:model_summary => "",
		:pbc => true,  # if periodic boundaric conditions are applied
		:matrix_material => Materials.IsotropicMaterial(tag="AluminiumMatrix", E=68.3e09, nu=0.30, alpha=23.0e-06),
		:inclusions_material => Materials.IsotropicMaterial(tag="BoronFiber", E=379.3e09, nu=0.10, alpha=8.10e-06),
		:strain_values => Dict(),
		:step_times => (1.0, 0.25, 1e-05, 0.25),  # total, init, min, max
		:field_nor_mech => ("U",),
		:field_nor_thermal => ("NT", "RFL"),
		:field_eor_mech => ("E", "S", "IVOL", "SENER"),
		:field_eor_thermal => ("HFL", "TEMP", "IVOL",),
		:nlgeom => false,
		:max_far_field_strain => 0.01,
		:init_temp => 100.0,
		:trans_thermal_analysis => false,
		:eps => sqrt(eps()),
	)
	ruc_model_data["mesh_data"]["ntags"] = ruc_model_data["mesh_data"]["all_node_tags"]
	ruc_model_data["mesh_data"]["ncoor"] = ruc_model_data["mesh_data"]["all_node_coordinates"]
	
	
	matrix_phase = MaterialPhase(
		"Matrix",
		inp_file_options[:matrix_material],
		ruc_model_data["mesh_data"]["matrix_element_connectivity"]
	)
	inclusion_phase = MaterialPhase(
		"Inclusion",
		inp_file_options[:inclusions_material],
		ruc_model_data["mesh_data"]["inclusions_element_connectivity"]
	)
	
	ruc_model_data["mesh_data"]["npairs"] = FEPreProcessing.make_rve_node_pairs(
		ruc_model_data["mesh_data"]["ntags"],
		ruc_model_data["mesh_data"]["ncoor"],
	)
	
	ruc_model_data["phases"] = [matrix_phase, inclusion_phase]
	
	write_3D_rve_inp(
		ruc_model_data,
		inp_file_options,
		working_dir,
		verbose = 1,
		add_abs_paths=true,
	)
catch e
	println("ERROR:", e)
	showerror(stdout, e, catch_backtrace())
end







