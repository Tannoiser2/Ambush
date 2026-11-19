import json,sys,glob,os,difflib,re
COL="ABCDEFGHIJKLMNOPQRSTUVWXY"
def da(q,r):
    if 0<=q<25 and 1<=r<=19: return f"{COL[q]}{r}"
    return None
def vicini(h):
    q=COL.index(h[0]); r=int(h[1:])
    pari=[(0,-1),(1,-1),(1,0),(0,1),(-1,0),(-1,-1)]; dis=[(0,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0)]
    return [x for x in (da(q+dx,r+dy) for dx,dy in (dis if q&1 else pari)) if x]
CL={}
for g in ["0OQDU","8SB5$","6G","1ITJLti!l|","2Z","4A","7"]:
    for c in g: CL[c]=g[0]
def can(s): return "".join(CL.get(c,c) for c in s.replace(" ","").replace("-",""))
def risolvi(h, letture, lettera=None):
    cand={f"{v[0]}-{v[1:]}":v for v in vicini(h)}
    if lettera:
        c2={s:v for s,v in cand.items() if v[0]==lettera}
        if c2: cand=c2
    pts={}
    for l in letture:
        if not l: continue
        if re.search(r"[Ee][Xx]|xit",l): pts["USCITA"]=pts.get("USCITA",0)+2; continue
        if re.fullmatch(r"\d{3}",l.strip()): pts[l.strip()]=pts.get(l.strip(),0)+1.5
        for s,v in cand.items():
            sc=difflib.SequenceMatcher(None,can(l),can(s)).ratio()
            if l.replace(" ","")==s: sc+=0.5
            pts[v]=pts.get(v,0)+sc
    if not pts: return None,0
    o=sorted(pts.items(),key=lambda x:-x[1])
    marg=o[0][1]-(o[1][1] if len(o)>1 else 0)
    return o[0][0],marg
if __name__=="__main__":
    for f in sorted(glob.glob('/home/claude/carte/m[2-8]_c*.json')):
        n=os.path.basename(f); a=json.load(open(f)); b=json.load(open('/home/claude/carte2/'+n))
        dub=[]
        for k in a:
            if k.startswith('_'): continue
            r,c=k.split('|')
            if c=='RE' or r=='0': 
                if a[k].get('rosso'): dub.append((k,'rosso fuori griglia',a[k].get('rosso')))
                continue
            ls=[a[k].get('rosso'),b[k].get('rosso')]
            if not any(ls): continue
            ll=(a[k].get('rosso_l') or '').strip()
            v,m=risolvi(f"{c}{r}",ls,ll[0] if ll[:1].isalpha() else None)
            if m<0.35: dub.append((k,ls,v,round(m,2)))
        print(n,len(dub),dub[:10])
