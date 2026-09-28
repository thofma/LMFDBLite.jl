const SEARCH_PAGES = [
    :number_fields => "Number fields",
    :elliptic_curves => "Elliptic curves over Q",
    :elliptic_curves_number_fields => "Elliptic curves over number fields",
    :integer_lattices => "Integer lattices (experimental)",
    :genera => "Genera (experimental)",
]

const SEARCH_PAGE_TITLES = Dict(SEARCH_PAGES)

const SEARCH_TABLES = Dict(
    :number_fields => "nf_fields",
    :elliptic_curves => "ec_curvedata",
    :elliptic_curves_number_fields => "ec_nfcurves",
    :integer_lattices => "lat_lattices_new",
    :genera => "lat_genera",
)

const SEARCH_RESULT_NAMES = Dict(
    :number_fields => ("field", "fields"),
    :elliptic_curves => ("curve", "curves"),
    :elliptic_curves_number_fields => ("curve", "curves"),
    :integer_lattices => ("lattice", "lattices"),
    :genera => ("genus", "genera"),
)

const SEARCH_TASK_IDS = Dict(
    :number_fields => :number_field_search,
    :elliptic_curves => :elliptic_curve_search,
    :elliptic_curves_number_fields => :number_field_elliptic_curve_search,
    :integer_lattices => :integer_lattice_search,
    :genera => :genus_search,
)

const SEARCH_FORM_SPECS = Dict(
    :number_fields => FIELD_SPECS,
    :elliptic_curves => ELLIPTIC_CURVE_SPECS,
    :elliptic_curves_number_fields => NUMBER_FIELD_ELLIPTIC_CURVE_SPECS,
    :integer_lattices => INTEGER_LATTICE_SPECS,
    :genera => GENUS_SPECS,
)

search_number_field_rows(conn; filters...) =
    LMFDBLite.search(conn, "nf_fields"; filters...)

search_database_rows(page::Symbol, conn; filters...) =
    LMFDBLite.search(conn, SEARCH_TABLES[page]; filters...)

function search_executors(number_field_executor = search_number_field_rows)
    return Dict{Symbol,Any}(
        :number_fields => number_field_executor,
        :elliptic_curves =>
            (conn; filters...) -> search_database_rows(:elliptic_curves, conn; filters...),
        :elliptic_curves_number_fields =>
            (conn; filters...) -> search_database_rows(:elliptic_curves_number_fields, conn; filters...),
        :integer_lattices =>
            (conn; filters...) -> search_database_rows(:integer_lattices, conn; filters...),
        :genera =>
            (conn; filters...) -> search_database_rows(:genera, conn; filters...),
    )
end

mutable struct SearchUI <: T.Model
    quit::Bool
    page::Symbol
    objects::T.SelectableList
    number_fields::SearchForm
    forms::Dict{Symbol,SearchForm}
    database::Symbol
    submitted::Union{Nothing,NamedTuple}
    action::Symbol
    tasks::T.TaskQueue
    search_state::Symbol
    results::Any
    search_error::Union{Nothing,Exception}
    tick::Int
    completion_focus::Int
    browse_button::T.Button
    return_button::T.Button
    completion_hits::Dict{Symbol,T.Rect}
    result_list::Union{Nothing,T.SelectableList}
    result_detail::Union{Nothing,T.ScrollPane}
    return_to_repl::Bool
    connect::Any
    execute::Dict{Symbol,Any}
end

function SearchUI(; connect = LMFDBLite.lmfdb, execute = search_number_field_rows,
                    executes = search_executors(execute))
    forms = Dict(page => SearchForm(SEARCH_FORM_SPECS[page], title)
                 for (page, title) in SEARCH_PAGES)
    return SearchUI(false, :home,
        T.SelectableList(last.(SEARCH_PAGES); focused = true), forms[:number_fields],
        forms, :number_fields,
        nothing, :search, T.TaskQueue(), :editing, nothing, nothing, 0, 1,
        T.Button("Browse"), T.Button("Return results to REPL"),
        Dict{Symbol,T.Rect}(), nothing, nothing, false, connect, executes)
end

T.should_quit(m::SearchUI) = m.quit
T.task_queue(m::SearchUI) = m.tasks
T.set_wake!(m::SearchUI, notify::Function) = (m.tasks.on_ready = notify; nothing)

function open_selected_page!(m::SearchUI)
    page = first(SEARCH_PAGES[T.value(m.objects)])
    form = m.forms[page]
    form.quit = false
    form.submitted = nothing
    m.database = page
    m.search_state = :editing
    m.search_error = nothing
    focus!(form, first(form.ids))
    m.page = page
    return nothing
end

active_form(m::SearchUI) = m.forms[m.database]

const NUMBER_FIELD_ROW_PROPERTIES =
    (:label, :coeffs, :disc_sign, :disc_abs, :degree, :r2)

is_number_field_row(result) =
    all(property -> hasproperty(result, property), NUMBER_FIELD_ROW_PROPERTIES)

function polynomial_text(coefficients)
    terms = Tuple{Bool,String}[]
    for (degree, coefficient) in Iterators.reverse(enumerate(coefficients))
        value = BigInt(coefficient)
        iszero(value) && continue
        power = degree - 1
        magnitude = abs(value)
        monomial = power == 0 ? string(magnitude) :
                   power == 1 ? "x" : "x^$power"
        term = power > 0 && magnitude != 1 ? "$(magnitude)*$monomial" : monomial
        push!(terms, (value < 0, term))
    end
    isempty(terms) && return "0"
    negative, first_term = first(terms)
    result = negative ? "-$first_term" : first_term
    for (negative, term) in @view terms[2:end]
        result *= negative ? " - $term" : " + $term"
    end
    return result
end

function number_field_row_summary(row)
    return "$(row.label)  $(polynomial_text(row.coeffs))"
end

const NUMBER_FIELD_BOOLEAN_DETAILS =
    (:is_galois, :gal_is_abelian, :gal_is_cyclic, :gal_is_solvable,
     :cm, :is_minimal_sibling, :used_grh)

const NUMBER_FIELD_DETAIL_FIELDS = (
    (:rd, "Root discriminant"),
    (:grd, "Galois root discriminant"),
    (:disc_rad, "Discriminant radical"),
    (:galois_label, "Galois group"),
    (:is_galois, "Galois"),
    (:gal_is_abelian, "Abelian"),
    (:gal_is_cyclic, "Cyclic"),
    (:gal_is_solvable, "Solvable"),
    (:class_number, "Class number"),
    (:class_group, "Class group"),
    (:narrow_class_number, "Narrow class number"),
    (:narrow_class_group, "Narrow class group"),
    (:relative_class_number, "Relative class number"),
    (:regulator, "Regulator"),
    (:ramps, "Ramified primes"),
    (:num_ram, "Ramified prime count"),
    (:conductor, "Conductor"),
    (:index, "Index"),
    (:monogenic, "Monogenic"),
    (:cm, "CM field"),
    (:is_minimal_sibling, "Minimal sibling"),
    (:minimal_sibling, "Minimal sibling label"),
    (:unit_signature_rank, "Unit signature rank"),
    (:torsion_order, "Roots of unity"),
    (:subfields, "Subfields"),
    (:subfield_mults, "Subfield multiplicities"),
    (:local_algs, "Local algebras"),
    (:inessentialp, "Inessential primes"),
    (:galois_disc_exponents, "Galois discr. exponents"),
    (:maximal_cm_subfield, "Maximal CM subfield"),
    (:embeddings_gen_real, "Generator real embeddings"),
    (:embeddings_gen_imag, "Generator imag. embeddings"),
    (:used_grh, "GRH used"),
)

format_detail_value(value::Bool) = value ? "yes" : "no"
format_detail_value(value::AbstractVector) =
    "[" * join((string(item) for item in skipmissing(value)), ", ") * "]"
format_detail_value(value) = string(value)

function format_boolean_detail(value)
    value isa Bool && return format_detail_value(value)
    value == 1 && return "yes"
    value == 0 && return "no"
    value == -1 && return "unknown"
    return format_detail_value(value)
end

detail_line(label, value) = rpad("$label:", 28) * value

function append_number_field_detail!(lines, row, property, label)
    hasproperty(row, property) || return lines
    value = getproperty(row, property)
    (ismissing(value) || value === nothing) && return lines
    formatted = property in NUMBER_FIELD_BOOLEAN_DETAILS || property == :monogenic ?
                format_boolean_detail(value) : format_detail_value(value)
    push!(lines, detail_line(label, formatted))
    return lines
end

function number_field_row_detail_lines(row)
    discriminant = row.disc_sign * row.disc_abs
    signature = (row.degree - 2 * row.r2, row.r2)
    lines = [
        detail_line("LMFDB label", string(row.label)),
        detail_line("Defining polynomial", polynomial_text(row.coeffs)),
        detail_line("Degree", string(row.degree)),
        detail_line("Signature", string(signature)),
        detail_line("Discriminant", string(discriminant)),
    ]
    for (property, label) in NUMBER_FIELD_DETAIL_FIELDS
        append_number_field_detail!(lines, row, property, label)
    end
    return lines
end

number_field_row_detail(row) = join(number_field_row_detail_lines(row), '\n')

function row_identifier(result)
    for property in (:label, :lmfdb_label, :Clabel, :genus_label)
        hasproperty(result, property) || continue
        value = getproperty(result, property)
        (ismissing(value) || value === nothing) || return string(value)
    end
    return nothing
end

function generic_row_detail_lines(row::NamedTuple)
    lines = String[]
    for (property, value) in pairs(row)
        (ismissing(value) || value === nothing) && continue
        label = uppercasefirst(replace(String(property), '_' => ' '))
        push!(lines, detail_line(label, format_detail_value(value)))
    end
    return isempty(lines) ? ["No details available."] : lines
end

function compact_result(result, i, database = :number_fields)
    if is_number_field_row(result)
        return "$i. $(number_field_row_summary(result))"
    end
    identifier = result isa NamedTuple ? row_identifier(result) : nothing
    identifier === nothing || return "$i. $identifier"
    text = strip(sprint(show, result; context = :compact => true))
    text = replace(text, r"\s+" => " ")
    isempty(text) && (text = string(typeof(result)))
    return "$i. $text"
end

function make_result_list(results, database = :number_fields)
    items = [compact_result(result, i, database) for (i, result) in enumerate(results)]
    _, plural = SEARCH_RESULT_NAMES[database]
    return T.SelectableList(items; focused = true, show_scrollbar = true,
                            block = T.Block(; title = uppercasefirst(plural)))
end

function result_detail_lines(result, database = :number_fields)
    if is_number_field_row(result)
        return number_field_row_detail_lines(result)
    elseif result isa NamedTuple
        return generic_row_detail_lines(result)
    end
    return split(sprint(show, MIME"text/plain"(), result; context = :limit => true), '\n')
end

function make_result_detail(results, database = :number_fields)
    singular, plural = SEARCH_RESULT_NAMES[database]
    lines = isempty(results) ? ["No $plural to display."] : result_detail_lines(first(results), database)
    return T.ScrollPane(lines; following = false, word_wrap = true,
                        block = T.Block(; title = "Selected $singular"))
end

function refresh_result_detail!(m::SearchUI)
    m.result_detail === nothing && return nothing
    if isempty(m.results)
        _, plural = SEARCH_RESULT_NAMES[m.database]
        T.set_content!(m.result_detail, ["No $plural to display."])
        return nothing
    end
    index = clamp(T.value(m.result_list), 1, length(m.results))
    T.set_content!(m.result_detail, result_detail_lines(m.results[index], m.database))
    m.result_detail.offset = 0
    m.result_detail.following = false
    return nothing
end

function set_completion_focus!(m::SearchUI, index)
    m.completion_focus = clamp(index, 1, 2)
    m.browse_button.focused = m.completion_focus == 1
    m.return_button.focused = m.completion_focus == 2
    return nothing
end

function start_search!(m::SearchUI, filters::NamedTuple)
    m.submitted = filters
    m.action = :search
    m.search_state = :searching
    m.search_error = nothing
    m.results = nothing
    m.result_list = nothing
    m.result_detail = nothing
    m.return_to_repl = false
    active_form(m).quit = false
    connect = m.connect
    execute = m.execute[m.database]
    T.spawn_task!(m.tasks, SEARCH_TASK_IDS[m.database]) do
        execute(connect(); filters...)
    end
    return nothing
end

function finish_page!(m::SearchUI)
    form = active_form(m)
    form.quit || return nothing
    if form.submitted === nothing
        form.quit = false
        m.page = :home
    elseif form.action == :search
        start_search!(m, form.submitted)
    else
        m.submitted = form.submitted
        m.action = form.action
        m.quit = true
    end
    return nothing
end

function finish_search!(m::SearchUI, value)
    if value isa Exception
        m.search_state = :failed
        m.search_error = value
        active_form(m).submitted = nothing
        return nothing
    end
    m.results = value
    m.result_list = make_result_list(value, m.database)
    m.result_detail = make_result_detail(value, m.database)
    m.search_state = :complete
    m.search_error = nothing
    set_completion_focus!(m, 1)
    return nothing
end

function return_results!(m::SearchUI)
    m.return_to_repl = true
    m.quit = true
    return nothing
end

function activate_completion!(m::SearchUI)
    if m.completion_focus == 1
        m.page = :results
    else
        return_results!(m)
    end
    return nothing
end

function update_completion!(m::SearchUI, e::T.KeyEvent)
    if e.key in (:left, :backtab)
        set_completion_focus!(m, m.completion_focus - 1)
    elseif e.key in (:right, :tab)
        set_completion_focus!(m, m.completion_focus + 1)
    elseif e.key == :enter
        activate_completion!(m)
    elseif e.key == :escape
        m.search_state = :editing
        m.results = nothing
        m.result_list = nothing
        m.result_detail = nothing
        active_form(m).submitted = nothing
        focus!(active_form(m), :search)
    end
    return nothing
end

function update_results!(m::SearchUI, e::T.KeyEvent)
    if e.key == :escape
        m.page = m.database
    elseif e.key == :char && lowercase(e.char) == 'r'
        return_results!(m)
    elseif e.key in (:pageup, :pagedown) && m.result_detail !== nothing
        T.handle_key!(m.result_detail, e)
    elseif m.result_list !== nothing
        selected = T.value(m.result_list)
        T.handle_key!(m.result_list, e)
        T.value(m.result_list) != selected && refresh_result_detail!(m)
    end
    return nothing
end

function T.update!(m::SearchUI, e::T.TaskEvent)
    e.id == SEARCH_TASK_IDS[m.database] && m.search_state == :searching && finish_search!(m, e.value)
    return nothing
end

function T.update!(m::SearchUI, e::T.KeyEvent)
    (m.quit || e.action == T.key_release) && return
    if e.key == :ctrl_c
        m.quit = true
    elseif m.page == :home
        if e.key == :escape
            m.quit = true
        elseif e.key == :enter
            open_selected_page!(m)
        else
            T.handle_key!(m.objects, e)
        end
    elseif m.page == :results
        update_results!(m, e)
    elseif m.search_state == :searching
        return nothing
    elseif m.search_state == :complete
        update_completion!(m, e)
    else
        T.update!(active_form(m), e)
        finish_page!(m)
    end
    return nothing
end

function T.update!(m::SearchUI, e::T.MouseEvent)
    m.quit && return
    if m.page == :home
        T.handle_mouse!(m.objects, e) # click selects; Enter opens the selected page
    elseif m.page == :results
        selected = m.result_list === nothing ? 0 : T.value(m.result_list)
        handled = m.result_list !== nothing && T.handle_mouse!(m.result_list, e)
        m.result_list !== nothing && T.value(m.result_list) != selected && refresh_result_detail!(m)
        !handled && m.result_detail !== nothing && T.handle_mouse!(m.result_detail, e)
    elseif m.search_state == :complete && e.button == T.mouse_left && e.action == T.mouse_press
        for (i, id) in enumerate((:browse, :return_repl))
            haskey(m.completion_hits, id) || continue
            T.contains(m.completion_hits[id], e.x, e.y) || continue
            set_completion_focus!(m, i)
            activate_completion!(m)
            break
        end
    elseif m.search_state != :searching
        T.update!(active_form(m), e)
        finish_page!(m)
    end
    return nothing
end

function T.view(m::SearchUI, frame::T.Frame)
    m.tick += 1
    render_ui!(m, frame.area, frame.buffer)
end

function render_search_status!(m::SearchUI, buf)
    empty!(m.completion_hits)
    area = active_form(m).status_area
    area.width > 0 || return nothing
    if m.search_state == :searching
        spinner = T.SPINNER_BRAILLE[mod1(m.tick ÷ 3, length(T.SPINNER_BRAILLE))]
        T.set_char!(buf, area.x, area.y + 1, spinner, T.tstyle(:accent, bold = true))
        T.set_string!(buf, area.x + 2, area.y + 1, "Search underway…",
                      T.tstyle(:accent, bold = true); max_x = T.right(area))
    elseif m.search_state == :complete
        n = length(m.results)
        singular, plural = SEARCH_RESULT_NAMES[m.database]
        noun = n == 1 ? singular : plural
        T.set_string!(buf, area.x, area.y, "Search complete. $n $noun retrieved",
                      T.tstyle(:success, bold = true); max_x = T.right(area))
        browse_width = min(12, area.width)
        return_width = min(26, max(1, area.width - browse_width - 1))
        T.render(m.browse_button, T.Rect(area.x, area.y + 1, browse_width, 1), buf)
        T.render(m.return_button,
                 T.Rect(area.x + browse_width + 1, area.y + 1, return_width, 1), buf)
        m.completion_hits[:browse] = m.browse_button.last_area
        m.completion_hits[:return_repl] = m.return_button.last_area
    elseif m.search_state == :failed
        message = "Search failed: " * sprint(showerror, m.search_error)
        T.render(T.Paragraph(message; wrap = T.word_wrap, style = T.tstyle(:error)),
                 area, buf)
    end
    return nothing
end

function render_results!(m::SearchUI, area, buf)
    if area.width < 30 || area.height < 10
        T.render(T.Paragraph("Results — enlarge the terminal. Esc returns to the search.";
                            wrap = T.word_wrap), area, buf)
        return nothing
    end
    result_noun = length(m.results) == 1 ? "result" : "results"
    inner = T.render(T.Block(; title = "$(SEARCH_PAGE_TITLES[m.database]) — $(length(m.results)) $result_noun",
                             border_style = T.tstyle(:border),
                             title_style = T.tstyle(:title)), area, buf)
    footer_y = T.bottom(inner)
    content = T.Rect(inner.x, inner.y, inner.width, max(1, inner.height - 1))
    if area.width >= 80
        list_width = max(24, content.width ÷ 3)
        list_area = T.Rect(content.x, content.y, list_width, content.height)
        detail_area = T.Rect(content.x + list_width + 1, content.y,
                             max(1, content.width - list_width - 1), content.height)
        m.result_list !== nothing && T.render(m.result_list, list_area, buf)
        m.result_detail !== nothing && T.render(m.result_detail, detail_area, buf)
    else
        list_height = max(3, content.height ÷ 2)
        list_area = T.Rect(content.x, content.y, content.width, list_height)
        detail_area = T.Rect(content.x, content.y + list_height,
                             content.width, max(1, content.height - list_height))
        m.result_list !== nothing && T.render(m.result_list, list_area, buf)
        m.result_detail !== nothing && T.render(m.result_detail, detail_area, buf)
    end
    T.render(T.StatusBar(; left = [T.Span("Up/Down: browse  PgUp/PgDn: details  Esc: search", T.tstyle(:text_dim))],
                         right = [T.Span("R: return all results to REPL ", T.tstyle(:text_dim))]),
             T.Rect(inner.x, footer_y, inner.width, 1), buf)
    return nothing
end

function render_ui!(m::SearchUI, area, buf)
    m.objects.last_area = T.Rect()
    if m.page == :results
        return render_results!(m, area, buf)
    elseif haskey(m.forms, m.page)
        render_form!(active_form(m), area, buf)
        render_search_status!(m, buf)
        return nothing
    end
    if area.width < 30 || area.height < 10
        T.render(T.Paragraph("LMFDB — enlarge the terminal. Esc quits."; wrap = T.word_wrap), area, buf)
        return nothing
    end
    inner = T.render(T.Block(; border_style = T.tstyle(:border)), area, buf)
    width = min(60, inner.width - 4)
    x = inner.x + (inner.width - width) ÷ 2
    T.render(T.Paragraph("LMFDB"; alignment = T.align_center,
                         style = T.tstyle(:title, bold = true)),
             T.Rect(x, inner.y + 1, width, 1), buf)
    T.render(T.Paragraph("Choose an object to search"; alignment = T.align_center,
                         style = T.tstyle(:text_dim)),
             T.Rect(x, inner.y + 3, width, 1), buf)
    T.render(m.objects, T.Rect(x, inner.y + 5, width, min(length(SEARCH_PAGES), inner.height - 7)), buf)
    T.render(T.Paragraph("Up/Down: select   Enter: open   Esc: quit";
                         alignment = T.align_center, style = T.tstyle(:text_dim)),
             T.Rect(inner.x, T.bottom(inner), inner.width, 1), buf)
    return nothing
end
