struct InputError <: Exception
    field::Symbol
    message::String
end
Base.showerror(io::IO, e::InputError) = print(io, e.message)

const REAL_PATTERN = r"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$"
const POSITIVE_REAL_TOKEN = raw"(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?"
const DASH_RANGE_PATTERN = Regex("^(" * POSITIVE_REAL_TOKEN * ")\\s*-\\s*(" * POSITIVE_REAL_TOKEN * ")\$")

# Tryparse 0.3.17 drops unary minus on expressions such as -(2^5).
# Multiplication preserves its meaning while leaving evaluation to Tryparse.
function normalize_integer_expression(ex)
    ex isa Expr || return ex
    args = map(normalize_integer_expression, ex.args)
    if ex.head == :call && length(args) == 2 && first(args) == :-
        return Expr(:call, :*, -1, args[2])
    end
    return Expr(ex.head, args...)
end

function integer_operand(s::AbstractString)
    try
        expression = normalize_integer_expression(Meta.parse(s))
        return Tryparse.parse(BigInt, expression isa Expr ? string(expression) : s)
    catch e
        # Very large decimal literals become @big_str syntax, which Tryparse
        # 0.3.17 does not accept. Preserve the existing exact literal input.
        if e isa Tryparse.ParseError
            literal = tryparse(BigInt, s)
            literal === nothing || return literal
        end
        e isa Union{Tryparse.ParseError, Meta.ParseError, ArgumentError,
                    DomainError, DivideError, InexactError, OverflowError,
                    BoundsError, MethodError, AssertionError} || rethrow()
        throw(ArgumentError("Expected an integer expression, e.g. 2^5."))
    end
end

function numeric_operand(s::AbstractString, integer::Bool)
    integer && return integer_operand(s)
    occursin(REAL_PATTERN, s) || throw(ArgumentError("Expected a finite real number."))
    value = tryparse(Float64, s)
    (value === nothing || !isfinite(value)) && throw(ArgumentError("Number is out of range."))
    return value
end

function check_domain(value, kind)
    if kind in (:positive_integer, :positive_real)
        value > 0 || throw(ArgumentError("Expected a positive value."))
    elseif kind in (:nonnegative_integer, :nonnegative_real)
        value >= 0 || throw(ArgumentError("Expected a nonnegative value."))
    end
    return value
end

function numeric_term(s::AbstractString, kind::Symbol)
    integer = kind in (:integer, :positive_integer, :nonnegative_integer)
    m = match(r"^(<=|>=|<|>|=)\s*(.+)$", s)
    if m !== nothing
        value = numeric_operand(strip(m[2]), integer)
        op = Dict("<" => (<), "<=" => (<=), ">" => (>), ">=" => (>=), "=" => (==))[m[1]]
        op === (==) && check_domain(value, kind)
        return op(value)
    end
    endpoints = if occursin("..", s)
        parts = split(s, ".."; keepempty = true)
        length(parts) == 2 || throw(ArgumentError("Use one range, e.g. 2..8."))
        strip.(parts)
    else
        m = match(DASH_RANGE_PATTERN, s)
        m === nothing ? nothing : [m[1], m[2]]
    end
    if endpoints !== nothing
        a, b = endpoints
        isempty(a) && isempty(b) && throw(ArgumentError("A range needs at least one endpoint."))
        isempty(a) && return <=(numeric_operand(b, integer))
        isempty(b) && return >=(numeric_operand(a, integer))
        lo = check_domain(numeric_operand(a, integer), kind)
        hi = check_domain(numeric_operand(b, integer), kind)
        lo <= hi || throw(ArgumentError("Range endpoints must be increasing."))
        return integer ? in(lo:hi) : LMFDBLite.allof(>=(lo), <=(hi))
    end
    return check_domain(numeric_operand(s, integer), kind)
end

function numeric_condition(s::AbstractString, kind::Symbol)
    terms = strip.(split(s, ','; keepempty = true))
    any(isempty, terms) && throw(ArgumentError("Missing value in the comma-separated list."))
    conditions = [numeric_term(term, kind) for term in terms]
    length(conditions) == 1 && return only(conditions)
    all(x -> x isa Number, conditions) && return in(conditions)
    return LMFDBLite.anyof(conditions...)
end

function integer_list(s::AbstractString; brackets = true)
    if startswith(s, '[') && endswith(s, ']')
        s = strip(chop(s; head = 1, tail = 1))
    elseif brackets
        throw(ArgumentError("Use a bracketed list, e.g. [2,4] or []."))
    end
    isempty(s) && return BigInt[]
    return BigInt[numeric_operand(strip(v), true) for v in split(s, ','; keepempty = true)]
end

function galois_input(s::AbstractString)
    code = uppercase(replace(s, r"\s+" => ""))
    # Check matching bracket types before using the backend's pure code splitter.
    stack = Char[]
    for c in code
        c in ('[', '(') && push!(stack, c)
        if c in (']', ')')
            (isempty(stack) || pop!(stack) != (c == ']' ? '[' : '(')) &&
                throw(ArgumentError("Unmatched brackets in Galois group."))
        end
    end
    isempty(stack) || throw(ArgumentError("Unmatched brackets in Galois group."))
    for part in LMFDBLite._split_galois_group_codes(code)
        # Abstract group labels may contain letters; alias existence is checked later.
        valid = occursin(r"^[0-9]+T[0-9]+$", part) ||
                occursin(r"^\[[0-9]+,[0-9]+\]$", part) ||
                occursin(r"^[0-9]+\.[0-9A-Z]+$", part) ||
                occursin(r"^[A-Z][A-Z0-9]*(?:\([0-9]+,[0-9]+\))?(?::[A-Z][A-Z0-9]*)*$", part)
        valid || throw(ArgumentError("Use a group code such as C5, 7T2, [8,3], or 8.3."))
    end
    return String(s)
end

function rational_operand(s::AbstractString)
    parts = strip.(split(s, '/'; keepempty = true))
    length(parts) in (1, 2) && all(part -> !isempty(part), parts) ||
        throw(ArgumentError("Use an integer or one fraction, e.g. 1/2."))
    numerator = integer_operand(first(parts))
    denominator = length(parts) == 1 ? big(1) : integer_operand(last(parts))
    iszero(denominator) && throw(ArgumentError("The denominator must be nonzero."))
    return numerator // denominator
end

function parse_field(spec::FieldSpec, input::AbstractString)
    s = strip(input)
    isempty(s) && return nothing
    kind = spec.kind
    kind in (:integer, :positive_integer, :nonnegative_integer, :real,
             :positive_real, :nonnegative_real) &&
        return numeric_condition(s, kind)
    if kind == :signature
        startswith(s, '(') && endswith(s, ')') && (s = "[" * chop(s; head = 1, tail = 1) * "]")
        values = integer_list(s)
        length(values) == 2 && all(>=(0), values) && values[1] + 2values[2] >= 1 ||
            throw(ArgumentError("Use (r1,r2) with nonnegative entries and positive degree."))
        return Tuple(values)
    elseif kind == :class_group
        values = integer_list(s)
        all(>=(2), values) && all(i -> iszero(rem(values[i+1], values[i])), 1:length(values)-1) ||
            throw(ArgumentError("Factors must be at least 2 and each divide the next; e.g. [2,4]."))
        return values
    elseif kind == :integer_list
        return integer_list(s)
    elseif kind == :rational
        return rational_operand(s)
    elseif kind == :text
        return String(s)
    elseif kind == :ramified
        values = integer_list(s; brackets = false)
        all(>=(2), values) || throw(ArgumentError("Enter primes at least 2, e.g. 2,3."))
        return sort!(unique!(values))
    elseif kind == :limit
        occursin(r"^[0-9]+$", s) || throw(ArgumentError("Use one positive integer or leave blank for no limit."))
        value = tryparse(Int, s)
        value !== nothing && value > 0 || throw(ArgumentError("Result limit must be a positive machine integer."))
        return value
    elseif kind == :galois
        return galois_input(s)
    elseif kind == :boolean
        s == "Any" && return nothing
        s in ("Yes", "No") || throw(ArgumentError("Select Any, Yes, or No."))
        return s == "Yes"
    elseif kind == :field_is
        i = findfirst(p -> first(p) == s, FIELD_IS)
        i === nothing && throw(ArgumentError("Select a field property from the list."))
        return last(FIELD_IS[i])
    end
    error("Unknown form field kind: $kind")
end

matches(c::LMFDBLite.And, value) = matches(c.a, value) && matches(c.b, value)
matches(c::LMFDBLite.Or, value) = matches(c.a, value) || matches(c.b, value)
matches(c::Base.Fix2, value) = c(value)
matches(c::Number, value) = c == value

function parse_inputs(specs::AbstractVector{FieldSpec}, inputs::AbstractDict)
    keywords = Pair{Symbol,Any}[]
    for spec in specs
        try
            value = parse_field(spec, get(inputs, spec.id, default_input(spec)))
            value === nothing && continue
            if spec.kind == :field_is
                push!(keywords, value)
            elseif spec.kind == :ramified
                relation = get(inputs, :ramified_relation, first(RAMIFIED_RELATIONS))
                relation in RAMIFIED_RELATIONS || throw(ArgumentError("Select a ramification relation."))
                value = relation == "Contains all" ? LMFDBLite.includes(value) :
                        relation == "Contained in" ? issubset(value) : value
                push!(keywords, spec.id => value)
            else
                push!(keywords, spec.id => value)
            end
        catch e
            e isa ArgumentError || rethrow()
            throw(InputError(spec.id, e.msg))
        end
    end
    result = (; keywords...)
    if haskey(result, :signature) && haskey(result, :degree)
        r1, r2 = result.signature
        matches(result.degree, r1 + 2r2) ||
            throw(InputError(:signature, "Signature has degree $(r1 + 2r2), outside the Degree condition."))
    elseif haskey(result, :signature) && haskey(result, :rank)
        nplus, nminus = result.signature
        matches(result.rank, nplus + nminus) ||
            throw(InputError(:signature, "Signature has rank $(nplus + nminus), outside the Rank condition."))
    end
    return result
end

parse_inputs(inputs::AbstractDict) = parse_inputs(FIELD_SPECS, inputs)
