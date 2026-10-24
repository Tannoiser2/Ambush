#!/usr/bin/env python3
"""Import only base-game sources from the user's TTS backup; never execute Lua."""
import argparse, collections, hashlib, json, pathlib, re, zipfile
import fitz
ROOT = pathlib.Path(__file__).resolve().parents[1]
def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')
def walk(obj):
    if isinstance(obj, dict):
        yield obj
        for v in obj.values(): yield from walk(v)
    elif isinstance(obj, list):
        for v in obj: yield from walk(v)
def main():
    parser=argparse.ArgumentParser(); parser.add_argument('archive',type=pathlib.Path); args=parser.parse_args()
    with zipfile.ZipFile(args.archive) as z:
        source=json.loads(z.read('Mods/Workshop/3099626094.json'))
        objects=list(walk(source)); entries=z.namelist(); inventory=[]
        targets={'Map A':'assets/maps/map_a','Map B':'assets/maps/map_b','Demonstration Squad':'assets/reference/squad','Mission Sleeve Viewer':'assets/reference/sleeve'}
        for mission in range(1,9):
            for condition in range(1,7):targets[f'Mission {mission} - Condition {condition}']=f'assets/reference/m{mission}_c{condition}'
        for o in objects:
            name=o.get('Nickname','')
            if name in targets:
                url=o.get('CustomImage',{}).get('ImageURL','') or o.get('CustomMesh',{}).get('DiffuseURL','')
                h=url.rstrip('/').split('/')[-1]
                matches=[n for n in entries if h and h in n]
                if not matches: raise ValueError(f'Missing asset: {name}')
                entry=matches[0]; raw=z.read(entry); path=ROOT/(targets[name]+'.'+entry.rsplit('.',1)[-1].lower())
                path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
                inventory.append({'name':name,'path':str(path.relative_to(ROOT)),'source':entry,'sha256':hashlib.sha256(raw).hexdigest()})
        for key,label in [('1187209805474697151','rules'),('1187209343569221100','paragraphs')]:
            entry=next(n for n in entries if key in n and n.lower().endswith('.pdf'));raw=z.read(entry)
            doc=fitz.open(stream=raw,filetype='pdf');pages=[]
            for i,p in enumerate(doc):pages.append({'page':i+1,'text':p.get_text()})
            write(ROOT/f'data/source/{label}_pages.json',{'status':'unreviewed_ocr','source':entry,'sha256':hashlib.sha256(raw).hexdigest(),'pages':pages})
            if label=='paragraphs':
                # Preserve OCR and page provenance. No silent repairs, no invented IDs.
                records={}; duplicates=[]
                for page in pages:
                    t=page['text']; matches=list(re.finditer(r'(?m)^([0-9][0-9 ]{1,3})\.[ \t]*',t))
                    for j,m in enumerate(matches):
                        pid=m[1].replace(' ','')
                        if len(pid)!=3:continue
                        record={'id':pid,'page':page['page'],'status':'unreviewed_ocr','en':t[m.end():matches[j+1].start() if j+1<len(matches) else len(t)].strip()}
                        if pid in records:duplicates.append(pid)
                        else:records[pid]=record
                write(ROOT/'data/source/paragraphs_en.json',{'records':records,'duplicate_ids':duplicates,'notice':'OCR candidates only; gaps in original numbering are intentional. Verify columns, numbers and references against scan.'})
        write(ROOT/'data/source/inventory.json',{'archive':args.archive.name,'archive_bytes':args.archive.stat().st_size,'entry_count':len(entries),'assets':inventory})
        print(f'Imported {len(inventory)} assets and base source text. OCR candidates: {len(records)}; duplicates: {duplicates}')
if __name__=='__main__':main()
