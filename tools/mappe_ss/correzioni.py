COR_F={'S12':('clear',1),'R12':('clear',1),'T14':('clear',1),'W14':('clear',1),'V15':('clear',1),'U16':('clear',1),'P16':('clear',1),
 'M16':('crater',1),'X15':('crater',1),'S17':('crater',1),'T17':('crater',1),'N19':('crater',4),'O19':('crater',4),'R19':('crater',4),
 'A6':('woods',2),'B5':('woods',2),'E3':('crater',2),'G3':('crater',2)}
COR_F.update({'P4':('clear',2),'R4':('crater',1),'T2':('woods',3),'U1':('boulder',4),'T1':('boulder',4),'Y1':('crater',3),'W2':('crater',3),'X3':('crater',3),'U9':('crater',2)})
COR_H={'A1':('water',1),'C4':('water',1),'B1':('water',1),'I2':('water',1),'B3':('clear',2),'B4':('clear',2),'B5':('clear',2),'B6':('clear',2),'B7':('clear',2),'B8':('clear',2)}
COR_H['I10']=('clear',2)
COR_H.update({'V2':('road',2),'W3':('road',2),'X3':('road',2),'Y6':('stream',3),'N9':('clear',2),'Q3':('crater',1),'R2':('crater',1),'S2':('crater',1),'T1':('crater',1),'S4':('crater',2),'Q6':('crater',2),'R6':('crater',3),'U10':('crater',2)})
for h,q in {'M12':2,'S12':2,'T11':2,'Y14':2,'X14':2,'W15':2,'Y16':2,'P16':2,'Q17':3,'O18':2,'N19':2,'A13':3,'C14':3,'E12':3,'H13':3,'H16':3,'B14':2,'F11':2,'F10':2}.items():
    COR_G[h]=('crater',q)
