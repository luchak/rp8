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
		    override_btns.png song_edit_btns.png drums_empty.png drum_btn_colors.png \
		    synth_empty.png rp8_help.2048.png record_btn_states.png mixer.png transport_ref.png \
		    rp8_file_menu.2048.png arrangement_btns.png tempo_shuffle_volume.png \
		    device_pattern_controls.png

ALL_IMGS = $(ALL_IMG_BASENAMES:%.png=img/%.png)

all: $(ALL_IMGS)

img/%.2048.png: img/orig/%.png
	convert -define png:exclude-chunks=date,time $< -scale 2048x2048 +dither -colors 255 $@

img/header_section.png: img/rp8_playing.2048.png
	magick -define png:exclude-chunks=date,time -extract 2048x512+0+0 $< $@

img/synth.png: img/rp8_playing.2048.png
	magick -define png:exclude-chunks=date,time -extract 2048x512+0+1024 $< $@

img/drums.png: img/rp8_playing.2048.png
	magick -define png:exclude-chunks=date,time -extract 2048x512+0+1536 $< $@

img/drum_step_btns.png: img/rp8_clear.2048.png
	magick -define png:exclude-chunks=date,time -extract 2048x128+0+1920 $< $@

img/bd_sd_radio_btns.png: img/rp8_clear.2048.png
	magick -define png:exclude-chunks=date,time -extract 128x256+512+1664 $< $@

img/synth_step_note_btns.png: img/rp8_clear.2048.png
	magick -define png:exclude-chunks=date,time -extract 2048x256+0+768 $< $@

img/ptn_bank_btns.png: img/rp8_clear.2048.png
	magick -define png:exclude-chunks=date,time -extract 512x128+0+640 $< $@

img/ptn_copy_paste_btns.png: img/rp8_clear.2048.png
	magick -define png:exclude-chunks=date,time -extract 256x128+128+512 $< $@

img/sound_design.png: img/rp8_clear.2048.png
	magick -define png:exclude-chunks=date,time $< -fill white \
	\( +clone -evaluate set 40% -draw "rectangle 512,1536 2048,1920" \
	-draw "rectangle 768,1024 2048,1280" -draw "rectangle 768,512 2048,768" \
	-draw "rectangle 1664,0 2048,128" -draw "rectangle 256,128 2048,512" \) \
	-compose multiply -composite $@

img/ps_mode_btn.png: img/rp8_recording.2048.png
	magick -define png:exclude-chunks=date,time -extract 128x128+384+0 $< $@

img/seq_copy_paste_btns.png: img/rp8_overrides.2048.png
	magick -define png:exclude-chunks=date,time -extract 128x256+0+128 $< $@

img/transport.png: img/rp8_overrides.2048.png
	magick -define png:exclude-chunks=date,time -extract 1024x128+512+0 $< $@

img/override_btns.png: img/rp8_overrides.2048.png
	magick -define png:exclude-chunks=date,time -extract 256x128+0+384 $< $@

img/song_edit_btns.png: img/rp8_overrides.2048.png
	magick -define png:exclude-chunks=date,time -extract 256x256+0+128 $< $@

img/arrangement_btns.png: img/rp8_overrides.2048.png
	magick -define png:exclude-chunks=date,time -extract 2048x512+0+0 $< -fill white \
	\( +clone -evaluate set 40% -draw "rectangle 0,128 255,511" \) \
	-compose multiply -composite $@

img/drums_empty.png: img/rp8_clear.2048.png
	magick -define png:exclude-chunks=date,time -extract 2048x512+0+1536 $< $@

img/drum_btn_colors.png: img/rp8_step_colors.2048.png
	magick -define png:exclude-chunks=date,time -extract 640x128+0+1920 $< $@

img/synth_empty.png: img/rp8_clear.2048.png
	magick -define png:exclude-chunks=date,time -extract 2048x512+0+512 $< $@

img/record_btn_states.png: img/rp8_clear.2048.png img/rp8_playing.2048.png img/rp8_overrides.2048.png img/rp8_recording.2048.png
	convert -define png:exclude-chunks=date,time -size 512x128 canvas:none \
		\( img/rp8_clear.2048.png[128x128+128+0] \) -geometry +0+0 -composite \
		\( img/rp8_playing.2048.png[128x128+128+0] \) -geometry +128+0 -composite \
		\( img/rp8_overrides.2048.png[128x128+128+0] \) -geometry +256+0 -composite \
		\( img/rp8_recording.2048.png[128x128+128+0] \) -geometry +384+0 -composite \
		$@

img/mixer.png: img/rp8_clear.2048.png
	magick -define png:exclude-chunks=date,time -extract 512x512+1536+0 $< $@

img/transport_ref.png: img/rp8_recording.2048.png
	magick -define png:exclude-chunks=date,time -extract 1664x128+0+0 $< $@

img/tempo_shuffle_volume.png: img/rp8_clear.2048.png
	magick -define png:exclude-chunks=date,time -extract 2048x512+0+0 $< -fill white \
	\( +clone -evaluate set 40% -draw "rectangle 256,128 767,255" \
	-draw "rectangle 256,256 511,383" \) \
	-compose multiply -composite $@

img/device_pattern_controls.png: img/rp8_clear.2048.png
	convert -define png:exclude-chunks=date,time -font helvetica -fill white -stroke black \
		-pointsize 80 -draw "text 128,128 'test'" $< $@

clean:
	rm -f $(ALL_IMGS)

watch:
	ls $(SRC) $(ALL_IMGS) | entr make

.PHONY: clean watch

.PRECIOUS: $(SRC_IMGS_EXPANDED)
