all: wkb_compress.so

wkb_compress.so: extension.o wkb_compress.o
	$(CC) -shared $^ -o $@

test: wkb_compress.c
	$(CC) -DTEST -o wkb_compress $^
clean:
	rm -f *.o *.so wkb_compress
