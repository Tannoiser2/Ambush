#!/usr/bin/env python3
"""Mission 1/condition 4: reviewed black operations references.
Red hex-coded Round references are deliberately kept separate for later rules work.
"""
import json,pathlib
root=pathlib.Path(__file__).resolve().parents[1]
source=json.loads((root/'data/source/condition_candidates.json').read_text())['4']
card={'status':'black_references_transcribed_visual_review','source':'m1_c4.png + sleeve.png','hexes':source['hexes'].copy(),'events':source['events'].copy()}
fix='''
M1=s6:290 R2=s8:604 S3=s8:604 T3=s8:604
N4=s6:318 O4=EVENT Q4=s2:335 U4=NONE V4=EVENT RE4=s0:613
M5=NONE N5=EVENT P5=s6:290 W5=NONE X5=EVENT
O6=s2:335 P6=s6:290 U6=s8:339 W6=s8:339 X6=NONE
B7=NONE D7=s2:311 E7=EVENT F7=EVENT G7=s2:335 H7=s2:335 J7=s2:335 L7=s2:182 M7=EVENT N7=608 O7=s2:335 P7=s2:335 Q7=s2:335 X7=EVENT Y7=NONE RE7=s5:611
E8=s1:325 F8=s2:311 O8=s2:335 P8=s6:290
F9=s3:600 N9=NONE O9=s2:295 P9=s2:196 R9=s2:335 T9=EVENT
A10=EVENT B10=NONE C10=NONE D10=NONE E10=s1:190 F10=s3:600 G10=s3:328 H10=s3:600 I10=s1:190 J10=s2:335 K10=s1:299 L10=s1:299 M10=s1:186 N10=s1:186 O10=EVENT P10=s2:295 Q10=s2:295 R10=s2:607 S10=s2:607 T10=NONE U10=NONE W10=NONE X10=EVENT RE10=451
M11=s1:299
K13=NONE L13=s1:179
L14=EVENT M14=NONE N14=NONE RE14=s0:613
E15=s1:186 M15=NONE N15=EVENT O15=NONE RE15=s0:613
F16=s1:190 N16=EVENT O16=EVENT P16=NONE
N17=EVENT Q17=EVENT
I18=s1:190 N18=NONE Q18=NONE
N19=NONE Q19=NONE
'''
for item in fix.split():
 key,val=item.split('=',1)
 if key.startswith('RE'):card['events'][key[2:]]=val
 else:card['hexes'][key]=val
remaining=[(kind,k,v) for kind in ('hexes','events') for k,v in card[kind].items() if v.startswith('?') or v=='']
if remaining:raise ValueError(f'Unreviewed cells: {remaining}')
assert len(card['hexes'])==475 and len(card['events'])==19
# Red entries are German Movement References (rules 2/2 and 6/8), not
# Operations paragraph checks. The base card leaves all other slots blank.
red='''
S3=T3 T3=U4 O6=O7 X6=457 N9=O10 P9=P9 Q9=Q10 U9=616
M15=N15 N15=O16 O15=O16 N18=N19 Q18=Q19
N4=N5 O4=N4 U4=V4 W4=W5
M7=N7 N7=O8 O7=O8 X7=Y7 Y7=EXIT
M10=N9 O10=P10 P10=352 R10=R10 S10=S10 T10=T9
K13=L13 L13=614 N16=N17 O16=350 P16=O17
N19=EXIT Q19=EXIT R2=S3 M5=N5 N5=O6 W5=X5 X5=X6
O8=O9 M11=M15 N11=N14 O11=O15 N14=N18 Q14=Q18
'''
card['round_overrides']={a:b for a,b in (item.split('=',1) for item in red.split())}
assert len(card['round_overrides'])==46
card['round_overrides_status']='transcribed_visual_review_not_yet_used'
path=root/'data/mission_01.json';mission=json.loads(path.read_text());mission['conditions']['4']=card
path.write_text(json.dumps(mission,ensure_ascii=False,indent=2)+'\n')
print('Condition 4 reviewed:',len(card['hexes']),'black hex references and',len(card['events']),'events')
