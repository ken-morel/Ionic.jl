# This file is executed during precompilation to force the compilation of
# common methods and improve load times.

function _run_workload()
    c = Catalyst()

    # --- Workload for common types ---
    for T in (Int, Float64, String)
        # Reactant
        r = Reactant{T}(one(T))
        catalyze!(c, r) do _ end
        setvalue!(r, one(T) * one(T))

        # ReactiveVector
        rv = ReactiveVector{T}([one(T), one(T) * one(T)])
        oncollectionchange(c, rv) do _, _ end
        push!(rv, one(T) * one(T))
        pop!(rv)
        rv[1] = one(T) * one(T)

        # Reactor
        r_source = Reactant{T}(one(T))
        r_computed = Reactor{String}(() -> string(r_source[]), nothing, [r_source])
        getvalue(r_computed)
        setvalue!(r_source, one(T) * one(T))
        getvalue(r_computed)

        # Diffing on standard Reactant{Vector}
        r_vec = Reactant{Vector{T}}([one(T)])
        oncollectionchange(c, r_vec) do _, _ end
        r_vec[] = [one(T), one(T) * one(T)]
    end

    return denature!(c)
end

_run_workload()
