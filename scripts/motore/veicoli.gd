extends RefCounted
## Veicoli (regola 17): auto (jeep, Kübelwagen, auto comando) e, più avanti, carri.
## Lo stato è in p.s.veicoli: {id: {id, modello, nome, lato, hex, stato, occupanti[], gomme, bersagliato, fermo_fino}}.
## I soldati a bordo hanno il campo «veicolo» con l’id del mezzo: il primo occupante attivo guida.

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

const MODELLI := {
	"jeep": {"art": "La", "nome": "Jeep", "piccolo": true, "lenta": 5, "veloce": 9, "posti": 4},
	"kubelwagen": {"art": "La", "nome": "Kübelwagen", "piccolo": true, "lenta": 5, "veloce": 9, "posti": 4},
	"auto_comando": {"art": "L’", "nome": "Auto comando", "piccolo": true, "lenta": 5, "veloce": 10, "posti": 5},
	"panzer4": {"art": "Il", "nome": "Panzer IV", "piccolo": false, "lenta": 3, "veloce": 6, "posti": 0, "carro": true, "torretta": true},
	"sherman": {"art": "Lo", "nome": "Sherman", "piccolo": false, "lenta": 3, "veloce": 6, "posti": 0, "carro": true, "torretta": true},
	"jagdpanther": {"art": "Il", "nome": "Jagdpanther", "piccolo": false, "lenta": 3, "veloce": 6, "posti": 0, "carro": true, "torretta": false},
}

## Tabelle dei colpi dei carri: per lato (fronte, fianco, retro) e chiuso/aperto: [parte, da, a, corazza].
const COLPI_CARRO := {
	"torretta": {
		"fronte": {"chiuso": [["cingoli", 0, 1, "M"], ["scafo", 2, 6, "H"], ["torretta", 7, 9, "H"]],
			"aperto": [["cingoli", 0, 0, "M"], ["scafo", 1, 4, "H"], ["torretta", 5, 6, "H"], ["equipaggio", 7, 9, ""]]},
		"fianco": {"chiuso": [["cingoli", 0, 3, "M"], ["scafo", 4, 6, "H"], ["torretta", 7, 9, "H"]],
			"aperto": [["cingoli", 0, 2, "M"], ["scafo", 3, 4, "H"], ["torretta", 5, 6, "H"], ["equipaggio", 7, 9, ""]]},
		"retro": {"chiuso": [["cingoli", 0, 1, "M"], ["scafo", 2, 6, "M"], ["torretta", 7, 9, "H"]],
			"aperto": [["cingoli", 0, 1, "M"], ["scafo", 2, 4, "M"], ["torretta", 5, 7, "H"], ["equipaggio", 8, 9, ""]]},
	},
	"casamatta": {
		"fronte": {"chiuso": [["cingoli", 0, 1, "M"], ["scafo", 2, 6, "H"], ["affusto", 7, 9, "M"]],
			"aperto": [["cingoli", 0, 0, "M"], ["scafo", 1, 4, "H"], ["affusto", 5, 6, "M"], ["equipaggio", 7, 9, ""]]},
		"fianco": {"chiuso": [["cingoli", 0, 3, "M"], ["scafo", 4, 8, "H"], ["affusto", 9, 9, "M"]],
			"aperto": [["cingoli", 0, 2, "M"], ["scafo", 3, 6, "H"], ["affusto", 7, 7, "M"], ["equipaggio", 8, 9, ""]]},
		"retro": {"chiuso": [["cingoli", 0, 1, "M"], ["scafo", 2, 9, "M"]],
			"aperto": [["cingoli", 0, 1, "M"], ["scafo", 2, 7, "M"], ["equipaggio", 8, 9, ""]]},
	},
}
const LIVELLO_COR := {"": 0, "-": 0, "L": 1, "M": 2, "H": 3}

var p: Partita

func _init(partita: Partita) -> void:
	p = partita

# ------------------------------------------------------------------ stato
func tutti() -> Array:
	return p.s.get("veicoli", {}).values()

func v(vid: String) -> Dictionary:
	return p.s.get("veicoli", {}).get(vid, {})

func di(un: Dictionary) -> Dictionary:
	return v(str(un.get("veicolo", "")))

func attivo(veic: Dictionary) -> bool:
	return not veic.is_empty() and veic.stato == "attivo"

func in_esagono(h: String) -> Array:
	return tutti().filter(func(x): return x.hex == h and x.stato != "uscito")

func occupanti(veic: Dictionary) -> Array:
	var out: Array = []
	for id in veic.occupanti:
		var x := p.u(str(id))
		if not x.is_empty() and x.get("veicolo", "") == veic.id:
			out.append(x)
	return out

## Chi guida: il primo occupante attivo (17/5).
func autista(veic: Dictionary) -> Dictionary:
	for x in occupanti(veic):
		if p.attivo(x):
			return x
	return {}

func e_autista(un: Dictionary) -> bool:
	var veic := di(un)
	return attivo(veic) and autista(veic).get("id", "") == un.id

## Nome con l’articolo («Il Panzer IV», «La Kübelwagen»).
## «della Kübelwagen», «del Panzer IV», «dello Sherman».
func di_art(veic: Dictionary) -> String:
	var a := str(MODELLI[veic.modello].get("art", "Il"))
	return {"La": "della ", "Il": "del ", "Lo": "dello ", "L’": "dell’"}.get(a, "del ") + str(veic.nome)

func nome_art(veic: Dictionary) -> String:
	var a := str(MODELLI[veic.modello].get("art", "Il"))
	return (a + veic.nome) if a.ends_with("’") else (a + " " + veic.nome)

func crea(vid: String, modello: String, h: String, lato: String) -> Dictionary:
	if not p.s.has("veicoli"):
		p.s.veicoli = {}
	var m: Dictionary = MODELLI[modello]
	var veic := {"id": vid, "modello": modello, "nome": m.nome, "lato": lato, "hex": h, "stato": "attivo",
		"occupanti": [], "gomme": true, "bersagliato": false, "fronte": 0}
	p.s.veicoli[vid] = veic
	return veic

func sali(un: Dictionary, veic: Dictionary) -> String:
	if not attivo(veic):
		return "Il veicolo è fuori uso."
	if un.hex != veic.hex:
		return "Si sale solo su un veicolo nello stesso esagono."
	if occupanti(veic).size() >= int(MODELLI[veic.modello].posti):
		return "Il veicolo è pieno."
	un.veicolo = veic.id
	veic.occupanti.append(un.id)
	un.postura = "crouching"
	return ""

func scendi(un: Dictionary) -> void:
	var veic := di(un)
	un.erase("veicolo")
	if not veic.is_empty():
		veic.occupanti.erase(un.id)
	for a in un.armi.duplicate():
		if a.get("montata", false):
			un.armi.erase(a)

## Sposta il veicolo e tutti gli occupanti.
func sposta(veic: Dictionary, verso: String) -> void:
	var da: String = veic.hex
	var d := E.direzione(da, verso)
	if d >= 0:
		veic.fronte = d
	veic.hex = verso
	if p.fase_round():
		var rn := str(int(p.s.round.get("n", 0)))
		if not veic.has("mossi"):
			veic.mossi = {}
		veic.mossi[rn] = int(veic.mossi.get(rn, 0)) + 1
	if veic.lato == "de":
		p.segna_passaggio_ponte(da, verso)
	var ids: Array = []
	for x in occupanti(veic):
		x.hex = verso
		ids.append(x.id)
		for pid in x.get("prigionieri", []):
			var pr := p.u(pid)
			if not pr.is_empty() and pr.stato == "catturato":
				pr.hex = verso
	p._fx("muovi", {"ids": ids, "da": da, "a": verso, "veicolo": veic.id})

## Costo in PM per un veicolo (Tabella dei costi di movimento): -1 se vietato.
func costo(veic: Dictionary, da: String, verso: String) -> int:
	if not E.adiacenti(da, verso):
		return -1
	var t := p.terreno.tipo(verso)
	if p.terreno.ponte(verso):
		return 1 if da in p.terreno.capi_ponte(verso) else -1
	var c: int = int(T.COSTO_VEICOLO.get(t, 1))
	if c < 0:
		return -1
	c += int(p.s.get("nebbia_veicoli", 0))
	if t == "woods" and not bool(MODELLI[veic.modello].piccolo):
		return -1
	if p.s.modifiche.has(verso):
		return -1
	var tl := p.terreno.tipo_lato(da, verso)
	match tl:
		"wall", "door", "window":
			return -1
		"crest":
			c += 2
		"embankment":
			if p.terreno.quota(verso) > p.terreno.quota(da):
				c += 2
	return c

# ------------------------------------------------------------------ incidenti (17/9)
## Controllo d’incidente: dado ≤ abilità di guida dell’autista, nessun incidente.
func controllo_incidente(veic: Dictionary, motivo: String) -> void:
	var a := autista(veic)
	var ds := int(a.get("DS", 0)) if not a.is_empty() else -1
	var r := p.d10()
	if r <= ds:
		p._log("dado", "Controllo d’incidente %s (%s, abilità di guida %d): %d → nessun incidente." % [di_art(veic), motivo, ds, r])
		return
	var r2 := p.d10()
	var esito: String = (T.INCIDENTE_CARRO if bool(MODELLI[veic.modello].get("carro", false)) else T.INCIDENTE_AUTO)[r2]
	p._log("dado", "Controllo d’incidente %s (%s, abilità di guida %d): %d → incidente possibile; tabella degli incidenti %d → %s." % [di_art(veic), motivo, ds, r, r2, _nome_incidente(esito)])
	applica_incidente(veic, esito)

func _nome_incidente(e: String) -> String:
	return {"nessuno": "nessun effetto", "ferma": "si ferma", "perde_turno": "perde il turno", "distrutta": "fuori uso",
		"schianto": "schianto"}.get(e, e)

func applica_incidente(veic: Dictionary, esito: String) -> void:
	match esito:
		"cingolo":
			veic.immobilizzato = true
			veic.fermo = true
		"ferma":
			veic.fermo = true
		"perde_turno":
			veic.fermo = true
			for x in occupanti(veic):
				x.turni = 0
				if p.fase_round():
					x.slot = "completo"
		"distrutta":
			disabilita(veic, "incidente")
		"schianto":
			# La vettura prosegue di due esagoni in linea retta, si schianta ed è fuori uso.
			for i in 2:
				var n := E.vicino(veic.hex, int(veic.fronte))
				if n == "" or costo(veic, veic.hex, n) < 0:
					break
				sposta(veic, n)
			p._fx("esplosione", {"a": veic.hex})
			var occ := occupanti(veic)
			disabilita(veic, "schianto")
			for x in occ:
				if p.attivo(x):
					var r := p.d10()
					var l := T.lettera_danno(T.ARMI.pistol.danni, r)
					p._log("dado", "Schianto: %s %d → %s" % [p.nome(x), r, p._nome_danno(l)])
					p._applica_danno(x, l, {})

## Veicolo fuori uso: gli occupanti scendono proni nell’esagono e perdono i turni rimasti.
func disabilita(veic: Dictionary, motivo: String) -> void:
	if veic.stato != "attivo":
		return
	veic.stato = "distrutto"
	p._log("danno", "%s è fuori uso (%s)." % [nome_art(veic), motivo])
	p._fx("danno", {"id": veic.id, "tipo": "distrutto"})
	if veic.lato == "de" and int(veic.get("pv_distrutto", 0)) > 0:
		p._pv(int(veic.pv_distrutto), "%s fuori uso" % veic.nome)
	for x in occupanti(veic):
		scendi(x)
		if p.attivo(x):
			x.postura = "prone"
			x.turni = 0
			if p.fase_round():
				x.slot = "completo"

# ------------------------------------------------------------------ colpi contro un veicolo (17/6)
## Modificatore del tiro contro un veicolo per il terreno del suo esagono.
func modificatore(veic: Dictionary) -> int:
	var t := p.terreno.tipo(veic.hex)
	if p.terreno.ponte(veic.hex):
		t = "bridge"
	var col := 0 if bool(MODELLI[veic.modello].piccolo) else 1
	return int(T.MOD_VEICOLO.get(t, [0, 1])[col])

## Tabella dei colpi di jeep, Kübelwagen e auto comando: parte colpita per numero di occupanti.
func _parte_colpita(veic: Dictionary, r: int) -> Array:
	var occ := occupanti(veic)
	var n := occ.size()
	var gomme := [1, 1, 0, 0, 0, 0]
	var limite_gomme: int = gomme[mini(n, 5)]
	if r <= limite_gomme:
		return ["gomme", {}]
	var corpo_fino: int = [9, 7, 5, 4, 3, 2][mini(n, 5)]
	if r <= corpo_fino:
		return ["carrozzeria", {}]
	# Numeri dell’autista e dei passeggeri, per numero di occupanti (Riepilogo dei veicoli).
	var fasce := {1: [[8, 9]], 2: [[6, 7], [8, 9]], 3: [[5, 6], [7, 8], [9, 9]], 4: [[4, 5], [6, 7], [8, 8], [9, 9]],
		5: [[3, 4], [5, 6], [7, 7], [8, 8], [9, 9]]}
	var lista: Array = fasce.get(mini(n, 5), [])
	for i in mini(lista.size(), occ.size()):
		if r >= int(lista[i][0]) and r <= int(lista[i][1]):
			return ["autista" if i == 0 else "passeggero", occ[i]]
	return ["carrozzeria", {}]

## Lato del carro colpito, secondo la posizione del tiratore rispetto al fronte.
func lato_colpito(veic: Dictionary, da: String) -> String:
	if da == "" or da == veic.hex:
		return ["fronte", "fianco", "retro"][p.rng.randi_range(0, 2)]
	var avanti := E.centro(E.vicino(veic.hex, int(veic.fronte)) if E.vicino(veic.hex, int(veic.fronte)) != "" else veic.hex) - E.centro(veic.hex)
	if avanti.length() < 0.01:
		return "fianco"
	var verso_t := E.centro(da) - E.centro(veic.hex)
	var ang := rad_to_deg(absf(avanti.angle_to(verso_t)))
	if ang <= 60.0:
		return "fronte"
	if ang >= 120.0:
		return "retro"
	return "fianco"

## Colpo contro un carro: parte colpita, corazza e penetrazione.
func colpito_carro(veic: Dictionary, arma: String, tiratore: Dictionary, mirato: bool, fx: Dictionary) -> void:
	veic.bersagliato = true
	var lato := lato_colpito(veic, tiratore.get("hex", ""))
	var tab: Array = COLPI_CARRO["torretta" if bool(MODELLI[veic.modello].torretta) else "casamatta"][lato]["chiuso" if veic.get("chiuso", false) else "aperto"]
	var r := p.d10()
	var parte: Array = ["scafo", 0, 9, "H"]
	for x in tab:
		if r >= int(x[1]) and r <= int(x[2]):
			parte = x
	var rd := p.d10()
	var pen := T.penetrazione(arma, rd)
	fx.dado_danno = rd
	p._log("dado", "Carro colpito sul %s: %d → %s%s; penetrazione %d → %s." % [lato, r, parte[0], (" (corazza %s)" % parte[3]) if parte[3] != "" else "",
		rd, {"-": "nessuna", "L": "leggera", "M": "media", "H": "pesante"}[pen]])
	var basta: bool = int(LIVELLO_COR[pen]) >= int(LIVELLO_COR[parte[3]]) and pen != "-"
	match str(parte[0]):
		"cingoli":
			if basta:
				veic.immobilizzato = true
				p._log("danno", "Cingolo spezzato: il %s non può più muoversi." % veic.nome)
		"scafo":
			if basta:
				disabilita(veic, "scafo perforato")
		"torretta":
			if basta:
				disabilita(veic, "torretta perforata")
			elif not veic.get("coax_distrutta", false):
				veic.coax_distrutta = true
				p._log("danno", "La mitragliatrice coassiale del %s è distrutta." % veic.nome)
		"affusto":
			if pen in ["M", "H"]:
				veic.cannone_distrutto = true
				p._log("danno", "Il cannone del %s è distrutto." % veic.nome)
			elif pen == "L":
				veic.mg_distrutta = true
				p._log("danno", "La mitragliatrice del %s è distrutta." % veic.nome)
		"equipaggio":
			riduci_equipaggio(veic, 1)
			if arma == "bazooka":
				for i in 2:
					var rr := p.d10()
					var l := T.lettera_danno(T.CARICA_DENTRO if false else T.GRANATA_DENTRO, rr)
					if l in ["W", "I", "K"]:
						riduci_equipaggio(veic, 1)
			elif mirato and T.ARMI[arma].get("auto", false):
				var prec := rd
				while veic.stato == "attivo" and int(veic.equipaggio) > 0:
					var r2 := p.d10()
					if r2 >= prec:
						break
					riduci_equipaggio(veic, 1)
					prec = r2

## Un uomo in meno nell’equipaggio: cambiano IN, PC, WS e DS del carro (tabella della carta).
func riduci_equipaggio(veic: Dictionary, n: int) -> void:
	veic.equipaggio = maxi(0, int(veic.equipaggio) - n)
	p._log("danno", "Equipaggio del %s ridotto a %d." % [veic.nome, int(veic.equipaggio)])
	var g := autista(veic)
	if int(veic.equipaggio) <= 0:
		disabilita(veic, "equipaggio fuori combattimento")
		if not g.is_empty():
			p._uccidi(g, "con l’equipaggio del carro")
		return
	if not g.is_empty():
		aggiorna_equipaggio(veic, g)

func aggiorna_equipaggio(veic: Dictionary, g: Dictionary) -> void:
	var d: Dictionary = p.missione.tedeschi.get(str(int(g.get("num", 0))), {})
	if not d.has("carro"):
		return
	var riga: Dictionary = d.carro.righe.get(str(int(veic.equipaggio)), {})
	for k in ["IN", "PC", "WS", "DS"]:
		if riga.has(k):
			g[k] = int(riga[k])

## Effetti di un colpo andato a segno contro il veicolo.
func colpito(veic: Dictionary, arma: String, tiratore: Dictionary, mirato: bool, fx: Dictionary) -> void:
	if bool(MODELLI[veic.modello].get("carro", false)):
		colpito_carro(veic, arma, tiratore, mirato, fx)
		return
	veic.bersagliato = true
	var r := p.d10()
	var parte: Array = _parte_colpita(veic, r)
	p._log("dado", "Tabella dei colpi %s: %d → %s%s." % [di_art(veic), r, {"gomme": "pneumatici", "carrozzeria": "carrozzeria",
		"autista": "autista", "passeggero": "passeggero"}[parte[0]], (" (%s)" % p.nome(parte[1])) if not parte[1].is_empty() else ""])
	var info: Dictionary = T.ARMI[arma]
	match parte[0]:
		"gomme":
			veic.gomme = false
			p._log("danno", "Pneumatici forati: la %s non può più andare veloce." % veic.nome)
			if not occupanti(veic).is_empty():
				controllo_incidente(veic, "pneumatici colpiti")
		"carrozzeria":
			var rd := p.d10()
			var pen := T.penetrazione(arma, rd)
			fx.dado_danno = rd
			if pen != "-":
				fx.danno = "penetrazione"
				p._log("dado", "Danno alla carrozzeria: %d → penetrazione." % rd)
				disabilita(veic, "colpita alla carrozzeria")
			else:
				fx.danno = "nessuna penetrazione"
				p._log("dado", "Danno alla carrozzeria: %d → nessuna penetrazione." % rd)
				if not occupanti(veic).is_empty():
					controllo_incidente(veic, "carrozzeria colpita")
		"autista", "passeggero":
			var x: Dictionary = parte[1]
			var rd := p.d10()
			var l := T.lettera_danno(info.danni, rd)
			fx.dado_danno = rd
			fx.danno = p._nome_danno(l)
			p._log("dado", "Danno a %s: %d → %s" % [p.nome(x), rd, p._nome_danno(l)])
			p._applica_danno(x, l, tiratore)
			if parte[0] == "autista" and attivo(veic):
				if l in ["P", "W"]:
					controllo_incidente(veic, "autista colpito")
				elif l in ["I", "K"]:
					var r2 := p.d10()
					var esito: String = T.INCIDENTE_AUTO[r2]
					p._log("dado", "Autista fuori combattimento: incidente, tabella %d → %s." % [r2, _nome_incidente(esito)])
					applica_incidente(veic, esito)

# ------------------------------------------------------------------ veicoli tedeschi
## Paragrafo 128 (Missione 2): la Kübelwagen del tedesco 19 parte da N12 con autista e ufficiale.
func attiva_tedesco(num: int, h: String, ctx: Dictionary) -> void:
	if not v("v%d" % num).is_empty():
		return
	var veic := crea("v%d" % num, "kubelwagen", h, "de")
	p._op_attiva({"g": [[num, h], [num + 100, h]], "stance": "crouching", "adv": null, "two": [], "us_two": false,
		"aware": false, "reaction": null}, ctx)
	for id in ["g%d" % num, "g%d" % (num + 100)]:
		var g := p.u(id)
		if not g.is_empty():
			g.veicolo = veic.id
			veic.occupanti.append(id)
	p._log("attivazione", "%s parte da %s con l’autista e l’ufficiale a bordo." % [nome_art(veic), h])

## Un tedesco con la carta di un carro: crea il carro e lo mette a bordo.
func imbarca_carro(g: Dictionary, carro: Dictionary) -> void:
	var vid := "v%d" % int(g.num)
	var veic := v(vid)
	if veic.is_empty():
		veic = crea(vid, str(carro.modello), g.hex, "de")
		veic.equipaggio = 5
		veic.chiuso = false
		veic.cannone_pronto = not ("cannon not" in str(carro.get("testo", "")))
		veic.pv_distrutto = int(carro.get("pv_distrutto", 0))
		veic.primo_turno = int(carro.get("primo_turno", 0))
		var rif: String = p.movimento_rosso(g.hex)
		if E.valido(rif) and E.adiacenti(g.hex, rif):
			veic.fronte = E.direzione(g.hex, rif)
	g.veicolo = vid
	g.postura = "crouching"
	if not (g.id in veic.occupanti):
		veic.occupanti.append(g.id)
	aggiorna_equipaggio(veic, g)
	p._log("attivazione", "Entra in gioco un %s (equipaggio 5, %s, cannone %s)." % [veic.nome, "chiuso" if veic.chiuso else "aperto", "carico" if veic.cannone_pronto else "scarico"])

## Turno di un tedesco a bordo (carta 19): l’azione dipende da chi è fuori combattimento.
## Restituisce true se il turno è stato gestito qui.
func turno_equipaggio(ia, g: Dictionary) -> bool:
	var veic := di(g)
	if attivo(veic) and bool(MODELLI[veic.modello].get("carro", false)):
		turno_carro(ia, g, veic)
		return true
	var num := int(g.num)
	if not (num == 19 or num == 119):
		return false
	var driver := p.u("g19")
	var uff := p.u("g119")
	var d_ok := not driver.is_empty() and p.attivo(driver)
	var u_ok := not uff.is_empty() and p.attivo(uff)
	var par := 802
	if attivo(veic):
		if d_ok:
			par = 826
		elif u_ok:
			par = 814
		if g.id != autista(veic).get("id", ""):
			p._log("tedesco", "Il %s è a bordo %s: guida l’autista." % [p.nome(g), di_art(veic)])
			return true
	else:
		par = 813 if not (d_ok and u_ok) else 802
	p._log("tedesco", "Turno del %s (carta 19): paragrafo %d." % [p.nome(g), par])
	p._passo("tedesco", {"id": g.id, "colonna": "veicolo", "numero": int(p.s.round.get("numero_azione", 0)), "paragrafo": par,
		"motivo": "veicolo", "casella": "", "numero_tirato": false, "vede": []})
	if par in [826, 814, 828]:
		p._log("par", p.paragrafi[str(par)].it, {"id": str(par), "tedesco": g.id})
		var veloce: bool = par == 828 or (par == 826 and bool(veic.bersagliato))
		guida_tedesca(veic, veloce)
	else:
		ia.esegui(par)
	return true

# ------------------------------------------------------------------ carri tedeschi (17/13)
var _cp := 0
var _sparato_cannone := false
var _sparato_coax := false
var _caricato := false
var _ia = null

## Turno di un carro: numero d’azione e uomini dell’equipaggio danno il paragrafo; i punti equipaggio
## (uno per uomo) pagano le azioni: cannone 2, carica 1, mitragliatrici 2 mirato / 1 rapido,
## guida lenta 2, veloce 3, aprire o chiudere tutti.
func turno_carro(ia, g: Dictionary, veic: Dictionary) -> void:
	_ia = ia
	var d: Dictionary = p.missione.tedeschi[str(int(g.num))].carro
	var numero := int(p.s.round.get("numero_azione", p.d10()))
	var riga: Dictionary = d.righe.get(str(int(veic.equipaggio)), {})
	if riga.is_empty():
		return
	var col := 0
	for i in d.gruppi.size():
		if numero >= int(d.gruppi[i][0]) and numero <= int(d.gruppi[i][1]):
			col = i
	var par := int(riga.par[col])
	if int(veic.get("primo_turno", 0)) > 0:
		par = int(veic.primo_turno)
		veic.primo_turno = 0
	_cp = int(veic.equipaggio)
	_sparato_cannone = false
	_sparato_coax = false
	_caricato = false
	p._passo("tedesco", {"id": g.id, "colonna": "equipaggio %d" % int(veic.equipaggio), "numero": numero, "paragrafo": par,
		"motivo": "carro", "casella": "", "numero_tirato": false, "vede": bersagli_carro(g).map(func(a): return a.id)})
	p._log("tedesco", "Turno del %s: equipaggio %d, numero d’azione %d → paragrafo %d (%d punti equipaggio)." % [veic.nome, int(veic.equipaggio), numero, par, _cp])
	p._fx("attore", {"id": g.id, "a": g.hex})
	esegui_carro(par, g, veic)

func bersagli_carro(g: Dictionary) -> Array:
	var out: Array = []
	for a in p.americani_attivi_in_mappa():
		if p.vede_unita(g, a):
			out.append(a)
	out.sort_custom(func(a, b): return E.distanza(a.hex, g.hex) < E.distanza(b.hex, g.hex))
	return out

func esegui_carro(n: int, g: Dictionary, veic: Dictionary) -> void:
	if not attivo(veic):
		return
	p._log("par", p.paragrafi[str(n)].it, {"id": str(n), "tedesco": g.id})
	var b := bersagli_carro(g)
	match n:
		800, 840:
			pass
		811:
			if not b.is_empty():
				p._log("danno", "L’equipaggio del %s si arrende." % veic.nome)
				disabilita(veic, "equipaggio arreso")
				g.stato = "arreso"
		814:
			_guida(veic, false, g)
		827, 828:
			_guida(veic, true, g)
		900:
			_guida(veic, false, g)
			_cannone_o_carica(g, veic)
			if veic.cannone_pronto and not _sparato_cannone:
				_mg(g, veic, "coax", false, 1)
			_mg(g, veic, "scafo", false, 0)
		901:
			esegui_carro(910 if not b.is_empty() else 906, g, veic)
		902:
			if not b.is_empty():
				if veic.get("chiuso", false):
					esegui_carro(900, g, veic)
				else:
					_apri_chiudi(veic, true)
			elif not veic.get("chiuso", false):
				esegui_carro(906, g, veic)
			else:
				_apri_chiudi(veic, false)
		903:
			_guida(veic, int(g.DS) >= 6, g)
			_carica(veic)
		904:
			_mg(g, veic, "scafo", false, 0)
			_cannone_o_carica(g, veic)
		905:
			if b.size() >= 2:
				if veic.get("chiuso", false):
					esegui_carro(900, g, veic)
				else:
					_apri_chiudi(veic, true)
			elif b.size() == 1:
				esegui_carro(910, g, veic)
			elif not veic.get("chiuso", false):
				esegui_carro(906, g, veic)
			else:
				_apri_chiudi(veic, false)
		906:
			_guida(veic, true, g)
			_mg(g, veic, "scafo", false, 0)
			_carica(veic)
		907:
			if b.size() >= 3:
				if veic.get("chiuso", false):
					esegui_carro(910, g, veic)
				else:
					_apri_chiudi(veic, true)
			elif not b.is_empty():
				esegui_carro(900, g, veic)
			elif not veic.get("chiuso", false):
				esegui_carro(900, g, veic)
			else:
				_apri_chiudi(veic, false)
		908:
			_mg(g, veic, "scafo", true, 0)
		909:
			if not b.is_empty():
				if veic.get("chiuso", false):
					esegui_carro(904, g, veic)
				else:
					_apri_chiudi(veic, true)
			else:
				esegui_carro(827, g, veic)
		910:
			_mg(g, veic, "scafo", true, 0)
			_cannone_o_carica(g, veic)
			if veic.cannone_pronto and not _sparato_cannone:
				_mg(g, veic, "coax", true, 1)
		921:
			_guida(veic, false, g)
			_mg(g, veic, "scafo", false, 0)
			_cannone_o_carica(g, veic)
		922:
			_guida(veic, true, g)
			_mg(g, veic, "scafo", false, 0)
			_carica(veic)
		923:
			if b.size() >= 2:
				if veic.get("chiuso", false):
					esegui_carro(921, g, veic)
				else:
					_apri_chiudi(veic, true)
			elif b.size() == 1:
				esegui_carro(924, g, veic)
			elif not veic.get("chiuso", false):
				esegui_carro(922, g, veic)
			else:
				_apri_chiudi(veic, false)
		924:
			_mg(g, veic, "scafo", true, 0)
			_cannone_o_carica(g, veic)
		925:
			if not b.is_empty():
				if veic.get("chiuso", false):
					esegui_carro(921, g, veic)
				else:
					_apri_chiudi(veic, true)
			elif not veic.get("chiuso", false):
				esegui_carro(922, g, veic)
			else:
				_apri_chiudi(veic, false)
		_:
			p._log("errore", "Paragrafo d’azione del carro %d non gestito." % n)

func _apri_chiudi(veic: Dictionary, chiudi: bool) -> void:
	veic.chiuso = chiudi
	_cp = 0
	p._log("tedesco", "Il %s %s i portelli." % [veic.nome, "chiude" if chiudi else "apre"])

func _guida(veic: Dictionary, veloce: bool, g: Dictionary) -> void:
	if veic.get("immobilizzato", false) or veic.get("cingolo", false) or veic.get("fermo_sempre", false) or g.get("reazione", "") == "B" and int(g.num) == 55:
		p._log("tedesco", "Il %s non si muove." % veic.nome)
		return
	if veloce and veic.get("chiuso", false):
		veloce = false
	var costo_cp := 3 if veloce else 2
	if _cp < 2:
		return
	if _cp < costo_cp:
		veloce = false
		costo_cp = 2
	_cp -= costo_cp
	guida_tedesca(veic, veloce)

func _carica(veic: Dictionary) -> void:
	if veic.get("cannone_pronto", false) or veic.get("cannone_distrutto", false) or _sparato_cannone or _sparato_coax or _cp < 1:
		return
	_cp -= 1
	veic.cannone_pronto = true
	_caricato = true
	p._log("tedesco", "Il %s carica il cannone." % veic.nome)

## Cannone contro un bersaglio in un edificio o contro un veicolo americano; altrimenti carica.
func _cannone_o_carica(g: Dictionary, veic: Dictionary) -> void:
	if veic.get("cannone_distrutto", false):
		return
	var bersaglio := {}
	for a in bersagli_carro(g):
		if p.terreno.edificio(a.hex) or attivo(di(a)):
			if not bool(MODELLI[veic.modello].torretta) and not _davanti(veic, a.hex):
				continue
			bersaglio = a
			break
	if bersaglio.is_empty() or not veic.get("cannone_pronto", false) or _sparato_coax or _caricato or _cp < 2:
		_carica(veic)
		return
	_cp -= 2
	_sparato_cannone = true
	veic.cannone_pronto = false
	var arma := {"tipo": "cannone", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false}
	if attivo(di(bersaglio)):
		p.risolvi_tiro(g, arma, bersaglio, true)
		return
	# Contro un edificio: si spara al muro (+4) e lo scoppio colpisce chi è nell’esagono (13/5).
	var dist := E.distanza(g.hex, bersaglio.hex)
	var prob := clampi(T.base_per_distanza("cannone", dist) + int(g.WS) + 4, 0, 8)
	var r := p.d10()
	var colpito: bool = r == 0 or (r != 9 and r <= prob)
	p._log("combattimento", "Il %s spara con il cannone contro l’edificio %s: serve 0–%d, esce %d → %s." % [veic.nome, bersaglio.hex, prob, r, "COLPITO" if colpito else "mancato"])
	p._fx("tiro", {"da": g.hex, "a": bersaglio.hex, "tiratore": g.id, "bersaglio": bersaglio.id, "auto": false, "mirato": true,
		"arma": "cannone", "esito": "colpito" if colpito else "mancato", "prob": prob, "base": -1, "mods": [], "gittata": ""})
	if not colpito:
		return
	p._fx("esplosione", {"a": bersaglio.hex, "grande": true})
	for x in p.unita_in(bersaglio.hex, "us"):
		var soglia: int = {"prone": 0, "crouching": 1, "standing": 2}.get(x.postura, 1)
		var rr := p.d10()
		if rr <= int(soglia):
			p._log("dado", "Scoppio nell’edificio: %s %d → colpito." % [p.nome(x), rr])
			p._applica_danno(x, "K", g)
		else:
			p._log("dado", "Scoppio nell’edificio: %s %d → illeso." % [p.nome(x), rr])

## Mitragliatrice di scafo (solo bersagli davanti) o coassiale; quale = 0 il più vicino, 1 il secondo.
func _mg(g: Dictionary, veic: Dictionary, tipo: String, mirato: bool, quale: int) -> void:
	if tipo == "coax" and (veic.get("coax_distrutta", false) or _sparato_cannone or _caricato):
		return
	if tipo == "scafo" and veic.get("mg_distrutta", false):
		return
	var costo := 2 if mirato else 1
	if _cp < costo:
		mirato = false
		costo = 1
		if _cp < 1:
			return
	var lista: Array = bersagli_carro(g)
	if tipo == "scafo":
		lista = lista.filter(func(a): return _davanti(veic, a.hex))
	if lista.is_empty():
		return
	var b: Dictionary = lista[mini(quale, lista.size() - 1)]
	if not veic.has("mitragliatrici"):
		veic.mitragliatrici = {}
	if not veic.mitragliatrici.has(tipo):
		veic.mitragliatrici[tipo] = {"tipo": "mmg", "inceppata": false, "rotta": false, "preparata": true, "catturata": false, "scarica": false}
	var arma: Dictionary = veic.mitragliatrici[tipo]
	if arma.inceppata:
		_cp -= 1
		arma.inceppata = false
		p._log("tedesco", "L’equipaggio del %s sblocca la mitragliatrice %s." % [veic.nome, "coassiale" if tipo == "coax" else "di scafo"])
		return
	_cp -= costo
	if tipo == "coax":
		_sparato_coax = true
	p._log("tedesco", "Il %s spara con la mitragliatrice %s." % [veic.nome, "coassiale" if tipo == "coax" else "di scafo"])
	p.risolvi_tiro(g, arma, b, mirato)

func _davanti(veic: Dictionary, h: String) -> bool:
	return lato_colpito(veic, h) == "fronte" or h == veic.hex

## Guida un veicolo tedesco lungo i riferimenti rossi della carta Condizione.
func guida_tedesca(veic: Dictionary, veloce: bool) -> void:
	if veic.get("fermo", false):
		veic.fermo = false
		p._log("tedesco", "%s resta %s in questo turno." % [nome_art(veic), "ferma" if bool(MODELLI[veic.modello].piccolo) else "fermo"])
		return
	if veloce and not veic.gomme:
		veloce = false
	var lenta: int = int(MODELLI[veic.modello].lenta)
	var mp: int = int(MODELLI[veic.modello].veloce if veloce else lenta)
	var spesi := 0
	var passi := 0
	var controllato := false
	while attivo(veic) and passi < 15:
		passi += 1
		var rif: String = p.movimento_rosso(veic.hex)
		if rif == "":
			if passi == 1:
				p._log("tedesco", "La carta non indica un movimento per %s: la %s resta ferma." % [veic.hex, veic.nome])
			return
		if rif == "USCITA":
			_esce(veic)
			return
		var verso := rif
		if rif.is_valid_int() and rif.length() == 3:
			var ctx := {"g": autista(veic).get("id", ""), "hex": veic.hex, "veicolo": true, "veicolo_id": veic.id}
			p.leggi(rif, ctx)
			verso = str(ctx.get("verso_veicolo", ""))
			if verso == "":
				return
		var c := costo(veic, veic.hex, verso)
		if c < 0 or spesi + c > mp:
			return
		spesi += c
		sposta(veic, verso)
		p._log("tedesco", "%s %s in %s." % [nome_art(veic), "corre" if veloce else "avanza", verso])
		if spesi > lenta and not controllato:
			controllato = true
			controllo_incidente(veic, "guida veloce")
			if not attivo(veic) or veic.get("fermo", false):
				veic.fermo = false
				return

## Riferimento di movimento letto da un paragrafo («se si muove un veicolo, entra in …»).
func entra_da_paragrafo(ctx: Dictionary, h: String) -> void:
	ctx.verso_veicolo = h

func _esce(veic: Dictionary) -> void:
	var da: String = veic.hex
	veic.stato = "uscito"
	var ids: Array = []
	for x in occupanti(veic):
		x.stato = "uscito"
		x.hex = ""
		x.turni = 0
		x.slot = "inattivo"
		ids.append(x.id)
	veic.hex = ""
	p._log("tedesco", "%s esce dalla mappa." % nome_art(veic))
	p._fx("sparisce", {"ids": ids, "da": da, "motivo": "uscito"})

## Paragrafo 173: l’ufficiale e l’aiutante si arrendono accanto alla Kübelwagen nascosta.
func resa_kubelwagen(ctx: Dictionary) -> void:
	var h: String = ctx.get("hex", "")
	var presenti: Array = p.unita_in(h, "us")
	if presenti.is_empty():
		return
	var guardia: Dictionary = presenti[0]
	for num in [19, 119]:
		var gid := "g%d" % num
		var g := p.u(gid)
		if g.is_empty():
			g = p._crea_tedesco(num, h, "prone")
		elif not p.attivo(g):
			continue
		g.erase("veicolo")
		g.hex = h
		p._cattura(guardia, g)
		p._log("info", "Il %s si arrende ed è fatto prigioniero." % p.nome(g))
	p._pv(3, "cattura dell’ufficiale della Kübelwagen")
	p.s.unita["g119"].pv_catturato = true
	p._log("info", "Interrogatorio dell’ufficiale: controllo Evento, poi paragrafo 177.")
	p.evento_casuale({"hex": h, "ids": presenti.map(func(x): return x.id)})
	if p.s.fase == "fine":
		return
	p.leggi("177", ctx)
	p._log("info", "Perquisizione della Kübelwagen: controllo Evento, poi paragrafo 006.")
	p.evento_casuale({"hex": h, "ids": presenti.map(func(x): return x.id)})
	if p.s.fase != "fine":
		p.leggi("006", ctx)
