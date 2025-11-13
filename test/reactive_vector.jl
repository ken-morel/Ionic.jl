using Ionic
using Test

@testset "ReactiveVector" begin

    @testset "Construction and Basic Properties" begin
        rv = ReactiveVector{Int}([1, 2, 3])
        @test rv[] == [1, 2, 3]
        @test length(rv) == 3
        @test eltype(rv) == Int
        @test !isempty(rv)
    end

    @testset "Standard Catalyze Notification" begin
        rv = ReactiveVector{Int}([1])
        c = Catalyst()
        call_count = Ref(0)

        catalyze!(c, rv) do _
            call_count[] += 1
        end

        push!(rv, 2)
        @test call_count[] == 1
        @test rv[] == [1, 2]

        pop!(rv)
        @test call_count[] == 2
        @test rv[] == [1]
    end

    @testset "oncollectionchange Granular Notifications" begin
        rv = ReactiveVector{String}(["a", "b"])
        c = Catalyst()
        
        changes_received = []
        
        oncollectionchange(c, rv) do _, get_changes
            append!(changes_received, get_changes())
        end

        # Test push!
        push!(rv, "c")
        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.Push
        @test changes_received[1].values == ["c"]
        @test rv[] == ["a", "b", "c"]
        empty!(changes_received)

        # Test pop!
        pop!(rv)
        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.Pop
        @test changes_received[1].count == 1
        @test rv[] == ["a", "b"]
        empty!(changes_received)

        # Test setindex!
        rv[2] = "z"
        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.SetIndex
        @test changes_received[1].value == "z"
        @test changes_received[1].index == 2
        @test rv[] == ["a", "z"]
        empty!(changes_received)

        # Test deleteat!
        deleteat!(rv, 1)
        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.DeleteAt
        @test changes_received[1].index == 1
        @test rv[] == ["z"]
        empty!(changes_received)

        # Test insert!
        insert!(rv, 1, "x")
        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.Insert
        @test changes_received[1].value == "x"
        @test changes_received[1].index == 1
        @test rv[] == ["x", "z"]
        empty!(changes_received)

        # Test empty!
        empty!(rv)
        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.Empty
        @test isempty(rv)
        empty!(changes_received)

        # Test setvalue! with diffing (now a Replace event)
        rv[] = ["x", "w"] # Start with a known state
        empty!(changes_received)
        setvalue!(rv, ["x", "y"])
        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.Replace
        @test changes_received[1].value == "y"
        @test changes_received[1].index == 2
        @test rv[] == ["x", "y"]
    end

    @testset "oncollectionchange on standard Reactant{Vector}" begin
        r = Reactant{Vector{String}}(["a", "b", "c"])
        c = Catalyst()
        changes_received = []

        oncollectionchange(c, r) do _, get_changes
            append!(changes_received, get_changes())
        end

        # Trigger a change that should be detected as a Replace
        r[] = ["a", "x", "c"]

        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.Replace
        @test changes_received[1].value == "x"
        @test changes_received[1].index == 2
    end

    @testset "move! function" begin
        rv = ReactiveVector{Int}([10, 20, 30, 40])
        c = Catalyst()
        changes_received = []

        oncollectionchange(c, rv) do _, get_changes
            append!(changes_received, get_changes())
        end

        move!(rv, 1 => 3) # Move item from index 1 to 3

        @test rv[] == [20, 30, 10, 40]
        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.Move
        @test changes_received[1].moves == [1 => 3]
    end

end
