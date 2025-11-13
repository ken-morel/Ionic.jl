using Ionic
using Test

@testset "Transaction" begin
    @testset "Reactant Transaction" begin
        r = Reactant(0)
        c = Catalyst()
        notifications = Ref(0)

        catalyze!(c, r) do _
            notifications[] += 1
        end

        @test notifications[] == 0

        transaction(r) do
            r[] = 1
            r[] = 2
            r[] = 3
        end

        @test r[] == 3
        @test notifications[] == 1 # Should only notify once
        
        # Test nested transactions
        transaction(r) do
            r[] = 4
            transaction(r) do
                r[] = 5
            end
            r[] = 6
        end
        @test r[] == 6
        @test notifications[] == 2 # Notified once for each top-level transaction
    end

    @testset "Reactor Transaction" begin
        r1 = Reactant(1)
        r2 = Reactant(2)
        reactor = Reactor(() -> r1[] + r2[], nothing, [r1, r2])
        c = Catalyst()
        notifications = Ref(0)

        catalyze!(c, reactor) do _
            notifications[] += 1
        end

        @test notifications[] == 0

        transaction(r1, r2, reactor) do
            r1[] = 10
            r2[] = 20
            # reactor should not notify yet
        end

        @test reactor[] == 30
        @test notifications[] == 1 # Should only notify once
    end

    @testset "ReactiveVector Transaction" begin
        rv = ReactiveVector{Int}([1, 2, 3])
        c = Catalyst()
        notifications = Ref(0)
        changes_received = Vector{VectorChange{Int}}()

        oncollectionchange(c, rv) do _, get_changes
            notifications[] += 1
            append!(changes_received, get_changes())
        end

        @test notifications[] == 0

        transaction(rv) do
            push!(rv, 4)
            pop!(rv)
            insert!(rv, 1, 0)
            rv[2] = 99
        end

        @test rv[] == [0, 99, 3]
        @test notifications[] == 1 # Should only notify once
        @test !isempty(changes_received)
        @test length(changes_received) > 1 # Should contain multiple batched changes
        @test changes_received[1] isa Push
        @test changes_received[end] isa Replace # The last change should be the result of rv[2] = 99
    end
end
