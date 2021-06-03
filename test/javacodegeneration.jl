@testset verbose=true "Test Java Code Generation" begin
    using JavaCall: JavaCodeGeneration

    @testset "Test Simple Object" begin
        obj_module = Module(:Object)
        Core.eval(obj_module, :(using JavaCall))
        Core.eval(
            obj_module, 
            JavaCodeGeneration.loadclass(obj_module, Symbol("java.lang.Object"))
        )
        @test isdefined(obj_module, :JObject)
        @test isdefined(obj_module, :JObjectJuliaImpl)
        @test isdefined(obj_module, :JString)
        @test isdefined(obj_module, :JStringJuliaImpl)
        @test isdefined(obj_module, :j_equals)
        @test isdefined(obj_module, :j_to_string)
    end

    @testset "Test Static Methods" begin
        @testset "Test Arrays" begin
            arrays_mod = Module(:Arrays)
            Core.eval(arrays_mod, :(using JavaCall))
            Core.eval(arrays_mod, JavaCodeGeneration.loadclass(
                arrays_mod, 
                Symbol("java.util.Arrays")
            ))
    
            a = [1, 2, 3, 4, 5]
            # Java Indexes at 0
            @test 1 == arrays_mod.j_binary_search(arrays_mod.JArrays, a, 2)
        end

        @testset "Test Dates" begin
            dates_mod = Module(:Dates)
            Core.eval(dates_mod, :(using JavaCall))
            Core.eval(dates_mod, JavaCodeGeneration.loadclass(
                dates_mod,
                Symbol("java.time.LocalDate")
            ))
            a = dates_mod.j_of(dates_mod.JLocalDate, Int32(2000), Int32(1), Int32(1))
            b = dates_mod.j_plus_days(a, 1)
            c = dates_mod.j_plus_months(b, 1)
            @test dates_mod.j_get_year(a) == 2000
            @test dates_mod.j_get_year(b) == 2000
            @test dates_mod.j_get_year(c) == 2000
            @test dates_mod.j_get_month_value(a) == 1
            @test dates_mod.j_get_month_value(b) == 1
            @test dates_mod.j_get_month_value(c) == 2
            @test dates_mod.j_get_day_of_month(a) == 1
            @test dates_mod.j_get_day_of_month(b) == 2
            @test dates_mod.j_get_day_of_month(c) == 2
        end
    end

    @testset "Test Constructors" begin
        cons_mod = Module(:Constructors)
        Core.eval(cons_mod, :(using JavaCall))
        Core.eval(
            cons_mod, 
            JavaCodeGeneration.loadclass(cons_mod, Symbol("java.lang.String"))
        )

        hellochars = ['H', 'e', 'l', 'l', 'o']
        hello1 = cons_mod.JString(hellochars)
        hello2 = cons_mod.JString(hello1)
        
        @test cons_mod.j_length(hello1) == 5
        @test cons_mod.j_length(hello2) == 5

        for (i, c) in enumerate(hellochars)
            @test cons_mod.j_char_at(hello1, Int32(i-1)) == c
            @test cons_mod.j_char_at(hello2, Int32(i-1)) == c
        end

        helloworldchars = ['H', 'e', 'l', 'l', 'o', ' ', 'W', 'o', 'r', 'l', 'd']
        
        finalworld = cons_mod.JString(helloworldchars, Int32(5), Int32(6))

        helloworld = cons_mod.j_concat(hello1, finalworld)
        for (i, c) in enumerate(helloworldchars)
            @test cons_mod.j_char_at(helloworld, Int32(i-1)) == c
        end

        @test cons_mod.j_equals(hello1, hello2)
        @test_false cons_mod.j_equals(hello1, helloworld)
        @test hello1 == hello2
        @test hello1 != helloworld

        # Test string special constructor
        helloworld2 = cons_mod.JString("Hello World")
        @test cons_mod.j_equals(helloworld, helloworld2)
        @test helloworld == helloworld2

        # Test string method to convert JString
        @test cons_mod.string(helloworld2) == "Hello World"
    end

    @testset "Test Load Superclass" begin
        super_mod = Module(:Constructors)
        Core.eval(super_mod, :(using JavaCall))
        Core.eval(
            super_mod, 
            JavaCodeGeneration.loadclass(super_mod, Symbol("java.lang.Integer"))
        )
        @test isdefined(super_mod, :JInteger)
        @test isdefined(super_mod, :JIntegerJuliaImpl)
        @test isdefined(super_mod, :JNumber)
        @test isdefined(super_mod, :JNumberJuliaImpl)

        a = super_mod.JInteger(Int32(1))
        b = super_mod.JInteger(Int32(1))
        @test 1 == super_mod.j_long_value(a)
        @test a == b
    end

    @testset "Test Load Return Value" begin
        net_mod = Module(:Net)
        Core.eval(net_mod, :(using JavaCall))
        Core.eval(net_mod, JavaCodeGeneration.loadclass(
            net_mod, 
            Symbol("javax.net.SocketFactory")
        ))
        socketfactory = net_mod.j_get_default(net_mod.JSocketFactory)
        socket = net_mod.j_create_socket(socketfactory)
        @test isdefined(net_mod, :j_bind) # Socket.bind
    end
end
