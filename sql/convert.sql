BEGIN;
CREATE INDEX featnames_tlid ON tiger_featnames (tlid);
CREATE INDEX addr_tlid ON tiger_addr (tlid);
CREATE INDEX edges_tlid ON tiger_edges (tlid);

CREATE TEMPORARY TABLE linezip AS
    SELECT DISTINCT tlid, zip FROM (
        SELECT tlid, zip FROM tiger_addr a
        UNION
        SELECT tlid, zipr AS zip FROM tiger_edges e
           WHERE e.mtfcc LIKE 'S%' AND zipr <> ""
        UNION
        SELECT tlid, zipl AS zip FROM tiger_edges e
           WHERE e.mtfcc LIKE 'S%' AND zipl <> ""
    ) AS whatever;

INSERT INTO feature
    SELECT l.tlid, name, metaphone(name,5), predirabrv, pretypabrv,
           prequalabr, sufdirabrv, suftypabrv, sufqualabr, paflag, zip
        FROM linezip l, tiger_featnames f
        WHERE l.tlid=f.tlid;

INSERT INTO edge
    SELECT l.tlid, substr(the_geom,10) FROM linezip l, tiger_edges e
        WHERE l.tlid=e.tlid;

INSERT INTO range SELECT tlid, fromhn, tohn, NULL, zip, side FROM tiger_addr;
END;
