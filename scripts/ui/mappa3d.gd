extends SubViewportContainer
## Vista 3D della mappa: rilievo dalle quote degli esagoni, fiume scavato, alberi, cespugli,
## erba alta, muri delle case diroccate, ponti e bunker. Sopra il terreno si stende un velo
## disegnato dalla mappa 2D (pedine, evidenziazioni, segnalini, linee di vista), così tutto
## il gioco funziona allo stesso modo anche in 3D.
## Mouse: trascina = sposta, tasto destro = ruota e inclina, rotella = zoom.
## Tocco: un dito sposta, due dita pizzicano (zoom), ruotano e, spostate in su o in giù, inclinano.

const E = preload("res://scripts/motore/esagoni.gd")
const DM = preload("res://scripts/motore/dati_mappe.gd")
const MappaScript = preload("res://scripts/ui/mappa.gd")

const K := 0.01            # unità 3D per pixel della mappa
const LIVELLO := 0.72      # altezza di un livello di quota
const PASSO_GRIGLIA := 20  # pixel tra i vertici del rilievo
const SCALA_VELO := 0.55   # risoluzione del velo disegnato rispetto alla mappa
const RAGGIO_PX := 180.5 * 0.6

var mappa2d   # la mappa 2D (scripts/ui/mappa.gd): stato, segnali e disegno del velo
var vp: SubViewport
var mondo: Node3D
var cam: Camera3D
var luce: DirectionalLight3D
var terreno_mi: MeshInstance3D
var acqua_mi: MeshInstance3D
var oggetti: Node3D
var velo_vp: SubViewport
var velo   # seconda istanza della mappa 2D che disegna solo le cose sopra il terreno
var mat_terreno: ShaderMaterial

var lettera := ""
var _chiave_rilievo := ""
var dim_px := Vector2(4200, 3840)
var gw := 0
var gh := 0
var alt := PackedFloat32Array()
var maschere: Image
var alberi_per_hex: Dictionary = {}   # esagono -> indici degli alberi
var alberi_mm_l: Array = []
var alberi_xf: Array = []             # per albero: [forma, indice nel multimesh, trasformazione]
var _firma_oggetti := ""
var _firma_pedine := ""
var _muri_rovine: Array = []

# camera
var bersaglio := Vector3(21, 0, 19)
var imbardata := 0.0
var beccheggio := 52.0
var distanza := 14.0
var _tween: Tween

# input
var _tocchi := {}
var _prec_dist := 0.0
var _prec_ang := 0.0
var _prec_centro := Vector2.ZERO
var _premuto := false
var _premuto_pos := Vector2.ZERO
var _trascinato := false
var _ruota := false
var _multi := false
var sopra := ""

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	vp = SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X
	vp.handle_input_locally = false
	vp.physics_object_picking = false
	add_child(vp)
	mondo = Node3D.new()
	vp.add_child(mondo)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.1
	cam.far = 200.0
	mondo.add_child(cam)
	luce = DirectionalLight3D.new()
	luce.rotation_degrees = Vector3(-48, -35, 0)
	luce.light_energy = 0.72
	luce.light_color = Color(1.0, 0.96, 0.88)
	luce.shadow_enabled = true
	luce.shadow_bias = 0.04
	luce.directional_shadow_max_distance = 45.0
	mondo.add_child(luce)
	var riempimento := DirectionalLight3D.new()
	riempimento.rotation_degrees = Vector3(-30, 150, 0)
	riempimento.light_energy = 0.28
	riempimento.light_color = Color(0.8, 0.85, 1.0)
	mondo.add_child(riempimento)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b2f24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.78)
	env.ambient_light_energy = 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color("3a3f31")
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	mondo.add_child(we)
	oggetti = Node3D.new()
	mondo.add_child(oggetti)

## Costruisce (o ricostruisce) la scena per la mappa della missione in corso.
func prepara(m2d) -> void:
	mappa2d = m2d
	var l: String = mappa2d.partita.lettera_mappa().to_lower() if mappa2d.partita != null else "a"
	# Il letto asciutto (Purple Heart 15) cambia il rilievo: fa parte della chiave.
	var secchi: Array = []
	if mappa2d.partita != null and not mappa2d.partita.s.is_empty():
		for hm in mappa2d.partita.s.get("modifiche", {}):
			if str(mappa2d.partita.s.modifiche[hm]) == "cover":
				secchi.append(str(hm))
	secchi.sort()
	var chiave := l + str(secchi)
	if chiave == _chiave_rilievo and terreno_mi != null:
		_aggiorna_tessitura()
		return
	_chiave_rilievo = chiave
	lettera = l
	_crea_velo()
	_costruisci_rilievo()
	_costruisci_vegetazione()
	_firma_oggetti = ""
	_aggiorna_oggetti()
	vista_iniziale()

func _aggiorna_tessitura() -> void:
	if mat_terreno != null:
		mat_terreno.set_shader_parameter("mappa", mappa2d.mappa)

# ================================================================== velo (pedine e segni)
func _crea_velo() -> void:
	if velo_vp == null:
		velo_vp = SubViewport.new()
		velo_vp.transparent_bg = true
		velo_vp.disable_3d = true
		velo_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.add_child(velo_vp)
		velo = MappaScript.new()
		velo.solo_velo = true
		velo_vp.add_child(velo)
	dim_px = Vector2(mappa2d.mappa.get_size())
	velo_vp.size = Vector2i(dim_px * SCALA_VELO)
	velo.partita = mappa2d.partita
	velo.zoom = SCALA_VELO
	velo.spostamento = Vector2.ZERO
	velo.position = Vector2.ZERO
	velo.size = dim_px * SCALA_VELO
	velo.mappa = mappa2d.mappa

func _sincronizza_velo() -> void:
	if velo == null or mappa2d == null:
		return
	for k in ["partita", "evidenzia", "selezionati", "origine_vista", "postura_vista", "mostra_vista",
			"mostra_obiettivi", "mostra_comando", "vista", "animazioni", "mobili", "tracce", "attore_id",
			"stato_pannelli", "segni", "etichette", "linee", "trame", "velocita", "pedine_nuove", "_t"]:
		velo.set(k, mappa2d.get(k))
	velo.sopra = sopra
	velo.senza_pedine = true
	velo.zoom = SCALA_VELO
	velo.spostamento = Vector2.ZERO
	velo.queue_redraw()

# ================================================================== rilievo
func _px_a_astratto(p: Vector2) -> Vector2:
	return Vector2((p.x / 0.6 - 307.0) / 270.8 * 1.5, (p.y / 0.6 - 272.0) / 314.0 * E.SQRT3)

static func centro_px(h: String) -> Vector2:
	var q := E.colonna(h)
	var r := E.riga(h) - 1
	return (Vector2(307.0, 272.0) + Vector2(q * 270.8, r * 314.0 + float(q & 1) * 157.0)) * 0.6

func esagono_px(p: Vector2) -> String:
	return E.a_punto(_px_a_astratto(p))

func _quota_base(p: Vector2) -> float:
	var t: Terreno = mappa2d.partita.terreno
	var h := esagono_px(p)
	if h == "":
		# Fuori dagli esagoni: il livello dell'esagono più vicino lungo il bordo.
		var c := p.clamp(Vector2(200, 180), dim_px - Vector2(200, 180))
		h = esagono_px(c)
		if h == "":
			return 1.0
	var somma := 0.0
	var pesi := 0.0
	var lista: Array = [h]
	lista.append_array(E.vicini(h))
	for x in lista:
		var hx := str(x)
		if hx == "":
			continue
		var d := p.distance_to(centro_px(hx)) / (RAGGIO_PX * 1.15)
		var w := maxf(0.0, 1.0 - d)
		w = w * w * w
		somma += w * float(t.quota(hx))
		pesi += w
	return somma / pesi if pesi > 0.0 else float(t.quota(h))

func _maschera(p: Vector2, canale: int) -> float:
	if maschere == null:
		return 0.0
	var u := p.x / dim_px.x * (maschere.get_width() - 1)
	var v := p.y / dim_px.y * (maschere.get_height() - 1)
	var x0 := clampi(int(u), 0, maschere.get_width() - 2)
	var y0 := clampi(int(v), 0, maschere.get_height() - 2)
	var fx := clampf(u - x0, 0.0, 1.0)
	var fy := clampf(v - y0, 0.0, 1.0)
	var a: float = maschere.get_pixel(x0, y0)[canale]
	var b: float = maschere.get_pixel(x0 + 1, y0)[canale]
	var c: float = maschere.get_pixel(x0, y0 + 1)[canale]
	var d: float = maschere.get_pixel(x0 + 1, y0 + 1)[canale]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

func _costruisci_rilievo() -> void:
	var percorso_m := "res://assets/maps/mappa_%s_maschere.png" % lettera
	maschere = null
	if ResourceLoader.exists(percorso_m):
		var tex: Texture2D = load(percorso_m)
		maschere = tex.get_image()
		if maschere.is_compressed():
			maschere.decompress()
	gw = int(dim_px.x / PASSO_GRIGLIA) + 1
	gh = int(dim_px.y / PASSO_GRIGLIA) + 1
	alt.resize(gw * gh)
	var secco := {}
	if mappa2d.partita != null and not mappa2d.partita.s.is_empty():
		for hm in mappa2d.partita.s.get("modifiche", {}):
			if str(mappa2d.partita.s.modifiche[hm]) == "cover":
				secco[str(hm)] = true
	var acqua := PackedFloat32Array()
	acqua.resize(gw * gh)
	for j in gh:
		for i in gw:
			var p := Vector2(i * PASSO_GRIGLIA, j * PASSO_GRIGLIA)
			var y := (_quota_base(p) - 1.0) * LIVELLO
			var a := _maschera(p, 0)
			var c := _maschera(p, 1)
			var hp := esagono_px(p)
			if hp != "" and mappa2d.partita.terreno.tipo(hp) == "water" and p.distance_to(centro_px(hp)) < RAGGIO_PX * 0.92:
				a = maxf(a, 1.0)  # specchi d'acqua segnati nell'editor anche dove il disegno non li ha
			if not secco.is_empty() and secco.has(hp):
				a = 0.0  # Purple Heart 15: letto del fiume asciutto per la diga
			acqua[j * gw + i] = a
			y -= 0.2 * smoothstep(0.05, 0.6, a)
			y += 0.045 * c
			alt[j * gw + i] = y
	_argini()
	# Mesh del terreno
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	v.resize(gw * gh)
	n.resize(gw * gh)
	uv.resize(gw * gh)
	for j in gh:
		for i in gw:
			var k := j * gw + i
			v[k] = Vector3(i * PASSO_GRIGLIA * K, alt[k], j * PASSO_GRIGLIA * K)
			uv[k] = Vector2(i * PASSO_GRIGLIA / dim_px.x, j * PASSO_GRIGLIA / dim_px.y)
			var hl := alt[j * gw + maxi(i - 1, 0)]
			var hr := alt[j * gw + mini(i + 1, gw - 1)]
			var hu := alt[maxi(j - 1, 0) * gw + i]
			var hd := alt[mini(j + 1, gh - 1) * gw + i]
			n[k] = Vector3(hl - hr, 2.0 * PASSO_GRIGLIA * K, hu - hd).normalized()
	for j in gh - 1:
		for i in gw - 1:
			var a := j * gw + i
			idx.append_array([a, a + 1, a + gw, a + 1, a + gw + 1, a + gw])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if terreno_mi == null:
		terreno_mi = MeshInstance3D.new()
		mondo.add_child(terreno_mi)
		mat_terreno = ShaderMaterial.new()
		mat_terreno.shader = load("res://scripts/ui/terreno3d.gdshader")
	terreno_mi.mesh = mesh
	mat_terreno.set_shader_parameter("mappa", mappa2d.mappa)
	mat_terreno.set_shader_parameter("velo", velo_vp.get_texture())
	terreno_mi.material_override = mat_terreno
	# Superficie dell'acqua: stessa griglia, appena sotto le sponde, trasparente dove non c'è fiume.
	var va := PackedVector3Array()
	va.resize(gw * gh)
	var uva := PackedVector2Array()
	uva.resize(gw * gh)
	for j in gh:
		for i in gw:
			var k := j * gw + i
			var p := Vector2(i * PASSO_GRIGLIA, j * PASSO_GRIGLIA)
			va[k] = Vector3(p.x * K, (_quota_base(p) - 1.0) * LIVELLO - 0.075, p.y * K)
			uva[k] = Vector2(p.x / dim_px.x, p.y / dim_px.y)
	var idx_a := PackedInt32Array()
	for j in gh - 1:
		for i in gw - 1:
			var a := j * gw + i
			if acqua[a] + acqua[a + 1] + acqua[a + gw] + acqua[a + gw + 1] > 0.01:
				idx_a.append_array([a, a + 1, a + gw, a + 1, a + gw + 1, a + gw])
	if acqua_mi == null:
		acqua_mi = MeshInstance3D.new()
		acqua_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mondo.add_child(acqua_mi)
		var ma := ShaderMaterial.new()
		ma.shader = load("res://scripts/ui/acqua3d.gdshader")
		acqua_mi.material_override = ma
	var mat_a: ShaderMaterial = acqua_mi.material_override
	mat_a.set_shader_parameter("velo", velo_vp.get_texture())
	mat_a.set_shader_parameter("ghiaccio", 1.0 if mappa2d.partita != null and bool(mappa2d.partita.regola("ghiaccio", false)) else 0.0)
	if ResourceLoader.exists(percorso_m):
		mat_a.set_shader_parameter("maschere", load(percorso_m))
	if idx_a.is_empty():
		acqua_mi.mesh = null
	else:
		var arr_a := []
		arr_a.resize(Mesh.ARRAY_MAX)
		arr_a[Mesh.ARRAY_VERTEX] = va
		arr_a[Mesh.ARRAY_TEX_UV] = uva
		arr_a[Mesh.ARRAY_INDEX] = idx_a
		var ma_mesh := ArrayMesh.new()
		ma_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr_a)
		acqua_mi.mesh = ma_mesh

## Massicciate (lati «embankment»): un dosso lungo il lato dell'esagono.
func _argini() -> void:
	var t: Terreno = mappa2d.partita.terreno
	for chiave in t.lati:
		if str(t.lati[chiave]) != "embankment":
			continue
		var parti := str(chiave).split("|")
		if parti.size() != 2:
			continue
		var ca := centro_px(parti[0])
		var cb := centro_px(parti[1])
		var mezzo := (ca + cb) / 2.0
		var dir := (cb - ca).normalized().orthogonal()
		var p1 := mezzo - dir * RAGGIO_PX * 0.55
		var p2 := mezzo + dir * RAGGIO_PX * 0.55
		var r := 34.0
		var i0 := maxi(0, int((minf(p1.x, p2.x) - r) / PASSO_GRIGLIA))
		var i1 := mini(gw - 1, int((maxf(p1.x, p2.x) + r) / PASSO_GRIGLIA) + 1)
		var j0 := maxi(0, int((minf(p1.y, p2.y) - r) / PASSO_GRIGLIA))
		var j1 := mini(gh - 1, int((maxf(p1.y, p2.y) + r) / PASSO_GRIGLIA) + 1)
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var p := Vector2(i * PASSO_GRIGLIA, j * PASSO_GRIGLIA)
				var q := Geometry2D.get_closest_point_to_segment(p, p1, p2)
				var d := p.distance_to(q) / r
				if d < 1.0:
					var k := j * gw + i
					alt[k] = maxf(alt[k], alt[k] + 0.12 * (1.0 - d * d))

## Altezza del terreno in un punto (pixel della mappa), interpolata sulla griglia.
func altezza_px(p: Vector2) -> float:
	if gw == 0:
		return 0.0
	var u := clampf(p.x / PASSO_GRIGLIA, 0.0, gw - 1.001)
	var v := clampf(p.y / PASSO_GRIGLIA, 0.0, gh - 1.001)
	var i := int(u)
	var j := int(v)
	var fx := u - i
	var fy := v - j
	var a := alt[j * gw + i]
	var b := alt[j * gw + i + 1]
	var c := alt[(j + 1) * gw + i]
	var d := alt[(j + 1) * gw + i + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

func punto3d(p: Vector2, sopra_terreno := 0.0) -> Vector3:
	return Vector3(p.x * K, altezza_px(p) + sopra_terreno, p.y * K)

func centro3d(h: String) -> Vector3:
	return punto3d(centro_px(h))

# ================================================================== vegetazione e muri
func _materiale(colore: Color, ruvido := 0.9, colori_vertice := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colore
	m.roughness = ruvido
	m.vertex_color_use_as_albedo = colori_vertice
	return m

func _multimesh(mesh: Mesh, n: int, con_colore: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = con_colore
	mm.mesh = mesh
	mm.instance_count = n
	return mm

func _costruisci_vegetazione() -> void:
	for c in oggetti.get_children():
		c.queue_free()
	alberi_per_hex.clear()
	alberi_xf.clear()
	var d: Dictionary = DM.leggi("mappa_%s_3d" % lettera)
	if d.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1983
	# Alberi: tronco e rami con corteccia, chioma di ciuffi di foglie (tre forme diverse)
	var mat_foglie := _mat_foglie("foglie")
	var mat_corteccia := _mat_trama("corteccia", Color(0.9, 0.88, 0.85), 0.95)
	var lista: Array = d.get("alberi", [])
	var varianti := 3
	var per_var: Array = []
	for v in varianti:
		per_var.append([])
	for i in lista.size():
		per_var[i % varianti].append(i)
	alberi_xf.resize(lista.size())
	alberi_mm_l.clear()
	for v in varianti:
		var mesh := _mesh_albero(v, mat_corteccia, mat_foglie)
		var mm := _multimesh(mesh, per_var[v].size(), true)
		alberi_mm_l.append(mm)
		for k in per_var[v].size():
			var i: int = per_var[v][k]
			var a: Array = lista[i]
			var p := Vector2(float(a[0]), float(a[1]))
			var r := float(a[2]) * K * 0.95
			var s := r / 0.42 * rng.randf_range(0.9, 1.08)
			var xf := Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.12), s)), punto3d(p, -0.02))
			mm.set_instance_transform(k, xf)
			alberi_xf[i] = [v, k, xf]
			mm.set_instance_color(k, Color(rng.randf_range(0.8, 1.05), rng.randf_range(0.85, 1.05), rng.randf_range(0.65, 0.9)))
			var h := esagono_px(p)
			if not alberi_per_hex.has(h):
				alberi_per_hex[h] = []
			alberi_per_hex[h].append(i)
		_aggiungi_mm(mm, true)
	# Cespugli: cupole basse di ciuffi di foglie
	var lc: Array = d.get("cespugli", [])
	var mat_cesp := _mat_foglie("foglie")
	var cm := _multimesh(_mesh_cespuglio(mat_cesp), lc.size(), true)
	for i in lc.size():
		var c: Array = lc[i]
		var p := Vector2(float(c[0]), float(c[1]))
		var r := float(c[2]) * K * 1.15
		cm.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, r * rng.randf_range(0.75, 1.0), r * rng.randf_range(0.8, 1.2))), punto3d(p, -0.01)))
		cm.set_instance_color(i, Color(rng.randf_range(0.95, 1.2), rng.randf_range(0.95, 1.1), rng.randf_range(0.5, 0.8)))
	_aggiungi_mm(cm, false)
	# Erba alta (macchie di copertura): ciuffi incrociati
	var lt: Array = d.get("ciuffi", [])
	var tm := _multimesh(_mesh_ciuffo(), lt.size(), true)
	for i in lt.size():
		var c: Array = lt[i]
		var p := Vector2(float(c[0]), float(c[1]))
		var s := rng.randf_range(0.8, 1.3)
		tm.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s)), punto3d(p, -0.005)))
		tm.set_instance_color(i, Color(rng.randf_range(0.9, 1.15), rng.randf_range(0.9, 1.1), rng.randf_range(0.75, 0.95)))
	_aggiungi_mm(tm, false)
	# Vigne (Purple Heart): filari di piccole piante su pali
	var lv: Array = d.get("vigne", [])
	if not lv.is_empty():
		var piante: Array = []
		for f in lv:
			var a := Vector2(float(f[0]), float(f[1]))
			var b := Vector2(float(f[2]), float(f[3]))
			var nn := maxi(2, int(a.distance_to(b) / 11.0))
			for k in nn + 1:
				piante.append(a.lerp(b, float(k) / nn))
		var vm := _multimesh(_mesh_cespuglio(_mat_foglie("foglie")), piante.size(), true)
		for i in piante.size():
			var pv: Vector2 = piante[i]
			var r := rng.randf_range(0.045, 0.06)
			vm.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, r * 1.7, r)), punto3d(pv, 0.0)))
			vm.set_instance_color(i, Color(rng.randf_range(0.9, 1.1), rng.randf_range(1.0, 1.15), rng.randf_range(0.7, 0.9)))
		_aggiungi_mm(vm, false)
	# Massi (Silver Star): rocce grigie irregolari con la trama della pietra
	var lm: Array = d.get("massi", [])
	if not lm.is_empty():
		var mr := _multimesh(_mesh_masso(), lm.size(), true)
		for i in lm.size():
			var c: Array = lm[i]
			var r := float(c[2]) * K
			var b := Basis().rotated(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
			mr.set_instance_transform(i, Transform3D(b.scaled(Vector3(r, r * rng.randf_range(0.55, 0.9), r * rng.randf_range(0.7, 1.1))), punto3d(Vector2(float(c[0]), float(c[1])), -0.01)))
			var g := rng.randf_range(0.78, 1.0)
			mr.set_instance_color(i, Color(g, g, g * rng.randf_range(0.95, 1.05)))
		_aggiungi_mm(mr, false)
	# Serbatoi di carburante e monumenti (Purple Heart)
	for c in d.get("serbatoi", []):
		var cp := Vector2(float(c[0]), float(c[1]))
		var cil := CylinderMesh.new()
		cil.top_radius = RAGGIO_PX * 0.62 * K
		cil.bottom_radius = cil.top_radius
		cil.height = 0.55
		cil.radial_segments = 24
		var ms := MeshInstance3D.new()
		ms.mesh = cil
		ms.material_override = _materiale(Color("a7aaa2"), 0.6)
		ms.position = punto3d(cp, 0.275)
		oggetti.add_child(ms)
		var tetto := CylinderMesh.new()
		tetto.top_radius = 0.05
		tetto.bottom_radius = cil.top_radius
		tetto.height = 0.12
		tetto.radial_segments = 24
		var mt := MeshInstance3D.new()
		mt.mesh = tetto
		mt.material_override = _materiale(Color("6f726b"), 0.7)
		mt.position = punto3d(cp, 0.61)
		oggetti.add_child(mt)
	for c in d.get("monumenti", []):
		var cp := Vector2(float(c[0]), float(c[1]))
		var pietra_m := _materiale(Color("b9b4a8"), 0.9)
		_scatola(oggetti, punto3d(cp, 0.09), Vector3(0.42, 0.18, 0.42), 0.0, pietra_m)
		_scatola(oggetti, punto3d(cp, 0.3), Vector3(0.26, 0.24, 0.26), 0.0, pietra_m)
		var cav := _oggetto("kubelwagen", Color("5b4d33"))
		cav.mesh = SphereMesh.new()
		(cav.mesh as SphereMesh).radius = 0.13
		(cav.mesh as SphereMesh).height = 0.34
		cav.position = punto3d(cp, 0.58)
		oggetti.add_child(cav)
	# I muri disegnati servono solo per le case ridotte in macerie (vedi _aggiorna_oggetti)
	_muri_rovine = d.get("muri", [])

func _aggiungi_mm(mm: MultiMesh, ombra: bool) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	oggetti.add_child(mi)

## Muro estruso dal contorno disegnato sulla mappa.
func _muro(poly_dati: Array, tipo: String, padre: Node3D = null) -> void:
	var poly := PackedVector2Array()
	for q in poly_dati:
		poly.append(Vector2(float(q[0]), float(q[1])))
	if poly.size() < 3:
		return
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
	var altezza := 0.44 if tipo == "pietra" else 0.36
	var colore := Color("a9b0ab") if tipo == "pietra" else Color("8d6a47")
	var base := 1e9
	for q in poly:
		base = minf(base, altezza_px(q))
	base -= 0.03
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(poly[0].x * 7 + poly[0].y)
	var cime := PackedFloat32Array()
	for i in poly.size():
		cime.append(base + altezza * rng.randf_range(0.55, 1.0))  # muri rotti ad altezze diverse
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var a0 := Vector3(a.x * K, base, a.y * K)
		var b0 := Vector3(b.x * K, base, b.y * K)
		var a1 := Vector3(a.x * K, cime[i], a.y * K)
		var b1 := Vector3(b.x * K, cime[(i + 1) % poly.size()], b.y * K)
		var nrm := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
		st.set_normal(nrm)
		for vtx in [a0, b0, b1, a0, b1, a1]:
			st.add_vertex(vtx)
	var tri := Geometry2D.triangulate_polygon(poly)
	st.set_normal(Vector3.UP)
	for i in range(0, tri.size(), 3):
		for k in [0, 2, 1]:
			var q := poly[tri[i + k]]
			st.add_vertex(Vector3(q.x * K, cime[tri[i + k]], q.y * K))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _materiale(colore, 0.95)
	(padre if padre != null else oggetti).add_child(mi)

# ================================================================== oggetti che cambiano con la partita
var _dinamici: Node3D

func _aggiorna_oggetti() -> void:
	var p: Partita = mappa2d.partita
	if p == null or p.s.is_empty():
		return
	var firma := str([p.s.get("radio_hex", ""), p.s.get("modifiche", {}), p.s.get("bunker", {}).keys(), p.s.get("bunker", {}).values().map(func(b): return b.get("distrutto", false)),
		p.s.get("blocchi", []), p.s.get("ponti", {}).values().map(func(b): return b.get("distrutto", false)), lettera,
		p.s.get("punti", {}), _oggetti_ph(p)])
	if firma == _firma_oggetti:
		return
	_firma_oggetti = firma
	if _dinamici != null:
		_dinamici.queue_free()
	_dinamici = Node3D.new()
	mondo.add_child(_dinamici)
	var t: Terreno = p.terreno
	_costruisci_case(_dinamici)
	var pietra := _materiale(Color("9ea5a1"))
	var legno := _materiale(Color("7a5a3c"))
	var cemento := _materiale(Color("8c8f86"))
	# Ponti
	for h in E.tutti():
		if not bool(t.esagoni.get(h, {}).get("ponte", false)):
			continue
		var c := centro_px(h)
		var capi: Array = []
		for v in E.vicini(h):
			var tv := t.tipo(v)
			if tv != "stream" and tv != "":
				capi.append(v)
		var dir := Vector2.RIGHT
		var migliore := -1.0
		for x in capi:
			for y in capi:
				if x == y:
					continue
				var d := centro_px(str(x)).distance_to(centro_px(str(y)))
				if d > migliore and (t.tipo(str(x)) == "road" or t.tipo(str(y)) == "road" or migliore < 0.0):
					migliore = d
					dir = (centro_px(str(y)) - centro_px(str(x))).normalized()
		var intatto := t.ponte(h)
		var quota := maxf(altezza_px(c + dir * RAGGIO_PX), altezza_px(c - dir * RAGGIO_PX)) + 0.06
		var lung := RAGGIO_PX * 2.1 * K
		var ang := atan2(-dir.y, dir.x)
		if intatto:
			_scatola(_dinamici, Vector3(c.x * K, quota, c.y * K), Vector3(lung, 0.07, 0.42), ang, pietra if h != "G13" else legno)
			for lato: float in [-1.0, 1.0]:
				var off := Vector2(-dir.y, dir.x) * 0.2 / K * lato
				_scatola(_dinamici, Vector3((c.x + off.x) * K, quota + 0.08, (c.y + off.y) * K), Vector3(lung, 0.09, 0.03), ang, pietra if h != "G13" else legno)
		else:
			for lato: float in [-1.0, 1.0]:
				var q := c + dir * RAGGIO_PX * 0.7 * lato
				_scatola(_dinamici, Vector3(q.x * K, quota - 0.04, q.y * K), Vector3(lung * 0.32, 0.07, 0.42), ang + lato * 0.25, pietra)
	# Bunker (missione 6)
	for h in p.s.get("bunker", {}):
		var bk: Dictionary = p.s.bunker[h]
		var c := centro_px(str(h))
		var b3 := Vector3(c.x * K, altezza_px(c), c.y * K)
		var mb := MeshInstance3D.new()
		mb.mesh = _mesh_mezzo("bunker")
		mb.material_override = _materiale_dipinto("bunker", Color(0.35, 0.33, 0.3) if bk.get("distrutto", false) else Color.WHITE)
		mb.position = b3
		_dinamici.add_child(mb)
		if bk.get("distrutto", false):
			_macerie(_dinamici, c, 9, cemento)
	# Crateri e macerie
	for h in p.s.get("modifiche", {}):
		var tipo := str(p.s.modifiche[h])
		if tipo == "rubble":
			_macerie(_dinamici, centro_px(str(h)), 14, pietra)
		elif tipo == "crater":
			var mc := MeshInstance3D.new()
			mc.mesh = _mesh_mezzo("cratere")
			mc.material_override = _materiale_dipinto("cratere")
			mc.position = punto3d(centro_px(str(h)), -0.02)
			_dinamici.add_child(mc)
		elif tipo == "water":
			# Purple Heart 15: esagono allagato dalla piena.
			var ma := MeshInstance3D.new()
			var cil := CylinderMesh.new()
			cil.radial_segments = 6
			cil.rings = 1
			cil.top_radius = RAGGIO_PX * 1.12 * K
			cil.bottom_radius = cil.top_radius
			cil.height = 0.04
			ma.mesh = cil
			var mat := _materiale(Color(0.28, 0.45, 0.62), 0.25)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.78
			ma.material_override = mat
			ma.rotation.y = PI / 6.0
			ma.position = punto3d(centro_px(str(h)), 0.05)
			_dinamici.add_child(ma)
	# Rocce degli esagoni accidentati
	for h in E.tutti():
		if t.tipo(h) == "rough":
			_macerie(_dinamici, centro_px(h), 10, _materiale(Color("8a8a80")))
	# Blocchi stradali (missione 8): barricate di traverso alla strada
	for h in p.s.get("blocchi", []):
		var c := centro_px(str(h))
		var ang := 0.0
		for v in E.vicini(str(h)):
			if t.tipo(v) == "road":
				var dv := centro_px(v) - c
				ang = atan2(dv.x, dv.y) + PI / 2.0
				break
		for k in [-1, 1]:
			var mb := _oggetto("barricata", Color("5e4a36"))
			mb.position = punto3d(c + Vector2(cos(ang), -sin(ang)).rotated(PI / 2.0) * 22.0 * k)
			mb.rotation.y = ang
			_dinamici.add_child(mb)
	_costruisci_ph(p, cemento)
	# Missione 3: radio presidiata e deposito di carburante
	var rh := str(p.s.get("radio_hex", ""))
	if rh != "":
		var mr := _oggetto("radio", Color("4f5638"))
		mr.position = punto3d(centro_px(rh) + Vector2(38, -30))
		mr.rotation.y = 0.6
		_dinamici.add_child(mr)
	var dep := str(p.regola("deposito", ""))
	if dep != "" and t.tipo(dep) != "rubble":
		var rng_t := RandomNumberGenerator.new()
		rng_t.seed = 7
		for i in 14:
			var mt := _oggetto("tanica", Color("4c5233") if i % 3 else Color("6b2e22"))
			mt.position = punto3d(centro_px(dep) + Vector2((i % 5) * 13 - 26, (i / 5) * 18 - 30 + rng_t.randf() * 4))
			mt.rotation.y = rng_t.randf_range(-0.2, 0.2)
			_dinamici.add_child(mt)

## Firma degli oggetti di Purple Heart che cambiano durante la partita.
func _oggetti_ph(p) -> Array:
	var out: Array = []
	for h in p.s.get("oggetti", {}):
		for o in p.s.oggetti[h]:
			if str(o.get("tipo", "")) in ["faro", "antenna", "cannone_costiero"]:
				out.append([h, o.tipo])
	var st: Dictionary = p.s.get("ph", {})
	out.append([st.get("faro", {}).get("attivo", true), st.get("cannone_W12", false), st.get("cannone_X12", false), st.get("antenna_distrutta", false)])
	return out

const MEZZI_RELITTO := {"jagdpanther": "jagdpanther", "sherman": "sherman", "panzer": "panzer4", "jeep": "jeep"}

## Purple Heart: diga, faro, antenna, cannoni costieri e relitti dei mezzi.
func _costruisci_ph(p, cemento: Material) -> void:
	var t: Terreno = p.terreno
	if bool(p.regola("diga", false)):
		var a := centro_px("M6")
		var b := centro_px("O5")
		var c := centro_px("N5")
		var dir := (b - a).normalized()
		var ang := -atan2(dir.y, dir.x)
		_scatola(_dinamici, punto3d(c, 0.18) + Vector3(0, 0, 0), Vector3(RAGGIO_PX * 2.1 * K, 0.36, 0.34), ang, cemento)
		# il muro della diga verso il lago
		var n := dir.orthogonal()
		_scatola(_dinamici, punto3d(c - n * RAGGIO_PX * 0.25, 0.32), Vector3(RAGGIO_PX * 2.1 * K, 0.64, 0.12), ang, cemento)
	var st: Dictionary = p.s.get("ph", {})
	for h in p.s.get("oggetti", {}):
		for o in p.s.oggetti[h]:
			var tipo := str(o.get("tipo", ""))
			var c := centro_px(str(h))
			match tipo:
				"faro":
					if bool(st.get("faro", {}).get("attivo", true)):
						var torre := CylinderMesh.new()
						torre.top_radius = 0.12
						torre.bottom_radius = 0.2
						torre.height = 1.6
						torre.radial_segments = 14
						var mt := MeshInstance3D.new()
						mt.mesh = torre
						mt.material_override = _materiale(Color("e4e0d6"), 0.7)
						mt.position = punto3d(c, 0.8)
						_dinamici.add_child(mt)
						var cima := CylinderMesh.new()
						cima.top_radius = 0.0
						cima.bottom_radius = 0.16
						cima.height = 0.26
						cima.radial_segments = 14
						var mc := MeshInstance3D.new()
						mc.mesh = cima
						mc.material_override = _materiale(Color("8e2b22"), 0.6)
						mc.position = punto3d(c, 1.73)
						_dinamici.add_child(mc)
						var luce := OmniLight3D.new()
						luce.light_color = Color(1.0, 0.92, 0.7)
						luce.light_energy = 0.8
						luce.omni_range = 2.5
						luce.position = punto3d(c, 1.55)
						_dinamici.add_child(luce)
					else:
						_macerie(_dinamici, c, 12, cemento)
				"antenna":
					if not bool(st.get("antenna_distrutta", false)):
						var asta := CylinderMesh.new()
						asta.top_radius = 0.012
						asta.bottom_radius = 0.035
						asta.height = 2.2
						asta.radial_segments = 6
						var ma := MeshInstance3D.new()
						ma.mesh = asta
						ma.material_override = _materiale(Color("5c5f5a"), 0.5)
						ma.position = punto3d(c, 1.1)
						_dinamici.add_child(ma)
						for k in 3:
							_scatola(_dinamici, punto3d(c, 0.6 + k * 0.55), Vector3(0.36 - k * 0.08, 0.015, 0.015), k * 1.0, ma.material_override)
				"cannone_costiero":
					if bool(st.get("cannone_" + str(h), false)):
						_macerie(_dinamici, c, 16, cemento)
					else:
						var mb := _oggetto("bunker", Color("8a8b82"))
						mb.position = punto3d(c)
						mb.rotation.y = PI * 0.75
						mb.scale = Vector3(1.25, 1.25, 1.25)
						_dinamici.add_child(mb)
						var canna := CylinderMesh.new()
						canna.top_radius = 0.035
						canna.bottom_radius = 0.05
						canna.height = 0.9
						canna.radial_segments = 8
						var mca := MeshInstance3D.new()
						mca.mesh = canna
						mca.material_override = _materiale(Color("3f423d"), 0.5)
						mca.position = punto3d(c + Vector2(-0.45, -0.45) * RAGGIO_PX * 0.9, 0.28)
						mca.rotation = Vector3(0, PI * 0.75, PI / 2.0 - 0.08)
						_dinamici.add_child(mca)
	# Treno (Missione 17): locomotiva, vagoni e cisterna lungo il binario
	var binario: Array = p.regola("binario", [])
	for h in p.s.get("punti", {}):
		var nome_t := str(p.s.punti[h])
		if not (nome_t in ["locomotiva", "vagone merci", "cisterna", "vagone rovesciato", "cisterna rovesciata"]):
			continue
		var i_b := binario.find(str(h))
		var dir_t := Vector2.RIGHT
		if i_b >= 0:
			# direzione media sul tratto di binario (i binari a zig-zag tra le righe vanno lisciati)
			var a_t := centro_px(str(binario[maxi(0, i_b - 2)]))
			var b_t := centro_px(str(binario[mini(binario.size() - 1, i_b + 2)]))
			if a_t.distance_to(b_t) > 1.0:
				dir_t = (b_t - a_t).normalized()
		var ang_t := -atan2(dir_t.y, dir_t.x)
		var rovesciato := "rovesciat" in nome_t
		var col_t := Color("3c3f3a") if nome_t == "locomotiva" else (Color("6a4a32") if "vagone" in nome_t else Color("4c5458"))
		var mat_t := _materiale(col_t.darkened(0.35) if rovesciato else col_t, 0.8)
		var nodo := Node3D.new()
		var pos_t := centro_px(str(h))
		if i_b > 0 and i_b + 1 < binario.size():
			pos_t = (centro_px(str(binario[i_b - 1])) + 2.0 * pos_t + centro_px(str(binario[i_b + 1]))) / 4.0
		nodo.position = punto3d(pos_t, 0.0)
		nodo.rotation.y = ang_t + (0.6 if rovesciato else 0.0)
		if rovesciato:
			nodo.rotation.x = 1.2
		_dinamici.add_child(nodo)
		if "cisterna" in nome_t:
			var cil := CylinderMesh.new()
			cil.top_radius = 0.16
			cil.bottom_radius = 0.16
			cil.height = RAGGIO_PX * 1.5 * K
			var mc := MeshInstance3D.new()
			mc.mesh = cil
			mc.material_override = mat_t
			mc.rotation = Vector3(0, 0, PI / 2.0)
			mc.position = Vector3(0, 0.26, 0)
			nodo.add_child(mc)
			_scatola(nodo, Vector3(0, 0.06, 0), Vector3(RAGGIO_PX * 1.55 * K, 0.08, 0.3), 0.0, mat_t)
		else:
			_scatola(nodo, Vector3(0, 0.25, 0), Vector3(RAGGIO_PX * 1.55 * K, 0.42 if nome_t == "locomotiva" else 0.38, 0.32), 0.0, mat_t)
			if nome_t == "locomotiva":
				var cam := CylinderMesh.new()
				cam.top_radius = 0.05
				cam.bottom_radius = 0.06
				cam.height = 0.2
				var mcm := MeshInstance3D.new()
				mcm.mesh = cam
				mcm.material_override = mat_t
				mcm.position = Vector3(RAGGIO_PX * 0.5 * K, 0.55, 0)
				nodo.add_child(mcm)
	# Relitti dei mezzi (Missione 15): mesh del mezzo, scuro e di traverso
	var rng := RandomNumberGenerator.new()
	for h in p.s.get("punti", {}):
		var nome := str(p.s.punti[h]).to_lower()
		if not "distrutt" in nome:
			continue
		for k in MEZZI_RELITTO:
			if k in nome:
				rng.seed = hash(str(h))
				var mr := _oggetto(MEZZI_RELITTO[k], Color("3b3632"))
				mr.position = punto3d(centro_px(str(h)) + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20)))
				mr.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf() * TAU, rng.randf_range(-0.1, 0.1))
				_dinamici.add_child(mr)
				break

func _oggetto(nome: String, colore: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_mezzo(nome)
	mi.material_override = _materiale(colore, 0.85)
	return mi

func _scatola(padre: Node3D, pos: Vector3, dim: Vector3, ang: float, mat: Material) -> void:
	var b := BoxMesh.new()
	b.size = dim
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = ang
	padre.add_child(mi)

func _macerie(padre: Node3D, c: Vector2, n: int, mat: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.x * 13 + c.y)
	for i in n:
		var p := c + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)) * RAGGIO_PX
		var s := rng.randf_range(0.06, 0.16)
		var m := SphereMesh.new()
		m.radius = s
		m.height = s * 1.3
		m.radial_segments = 5
		m.rings = 3
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = mat
		mi.position = punto3d(p, s * 0.3)
		mi.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf())
		padre.add_child(mi)

## Negli esagoni con pedine gli alberi si diradano, così le pedine restano visibili.
func _dirada_alberi() -> void:
	var p: Partita = mappa2d.partita
	if p == null or p.s.is_empty() or alberi_mm_l.is_empty():
		return
	var occupati := {}
	for id in p.s.unita:
		var x: Dictionary = p.s.unita[id]
		if str(x.get("hex", "")) != "" and not x.stato in ["fuori", "uscito", "rimosso"]:
			occupati[str(x.hex)] = true
	for h in mappa2d.evidenzia:
		occupati[str(h)] = true
	var firma := str(occupati.keys())
	if firma == _firma_pedine:
		return
	_firma_pedine = firma
	for h in alberi_per_hex:
		var c := centro_px(str(h))
		for i in alberi_per_hex[h]:
			var info: Array = alberi_xf[i]
			var mm: MultiMesh = alberi_mm_l[info[0]]
			var xf: Transform3D = info[2]
			var vicino := occupati.has(h) and Vector2(xf.origin.x / K, xf.origin.z / K).distance_to(c) < RAGGIO_PX * 0.85
			if vicino:
				# resta solo un alberello basso, che non nasconde le pedine
				mm.set_instance_transform(int(info[1]), Transform3D(xf.basis.scaled(Vector3(0.35, 0.22, 0.35)), xf.origin))
			else:
				mm.set_instance_transform(int(info[1]), xf)

## Materiale dei ciuffi di foglie: trama con trasparenza a soglia, due facce, un po' di luce che passa.
func _mat_foglie(nome: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _trama(nome)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.45
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	m.backlight_enabled = true
	m.backlight = Color(0.25, 0.32, 0.12)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m

## Un albero alto 1 (chioma larga circa 0.84): tronco e rami con corteccia, chioma di ciuffi.
## Le normali dei ciuffi puntano fuori dal centro della chioma: luce morbida e volume pieno.
func _mesh_albero(forma: int, mat_c: Material, mat_f: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + forma * 31
	var legno := SurfaceTool.new()
	legno.begin(Mesh.PRIMITIVE_TRIANGLES)
	var chioma_c := Vector3(rng.randf_range(-0.03, 0.03), [0.62, 0.66, 0.58][forma], rng.randf_range(-0.03, 0.03))
	var raggi: Vector3 = [Vector3(0.42, 0.34, 0.42), Vector3(0.36, 0.38, 0.36), Vector3(0.46, 0.3, 0.44)][forma]
	var cima_tronco := Vector3(chioma_c.x * 0.5, 0.5, chioma_c.z * 0.5)
	_ramo(legno, Vector3.ZERO, cima_tronco, 0.05, 0.03, 7)
	for k in 5:
		var a := TAU * k / 5.0 + rng.randf_range(-0.4, 0.4)
		var da := cima_tronco.lerp(Vector3.ZERO, rng.randf_range(0.05, 0.3))
		var verso := chioma_c + Vector3(cos(a) * raggi.x * 0.7, rng.randf_range(-0.05, 0.15), sin(a) * raggi.z * 0.7)
		_ramo(legno, da, verso, 0.022, 0.008, 5)
	var foglie := SurfaceTool.new()
	foglie.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 46
	for k in n:
		# punti più fitti verso la superficie della chioma
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 1), rng.randf_range(-1, 1)).normalized()
		var r := pow(rng.randf(), 0.35)
		var pos := chioma_c + Vector3(dir.x * raggi.x, dir.y * raggi.y, dir.z * raggi.z) * r
		var lato := rng.randf_range(0.24, 0.34)
		var quad := rng.randi() % 4
		var uv0 := Vector2((quad % 2) * 0.5, (quad / 2) * 0.5)
		for piano in 2:
			var asse_u := Vector3(cos(rng.randf() * TAU), 0, sin(rng.randf() * TAU)).normalized()
			var asse_v := asse_u.cross(Vector3(rng.randf_range(-0.6, 0.6), 1, rng.randf_range(-0.6, 0.6)).normalized()).normalized()
			if piano == 1:
				asse_v = Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3)) + asse_u.cross(Vector3.UP).normalized()
				asse_v = asse_v.normalized()
				asse_u = asse_u.rotated(asse_v, PI / 2.0)
			var vs := [pos - asse_u * lato / 2 - asse_v * lato / 2, pos + asse_u * lato / 2 - asse_v * lato / 2,
					pos + asse_u * lato / 2 + asse_v * lato / 2, pos - asse_u * lato / 2 + asse_v * lato / 2]
			var uvs := [uv0, uv0 + Vector2(0.5, 0), uv0 + Vector2(0.5, 0.5), uv0 + Vector2(0, 0.5)]
			for t in [[0, 1, 2], [0, 2, 3]]:
				for q in t:
					var vtx: Vector3 = vs[q]
					var nrm := ((vtx - chioma_c) / Vector3(raggi.x, raggi.y, raggi.z) + Vector3(0, 0.35, 0)).normalized()
					foglie.set_normal(nrm)
					foglie.set_uv(uvs[q])
					foglie.add_vertex(vtx)
	legno.generate_tangents()
	var mesh := legno.commit()
	mesh.surface_set_material(0, mat_c)
	foglie.commit(mesh)
	mesh.surface_set_material(1, mat_f)
	return mesh

## Tronco o ramo: cilindro rastremato con corteccia.
func _ramo(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, lati: int) -> void:
	var asse := (b - a).normalized()
	var u := asse.cross(Vector3.FORWARD if absf(asse.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var v := asse.cross(u)
	var lung := a.distance_to(b)
	for i in lati:
		var a0 := TAU * i / lati
		var a1 := TAU * (i + 1) / lati
		var d0 := u * cos(a0) + v * sin(a0)
		var d1 := u * cos(a1) + v * sin(a1)
		var p00 := a + d0 * r0
		var p01 := a + d1 * r0
		var p10 := b + d0 * r1
		var p11 := b + d1 * r1
		var u0 := float(i) / lati
		var u1 := float(i + 1) / lati
		var verts := [[p00, d0, Vector2(u0, 0)], [p10, d0, Vector2(u0, -lung * 3.0)], [p11, d1, Vector2(u1, -lung * 3.0)],
				[p00, d0, Vector2(u0, 0)], [p11, d1, Vector2(u1, -lung * 3.0)], [p01, d1, Vector2(u1, 0)]]
		# faccia anteriore verso fuori
		if (p10 - p00).cross(p11 - p00).dot(d0 + d1) > 0:
			verts = [verts[0], verts[2], verts[1], verts[3], verts[5], verts[4]]
		for vv in verts:
			st.set_normal(vv[1])
			st.set_uv(vv[2])
			st.add_vertex(vv[0])

## Cespuglio di raggio 1, alto circa 0.8: ciuffi di foglie ammucchiati, normali a cupola.
func _mesh_cespuglio(mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centro := Vector3(0, 0.25, 0)
	for k in 16:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.75
		var pos := Vector3(cos(a) * r, rng.randf_range(0.25, 0.55) * (1.0 - r * 0.5), sin(a) * r)
		var lato := rng.randf_range(0.7, 1.0)
		var quad := rng.randi() % 4
		var uv0 := Vector2((quad % 2) * 0.5, (quad / 2) * 0.5)
		var asse_u := Vector3(cos(rng.randf() * TAU), 0, sin(rng.randf() * TAU)).normalized()
		var asse_v := Vector3(0, 1, 0).lerp(asse_u.cross(Vector3.UP), rng.randf_range(0.0, 0.8)).normalized()
		var vs := [pos - asse_u * lato / 2 - asse_v * lato / 2, pos + asse_u * lato / 2 - asse_v * lato / 2,
				pos + asse_u * lato / 2 + asse_v * lato / 2, pos - asse_u * lato / 2 + asse_v * lato / 2]
		var uvs := [uv0, uv0 + Vector2(0.5, 0), uv0 + Vector2(0.5, 0.5), uv0 + Vector2(0, 0.5)]
		for t in [[0, 1, 2], [0, 2, 3]]:
			for q in t:
				var vtx: Vector3 = vs[q]
				st.set_normal(((vtx - centro) * Vector3(1, 1.6, 1) + Vector3(0, 0.4, 0)).normalized())
				st.set_uv(uvs[q])
				st.add_vertex(vtx)
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh

## Masso di raggio 1: icosfera schiacciata e deformata, pietra grigia.
func _mesh_masso() -> ArrayMesh:
	var sf := SphereMesh.new()
	sf.radius = 1.0
	sf.height = 2.0
	sf.radial_segments = 10
	sf.rings = 6
	var arr := sf.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var cache := {}
	for i in v.size():
		var k := v[i].snapped(Vector3.ONE * 0.01)
		if not cache.has(k):
			cache[k] = rng.randf_range(0.8, 1.15)
		v[i] = v[i] * float(cache[k])
		v[i].y = maxf(v[i].y, -0.2)
	arr[Mesh.ARRAY_VERTEX] = v
	var st := SurfaceTool.new()
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	st.create_from(m, 0)
	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()
	var mat := _mat_trama("pietra", Color(0.72, 0.72, 0.74), 0.95)
	mat.vertex_color_use_as_albedo = true
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(2, 2, 2)
	mesh.surface_set_material(0, mat)
	return mesh

## Ciuffo d'erba alta: tre piani incrociati con la trama dell'erba.
func _mesh_ciuffo() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var alto := 0.13
	var largo := 0.14
	for k in 3:
		var a := PI * k / 3.0
		var u := Vector3(cos(a), 0, sin(a)) * largo / 2.0
		var vs := [-u, u, u + Vector3(0, alto, 0), -u + Vector3(0, alto, 0)]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for t in [[0, 1, 2], [0, 2, 3]]:
			for q in t:
				st.set_normal((Vector3.UP + (vs[q] as Vector3).normalized() * 0.3).normalized() if (vs[q] as Vector3).length() > 0.001 else Vector3.UP)
				st.set_uv(uvs[q])
				st.add_vertex(vs[q])
	var mesh := st.commit()
	var m := _mat_foglie("erba")
	m.backlight = Color(0.3, 0.3, 0.15)
	mesh.surface_set_material(0, m)
	return mesh


# ================================================================== edifici
## Ogni gruppo di esagoni edificio adiacenti dello stesso tipo è una casa: muri pieni sui lati
## verso l'esterno, finestre e porte dove le regole le mettono (lati «window» e «door»), tetto piatto.
## Quando si gioca con chi sta dentro (pedine, esagoni evidenziati, esagono sotto il dito)
## il tetto sparisce e i muri diventano trasparenti.
const ALTEZZA_CASA := 0.95
const SPESSORE_MURO := 0.1
const GRONDA := 0.075          # sporgenza del tetto oltre i muri (unità 3D)
const DIR_TRAME := "res://assets/trame3d/"
var _case: Array = []   # {hex, muri: [MeshInstance3D], tetto: [Node3D], dettagli: [Node3D], mat: [StandardMaterial3D], aperta}
var _trame3d: Dictionary = {}

func _trama(nome: String) -> Texture2D:
	if not _trame3d.has(nome):
		var p := DIR_TRAME + nome + ".png"
		_trame3d[nome] = load(p) if ResourceLoader.exists(p) else null
	return _trame3d[nome]

## Materiale con trama e rilievo (colore × tinta), opzionalmente da duplicare per ogni casa.
func _mat_trama(nome: String, tinta := Color.WHITE, ruvido := 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _trama(nome + "_c")
	m.albedo_color = tinta
	m.roughness = ruvido
	var n := _trama(nome + "_n")
	if n != null:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = 0.8
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _costruisci_case(padre: Node3D) -> void:
	_case.clear()
	var d: Dictionary = DM.leggi("mappa_%s_3d" % lettera)
	if d.is_empty():
		return
	var t: Terreno = mappa2d.partita.terreno
	var indice := 0
	for st in d.get("case", []):
		indice += 1
		var angoli: Array = []
		for q in st.angoli:
			angoli.append(Vector2(float(q[0]), float(q[1])))
		if angoli.size() < 3:
			continue
		var macerie := false
		for h in st.hex:
			if t.tipo(str(h)) == "rubble":
				macerie = true
		if macerie:
			# casa crollata: restano i muri diroccati del disegno dentro la sua pianta
			var pol := PackedVector2Array(angoli)
			for m in _muri_rovine:
				var pm: Array = m.poly
				if Geometry2D.is_point_in_polygon(Vector2(float(pm[0][0]), float(pm[0][1])), pol):
					_muro(pm, str(m.tipo), padre)
			continue
		var campanile: bool = lettera == "b" and "S13" in st.hex
		_stanza(padre, st, angoli, str(st.tipo) == "pietra", campanile, indice)

## Una stanza come è stampata: la faccia esterna dei muri sta esattamente sul contorno disegnato;
## finestre con telaio, vetri, persiane e davanzale, porte di legno, tetto a padiglione con gronda e coppi.
func _stanza(padre: Node3D, st: Dictionary, angoli: Array, pietra: bool, campanile: bool, indice: int) -> void:
	var nang := angoli.size()
	var base := 1e9
	var centro := Vector2.ZERO
	for p in angoli:
		base = minf(base, altezza_px(p))
		centro += p
	centro /= float(nang)
	base = minf(base, altezza_px(centro)) - 0.05
	# il verso dei vertici decide da che parte è l'interno
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(st.angoli))
	var intonacata := pietra and rng.randf() < 0.55
	var h_muri := 1.75 if campanile else ALTEZZA_CASA
	var muri := SurfaceTool.new()
	muri.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zoccolo := SurfaceTool.new()
	zoccolo.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vetri := SurfaceTool.new()
	vetri.begin(Mesh.PRIMITIVE_TRIANGLES)
	var telai := SurfaceTool.new()
	telai.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ante := SurfaceTool.new()
	ante.begin(Mesh.PRIMITIVE_TRIANGLES)
	var porte := SurfaceTool.new()
	porte.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tetto := SurfaceTool.new()
	tetto.begin(Mesh.PRIMITIVE_TRIANGLES)
	var legni := SurfaceTool.new()
	legni.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tile_muro := 0.75 if (intonacata or not pietra) else 0.6
	for i in nang:
		var p: Vector2 = angoli[i]
		var q: Vector2 = angoli[(i + 1) % nang]
		var dentro := (centro - (p + q) / 2.0).normalized()
		# perpendicolare al lato, verso l'interno
		var perp := (q - p).normalized().orthogonal()
		if perp.dot(dentro) < 0:
			perp = -perp
		var segs: Array = st.lati[i] if i < st.lati.size() else [[0.0, 1.0, "muro"]]
		for seg in segs:
			var a := p.lerp(q, float(seg[0]))
			var b := p.lerp(q, float(seg[1]))
			if a.distance_to(b) < 0.5:
				continue
			match str(seg[2]):
				"muro":
					_blocco_uv(muri, a, b, perp, base, base + h_muri, SPESSORE_MURO, p, tile_muro)
				"finestra":
					_finestre(muri, vetri, telai, ante, zoccolo, a, b, perp, base, h_muri, p, tile_muro)
				"porta":
					_porta(muri, porte, telai, a, b, perp, base, h_muri, p, tile_muro)
				_:
					# varco: resta solo l'architrave
					_blocco_uv(muri, a, b, perp, base + 0.7, base + h_muri, SPESSORE_MURO, p, tile_muro)
		# zoccolo e cornicione lungo tutto il lato
		_blocco_uv(zoccolo, p - perp * 1.2, q - perp * 1.2, perp, base, base + 0.1, SPESSORE_MURO + 0.012, p, 0.6)
		_blocco_uv(zoccolo, p - perp * 1.5, q - perp * 1.5, perp, base + h_muri - 0.05, base + h_muri, SPESSORE_MURO + 0.015, p, 0.6)
	var alto := base + h_muri
	if campanile:
		for i in nang:
			var p: Vector2 = angoli[i]
			var q: Vector2 = angoli[(i + 1) % nang]
			var perp := (q - p).normalized().orthogonal()
			if perp.dot(centro - (p + q) / 2.0) < 0:
				perp = -perp
			_blocco_uv(muri, p, p.lerp(q, 0.28), perp, alto, alto + 0.5, SPESSORE_MURO * 1.4, p, tile_muro)
			_blocco_uv(muri, p.lerp(q, 0.72), q, perp, alto, alto + 0.5, SPESSORE_MURO * 1.4, p, tile_muro)
			_blocco_uv(muri, p, q, perp, alto + 0.5, alto + 0.68, SPESSORE_MURO * 1.6, p, tile_muro)
			_blocco_uv(zoccolo, p - perp * 2.0, q - perp * 2.0, perp, alto - 0.05, alto + 0.02, SPESSORE_MURO * 1.9, p, 0.6)
		alto += 0.68
		var cima := Vector3(centro.x * K, alto + 0.95, centro.y * K)
		for i in nang:
			var p: Vector2 = centro + (angoli[i] - centro) * 1.08
			var q: Vector2 = centro + (angoli[(i + 1) % nang] - centro) * 1.08
			var nrm := (Vector3(p.x - centro.x, 0, p.y - centro.y) + Vector3(q.x - centro.x, 0, q.y - centro.y)).normalized()
			nrm = (nrm + Vector3.UP * 0.6).normalized()
			_tri_uv(tetto, [_p3(p, alto), cima, _p3(q, alto)], [Vector2(0, 0), Vector2(p.distance_to(q) * K * 0.5 / 0.5, 2.4), Vector2(p.distance_to(q) * K / 0.5, 0)], nrm)
	elif nang == 4:
		_tetto_padiglione(tetto, legni, angoli, centro, alto, pietra, rng)
	else:
		_tetto_piramide(tetto, angoli, centro, alto)
	# materiali (i muri sono della casa: diventano trasparenti quando si guarda dentro)
	var mat_muri: StandardMaterial3D
	if intonacata:
		mat_muri = _mat_trama("intonaco", Color.from_hsv(rng.randf_range(0.08, 0.13), rng.randf_range(0.05, 0.25), rng.randf_range(0.88, 1.0)))
	elif pietra:
		mat_muri = _mat_trama("pietra", Color(rng.randf_range(0.92, 1.0), rng.randf_range(0.9, 0.98), rng.randf_range(0.86, 0.95)))
	else:
		mat_muri = _mat_trama("legno", Color(rng.randf_range(0.85, 1.0), rng.randf_range(0.82, 0.95), rng.randf_range(0.78, 0.9)))
	var mat_zoccolo := _mat_trama("pietra", Color(0.78, 0.76, 0.72))
	var mat_tetto := _mat_trama("tegole" if pietra else "scandole", Color(rng.randf_range(0.72, 0.86), rng.randf_range(0.74, 0.86), rng.randf_range(0.74, 0.88)), 0.85)
	mat_tetto.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mat_vetri := StandardMaterial3D.new()
	mat_vetri.albedo_color = Color(0.13, 0.16, 0.18)
	mat_vetri.roughness = 0.12
	mat_vetri.metallic = 0.35
	var tinte_ante := [Color("4d6b4a"), Color("6b4a32"), Color("4f6170"), Color("7a3a2e"), Color("8a8466")]
	var mat_telai := _materiale(Color("d9d2bf") if pietra else Color("4a3a2a"), 0.7)
	var mat_ante := _mat_trama("legno", tinte_ante[rng.randi() % tinte_ante.size()] * 1.6, 0.8)
	var mat_porte := _mat_trama("legno", Color(0.62, 0.48, 0.36), 0.8)
	var mat_legni := _mat_trama("legno", Color(0.5, 0.4, 0.32), 0.85)
	var n := Node3D.new()
	padre.add_child(n)
	var casa := {"hex": [], "muri": [], "tetto": [], "dettagli": [], "mat": [], "aperta": false}
	for coppia in [[muri, mat_muri, "muri"], [zoccolo, mat_zoccolo, "muri"], [tetto, mat_tetto, "tetto"], [legni, mat_legni, "tetto"],
			[vetri, mat_vetri, "dettagli"], [telai, mat_telai, "dettagli"], [ante, mat_ante, "dettagli"], [porte, mat_porte, "dettagli"]]:
		var stt: SurfaceTool = coppia[0]
		stt.generate_tangents()
		var mesh := stt.commit()
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = coppia[1]
		n.add_child(mi)
		casa[coppia[2]].append(mi)
		if coppia[2] == "muri":
			casa.mat.append(coppia[1])
	var hexes: Array = st.hex.duplicate()
	var pol := PackedVector2Array(angoli)
	for h in E.tutti():
		if not h in hexes and Geometry2D.is_point_in_polygon(centro_px(h), pol):
			hexes.append(h)
	casa.hex = hexes
	_case.append(casa)

## Una o più finestre nel tratto a–b: davanzale, telaio a croce, vetri scuri e persiane aperte.
func _finestre(muri: SurfaceTool, vetri: SurfaceTool, telai: SurfaceTool, ante: SurfaceTool, zoccolo: SurfaceTool,
		a: Vector2, b: Vector2, perp: Vector2, base: float, h_muri: float, origine: Vector2, tile: float) -> void:
	var lung := a.distance_to(b) * K
	var dir := (b - a).normalized()
	var y0 := base + 0.36
	var y1 := base + 0.7
	# tratti lunghi: più finestre separate da pilastri
	var n := maxi(1, int(round(lung / 0.42)))
	var passo := lung / n
	var largo := minf(passo * 0.72, 0.3)
	var cursore := a
	for k in n:
		var c := a + dir * (passo * (k + 0.5)) / K
		var w1 := c - dir * (largo / 2.0) / K
		var w2 := c + dir * (largo / 2.0) / K
		if w1.distance_to(cursore) > 0.5:
			_blocco_uv(muri, cursore, w1, perp, base, base + h_muri, SPESSORE_MURO, origine, tile)
		_blocco_uv(muri, w1, w2, perp, base, y0, SPESSORE_MURO, origine, tile)
		_blocco_uv(muri, w1, w2, perp, y1, base + h_muri, SPESSORE_MURO, origine, tile)
		# vetro arretrato a metà muro
		var mezzo := perp * (SPESSORE_MURO * 0.55) / K
		_blocco_uv(vetri, w1 + mezzo, w2 + mezzo, perp, y0, y1, 0.01, origine, 1.0)
		# telaio: montanti, traverso e croce
		var spt := 0.022
		var dp := perp * (SPESSORE_MURO * 0.45) / K
		_blocco_uv(telai, w1 + dp, w1 + dp + dir * spt / K, perp, y0, y1, 0.035, origine, 1.0)
		_blocco_uv(telai, w2 + dp - dir * spt / K, w2 + dp, perp, y0, y1, 0.035, origine, 1.0)
		_blocco_uv(telai, w1 + dp, w2 + dp, perp, y1 - spt, y1, 0.035, origine, 1.0)
		_blocco_uv(telai, w1 + dp, w2 + dp, perp, y0, y0 + spt, 0.035, origine, 1.0)
		_blocco_uv(telai, c + dp - dir * 0.008 / K, c + dp + dir * 0.008 / K, perp, y0, y1, 0.025, origine, 1.0)
		_blocco_uv(telai, w1 + dp, w2 + dp, perp, (y0 + y1) / 2.0 + 0.04, (y0 + y1) / 2.0 + 0.055, 0.025, origine, 1.0)
		# davanzale sporgente
		var fuori := -perp * 0.035 / K
		_blocco_uv(zoccolo, w1 - dir * 0.02 / K + fuori, w2 + dir * 0.02 / K + fuori, perp, y0 - 0.03, y0, 0.06, origine, 0.6)
		# persiane aperte contro il muro, ai due lati
		var f2 := -perp * 0.012 / K
		_blocco_uv(ante, w1 - dir * (largo / 2.0) / K + f2, w1 + f2, perp, y0, y1, 0.012, origine, 0.5)
		_blocco_uv(ante, w2 + f2, w2 + dir * (largo / 2.0) / K + f2, perp, y0, y1, 0.012, origine, 0.5)
		cursore = w2
	if b.distance_to(cursore) > 0.5:
		_blocco_uv(muri, cursore, b, perp, base, base + h_muri, SPESSORE_MURO, origine, tile)

## Porta: architrave, stipiti e battente di legno a doghe arretrato.
func _porta(muri: SurfaceTool, porte: SurfaceTool, telai: SurfaceTool, a: Vector2, b: Vector2, perp: Vector2, base: float, h_muri: float, origine: Vector2, tile: float) -> void:
	var lung := a.distance_to(b) * K
	var dir := (b - a).normalized()
	var largo := minf(lung, 0.26)
	var c := (a + b) / 2.0
	var p1 := c - dir * (largo / 2.0) / K
	var p2 := c + dir * (largo / 2.0) / K
	if p1.distance_to(a) > 0.5:
		_blocco_uv(muri, a, p1, perp, base, base + h_muri, SPESSORE_MURO, origine, tile)
	if b.distance_to(p2) > 0.5:
		_blocco_uv(muri, p2, b, perp, base, base + h_muri, SPESSORE_MURO, origine, tile)
	var y1 := base + 0.64
	_blocco_uv(muri, p1, p2, perp, y1, base + h_muri, SPESSORE_MURO, origine, tile)
	var dp := perp * (SPESSORE_MURO * 0.6) / K
	_blocco_uv(porte, p1 + dp, p2 + dp, perp, base, y1, 0.025, origine, 0.5)
	var spt := 0.02
	_blocco_uv(telai, p1 - perp * 0.005 / K, p1 + dir * spt / K - perp * 0.005 / K, perp, base, y1, SPESSORE_MURO * 0.7, origine, 1.0)
	_blocco_uv(telai, p2 - dir * spt / K - perp * 0.005 / K, p2 - perp * 0.005 / K, perp, base, y1, SPESSORE_MURO * 0.7, origine, 1.0)
	_blocco_uv(telai, p1 - dir * spt / K - perp * 0.006 / K, p2 + dir * spt / K - perp * 0.006 / K, perp, y1, y1 + spt * 1.5, SPESSORE_MURO * 0.7, origine, 1.0)

## Tetto a padiglione sopra un rettangolo: colmo lungo il lato lungo, gronda sporgente con
## frontalino di legno, colmo coperto e (a volte) un comignolo.
func _tetto_padiglione(st: SurfaceTool, legni: SurfaceTool, angoli: Array, centro: Vector2, alto: float, pietra: bool, rng: RandomNumberGenerator) -> void:
	var c: Array = []
	for p in angoli:
		var d: Vector2 = (p - centro)
		c.append(p + d.normalized() * GRONDA / K * 1.41)
	var l01: float = (c[1] as Vector2).distance_to(c[0])
	var l12: float = (c[2] as Vector2).distance_to(c[1])
	var u: Vector2 = ((c[1] - c[0]) as Vector2).normalized() if l01 >= l12 else ((c[2] - c[1]) as Vector2).normalized()
	var lungo := maxf(l01, l12)
	var corto := minf(l01, l12)
	var y_gronda := alto - 0.02
	var colmo := y_gronda + corto * K * (0.42 if pietra else 0.5)
	var r1 := centro - u * (lungo - corto) / 2.0
	var r2 := centro + u * (lungo - corto) / 2.0
	var R1 := Vector3(r1.x * K, colmo, r1.y * K)
	var R2 := Vector3(r2.x * K, colmo, r2.y * K)
	var tile := 0.62 if pietra else 0.6
	for i in 4:
		var p: Vector2 = c[i]
		var q: Vector2 = c[(i + 1) % 4]
		var mezzo := (p + q) / 2.0
		var rp := R1 if p.distance_to(r1) < p.distance_to(r2) else R2
		var rq := R1 if q.distance_to(r1) < q.distance_to(r2) else R2
		var fuori := (mezzo - centro).normalized()
		var dir := (q - p).normalized()
		var falda := sqrt(pow(colmo - y_gronda, 2.0) + pow(_dist_linea(centro, p, q) * K, 2.0))
		# coordinate di trama: U lungo la gronda, V su per la falda
		var uv := func(v3: Vector3) -> Vector2:
			var d2 := Vector2(v3.x / K, v3.z / K) - p
			var su := d2.dot(dir) * K
			var lungo_falda := (v3.y - y_gronda) / maxf(colmo - y_gronda, 0.001) * falda
			return Vector2(su / tile, -lungo_falda / tile)
		var a3 := _p3(p, y_gronda)
		var b3 := _p3(q, y_gronda)
		var e1: Vector3 = b3 - a3
		var e2: Vector3 = rp - a3
		var nrm := e1.cross(e2).normalized()
		if nrm.y < 0:
			nrm = -nrm
		_tri_uv(st, [a3, rp, b3], [uv.call(a3), uv.call(rp), uv.call(b3)], nrm)
		if rp != rq:
			_tri_uv(st, [rp, rq, b3], [uv.call(rp), uv.call(rq), uv.call(b3)], nrm)
		# frontalino sotto la gronda
		_blocco_uv(legni, p, q, -fuori, y_gronda - 0.045, y_gronda, 0.02, p, 0.5)
	# colmo: una fila di coppi più scuri
	var dc := (r2 - r1).normalized()
	if r1.distance_to(r2) > 1.0:
		_blocco_uv(st, r1 - dc * 2.0, r2 + dc * 2.0, dc.orthogonal(), colmo - 0.02, colmo + 0.025, 0.035, r1, 0.5, true)
	# comignolo sulle case in muratura
	if pietra and rng.randf() < 0.7:
		var lato := 1.0 if rng.randf() < 0.5 else -1.0
		var pc := centro + u * lato * (lungo - corto) / 2.0 * 0.6 + u.orthogonal() * corto * 0.12
		var hgt := colmo + 0.22
		var s := 0.06 / K
		var q1 := pc - u * s - u.orthogonal() * s * 0.8
		var q2 := pc + u * s - u.orthogonal() * s * 0.8
		_blocco_uv(legni, q1, q2, u.orthogonal(), y_gronda + 0.1, hgt, 0.12, q1, 0.4)

func _dist_linea(c: Vector2, p: Vector2, q: Vector2) -> float:
	return c.distance_to(Geometry2D.get_closest_point_to_segment_uncapped(c, p, q))

## Pianta non rettangolare: tetto a piramide.
func _tetto_piramide(st: SurfaceTool, angoli: Array, centro: Vector2, alto: float) -> void:
	var cima := _p3(centro, alto + 0.4)
	for i in angoli.size():
		var p: Vector2 = centro + (angoli[i] - centro) * 1.06
		var q: Vector2 = centro + (angoli[(i + 1) % angoli.size()] - centro) * 1.06
		var a3 := _p3(p, alto)
		var b3 := _p3(q, alto)
		var nrm := (b3 - a3).cross(cima - a3).normalized()
		if nrm.y < 0:
			nrm = -nrm
		var l := p.distance_to(q) * K
		_tri_uv(st, [a3, cima, b3], [Vector2(0, 0), Vector2(l / 1.0, -1.0), Vector2(l / 0.5, 0)], nrm)

func _p3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x * K, y, p.y * K)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

## Triangolo con coordinate di trama, girato in modo che la faccia anteriore guardi verso n.
func _tri_uv(st: SurfaceTool, v: Array, uv: Array, n: Vector3) -> void:
	var ordine := [0, 1, 2]
	if ((v[1] as Vector3) - (v[0] as Vector3)).cross((v[2] as Vector3) - (v[0] as Vector3)).dot(n) > 0:
		ordine = [0, 2, 1]
	for k in ordine:
		st.set_normal(n)
		st.set_uv(uv[k])
		st.add_vertex(v[k])

## Parallelepipedo tra due punti della pianta (pixel), da quota y0 a y1, spessore verso «dentro».
## Coordinate di trama in unità 3D / tile: U lungo il muro a partire da «origine», V in altezza.
func _blocco_uv(st: SurfaceTool, a: Vector2, b: Vector2, dentro: Vector2, y0: float, y1: float, spess: float, origine: Vector2, tile: float, _colmo := false) -> void:
	var a2 := a + dentro * spess / K
	var b2 := b + dentro * spess / K
	var dir := (b - a).normalized()
	var ua := (a - origine).dot(dir) * K / tile
	var ub := (b - origine).dot(dir) * K / tile
	var v0 := -y0 / tile
	var v1 := -y1 / tile
	var fuori := -dentro
	var n_f := Vector3(fuori.x, 0, fuori.y)
	var n_d := Vector3(dentro.x, 0, dentro.y)
	var n_a := Vector3(-dir.x, 0, -dir.y)
	var n_b := Vector3(dir.x, 0, dir.y)
	# faccia esterna (a → b), interna (b2 → a2), testate
	_quad(st, _p3(a, y0), _p3(b, y0), _p3(b, y1), _p3(a, y1), Vector2(ua, v0), Vector2(ub, v0), Vector2(ub, v1), Vector2(ua, v1), n_f)
	_quad(st, _p3(b2, y0), _p3(a2, y0), _p3(a2, y1), _p3(b2, y1), Vector2(ub, v0), Vector2(ua, v0), Vector2(ua, v1), Vector2(ub, v1), n_d)
	var s := spess / tile
	_quad(st, _p3(a2, y0), _p3(a, y0), _p3(a, y1), _p3(a2, y1), Vector2(0, v0), Vector2(s, v0), Vector2(s, v1), Vector2(0, v1), n_a)
	_quad(st, _p3(b, y0), _p3(b2, y0), _p3(b2, y1), _p3(b, y1), Vector2(0, v0), Vector2(s, v0), Vector2(s, v1), Vector2(0, v1), n_b)
	_quad(st, _p3(a, y1), _p3(b, y1), _p3(b2, y1), _p3(a2, y1), Vector2(ua, 0), Vector2(ub, 0), Vector2(ub, s), Vector2(ua, s), Vector3.UP)

## Quadrilatero a–b–c–d con le sue coordinate di trama; le facce vanno in senso orario visto dalla normale.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ta: Vector2, tb: Vector2, tc: Vector2, td: Vector2, n: Vector3) -> void:
	_tri_uv(st, [a, b, c], [ta, tb, tc], n)
	_tri_uv(st, [a, c, d], [ta, tc, td], n)

## Tetti e muri si aprono quando si interagisce con chi sta dentro.
func _aggiorna_case() -> void:
	if _case.is_empty():
		return
	var interessati := {}
	var p: Partita = mappa2d.partita
	for x in mappa2d._stati_visibili().values():
		interessati[str(x.hex)] = true
	for h in mappa2d.evidenzia:
		interessati[str(h)] = true
	if sopra != "":
		interessati[sopra] = true
	for id in mappa2d.mobili:
		interessati[str(mappa2d.mobili[id].a)] = true
	for casa in _case:
		var aperta := false
		for h in casa.hex:
			if interessati.has(h):
				aperta = true
				break
		if aperta == casa.aperta:
			continue
		casa.aperta = aperta
		for mat in casa.mat:
			var sm: StandardMaterial3D = mat
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if aperta else BaseMaterial3D.TRANSPARENCY_DISABLED
			sm.albedo_color.a = 0.28 if aperta else 1.0
		for nd in casa.tetto + casa.dettagli:
			nd.visible = not aperta
		for mi in casa.muri:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if aperta else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

# ================================================================== miniature dei soldati
## Le pedine diventano miniature 3D (assets/soldati3d, da tools/costruisci_soldati3d.py),
## scelte secondo parte, postura, stato e arma principale.
const DIR_SOLDATI := "res://assets/soldati3d/"
const VERSO_MODELLI := PI   # rotazione che porta il «davanti» delle miniature verso +Z
var _mesh_soldati: Dictionary = {}
var _figure: Dictionary = {}     # id unità -> Node3D
var _figure_nodo: Node3D
var _mat_soldati: Dictionary = {}

func _mesh_soldato(nome: String) -> Mesh:
	if _mesh_soldati.has(nome):
		return _mesh_soldati[nome]
	var m: Mesh = null
	var percorso := DIR_SOLDATI + nome + ".glb"
	if ResourceLoader.exists(percorso):
		var sc: PackedScene = load(percorso)
		var n := sc.instantiate()
		var mi := _trova_mesh(n)
		if mi != null:
			m = mi.mesh
		n.free()
	_mesh_soldati[nome] = m
	return m

func _trova_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _trova_mesh(c)
		if r != null:
			return r
	return null

static func _tipi_armi(x: Dictionary) -> Array:
	var out: Array = []
	for a in x.get("armi", []):
		out.append(str(a.get("tipo", "")) if a is Dictionary else str(a))
	return out

## Nome del modello per un'unità: miniature colorate del modulo TTS (tools/costruisci_soldati_tts.py),
## scelte per parte, arma principale e postura; a terra per i caduti e gli incapacitati.
static func modello_per(x: Dictionary) -> String:
	var us := str(x.get("lato", "us")) == "us"
	var armi := _tipi_armi(x)
	var post := str(x.get("postura", "standing"))
	var stato := str(x.get("stato", "attivo"))
	var lato := "us" if us else "de"
	if stato == "morto":
		return lato + "_morto"
	if stato == "incapacitato":
		return lato + "_ferito"
	var posa: String = {"prone": "prono", "crouching": "acc"}.get(post, "piedi")
	if stato in ["catturato", "arreso"]:
		posa = "piedi"
	var arma := ""
	if us:
		if "bazooka" in armi:
			arma = "bazooka"
		elif "ar" in armi or "lmg" in armi or "mmg" in armi or "hmg" in armi:
			arma = "bar"
		elif "smg" in armi or "mp" in armi:
			arma = "mitra"
		elif "carbine" in armi:
			arma = "carabina"
		elif armi.is_empty() or armi == ["pistol"]:
			arma = "mitra"
		else:
			arma = "garand"
	else:
		if "bazooka" in armi:
			return "de_pzf" if posa != "prono" else "de_fucile_prono"
		if "lmg" in armi or "mmg" in armi or "hmg" in armi:
			arma = "mg"
		elif "smg" in armi or "mp" in armi:
			arma = "mp"
		elif "scoped" in armi:
			arma = "ott"
		elif "sar" in armi or "ar" in armi:
			arma = "stg"
		elif armi.is_empty() or armi == ["pistol"]:
			arma = "pistola"
		else:
			arma = "fucile2" if int(x.get("num", 0)) % 2 == 1 else "fucile"
	return "%s_%s_%s" % [lato, arma, posa]

func _materiale_soldato(chiave: String) -> StandardMaterial3D:
	if _mat_soldati.has(chiave):
		return _mat_soldati[chiave]
	var c: Color = {"us": Color.WHITE, "de": Color.WHITE, "us_morto": Color(0.62, 0.6, 0.58), "de_morto": Color(0.62, 0.6, 0.58), "pzf": Color("6f7a73"),
		"us_base": Color("3d5c2c"), "de_base": Color("4a4e55"), "sel": Color("d9b44a"), "turno": Color("6fd35a")}.get(chiave, Color.WHITE)
	var m := _materiale(c, 0.75)
	if chiave in ["us", "de", "us_morto", "de_morto"]:
		# tessitura dipinta delle miniature del modulo TTS
		var tex: Texture2D = load(DIR_SOLDATI + "tessitura_%s.jpg" % chiave.substr(0, 2))
		m.albedo_texture = tex
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.5
	if chiave == "pzf":
		m.rim_enabled = true
		m.rim = 0.5
	if chiave in ["sel", "turno"]:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.8
	_mat_soldati[chiave] = m
	return m

const SCALA_FIGURE := 1.4

func _crea_figura(id: String) -> Node3D:
	var n := Node3D.new()
	n.name = "F_" + id
	n.scale = Vector3.ONE * SCALA_FIGURE
	var mi := MeshInstance3D.new()
	mi.name = "corpo"
	n.add_child(mi)
	var base := MeshInstance3D.new()
	base.name = "base"
	var cil := CylinderMesh.new()
	cil.top_radius = 0.17
	cil.bottom_radius = 0.18
	cil.height = 0.025
	cil.radial_segments = 16
	base.mesh = cil
	base.position.y = 0.012
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(base)
	var et := Label3D.new()
	et.name = "etichetta"
	et.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	et.no_depth_test = true
	et.fixed_size = true
	et.pixel_size = 0.0009
	et.font = Tema.testo_bold
	et.font_size = 18
	et.outline_size = 6
	et.outline_modulate = Color(0, 0, 0, 0.85)
	et.position.y = 0.66
	n.add_child(et)
	_figure_nodo.add_child(n)
	return n

func _aggiorna_pedine() -> void:
	if _figure_nodo == null:
		_figure_nodo = Node3D.new()
		mondo.add_child(_figure_nodo)
	var stati: Dictionary = mappa2d._stati_visibili()
	var per_hex := {}
	for id in stati:
		var d: Dictionary = stati[id]
		if mappa2d.mobili.has(id) or d.get("fuori_mappa_ph", false):
			continue
		if not per_hex.has(d.hex):
			per_hex[d.hex] = []
		per_hex[d.hex].append(d)
	var posti := {}
	for h in per_hex:
		var pila: Array = per_hex[h]
		pila.sort_custom(func(a, b): return mappa2d._ordine(a) < mappa2d._ordine(b))
		var pp: Array = mappa2d._posti(pila.size(), RAGGIO_PX)
		for i in pila.size():
			var r: Rect2 = pp[i]
			posti[pila[i].id] = centro_px(str(h)) + r.get_center() * 0.95
	var t_ora: float = mappa2d._t
	for id in mappa2d.mobili:
		if not stati.has(id):
			continue
		var m: Dictionary = mappa2d.mobili[id]
		var k := clampf((t_ora - float(m.t0)) / float(m.dur), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		posti[id] = centro_px(str(m.da)).lerp(centro_px(str(m.a)), k) + Vector2(float(m.off), -float(m.off))
	var di_turno: Array = [] if mappa2d.vista != null else mappa2d.partita.americani_di_turno().map(func(a): return a.id)
	var visti := {}
	for id in posti:
		var x: Dictionary = stati[id]
		# equipaggio di un carro o di una motosilurante: lo rappresenta il mezzo (vedi _aggiorna_mezzi)
		var vx: Dictionary = mappa2d.partita.s.get("veicoli", {}).get(str(x.get("veicolo", "")), {})
		if not vx.is_empty() and str(vx.get("modello", "")) in ["panzer4", "sherman", "jagdpanther", "eboat"]:
			continue
		# carri e mezzi corazzati: per ora restano segnalini sul terreno (miniature da aggiungere)
		if str(x.get("nome", "")) in ["Panzer IV", "Jagdpanther"] or x.get("carro_us", false):
			_carro_unita(str(id), x, posti[id])
			visti[id] = true
			continue
		visti[id] = true
		var fig: Node3D = _figure.get(id)
		if fig == null or not is_instance_valid(fig):
			fig = _crea_figura(str(id))
			_figure[id] = fig
		var pos2: Vector2 = posti[id]
		fig.position = punto3d(pos2)
		if int(x.get("piano", 0)) > 0 and mappa2d.partita != null and mappa2d.partita.piano(x) > 0:
			fig.position.y += ALTEZZA_CASA * 0.95  # al piano superiore del campanile
		var nome := modello_per(x)
		var ang_mezzo := INF
		# a bordo di un mezzo: seduti in fila lungo il mezzo
		var vm: Dictionary = _veicolo_di(x)
		if not vm.is_empty() and _mezzi.has(str(vm.id)):
			var nm: Node3D = _mezzi[str(vm.id)]
			var posto: int = vm.occupanti.find(str(id))
			var lung := 0.5 if str(vm.modello) == "canoa" else (0.8 if str(vm.modello) in ["chiatta", "scialuppa", "motovedetta"] else 0.35)
			var loc := Vector3(0, 0.1, (float(posto) - (vm.occupanti.size() - 1) / 2.0) * lung / maxf(1.0, vm.occupanti.size() - 1.0) * -1.0)
			if str(vm.modello) in ["chiatta", "scialuppa", "motovedetta"]:
				loc.x = -0.08 if posto % 2 == 0 else 0.08
			elif str(vm.modello) != "canoa":
				loc = Vector3(-0.1 if posto % 2 == 0 else 0.1, 0.12, 0.1 - 0.25 * (posto / 2))
			fig.position = nm.position + nm.basis * loc
			ang_mezzo = nm.rotation.y
			if not str(x.stato) in ["morto", "incapacitato"]:
				nome = nome.replace("_piedi", "_acc").replace("_prono", "_acc")
				if nome == "de_pzf":
					nome = "de_fucile_acc"
		_paracadute(fig, str(id), x)
		var corpo: MeshInstance3D = fig.get_node("corpo")
		if corpo.get_meta("modello", "") != nome:
			corpo.mesh = _mesh_mezzo(nome.substr(3)) if nome.begins_with("mz:") else _mesh_soldato(nome)
			corpo.set_meta("modello", nome)
		# mitragliatrice su treppiede davanti a chi la serve da accovacciato o prono
		var tre: MeshInstance3D = fig.get_node_or_null("treppiede")
		var serve_mg := str(x.lato) == "de" and str(x.stato) == "attivo" and str(x.get("postura", "")) != "standing" and _tipi_armi(x).any(func(a): return a in ["mmg", "hmg"])
		if serve_mg and tre == null:
			tre = MeshInstance3D.new()
			tre.name = "treppiede"
			tre.mesh = _mesh_mezzo("mg_treppiede")
			tre.material_override = _materiale(Color("3a3b38"), 0.6)
			fig.add_child(tre)
		if tre != null:
			tre.visible = serve_mg
		var morto := str(x.stato) == "morto"
		corpo.material_override = _materiale_soldato("pzf" if nome == "de_pzf" else (str(x.lato) + "_morto" if morto else str(x.lato)))
		# verso: gli americani guardano il tedesco visibile più vicino, i tedeschi l'americano più vicino
		var yaw := _verso(x, pos2) if ang_mezzo == INF else ang_mezzo
		corpo.rotation = Vector3(0, yaw + VERSO_MODELLI, deg_to_rad(80.0) if morto else 0.0)
		var tre2: MeshInstance3D = fig.get_node_or_null("treppiede")
		if tre2 != null and tre2.visible:
			tre2.rotation.y = yaw + VERSO_MEZZI
			tre2.scale = Vector3.ONE * 0.7
			tre2.position = Vector3(sin(yaw), 0, cos(yaw)) * 0.2
		corpo.position.y = 0.05 if morto else 0.0
		# Silver Star: chi nuota affiora fino alle spalle; chi è sott’acqua si intravede sotto la superficie.
		var ssx = mappa2d.partita.ss if mappa2d.partita != null else null
		var in_acqua_ss: bool = ssx != null and ssx.attiva() and str(x.stato) == "attivo" and ssx.in_acqua(x)
		var sotto_ss: bool = in_acqua_ss and ssx.sott_acqua(x)
		if in_acqua_ss:
			corpo.position.y = -0.12 if sotto_ss else -0.27
		corpo.transparency = 0.55 if sotto_ss else 0.0
		var base: MeshInstance3D = fig.get_node("base")
		var sel: bool = mappa2d.vista == null and id in mappa2d.selezionati
		var turno: bool = id in di_turno
		base.material_override = _materiale_soldato("sel" if sel else ("turno" if turno else str(x.lato) + "_base"))
		var et: Label3D = fig.get_node("etichetta")
		var testo := str(x.get("lettera", id))
		if str(x.lato) == "de" and x.has("num"):
			testo = "%s %d" % [testo, int(x.num) % 100]
		var extra: Array = []
		if x.get("panico", false):
			extra.append("PANICO")
		if x.get("ferito", false) and str(x.stato) == "attivo":
			extra.append("FERITO")
		if str(x.stato) in ["incapacitato", "morto", "catturato", "arreso"]:
			extra.append({"incapacitato": "INCAPACITATO", "morto": "UCCISO", "catturato": "PRIGIONIERO", "arreso": "ARRESO"}[str(x.stato)])
		if sotto_ss:
			extra.append("SOTT’ACQUA")
		if x.get("barca_ss", false) and str(x.stato) == "attivo":
			extra.append("BARCA DI GUARDIA")
		if not extra.is_empty():
			testo += "\n" + " · ".join(extra)
		et.text = testo
		et.modulate = Color("f2d77a") if str(x.lato) == "us" else Color("f0f0ea")
		if sel:
			et.modulate = Color("fff3c4")
		et.position.y = 0.3 if str(x.get("postura", "")) == "prone" or str(x.stato) in ["morto", "incapacitato"] else 0.66
	for id in _carri_unita.keys():
		if not visti.has(id):
			if is_instance_valid(_carri_unita[id]):
				_carri_unita[id].queue_free()
			_carri_unita.erase(id)
	for id in _figure.keys():
		if not visti.has(id):
			if is_instance_valid(_figure[id]):
				_figure[id].queue_free()
			_figure.erase(id)

func _verso(x: Dictionary, da: Vector2) -> float:
	var dz: Array = mappa2d.direzioni.get(str(x.id), [])
	if dz.size() == 2 and E.valido(str(dz[0])) and E.valido(str(dz[1])):
		var dv := centro_px(str(dz[1])) - centro_px(str(dz[0]))
		return atan2(dv.x, dv.y)
	var nemico := "de" if str(x.lato) == "us" else "us"
	var migliore := 1e9
	var dir := Vector2(0, 1) if nemico == "de" else Vector2(0, -1)
	for id in mappa2d.partita.s.unita:
		var y: Dictionary = mappa2d.partita.s.unita[id]
		if str(y.lato) != nemico or str(y.get("hex", "")) == "" or not str(y.stato) in ["attivo"]:
			continue
		if nemico == "de" and not mappa2d.partita.attivo(y):
			continue
		var c := centro_px(str(y.hex))
		var d := c.distance_squared_to(da)
		if d < migliore and d > 1.0:
			migliore = d
			dir = c - da
	# angolo attorno a Y: 0 = guarda verso +Z (sud sulla mappa)
	return atan2(dir.x, dir.y)


# ================================================================== mezzi
## Mezzi (assets/mezzi3d, da tools/costruisci_mezzi3d.py): Jeep, Kübelwagen, auto comando, canoe,
## Sherman, Panzer IV (scafo disegnato qui con la torretta del kit), Jagdpanther.
const DIR_MEZZI := "res://assets/mezzi3d/"
const VERSO_MEZZI := 0.0   # i mezzi sono salvati col davanti verso +Z
var _mezzi: Dictionary = {}       # id veicolo -> Node3D
var _carri_unita: Dictionary = {} # id unità carro tedesca -> Node3D
var _mezzi_nodo: Node3D
var _mesh_mezzi: Dictionary = {}

func _mesh_mezzo(nome: String) -> Mesh:
	if _mesh_mezzi.has(nome):
		return _mesh_mezzi[nome]
	var m: Mesh = null
	if ResourceLoader.exists(DIR_MEZZI + nome + ".glb"):
		var n := (load(DIR_MEZZI + nome + ".glb") as PackedScene).instantiate()
		var mi := _trova_mesh(n)
		if mi != null:
			m = mi.mesh
		n.free()
	_mesh_mezzi[nome] = m
	return m

func _veicolo_di(x: Dictionary) -> Dictionary:
	var vid := str(x.get("veicolo", ""))
	if vid == "":
		return {}
	return mappa2d.partita.s.get("veicoli", {}).get(vid, {})

func _nodo_mezzo(modello: String, lato: String) -> Node3D:
	var n := Node3D.new()
	var corpo := MeshInstance3D.new()
	corpo.name = "corpo"
	var nome_mesh := "kubelwagen" if modello in ["auto_comando", "moto", "camion", "atg"] else ("canoa" if modello in ["chiatta", "scialuppa", "motovedetta"] else modello)
	corpo.mesh = _mesh_mezzo(nome_mesh)
	corpo.material_override = _materiale_dipinto(nome_mesh, Color(0.75, 0.75, 0.78) if modello == "auto_comando" else (Color(0.62, 0.52, 0.42) if modello == "chiatta" else (Color(0.78, 0.76, 0.7) if modello in ["scialuppa", "motovedetta"] else Color.WHITE)))
	if modello == "auto_comando":
		corpo.scale = Vector3(1.08, 1.05, 1.12)
	if modello == "moto":
		corpo.scale = Vector3(0.55, 0.8, 0.6)
	if modello == "camion":
		corpo.scale = Vector3(1.45, 1.55, 1.8)  # camion americano: carrozzeria più grande e alta
		corpo.material_override = _materiale_dipinto(nome_mesh, Color(0.55, 0.6, 0.42))
		# cassone telonato dietro la cabina
		_scatola(n, Vector3(0, 0.3, 0.22), Vector3(0.34, 0.26, 0.5), 0.0, _materiale(Color("6b6a4a"), 0.85))
	if modello == "eboat":
		# Motosilurante (Purple Heart 13): scafo affusolato, plancia e due tubi lanciasiluri, costruiti qui.
		corpo.mesh = null
		var grigio := _materiale(Color("7b8083"), 0.6)
		var scafo := PrismMesh.new()
		scafo.size = Vector3(0.36, 0.16, 1.5)
		scafo.left_to_right = 0.5
		var ms := MeshInstance3D.new()
		ms.mesh = scafo
		ms.material_override = grigio
		ms.rotation = Vector3(PI, 0, 0)
		ms.position = Vector3(0, 0.1, 0)
		corpo.add_child(ms)
		_scatola(corpo, Vector3(0, 0.17, 0.1), Vector3(0.34, 0.05, 1.2), 0.0, grigio)
		_scatola(corpo, Vector3(0, 0.27, 0.05), Vector3(0.2, 0.16, 0.3), 0.0, _materiale(Color("62686b"), 0.6))
		for k in [-1, 1]:
			var tubo := CylinderMesh.new()
			tubo.top_radius = 0.035
			tubo.bottom_radius = 0.035
			tubo.height = 0.5
			var mt := MeshInstance3D.new()
			mt.mesh = tubo
			mt.material_override = _materiale(Color("4b4f50"), 0.5)
			mt.rotation = Vector3(PI / 2.0, 0, 0)
			mt.position = Vector3(0.11 * k, 0.22, -0.35)
			corpo.add_child(mt)
	if modello in ["chiatta", "scialuppa", "motovedetta"]:
		corpo.scale = Vector3(1.9, 1.2, 1.6)  # chiatta e scialuppa: grosse barche da dieci posti
	n.add_child(corpo)
	var et := Label3D.new()
	et.name = "etichetta"
	et.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	et.no_depth_test = true
	et.fixed_size = true
	et.pixel_size = 0.0009
	et.font = Tema.testo_bold
	et.font_size = 16
	et.outline_size = 6
	et.outline_modulate = Color(0, 0, 0, 0.85)
	et.position.y = 0.95
	n.add_child(et)
	if _mezzi_nodo == null:
		_mezzi_nodo = Node3D.new()
		mondo.add_child(_mezzi_nodo)
	_mezzi_nodo.add_child(n)
	return n

## Materiale con la tessitura dipinta del modulo TTS (assets/mezzi3d/<nome>.jpg).
var _mat_dipinti: Dictionary = {}

func _materiale_dipinto(nome: String, tinta := Color.WHITE) -> StandardMaterial3D:
	var k := nome + tinta.to_html()
	if _mat_dipinti.has(k):
		return _mat_dipinti[k]
	var m := _materiale(tinta, 0.8)
	if ResourceLoader.exists(DIR_MEZZI + nome + ".jpg"):
		m.albedo_texture = load(DIR_MEZZI + nome + ".jpg")
	_mat_dipinti[k] = m
	return m

func _angolo_fronte(h: String, fronte: int) -> float:
	var v := E.vicino(h, clampi(fronte, 0, 5))
	if v == "":
		return 0.0
	var d := centro_px(v) - centro_px(h)
	return atan2(d.x, d.y)

func _aggiorna_mezzi() -> void:
	var p: Partita = mappa2d.partita
	var vista_v: Dictionary = p.s.get("veicoli", {})
	var visti := {}
	for veic in vista_v.values():
		if str(veic.hex) == "" or str(veic.stato) == "uscito" or veic.get("fuori_mappa_ph", false):
			continue
		var vid := str(veic.id)
		visti[vid] = true
		var n: Node3D = _mezzi.get(vid)
		if n == null or not is_instance_valid(n):
			n = _nodo_mezzo(str(veic.modello), str(veic.lato))
			_mezzi[vid] = n
		var c := centro_px(str(veic.hex))
		# se il mezzo si sta muovendo con chi lo guida, segue l'animazione
		for x in veic.occupanti:
			if mappa2d.mobili.has(x):
				var m: Dictionary = mappa2d.mobili[x]
				var k := clampf((float(mappa2d._t) - float(m.t0)) / float(m.dur), 0.0, 1.0)
				k = k * k * (3.0 - 2.0 * k)
				c = centro_px(str(m.da)).lerp(centro_px(str(m.a)), k)
				break
		var acqua := str(veic.modello) in ["canoa", "chiatta", "scialuppa", "motovedetta"] and p.terreno.tipo(str(veic.hex)) in ["stream", "water"]
		n.position = punto3d(c)
		if acqua:
			n.position.y = (_quota_base(c) - 1.0) * LIVELLO - 0.1
		n.rotation.y = _angolo_fronte(str(veic.hex), int(veic.get("fronte", 0)))
		var corpo: MeshInstance3D = n.get_node("corpo")
		var fuori_uso := str(veic.stato) != "attivo"
		if fuori_uso:
			corpo.material_override = _materiale_dipinto(("kubelwagen" if str(veic.modello) == "auto_comando" else str(veic.modello)), Color(0.3, 0.28, 0.26))
		var et: Label3D = n.get_node("etichetta")
		et.text = str(veic.nome).to_upper() + (" FUORI USO" if fuori_uso else "")
		et.visible = fuori_uso or sopra == str(veic.hex)
		if str(veic.modello) in ["panzer4", "jagdpanther", "eboat"] and str(veic.lato) == "de":
			# carro o motosilurante di una carta: si mostra la lettera e il numero dell'equipaggio
			for oid in veic.occupanti:
				var ox: Dictionary = p.s.unita.get(str(oid), {})
				if not ox.is_empty() and str(ox.get("lettera", "")) != "":
					et.text = "%s %d%s" % [str(ox.lettera), int(ox.get("num", 0)) % 100, " FUORI USO" if fuori_uso else ""]
					et.visible = true
					break
	for vid in _mezzi.keys():
		if not visti.has(vid):
			if is_instance_valid(_mezzi[vid]):
				_mezzi[vid].queue_free()
			_mezzi.erase(vid)

## Carri tedeschi che sono unità (Panzer IV, Jagdpanther delle carte).
func _carro_unita(id: String, x: Dictionary, pos: Vector2) -> void:
	var modello := "jagdpanther" if str(x.nome) == "Jagdpanther" else "panzer4"
	if x.get("carro_us", false):
		return   # lo Sherman è già tra i veicoli
	var n: Node3D = _carri_unita.get(id)
	if n == null or not is_instance_valid(n):
		n = _nodo_mezzo(modello, "de")
		_carri_unita[id] = n
	n.position = punto3d(centro_px(str(x.hex)) if not mappa2d.mobili.has(id) else pos)
	n.rotation.y = _verso(x, pos)
	var et: Label3D = n.get_node("etichetta")
	var morto := str(x.stato) == "morto"
	et.text = "%s %d%s" % [str(x.get("lettera", "")), int(x.get("num", 0)) % 100, " DISTRUTTO" if morto else ""]
	et.visible = true
	if morto:
		(n.get_node("corpo") as MeshInstance3D).material_override = _materiale_dipinto(modello, Color(0.3, 0.28, 0.26))

# ================================================================== paracadute (missione 4)
var _mesh_vela: Mesh
var _mat_vela: StandardMaterial3D

func _vela() -> Node3D:
	if _mesh_vela == null:
		var s := SphereMesh.new()
		s.radius = 0.55
		s.height = 0.55
		s.is_hemisphere = true
		s.radial_segments = 16
		s.rings = 6
		_mesh_vela = s
		_mat_vela = _materiale(Color("d9d4bf"), 0.9)
		_mat_vela.cull_mode = BaseMaterial3D.CULL_DISABLED
	var n := Node3D.new()
	n.name = "paracadute"
	var cupola := MeshInstance3D.new()
	cupola.name = "cupola"
	cupola.mesh = _mesh_vela
	cupola.material_override = _mat_vela
	cupola.position.y = 1.15
	n.add_child(cupola)
	var funi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 8:
		var a := TAU * i / 8.0
		im.surface_add_vertex(Vector3(0, 0.5, 0))
		im.surface_add_vertex(Vector3(cos(a) * 0.52, 1.15, sin(a) * 0.52))
	im.surface_end()
	funi.mesh = im
	funi.material_override = _materiale(Color("3b3a33"))
	funi.name = "funi"
	n.add_child(funi)
	return n

## Durante la discesa il soldato è in aria sotto la vela e ondeggia; appena atterrato la vela
## si affloscia accanto a lui e resta finché non si toglie il paracadute.
func _paracadute(fig: Node3D, id: String, x: Dictionary) -> void:
	var corpo: MeshInstance3D = fig.get_node("corpo")
	var vela: Node3D = fig.get_node_or_null("paracadute")
	var info: Dictionary = mappa2d.paracadutisti.get(id, {})
	var t_ora: float = mappa2d._t
	var quota := 0.0
	var aperta := false
	if not info.is_empty():
		var passo := int(info.get("passo", 0))
		var q0 := maxf(1.4, 4.2 - passo * 0.45)
		var q1 := maxf(1.2, 4.2 - (passo + 1) * 0.45)
		var m: Dictionary = mappa2d.mobili.get(id, {})
		if not m.is_empty():
			var k := clampf((t_ora - float(m.t0)) / float(m.dur), 0.0, 1.0)
			quota = lerpf(q0, q1, k)
		else:
			quota = q1
		aperta = true
		if float(info.get("atterra", -1.0)) >= 0.0:
			var k2 := clampf((t_ora - float(info.atterra)) / float(info.get("dur", 1.0)), 0.0, 1.0)
			quota = lerpf(q1, 0.0, 1.0 - (1.0 - k2) * (1.0 - k2))
			if k2 >= 1.0:
				mappa2d.paracadutisti.erase(id)
				aperta = false
	if aperta:
		if vela == null:
			vela = _vela()
			fig.add_child(vela)
		vela.visible = true
		fig.position.y += quota
		var oscilla := sin(t_ora * 2.3 + id.hash() % 7) * 0.12
		vela.rotation = Vector3(oscilla, 0, oscilla * 0.6)
		corpo.rotation.x = oscilla
		(vela.get_node("cupola") as MeshInstance3D).scale = Vector3.ONE
		vela.get_node("funi").visible = true
		vela.position = Vector3.ZERO
	elif int(x.get("paracadute", 0)) > 0 and str(x.stato) == "attivo":
		# a terra con l'imbracatura ancora addosso: vela afflosciata accanto
		if vela == null:
			vela = _vela()
			fig.add_child(vela)
		vela.visible = true
		vela.rotation = Vector3.ZERO
		vela.position = Vector3(0.22, -1.12, -0.18)
		(vela.get_node("cupola") as MeshInstance3D).scale = Vector3(1.0, 0.12, 0.8)
		vela.get_node("funi").visible = false
	elif vela != null:
		vela.visible = false

# ================================================================== camera
func _process(_delta: float) -> void:
	if not visible or mappa2d == null:
		return
	_sincronizza_velo()
	_aggiorna_oggetti()
	_aggiorna_mezzi()
	_aggiorna_pedine()
	_aggiorna_case()
	_dirada_alberi()
	_aggiorna_camera()

func _aggiorna_camera() -> void:
	beccheggio = clampf(beccheggio, 22.0, 88.0)
	distanza = clampf(distanza, 2.5, 48.0)
	bersaglio.x = clampf(bersaglio.x, 0.0, dim_px.x * K)
	bersaglio.z = clampf(bersaglio.z, 0.0, dim_px.y * K)
	bersaglio.y = altezza_px(Vector2(bersaglio.x, bersaglio.z) / K)
	var b := deg_to_rad(beccheggio)
	var dir := Vector3(sin(imbardata) * cos(b), sin(b), cos(imbardata) * cos(b))
	cam.position = bersaglio + dir * distanza
	cam.look_at(bersaglio, Vector3.UP)

func vista_iniziale() -> void:
	var ing: Array = mappa2d.partita.esagoni_ingresso() if mappa2d.partita != null else []
	var c := dim_px / 2.0
	if not ing.is_empty():
		c = Vector2.ZERO
		for h in ing:
			c += centro_px(str(h))
		c /= float(ing.size())
	if _tween != null and _tween.is_valid():
		_tween.kill()
	bersaglio = Vector3(c.x * K, 0, c.y * K)
	imbardata = 0.0
	beccheggio = 55.0
	distanza = 11.0
	_aggiorna_camera()

func centra() -> void:
	_vai_a(Vector3(dim_px.x * K / 2.0, 0, dim_px.y * K / 2.0), 46.0)

func centra_su(h: String) -> void:
	if h == "" or not E.valido(h):
		return
	var c := centro3d(h)
	_vai_a(c, minf(distanza, 12.0))

func zoom_a(fattore: float, _punto := Vector2.ZERO) -> void:
	distanza /= fattore
	_aggiorna_camera()

func _vai_a(dest: Vector3, dist: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "bersaglio", dest, 0.35)
	_tween.tween_property(self, "distanza", dist, 0.35)

func centro_schermo(h: String) -> Vector2:
	var c := centro3d(h)
	if cam.is_position_behind(c):
		return Vector2(-9999, -9999)
	return cam.unproject_position(c) * (size / Vector2(vp.size)) if vp.size.x > 0 else Vector2.ZERO

func assicura_visibili(esagoni: Array) -> void:
	var dentro := true
	var somma := Vector3.ZERO
	var n := 0
	var margine := Rect2(Vector2(60, 60), size - Vector2(120, 150))
	for h in esagoni:
		if str(h) == "" or not E.valido(str(h)):
			continue
		somma += centro3d(str(h))
		n += 1
		if not margine.has_point(centro_schermo(str(h))):
			dentro = false
	if n == 0 or dentro:
		return
	_vai_a(somma / float(n), distanza)

# ================================================================== input
func _raggio_esagono(pos: Vector2) -> String:
	var pv := pos * (Vector2(vp.size) / size)
	var o := cam.project_ray_origin(pv)
	var d := cam.project_ray_normal(pv)
	var t := 0.0
	var passo := 0.08
	var prec := o
	for i in 1500:
		var q := o + d * t
		var hq := altezza_px(Vector2(q.x, q.z) / K)
		if q.y <= hq:
			# raffina tra il punto precedente e questo
			var a := prec
			var b := q
			for k in 6:
				var m := (a + b) / 2.0
				if m.y <= altezza_px(Vector2(m.x, m.z) / K):
					b = m
				else:
					a = m
			return esagono_px(Vector2(b.x, b.z) / K)
		prec = q
		t += passo
		if q.y < -2.0:
			break
	return ""

func _imposta_sopra(h: String) -> void:
	if h != sopra:
		sopra = h
		mappa2d.sopra = h
		mappa2d.esagono_sopra.emit(h)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.pressed:
			_tocchi[st.index] = st.position
		else:
			_tocchi.erase(st.index)
		if _tocchi.size() >= 2:
			_multi = true
			_misura_due_dita()
		accept_event()
	elif ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		_tocchi[sd.index] = sd.position
		if _tocchi.size() >= 2:
			var k := _tocchi.keys()
			var a: Vector2 = _tocchi[k[0]]
			var b: Vector2 = _tocchi[k[1]]
			var dd := a.distance_to(b)
			var ang := (b - a).angle()
			var cc := (a + b) / 2.0
			if _prec_dist > 1.0 and dd > 1.0:
				distanza *= _prec_dist / dd
				imbardata -= wrapf(ang - _prec_ang, -PI, PI)
				beccheggio += (cc.y - _prec_centro.y) * 0.25
				_aggiorna_camera()
			_prec_dist = dd
			_prec_ang = ang
			_prec_centro = cc
		accept_event()
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_a(1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_a(1.0 / 1.12)
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_ruota = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_premuto = true
				_premuto_pos = mb.position
				_trascinato = false
				if _tocchi.size() < 2:
					_multi = false
			else:
				if _premuto and not _trascinato and not _multi:
					var h := _raggio_esagono(mb.position)
					if h != "":
						_imposta_sopra(h)
						mappa2d.esagono_cliccato.emit(h, MOUSE_BUTTON_LEFT)
				_premuto = false
		accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _tocchi.size() >= 2:
			return
		if _ruota:
			imbardata -= mm.relative.x * 0.008
			beccheggio += mm.relative.y * 0.25
			_aggiorna_camera()
		elif _premuto:
			if not _trascinato and mm.position.distance_to(_premuto_pos) > 10.0:
				_trascinato = true
			if _trascinato:
				_sposta(mm.relative)
		_imposta_sopra(_raggio_esagono(mm.position))
	elif ev is InputEventMagnifyGesture:
		zoom_a((ev as InputEventMagnifyGesture).factor)
	elif ev is InputEventPanGesture:
		_sposta(-(ev as InputEventPanGesture).delta * 12.0)

func _misura_due_dita() -> void:
	var k := _tocchi.keys()
	var a: Vector2 = _tocchi[k[0]]
	var b: Vector2 = _tocchi[k[1]]
	_prec_dist = a.distance_to(b)
	_prec_ang = (b - a).angle()
	_prec_centro = (a + b) / 2.0

## Trascinare sposta il terreno sotto il dito (sul piano, nella direzione in cui guarda la camera).
func _sposta(rel: Vector2) -> void:
	var avanti := Vector3(-sin(imbardata), 0, -cos(imbardata))
	var destra := Vector3(cos(imbardata), 0, -sin(imbardata))
	var scala := distanza * 0.0016 * (900.0 / maxf(size.y, 300.0))
	bersaglio -= destra * rel.x * scala
	bersaglio += avanti * rel.y * scala / maxf(0.35, sin(deg_to_rad(beccheggio)))
	_aggiorna_camera()
