using Ionic

c = Catalyst()

reactant = Reactant(5)

trace!(reactant)

reactor = @reactor rand(1, 1, reactant')

println(Ionic.Tracing.TRACE)
