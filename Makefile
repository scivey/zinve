
.PHONY: zinve-bundle

zinve-bundle:
	rm -rf build
	./scripts/bundle_zinve.py

install: zinve-bundle
	rm -rf tmp/phone && mkdir -p tmp/phony
	cp -r build/* tmp/phony/

