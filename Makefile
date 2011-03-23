all:
	make -C src install
	gem build gemspec

test: all
	ruby -Ilib tests/run.rb

install: all
	# gem install *.gem

clean:
	make -C src clean
	rm -f lib/geocoder/us/sqlite3.so
	rm -f *.gem
