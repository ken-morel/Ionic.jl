"""
    macro ionic(expr)

Converts the given `ionic` expression to 
the julia getter code.
The code returns the evaluated expression.

See also [`@reactor`](@ref)
"""
macro ionic(expr)
    return esc(transcribe(expr).code)
end

"""
    macro reactor(expr, setter = nothing, usedeps = nothing)

Shorcut for creating a reactor, with optional setter.
It accepts ionic expressions for both. The 
generated expression returns a lazily evaluated [`Reactor`](@ref).
If the getter expression is a typeassert the type 
will be used to cast to the reactor.

See also [`@radical`](@ref)
"""
macro reactor(expr, setter = nothing, usedeps = nothing)
    expr, type = if expr isa Expr && expr.head == :(::)
        expr.args
    else
        expr, :Any
    end
    trans = transcribe(expr)
    setter = if !isnothing(setter)
        transcribe(setter).code
    end
    deps = something(usedeps, Expr(:vect, trans.gets...))
    return esc(:(Reactor{$type}(() -> $(trans.code), $setter, $deps)))
end

"""
    macro radical(expr,  usedeps = nothing, setter = nothing)

Creates an expression which re-evaluates directly when 
it's dependencies change, agnostic to svelte's \$: {}.
Returns the underlying eagerly evaluated [`Reactor`](@ref).
The setter and usedeps can be put in any direction.

See also [`@reactor`](@ref)
"""
macro radical(expr, usedeps = nothing, setter = nothing)
    expr, type = if expr isa Expr && expr.head == :(::)
        expr.args
    else
        expr, :Any
    end
    trans = transcribe(expr)
    setter = if !isnothing(setter)
        Ionic.transcribe(setter).code
    end
    deps = something(usedeps, Expr(:vect, trans.gets...))
    return esc(:($Reactor{$type}(() -> $(trans.code), $setter, $deps; eager = true)))
end
