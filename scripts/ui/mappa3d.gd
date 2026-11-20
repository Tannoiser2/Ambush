extends SubViewportContainer
## Vista 3D della mappa: rilievo dalle quote degli esagoni, fiume scavato, alberi, cespugli,
## erba alta, muri delle case diroccate, ponti e bunker. Sopra il terreno si stende un velo
## disegnato dalla mappa 2D (pedine, evidenziazioni, segnalini, linee di vista), così tutto
## il gioco funziona allo stesso modo anche in 3D.
## Mouse: trascina = sposta, tasto destro = ruota e inclina, rotella = zoom.
## Tocco: un dito sposta, due dita pizzicano (zoom), ruotano e, spostate in su o in giù, inclinano.

const E = preload("res://scripts/motore/esagoni.gd")
const MappaScript = preload("res://scripts/ui/mappa.gd")

const K := 0.01            # unità 3D per pixel della mappa
const LIVELLO := 0.42      # altezza di un livello di quota
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
var dim_px := Vector2(4200, 3840)
var gw := 0
var gh := 0
var alt := PackedFloat32Array()
var maschere: Image
var alberi_per_hex: Dictionary = {}   # esagono -> indici degli alberi
var alberi_mm: MultiMesh
var tronchi_mm: MultiMesh
var alberi_xf: Array = []             # trasformazioni originali delle chiome
var tronchi_xf: Array = []
var _firma_oggetti := ""
var _firma_pedine := ""

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
	luce.light_energy = 1.05
	luce.light_color = Color(1.0, 0.96, 0.88)
	luce.shadow_enabled = true
	luce.shadow_bias = 0.04
	luce.directional_shadow_max_distance = 45.0
	mondo.add_child(luce)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b2f24")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.78)
	env.ambient_light_energy = 0.55
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
	var l := str(mappa2d.partita.missione.get("mappa", "A")).to_lower() if mappa2d.partita != null else "a"
	if l == lettera and terreno_mi != null:
		_aggiorna_tessitura()
		return
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
		var d := p.distance_to(centro_px(hx)) / (RAGGIO_PX * 1.32)
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
	var acqua := PackedFloat32Array()
	acqua.resize(gw * gh)
	for j in gh:
		for i in gw:
			var p := Vector2(i * PASSO_GRIGLIA, j * PASSO_GRIGLIA)
			var y := (_quota_base(p) - 1.0) * LIVELLO
			var a := _maschera(p, 0)
			var c := _maschera(p, 1)
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
	tronchi_xf.clear()
	var percorso := "res://data/mappa_%s_3d.json" % lettera
	if not FileAccess.file_exists(percorso):
		return
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(percorso))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1983
	# Alberi: chioma tondeggiante + tronco
	var chioma := SphereMesh.new()
	chioma.radius = 1.0
	chioma.height = 1.7
	chioma.radial_segments = 9
	chioma.rings = 5
	chioma.material = _materiale(Color.WHITE, 0.95, true)
	var tronco := CylinderMesh.new()
	tronco.top_radius = 0.035
	tronco.bottom_radius = 0.055
	tronco.height = 1.0
	tronco.radial_segments = 5
	tronco.material = _materiale(Color("5a4330"))
	var lista: Array = d.get("alberi", [])
	alberi_mm = _multimesh(chioma, lista.size(), true)
	tronchi_mm = _multimesh(tronco, lista.size(), false)
	for i in lista.size():
		var a: Array = lista[i]
		var p := Vector2(float(a[0]), float(a[1]))
		var r := float(a[2]) * K * 0.95
		var base := punto3d(p)
		var alto := 0.32 + r * 1.1 + rng.randf_range(-0.05, 0.12)
		var xf := Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, r * rng.randf_range(0.85, 1.1), r)), base + Vector3(0, alto, 0))
		alberi_mm.set_instance_transform(i, xf)
		alberi_xf.append(xf)
		var verde := Color.from_hsv(rng.randf_range(0.24, 0.36), rng.randf_range(0.45, 0.7), rng.randf_range(0.32, 0.5))
		alberi_mm.set_instance_color(i, verde)
		var xt := Transform3D(Basis().scaled(Vector3(1, alto, 1)), base + Vector3(0, alto / 2.0, 0))
		tronchi_mm.set_instance_transform(i, xt)
		tronchi_xf.append(xt)
		var h := esagono_px(p)
		if not alberi_per_hex.has(h):
			alberi_per_hex[h] = []
		alberi_per_hex[h].append(i)
	_aggiungi_mm(alberi_mm, true)
	_aggiungi_mm(tronchi_mm, true)
	# Cespugli
	var cesp := SphereMesh.new()
	cesp.radius = 1.0
	cesp.height = 1.2
	cesp.radial_segments = 7
	cesp.rings = 4
	cesp.material = _materiale(Color.WHITE, 1.0, true)
	var lc: Array = d.get("cespugli", [])
	var cm := _multimesh(cesp, lc.size(), true)
	for i in lc.size():
		var c: Array = lc[i]
		var p := Vector2(float(c[0]), float(c[1]))
		var r := float(c[2]) * K * 1.1
		cm.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, r * 0.8, r * rng.randf_range(0.8, 1.2))), punto3d(p, r * 0.25)))
		cm.set_instance_color(i, Color.from_hsv(rng.randf_range(0.14, 0.22), rng.randf_range(0.45, 0.65), rng.randf_range(0.42, 0.58)))
	_aggiungi_mm(cm, false)
	# Erba alta (macchie di copertura)
	var ciuffo := CylinderMesh.new()
	ciuffo.top_radius = 0.0
	ciuffo.bottom_radius = 0.06
	ciuffo.height = 0.16
	ciuffo.radial_segments = 4
	ciuffo.rings = 1
	ciuffo.material = _materiale(Color.WHITE, 1.0, true)
	var lt: Array = d.get("ciuffi", [])
	var tm := _multimesh(ciuffo, lt.size(), true)
	for i in lt.size():
		var c: Array = lt[i]
		var p := Vector2(float(c[0]), float(c[1]))
		var s := rng.randf_range(0.7, 1.3)
		tm.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.6), s)), punto3d(p, 0.06 * s)))
		tm.set_instance_color(i, Color.from_hsv(rng.randf_range(0.13, 0.19), rng.randf_range(0.3, 0.45), rng.randf_range(0.5, 0.65)))
	_aggiungi_mm(tm, false)
	# Muri delle case diroccate
	for m in d.get("muri", []):
		_muro(m.poly, str(m.tipo))

func _aggiungi_mm(mm: MultiMesh, ombra: bool) -> void:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if ombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	oggetti.add_child(mi)

## Muro estruso dal contorno disegnato sulla mappa.
func _muro(poly_dati: Array, tipo: String) -> void:
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
	oggetti.add_child(mi)

# ================================================================== oggetti che cambiano con la partita
var _dinamici: Node3D

func _aggiorna_oggetti() -> void:
	var p: Partita = mappa2d.partita
	if p == null or p.s.is_empty():
		return
	var firma := str([p.s.get("modifiche", {}), p.s.get("bunker", {}).keys(), p.s.get("bunker", {}).values().map(func(b): return b.get("distrutto", false)),
		p.s.get("blocchi", []), p.s.get("ponti", {}).values().map(func(b): return b.get("distrutto", false)), lettera])
	if firma == _firma_oggetti:
		return
	_firma_oggetti = firma
	if _dinamici != null:
		_dinamici.queue_free()
	_dinamici = Node3D.new()
	mondo.add_child(_dinamici)
	var t: Terreno = p.terreno
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
	# Campanile (mappa B)
	if lettera == "b":
		var c := centro_px("S13")
		var base := Vector3(c.x * K, altezza_px(c), c.y * K)
		_scatola(_dinamici, base + Vector3(0, 0.75, 0), Vector3(0.42, 1.5, 0.42), 0.0, pietra)
		var tetto := CylinderMesh.new()
		tetto.top_radius = 0.0
		tetto.bottom_radius = 0.34
		tetto.height = 0.5
		tetto.radial_segments = 4
		var mt := MeshInstance3D.new()
		mt.mesh = tetto
		mt.material_override = _materiale(Color("6e4a3a"))
		mt.position = base + Vector3(0, 1.75, 0)
		mt.rotation.y = PI / 4.0
		_dinamici.add_child(mt)
	# Bunker (missione 6)
	for h in p.s.get("bunker", {}):
		var bk: Dictionary = p.s.bunker[h]
		var c := centro_px(str(h))
		var b3 := Vector3(c.x * K, altezza_px(c), c.y * K)
		if bk.get("distrutto", false):
			_macerie(_dinamici, c, 9, cemento)
		else:
			_scatola(_dinamici, b3 + Vector3(0, 0.22, 0), Vector3(0.95, 0.44, 0.95), 0.0, cemento)
			_scatola(_dinamici, b3 + Vector3(0, 0.3, 0), Vector3(0.97, 0.05, 0.97), 0.0, _materiale(Color("2d2f2b")))
	# Crateri e macerie
	for h in p.s.get("modifiche", {}):
		var tipo := str(p.s.modifiche[h])
		if tipo == "rubble":
			_macerie(_dinamici, centro_px(str(h)), 14, pietra)
	# Rocce degli esagoni accidentati
	for h in E.tutti():
		if t.tipo(h) == "rough":
			_macerie(_dinamici, centro_px(h), 10, _materiale(Color("8a8a80")))
	# Blocchi stradali (missione 8)
	for h in p.s.get("blocchi", []):
		var c := centro_px(str(h))
		for i in 3:
			_scatola(_dinamici, punto3d(c, 0.07 + i * 0.09), Vector3(0.9, 0.08, 0.08), 0.3 * i, legno)

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
	if p == null or p.s.is_empty() or alberi_mm == null:
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
			var xf: Transform3D = alberi_xf[i]
			var xt: Transform3D = tronchi_xf[i]
			var vicino := occupati.has(h) and Vector2(xf.origin.x / K, xf.origin.z / K).distance_to(c) < RAGGIO_PX * 0.85
			if vicino:
				# resta solo un alberello basso e trasparente alla vista
				alberi_mm.set_instance_transform(i, Transform3D(xf.basis.scaled(Vector3(0.35, 0.25, 0.35)), Vector3(xf.origin.x, xt.origin.y - xt.basis.y.y / 2.0 + 0.05, xf.origin.z)))
				tronchi_mm.set_instance_transform(i, Transform3D(xt.basis.scaled(Vector3(1, 0.05, 1)), xt.origin))
			else:
				alberi_mm.set_instance_transform(i, xf)
				tronchi_mm.set_instance_transform(i, xt)

# ================================================================== camera
func _process(_delta: float) -> void:
	if not visible or mappa2d == null:
		return
	_sincronizza_velo()
	_aggiorna_oggetti()
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
