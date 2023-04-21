
function get_uc_model_data(
    bbox::Tuple{Vararg{Float64}},
    incl_data::Dict{String, Matrix{Float64}},
	options::Dict{Symbol, Any},
)::Dict{String, Any}
    #
    rve = if length(bbox)==4
        UnitCellModelling.UDC2D(UnitCellModelling.BBox2D(bbox...,), incl_data)
    elseif length(bbox)==6
        UnitCellModelling.UDC3D(UnitCellModelling.BBox3D(bbox...,), incl_data)
    else
        throw(ErrorException("Invalid size of bbox"))
    end
    #

    #
	rve_model_data = make_unit_cell_model(
		rve,
		mesh_periodicity = options[:pbc],
		element_types = options[:fe_type],
		geom_export_paths = options[:geom_export_paths],
		extr_dir_num_ele = Int[options[:num_thickness_dir_ele],],
		extr_dir_cum_heights = Float64[1.0,],
		extr_dir_recombine_ele = options[:extr_dir_recombine_ele],
		min_ele_size_factor = options[:min_ele_size_factor],
		max_ele_size_factor = options[:max_ele_size_factor],
		mesh_opt_algorithm = "Netgen",
		node_renum_algorithm = "RCM",
		show_mesh_stats = options[:show_mesh_stats],
		show_rve = options[:show_rve],
	)
    #
	rve_model_data["mesh_data"]["ntags"] = rve_model_data["mesh_data"]["all_node_tags"]
	rve_model_data["mesh_data"]["ncoor"] = rve_model_data["mesh_data"]["all_node_coordinates"]
    #
	matrix_phase = MaterialPhase(
		"Matrix",
		options[:matrix_material],
		rve_model_data["mesh_data"]["matrix_element_connectivity"],
	)
	inclusion_phase = MaterialPhase(
		"Inclusion",
		options[:inclusions_material],
		rve_model_data["mesh_data"]["inclusions_element_connectivity"],
	)
    #
	rve_model_data["mesh_data"]["npairs"] = FEPreProcessing.make_rve_node_pairs(
		rve_model_data["mesh_data"]["ntags"],
		rve_model_data["mesh_data"]["ncoor"],
	)

	rve_model_data["phases"] = [matrix_phase, inclusion_phase]
	return rve_model_data
end

"""
	"RVE_DIMENSIONS", "COMMON_FILES_DIR", "INP_OPTIONS"
"""
function write_3D_rve_inp(
    bounding_box::Tuple{Vararg{Float64}},
    inclusions_data::Dict{String, Matrix{Float64}};
    options::Dict{Symbol, Any}=Dict{Symbol, Any}(),
	verbose::Int = 0,
	add_abs_paths::Bool = false,
)
    #
    # getting the default options
    for (a_key, a_value) in DEAFULT_RVE_INP_FILE_OPTIONS
        if !(a_key in keys(options))
            options[a_key] = a_value
        end
    end
    #
    # getting the unit cell model data
    uc_data = get_uc_model_data(bounding_box, inclusions_data, options)
	# ========================
	#   Preliminaries
	# ========================
	global RVE_DIMENSIONS = uc_data["side_lengths"]
	mesh_data = uc_data["mesh_data"]
	material_phases = uc_data["phases"]
	#
	RVE_ID::String = isempty(options[:id]) ? "RVE" : options[:id]
	assembly_name::String = :assembly_name in keys(options) ? options[:assembly_name] : "ASSEMBLY-1"
	part_name::String = RVE_ID * "-part"
	instance_name::String = RVE_ID * "-instance"
	#
	global INP_OPTIONS = options
	global BASE_DIR = options[:root_dir]
	global COMMON_DATA_DIR = joinpath(BASE_DIR, RVE_ID * "_inp_files_common_data")
	global ABS_PATH = add_abs_paths
	#
	rm(COMMON_DATA_DIR; force = true, recursive = true)  # removes the cotents of the exisiting inp_files dir
	COMMON_DATA_DIR = mkpath(COMMON_DATA_DIR)
	#
	verbose > 0 ? println("> writing common data of input files,") : ""
	#
	# ============================
	#   Writing Common Data
	# ============================
	verbose > 0 ? println(">> writing nodal information,") : ""
	nodal_info_file = write_nodes_info(mesh_data["ntags"], mesh_data["ncoor"])
	verbose > 0 ? println(">> writing element information,") : ""

	eldata_files = Dict{String, Dict{String, String}}(
		a_phase.tag => write_felset_info(a_phase.econn, a_phase.tag) for a_phase in material_phases
	)  # {"phase_tag@Str" => {"phase_tag-gmsh_ele_type@Str" => "file_path@Str"}}
	phase_materials::Dict{String, String} = Dict{String, String}(a_phase.tag => a_phase.material.tag for a_phase in material_phases)
	# ================================
	#   Write inp files for each 
	#   of the required property
	# ================================
	set_names::Dict{String, Vector{String}} = Dict{String, Vector{String}}()
	for a_req_prop in INP_OPTIONS[:req_properties]
		inp_file_name = RVE_ID * "_" * a_req_prop * ".inp"
		inp_file_path = initialize_inp_file(inp_file_name)
		verbose > 0 ? println("Writing input file for $a_req_prop at $inp_file_path") : ""
		#
		analysis_type = get_analysis_type(a_req_prop)
		load_options = get_the_load_vector_3D(a_req_prop, uc_data["side_lengths"])
		# -------------------
		#    PART DATA
		# -------------------
		start_part_data(inp_file_path, part_name)
		add_nodal_data(inp_file_path, nodal_info_file)
		set_names = add_elements_data(
			inp_file_path, eldata_files, analysis_type;
			add_node_sets = true,
			add_sections = true,
			section_thickness = ",",
			materials = phase_materials,
		)
		finish_part_data(inp_file_path)
		# -------------------
		#    ASSEMBLY
		# -------------------
		start_assembly(inp_file_path, assembly_name)
		ref_points::Dict{String, NTuple{3, Float64}} = Dict{String, NTuple{3, Float64}}(
			"RP1" => (1.25 * RVE_DIMENSIONS[1], 0.0, 0.0),
			"RP2" => (0.0, 1.25 * RVE_DIMENSIONS[2], 0.0),
			"RP3" => (0.0, 0.0, 1.25 * RVE_DIMENSIONS[3]),
		)
		add_reference_points(inp_file_path, ref_points)
		add_instance_of_part(inp_file_path, instance_name, part_name)
		add_constraint_equations(
			inp_file_path, analysis_type, instance_name,
			mesh_data["npairs"], mesh_data["ntags"], mesh_data["ncoor"], ref_points,
		)
		finish_assembly(inp_file_path)
		# -------------------
		#    MATERIAL DATA
		# -------------------
		write_materials_data(inp_file_path, [a_phase.material for a_phase in material_phases])
		# ---------------------
		#    LOADS
		# ---------------------
		if (:init_temp in keys(load_options))
			predefined_fields = Dict(
				("$(instance_name).$(a_ns_name)" => load_options[:init_temp])
				for a_ns_name in set_names["node_set_names"]
			)  # Adding predefined_fields on all the nodes
			#
			add_predefined_fields(
				inp_file_path,
				"TEMPERATURE",
				predefined_fields,
			)
		end
		if (:final_temp in keys(load_options))
			load_options[:final_temp_fields] = Dict(
				("$(instance_name).$(a_ns_name)" => load_options[:final_temp])
				for a_ns_name in set_names["node_set_names"]
			)  # Adding final temp fields on all the nodes
		end
		# ---------------------
		#       STEP
		# ---------------------
		start_step(inp_file_path, analysis_type)
		add_boundary_conditions(inp_file_path, analysis_type, ref_points, load_options)
		#
		if analysis_type <: MechanicalAnalysis
			add_field_output_requests(inp_file_path, INP_OPTIONS[:field_nor_mech], INP_OPTIONS[:field_eor_mech])
		elseif analysis_type <: ThermalAnalysis
			add_field_output_requests(inp_file, INP_OPTIONS[:field_nor_thermal], INP_OPTIONS[:field_eor_thermal])
		else
			@warn "Skipping field output requests as un-identifiable analysis type $analysis_type is found."
		end
		#
		finish_step(inp_file_path)
	end
end


function get_the_load_vector_3D(
	prop::String,
	uc_side_lengths::NTuple{3, Float64},
)::Dict{Symbol, Any}
	#
	load_vector::Dict{Symbol, Any} = Dict{Symbol, Any}()
	#
	lx, ly, lz = uc_side_lengths
	ux = INP_OPTIONS[:max_far_field_strain] * lx
	uy = INP_OPTIONS[:max_far_field_strain] * ly
	uz = INP_OPTIONS[:max_far_field_strain] * lz
	load_vector[:rel_disp_matrix] = [0.0 0.0 0.0; 0.0 0.0 0.0; 0.0 0.0 0.0]
	load_vector[:rel_temp_vector] = [0.0; 0.0; 0.0]
	load_vector[:apply_field_temp] = false
	if prop == "E22_3D"
		load_vector[:rel_disp_matrix][1, 1] = ux
	elseif prop == "E33_3D"
		load_vector[:rel_disp_matrix][2, 2] = uy
	elseif prop == "E11_3D"
		load_vector[:rel_disp_matrix][3, 3] = uz
	elseif prop in ("G31_3D", "G13_3D")
		load_vector[:rel_disp_matrix][2, 3] = uz
		load_vector[:rel_disp_matrix][3, 2] = uy
	elseif prop in ("G12_3D", "G21_3D")
		load_vector[:rel_disp_matrix][1, 3] = uz
		load_vector[:rel_disp_matrix][3, 1] = ux
	elseif prop in ("G23_3D", "G32_3D")
		load_vector[:rel_disp_matrix][2, 1] = ux
		load_vector[:rel_disp_matrix][1, 2] = uy
	elseif prop == "CTE_3D"
		load_vector[:apply_field_temp] = true
		load_vector[:init_temp] = 0.0
		load_vector[:final_temp] = 100.0
	elseif prop == "K22_3D"
		load_vector[:rel_temp_vector][1] = lx  # in order to give unit gradient
	elseif prop == "K33_3D"
		load_vector[:rel_temp_vector][2] = ly  # in order to give unit gradient
	elseif prop == "K11_3D"
		load_vector[:rel_temp_vector][3] = lz  # in order to give unit gradient
	end
	return load_vector
end



function write_2D_unit_cell_inp(
	uc_data::Dict{String, Any},
	options::Dict,
	dir::String;
	verbose::Int = 0,
)
	# ========================
	#   Preliminaries
	# ========================
	lx, ly = uc_data["side_lengths"]
	mesh_data = uc_data["mesh_data"]
	ref_points::Dict = Dict(
		"RP2" => (1.25 * lx, 0.0, 0.0),
		"RP3" => (0.0, 1.25 * ly, 0.0),
	)
	#
	id = options[:id]
	required_properties = options[:req_properties]
	max_strain = options[:max_far_field_strain]
	job_name = options[:job_name]
	model_name, model_summary = options[:model_name], options[:model_summary]
	part_name::String = :part_name in keys(options) ? options[:part_name] : "PART-1"
	assembly_name::String = :assembly_name in keys(options) ? options[:assembly_name] : "ASSEMBLY-1"
	instance_name::String = :instance_name in keys(options) ? options[:instance_name] : "INSTANCE-1"
	#
	inp_files_dir = mkpath(joinpath(dir, id * "_inp_files"))
	#
	verbose > 0 ? println("> writing common data of input files,") : ""
	# ========================
	#   Nodal information
	# ========================
	verbose > 0 ? println(">> writing nodal information,") : ""
	nfile = write_nodes_info(
		mesh_data["ntags"],
		mesh_data["ncoor"],
		inp_files_dir,
	)
	# ========================
	#   Elements information
	# ========================
	verbose > 0 ? println(">> writing element information,") : ""
	econn_files = Dict{String, Dict{String, String}}()
	material_phases = uc_data["phases"]
	for a_phase in material_phases
		econn_files[a_phase.tag] = write_felset_info(
			a_phase.econn,
			a_phase.tag,
			inp_files_dir,
		)
	end

	# ================================
	#   Write inp files for each 
	#   of the required property
	# ================================
	for a_req_prop in required_properties
		inp_file = create_new_file(joinpath(dir, id * "_" * a_req_prop * ".inp"))
		analysis_type = get_analysis_type(a_req_prop)
		verbose > 0 ? println("Writing input file for $a_req_prop at $inp_file") : ""
		options = get_the_load_vector_2D(a_req_prop, options, (max_strain * lx, max_strain * ly))
		# ==============================
		#       Start of INP file
		# ==============================
		initialize_inp_file(inp_file, job_name, model_name, model_summary)
		# -------------------
		#    PART DATA
		# -------------------
		start_part_data(inp_file, part_name)
		add_nodal_data(inp_file, nfile)
		for a_phase in material_phases
			a_phase_tag = a_phase.tag
			add_elsets_data(inp_file, econn_files[a_phase_tag], analysis_type)
			add_elset_from_elsets(inp_file, econn_files[a_phase_tag], a_phase_tag * "-elements")
			add_nset_from_elsets(inp_file, a_phase_tag * "-elements", a_phase_tag * "-nodes")
			add_solid_section(inp_file, a_phase_tag * "-elements", a_phase.material.tag, a_phase_tag, add_unit_thickness = true)
		end
		finish_part_data(inp_file)
		# -------------------
		#    ASSEMBLY
		# -------------------
		start_assembly(inp_file, assembly_name)
		add_instance_of_part(inp_file, instance_name, part_name)
		add_reference_points(inp_file, ref_points)
		add_constraint_equations(
			inp_file, inp_files_dir, analysis_type, instance_name,
			mesh_data["npairs"], mesh_data["ntags"], mesh_data["ncoor"], ref_points)
		finish_assembly(inp_file)
		# -------------------
		#    MATERIAL DATA
		# -------------------
		write_materials_data(inp_file, [a_phase.material for a_phase in material_phases])
		# ---------------------
		#    LOADS
		# ---------------------
		if (:init_temp in keys(options))
			predefined_fields = Dict(
				("$(instance_name).$(a_phase.tag)-nodes" => options[:init_temp])
				for a_phase in material_phases
			)
			add_predefined_fields(
				inp_file,
				"TEMPERATURE",
				predefined_fields,
			)
		end
		# ---------------------
		#       STEP
		# ---------------------
		start_step(inp_file, analysis_type, options)
		add_boundary_conditions(inp_file, analysis_type, options, ref_points)
		#
		if analysis_type <: MechanicalAnalysis
			add_field_output_requests(inp_file, options[:field_nor_mech], options[:field_eor_mech])
		elseif analysis_type <: ThermalAnalysis
			add_field_output_requests(inp_file, options[:field_nor_thermal], options[:field_eor_thermal])
		else
			@warn "Skipping field output requests as un-identifiable analysis type $analysis_type"
		end
		#
		finish_step(inp_file)
	end
end



function get_the_load_vector_2D(
	prop::String,
	options::Dict{Symbol, Any},
	displacements::NTuple{2, Float64},
)
	options[:rel_disp_matrix] = [0.0 0.0; 0.0 0.0; 0.0 0.0]
	options[:rel_temp_vector] = [0.0; 0.0]
	options[:apply_field_temp] = false
	if prop in ["E22_2D"]
		options[:rel_disp_matrix][1, 1] = displacements[1]
	elseif prop in ["E33_2D"]
		options[:rel_disp_matrix][2, 2] = displacements[2]
	elseif prop in ["G23_2D"]
		options[:rel_disp_matrix][2, 1] = displacements[1]
		options[:rel_disp_matrix][1, 2] = displacements[2]
	elseif prop == "CTE_2D"
		options[:apply_field_temp] = true
		options[:init_temp] = 0.0
		options[:final_temp] = 100.0
	elseif prop == "K22_2D"
		options[:rel_temp_vector][1] = lx  # in order to give unit gradient
	elseif prop == "K33_2D"
		options[:rel_temp_vector][2] = ly  # in order to give unit gradient
	else
		@warn "Not updating BCs, check the required_properties in options."
	end
	return options
end




"""

# for a_phase in material_phases
#     a_phase_tag = a_phase.tag
#     add_elsets_data(inp_file, econn_files[a_phase_tag], analysis_type; add_node_sets=true)
#     # add_elset_from_elsets(inp_file, econn_files[a_phase_tag], a_phase_tag * "-elements")
#     # add_nset_from_elsets(inp_file, a_phase_tag * "-elements", a_phase_tag * "-nodes")
#     add_solid_section(inp_file, a_phase_tag * "-elements", a_phase.material.tag, a_phase_tag)
# end

"""
