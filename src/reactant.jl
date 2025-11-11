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

    Reactant(ref::Ref{T}) where {T} =
        finalizer(denature!, new{T}(ref, AbstractReaction{T}[], Base.ReentrantLock()))

    Reactant(val::T) where {T} = Reactant(Ref(val))

    Reactant{T}(val) where {T} = Reactant(Ref{T}(val))
    Reactant{T}() where {T} = Reactant(Ref{T}())
end



getvalue(r::Reactant{T}) where {T} = r.value[]

function setvalue!(r::Reactant{T}, new_value; notify::Bool = true) where {T}
    @lock r r.value[] = convert(T, new_value)
    notify && Base.notify(r)
    return r
end


"""
    inhibit!(catalyst::Catalyst, reactant::AbstractReactive, callback::Union{Function, Nothing} = nothing)
    inhibit!(::Reaction)


Searches and inhibit all reactions between the catalyst and reactant, if a callback is 
passed, it checks for a reaction which has that callback.
returns the number of inhibited reactions.
"""
function inhibit!(
    catalyst::AbstractCatalyst,
    reactant::AbstractReactive,
    callback::Union{Function,Nothing} = nothing,
)
    return @lock catalyst begin
        reactions_to_inhibit = if isnothing(callback)
            filter(catalyst.reactions) do sub
                sub.reactant === reactant
            end
        else
            filter(catalyst.reactions) do sub
                sub.reactant === reactant && sub.callback === callback
            end
        end

        for reaction in reactions_to_inhibit
            inhibit!(reaction)
        end
        length(reactions_to_inhibit)
    end
end
