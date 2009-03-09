all: metaphone.so

metaphone.so: extension.o metaphon.o
	$(CC) -shared $^ -o $@

clean:
	rm -f *.o *.so
