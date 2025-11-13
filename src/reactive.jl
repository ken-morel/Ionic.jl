"""
    add!(a::AbstractReactive, r::AbstractReaction)

Add the reaction to the reactive object(thread safe)
"""
add!(a::BuiltinReactive{T}, r::AbstractReaction{T}) where {T} = Tracing.record(() -> @lock(a, push!(a.reactions, r)), a.trace, Tracing.Subscribe, r)

"""
    remove!(a::AbstractReactive, r::AbstractReaction)

Remove the reaction from the reactive object(thread safe)
"""
remove!(a::BuiltinReactive{T}, r::AbstractReaction{T}) where {T} = Tracing.record(() -> @lock(a, filter!(o -> o !== r, a.reactions)), a.trace, Tracing.Unsubscribe, r)


function Base.notify(r::BuiltinReactive)
    return length(
        Tracing.record(r.trace, Tracing.Notify) do
            reactions = @lock r copy(r.reactions)
            for reaction in reactions
                reaction.callback(r)
            end
            reactions
        end
    )
end
precompile(Base.notify, (BuiltinReactive,))


for fn in [:lock, :trylock, :unlock]
    @eval Base.$fn(r::BuiltinReactive) = Base.$fn(r.lock)
    @eval precompile(Base.$fn, (BuiltinReactive,))
end


function inhibit!(r::BuiltinReactive)
    return Tracing.record(() -> @lock(r, foreach(inhibit!, copy(r.reactions))), r.trace, Tracing.Inhibit)
end
precompile(inhibit!, (BuiltinReactive,))

"""
    istraced(c::BuiltinReactive) -> Bool

Know if tracing is activated for the reactive object.
"""
istraced(c::BuiltinReactive) = !isnothing(c.trace)
precompile(istraced, (BuiltinReactive,))


function trace!(c::BuiltinReactive, trace::Bool = true)
    return @lock c begin
        if trace && isnothing(c.trace)
            c.trace = Tracing.createtrace(c)
        elseif !trace && !isnothing(c.trace)
            c.trace = nothing
            gettrace(c)
        end
    end
end
gettrace(c::BuiltinReactive) = isnothing(c.trace) ? nothing : Tracing.gettrace(c.trace)
precompile(gettrace, (BuiltinReactive,))


batch!(r::BuiltinReactive) = @lock r r.defer_level += 1
function resume!(r::BuiltinReactive; fire::Bool = true)
    @lock r r.defer_level -= 1
    return if r.defer_level == 0 && fire
        fire!(r)
    end
end
function fire!(r::BuiltinReactive)
    return if r.needs_notification
        r.needs_notification = false
        Base.notify(r)
    end
end
