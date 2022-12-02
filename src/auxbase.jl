

function get_nodal_dof(analysis::DataType)
    if analysis == Static3DStressAnalysis
        return [1, 2, 3]
    elseif analysis == Steady3DHeatConduction
        return (11,)
    elseif analysis in [StaticPlaneStrainAnalysis, StaticPlaneStressAnalysis]
        return [1, 2]
    end
end


function add_constraint_equations(
    inp_file::String,
    analysis_type::DataType,
    instance_name::String,
    npairs::Vector{FENodePair},
    ntags::Vector{Int},
    ncoor::Matrix{Float64},
    ref_points::Dict;
    small_param::Float64=1e-06,
)
    #
    ntc = Dict{Int,Vector{Float64}}((i => j) for (i, j) in zip(ntags, eachcol(ncoor)))
    nodal_dof = get_nodal_dof(analysis_type)
    #
    analysis_ID = split(string(analysis_type), ".")[end]
    eqns_file_abs_path = create_new_file(joinpath(COMMON_DATA_DIR, "constraint_eqns_" * analysis_ID * ".inp"))
    path = ABS_PATH ? eqns_file_abs_path : joinpath(basename(dirname(eqns_file_abs_path)), basename(eqns_file_abs_path))
    # TODO You can avoid overwriting constraint equations
    for a_npair in npairs
        p_id, p_nt, c_id, c_nt = split(a_npair.tag, "-")
        append_to_file(
            eqns_file_abs_path,
            """
            ** =-==--==--==--==--==--==--==--==--==--==--==
            """)
        cnset_tag = "NODE-" * c_id * c_nt
        pnset_tag = "NODE-" * p_id * p_nt
        add_nset_on_instance(eqns_file_abs_path, cnset_tag, instance_name, [a_npair.c_nodetag,])
        add_nset_on_instance(eqns_file_abs_path, pnset_tag, instance_name, [a_npair.p_nodetag,])
        #
        dx, dy, dz = ntc[a_npair.c_nodetag] .- ntc[a_npair.p_nodetag]
        coeff = [abs(i) <= small_param ? 0.0 : sign(i) for i in (dx, dy, dz)]
        nz_coeff = [i for i in coeff if i != 0.0]
        num_terms = 2 + length(nz_coeff)
        #
        open(eqns_file_abs_path, "a") do fp
            write(fp,
                """
                ** CONSTRAINT: EQUATIONS NODES-$(a_npair.tag)
                """)
            for a_dof in nodal_dof
                write(fp,
                    """
                    *EQUATION
                    $num_terms
                    $cnset_tag, $a_dof, 1.0
                    $pnset_tag, $a_dof, -1.0
                    """)
                for (k, rpnt) in enumerate(keys(ref_points))
                    if coeff[k] != 0.0
                        write(fp,
                            """
                            $rpnt, $a_dof, $(-1.0*coeff[k])
                            """)
                    end
                end
            end
        end
    end
    open(inp_file, "a") do fp
        write(
            fp,
            """
            **
            ** CONSTRAINT EQUATIONS
            *INCLUDE, INPUT="$path"
            """
        )
    end
    return inp_file
end


