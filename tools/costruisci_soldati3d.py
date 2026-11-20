#!/usr/bin/env python3
"""Prepara le miniature 3D dei soldati per la vista 3D.

Sorgenti (fuori dal repository, file grandi):
  STL americani  H2D_Infantry_US_WW2_stls.zip  (scala 15 mm, con basetta)
  3MF tedeschi   1_32+German+Wehrmacht+Soldiers.zip (scala 1/32, basetta separata)
Per ogni posa scelta: tolta la basetta, ridotta a ~4000 triangoli, girata con l'alto su Y,
portata all'altezza comune (in piedi = 0,5 unità della mappa 3D) e salvata in
assets/soldati3d/<nome>.glb con i piedi a quota 0 e centrata sull'origine.
Uso: python3 tools/costruisci_soldati3d.py <cartella_us_stl> <cartella_3mf_estratto>
"""
import sys, os, glob, re, json
import numpy as np, trimesh, fast_simplification
import xml.etree.ElementTree as ET

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USCITA = os.path.join(RADICE, "assets/soldati3d")
ALTEZZA = 0.5
TRIANGOLI = 4000

US = {  # nome: numero obj_ nel pacchetto americano
    "us_fucile_piedi": 72, "us_fucile_piedi2": 84, "us_fucile_acc": 59, "us_fucile_acc2": 4, "us_fucile_prono": 37,
    "us_mitra_piedi": 56, "us_mitra_acc": 50, "us_mitra_prono": 49,
    "us_bar_piedi": 48, "us_bar_acc": 62, "us_bar_prono": 21,
    "us_bazooka_piedi": 18, "us_bazooka_acc": 6,
    "us_mg_piedi": 46, "us_mg_acc": 34, "us_mg_prono": 25,
    "us_capo_piedi": 83, "us_capo_acc": 12, "us_capo_prono": 55,
    "us_strisciante": 41,
}
DE = {  # nome: id oggetto nel 3MF tedesco
    "de_fucile_piedi": "24", "de_fucile_piedi2": "21", "de_fucile_piedi3": "12", "de_fucile_piedi4": "46",
    "de_fucile_acc": "3", "de_ott_acc": "18", "de_mp_piedi": "29", "de_mp_acc": "10",
    "de_mg_piedi": "34", "de_ufficiale_piedi": "37", "de_ufficiale_acc": "15", "de_pzf": "49", "de_granata": "6",
    "de_riposo": "31",
}
PRONI_DE = {"de_fucile_prono": "24"}  # in piedi coricati a pancia in giù


def riduci(v, f, obiettivo=TRIANGOLI):
    v = np.asarray(v, np.float32); f = np.asarray(f, np.int32)
    area0 = trimesh.Trimesh(v, f, process=False).area
    for _ in range(40):
        if len(f) <= obiettivo:
            break
        rid = min(0.5, 1 - obiettivo / len(f))
        v2, f2 = fast_simplification.simplify(v, f, target_reduction=rid, agg=2)
        if len(f2) >= len(f) * 0.97:
            v2, f2 = fast_simplification.simplify(v, f, target_reduction=rid, agg=4)
        if trimesh.Trimesh(v2, f2, process=False).area < area0 * 0.88:
            break
        v, f = v2, f2
    return v, f


def togli_basetta(m):
    """Le figure americane stanno su una basetta: si trova il piano superiore della basetta
    (la superficie orizzontale più ampia vicino al fondo) e si tolgono i triangoli sotto di esso."""
    v, f = m.vertices, m.faces
    z = v[:, 2]
    zmin = z.min()
    tri = v[f]
    n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    area = np.linalg.norm(n, axis=1) / 2
    su = (n[:, 2] / (np.linalg.norm(n, axis=1) + 1e-12)) > 0.95
    zc = tri[:, :, 2].mean(1)
    sel = su & (zc < zmin + 4.0)
    if not sel.any():
        return m
    bins = np.arange(zmin, zmin + 4.05, 0.05)
    h, _ = np.histogram(zc[sel], bins=bins, weights=area[sel])
    piano = bins[np.argmax(h)] + 0.05
    tieni = tri[:, :, 2].min(1) > piano - 0.01
    m2 = trimesh.Trimesh(v, f[tieni], process=True)
    m2.remove_unreferenced_vertices()
    # resti staccati (bordi della basetta): si tiene il pezzo più grande e quelli vicini
    parti = m2.split(only_watertight=False)
    if len(parti) > 1:
        parti = sorted(parti, key=lambda p: -len(p.faces))
        grande = parti[0]
        tenute = [p for p in parti if len(p.faces) > len(grande.faces) * 0.02]
        m2 = trimesh.util.concatenate(tenute)
    return m2


def carica_3mf(cartella):
    ns = {'m': 'http://schemas.microsoft.com/3dmanufacturing/core/2015/02',
          'p': 'http://schemas.microsoft.com/3dmanufacturing/production/2015/06'}
    cache = {}

    def mesh_da(path, oid):
        if (path, oid) not in cache:
            for o in ET.parse(cartella + path).getroot().iter('{%s}object' % ns['m']):
                if o.get('id') == oid:
                    mm = o.find('m:mesh', ns)
                    v = np.array([[float(x.get('x')), float(x.get('y')), float(x.get('z'))] for x in mm.find('m:vertices', ns)])
                    f = np.array([[int(x.get('v1')), int(x.get('v2')), int(x.get('v3'))] for x in mm.find('m:triangles', ns)])
                    cache[(path, oid)] = (v, f)
        return cache[(path, oid)]
    out = {}
    root = ET.parse(cartella + '/3D/3dmodel.model').getroot()
    for o in root.find('m:resources', ns).findall('m:object', ns):
        comps = o.find('m:components', ns)
        if comps is None:
            continue
        parti = []
        for c in comps.findall('m:component', ns):
            v, f = mesh_da(c.get('{%s}path' % ns['p']), c.get('objectid'))
            a = [float(x) for x in c.get('transform').split()]
            M = np.eye(4); M[:3, :3] = np.array(a[:9]).reshape(3, 3).T; M[:3, 3] = a[9:12]
            parti.append((len(f), (np.c_[v, np.ones(len(v))] @ M.T)[:, :3], f))
        parti.sort(key=lambda x: -x[0])
        out[o.get('id')] = trimesh.Trimesh(parti[0][1], parti[0][2], process=True)  # la figura, non il cilindro
    return out


def salva(nome, m, scala, coricato=False):
    v, f = riduci(m.vertices, m.faces)
    m = trimesh.Trimesh(v, f, process=True)
    # Z in alto -> Y in alto (Godot); la figura guarda verso -Z come da file
    R = trimesh.transformations.rotation_matrix(-np.pi / 2, [1, 0, 0])
    m.apply_transform(R)
    if coricato:
        # da in piedi a sdraiato a pancia in giù: ruota di 90° attorno all'asse X
        m.apply_transform(trimesh.transformations.rotation_matrix(np.pi / 2, [1, 0, 0]))
    m.apply_scale(scala)
    b = m.bounds
    m.apply_translation([-(b[0][0] + b[1][0]) / 2, -b[0][1], -(b[0][2] + b[1][2]) / 2])
    m.fix_normals()
    m.export(os.path.join(USCITA, nome + ".glb"))
    return len(m.faces), m.extents.round(3).tolist()


def main():
    cartella_us, cartella_de = sys.argv[1], sys.argv[2]
    solo = sys.argv[3].split(",") if len(sys.argv) > 3 else []
    os.makedirs(USCITA, exist_ok=True)
    file_us = {int(re.search(r'obj_(\d+)_', p).group(1)): p for p in glob.glob(os.path.join(cartella_us, '*.stl'))}
    rif = togli_basetta(trimesh.load(file_us[US["us_fucile_piedi"]]))
    scala_us = ALTEZZA / rif.extents[2]
    info = {}
    for nome, n in US.items():
        if solo and nome not in solo:
            continue
        m = togli_basetta(trimesh.load(file_us[n]))
        info[nome] = salva(nome, m, scala_us)
        print(nome, info[nome])
    de = carica_3mf(cartella_de)
    scala_de = ALTEZZA / de[DE["de_fucile_piedi"]].extents[2]
    for nome, k in DE.items():
        if solo and nome not in solo:
            continue
        # le figure tedesche non hanno tutte la stessa scala: si portano ad altezze uguali per posa
        alt = 0.5 if ("piedi" in nome or nome in ("de_granata", "de_riposo")) else 0.41
        info[nome] = salva(nome, de[k], alt / de[k].extents[2])
        print(nome, info[nome])
    for nome, k in PRONI_DE.items():
        if solo and nome not in solo:
            continue
        info[nome] = salva(nome, de[k], 0.5 / de[k].extents[2], coricato=True)
        print(nome, info[nome])
    vecchio = json.load(open(os.path.join(USCITA, "indice.json"))) if os.path.exists(os.path.join(USCITA, "indice.json")) else {}
    vecchio.update(info)
    json.dump(vecchio, open(os.path.join(USCITA, "indice.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
