using Ionic

c = Catalyst()

r = Reactant(1)


function jlmain(_)
    trace!(r)

    r[] = 2
    setvalue!(r, 4)


    # catalyze!(c, r) do r
    #     println("New value: ", r[])
    # end

    # @radical rand(100, 100, r')
    #

    Ionic.Tracing.printtrace(gettrace(r))
    return
end

(@main)(v) = jlmain(v)
