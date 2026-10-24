#!/usr/bin/env python3
"""Reviewed transcription for mission 1 / condition 1. No OCR used at runtime."""
import json,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
def dump(name,d): (ROOT/'data'/name).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
# Physical row order, A..Y, then RE. Sighting references use sN:paragraph.
rows='''
NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE 012
NONE EVENT EVENT 315 311 024 311 295 295 024 326 318 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
024 024 NONE 329 329 311 330 185 330 182 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
024 325 325 325 NONE s3:600 184 184 185 295 182 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE 026
325 325 024 EVENT EVENT 186 186 179 179 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
325 325 325 NONE 186 299 190 190 179 179 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
024 EVENT NONE 024 325 325 325 325 190 299 179 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
EVENT NONE NONE 315 311 311 311 024 NONE 326 290 189 189 318 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
NONE NONE EVENT 315 311 311 335 335 335 335 025 317 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
EVENT NONE 325 311 329 329 330 330 330 182 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
325 024 325 325 181 s3:600 s3:328 s3:600 181 179 179 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE s9:348
024 325 325 EVENT 186 190 190 179 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
325 024 EVENT EVENT 186 190 190 190 299 190 179 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE s9:453
325 EVENT 025 325 325 325 325 325 325 325 179 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
EVENT EVENT NONE 315 311 311 024 311 EVENT 025 290 318 318 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE 011
EVENT NONE NONE 329 311 329 335 330 295 296 182 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
325 325 EVENT EVENT 311 311 185 185 330 182 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE s9:348
325 325 325 325 181 EVENT 191 179 s4:292 179 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE 029
325 024 325 NONE 186 190 299 179 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
325 NONE NONE 025 325 325 299 299 190 190 179 NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE NONE
'''.strip().splitlines()
rows=[r.split() for r in rows]; assert all(len(r)==26 for r in rows)
# Mask apertures 0..19. The first hex is row 1; RE uses sums 0..18.
mask=[0,7,14,1,8,15,2,9,16,3,10,17,4,11,18,5,12,19,6,13]
hexes={f'{chr(65+c)}{n}':rows[mask[n]][c] for c in range(25) for n in range(1,20)}
events={str(n):rows[mask[n]][25] for n in range(19)}
squad=[]
for id,name,ini,pc,ws,ds,cmd,weapon,extra,clips,grenades in [
 ('A','Alex',4,6,2,2,True,'Fucile automatico','',5,1),('B','Bradley',3,5,0,4,False,'Carabina','',5,1),('C','Charles',3,4,0,4,False,'Carabina','Bazooka · 2 razzi',3,1),('D','David',2,4,0,6,False,'Carabina','',5,1),('E','Encio',2,3,-1,4,False,'Fucile semiautomatico','',5,1),('F','Frankie',2,5,0,6,False,'Fucile semiautomatico','Carica esplosiva',3,3),('G','Gerald',2,3,1,4,False,'Fucile automatico','',5,1),('H','Harold',2,3,1,6,False,'Fucile semiautomatico','Carica esplosiva',4,2)]:
 squad.append(dict(id=id,name=name,initiative=ini,pc=pc,ws=ws,driving=ds,commander=cmd,weapon=weapon,extra=extra,clips=clips,grenades=grenades,mp=4,hex='',stance='standing',status='active'))
dump('mission_01.json',dict(id='base_01',title='Sangue a Saint-Michaux',original_title='Bloody St. Mick',date='Normandia · fine giugno 1944',map='A',briefing='La divisione avanza con cautela tra i bocage della Normandia. Questa mattina una squadra è stata respinta dal fuoco di tiratori tedeschi nascosti. Ora tocca ai tuoi uomini: prendete il controllo della strada di Saint-Michaux, collegamento tra le forze britanniche a est e quelle americane a ovest.',entry='A1–J1, sul margine nord',victory_points=13,activation_levels=[1,3,5,8],squad=squad,conditions={'1':{'hexes':hexes,'events':events,'status':'transcribed_visual_review','source':'m1_c1.png + sleeve.png'}},scope='Operations pilot. Combat and conditions 2–4 are gated, never approximated.'))
P={}
def add(id,text,ops=None,page=8):
 P[id]={'id':id,'it':text,'ops':ops or [],'source':{'book':'Ambush! Paragraph Book','page':page},'status':'reviewed_translation'}
def go(id):return {'op':'goto','id':id}
def check(kind,mod,yes,no=None):return {'op':'check','kind':kind,'modifier':mod,'success':yes,'failure':no or []}
def pc(mod,id,no=None):return check('pc',mod,[go(id)],no)
def act(mod,id,no=None):return check('activation',mod,[go(id)],no)
def dice(branches):return {'op':'die','branches':[{'min':a,'max':b,'ops':ops} for a,b,ops in branches]}
def sight(id,yes,no=None):return {'op':'if','condition':{'kind':'sighting','id':id},'yes':yes,'no':no or []}
marker={'op':'event_marker'}
def block(reason):return {'op':'unsupported','reason':reason}
add('007','Deve essere stato il vento.',page=2)
add('010','Falso allarme.',page=2)
add('013','È soltanto la tua immaginazione.',page=2)
add('024','Colloca un segnalino Evento. Effettua un controllo di percezione (−1). Se riesce, leggi il paragrafo 013.',[marker,pc(-1,'013')],2)
add('025','Colloca un segnalino Evento. Effettua un controllo di percezione (−1). Se riesce, leggi il paragrafo 007.',[marker,pc(-1,'007')],2)
for id,scope in [('020','Fucile a otturatore'),('023','Fucile a otturatore con mirino telescopico')]:
 add(id,f'Un soldato subisce il fuoco di un tiratore nascosto. Non iniziano i Round. Risolvi un tiro mirato a corta distanza: {scope.lower()}, abilità di tiro 0.',[block('Fuoco da tiratore nascosto: tabella armi, modificatori del terreno e danni ancora da verificare.')],2)
add('011','Possibile colpo di artiglieria casuale. Per ciascuna coppia di dadi, la cifra minore indica le decine. Il primo risultato deve essere al massimo 25, il secondo al massimo 19: i due risultati determinano colonna e riga colpite. Altrimenti il colpo cade fuori mappa. Nell’esagono colpito tutti i soldati muoiono e i veicoli sono distrutti; colloca un cratere, oppure macerie se contiene un edificio.',[{'op':'artillery'}],2)
add('012','Se un soldato americano porta granate, una esplode accidentalmente. Scegli casualmente il portatore: solo lui effettua un controllo di percezione. Se riesce può lanciarla in un esagono adiacente libero; altrimenti l’esplosione colpisce tutti nel suo esagono e il portatore è considerato al chiuso.',[block('Granata difettosa: danni e scelta di un esagono adiacente libero da implementare.')],2)
add('026','Il soldato con la percezione più alta tra quelli che possono vedere U9 effettua un controllo di percezione. Se riesce, leggi 007.',[block('Serve la linea di vista verificata verso U9.')],2)
add('029','Se questo evento è stato provocato dall’ingresso in un bosco o in terreno accidentato, il soldato ha spaventato degli uccelli che si alzano in volo.',[block('Serve la classificazione verificata del terreno per questo evento.')],2)
add('179','Controllo di attivazione (+2). Se riesce, leggi 288; altrimenti leggi 310.',[act(2,'288',[go('310')])],5)
add('181','Tira un dado. 0–5: controllo di attivazione (+3), se riesce leggi 020. 6–8: nessun effetto. 9: controllo di percezione (−1), se riesce leggi 289.',[dice([(0,5,[act(3,'020')]),(6,8,[]),(9,9,[pc(-1,'289')])])],6)
add('182','Controllo di attivazione (+1). Se riesce, leggi 291; altrimenti leggi 313.',[act(1,'291',[go('313')])],6)
add('184','Tira un dado. 0–4: se s2 non è avvenuto, controllo di attivazione (+3), se riesce leggi 020. 5–8: se s3 non è avvenuto, controllo di percezione; se riesce leggi 293. 9: se s2 non è avvenuto, controllo di percezione; se riesce leggi 289.',[dice([(0,4,[sight('s2',[],[act(3,'020')])]),(5,8,[sight('s3',[],[pc(0,'293')])]),(9,9,[sight('s2',[],[pc(0,'289')])])])],6)
add('185','Controllo di attivazione (+1). Se riesce, leggi 294. Altrimenti effettua un controllo di percezione: se riesce, leggi 316.',[act(1,'294',[pc(0,'316')])],6)
add('186','Tira un dado. 0–2: controllo di attivazione, se riesce leggi 288. 3–8: nessun effetto. 9: controllo di percezione (−1), se riesce leggi 289.',[dice([(0,2,[act(0,'288')]),(3,8,[]),(9,9,[pc(-1,'289')])])],6)
add('188','Controllo di percezione. Se riesce, leggi 333; altrimenti leggi 297.',[pc(0,'333',[go('297')])],6)
add('189','Controllo di attivazione (+2). Se riesce, leggi 334. Altrimenti controllo di percezione (−2): se riesce, leggi 298.',[act(2,'334',[pc(-2,'298')])],6)
add('190','Controllo di attivazione (+2). Se riesce, leggi 324. Altrimenti controllo di percezione (−2): se riesce, leggi 289.',[act(2,'324',[pc(-2,'289')])],6)
add('191','Tira un dado. 0–3: controllo di attivazione, se riesce leggi 288. 4–8: se s3 non è avvenuto, controllo di percezione (−1), se riesce leggi 293. 9: controllo di percezione, se riesce leggi 289.',[dice([(0,3,[act(0,'288')]),(4,8,[sight('s3',[],[pc(-1,'293')])]),(9,9,[pc(0,'289')])])],6)
add('288','Controllo di percezione (−2). Se riesce, leggi 324; altrimenti leggi 180.',[pc(-2,'324',[go('180')])],7)
add('290','Controllo di attivazione (+2). Se riesce, leggi 297. Altrimenti controllo di percezione (−2): se riesce, leggi 333.',[act(2,'297',[pc(-2,'333')])],7)
add('291','Controllo di percezione (−2). Se riesce, leggi 321; altrimenti leggi 183.',[pc(-2,'321',[go('183')])])
add('292','Se s3 è avvenuto, leggi 314. Altrimenti colloca un segnalino Evento ed effettua un controllo di percezione (−1): se riesce, leggi 314.',[sight('s3',[go('314')],[marker,pc(-1,'314')])])
add('293','Il soldato nota una figura in uniforme da combattimento americana distesa accanto a un albero nell’esagono G10.')
add('295','Controllo di attivazione (+1). Se riesce, leggi 183. Altrimenti controllo di percezione (−2): se riesce, leggi 312.',[act(1,'183',[pc(-2,'312')])])
add('296','Se s5 è avvenuto, leggi 182. Altrimenti effettua un controllo di attivazione: se riesce leggi 294, se fallisce leggi 316.',[sight('s5',[go('182')],[act(0,'294',[go('316')])])])
add('299','Tira un dado. 0–3: controllo di attivazione (+1), se riesce leggi 288. 4–8: nessun effetto. 9: controllo di percezione, se riesce leggi 289.',[dice([(0,3,[act(1,'288')]),(4,8,[]),(9,9,[pc(0,'289')])])])
add('310','Controllo di percezione. Se riesce, leggi 289; altrimenti leggi 324.',[pc(0,'289',[go('324')])])
add('311','Tira un dado. 0–3: controllo di attivazione (+2), se riesce leggi 023. 4–8: nessun effetto. 9: controllo di percezione (−1), se riesce leggi 312.',[dice([(0,3,[act(2,'023')]),(4,8,[]),(9,9,[pc(-1,'312')])])])
add('313','Controllo di percezione. Se riesce, leggi 312; altrimenti leggi 327.',[pc(0,'312',[go('327')])])
add('314','[s4] Il soldato nota un riflesso metallico e trova in questo esagono un mitra intatto, senza munizioni.',[{'op':'sighting','id':'s4'},{'op':'item','item':'Mitra senza munizioni'}])
add('315','Tira un dado. 0–8: nessun effetto, colloca un segnalino Evento. 9: controllo di percezione (−2), se riesce leggi 312.',[dice([(0,8,[marker]),(9,9,[pc(-2,'312')])])])
add('317','Controllo di attivazione (+1). Se riesce, leggi 331; altrimenti leggi 187.',[act(1,'331',[go('187')])])
add('318','Controllo di attivazione (+1). Se riesce, leggi 332; altrimenti leggi 188.',[act(1,'332',[go('188')])])
add('321','Il soldato con la percezione più alta tra quelli che vedono Q10 effettua un controllo di percezione. Se riesce, leggi 004.',[block('Serve la linea di vista verificata verso Q10.')])
add('325','Tira un dado. 0–3: controllo di attivazione (+2), se riesce leggi 023. 4–8: nessun effetto. 9: controllo di percezione (−2), se riesce leggi 289.',[dice([(0,3,[act(2,'023')]),(4,8,[]),(9,9,[pc(-2,'289')])])])
add('326','Tira un dado. 0–3: controllo di attivazione (+1), se riesce leggi 297. 4–8: nessun effetto. 9: controllo di percezione (+2), se riesce leggi 333.',[dice([(0,3,[act(1,'297')]),(4,8,[]),(9,9,[pc(2,'333')])])])
add('328','[s3] Il soldato trova un ferito della squadra caduta nell’imboscata questa mattina. Ha due caricatori per mitra e una granata. Riesce a parlare: ha lasciato il mitra circa venti metri più avanti, in I11. Colloca il soldato americano K in G10, incapacitato. Se lo porti al sicuro e sopravvive fino alla fine della missione, ottieni 3 PV.',[{'op':'sighting','id':'s3'},{'op':'rescue_target'}])
add('329','Colloca un segnalino Evento. Controllo di percezione (−2): se riesce, leggi 007.',[marker,pc(-2,'007')])
add('330','Controllo di attivazione (+3). Se riesce, leggi 294. Altrimenti controllo di percezione: se riesce, leggi 316.',[act(3,'294',[pc(0,'316')])])
add('332','Controllo di percezione (−2). Se riesce, leggi 297; altrimenti leggi 319.',[pc(-2,'297',[go('319')])])
add('335','Controllo di attivazione (+3). Se riesce, leggi 183. Altrimenti controllo di percezione (−2): se riesce, leggi 312.',[act(3,'183',[pc(-2,'312')])])
add('348','Lontano a est del campo di battaglia, i tuoi soldati vedono dei Typhoon picchiare sulle posizioni tedesche. Le esplosioni della contraerea circondano gli aerei britannici.',page=9)
add('453','[s9] Un caccia britannico Typhoon, avvolto dal fumo, precipita in R15. Colloca il relitto fumante: ogni soldato nell’esagono muore. Se un americano entra in R15 mentre il relitto è presente, leggi 349.',[{'op':'sighting','id':'s9'},{'op':'crash','hex':'R15','entry_paragraph':'349'}],11)
add('600','Controllo di percezione. Se riesce, leggi 293; altrimenti colloca un segnalino Evento.',[pc(0,'293',[marker])],14)
# Encounter effects are recorded exactly. Round resolution remains explicitly gated.
for id,sightings,enemies,stance,adv,condition,extra in [
 ('180',['s1'],[(9,'K13'),(15,'K13')],'crouching','de',3,'I tedeschi appena attivati ricevono 2 turni in questo Round.'),
 ('183',['s2'],[(25,'M7')],'crouching','de',3,'Il tedesco 25 riceve 2 turni in questo Round.'),
 ('187',['s2','s5','s6'],[(34,'M5'),(25,'M7'),(53,'O4')],'crouching','us',3,''),
 ('289',['s1'],[(9,'K13'),(15,'K13')],'standing','us',3,'Il soldato che ha superato il controllo è consapevole. Tutti gli americani consapevoli che non cedono al panico ricevono 2 turni in questo Round.'),
 ('294',['s2','s5'],[(25,'M7'),(34,'M5')],'standing','de',3,''),
 ('297',['s6'],[(53,'O4')],'crouching','de',2,''),
 ('298',['s5','s6'],[(34,'M5'),(53,'O4')],'crouching','us',2,''),
 ('312',['s2'],[(25,'M7')],'standing','us',3,'Il soldato che ha superato il controllo è consapevole. Tutti gli americani consapevoli che non cedono al panico ricevono 2 turni in questo Round.'),
 ('316',['s2','s5'],[(25,'M7'),(34,'M5')],'crouching','us',3,'Se il soldato ha appena superato un controllo di percezione, è automaticamente consapevole.'),
 ('319',['s6'],[(53,'O4')],'crouching','de',2,'Il tedesco 53 riceve 2 turni in questo Round.'),
 ('324',['s1'],[(9,'K13'),(15,'K13')],'crouching','de',3,''),
 ('327',['s2'],[(25,'M7')],'crouching','de',3,''),
 ('331',['s2','s5','s6'],[(25,'M7'),(34,'M5'),(53,'O4')],'crouching','de',2,'Il tedesco 34 riceve 2 turni; gli altri tirano normalmente.'),
 ('333',['s6'],[(53,'O4')],'standing','us',2,'Il soldato che ha superato il controllo è consapevole. Tutti gli americani consapevoli che non cedono al panico ricevono 2 turni in questo Round.'),
 ('334',['s5','s6'],[(34,'M5'),(53,'O4')],'crouching','de',2,'')]:
  text='['+', '.join(sightings)+'] Attiva '+', '.join(f'il tedesco {n} in {h}' for n,h in enemies)+('. In piedi.' if stance=='standing' else '. Accovacciati.')+' Iniziano i Round. Vantaggio '+('americano.' if adv=='us' else 'tedesco.')+f' Passa alla Condizione {condition}. '+extra
  add(id,text.strip(),[{'op':'encounter','sightings':sightings,'enemies':[{'id':str(n),'hex':h,'stance':stance} for n,h in enemies],'advantage':adv,'condition':condition}],5 if id=='180' else 6 if id in ['183','187'] else 7 if id=='289' else 8)
add('018','Una delle armi tedesche che hanno sparato nel Round precedente ha esaurito le munizioni. Se sono più di una, scegli casualmente quale.',[block('Occorre il registro delle armi tedesche usate nel Round precedente.')],2)
add('028','Il soldato con la percezione più alta tra quelli che vedono O12 effettua un controllo di percezione. Se riesce, leggi 010.',[block('Serve la linea di vista verificata verso O12.')],2)
add('340','Controllo di attivazione. Se riesce, leggi 291; altrimenti leggi 313.',[act(0,'291',[go('313')])],9)
add('601','Controllo di attivazione (+3). Se riesce e s5 è già avvenuto, leggi 183; se s5 non è avvenuto, leggi 294. Se fallisce, effettua un controllo di percezione (−2): se riesce e s5 è avvenuto, leggi 312; altrimenti leggi 316.',[check('activation',3,[sight('s5',[go('183')],[go('294')])],[check('pc',-2,[sight('s5',[go('312')],[go('316')])])])],12)
add('603','Controllo di attivazione (+2). Se riesce, leggi 337; altrimenti leggi 194.',[act(2,'337',[go('194')])],12)
add('604','Controllo di percezione (−2). Se riesce, leggi 342; altrimenti colloca un segnalino Evento.',[pc(-2,'342',[marker])],12)
add('605','Campo minato! Risolvi la procedura del campo minato. Poi, se s2 non è ancora avvenuto, effettua un controllo di attivazione (+1): se riesce, leggi 291; altrimenti leggi 313.',[block('Procedura del campo minato ancora da implementare.')],12)
add('615','[s5] Attiva il tedesco 34 in N4, accovacciato. Iniziano i Round.',[{'op':'encounter','sightings':['s5'],'enemies':[{'id':'34','hex':'N4','stance':'crouching'}],'advantage':'unknown','condition':2}],12)
add('342','[s8] Il soldato nota i segni rivelatori di una striscia di mine che forma un arco da Q9 a V6.',[{'op':'sighting','id':'s8'}],9)
add('339','Controllo di percezione. Se riesce, leggi 342; altrimenti colloca un segnalino Evento.',[pc(0,'342',[marker])],8)
add('336','Controllo di attivazione (+1). Se riesce e s5 è già avvenuto, leggi 183; se s5 non è avvenuto, leggi 294. Se fallisce, effettua un controllo di percezione (−2): se riesce e s5 è avvenuto, leggi 312; altrimenti leggi 316.',[check('activation',1,[sight('s5',[go('183')],[go('294')])],[check('pc',-2,[sight('s5',[go('312')],[go('316')])])])],8)
add('192','Tira un dado. 0–5: controllo di attivazione (+2), se riesce leggi 337. 6–8: nessun effetto. 9: controllo di percezione (−2), se riesce leggi 602.',[dice([(0,5,[act(2,'337')]),(6,8,[]),(9,9,[pc(-2,'602')])])],6)
add('193','Tira un dado. 0–3: controllo di attivazione (+1), se riesce leggi 338. 4–8: nessun effetto. 9: controllo di percezione (−1), se riesce leggi 602.',[dice([(0,3,[act(1,'338')]),(4,8,[]),(9,9,[pc(-1,'602')])])],6)
add('194','Controllo di percezione. Se riesce, leggi 602; altrimenti leggi 338.',[pc(0,'602',[go('338')])],6)
add('196','Tira un dado. 0–4: controllo di attivazione (+2), se riesce leggi 291. 5–8: se s8 non è ancora avvenuto, controllo di percezione: se riesce leggi 342, altrimenti colloca un segnalino Evento. 9: controllo di percezione; se riesce leggi 312.',[dice([(0,4,[act(2,'291')]),(5,8,[sight('s8',[],[pc(0,'342',[marker])])]),(9,9,[pc(0,'312')])])],6)
add('341','Tutti i soldati che vedono R2 devono effettuare un controllo di percezione (−2). Se almeno uno riesce, leggi 606; se tutti falliscono, leggi 197. Se non si effettuano controlli, nessun evento.',[block('Serve la linea di vista verificata verso R2 e il controllo di più soldati.')],9)
add('337','[s5] Attiva il tedesco 34 in M5, accovacciato. Iniziano i Round. Vantaggio tedesco. Il tedesco 34 riceve due turni in questo Round.',[{'op':'encounter','sightings':['s5'],'enemies':[{'id':'34','hex':'M5','stance':'crouching'}],'advantage':'de','condition':2}],8)
add('338','[s5] Attiva il tedesco 34 in M5, accovacciato. Iniziano i Round. Vantaggio tedesco.',[{'op':'encounter','sightings':['s5'],'enemies':[{'id':'34','hex':'M5','stance':'crouching'}],'advantage':'de','condition':2}],8)
add('602','[s5] Attiva il tedesco 34 in M5, in piedi. Iniziano i Round. Vantaggio americano. Il soldato che ha superato il controllo di percezione è automaticamente consapevole in questo Round.',[{'op':'encounter','sightings':['s5'],'enemies':[{'id':'34','hex':'M5','stance':'standing'}],'advantage':'us','condition':2}],12)
dump('paragraphs_it.json',P)
print(len(P),'reviewed Italian paragraphs;',len(hexes),'hex lookups;',len(events),'event lookups')
