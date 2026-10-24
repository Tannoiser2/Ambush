#!/usr/bin/env python3
"""Fail on broken paragraph references; report coverage without calling OCR reviewed."""
import json, pathlib
root=pathlib.Path(__file__).resolve().parents[1]
mission=json.loads((root/'data/mission_01.json').read_text())
paragraphs=json.loads((root/'data/paragraphs_it.json').read_text())
source=json.loads((root/'data/source/paragraphs_en.json').read_text())['records']
refs=set()
for card in mission['conditions'].values():
    for value in list(card['hexes'].values())+list(card['events'].values()):
        if value not in ('NONE','EVENT'): refs.add(value.split(':')[-1])
def visit(obj):
    if isinstance(obj,dict):
        if obj.get('op')=='goto':refs.add(obj['id'])
        for value in obj.values():visit(value)
    elif isinstance(obj,list):
        for value in obj:visit(value)
seen=set()
while refs-seen:
    todo=refs-seen;seen|=todo
    for id in todo:
        if id in paragraphs:visit(paragraphs[id]['ops'])
missing=refs-paragraphs.keys()
print(f'Carte verificate: {len(mission["conditions"])} / 4 nella missione 1')
print(f'Paragrafi italiani rivisti: {len(paragraphs)}; candidati OCR inglesi: {len(source)}')
print(f'Riferimenti raggiungibili dalla Condizione 1: {len(refs)}; mancanti: {sorted(missing)}')
assert not missing
