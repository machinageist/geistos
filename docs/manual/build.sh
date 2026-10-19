#!/usr/bin/env bash
# Author: Jeff
# Date: 2026-10-19
# Description: Build the GeistOS operations manual EPUB from manual.md
# Notes: Needs pandoc and rsvg-convert. Diagrams are rendered to PNG because
#        some e-readers draw SVG poorly or not at all
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output="${1:-${here}/GeistOS-Operations-Manual.epub}"

# Render each diagram at twice its drawn size so it stays sharp on dense screens
for svg in "${here}"/images/*.svg; do
    png="${svg%.svg}.png"
    if [[ "$(basename "$svg")" == "cover.svg" ]]; then
        rsvg-convert --width 1600 "$svg" -o "$png"
    else
        rsvg-convert --zoom 2 "$svg" -o "$png"
    fi
done

cd "$here"
pandoc manual.md \
    --from markdown \
    --to epub3 \
    --output "$output" \
    --css epub.css \
    --epub-cover-image images/cover.png \
    --toc \
    --toc-depth 2 \
    --split-level 1 \
    --syntax-highlighting=none \
    --resource-path "$here"

printf 'built %s\n' "$output"
