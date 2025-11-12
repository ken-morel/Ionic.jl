using Ionic

c = Catalyst()

r = Reactant(1)

trace!(r)

catalyze!(c, r) do r
    println("New value: ", r[])
end

r[] = 2

@radical rand(100, 100, r')

r[] = 6

r[] = 8

Ionic.Tracing.printtrace(gettrace(r))
