## What extension (e.g. md, markdown, mdown) is being used
## for markdown files
MEXT = md

## Expands to a list of all markdown files in the working directory
SRC = $(wildcard *.$(MEXT))

SRC_IMGS = $(wildcard img/orig/*.png)
SRC_IMGS_EXPANDED = $(SRC_IMGS:img/orig/%.png=img/%.2048.png)

ALL_IMG_BASENAMES = synth.png drums.png header_section.png drum_step_btns.png \
		    bd_sd_radio_btns.png synth_step_note_btns.png ptn_bank_btns.png ptn_copy_paste_btns.png \
		    sound_design.png ps_mode_btn.png seq_copy_paste_btns.png transport.png \
		    override_btns.png song_edit_btns.png
ALL_IMGS = $(ALL_IMG_BASENAMES:%.png=img/%.png) $(SRC_IMGS_EXPANDED)

## x.pdf depends on x.md, x.html depends on x.md, etc
PDF=$(SRC:.md=.pdf)
HTML=$(SRC:.md=.html) index.html

## Rules -- make all, make pdf, make html. The `clean` rule is below.
all:    $(HTML) $(PDF)
pdf:    clean $(PDF)
html:   clean $(HTML)

index.html: user_guide.html
	cp user_guide.html index.html

%.html: %.md $(ALL_IMGS)
	./build_html.sh $< $@

%.tex:  %.md $(ALL_IMGS)
	pandoc --standalone --toc --template=eisvogel -o $@ $<

%.pdf:  %.md $(ALL_IMGS)
	pandoc --standalone --toc --template=eisvogel -o $@ $<

img/%.2048.png: img/orig/%.png
	convert $< -scale 2048x2048 +dither -colors 255 $@

img/header_section.png: img/rp8_playing.2048.png
	magick -extract 2048x512+0+0 $< $@

img/synth.png: img/rp8_playing.2048.png
	magick -extract 2048x512+0+1024 $< $@

img/drums.png: img/rp8_playing.2048.png
	magick -extract 2048x512+0+1536 $< $@

img/drum_step_btns.png: img/rp8_clear.2048.png
	magick -extract 2048x128+0+1920 $< $@

img/bd_sd_radio_btns.png: img/rp8_clear.2048.png
	magick -extract 128x256+512+1664 $< $@

img/synth_step_note_btns.png: img/rp8_clear.2048.png
	magick -extract 2048x256+0+768 $< $@

img/ptn_bank_btns.png: img/rp8_clear.2048.png
	magick -extract 512x128+0+640 $< $@

img/ptn_copy_paste_btns.png: img/rp8_clear.2048.png
	magick -extract 256x128+128+512 $< $@

img/sound_design.png: img/rp8_clear.2048.png
	magick $< -fill white \
	\( +clone -evaluate set 40% -draw "rectangle 512,1536 2048,1920" \
	-draw "rectangle 768,1024 2048,1280" -draw "rectangle 768,512 2048,768" \
	-draw "rectangle 1664,0 2048,128" -draw "rectangle 256,128 2048,512" \) \
	-compose multiply -composite $@

img/ps_mode_btn.png: img/rp8_recording.2048.png
	magick -extract 128x128+384+0 $< $@

img/seq_copy_paste_btns.png: img/rp8_overrides.2048.png
	magick -extract 128x256+0+128 $< $@

img/transport.png: img/rp8_playing.2048.png
	magick -extract 1024x128+512+0 $< $@

img/override_btns.png: img/rp8_overrides.2048.png
	magick -extract 256x128+0+384 $< $@

img/song_edit_btns.png: img/rp8_overrides.2048.png
	magick -extract 256x256+0+128 $< $@

clean:
	rm -f *.html *.pdf *.tex *.aux *.log $(ALL_IMGS)

watch:
	ls $(SRC) $(ALL_IMGS) | entr make

.PHONY: clean watch
