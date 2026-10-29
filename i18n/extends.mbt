// --- promoted: kept as regular methods ---

///|
pub extend Lang with Eq::{equal}

// --- deprecated: hidden from the generated interface ---

///|
#deprecated("Use `!=` instead", skip_current_package=true)
#doc(hidden)
pub extend Lang with Eq::{not_equal}
