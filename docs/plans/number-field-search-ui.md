# Number-field search form: implementation handoff

Status: implemented, including the `ui()` landing page and in-UI search lifecycle
revisions of 2026-09-25. Repository baseline: `e60263e`.

## 1. Deliverable and scope

Build a Tachikoma terminal form that collects number-field search conditions,
validates them locally, then returns the result of
**`LMFDBLite.number_fields(LMFDBLite.lmfdb(); filters...)`** when submitted.
Search obtains raw `nf_fields` rows in a background task while the form remains
visible. On completion, the interface browses those rows. If the user returns
the results to the REPL, it converts the retained rows to number fields after
the terminal is restored, without repeating the query. Count returns the integer
from `LMFDBLite.count_number_fields(LMFDBLite.lmfdb(); filters...)`. Pagination,
sorting controls, and other mathematical objects are outside this step. Count
still closes the interface before it runs.

Reuse the existing cached default connection through `lmfdb()`, the raw `search`
backend, and the conversion logic shared with `number_fields`; use the existing
`count_number_fields` method for Count.

Follow the labels, examples, and relative field order of the homepage's Search
section. This first form exposes the filters the current Julia API can express;
the explicit gaps below prevent a claim of complete website parity. The website's
Browse and random-field links, and its separate label/name/polynomial jump box,
are outside the requested Search section. The local result browser only displays
the fields retrieved by the current search.

## 2. Public behavior

Export the entry point `ui`:

```julia
using LMFDBLite, Hecke
fields = ui()
```

Contract: `ui()` returns the vector produced by
`number_fields`, the integer produced by `count_number_fields`, or `nothing`
on cancellation. Do not force a return-type
annotation that introduces a hard dependency on Hecke.

- Open a landing page titled **LMFDB**, listing implemented object search
  pages. Currently the list contains **Number fields**. Arrow keys or a mouse
  click select an object; Enter opens its search page.
- The number-field form is initially blank, except for the result limit below.
- **Search** validates all entries. On success, capture typed keyword values and
  execute `LMFDBLite.search(LMFDBLite.lmfdb(), "nf_fields"; filters...)` exactly once
  in a Tachikoma background task. Keep the form and its submitted parameters
  visible and show a spinner in the status area below the fields while it runs.
- On success, show **Search complete. N field(s) retrieved** below the parameters
  and offer **Browse** and **Return results to REPL**. Browse shows the retained
  rows as labels and polynomials, with a scrollable detail pane for the available
  field invariants, and allows returning to the completed form. Returning to the REPL closes the interface, converts
  exactly those rows to number fields, and returns the resulting vector.
- **Count** validates the filters, ignoring the result-limit input, then closes
  the interface and calls `LMFDBLite.count_number_fields(LMFDBLite.lmfdb(); filters...)`
  exactly once. Return the total count unchanged; omit `limit` so it is uncapped.
- Invalid input keeps the form open, preserves all values, and focuses the
  first error with a concrete explanation and accepted example.
- **Reset** restores initial defaults. **Back** or Escape outside an open
  selector returns to the landing page, preserving filters. Escape on the
  landing page or Ctrl+C anywhere closes and returns `nothing` without
  obtaining a connection or executing a search.
- Leave REPL display to Julia's normal display of the returned value. Do not
  print source, manually print the returned vector, or wrap it in a new result type.
- Return an empty vector for Search or zero for Count when no fields match, preserving the distinction from
  cancellation. Show connection, query, and alias-resolution failures in the
  status area with the parameters still available for editing and retry. A field
  conversion failure propagates at the REPL after terminal restoration. Do not
  turn failures into an empty result or retry automatically.
- Keep parsing and keyword construction as pure functions for testing.

For example, submitting these values must have the same effect and return
type as executing:

```julia
LMFDBLite.number_fields(LMFDBLite.lmfdb();
    degree = 2,
    signature = (0, 1),
    discriminant = in(-1000:-1),
    ramified = LMFDBLite.includes([2, 3]),
    class_group = [2, 2],
    limit = 50,
)
```

No `conn` argument or variable is required. The launcher requires the existing
Hecke conversion extension, loaded through Hecke or Oscar. Before opening the
terminal, check that `number_fields(::LMFDBConnection)` is available and report
a clear instruction to load Hecke or Oscar if it is missing. This check must
not connect to the database. Constructing widgets, editing, local validation,
and cancellation remain offline; only successful submission accesses LMFDB.
Do not close the shared cached connection when the UI returns.

## 3. Field mapping

Use an ordered, number-field-specific field specification with stable symbol
IDs, labels, help, widget kinds, parsers, and search keyword mappings. Do not
derive the interface from dictionary iteration or use display labels as IDs.
The source of truth for supported Julia filters is
`src/SearchParameters/NumberField.jl`.

| Homepage label | Search keyword | Input and behavior |
| --- | --- | --- |
| Degree | `degree` | Positive integer condition |
| Signature | `signature` | `(r1,r2)`; also accept `[r1,r2]`; nonnegative integers with `r1 + 2r2 >= 1` |
| Discriminant | `discriminant` | Signed integer condition; preserve the sign |
| Root discriminant | `root_discriminant` | Positive real condition |
| Galois root discriminant | `galois_root_discriminant` | Positive real condition |
| Regulator | `regulator` | Nonnegative real condition |
| Galois group | `galois_group` | Group-code string, e.g. `C5`, `7T2`, `[8,3]`, `8.3` |
| Field is | See below | Selector; default Any |
| Ramified prime count | `ramified_prime_count` | Nonnegative integer condition |
| Ramified | `ramified` | Prime list and relation selector |
| Class number | `class_number` | Positive integer condition |
| Class group structure | `class_group` | Invariant-factor list, e.g. `[]`, `[3]`, `[2,4]` |
| Narrow class number | `narrow_class_number` | Positive integer condition |
| Narrow class group structure | `narrow_class_group` | Same list syntax as class group |
| Relative class number | `relative_class_number` | Positive integer condition |
| CM field | `is_cm` | Any / Yes / No; default Any |
| Index | `index` | Positive integer condition |
| Minimal sibling | `is_minimal_sibling` | Any / Yes / No; default Any |
| Number of results | `limit` | Search only: positive integer, default `50`; blank omits the keyword. Count ignores this input. |

The limit is an argument in the executed search call. It does not introduce
pagination. Explain in its help that blank uses the API's unlimited default
and Count always counts every match.

The **Field is** choices map as follows; Any omits the keyword:

| Choice | Keyword condition |
| --- | --- |
| cyclic | `is_cyclic = true` |
| abelian | `is_abelian = true` |
| Galois | `is_galois = true` |
| solvable | `is_solvable = true` |
| nonsolvable | `is_solvable = false` |

For **Ramified**, provide Exactly / Contains all / Contained in, initially
Contains all. Construct respectively a vector, `LMFDBLite.includes(vector)`, or
`issubset(vector)`. Accept `2,3` and `[2,3]`. Deduplicate and sort this set only;
do not reorder class-group invariant factors. Blank omits the filter, whereas
explicit `[]` preserves the selected empty-set condition.

Homepage controls omitted in this step because the API has no corresponding
supported predicate: maximum ramified prime, unramified primes, intermediate
field, p-adic completions, monogenic, inessential primes, and unit signature
rank. Also omit the multi-quadratic and two dihedral Field is choices: their
website mappings require additional group-family logic. List these gaps in the
README. Do not render editable controls whose values would be discarded, add
new database parameters, or approximate any of these filters.

The Julia API's additional `label` and `absolute_discriminant` filters need not
appear here: they are not separate inputs in the homepage Search form.

## 4. Parsing and keyword construction

Keep this layer independent of Tachikoma events, databases, and Hecke. Parse
into typed Julia values and predicates accepted by the existing API, collected
in a named tuple or ordered keyword pairs. Pass these directly to
`search` using keyword splatting. Parse integer arithmetic with Tryparse;
do not use `eval` or execute arbitrary Julia code.

Supported numeric syntax:

- A single number, e.g. `3`, `-23`, `4.3`.
- Comparisons `=`, `<`, `<=`, `>`, `>=`, e.g. `<=1000`.
- Inclusive ranges `a..b`; also `a-b` for nonnegative endpoints to match the
  homepage examples. Signed ranges use `..`, e.g. `-1000..-1`.
- Open bounds `a..` and `..b`.
- Comma-separated alternatives, e.g. `2,4,6..8`.
- Decimal and scientific notation in real-valued fields. Integer fields accept
  arithmetic expressions via `Tryparse.parse(BigInt, ...)`, including `2^5`,
  `<=2^5`, and `0..2^5`. Expression endpoints use the `..` range separator.

Construct integer ranges as `in(a:b)`, real ranges as
`LMFDBLite.allof(>=(a), <=(b))`, scalar alternatives as `in([values...])`, and
mixed alternatives as `LMFDBLite.anyof(...)`. A single bare number means
equality. Blank or whitespace-only input omits a condition, and Any must not
turn into `false`.

Additional rules:

- Add Tryparse as an unconditional dependency. Parse integer operands as `BigInt`;
  never round integer literals via Float64 or expand a range into a vector.
  Use `BigInt[]` for explicit empty integer vectors.
  Parse `limit` separately as a positive `Int`, reporting overflow locally.
- Parse real operands as finite Float64, matching the existing API. Reject
  NaN, infinities, reversed ranges, malformed lists, and unsupported syntax.
  Bounds such as `degree > 0` are valid even though zero is not a valid degree;
  distinguish comparison bounds from equality values during domain checks.
- Class-group factors must be at least 2 and each divide the next; `[]` means
  trivial, while a blank box imposes no condition. Preserve input order.
- Check ramified entries are integers at least 2. Avoid a new number-theory
  dependency just for primality validation; state in help that primality is
  assumed. This matches the current backend's integer-set input capability.
- For a supplied signature, detect incompatibility with a supplied degree
  condition by testing `r1 + 2r2` against that condition locally.
- Preserve Galois input as an ordinary Julia string. Validate basic group-code
  syntax and bracket balance locally; allow comma-separated codes without
  splitting commas inside `[8,3]`. Leave alias resolution and existence checks
  to the existing backend after submission.
- Keep keyword construction deterministic in field-specification order, with
  `limit` last. Use the existing `LMFDBLite.includes`, `LMFDBLite.allof`, and
  `LMFDBLite.anyof` constructors. All-blank filters with blank limit execute
  an unrestricted raw search and convert those rows only if they are returned
  to the REPL, which is equivalent to `LMFDBLite.number_fields(LMFDBLite.lmfdb())`.

## 5. Package and UI architecture

Tachikoma is a regular dependency, loaded by the built-in `LMFDBLite.UI` module.
Hecke remains optional and uses the existing package extension:

| File | Planned change |
| --- | --- |
| `Project.toml` | Add Tachikoma to regular dependencies and compatibility bounds |
| `src/UI.jl`, `src/LMFDBLite.jl` | Declare, document, include, and export `function ui end` |
| `src/UI/UI.jl` | Module and entry-point implementation, included by `src/UI.jl` |
| `src/UI/Fields.jl` | Ordered field specifications and selector mappings |
| `src/UI/Input.jl` | Pure parsing, validation, and typed keyword construction |
| `src/UI/NumberFieldForm.jl` | Model, widgets, event handling, layout |
| `src/UI/SearchUI.jl` | Landing page and navigation between object search pages |
| `test/number_field_search_ui.jl` | Offline parser, submission/return, and interaction tests |
| `test/core.jl` | Assert `ui()` is available from LMFDBLite alone, with Hecke still unloaded |
| `test/runtests.jl` | Include UI tests after `core.jl` and before `hecke.jl` |
| `test/hecke.jl` | Verify the launcher availability check after Hecke loads |
| `test/number_fields.jl` | Bounded submission smoke check in the existing opt-in live suite |
| `README.md`, `test/README.md` | Launch instructions, syntax, return behavior, gaps, tests |

Tachikoma UUID: `468859d6-42d8-48b7-8ad9-1d312e0e3b0a`. Version 2.6.1 is
installed locally; upstream main inspected here declares 2.7.0. Start with
compat `Tachikoma = "2.6.1"` and verify on that minimum version before relying
on newer APIs. Preserve the package's Julia 1.11 minimum. Do not modify
`Search.jl` or the SQL condition builders for this UI. Add a small Hecke
extension helper that converts an already retrieved row vector.

Use Tachikoma's `Model`, `update!`, `view`, `TextInput`, `DropDown`, `Button`,
`Block`, `StatusBar`, and focus utilities. Use persistent widget instances;
rendering must not recreate input state. A root model owns the landing-page
selection and number-field form, routing events to the active page and preserving
filters when going back. Track submission as validated keyword values in the
model, distinct from navigation or cancellation. The root model owns a
`TaskQueue`; Search uses `spawn_task!` and handles its `TaskEvent` on the app
thread. The public entry point uses the real `lmfdb()` and raw `search`
functions in the background, then the Hecke extension's row converter after UI
exit. Private orchestration helpers may accept test doubles for the app runner,
search executor, and converter. Keep blocking database work out of `update!`
and `view`, and preserve Tachikoma's terminal cleanup on exit. Count retains
its existing post-app execution so the terminal is restored before it queries.

Layout and interaction:

- Title: Number fields — Search. Terminals at least 110 characters wide use
  three columns in homepage order, starting with degree/signature/discriminant.
  Reflow to two columns at widths 80–109 and one column below 80.
- Keep Search, Count, Reset, Back and a short help/status area visible.
  Scroll the input area vertically; Tab/Shift-Tab must reveal the focused
  field. This is form scrolling, not result pagination.
- Reserve space below the fields for search progress, completion choices, and
  errors. Ignore form edits while a search is active so the visible parameters
  continue to describe the running query.
- In the result browser, keep Up/Down for selecting rows and use Page Up/Page
  Down or the mouse wheel to scroll the selected row's invariant details.
- At 80×24 every input and action must remain reachable. Support resizing
  without losing values. Extremely small terminals may show a resize hint.
- Show examples and validation errors near the focused field. Expanded
  selectors must fit within the viewport or use a small overlay.
- Give open selectors first chance to consume Escape and navigation keys;
  Enter in a selector must not submit the form. Enter on Search submits.
  Ctrl+S submits from any control, including an open selector, using the same
  validation and search action.
- Keep keyboard operation complete. Add mouse focus and button activation
  using the same actions; skip hits on clipped controls.

Implementation cautions verified in Tachikoma source: `Form` supplies focus and
validation but renders a single vertical column without automatic scrolling;
`ScrollPane` accepts text or a rendering callback, not `ScrollPane(form)`.
Use the widgets with a small custom responsive layout and explicit scroll/focus
management. `DropDown.value` returns the selected string. Avoid assumptions
that every widget has the same `focused` property type. Do not copy the form
demo's Ctrl+R reset shortcut: Tachikoma reserves Ctrl+R for recording. Buttons
alone are enough for this first version.

## 6. Implementation sequence and acceptance checks

1. **Wire the UI module and specify fields.** Add the entry point and regular
   dependency; establish the field mapping and empty/Any defaults. Verify
   loading LMFDBLite alone loads the UI and Tachikoma without loading Hecke.
2. **Implement parsing and keyword construction first.** Write table-driven
   cases for the documented syntax and mapping. The filters in section 2 must
   be reproducible without loading any UI or opening a database connection.
3. **Build the form around that pure layer.** Implement input preservation,
   focus, selectors, scrolling, local errors, and the four actions. Test the
   landing-page selection, back navigation, and transitions to submitted or
   cancelled state directly through model events.
4. **Connect submission to search or count.** Add the Hecke-extension availability check
   before launching. For Search, obtain the cached connection and call
   raw `search` in the model's background task; after completion, let the user
   browse the retained rows or convert those rows after returning to the REPL.
   For Count, close the app before obtaining
   the connection and calling `count_number_fields`. Use test doubles to verify
   ordering and exactly one execution, plus no connection or execution on
   cancellation or invalid input. Never
   invoke `lmfdb`, `search`, `number_fields`, `count_number_fields`, `galois_group_labels`, or metadata
   reflection while collecting or locally validating input.
5. **Document and verify.** Run the existing offline suite and UI tests with
   live-test environment flags unset. Add a small submission smoke check to
   the existing opt-in live tests, reusing their connection overrides and
   bounded number-field cases; do not introduce a new CI job or database
   requirement for the default suite. Perform one real-terminal smoke test
   with a restrictive filter and `limit = 1`, then open the
   relevant changes in the Codex review panel before the final handoff.

Run the full offline suite from the repository root:

```sh
LMFDB_TEST_LIVE=false LMFDB_TEST_PUBLIC_DEFAULT=false julia --project=. -e 'using Pkg; Pkg.test()'
```

Meaningful test coverage:

- Each active field maps to the intended public keyword; unset fields vanish.
- Negative discriminants, large integers, power expressions and range endpoints,
  mixed range/list conditions, real
  bounds, whitespace, invalid syntax, and degree/signature incompatibility.
- Empty versus blank class groups and ramification sets; all three set modes;
  Any versus No; all supported Field is mappings.
- Galois codes `[8,3]`, `8.3`, `C5`, and multiple codes with internal commas;
  malformed expressions must be rejected or remain inert string data.
- Verify typed keyword values and predicate behavior against independent
  expected cases. Test the executor receives these exact keywords and the
  default connection; no source parsing or evaluation is needed.
- Verify the launcher converts the selected executor's rows only after terminal
  restoration and returns that vector or the Count integer, including an empty
  vector or zero, while cancellation returns `nothing`.
  Count must omit the result limit, preserve filters, and skip field construction.
  Search errors must appear in the form and permit retry; cancellation before
  submission skips connection acquisition, and the launcher does not manually
  print the result.
- Use `Tachikoma.TestBackend` and synthetic `KeyEvent`s for focus, reset,
  cancellation, invalid submission, async completion, Browse, and rendering at
  120×40 and 80×24. Verify the spinner and completion controls share the form
  with the submitted parameters, and that keyboard and mouse return actions
  preserve the exact retained rows until conversion. Verify the last field and action buttons
  remain reachable after resizing.
- Exercise pure parsing and form events without Hecke loaded, and test the
  public launcher's helpful missing-Hecke error before terminal startup.
  After `hecke.jl` loads the extension, verify the availability check succeeds;
  use executor doubles for the return contract without network access.

Completion means a user can fill the supported number-field search form,
submit it, and receive the actual return value of
`LMFDBLite.number_fields(LMFDBLite.lmfdb(); ...)` or
`LMFDBLite.count_number_fields(LMFDBLite.lmfdb(); ...)` in their Julia session.
Search keeps the terminal interface visible until the user chooses to return
the results; Count restores the terminal before it runs.

## 7. References for the implementing agent

- [LMFDB number-field homepage](https://www.lmfdb.org/NumberField/).
  The live page presented a browser challenge during planning; its public
  implementation was used to inspect the form.
- [LMFDB form and search parser](https://github.com/LMFDB/lmfdb/blob/master/lmfdb/number_fields/number_field.py):
  `NFSearchArray.browse_array` for homepage controls, `number_field_search` for
  semantics. Inspected 2026-09-25; the live deployment may differ from master.
- [Tachikoma form tutorial](https://github.com/kahliburke/Tachikoma.jl/blob/8360d2ed1ba676de2e6c946afbbce5e2e23e9793/docs/src/tutorials/form-app.md),
  [form widget](https://github.com/kahliburke/Tachikoma.jl/blob/8360d2ed1ba676de2e6c946afbbce5e2e23e9793/src/widgets/form.jl),
  [scroll pane](https://github.com/kahliburke/Tachikoma.jl/blob/8360d2ed1ba676de2e6c946afbbce5e2e23e9793/src/widgets/scrollpane.jl),
  and [headless testing](https://github.com/kahliburke/Tachikoma.jl/blob/8360d2ed1ba676de2e6c946afbbce5e2e23e9793/docs/src/testing.md).
- Local API references: `src/NumberField.jl`,
  `src/SearchParameters/NumberField.jl`, `src/GaloisGroup.jl`, `src/Search.jl`,
  and `ext/LMFDBLiteHeckeExt/NumberField.jl`.
