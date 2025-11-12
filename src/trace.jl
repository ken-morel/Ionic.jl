"""
utilities for tracing of reactive objects.
"""
module Tracing
using ..Ionic: Ionic

abstract type Trace end


struct TraceLog
    object::Ionic.AbstractReactive
    traces::Vector{Trace}
    TraceLog(r::Ionic.AbstractReactive) = new(r, Trace[])
end
Base.push!(l::TraceLog, t::Trace) = push!(l.traces, t)

const TRACE = Dict{UInt, TraceLog}()
const TRACE_SM = Base.Semaphore(1)
TRACE_COUNT::UInt = 1

function gettrace(id::UInt)
    id == 0 && return nothing
    return Base.acquire(TRACE_SM) do
        if haskey(TRACE, id)
            TRACE[id]
        end
    end
end
function createtrace(r::Ionic.AbstractReactive)
    return Base.acquire(TRACE_SM) do
        id = TRACE_COUNT
        TRACE_COUNT += 1
        TRACE[id] = TraceLog(r)
        id
    end
end
function trace(id::UInt, t::Trace)
    return Base.acquire(TRACE_SM) do
        push!(TRACE[id], t)
    end
end


@kwdef struct Get <: Trace
    value
    stack::Vector{Base.StackTraces.StackFrame}
    start::UInt
    stop::UInt
    error::Union{Exception, Nothing}
end


@kwdef struct Set <: Trace
    value::T
    stack::Vector{Base.StackTraces.StackFrame}
    start::UInt
    stop::UInt
    error::Union{Exception, Nothing}
end


function record(fn::Function, id::UInt, ::Type{T}) where {T <: Union{Get, Set}}
    start = time_ns()
    value = nothing
    error = nothing
    stack = stacktrace()[2:end]
    return try
        value = fn()
    catch e
        error = e
        rethrow()
    finally
        stop = time_ns()
        trace(id, T(; value, start, stop, error, stack))
    end
end
record(fn::Function, ::Nothing, ::Type{T}) where {T <: Union{Get, Set}} = fn()


@kwdef struct Notify <: Trace
    stack::Vector{Base.StackTraces.StackFrame}
    start::UInt
    stop::UInt
    reactions::Vector{AbstractReaction}
    error::Union{Exception, Nothing}
end

function record(fn::Function, id::UInt, ::Type{Notify})
    start = time_ns()
    error = nothing
    stack = stacktrace()[2:end]
    reactions::Ionic.AbstractReaction = Ionic.AbstractReaction[]
    return try
        reactions = fn()
    catch e
        error = e
        rethrow()
    finally
        stop = time_ns()
        trace(id, Notify(; start, stop, error, stack, reactions))
    end
end
record(fn::Function, ::Nothing, ::Type{T}) where {T <: Trace} = fn()

@kwdef struct Subscribe <: Trace
    reaction::Ionic.AbstractReaction

    start::UInt
    stop::UIntend
end

@kwdef struct Unsubscribe <: Trace
    reaction::Ionic.AbstractReaction
    start::UInt
    stop::UInt
end
@kwdef struct Inhibit <: Trace
    start::UInt
    stop::UInt
end
function record(fn::Function, id::UInt, ::Type{Inhibit})
    start = time_ns()
    fn()
    stop = time_ns()
    return trace(id, Inhibit(; start, stop))
end
record(fn::Function, ::Nothing, ::Type{Inhibit}) = fn()

function record(fn::Function, id::UInt, ::Type{T}, reaction::AbstractReaction) where {T <: Union{Subscribe, Unsubscribe}}
    trace(id, T(; reaction))
    start = time_ns()
    ret = fn()
    stop = time_ns()
    trace(id, T(; reaction, start, stop))
    return ret
end
record(fn::Function, ::Nothing, ::Type{T}, ::AbstractReaction) where {T <: Union{Subscribe, Unsubscribe}} = fn()

end
