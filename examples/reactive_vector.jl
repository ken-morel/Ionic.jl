using Ionic

# --- Setup ---
println("--- ReactiveVector Usage Example ---")

# 1. Create a ReactiveVector
# It's a reactive object that wraps a standard Vector
rv = ReactiveVector{String}(["apples", "bananas"])

# 2. Create catalysts to manage subscriptions
standard_catalyst = Catalyst()
changes_catalyst = Catalyst()

# --- Subscriptions ---

# 3. Standard subscription using `catalyze!`
# This callback is notified that *something* changed, but not what.
# It's useful for simple reactions, like logging or triggering a full redraw.
catalyze!(standard_catalyst, rv) do reactive_vector
    println("\n[Standard Listener] Notified! Current vector: ", reactive_vector[])
end

# 4. Granular subscription using `oncollectionchange`
# This callback receives a list of specific change events that occurred.
# This is highly efficient for UIs, allowing for precise updates.
oncollectionchange(changes_catalyst, rv) do reactive_vector, changes
    println("\n[Changes Listener] Received ", length(changes), " specific change(s): ")
    for change in changes
        if change isa Ionic.Push
            println("  - PUSHED value(s): ", change.values)
        elseif change isa Ionic.Pop
            println("  - POPPED a value")
        elseif change isa Ionic.SetIndex
            println("  - SET index ", change.index, " to value: ", change.value)
        elseif change isa Ionic.DeleteAt
            println("  - DELETED at index: ", change.index)
        elseif change isa Ionic.Insert
            println("  - INSERTED value: ", change.value, " at index: ", change.index)
        elseif change isa Ionic.Empty
            println("  - EMPTIED the vector")
        end
    end
    println("  Current vector is now: ", reactive_vector[])
end

# --- Operations ---

# Now, let's modify the ReactiveVector and see the listeners in action.

println("\n--- Performing Operations on ReactiveVector ---")

# A. Push a new item
println("\n1. Pushing 'cherries'...")
@time push!(rv, "cherries")

# B. Set an index
println("\n2. Setting index 1 to 'apricots'...")
@time rv[1] = "apricots"

# C. Pop an item
println("\n3. Popping an item...")
@time popped_value = pop!(rv)
println("   (Popped value was: ", popped_value, ")")

# D. Delete an item at a specific index
println("\n4. Deleting item at index 2...")
@time deleteat!(rv, 2)

# E. Insert an item
println("\n5. Inserting 'blueberries' at index 1...")
@time insert!(rv, 1, "blueberries")

# F. Empty the vector
println("\n6. Emptying the vector...")
@time empty!(rv)


# --- Overload Example ---
println("\n--- Using oncollectionchange with a standard Reactant{Vector} ---")

# 1. Create a standard Reactant holding a Vector
standard_rv = Reactant{Vector{Int}}([10, 20, 30])
standard_rv_catalyst = Catalyst()

# 2. Subscribe with oncollectionchange
oncollectionchange(standard_rv_catalyst, standard_rv) do r, changes
    println("\n[Standard Reactant Listener] Received $(length(changes)) change(s) from diffing:")
    for change in changes
        if change isa Ionic.Insert
            println("  - INSERTED value: $(change.value) at index: $(change.index)")
        elseif change isa Ionic.DeleteAt
            println("  - DELETED at index: $(change.index)")
        else
            println("  - Received unexpected change type: $(typeof(change))")
        end
    end
end

# 3. Trigger a change. The diffing algorithm will detect the precise changes.
println("\n1. Replacing the entire vector (will be diffed)...")
@time standard_rv[] = [10, 50, 30] # Changed 20 to 50

println("\n1. Replacing the entire vector again (will be diffed)...")
@time standard_rv[] = [10, 50, 30] # Changed 20 to 50


# --- Move Example ---
println("\n--- Using move! to reorder items ---")
move_rv = ReactiveVector{Symbol}([:a, :b, :c, :d])
move_catalyst = Catalyst()

oncollectionchange(move_catalyst, move_rv) do r, changes
    println("\n[Move Listener] Received change(s):")
    for change in changes
        if change isa Ionic.Move
            println("  - MOVE operation with pairs: $(change.moves)")
        end
    end
    println("  Current vector is now: ", r[])
end

println("\n1. Moving item from index 2 to 4...")
@time move!(move_rv, 2 => 4)


println("\n1. Moving item from index 3 to 2 and 2 to 1...")
@time move!(move_rv, 3 => 2, 2 => 1)


# --- Cleanup ---
# It's good practice to denature catalysts when they are no longer needed
# to prevent memory leaks.
denature!(standard_catalyst)
denature!(changes_catalyst)
denature!(standard_rv_catalyst)
denature!(move_catalyst)

println("\n--- Example Finished ---")
