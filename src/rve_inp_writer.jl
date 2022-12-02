

function write_common_files(
    inp_dir::String,
    rve_model_data::Dict,
    instance_name::String,
    pbc::Bool=false,
    req_prop::Vector{String}=String[];
    small_param=1e-06
)::Dict
    common_inp_files = Dict()
    println("writing COMMON INP files..!")
    mesh_data = rve_model_data["mesh_data"]
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # ~~~~~~~ adding NODAL data    ~~~~
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nodal_data_inp = create_new_file(joinpath(inp_dir, "nodal_data.inp"))
    node_tags = mesh_data["all_node_tags"]
    node_coor = mesh_data["all_node_coordinates"]
    num_node_tags = length(node_tags)
    println("Type of node_coor: ", typeof(node_coor))

    nt_coor = Dict{Int, Vector{Float64}}((node_tags[i] => node_coor[:, i]) for i in 1:num_node_tags)
    open(nodal_data_inp, "a") do fp
        for (k, nt) in enumerate(node_tags)
            write(
                fp,
                """
      $nt, $(node_coor[1, k]), $(node_coor[2, k]), $(node_coor[3, k])
      """
            )
        end
    end
    common_inp_files["NODAL_DATA_INP"] = nodal_data_inp
    #
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # ~~~~~~~ adding matrix Element and nodal info ~~~~
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    mat_ele_sets::Dict{String,String} = Dict()
    for (elt, mat_ele_connectivity) in mesh_data["matrix_element_connectivity"]
        abaqus_ele_type = get_abaqus_element_type(elt)
        mat_ele_inp = create_new_file(joinpath(inp_dir, "matrix_ele_connectivity_$abaqus_ele_type.inp"))
        write_matrix_to_file(mat_ele_inp, mat_ele_connectivity)
        mat_ele_sets["MATRIX-ELEMENTS-SET-$abaqus_ele_type"] = mat_ele_inp
    end
    common_inp_files["MATRIX_ELE_CON_INP"] = mat_ele_sets
    #
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # ~~~~~~~ adding inclusions Element and nodal info ~~~
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    inc_ele_sets::Dict{String,String} = Dict()
    for (elt, inc_ele_connectivity) in mesh_data["inclusions_element_connectivity"]
        abaqus_ele_type = get_abaqus_element_type(elt)
        inc_ele_inp = create_new_file(joinpath(inp_dir, "inclusions_ele_connectivity_$abaqus_ele_type.inp"))
        write_matrix_to_file(inc_ele_inp, inc_ele_connectivity)
        inc_ele_sets["INCLUSIONS-ELEMENTS-SET-$abaqus_ele_type"] = inc_ele_inp
    end
    common_inp_files["INCLUSIONS_ELE_CON_INP"] = inc_ele_sets
    #
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # ~~~~~~~ adding constraint equations, if needed ~~~~~
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if pbc
        # req_prop = options[:req_properties]
        mech_prop = ["EXX", "EYY", "EZZ", "EYZ", "EZX", "EXY", "CTE"]
        thermal_prop = ["KXX", "KYY", "KZZ",]
        #
        mechanical_properties = length([i for i in req_prop for j in mech_prop if i==j]) > 0
        #
        thermal_properties = length([i for i in thermal_prop for j in thermal_prop if i==j]) > 0
        #
        if mechanical_properties
            constr_eqs_mech_inp = create_new_file(joinpath(inp_dir, "constr_eqs_mech.inp"))
            write_constraint_eq(
                constr_eqs_mech_inp,
                rve_model_data["all_node_pairs"],
                nt_coor,
                instance_name;
                eps=small_param,
                dof=(1, 2, 3)
            )
            common_inp_files["CONSTR_EQS_MECH_INP"] = constr_eqs_mech_inp
        end
        if thermal_properties
            constr_eqs_thermal_inp = create_new_file(joinpath(inp_dir, "constr_eqs_thermal.inp"))
            write_constraint_eq(
                constr_eqs_thermal_inp,
                rve_model_data["all_node_pairs"],
                nt_coor,
                instance_name;
                eps=small_param,
                dof=(11,)
            )
            common_inp_files["CONSTR_EQS_THERMAL_INP"] = constr_eqs_thermal_inp
        end
    end
    
    return common_inp_files
end







function add_ref_points(
    file_path::String,
    points::Dict{String,NTuple{3,Float64}};
    init_ref_node_num::Int64=1000000
)
    append_to_file(file_path,
        """
        **
        **
        **      REFERENCE POINTS
        **
        """)
    open(file_path, "a") do fp
        for (k, (rp_key, rp_loc)) in enumerate(points)
            write(fp,
                """
                *NODE
                $(init_ref_node_num+k-1), $(rp_loc[1]), $(rp_loc[2]), $(rp_loc[3])
                *NSET, NSET=$rp_key
                $(init_ref_node_num+k-1),
                """)
        end
    end
    append_to_file(file_path,
        """
        **
        **
        """)
end


function write_constraint_eq(
    file_path::String,
    node_pairs::Vector{FENodePair},
    ntc::Dict{Int, Vector{Float64}},
    instance::String;
    ref_points::NTuple{3,String}=("RP1", "RP2", "RP3"),
    eps::Float64=sqrt(eps()),
    dof::Tuple=Vararg{Int64}()
)
    append_to_file(file_path,
        """
        **
        ** **************************************
        **          PBC CONSTRAINT EQUATIONS
        ** **************************************
        **
        """)
    num_terms::Int = 0
    parent_nset_name::String = ""
    child_nset_name::String = ""
    for node_pair in node_pairs
        parent_nset_name = "NODE-$(node_pair.tag)-$(node_pair.p_nodetag)"
        child_nset_name = "NODE-$(node_pair.tag)-$(node_pair.c_nodetag)"
        dx, dy, dz = ntc[node_pair.p_nodetag] .- ntc[node_pair.c_nodetag]
        coeff = [abs(i) <= eps ? 0.0 : sign(i) for i in (dx, dy, dz)]
        num_terms = 2 + convert(Int64, sum(abs.(coeff)))
        #
        open(file_path, "a") do fp
            write(fp,
                """
                ** - - - - - - - - - - - - - - - - - - - - - 
                *NSET, NSET=$parent_nset_name, INSTANCE=$instance
                $(node_pair.p_nodetag)
                *NSET, NSET=$child_nset_name, INSTANCE=$instance
                $(node_pair.c_nodetag)
                ** CONSTRAINT: EQUATIONS NODES-$(node_pair.p_nodetag)-$(node_pair.c_nodetag)
                """)
            for a_dof in dof
                write(fp,
                    """
                    *EQUATION
                    $num_terms
                    $parent_nset_name, $a_dof, 1.0
                    $child_nset_name, $a_dof, -1.0
                    """)
                for (k, RP) in enumerate(ref_points)
                    if coeff[k] != 0.0
                        write(fp,
                            """
                            $RP, $a_dof, $(-1.0*coeff[k])
                            """)
                    end
                end
            end
        end
    end
end



function write_materials_data(
    file_path::String,
    materials_data::Vector,
)
    open(file_path, "a") do fp
        write(
            fp,
            """
            ** 
            **
            ** ***********************************
            **          MATERIAL DATA
            ** ***********************************
            **
            """
        )
        for a_material_data in materials_data
            write(
                fp,
                """
                *Material, name=$(a_material_data.tag)
                """
                )
            #
            field_names = fieldnames(typeof(a_material_data))
            if (:E in field_names) && (:nu in field_names)
                write(
                    fp,
                    """
                    *ELASTIC
                    $(a_material_data.E), $(a_material_data.nu)
                    """
                )
            end
            if :alpha in field_names
                write(
                    fp,
                    """
                    *EXPANSION
                    $(a_material_data.alpha),
                    """
                )
            end
            # if :cv in field_names
            #     write(
            #         fp,
            #         """
            #         *SPECIFIC HEAT
            #         $(a_material_data.cv),
            #         """
            #     )
            # end
            if :K in field_names
                write(
                    fp,
                    """
                    *CONDUCTIVITY
                    $(a_material_data.K),
                    """
                )
            end
        end
    end
    #
end


function write_an_abaqus_step(
    file_path::String,
    options::Dict,
    instance_name::String,
    analysis_type::String,
)
    #
    step_time_period, init_time_incr, min_time_incr, max_time_incr = options[:step_times]
    NLGEOM_FLAG = options[:nlgeom] ? "YES" : "NO"
    #
    if analysis_type == "MECHANICAL"
        analysis = "*STATIC"
    elseif analysis_type == "THERMAL"
        if !(options[:trans_thermal_analysis])
            analysis = "*HEAT TRANSFER, STEADY STATE, DELTMX=0"
        end
    end
    #
    append_to_file(file_path,
        """
        **
        **
        **
        ** ***********************************
        **          HISTORY DATA
        ** ***********************************
        ** 
        ** STEP: STEP-1
        ** 
        *STEP, NAME=STEP-1, NLGEOM=$NLGEOM_FLAG
        $(analysis)
        $init_time_incr, $step_time_period, $min_time_incr, $max_time_incr
        ** 
        ** BOUNDARY CONDITIONS
        ** 
        """
    )
    #
    if analysis_type == "MECHANICAL"
        append_to_file(file_path,
            """
            ** NAME: $(options[:id]) TYPE: DISPLACEMENT/ROTATION
            *BOUNDARY
            """)
        #
        rel_disp_matrix = options[:rel_disp_matrix]
        for jj in 1:3
            for ii in 1:3
                append_to_file(file_path,
                    """
                    RP$(jj), $(ii), $(ii), $(rel_disp_matrix[ii,jj])
                    """)
            end
        end
        #
        if options[:apply_field_temp]
            append_to_file(
                file_path,
                """
                ** 
                ** PREDEFINED FIELDS
                ** 
                ** NAME: PREDEFINED FIELD-1   TYPE: TEMPERATURE
                *TEMPERATURE
                $(instance_name).MATRIX-NODES-SET, $(options[:final_temp])
                $(instance_name).INCLUSIONS-NODES-SET, $(options[:final_temp])
                """
            )
        end
        #   
    elseif analysis_type == "THERMAL"
        open(file_path, "a") do fp
            write(
                fp,
                """
                ** NAME: $(options[:id])
                ** TYPE: TEMPERATURE
                *BOUNDARY
                """
            )
            for ii in 1:3
                write(
                    fp,
                    """
                    RP$(ii), 11, 11, $(options[:rel_temp_vector][ii])
                    """
                )
            end
        end
    end

    #

    #
    append_to_file(file_path,
        """
        ** 
        ** OUTPUT REQUESTS
        ** 
        *RESTART, WRITE, FREQUENCY=0
        ** 
        ** FIELD OUTPUT: F-OUTPUT-1
        ** 
        """)
    #
    field_nor_mech = options[:field_nor_mech]
    field_eor_mech = options[:field_eor_mech]
    field_nor_thermal = options[:field_nor_thermal]
    field_eor_thermal = options[:field_eor_thermal]

    if analysis_type == "MECHANICAL"
        field_nor = field_nor_mech
        field_eor = field_eor_mech
    elseif analysis_type == "THERMAL"
        field_nor = field_nor_thermal
        field_eor = field_eor_thermal
    end
    field_output_requests = (field_nor..., field_eor...)
    if isempty(field_output_requests)
        append_to_file(file_path,
            """
            *OUTPUT, FIELD, VARIABLE=PRESELECT
            """)
    else
        append_to_file(file_path,
            """
            *OUTPUT, FIELD
            """)
        if !isempty(field_nor)
            append_to_file(file_path,
                """
                *NODE OUTPUT
                $(["$i, " for i in field_nor]...)
                """)
        end
        if !(isempty(field_eor))
            append_to_file(file_path,
                """
                *ELEMENT OUTPUT, DIRECTIONS=YES
                $(["$i, " for i in field_eor]...)
                ** """)
        end
    end

    append_to_file(file_path,
        """
        **
        *END STEP""")
end




function write_rve_abaqus_inp(
    uc_model_data::Dict,
    options::Dict,
    working_dir::String,
)
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # ~~~~~~~          WRITING COMMON FILES          ~~~~~
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # common files:: nodal_data, matrix_ele_connectivity, inclusions_ele_connectivity, constr eqns if pbc is true
    id = options[:id]
    required_properties = options[:req_properties]
    inp_files_dir = mkpath(joinpath(working_dir, id * "_inp_files"))
    #
    instance_name::String = :instance_name in keys(options) ? options[:instance_name] : "INSTANCE-1"
    part_name::String = :part_name in keys(options) ? options[:part_name] : "PART-1"
    assembly_name::String = :assembly_name in keys(options) ? options[:assembly_name] : "ASSEMBLY-1"
    #
    common_inp_files = write_common_files(
        inp_files_dir,
        uc_model_data,
        instance_name,
        true,
        required_properties,
        small_param=options[:eps]
    )
    nodal_data_inp = common_inp_files["NODAL_DATA_INP"]
    matrix_ele_sets = common_inp_files["MATRIX_ELE_CON_INP"]
    incl_ele_sets = common_inp_files["INCLUSIONS_ELE_CON_INP"]
    #
    if options[:pbc]
        if !isempty(intersect(["EXX", "EYY", "EZZ", "GYZ", "GZX", "GXY", "CTE"], required_properties))
            constr_eqs_mech_inp = common_inp_files["CONSTR_EQS_MECH_INP"]
        end
        if !isempty(intersect(["KXX", "KYY", "KZZ"], required_properties))
            constr_eqs_thermal_inp = common_inp_files["CONSTR_EQS_THERMAL_INP"]
        end
    end
    #
    #
    matrix_material = options[:matrix_material]
    inclusions_material = options[:inclusions_material]
    sections_data = [
        (name="INCLUSIONS-SECTION", elset="INCLUSIONS-ELEMENTS-SET", material=inclusions_material.tag),
        (name="MATRIX-SECTION", elset="MATRIX-ELEMENTS-SET", material=matrix_material.tag),
    ]
    #
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # ~~~~~~~      WRITING CASE SPECIFIC FILES       ~~~~~
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    lx, ly, lz = uc_model_data["side_lengths"]
    max_strain = options[:max_far_field_strain]
    for a_req_prop in required_properties
        options[:rel_disp_matrix] = [0.0 0.0 0.0; 0.0 0.0 0.0; 0.0 0.0 0.0]
        options[:rel_temp_vector] = [0.0; 0.0; 0.0]
        options[:apply_field_temp] = false
        if a_req_prop ∈ ["EXX", "EYY", "EZZ", "GYZ", "GZX", "GXY", "CTE"]
            prop_type = "MECHANICAL"
        elseif a_req_prop ∈ ["KXX", "KYY", "KZZ"]
            prop_type = "THERMAL"
        else
            prop_type = "NOTHING"
        end
        #
        if a_req_prop == "EXX"
            options[:rel_disp_matrix][1, 1] = max_strain * lx
        elseif a_req_prop == "EYY"
            options[:rel_disp_matrix][2, 2] = max_strain * ly
        elseif a_req_prop == "EZZ"
            options[:rel_disp_matrix][3, 3] = max_strain * lz
        elseif a_req_prop == "GYZ"
            options[:rel_disp_matrix][2, 3] = max_strain * lz
            options[:rel_disp_matrix][3, 2] = max_strain * ly
        elseif a_req_prop == "GZX"
            options[:rel_disp_matrix][1, 3] = max_strain * lz
            options[:rel_disp_matrix][3, 1] = max_strain * lx
        elseif a_req_prop == "GXY"
            options[:rel_disp_matrix][2, 1] = max_strain * lx
            options[:rel_disp_matrix][1, 2] = max_strain * ly
        elseif a_req_prop == "CTE"
            options[:apply_field_temp] = true
            options[:init_temp] = 0.0
            options[:final_temp] = 100.0
        elseif a_req_prop == "KXX"
            options[:rel_temp_vector][1] = lx  # in order to give unit gradient
        elseif a_req_prop == "KYY"
            options[:rel_temp_vector][2] = ly  # in order to give unit gradient
        elseif a_req_prop == "KZZ"
            options[:rel_temp_vector][3] = lz  # in order to give unit gradient
        end
        inp_file = create_new_file(joinpath(working_dir, id * "_" * a_req_prop * ".inp"))
        #
        println("Writing input file for $a_req_prop at $inp_file")
        # ~~~~~~~~~~~~~~~~~~ START of INP ~~~~~~~~~~~~~~~~~~~
        initialize_inp_file(
            inp_file, options[:job_name], options[:model_name], options[:model_summary]
        )
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        # ~~~~~~~~~~~~~~~~~~~~~~~~~>> PARTS DATA
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        open(inp_file, "a") do fp
            write(# nodal data
                fp,
                """
                ** 
                *PART, NAME=$part_name
                *NODE
                *INCLUDE, INPUT="$nodal_data_inp"
                """
            )



            for (mat_elset_name, mat_elset_file) in matrix_ele_sets
                ele_type = split(mat_elset_name, "-")[end]
                if prop_type == "THERMAL"
                    ele_type = "D" * ele_type
                end
                write(
                    fp,
                    """
                    **
                    *ELEMENT, type=$ele_type, ELSET=$mat_elset_name
                    *INCLUDE, INPUT="$mat_elset_file"
                    """
                )
            end
            # -------------
            write( # cumulative matrix elements set
                fp,
                """
                **
                *ELSET, ELSET=MATRIX-ELEMENTS-SET
                """
            )
            #
            mat_ele_set_names = collect(keys(matrix_ele_sets))
            write_vector_to_file(
                fp,
                mat_ele_set_names,
            )
            # -------------
            write( # defining matrix node sets
                fp,
                """
                *NSET, NSET=MATRIX-NODES-SET, ELSET=MATRIX-ELEMENTS-SET
                """
            )
            #





            for (inc_elset_name, inc_elset_file) in incl_ele_sets
                ele_type = split(inc_elset_name, "-")[end]
                if prop_type == "THERMAL"
                    ele_type = "D" * ele_type
                end
                write(
                    fp,
                    """
                    **
                    *ELEMENT, type=$ele_type, ELSET=$inc_elset_name
                    *INCLUDE, INPUT="$inc_elset_file"
                    """
                )
            end
            write( # cumulative inclusions elements set
                fp,
                """
                **
                *ELSET, ELSET=INCLUSIONS-ELEMENTS-SET
                """
            )
            #
            inc_ele_set_names = collect(keys(incl_ele_sets))
            write_vector_to_file(
                fp,
                inc_ele_set_names,
            )
            write( # defining matrix node sets
                fp,
                """
                *NSET, NSET=INCLUSIONS-NODES-SET, ELSET=INCLUSIONS-ELEMENTS-SET
                """
            )
            # ~~~~~~~~~~~~~~~~~~ WRITING SECTION DATA
            for a_section_data in sections_data
                write(
                    fp,
                    """
                    **
                    ** SECTION: $(a_section_data[:name])
                    *SOLID SECTION, ELSET=$(a_section_data[:elset]), MATERIAL=$(a_section_data[:material])
                    ,
                    """
                )
            end
            #
            write( # ENDING PART
                fp,
                """
                *END PART
                **
                """
            )
        end
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        # ~~~~~~~~~~~~~~~~~~~~~~~~~>> MATERIAL DATA
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        write_materials_data(
            inp_file,
            [matrix_material, inclusions_material]
        )
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        # ~~~~~~~~~~~~~~~~~~~~~~~~~>> START OF ASSEMBLY
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        open(inp_file, "a") do fp
            write(
                fp,
                """
                **
                **
                ** ASSEMBLY
                **
                *ASSEMBLY, NAME=$assembly_name
                """
            )
        end
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        # ~~~~~~~~~~~~~~~~~~~~~~~~~>> INSTANCE
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        open(inp_file, "a") do fp
            write(
                fp,
                """
                **
                *INSTANCE, NAME=$instance_name, PART=$part_name
                *END INSTANCE
                """
            )
        end
        # ~~~~~~~~~~~~~~~~~~~~~~~~~==>
        # ~~~~~~~~~~~~~~~~~~~~~~~~~==> PBC
        # ~~~~~~~~~~~~~~~~~~~~~~~~~==>
        if options[:pbc]
            ref_points::Dict = Dict(
                "RP1" => (1.25 * uc_model_data["side_lengths"][1], 0.0, 0.0),
                "RP2" => (0.0, 1.25 * uc_model_data["side_lengths"][2], 0.0),
                "RP3" => (0.0, 0.0, 1.25 * uc_model_data["side_lengths"][3]),
            )
            add_ref_points(inp_file, ref_points)
            #
            constr_eqs_file = begin
                if prop_type == "MECHANICAL"
                    constr_eqs_mech_inp
                elseif prop_type == "THERMAL"
                    constr_eqs_thermal_inp
                end
            end
            #
            open(inp_file, "a") do fp
                write(
                    fp,
                    """
                    **
                    ** CONSTRAINT EQUATIONS
                    *INCLUDE, INPUT="$constr_eqs_file"
                    """
                )
            end
        end
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        # ~~~~~~~~~~~~~~~~~~~~~~~~~>> END OF ASSEMBLY
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        append_to_file(
            inp_file,
            """
            **
            **
            **
            *END ASSEMBLY
            """
        )
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        # ~~~~~~~~~~~~~~~~~~~~~~~~~>> PREDEFINED FIELDS
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        if (:init_temp in keys(options))
            append_to_file(
                inp_file,
                """
                ** 
                ** PREDEFINED FIELDS
                ** 
                ** NAME: PREDEFINED FIELD-1   TYPE: TEMPERATURE
                *INITIAL CONDITIONS, TYPE=TEMPERATURE
                $(instance_name).MATRIX-NODES-SET, $(options[:init_temp])
                $(instance_name).INCLUSIONS-NODES-SET, $(options[:init_temp])
                """
            )
        end
        # ~~~~~~~~~~~~~~~~~~~~~~~~~
        # ~~~~~~~~~~~~~~~~~~~~~~~~~>> HISTORY DATA
        write_an_abaqus_step(inp_file, options, instance_name, prop_type)
        # ~~~~~~~~~~~~~~~~~~~ END of INP ~~~~~~~~~~~~~~~~~~~~~~~
    end
end