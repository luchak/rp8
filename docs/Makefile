## What extension (e.g. md, markdown, mdown) is being used
## for markdown files
MEXT = md

## Expands to a list of all markdown files in the working directory
SRC = $(wildcard *.$(MEXT))

## x.pdf depends on x.md, x.html depends on x.md, etc
PDFS=$(SRC:.md=.pdf)
HTML=$(SRC:.md=.html)
TEX=$(SRC:.md=.tex)

## Rules -- make all, make pdf, make html. The `clean` rule is below.
all:    $(PDFS) $(HTML) $(TEX)
pdf:    clean $(PDFS)
html:   clean $(HTML)
tex:    clean $(TEX)

## The commands associated with each rule. The first one is run with 
## make html.
%.html: %.md
	pandoc -s -o $@ $<

## Same goes for the other file types. 
## Watch out for the TAB before 'pandoc'
%.tex:  %.md
	pandoc -o $@ $<

%.pdf:  %.md
	pandoc -o $@ $<

clean:
	rm -f *.html *.pdf *.tex *.aux *.log

.PHONY: clean
