## What extension (e.g. md, markdown, mdown) is being used
## for markdown files
MEXT = md

## Expands to a list of all markdown files in the working directory
SRC = $(wildcard *.$(MEXT))

## x.pdf depends on x.md, x.html depends on x.md, etc
PDF=$(SRC:.md=.pdf)
HTML=$(SRC:.md=.html)

## Rules -- make all, make pdf, make html. The `clean` rule is below.
all:    $(HTML) $(PDF)
pdf:    clean $(PDF)
html:   clean $(HTML)

%.html: %.md
	./build_html.sh $< $@

%.tex:  %.md
	pandoc --standalone --toc --template=eisvogel -o $@ $<

%.pdf:  %.md
	pandoc --standalone --toc --template=eisvogel -o $@ $<

clean:
	rm -f *.html *.pdf *.tex *.aux *.log

watch:
	echo "$(SRC)" | entr make

.PHONY: clean watch
