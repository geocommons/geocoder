# include <string.h>
# include <ctype.h>

size_t rindex_nondigit (const char *string) {
    size_t i = strlen(string);
    for (i = strlen(string); i && isdigit(string[i]); i--);
    return i;
}
