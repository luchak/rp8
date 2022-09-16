SRC = $(wildcard src/*.lua) src/rp8.p8 src/names.txt tools/loaf.py tools/rp8.py

all: build/rp8_min.p8.png build/rp8_debug.p8

build/rp8_min.p8.png: $(SRC)
	mkdir -p build
	python3 shrinko8/shrinko8.py --minify --count --preserve "$(tr '\n' ',' < names.txt)" \
		--script tools/rp8.py src/rp8.p8 $@

build/rp8_debug.p8: $(SRC)
	mkdir -p build
	python3 shrinko8/shrinko8.py --minify --count --no-minify-rename --no-minify-spaces \
		--no-minify-lines --no-minify-comments --script tools/rp8.py src/rp8.p8 $@

clean:
	rm -rf build

watch:
	ls $(SRC) | entr make

.PHONY: clean watch
