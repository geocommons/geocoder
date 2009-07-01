.echo on
PRAGMA temp_store=MEMORY;
PRAGMA journal_mode=MEMORY;
PRAGMA synchronous=OFF;
PRAGMA cache_size=500000;
PRAGMA count_changes=0;
-- create indexes for all the relevant ways each table is queried.
CREATE INDEX place_city_phone_state_idx ON place (city_phone, state);
CREATE INDEX place_zip_priority_idx ON place (zip, priority);
CREATE INDEX feature_street_phone_zip_idx ON feature (street_phone, zip);
CREATE INDEX feature_edge_fid_idx ON feature_edge (fid);
CREATE INDEX range_tlid_idx ON range (tlid);
