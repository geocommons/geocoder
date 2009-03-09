/* +++Customized by SDE for sqlite3 use 09-Mar-2009 */
/* +++File obtained from http://www.shedai.net/c/new/METAPHON.C */
/* +++Date previously modified: 05-Jul-1997 */

/*
**  METAPHON.C - Phonetic string matching
**
**  The Metaphone algorithm was developed by Lawrence Phillips. Like the
**  Soundex algorithm, it compares words that sound alike but are spelled
**  differently. Metaphone was designed to overcome difficulties encountered
**  with Soundex.
**
**  This implementation was written by Gary A. Parker and originally published
**  in the June/July, 1991 (vol. 5 nr. 4) issue of C Gazette. As published,
**  this code was explicitly placed in the public domain by the author.
*/

#include <ctype.h>
#include <string.h> /* strlen() */
#include <stdio.h>
#define malloc(x) sqlite3_malloc((x))
#define free(x) sqlite3_free((x))

/*
**  Character coding array
*/

static char vsvfn[26] = {
      1,16,4,16,9,2,4,16,9,2,0,2,2,2,1,4,0,2,4,4,1,0,0,0,8,0};
/*    A  B C  D E F G  H I J K L M N O P Q R S T U V W X Y Z      */

/*
**  Macros to access the character coding array
*/

#define vowel(x)  (vsvfn[(x) - 'A'] & 1)  /* AEIOU    */
#define same(x)   (vsvfn[(x) - 'A'] & 2)  /* FJLMNR   */
#define varson(x) (vsvfn[(x) - 'A'] & 4)  /* CGPST    */
#define frontv(x) (vsvfn[(x) - 'A'] & 8)  /* EIY      */
#define noghf(x)  (vsvfn[(x) - 'A'] & 16) /* BDH      */

int metaphone(const char *Word, char *Metaph, int max_phones)
{
      char *n, *n_start, *n_end;    /* Pointers to string               */
      char *metaph_start = Metaph, *metaph_end;    
                                    /* Pointers to metaph         */
      int ntrans_len = strlen(Word)+4;
      char *ntrans = (char *)malloc(sizeof(char) * ntrans_len);
                                    /* Word with uppercase letters      */
      int KSflag;                   /* State flag for X translation     */

      /*
      ** Copy word to internal buffer, dropping non-alphabetic characters
      ** and converting to upper case.
      */

      for (n = ntrans + 1, n_end = ntrans + ntrans_len - 2;
            *Word && n < n_end; ++Word)
      {
            if (isalpha(*Word))
                  *n++ = toupper(*Word);
      }

      if (n == ntrans + 1) {
            free(ntrans);
            Metaph[0]='\0';
            return 1;           /* Return if zero characters        */
      }
      else  n_end = n;          /* Set end of string pointer        */

      /*
      ** Pad with '\0's, front and rear
      */

      *n++ = '\0';
      *n   = '\0';
      n    = ntrans;
      *n++ = '\0';

      /*
      ** Check for PN, KN, GN, WR, WH, and X at start
      */

      switch (*n)
      {
      case 'P':
      case 'K':
      case 'G':
            if ('N' == *(n + 1))
                  *n++ = '\0';
            break;

      case 'A':
            if ('E' == *(n + 1))
                  *n++ = '\0';
            break;

      case 'W':
            if ('R' == *(n + 1))
                  *n++ = '\0';
            else if ('H' == *(n + 1))
            {
                  *(n + 1) = *n;
                  *n++ = '\0';
            }
            break;

      case 'X':
            *n = 'S';
            break;
      }

      /*
      ** Now loop through the string, stopping at the end of the string
      ** or when the computed Metaphone code is max_phones characters long.
      */

      KSflag = 0;              /* State flag for KStranslation     */
      for (metaph_end = Metaph + max_phones, n_start = n;
            n <= n_end && Metaph < metaph_end; ++n)
      {
            if (KSflag)
            {
                  KSflag = 0;
                  *Metaph++ = *n;
            }
            else
            {
                  /* Drop duplicates except for CC    */

                  if (*(n - 1) == *n && *n != 'C')
                        continue;

                  /* Check for F J L M N R  or first letter vowel */

                  if (same(*n) || (n == n_start && vowel(*n)))
                        *Metaph++ = *n;
                  else switch (*n)
                  {
                  case 'B':
                        if (n < n_end || *(n - 1) != 'M')
                              *Metaph++ = *n;
                        break;

                  case 'C':
                        if (*(n - 1) != 'S' || !frontv(*(n + 1)))
                        {
                              if ('I' == *(n + 1) && 'A' == *(n + 2))
                                    *Metaph++ = 'X';
                              else if (frontv(*(n + 1)))
                                    *Metaph++ = 'S';
                              else if ('H' == *(n + 1))
                                    *Metaph++ = ((n == n_start &&
                                          !vowel(*(n + 2))) ||
                                          'S' == *(n - 1)) ? 'K' : 'X';
                              else  *Metaph++ = 'K';
                        }
                        break;

                  case 'D':
                        *Metaph++ = ('G' == *(n + 1) && frontv(*(n + 2))) ?
                              'J' : 'T';
                        break;

                  case 'G':
                        if ((*(n + 1) != 'H' || vowel(*(n + 2))) &&
                              (*(n + 1) != 'N' || ((n + 1) < n_end &&
                              (*(n + 2) != 'E' || *(n + 3) != 'D'))) &&
                              (*(n - 1) != 'D' || !frontv(*(n + 1))))
                        {
                              *Metaph++ = (frontv(*(n + 1)) &&
                                    *(n + 2) != 'G') ? 'J' : 'K';
                        }
                        else if ('H' == *(n + 1) && !noghf(*(n - 3)) &&
                              *(n - 4) != 'H')
                        {
                              *Metaph++ = 'F';
                        }
                        break;

                  case 'H':
                        if (!varson(*(n - 1)) && (!vowel(*(n - 1)) ||
                              vowel(*(n + 1))))
                        {
                              *Metaph++ = 'H';
                        }
                        break;

                  case 'K':
                        if (*(n - 1) != 'C')
                              *Metaph++ = 'K';
                        break;

                  case 'P':
                        *Metaph++ = ('H' == *(n + 1)) ? 'F' : 'P';
                        break;

                  case 'Q':
                        *Metaph++ = 'K';
                        break;

                  case 'S':
                        *Metaph++ = ('H' == *(n + 1) || ('I' == *(n + 1) &&
                              ('O' == *(n + 2) || 'A' == *(n + 2)))) ?
                              'X' : 'S';
                        break;

                  case 'T':
                        if ('I' == *(n + 1) && ('O' == *(n + 2) ||
                              'A' == *(n + 2)))
                        {
                              *Metaph++ = 'X';
                        }
                        else if ('H' == *(n + 1))
                              *Metaph++ = 'O';
                        else if (*(n + 1) != 'C' || *(n + 2) != 'H')
                              *Metaph++ = 'T';
                        break;

                  case 'V':
                        *Metaph++ = 'F';
                        break;

                  case 'W':
                  case 'Y':
                        if (vowel(*(n + 1)))
                              *Metaph++ = *n;
                        break;

                  case 'X':
                        if (n == n_start)
                              *Metaph++ = 'S';
                        else
                        {
                              *Metaph++ = 'K';
                              KSflag = 1;
                        }
                        break;

                  case 'Z':
                        *Metaph++ = 'S';
                        break;
                  }
            }
      }

      *Metaph = '\0';
      free(ntrans);
      return strlen(metaph_start);
}

