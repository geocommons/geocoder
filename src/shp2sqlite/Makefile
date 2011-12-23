# **********************************************************************
# * $Id: Makefile.in
# *
# * PostGIS - Spatial Types for PostgreSQL
# * http://postgis.refractions.net
# * Copyright 2008 Mark Cave-Ayland
# *
# * This is free software; you can redistribute and/or modify it under
# * the terms of the GNU General Public Licence. See the COPYING file.
# *
# **********************************************************************

CC=gcc

CFLAGS=-g -O2  -fPIC -DPIC  -Wall -Wmissing-prototypes

# Filenames with extension as determined by the OS
SHP2SQLITE=shp2sqlite
LIBLWGEOM=../liblwgeom/liblwgeom.a

# iconv flags
ICONV_LDFLAGS=-lc

all: $(SHP2SQLITE)

$(LIBLWGEOM):
	make -C ../liblwgeom

$(SHP2SQLITE): shpopen.o dbfopen.o getopt.o shp2sqlite.o $(LIBLWGEOM)

	$(CC) -I/usr/include $(CFLAGS) $^ $(ICONV_LDFLAGS) -lm -o $@

install: all
	@cp $(SHP2SQLITE) ../../build/

clean:
	@rm -f *.o $(SHP2SQLITE)

