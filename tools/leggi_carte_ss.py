import json, re
D=json.load(open('testi.json'))
ARMI=[('Bolt Rifle (Scope)','scoped'),('Bolt Rifle w/Scope','scoped'),('Scoped','scoped'),('Bolt Rifle','bolt'),('Semi-Automatic Rifle','sar'),('Semi-auto','sar'),('Submachine Gun','mp'),('Machine Pistol','mp'),('Clip-fed LMG','lmg'),('LMG','lmg'),('MMG','mmg'),('Panzerfaust','panzerfaust'),('Pistol','pistol'),('Carbine','carbine'),('Flamethrower','flamethrower'),('Mortar','mortar')]
def norm_col(t):
    t=t.replace('$','S').replace('™','').replace('§','S').replace('|','1').replace('l','1')
    t=re.sub(r'^(\d)(\d)$',r'\1-\2',t)
    return t
out={}; dubbi=[]
for x in D:
    t=x['testo']; L=[l for l in t.splitlines() if l.strip()]
    if not L: dubbi.append((x['foglio'],x['i'],'vuota')); continue
    m=re.search(r'(GE|US)\s*0?(\d+)(?:\s*-\s*(\d+))?(?:/\s*(\w+))?\s*(.*)',L[0])
    if not m: dubbi.append((x['i'],'intest',L[0])); continue
    lato,num,num2,lett,ruolo=m.group(1),int(m.group(2)),m.group(3),(m.group(4) or ''),m.group(5).strip()
    key=f"{lato}{num}"+(f"-{num2}" if num2 else '')
    rec={'lato':lato,'num':num,'lettera':lett,'ruolo':ruolo,'foglio':x['foglio'],'indice':x['i'],'testo':t}
    if num2: rec['fino_a']=int(num2)
    st=re.search(r'IN[:;]?\s*(-?\d+)\W+PC[:;]?\s*(-?\d+)\W+WS[:;]?\s*([+-—–]*\s*\d+)\W+\w*DS[:;]?\s*(\d+)\W+MPA[:;]?\s*(\d+)',t)
    if st:
        ws=st.group(3).replace('—','-').replace('–','-').replace(' ','')
        ws=re.sub(r'^[-]+','-',ws)
        rec.update(IN=int(st.group(1)),PC=int(st.group(2)),WS=int(ws),DS=int(st.group(4)),MPA=int(st.group(5)))
    else: dubbi.append((key,'stat'))
    vp=re.search(r'\+\s*(\d)\s*VP',t); rec['pv']=int(vp.group(1)) if vp else 0
    vc=re.search(r'\+\s*(\d)\s*VP if captured',t); 
    if vc: rec['pv_cattura']=int(vc.group(1))
    ai=[i for i,l in enumerate(L) if 'MPA' in l]
    riga_armi=L[ai[0]+1] if ai and ai[0]+1<len(L) else ''
    rec['armi_testo']=riga_armi
    armi=[]; resto=riga_armi
    for k,v in ARMI:
        if k.lower() in resto.lower():
            if v not in armi: armi.append(v)
            resto=re.sub(re.escape(k),'',resto,flags=re.I)
    rec['armi']=armi
    g=re.search(r'(\d)\s*Grenades',riga_armi); rec['granate']=int(g.group(1)) if g else (1 if 'Grenade' in riga_armi else 0)
    hdr=[i for i,l in enumerate(L) if re.match(r'\s*DIE\b',l)]
    righe=[]
    if hdr:
        cols=[norm_col(c) for c in L[hdr[0]].split()[1:]]
        for l in L[hdr[0]+1:hdr[0]+8]:
            l2=l.replace('.',' ').replace(',',' ')
            p=l2.split()
            if not p: continue
            g0=p[0].replace('·','-').replace('—','-').replace('–','-')
            g0=re.sub(r'^(\d)(\d)$',r'\1-\2',g0)
            if re.match(r'^\d(-\d)?$',g0):
                nums=[re.sub(r'\D','',z) for z in p[1:]]
                nums=[int(z) for z in nums if len(z)==3]
                righe.append((g0,nums))
        n=max([len(r[1]) for r in righe],default=0)
        if len(cols)!=n or any(len(r[1])!=n for r in righe): dubbi.append((key,'colonne',cols,[r[1] for r in righe]))
        rec['gruppi']=[[int(r[0][0]),int(r[0][-1])] for r in righe]
        rec['colonne']={(cols[j] if j<len(cols) else f'?{j}'):[r[1][j] if j<len(r[1]) else None for r in righe] for j in range(n)}
        cop=sorted(v for a,b in rec['gruppi'] for v in range(a,b+1))
        if cop!=list(range(10)): dubbi.append((key,'gruppi',rec['gruppi']))
        tail=L[hdr[0]+1+len(righe):]
        rec['note']=' '.join(tail).strip()
    else: dubbi.append((key,'tabella'))
    if key in out: dubbi.append(('dup',key))
    out[key]=rec
json.dump(out,open('carte_ss_grezze.json','w'),indent=1,ensure_ascii=False)
print(len(out), sorted(out, key=lambda k:(k[:2],int(re.sub(r'\D.*','',k[2:]) or 0))))
for d in dubbi: print(d)
