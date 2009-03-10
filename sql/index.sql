.echo on
create index edge_tlid_idx on edge (tlid);
create index feature_tlid_idx on feature (tlid);
create index feature_name_zip_idx on feature (name, zip);
create index feature_name_phone_zip_idx on feature (name_phone, zip);
create index range_tlid_idx on range (tlid);
