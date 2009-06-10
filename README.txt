= Geocoder::US

Geocoder::US 2.0 is a software package designed to geocode US street
addresses.  Although it is primarily intended for use with the US Census
Bureau's free TIGER/Line dataset, it uses an abstract US address data model
that can be employed with other sources of US street address range data.

Geocoder::US 2.0 implements a Ruby interface to parse US street addresses, and
perform fuzzy lookup against an SQLite 3 database. Geocoder::US is designed to
return the best matches found, with geographic coordinates interpolated from
the street range dataset. Geocoder::US will fill in missing information, and
it knows about standard and common non-standard postal abbreviations, ordinal
versus cardinal numbers, and more.

Geocoder::US 2.0 is shipped with a free US ZIP code data set, compiled from
public domain sources.

== Synopsis

  >> require 'geocoder/us'
  >> db = Geocoder::US::Database.new("/opt/tiger/geocoder.db")
  >> p db.geocode("1600 Pennsylvania Av, Washington DC")

  [{:pretyp=>"", :street=>"Pennsylvania", :sufdir=>"NW", :zip=>"20502",
    :lon=>-77.037528, :number=>"1600", :fips_county=>"11001", :predir=>"",
    :precision=>:range, :city=>"Washington", :lat=>38.898746, :suftyp=>"Ave",
    :state=>"DC", :prequal=>"", :sufqual=>"", :score=>0.906, :prenum=>""}]

== Prerequisites

To build Geocoder::US, you will need gcc/g++, make, bash or equivalent, the
standard *NIX 'unzip' utility, and the SQLite 3 executable and development
files installed on your system.

To use the Ruby interface, you will need the 'Text' gem installed from
rubyforge. To run the tests, you will also need the 'fastercsv' gem.

Additionally, you will need a custom build of the 'sqlite3-ruby' gem that
supports loading extension modules in SQLite. You can get a patched version of
this gem from http://github.com/schuyler/sqlite3-ruby/. Until the sqlite3-ruby
maintainers roll in the relevant patch, you will need *this* version.

*NOTE*: If you do not have /usr/include/sqlite3ext.h installed, then your
sqlite3 binaries are probably not configured to support dynamic extension
loading. If not, you *must* compile and install SQLite from source, or rebuild
your system packages. This is not believed to be a problem on Debian/Ubuntu,
but is known to be a problem with Red Hat/CentOS.

*NOTE*: If you *do* have to install from source, make sure that the
source-installed 'sqlite3' program is in your path before proceeding (and not
the system-installed version), using `which sqlite3`. Also, be sure that you've
added your source install prefix (usually /usr/local) to /etc/ld.so.conf (or
its moral equivalent) and that you've run /sbin/ldconfig.

== Building Geocoder::US

Unpack the source and run 'make'. This will compile the SQLite 3 extension
needed by Geocoder::US, the Shapefile import utility, and the Geocoder-US
gem.

You can run 'make install' as root to install the gem systemwide.

== Generating a Geocoder::US Database

Build the package from source as described above. Generating the database
involves three basic steps:

* Import the Shapefile data into an SQLite database.
* Build the database indexes.
* Optionally, rebuild the database to cluster indexed rows.

We will presume that you are building a Geocoder::US database from TIGER/Line,
and that you have obtained the complete set of TIGER/Line ZIP files, and put
the entire tree in /opt/tiger. Please adjust these instructions as needed.

A full TIGER/Line database import takes 1-2 days to run on a normal Amazon EC2
instance, and takes up a little over 5 gigabytes after all is said and done.
You will need to have at least 12 gigabytes of free disk space *after*
downloading the TIGER/Line dataset, if you are building the full database. 

=== Import TIGER/Line

From inside the Geocoder::US source tree, run the following:

  $ bin/tiger_import /opt/tiger/geocoder.db /opt/tiger

This will unpack each TIGER/Line ZIP file to a temporary directory, and
perform the extract/transform/load sequence to incrementally build the
database. The process takes about a day on a normal Amazon EC2 instance. Note
that not all TIGER/Line source files contain address range information, so you
will see error messages for some counties, but this is normal.

If you only want to import specific counties, you can pipe a list of
TIGER/Line county directories to tiger_import on stdin. For example,
the following will install just the data for the state of Delaware:

  $ ls -d /opt/tiger/10_DELAWARE/1* | bin/tiger_import ~/delaware.db

The tiger_import process uses a binary utility, shp2sqlite, which is derived
from shp2pgsql, which ships with PostGIS. The shp2sqlite utility converts
.shp and .dbf files into SQL suitable for import into SQLite. This SQL
is then piped into the sqlite3 command line tool, where it is loaded into
temporary tables, and then a set of static SQL statements (kept in the sql/
directory) are used to transform this data and import it into the database
itself.

=== Build the indexes

After the database import is complete, you will want to construct the database
indexes:

  $ bin/build_indexes /opt/tiger/geocoder.db

This process will take a few hours, but it's a *lot* faster than building
the indexes incrementally during the import process. Basically, this process
simply feeds SQL statements to the sqlite3 utility to construct the indexes on
the existing database.

=== Cluster the database tables (optional)

As a final optional step, you can cluster the database tables according to
their indexes, which will make the database smaller, and lookups faster. This
process will take an hour or two, and may be a micro-optimization.

  $ bin/rebuild_cluster /opt/tiger/geocoder.db

You will need as much free disk space to run rebuild_cluster as the database
takes up, because the process essentially reconstructs the database in a new
file, with the tables sorted by their relevant indexed columns, and then
it renames the new database over top of the old.

== Running the unit tests

From within the source tree, you can run the following:

  $ ruby tests/run.rb

This tests the libraries, except for the database routines. If you have a
database built, you can run the test harness like so:

  $ ruby tests/run.rb /opt/tiger/geocoder.db

The full test suite may take 30 or so seconds to run completely.

== License

Geocoder::US 2.0 was based on earlier work by Schuyler Erle on
a Perl module of the same name. You can find it at
http://search.cpan.org/~sderle/.

Geocoder::US 2.0 was written by Schuyler Erle, of Entropy Free LLC,
with the gracious support of FortiusOne, Inc. Please send bug reports,
patches, kudos, etc. to patches at geocoder.us.

Copyright (c) 2009 FortiusOne, Inc.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
