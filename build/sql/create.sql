-- initialize the database tables.
-- 'place' contains the gazetteer of place names.
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
-- 'edge' stores the line geometries and their IDs.
CREATE TABLE edge (
  tlid INTEGER(10) PRIMARY KEY,
  geometry BLOB);
-- 'feature' stores the name(s) and ZIP(s) of each edge.
CREATE TABLE feature (
  fid INTEGER PRIMARY KEY,
  street VARCHAR(100),
  street_phone VARCHAR(5),
  paflag BOOLEAN,
  zip CHAR(5));
-- 'feature_edge' links each edge to a feature.
CREATE TABLE feature_edge (
  fid INTEGER,
  tlid INTEGER);
-- 'range' stores the address range(s) for each edge.
CREATE TABLE range (
  tlid INTEGER(10),
  fromhn INTEGER(6),
  tohn INTEGER(6),
  prenum VARCHAR(12),
  zip CHAR(5),
  side CHAR(1));
