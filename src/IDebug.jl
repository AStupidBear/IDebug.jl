module IDebug

export @debug, @bp
using JSON

macro bp(ex)
    return :($(esc(ex)))
end

function nbinclude_string(path::AbstractString)
    codes = []
    path = abspath(path)

    nb = open(JSON.parse, path, "r")

    # check for an acceptable notebook:
    nb["nbformat"] == 4 || error("unrecognized notebook format ", nb["nbformat"])
    lang = lowercase(nb["metadata"]["language_info"]["name"])
    lang == "julia" || error("notebook is for unregognized language $lang")

    shell_or_help = r"^\s*[;?]" # pattern for shell command or help

    for cell in nb["cells"]
        if cell["cell_type"] == "code" && !isempty(cell["source"])
            s = join(cell["source"])
            isempty(strip(s)) && continue # Jupyter doesn't number empty cellsf
            ismatch(shell_or_help, s) && continue
            ismatch(r"IDebug", s) && continue
            ismatch(r"@debug", s) && continue
            push!(codes,s)
        end
    end
    code = join(codes, '\n')
    lines = []
    for (line, str) in enumerate(split(code,'\n'))
        ismatch(r"@bp", str) && push!(lines, line) 
    end
    return code, lines
end

macro debug(ex...)
	println("using Gallium, IDebug")
    ex = quote
    cd($(pwd()))
    code, lines = IDebug.nbinclude_string($(ex[1]))
    write("test.jl", code)

    for line in lines
        Gallium.breakpoint("test.jl", line)
    end
    include("test.jl")
    $(ex[2])
    end
    println(ex)
end

end # end of module