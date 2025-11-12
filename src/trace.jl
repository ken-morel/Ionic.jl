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
        global TRACE_COUNT
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
    value
    stack::Vector{Base.StackTraces.StackFrame}
    start::UInt
    stop::UInt
    error::Union{Exception, Nothing}
end


function record(fn::Function, id::UInt, ::Type{T}) where {T <: Union{Get, Set}}
    start = time_ns()
    value = nothing
    error = nothing
    stack = stacktrace() # Capture the full stack trace
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
    reactions::Vector{Ionic.AbstractReaction}
    error::Union{Exception, Nothing}
end

function record(fn::Function, id::UInt, ::Type{Notify})
    start = time_ns()
    error = nothing
    stack = stacktrace() # Capture the full stack trace
    reactions = Ionic.AbstractReaction[]
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
    stop::UInt
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

function record(fn::Function, id::UInt, ::Type{T}, reaction::Ionic.AbstractReaction) where {T <: Union{Subscribe, Unsubscribe}}
    start = time_ns()
    ret = fn()
    stop = time_ns()
    trace(id, T(; reaction, start, stop))
    return ret
end
record(fn::Function, ::Nothing, ::Type{T}, ::Ionic.AbstractReaction) where {T <: Union{Subscribe, Unsubscribe}} = fn()

# --- Trace Visualization ---

const IONIC_SRC_PATH = dirname(@__FILE__)

function find_origin_frame(stack::Vector{Base.StackTraces.StackFrame})
    for frame in stack
        # Skip frames from files within the Ionic/src directory
        if startswith(String(frame.file), IONIC_SRC_PATH)
            continue
        end
        # This is the first frame outside of the Ionic source directory.
        return frame
    end
    return stack[1] # Fallback
end

function isinternal(trace::Trace)
    # Find the first frame outside of the Tracing module.
    # If its path is still inside the Ionic/src directory, it's an internal call.
    for frame in trace.stack
        if String(frame.file) == @__FILE__
            continue
        end
        return startswith(String(frame.file), IONIC_SRC_PATH)
    end
    return false
end

function format_time(ns)
    if ns < 1_000
        return "$ns ns"
    elseif ns < 1_000_000
        return "$(round(ns / 1_000, digits = 2)) μs"
    elseif ns < 1_000_000_000
        return "$(round(ns / 1_000_000, digits = 2)) ms"
    else
        return "$(round(ns / 1_000_000_000, digits = 2)) s"
    end
end

function Base.show(io::IO, ::MIME"text/plain", event::Get)
    printstyled(io, "GET"; color = :cyan)
    if isinternal(event)
        printstyled(io, " (internal)"; color=:light_black)
    end
    println(io, " ($(format_time(event.stop - event.start)))")
    println(io, "  Value: ", event.value)
    printstyled(io, "  From: ", color = :light_black)
    return println(io, find_origin_frame(event.stack))
end

function Base.show(io::IO, ::MIME"text/plain", event::Set)
    printstyled(io, "SET"; color = :magenta)
    if isinternal(event)
        printstyled(io, " (internal)"; color=:light_black)
    end
    println(io, " ($(format_time(event.stop - event.start)))")
    println(io, "  New Value: ", event.value)
    printstyled(io, "  From: ", color = :light_black)
    return println(io, find_origin_frame(event.stack))
end

function Base.show(io::IO, ::MIME"text/plain", event::Notify)
    printstyled(io, "NOTIFY"; color = :yellow)
    if isinternal(event)
        printstyled(io, " (internal)"; color=:light_black)
    end
    println(io, " ($(format_time(event.stop - event.start)))")
    println(io, "  Reactions triggered: ", length(event.reactions))
    printstyled(io, "  From: ", color = :light_black)
    return println(io, find_origin_frame(event.stack))
end

function Base.show(io::IO, ::MIME"text/plain", event::Subscribe)
    printstyled(io, "SUBSCRIBE"; color = :green)
    return println(io, " ($(format_time(event.stop - event.start)))")
end

function Base.show(io::IO, ::MIME"text/plain", event::Unsubscribe)
    printstyled(io, "UNSUBSCRIBE"; color = :red)
    return println(io, " ($(format_time(event.stop - event.start)))")
end

function Base.show(io::IO, ::MIME"text/plain", event::Inhibit)
    printstyled(io, "INHIBIT"; color = :red)
    return println(io, " ($(format_time(event.stop - event.start)))")
end

function Base.show(io::IO, m::MIME"text/plain", log::TraceLog)
    println(io, "TraceLog for ", typeof(log.object), ":")
    for (i, event) in enumerate(log.traces)
        print(io, i, ". ")
        show(io, m, event)
    end
    return
end

printtrace(l::TraceLog) = show(stdout, MIME("text/plain"), l)

end
