.echo on
PRAGMA temp_store=MEMORY;
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
PRAGMA cache_size=500000;
PRAGMA count_changes=0;
BEGIN TRANSACTION;
CREATE TABLE place AS SELECT * FROM old.place ORDER BY zip, paflag;
CREATE TABLE edge AS SELECT * FROM old.edge ORDER BY tlid;
CREATE TABLE feature AS SELECT * FROM old.feature ORDER BY street_phone, zip;
CREATE TABLE range AS SELECT * FROM old.range ORDER BY tlid;
COMMIT;
