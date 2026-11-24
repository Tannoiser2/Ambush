import numpy as np, sys, json, cv2
from PIL import Image
from campiona import centro, COL
def maschere(img):
    hsv=cv2.cvtColor(img.astype(np.uint8),cv2.COLOR_RGB2HSV).astype(np.float32)
    H=hsv[...,0]*2; S=hsv[...,1]/255; V=hsv[...,2]/255
    blu=(H>=185)&(H<=225)&(S>0.35)&(V>0.35)
    verde=(H>=75)&(H<=165)&(S>0.28)&(V>0.18)
    grigio_chiaro=(S<0.16)&(V>0.68)
    grigio_strada=(S<0.2)&(V>0.45)&(V<=0.72)
    azz=(H>=180)&(H<=215)&(S>0.12)&(S<=0.45)&(V>0.6)
    g=cv2.cvtColor(img.astype(np.uint8),cv2.COLOR_RGB2GRAY).astype(np.float32)
    lap=np.abs(cv2.Laplacian(cv2.GaussianBlur(g,(0,0),1.0),cv2.CV_32F))
    return dict(H=H,S=S,V=V,blu=blu,verde=verde,gc=grigio_chiaro,gs=grigio_strada,azz=azz,lap=lap)
FONDI={'L1':(253,249,124),'L2':(252,220,97),'L3':(238,154,85),'L4':(140,135,95)}
def fondo(px):
    best=None
    for k,c in FONDI.items():
        d=np.linalg.norm(px-np.array(c),axis=1)
        n=(d<22).sum()
        if best is None or n>best[1]: best=(k,n)
    return best
def classifica(path, righe=range(1,20)):
    img=np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    M=maschere(img); out={}
    yy,xx=np.mgrid[-90:90,-90:90]; disc=np.hypot(xx,yy)<88; inner=np.hypot(xx,yy)<55
    for c in COL:
        for r in righe:
            h=f"{c}{r}"; cx,cy=centro(h); cx,cy=int(cx),int(cy)
            sl=(slice(cy-90,cy+90),slice(cx-90,cx+90))
            f={k:float(M[k][sl][disc].mean()) for k in ['blu','verde','gc','gs','azz']}
            f['blu_c']=float(M['blu'][sl][inner].mean()); f['gs_c']=float(M['gs'][sl][inner].mean())
            px=img[sl][disc]
            f['tex']=float(M['lap'][sl][disc].mean())
            fl=fondo(px); f['fondo']=fl[0]; f['fondo_n']=int(fl[1])
            # strisce (scogliera): molta tessitura su pixel arancio/rossi
            Hh=M['H'][sl][disc]; Ss=M['S'][sl][disc]; Vv=M['V'][sl][disc]
            f['rossi']=float(((Hh<28)&(Ss>0.45)&(Vv<0.9)&(Vv>0.4)).mean())
            f['scuri']=float((Vv<0.45).mean())
            out[h]=f
    return out
if __name__=="__main__":
    o=classifica(sys.argv[1]); json.dump(o,open(sys.argv[2],'w'))
    for h in sys.argv[3:]: print(h,{k:(round(v,2) if isinstance(v,float) else v) for k,v in o[h].items()})

def extra(path, out):
    img=np.asarray(Image.open(path).convert('RGB')).astype(np.float32)
    hsv=cv2.cvtColor(img.astype(np.uint8),cv2.COLOR_RGB2HSV).astype(np.float32)
    H=hsv[...,0]*2; S=hsv[...,1]/255; V=hsv[...,2]/255
    cesp=(H>=28)&(H<=62)&(S>0.45)&(V>0.25)&(V<0.68)
    crema=(V>0.93)&(S<0.22)
    g=cv2.cvtColor(img.astype(np.uint8),cv2.COLOR_RGB2GRAY).astype(np.float32)
    g=cv2.GaussianBlur(g,(0,0),1.5)
    gx=cv2.Sobel(g,cv2.CV_32F,1,0); gy=cv2.Sobel(g,cv2.CV_32F,0,1)
    yy,xx=np.mgrid[-90:90,-90:90]; disc=np.hypot(xx,yy)<80
    for h,f in out.items():
        cx,cy=centro(h); cx,cy=int(cx),int(cy); sl=(slice(cy-90,cy+90),slice(cx-90,cx+90))
        f['cesp']=float(cesp[sl][disc].mean()); f['crema']=float(crema[sl][disc].mean())
        a=gx[sl][disc]; b=gy[sl][disc]
        Jxx=(a*a).mean(); Jyy=(b*b).mean(); Jxy=(a*b).mean()
        tr=Jxx+Jyy; det=Jxx*Jyy-Jxy*Jxy; disc_=np.sqrt(max(tr*tr/4-det,0))
        l1=tr/2+disc_; l2=tr/2-disc_
        f['coer']=float((l1-l2)/(l1+l2+1e-6)); f['energia']=float(tr)
    return out
