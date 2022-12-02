
function create_new_file(file_path::String)
    open(file_path, "w") do fp
    end
    return file_path
end

function append_to_file(file_path::String, content::String)
    open(file_path, "a") do fp
        write(fp, content)
    end
end


function write_vector_to_file(
    file_path::Union{String,IOStream},
    a::Vector;
    max_ele_per_row::Int64=10
)
    num_perfect_rows::Int64 = length(a) ÷ max_ele_per_row
    num_reminder_ele::Int64 = length(a) % max_ele_per_row
    perfect_a = permutedims(reshape(a[1:(end-num_reminder_ele)], max_ele_per_row, num_perfect_rows,))
    rem_a = reshape(a[(end-num_reminder_ele+1):end], 1, :)
    if isa(file_path, IOStream)
        writedlm(file_path, perfect_a, ", ")
        writedlm(file_path, rem_a, ", ")
    else
        open(file_path, "a") do fp
            writedlm(file_path, perfect_a, ", ")
            writedlm(file_path, rem_a, ", ")
        end
    end

end



function write_matrix_to_file(
    file_path::String,
    a::Matrix;
)::String
    open(file_path, "a") do fp
        writedlm(fp, transpose(a), ",\t")
    end
    return file_path
end


function comment_header(header::String, symbol::String="=")
    h_line = repeat(symbol, length(header))
    return "\n** $(h_line)\n** $(header)\n** $(h_line)\n**"
end

function comment_sub_header(header::String, symbol::String="=")
    h_line = repeat(symbol, 1*length(header))
    return "\n** $(h_line)\n** $(header)\n** $(h_line)"
end
