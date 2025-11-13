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
    @eval precompile(Base.$fn, (Catalyst,))
end

"""
    add!(c::Catalyst, r::AbstractReaction)

Add the reaction to the catalyst(thread safe)
"""
add!(c::Catalyst, @nospecialize(r::AbstractReaction)) = @lock c push!(c.reactions, r)
precompile(add!, (Catalyst, AbstractReaction))

"""
    Base.pop!(c::Catalyst, r::AbstractReaction)

Remove the reaction from the catalyst(thread safe)
"""
remove!(c::Catalyst, @nospecialize(r::AbstractReaction)) = @lock c filter!(o -> o !== r, c.reactions)
precompile(remove!, (Catalyst, AbstractReaction))


"""
    catalyze!(c::Catalyst, r::AbstractReactive{T}, callback::Function)::Reaction{T} where {T}
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
        @nospecialize(r::AbstractReactive{T}),
        @nospecialize(callback::Function),
    )::Reaction{T} where {T}

    reaction = Reaction{T}(r, c, callback)

    add!(c, reaction)
    add!(r, reaction)
    return reaction
end
precompile(catalyze!, (Catalyst, AbstractReactive{Any}, Function))

catalyze!(@nospecialize(fn::Function), c::Catalyst, @nospecialize(r::AbstractReactive{T})) where {T} = catalyze!(c, r, fn)
precompile(catalyze!, (Function, Catalyst, AbstractReactive{Any}))


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


"""
    inhibit!(catalyst::Catalyst, reactant::AbstractReactive[, callback::Union{Function, Nothing}])

Searches and inhibit all reactions between the catalyst and reactant, if a callback is 
passed, it checks for a reaction which has that callback.
returns the number of inhibited reactions.
"""
function inhibit!(
        catalyst::Catalyst,
        @nospecialize(reactant::AbstractReactive),
        @nospecialize(callback::Function),
    )
    return @lock catalyst begin
        reactions_to_inhibit =
            filter(s -> s.reactant === reactant && s.callback === callback, catalyst.reactions)
        foreach(inhibit!, reactions_to_inhibit)
        length(reactions_to_inhibit)
    end
end
precompile(inhibit!, (AbstractReactive, Function))

function inhibit!(
        catalyst::Catalyst,
        @nospecialize(reactant::AbstractReactive),
    )
    return @lock catalyst begin
        reactions_to_inhibit = filter(s -> s.reactant === reactant, catalyst.reactions)
        foreach(inhibit!, reactions_to_inhibit)
        length(reactions_to_inhibit)
    end
end
precompile(inhibit!, (AbstractReactive,))
