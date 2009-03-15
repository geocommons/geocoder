# include <string.h>
# include <ctype.h>

int address_metaphone(const char *input, char *output, int max_phones) {
    const char *n = input;
    int i = 0;
    if (isdigit(*n)) {
        while (i < max_phones && isdigit(n[i]) && n[i] != '\0')
            *output++ = n[i++];
        *output = '\0';
        return 1;
    } else {
        return metaphone(input, output, max_phones);
    }
}

size_t rindex_nondigit (const char *string) {
    size_t i = strlen(string);
    if (!i) return 0;
    for (i--; i && isdigit(string[i]); i--);
    if (!isdigit(string[i])) i++;
    return i;
}

size_t digit_suffix (const char *input, char *output) {
    size_t i = rindex_nondigit(input);
    strcpy(output, input+i);
    return strlen(output);
}

size_t nondigit_prefix (const char *input, char *output) {
    size_t i = rindex_nondigit(input);
    if (i) strncpy(output, input, i-1);
    output[i] = '\0';
    return i;
}
