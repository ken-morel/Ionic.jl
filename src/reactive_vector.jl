abstract type VectorChange{T} end

"Event representing `push!(vector, value)`."
struct Push{T} <: VectorChange{T}
    value::T
end
public Push

"Event representing `pop!(vector)`."
struct Pop{T} <: VectorChange{T}
end
public Pop

"Event representing `vector[index] = value`."
struct SetIndex{T} <: VectorChange{T}
    value::T
    index::Int
end
public SetIndex

"Event representing `deleteat!(vector, index)`."
struct DeleteAt{T} <: VectorChange{T}
    index::Int
end
public DeleteAt

"Event representing `insert!(vector, index, value)`."
struct Insert{T} <: VectorChange{T}
    value::T
    index::Int
end
public Insert

"Event representing `empty!(vector)`."
struct Empty{T} <: VectorChange{T}
end
public Empty

"Event representing `setvalue!(vector, new_values)`."
struct ReplaceAll{T} <: VectorChange{T}
    new_values::Vector{T}
end
public ReplaceAll

"""
A specialized reaction for `ReactiveVector` that receives a list of `VectorChange{T}` events.
The function receives (::ReactiveVector, Vector{VectorChange{T}})
"""
struct VectorReaction{T} <: AbstractReaction{Vector{T}}
    reactant::AbstractReactive{Vector{T}}
    catalyst::AbstractCatalyst
    callback::Function
end


"""
    ReactiveVector{T}

A reactive wrapper around a `Vector{T}` that emits granular change events.
Subscribers can use `onchange` to receive a list of all changes
that occurred within a single notification cycle.
"""
mutable struct ReactiveVector{T} <: AbstractReactive{Vector{T}}
    value::Vector{T}
    const reactions::Vector{AbstractReaction{Vector{T}}}
    const lock::ReentrantLock
    trace::Union{Nothing, UInt}

    function ReactiveVector{T}(v::Vector{T}) where {T}
        return new{T}(v, AbstractReaction{Vector{T}}[], ReentrantLock(), nothing)
    end
    ReactiveVector(v::Vector{T}) where {T} = ReactiveVector{T}(v)
    ReactiveVector{T}() where {T} = ReactiveVector{T}(T[])
end


function setvalue!(rv::ReactiveVector{T}, new_value; notify::Bool = true) where {T}
    val = convert(Vector{T}, new_value)
    Tracing.record(() -> @lock(rv, rv.value = val), rv.trace, Tracing.Set)
    notify && Base.notify(rv, ReplaceAll{T}(val))
    return rv
end
function getvalue(rv::ReactiveVector)
    return Tracing.record(() -> @lock(rv, rv.value), rv.trace, Tracing.Get)
end


function Base.notify(rv::ReactiveVector{T}, change::VectorChange{T}) where {T}
    @lock rv begin
        Tracing.record(rv.trace, Tracing.Notify) do
            reactions = copy(rv.reactions)
            for reaction in reactions
                if reaction isa VectorReaction{T}
                    reaction.callback(rv, [change])
                else
                    reaction.callback(rv)
                end
            end
            reactions
        end
    end
    return
end
Base.notify(rv::ReactiveVector{T}) where {T} = notify(rv, ReplaceAll{T}(rv.value))


function Base.push!(rv::ReactiveVector{T}, item) where {T}
    val = convert(T, item)
    @lock rv push!(rv.value, val)
    Base.notify(rv, Push{T}(val))
    return rv
end

function Base.pop!(rv::ReactiveVector{T}) where {T}
    val = @lock rv pop!(rv.value)
    Base.notify(rv, Pop{T}())
    return val
end

function Base.setindex!(rv::ReactiveVector{T}, value, index::Int) where {T}
    val = convert(T, value)
    @lock rv rv.value[index] = val
    Base.notify(rv, SetIndex{T}(val, index))
    return rv
end

function Base.deleteat!(rv::ReactiveVector{T}, index::Int) where {T}
    @lock rv deleteat!(rv.value, index)
    Base.notify(rv, DeleteAt{T}(index))
    return rv
end

function Base.insert!(rv::ReactiveVector{T}, index::Int, value) where {T}
    val = convert(T, value)
    @lock rv insert!(rv.value, index, val)
    Base.notify(rv, Insert{T}(val, index))
    return rv
end

function Base.empty!(rv::ReactiveVector{T}) where {T}
    @lock rv empty!(rv.value)
    Base.notify(rv, Empty{T}())
    return rv
end


"""
    oncollectionchange(callback::Function, c::Catalyst, rv::ReactiveVector)

Subscribes to a `ReactiveVector` with a callback that receives a batched list
of `VectorChange{T}` events. The callback signature must be `(reactive, changes)`.
"""
function oncollectionchange(
        callback::Function,
        c::Catalyst,
        rv::ReactiveVector{T},
    )::VectorReaction{T} where {T}
    reaction = VectorReaction{T}(rv, c, callback)
    add!(c, reaction)
    add!(rv, reaction)
    return reaction
end

"""
    oncollectionchange(callback::Function, c::Catalyst, r::AbstractReactive{<:AbstractVector})

Subscribes to any reactive vector (like a `Reactant{Vector{T}}`).
The callback will receive a `[ReplaceAll(...)]` event on every change.
"""
function oncollectionchange(
    callback::Function,
    c::Catalyst,
    r::AbstractReactive{V},
) where {T, V <: AbstractVector{T}}
    catalyze!(c, r) do reactive_vector
        changes = [ReplaceAll{T}(getvalue(reactive_vector))]
        callback(reactive_vector, changes)
    end
end

Base.length(rv::ReactiveVector) = length(rv.value)
Base.iterate(rv::ReactiveVector, state...) = iterate(rv.value, state...)
Base.getindex(rv::ReactiveVector, i, j...) = getindex(rv.value, i, j...)
Base.lastindex(rv::ReactiveVector) = lastindex(rv.value)
Base.firstindex(rv::ReactiveVector) = firstindex(rv.value)
Base.eltype(rv::ReactiveVector{T}) where {T} = T
Base.size(rv::ReactiveVector) = size(rv.value)
Base.isempty(rv::ReactiveVector) = isempty(rv.value)
