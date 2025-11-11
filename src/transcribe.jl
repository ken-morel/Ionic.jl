export transcribe

const Transcription = @NamedTuple{code, gets::Vector, sets::Vector}

"""
    function transcribe(orig)::Tuple{Any, Vector, Vector}

Translate an ionic expression by replacing all occurrences of 
`var'` with `Ionic.getvalue(var)` and all assignments to 
`var'` = value` with `Ionic.setvalue!(var, value)` and 
returning the new code and all dependencies.
Where a double '' in gets translated to a single ' and ignored.
"""
function transcribe(orig::Expr)::Transcription
    expr = copy(orig)
    todo = Vector{Expr}([expr])
    dependencies = []
    dependents = []
    while !isempty(todo)
        current = pop!(todo)
        if current.head == Symbol("'")
            push!(dependencies, current.args[1])
            current.head = :call
            current.args = [getvalue, current.args[1]]
            current.args[1] isa Expr && push!(todo, current.args[1])
        elseif current.head == Symbol("=") &&
               length(current.args) == 2 &&
               current.args[1] isa Expr &&
               current.args[1].head == Symbol("'")
            # it is an assignment to a reactive variable
            reactive_var = current.args[1].args[1]
            push!(dependents, reactive_var)
            value_expr = current.args[2]
            current.head = :call
            current.args = [setvalue!, reactive_var, value_expr]

            reactive_var isa Expr && push!(todo, reactive_var)
            value_expr isa Expr && push!(todo, value_expr)
        else
            push!(todo, filter(x -> x isa Expr, current.args)...)
        end
    end
    return Transcription((expr, dependencies, dependents))
end

transcribe(x) = Transcription((x, [], []))
