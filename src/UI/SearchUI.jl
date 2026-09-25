# Only implemented search pages belong in this menu.
const SEARCH_PAGES = [:number_fields => "Number fields"]

mutable struct SearchUI <: T.Model
    quit::Bool
    page::Symbol
    objects::T.SelectableList
    number_fields::NumberFieldForm
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
    return_to_repl::Bool
    connect::Any
    execute::Any
end

function SearchUI(; connect = LMFDBLite.lmfdb, execute = LMFDBLite.number_fields)
    return SearchUI(false, :home,
        T.SelectableList(last.(SEARCH_PAGES); focused = true), NumberFieldForm(),
        nothing, :search, T.TaskQueue(), :editing, nothing, nothing, 0, 1,
        T.Button("Browse"), T.Button("Return results to REPL"),
        Dict{Symbol,T.Rect}(), nothing, false, connect, execute)
end

T.should_quit(m::SearchUI) = m.quit
T.task_queue(m::SearchUI) = m.tasks
T.set_wake!(m::SearchUI, notify::Function) = (m.tasks.on_ready = notify; nothing)

function open_selected_page!(m::SearchUI)
    page = first(SEARCH_PAGES[T.value(m.objects)])
    if page == :number_fields
        m.number_fields.quit = false
        m.number_fields.submitted = nothing
        m.search_state = :editing
        m.search_error = nothing
        focus!(m.number_fields, first(m.number_fields.ids))
        m.page = page
    end
    return nothing
end

function compact_result(result, i)
    text = strip(sprint(show, result; context = :compact => true))
    text = replace(text, r"\s+" => " ")
    isempty(text) && (text = string(typeof(result)))
    return "$i. $text"
end

function make_result_list(results)
    items = [compact_result(result, i) for (i, result) in enumerate(results)]
    return T.SelectableList(items; focused = true, show_scrollbar = true,
                            block = T.Block(; title = "Fields"))
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
    m.return_to_repl = false
    m.number_fields.quit = false
    connect = m.connect
    execute = m.execute
    T.spawn_task!(m.tasks, :number_field_search) do
        execute(connect(); filters...)
    end
    return nothing
end

function finish_page!(m::SearchUI)
    form = m.number_fields
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
        m.number_fields.submitted = nothing
        return nothing
    end
    m.results = value
    m.result_list = make_result_list(value)
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
        m.number_fields.submitted = nothing
        focus!(m.number_fields, :search)
    end
    return nothing
end

function update_results!(m::SearchUI, e::T.KeyEvent)
    if e.key == :escape
        m.page = :number_fields
    elseif e.key == :char && lowercase(e.char) == 'r'
        return_results!(m)
    elseif m.result_list !== nothing
        T.handle_key!(m.result_list, e)
    end
    return nothing
end

function T.update!(m::SearchUI, e::T.TaskEvent)
    e.id == :number_field_search && m.search_state == :searching && finish_search!(m, e.value)
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
        T.update!(m.number_fields, e)
        finish_page!(m)
    end
    return nothing
end

function T.update!(m::SearchUI, e::T.MouseEvent)
    m.quit && return
    if m.page == :home
        T.handle_mouse!(m.objects, e) # click selects; Enter opens the selected page
    elseif m.page == :results
        m.result_list !== nothing && T.handle_mouse!(m.result_list, e)
    elseif m.search_state == :complete && e.button == T.mouse_left && e.action == T.mouse_press
        for (i, id) in enumerate((:browse, :return_repl))
            haskey(m.completion_hits, id) || continue
            T.contains(m.completion_hits[id], e.x, e.y) || continue
            set_completion_focus!(m, i)
            activate_completion!(m)
            break
        end
    elseif m.search_state != :searching
        T.update!(m.number_fields, e)
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
    area = m.number_fields.status_area
    area.width > 0 || return nothing
    if m.search_state == :searching
        spinner = T.SPINNER_BRAILLE[mod1(m.tick ÷ 3, length(T.SPINNER_BRAILLE))]
        T.set_char!(buf, area.x, area.y + 1, spinner, T.tstyle(:accent, bold = true))
        T.set_string!(buf, area.x + 2, area.y + 1, "Search underway…",
                      T.tstyle(:accent, bold = true); max_x = T.right(area))
    elseif m.search_state == :complete
        n = length(m.results)
        noun = n == 1 ? "field" : "fields"
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

function result_detail(m::SearchUI)
    (m.result_list === nothing || isempty(m.results)) && return "No fields to display."
    index = clamp(T.value(m.result_list), 1, length(m.results))
    return sprint(show, MIME"text/plain"(), m.results[index]; context = :limit => true)
end

function render_results!(m::SearchUI, area, buf)
    if area.width < 30 || area.height < 10
        T.render(T.Paragraph("Results — enlarge the terminal. Esc returns to the search.";
                            wrap = T.word_wrap), area, buf)
        return nothing
    end
    result_noun = length(m.results) == 1 ? "result" : "results"
    inner = T.render(T.Block(; title = "Number fields — $(length(m.results)) $result_noun",
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
        T.render(T.Paragraph(result_detail(m); wrap = T.word_wrap,
                             block = T.Block(; title = "Selected field")), detail_area, buf)
    else
        list_height = max(3, content.height ÷ 2)
        list_area = T.Rect(content.x, content.y, content.width, list_height)
        detail_area = T.Rect(content.x, content.y + list_height,
                             content.width, max(1, content.height - list_height))
        m.result_list !== nothing && T.render(m.result_list, list_area, buf)
        T.render(T.Paragraph(result_detail(m); wrap = T.word_wrap,
                             block = T.Block(; title = "Selected field")), detail_area, buf)
    end
    T.render(T.StatusBar(; left = [T.Span("Up/Down: browse  Esc: search", T.tstyle(:text_dim))],
                         right = [T.Span("R: return all results to REPL ", T.tstyle(:text_dim))]),
             T.Rect(inner.x, footer_y, inner.width, 1), buf)
    return nothing
end

function render_ui!(m::SearchUI, area, buf)
    m.objects.last_area = T.Rect()
    if m.page == :results
        return render_results!(m, area, buf)
    elseif m.page == :number_fields
        render_form!(m.number_fields, area, buf)
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
