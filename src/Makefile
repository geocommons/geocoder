all:
	$(MAKE) -C metaphone
	$(MAKE) -C wkb_compress

clean:
	$(MAKE) -C metaphone clean
	$(MAKE) -C wkb_compress clean

install: all
	cp metaphone/*.so ../lib
	cp wkb_compress/*.so ../lib
	
