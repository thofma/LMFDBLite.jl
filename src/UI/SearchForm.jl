mutable struct SearchForm <: T.Model
    quit::Bool
    submitted::Union{Nothing,NamedTuple}
    action::Symbol
    widgets::Dict{Symbol,Any}
    ids::Vector{Symbol}
    focus::T.FocusRing
    errors::Dict{Symbol,String}
    scroll::Int                   # first visible field row (zero based)
    columns::Int
    visible_rows::Int
    reveal_focus::Bool
    hits::Dict{Symbol,T.Rect}
    body::T.Rect
    status_area::T.Rect
    specs::Vector{FieldSpec}
    title::String
end

SearchForm() = SearchForm(FIELD_SPECS, "Number fields")

function SearchForm(specs::Vector{FieldSpec}, title::AbstractString)
    widgets = Dict{Symbol,Any}()
    ids = Symbol[]
    for spec in specs
        widgets[spec.id] = if spec.kind == :boolean
            T.DropDown(["Any", "Yes", "No"])
        elseif spec.kind == :field_is
            T.DropDown(first.(FIELD_IS))
        else
            T.TextInput(; text = default_input(spec), focused = false)
        end
        push!(ids, spec.id)
        if spec.id == :ramified
            widgets[:ramified_relation] = T.DropDown(copy(RAMIFIED_RELATIONS))
            push!(ids, :ramified_relation)
        end
    end
    for (id, label) in (:search => "Search", :count => "Count", :reset => "Reset", :back => "Back")
        widgets[id] = T.Button(label)
        push!(ids, id)
    end
    model = SearchForm(false, nothing, :search, widgets, ids,
        T.FocusRing(Any[widgets[id] for id in ids]), Dict{Symbol,String}(),
        0, 1, 1, true, Dict{Symbol,T.Rect}(), T.Rect(), T.Rect(), specs, String(title))
    sync_focus!(model)
    return model
end

T.should_quit(m::SearchForm) = m.quit
focused_id(m) = m.ids[m.focus.active]
field_id(id) = id == :ramified_relation ? :ramified : id

function sync_focus!(m)
    for id in m.ids
        widget = m.widgets[id]
        if widget isa Union{T.TextInput,T.Button}
            widget.focused = id == focused_id(m)
        end
    end
    m.reveal_focus = true
    return nothing
end

function focus!(m, id)
    old = T.current(m.focus)
    old isa T.DropDown && (old.open = false)
    m.focus.active = something(findfirst(==(id), m.ids))
    sync_focus!(m)
end

function form_inputs(m)
    return Dict(id => String(T.value(m.widgets[id])) for id in m.ids
                if !(m.widgets[id] isa T.Button))
end

function submit!(m, action = :search)
    empty!(m.errors)
    try
        inputs = form_inputs(m)
        action == :count && (inputs[:limit] = "") # Count all matches, regardless of the result limit.
        m.submitted = parse_inputs(m.specs, inputs)
        m.action = action
        m.quit = true
    catch e
        e isa InputError || rethrow()
        m.errors[e.field] = e.message
        focus!(m, e.field)
    end
    return nothing
end

function reset_form!(m)
    for spec in m.specs
        widget = m.widgets[spec.id]
        if widget isa T.TextInput
            T.set_text!(widget, default_input(spec))
        else
            T.set_value!(widget, 1)
            widget.open = false
        end
    end
    if haskey(m.widgets, :ramified_relation)
        T.set_value!(m.widgets[:ramified_relation], 1)
        m.widgets[:ramified_relation].open = false
    end
    empty!(m.errors)
    m.submitted = nothing
    m.action = :search
    m.scroll = 0
    focus!(m, first(m.ids))
end

function activate!(m, id)
    if id in (:search, :count)
        submit!(m, id)
    elseif id == :reset
        reset_form!(m)
    elseif id == :back
        m.quit = true
    end
    return nothing
end

function scroll!(m, delta)
    total = cld(length(m.specs), m.columns)
    m.scroll = clamp(m.scroll + delta, 0, max(0, total - m.visible_rows))
    m.reveal_focus = false
end

function T.update!(m::SearchForm, e::T.KeyEvent)
    m.quit && return
    e.action == T.key_release && return
    if e.key == :ctrl_c
        m.quit = true
        return
    elseif e.key == :ctrl && e.char == 's'
        submit!(m)
        return
    end
    widget = T.current(m.focus)
    # A selector consumes Enter/Escape before any application-level actions.
    if widget isa T.DropDown && widget.open && T.handle_key!(widget, e)
        delete!(m.errors, field_id(focused_id(m)))
        return
    end
    if e.key in (:tab, :backtab)
        widget isa T.DropDown && (widget.open = false)
        e.key == :tab ? T.next!(m.focus) : T.prev!(m.focus)
        sync_focus!(m)
    elseif e.key == :escape
        m.quit = true
    elseif e.key in (:pageup, :pagedown)
        scroll!(m, (e.key == :pageup ? -1 : 1) * m.visible_rows)
    else
        # Ctrl+U clears the focused text input; ordinary text is never a shortcut.
        if widget isa T.TextInput && e.key == :ctrl && e.char == 'u'
            T.clear!(widget)
        elseif T.handle_key!(widget, e)
            widget isa T.Button && activate!(m, focused_id(m))
        else
            return
        end
        widget isa T.Button || delete!(m.errors, field_id(focused_id(m)))
        m.reveal_focus = true
    end
    return nothing
end

function T.update!(m::SearchForm, e::T.MouseEvent)
    m.quit && return
    widget = T.current(m.focus)
    if widget isa T.DropDown && widget.open
        T.handle_mouse!(widget, e) && return
        if e.button == T.mouse_left && e.action == T.mouse_press
            widget.open = false
        else
            return
        end
    end
    if e.action == T.mouse_press && e.button in (T.mouse_scroll_up, T.mouse_scroll_down)
        T.contains(m.body, e.x, e.y) && scroll!(m, e.button == T.mouse_scroll_up ? -1 : 1)
    elseif e.button == T.mouse_left && e.action == T.mouse_press
        for id in m.ids
            haskey(m.hits, id) || continue
            T.contains(m.hits[id], e.x, e.y) || continue
            focus!(m, id)
            widget = m.widgets[id]
            T.handle_mouse!(widget, e)
            widget isa T.Button && activate!(m, id)
            delete!(m.errors, field_id(id))
            break
        end
    end
    return nothing
end

function draw_widget!(m, id, rect, buf)
    widget = m.widgets[id]
    # Draw selectors collapsed here, then draw the open one as an overlay last.
    if widget isa T.DropDown
        was_open = widget.open
        widget.open = false
        widget.style = T.tstyle(:text)
        widget.selected_style = id == focused_id(m) ? T.tstyle(:accent, bold = true) : T.tstyle(:primary)
        T.render(widget, rect, buf)
        widget.open = was_open
    else
        T.render(widget, rect, buf)
    end
    m.hits[id] = widget.last_area
end

function T.view(m::SearchForm, frame::T.Frame)
    render_form!(m, frame.area, frame.buffer)
end

function render_form!(m, area, buf)
    empty!(m.hits)
    for widget in values(m.widgets)
        widget.last_area = T.Rect() # hidden controls must never retain mouse targets
    end
    m.body = T.Rect()
    m.status_area = T.Rect()
    if area.width < 45 || area.height < 14
        T.render(T.Paragraph("Enlarge terminal to at least 45 x 14. Esc goes back.";
                            wrap = T.word_wrap), area, buf)
        return
    end
    inner = T.render(T.Block(; title = "$(m.title) — Search",
                             border_style = T.tstyle(:border),
                             title_style = T.tstyle(:title)), area, buf)
    T.set_string!(buf, inner.x + 1, inner.y,
                  "Fill any filters, then Search or Count.", T.tstyle(:text_dim);
                  max_x = T.right(inner))
    help_y = T.bottom(inner) - 4
    status_y = help_y - 3
    body = T.Rect(inner.x + 1, inner.y + 2, inner.width - 2,
                  max(1, status_y - (inner.y + 2)))
    m.status_area = T.Rect(inner.x + 1, status_y, inner.width - 2, 3)
    columns = area.width >= 110 ? 3 : area.width >= 80 ? 2 : 1
    visible_rows = max(1, body.height ÷ 3)
    if columns != m.columns || visible_rows != m.visible_rows
        m.reveal_focus = true
    end
    m.columns, m.visible_rows, m.body = columns, visible_rows, body
    total_rows = cld(length(m.specs), columns)
    index = findfirst(s -> s.id == field_id(focused_id(m)), m.specs)
    if m.reveal_focus && index !== nothing
        row = (index - 1) ÷ columns
        m.scroll = clamp(m.scroll, row - visible_rows + 1, row)
    end
    m.scroll = clamp(m.scroll, 0, max(0, total_rows - visible_rows))
    m.reveal_focus = false
    cell_width = (body.width - 3(columns - 1)) ÷ columns
    for (i, spec) in enumerate(m.specs)
        row, col = divrem(i - 1, columns)
        m.scroll <= row < m.scroll + visible_rows || continue
        x = body.x + col * (cell_width + 3)
        y = body.y + 3(row - m.scroll)
        style = haskey(m.errors, spec.id) ? T.tstyle(:error) :
                field_id(focused_id(m)) == spec.id ? T.tstyle(:accent, bold = true) : T.tstyle(:text_dim)
        label = spec.label * (haskey(m.errors, spec.id) ? " !" : "")
        T.set_string!(buf, x, y, label, style; max_x = x + cell_width - 1)
        # Give blank text inputs a visible track without inserting placeholder data.
        T.set_string!(buf, x, y + 1, repeat("·", cell_width), T.tstyle(:text_dim);
                      max_x = x + cell_width - 1)
        if spec.id == :ramified
            text_width = cell_width - 19
            draw_widget!(m, spec.id, T.Rect(x, y + 1, text_width, 1), buf)
            draw_widget!(m, :ramified_relation, T.Rect(x + text_width + 1, y + 1, 18, 1), buf)
        else
            draw_widget!(m, spec.id, T.Rect(x, y + 1, cell_width, 1), buf)
        end
    end

    help = if index === nothing
        focused_id(m) == :search ? "Search runs here; then browse the results or return them to Julia." :
        focused_id(m) == :count ? "Count closes the form and returns the total matches, ignoring the result limit." :
        focused_id(m) == :reset ? "Reset all filters and restore the result limit to 50." : "Back to the object list, keeping these filters."
    else
        spec = m.specs[index]
        get(m.errors, spec.id, "") * (haskey(m.errors, spec.id) ? " " : "") * spec.help
    end
    help_style = haskey(m.errors, field_id(focused_id(m))) ? T.tstyle(:error) :
                 T.Style(; fg = T.Color256(226), bold = true)
    T.render(T.Paragraph(help; wrap = T.word_wrap, style = help_style),
             T.Rect(inner.x + 1, help_y, inner.width - 2, 2), buf)
    actions = (:search, :count, :reset, :back)
    button_width = min(12, (inner.width - 2) ÷ length(actions))
    for (i, id) in enumerate(actions)
        draw_widget!(m, id, T.Rect(inner.x + 1 + (i - 1) * button_width, help_y + 2, button_width, 1), buf)
    end
    footer = "Ctrl+S: search  Tab/Shift-Tab: focus  PgUp/PgDn: scroll  Esc: back  Ctrl+C: quit"
    T.render(T.StatusBar(; left = [T.Span(footer, T.tstyle(:text_dim))],
                         right = [T.Span(" $(m.scroll + 1)-$(min(total_rows, m.scroll + visible_rows))/$total_rows ", T.tstyle(:text_dim))]),
             T.Rect(inner.x, T.bottom(inner), inner.width, 1), buf)

    # Fit the expanded selector into the form viewport, even for the last row.
    id = focused_id(m)
    widget = m.widgets[id]
    if widget isa T.DropDown && widget.open && haskey(m.hits, id)
        anchor = m.hits[id]
        widget.max_visible = min(6, length(widget.items), body.height - 1)
        widget.offset = clamp(widget.offset, max(0, widget.focused - widget.max_visible), widget.focused - 1)
        height = widget.max_visible + 1
        y = clamp(anchor.y, body.y, T.bottom(body) - height + 1)
        overlay = T.Rect(anchor.x, y, anchor.width, height)
        for line in y:y+height-1
            T.set_string!(buf, anchor.x, line, repeat(" ", anchor.width), T.tstyle(:text))
        end
        T.render(widget, overlay, buf)
        # Make navigation and the committed choice visible without relying on color.
        for row in 1:widget.max_visible
            item = widget.offset + row
            if item == widget.focused
                T.set_string!(buf, overlay.x, overlay.y + row, "›", widget.focused_style;
                              max_x = T.right(overlay))
            end
            if item == widget.selected
                T.set_string!(buf, T.right(overlay), overlay.y + row, "✓", widget.selected_style;
                              max_x = T.right(overlay))
            end
        end
        m.hits[id] = overlay
    end
    return nothing
end
