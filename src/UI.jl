"""
    ui()

Open the LMFDB terminal interface. Tachikoma is loaded automatically.
Load Hecke (or Oscar) first: `using LMFDBLite, Hecke`.

Select an object on the landing page with the arrow keys and press Enter to
open its search form. Currently, Number fields is the available search page.
Back or Escape returns to the landing page, preserving the entered filters;
Escape on the landing page or Ctrl+C anywhere returns `nothing` without querying.

Ctrl+S or Search runs `number_fields(lmfdb(); filters...)` in the background
while the form and a spinner remain visible. On completion, Browse opens the
retrieved fields inside the interface; Return results to REPL closes the
interface and returns the original vector. Search errors remain visible with
the entered filters so they can be corrected and retried.
Count closes the interface and returns `count_number_fields(lmfdb(); filters...)`,
ignoring the result limit to count all matches.
No matches returns an empty vector for Search or zero for Count. The default
result limit is 50; clearing it uses the unlimited search default. The cached
connection remains open. No pagination is provided.
"""
function ui end

include("UI/UI.jl")
