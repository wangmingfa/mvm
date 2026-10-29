// --- promoted: kept as regular methods ---

///|
pub extend Tool with @utils.ToStr::{to_str}

///|
pub extend Tool with Show::{to_string}

///|
pub extend Config with @json.FromJson::{from_json}

///|
pub extend GlobalConfig with @json.FromJson::{from_json}

///|
pub extend DownloadInfo with @debug.Debug::{to_repr}

///|
pub extend ProgramExeInfo with @debug.Debug::{to_repr}

// --- deprecated: hidden from the generated interface ---

///|
#deprecated("Use `@debug.Debug` instead of the promoted `to_repr`", skip_current_package=true)
#doc(hidden)
pub extend Config with @debug.Debug::{to_repr}

///|
#deprecated("Use `Json(..)` instead of `to_json`", skip_current_package=true)
#doc(hidden)
pub extend Config with ToJson::{to_json}

///|
#deprecated("Use `Json(..)` instead of `to_json`", skip_current_package=true)
#doc(hidden)
pub extend GlobalConfig with ToJson::{to_json}

///|
#deprecated("Use `Show::to_string` instead", skip_current_package=true)
#doc(hidden)
pub extend Tool with Show::{output}

///|
#deprecated("Use `@debug.Debug` instead of the promoted `to_repr`", skip_current_package=true)
#doc(hidden)
pub extend Tool with @debug.Debug::{to_repr}
