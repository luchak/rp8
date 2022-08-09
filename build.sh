#!/bin/sh

python3 shrinko8/shrinko8.py --minify --count --preserve "$(tr '\n' ',' < names.txt)" rp8.p8 rp8_shrink.p8.png
