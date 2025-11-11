module Ionic

export Reactant, Catalyst, Reaction, AbstractReaction
export getvalue, setvalue!, catalyze!, inhibit!, denature!
export resolve, MayBeReactive
export AbstractReactive, Reactor
export update!, alter!
export @ionic, @reactor, @radical
export trace, clear_trace_log

# Global tracing state
const TRACING_ENABLED = Dict{AbstractReactive, Bool}()
const TRACING_LOG = Vector{Any}() # Store (event_type, reactive, old_value, new_value, caller_frame)
const TRACING_LOCK = ReentrantLock()

"""
    trace(r::AbstractReactive, enable::Bool=true)

Enable or disable tracing for a specific reactive object.
When tracing is enabled, `getvalue`, `setvalue!`, and `notify` operations
on `r` will be logged to `Ionic.TRACING_LOG`.
"""
function trace(r::AbstractReactive, enable::Bool=true)
    @lock TRACING_LOCK begin
        if enable
            TRACING_ENABLED[r] = true
        else
            delete!(TRACING_ENABLED, r)
        end
    end
    return
end

"""
    clear_trace_log()

Clears the global tracing log.
"""
function clear_trace_log()
    @lock TRACING_LOCK empty!(TRACING_LOG)
    return
end


"""
    abstract type AbstractReactive{T} end

The abstract reactive is the supertype for every
reactive value, where T is the type of the
contained value.
A reactive value supports setvalue!, getvalue
methods. And should have a .reactions attribute.
"""
abstract type AbstractReactive{T} end

getvalue(::AbstractReactive) = error("Not implemented")
setvalue(::AbstractReactive, val; kw...) = error("Not implemented")
Base.notify(::AbstractReactive) = error("Not implemented")

Base.getindex(r::AbstractReactive) = getvalue(r)
Base.setindex!(r::AbstractReactive, v) = setvalue!(r, v)

abstract type AbstractCatalyst end
denature!(::AbstractCatalyst) = error("Not implemented")
catalyze!(::AbstractCatalyst, ::AbstractReactive, fn::Function; kw...) =
    error("Not implemented")

abstract type AbstractReaction{T} end


include("catalyst.jl")

include("reaction.jl")

include("reactant.jl")

include("reactor.jl")

include("reactive.jl")

include("transcribe.jl")

include("macros.jl")


"""
    const MayBeReactive{T} = Union{AbstractReactive{T}, T}

Use this in cases you deal with values like component
arguments which may be an instance of abstract reactive.

You can then call resolve() on them which 
"""
const MayBeReactive{T} = Union{AbstractReactive{T}, T}

"""
    converter(::Type{AbstractReactive{T}}, r::AbstractReactive{K};eager) where {T, K}

Creates a reactor which subscribes and get's it value 
from converting that of the other and set's it with another
conversion.
"""

converter(::Type{T}, r::AbstractReactive{K}; eager::Bool = false) where {T, K} = Reactor{T}(
    () -> convert(T, getvalue(r)),
    (v::T) -> setvalue!(r, convert(K, v)),
    [r];
    eager,
)

public converter


"""
    resolve(r::MayBeReactive) -> Any
    resolve(::Type{T}, r::MayBeReactive) -> T

It resolves the value
"""
function resolve end

resolve(r) = r
resolve(::Type{T}, r) where {T} = convert(T, r)
resolve(r::AbstractReactive) = getvalue(r)
resolve(::Type{T}, r::AbstractReactive) where {T} = convert(T, getvalue(r))

"""
    update!(fn::Function, r::AbstractReactive)

A helper to update the reactive's value, 
the function receives the reactive's value 
and returns a new one.
"""
function update!(fn::Function, r::AbstractReactive)
    return @lock r setvalue(r, fn(getvalue(r)))
end

"""
    alter!(fn!::Function, r::AbstractReactive)

A helper to modify the value of a reactant, the passed
function receives the reactant value and can modify it,
the return of alter! is that of the passed function.
"""
function alter!(fn!::Function, r::AbstractReactive)
    return @lock r begin
        value = getvalue(r)
        ret = fn!(value)
        setvalue!(r, value)
        ret
    end
end


"""
Setvalue set's the value of a given AbstractReactive{T}
object.
It accepts a `notify` optional keyword argument which if 
set to false, prevents it from notifying subscribed values 
about it's change
"""
function setvalue! end


"""
    sync!(c::AbstractCatalyst, reactives::AbstractReactive ...)

Synchronize the values of the given reactive values.
"""
function sync!(c::AbstractCatalyst, reactives::AbstractReactive ...)
    local from::AbstractReactive
    local notifier = Base.Lockable{Union{AbstractReactive, Nothing}, ReentrantLock}(
        nothing,
        ReentrantLock(),
    )
    for outer from in reactives
        catalyze!(c, from) do _
            @lock notifier if isnothing(notifier[])
                notifier[] = from
            else
                return
            end
            try
                value = getvalue(from)
                for to in reactives
                    setvalue!(to, value)
                end
            finally
                @lock notifier notifier[] = nothing
            end
        end
    end
    return
end

end # module Ionic
