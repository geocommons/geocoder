# include <sqlite3ext.h>
# include <stdio.h>
# include <string.h>
# include <assert.h>
# include <math.h>

# include "extension.h"

static SQLITE_EXTENSION_INIT1;

static void
sqlite3_metaphone (sqlite3_context *context, int argc, sqlite3_value **argv) {
    const unsigned char *input = sqlite3_value_text(argv[0]);
    int max_phones = 0;
    char *output; 
    int len;
    if (sqlite3_value_type(argv[0]) == SQLITE_NULL) {
        sqlite3_result_null(context);
        return;
    }
    if (argc > 1)
        max_phones = sqlite3_value_int(argv[1]);
    if (max_phones <= 0)
        max_phones = strlen(input);
    output = sqlite3_malloc((max_phones+1)*sizeof(char));
    len = metaphone(input, output, max_phones); 
    sqlite3_result_text(context, output, len, sqlite3_free);
}

static void
sqlite3_levenshtein (sqlite3_context *context, int argc, sqlite3_value **argv) {
    const unsigned char *s1 = sqlite3_value_text(argv[0]),
                        *s2 = sqlite3_value_text(argv[1]);
    double dist;
    if (sqlite3_value_type(argv[0]) == SQLITE_NULL ||
        sqlite3_value_type(argv[1]) == SQLITE_NULL) {
        sqlite3_result_null(context);
        return;
    }
    dist = levenshtein_distance(s1, s2);
    sqlite3_result_double(context, dist);
}

static void
sqlite3_digit_suffix (sqlite3_context *context,
                           int argc, sqlite3_value **argv) {
    if (sqlite3_value_type(argv[0]) == SQLITE_NULL) {
        sqlite3_result_null(context);
        return;
    }
    const unsigned char *input = sqlite3_value_text(argv[0]);
    char *output = sqlite3_malloc((strlen(input)+1) * sizeof(char));
    size_t len = digit_suffix(input, output);
    sqlite3_result_text(context, output, len, sqlite3_free);
}

static void
sqlite3_nondigit_prefix (sqlite3_context *context,
                           int argc, sqlite3_value **argv) {
    if (sqlite3_value_type(argv[0]) == SQLITE_NULL) {
        sqlite3_result_null(context);
        return;
    }
    const unsigned char *input = sqlite3_value_text(argv[0]);
    char *output = sqlite3_malloc((strlen(input)+1) * sizeof(char));
    size_t len = nondigit_prefix(input, output);
    sqlite3_result_text(context, output, len, sqlite3_free);
}


static void
sqlite3_compress_wkb_line (sqlite3_context *context,
                           int argc, sqlite3_value **argv) {
    if (sqlite3_value_type(argv[0]) == SQLITE_NULL) {
        sqlite3_result_null(context);
        return;
    }
    unsigned long input_len = sqlite3_value_bytes(argv[0]);
    const void *input = sqlite3_value_blob(argv[0]);
    unsigned long output_len = ceil((input_len-9)/8.0) * 4;
    unsigned long len = 0;
    void *output = sqlite3_malloc(output_len);
    len = compress_wkb_line(output, input, input_len); 
    assert(len == output_len);
    sqlite3_result_blob(context, output, len, sqlite3_free);
}

static void
sqlite3_uncompress_wkb_line (sqlite3_context *context,
                           int argc, sqlite3_value **argv) {
    unsigned long input_len = sqlite3_value_bytes(argv[0]);
    const void *input = sqlite3_value_blob(argv[0]);
    unsigned long output_len = input_len*2+9;
    unsigned long len = 0;
    void *output = sqlite3_malloc(output_len);
    len = uncompress_wkb_line(output, input, input_len);
    assert(len == output_len);
    sqlite3_result_blob(context, output, len, sqlite3_free);
}

int sqlite3_extension_init (sqlite3 * db, char **pzErrMsg,
                            const sqlite3_api_routines *pApi) {
    SQLITE_EXTENSION_INIT2(pApi);
    
    sqlite3_create_function(db, "metaphone", 1, SQLITE_ANY,
                            NULL, sqlite3_metaphone, NULL, NULL);
    sqlite3_create_function(db, "metaphone", 2, SQLITE_ANY,
                            NULL, sqlite3_metaphone, NULL, NULL);
    
    sqlite3_create_function(db, "levenshtein", 2, SQLITE_ANY,
                            NULL, sqlite3_levenshtein, NULL, NULL);
    sqlite3_create_function(db, "compress_wkb_line", 1, SQLITE_ANY,
                            NULL, sqlite3_compress_wkb_line, NULL, NULL);
    sqlite3_create_function(db, "uncompress_wkb_line", 1, SQLITE_ANY,
                            NULL, sqlite3_uncompress_wkb_line, NULL, NULL);
    sqlite3_create_function(db, "digit_suffix", 1, SQLITE_ANY,
                            NULL, sqlite3_digit_suffix, NULL, NULL);
    sqlite3_create_function(db, "nondigit_prefix", 1, SQLITE_ANY,
                            NULL, sqlite3_nondigit_prefix, NULL, NULL);
    return 0;
}
