.echo on
PRAGMA temp_store=MEMORY;
PRAGMA journal_mode=MEMORY;
PRAGMA synchronous=OFF;
PRAGMA cache_size=500000;
PRAGMA count_changes=0;
CREATE INDEX edge_tlid_idx ON edge (tlid);
CREATE INDEX feature_tlid_idx ON feature (tlid);
CREATE INDEX feature_name_phone_zip_idx ON feature (name_phone, zip);
CREATE INDEX range_tlid_idx ON range (tlid);
