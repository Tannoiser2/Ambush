extends Node3D
## Effetti della vista 3D: notte (esagoni in vista più chiari, il resto nel buio), nebbia procedurale a strati, bengala che
## illuminano davvero, colpi traccianti con la vampata, esplosioni con fiamma, fumo e detriti, incendi che bruciano e mezzi
## distrutti che fumano. Tutto con luci morbide (niente bianchi bruciati) e compatibile con il renderer GL Compatibility.

const E = preload("res://scripts/motore/esagoni.gd")

## Missioni notturne (vista limitata dal buio) e missioni con la nebbia.
const NOTTE := [4, 6, 9, 12, 13, 16, 19, 23]
const NEBBIA := [3, 23]
const CELLA := 16  # pixel della mappa per ogni pixel della maschera di luce

var m3  # la vista 3D (mappa3d.gd)
var notte := 0.0
var nebbia := 0.0
var _env: Environment
var _luce: DirectionalLight3D
var _riemp: DirectionalLight3D

# maschera di luce: r = esagono in vista, g = bengala
var _hex_pixel: PackedStringArray = PackedStringArray()
var _mw := 0
var _mh := 0
var _img: Image
var _tex: ImageTexture
var _firma_maschera := ""

var _strati_nebbia: Array = []

var _bengala: Dictionary = {}   # esagono -> nodo
var _fuochi: Dictionary = {}    # chiave -> nodo
var _visti: Dictionary = {}     # animazioni 2D già trasformate in effetti 3D
var _attivi: Array = []         # effetti a tempo: {nodo, t0, dur, tipo, ...}
var _t := 0.0
var _tex_morbida: Texture2D

func prepara(vista3d, env: Environment, luce: DirectionalLight3D, riempimento: DirectionalLight3D) -> void:
	m3 = vista3d
	_env = env
	_luce = luce
	_riemp = riempimento
	_tex_morbida = _sfumato()
	_env.glow_enabled = true
	_env.glow_intensity = 0.55
	_env.glow_strength = 0.9
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.05
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

## Da chiamare quando cambia la mappa: ricalcola quale esagono copre ogni pixel della maschera.
func nuova_mappa() -> void:
	_mw = int(ceil(m3.dim_px.x / CELLA))
	_mh = int(ceil(m3.dim_px.y / CELLA))
	_hex_pixel.resize(_mw * _mh)
	for j in _mh:
		for i in _mw:
			_hex_pixel[j * _mw + i] = m3.esagono_px(Vector2((i + 0.5) * CELLA, (j + 0.5) * CELLA))
	_img = Image.create(_mw, _mh, false, Image.FORMAT_RGBA8)
	_img.fill(Color(1, 0, 0, 1))
	_tex = ImageTexture.create_from_image(_img)
	_firma_maschera = ""
	for n in _bengala.values():
		n.queue_free()
	_bengala.clear()
	for n in _fuochi.values():
		n.queue_free()
	_fuochi.clear()
	_crea_nebbia()
	if m3.mat_terreno != null:
		m3.mat_terreno.set_shader_parameter("luce_mask", _tex)
	if m3.acqua_mi != null and m3.acqua_mi.material_override != null:
		m3.acqua_mi.material_override.set_shader_parameter("luce_mask", _tex)

var _conta := 0
var _ms := {}
func aggiorna(delta: float) -> void:
	_t += delta
	_conta += 1
	var p = m3.mappa2d.partita if m3.mappa2d != null else null
	if p == null or p.s.is_empty() or _img == null:
		return
	var t0 := Time.get_ticks_usec()
	_atmosfera(p)
	var t1 := Time.get_ticks_usec()
	_maschera_luce(p)
	var t2 := Time.get_ticks_usec()
	_aggiorna_bengala(p)
	_aggiorna_fuochi(p)
	_nuove_animazioni()
	_anima(delta)
	var t3 := Time.get_ticks_usec()
	if OS.has_environment("FX_PROFILO") and _conta % 20 == 0:
		print("fx ", _conta, " atm ", t1 - t0, " masch ", t2 - t1, " resto ", t3 - t2, " fps ", Engine.get_frames_per_second())

# ------------------------------------------------------------------ notte e nebbia
func _atmosfera(p) -> void:
	var lim: int = int(p.terreno.limite_vista)
	var vuole_notte := 1.0 if int(p.numero) in NOTTE else 0.0
	var vuole_nebbia := 0.0
	if int(p.numero) in NEBBIA and lim > 0:
		vuole_nebbia = clampf((9.0 - float(lim)) / 5.0, 0.35, 1.0)
	notte = move_toward(notte, vuole_notte, 0.02)
	nebbia = move_toward(nebbia, vuole_nebbia, 0.01)
	# Luna fredda e debole di notte, sole caldo di giorno; mai bianchi sovraesposti.
	_luce.light_energy = lerpf(0.72, 0.30, notte)
	_luce.light_color = Color(1.0, 0.96, 0.88).lerp(Color(0.62, 0.70, 0.92), notte)
	_riemp.light_energy = lerpf(0.28, 0.10, notte)
	_env.ambient_light_color = Color(0.72, 0.74, 0.78).lerp(Color(0.30, 0.36, 0.52), notte)
	_env.ambient_light_energy = lerpf(0.34, 0.22, notte)
	_env.background_color = Color("2b2f24").lerp(Color("0b0e16"), notte)
	var col_nebbia := Color(0.56, 0.58, 0.58).lerp(Color(0.16, 0.19, 0.26), notte)
	_env.fog_light_color = Color("3a3f31").lerp(col_nebbia, maxf(nebbia, notte * 0.6))
	_env.fog_density = 0.006 + nebbia * 0.055 + notte * 0.01
	_env.tonemap_exposure = lerpf(0.95, 1.05, notte)
	for mat in [m3.mat_terreno, m3.acqua_mi.material_override if m3.acqua_mi != null else null]:
		if mat != null:
			mat.set_shader_parameter("notte", notte)
			mat.set_shader_parameter("nebbia", nebbia)
	for s in _strati_nebbia:
		s.visible = nebbia > 0.01
		var mn: ShaderMaterial = s.material_override
		mn.set_shader_parameter("densita", nebbia)
		mn.set_shader_parameter("colore", col_nebbia)
		mn.set_shader_parameter("luce_mask", _tex)

## Maschera per esagono: in vista (r) se un americano attivo lo vede entro il limite di visibilità; illuminato da un bengala (g).
func _maschera_luce(p) -> void:
	var lim: int = int(p.terreno.limite_vista)
	var squadra: Array = p.americani_attivi_in_mappa() if p.has_method("americani_attivi_in_mappa") else []
	var firma := str([lim, notte > 0.5, nebbia > 0.01, p.terreno.illuminati.keys(), squadra.map(func(a): return [a.hex, a.postura])])
	if firma == _firma_maschera:
		return
	_firma_maschera = firma
	var in_vista := {}
	if lim > 0 and (notte > 0.0 or nebbia > 0.0):
		for a in squadra:
			if str(a.hex) == "":
				continue
			in_vista[a.hex] = true
			for h in E.tutti():
				if E.distanza(h, a.hex) <= lim and not in_vista.has(h) and p.terreno.vede(a.hex, h, a.postura if a.postura != "prone" else "crouching", "standing"):
					in_vista[h] = true
	var tutto := lim <= 0 or (notte <= 0.0 and nebbia <= 0.0)
	var dati := PackedByteArray()
	dati.resize(_mw * _mh * 4)
	for k in _hex_pixel.size():
		var h: String = _hex_pixel[k]
		var vis: int = 255 if tutto or in_vista.has(h) else 0
		var ill: int = 255 if p.terreno.illuminati.has(h) else 0
		dati[k * 4] = vis
		dati[k * 4 + 1] = ill
		dati[k * 4 + 2] = 0
		dati[k * 4 + 3] = 255
	_img.set_data(_mw, _mh, false, Image.FORMAT_RGBA8, dati)
	_tex.update(_img)

func _crea_nebbia() -> void:
	for s in _strati_nebbia:
		s.queue_free()
	_strati_nebbia.clear()
	var shader: Shader = load("res://scripts/ui/nebbia3d.gdshader")
	var lato: Vector2 = m3.dim_px * m3.K
	for i in 4:
		var pm := PlaneMesh.new()
		pm.size = lato * 1.15
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("strato", float(i))
		mat.set_shader_parameter("dim", lato)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(lato.x * 0.5, 0.3 + i * 0.3, lato.y * 0.5)
		mi.visible = false
		add_child(mi)
		_strati_nebbia.append(mi)

# ------------------------------------------------------------------ bengala
func _centri_bengala(p) -> Array:
	var out: Array = []
	for c in p.s.get("razzi", []):
		out.append(str(c))
	var ss_st: Dictionary = p.s.get("ss", {})
	for c in ss_st.get("m23", {}).get("razzi", []):
		out.append(str(c))
	return out

func _aggiorna_bengala(p) -> void:
	var centri: Array = _centri_bengala(p)
	for h in _bengala.keys():
		if not (h in centri):
			_bengala[h].queue_free()
			_bengala.erase(h)
	for h in centri:
		if _bengala.has(h) or not E.valido(h):
			continue
		var n := Node3D.new()
		n.position = m3.centro3d(h) + Vector3(0, 2.4, 0)
		var luce := OmniLight3D.new()
		luce.light_color = Color(1.0, 0.86, 0.62)
		luce.light_energy = 1.4
		luce.omni_range = 5.0
		luce.omni_attenuation = 1.4
		luce.shadow_enabled = false
		n.add_child(luce)
		var sfera := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.12
		sfera.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.92, 0.75)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.5)
		mat.emission_energy_multiplier = 2.0
		sfera.material_override = mat
		n.add_child(sfera)
		n.add_child(_particelle_scintille())
		add_child(n)
		n.set_meta("base_y", n.position.y)
		n.set_meta("t0", _t)
		_bengala[h] = n
	for h in _bengala:
		var n: Node3D = _bengala[h]
		var eta: float = _t - float(n.get_meta("t0"))
		# scende piano sotto il paracadute, ondeggiando, con la luce che tremola
		n.position.y = float(n.get_meta("base_y")) - fmod(eta * 0.05, 0.9)
		n.position.x += sin(eta * 0.7) * 0.0015
		var l: OmniLight3D = n.get_child(0)
		l.light_energy = 1.3 + 0.22 * sin(eta * 17.0) + 0.12 * sin(eta * 5.3)

# ------------------------------------------------------------------ incendi e relitti fumanti
func _aggiorna_fuochi(p) -> void:
	var voluti := {}
	for h in p.s.get("oggetti", {}):
		for o in p.s.oggetti[h]:
			if str(o.get("tipo", "")) == "incendio":
				voluti["fuoco:" + str(h)] = {"hex": str(h), "fiamme": true}
	for vid in p.s.get("veicoli", {}):
		var v: Dictionary = p.s.veicoli[vid]
		if str(v.get("hex", "")) != "" and str(v.get("stato", "")) in ["distrutto", "fuori_uso", "disabilitato"]:
			voluti["relitto:" + str(vid)] = {"hex": str(v.hex), "fiamme": str(v.get("stato", "")) == "distrutto"}
	for k in _fuochi.keys():
		if not voluti.has(k):
			_fuochi[k].queue_free()
			_fuochi.erase(k)
	for k in voluti:
		if _fuochi.has(k):
			continue
		var d: Dictionary = voluti[k]
		var n := Node3D.new()
		n.position = m3.centro3d(str(d.hex)) + Vector3(0.12, 0.05, -0.08)
		n.add_child(_particelle_fumo(1.0 if d.fiamme else 0.7, true))
		if d.fiamme:
			n.add_child(_particelle_fiamme(0.8))
			var luce := OmniLight3D.new()
			luce.light_color = Color(1.0, 0.55, 0.22)
			luce.light_energy = 1.1
			luce.omni_range = 2.6
			luce.position.y = 0.35
			n.add_child(luce)
			n.set_meta("luce", luce)
		add_child(n)
		_fuochi[k] = n
	for k in _fuochi:
		var n: Node3D = _fuochi[k]
		if n.has_meta("luce"):
			var l: OmniLight3D = n.get_meta("luce")
			l.light_energy = 0.9 + 0.3 * sin(_t * 13.0 + n.position.x * 3.0) + 0.2 * sin(_t * 31.0)

# ------------------------------------------------------------------ colpi ed esplosioni
func _nuove_animazioni() -> void:
	var anim: Array = m3.mappa2d.animazioni
	var ancora := {}
	for a in anim:
		var k := "%s|%s|%s|%s" % [str(a.get("t0", 0.0)), str(a.get("fx", "")), str(a.get("da", "")), str(a.get("a", ""))]
		ancora[k] = true
		if _visti.has(k):
			continue
		_visti[k] = true
		match str(a.get("fx", "")):
			"tiro":
				_tiro(a)
			"esplosione":
				_esplosione(str(a.get("a", "")), bool(a.get("grande", false)))
	for k in _visti.keys():
		if not ancora.has(k):
			_visti.erase(k)

func _tiro(a: Dictionary) -> void:
	var da := str(a.get("da", ""))
	var verso := str(a.get("a", ""))
	if not E.valido(da) or not E.valido(verso):
		return
	var p0: Vector3 = m3.centro3d(da) + Vector3(0, 0.28, 0)
	var p1: Vector3 = m3.centro3d(verso) + Vector3(0, 0.22, 0)
	var arma := str(a.get("arma", ""))
	var pesante := arma in ["cannone", "bazooka", "pzf", "mortaio"]
	var raffica := 1 if pesante or not bool(a.get("auto", false)) else 4
	if arma in ["lmg", "mmg", "hmg", "smg", "ar", "mp"]:
		raffica = 4
	# vampata alla bocca
	var vampa := OmniLight3D.new()
	vampa.light_color = Color(1.0, 0.72, 0.38)
	vampa.light_energy = 2.4 if pesante else 1.3
	vampa.omni_range = 2.2 if pesante else 1.2
	vampa.position = p0
	add_child(vampa)
	_attivi.append({"nodo": vampa, "t0": _t, "dur": 0.16 if not pesante else 0.3, "tipo": "vampa", "e0": vampa.light_energy})
	if pesante:
		var fumo_bocca := Node3D.new()
		fumo_bocca.position = p0
		fumo_bocca.add_child(_particelle_fumo(0.45, false))
		add_child(fumo_bocca)
		_attivi.append({"nodo": fumo_bocca, "t0": _t, "dur": 2.5, "tipo": "resto"})
	for i in raffica:
		var tr := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.018 if not pesante else 0.035
		cm.bottom_radius = cm.top_radius
		cm.height = 0.5 if not pesante else 0.35
		cm.radial_segments = 4
		cm.rings = 1
		tr.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.45) if not pesante else Color(1.0, 0.6, 0.3)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.6
		tr.material_override = mat
		tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tr.visible = false
		add_child(tr)
		var dev := Vector3(randf_range(-0.06, 0.06), randf_range(-0.03, 0.05), randf_range(-0.06, 0.06)) if i > 0 else Vector3.ZERO
		var dur := clampf(p0.distance_to(p1) * 0.035, 0.12, 0.5)
		_attivi.append({"nodo": tr, "t0": _t + i * 0.09, "dur": dur, "tipo": "tracciante", "p0": p0, "p1": p1 + dev,
			"colpito": str(a.get("esito", "")) == "colpito", "pesante": pesante})

func _esplosione(h: String, grande: bool) -> void:
	if not E.valido(h):
		return
	var c: Vector3 = m3.centro3d(h) + Vector3(0, 0.08, 0)
	var n := Node3D.new()
	n.position = c
	add_child(n)
	var s := 1.6 if grande else 1.0
	var luce := OmniLight3D.new()
	luce.light_color = Color(1.0, 0.62, 0.3)
	luce.light_energy = 3.0 * s
	luce.omni_range = 3.2 * s
	luce.position.y = 0.4
	n.add_child(luce)
	n.add_child(_particelle_scoppio(s))
	n.add_child(_particelle_detriti(s))
	n.add_child(_particelle_fumo(0.9 * s, false))
	_attivi.append({"nodo": n, "t0": _t, "dur": 4.0, "tipo": "esplosione", "luce": luce, "e0": luce.light_energy})

func _anima(_delta: float) -> void:
	for e in _attivi.duplicate():
		var nodo: Node3D = e.nodo
		if not is_instance_valid(nodo):
			_attivi.erase(e)
			continue
		var k: float = (_t - float(e.t0)) / float(e.dur)
		if k < 0.0:
			continue
		match str(e.tipo):
			"vampa":
				(nodo as OmniLight3D).light_energy = float(e.e0) * maxf(0.0, 1.0 - k)
			"tracciante":
				nodo.visible = k <= 1.0
				if k <= 1.0:
					var p0: Vector3 = e.p0
					var p1: Vector3 = e.p1
					var pos := p0.lerp(p1, k)
					nodo.position = pos
					var dir := (p1 - p0).normalized()
					if dir.length() > 0.01:
						nodo.look_at(pos + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
						nodo.rotate_object_local(Vector3.RIGHT, PI / 2.0)
				elif not e.has("finito"):
					e.finito = true
					# all’arrivo: sbuffo di polvere o scintille
					var sb := Node3D.new()
					sb.position = e.p1
					sb.add_child(_particelle_impatto(bool(e.pesante)))
					add_child(sb)
					_attivi.append({"nodo": sb, "t0": _t, "dur": 1.6, "tipo": "resto"})
			"esplosione":
				var l: OmniLight3D = e.luce
				if is_instance_valid(l):
					l.light_energy = float(e.e0) * maxf(0.0, 1.0 - k * 5.0)
		if k > 1.0 and str(e.tipo) != "tracciante":
			nodo.queue_free()
			_attivi.erase(e)
		elif k > 1.0 and e.has("finito"):
			nodo.queue_free()
			_attivi.erase(e)

# ------------------------------------------------------------------ particelle (CPU: vanno anche in GL Compatibility)
func _sfumato() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

func _mat_particella(additivo: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additivo else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _tex_morbida
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m

func _quad(lato: float, additivo: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(lato, lato)
	q.material = _mat_particella(additivo)
	return q

func _rampa(colori: Array) -> Gradient:
	var g := Gradient.new()
	var off := PackedFloat32Array()
	var col := PackedColorArray()
	for i in colori.size():
		off.append(float(i) / float(colori.size() - 1))
		col.append(colori[i])
	g.offsets = off
	g.colors = col
	return g

func _base(n: int, vita: float, uno_solo: bool) -> CPUParticles3D:
	var c := CPUParticles3D.new()
	c.amount = n
	c.lifetime = vita
	c.one_shot = uno_solo
	c.explosiveness = 1.0 if uno_solo else 0.0
	c.emitting = true
	c.local_coords = false
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return c

func _particelle_fumo(scala: float, continuo: bool) -> CPUParticles3D:
	var c := _base(28 if continuo else 18, 3.2 if continuo else 2.4, not continuo)
	c.mesh = _quad(0.62 * scala, false)
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	c.emission_sphere_radius = 0.08 * scala
	c.direction = Vector3(0.15, 1, 0)
	c.spread = 18.0
	c.gravity = Vector3(0.05, 0.12, 0)
	c.initial_velocity_min = 0.18 * scala
	c.initial_velocity_max = 0.35 * scala
	c.scale_amount_min = 0.8
	c.scale_amount_max = 1.6
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.5))
	curva.add_point(Vector2(1, 2.4))
	c.scale_amount_curve = curva
	c.color_ramp = _rampa([Color(0.33, 0.31, 0.29, 0.0), Color(0.30, 0.29, 0.28, 0.55), Color(0.42, 0.42, 0.42, 0.3), Color(0.5, 0.5, 0.5, 0.0)])
	return c

func _particelle_fiamme(scala: float) -> CPUParticles3D:
	var c := _base(40, 0.8, false)
	c.mesh = _quad(0.42 * scala, true)
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	c.emission_sphere_radius = 0.1 * scala
	c.direction = Vector3(0, 1, 0)
	c.spread = 12.0
	c.gravity = Vector3(0, 0.5, 0)
	c.initial_velocity_min = 0.15
	c.initial_velocity_max = 0.4
	c.color_ramp = _rampa([Color(1.0, 0.85, 0.45, 0.0), Color(1.0, 0.62, 0.22, 0.8), Color(0.85, 0.28, 0.08, 0.5), Color(0.2, 0.1, 0.05, 0.0)])
	return c

func _particelle_scoppio(scala: float) -> CPUParticles3D:
	var c := _base(40, 0.55, true)
	c.mesh = _quad(0.55 * scala, true)
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	c.emission_sphere_radius = 0.05
	c.direction = Vector3(0, 1, 0)
	c.spread = 80.0
	c.gravity = Vector3(0, 0.3, 0)
	c.initial_velocity_min = 0.8 * scala
	c.initial_velocity_max = 2.0 * scala
	c.damping_min = 2.0
	c.damping_max = 3.0
	c.color_ramp = _rampa([Color(1.0, 0.9, 0.6, 0.95), Color(1.0, 0.55, 0.18, 0.8), Color(0.45, 0.18, 0.06, 0.4), Color(0.1, 0.08, 0.06, 0.0)])
	return c

func _particelle_detriti(scala: float) -> CPUParticles3D:
	var c := _base(22, 1.1, true)
	var b := BoxMesh.new()
	b.size = Vector3(0.025, 0.025, 0.025) * scala
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.22, 0.18)
	b.material = m
	c.mesh = b
	c.direction = Vector3(0, 1, 0)
	c.spread = 55.0
	c.gravity = Vector3(0, -6.0, 0)
	c.initial_velocity_min = 1.2 * scala
	c.initial_velocity_max = 2.4 * scala
	c.angular_velocity_min = -400.0
	c.angular_velocity_max = 400.0
	return c

func _particelle_impatto(pesante: bool) -> CPUParticles3D:
	var c := _base(10 if not pesante else 18, 0.8, true)
	c.mesh = _quad(0.16 if not pesante else 0.32, false)
	c.direction = Vector3(0, 1, 0)
	c.spread = 60.0
	c.gravity = Vector3(0, -0.6, 0)
	c.initial_velocity_min = 0.3
	c.initial_velocity_max = 0.7
	c.color_ramp = _rampa([Color(0.55, 0.48, 0.38, 0.7), Color(0.5, 0.45, 0.4, 0.0)])
	return c

func _particelle_scintille() -> CPUParticles3D:
	var c := _base(14, 0.9, false)
	c.mesh = _quad(0.05, true)
	c.direction = Vector3(0, -1, 0)
	c.spread = 25.0
	c.gravity = Vector3(0, -1.2, 0)
	c.initial_velocity_min = 0.05
	c.initial_velocity_max = 0.2
	c.local_coords = true
	c.color_ramp = _rampa([Color(1.0, 0.92, 0.7, 0.9), Color(1.0, 0.6, 0.3, 0.0)])
	return c
