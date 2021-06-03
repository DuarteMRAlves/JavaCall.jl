@testset verbose = true "Tests for exceptions" begin

    using JavaCall.JNI
    using JavaCall: JavaCodeGeneration

    @testset "Integer Parsing Exception" begin
        exceptions_mod = Module(:Exceptions)
        Core.eval(exceptions_mod, :(using JavaCall))
        Core.eval(exceptions_mod, JavaCodeGeneration.loadclass(
            exceptions_mod, 
            Symbol("java.lang.Integer")
        ))
        Core.eval(exceptions_mod, JavaCodeGeneration.loadclass(
            exceptions_mod, 
            Symbol("java.lang.String")
        ))

        invalidnumber = exceptions_mod.JString(Char['1', '!', '3'])

        @test_throws exceptions_mod.JNumberFormatExceptionJuliaImpl exceptions_mod.j_parse_int(
            exceptions_mod.JInteger, 
            invalidnumber
        )
        @test_throws exceptions_mod.JNumberFormatException exceptions_mod.j_parse_int(
            exceptions_mod.JInteger, 
            invalidnumber
        )
        @test_throws exceptions_mod.JRuntimeException exceptions_mod.j_parse_int(
            exceptions_mod.JInteger,
            invalidnumber
        )

        try
            exceptions_mod.j_parse_int(exceptions_mod.JInteger, invalidnumber)
        catch e
            @test isa(e, exceptions_mod.JNumberFormatException)
            @test isa(e, exceptions_mod.JThrowable)
            @test exceptions_mod.j_length(exceptions_mod.j_get_message(e)) > 0
        end
    end
end
