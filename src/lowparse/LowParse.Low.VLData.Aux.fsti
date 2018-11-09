module LowParse.Low.VLData.Aux
include LowParse.Spec.VLData
include LowParse.Low.Base

inline_for_extraction
val read_bounded_integer_1 : unit -> Tot (leaf_reader (parse_bounded_integer 1))

inline_for_extraction
val read_bounded_integer_2 : unit -> Tot (leaf_reader (parse_bounded_integer 2))

inline_for_extraction
val read_bounded_integer_3 : unit -> Tot (leaf_reader (parse_bounded_integer 3))

inline_for_extraction
val read_bounded_integer_4 : unit -> Tot (leaf_reader (parse_bounded_integer 4))
