# include <string.h>
# define STRLEN_MAX 256
# define min(x, y) ((x) < (y) ? (x) : (y))
# define max(x, y) ((x) > (y) ? (x) : (y))

static int d[STRLEN_MAX][STRLEN_MAX]; // this isn't thread safe

double levenshtein_distance (const unsigned char *s1, const unsigned char *s2) {
    const size_t len1 = min(strlen(s1), STRLEN_MAX-1),
                 len2 = min(strlen(s2), STRLEN_MAX-1);
    int cost, i, j;

    for (i = 1; i <= len1; ++i) d[i][0] = i;
    for (i = 1; i <= len2; ++i) d[0][i] = i;
    for (i = 1; i <= len1; ++i) {
        for (j = 1; j <= len2; ++j) {
            cost = (s1[i-1] == s2[j-1] ? 0 : 1);
            d[i][j] = min(min(
                        d[i-1][j] + 1,              /* addition */
                        d[i][j-1] + 1),             /* deletion */
                        d[i-1][j-1] + cost);        /* substitution */
            if (i > 1 && j > 1 && s1[i] == s2[j-1] && s1[i-1] == s2[j])
               d[i][j] = min( d[i][j],
                              d[i-2][j-2] + cost);   /* transposition */
        }
    }
    return (d[len1][len2] / (double) max(len1, len2));
}

#ifdef TEST
#include <stdio.h>

int main (int argc, char **argv) {
    if (argc < 3) return -1;
    printf("%.1f%%\n", levenshtein_distance(argv[1],argv[2]) * 100);
    return 0;
}

#endif
