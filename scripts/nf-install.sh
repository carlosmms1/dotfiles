#!/bin/bash

set -e

FONTS_DIR=.local/share/fonts

sudo dnf install fontconfig
cd ~
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Meslo.zip
mkdir -p "$FONTS_DIR"
unzip Meslo.zip -d "$FONTS_DIR"
cd "$FONTS_DIR"
cd ~
rm Meslo.zip
fc-cache -fv
