abstract type VectorChange{T} end

"Event representing `push!(vector, value)`."
struct Push{T} <: VectorChange{T}
    values::Vector{T}
end
public Push

"Event representing `pop!(vector)`."
struct Pop{T} <: VectorChange{T}
    count::Int
    Pop{T}(count::Int = 1) where {T} = new{T}(count)
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
struct Move{T} <: VectorChange{T}
    moves::Vector{Pair{Int, Int}}
end

function _diff_vectors(old_list::AbstractVector{T}, new_list::AbstractVector{T}) where {T}
    # Pass 1: Generate raw Insert and DeleteAt events using LCS
    raw_changes = Vector{VectorChange{T}}()
    old_len = length(old_list)
    new_len = length(new_list)

    dp = zeros(Int, old_len + 1, new_len + 1)
    for i in 1:old_len, j in 1:new_len
        dp[i + 1, j + 1] = old_list[i] === new_list[j] ? dp[i, j] + 1 : max(dp[i + 1, j], dp[i, j + 1])
    end

    i, j = old_len, new_len
    while i > 0 || j > 0
        if i > 0 && j > 0 && old_list[i] === new_list[j]
            i -= 1; j -= 1
        elseif j > 0 && (i == 0 || dp[i + 1, j] >= dp[i, j + 1])
            push!(raw_changes, Insert{T}(new_list[j], j)); j -= 1
        elseif i > 0 && (j == 0 || dp[i + 1, j] < dp[i, j + 1])
            push!(raw_changes, DeleteAt{T}(i)); i -= 1
        else
            break
        end
    end
    reverse!(raw_changes)

    # Pass 2: Consolidate trailing Inserts/Deletes into Push/Pop
    optimized_changes = Vector{VectorChange{T}}()

    # Group sequential trailing inserts into a single Push
    trailing_inserts = []
    last_insert_idx = new_len
    temp_changes = copy(raw_changes) # Work on a copy
    empty!(raw_changes)

    for change in reverse(temp_changes)
        if change isa Insert && change.index == last_insert_idx
            push!(trailing_inserts, change.value)
            last_insert_idx -= 1
        else
            push!(raw_changes, change)
        end
    end
    if !isempty(trailing_inserts)
        push!(raw_changes, Push{T}(reverse(trailing_inserts)))
    end
    reverse!(raw_changes)

    # Group sequential trailing deletes into a single Pop
    trailing_deletes = 0
    last_delete_idx = old_len
    temp_changes = copy(raw_changes)
    empty!(raw_changes)

    for change in reverse(temp_changes)
        if change isa DeleteAt && change.index == last_delete_idx
            trailing_deletes += 1
            last_delete_idx -= 1
        else
            push!(raw_changes, change)
        end
    end
    if trailing_deletes > 0
        push!(raw_changes, Pop{T}(trailing_deletes))
    end
    reverse!(raw_changes)

    optimized_changes = raw_changes

    # Pass 3: Find Delete/Insert pairs and convert them to Move events
    final_changes = Vector{VectorChange{T}}()
    moved_items = Dict() # Dict to track items that are part of a move

    for i in 1:length(optimized_changes)
        change1 = optimized_changes[i]
        if change1 isa DeleteAt && !haskey(moved_items, change1)
            for j in (i + 1):length(optimized_changes)
                change2 = optimized_changes[j]
                if change2 isa Insert && old_list[change1.index] === change2.value
                    # Found a move
                    push!(final_changes, Move{T}([change1.index => change2.index]))
                    moved_items[change1] = true
                    moved_items[change2] = true # Fix: use moved_items here
                    break
                end
            end
        end
    end

    # Add non-moved changes to the final list
    for change in optimized_changes
        if !haskey(moved_items, change)
            push!(final_changes, change)
        end
    end

    return final_changes
end


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
Subscribers can use `oncollectionchange` to receive a list of all changes
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


"""
    move!(rv::ReactiveVector, moves::Pair{Int, Int}...)

Move item to new locations
"""
function move!(rv::ReactiveVector{T}, moves::Pair{Int, Int}...) where {T}
    @lock rv begin
        # Create a temporary copy of the current value to perform moves
        # This helps in handling multiple moves without affecting indices of subsequent moves
        # if they refer to original positions.
        current_value = copy(rv.value)
        
        # For each move, remove the item from its 'from' position and insert it at the 'to' position.
        # This is a simplified approach. For complex, overlapping moves, a more sophisticated
        # algorithm (e.g., based on permutation cycles) might be needed.
        for (from, to) in moves
            if from < 1 || from > length(current_value) || to < 1 || to > length(current_value) + 1
                throw(BoundsError(current_value, max(from, to)))
            end
            item = splice!(current_value, from) # Remove item from 'from'
            splice!(current_value, to:to-1, [item]) # Insert item at 'to'
        end
        rv.value = current_value
    end
    return notify(rv, [Move{T}(collect(moves))])
end


function setvalue!(rv::ReactiveVector{T}, new_value; notify::Bool = true) where {T}
    val = convert(Vector{T}, new_value)
    changes = @lock rv begin
        old_val = rv.value
        rv.value = val
        _diff_vectors(old_val, val)
    end

    if notify && !isempty(changes)
        Base.notify(rv, changes)
    end
    return rv
end
getvalue(rv::ReactiveVector) = Tracing.record(() -> @lock(rv, rv.value), rv.trace, Tracing.Get)


function Base.notify(rv::ReactiveVector{T}, changes::Vector{<:VectorChange{T}}) where {T}
    @lock rv begin
        Tracing.record(rv.trace, Tracing.Notify) do
            reactions = copy(rv.reactions)
            for reaction in reactions
                if reaction isa VectorReaction{T}
                    reaction.callback(rv, changes)
                else
                    reaction.callback(rv)
                end
            end
            reactions
        end
    end
    return
end

function Base.notify(rv::ReactiveVector{T}, change::VectorChange{T}) where {T}
    return notify(rv, [change])
end

Base.notify(rv::ReactiveVector{T}) where {T} = notify(rv, _diff_vectors(rv.value, rv.value))


function Base.push!(rv::ReactiveVector{T}, items...) where {T}
    val = convert.(T, items)
    @lock rv push!(rv.value, items...)
    Base.notify(rv, Push{T}(collect(val)))
    return rv
end

function Base.pop!(rv::ReactiveVector{T}) where {T}
    val = @lock rv pop!(rv.value)
    Base.notify(rv, Pop{T}(1))
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
The callback will receive a list of granular changes generated by a diffing algorithm.
"""
function oncollectionchange(
        callback::Function,
        c::Catalyst,
        r::AbstractReactive{V},
    ) where {T, V <: AbstractVector{T}}
    old_value = getvalue(r)
    return catalyze!(c, r) do reactive_vector
        new_value = getvalue(reactive_vector)
        changes = _diff_vectors(old_value, new_value)
        old_value = new_value
        if !isempty(changes)
            callback(reactive_vector, changes)
        end
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
