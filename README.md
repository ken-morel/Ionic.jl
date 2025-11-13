# Ionic.jl

`Ionic.jl` is a powerful and lightweight reactive programming library for Julia. It provides a set of tools to create dynamic and declarative data flows, making it easy to build applications where the UI or other components automatically react to changes in the underlying data.

It serves as the core reactivity engine for the [Efus.jl](https://github.com/ken-morel/Efus.jl) component framework.

[![code style: runic](https://img.shields.io/badge/code_style-%E1%9A%B1%E1%9A%A2%E1%9A%BE%E1%9B%81%E1%9A%B2-black)](https://github.com/fredrikekre/Runic.jl)
[![CI](https://github.com/ken-morel/Ionic.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/ken-morel/Ionic.jl/actions/workflows/CI.yml)

## Core Concepts

Ionic's reactivity model is built around a few key concepts:

-   **`AbstractReactive`**: The foundation of the system. This is an abstract type representing a value that can be observed for changes.
-   **`Reactant`**: The primary source of truth. It's a concrete `AbstractReactive` that holds a value. When its value changes, it notifies all its subscribers.
-   **`Reactor`**: A derived value. Its state is a computed result of other `Reactant`s or `Reactor`s. It automatically tracks its dependencies and re-calculates its value only when needed (lazy evaluation) or immediately (eager evaluation).
-   **`Catalyst` and `Reaction`**: The subscription mechanism. A `Catalyst` manages the subscriptions (`Reaction`s) between a reactive source and a callback function. This is crucial for managing the lifecycle of reactivity and preventing memory leaks.

## Key Feature: The `'` Syntax and `@ionic`

A central feature of `Ionic.jl` is a special syntax that makes working with reactive objects feel natural and declarative. The `transcribe` function, used by the `@ionic` and `@radical` macros, automatically rewrites expressions:

-   `my_reactant'` is transcribed to `getvalue(my_reactant)`.
-   `my_reactant' = new_value` is transcribed to `setvalue!(my_reactant, new_value)`.

Crucially, when assignments (`my_reactant' = new_value`) occur within `@ionic` or `@radical` blocks, they are now automatically wrapped in a `batch()` call. This means that if multiple reactive variables are updated within a single `@ionic` or `@radical` expression, all notifications are collected and sent out only once at the end, preventing redundant computations and improving performance.

This allows you to write clean, readable code while `Ionic.jl` handles the underlying reactivity and dependency tracking for you.

```julia
using Ionic

# Create a source reactant
a = Reactant(5)

# Create a reactor that depends on 'a'
# The `'` syntax makes this clean and automatic
b = @reactor a' * 2

println(b') #> 10

# Change the source value
a' = 10

println(b[]) #> 20

# Example of automatic batching:
# Even though 'a' is set twice, the reactor 'b' will only notify once
@ionic begin
    a' = 100
    a' = 200
end
println(b[]) #> 400 (only one notification for 'b')
```

## API Overview

### `AbstractReactive{T}`

This is the abstract supertype for all reactive values.

**Interface:**

-   `getvalue(r::AbstractReactive)`: Gets the current value. For a `Reactor`, this may trigger a re-computation if its dependencies have changed.
-   `setvalue!(r::AbstractReactive, value)`: Sets a new value and notifies all subscribers.

### `Reactant{T}`

The basic, thread-safe container for a reactive value.

**Constructors:**

-   `Reactant(value::T)`
-   `Reactant{T}(value)`

**Usage:**

```julia
r = Reactant(10)
println(getvalue(r)) #> 10
println(r[])          #> 10 (shorthand)

setvalue!(r, 20)
r[] = 20 # (shorthand)
```

### `Reactor{T}`

A reactive value that is computed from other reactive values.

**Constructors:**

-   `Reactor{T}(getter, [setter], [dependencies]; eager=false)`

The `@reactor` and `@radical` macros are the most convenient way to create `Reactor`s.

-   `@reactor expression`: Creates a lazily-evaluated `Reactor`. The value is recomputed only when `getvalue` is called and a dependency has changed.
-   `@radical expression`: Creates an eagerly-evaluated `Reactor`. The value is recomputed immediately whenever a dependency changes.

```julia
width = Reactant(10)
height = Reactant(5)

# A lazy reactor for area
area = @reactor width' * height'

# An eager reactor that prints on change
_ = @radical println("Area is now $(area')")

width[] = 20 # The radical reactor will trigger and print "Area is now 100"
```

### `Catalyst`

A `Catalyst` manages the lifecycle of subscriptions to reactive objects.

**Key Functions:**

-   `catalyze!(callback::Function, catalyst::Catalyst, reactive::AbstractReactive)`: Subscribes a callback function to a reactive object. The callback is executed whenever the reactive's value changes.
-   `denature!(catalyst::Catalyst)`: Cleans up and stops all subscriptions managed by the catalyst. This is essential for preventing memory leaks when a component or scope is destroyed.

**Usage:**

```julia
c = Catalyst()
r = Reactant("Hello")

catalyze!(c, r) do changed_reactant
    println("Value changed to: ", changed_reactant[])
end

@ionic r' = "World" #> Prints "Value changed to: World"

# Clean up all subscriptions
denature!(c)
```

## Advanced Features

### Batching Updates

Ionic.jl provides a powerful batching mechanism to group multiple reactive updates into a single notification cycle. This significantly improves performance by preventing redundant computations and ensuring a consistent state.

**Functions:**

-   `batch(f::Function, reactives::AbstractReactive...)`: Executes a function `f` in a batch. All notifications for the specified `reactives` triggered within `f` are deferred and sent as a single update after `f` completes.
-   `batch!(r::AbstractReactive)`: Manually increments the deferral level for a reactive object. Notifications are deferred if the deferral level is greater than zero.
-   `resume!(r::AbstractReactive)`: Manually decrements the deferral level for a reactive object. When the deferral level reaches zero, any pending notifications are sent.
-   `fire!(r::AbstractReactive)`: Forces any pending (batched) notifications to be sent for the given reactive object, regardless of the deferral level. This is automatically called by `batch` when the deferral level returns to zero.

**Usage Example (see also [examples/reactive_vector.jl](examples/reactive_vector.jl)):**

```julia
using Ionic

r = Reactant(0)
c = Catalyst()
notifications = Ref(0)

catalyze!(c, r) do _
    notifications[] += 1
end

println("Notifications before batch: ", notifications[]) #> 0

batch(r) do
    r[] = 1 # Deferred
    r[] = 2 # Deferred
    r[] = 3 # Deferred
end

println("Notifications after batch: ", notifications[]) #> 1 (only one notification)
println("Final value: ", r[]) #> 3
```

### `ReactiveVector` for Granular List Updates

The `ReactiveVector{T}` type is a specialized reactive container that wraps a `Vector{T}`. Unlike a standard `Reactant{Vector{T}}`, it emits granular change events for operations like `push!`, `pop!`, `setindex!`, `insert!`, `deleteat!`, and `move!`. This allows UI components to perform highly efficient, targeted updates instead of re-rendering entire lists.

**Key Functions:**

-   `oncollectionchange(callback::Function, catalyst::Catalyst, rv::ReactiveVector)`: Subscribes a callback that receives two arguments: first, a function (`get_changes_closure`) which, when called, returns a list of `VectorChange` events (e.g., `Push`, `Pop`, `Move`, `Replace`, `Insert`, `DeleteAt`, `Empty`) that occurred during a notification cycle; and second, the `ReactiveVector` itself.
-   `move!(rv::ReactiveVector, moves::Pair{Int, Int}...)`: Efficiently reorders items within the `ReactiveVector`, emitting a `Move` event.

**Usage Example (see [examples/reactive_vector.jl](examples/reactive_vector.jl)):**

```julia
using Ionic

rv = ReactiveVector{String}(["apple", "banana"])
c = Catalyst()
changes_received = []

oncollectionchange(c, rv) do get_changes, reactive_vector # Note the argument order
    append!(changes_received, get_changes())
end

push!(rv, "cherry")
println("Changes: ", changes_received) #> [Push(["cherry"])]
empty!(changes_received)

rv[1] = "apricot"
println("Changes: ", changes_received) #> [Replace("apricot", 1)]
empty!(changes_received)

move!(rv, 2 => 1) # Move 'banana' from index 2 to 1
println("Changes: ", changes_received) #> [Move([2 => 1])]
```

### Reactivity Debugging Tools (Tracing)

Ionic.jl includes powerful tracing tools to help debug complex reactive graphs. You can enable tracing on any reactive object to log detailed information about its interactions.

**Functions:**

-   `trace!(r::AbstractReactive, enable::Bool = true)`: Enables or disables tracing for a specific reactive object `r`.
-   `gettrace(r::AbstractReactive)`: Retrieves the `TraceLog` for a reactive object, containing all recorded events.
-   `printtrace(log::TraceLog)`: Prints a formatted, human-readable output of the `TraceLog` to the console.

**Logged Events:**

-   `Get`: When the value of a reactive object is read.
-   `Set`: When the value of a reactive object is set.
-   `Notify`: When a reactive object notifies its subscribers.
-   `Subscribe`: When a new reaction is subscribed.
-   `Unsubscribe`: When a reaction is unsubscribed.
-   `Inhibit`: When a reaction is inhibited.

Each event includes a timestamp, duration, value (for Get/Set), and a stack trace to pinpoint the origin of the interaction.

**Usage Example (see [examples/tracing.jl](examples/tracing.jl)):**

```julia
using Ionic

r = Reactant(10)
trace!(r) # Enable tracing for reactant 'r'

r[] = 20 # This will generate a 'Set' event
val = r[] # This will generate a 'Get' event

log = gettrace(r)
printtrace(log)
# Output will show formatted Get and Set events with timestamps and stack traces.
```
