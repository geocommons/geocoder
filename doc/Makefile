all: lookup.html parsing.html

%.html: %.rst voidspace.css
	rst2html --stylesheet-path=voidspace.css --no-compact-lists $< > $@

clean:
	rm -f *.html
