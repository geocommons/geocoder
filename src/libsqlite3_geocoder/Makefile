all: libsqlite3_geocoder.so
CC=gcc
CFLAGS=-fPIC
libsqlite3_geocoder.so: extension.o wkb_compress.o util.o metaphon.o levenshtein.o
	$(CC) -fPIC -lsqlite3 -I/usr/include -lm -shared $^ -o $@ 

test: test_wkb_compress test_levenshtein

test_wkb_compress: wkb_compress.c
	$(CC) -DTEST -o wkb_compress $^

test_levenshtein: levenshtein.c
	$(CC) -DTEST -o levenshtein $^

clean:
	rm -f *.o *.so wkb_compress levenshtein
