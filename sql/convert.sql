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

-- generate features from the featnames table for each desired edge
--   computing the metaphone hash of the name in the process.

INSERT INTO feature
    SELECT f.tlid, fullname, metaphone(name,5), paflag, zip
        FROM linezip l, tiger_featnames f
        WHERE l.tlid=f.tlid AND name <> "" AND name IS NOT NULL;

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
