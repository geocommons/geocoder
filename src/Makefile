all:
	$(MAKE) -C metaphone
	$(MAKE) -C wkb_compress
	$(MAKE)	-C liblwgeom
	$(MAKE) -C shp2sqlite

clean:
	$(MAKE) -C metaphone clean
	$(MAKE) -C wkb_compress clean
	$(MAKE)	-C liblwgeom clean
	$(MAKE) -C shp2sqlite clean


install: all
	cp metaphone/*.so ../lib
	cp wkb_compress/*.so ../lib
	$(MAKE) -C shp2sqlite install
