extends RefCounted
## Comportamento dei soldati tedeschi (regola 6/8): carta del soldato, numero d’azione,
## paragrafi d’azione 800–971 e movimento con i riferimenti rossi delle carte Condizione.

const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")

var p: Partita
var _g: Dictionary = {}
var _mp := 0
var _fermo := false
var _reazione_cambiata := false

func _init(partita: Partita) -> void:
	p = partita

# ------------------------------------------------------------------ turno
func turno(g: Dictionary) -> void:
	_g = g
	g.cambio_libero = not g.ferito
	_mp = p.effettivo_mpa(g)
	_fermo = false
	_reazione_cambiata = false
	var col := colonna(g)
	var numero: int = int(p.s.round.numero_azione)
	var par := paragrafo_da_carta(g, col, numero)
	p._log("tedesco", "Turno del %s: colonna %s, numero d’azione %d → paragrafo %d." % [p.nome(g), _nome_colonna(col), numero, par])
	p._fx("attore", {"id": g.id, "a": g.hex})
	esegui(par)
	if _reazione_cambiata:
		# Una reazione speciale fa tirare un nuovo numero d’azione per i tedeschi che devono ancora agire.
		p.s.round.numero_azione = p.d10()
		p._log("dado", "Reazione speciale: nuovo numero d’azione tedesco %d." % int(p.s.round.numero_azione))

func _nome_colonna(c: String) -> String:
	if c == "S":
		return "autoconservazione (S)"
	if c.length() == 1 and c >= "A" and c <= "Z":
		return "reazione speciale " + c
	return "Condizione " + c

## Colonna da usare: autoconservazione se adiacente a un americano attivo, poi reazione speciale, poi Condizione.
func colonna(g: Dictionary, ignora_s := false) -> String:
	var colonne: Dictionary = p.missione.tedeschi[str(int(g.num))].colonne
	if g.get("solo_S", false):
		return "S"
	if not ignora_s and not g.no_auto and _vicino_ad_americani(g) and colonne.has("S"):
		return "S"
	var r: String = g.get("reazione", "")
	if r != "" and colonne.has(r):
		return r
	var c := int(p.s.condizione)
	for k in colonne:
		if k in ["A", "B", "S"]:
			continue
		var parti: PackedStringArray = str(k).split("-")
		var lo := int(parti[0])
		var hi := int(parti[parti.size() - 1])
		if c >= lo and c <= hi:
			return k
	# Condizione senza colonna (es. Condizione 1): si usa la prima colonna di Condizione disponibile.
	for k in colonne:
		if not (k in ["A", "B", "S"]):
			return k
	return "S"

func _vicino_ad_americani(g: Dictionary) -> bool:
	for a in p.americani_attivi_in_mappa():
		if E.distanza(a.hex, g.hex) <= 1:
			return true
	return false

func paragrafo_da_carta(g: Dictionary, col: String, numero: int) -> int:
	var d: Dictionary = p.missione.tedeschi[str(int(g.num))]
	var riga := 0
	for i in d.gruppi.size():
		var gr: Array = d.gruppi[i]
		if numero >= int(gr[0]) and numero <= int(gr[1]):
			riga = i
	return int(d.colonne[col][riga])

# ------------------------------------------------------------------ paragrafi d’azione
func esegui(n: int) -> void:
	var g := _g
	if not p.in_mappa(g):
		return
	if n != 816:
		p._log("par", p.paragrafi[str(n)].it, {"id": str(n), "tedesco": g.id})
	match n:
		800:
			_prono()
		801:
			_accovacciati()
			_miglior_tiro("facile")
			_prono_se_libero()
		802:
			_accovacciati()
			_miglior_tiro("vicino")
			_prono_se_libero()
		803:
			var v := bersagli(g)
			if not v.is_empty() and not p.terreno.scoperto(g.hex):
				_accovacciati()
				_miglior_tiro("facile")
				_prono_se_libero()
			elif not v.is_empty():
				_muovi_rapido(false)
			else:
				_corri_o_striscia(false)
		804:
			if not p.in_vista_americani(g):
				rimuovi_evasivo(g)
			elif _bersagli_entro(3):
				_accovacciati()
				_miglior_tiro("facile", 3)
				_prono_se_libero()
			else:
				_prono()
		805:
			if not p.in_vista_americani(g):
				rimuovi_evasivo(g)
			elif _bersagli_entro(4):
				_arrenditi()
			else:
				_prono()
		808:
			var v := bersagli(g)
			if v.is_empty():
				_accovacciati()
			elif v.size() <= 2:
				_accovacciati()
				_miglior_tiro("facile")
				_prono_se_libero()
			else:
				_prono()
		809:
			_muovi_rapido(false)
			if g.postura != "prone" and p.in_mappa(g):
				if g.cambio_libero:
					g.cambio_libero = false
					_set_postura("prone")
				elif _mp >= 1:
					_mp -= 1
					_set_postura("prone")
		813:
			if bersagli(g).size() > 2:
				_arrenditi()
			else:
				esegui(802)
		815:
			_accovacciati()
			if _bersagli_entro(3):
				_miglior_tiro("facile", 3)
			else:
				_miglior_tiro("facile")
			_prono_se_libero()
		816:
			p._log("par", p.paragrafi["816"].it, {"id": "816", "tedesco": g.id})
			var nuovo := p.d10()
			p._log("dado", "Nuovo numero d’azione per il %s: %d" % [p.nome(g), nuovo])
			var col := colonna(g, true)
			esegui(paragrafo_da_carta(g, col, nuovo))
		824:
			_accovacciati()
			_miglior_tiro("facile", -1, true)
			_prono_se_libero()
		825:
			_accovacciati()
			_tiri_rapidi()
		829:
			var v := bersagli(g)
			if v.size() == 1:
				_accovacciati()
				_miglior_tiro("facile")
				_prono_se_libero()
			else:
				_prono()
		830:
			if p.terreno.scoperto(g.hex):
				_muovi_rapido(true)
			else:
				_prono()
		831, 832:
			var ok := _cedi_turno(1)
			if not ok:
				if _tutti_due_turni(1):
					esegui(801)
				elif n == 831:
					_prono()
				else:
					esegui(801)
		833:
			if not p.unita_in(g.hex, "us").is_empty():
				_assalta(_bersaglio_assalto())
			elif _granata_adiacente():
				pass
			elif not bersagli(g).is_empty():
				_accovacciati()
				_miglior_tiro("facile")
			else:
				_prono()
		835:
			if not _cedi_turno(2):
				esegui(801)
		836:
			if not p.in_vista_americani(g):
				rimuovi_evasivo(g)
			elif p.terreno.scoperto(g.hex):
				_muovi_rapido(false)
				_prono_se_libero()
			else:
				_accovacciati()
				_miglior_tiro("facile")
				_prono_se_libero()
		837:
			if not p.in_vista_americani(g):
				rimuovi_evasivo(g)
			else:
				_muovi_rapido(false, true)
		838:
			_corri_o_striscia(true)
			g.rimuovi_fine_round = true
		839:
			if not p.unita_in(g.hex, "us").is_empty():
				_assalta(_bersaglio_assalto())
			else:
				_accovacciati()
				_miglior_tiro("vicino")
		913:
			if _americano_in("T8"):
				esegui(802)
			elif _tedeschi_persi() >= 3:
				_striscia_verso("N5")
				p.cambia_condizione(4)
			else:
				esegui(802)
		914:
			if _americano_in("T8"):
				esegui(802)
			elif bersagli(g).size() >= 3:
				_striscia_verso("N5")
				p.cambia_condizione(4)
			else:
				esegui(802)
		915:
			if not bersagli(g).is_empty():
				esegui(801)
			else:
				esegui(830)
		916:
			if p.terreno.edificio(g.hex) or p.terreno.tipo(g.hex) == "woods":
				esegui(802)
			else:
				esegui(830)
		917:
			if p.terreno.edificio(g.hex):
				esegui(801)
			else:
				esegui(803)
		918:
			esegui(801 if g.hex == g.hex_attivazione else 836)
		919:
			esegui(802 if g.hex == g.hex_attivazione else 837)
		920:
			esegui(802 if g.hex == g.hex_attivazione else 809)
		965:
			if _bersagli_entro(5):
				_accovacciati()
				_miglior_tiro("vicino", 5, false, "pistol")
				_prono_se_libero()
			else:
				_prono()
		971:
			var nell := p.unita_in(g.hex, "us").size()
			if nell == 0:
				_prono()
			elif nell <= 2:
				_assalta(_bersaglio_assalto())
			else:
				_arrenditi()
		_:
			p._log("errore", "Paragrafo d’azione %d non gestito: il tedesco resta fermo." % n)

# ------------------------------------------------------------------ bersagli
func bersagli(g: Dictionary) -> Array:
	var out: Array = []
	for a in p.americani_attivi_in_mappa():
		if p.vede_unita(g, a):
			out.append(a)
	return out

func _bersagli_entro(n: int) -> bool:
	for a in bersagli(_g):
		if E.distanza(_g.hex, a.hex) <= n:
			return true
	return false

func _americano_in(h: String) -> bool:
	return not p.unita_in(h, "us").is_empty()

func _tedeschi_persi() -> int:
	var n := 0
	for g in p.tedeschi():
		if g.stato in ["morto", "incapacitato", "catturato"]:
			n += 1
	return n

## Arma primaria: quella con la migliore probabilità contro il bersaglio.
func _migliore_arma(g: Dictionary, b: Dictionary, mirato: bool, solo := "") -> Array:
	var migliore: Array = []
	for a in g.armi:
		if a.rotta or a.inceppata or a.get("scarica", false):
			continue
		if solo != "" and a.tipo != solo:
			continue
		var pr: Dictionary = p.probabilita_tiro(g, a, b, mirato)
		if pr.ok and (migliore.is_empty() or int(pr.prob) > int(migliore[1].prob)):
			migliore = [a, pr]
	return migliore

func _scegli_bersaglio(criterio: String, limite: int, mirato: bool, evita_gia: bool, solo := "") -> Array:
	var g := _g
	var opzioni: Array = []
	for b in bersagli(g):
		var d := E.distanza(g.hex, b.hex)
		if limite >= 0 and d > limite:
			continue
		var m := _migliore_arma(g, b, mirato, solo)
		if m.is_empty():
			continue
		opzioni.append({"b": b, "arma": m[0], "prob": int(m[1].prob), "dist": d})
	if opzioni.is_empty():
		return []
	if evita_gia and opzioni.size() > 1:
		var nuovi := opzioni.filter(func(o): return not (o.b.id in g.bersagli_round))
		if not nuovi.is_empty():
			opzioni = nuovi
	var rng: RandomNumberGenerator = p.rng
	var chiave := func(o):
		if criterio == "facile":
			return [-o.prob, o.dist, rng.randf()]
		return [o.dist, -o.prob, rng.randf()]
	var valutate: Array = opzioni.map(func(o): return [chiave.call(o), o])
	valutate.sort_custom(func(x, y):
		for i in 3:
			if x[0][i] != y[0][i]:
				return x[0][i] < y[0][i]
		return false)
	var o: Dictionary = valutate[0][1]
	return [o.b, o.arma]

func _miglior_tiro(criterio: String, limite := -1, evita_gia := false, solo := "") -> void:
	var g := _g
	if not p.in_mappa(g) or g.postura == "prone":
		return
	if _arma_inceppata_senza_alternative():
		return
	var mirato: bool = not g.get("_snap_forzato", false)
	var scelta := _scegli_bersaglio(criterio, limite, mirato, evita_gia, solo)
	if scelta.is_empty():
		p._log("tedesco", "Il %s non ha bersagli validi." % p.nome(g))
		return
	p.risolvi_tiro(g, scelta[1], scelta[0], mirato)
	g.erase("_snap_forzato")

func _tiri_rapidi() -> void:
	var g := _g
	if not p.in_mappa(g) or g.postura == "prone" or _arma_inceppata_senza_alternative():
		return
	for i in 2:
		var scelta := _scegli_bersaglio("vicino", -1, false, i > 0)
		if scelta.is_empty():
			return
		p.risolvi_tiro(g, scelta[1], scelta[0], false)
		if not p.in_mappa(g):
			return

## Arma inceppata e nessuna alternativa: il tedesco prova a liberarla invece di sparare (9/4).
func _arma_inceppata_senza_alternative() -> bool:
	var g := _g
	var utilizzabili := 0
	var inceppata := {}
	for a in g.armi:
		if a.rotta or a.get("scarica", false):
			continue
		if a.inceppata:
			inceppata = a
		else:
			utilizzabili += 1
	if utilizzabili > 0 or inceppata.is_empty():
		return false
	var ws := clampi(int(g.WS), -3, 2)
	var r := p.d10()
	var l: String = T.DISINCEPPA[ws].substr(r, 1)
	if l == "C":
		inceppata.inceppata = false
		p._log("dado", "Il %s libera l’arma inceppata (%d)." % [p.nome(g), r])
	elif l == "B":
		inceppata.inceppata = false
		inceppata.rotta = true
		p._log("dado", "Il %s rompe l’arma cercando di liberarla (%d)." % [p.nome(g), r])
	else:
		p._log("dado", "Il %s non riesce a liberare l’arma (%d)." % [p.nome(g), r])
	return true

# ------------------------------------------------------------------ posture
func _set_postura(x: String) -> void:
	if _g.postura == x:
		return
	if x == "prone" and p.terreno.tipo(_g.hex) == "stream" and not _g.get("sul_ponte", false):
		return
	p._log("tedesco", "Il %s è ora %s." % [p.nome(_g), T.NOMI_POSTURA[x]])
	p.imposta_postura(_g, x)

func _accovacciati() -> void:
	if _g.postura == "crouching":
		return
	if _g.cambio_libero:
		_g.cambio_libero = false
		_set_postura("crouching")
	else:
		# Ferito: il cambio costa 1 PM e trasforma il tiro in «muovi e spara» (rapido).
		_mp -= 1
		_g._snap_forzato = true
		_set_postura("crouching")

func _alzati() -> bool:
	if _g.postura == "standing":
		return true
	if _g.cambio_libero:
		_g.cambio_libero = false
		_set_postura("standing")
		return true
	if _mp >= 1:
		_mp -= 1
		_set_postura("standing")
		return true
	return false

func _prono() -> void:
	if _g.postura == "prone":
		return
	if _g.cambio_libero:
		_g.cambio_libero = false
		_set_postura("prone")
	elif _mp >= 1:
		_mp -= 1
		_set_postura("prone")

func _prono_se_libero() -> void:
	if p.in_mappa(_g) and _g.cambio_libero and _g.postura != "prone":
		_g.cambio_libero = false
		_set_postura("prone")

# ------------------------------------------------------------------ movimento
## Prossimo passo secondo la carta Condizione: esagono, paragrafo o USCITA (vuoto se nessuno).
func _riferimento(h: String) -> String:
	return p.movimento_rosso(h)

func _passo(verso: String, strisciando: bool) -> bool:
	var g := _g
	if not E.adiacenti(g.hex, verso):
		return false
	var costo: int = p.terreno.costo_movimento(g.hex, verso)
	if costo < 0:
		return false
	if strisciando:
		if not p.terreno.strisciare_possibile(g.hex, verso):
			return false
		_mp = 0
	else:
		if costo > _mp:
			return false
		_mp -= costo
	var da_hex: String = g.hex
	g.hex = verso
	g.sul_ponte = p.terreno.ponte(verso) and da_hex in p.terreno.capi_ponte(verso)
	p._log("tedesco", "Il %s %s in %s." % [p.nome(g), "striscia" if strisciando else "corre", verso])
	p._fx("muovi", {"ids": [g.id], "da": da_hex, "a": verso, "strisciando": strisciando})
	if not p.unita_in(verso, "us").is_empty():
		_fermo = true
	return true

## Esegue un riferimento di movimento; restituisce false se il movimento deve fermarsi.
func _segui_riferimento(rif: String, strisciando: bool) -> bool:
	var g := _g
	if rif == "":
		return false
	if rif == "USCITA":
		var da_u: String = g.hex
		g.stato = "uscito"
		g.hex = ""
		g.turni = 0
		g.slot = "inattivo"
		p._log("tedesco", "Il %s esce dalla mappa." % p.nome(g))
		p._fx("sparisce", {"ids": [g.id], "da": da_u, "motivo": "uscito"})
		return false
	if rif.is_valid_int() and rif.length() == 3:
		var ctx := {"g": g.id, "hex": g.hex, "strisciando": strisciando}
		p.leggi(rif, ctx)
		return not _fermo and not _reazione_cambiata and p.in_mappa(g) and not strisciando
	return _passo(rif, strisciando) and not _fermo and not strisciando

func entra_da_paragrafo(ctx: Dictionary, h: String) -> void:
	if _g.is_empty() or ctx.get("g", "") != _g.id:
		return
	if not _passo(h, bool(ctx.get("strisciando", false))):
		# Senza punti sufficienti si entra comunque: il riferimento definisce la mossa.
		var da_h: String = _g.hex
		_g.hex = h
		p._log("tedesco", "Il %s entra in %s." % [p.nome(_g), h])
		p._fx("muovi", {"ids": [_g.id], "da": da_h, "a": h})

func imposta_reazione(ctx: Dictionary, r: String) -> void:
	var g: Dictionary = p.u(ctx.get("g", ""))
	if g.is_empty():
		return
	g.reazione = r
	_reazione_cambiata = true
	p._log("tedesco", "Reazione speciale %s in vigore per il %s." % [r, p.nome(g)])

func _nessun_riferimento() -> void:
	p._log("tedesco", "La carta della Condizione %d non indica un movimento per %s: il %s resta sul posto." % [int(p.s.condizione), _g.hex, p.nome(_g)])

## «Muoviti il più rapidamente possibile»: in piedi, segue i riferimenti finché ha PM.
func _muovi_rapido(prono_se_non_scoperto: bool, prono_primo_non_scoperto := false) -> void:
	var g := _g
	if _riferimento(g.hex) == "":
		_nessun_riferimento()
		if prono_se_non_scoperto and not p.terreno.scoperto(g.hex):
			_prono()
		return
	if not _alzati():
		return
	var passi := 0
	while p.in_mappa(g) and passi < 12:
		passi += 1
		var rif := _riferimento(g.hex)
		if not _segui_riferimento(rif, false):
			break
		if (prono_se_non_scoperto or prono_primo_non_scoperto) and not p.terreno.scoperto(g.hex):
			_prono()
			return

## «Corri in un esagono scoperto, striscia in ogni altro tipo».
func _corri_o_striscia(evasivo: bool) -> void:
	var g := _g
	if _riferimento(g.hex) == "":
		_nessun_riferimento()
		return
	var mosso := false
	var passi := 0
	while p.in_mappa(g) and passi < 12:
		passi += 1
		var rif := _riferimento(g.hex)
		if rif == "":
			break
		var verso := rif if E.valido(rif) else ""
		if verso != "" and not p.terreno.scoperto(verso):
			if mosso:
				break
			if g.postura == "prone":
				if not (g.cambio_libero or _mp >= 1):
					break
				_accovacciati()
			elif g.postura == "standing":
				_accovacciati()
			_segui_riferimento(rif, true)
			break
		if not _alzati():
			break
		if not _segui_riferimento(rif, false):
			break
		mosso = true
		if evasivo and not p.terreno.edificio(g.hex) and not p.in_vista_americani(g):
			_prono()
			break

func _striscia_verso(h: String) -> void:
	if _g.postura == "standing" or _g.postura == "prone":
		_accovacciati()
	if not _passo(h, true):
		p._log("tedesco", "Il %s non riesce a strisciare in %s." % [p.nome(_g), h])

func rimuovi_evasivo(g: Dictionary) -> void:
	var da_r: String = g.hex
	g.stato = "rimosso"
	g.hex = ""
	g.turni = 0
	g.slot = "inattivo"
	var k := str(int(g.num))
	p.s.evasi[k] = int(p.s.evasi.get(k, 0)) + 1
	p._log("tedesco", "Il %s si dilegua fuori dalla vista degli americani: è rimosso dalla mappa." % p.nome(g))
	p._fx("sparisce", {"ids": [g.id], "da": da_r, "motivo": "dileguato"})

# ------------------------------------------------------------------ altre azioni
func _arrenditi() -> void:
	var g := _g
	var presenti: Array = p.unita_in(g.hex, "us")
	g.postura = "prone"
	g.turni = 0
	g.slot = "inattivo"
	if not presenti.is_empty():
		p._cattura(presenti[0], g)
	else:
		g.stato = "arreso"
		p._log("danno", "Il %s si arrende e alza le mani. Il primo americano che entra in %s lo cattura." % [p.nome(g), g.hex])
		p._fx("danno", {"id": g.id, "tipo": "arreso"})

func _bersaglio_assalto() -> Dictionary:
	var lista: Array = p.unita_in(_g.hex, "us")
	if lista.is_empty():
		return {}
	var deboli := lista.filter(func(a): return a.postura == "prone" or a.ferito)
	var scelta: Array = deboli if not deboli.is_empty() else lista
	return scelta[p.rng.randi_range(0, scelta.size() - 1)]

func _assalta(b: Dictionary, carica := false) -> void:
	if b.is_empty():
		return
	if not _alzati():
		return
	p.risolvi_assalto(_g, b, "uccidi", carica)

## 833, punto 2: americano adiacente oltre un lato attraversabile e granata disponibile.
func _granata_adiacente() -> bool:
	var g := _g
	for a in p.americani_attivi_in_mappa():
		if not E.adiacenti(a.hex, g.hex) or p.terreno.costo_movimento(g.hex, a.hex) < 0:
			continue
		if not p.unita_in(a.hex, "de").is_empty():
			# Eccezione: tedesco attivo nell’esagono americano → carica d’assalto.
			var vecchio: String = g.hex
			if _alzati():
				var c: int = p.terreno.costo_movimento(g.hex, a.hex)
				if c <= int(p.effettivo_mpa(g)) / 2:
					g.hex = a.hex
					p._log("tedesco", "Il %s carica in %s." % [p.nome(g), a.hex])
					p._fx("muovi", {"ids": [g.id], "da": vecchio, "a": a.hex})
					_assalta(_bersaglio_assalto(), true)
					return true
			g.hex = vecchio
			continue
		if int(g.munizioni.get("granata", 0)) > 0:
			_accovacciati()
			if p.probabilita_lancio(g, "granata", a.hex).ok:
				p.risolvi_lancio(g, "granata", a.hex)
				return true
	return false

## Cede un turno a un tedesco vicino (831, 832, 835). Restituisce true se ceduto.
func _cedi_turno(raggio: int) -> bool:
	var g := _g
	var candidati: Array = []
	for x in p.tedeschi_attivi():
		if x.id == g.id or x.ferito or x.panico:
			continue
		if E.distanza(x.hex, g.hex) > raggio:
			continue
		if x.slot in ["turni", "completo"] and int(x.turni) < 2:
			candidati.append(x)
	if candidati.is_empty():
		return false
	candidati.sort_custom(func(a, b):
		if int(a.turni) != int(b.turni):
			return int(a.turni) < int(b.turni)
		return int(a.WS) > int(b.WS))
	var x: Dictionary = candidati[0]
	if raggio == 1:
		_accovacciati()
	x.turni = int(x.turni) + 1
	x.slot = "turni"
	p._log("tedesco", "Il %s cede un turno al %s." % [p.nome(g), p.nome(x)])
	return true

func _tutti_due_turni(raggio: int) -> bool:
	var trovati := false
	for x in p.tedeschi_attivi():
		if x.id == _g.id or E.distanza(x.hex, _g.hex) > raggio:
			continue
		trovati = true
		if int(x.turni) < 2:
			return false
	return trovati
