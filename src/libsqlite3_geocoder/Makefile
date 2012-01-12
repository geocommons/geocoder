all: libsqlite3_geocoder.so
CC=gcc -fPIC 

#extension.o:
#	$(CC) -lm -lsqlite3 -shared $^ -o $@

libsqlite3_geocoder.so: extension.o wkb_compress.o util.o metaphon.o levenshtein.o
#	$(CC) -lm -lsqlite3 -I/usr/include -shared $^ -o $@ 
	$(CC) $^ -lm -lsqlite3 -shared -o $@ 

test: test_wkb_compress test_levenshtein


test_wkb_compress: wkb_compress.c
	$(CC) -DTEST -o wkb_compress $^

test_levenshtein: levenshtein.c
	$(CC) -DTEST -o levenshtein $^

clean:
	rm -f *.o *.so wkb_compress levenshtein

install:
	cp *.so ../../lib/geocoder/us/sqlite3.so

