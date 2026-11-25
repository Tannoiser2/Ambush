"""Lettore di file 3MF, anche quelli di Bambu Studio / OrcaSlicer con gli oggetti in file separati
(3D/Objects/*.model richiamati come componenti). Restituisce un dizionario
{nome oggetto: trimesh.Trimesh} con le trasformazioni dei componenti già applicate; se `piatto` è vero
applica anche le trasformazioni della sezione <build> (posizione sul piatto di stampa)."""
import re
import zipfile
import numpy as np
import trimesh

_NUM = r"[-+0-9.eE]+"


def _matrice(t):
    if not t:
        return np.eye(4)
    v = [float(x) for x in t.split()]
    m = np.eye(4)
    # 3MF: punto riga per matrice (m00 m01 m02 m10 … m32); qui in forma colonna
    m[:3, :3] = np.array([[v[0], v[3], v[6]], [v[1], v[4], v[7]], [v[2], v[5], v[8]]])
    m[:3, 3] = v[9:12]
    return m


def _mesh_da_xml(testo):
    """Oggetti con <mesh> in un file .model: {id: (vertici, facce)}."""
    out = {}
    for mo in re.finditer(r'<object\b[^>]*\bid="(\d+)"[^>]*>(.*?)</object>', testo, re.S):
        corpo = mo.group(2)
        if "<mesh" not in corpo:
            continue
        vs = re.findall(r'<vertex\s+x="(%s)"\s+y="(%s)"\s+z="(%s)"' % (_NUM, _NUM, _NUM), corpo)
        ts = re.findall(r'<triangle\s+v1="(\d+)"\s+v2="(\d+)"\s+v3="(\d+)"', corpo)
        out[mo.group(1)] = (np.array(vs, dtype=np.float64), np.array(ts, dtype=np.int64))
    return out


def leggi(percorso, piatto=False):
    z = zipfile.ZipFile(percorso)
    principale = z.read("3D/3dmodel.model").decode("utf-8", "replace")
    file_cache = {}

    def mesh_in(file, oid):
        if file not in file_cache:
            file_cache[file] = _mesh_da_xml(z.read(file.lstrip("/")).decode("utf-8", "replace"))
        return file_cache[file].get(oid)

    locali = _mesh_da_xml(principale)
    nomi = dict(re.findall(r'<object\b[^>]*\bid="(\d+)"[^>]*\bname="([^"]*)"', principale))
    oggetti = {}
    for mo in re.finditer(r'<object\b[^>]*\bid="(\d+)"[^>]*>(.*?)</object>', principale, re.S):
        oid, corpo = mo.group(1), mo.group(2)
        parti = []
        if oid in locali:
            v, f = locali[oid]
            parti.append(trimesh.Trimesh(v, f, process=False))
        for c in re.finditer(r'<component\b([^>]*)/?>', corpo):
            att = c.group(1)
            sid = re.search(r'objectid="(\d+)"', att).group(1)
            pth = re.search(r'path="([^"]+)"', att)
            tr = re.search(r'transform="([^"]+)"', att)
            vf = mesh_in(pth.group(1), sid) if pth else locali.get(sid)
            if vf is None:
                continue
            m = trimesh.Trimesh(vf[0], vf[1], process=False)
            m.apply_transform(_matrice(tr.group(1) if tr else ""))
            parti.append(m)
        if parti:
            oggetti[oid] = trimesh.util.concatenate(parti) if len(parti) > 1 else parti[0]
    risultato = {}
    for it in re.finditer(r'<item\b([^>]*)/?>', principale):
        att = it.group(1)
        oid = re.search(r'objectid="(\d+)"', att).group(1)
        if oid not in oggetti:
            continue
        m = oggetti[oid].copy()
        tr = re.search(r'transform="([^"]+)"', att)
        if piatto and tr:
            m.apply_transform(_matrice(tr.group(1)))
        nome = nomi.get(oid, oid)
        k, i = nome, 2
        while k in risultato:
            k, i = "%s_%d" % (nome, i), i + 1
        risultato[k] = m
    return risultato


if __name__ == "__main__":
    import sys
    for k, m in leggi(sys.argv[1]).items():
        print(k, len(m.faces), m.extents.round(1).tolist())
