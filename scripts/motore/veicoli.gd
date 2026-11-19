extends RefCounted
## Veicoli (regola 17): auto (jeep, Kübelwagen, auto comando) e, più avanti, carri.
## Lo stato è in p.s.veicoli: {id: {id, modello, nome, lato, hex, stato, occupanti[], gomme, bersagliato, fermo_fino}}.
## I soldati a bordo hanno il campo «veicolo» con l’id del mezzo: il primo occupante attivo guida.

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

const MODELLI := {
	"jeep": {"nome": "Jeep", "piccolo": true, "lenta": 5, "veloce": 9, "posti": 4},
	"kubelwagen": {"nome": "Kübelwagen", "piccolo": true, "lenta": 5, "veloce": 9, "posti": 4},
	"auto_comando": {"nome": "Auto comando", "piccolo": true, "lenta": 5, "veloce": 10, "posti": 5},
}

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
		p._log("dado", "Controllo d’incidente della %s (%s, abilità di guida %d): %d → nessun incidente." % [veic.nome, motivo, ds, r])
		return
	var r2 := p.d10()
	var esito: String = T.INCIDENTE_AUTO[r2]
	p._log("dado", "Controllo d’incidente della %s (%s, abilità di guida %d): %d → incidente possibile; tabella degli incidenti %d → %s." % [veic.nome, motivo, ds, r, r2, _nome_incidente(esito)])
	applica_incidente(veic, esito)

func _nome_incidente(e: String) -> String:
	return {"nessuno": "nessun effetto", "ferma": "si ferma", "perde_turno": "perde il turno", "distrutta": "fuori uso",
		"schianto": "schianto"}.get(e, e)

func applica_incidente(veic: Dictionary, esito: String) -> void:
	match esito:
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
	p._log("danno", "La %s è fuori uso (%s)." % [veic.nome, motivo])
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

## Effetti di un colpo andato a segno contro il veicolo.
func colpito(veic: Dictionary, arma: String, tiratore: Dictionary, mirato: bool, fx: Dictionary) -> void:
	veic.bersagliato = true
	var r := p.d10()
	var parte: Array = _parte_colpita(veic, r)
	p._log("dado", "Tabella dei colpi della %s: %d → %s%s." % [veic.nome, r, {"gomme": "pneumatici", "carrozzeria": "carrozzeria",
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
	p._log("attivazione", "La %s parte da %s con l’autista e l’ufficiale a bordo." % [veic.nome, h])

## Turno di un tedesco a bordo (carta 19): l’azione dipende da chi è fuori combattimento.
## Restituisce true se il turno è stato gestito qui.
func turno_equipaggio(ia, g: Dictionary) -> bool:
	var veic := di(g)
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
			p._log("tedesco", "Il %s è a bordo della %s: guida l’autista." % [p.nome(g), veic.nome])
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

## Guida un veicolo tedesco lungo i riferimenti rossi della carta Condizione.
func guida_tedesca(veic: Dictionary, veloce: bool) -> void:
	if veic.get("fermo", false):
		veic.fermo = false
		p._log("tedesco", "La %s resta ferma in questo turno." % veic.nome)
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
		p._log("tedesco", "La %s %s in %s." % [veic.nome, "corre" if veloce else "avanza", verso])
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
	p._log("tedesco", "La %s esce dalla mappa." % veic.nome)
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
