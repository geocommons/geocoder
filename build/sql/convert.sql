BEGIN;
-- start by indexing the temporary tables created from the input data.
CREATE INDEX featnames_tlid ON tiger_featnames (tlid);
CREATE INDEX addr_tlid ON tiger_addr (tlid);
CREATE INDEX edges_tlid ON tiger_edges (tlid);

-- generate a summary table matching each edge to one or more ZIPs
--   for those edges that are streets and have a name
CREATE TEMPORARY TABLE linezip AS
    SELECT DISTINCT tlid, zip FROM (
        SELECT tlid, zip FROM tiger_addr a
        UNION
        SELECT tlid, zipr AS zip FROM tiger_edges e
           WHERE e.mtfcc LIKE 'S%' AND zipr <> "" AND zipr IS NOT NULL
        UNION
        SELECT tlid, zipl AS zip FROM tiger_edges e
           WHERE e.mtfcc LIKE 'S%' AND zipl <> "" AND zipl IS NOT NULL
    ) AS whatever;

CREATE INDEX linezip_tlid ON linezip (tlid);

-- generate features from the featnames table for each desired edge
--   computing the metaphone hash of the name in the process.

-- CREATE TEMPORARY TABLE sqlite_sequence (
--  name VARCHAR(255),
--  seq INTEGER);

CREATE TEMPORARY TABLE feature_bin (
  fid INTEGER PRIMARY KEY AUTOINCREMENT,
  street VARCHAR(100),
  street_phone VARCHAR(5),
  paflag BOOLEAN,
  zip CHAR(5));

INSERT OR IGNORE INTO sqlite_sequence (name, seq) VALUES ('feature_bin',0);
UPDATE sqlite_sequence
    SET seq=(SELECT max(fid) FROM feature)
    WHERE name="feature_bin";

INSERT INTO feature_bin
    SELECT DISTINCT NULL, fullname, metaphone(name,5), paflag, zip
        FROM linezip l, tiger_featnames f
        WHERE l.tlid=f.tlid AND name <> "" AND name IS NOT NULL;

CREATE INDEX feature_bin_idx ON feature_bin (street, zip);

INSERT INTO feature_edge
    SELECT DISTINCT fid, f.tlid
        FROM linezip l, tiger_featnames f, feature_bin b
        WHERE l.tlid=f.tlid AND l.zip=b.zip
          AND f.fullname=b.street AND f.paflag=b.paflag;

-- SELECT min(fid),max(fid) FROM feature_bin;

INSERT INTO feature
    SELECT * FROM feature_bin;

-- generate edges from the edges table for each desired edge, running
--   a simple compression on the WKB geometry (because they're all
--   linestrings).
INSERT OR IGNORE INTO edge
    SELECT l.tlid, compress_wkb_line(the_geom) FROM
        (SELECT DISTINCT tlid FROM linezip) AS l, tiger_edges e
        WHERE l.tlid=e.tlid AND fullname <> "" AND fullname IS NOT NULL;

-- generate all ranges from the addr table, stripping off any non-digit
--   prefixes and putting them in a separate column.
INSERT INTO range
    SELECT tlid, digit_suffix(fromhn), digit_suffix(tohn),
           nondigit_prefix(fromhn), zip, side
    FROM tiger_addr;
END;

DROP TABLE feature_bin;
DROP TABLE linezip;
DROP TABLE tiger_addr;
DROP TABLE tiger_featnames;
DROP TABLE tiger_edges;

