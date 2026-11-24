import numpy as np, sys
from PIL import Image
SCALA=0.6; ORIG=(307*SCALA,272*SCALA); PASSO=(270.8*SCALA,314*SCALA)
COL="ABCDEFGHIJKLMNOPQRSTUVWXY"
def centro(h):
    c=COL.index(h[0]); r=int(h[1:])
    return ORIG[0]+c*PASSO[0], ORIG[1]+(r-1)*PASSO[1]+(PASSO[1]/2 if c&1 else 0)
def dati(img,h,r0=0,r1=88):
    cx,cy=centro(h); a=img[int(cy)-r1:int(cy)+r1, int(cx)-r1:int(cx)+r1].reshape(-1,3)
    yy,xx=np.mgrid[-r1:r1,-r1:r1]; d=np.hypot(xx,yy).reshape(-1)
    return a[(d>=r0)&(d<r1)]
if __name__=="__main__":
    img=np.asarray(Image.open(sys.argv[1]).convert('RGB')).astype(int)
    for h in sys.argv[2:]:
        p=dati(img,h); print(h, np.median(p,0), np.percentile(p,25,0).astype(int), np.percentile(p,75,0).astype(int))
