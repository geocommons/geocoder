# include <sqlite3.h>
# include <sqlite3ext.h>
# include <stdio.h>
# include <string.h>

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
    sqlite3_result_text(context, output, len, SQLITE_TRANSIENT);
}

int sqlite3_extension_init (sqlite3 * db, char **pzErrMsg,
                            const sqlite3_api_routines *pApi) {
    SQLITE_EXTENSION_INIT2(pApi);
    sqlite3_create_function(db, "metaphone", 1, SQLITE_ANY,
                            NULL, sqlite3_metaphone, NULL, NULL);
    sqlite3_create_function(db, "metaphone", 2, SQLITE_ANY,
                            NULL, sqlite3_metaphone, NULL, NULL);
    return 0;
}


