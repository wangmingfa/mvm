// --- promoted: kept as regular methods ---

///|
pub extend Command with Show::{to_string}

// --- deprecated: hidden from the generated interface ---

///|
#deprecated("Use `@debug.Debug` instead of the promoted `to_repr`", skip_current_package=true)
#doc(hidden)
pub extend Command with @debug.Debug::{to_repr}

///|
#deprecated("Use `Show::to_string` instead", skip_current_package=true)
#doc(hidden)
pub extend Command with Show::{output}

///|
#deprecated("Use `@debug.Debug` instead of the promoted `to_repr`", skip_current_package=true)
#doc(hidden)
pub extend CommandResult with @debug.Debug::{to_repr}
