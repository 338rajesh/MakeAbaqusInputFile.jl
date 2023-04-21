using Materials

DEAFULT_RVE_INP_FILE_OPTIONS = Dict(
	#
	# =========================================
	#		Preliminaries
	# =========================================
	#
	# The root directory or working directory, defaults to the script directory
	:root_dir => @__DIR__,
	#
	# =========================================
	#		Abaqus Job information
	# =========================================
	# 
	# Model Identifier
	#
	:id => "RVE",
	#
	# Abaqus model name
	#
	:model_name => "MODEL",
	#
	# Abaqus job name
	#
	:job_name => "JOB",
	#
	# Model Summary
	#
	:model_summary => "",
	#
	# Required properties
	:req_properties => ["E11_3D", "E22_3D",  "E33_3D", "G23_3D", "G31_3D", "G12_3D", "CTE_3D"],
	#
	# =========================================
	#		Modelling and meshing in gmsh
	# =========================================
	#
	# Minimum and maximum desirable element sizes
	# element size = element size factor * smallest  unit cell side length 
	:min_ele_size_factor => 0.5,
	:max_ele_size_factor => 0.7,
	#
	# If periodic boundary conditions are required
	:pbc => true,
	#
	# Number of elements in the thickness direction
	:num_thickness_dir_ele => 5,
	#
	# If the mesh stats to be displayed after meshing step
	:show_mesh_stats => true,
	#
	# switch for visualising the model in gmsh
	:show_rve => false,
	#
	# Finite element types; for possible options, see :  
	:fe_type => (:C3D8, :C3D6),
	#
	# Geometry export paths
	:geom_export_paths => (),
	#
	# If tet elements have to be recombined in the z-direction
	# If true, creates hex or prism elements in the thickness direction 
	:extr_dir_recombine_ele => true,
	#
	# =========================================
	#		Select Phase material information
	# =========================================
	#
	# Matrix and fibre Materials
	#
	:matrix_material => Materials.IsotropicMaterial(
		tag="Matrix-Material",
		E=3.35e09,
		nu=0.35,
	),
	:inclusions_material => Materials.IsotropicMaterial(
		tag="Fibre-Material",
		E=379.3e09,
		nu=0.1,
    ),
	#
	# =========================================
	#		Select Phase material information
	# =========================================
	#
	# Strain Values
	:strain_values => Dict(),
	#
	# Step times in the order of total, init, min, max
	:step_times => (1.0, 0.25, 1e-05, 0.25),
	#
	# Mechanical field nodal output requests
	:field_nor_mech => ("U",),
	#
	# Thermal field nodal output requests
	:field_nor_thermal => ("NT", "RFL"),
	#
	# Mechanical field elemental output requests
	:field_eor_mech => ("E", "S", "IVOL", "SENER"),
	#
	# Thermal field elemental output requests
	:field_eor_thermal => ("HFL", "TEMP", "IVOL",),
	#
	# Nonlinear analysis
	:nlgeom => false,
	#
	# Maximum farfield strain
	:max_far_field_strain => 0.01,
	# 
	# Initial Temperature
	:init_temp => 0.0,
	#
	# Transient thermal analysis
	:trans_thermal_analysis => false,
	#
	# Small parameter used during the modelling. For example, while ensuring the 
	# periodicity condition
	:eps => sqrt(eps()),
	#
	# Reference temperature
	:ref_temp => 300.0,
)