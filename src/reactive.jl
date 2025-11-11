const BuiltinReactive{T} = Union{Reactant{T}, Reactor{T}}

"""
    Base.push!(a::AbstractReactive, r::AbstractReaction)

Add the reaction to the reactive object(thread safe)
"""
Base.push!(a::BuiltinReactive, r::Reaction) = @lock a push!(a.reactions, r)

"""
    Base.pop!(a::AbstractReactive, r::AbstractReaction)

Remove the reaction from the reactive object(thread safe)
"""
Base.pop!(a::BuiltinReactive, r::Reaction) = @lock a filter!(o -> o !== r, a.reactions)


function Base.notify(r::BuiltinReactive)
    if haskey(TRACING_ENABLED, r)
        @lock TRACING_LOCK push!(TRACING_LOG, (:notify, r, nothing, nothing, stacktrace()[2]))
    end
    for reaction in (@lock r copy(r.reactions))
        reaction.callback(r)
    end

    #PERF: Trace time and log if too long
    # But spawning a timer takes some time
    return
end


for fn in [:lock, :trylock, :unlock]
    @eval Base.$fn(r::BuiltinReactive) = Base.$fn(r.lock)
end


function denature!(r::BuiltinReactive)
    return @lock r for r in copy(r.reactions)
        inhibit!(r)
    end
end
