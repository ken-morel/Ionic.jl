"""
    struct Reaction{T} <: AbstractReaction{T}

A reaction are internaly used by catalysts and 
instances of [AbstractReactive](@ref).
They store the catalyst, reactive and callback.
They are returned when [catalyze!](@ref) is called 
and can be [inhibit!](@ref)-ed.
"""
struct Reaction{T} <: AbstractReaction{T}
    reactant::AbstractReactive{T}
    catalyst::AbstractCatalyst
    callback::Function
end


"""
    inhibit!(r::Reaction)

Stops and removes a single, specific Reaction. This is the low-level implementation.
It does so by calling [`pop!`](@ref) on the catalyst and reactants, which is again
more lowlevel.
"""
function inhibit!(r::Reaction)
    remove!(r.catalyst, r)
    remove!(r.reactant, r)

    return
end
