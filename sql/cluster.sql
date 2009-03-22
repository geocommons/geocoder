.echo on
PRAGMA temp_store=MEMORY;
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
PRAGMA cache_size=500000;
PRAGMA count_changes=0;
BEGIN TRANSACTION;
INSERT INTO place SELECT * FROM old.place ORDER BY zip, paflag;
INSERT INTO edge SELECT * FROM old.edge ORDER BY tlid;
INSERT INTO feature SELECT * FROM old.feature ORDER BY street_phone, zip;
INSERT INTO range SELECT * FROM old.range ORDER BY tlid;
COMMIT;
