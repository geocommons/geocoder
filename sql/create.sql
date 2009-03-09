CREATE TABLE edge (
  tlid INTEGER(10),
  geometry BLOB);
CREATE TABLE feature (
  tlid INTEGER(10),
  name VARCHAR(100),
  name_phone VARCHAR(100),
  predir VARCHAR(2),
  pretyp VARCHAR(3),
  prequal VARCHAR(2),
  sufdir VARCHAR(2),
  suftyp VARCHAR(3),
  sufqual VARCHAR(2),
  paflag BOOLEAN,
  zip INTEGER(5));
CREATE TABLE range (
  tlid INTEGER(10),
  fromhn INTEGER(6),
  tohn INTEGER(6),
  prefix VARCHAR(12),
  zip INTEGER(5),
  side CHAR(1));
