import json, sys
from etichetta import regole, disegna
from campiona import COL
sys.path.insert(0,'/home/claude/repos/Ambush/tools')
from costruisci_mappe_ph import vicini
def base(feat):
    T={h:list(regole(f)) for h,f in feat.items()}
    # strade: livello dei vicini non stradali
    for h,(t,q) in T.items():
        if t=='road':
            qs=[T[v][1] for v in vicini(h) if T[v][0] not in ('road','water','stream','cliff')]
            if qs: T[h][1]=max(set(qs),key=qs.count)
    return T
EDF={'stone_building':['O14','R13','S13','T12','V13','V14','U15','T15','P15','Q16'],'wood_building':['U13']}
EDH={'stone_building':['C9','D9','I9','J9','M9','N8','P5','P7'],'wood_building':[]}
def applica(T,ed,cor):
    for t,hs in ed.items():
        for h in hs: T[h]=[t,T[h][1] if T[h][0] not in ('road','cliff') else 1]
    for h,v in cor.items(): T[h]=list(v)
    return T
def in_h(h):
    c=COL.index(h[0]); r=int(h[1:]); return r<=9 or (r==10 and c%2==0)
COR_F={}; COR_H={}; COR_G={}
try:
    exec(open('correzioni.py').read())
except FileNotFoundError: pass
if __name__=="__main__":
    F=applica(base(json.load(open('f_feat.json'))),EDF,COR_F)
    H=applica(base(json.load(open('tts_fg_feat.json'))),EDH,COR_H)
    G=applica(base(json.load(open('tts_fh_feat.json'))),{},COR_G)
    H={h:v for h,v in H.items() if in_h(h)}; G={h:v for h,v in G.items() if not in_h(h)}
    json.dump({'F':F,'H':H,'G':G},open('terreni.json','w'))
    if len(sys.argv)>1:
        boxes=[(0,0,2200,1950),(2000,0,4200,1950),(0,1850,2200,3840),(2000,1850,4200,3840)]
        T={h:tuple(v) for h,v in F.items()}
        for i,b in enumerate(boxes): disegna('f_4200.jpg',T,f'fin_f_{i}.png',b,0.62)
        T={h:tuple(v) for h,v in H.items()}
        for i,b in enumerate(boxes[:2]): disegna('tts_fg_4200.jpg',T,f'fin_h_{i}.png',b,0.62)
        T={h:tuple(v) for h,v in G.items()}
        for i,b in enumerate(boxes[2:]): disegna('tts_fh_4200.jpg',T,f'fin_g_{i}.png',b,0.62)
