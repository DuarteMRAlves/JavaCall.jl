# Module to represent the base java package: java.lang
# This modules has basic definitions that should be exported by default
module JavaLang

export JString, JObject, new_string, equals

using JavaCall.JNI
using JavaCall.Core
using JavaCall.CodeGeneration
using JavaCall.Conversions

# Replace by dynamic generation of JObject. Just to show that it is possible.
eval(generateblock(
    generatetype(:JObject),
    generatemethod(:convert, [:(::Type{jobject}), :(x::JObject)], :(x.ref)),
    generatemethod(
        :equals,
        [:(x::JObject), :(y::JObject)],
        quote
            obj = convert(jobject, x)
            result = callinstancemethod(obj, :equals, jboolean, Any[Symbol("java.lang.Object")], convert(jobject, y))
            Base.convert(Bool, result)
        end
    )
))
# Code generated by the above eval
# abstract type JObject end

# convert(::Type{jobject}, x::JObject) = x.ref

# function equals(x::JObject, y::JObject)::Bool
#     obj = convert(jobject, x)
#     result = callinstancemethod(obj, :equals, jboolean, Any[Symbol("java.lang.Object")], convert(jobject, y))
#     convert(Bool, result)
# end

# Replace by dynamic generation of JString. Just to show that it is possible.
eval(generateblock(
    generatetype(:JString, :JObject),
    generatestruct(:JStringImpl, :JString, (:ref, :jobject)),
    generatemethod(:convert, [:(::Type{JString}), :(x::jobject)], :(JStringImpl(x))),
    generatemethod(:convert, [:(::Type{jobject}), :(x::JString)], :(x.ref))
))

# Code generated by the above eval
# abstract type JString <: JObject end

# struct JStringImpl <: JString 
#     ref::jobject
# end

# convert(::Type{JString}, x::jobject) = JStringImpl(x)
# convert(::Type{jobject}, x::JString) = x.ref

# This code is not part of the API so it will not be automatically generated
new_string(s::T) where {T <: AbstractString} = 
    convert(JString, JNI.new_string(map(JNI.jchar, collect(s)), length(s)))

end