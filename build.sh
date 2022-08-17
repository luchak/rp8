#!/bin/sh

python3 shrinko8/shrinko8.py --minify --count --preserve "$(tr '\n' ',' < names.txt)" --script shrinko8/loaf.py rp8.p8 rp8_shrink.p8.png
python3 shrinko8/shrinko8.py --minify --count --preserve "$(tr '\n' ',' < names.txt)" --script shrinko8/loaf.py rp8.p8 rp8_shrink.p8
