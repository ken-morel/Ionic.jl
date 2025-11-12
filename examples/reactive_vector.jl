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

# 4. Granular subscription using `onchange`
# This callback receives a list of specific change events that occurred.
# This is highly efficient for UIs, allowing for precise updates.
onchange(changes_catalyst, rv) do reactive_vector, changes
    println("\n[Changes Listener] Received ", length(changes), " specific change(s): ")
    for change in changes
        if change isa Ionic.Push
            println("  - PUSHED value: ", change.value)
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

println("\n--- Performing Operations ---")

# A. Push a new item
println("\n1. Pushing 'cherries'...")
push!(rv, "cherries")

# B. Set an index
println("\n2. Setting index 1 to 'apricots'...")
rv[1] = "apricots"

# C. Pop an item
println("\n3. Popping an item...")
popped_value = pop!(rv)
println("   (Popped value was: ", popped_value, ")")

# D. Delete an item at a specific index
println("\n4. Deleting item at index 2...")
deleteat!(rv, 2)

# E. Insert an item
println("\n5. Inserting 'blueberries' at index 1...")
insert!(rv, 1, "blueberries")

# F. Empty the vector
println("\n6. Emptying the vector...")
empty!(rv)

# --- Cleanup ---
# It's good practice to denature catalysts when they are no longer needed
# to prevent memory leaks.
denature!(standard_catalyst)
denature!(changes_catalyst)

println("\n--- Example Finished ---")
