#!/usr/bin/env python3
"""Turn the inspected Map A atlas into conservative terrain data.

Image-derived classes are useful to display, but only white-background level-1
hexes outside known crest/embankment zones are cleared for automatic LOS.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = json.loads((ROOT / "data/source/map_a_terrain_candidates.json").read_text())
buildings = {"K13": "stone_building", "L13": "stone_building", "T8": "wood_building"}
terrain_names = {"open_or_building": "clear", "woods": "woods", "brush": "brush",
                 "cover": "cover", "road": "road", "stream": "stream"}

# Hexsides traced on the original scan, not inferred from the terrain classifier.
# Unlisted sides in the hazard zones intentionally remain unresolved.
crest_edges = """
R16|S17 S18|T17 S18|T18 T13|T14 T14|U14 T14|U15
U15|V15 V14|W15 V15|V16 V15|W16 V16|W17 V17|W18
U18|U19 U19|V18 V18|W19 W14|W15 W15|W16 W17|W18
W19|X19 X14|X15 X15|X16 X16|X17 X17|X18 X18|Y19
""".split()
embankment_edges = """
A7|B7 B5|C6 B7|C8 C8|D8 D6|E7 D8|E9 E7|F7
F7|G8 F9|G10 G8|H8 G10|G11 H8|I9 I10|I11
I10|J9 J10|J11 J9|K10 R12|S13 S13|T12
""".split()

def cube(hex_id: str) -> tuple[int, int, int]:
    q = ord(hex_id[0])-65
    r = int(hex_id[1:])-1-(q-(q&1))//2
    return q, r, -q-r

hexsides = {}
for kind, edges in (("crest", crest_edges), ("embankment", embankment_edges)):
    for edge in edges:
        a, b = edge.split("|")
        ca, cb = cube(a), cube(b)
        assert max(abs(ca[i]-cb[i]) for i in range(3)) == 1, edge
        key = "|".join(sorted((a,b)))
        assert key not in hexsides, key
        hexsides[key] = kind

# The printed embankment follows the western road; crests lie in the southeast.
# All edges touching these zones remain unresolved until individual hexsides are traced.
hazard_hexes = set()
for col, row in [(0,6),(1,6),(2,7),(3,7),(4,8),(5,8),(6,9),(7,9),
                 (8,10),(9,10),(10,11),(11,11)]:
    for dc in (-1, 0, 1):
        for dr in (-1, 0, 1):
            if 0 <= col+dc < 25 and 1 <= row+dr <= 19:
                hazard_hexes.add(f"{chr(65+col+dc)}{row+dr}")
for col in range(17,25):
    for row in range(12,20):
        hazard_hexes.add(f"{chr(65+col)}{row}")

hexes = {}
for hex_id, record in source["hexes"].items():
    terrain = buildings.get(hex_id, terrain_names[record["guess"]])
    blue = record["background_blue_median"]
    # Bright white is unambiguous Level 1. Yellow Levels 2/3 are not separated
    # reliably by JPEG pixels, so do not assign either one yet.
    elevation = 1 if blue is not None and blue >= 250 else None
    hexes[hex_id] = {"terrain": terrain, "elevation": elevation,
                     "classification": "image_heuristic_with_atlas_spot_checks",
                     "hexside_review_pending": hex_id in hazard_hexes}

out = {"map": "A", "status": "partial_los_diagnostic_only",
       "notes": "Terrain classes are image-derived and spot-checked; yellow elevation and building apertures await hexside review. Never authorize fire from this data alone.",
       "hexes": hexes, "hexsides": hexsides}
path = ROOT / "data/map_a_terrain.json"
path.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
print(f"{len(hexes)} hexes; {sum(v['elevation'] == 1 for v in hexes.values())} with probable white Level 1")
