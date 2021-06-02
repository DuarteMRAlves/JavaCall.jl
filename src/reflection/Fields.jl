module Fields

export classfields, FieldDescriptor

using JavaCall.JNI
using JavaCall.Conversions
using JavaCall.Core
using JavaCall.Reflection: Classes, Modifiers

#=
Struct to hold information about java fields
that can be accessed by the user.
This is not a replecament to java.lang.reflect.Field
as it only holds essential information for
code generation

name:       Name of the field

type:       Descriptor for the type of the field

modifiers:  Information about the field modifiers
=#
struct FieldDescriptor
    name::String
    type::Classes.ClassDescriptor
    modifiers::Modifiers.ModifiersDescriptor
end

function Base.show(io::IO, f::FieldDescriptor)
    print(
        io,
        "FieldDescriptor{name: ", f.name,
        ", type: ", f.type,
        ", modifiers: ", f.modifiers,
        "}"
    )
end

function Base.:(==)(x::FieldDescriptor, y::FieldDescriptor)
    x.name == y.name && 
    x.type == y.type &&
    x.modifiers == y.modifiers
end

function descriptorfromfield(field::jobject)
    name = callinstancemethod(field, :getName, Symbol("java.lang.String"), [])
    type = callinstancemethod(field, :getType, Symbol("java.lang.Class"), [])
    FieldDescriptor(
        convert_to_string(String, name),
        Classes.descriptorfromclass(type),
        Modifiers.methodmodifiers(field))
end

classfields(classname::Symbol) = classfields(Classes.findclass(classname))

function classfields(classdescriptor::Classes.ClassDescriptor)
    array = convert_to_vector(Vector{jobject}, callinstancemethod(
        classdescriptor.jniclass, 
        :getFields, 
        Vector{Symbol("java.lang.reflect.Field")}, 
        []))
    map(descriptorfromfield, array)
end

end
