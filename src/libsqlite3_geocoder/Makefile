all: libsqlite3_geocoder.so

libsqlite3_geocoder.so: extension.o wkb_compress.o util.o metaphon.o
	$(CC) -shared $^ -o $@

test: wkb_compress.c
	$(CC) -DTEST -o wkb_compress $^
clean:
	rm -f *.o *.so wkb_compress
