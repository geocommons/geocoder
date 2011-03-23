all: metaphone.so

metaphone.so: extension.o metaphon.o
	$(CC) -fPIC -shared $^ -o $@

clean:
	rm -f *.o *.so
