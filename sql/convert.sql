BEGIN;
CREATE INDEX featnames_tlid ON tiger_featnames (tlid);
CREATE INDEX addr_tlid ON tiger_addr (tlid);
CREATE INDEX edges_tlid ON tiger_edges (tlid);

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

INSERT INTO feature
    SELECT l.tlid, name, metaphone(name,5), predirabrv, pretypabrv,
           prequalabr, sufdirabrv, suftypabrv, sufqualabr, paflag, zip
        FROM linezip l, tiger_featnames f
        WHERE l.tlid=f.tlid AND name <> "" AND name IS NOT NULL;

INSERT OR IGNORE INTO edge
    SELECT l.tlid, compress_wkb_line(the_geom) FROM
        (SELECT DISTINCT tlid FROM linezip) AS l, tiger_edges e
        WHERE l.tlid=e.tlid AND fullname <> "" AND fullname IS NOT NULL;

INSERT INTO range
    SELECT tlid, digit_suffix(fromhn), digit_suffix(tohn),
           nondigit_prefix(fromhn), zip, side
    FROM tiger_addr;
END;
