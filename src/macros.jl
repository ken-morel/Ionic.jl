function _batch_modifications_in_expr(sets::Vector, expr)
    isempty(sets) && return expr
    return Expr(:call, batch, Expr(:->, Expr(:tuple), expr), sets...)
end
"""
    macro ionic(expr)

Converts the given `ionic` expression to 
the julia getter code, wrapping the modified variables in
a batch() call, if the expression is a function, it wraps it's content.
See also [`@reactor`](@ref)
"""
macro ionic(expr)
    trans = transcribe(expr)
    code = trans.code
    if code isa Expr && code.head == Symbol("function")
        #BUG: I don't know about moving the linenumbernodes, but it works
        code.args[2] = Expr(:block, _batch_modifications_in_expr(trans.sets, code.args[2]))
    else
        code = _batch_modifications_in_expr(trans.sets, trans.code)
    end
    return esc(code)
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
    code = _batch_modifications_in_expr(trans.sets, trans.code)
    return esc(:($Reactor{$type}(() -> $code, $setter, $deps)))
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
    code = _batch_modifications_in_expr(trans.sets, trans.code)
    return esc(:($Reactor{$type}(() -> $code, $setter, $deps; eager = true)))
end
