#!/bin/sh

set -ex

butler push --fix-permissions --if-changed --userversion="$1" exports/rp8.bin/rp8_windows.zip luchak/rp8:win
butler push --fix-permissions --if-changed --userversion="$1" exports/rp8.bin/rp8_osx.zip luchak/rp8:mac
butler push --fix-permissions --if-changed --userversion="$1" exports/rp8.bin/rp8_linux.zip luchak/rp8:linux
butler push --fix-permissions --if-changed --userversion="$1" exports/rp8.bin/rp8_raspi.zip luchak/rp8:raspi
butler push --fix-permissions --if-changed --userversion="$1" docs/user_guide.pdf luchak/rp8:manual
