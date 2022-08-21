#!/bin/sh

python3 shrinko8/shrinko8.py --minify --count --preserve "$(tr '\n' ',' < names.txt)" --script \
    rp8.py rp8.p8 rp8_min.p8.png
python3 shrinko8/shrinko8.py --minify --count --preserve "$(tr '\n' ',' < names.txt)" --script \
    rp8.py rp8.p8 rp8_min.p8
python3 shrinko8/shrinko8.py --minify --count --no-minify-rename --no-minify-spaces --no-minify-lines \
    --no-minify-comments --script rp8.py rp8.p8 rp8_debug.p8
