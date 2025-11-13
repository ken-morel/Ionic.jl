using Ionic

r = Reactant(1)
c = Catalyst()

catalyze!(identity, c, r)

@radical r'

r[] = 5

for x in 1:2
    r[] = x
end

println("Starting timing")

start = time_ns()
for x in 1:100
    r[] = x
end
stop = time_ns()
withouttrace = stop - start
println("Without trace took ", Ionic.Tracing.format_time(withouttrace))

trace!(r)


start = time_ns()
for x in 1:100
    r[] = x
end
stop = time_ns()
withtrace = stop - start
println("With trace took ", Ionic.Tracing.format_time(withtrace))
difference = withtrace - withouttrace

println("The time difference was ", Ionic.Tracing.format_time(difference), " so about ", round(difference / withouttrace * 100; digits = 4), "% more time")
