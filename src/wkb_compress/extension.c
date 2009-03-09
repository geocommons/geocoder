# include <sqlite3.h>
# include <sqlite3ext.h>
# include <stdio.h>
# include <string.h>
# include <assert.h>

static SQLITE_EXTENSION_INIT1;

static void
sqlite3_compress_wkb_line (sqlite3_context *context,
                           int argc, sqlite3_value **argv) {
    const void *input = sqlite3_value_blob(argv[0]);
    unsigned long input_len = sqlite3_value_bytes(argv[0]);
    unsigned long output_len = (input_len-9)/2;
    unsigned long len = 0;
    void *output = sqlite3_malloc(output_len);
    len = compress_wkb_line(output, input, input_len); 
    assert(len == output_len);
    sqlite3_result_blob(context, output, len, SQLITE_TRANSIENT);
}

static void
sqlite3_uncompress_wkb_line (sqlite3_context *context,
                           int argc, sqlite3_value **argv) {
    const void *input = sqlite3_value_blob(argv[0]);
    unsigned long input_len = sqlite3_value_bytes(argv[0]);
    unsigned long output_len = input_len*2+9;
    unsigned long len = 0;
    void *output = sqlite3_malloc(output_len);
    len = uncompress_wkb_line(output, input, input_len); 
    assert(len == output_len);
    sqlite3_result_blob(context, output, len, SQLITE_TRANSIENT);
}

int sqlite3_extension_init (sqlite3 * db, char **pzErrMsg,
                            const sqlite3_api_routines *pApi) {
    SQLITE_EXTENSION_INIT2(pApi);
    sqlite3_create_function(db, "compress_wkb_line", 1, SQLITE_ANY,
                            NULL, sqlite3_compress_wkb_line, NULL, NULL);
    sqlite3_create_function(db, "uncompress_wkb_line", 1, SQLITE_ANY,
                            NULL, sqlite3_uncompress_wkb_line, NULL, NULL);
    return 0;
}
