-- create temporary tables to hold the TIGER/Line data before it's
--   transformed and loaded into the permanent tables.
--
-- this file was made by running 'shp2pgsql -p' on each of the 
--   TIGER/Line shapefiles and then massaging the result by hand.
--
PRAGMA temp_store=MEMORY;
PRAGMA journal_mode=MEMORY;
PRAGMA synchronous=OFF;
PRAGMA cache_size=500000;
PRAGMA count_changes=0;
CREATE TEMPORARY TABLE "tiger_edges" (
"statefp" varchar(2),
"countyfp" varchar(3),
"tlid" int8,
"tfidl" int8,
"tfidr" int8,
"mtfcc" varchar(5),
"fullname" varchar(100),
"smid" varchar(22),
"lfromadd" varchar(12),
"ltoadd" varchar(12),
"rfromadd" varchar(12),
"rtoadd" varchar(12),
"zipl" varchar(5),
"zipr" varchar(5),
"featcat" varchar(1),
"hydroflg" varchar(1),
"railflg" varchar(1),
"roadflg" varchar(1),
"olfflg" varchar(1),
"passflg" varchar(1),
"divroad" varchar(1),
"exttyp" varchar(1),
"ttyp" varchar(1),
"deckedroad" varchar(1),
"artpath" varchar(1),
"persist" varchar(1),
"gcseflg" varchar(1),
"offsetl" varchar(1),
"offsetr" varchar(1),
"tnidf" int8,
"tnidt" int8,
"the_geom" blob
);
-- SELECT AddGeometryColumn('','edges','the_geom','-1','MULTILINESTRING',2);
CREATE TEMPORARY TABLE "tiger_featnames" (
"tlid" int8,
"fullname" varchar(100),
"name" varchar(100),
"predirabrv" varchar(15),
"pretypabrv" varchar(50),
"prequalabr" varchar(15),
"sufdirabrv" varchar(15),
"suftypabrv" varchar(50),
"sufqualabr" varchar(15),
"predir" varchar(2),
"pretyp" varchar(3),
"prequal" varchar(2),
"sufdir" varchar(2),
"suftyp" varchar(3),
"sufqual" varchar(2),
"linearid" varchar(22),
"mtfcc" varchar(5),
"paflag" varchar(1));
CREATE TEMPORARY TABLE "tiger_addr" (
"tlid" int8,
"fromhn" varchar(12),
"tohn" varchar(12),
"side" varchar(1),
"zip" varchar(5),
"plus4" varchar(4),
"fromtyp" varchar(1),
"totyp" varchar(1),
"fromarmid" int4,
"toarmid" int4,
"arid" varchar(22),
"mtfcc" varchar(5));
