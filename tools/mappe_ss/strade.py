import numpy as np, cv2, json, sys
from PIL import Image
from campiona import centro, COL
def strade(path, largo=False):
    img=np.asarray(Image.open(path).convert('RGB')).astype(np.int16)
    R,G,B=img[...,0],img[...,1],img[...,2]
    mx=img.max(2); mn=img.min(2)
    m=(((mx-mn)<50)&(B>=R-12)&(mx>110)&(mx<215)) if largo else (((mx-mn)<45)&(B>=R)&(mx>120)&(mx<200))
    m=m.astype(np.uint8)
    m=cv2.morphologyEx(m,cv2.MORPH_CLOSE,np.ones((9,9),np.uint8)); m=cv2.morphologyEx(m,cv2.MORPH_OPEN,np.ones((7,7),np.uint8))
    n,lab,st,_=cv2.connectedComponentsWithStats(m)
    keep=np.zeros_like(m)
    for i in range(1,n):
        x,y,w,h,a=st[i]
        if a>8000 and max(w,h)>350: keep[lab==i]=1
    return keep
if __name__=="__main__":
    k=strade(sys.argv[1], len(sys.argv)>4); cv2.imwrite(sys.argv[2],k*255)
    feat=json.load(open(sys.argv[3]))
    yy,xx=np.mgrid[-90:90,-90:90]; disc=np.hypot(xx,yy)<70
    for h,f in feat.items():
        cx,cy=centro(h); cx,cy=int(cx),int(cy)
        f['strada']=float(k[cy-90:cy+90,cx-90:cx+90][disc].mean())
    json.dump(feat,open(sys.argv[3],'w'))
    print(sorted([h for h,f in feat.items() if f['strada']>0.08]))
