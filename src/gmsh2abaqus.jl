function get_abaqus_element_type(
    gmsh_element_type::Int64,
    analysis_type::DataType,
)
    plane_strain_analysis = analysis_type in (
        StaticPlaneStrainAnalysis,
    )
    
    plane_stress_analysis = analysis_type in (
        StaticPlaneStressAnalysis,
    )
    
    if gmsh_element_type == 2 && plane_strain_analysis
        return "CPE3"
    elseif gmsh_element_type == 2 && plane_stress_analysis
        return "CPS3"
    elseif gmsh_element_type == 3 && plane_strain_analysis
        return "CPE4"
    elseif gmsh_element_type == 3 && plane_stress_analysis
        return "CPS4"
    elseif gmsh_element_type == 4
        if analysis_type == Static3DStressAnalysis
            return "C3D4"
        elseif analysis_type == Steady3DHeatConduction
            return "DC3D4"
        end
    elseif gmsh_element_type == 5  # 8-node brick/hexahedron Element
        if analysis_type == Static3DStressAnalysis
            return "C3D8"
        elseif analysis_type == Steady3DHeatConduction
            return "DC3D8"
        end
    elseif gmsh_element_type == 6  # 6-node triangular prism
        if analysis_type == Static3DStressAnalysis
            return "C3D6"
        elseif analysis_type == Steady3DHeatConduction
            return "DC3D6"
        end
    elseif gmsh_element_type == 7  # 5-node pyramid
        if analysis_type == Static3DStressAnalysis
            return "C3D5"
        elseif analysis_type == Steady3DHeatConduction
            return "DC3D5"
        end
    end
end