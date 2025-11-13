using Ionic

called = 0
r = Reactant(5)
c = Catalyst()

catalyze!(c, r) do _
    println("changed with new value ", r[])
    global called += 1
end

println("Batching updates")
batch(r) do
    println("seting to 5...")
    r[] = 5
    println("setting to 6...")
    r[] = 6
    println("Done bach, firing!")
end

@assert called == 1
