# Ionic.jl

Reactivity constructs for [Efus.jl](https://github.com/ken-morel/Efus.jl)

A full pack of nice names, Reactant, Reactor, Catalyst, and few more
to revive your form 2 chem. Not that I love the subject, it actually
caused my worst grade

```chem
(salt + funnel + H2O ---pooring--> 😢).
```

In short:

- A `Reaction`: Links a `Catalyst`, a `Reactant` and a callback. An
  can be `inhibit!` -ed. Your usually don't have to manage this.
- A `Catalyst`: `catalyze!` and manage reactions with `Reactants` ,
  can be `denature!` -ed.
- a `Reactant` hold a value and notify all ongoing reactions when
  it's value change.
- A `Reactor`: holds several catalysts, and acts like a computed
  reactant whose value depends on other `AbstractReactive` objects
  and whose value is lazily-computed.
- `@ionic`: is just a tool, a translater, or something like that,
  I'm not so good at names, but in fact, it transforms assignments
  and getting values to ''' prepended values into
  a `IonicEfus.setvalue` and `IonicEfus.getvalue!` call.

So you have three things, the `AbstractCatalyst`, the `AbstractReaction{T}`
and the `AbstractReactive{T}`.

## `AbstractReactive{T}`

The abstract supertype for compatible reactive values.

### interfaces

- `Ionic.getvalue(r)`
  Get and maybe compute the value of the Reactive object.

- `Ionic.setvalue!(r, v;notify::Bool)`
  Assigns a value to the reactive value, maybe through a setter.
  the optional `notify` can prevent it notifying dependeicies. 

- `Ionic.push!(r, ::AbstractReaction)`, `IonicEfus.pop!(r, ::AbstractReaction)`
  low-level function to add or remove reactions from the reactive objects's stack.
 
### `Reactant{T}`

The Reactant is the first builtin concrete implementation of `AbstractReactive`,
it stores a simple typed value, and is thread-safe and lockable.

- `Reactant(value::T)`
- `Reactant{T}(value)`
- `Reactant(ref::Ref{T})`
- `Reactant{T}()`

```julia
r = Reactant(5)
r[] = 5
println(r[])
@assert r[] === getvalue!(r)
```

### `Reactor{T}`

A reactor acts as a container for other reactants, you can use it both
for simple computed values by providing a setter and a getter or from values
which depend on other reactive objects, when `deps[]` is passed, it subscribes
to them and marks itself as `fouled` and will recompute it's value when next queried.
The value of the reactor is always lazy-computed except `;eager = true` argument
is given.

- `Reactor{T}(getter, [setter, [deps::Vector{AbstractReactive}]];eager=false,initial=nothing)`
- `Reactor(...)` type computed from `Base.returntypes(getter)`.

You can use the `@reactor` macro which uses ionic syntax(see below) to
automatically guess dependencies.

## `AbstractCatalyst`

A catalyst is used to manage subscriptions with reactive objects.

- `catalyze!(fn::Function, r, ::AbstractReactive)`
- `pop!(r, ::AbstractReaction)`
- `push!(r, ::AbstractReaction)`
- `denature!(::Catalyst)`
- `inhibit!(::Catalyst, r::AbstractReactive, [fn])` looks for corresponding
  reactions and `inhibit!` them.

The default implementation, which should suffice in most cases is the
`Catalyst`.

```julia
number = Reactant(5)
c = Catalyst()

catalyze!(c, number) do r::Reactant{Int}
    println(r[])
end
```

## `Ionic.transcribe`

Here comes the name `Ionic`, this function takes an expression(or actually anything)
and returns a `@NamedTuple{code::Expr, gets::Vector, sets::Vector}`, gets are
the values which the code queries with the `'` syntax e.g `number'`, and sets
are the values which are similarly assigned e.g `number' = 6` and code is
the transcribed code which transforms those to their corresponding
`setvalue!` and `getvalue!` calls.
It is used in macros including:

- `@reactor getter_expr [setter_fn [deps_vector]]`
  Which creates a simple reactor.
- `@ionic getter_expr [setter_fn [deps_vector]]`
  Creates an anonymous eagerly evaluated reactor.
  ```julia
  num = Reactant(5)
  flt = Reactant(6.0)
  _ = @ionic num' = round(flt')
  ```
