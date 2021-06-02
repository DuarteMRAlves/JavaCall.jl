module Reflection

export 
    # Classes.jl
    findclass, isarray, isinterface, superclass, ClassDescriptor,
    # Modifiers.jl
    ModifiersDescriptor,
    # Methods.jl
    classmethods, classdeclaredmethods,
    isstatic, ispublic, MethodDescriptor,
    # Constructors.jl
    classconstructors, ConstructorDescriptor,
    # Fields.jl
    classfields, FieldDescriptor

include("Classes.jl")
include("Modifiers.jl")
include("Methods.jl")
include("Constructors.jl")
include("Fields.jl")

using .Classes
using .Modifiers
using .Methods
using .Constructors
using .Fields

end
