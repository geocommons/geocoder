#include <stdint.h>
#include <string.h>

uint32_t compress_wkb_line (void *dest, const void *src, uint32_t len) {
    uint32_t d, s;
    double value;
    if (!len) return 0;
    for (s = 9, d = 0; s < len; d += 4, s += 8) {
        value = *(double *)(src + s);
        value *= 1000000;
        *(int32_t *)(dest + d) = (int32_t) value;
    }
    return d; 
}

uint32_t uncompress_wkb_line (void *dest, const void *src, uint32_t len) {
    uint32_t d, s;
    double value;
    if (!len) return 0;
    memcpy(dest, "\01\02\00\00\00\06\00\00\00", 10);
    for (s = 0, d = 9; s < len; s += 4, d += 8) {
        value = (double) *(int32_t *)(src + s);
        value /= 1000000;
        *(double *)(dest + d) = value;
    }
    return d; 
}


#ifdef TEST

#include <stdio.h>
int main (int argc, char *argv) {
    char hex[1024], *scan;
    char wkb[512];
    unsigned long len, clen;
    
    while (!feof(stdin)) {
        fgets(hex, sizeof(hex), stdin);
        for (scan = hex, len = 0; *scan && sizeof(wkb)>len; scan += 2, len++) {
            if (sscanf(scan, "%2x", (uint32_t *)(wkb+len)) != 1) break;
        }
        clen = compress_wkb_line(hex, wkb, len);
        printf("before: %lu, after: %lu\n", len, clen);
        len = uncompress_wkb_line(wkb, hex, clen);
        printf("before: %lu, after: %lu\n", clen, len);
        for (scan = wkb + 9; scan < wkb + len; scan += 8) {
            printf("%.6f ", *(double *)scan);
        }
        printf("\n");
    }
}

#endif
