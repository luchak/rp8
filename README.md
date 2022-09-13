# RP-8

A demake of ReBirth RB-338 for Pico-8.

Run `build.sh` to build, or install `entr` and run `watch.sh` to rebuild on changes. Build produces `rp8_min.p8`, `rp8_min.p8.png`, and `rp8_debug.p8` (not minified).

### Dependencies

* For shrinko8, you must have a recent-ish version of Python installed, plus Pillow for PNG export.
* To export, you must have Pico-8 in your path as `pico8`, and the `realpath` utility in your path as `grealpath`.
* To watch and rebuild on changes, you must have `entr` in your path.
