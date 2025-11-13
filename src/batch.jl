export batch, fire!, batch!, resume!

"""
    batch(f::Function, reactives::AbstractReactive...)

Execute a function `f` in a batch. All notifications for the specified `reactives`
that are triggered within `f` will be batched and sent as a single update after `f` completes.

This is useful for performance when making multiple changes to reactive objects in quick succession.

# Example
```julia
r1 = Reactant(1)
r2 = Reactant(2)

@radical println("Sum: ", r1' + r2')

batch(r1, r2) do
    r1[] = 10 # No notification yet
    r2[] = 20 # No notification yet
end
# "Sum: 30" is printed once here
```
"""
function batch(f::Function, reactives::AbstractReactive...)

    foreach(batch!, reactives)
    return try
        f()
    finally
        foreach(resume!, reactives)
    end
end

# --- fire! methods to be implemented for each reactive type ---

"""
    fire!(r::AbstractReactive)

Force any pending (batched) notifications to be sent for the given reactive object.
This is automatically called by `batch` and usually does not need to be called manually.
"""
function fire! end
