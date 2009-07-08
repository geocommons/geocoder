all: libsqlite3_geocoder.so
CC=gcc-4.2
libsqlite3_geocoder.so: extension.o wkb_compress.o util.o metaphon.o 
	$(CC) -arch i386 -lsqlite3 -I/usr/include -shared $^ -o $@ 
test: wkb_compress.c
	$(CC) -DTEST -o wkb_compress $^
clean:
	rm -f *.o *.so wkb_compress
