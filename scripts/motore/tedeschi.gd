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

var mo: RefCounted
var ph: RefCounted
var ss: RefCounted

func _init(partita: Partita) -> void:
	p = partita
	mo = preload("res://scripts/motore/tedeschi_mo.gd").new(self)
	ph = preload("res://scripts/motore/tedeschi_ph.gd").new(self)
	ss = preload("res://scripts/motore/tedeschi_ss.gd").new(self)

# ------------------------------------------------------------------ turno
func turno(g: Dictionary, numero_tirato := false, casella := "") -> void:
	_g = g
	g.cambio_libero = not g.ferito
	_mp = p.effettivo_mpa(g)
	_fermo = false
	_reazione_cambiata = false
	if p.ss.attiva() and ss.turno(g):
		return
	if p.veicoli.turno_equipaggio(self, g):
		return
	if p.ph.attiva() and p.ph.berserk.turno_tedesco(self, g):
		return
	var col := colonna(g)
	var numero: int = int(p.s.round.numero_azione)
	var par := paragrafo_da_carta(g, col, numero)
	var motivo := "condizione"
	var dati_g: Dictionary = p.missione.tedeschi.get(str(int(g.num)), {})
	if dati_g.has("primo_turno") and not g.get("primo_fatto", false):
		g.primo_fatto = true
		par = int(dati_g.primo_turno)
		col = "primo"
		motivo = "primo turno"
	elif str(g.get("reazione", "")) != "" and dati_g.get("reazione_par", {}).has(str(g.reazione)) and col != "S":
		par = int(dati_g.reazione_par[str(g.reazione)])
		motivo = "reazione"
	if col == "S":
		motivo = "autoconservazione"
	elif col.length() == 1 and col >= "A" and col <= "Z":
		motivo = "reazione"
	p._passo("tedesco", {"id": g.id, "colonna": col, "numero": numero, "paragrafo": par, "motivo": motivo,
		"casella": casella, "numero_tirato": numero_tirato, "vede": bersagli(g).map(func(a): return a.id)})
	if numero_tirato:
		p._log("dado", "Numero d’azione tedesco: %d (vale per tutti i tedeschi di questo turno)." % numero)
	p._log("tedesco", "Turno del %s: colonna %s, numero d’azione %d → paragrafo %d." % [p.nome(g), _nome_colonna(col), numero, par])
	p._fx("attore", {"id": g.id, "a": g.hex})
	esegui(par)
	if _reazione_cambiata:
		# Una reazione speciale fa tirare un nuovo numero d’azione per i tedeschi che devono ancora agire.
		p.s.round.numero_azione = p.d10()
		p._log("dado", "Reazione speciale: nuovo numero d’azione tedesco %d." % int(p.s.round.numero_azione))

func _nome_colonna(c: String) -> String:
	if c == "primo":
		return "primo turno (indicato sulla carta)"
	if c == "S":
		return "autoconservazione (S)"
	if c.length() == 1 and c >= "A" and c <= "Z":
		return "reazione speciale " + c
	return "Condizione " + c

## Colonna da usare: autoconservazione se adiacente a un americano attivo, poi reazione speciale, poi Condizione.
func colonna(g: Dictionary, ignora_s := false) -> String:
	var colonne: Dictionary = p.missione.tedeschi[str(int(g.num))].colonne
	if str(g.get("reazione_fissa", "")) != "":
		g.reazione = str(g.reazione_fissa)  # Purple Heart 648: reazione speciale fino alla fine della missione
	if g.get("solo_S", false):
		return "S"
	if int(g.get("paracadute", 0)) > 0:
		ignora_s = true
	if bool(p.missione.tedeschi[str(int(g.num))].get("ignora_s_veicolo", false)) and str(g.get("veicolo", "")) != "" and p.veicoli.attivo(p.veicoli.di(g)):
		ignora_s = true  # Purple Heart: «ignora l’autoconservazione a bordo di un mezzo attivo»  # Move Out! 426: col paracadute addosso si ignora l’autoconservazione
	if not ignora_s and not g.no_auto and _vicino_ad_americani(g) and colonne.has("S"):
		return "S"
	var r: String = g.get("reazione", "")
	if r != "" and colonne.has(r):
		return r
	var c := int(p.s.condizione)
	for k in colonne:
		if not str(k).substr(0, 1).is_valid_int():
			continue
		if "," in str(k):
			# Move Out!: colonne per Condizioni sparse («1,2,4»).
			if str(c) in str(k).split(","):
				return k
			continue
		var parti: PackedStringArray = str(k).split("-")
		var lo := int(parti[0])
		var hi := int(parti[parti.size() - 1])
		if c >= lo and c <= hi:
			return k
	# Condizione senza colonna (es. Condizione 1): si usa la prima colonna di Condizione disponibile.
	for k in colonne:
		if str(k).substr(0, 1).is_valid_int():
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
	var chiave := "%03d" % n
	if n != 816 and p.paragrafi.has(chiave):
		p._log("par", p.paragrafi[chiave].it, {"id": chiave, "tedesco": g.id})
	if p.mo.attiva() and mo.esegui(n):
		return
	if p.ph.attiva() and ph.esegui(n):
		return
	if p.ss.attiva() and ss.esegui(n):
		return
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
			var nuovo_par := paragrafo_da_carta(g, col, nuovo)
			if nuovo_par == 816:
				p._log("tedesco", "La carta del %s non dà un’azione per questa colonna: non fa nulla." % p.nome(g))
			else:
				esegui(nuovo_par)
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
		812:
			if not p.unita_in(g.hex, "us").is_empty():
				_assalta(_bersaglio_assalto())
			elif _americano_adiacente() and int(g.munizioni.get("granata", 0)) > 0:
				if p.unita_in(g.hex, "de").size() > 1:
					_assalta(_bersaglio_assalto(), true)
				else:
					_accovacciati()
					_granata_adiacente()
			elif not bersagli(g).filter(func(a): return p.unita_in(a.hex, "de").is_empty()).is_empty():
				_accovacciati()
				_miglior_tiro("facile")
			else:
				_muovi_e_spara()
		834:
			var con_veicolo := false
			for vv in p.veicoli.tutti():
				if vv.lato == "de" and vv.hex == g.hex and p.veicoli.attivo(vv):
					con_veicolo = true
			if con_veicolo:
				_accovacciati()
				_miglior_tiro("facile")
				_prono_se_libero()
			else:
				esegui(808)
		858:
			var v := bersagli(g)
			if v.is_empty():
				_accovacciati()
			elif v.size() >= 3:
				_prono()
			elif p.terreno.edificio(g.hex):
				_alzati()
				_miglior_tiro("facile")
				_prono_se_libero()
			else:
				_accovacciati()
				_miglior_tiro("facile")
				_prono_se_libero()
		860:
			if p.terreno.edificio(g.hex):
				_alzati()
				_tiri_rapidi()
				_prono_se_libero()
			else:
				_accovacciati()
				_tiri_rapidi()
		862:
			var v := bersagli(g)
			if v.is_empty():
				_muovi_rapido(false)
			elif p.terreno.scoperto(g.hex):
				_muovi_rapido(false)
				_prono_fine_movimento()
			else:
				_accovacciati()
				_miglior_tiro("facile")
		863:
			var v := bersagli(g)
			if v.is_empty():
				_muovi_rapido(false)
			elif p.terreno.scoperto(g.hex):
				_muovi_rapido(false, true)
				_prono_fine_movimento()
			else:
				esegui(869)
		864:
			var v := bersagli(g)
			if v.is_empty():
				_muovi_rapido(false)
			else:
				_alzati()
				var scelta := _scegli_bersaglio("vicino", -1, false, false)
				if not scelta.is_empty():
					p.risolvi_tiro(g, scelta[1], scelta[0], false)
				if p.in_mappa(g) and p.attivo(g):
					_mp = int(p.effettivo_mpa(g) / 2)
					_muovi_rapido(false)
					_prono_se_libero()
		869:
			if int(g.munizioni.get("granata", 0)) > 0 and _bersagli_entro(3):
				_alzati()
				if _lancia_granata(3):
					_prono_se_libero()
				else:
					esegui(801)
			else:
				esegui(801)
		60:
			var saltato := false
			for hp in ["G14", "G13"]:
				if p.ponte_intatto(hp) and not p.ponte_stato(hp).get("catturato", false) and not _tedeschi_attivi_vicino(hp):
					p._log("par", p.paragrafi["565"].it, {"id": "565", "tedesco": g.id})
					p.distruggi_ponte(hp, "interruttore segreto")
					for v in E.vicini(hp):
						for x in p.unita_in(v, ""):
							p._danno_esplosione(x, T.GRANATA_FUORI)
					saltato = true
					break
			if not saltato:
				esegui(858)
		716:
			var g63 := p.u("g63")
			var g83 := p.u("g83")
			if not g63.is_empty() and not g83.is_empty() and not p.attivo(g63) and not p.attivo(g83):
				_arrenditi()
			else:
				esegui(802)
		732:
			var coppia: Array = [20, 21] if E.distanza(g.hex, "H15") <= E.distanza(g.hex, "S13") else [65, 66]
			var inattivi := 0
			var arma_mg := {}
			for num in coppia:
				var m := p.u("g%d" % num)
				if m.is_empty() or not p.attivo(m):
					inattivi += 1
					if not m.is_empty() and m.hex == g.hex:
						for w in m.armi:
							if w.tipo in ["lmg", "mmg", "hmg"]:
								arma_mg = w
			if inattivi == 1 and not arma_mg.is_empty():
				for num in coppia:
					var m := p.u("g%d" % num)
					if not m.is_empty() and not p.attivo(m):
						m.armi.erase(arma_mg)
				g.armi.append(arma_mg)
				p._log("tedesco", "Il %s prende la mitragliatrice del bunker." % p.nome(g))
				esegui(815)
			elif inattivi == 1:
				esegui(815)
			else:
				esegui(802)
		770:
			var migliore := ""
			var quanti := 0
			for a in p.americani_attivi_in_mappa():
				var d := E.distanza(a.hex, g.hex)
				if d >= 1 and d <= 3:
					var n_h := p.unita_in(a.hex, "us").size()
					if n_h > quanti or (n_h == quanti and migliore != "" and d < E.distanza(migliore, g.hex)):
						quanti = n_h
						migliore = a.hex
			if migliore != "" and int(g.munizioni.get("granata", 0)) > 0 and _alzati() and p.probabilita_lancio(g, "granata", migliore).ok:
				p.risolvi_lancio(g, "granata", migliore)
			else:
				_alzati()
				_miglior_tiro("vicino")
		841:
			esegui(800 if bersagli(g).size() >= 3 else 815)
		842:
			_accovacciati()
			var sc := _scegli_bersaglio("vicino", -1, false, false)
			if not sc.is_empty():
				p.risolvi_tiro(g, sc[1], sc[0], false)
			if p.in_mappa(g):
				_prono_fine_movimento()
		843:
			if p.unita_in(g.hex, "de").size() <= 1 and bersagli(g).size() > 1:
				_arrenditi()
			else:
				esegui(815)
		844:
			var est := false
			for a in bersagli(g):
				if E.colonna(a.hex) < 12:
					est = true
			if not est:
				_corri_verso("N6")
				g.reazione = "D"
		926:
			_accovacciati()
			_tiri_rapidi()
			p.leggi("507", {"g": g.id, "hex": g.hex})
		927:
			_prono()
			p.leggi("507", {"g": g.id, "hex": g.hex})
		928:
			if not _tedesco_vicino(1) and bersagli(g).is_empty():
				_muovi_rapido(false)
				g.reazione = "A"
			else:
				esegui(801)
		929:
			if p.terreno.edificio(g.hex):
				esegui(930)
			else:
				_prono()
		930:
			_accovacciati()
			if bersagli(g).is_empty() and p.ponte_intatto("M12") and E.adiacenti(g.hex, "L12"):
				_alzati()
				_passo("L12", false)
				g.reazione = "B"
			elif bersagli(g).is_empty() and E.adiacenti(g.hex, "L13"):
				_corri_verso("K14")
				g.reazione = "B"
			else:
				esegui(802)
		931:
			if bersagli(g).size() >= 3:
				_corri_verso("N6")
				g.rimuovi_fine_round = true
		932:
			if p.terreno.tipo(g.hex) == "woods":
				esegui(844)
			elif p.terreno.edificio(g.hex):
				esegui(802)
		911:
			esegui(824 if g.hex == "J13" else 803)
		912:
			esegui(824 if g.hex in ["E11", "K7"] else 803)
		806:
			_corri_o_striscia(false, true)
			g.rimuovi_fine_round = true
		807:
			if not bersagli(g).is_empty():
				_accovacciati()
				_miglior_tiro("facile")
				_prono_se_libero()
			else:
				_corri_o_striscia(false)
				_prono_se_libero()
		810:
			if not bersagli(g).is_empty():
				_accovacciati()
				_miglior_tiro("facile")
			else:
				_prendi_arma_vicina()
				_accovacciati()
		811:
			if not bersagli(g).is_empty():
				_arrenditi()
			else:
				_prono()
		840:
			p._log("tedesco", "Il %s non fa nulla." % p.nome(g))
		974:
			g.reazione = "B"
			_prono_fine_movimento()
		977:
			p._log("tedesco", "Il %s usa la radio." % p.nome(g))
			p.cambia_condizione(3)
		993:
			esegui(977 if int(p.s.condizione) <= 2 else 839)
		642:
			var vg: Dictionary = p.veicoli.di(g)
			if p.veicoli.attivo(vg):
				p.veicoli.guida_tedesca(vg, not bersagli(g).is_empty())
		34:
			_auto_raccoglie([7], "X", ["P7", "Q6"])
		459:
			_auto_raccoglie([24, 42], "Q", ["T15", "R14"])
		630:
			_sali_su_auto("S14", "S15")
		972:
			_sali_su_auto("P5", "P6")
		649:
			var vg: Dictionary = p.veicoli.di(g)
			if p.veicoli.attivo(vg) and p.veicoli.autista(vg).get("id", "") != g.id:
				esegui(832)
			elif p.veicoli.attivo(vg):
				p.veicoli.guida_tedesca(vg, true)
			else:
				_reazione_e_rilancia("U")
		814, 826, 827, 828:
			var vg: Dictionary = p.veicoli.di(g)
			if p.veicoli.attivo(vg):
				var veloce: bool = n in [827, 828] or (n == 826 and bool(vg.get("bersagliato", false)))
				p.veicoli.guida_tedesca(vg, veloce)
			else:
				p._log("tedesco", "Il %s non è su un veicolo: resta fermo." % p.nome(g))
		50:
			p.cambia_condizione(4)
			esegui(868)
		55:
			var vg: Dictionary = p.veicoli.di(g)
			if p.veicoli.attivo(vg):
				p.veicoli.guida_tedesca(vg, true)
			else:
				_reazione_e_rilancia("U")
		470:
			_op_470()
		554:
			var vg: Dictionary = p.veicoli.di(g)
			if p.veicoli.attivo(vg) and p.attivo(p.veicoli.autista(vg)) and p.veicoli.autista(vg).id != g.id:
				_miglior_tiro("facile")
			elif p.veicoli.attivo(vg):
				g.reazione = "T"
				p._log("tedesco", "Reazione speciale T in vigore per il %s: in questo turno non agisce." % p.nome(g))
			else:
				_reazione_e_rilancia("U")
		708:
			if int(p.s.condizione) >= 4:
				g.reazione = ""
				p._log("tedesco", "Il %s torna a seguire la Condizione in vigore." % p.nome(g))
				esegui(paragrafo_da_carta(g, colonna(g, true), int(p.s.round.get("numero_azione", 0))))
			else:
				esegui(802)
		711:
			if p.unita_in(g.hex, "us").size() >= 2:
				_arrenditi()
			else:
				_alzati()
				_miglior_tiro("vicino")
				_prono_se_libero()
		712:
			if _tedesco_vicino(1):
				_accovacciati()
				if not _cedi_turno(1):
					_prono()
			else:
				esegui(801)
		856, 857:
			if p.terreno.edificio(g.hex):
				_alzati()
			else:
				_accovacciati()
			_miglior_tiro("facile" if n == 856 else "vicino")
			_prono_se_libero()
		859:
			if not p.unita_in(g.hex, "us").is_empty():
				_assalta(_bersaglio_assalto())
			elif p.terreno.edificio(g.hex):
				_alzati()
				_miglior_tiro("vicino")
				_prono_se_libero()
			else:
				_accovacciati()
				_miglior_tiro("vicino")
		865:
			var v := bersagli(g)
			if v.is_empty():
				_muovi_rapido(false)
			elif v.size() <= 2:
				_accovacciati()
				_miglior_tiro("vicino")
			else:
				_prono()
		866:
			var v := bersagli(g)
			if v.is_empty():
				_muovi_rapido(false)
			elif v.size() <= 2:
				_muovi_rapido(false, true)
				_prono_fine_movimento()
			else:
				_accovacciati()
				_tiri_rapidi()
		868:
			_muovi_rapido(false)
			if not bersagli(g).is_empty():
				_prono_se_libero()
		817:
			var adiac := _americano_adiacente()
			if adiac and int(g.munizioni.get("granata", 0)) > 0:
				esegui(818)
			elif bersagli(g).is_empty():
				_accovacciati()
			elif _ha_munizioni():
				_accovacciati()
				_miglior_tiro("vicino")
			elif int(g.munizioni.get("granata", 0)) > 0:
				esegui(818)
			else:
				_arrenditi()
		818:
			_accovacciati()
			if not _lancia_granata(6):
				pass
			_prono_se_libero()
		819:
			if int(g.munizioni.get("granata", 0)) > 0 and _lancia_granata(6):
				_prono_se_libero()
			else:
				_corri_o_striscia(false)
		820:
			if bersagli(g).is_empty():
				_corri_o_striscia(false)
			elif _tedesco_vicino(1):
				_prono()
			else:
				_arrenditi()
		821:
			if not bersagli(g).is_empty():
				_prono()
			else:
				_corri_o_striscia(false)
		822:
			if not _cedi_turno(1):
				if _tutti_due_turni(1):
					esegui(801)
				else:
					_corri_o_striscia(false)
		867:
			_muovi_rapido(false, not bersagli(g).is_empty())
			if not bersagli(g).is_empty():
				_prono()
		950:
			if _attivo_num(2):
				esegui(802)
			elif _bersagli_da_porta():
				_accovacciati()
				g._snap_forzato = true
				_miglior_tiro("vicino")
			else:
				if _corri_verso("K15"):
					_prono()
					g.reazione = "K"
					_reazione_cambiata = true
		951:
			if not p.in_vista_americani(g):
				rimuovi_evasivo(g)
			elif g.hex == "N13":
				_prono()
			else:
				_corri_o_striscia(false, false, true)
				_prono_se_libero()
		952:
			esegui(953 if g.get("bersagliato", false) else 806)
		953:
			if not bersagli(g).is_empty():
				_accovacciati()
				_miglior_tiro("facile")
				_prono_se_libero()
			else:
				esegui(806)
		954:
			_accovacciati()
			_miglior_tiro("facile")
			_prono_se_libero()
			if g.hex == "K7" and _bersaglio_verso_est():
				g.reazione = "A"
				_reazione_cambiata = true
		955:
			if int(g.get("bersagliato_da", []).size()) > 2 or g.get("granata_subita", false):
				g.reazione = "A"
				_reazione_cambiata = true
				_ritira_e_esegui()
			else:
				esegui(801)
		956:
			if _attivo_num(10):
				esegui(802)
			else:
				g.reazione = "A"
				_reazione_cambiata = true
				_ritira_e_esegui()
		957:
			if _bersagli_da_porta():
				_accovacciati()
				_miglior_tiro("facile")
			else:
				_corri_o_striscia(false)
			g.reazione = "D"
			_reazione_cambiata = true
		958:
			if _bersagli_da_porta():
				_accovacciati()
				_miglior_tiro("facile")
			else:
				if _corri_verso("L6"):
					_prono()
				g.reazione = "B"
				_reazione_cambiata = true
		959:
			if _bersagli_entro(3):
				_accovacciati()
				_miglior_tiro("vicino", 3, false, "pistol")
				_prono_se_libero()
			else:
				esegui(815)
		960, 961:
			var compagno := 49 if n == 960 else 5
			if not _attivo_num(compagno) and bersagli(g).is_empty():
				_corri_o_striscia(false, false, true)
				g.reazione = "E" if n == 960 else "F"
				_reazione_cambiata = true
			else:
				_prono()
		962:
			if not _attivo_num(49) and not bersagli(g).is_empty():
				_arrenditi()
			else:
				esegui(815)
		963, 964:
			var da: String = g.hex
			_corri_o_striscia(false)
			var speciale := "K7" if n == 963 else "J13"
			g.reazione = ("A" if da == speciale else "B") if n == 963 else ("K" if da == speciale else "D")
			_reazione_cambiata = true
		966:
			esegui(815 if g.hex == "N12" else 813)
		967:
			esegui(815 if g.hex == "N12" else 820)
		968:
			esegui(815 if g.hex == "N12" else 818)
		969:
			if _bersagli_entro(7):
				_accovacciati()
				_miglior_tiro("facile", 7)
				_prono_se_libero()
			else:
				esegui(822)
		970:
			var soli := true
			for k in [37, 50]:
				var x := p.u("g%d" % k)
				if x.is_empty() or not p.attivo(x) or x.hex != g.hex:
					soli = false
			if not soli:
				_corri_o_striscia(false, false, true)
			else:
				esegui(801)
		_:
			p._log("errore", "Paragrafo d’azione %d non gestito: il tedesco resta fermo." % n)

# ------------------------------------------------------------------ aiuti per i paragrafi d’azione
func _attivo_num(num: int) -> bool:
	var x := p.u("g%d" % num)
	return not x.is_empty() and p.attivo(x)

func _tedesco_vicino(raggio: int) -> bool:
	for x in p.tedeschi_attivi():
		if x.id != _g.id and E.distanza(x.hex, _g.hex) <= raggio:
			return true
	return false

func _americano_adiacente() -> bool:
	for a in p.americani_attivi_in_mappa():
		if E.adiacenti(a.hex, _g.hex):
			return true
	return false

func _ha_munizioni() -> bool:
	for a in _g.armi:
		if not a.rotta and not a.get("scarica", false):
			return true
	return false

## Bersagli visibili attraverso una porta dell’edificio in cui si trova il tedesco.
func _bersagli_da_porta() -> bool:
	var g := _g
	if not p.terreno.edificio(g.hex):
		return not bersagli(g).is_empty()
	for b in bersagli(g):
		for n in p.terreno._lato_di_uscita(g.hex, b.hex):
			if p.terreno.tipo_lato(g.hex, n) == "door":
				return true
	return false

## Bersaglio visibile verso est (finestra est dell’edificio K7).
func _bersaglio_verso_est() -> bool:
	for b in bersagli(_g):
		if E.colonna(b.hex) > E.colonna(_g.hex):
			return true
	return false

## Corre verso un esagono vicino (paragrafo che indica la destinazione); true se ci arriva.
func _corri_verso(h: String) -> bool:
	var passi := 0
	while _g.hex != h and passi < 6 and p.in_mappa(_g):
		passi += 1
		var migliore := ""
		for n in E.vicini(_g.hex):
			if E.distanza(n, h) < E.distanza(_g.hex, h) and p.terreno.costo_movimento(_g.hex, n) >= 0:
				migliore = n
				break
		if migliore == "" or not _alzati() or not _passo(migliore, false):
			return _g.hex == h
	return _g.hex == h

## Ritira il numero d’azione per questo tedesco ed esegue il nuovo paragrafo (reazione speciale).
func _ritira_e_esegui() -> void:
	var nuovo := p.d10()
	p._log("dado", "Nuovo numero d’azione per il %s: %d" % [p.nome(_g), nuovo])
	esegui(paragrafo_da_carta(_g, colonna(_g, true), nuovo))

## Granata al bersaglio più vicino entro il raggio; false se non c’è un bersaglio valido.
func _lancia_granata(raggio: int) -> bool:
	var g := _g
	if int(g.munizioni.get("granata", 0)) <= 0:
		return false
	var lista: Array = p.americani_attivi_in_mappa().filter(func(a): return a.hex != g.hex and E.distanza(a.hex, g.hex) <= raggio)
	lista.sort_custom(func(a, b): return E.distanza(a.hex, g.hex) < E.distanza(b.hex, g.hex))
	for a in lista:
		if p.probabilita_lancio(g, "granata", a.hex).ok:
			p.risolvi_lancio(g, "granata", a.hex)
			return true
	return false

## 810: raccoglie l’arma di un soldato fuori combattimento entro 2 esagoni (se non vede bersagli).
func _prendi_arma_vicina() -> void:
	var g := _g
	for x in p.s.unita.values():
		if x.hex == "" or not (x.stato in ["morto", "incapacitato"]) or E.distanza(x.hex, g.hex) > 2:
			continue
		for a in x.armi:
			if not a.rotta and not (a.tipo in g.armi.map(func(w): return w.tipo)):
				x.armi.erase(a)
				a.catturata = x.lato != "de"
				g.armi.append(a)
				p._log("tedesco", "Il %s raccoglie l’arma (%s) di %s." % [p.nome(g), T.ARMI[a.tipo].nome.to_lower(), p.nome(x)])
				return

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
	if bool(T.ARMI[scelta[1].tipo].get("squadra", false)) and mirato:
		var servente := false
		for x in p.unita_in(g.hex, "de"):
			if x.id != g.id:
				servente = true
		if not servente:
			mirato = false
			p._log("tedesco", "Senza servente la mitragliatrice spara solo di rapido.")
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
	if p.piano(g) > 0:
		# Dal piano superiore si scende prima la scala (1 PM).
		if _mp < 1 or strisciando:
			return false
		_mp -= 1
		g.piano = 0
		p._log("tedesco", "Il %s scende le scale in %s." % [p.nome(g), g.hex])
	if strisciando:
		if not p.terreno.strisciare_possibile(g.hex, verso):
			return false
		_mp = 0
	else:
		if costo > _mp:
			return false
		_mp -= costo
	var da_hex: String = g.hex
	g.hex_prec = da_hex
	g.hex = verso
	p.segna_passaggio_ponte(da_hex, verso)
	g.sul_ponte = p.terreno.ponte(verso) and da_hex in p.terreno.capi_ponte(verso)
	p._log("tedesco", "Il %s %s in %s." % [p.nome(g), "striscia" if strisciando else "corre", verso])
	p._fx("muovi", {"ids": [g.id], "da": da_hex, "a": verso, "strisciando": strisciando})
	if p.ph.in_fiamme(verso):
		var rif: String = _riferimento(verso)
		p.ph.attraversa_fiamme(g, da_hex, rif if E.valido(rif) else "")
		_mp = 0
		_fermo = true
		return false
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
		p.tedesco_uscito(g, da_u)
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

## Paragrafi 265 (gioco base) e 980 (Move Out!): il tedesco nel campanile di S13.
## Dal piano superiore scende; dal pianterreno sale ad assaltare un americano attivo di sopra; altrimenti entra in «altrimenti».
func scala(ctx: Dictionary, altrimenti: String) -> void:
	if _g.is_empty() or ctx.get("g", "") != _g.id:
		return
	var g := _g
	if p.piano(g) > 0:
		g.piano = 0
		p._log("tedesco", "Il %s scende al pianterreno di %s." % [p.nome(g), g.hex])
		_fermo = true
		return
	var sopra: Array = p.unita_in(g.hex, "us").filter(func(a): return p.piano(a) > 0)
	if p.terreno.ha_piani(g.hex) and not sopra.is_empty():
		g.piano = 1
		p._log("tedesco", "Il %s sale le scale di %s e carica." % [p.nome(g), g.hex])
		_fermo = true
		_assalta(sopra[p.rng.randi_range(0, sopra.size() - 1)], true)
		return
	entra_da_paragrafo(ctx, altrimenti)

func entra_da_paragrafo(ctx: Dictionary, h: String) -> void:
	if _g.is_empty() or ctx.get("g", "") != _g.id:
		return
	if not _passo(h, bool(ctx.get("strisciando", false))):
		# Senza punti sufficienti si entra comunque: il riferimento definisce la mossa.
		var da_h: String = _g.hex
		_g.hex_prec = da_h
		_g.hex = h
		p.segna_passaggio_ponte(da_h, h)
		p._log("tedesco", "Il %s entra in %s." % [p.nome(_g), h])
		p._fx("muovi", {"ids": [_g.id], "da": da_h, "a": h})

## Interrompe il movimento del tedesco di turno.
func ferma() -> void:
	_fermo = true
	_mp = 0

## «Tira un nuovo numero d’azione e applica l’azione indicata a questo tedesco» (254, 275).
func rilancia_azione(ctx: Dictionary) -> void:
	var g: Dictionary = p.u(ctx.get("g", ""))
	if g.is_empty() or g.id != _g.id or int(ctx.get("_rilanci", 0)) >= 2:
		return
	ctx._rilanci = int(ctx.get("_rilanci", 0)) + 1
	var numero := p.d10()
	if p.fase_round():
		p.s.round.numero_azione = numero
	_reazione_cambiata = false
	var col := colonna(g)
	var par := paragrafo_da_carta(g, col, numero)
	p._log("dado", "Nuovo numero d’azione tedesco: %d → colonna %s, paragrafo %d." % [numero, _nome_colonna(col), par])
	_mp = p.effettivo_mpa(g)
	_fermo = false
	esegui(par)

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

func _tedeschi_attivi_vicino(h: String) -> bool:
	for x in p.s.unita.values():
		if x.lato == "de" and p.attivo(x) and p.in_mappa(x) and E.distanza(x.hex, h) <= 1:
			return true
	return false

## Auto comando (Missione 5): passeggeri da raccogliere; poi via, con la reazione speciale C.
func _auto_raccoglie(nums: Array, reazione: String, primi: Array) -> void:
	var g := _g
	var vg: Dictionary = p.veicoli.di(g)
	var tutti_inattivi := true
	var fuori := false
	for num in nums:
		var x := p.u("g%d" % int(num))
		if not x.is_empty() and p.attivo(x):
			tutti_inattivi = false
			if x.get("veicolo", "") != vg.get("id", "-"):
				fuori = true
	if tutti_inattivi:
		g.reazione = ""
		p._log("tedesco", "Nessuno da raccogliere: il %s torna alla colonna delle Condizioni." % p.nome(g))
		_ritira_e_esegui()
	elif fuori:
		esegui(825)
	else:
		for num in nums + [13]:
			var x := p.u("g%d" % int(num))
			if not x.is_empty():
				x.reazione = "C"
		p._log("tedesco", "Tutti a bordo: l’auto comando riparte (reazione speciale C).")
		if p.veicoli.attivo(vg):
			var primo: String = primi[0] if str(p.s.get("ingresso_auto", "Y8")) == "Y8" else primi[1]
			if E.adiacenti(vg.hex, primo) and p.veicoli.costo(vg, vg.hex, primo) >= 0:
				p.veicoli.sposta(vg, primo)
				p._log("tedesco", "%s entra in %s." % [p.veicoli.nome_art(vg), primo])
			p.veicoli.guida_tedesca(vg, true)

## Un passeggero raggiunge l’auto comando strisciando e sale a bordo.
func _sali_su_auto(da: String, verso: String) -> void:
	var g := _g
	var vg: Dictionary = {}
	for v in p.veicoli.tutti():
		if v.modello == "auto_comando" and v.lato == "de":
			vg = v
	if g.get("veicolo", "") != "" and p.veicoli.attivo(p.veicoli.di(g)):
		var vv: Dictionary = p.veicoli.di(g)
		if not p.attivo(p.veicoli.autista(vv)) or p.veicoli.autista(vv).id == g.id:
			p.veicoli.guida_tedesca(vv, true)
		else:
			p._log("tedesco", "Il %s aspetta a bordo." % p.nome(g))
		return
	if vg.is_empty() or not p.veicoli.attivo(vg):
		esegui(832)
		return
	if g.hex == vg.hex:
		g.veicolo = vg.id
		if not (g.id in vg.occupanti):
			vg.occupanti.append(g.id)
		g.postura = "crouching"
		p._log("tedesco", "Il %s sale sull’auto comando." % p.nome(g))
	elif g.hex == da and E.adiacenti(da, verso):
		_accovacciati()
		_passo(verso, true)
	else:
		_corri_verso(vg.hex)

func _reazione_e_rilancia(r: String) -> void:
	_g.reazione = r
	p._log("tedesco", "Reazione speciale %s in vigore per il %s." % [r, p.nome(_g)])
	_ritira_e_esegui()

## 470: il generale (63) e l’aiutante (83) cercano di fuggire con la Kübelwagen nascosta.
func _op_470() -> void:
	var g := _g
	var vk: Dictionary = p.veicoli.v("vk")
	var in_auto: bool = not vk.is_empty() and g.get("veicolo", "") == "vk"
	var us_dentro: bool = not vk.is_empty() and not p.unita_in(vk.hex, "us").is_empty()
	if vk.is_empty() or not p.veicoli.attivo(vk) or us_dentro:
		g.reazione = "U"
		p._log("tedesco", "La Kübelwagen non è utilizzabile: reazione speciale U per il %s." % p.nome(g))
		if _alzati():
			_corri_verso("L4")
		return
	if not in_auto:
		if g.hex != vk.hex:
			_corri_verso(vk.hex)
		if g.hex == vk.hex and p.in_mappa(g):
			g.veicolo = "vk"
			if not (g.id in vk.occupanti):
				vk.occupanti.append(g.id)
			g.postura = "crouching"
			p._log("tedesco", "Il %s sale sulla Kübelwagen." % p.nome(g))
		return
	var g63 := p.u("g63")
	var g83 := p.u("g83")
	var a63: bool = not g63.is_empty() and p.attivo(g63) and g63.get("veicolo", "") == "vk"
	var a83: bool = not g83.is_empty() and p.attivo(g83) and g83.get("veicolo", "") == "vk"
	var i63: bool = g63.is_empty() or not p.attivo(g63)
	var i83: bool = g83.is_empty() or not p.attivo(g83)
	if a63 and a83:
		g63.reazione = "Q"
		g83.reazione = "Q"
		p._log("tedesco", "Generale e aiutante sono a bordo: reazione speciale Q per entrambi.")
		_ritira_e_esegui()
	elif a63 and i83 and g.id == "g63":
		_reazione_e_rilancia("T")
	elif a83 and i63 and g.id == "g83":
		_reazione_e_rilancia("Q")
	else:
		esegui(825)

## Prono alla fine del movimento, spendendo un punto movimento se serve.
func _prono_fine_movimento() -> void:
	var g := _g
	if not p.in_mappa(g) or g.postura == "prone":
		return
	if g.cambio_libero:
		g.cambio_libero = false
	elif _mp >= 1:
		_mp -= 1
	_set_postura("prone")

## «Muoviti e spara di rapido se compaiono bersagli durante il movimento».
func _muovi_e_spara() -> void:
	var g := _g
	if _riferimento(g.hex) == "":
		_nessun_riferimento()
		return
	if not _alzati():
		return
	var passi := 0
	while p.in_mappa(g) and passi < 12:
		passi += 1
		if not _segui_riferimento(_riferimento(g.hex), false):
			break
		if not bersagli(g).is_empty():
			var scelta := _scegli_bersaglio("vicino", -1, false, false)
			if not scelta.is_empty():
				p.risolvi_tiro(g, scelta[1], scelta[0], false)
			return

## «Corri in un esagono scoperto, striscia in ogni altro tipo».
## fuori_vista: fermati prono appena fuori dalla vista degli americani (806); solo_striscia: un esagono strisciando.
func _corri_o_striscia(evasivo: bool, fuori_vista := false, solo_striscia := false) -> void:
	var g := _g
	if solo_striscia:
		var rs := _riferimento(g.hex)
		if rs == "":
			_nessun_riferimento()
			return
		if g.postura != "crouching":
			_accovacciati()
		_segui_riferimento(rs, true)
		return
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
		if (evasivo and not p.terreno.edificio(g.hex) and not p.in_vista_americani(g)) or (fuori_vista and g.cambio_libero and not p.in_vista_americani(g)):
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
	var lista: Array = p.unita_in(_g.hex, "us").filter(func(a): return p.piano(a) == p.piano(_g))
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
