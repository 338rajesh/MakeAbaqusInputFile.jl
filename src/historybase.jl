

function ()
    step_time_period, init_time_incr, min_time_incr, max_time_incr = options[:step_times]
    NLGEOM_FLAG = options[:nlgeom] ? "YES" : "NO"
end

function start_step(
    inp_file::String,
    analysis_type::DataType;
    step_name::String="STEP-1"
)
    #
    analysis_ID = split(string(analysis_type), ".")[end]
    analysis = if startswith(analysis_ID, "Static")
        "STATIC"
    elseif analysis_type == Steady3DHeatConduction
        "HEAT TRANSFER, STEADY STATE, DELTMX=0"
    else
        @warn "Unable to find the analysis type, while writing STEP."
    end
    nlgeom_flag = INP_OPTIONS[:nlgeom] ? "YES" : "NO"
    step_time_period, init_time_incr, min_time_incr, max_time_incr = INP_OPTIONS[:step_times]
    #
    open(inp_file, "a") do fp
        write(
            fp,
            """
            **
            **
            **
            ** ***********************************
            **          HISTORY DATA
            ** ***********************************
            ** 
            ** STEP: $(step_name)
            ** 
            *STEP, NAME=$(step_name), NLGEOM=$nlgeom_flag
            *$(analysis)
            $init_time_incr, $step_time_period, $min_time_incr, $max_time_incr
            """
        )
    end
end

function finish_step(inp_file::String)
    open(inp_file, "a") do fp
        write(
            fp,
            """
            **
            *END STEP"""
        )
    end
end

function _apply_mech_bc(
    inp_file::String,
    ref_points::Dict,
    load_options::Dict,
)
    rel_disp_matrix = load_options[:rel_disp_matrix]
    #
    open(inp_file, "a") do fp
        write(
            fp,
            """
            ** NAME: $(INP_OPTIONS[:id]) - BC
            ** TYPE: DISPLACEMENT/ROTATION
            *BOUNDARY
            """
        )
        #
        # Adding BC's at all REFERENCE points
        for (jj, rpj) in enumerate(keys(ref_points))
            for ii in 1:length(ref_points)
                write(
                    fp,
                    """
                    $(rpj), $(ii), $(ii), $(rel_disp_matrix[ii,jj])
                    """
                )
            end
        end
        #
        # Applying temperature loads, if specified
        if :final_temp_fields in keys(load_options)
            write(
                fp,
                """
                ** 
                ** PREDEFINED FIELDS
                ** 
                ** NAME: PREDEFINED FIELD-1   TYPE: TEMPERATURE
                *TEMPERATURE
                """
            )
            for (ns_pointer, final_temp) in load_options[:final_temp_fields]
                write(
                fp,
                """
                $(ns_pointer), $(final_temp)
                $(ns_pointer), $(final_temp)
                """
            )
            end
        end
    end
    #
    #
end


function _apply_thermal_bc(inp_file, load_options)
    open(inp_file, "a") do fp
        write(
            fp,
            """
            ** NAME: $(INP_OPTIONS[:id]) - BC
            ** TYPE: TEMPERATURE
            *BOUNDARY
            """
        )
        for ii in 1:3
            write(
                fp,
                """
                RP$(ii), 11, 11, $(load_options[:rel_temp_vector][ii])
                """
            )
        end
    end
end


function add_predefined_fields(
    inp_file::String,
    field_type::String,
    fields::Dict{String,Float64};
    field_name::String="PREDEFINED FIELD-1"
)
    open(inp_file, "a") do fp
        write(fp,
            """
            ** 
            ** $(comment_header("PREDEFINED FIELDS"))
            ** 
            ** NAME: $field_name   TYPE: $field_type
            *INITIAL CONDITIONS, TYPE=$field_type
            """)
        for (k, v) in fields
            write(fp,
                """
                $k, $v
                """)
        end
    end
end


function add_boundary_conditions(
    inp_file::String,
    analysis_type::DataType,
    ref_points::Dict{String, NTuple{3, Float64}},
    load_options::Dict{Symbol, Any},
)
    if analysis_type in (Static3DStressAnalysis, StaticPlaneStrainAnalysis)
        _apply_mech_bc(inp_file, ref_points, load_options)
    elseif analysis_type <: ThermalAnalysis
        _apply_thermal_bc(inp_file, load_options)
    end
end


function add_field_output_requests(
    inp_file::String,
    nodal_for::Tuple{Vararg{String}},
    element_for::Tuple{Vararg{String}},
)
    #
    open(inp_file, "a") do fp
        write(
            fp, """
            ** 
            ** OUTPUT REQUESTS
            ** 
            *RESTART, WRITE, FREQUENCY=0
            ** 
            ** FIELD OUTPUT: F-OUTPUT-1
            ** 
            """
        )
        if isempty(nodal_for) && isempty(element_for)
            write(
                fp,
                """
                *OUTPUT, FIELD, VARIABLE=PRESELECT
                """
            )
        else
            write(
                fp,
                """
                *OUTPUT, FIELD
                """
            )
            if !isempty(nodal_for)
                write(
                    fp,
                    """
                    *NODE OUTPUT
                    $(["$i, " for i in nodal_for]...)
                    """
                )
            end
            if !(isempty(element_for))
                write(
                    fp,
                    """
                    *ELEMENT OUTPUT, DIRECTIONS=YES
                    $(["$i, " for i in element_for]...)
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

