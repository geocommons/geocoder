all:
	make -C src install
	gem build gemspec

install: all
	gem install *.gem

clean:
	make -C src clean
	rm *.gem
