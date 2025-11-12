"""
    mutable struct Reactant{T} <: AbstractReactive{T}

Reactants are the builtin base for reactivity. They 
contain a value of type `T`, a list of reactions and 
notified all catalysts when it's setvalue! is called
"""
mutable struct Reactant{T} <: AbstractReactive{T}
    value::Ref{T}
    reactions::Vector{AbstractReaction{T}}

    lock::Base.ReentrantLock
    trace::Union{Nothing, UInt}

    Reactant(ref::Ref{T}) where {T} =
        finalizer(inhibit!, new{T}(ref, AbstractReaction{T}[], Base.ReentrantLock(), nothing))

    Reactant(val::T) where {T} = Reactant(Ref(val))

    Reactant{T}(val) where {T} = Reactant(Ref{T}(val))
    Reactant{T}() where {T} = Reactant(Ref{T}())
end


function getvalue(r::Reactant{T}) where {T}
    return Tracing.record(() -> r.value[], r.trace, Tracing.Get)
end

function setvalue!(r::Reactant{T}, new_value; notify::Bool = true) where {T}
    Trace.record(() -> @lock(r, r.value[] = convert(T, new_value)), r.trace, Trace.Set)
    notify && Base.notify(r)
    return new_value
end
