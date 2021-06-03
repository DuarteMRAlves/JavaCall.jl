module JImport

export @jimport

using JavaCall.JavaCodeGeneration

macro jimport(expr)
    # return nothing since we want no output, just to eval the methods
    :($__module__.eval(loadclass($__module__, Symbol($expr))); nothing)
end

end
