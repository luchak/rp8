#!/bin/sh

set -ex

echo $(pwd)

butler push --auto-wrap --fix-permissions --if-changed --userversion="$1" exports/rp8.bin/windows luchak/rp8:win
butler push --auto-wrap --fix-permissions --if-changed --userversion="$1" exports/rp8.bin/rp8.app luchak/rp8:mac
butler push --auto-wrap --fix-permissions --if-changed --userversion="$1" exports/rp8.bin/linux luchak/rp8:linux
butler push --auto-wrap --fix-permissions --if-changed --userversion="$1" exports/rp8.bin/raspi luchak/rp8:raspi
butler push --fix-permissions --if-changed --userversion="$1" docs/user_guide.pdf luchak/rp8:manual
