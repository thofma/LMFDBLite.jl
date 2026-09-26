struct FieldSpec
    id::Symbol
    label::String
    kind::Symbol
    help::String
end

const INTEGER_HELP = "Integer or expression (2^5), <=10, 2..2^5, 2-8, 2.., ..8, or 2,4; Blank: any."
const REAL_HELP = "Number, <=4.3, 1..4.3, 1.., ..4.3, or 1,2..3; Blank: any."
const GROUP_HELP = "Invariant factors: [], [3], [2,4]; each factor divides the next. Blank: any."

# Homepage order; the ramification relation belongs beside the ramified input.
const FIELD_SPECS = [
    FieldSpec(:degree, "Degree", :positive_integer, INTEGER_HELP),
    FieldSpec(:signature, "Signature", :signature, "(r1,r2) or [r1,r2], e.g. (1,1); degree = r1 + 2r2. Blank: any."),
    FieldSpec(:discriminant, "Discriminant", :integer, "Signed integer, expression, or range, e.g. -23, -2^5..-1, 0..2^5; Blank: any."),
    FieldSpec(:root_discriminant, "Root discriminant", :positive_real, REAL_HELP),
    FieldSpec(:galois_root_discriminant, "Galois root discriminant", :positive_real, REAL_HELP),
    FieldSpec(:regulator, "Regulator", :nonnegative_real, REAL_HELP),
    FieldSpec(:galois_group, "Galois group", :galois, "C5, 7T2, [8,3], 8.3, or comma-separated codes. Resolved when searching."),
    FieldSpec(:field_is, "Field is", :field_is, "Select a Galois property; Any imposes no condition."),
    FieldSpec(:ramified_prime_count, "Ramified prime count", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:ramified, "Ramified", :ramified, "2,3 or [2,3]; [] is an empty set. Primality is assumed. Blank: any."),
    FieldSpec(:class_number, "Class number", :positive_integer, INTEGER_HELP),
    FieldSpec(:class_group, "Class group structure", :class_group, GROUP_HELP),
    FieldSpec(:narrow_class_number, "Narrow class number", :positive_integer, INTEGER_HELP),
    FieldSpec(:narrow_class_group, "Narrow class group structure", :class_group, GROUP_HELP),
    FieldSpec(:relative_class_number, "Relative class number", :positive_integer, INTEGER_HELP),
    FieldSpec(:is_cm, "CM field", :boolean, "Any / Yes / No; No requires a field that is not CM."),
    FieldSpec(:index, "Index", :positive_integer, INTEGER_HELP),
    FieldSpec(:is_minimal_sibling, "Minimal sibling", :boolean, "Any / Yes / No; Any omits this condition."),
    FieldSpec(:limit, "Number of results", :limit, "Search limit; default 50. Blank returns all matches. Count ignores this limit."),
]

const FIELD_IS = [
    "Any" => nothing,
    "cyclic" => (:is_cyclic => true),
    "abelian" => (:is_abelian => true),
    "Galois" => (:is_galois => true),
    "solvable" => (:is_solvable => true),
    "nonsolvable" => (:is_solvable => false),
]
const RAMIFIED_RELATIONS = ["Contains all", "Exactly", "Contained in"]

default_input(spec::FieldSpec) = spec.kind in (:boolean, :field_is) ? "Any" :
                               spec.kind == :limit ? "50" : ""
