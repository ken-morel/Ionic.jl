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

"Event representing replacing an item at a specific index."
struct Replace{T} <: VectorChange{T}
    value::T
    index::Int
end
public Replace

"Event representing `setvalue!(vector, new_values)`."
struct Move{T} <: VectorChange{T}
    moves::Vector{Pair{Int, Int}}
end

function _perform_lcs_diff(@nospecialize(old_list::AbstractVector{T}), @nospecialize(new_list::AbstractVector{T})) where {T}
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
    return raw_changes
end
precompile(_perform_lcs_diff, (Vector{Any}, Vector{Any}))

function _optimize_for_replace(@nospecialize(changes::Vector{VectorChange{T}})) where {T}
    optimized_changes = Vector{VectorChange{T}}()
    processed_indices = Set{Int}()

    for i in 1:length(changes)
        change1 = changes[i]
        if change1 isa DeleteAt && !(i in processed_indices)
            found_replace = false
            for j in (i + 1):length(changes)
                change2 = changes[j]
                if change2 isa Insert && change1.index == change2.index && !(j in processed_indices)
                    push!(optimized_changes, Replace{T}(change2.value, change1.index))
                    push!(processed_indices, i)
                    push!(processed_indices, j)
                    found_replace = true
                    break
                end
            end
            if !found_replace
                push!(optimized_changes, change1)
            end
        elseif !(i in processed_indices)
            push!(optimized_changes, change1)
        end
    end
    return optimized_changes
end
precompile(_optimize_for_replace, (Vector{VectorChange{Any}},))

function _optimize_for_push_pop(@nospecialize(changes::Vector{VectorChange{T}}), old_len::Int, new_len::Int) where {T}
    optimized_changes = Vector{VectorChange{T}}()

    # Group sequential trailing inserts into a single Push
    trailing_inserts = []
    last_insert_idx = new_len
    temp_changes = copy(changes)
    empty!(changes)

    for change in reverse(temp_changes)
        if change isa Insert && change.index == last_insert_idx
            push!(trailing_inserts, change.value)
            last_insert_idx -= 1
        else
            push!(changes, change)
        end
    end
    if !isempty(trailing_inserts)
        push!(changes, Push{T}(reverse(trailing_inserts)))
    end
    reverse!(changes)

    # Group sequential trailing deletes into a single Pop
    trailing_deletes = 0
    last_delete_idx = old_len
    temp_changes = copy(changes)
    empty!(changes)

    for change in reverse(temp_changes)
        if change isa DeleteAt && change.index == last_delete_idx
            trailing_deletes += 1
            last_delete_idx -= 1
        else
            push!(changes, change)
        end
    end
    if trailing_deletes > 0
        push!(changes, Pop{T}(trailing_deletes))
    end
    reverse!(changes)

    return changes
end
precompile(_optimize_for_push_pop, (Vector{VectorChange{Any}}, Int, Int))

function _optimize_for_move(@nospecialize(changes::Vector{VectorChange{T}}), @nospecialize(old_list::AbstractVector{T})) where {T}
    final_changes = Vector{VectorChange{T}}()
    moved_items = Dict()

    for i in 1:length(changes)
        change1 = changes[i]
        if change1 isa DeleteAt && !haskey(moved_items, change1)
            for j in (i + 1):length(changes)
                change2 = changes[j]
                if change2 isa Insert && old_list[change1.index] === change2.value
                    push!(final_changes, Move{T}([change1.index => change2.index]))
                    moved_items[change1] = true
                    moved_items[change2] = true
                    break
                end
            end
        end
    end

    for change in changes
        if !haskey(moved_items, change)
            push!(final_changes, change)
        end
    end

    return final_changes
end
precompile(_optimize_for_move, (Vector{VectorChange{Any}}, Vector{Any}))

function _diff_vectors(old_list::AbstractVector{T}, new_list::AbstractVector{T}) where {T}
    raw_changes = _perform_lcs_diff(old_list, new_list)
    replace_optimized = _optimize_for_replace(raw_changes)
    push_pop_optimized = _optimize_for_push_pop(replace_optimized, length(old_list), length(new_list))
    move_optimized = _optimize_for_move(push_pop_optimized, old_list)
    return move_optimized
end
precompile(_diff_vectors, (Vector{Any}, Vector{Any}))

"""
A specialized reaction for `ReactiveVector` that receives a list of `VectorChange{T}` events.
The function receives (::ReactiveVector, Vector{VectorChange{T}})
"""
struct VectorReaction{T} <: BuiltinReaction{Vector{T}}
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
mutable struct ReactiveVector{T} <: BuiltinReactive{Vector{T}}
    value::Vector{T}
    const reactions::Vector{AbstractReaction{Vector{T}}}
    const lock::ReentrantLock
    trace::Union{Nothing, UInt}
    defer_level::Int # New field
    pending_changes::Vector{VectorChange{T}} # New field

    function ReactiveVector{T}(v::Vector{T}) where {T}
        return new{T}(v, AbstractReaction{Vector{T}}[], ReentrantLock(), nothing, 0, VectorChange{T}[])
    end
    ReactiveVector(v::Vector{T}) where {T} = ReactiveVector{T}(v)
    ReactiveVector{T}() where {T} = ReactiveVector{T}(T[])
end


"""
    move!(rv::ReactiveVector, moves::Pair{Int, Int}...)

Move item to new locations
"""
function move!(@nospecialize(rv::ReactiveVector{T}), moves::Pair{Int, Int}...) where {T}
    @lock rv begin
        for (from, to) in moves
            if from < 1 || from > length(rv.value) || to < 1 || to > length(rv.value) + 1
                throw(BoundsError(rv.value, max(from, to)))
            end

            item = rv.value[from]
            deleteat!(rv.value, from)
            insert!(rv.value, to, item)
        end
    end
    return Base.notify(rv, [Move{T}(collect(moves))])
end
precompile(move!, (ReactiveVector{Any}, Pair{Int, Int}))
precompile(move!, (ReactiveVector{Any}, Pair{Int, Int}, Pair{Int, Int}))
precompile(move!, (ReactiveVector{Any}, Pair{Int, Int}, Pair{Int, Int}, Pair{Int, Int}))


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
precompile(setvalue!, (ReactiveVector{String}, Vector{String}))

getvalue(@nospecialize(rv::ReactiveVector)) = Tracing.record(() -> @lock(rv, rv.value), rv.trace, Tracing.Get)
precompile(getvalue, (ReactiveVector{Any},))


function Base.notify(rv::ReactiveVector{T}, changes::Vector{<:VectorChange{T}}) where {T}
    if rv.defer_level > 0
        append!(rv.pending_changes, changes)
        return
    end

    @lock rv begin
        Tracing.record(rv.trace, Tracing.Notify) do
            reactions = copy(rv.reactions)
            for reaction in reactions
                if reaction isa VectorReaction{T}
                    reaction.callback(rv, () -> changes)
                else
                    reaction.callback(rv)
                end
            end
            reactions
        end
    end
    return
end
precompile(notify, (ReactiveVector{Any}, Vector{VectorChange{Any}}))

function Base.notify(rv::ReactiveVector{T}, change::VectorChange{T}) where {T}
    return Base.notify(rv, [change])
end
precompile(notify, (ReactiveVector{Any}, Push{Any}))


Base.notify(rv::ReactiveVector{T}) where {T} = Base.notify(rv, _diff_vectors(rv.value, rv.value))
precompile(notify, (ReactiveVector{Any},))

function flush!(rv::ReactiveVector)
    return if !isempty(rv.pending_changes)
        changes_to_send = copy(rv.pending_changes)
        empty!(rv.pending_changes)
        Base.notify(rv, changes_to_send)
    end
end


function Base.push!(@nospecialize(rv::ReactiveVector{T}), items...) where {T}
    val = convert.(T, items)
    @lock rv push!(rv.value, items...)
    Base.notify(rv, Push{T}(collect(val)))
    return rv
end
precompile(push!, (ReactiveVector{Any}, Any))
precompile(push!, (ReactiveVector{Any}, Any, Any))
precompile(push!, (ReactiveVector{Any}, Any, Any, Any))

function Base.pop!(@nospecialize(rv::ReactiveVector{T})) where {T}
    val = @lock rv pop!(rv.value)
    Base.notify(rv, Pop{T}(1))
    return val
end
precompile(pop!, (ReactiveVector{Any},))

function Base.setindex!(rv::ReactiveVector{T}, value, index::Int) where {T}
    val = convert(T, value)
    @lock rv rv.value[index] = val
    Base.notify(rv, SetIndex{T}(val, index))
    return rv
end
precompile(setindex!, (ReactiveVector{Any}, Any, Int))

function Base.deleteat!(rv::ReactiveVector{T}, index::Int) where {T}
    @lock rv deleteat!(rv.value, index)
    Base.notify(rv, DeleteAt{T}(index))
    return rv
end
precompile(deleteat!, (ReactiveVector{String}, Int))

function Base.insert!(rv::ReactiveVector{T}, index::Int, value) where {T}
    val = convert(T, value)
    @lock rv insert!(rv.value, index, val)
    Base.notify(rv, Insert{T}(val, index))
    return rv
end
precompile(insert!, (ReactiveVector{String}, Int, String))

function Base.empty!(rv::ReactiveVector{T}) where {T}
    @lock rv empty!(rv.value)
    Base.notify(rv, Empty{T}())
    return rv
end
precompile(empty!, (ReactiveVector{String},))


"""
    oncollectionchange(callback::Function, c::Catalyst, rv::ReactiveVector)

Subscribes to a `ReactiveVector` with a callback that receives a function
which returns batched list
of `VectorChange{T}` events. The callback signature must be `(reactive, changes)`.
"""
function oncollectionchange(
        callback::Function,
        c::AbstractCatalyst,
        @nospecialize(rv::ReactiveVector{T})
    )::VectorReaction{T} where {T}
    reaction = VectorReaction{T}(rv, c, callback)
    add!(c, reaction)
    add!(rv, reaction)
    return reaction
end
precompile(oncollectionchange, (Function, Catalyst, ReactiveVector{setcpuaffinity}))

"""
    oncollectionchange(callback::Function, c::Catalyst, r::AbstractReactive{<:AbstractVector})

Subscribes to any reactive vector (like a `Reactant{Vector{T}}`).
The callback will receive a list of granular changes generated by a diffing algorithm.
"""
function oncollectionchange(
        callback::Function,
        c::AbstractCatalyst,
        r::AbstractReactive{V},
    ) where {T, V <: AbstractVector{T}}
    old_value = Ref{V}(getvalue(r))
    return catalyze!(c, r) do reactive_vector
        callback() do
            new_value = getvalue(reactive_vector)
            changes = _diff_vectors(old_value[], new_value)
            old_value[] = new_value
            return changes
        end
    end
end
precompile(oncollectionchange, (Function, Catalyst, Reactant{Vector{String}}))


Base.length(rv::ReactiveVector) = length(rv.value)
Base.iterate(rv::ReactiveVector, state...) = iterate(rv.value, state...)
Base.getindex(rv::ReactiveVector, i, j...) = getindex(rv.value, i, j...)
Base.lastindex(rv::ReactiveVector) = lastindex(rv.value)
Base.firstindex(rv::ReactiveVector) = firstindex(rv.value)
Base.eltype(rv::ReactiveVector{T}) where {T} = T
Base.size(rv::ReactiveVector) = size(rv.value)
Base.isempty(rv::ReactiveVector) = isempty(rv.value)
