#__precompile__()

module WorkspaceToHdf5

import HDF5: read, write, close, h5open

function save_write(f, s, vname)
    g = f["/"]
    if !isa(vname, Function) 
        if (isa(vname, Number) || isa(vname, Array{<: Number}))
            g[s] = vname
        else
            warn("Skipping $vname because it isn't the Number or Array of Numbers")
        end
    end
end

macro save(filename, vars...)
    if isempty(vars)
        # Save all variables in the current module
        writeexprs = Vector{Expr}(0)
        m = current_module()
        for vname in names(m)
            s = string(vname)
            if !ismatch(r"^_+[0-9]*$", s) # skip IJulia history vars
                v = eval(m, vname)
                if !isa(v, Module)
                    push!(writeexprs, :(save_write(f, $s, $(esc(vname)))))
                end
            end
        end
    else
        writeexprs = Vector{Expr}(length(vars))
        for i = 1:length(vars)
            writeexprs[i] = :(save_write(f, $(string(vars[i])), $(esc(vars[i]))))
        end
    end

    quote
        local f = h5open($(esc(filename)), "w")
        try
            $(Expr(:block, writeexprs...))
        finally
            close(f)
        end
    end
end

macro load(filename, vars...)
    if isempty(vars)
        # Load all variables in the top level of the file
        readexprs = Expr[]
        vars = Symbol[]
        f = h5open(filename, "r")
        try
            for v in names(f)
                obj = f[v]
                try
                    push!(vars, Symbol(v))
                finally
                    close(obj)
                end
            end
        finally
            close(f)
        end
    end
    return quote
        f = h5open($(esc(filename)), "r")
        g = f["/"]
        ($([esc(x) for x in vars]...),) = try
            ($([:(read(g[$(string(x))])) for x in vars]...),)
        finally
            close(f)
        end
        $(Symbol[v for v in vars]) # convert to Array
    end
end
 end
