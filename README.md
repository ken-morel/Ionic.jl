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

A central feature of `Ionic.jl` is a special syntax that makes working with reactive objects feel natural and declarative. The `transcribe` function, used by the `@ionic` macro, automatically rewrites expressions:

-   `my_reactant'` is transcribed to `getvalue(my_reactant)`.
-   `my_reactant' = new_value` is transcribed to `setvalue!(my_reactant, new_value)`.

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
