#!/usr/bin/env python3
"""Measure Map A hex interiors. Output is an unreviewed visual aid, never rules data."""
from __future__ import annotations
import json
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
IMAGE = ROOT / 'assets/maps/map_a.jpg'
OUTPUT = ROOT / 'data/source/map_a_terrain_candidates.json'
image = Image.open(IMAGE).convert('RGB')
records = {}
for q in range(25):
    for row in range(1,20):
        hex_id = f'{chr(65+q)}{row}'
        x = round(307 + q * 270.8)
        y = round(272 + (row-1) * 314 + (q & 1) * 157)
        pixels = []
        for dy in range(-120,121,4):
            for dx in range(-135,136,4):
                if (dx/135)**2 + (dy/120)**2 < .9:
                    pixels.append(image.getpixel((x+dx,y+dy)))
        count = len(pixels)
        features = {
            'blue': sum(b > r*1.17 and b > g*1.05 and b > 130 for r,g,b in pixels)/count,
            'cyan': sum(b > 195 and g > 165 and r < 150 for r,g,b in pixels)/count,
            'green': sum(g > r*1.13 and g > b*1.03 and r < 215 for r,g,b in pixels)/count,
            'olive': sum(110 < r < 235 and 105 < g < 235 and b < 185 and abs(r-g) < 30 for r,g,b in pixels)/count,
            'brown': sum(65 < r < 210 and 35 < g < 180 and b < 135 and r > g*1.1 for r,g,b in pixels)/count,
        }
        green, olive, brown = features['green'], features['olive'], features['brown']
        if features['cyan'] > .13: guess = 'stream'
        elif features['blue'] > .14: guess = 'road'
        elif green > .075 and olive > green*1.2 and brown > .05: guess = 'brush'
        elif green > .14: guess = 'woods'
        elif green > .025 and brown > .018: guess = 'brush'
        elif olive > .32: guess = 'cover'
        else: guess = 'open_or_building'
        background_blue = sorted(b for r,g,b in pixels if r > 245 and g > 245 and b > 175)
        records[hex_id] = {
            'guess': guess,
            'features': {key:round(value,3) for key,value in features.items()},
            'background_blue_median': background_blue[len(background_blue)//2] if background_blue else None,
        }
OUTPUT.write_text(json.dumps({'status':'unreviewed_image_heuristic_do_not_use_for_gameplay','image':'assets/maps/map_a.jpg','hexes':records},ensure_ascii=False,indent=2)+'\n')
print(f'Wrote {len(records)} candidate hexes to {OUTPUT.relative_to(ROOT)}')
