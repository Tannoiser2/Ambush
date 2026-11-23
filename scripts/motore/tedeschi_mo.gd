extends RefCounted
const E = preload("res://scripts/motore/esagoni.gd")
const T = preload("res://scripts/motore/tabelle.gd")
## Paragrafi d’azione dei tedeschi propri di Move Out! (quelli identici al gioco base usano tedeschi.gd).

var t  # tedeschi.gd

func _init(tedeschi) -> void:
	t = tedeschi

## Esegue il paragrafo n se è di Move Out!; false per lasciarlo al gioco base.
func esegui(n: int) -> bool:
	var g: Dictionary = t._g
	match n:
		466, 469, 471:
			if int(g.get("paracadute", 0)) > 0:
				_togli_paracadute(g)
			else:
				t.esegui({466: 865, 469: 863, 471: 864}[n])
		476:
			if not t._cedi_turno(1):
				esegui(466)
		967, 969:
			t.p.leggi(str(n), {"g": g.id, "hex": g.hex})
		803:
			var vicini: Array = _americani_entro(g, 6)
			var visti: Array = t.bersagli(g)
			if visti.is_empty() and not vicini.is_empty() and int(g.munizioni.get("granata", 0)) > 0:
				if t._alzati():
					_granata_su(g, vicini[0].hex)
					t._prono_se_libero()
			elif not visti.is_empty() and int(g.munizioni.get("granata", 0)) > 0:
				if t._alzati():
					_granata_su(g, visti[0].hex)
					t._prono_se_libero()
			elif not visti.is_empty():
				t.esegui(801)
		804:
			var b4: Array = t.bersagli(g)
			if b4.size() == 1:
				t._accovacciati()
				t._miglior_tiro("vicino", -1, false, "mmg")
			elif b4.size() >= 2:
				esegui(805)
		805:
			if t._bersagli_entro(3) and int(g.munizioni.get("granata", 0)) > 0:
				t._accovacciati()
				_granata_su(g, _esagono_affollato(g, 3))
				t._prono_se_libero()
			elif t._bersagli_entro(5):
				if t._alzati():
					t._tiri_rapidi()
					t._prono_se_libero()
			else:
				t.esegui(815)
		806, 807, 809:
			if not _anticarro(g, "pzb", 99):
				if n == 806:
					esegui(805)
				elif n == 807:
					t.esegui(815)
				else:
					esegui(810)
		810:
			if not _americani_entro(g, 5).is_empty():
				if t._alzati():
					t._miglior_tiro("vicino", 5)
					t._prono_se_libero()
			else:
				t.esegui(815)
		811:
			var entro6: Array = _americani_entro(g, 6)
			if not entro6.is_empty() and int(g.munizioni.get("granata", 0)) > 0:
				if t._alzati():
					_granata_su(g, entro6[t.p.rng.randi_range(0, entro6.size() - 1)].hex)
					t._prono_se_libero()
			else:
				t._prono()
		813, 818:
			var capo: int = 50 if n == 813 else 52
			if not t._attivo_num(capo):
				t._accovacciati()
				var adiac: Array = E.vicini(g.hex).filter(func(h): return not t.p.unita_in(h, "us").is_empty())
				if adiac.is_empty():
					adiac = E.vicini(g.hex)
				_granata_su(g, adiac[t.p.rng.randi_range(0, adiac.size() - 1)])
		816:
			var col: String = t.colonna(g, true)
			var num: int = t.p.d10("Nuovo numero d’azione")
			t.esegui(t.paragrafo_da_carta(g, col, num))
		820:
			if not t._attivo_num(50):
				t._arrenditi()
		821:
			if not t._attivo_num(52):
				t._arrenditi()
			elif not t._tedesco_vicino(1):
				t._prono()
		823, 825, 826, 827:
			var verso: String = {823: "J13", 825: "N13", 826: "S12", 827: "T12"}[n]
			var ha_pzf: bool = not g.armi.filter(func(w): return w.tipo == "pzf").is_empty()
			if ha_pzf and _anticarro(g, "pzf", 3):
				t._prono_se_libero()
			elif ha_pzf and not _mezzi_in_vista(g, 99).is_empty():
				t.esegui(801)
			else:
				t._corri_verso(verso)
				if t.p.in_mappa(g) and g.hex == verso:
					t.esegui(868)
		932:
			if t.p.unita_in(g.hex, "us").size() >= 2:
				t._arrenditi()
			elif t._alzati():
				t._miglior_tiro("vicino")
				t._prono_se_libero()
		933:
			if t._bersagli_entro(3) and int(g.munizioni.get("granata", 0)) > 0:
				if t._alzati():
					_granata_su(g, _esagono_affollato(g, 3))
			elif t._alzati():
				t._miglior_tiro("vicino")
		477:
			g.reazione = "Z"
			t._reazione_cambiata = true
			t.p._log("tedesco", "Reazione speciale Z in vigore per il %s." % t.p.nome(g))
		_:
			return false
	return true

func _americani_entro(g: Dictionary, n: int) -> Array:
	var l: Array = t.p.americani_attivi_in_mappa().filter(func(a): return a.hex != g.hex and E.distanza(a.hex, g.hex) <= n)
	l.sort_custom(func(a, b): return E.distanza(a.hex, g.hex) < E.distanza(b.hex, g.hex))
	return l

## Esagono con più americani entro n esagoni (a parità, il più vicino).
func _esagono_affollato(g: Dictionary, n: int) -> String:
	var conta := {}
	for a in _americani_entro(g, n):
		conta[a.hex] = int(conta.get(a.hex, 0)) + 1
	var meglio := ""
	for h in conta:
		if meglio == "" or int(conta[h]) > int(conta[meglio]) or (int(conta[h]) == int(conta[meglio]) and E.distanza(h, g.hex) < E.distanza(meglio, g.hex)):
			meglio = h
	return meglio

func _granata_su(g: Dictionary, h: String) -> void:
	if h == "" or int(g.munizioni.get("granata", 0)) <= 0:
		return
	if t.p.probabilita_lancio(g, "granata", h).ok:
		t.p.risolvi_lancio(g, "granata", h)

## Mezzi americani in vista entro n esagoni: prima lo Sherman, poi la jeep.
func _mezzi_in_vista(g: Dictionary, n: int) -> Array:
	var l: Array = t.p.americani_attivi_in_mappa().filter(func(a):
		return (a.get("carro_us", false) or t.p.veicoli.attivo(t.p.veicoli.di(a))) and E.distanza(a.hex, g.hex) <= n and t.p.vede_unita(g, a))
	l.sort_custom(func(a, b): return int(a.get("carro_us", false)) > int(b.get("carro_us", false)))
	return l

## Panzerfaust o Panzerbüchse contro un mezzo americano. true se ha sparato.
func _anticarro(g: Dictionary, tipo: String, raggio: int) -> bool:
	var armi: Array = g.armi.filter(func(w): return w.tipo == tipo and not w.get("rotta", false))
	if armi.is_empty():
		return false
	var bersagli: Array = _mezzi_in_vista(g, raggio)
	if bersagli.is_empty():
		return false
	var arma: Dictionary = armi[0]
	var b: Dictionary = bersagli[0]
	if tipo == "pzb":
		arma.preparata = true
	else:
		t._accovacciati()
	var base: int = T.base_per_distanza(tipo, E.distanza(g.hex, b.hex))
	if base < 0:
		return false
	var prob: int = base if tipo == "pzf" else base + int(g.WS)
	t.p._log("tedesco", "Il %s spara col %s a %s." % [t.p.nome(g), T.ARMI[tipo].nome, t.p.nome(b)])
	t.p.risolvi_tiro(g, arma, b, true, maxi(0, prob))
	if tipo == "pzf":
		g.armi.erase(arma)
	else:
		g.pzb_colpi = int(g.get("pzb_colpi", int(t.p.missione.tedeschi.get(str(int(g.num)), {}).get("pzb_colpi", 2)))) - 1
		if int(g.pzb_colpi) <= 0:
			g.armi.erase(arma)
	return true

func _togli_paracadute(g: Dictionary) -> void:
	if g.postura == "prone":
		t._accovacciati()
	g.paracadute = int(g.paracadute) - 1
	if int(g.paracadute) > 0:
		t.p._log("tedesco", "Il %s comincia a togliersi il paracadute." % t.p.nome(g))
	else:
		t.p._log("tedesco", "Il %s si è tolto il paracadute." % t.p.nome(g))
	t._fermo = true

## Azioni dei carri di Move Out! (Missione 10). false per lasciarle al gioco base.
func esegui_carro(n: int, g: Dictionary, veic: Dictionary) -> bool:
	var vv = t.p.veicoli
	var c1: bool = int(t.p.s.condizione) == 1
	match n:
		919:
			_log_par(n, g)
			var vicina: bool = t.p.mo.artiglieria_vicina(veic.hex)
			if vicina and not veic.get("chiuso", false):
				vv._apri_chiudi(veic, true)
			elif vicina:
				vv._guida(veic, false, g)
			else:
				vv._guida(veic, not veic.get("chiuso", false), g)
		920:
			_log_par(n, g)
			if not veic.get("chiuso", false):
				vv._apri_chiudi(veic, true)
			else:
				vv._guida(veic, false, g)
		921:
			_log_par(n, g)
			vv._guida(veic, false, g)
			vv._mg(g, veic, "scafo", false, 0)
			vv._cannone_o_carica(g, veic)
		923, 925, 926, 927:
			_log_par(n, g)
			if c1:
				esegui_carro(919, g, veic)
			else:
				var dopo: int = {923: 910, 925: 921, 926: 900, 927: 924}[n]
				if not esegui_carro(dopo, g, veic):
					vv.esegui_carro(dopo, g, veic)
		928, 929, 930, 931:
			_log_par(n, g)
			if c1:
				esegui_carro(920, g, veic)
			else:
				var dopo2: int = {928: 814, 929: 908, 930: 968, 931: 970}[n]
				if not esegui_carro(dopo2, g, veic):
					vv.esegui_carro(dopo2, g, veic)
		968, 970:
			_log_par(n, g)
			vv._cannone_o_carica(g, veic)
			vv._mg(g, veic, "scafo", false, 0)
		901, 903:
			_log_par(n, g)
			var mezzi: Array = _mezzi_in_vista(g, 99)
			if not mezzi.is_empty():
				veic.cannone_pronto = true
				vv._cannone_o_carica(g, veic)
			else:
				esegui_carro(902 if n == 901 else 904, g, veic)
		902:
			_log_par(n, g)
			if not vv.bersagli_carro(g).is_empty():
				vv._mg(g, veic, "scafo", true, 0)
		904:
			_log_par(n, g)
			if t.p.unita_in(veic.hex, "us").size() >= 4:
				t.p._log("danno", "L’equipaggio del %s si arrende." % veic.nome)
				vv.disabilita(veic, "equipaggio arreso")
				g.stato = "arreso"
			else:
				esegui_carro(902, g, veic)
		972:
			_log_par(n, g)
			vv._mg(g, veic, "scafo", false, 0)
		973:
			_log_par(n, g)
			vv._mg(g, veic, "coax", false, 1)
		_:
			return false
	return true

func _log_par(n: int, g: Dictionary) -> void:
	if t.p.paragrafi.has(str(n)):
		t.p._log("par", t.p.paragrafi[str(n)].it, {"id": str(n), "tedesco": g.id})
