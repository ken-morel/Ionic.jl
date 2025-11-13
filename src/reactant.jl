"""
    mutable struct Reactant{T} <: AbstractReactive{T}

Reactants are the builtin base for reactivity. They 
contain a value of type `T`, a list of reactions and 
notified all catalysts when it's setvalue! is called
"""
mutable struct Reactant{T} <: BuiltinReactive{T}
    const value::Ref{T}
    const reactions::Vector{AbstractReaction{T}}
    const lock::Base.ReentrantLock
    trace::Union{Nothing, UInt}
    defer_level::Int # New field
    needs_notification::Bool # New field

    Reactant(ref::Ref{T}) where {T} =
        finalizer(inhibit!, new{T}(ref, AbstractReaction{T}[], Base.ReentrantLock(), nothing, 0, false)) # Initialize new fields

    Reactant(val::T) where {T} = Reactant(Ref(val))
    Reactant{T}(val) where {T} = Reactant(Ref{T}(val))
    Reactant{T}() where {T} = Reactant(Ref{T}())
end

getvalue(r::Reactant{T}) where {T} = Tracing.record(() -> @lock(r, r.value[]), r.trace, Tracing.Get)

function setvalue!(r::Reactant{T}, new_value; notify::Bool = true) where {T}
    Tracing.record(() -> @lock(r, r.value[] = convert(T, new_value)), r.trace, Tracing.Set)
    notify && Base.notify(r)
    return new_value
end

function Base.notify(r::Reactant{T}) where {T}
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
