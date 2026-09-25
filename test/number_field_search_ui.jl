using Tachikoma
const NFUI = LMFDBLite.UI

# Test predicate behavior independently of the form's degree/signature check.
ui_accepts(c::LMFDBLite.And, x) = ui_accepts(c.a, x) && ui_accepts(c.b, x)
ui_accepts(c::LMFDBLite.Or, x) = ui_accepts(c.a, x) || ui_accepts(c.b, x)
ui_accepts(c::Base.Fix2, x) = c(x)
ui_accepts(c, x) = c == x

function ui_render(m, width = 120, height = 40)
    tb = Tachikoma.TestBackend(width, height)
    NFUI.render_form!(m, Tachikoma.Rect(1, 1, width, height), tb.buf)
    return tb
end

function ui_fill!(m, values)
    for (id, value) in pairs(values)
        widget = m.widgets[id]
        if widget isa Tachikoma.TextInput
            Tachikoma.set_text!(widget, value)
        else
            Tachikoma.set_value!(widget, something(findfirst(==(value), widget.items)))
        end
    end
    return m
end

function ui_receive_task!(m; timeout = 5.0)
    deadline = time() + timeout
    while !isready(m.tasks.channel)
        time() < deadline || error("Timed out waiting for UI background task")
        sleep(0.001)
    end
    event = take!(m.tasks.channel)
    Tachikoma.update!(m, event)
    return event
end

@testset "Number-field form without Hecke" begin
    @test NFUI !== nothing
    @test Base.get_extension(LMFDBLite, :LMFDBLiteHeckeExt) === nothing
    @test_throws ArgumentError ui()
    @test LMFDBLite._lmfdb_cache[] === nothing
end

@testset "Number-field form input" begin
    @test NFUI.parse_inputs(Dict()) == (; limit = 50)
    @test NFUI.parse_inputs(Dict(:limit => " ")) == NamedTuple()
    @test NFUI.parse_inputs(Dict(:degree => " 2 ", :signature => "[0, 1]")) ==
        (; degree = big(2), signature = (big(0), big(1)), limit = 50)

    cases = [
        ("3", ==(3)), ("=3", ==(3)), ("<3", <(3)), ("<=3", <=(3)),
        (">3", >(3)), (">=3", >=(3)), ("2..4", x -> 2 <= x <= 4),
        ("2-4", x -> 2 <= x <= 4), ("2..", >=(2)), ("..4", <=(4)),
        ("2,4", x -> x in (2, 4)), ("2,4,6..8", x -> x in (2, 4, 6, 7, 8)),
        ("<=2,>=7", x -> x <= 2 || x >= 7),
        ("2^3", ==(8)), ("<=2^3", <=(8)), ("2..2^3", x -> 2 <= x <= 8),
        ("2^3..", >=(8)), ("..2^3", <=(8)),
        ("2^1,2^2,2^3..10", x -> x in (2, 4, 8, 9, 10)),
    ]
    for (input, expected) in cases
        actual = NFUI.parse_inputs(Dict(:degree => input)).degree
        @test [ui_accepts(actual, n) for n in 0:10] == expected.(0:10)
    end
    for key in (:degree, :class_number, :narrow_class_number, :relative_class_number,
                :index, :ramified_prime_count)
        condition = getproperty(NFUI.parse_inputs(Dict(key => "2..2^3")), key)
        @test condition(2) && condition(8) && !condition(9)
        @test condition.x isa UnitRange{BigInt}
        @test_throws NFUI.InputError NFUI.parse_inputs(Dict(key => "1.5"))
    end
    @test NFUI.parse_inputs(Dict(:ramified_prime_count => "0")).ramified_prime_count == 0
    @test_throws NFUI.InputError NFUI.parse_inputs(Dict(:degree => "0"))
    @test NFUI.parse_inputs(Dict(:degree => ">0", :signature => "(0,1)")).degree(2)
    @test_throws NFUI.InputError NFUI.parse_inputs(Dict(:degree => "3,5..8", :signature => "(0,1)"))
    @test_throws NFUI.InputError NFUI.parse_inputs(Dict(:degree => "2", :signature => "(1,1)"))

    disc = NFUI.parse_inputs(Dict(:discriminant => "-1000..-1")).discriminant
    @test disc(-1000) && disc(-1) && !disc(0) && !disc(-1001)
    @test NFUI.parse_inputs(Dict(:discriminant => "-23")).discriminant == -23
    large = big(10)^80
    @test NFUI.parse_inputs(Dict(:discriminant => string(large))).discriminant == large
    @test NFUI.parse_inputs(Dict(:discriminant => string(-large))).discriminant == -large
    @test NFUI.parse_inputs(Dict(:discriminant => "1..$large")).discriminant.x isa UnitRange{BigInt}
    @test NFUI.parse_inputs(Dict(:discriminant => "10^80")).discriminant == large
    @test NFUI.parse_inputs(Dict(:discriminant => "-2^5")).discriminant == -32
    @test NFUI.parse_inputs(Dict(:discriminant => "-(2^5) + 1")).discriminant == -31
    @test NFUI.parse_inputs(Dict(:discriminant => "2 * -(2^5)")).discriminant == -64
    @test NFUI.parse_inputs(Dict(:discriminant => "2^5 - 1")).discriminant == 31
    for key in (:discriminant, :ramified_prime_count)
        condition = getproperty(NFUI.parse_inputs(Dict(key => "0..2^5")), key)
        @test condition.x isa UnitRange{BigInt}
        @test [condition(n) for n in (-1, 0, 16, 32, 33)] == [false, true, true, true, false]
    end
    disc = NFUI.parse_inputs(Dict(:discriminant => "-2^5..-1")).discriminant
    @test [disc(n) for n in (-33, -32, -1, 0)] == [false, true, true, false]
    disc = NFUI.parse_inputs(Dict(:discriminant => "0..10^80")).discriminant
    @test disc.x isa UnitRange{BigInt}
    @test first(disc.x) == 0 && last(disc.x) == large
    @test NFUI.parse_inputs(Dict(:signature => "(2^1,0)")).signature == (big(2), big(0))
    @test NFUI.parse_inputs(Dict(:ramified => "2^1,3", :ramified_relation => "Exactly")).ramified == BigInt[2,3]

    for key in (:root_discriminant, :galois_root_discriminant, :regulator)
        condition = getproperty(NFUI.parse_inputs(Dict(key => "1..4.3")), key)
        @test [ui_accepts(condition, x) for x in (0.9, 1.0, 2.5, 4.3, 4.4)] == [false, true, true, true, false]
        @test getproperty(NFUI.parse_inputs(Dict(key => "1e-3-2e-3")), key) isa LMFDBLite.And
        @test getproperty(NFUI.parse_inputs(Dict(key => ".5,2.5")), key)(0.5)
        @test getproperty(NFUI.parse_inputs(Dict(key => "1e2")), key) === 100.0
    end
    @test NFUI.parse_inputs(Dict(:regulator => "0")).regulator === 0.0
    for input in ("NaN", "Inf", "1e999", "4..1", "..", "1...2", "1,,2", "1,", "sin(1)", "1;exit()")
        @test_throws NFUI.InputError NFUI.parse_inputs(Dict(:root_discriminant => input))
    end
    for input in ("1.5", "2^", "2^foo", "2^-1", "1/0", "1%0", "div(1)",
                  "0..2^", "2^5..2", "sin(1)", "1;exit()", "in(1:10)", "-4--1", "[2,3]",
                  "\"2\"", "'3'", "0")
        @test_throws NFUI.InputError NFUI.parse_inputs(Dict(:degree => input))
    end
    for input in ("(1)", "(1,2,3)", "[-1,2]", "(0,0)", "[1,2)")
        @test_throws NFUI.InputError NFUI.parse_inputs(Dict(:signature => input))
    end
    for key in (:class_group, :narrow_class_group)
        @test getproperty(NFUI.parse_inputs(Dict(key => "[]")), key) == BigInt[]
        @test getproperty(NFUI.parse_inputs(Dict(key => "[2,4]")), key) == BigInt[2,4]
        @test getproperty(NFUI.parse_inputs(Dict(key => "[2^1,2^3]")), key) == BigInt[2,8]
        @test !haskey(NFUI.parse_inputs(Dict(key => " ")), key)
        for input in ("[4,2]", "[2,3]", "[1]", "2,4", "[2,]", "[-2]")
            @test_throws NFUI.InputError NFUI.parse_inputs(Dict(key => input))
        end
    end
    for key in (:is_cm, :is_minimal_sibling)
        @test !haskey(NFUI.parse_inputs(Dict(key => "Any")), key)
        @test getproperty(NFUI.parse_inputs(Dict(key => "Yes")), key) === true
        @test getproperty(NFUI.parse_inputs(Dict(key => "No")), key) === false
    end
    for (choice, key, value) in [("cyclic", :is_cyclic, true), ("abelian", :is_abelian, true),
            ("Galois", :is_galois, true), ("solvable", :is_solvable, true), ("nonsolvable", :is_solvable, false)]
        @test NFUI.parse_inputs(Dict(:field_is => choice)) == (; key => value, :limit => 50)
    end
    for code in ("[8,3]", "8.3", "C5", "7T2", " [8,3], C5 ", "PSL(2,5),C2xC2", "C3:C4")
        @test NFUI.parse_inputs(Dict(:galois_group => code)).galois_group == strip(code)
    end
    for code in ("[8,3)", "C5,", "[8,3", "C5;exit()", "\"C5\"", "\$(exit())")
        @test_throws NFUI.InputError NFUI.parse_inputs(Dict(:galois_group => code))
    end
    for (relation, expected) in [("Exactly", [2,3]), ("Contains all", LMFDBLite.includes([2,3])),
                                 ("Contained in", issubset([2,3]))]
        condition = NFUI.parse_inputs(Dict(:ramified => "3,2,2", :ramified_relation => relation)).ramified
        for primes in (Int[], [2], [2,3], [2,3,5])
            @test ui_accepts(condition, primes) == ui_accepts(expected, primes)
        end
        empty_condition = NFUI.parse_inputs(Dict(:ramified => "[]", :ramified_relation => relation)).ramified
        @test ui_accepts(empty_condition, Int[])
        @test ui_accepts(empty_condition, [2]) == (relation == "Contains all")
        @test !haskey(NFUI.parse_inputs(Dict(:ramified => " ", :ramified_relation => relation)), :ramified)
    end
    @test_throws NFUI.InputError NFUI.parse_inputs(Dict(:ramified => "1,2"))
    for input in ("0", "-1", "1..10", "1.5", string(big(typemax(Int)) + 1))
        @test_throws NFUI.InputError NFUI.parse_inputs(Dict(:limit => input))
    end
end

@testset "Form interaction and layout" begin
    m = NFUI.NumberFieldForm()
    @test NFUI.focused_id(m) == :degree
    tb = ui_render(m)
    @test Tachikoma.find_text(tb, "Number fields") !== nothing
    @test m.columns == 3
    @test Tachikoma.find_text(tb, "Search") !== nothing
    @test Tachikoma.find_text(tb, "Count") !== nothing
    @test Tachikoma.find_text(tb, "Ctrl+S: search") !== nothing
    Tachikoma.update!(m, Tachikoma.KeyEvent('3'))
    Tachikoma.update!(m, Tachikoma.KeyEvent(:tab))
    @test NFUI.focused_id(m) == :signature
    Tachikoma.update!(m, Tachikoma.KeyEvent(:backtab))
    @test NFUI.form_inputs(m)[:degree] == "3"
    Tachikoma.update!(m, Tachikoma.KeyEvent(:ctrl, 'u'))
    @test NFUI.form_inputs(m)[:degree] == ""

    for (width, height) in ((120,40), (80,24), (45,14))
        for id in m.ids
            NFUI.focus!(m, id)
            ui_render(m, width, height)
            @test haskey(m.hits, id)
            @test m.hits[id].width > 0
            @test Tachikoma.right(m.hits[id]) < width
        end
        NFUI.focus!(m, :is_minimal_sibling)
        ui_render(m, width, height)
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        ui_render(m, width, height)
        rect = m.widgets[:is_minimal_sibling].last_area
        @test rect.y >= m.body.y && Tachikoma.bottom(rect) <= Tachikoma.bottom(m.body)
        Tachikoma.update!(m, Tachikoma.KeyEvent(:down))
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        @test !m.quit
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        Tachikoma.update!(m, Tachikoma.KeyEvent(:escape))
        @test !m.quit
    end
    ui_render(m, 20, 5) # graceful tiny-terminal fallback
    @test isempty(m.hits)
    NFUI.focus!(m, :limit)
    ui_render(m, 80, 24)
    @test m.scroll > 0 && !haskey(m.hits, :degree)
    Tachikoma.update!(m, Tachikoma.KeyEvent(:pageup))
    ui_render(m, 80, 24)
    Tachikoma.update!(m, Tachikoma.KeyEvent('1'))
    ui_render(m, 80, 24)
    @test haskey(m.hits, :limit) # typing reveals focus after manual scrolling

    ui_fill!(m, (; degree = "oops", signature = "(0,1)"))
    NFUI.focus!(m, :is_cm)
    Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
    @test m.widgets[:is_cm].open
    Tachikoma.update!(m, Tachikoma.KeyEvent(:ctrl, 's'))
    @test !m.quit && m.submitted === nothing
    @test NFUI.focused_id(m) == :degree && haskey(m.errors, :degree)
    tb = ui_render(m, 80, 24)
    @test Tachikoma.find_text(tb, "Expected an integer") !== nothing
    @test NFUI.form_inputs(m)[:signature] == "(0,1)"

    NFUI.focus!(m, :reset)
    Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
    @test NFUI.form_inputs(m)[:limit] == "50"
    @test NFUI.form_inputs(m)[:signature] == ""
    @test isempty(m.errors)

    # Mouse clicks use only the current visible widget rectangles.
    ui_render(m, 80, 24)
    rect = m.hits[:degree]
    Tachikoma.update!(m, Tachikoma.MouseEvent(rect.x, rect.y, Tachikoma.mouse_left,
                                          Tachikoma.mouse_press, false, false, false))
    @test NFUI.focused_id(m) == :degree
    ui_fill!(m, (; degree = "2", signature = "(0,1)", limit = "1"))
    ui_render(m, 80, 24)
    rect = m.hits[:search]
    Tachikoma.update!(m, Tachikoma.MouseEvent(rect.x, rect.y, Tachikoma.mouse_left,
                                          Tachikoma.mouse_press, false, false, false))
    @test m.quit && m.submitted == (; degree = big(2), signature = (big(0),big(1)), limit = 1)
    for key in (:escape, :ctrl_c)
        cancelled = NFUI.NumberFieldForm()
        Tachikoma.update!(cancelled, Tachikoma.KeyEvent(key))
        @test cancelled.quit && cancelled.submitted === nothing
    end
end

@testset "Search runs in the UI and returns results after selection" begin
    events = Symbol[]
    connection = Ref(:connection)
    returned = [Ref(:first), Ref(:second)]
    started = Channel{Nothing}(1)
    release = Channel{Nothing}(1)
    runner = function(m)
        push!(events, :open)
        @test m.page == :home
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        ui_fill!(m.number_fields, (; degree = "2", limit = "1"))
        Tachikoma.update!(m, Tachikoma.KeyEvent(:ctrl, 's'))
        @test take!(started) === nothing
        @test !m.quit && m.page == :number_fields && m.search_state == :searching
        @test NFUI.form_inputs(m.number_fields)[:degree] == "2"
        Tachikoma.update!(m, Tachikoma.KeyEvent('9'))
        @test NFUI.form_inputs(m.number_fields)[:degree] == "2"
        tb = Tachikoma.TestBackend(120, 40)
        m.tick = 3
        NFUI.render_ui!(m, Tachikoma.Rect(1, 1, 120, 40), tb.buf)
        @test Tachikoma.find_text(tb, "Search underway") !== nothing
        @test Tachikoma.find_text(tb, "Degree") !== nothing
        put!(release, nothing)
        event = ui_receive_task!(m)
        @test event.id == :number_field_search
        @test m.search_state == :complete && m.results === returned && !m.quit
        tb = Tachikoma.TestBackend(120, 40)
        NFUI.render_ui!(m, Tachikoma.Rect(1, 1, 120, 40), tb.buf)
        @test Tachikoma.find_text(tb, "Search complete. 2 fields retrieved") !== nothing
        @test Tachikoma.find_text(tb, "Browse") !== nothing
        @test Tachikoma.find_text(tb, "Return results to REPL") !== nothing
        @test Tachikoma.find_text(tb, "Degree") !== nothing
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        @test m.page == :results
        tb = Tachikoma.TestBackend(120, 40)
        NFUI.render_ui!(m, Tachikoma.Rect(1, 1, 120, 40), tb.buf)
        @test Tachikoma.find_text(tb, "Number fields — 2 results") !== nothing
        @test Tachikoma.find_text(tb, "Ref") !== nothing
        Tachikoma.update!(m, Tachikoma.KeyEvent(:down))
        @test Tachikoma.value(m.result_list) == 2
        tb = Tachikoma.TestBackend(120, 40)
        NFUI.render_ui!(m, Tachikoma.Rect(1, 1, 120, 40), tb.buf)
        @test Tachikoma.find_text(tb, "second") !== nothing
        Tachikoma.update!(m, Tachikoma.KeyEvent(:escape))
        @test m.page == :number_fields && m.search_state == :complete
        Tachikoma.update!(m, Tachikoma.KeyEvent(:right))
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        @test m.quit && m.return_to_repl
        push!(events, :restored)
    end
    connect = () -> (push!(events, :connect); connection)
    execute = function(conn; kw...)
        push!(events, :execute)
        @test conn === connection
        @test (; kw...) == (; degree = big(2), limit = 1)
        put!(started, nothing)
        take!(release)
        return returned
    end
    @test NFUI.run_ui(; runner, connect, execute) === returned
    @test events == [:open, :connect, :execute, :restored]

    empty_runner = function(m)
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        Tachikoma.update!(m, Tachikoma.KeyEvent(:ctrl, 's'))
        ui_receive_task!(m)
        @test m.search_state == :complete
        tb = Tachikoma.TestBackend(80, 24)
        NFUI.render_ui!(m, Tachikoma.Rect(1, 1, 80, 24), tb.buf)
        @test Tachikoma.find_text(tb, "Search complete. 0 fields retrieved") !== nothing
        rect = m.completion_hits[:return_repl]
        Tachikoma.update!(m, Tachikoma.MouseEvent(rect.x, rect.y, Tachikoma.mouse_left,
            Tachikoma.mouse_press, false, false, false))
        @test m.quit && m.return_to_repl
    end
    empty = Any[]
    @test NFUI.run_ui(; runner = empty_runner, connect = () -> :connection,
                       execute = (c; kw...) -> empty) === empty

    failed_runner = function(m)
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        Tachikoma.update!(m, Tachikoma.KeyEvent(:ctrl, 's'))
        ui_receive_task!(m)
        @test m.search_state == :failed && !m.quit
        tb = Tachikoma.TestBackend(80, 24)
        NFUI.render_ui!(m, Tachikoma.Rect(1, 1, 80, 24), tb.buf)
        @test Tachikoma.find_text(tb, "Search failed: query failed") !== nothing
        @test Tachikoma.find_text(tb, "Degree") !== nothing
        Tachikoma.update!(m, Tachikoma.KeyEvent(:ctrl_c))
    end
    @test NFUI.run_ui(; runner = failed_runner, connect = () -> :connection,
                       execute = (c; kw...) -> error("query failed")) === nothing

    never = (args...; kw...) -> error("must not run")
    @test NFUI.run_ui(; runner = m -> nothing, connect = never, execute = never) === nothing
    @test NFUI.run_ui(; runner = m -> Tachikoma.update!(m, Tachikoma.KeyEvent(:escape)),
                               connect = never, execute = never) === nothing
    invalid = function(m)
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        ui_fill!(m.number_fields, (; degree = "oops"))
        Tachikoma.update!(m, Tachikoma.KeyEvent(:ctrl, 's'))
        @test m.page == :number_fields && !m.quit && m.search_state == :editing
    end
    @test NFUI.run_ui(; runner = invalid, connect = never, execute = never) === nothing
    @test_throws ErrorException NFUI.run_ui(; runner = m -> error("terminal failed"), connect = never)
    @test LMFDBLite._lmfdb_cache[] === nothing
end

@testset "Count returns the total after terminal restoration" begin
    never = (args...; kw...) -> error("must not run")
    for activation in (:keyboard, :mouse), limit in ("50", "1", "", "invalid")
        events = Symbol[]
        connection = Ref(:connection)
        runner = function(m)
            push!(events, :open)
            Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
            ui_fill!(m.number_fields, (; degree = "2", discriminant = "0..2^5", limit))
            NFUI.focus!(m.number_fields, :count)
            ui_render(m.number_fields, 45, 14)
            if activation == :keyboard
                Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
            else
                rect = m.number_fields.hits[:count]
                Tachikoma.update!(m, Tachikoma.MouseEvent(rect.x, rect.y, Tachikoma.mouse_left,
                    Tachikoma.mouse_press, false, false, false))
            end
            @test m.quit
            @test NFUI.form_inputs(m.number_fields)[:limit] == limit
            push!(events, :restored)
        end
        connect = () -> (push!(events, :connect); connection)
        execute_count = function(conn; kw...)
            push!(events, :count)
            @test conn === connection
            @test Set(keys(kw)) == Set((:degree, :discriminant))
            @test kw[:degree] == 2
            @test [kw[:discriminant](n) for n in (-1, 0, 32, 33)] == [false, true, true, false]
            return 123
        end
        @test NFUI.run_ui(; runner, connect, execute = never, execute_count) === 123
        @test events == [:open, :restored, :connect, :count]
    end

    count_runner = function(m)
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        NFUI.focus!(m.number_fields, :count)
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        @test m.quit && m.submitted == NamedTuple()
    end
    @test NFUI.run_ui(; runner = count_runner, connect = () -> nothing, execute = never,
                       execute_count = (c; kw...) -> 0) === 0
    @test_throws ErrorException NFUI.run_ui(; runner = count_runner, connect = () -> nothing,
        execute = never, execute_count = (c; kw...) -> error("count failed"))

    invalid = function(m)
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        ui_fill!(m.number_fields, (; degree = "oops"))
        NFUI.focus!(m.number_fields, :count)
        Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
        @test !m.quit && m.submitted === nothing
        @test m.page == :number_fields
        @test NFUI.focused_id(m.number_fields) == :degree
        @test haskey(m.number_fields.errors, :degree)
    end
    @test NFUI.run_ui(; runner = invalid, connect = never, execute = never, execute_count = never) === nothing
    @test NFUI.run_ui(; runner = m -> nothing, connect = never, execute = never, execute_count = never) === nothing
    @test LMFDBLite._lmfdb_cache[] === nothing
end

@testset "LMFDB landing page and navigation" begin
    m = NFUI.SearchUI()
    for (width, height) in ((120,40), (80,24), (30,10))
        tb = Tachikoma.TestBackend(width, height)
        NFUI.render_ui!(m, Tachikoma.Rect(1, 1, width, height), tb.buf)
        @test Tachikoma.find_text(tb, "LMFDB") !== nothing
        @test Tachikoma.find_text(tb, "Number fields") !== nothing
        @test m.page == :home && !m.quit
    end
    # The available page is selectable with arrows or a click; Enter opens it.
    for key in (:up, :down, :home, :end_key)
        Tachikoma.update!(m, Tachikoma.KeyEvent(key))
        @test Tachikoma.value(m.objects) == 1
        @test m.page == :home
    end
    rect = m.objects.last_area
    Tachikoma.update!(m, Tachikoma.MouseEvent(rect.x, rect.y, Tachikoma.mouse_left,
                                          Tachikoma.mouse_press, false, false, false))
    @test m.page == :home
    Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
    @test m.page == :number_fields && !m.quit
    tb = Tachikoma.TestBackend(80,24)
    NFUI.render_ui!(m, Tachikoma.Rect(1, 1, 80, 24), tb.buf)
    @test Tachikoma.find_text(tb, "Number fields — Search") !== nothing
    @test Tachikoma.find_text(tb, "Back") !== nothing
    ui_fill!(m.number_fields, (; degree = "2", signature = "(0,1)"))
    NFUI.focus!(m.number_fields, :is_cm)
    Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
    Tachikoma.update!(m, Tachikoma.KeyEvent(:escape))
    @test m.page == :number_fields # closes the selector first
    Tachikoma.update!(m, Tachikoma.KeyEvent(:escape))
    @test m.page == :home && !m.quit && m.submitted === nothing
    Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
    @test NFUI.form_inputs(m.number_fields)[:degree] == "2"
    @test NFUI.form_inputs(m.number_fields)[:signature] == "(0,1)"
    NFUI.focus!(m.number_fields, :back)
    Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
    @test m.page == :home && !m.quit
    Tachikoma.update!(m, Tachikoma.KeyEvent(:enter))
    ui_render(m.number_fields, 80, 24)
    rect = m.number_fields.hits[:back]
    Tachikoma.update!(m, Tachikoma.MouseEvent(rect.x, rect.y, Tachikoma.mouse_left,
                                          Tachikoma.mouse_press, false, false, false))
    @test m.page == :home && !m.quit
    Tachikoma.update!(m, Tachikoma.KeyEvent(:escape))
    @test m.quit && m.submitted === nothing
    for page in (:home, :number_fields)
        cancelled = NFUI.SearchUI()
        page == :number_fields && Tachikoma.update!(cancelled, Tachikoma.KeyEvent(:enter))
        Tachikoma.update!(cancelled, Tachikoma.KeyEvent(:ctrl_c))
        @test cancelled.quit && cancelled.submitted === nothing
    end
    @test LMFDBLite._lmfdb_cache[] === nothing
end
