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

signed int rindex_nondigit (const char *string) {
    signed int i = strlen(string);
    if (!i) return -1;
    for (i--; i >= 0 && isdigit(string[i]); i--);
    return i;
}

signed int digit_suffix (const char *input, char *output) {
    signed int i = rindex_nondigit(input);
    strcpy(output, input+i+1);
    return strlen(output);
}

signed int nondigit_prefix (const char *input, char *output) {
    signed int i = rindex_nondigit(input);
    if (i++ >= 0) {
        strncpy(output, input, i);
        output[i] = '\0';
    }
    return i;
}
