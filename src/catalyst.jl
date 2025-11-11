"""
    struct Catalyst

A catalyst is a container and manager
for subscribing to reactants.

Catalysts support the `catalyze!`,
and `denature!` functions.
"""
struct Catalyst <: AbstractCatalyst
    reactions::Vector{AbstractReaction}

    lock::Base.ReentrantLock

    """
    Construct a catalyst with no reactions.
    """
    Catalyst() = new(AbstractReaction[], Base.ReentrantLock())
end

for fn in [:lock, :trylock, :unlock]
    @eval Base.$fn(r::Catalyst) = Base.$fn(r.lock)
end

"""
    Base.push!(c::Catalyst, r::AbstractReaction)

Add the reaction to the catalyst(thread safe)
"""
Base.push!(c::Catalyst, r::AbstractReaction) = @lock c push!(c.reactions, r)

"""
    Base.pop!(c::Catalyst, r::AbstractReaction)

Remove the reaction from the catalyst(thread safe)
"""
Base.pop!(c::Catalyst, r::AbstractReaction) = @lock c filter!(o -> o !== r, c.reactions)


"""
    function catalyze!(c::Catalyst, r::AbstractReactive{T}, callback::Function)::Reaction{T} where {T}
    catalyze!(fn::Function, c::Catalyst, r::AbstractReactive{T}) where {T}

Subscribes and calls `callback` everytime `r` notifies.
r should be a function which takes a single argument, the 
AbstractReactive instance which was subscribed, and 
it can then call [getvalue](@ref), on it.
Not that this should preferably not be done here, 
since the getvalue may trigger a computation, usualy
you may instead want to notify ui components that 
something changed, and compute the result only 
when updating, so as to limit unnecesarry computations.

## Example

```julia
c = Catalyst()
r = Reactant(1)
catalyze!(c, r) do reactant
    println(getvalue(reactant))
end
```
"""
function catalyze!(
    c::Catalyst,
    r::AbstractReactive{T},
    callback::Function,
)::Reaction{T} where {T}

    reaction = Reaction{T}(r, c, callback)

    push!(c, reaction)
    push!(r, reaction)
    return reaction
end

catalyze!(fn::Function, c::Catalyst, r::AbstractReactive{T}) where {T} = catalyze!(c, r, fn)


"""
    denature!(c::Catalyst)

Stops all reactions being managed by the Catalyst.

This is the primary cleanup function to be called when a UI component
is destroyed, preventing memory leaks.
"""
function denature!(c::Catalyst)
    @lock c for reaction in copy(c.reactions)
        inhibit!(reaction)
    end
    return
end
