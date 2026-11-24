from campiona import centro, COL
BOX=[(0,0),(2000,0),(0,1850),(2000,1850)]
def hex_di(i,x,y,s=0.62):
    X=BOX[i][0]+x/s; Y=BOX[i][1]+y/s
    return min(((X-centro(f"{c}{r}")[0])**2+(Y-centro(f"{c}{r}")[1])**2,f"{c}{r}") for c in COL for r in range(1,20))[1]
