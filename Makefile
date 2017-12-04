
.PHONY: zinve-bundle clean dist

DEFAULT: dist

clean:
	rm -rf build

dist: zinve-bundle

zinve-bundle: clean
	mkdir -p build/bin
	./scripts/bundle_zinve.py -o build/bin/zinve

install: zinve-bundle
	rm -rf tmp/phone && mkdir -p tmp/phony
	cp -r build/* tmp/phony/

