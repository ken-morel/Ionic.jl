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
        
        oncollectionchange(c, rv) do _, changes
            append!(changes_received, changes)
        end

        # Test push!
        push!(rv, "c")
        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.Push
        @test changes_received[1].value == "c"
        @test rv[] == ["a", "b", "c"]
        empty!(changes_received)

        # Test pop!
        pop!(rv)
        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.Pop
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

        # Test setvalue! with diffing
        setvalue!(rv, ["a", "x", "z"])
        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.Insert
        @test changes_received[1].value == "x"
        @test rv[] == ["a", "x", "z"]
    end

    @testset "oncollectionchange on standard Reactant{Vector}" begin
        r = Reactant{Vector{String}}(["a", "b", "c"])
        c = Catalyst()
        changes_received = []

        oncollectionchange(c, r) do _, changes
            append!(changes_received, changes)
        end

        # Trigger a change that involves inserts and deletes
        r[] = ["a", "x", "c", "y"]

        @test length(changes_received) == 3 # Delete 'b', Insert 'x', Insert 'y'
        @test count(c -> c isa Ionic.DeleteAt && c.index == 2, changes_received) == 1
        @test count(c -> c isa Ionic.Insert && c.value == "x", changes_received) == 1
        @test count(c -> c isa Ionic.Insert && c.value == "y", changes_received) == 1
    end

    @testset "move! function" begin
        rv = ReactiveVector{Int}([10, 20, 30, 40])
        c = Catalyst()
        changes_received = []

        oncollectionchange(c, rv) do _, changes
            append!(changes_received, changes)
        end

        move!(rv, 1 => 3) # Move item from index 1 to 3

        @test rv[] == [20, 30, 10, 40]
        @test length(changes_received) == 1
        @test changes_received[1] isa Ionic.Move
        @test changes_received[1].moves == [1 => 3]
    end

end
