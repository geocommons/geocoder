CREATE TABLE place(
  zip CHAR(5),
  city VARCHAR(100),
  state CHAR(2),
  city_phone VARCHAR(5),
  lat NUMERIC(9,6),
  lon NUMERIC(9,6),
  status CHAR(1),
  fips_class CHAR(2),
  fips_place CHAR(7),
  fips_county CHAR(5),
  priority char(1));
CREATE TABLE edge (
  tlid INTEGER(10) PRIMARY KEY,
  geometry BLOB);
CREATE TABLE feature (
  tlid INTEGER(10),
  street VARCHAR(100),
  street_phone VARCHAR(5),
  predir VARCHAR(2),
  pretyp VARCHAR(3),
  prequal VARCHAR(2),
  sufdir VARCHAR(2),
  suftyp VARCHAR(3),
  sufqual VARCHAR(2),
  paflag BOOLEAN,
  zip CHAR(5));
CREATE TABLE range (
  tlid INTEGER(10),
  fromhn INTEGER(6),
  tohn INTEGER(6),
  prenum VARCHAR(12),
  zip CHAR(5),
  side CHAR(1));
