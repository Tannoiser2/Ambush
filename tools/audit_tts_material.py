#!/usr/bin/env python3
"""Inventory physical combat sources in the local TTS backup.

Only metadata is committed. The source images remain in the user's archive.
"""
import collections
import json
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
archive = ROOT / 'Ambush! (3099626094).ttsmod'

def walk(obj):
    if isinstance(obj, dict):
        yield obj
        for value in obj.values():
            yield from walk(value)
    elif isinstance(obj, list):
        for value in obj:
            yield from walk(value)

with zipfile.ZipFile(archive) as z:
    entries = z.namelist()
    tts = json.loads(z.read('Mods/Workshop/3099626094.json'))
    imported = json.loads((ROOT / 'data/source/inventory.json').read_text())
    names = {item['name'] for item in imported['assets']}
    base_assets = ['Map A', 'Map B', 'Mission Sleeve Viewer'] + [f'Mission 1 - Condition {i}' for i in range(1, 5)]
    source_pdfs = [path for path in entries if path.lower().endswith('.pdf')]
    cards = {}
    sheets = {}
    missing = [name for name in base_assets if name not in names]
    if not any('1187209805474697151' in path for path in source_pdfs): missing.append('Rules PDF')
    if not any('1187209343569221100' in path for path in source_pdfs): missing.append('Paragraph PDF')
    for obj in walk(tts):
        name = obj.get('Nickname', '')
        if obj.get('Name') != 'Card' or not (name.startswith('US ') or name.startswith('GE ')):
            continue
        deck_id, deck = next(iter(obj['CustomDeck'].items()))
        card_id = int(obj['CardID'])
        face_url = deck['FaceURL']
        image_hash = face_url.rstrip('/').split('/')[-1]
        matches = [entry for entry in entries if image_hash.lower() in entry.lower()]
        if not matches:
            missing.append(name)
        cards[name] = {'deck_id': deck_id, 'card_id': card_id,
                       'sheet_hash': image_hash,
                       'column': card_id % 100 % int(deck['NumWidth']),
                       'row': card_id % 100 // int(deck['NumWidth'])}
        sheets[image_hash] = {'width_cards': int(deck['NumWidth']),
                              'height_cards': int(deck['NumHeight']),
                              'present': bool(matches)}
    chart = next(obj for obj in walk(tts) if obj.get('Nickname') == 'Hit Charts')
    chart_hash = chart['CustomImage']['ImageURL'].rstrip('/').split('/')[-1]
    chart_present = any(chart_hash.lower() in entry.lower() for entry in entries)
    if not chart_present: missing.append('Hit Charts')
    for prefix in ('US ', 'GE '):
        if not any(name.startswith(prefix) for name in cards): missing.append(prefix + 'cards')
    report = {'archive': archive.name,
              'named_card_count': len(cards),
              'us_card_count': sum(name.startswith('US ') for name in cards),
              'german_card_count': sum(name.startswith('GE ') for name in cards),
              'unique_face_sheets': len(sheets),
              'face_sheets': sheets,
              'hit_chart': {'hash': chart_hash, 'present': chart_present},
              'base_assets_present': {name: name in names for name in base_assets},
              'rules_pdf_present': 'Rules PDF' not in missing,
              'paragraph_pdf_present': 'Paragraph PDF' not in missing,
              'cards': dict(sorted(cards.items())),
              'missing': sorted(set(missing))}
    output = ROOT / 'data/source/material_audit.json'
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f"{len(cards)} named cards: {report['us_card_count']} US, {report['german_card_count']} German; "
          f"{len(sheets)} sheets; chart present: {chart_present}; missing: {report['missing']}")
    assert not missing
