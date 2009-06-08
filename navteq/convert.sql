BEGIN;
CREATE INDEX navteq_link_id on local_streets (link_id);

CREATE TEMPORARY TABLE linezip AS
    SELECT DISTINCT tlid, zip FROM (
        SELECT link_id AS tlid, r_postcode AS zip FROM local_streets
           WHERE addr_type IS NOT NULL AND st_name IS NOT NULL
           AND r_postcode IS NOT NULL
        UNION
        SELECT link_id AS tlid, l_postcode AS zip FROM local_streets
           WHERE addr_type IS NOT NULL AND st_name IS NOT NULL
           AND l_postcode IS NOT NULL
    ) AS whatever;

INSERT INTO feature
    SELECT l.tlid, st_nm_base, metaphone(st_nm_base,5), st_nm_pref, st_typ_bef,
           NULL, st_nm_suff, st_typ_aft, NULL, 'P', zip
        FROM linezip l, local_streets f
        WHERE l.tlid=f.link_id AND st_name IS NOT NULL;

INSERT OR IGNORE INTO edge
    SELECT l.tlid, compress_wkb_line(the_geom) FROM
        (SELECT DISTINCT tlid FROM linezip) AS l, local_streets f
        WHERE l.tlid=f.link_id AND st_name IS NOT NULL;

INSERT INTO range
    SELECT link_id, digit_suffix(l_refaddr), digit_suffix(l_nrefaddr),
           nondigit_prefix(l_refaddr), l_postcode, 'L'
    FROM linezip l, local_streets f
    WHERE l.tlid=f.link_id AND l_refaddr IS NOT NULL
    UNION
    SELECT link_id, digit_suffix(r_refaddr), digit_suffix(r_nrefaddr),
           nondigit_prefix(r_refaddr), r_postcode, 'R'
    FROM linezip l, local_streets f
    WHERE l.tlid=f.link_id AND r_refaddr IS NOT NULL;

END;
