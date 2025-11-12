const BuiltinReactive{T} = Union{Reactant{T}, Reactor{T}}

"""
    Base.push!(a::AbstractReactive, r::AbstractReaction)

Add the reaction to the reactive object(thread safe)
"""
Base.push!(a::BuiltinReactive, r::Reaction) = Tracing.record(() -> @lock(a, push!(a.reactions, r)), a.trace, Tracing.Subscribe, r)

"""
    Base.pop!(a::AbstractReactive, r::AbstractReaction)

Remove the reaction from the reactive object(thread safe)
"""
Base.pop!(a::BuiltinReactive, r::Reaction) = Tracing.record(() -> @lock(a, filter!(o -> o !== r, a.reactions)), a.trace, Tracing.Unsubscribe, r)


function Base.notify(r::BuiltinReactive)
    Tracing.record(r.trace, Tracing.Notify) do
        reactions = @lock r copy(r.reactions)
        for reaction in reactions
            reaction.callback(r)
        end
        reactions
    end
    return
end


for fn in [:lock, :trylock, :unlock]
    @eval Base.$fn(r::BuiltinReactive) = Base.$fn(r.lock)
end


function inhibit!(r::BuiltinReactive)
    return Tracing.record(() -> @lock(r, foreach(inhibit!, copy(r.reactions))), r.trace, Tracing.Inhibit)
end

"""
    istraced(c::BuiltinReactive) -> Bool

Know if tracing is activated for the reactive object.
"""
istraced(c::BuiltinReactive) = !isnothing(c.trace)


function trace!(c::BuiltinReactive, trace::Bool = true)
    return @lock c begin
        if trace && isnothing(c.trace)
            c.trace = Tracing.createtrace(c)
        elseif !trace && !isnothing(c.trace)
            c.trace = nothing
        end
    end
end
gettrace(c::BuiltinReactive) = isnothing(c.trace) ? nothing : Tracing.gettrace(c.trace)
