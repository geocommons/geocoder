all:
	$(MAKE) -C libsqlite3_geocoder
	$(MAKE)	-C liblwgeom
	$(MAKE) -C shp2sqlite

clean:
	$(MAKE) -C libsqlite3_geocoder clean
	$(MAKE)	-C liblwgeom clean
	$(MAKE) -C shp2sqlite clean

install: all
	cp libsqlite3_geocoder/*.so ../lib/geocoder/us/sqlite3.so
	$(MAKE) -C shp2sqlite install
