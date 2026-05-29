#include "./multi_select.c"
#include "../ffi/string.c"

moonbit_string_t interactive_select_tools_c(const char * options, const char * preselected, const char * title) {
    return make_moonbit_str(multi_select(options, preselected, title));
}
