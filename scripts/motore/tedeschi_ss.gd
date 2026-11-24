extends RefCounted
const E = preload("res://scripts/motore/esagoni.gd")
## Paragrafi d’azione dei tedeschi propri di Silver Star (Missione 19): sommozzatori, chiatte, camion, reazione A, barche.

var t  # tedeschi.gd

func _init(tedeschi) -> void:
	t = tedeschi

func _ss():
	return t.p.ss

## Turno interamente gestito qui (barche di guardia): true se fatto.
func turno(g: Dictionary) -> bool:
	if g.get("barca_ss", false):
		_ss().turno_barca(t, g)
		return true
	return false

func esegui(n: int) -> bool:
	var g: Dictionary = t._g
	var p = t.p
	match n:
		760:
			# Granata entro 3 (accovacciato) o a 4–6 (in piedi); poi a terra.
			var vicini: Array = p.americani_attivi_in_mappa().filter(func(a): return E.distanza(a.hex, g.hex) <= 3 and a.hex != g.hex)
			var lontani: Array = t.bersagli(g).filter(func(a): return E.distanza(a.hex, g.hex) in [4, 5, 6])
			if int(g.munizioni.get("granata", 0)) > 0 and not vicini.is_empty():
				t._accovacciati()
				t._lancia_granata(3)
			elif int(g.munizioni.get("granata", 0)) > 0 and not lontani.is_empty():
				t._alzati()
				t._lancia_granata(6)
			t._prono_se_libero()
			return true
		761:
			# Se vede un altro tedesco attivo, tiri rapidi; altrimenti a terra.
			var altri: Array = p.tedeschi_attivi().filter(func(x): return x.id != g.id and p.vede_unita(g, x))
			if not altri.is_empty() and not t.bersagli(g).is_empty():
				g._snap_forzato = true
				t._miglior_tiro("vicino")
				g.erase("_snap_forzato")
			else:
				g.postura = "prone"
			return true
	if p.ss.m20.attiva():
		return _esegui20(g, n)
	if p.ss.m24.attiva():
		var m24 = p.ss.m24
		if m24.ruba_muli(t, g) or m24.tiro_ai_muli(t, g):
			return true
		match n:
			742, 743, 744:
				p.ss.m23.turno_pattuglia(t, g, {742: 762, 743: 739, 744: 735}[n])
				return true
			740:
				if t.bersagli(g).is_empty():
					g.reazione = "B"
					t._corri_verso("P12")
				else:
					t.esegui(t.paragrafo_da_carta(g, "1", int(p.s.round.get("numero_azione", 0))))
				return true
			749:
				if t.bersagli(g).is_empty() and p.americani_attivi_in_mappa().filter(func(a): return E.colonna(a.hex) > E.colonna("N1")).is_empty():
					p.ss.m20._togli(g, 0, "")
					p._log("tedesco", "Il %s si ritira e sparisce." % p.nome(g))
				else:
					t.esegui(t.paragrafo_da_carta(g, "1", int(p.s.round.get("numero_azione", 0))))
				return true
			520:
				var squadra: Array = [471, 472, 473].filter(func(x): return p.attivo(p.u("g%d" % x)))
				if squadra.is_empty():
					g.reazione = "M" if int(p.s.condizione) == 3 else ""
					t._ritira_e_esegui()
				else:
					t._accovacciati()
					t._miglior_tiro("vicino")
					t._prono_se_libero()
				return true
			501, 502, 503, 504:
				return _esegui20(g, 549 if n == 501 else n)
			635, 848, 849:
				var vicini: Array = p.americani_attivi_in_mappa().filter(func(a): return E.distanza(a.hex, g.hex) <= 3 and a.hex != g.hex)
				var lontani: Array = p.americani_attivi_in_mappa().filter(func(a): return E.distanza(a.hex, g.hex) in [4, 5, 6])
				if int(g.munizioni.get("granata", 0)) > 0 and not vicini.is_empty():
					t._accovacciati()
					t._lancia_granata(3)
					t._prono_se_libero()
				elif int(g.munizioni.get("granata", 0)) > 0 and not lontani.is_empty():
					t._alzati()
					t._lancia_granata(6)
					t._prono_se_libero()
				else:
					t.esegui(815 if int(p.s.round.get("numero_azione", 0)) % 2 == 1 else 840)
				return true
			884, 883:
				t._alzati()
				if n == 883:
					g._snap_forzato = true
				t._miglior_tiro("facile" if n == 884 else "vicino")
				g.erase("_snap_forzato")
				t._prono_se_libero()
				return true
			846:
				var nb: int = t.bersagli(g).size()
				if nb >= 3:
					g.postura = "prone"
				elif nb == 2:
					t.esegui(815)
				elif nb == 1:
					t._alzati()
					t._miglior_tiro("vicino")
					t._prono_se_libero()
				return true
			847:
				var vicino: bool = not p.tedeschi_attivi().filter(func(x): return x.id != g.id and E.distanza(x.hex, g.hex) <= 8).is_empty()
				if vicino:
					t.esegui(869)
				else:
					g.postura = "prone"
				return true
			322:
				if not g.get("mosso_turno", false):
					ss_esce(g)
				else:
					t._accovacciati()
				return true
		return false
	if p.ss.m23.attiva():
		match n:
			730, 735, 739, 762:
				p.ss.m23.turno_pattuglia(t, g, n)
				return true
			415:
				return true
		return false
	if p.ss.m22.attiva():
		var m22 = p.ss.m22
		match n:
			216:
				m22.turno_autista(t, g)
			217:
				m22.turno_secondo(t, g)
			218:
				m22.turno_geniere(t, g)
			261:
				m22.turno_e(t, g)
			153:
				m22.turno_h(t, g)
			158, 481:
				m22.turno_g(t, g)
			599:
				m22.turno_b(t, g)
			265, 266, 267, 268:
				m22.turno_atg(t, g)
			208, 209:
				_panzerfaust22(g, n)
			823:
				var altri: Array = p.unita_in(g.hex, "de").filter(func(x): return x.id != g.id and p.attivo(x))
				if not altri.is_empty():
					g.postura = "prone"
				else:
					t.esegui(868)
			848:
				var vicini: Array = p.americani_attivi_in_mappa().filter(func(a): return E.distanza(a.hex, g.hex) <= 3)
				var lontani: Array = t.bersagli(g).filter(func(a): return E.distanza(a.hex, g.hex) in [4, 5, 6])
				if int(g.munizioni.get("granata", 0)) > 0 and not vicini.is_empty():
					t._accovacciati()
					t._lancia_granata(3)
					t._prono_se_libero()
				elif int(g.munizioni.get("granata", 0)) > 0 and not lontani.is_empty():
					t._alzati()
					t._lancia_granata(6)
					t._prono_se_libero()
				else:
					t.esegui(815)
			549, 502, 503, 504:
				return _esegui20(g, n)
			_:
				return false
		return true
	if p.ss.m21.attiva():
		match n:
			425, 426, 584, 585:
				return p.ss.m21.turno_granatiere(t, g, n)
			583, 586:
				p.ss.m21.turno_h(t, g, n)
				return true
		return false
	match n:
		233, 564:
			_sub_cerca(g, "F4" if n == 233 else "K6", n == 564)
		672:
			_sub_672(g)
		348:
			_sub_348(g)
		343, 344, 345, 347:
			_su_chiatta(g, n)
		346:
			t.esegui(801)
		565:
			var v: Dictionary = p.veicoli.di(g)
			if p.veicoli.attivo(v):
				var colpito: bool = bool(v.get("bersagliato", false))
				p.veicoli.guida_tedesca(v, colpito)
				if colpito and p.attivo(g):
					g._snap_forzato = true
					t._miglior_tiro("facile")
			else:
				esegui(569)
		566, 567:
			var v2: Dictionary = p.veicoli.di(g)
			if not p.veicoli.attivo(v2):
				esegui(569)
			elif bool(v2.get("bersagliato", false)):
				t._miglior_tiro("vicino" if n == 566 else "facile")
			else:
				p._log("tedesco", "Il %s resta seduto sul camion." % p.nome(g))
		568:
			var v3: Dictionary = p.veicoli.di(g)
			if not p.veicoli.attivo(v3):
				esegui(569)
			elif bool(v3.get("bersagliato", false)):
				var d: int = p.d10()
				if d % 2 == 1:
					p._log("dado", "Dado %d: il capitano cede il turno al soldato più abile sul camion." % d)
					var migliore := {}
					for x in p.veicoli.occupanti(v3):
						if x.id != g.id and p.attivo(x) and (migliore.is_empty() or int(x.WS) > int(migliore.WS)):
							migliore = x
					if not migliore.is_empty():
						t.turno(migliore)
						t._g = g
				else:
					t._tiri_rapidi()
		569:
			if str(g.get("veicolo", "")) != "":
				p.veicoli.scendi(g)
				g.postura = "standing"
			g.reazione = ""
			p._log("tedesco", "Il %s toglie la reazione speciale T e scende dal camion." % p.nome(g))
			t._ritira_e_esegui()
		823:
			if p.unita_in(g.hex, "de").filter(func(x): return x.id != g.id).is_empty():
				t._corri_o_striscia(false)
			else:
				t._prono()
		861:
			if not t._cedi_turno(1):
				t.esegui(856)
		782:
			if not _verso_chiatta(g, [["N5", "O5"], ["N6", "O6"]]):
				_per_numero(g, [[0, 1, 801], [2, 5, 800], [6, 9, 808]])
		784:
			if not _verso_chiatta(g, [["M7", "M8"], ["L7", "M8"]]):
				_per_numero(g, [[0, 3, 801], [4, 6, 808], [7, 9, 856]])
		785:
			if not _verso_chiatta(g, [["J7", "J8"], ["I7", "I8"]]):
				_per_numero(g, [[0, 3, 801], [4, 6, 808], [7, 9, 856]])
		786:
			if not _verso_chiatta(g, [["D7", "D8"], ["C6", "B8"]]):
				_per_numero(g, [[0, 1, 856], [2, 2, 840], [3, 6, 810], [7, 9, 802]])
		_:
			return false
	return true

func _per_numero(g: Dictionary, tab: Array) -> void:
	var num := int(t.p.s.round.get("numero_azione", 0))
	for r in tab:
		if num >= int(r[0]) and num <= int(r[1]):
			t.esegui(int(r[2]))
			return

## Reazione A: se c’è una chiatta libera, va verso il suo esagono di terra.
func _verso_chiatta(g: Dictionary, coppie: Array) -> bool:
	for c in coppie:
		var ch: Dictionary = _ss().chiatta_in(str(c[0]))
		if not ch.is_empty() and t.p.veicoli.occupanti(ch).filter(func(x): return t.p.attivo(x)).is_empty():
			g.reazione = ""
			t.p._log("tedesco", "Il %s toglie la reazione speciale A e va verso la chiatta in %s." % [t.p.nome(g), c[0]])
			t._corri_verso(str(c[1]))
			return true
	return false

func _piu_vicino(g: Dictionary, lista: Array) -> Dictionary:
	var m := {}
	for a in lista:
		if m.is_empty() or E.distanza(a.hex, g.hex) < E.distanza(m.hex, g.hex):
			m = a
	return m

func _sub_cerca(g: Dictionary, base: String, spara: bool) -> void:
	var p = t.p
	var ss = _ss()
	if p.controllo_pc(g, 0, "sommozzatore tedesco"):
		var visti: Array = t.bersagli(g).filter(func(a): return ss.sommozzatore(a))
		var b := _piu_vicino(g, visti)
		if not b.is_empty():
			ss.nuota_verso(g, b.hex, true)
			return
		if g.hex != base:
			ss.nuota_verso(g, base, true)
		elif spara and not t.bersagli(g).is_empty():
			if ss.sott_acqua(g):
				g.postura = "standing"
			g._snap_forzato = true
			t._miglior_tiro("vicino")
		else:
			p._log("tedesco", "Il %s resta in agguato in %s." % [p.nome(g), g.hex])
	else:
		if g.hex != base:
			ss.nuota_verso(g, base, false)
		else:
			p._log("tedesco", "Il %s resta in agguato in %s." % [p.nome(g), g.hex])

func _sub_672(g: Dictionary) -> void:
	var p = t.p
	var ss = _ss()
	var sub: Array = ss.sub_americani()
	var b := _piu_vicino(g, sub)
	if not b.is_empty() and E.distanza(b.hex, g.hex) <= 2:
		ss.nuota_verso(g, b.hex, false)
		return
	if not b.is_empty() and E.distanza(b.hex, g.hex) == 3 and int(g.munizioni.get("granata", 0)) > 0:
		if ss.sott_acqua(g):
			g.postura = "standing"
		if t._lancia_granata(3):
			return
	var bersagli: Array = t.bersagli(g)
	if not bersagli.is_empty():
		if ss.sott_acqua(g):
			g.postura = "standing"
			p._log("tedesco", "Il %s riemerge per sparare." % p.nome(g))
		g._snap_forzato = true
		t._miglior_tiro("vicino")
		return
	if g.hex != "F2":
		ss.nuota_verso(g, "F2", false)
	else:
		p._log("tedesco", "Il %s aspetta in F2." % p.nome(g))

func _sub_348(g: Dictionary) -> void:
	var p = t.p
	var stesso: Array = p.unita_in(g.hex, "us")
	if not stesso.is_empty():
		t._assalta(t._bersaglio_assalto())
		return
	var inc: Array = p.unita_in(g.hex, "us", false).filter(func(a): return a.stato == "incapacitato" and a.get("sub", false))
	var adiac := false
	for a in p.americani_attivi_in_mappa():
		if E.distanza(a.hex, g.hex) == 1:
			adiac = true
	if not inc.is_empty() and adiac:
		var x: Dictionary = inc[0]
		x.sub = false
		p._log("tedesco", "Il %s strappa l’autorespiratore a %s, che affonda." % [p.nome(g), p.nome(x)])
		x.stato = "morto"
		return
	var vicini: Array = p.americani_attivi_in_mappa().filter(func(a): return E.distanza(a.hex, g.hex) == 1)
	if not vicini.is_empty():
		var b: Dictionary = vicini[0]
		var da: String = g.hex
		g.hex = b.hex
		p._fx("muovi", {"ids": [g.id], "da": da, "a": b.hex})
		p.risolvi_assalto(g, b, "uccidi", true)

## Paragrafi 343–347: il tedesco sulla chiatta spara (prima ai sommozzatori) o lancia granate.
func _su_chiatta(g: Dictionary, n: int) -> void:
	var p = t.p
	var ss = _ss()
	var sub: Array = ss.sub_americani().filter(func(a): return E.distanza(a.hex, g.hex) <= 3)
	match n:
		343, 347:
			if int(g.munizioni.get("granata", 0)) > 0 and (not sub.is_empty() or n == 347):
				t._accovacciati()
				if t._lancia_granata(3):
					t._prono_se_libero()
					return
			t._accovacciati()
			t._miglior_tiro("vicino" if n == 343 else "facile")
			t._prono_se_libero()
		344:
			t._accovacciati()
			var visti: Array = t.bersagli(g).filter(func(a): return ss.sommozzatore(a))
			if not visti.is_empty():
				t._miglior_tiro("vicino")
			elif not sub.is_empty() and t._lancia_granata(3):
				pass
			else:
				t._miglior_tiro("facile")
			t._prono_se_libero()
		345:
			if int(g.munizioni.get("granata", 0)) > 0 and not t.bersagli(g).is_empty() and t._lancia_granata(6):
				return
			t._accovacciati()
			t._tiri_rapidi()

# ------------------------------------------------------------------ Missione 20
func _per_numero20(tab: Array) -> void:
	var num := int(t.p.s.round.get("numero_azione", 0))
	for r in tab:
		if num >= int(r[0]) and num <= int(r[1]):
			t.esegui(int(r[2]))
			return

## Bersagli a bordo dei mezzi del convoglio (la priorità è sempre il mezzo, poi il soldato).
func _su_mezzi(g: Dictionary) -> Array:
	return t.bersagli(g).filter(func(a): return str(a.get("veicolo", "")) != "")

func _piu_vicino20(g: Dictionary, lista: Array) -> Dictionary:
	var m := {}
	for a in lista:
		if m.is_empty() or E.distanza(a.hex, g.hex) < E.distanza(m.hex, g.hex):
			m = a
	return m

func _granata_mezzo(g: Dictionary, lista: Array) -> bool:
	if int(g.munizioni.get("granata", 0)) <= 0:
		return false
	var b := _piu_vicino20(g, lista)
	if b.is_empty():
		return false
	var d := E.distanza(b.hex, g.hex)
	if d > 6:
		return false
	if d <= 3:
		t._accovacciati()
	else:
		t._alzati()
	if t.p.probabilita_lancio(g, "granata", b.hex).ok:
		t.p.risolvi_lancio(g, "granata", b.hex)
		t._prono_se_libero()
		return true
	return false

func _verso_americano(g: Dictionary, spara: bool) -> void:
	var b := _piu_vicino20(g, t.p.americani_attivi_in_mappa())
	if b.is_empty():
		t._accovacciati()
		return
	t._corri_verso(b.hex)
	if spara and t.p.attivo(g) and not t.bersagli(g).is_empty():
		g._snap_forzato = true
		t._miglior_tiro("facile")

## 352, 106, 114: prima i mezzi (granata o tiro), poi i soldati.
func _contro_mezzi(g: Dictionary, n: int) -> void:
	var mezzi := _su_mezzi(g)
	if not mezzi.is_empty():
		if _granata_mezzo(g, mezzi):
			return
		t._accovacciati()
		t._miglior_tiro("vicino")
		t._prono_se_libero()
		return
	if not t.bersagli(g).is_empty():
		t._accovacciati()
		t._miglior_tiro("vicino" if n == 352 else "facile")
		t._prono_se_libero()
		return
	_verso_americano(g, n != 114)

func ss_esce(g: Dictionary) -> void:
	var p = t.p
	p.ss.m20._togli(g, 0, "")
	p._pv(-1, "tedesco uscito")
	p._log("tedesco", "Il %s esce dalla mappa." % p.nome(g))

## 208/209 (reazioni P e Q): panzerfaust contro un mezzo americano entro 3 esagoni, poi la tabella.
func _panzerfaust22(g: Dictionary, n: int) -> void:
	var p = t.p
	var pzf: Dictionary = p.arma_di(g, "pzf")
	if pzf.is_empty() or pzf.get("scarica", false) or pzf.get("usata", false):
		g.reazione = ""
		t._ritira_e_esegui()
		return
	var mezzi: Array = p.veicoli.tutti().filter(func(v): return v.lato == "us" and p.veicoli.attivo(v) and str(v.hex) != "" \
		and E.distanza(v.hex, g.hex) <= 3 and p.terreno.vede(g.hex, v.hex, "crouching", "standing"))
	if not mezzi.is_empty():
		mezzi.sort_custom(func(a, b): return E.distanza(a.hex, g.hex) < E.distanza(b.hex, g.hex))
		var occ: Array = p.veicoli.occupanti(mezzi[0])
		if not occ.is_empty():
			t._accovacciati()
			pzf.usata = true
			p._log("tedesco", "Il %s spara il panzerfaust contro %s." % [p.nome(g), str(mezzi[0].nome).to_lower()])
			p.risolvi_tiro(g, pzf, occ[0], true)
			t._prono_se_libero()
			return
	var num := int(p.s.round.get("numero_azione", 0))
	var tab: Array = [[0, 0, 840], [1, 4, 802], [5, 7, 825], [8, 9, 869]] if n == 208 else [[0, 0, 869], [1, 2, 824], [3, 4, 825], [5, 9, 802]]
	for r in tab:
		if num >= int(r[0]) and num <= int(r[1]):
			t.esegui(int(r[2]))
			return

func _esegui20(g: Dictionary, n: int) -> bool:
	var p = t.p
	var m20 = p.ss.m20
	match n:
		352, 106, 114:
			_contro_mezzi(g, n)
		115, 241:
			var mezzi: Array = m20.mezzi_attivi()
			var sotto: Array = mezzi.filter(func(v): return v.hex == g.hex)
			var adiac: Array = mezzi.filter(func(v): return E.distanza(v.hex, g.hex) == 1)
			if int(g.munizioni.get("granata", 0)) > 0 and g.hex == "U13" and not sotto.is_empty():
				g.postura = "standing"
				p._log("tedesco", "Il %s si sporge dalla finestra e lascia cadere una granata sul mezzo sotto." % p.nome(g))
				g.munizioni.granata = int(g.munizioni.granata) - 1
				p.ss.m20.esplosione("granata", g.hex)
				t._prono_se_libero()
			elif int(g.munizioni.get("granata", 0)) > 0 and not adiac.is_empty():
				adiac.sort_custom(func(a, b): return (E.colonna(a.hex) > E.colonna(b.hex)) if n == 115 else (E.colonna(a.hex) < E.colonna(b.hex)))
				t._accovacciati()
				if p.probabilita_lancio(g, "granata", adiac[0].hex).ok:
					p.risolvi_lancio(g, "granata", adiac[0].hex)
				t._prono_se_libero()
			elif int(g.munizioni.get("granata", 0)) <= 0 and not t.bersagli(g).filter(func(a): return a.hex != g.hex).is_empty():
				t._accovacciati()
				t._miglior_tiro("vicino")
				t._prono_se_libero()
			elif t.bersagli(g).is_empty() and _piu_vicino20(g, p.americani_attivi_in_mappa()).is_empty() \
					or (t.bersagli(g).is_empty() and E.distanza(_piu_vicino20(g, p.americani_attivi_in_mappa()).hex, g.hex) > 3):
				if n == 115:
					m20._togli(g, 0, "")
				else:
					g.reazione = "M"
					p._log("tedesco", "Il %s passa alla reazione speciale M." % p.nome(g))
			else:
				t._accovacciati()
		132:
			if not t.bersagli(g).is_empty():
				_per_numero20([[0, 3, 815], [4, 4, 840], [5, 6, 841], [7, 9, 770]])
			elif int(p.s.condizione) == 1:
				t._accovacciati()
			elif int(p.s.condizione) == 2:
				_verso_americano(g, false)
			else:
				m20._togli(g, 0, "")
		139:
			if t.bersagli(g).is_empty():
				_verso_americano(g, false)
			else:
				_per_numero20([[0, 1, 815], [2, 2, 840], [3, 6, 770], [7, 9, 841]])
		462:
			if t.bersagli(g).is_empty():
				var tutti_est := true
				for a in p.americani_attivi_in_mappa():
					if E.colonna(a.hex) <= 13:
						tutti_est = false
				if tutti_est:
					m20._togli(g, 1, "tiratore scelto uscito dalla mappa")
				elif not t._lancia_granata(6):
					t._accovacciati()
			else:
				_per_numero20([[0, 3, 802], [4, 6, 808], [7, 8, 824], [9, 9, 800]])
		466, 467:
			if t.bersagli(g).is_empty() and g.hex == "Q9":
				t._alzati()
				t._passo("R8", false)
				t._accovacciati()
				t._miglior_tiro("facile" if n == 466 else "vicino")
			elif t.bersagli(g).is_empty() and m20.passati_tutti("W6"):
				m20._togli(g, 1, "mitragliere uscito dalla mappa")
			elif n == 466:
				_per_numero20([[0, 0, 843], [1, 3, 841], [4, 6, 815], [7, 9, 770]])
			else:
				_per_numero20([[0, 3, 841], [4, 4, 843], [5, 8, 815], [9, 9, 770]])
		549:
			var stesso: Array = p.unita_in(g.hex, "us")
			var visti: Array = t.bersagli(g)
			if not stesso.is_empty():
				t._assalta(t._bersaglio_assalto())
			elif not visti.filter(func(a): return E.distanza(a.hex, g.hex) == 1).is_empty():
				t._accovacciati()
				t._miglior_tiro("facile")
				t._prono_se_libero()
			elif int(g.munizioni.get("granata", 0)) > 0 and not p.americani_attivi_in_mappa().filter(func(a): return E.distanza(a.hex, g.hex) in [2, 3]).is_empty():
				t._accovacciati()
				t._lancia_granata(3)
				t._prono_se_libero()
			elif int(g.munizioni.get("granata", 0)) > 0 and not visti.filter(func(a): return E.distanza(a.hex, g.hex) in [4, 5, 6]).is_empty():
				t._alzati()
				t._lancia_granata(6)
				t._prono_se_libero()
			elif not visti.filter(func(a): return E.distanza(a.hex, g.hex) in [4, 5, 6]).is_empty():
				t._accovacciati()
				t._miglior_tiro("vicino")
				t._prono_se_libero()
			else:
				var num := int(p.s.round.get("numero_azione", 0))
				var idx: int = [471, 472, 473].find(int(g.num))
				var tab: Array = [[502, 503, 504], [503, 504, 502], [504, 502, 503]]
				var riga := 0 if num <= 2 else (1 if num <= 5 else 2)
				var par: int = tab[riga][maxi(idx, 0)]
				p._log("tedesco", "Il %s esegue il %d." % [p.nome(g), par])
				m20.mortaio_azione(g, par)
		502, 503, 504:
			m20.mortaio_azione(g, n)
		_:
			return false
	return true
