///|
pub(all) enum LogLevel {
  Debug = 1
  Info
  Warn
  Error
}

///|
fn LogLevel::to_int(self : LogLevel) -> Int = "%identity"

///|
impl Show for LogLevel with fn output(s, logger) {
  logger.write_string(s.to_string())
}

///|
impl Show for LogLevel with fn to_string(s) {
  match s {
    Debug => "debug"
    Info => "info"
    Warn => "warn"
    Error => "error"
  }
}

///|
pub fn LogLevel::from_string_with_default(s : String, default : Self) -> Self {
  match s.to_lower() {
    "info" => Info
    "debug" => Debug
    "warn" => Warn
    "error" => Error
    _ => default
  }
}

///|
const LOG_LEVEL_ENV_KEY = "MVM_LOG_LEVEL"

///|
fn get_default_log_level() -> LogLevel {
  if is_debug() {
    Debug
  } else {
    Info
  }
}

///|
fn get_log_level() -> LogLevel {
  guard @env.get_env_var(LOG_LEVEL_ENV_KEY) is Some(log_level) else {
    return get_default_log_level()
  }
  let log_level = LogLevel::from_string_with_default(
    log_level,
    get_default_log_level(),
  )
  log_level
}

///|
fn match_log_level(log_level : LogLevel) -> Bool {
  let current_log_level = get_log_level()
  return log_level.to_int() >= current_log_level.to_int()
}

///|
pub fn is_debug_log_level() -> Bool {
  match_log_level(Debug)
}
