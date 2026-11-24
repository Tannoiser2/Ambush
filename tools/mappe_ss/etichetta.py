import json, sys, numpy as np
from PIL import Image, ImageDraw, ImageFont
from campiona import centro, COL
def regole(f):
    q=int(f['fondo'][1])
    if f['blu']>0.75: return 'water',q
    if f['blu']>0.06: return 'stream',q
    if f.get('strada',0)>0.08: return 'road',q
    if f['verde']>0.2: return 'woods',q
    if f['coer']>0.5 and f['energia']>1200: return 'cliff',(3 if f['rossi']>0.25 else 2)
    if f['gc']>0.12: return 'boulder',q
    if f['crema']>0.02 or f['gc']>0.05: return 'crater',q
    if f['energia']>950 and f['coer']<0.35: return 'brush',q
    return 'clear',q
SIG={'water':'W','stream':'S','road':'R','woods':'B','cliff':'X','boulder':'M','crater':'C','brush':'c','clear':'.','stone_building':'P','wood_building':'L'}
def disegna(img_path, ter, out, box, scala=0.42):
    im=Image.open(img_path).convert('RGB').crop(box)
    im=im.resize((int(im.width*scala),int(im.height*scala)))
    d=ImageDraw.Draw(im)
    try: font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',22)
    except: font=None
    for h,(t,q) in ter.items():
        cx,cy=centro(h); x=(cx-box[0])*scala; y=(cy-box[1])*scala
        if 0<=x<im.width and 0<=y<im.height:
            s=f"{SIG.get(t,'?')}{q}"
            d.text((x-14,y-4),s,fill=(0,0,0),font=font,stroke_width=3,stroke_fill=(255,255,255))
    im.save(out)
if __name__=="__main__":
    feat=json.load(open(sys.argv[1])); ter={h:regole(f) for h,f in feat.items()}
    json.dump({h:{'t':t,'q':q} for h,(t,q) in ter.items()},open(sys.argv[2],'w'),indent=0)
    for i,box in enumerate([(0,0,2200,1950),(2000,0,4200,1950),(0,1850,2200,3840),(2000,1850,4200,3840)]):
        disegna(sys.argv[3],ter,f'{sys.argv[4]}_{i}.png',box,0.62)
