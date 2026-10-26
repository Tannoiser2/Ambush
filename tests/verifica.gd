extends SceneTree
## Verifiche puntuali del motore: linea di vista, alture della vittoria, costi di movimento, dati.
const E = preload("res://scripts/motore/esagoni.gd")
const PartitaScript = preload("res://scripts/motore/partita.gd")
var errori := 0

func controlla(cond: bool, msg: String) -> void:
	if not cond:
		errori += 1
		print("FALLITO: ", msg)

func _init() -> void:
	var p = PartitaScript.new()
	p.nuova(42)
	var t: Terreno = p.terreno
	# Geometria
	controlla(E.adiacenti("A1", "B1"), "A1-B1 adiacenti")
	controlla(E.adiacenti("B1", "C2"), "B1-C2 adiacenti")
	controlla(not E.adiacenti("A1", "B2"), "A1-B2 non adiacenti")
	controlla(E.distanza("T3", "P9") == 8, "esempio regola 9/1: T3–P9 distano 8, trovato %d" % E.distanza("T3", "P9"))
	# Alture: esagoni di livello 3 da cui si vede tutta la strada
	var strade: Array = p.esagoni_strada()
	var buoni: Array = []
	for h in E.tutti():
		if t.quota(h) != 3:
			continue
		var tutte := true
		for r in strade:
			if not t.vede(h, r):
				tutte = false
				break
		if tutte:
			buoni.append(h)
	print("Strade: ", strade.size(), " · alture con vista su tutta la strada: ", buoni)
	print("Alture obiettivo: ", p.alture_obiettivo())
	controlla(not p.alture_obiettivo().is_empty(), "esiste almeno un’altura obiettivo")
	# Vista bloccata da un bosco alla stessa quota
	print("A5 bosco: ", t.tipo("A5"), " · vista A4→A6: ", t.vista("A4", "A6"))
	# Edificio T8: dall’esterno non si vede attraverso i muri
	print("T8 da U8: ", t.vista("U8", "T8"), " · da T9 (porta): ", t.vista("T9", "T8"), " · da T7 (finestra) prono: ", t.vista("T7", "T8", "standing", "prone"))
	print("Costo J1→J2: ", t.costo_movimento("J1", "J2"), " · U8→T8 (muro): ", t.costo_movimento("U8", "T8"), " · T9→T8 (porta): ", t.costo_movimento("T9", "T8"))
	print("Ponte M12 da L11: ", t.costo_movimento("L11", "M12"), " · da M11 (sotto): ", t.costo_movimento("M11", "M12"))
	# Vittoria artificiale
	p.u("A").stato = "attivo"; p.u("A").hex = "T8"
	p.u("B").stato = "attivo"; p.u("B").hex = "K13"
	p.u("C").stato = "attivo"; p.u("C").hex = p.alture_obiettivo()[0]
	var v: Dictionary = p.condizioni_vittoria()
	print("Vittoria: ", v)
	controlla(v.ok, "condizioni di vittoria riconosciute")
	# Paragrafi: ogni rimando esiste
	for k in p.paragrafi:
		controlla(p.paragrafi[k].it.length() > 3, "testo del paragrafo %s" % k)
	print("Errori: ", errori)
	quit(1 if errori > 0 else 0)
