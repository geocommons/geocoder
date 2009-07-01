#ifndef SQLITE3_GEOCODER
#define SQLITE3_GEOCODER

#include <stdint.h>

int metaphone(const char *Word, char *Metaph, int max_phones);
double levenshtein_distance (const unsigned char *s1, const unsigned char *s2);
signed int rindex_nondigit (const char *string);
signed int nondigit_prefix (const char *input, char *output);
uint32_t compress_wkb_line (void *dest, const void *src, uint32_t len);
uint32_t uncompress_wkb_line (void *dest, const void *src, uint32_t len);

#endif
