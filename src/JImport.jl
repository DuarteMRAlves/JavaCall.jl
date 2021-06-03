module JImport

export @jimport

using JavaCall.JavaCodeGeneration

macro jimport(expr)
    # return nothing since we wian no output, just to eval the methods
    :($__module__.eval(loadclass(Symbol($expr))); nothing)
end

end
