.echo on
-- turn off various pragmas to make SQLite faster
PRAGMA temp_store=MEMORY;
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
PRAGMA cache_size=500000;
PRAGMA count_changes=0;
BEGIN TRANSACTION;
-- order the contents of each table by their indexes to reduce
--   the number of disk pages that need to be read on each query.
INSERT INTO place SELECT * FROM old.place ORDER BY zip, priority;
INSERT INTO edge SELECT * FROM old.edge ORDER BY tlid;
INSERT INTO feature SELECT * FROM old.feature ORDER BY street_phone, zip;
INSERT INTO feature_edge SELECT * FROM old.feature_edge ORDER BY fid;
INSERT INTO range SELECT * FROM old.range ORDER BY tlid;
COMMIT;
