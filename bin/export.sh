#!/bin/sh

mkdir -p ./exports/html
pico8 -export /tmp/rp8.html "$(grealpath ./build/rp8_min.p8.png)"
pico8 -export /tmp/rp8.bin "$(grealpath ./build/rp8_min.p8.png)"
mv /tmp/rp8.html /tmp/rp8.js ./exports/html
mv ./exports/html/rp8.html ./exports/html/index.html
rm -rf ./exports/rp8.bin
cp -r /tmp/rp8.bin ./exports
rm -f ./exports/rp8_html.zip
zip -j ./exports/rp8_html.zip exports/html/index.html exports/html/rp8.js
cp ./build/rp8_min.p8.png exports/rp8.p8.png
