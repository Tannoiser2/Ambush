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
