module JavaCodeGeneration

using Core: print
export loadclass

using Base.Iterators

using DataStructures

using JavaCall.CodeGeneration
using JavaCall.Reflection
using JavaCall.Utils

using JavaCall.JNI

const DEFAULT_SYMBOLS = Set([
    :Bool, 
    :Int8, 
    :Char,
    :Int16,
    :Int32,
    :Int64,
    :Float32,
    :Float64,
    :Nothing
])

const SHALLOW_LOADED_SYMBOLS = 
    DefaultDict{Module, Set{Symbol}}(() -> copy(DEFAULT_SYMBOLS))

const FULLY_LOADED_SYMBOLS = 
    DefaultDict{Module, Set{Symbol}}(() -> copy(DEFAULT_SYMBOLS))

structidfromtypeid(typeid::Symbol) = Symbol(typeid, "JuliaImpl")

paramnamefromindex(i::Int64) = Symbol("param", i)

paramexprfromtuple(x::Tuple{Int64, ClassDescriptor}) = :($(paramnamefromindex(x[1]))::$(x[2].juliatype)) 

function generateconvertarg(x::Tuple{Int64, ClassDescriptor})
    :(push!(args, JavaCall.Conversions.convert_to_jni($(x[2].jnitype), $(paramnamefromindex(x[1])))))
end

function loadclassfromobject(m::Module, object::jobject)
    class = JNI.get_object_class(object)
    loadclass(m, Reflection.descriptorfromclass(class))
end

function methodfromdescriptors(
    m::Module,
    classdescriptor::ClassDescriptor,
    methoddescriptor::MethodDescriptor
)   
    methodfromdescriptors(
        Val(isstatic(methoddescriptor)),
        m::Module,
        classdescriptor,
        methoddescriptor
    )
end

function methodfromdescriptors(
    ::Val{true},
    m::Module,
    classdescriptor::ClassDescriptor,
    methoddescriptor::MethodDescriptor
)   
    paramtypes = map(paramexprfromtuple, enumerate(methoddescriptor.paramtypes))
    signature = string(
        '(',
        map(x->x.signature, methoddescriptor.paramtypes)...,
        ')',
        methoddescriptor.rettype.signature)
    body = quote
        args = jvalue[]
        $(map(generateconvertarg, enumerate(methoddescriptor.paramtypes))...)
        result = JavaCall.Core.callstaticmethod(
            $(classdescriptor.jniclass),
            $(QuoteNode(Symbol(methoddescriptor.name))),
            $(methoddescriptor.rettype.jnitype),
            $signature,
            args...)

        $(generateexceptionhandling(m))

        if isa(result, jobject)
            Core.eval($m, JavaCall.JavaCodeGeneration.loadclassfromobject($m, result))
        end
        JavaCall.Conversions.convert_to_julia($(methoddescriptor.rettype.juliatype), result)
    end
    generatemethod(
        Symbol("j_", snakecase_from_camelcase(methoddescriptor.name)),
        [:(::Type{$(classdescriptor.juliatype)}), paramtypes...],
        body)
end

function methodfromdescriptors(
    ::Val{false},
    m::Module,
    receiverdescriptor::ClassDescriptor,
    descriptor::MethodDescriptor
)
    paramtypes = map(paramexprfromtuple, enumerate(descriptor.paramtypes))
    pushfirst!(paramtypes, :(receiver::$(receiverdescriptor.juliatype)))
    signature = string(
        '(',
        map(x->x.signature, descriptor.paramtypes)...,
        ')',
        descriptor.rettype.signature)
    
    body = quote
        obj = JavaCall.Conversions.convert_to_jni(jobject, receiver)
        args = jvalue[]
        $(map(generateconvertarg, enumerate(descriptor.paramtypes))...)
        result = JavaCall.Core.callinstancemethod(
            obj, 
            $(QuoteNode(Symbol(descriptor.name))), 
            $(descriptor.rettype.jnitype),
            $signature,
            args...)

        $(generateexceptionhandling(m))

        if isa(result, jobject)
            Core.eval($m, JavaCall.JavaCodeGeneration.loadclassfromobject($m, result))
        end
        JavaCall.Conversions.convert_to_julia($(descriptor.rettype.juliatype), result)
    end
    generatemethod(
        Symbol("j_", snakecase_from_camelcase(descriptor.name)),
        paramtypes,
        body)
end

function constructorfromdescriptors(
    classdescriptor::ClassDescriptor,
    constructordescriptor::ConstructorDescriptor
)
    paramtypes = map(paramexprfromtuple, enumerate(constructordescriptor.paramtypes))
    # As specified in the JNI reference object contructor methods signatures
    # should return void(V)
    signature = string(
        '(',
        map(x->x.signature, constructordescriptor.paramtypes)...,
        ")V")
    body = quote
        args = jvalue[]
        $(map(generateconvertarg, enumerate(constructordescriptor.paramtypes))...)
        result = JavaCall.Core.callconstructor(
            $(classdescriptor.jniclass),
            $signature,
            args...)
        JavaCall.Conversions.convert_to_julia($(classdescriptor.juliatype), result)
    end
    generatemethod(
        classdescriptor.juliatype,
        paramtypes,
        body)
end

loadclass(m::Module, classname::Symbol, shallow=false) = 
    loadclass(m, findclass(classname), shallow)

function loadclass(m::Module, classdescriptor::ClassDescriptor, shallow=false)
    if isarray(classdescriptor)
        return generateblock(loadclass(m, classdescriptor.component, true))
    end

    exprstoeval = []
    
    if !shallowcomponentsloeaded(m, classdescriptor)
        loadshallowcomponents!(m, exprstoeval, classdescriptor)
    end

    if !shallow && !fullcomponentsloaded(m, classdescriptor)
        loadfullcomponents!(m, exprstoeval, classdescriptor)
    end

    generateblock(exprstoeval...)
end

## Loading of shallow components (minimal components required for the code to function)

shallowcomponentsloeaded(m::Module, d::ClassDescriptor) = d.juliatype in SHALLOW_LOADED_SYMBOLS[m]

function loadshallowcomponents!(m::Module, exprstoeval, classdescriptor)
    loadtype!(m, exprstoeval, classdescriptor)
    loadstruct!(exprstoeval, classdescriptor)
    loadconversions!(exprstoeval, classdescriptor)
    push!(SHALLOW_LOADED_SYMBOLS[m], classdescriptor.juliatype)
end

function loadtype!(m, exprstoeval, classdescriptor)
    typeid = classdescriptor.juliatype
    
    if !isinterface(classdescriptor) &&
        superclass(classdescriptor) !== nothing

        loadshallowcomponents!(m, exprstoeval, superclass(classdescriptor))
        push!(exprstoeval, generatetype(typeid, superclass(classdescriptor).juliatype))
    else
        push!(exprstoeval, generatetype(typeid))
    end
end

function loadstruct!(exprstoeval, classdescriptor)
    typeid = classdescriptor.juliatype
    structid = structidfromtypeid(typeid)
    push!(exprstoeval, generatestruct(structid, typeid, (:ref, :jobject)))
end

function loadconversions!(exprstoeval, classdescriptor)
    typeid = classdescriptor.juliatype
    structid = structidfromtypeid(typeid)
    push!(
        exprstoeval,
        generatemethod(
            :(JavaCall.Conversions.convert_to_julia), 
            [:(::Type{$typeid}), :(x::jobject)], 
            :($structid(x))
        ),
        generatemethod(
            :(JavaCall.Conversions.convert_to_jni),
            [:(::Type{jobject}), :(x::$typeid)], 
            :(x.ref)
        )
    )
end

## Loading of full components (fully generate the code for the class 
## such as methods and constructors)

fullcomponentsloaded(m::Module, d::ClassDescriptor) = 
    d.juliatype in FULLY_LOADED_SYMBOLS[m]

function loadfullcomponents!(m::Module, exprstoeval, class::ClassDescriptor)
    loadsuperclass!(m, exprstoeval, class)
    methods = filter(ispublic, classdeclaredmethods(class))
    constructors = classconstructors(class)
    loaddependencies!(m, exprstoeval, methods)
    loaddependencies!(m, exprstoeval, constructors)
    loadmethods!(m, exprstoeval, class, methods)
    loadconstructors!(exprstoeval, class, constructors)
    loadjuliamethods!(exprstoeval, class)
    loadcustommethods!(Val(class.juliatype), exprstoeval, class)
    push!(FULLY_LOADED_SYMBOLS[m], class.juliatype)
end

function loadsuperclass!(m, exprstoeval, class)
    if !isinterface(class) && superclass(class) !== nothing
        push!(exprstoeval, loadclass(m, superclass(class)))
    end
end

function loaddependencies!(m, exprstoeval, methods::Vector{MethodDescriptor})
    dependencies = 
        flatmap(m -> [m.rettype, m.paramtypes...], methods) |>
        l -> map(x -> loadclass(m, x, true), l)
    
    push!(exprstoeval, dependencies...)
end

function loaddependencies!(m, exprstoeval, constructors::Vector{ConstructorDescriptor})
    dependencies = 
        flatmap(c -> c.paramtypes, constructors) |>
        l -> map(x -> loadclass(m, x, true), l)
    
    push!(exprstoeval, dependencies...)
end

function loadmethods!(m, exprstoeval, class, methods)
    push!(exprstoeval, map(x -> methodfromdescriptors(m, class, x), methods)...)
end

function loadconstructors!(exprstoeval, class, constructors)
    push!(exprstoeval, map(x -> constructorfromdescriptors(class, x), constructors)...)
end

function loadjuliamethods!(exprstoeval, class)
    typeid = class.juliatype
    push!(
        exprstoeval,
        # generatemethod(
        #     :(Base.show), 
        #     [:(io::IO), :(o::$typeid)],
        #     :(print(io, JavaCall.Conversions.convert_to_string(String, j_to_string(o).ref)))),
        generatemethod(
            :(Base.:(==)),
            [:(o1::$typeid), :(o2::$typeid)],
            :(j_equals(o1, o2))
        )
    )
end

# Function to implement for concrete types to add
# custom methods to a given loaded class
loadcustommethods!(::Val{T}, exprstoeval, class) where T = nothing

function loadcustommethods!(::Val{:JString}, exprstoeval, class)
    push!(
        exprstoeval,
        # Add an extra constructor to facilitate
        # construction of java strings from julia strings
        generatemethod(
            :JString,
            [:(s::T)],
            :(JavaCall.Conversions.convert_to_julia(
                JString, 
                JavaCall.JNI.new_string(map(JavaCall.JNI.jchar, collect(s)), length(s)))),
            :(T <: AbstractString)
        ),
        # Add extra string method from JString
        generatemethod(
            :string,
            [:(s::JString)],
            :(JavaCall.Conversions.convert_to_string(String, s.ref))
        )
    )
end

function generateexceptionhandling(m::Module)
    quote
        if JavaCall.JNI.exception_check() === JavaCall.JNI.JNI_TRUE
            exception = JavaCall.JNI.exception_occurred()
            class = JavaCall.JNI.get_object_class(exception)
            desc = JavaCall.Reflection.descriptorfromclass(class)
            Core.eval($m, JavaCall.JavaCodeGeneration.loadclass($m, desc))
            JavaCall.JNI.exception_clear()
            throw(Core.eval($m, quote
                JavaCall.Conversions.convert_to_julia(
                    $(desc.juliatype),
                    $exception
                )
                end
            ))
        end
    end
end

end
