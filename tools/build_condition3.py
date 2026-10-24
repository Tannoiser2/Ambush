#!/usr/bin/env python3
"""Review every OCR-uncertain cell against the printed mission 1 condition 3."""
import json,pathlib
root=pathlib.Path(__file__).resolve().parents[1]
source=json.loads((root/'data/source/condition_candidates.json').read_text())['3']
card={'status':'transcribed_visual_review','source':'m1_c3.png + sleeve.png','hexes':source['hexes'].copy(),'events':source['events'].copy()}
fix='''
RE1=s0:613
N3=s6:318 Q4=s2:335
K5=s2:295 L5=s5:603 N5=s5:603 P5=s6:290 R5=s6:326
F6=s5:192 H6=s2:295 J6=s2:295 L6=s2:182 O6=s5:192 R6=s2:196 U6=s8:339 W6=s8:339
B7=NONE D7=s2:311 E7=NONE F7=NONE G7=344 H7=344 J7=344 K7=344 L7=s2:182 M7=s5:351 O7=s2:335 Q7=344 R7=605 S7=345 T7=s8:339 U7=001 V7=EVENT W7=s8:339 Y7=EVENT
K8=s1:190 L8=s1:299 T8=s5:456
G9=s1:190 K9=s2:295 L9=s1:299 T9=NONE
A10=NONE B10=EVENT C10=NONE D10=NONE E10=s1:190 F10=s3:600 G10=s3:328 H10=s3:600 I10=s1:190 J10=s2:335 K10=s1:299 L10=s1:299 M10=s1:186 N10=s1:186 O10=NONE P10=s2:295 Q10=s2:295 R10=s2:607 S10=s2:607 T10=NONE U10=NONE W10=NONE X10=NONE Y10=NONE RE10=s7:450
G11=s1:191 F13=s1:190 H14=s1:190 F15=s1:299 G15=s1:190 G16=s1:190 H17=s1:299 I18=s1:190
'''
for item in fix.split():
 key,val=item.split('=',1)
 if key.startswith('RE'):card['events'][key[2:]]=val
 else:card['hexes'][key]=val
remaining=[(k,v) for kind in ('hexes','events') for k,v in card[kind].items() if v.startswith('?') or v=='']
if remaining:raise ValueError(f'Unreviewed cells remain: {remaining}')
assert len(card['hexes'])==475 and len(card['events'])==19
path=root/'data/mission_01.json';mission=json.loads(path.read_text());mission['conditions']['3']=card
path.write_text(json.dumps(mission,ensure_ascii=False,indent=2)+'\n')
print('Condition 3 reviewed:',len(card['hexes']),'hexes and',len(card['events']),'events')
