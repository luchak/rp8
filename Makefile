SRC = $(wildcard src/*.p8.lua) src/names.txt tools/loaf.py tools/rp8.py

all: build/rp8_min.p8.png build/rp8_debug.p8

build/rp8_min.p8.png: $(SRC) src/rp8.p8
	mkdir -p build
	python3 shrinko8/shrinko8.py --minify --focus-compressed --count --preserve "$$(tr '\n' ',' < src/names.txt)" \
		--script tools/rp8.py src/rp8.p8 $@

build/rp8_debug.p8: $(SRC) src/rp8.p8
	mkdir -p build
	python3 shrinko8/shrinko8.py --minify --count --no-minify-rename --no-minify-spaces \
		--no-minify-lines --no-minify-comments --script tools/rp8.py src/rp8.p8 $@

lint:
	python3 shrinko8/shrinko8.py --lint --script tools/rp8.py src/rp8.p8

build/user_guide.html: $(wildcard docs/*.md)
	mkdir -p build
	mkdocs build
	htmlark site/print_page/index.html -o build/user_guide.html

docs: build/user_guide.html

clean:
	rm -rf build site

watch:
	ls $(SRC) src/rp8.p8 | entr make

.PHONY: clean watch
