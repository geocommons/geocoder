.echo on
PRAGMA temp_store=MEMORY;
PRAGMA journal_mode=MEMORY;
PRAGMA synchronous=OFF;
PRAGMA cache_size=500000;
PRAGMA count_changes=0;
CREATE INDEX place_city_phone_state_idx ON place (city_phone, state);
CREATE INDEX place_zip_paflag_idx ON place (zip, priority);
CREATE INDEX edge_tlid_idx ON edge (tlid);
CREATE INDEX feature_tlid_paflag_idx ON feature (tlid, paflag);
CREATE INDEX feature_street_phone_zip_idx ON feature (street_phone, zip);
CREATE INDEX range_tlid_idx ON range (tlid);
