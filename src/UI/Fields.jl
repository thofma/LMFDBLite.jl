struct FieldSpec
    id::Symbol
    label::String
    kind::Symbol
    help::String
end

const INTEGER_HELP = "Integer or expression (2^5), <=10, 2..2^5, 2-8, 2.., ..8, or 2,4; Blank: any."
const REAL_HELP = "Number, <=4.3, 1..4.3, 1.., ..4.3, or 1,2..3; Blank: any."
const GROUP_HELP = "Invariant factors: [], [3], [2,4]; each factor divides the next. Blank: any."
const TEXT_HELP = "Exact text value; blank: any."
const LIST_HELP = "Exact bracketed integer list, e.g. [], [2], or [2,4]; blank: any."
const RATIONAL_HELP = "Exact integer or rational value, e.g. 1, -3, or 1/2; blank: any."
const BOOLEAN_HELP = "Any / Yes / No; Any imposes no condition."

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

const ELLIPTIC_CURVE_SPECS = [
    FieldSpec(:label, "LMFDB label", :text, TEXT_HELP),
    FieldSpec(:cremona_label, "Cremona label", :text, TEXT_HELP),
    FieldSpec(:isogeny_class, "LMFDB isogeny class", :text, TEXT_HELP),
    FieldSpec(:cremona_isogeny_class, "Cremona isogeny class", :text, TEXT_HELP),
    FieldSpec(:number, "Curve number", :positive_integer, INTEGER_HELP),
    FieldSpec(:cremona_number, "Cremona number", :positive_integer, INTEGER_HELP),
    FieldSpec(:conductor, "Conductor", :positive_integer, INTEGER_HELP),
    FieldSpec(:rank, "Rank", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:analytic_rank, "Analytic rank", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:torsion_order, "Torsion order", :positive_integer, INTEGER_HELP),
    FieldSpec(:torsion_structure, "Torsion structure", :integer_list, LIST_HELP),
    FieldSpec(:torsion_primes, "Torsion primes", :integer_list, LIST_HELP),
    FieldSpec(:a_invariants, "a-invariants", :integer_list, LIST_HELP),
    FieldSpec(:j_invariant, "j-invariant", :rational, RATIONAL_HELP),
    FieldSpec(:discriminant, "Discriminant", :integer, INTEGER_HELP),
    FieldSpec(:cm_discriminant, "CM discriminant", :integer, INTEGER_HELP),
    FieldSpec(:isogeny_degrees, "Isogeny degrees", :integer_list, LIST_HELP),
    FieldSpec(:isogeny_class_degree, "Isogeny class degree", :positive_integer, INTEGER_HELP),
    FieldSpec(:isogeny_class_size, "Isogeny class size", :positive_integer, INTEGER_HELP),
    FieldSpec(:modular_degree, "Modular degree", :positive_integer, INTEGER_HELP),
    FieldSpec(:sha, "Tate–Shafarevich order", :positive_integer, INTEGER_HELP),
    FieldSpec(:sha_primes, "Tate–Shafarevich primes", :integer_list, LIST_HELP),
    FieldSpec(:regulator, "Regulator", :nonnegative_real, REAL_HELP),
    FieldSpec(:semistable, "Semistable", :boolean, BOOLEAN_HELP),
    FieldSpec(:potential_good_reduction, "Potential good reduction", :boolean, BOOLEAN_HELP),
    FieldSpec(:squarefree_discriminant, "Squarefree discriminant", :boolean, BOOLEAN_HELP),
    FieldSpec(:bad_primes, "Bad primes", :integer_list, LIST_HELP),
    FieldSpec(:bad_prime_count, "Bad prime count", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:integral_point_count, "Integral point count", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:manin_constant, "Manin constant", :positive_integer, INTEGER_HELP),
    FieldSpec(:optimality, "Optimality", :integer, INTEGER_HELP),
    FieldSpec(:nonmaximal_primes, "Nonmaximal primes", :integer_list, LIST_HELP),
    FieldSpec(:nonmaximal_radical, "Nonmaximal radical", :positive_integer, INTEGER_HELP),
    FieldSpec(:minimal_quadratic_twist_discriminant, "Minimal twist discriminant", :integer, INTEGER_HELP),
    FieldSpec(:minimal_quadratic_twist_a_invariants, "Minimal twist a-invariants", :integer_list, LIST_HELP),
    FieldSpec(:faltings_height, "Faltings height", :real, REAL_HELP),
    FieldSpec(:stable_faltings_height, "Stable Faltings height", :real, REAL_HELP),
    FieldSpec(:adelic_level, "Adelic level", :positive_integer, INTEGER_HELP),
    FieldSpec(:adelic_index, "Adelic index", :positive_integer, INTEGER_HELP),
    FieldSpec(:adelic_genus, "Adelic genus", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:abc_quality, "abc quality", :real, REAL_HELP),
    FieldSpec(:szpiro_ratio, "Szpiro ratio", :real, REAL_HELP),
    FieldSpec(:intrinsic_torsion, "Intrinsic torsion", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:limit, "Number of results", :limit, "Search limit; default 50. Blank returns all matches. Count ignores this limit."),
]

const NUMBER_FIELD_ELLIPTIC_CURVE_SPECS = [
    FieldSpec(:label, "LMFDB label", :text, TEXT_HELP),
    FieldSpec(:field_label, "Number field label", :text, TEXT_HELP),
    FieldSpec(:degree, "Field degree", :positive_integer, INTEGER_HELP),
    FieldSpec(:signature, "Field signature", :signature, "(r1,r2) or [r1,r2], e.g. (0,1); blank: any."),
    FieldSpec(:conductor_label, "Conductor label", :text, TEXT_HELP),
    FieldSpec(:conductor_norm, "Conductor norm", :positive_integer, INTEGER_HELP),
    FieldSpec(:isogeny_class, "Isogeny class", :text, TEXT_HELP),
    FieldSpec(:number, "Curve number", :positive_integer, INTEGER_HELP),
    FieldSpec(:rank, "Rank", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:analytic_rank, "Analytic rank", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:torsion_order, "Torsion order", :positive_integer, INTEGER_HELP),
    FieldSpec(:torsion_structure, "Torsion structure", :integer_list, LIST_HELP),
    FieldSpec(:torsion_primes, "Torsion primes", :integer_list, LIST_HELP),
    FieldSpec(:a_invariants, "a-invariants", :text, "Exact semicolon-separated coefficient text; blank: any."),
    FieldSpec(:j_invariant, "j-invariant", :text, "Exact coefficient text in the field power basis; blank: any."),
    FieldSpec(:cm_discriminant, "CM discriminant", :integer, INTEGER_HELP),
    FieldSpec(:isogeny_degrees, "Isogeny degrees", :integer_list, LIST_HELP),
    FieldSpec(:isogeny_class_degree, "Isogeny class degree", :positive_integer, INTEGER_HELP),
    FieldSpec(:isogeny_class_size, "Isogeny class size", :positive_integer, INTEGER_HELP),
    FieldSpec(:regulator, "Regulator", :nonnegative_real, REAL_HELP),
    FieldSpec(:sha, "Tate–Shafarevich order", :positive_integer, INTEGER_HELP),
    FieldSpec(:semistable, "Semistable", :boolean, BOOLEAN_HELP),
    FieldSpec(:potential_good_reduction, "Potential good reduction", :boolean, BOOLEAN_HELP),
    FieldSpec(:is_q_curve, "Q-curve", :boolean, BOOLEAN_HELP),
    FieldSpec(:tamagawa_product, "Tamagawa product", :positive_integer, INTEGER_HELP),
    FieldSpec(:bad_prime_count, "Bad prime count", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:nonmaximal_primes, "Nonmaximal primes", :integer_list, LIST_HELP),
    FieldSpec(:nonmaximal_radical, "Nonmaximal radical", :positive_integer, INTEGER_HELP),
    FieldSpec(:discriminant_norm, "Discriminant norm", :integer, INTEGER_HELP),
    FieldSpec(:limit, "Number of results", :limit, "Search limit; default 50. Blank returns all matches. Count ignores this limit."),
]

const QUADRATIC_SPECS = [
    FieldSpec(:label, "LMFDB label", :text, TEXT_HELP),
    FieldSpec(:rank, "Rank", :positive_integer, INTEGER_HELP),
    FieldSpec(:signature, "Signature", :signature, "(nplus,nminus) or [nplus,nminus]; blank: any."),
    FieldSpec(:nplus, "Positive index", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:level, "Level", :positive_integer, INTEGER_HELP),
    FieldSpec(:class_number, "Class number", :positive_integer, INTEGER_HELP),
    FieldSpec(:is_even, "Even", :boolean, BOOLEAN_HELP),
    FieldSpec(:discriminant, "Discriminant", :integer, INTEGER_HELP),
    FieldSpec(:disc_group_invs, "Discriminant group invariants", :integer_list, LIST_HELP),
    FieldSpec(:discriminant_group_exponent, "Discriminant group exponent", :positive_integer, INTEGER_HELP),
    FieldSpec(:conway_symbol, "Conway symbol", :text, TEXT_HELP),
    FieldSpec(:dual_conway_symbol, "Dual Conway symbol", :text, TEXT_HELP),
    FieldSpec(:scale, "Scale", :positive_integer, INTEGER_HELP),
]

const INTEGER_LATTICE_SPECS = vcat(QUADRATIC_SPECS, [
    FieldSpec(:genus_label, "Genus label", :text, TEXT_HELP),
    FieldSpec(:minimum, "Minimum", :integer, INTEGER_HELP),
    FieldSpec(:automorphism_group_order, "Automorphism group order", :positive_integer, INTEGER_HELP),
    FieldSpec(:automorphism_group, "Automorphism group", :text, TEXT_HELP),
    FieldSpec(:dual_determinant, "Dual determinant", :positive_real, REAL_HELP),
    FieldSpec(:dual_kissing_number, "Dual kissing number", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:gram_matrix, "Gram matrix (flattened)", :integer_list, LIST_HELP),
    FieldSpec(:kissing_number, "Kissing number", :nonnegative_integer, INTEGER_HELP),
    FieldSpec(:festi_veniani_index, "Festi–Veniani index", :positive_integer, INTEGER_HELP),
    FieldSpec(:limit, "Number of results", :limit, "Search limit; default 50. Blank returns all matches. Count ignores this limit."),
])

const GENUS_SPECS = vcat(QUADRATIC_SPECS, [
    FieldSpec(:determinant, "Determinant", :integer, INTEGER_HELP),
    FieldSpec(:representative_gram_matrix, "Representative Gram matrix", :integer_list, LIST_HELP),
    FieldSpec(:discriminant_form, "Discriminant form", :integer_list, LIST_HELP),
    FieldSpec(:mass, "Mass", :rational, RATIONAL_HELP),
    FieldSpec(:limit, "Number of results", :limit, "Search limit; default 50. Blank returns all matches. Count ignores this limit."),
])

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
