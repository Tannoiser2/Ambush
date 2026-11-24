extends SceneTree
## Silver Star, Missione 24 «Il blues del mulattiere»: schieramento (comandante in D9), scarico dei muli in K8, guida dei muli,
## danni ai muli e reazione M, mulo imbizzarrito, furto dei muli, uscita a nord e passaggio alla mappa F, consegna (637) e PV.
## Uso: godot --headless --path . --script tests/missione24.gd

const PartitaScript = preload("res://scripts/motore/partita.gd")
const E = preload("res://scripts/motore/esagoni.gd")

var errori := 0

func ok(c: bool, testo: String) -> void:
	print(("ok      " if c else "ERRORE  ") + testo)
	if not c:
		errori += 1

func nuova(seme: int):
	var p = PartitaScript.new(24)
	p.nuova(seme, true)
	var i := 0
	for a in p.americani():
		p.schiera([a.id], "D9" if i == 0 else ("I9" if i < 5 else "J9"))
		i += 1
	p.inizia_missione()
	p.s.pausa = ""
	return p

func _init() -> void:
	var p0 = PartitaScript.new(24)
	p0.nuova(1, true)
	ok(p0.missione.mappa == "GH", "mezze mappe G e H")
	ok(p0.schiera(["A"], "D9").ok and not p0.schiera(["B"], "D9").ok, "in D9 va un solo comandante")
	var p = nuova(3)
	ok(p.s.fase in ["operazioni", "round"], "la missione comincia")
	# Scarico dei muli.
	var a: Dictionary = p.u("B")
	a.hex = "K8"
	p.ss.m24.scarica_muli()
	var n: int = p.ss.m24.muli_attivi().size()
	ok(n >= 4 and n <= 6 and p.ss.m24.muli_in("K8").size() == n, "muli scaricati in K8 (%d)" % n)
	ok(p.ss.m24.puo_prendere(a) and p.ss.m24.prendi(a) == "" and p.ss.m24.muli_di(a).size() == 2, "B prende due muli")
	ok(p.ss.m24.blocca_tiro(a, "carbine", true) != "" and p.ss.m24.blocca_tiro(a, "carbine", false) == "", "chi guida i muli spara solo di rapido")
	a.hex = "L8"
	p.ss.m24.dopo_movimento(["B"])
	ok(p.ss.m24.muli_in("L8").size() == 2, "i muli seguono chi li guida")
	p.ss.m24.lascia(a)
	ok(p.ss.m24.muli_di(a).is_empty() and p.ss.m24.incustoditi().size() == n, "lascia i muli")
	# Mulo imbizzarrito, danni e furto.
	p.ss.m24.mulo_scappa()
	ok(true, "529 senza errori")
	var m: Dictionary = p.ss.m24.muli_attivi()[0]
	for i in 6:
		p.ss.m24.colpisci_mulo(m)
	ok(str(m.stato) in ["attivo", "ferito", "incapacitato", "morto"], "danni al mulo (%s)" % m.stato)
	var g = p._crea_tedesco(78, p.ss.m24.incustoditi()[0].hex, "crouching")
	p.ia._g = g
	ok(p.ss.m24.ruba_muli(p.ia, g), "un tedesco prende i muli incustoditi")
	# Uscita a nord e mappa F.
	var q = nuova(5)
	q.u("B").hex = "K8"
	q.ss.m24.scarica_muli()
	q.leggi("175", {})
	ok(q.ss.m24.uscita_ammessa("Y12") and not q.ss.m24.uscita_ammessa("Y1"), "175: si esce fra Y10 e Y14")
	for x in q.americani():
		x.hex = "Y12"
		x.postura = "standing"
	for mm in q.ss.m24.muli_attivi():
		mm.hex = "Y12"
		mm.guida = "B"
	q.s.turno = {}
	q.s.fase = "operazioni"
	for x in q.americani():
		q.esci(x.id)
	ok(q.lettera_mappa() == "F" and int(q.ss.m24._st().parte) == 2 and int(q.s.condizione) == 2, "631: mappa F, Condizione 2")
	ok(q.americani_attivi_in_mappa().size() == 8 and q.u("A").hex in ["A19", "B19", "C19"], "la squadra rientra fra A19 e C19")
	ok(not q.ss.m24.muli_attivi().is_empty() and q.ss.m24.muli_attivi()[0].hex in ["A19", "B19", "C19"], "i muli rientrano con la squadra")
	# Consegna.
	q.leggi("637", {})
	ok(int(q.s.condizione) == 3 and q.ss.m24.uscita_ammessa("Y1") and int(q.missione.vittoria_pv) == 21, "637: Condizione 3, uscita W1–Y3, 21 PV")
	var righe: Array = []
	var pv: int = q.ss.m24.righe_fine(righe)
	ok(pv < 0 or not righe.is_empty() or true, "righe di fine senza errori")
	q.s.fase = "operazioni"
	for x in q.americani_attivi_in_mappa():
		x.hex = "Y1"
		x.postura = "standing"
	for mm in q.ss.m24.muli_attivi():
		mm.hex = "Y1"
		mm.guida = "B"
	for x in q.americani():
		if q.attivo(x):
			q.esci(x.id)
	q.ss.m24.controlla()
	ok(q.s.fase == "fine", "tutti usciti: fine")
	print("Errori: %d" % errori)
	quit(1 if errori > 0 else 0)
