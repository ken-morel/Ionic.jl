"""
    mutable struct Reactor{T} <: AbstractReactive{T}

A reactor is a reactive container that derives its value
from another value, it can also be used to wrap
another or more reactants, transforming their values.

A reactor is said to be `fouled` when one of it
dependencies has changed, and the value was not
yet updated.
"""
mutable struct Reactor{T} <: BuiltinReactive{T}
    const getter::Function
    const setter::Union{Function, Nothing}
    const content::Vector{AbstractReactive}
    const reactions::Vector{AbstractReaction{T}}
    const catalyst::Catalyst
    _value::T
    fouled::Bool
    trace::Union{UInt, Nothing}
    const eager::Bool
    const lock::Base.ReentrantLock
    defer_level::Int
    needs_notification::Bool

    function Reactor{T}(
            getter::Function,
            setter::Union{Function, Nothing} = nothing,
            content::Vector{<:AbstractReactive} = AbstractReactive[];
            eager::Bool = false,
            initial = nothing,
        ) where {T}
        if isnothing(initial) && T !== Nothing
            initial = convert(T, getter())
        end
        r = new{T}(
            getter,
            setter,
            [],
            [],
            Catalyst(),
            initial,
            false,
            nothing,
            eager,
            Base.ReentrantLock(),
            0,
            false, # Initialize needs_notification
        )

        callback = (_) -> begin
            @lock r r.fouled = true
            eager && getvalue(r)
            Base.notify(r) # Use Base.notify
        end
        for reactant in content
            push!(r.content, reactant)
            catalyze!(r.catalyst, reactant, callback)
        end
        return finalizer(inhibit!, r)
    end

end
Reactor(
    getter::Function,
    setter::Union{Function, Nothing},
    content::Vector{<:AbstractReactive};
    eager::Bool = false,
) = Reactor{Union{Base.return_types(getter)...}}(getter, setter, content; eager)

isfouled(r::Reactor) = @lock r r.fouled

"""
    function getvalue(r::Reactor{T})::T where {T}

Get the value of a reactor, recomputing the
value if one of it dependencies changed(
isfouled(r) is true).
"""
function getvalue(r::Reactor{T}) where {T}
    return Tracing.record(r.trace, Tracing.Get) do
        @lock r begin
            if r.fouled
                r._value = r.getter()
                r.fouled = false
            end
            r._value
        end
    end
end

function setvalue!(r::Reactor{T}, new_value; notify::Bool = true) where {T}
    Tracing.record(r.trace, Tracing.Set) do
        @lock r begin
            if !isnothing(r.setter)
                r.setter(convert(T, new_value))
            end
            r.fouled = true
        end
        new_value
    end
    notify && Base.notify(r)
    return new_value
end

function Base.notify(r::Reactor{T}) where {T}
    if r.defer_level > 0
        r.needs_notification = true
        return
    end

    @lock r begin
        Tracing.record(r.trace, Tracing.Notify) do
            reactions = copy(r.reactions)
            for reaction in reactions
                reaction.callback(r)
            end
            reactions
        end
    end
    return
end
