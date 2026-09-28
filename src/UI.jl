"""
    ui()

Open the LMFDB terminal interface. Tachikoma is loaded automatically.
Load Hecke (or Oscar) first: `using LMFDBLite, Hecke`.

Select an object on the landing page with the arrow keys and press Enter to
open its search form. Search forms are available for number fields, elliptic
curves over Q, elliptic curves over number fields, integer lattices, and genera.
Integer lattices and genera are marked experimental because their underlying
LMFDB tables are experimental.
Back or Escape returns to the landing page, preserving the entered filters;
Escape on the landing page or Ctrl+C anywhere returns `nothing` without querying.

Ctrl+S or Search runs `search` on the selected database in the
background while the form and a spinner remain visible. The returned database
rows remain available for Browse in a scrollable detail pane. Return results to
REPL closes the interface, converts those rows to the selected mathematical
objects, and returns the resulting vector without repeating the query. Search
errors remain visible with the entered filters so they can be corrected and
retried. Count closes the interface and returns the number of matches, ignoring
the result limit.
No matches returns an empty vector for Search or zero for Count. The default
result limit is 50; clearing it uses the unlimited search default. The cached
connection remains open. No pagination is provided.
"""
function ui end

include("UI/UI.jl")
