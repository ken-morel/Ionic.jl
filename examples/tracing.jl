using Ionic

c = Catalyst()


trace = nothing


function jlmain(_)
    let r = Reactant(1)
        trace!(r)

        r[] = 2
        setvalue!(r, 4)

        catalyze!(c, r) do r
            println("New value: ", r[])
        end

        @radical rand(100, 100, r')


        global trace = gettrace(r)
    end
    return
end

(@main)(v) = (jlmain(v); GC.gc(); Ionic.Tracing.printtrace(trace); 0)
