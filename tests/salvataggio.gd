extends SceneTree
## Una partita salvata e ricaricata (passando dal JSON, come nel browser) deve comportarsi
## come prima: stessi paragrafi per esagono, stesso livello di attivazione, nessun errore.
const E = preload("res://scripts/motore/esagoni.gd")

func _init() -> void:
	var errori := 0
	var p := Partita.new()
	p.nuova(11)
	p.muovi(["A", "B", "C"], "E1")
	for cond in [1, 2, 3, 4]:
		p.s.condizione = cond
		var testo := JSON.stringify(p.salva())
		var q := Partita.new()
		var ok: bool = q.carica(JSON.parse_string(testo))
		var diversi: Array = []
		for h in E.tutti():
			if q.riferimento(h) != p.riferimento(h):
				diversi.append("%s: «%s» invece di «%s»" % [h, q.riferimento(h), p.riferimento(h)])
		var uguali: bool = ok and diversi.is_empty() and q.livello_attivazione() == p.livello_attivazione() \
			and typeof(q.s.condizione) == TYPE_INT and typeof(q.u("A").turni) == TYPE_INT
		for n in range(0, 19):
			if q.riferimento_evento(n) != p.riferimento_evento(n):
				uguali = false
		# e muovendo dopo il caricamento non compaiono errori
		q._inizia_registrazione()
		q.controllo_paragrafo("D3", ["A"])
		var err: Array = q.recenti.filter(func(v): return v.t == "errore")
		var bene: bool = uguali and err.is_empty()
		print(("ok      " if bene else "ERRORE  ") + "Condizione %d dopo il caricamento%s%s" % [cond,
			"" if diversi.is_empty() else " — " + diversi[0], "" if err.is_empty() else " — " + str(err[0].x)])
		if not bene:
			errori += 1
	print("Errori: ", errori)
	quit(1 if errori > 0 else 0)
