#!/usr/bin/env python3
"""Generate review candidates from base mission condition cards; not runtime content."""
import csv, io, json, pathlib, re, subprocess
from PIL import Image
root=pathlib.Path(__file__).resolve().parents[1]
out={}
mask=[0,7,14,1,8,15,2,9,16,3,10,17,4,11,18,5,12,19,6,13]
for condition in range(1,5):
 path=root/f'assets/reference/m1_c{condition}.png'
 image=Image.open(path).convert('RGB');scale=image.width/1635.0
 if scale>1.5:
  image=image.resize((1635,round(image.height/scale)));scale=1.0
  path=root/'tmp'/f'm1_c{condition}_ocr.png';path.parent.mkdir(exist_ok=True);image.save(path)
 proc=subprocess.run(['tesseract',str(path),'stdout','--psm','6','tsv'],capture_output=True,text=True,check=True)
 cells=[[[] for _ in range(26)] for _ in range(20)]
 for word in csv.DictReader(io.StringIO(proc.stdout),delimiter='\t'):
  token=word.get('text','').strip()
  if not token:continue
  x=float(word['left'])+float(word['width'])/2;y=float(word['top'])+float(word['height'])/2
  col=round((x-109)/56.4)
  if col<0 or col>25:continue
  row=round((y-(73 if y<585 else 666))/47.0)+(0 if y<585 else 10)
  if row<0 or row>19:continue
  cells[row][col].append(token)
 def clean(parts):
  value=' '.join(parts).upper().strip('.,:;°©«~\\')
  value=re.sub(r'\s+',' ',value)
  value=value.replace('N0NE','NONE').replace('NQNE','NONE').replace('EVEN T','EVENT')
  if value in ('NONE','EVENT') or re.fullmatch(r'\d{3}',value):return value
  sight=re.fullmatch(r'S\s*([0-9])\s*(\d{3})',value)
  return 's'+sight[1]+':'+sight[2] if sight else '?'+value
 table={f'{chr(65+c)}{n}':clean(cells[mask[n]][c]) for c in range(25) for n in range(1,20)}
 events={str(n):clean(cells[mask[n]][25]) for n in range(19)}
 out[str(condition)]={'status':'ocr_candidate_not_reviewed','hexes':table,'events':events,'uncertain':sum(v.startswith('?') or v=='' for v in [*table.values(),*events.values()])}
 print('condition',condition,'uncertain',out[str(condition)]['uncertain'])
(root/'data/source/condition_candidates.json').write_text(json.dumps(out,indent=2,ensure_ascii=False)+'\n')
