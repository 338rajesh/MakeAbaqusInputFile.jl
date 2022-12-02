# Methods for writing common data of input files, 

abstract type Analysis end

abstract type SolutionProcedure end

abstract type MechanicalAnalysis <: Analysis end
abstract type ThermalAnalysis <: Analysis end

struct Static3DStressAnalysis <: MechanicalAnalysis end
struct StaticPlaneStressAnalysis <: MechanicalAnalysis end
struct StaticPlaneStrainAnalysis <: MechanicalAnalysis end
struct Steady3DHeatConduction <: ThermalAnalysis end

struct SteadyStateDynamicDirectSolution <: SolutionProcedure end

struct MaterialPhase
    tag::String
    material
    econn::Dict
end


function get_analysis_type(
    prop_ID::String
)
    Stress3D_properties = ["E22_3D", "E33_3D", "E11_3D", "G23_3D", "G31_3D", "G12_3D", "CTE_3D",]
    Thermal3D_properties = ["K11_3D", "K22_3D", "K33_3D"]
    Stress2D_properties = ["E22_2D", "E33_2D", "G23_2D"]
    if prop_ID ∈ Stress3D_properties
        return Static3DStressAnalysis
    elseif prop_ID ∈ Thermal3D_properties
        return Steady3DHeatConduction
    elseif prop_ID ∈ Stress2D_properties
        return StaticPlaneStrainAnalysis
    else
        @warn "Invalid property ID $prop_ID is encountered!"*" It must be one of $([Stress2D_properties; Thermal3D_properties])"
    end
end


function initialize_inp_file(
    inp_file_name::String;
    echo_info::String="NO",
    print_model_info::String="NO",
    print_history::String="NO",
    print_contact_info::String="NO"
)
    # creating new file or clearing the contents of file, if any.
    file_path = create_new_file(joinpath(BASE_DIR, inp_file_name))
    #
    #
    open(file_path, "a") do fp
        write(fp,
        """
        *HEADING
        $(!isempty(INP_OPTIONS[:model_summary]) ? INP_OPTIONS[:model_summary] : "**")
        ** =================================
        ** JOB NAME: $(INP_OPTIONS[:job_name]) 
        ** MODEL NAME: $(INP_OPTIONS[:model_name])
        ** Generated by AbaqusINPwriter.jl
        ** ==================================
        *PREPRINT, ECHO=$echo_info, MODEL=$print_model_info, HISTORY=$print_history, CONTACT=$print_contact_info
        """)
    end
    return file_path
end


function write_nodes_info(
    ntags::Vector{Int},
    ncoor::Matrix{Float64},
)
    # =====================================
    #        adding NODAL data    
    # =====================================
    nodes_file_path = create_new_file(joinpath(COMMON_DATA_DIR, "nodes_info.inp"))
    open(nodes_file_path, "a") do fp
        for (k, nt) in enumerate(ntags)
            write(
                fp,
                """
      $nt, $(ncoor[1, k]), $(ncoor[2, k]), $(ncoor[3, k])
      """
            )
        end
    end
    return nodes_file_path
end


function write_felset_info(
    econn::Dict{Int,Matrix{Int}},
    tag::Union{String,Int},
)::Dict{String,String}
    ele_sets::Dict{String,String} = Dict()
    for (elt, elt_table) in econn
        ele_inp = create_new_file(joinpath(COMMON_DATA_DIR, "$tag-ele_conn_$elt.inp"))  # TODO change element type in file name to that of the ABAQUS
        ele_sets["$tag-$elt"] = write_matrix_to_file(ele_inp, elt_table)
    end
    return ele_sets
end


function start_part_data(inp_file::String, part_name::String="PART-1")
    open(inp_file, "a") do fp
        write(
            fp,
            """
            **
            ** $(comment_header("PART DEFINITIONS"))
            ** 
            *PART, NAME=$part_name
            """
        )
    end
end

function finish_part_data(inp_file::String)
    open(inp_file, "a") do fp
        write( # ENDING PART
            fp,
            """
            *END PART
            **
            """
        )
    end
end


function add_nodal_data(
    inp_file::String,
    nodal_info_file_path::String;
)
    path = ABS_PATH ? nodal_info_file_path : joinpath(basename(dirname(nodal_info_file_path)), basename(nodal_info_file_path))
    open(inp_file, "a") do fp
        write(
            fp,
            """
            ** $(comment_sub_header("Nodal information", "*"))
            *NODE
            *INCLUDE, INPUT="$path"
            """
        )
    end
end

"""
    add_elements_data() -> Dict{String, Vector{String}}

It returns a dictionary with `"node_set_names"` and `"element_set_names"` keys, mapping to vector of 
respective set names.

"""
function add_elements_data(
    inp_file::String,
    eldata_files::Dict{String,Dict{String, String}},  # {"phase_tag@Str" => {"phase_tag-gmsh_ele_type@Str" => "file_path@Str"}}
    analysis_type::DataType;
    add_node_sets::Bool=true,
    add_sections::Bool=true,
    section_thickness::Union{Real,String}=",",
    materials::Dict{String, String}=Dict{String, String}(),
)::Dict{String, Vector{String}}
    set_names::Dict{String, Vector{String}} = Dict{String, Vector{String}}(
        "node_set_names" => String[],
        "element_set_names" => String[],
    )
    open(inp_file, "a") do fp
        for (a_phase_tag, a_phase_ele_inp_files) in eldata_files
            write(
                fp,
                """
                ** $(comment_sub_header("Elemental information", "*"))
                """
            )
            for (elt_tag, eld_file_path) in a_phase_ele_inp_files
                
                path = ABS_PATH ? eld_file_path : joinpath(basename(dirname(eld_file_path)), basename(eld_file_path))
                #
                # Changing element type from gmsh to that of ABAQUS.
                phase_tag, gmsh_ele_type = split(elt_tag, "-")
                abaqus_ele_type = get_abaqus_element_type(parse(Int, gmsh_ele_type), analysis_type)
                elset_name = phase_tag * "-" * abaqus_ele_type
                #
                node_set_name = elset_name * "-" * "Nodes"
                push!(set_names["node_set_names"], node_set_name)
                push!(set_names["element_set_names"], elset_name)
                write(
                    fp,
                    """
                    *ELEMENT, type=$abaqus_ele_type, ELSET=$elset_name
                    *INCLUDE, INPUT="$path"
                    """
                )
                if add_node_sets
                    write(
                        fp,
                        """
                        *NSET, NSET=$node_set_name, ELSET=$elset_name
                        """
                    )
                end
                if add_sections
                    @assert length(materials[a_phase_tag])>0 "Material tag must be provided for section assignment" 
                    write(
                        fp,
                        """
                        *SOLID SECTION, ELSET=$elset_name, MATERIAL=$(materials[a_phase_tag])
                        $section_thickness
                        """
                    )
                end
            end
        end

    end
    return set_names
end


function add_nset_on_instance(
    inp_file::String,
    nset_tag::String,
    inst_tag::String,
    ntags::Vector{Int},
)
    open(inp_file, "a") do fp
        write(
            fp,
            """
            *NSET, NSET=$nset_tag, INSTANCE=$inst_tag
            """
        )
        write_vector_to_file(
            fp,
            ntags,
        )
    end
end


function add_solid_section(
    inp_file::String,
    elset_tag::String,
    material_tag::String,
    section_tag::String;
    add_unit_thickness::Bool=false
)
    open(inp_file, "a") do fp
        thkns = add_unit_thickness ? "1," : ","
        write(
            fp,
            """
            **
            ** SECTION: $section_tag
            *SOLID SECTION, ELSET=$elset_tag, MATERIAL=$material_tag
            $thkns
            """
        )
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
            ** $(comment_header("MATERIAL DATA"))
            """
        )
        for a_material_data in materials_data
            
            write(
                fp,
                """
                ** $(comment_sub_header(a_material_data.tag*" data"))
                **
                **
                *MATERIAL, NAME=$(a_material_data.tag)
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




function start_assembly(inp_file::String, assembly_name::String="Assembly-1")
    open(inp_file, "a") do fp
        write(
            fp,
            """
            ** $(comment_header("ASSEMBLY"))
            *ASSEMBLY, NAME=$assembly_name
            """
        )
    end
end


function finish_assembly(inp_file::String)
    open(inp_file, "a") do fp
        write(
            fp,
            """
            *END ASSEMBLY
            **
            """
        )
    end
end


function add_instance_of_part(inp_file::String, instance_name::String, part_name::String)
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
end

function add_reference_points(
    file_path::String,
    points::Dict{String, NTuple{3, Float64}};
    init_ref_node_num::Int64=1000000
)
    open(file_path, "a") do fp
        write(fp,
            """
            ** $(comment_header("REFERENCE POINTS"))
            """)
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
end













