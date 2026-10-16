"""Кротик-Росток: one geometry spec -> model.json, .glb, .obj/.mtl, Luau spec table.

Units are Roblox studs. Y is up, the pet faces -Z (Roblox LookVector).
Rotations are Euler XYZ in degrees, matrix R = Rx * Ry * Rz (same as CFrame.Angles and three.js 'XYZ').
"""
import json, math, struct, sys, os
import numpy as np

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
os.makedirs(OUT, exist_ok=True)

PALETTE = {
    "fur":   "#8f5b3d",  # cocoa-brown velvet fur (main colour)
    "shade": "#5e3a26",  # tuft at the sprout base, tail tip
    "face":  "#f2c9a0",  # muzzle and belly
    "paw":   "#ffb09e",  # digging paws and feet
    "claw":  "#fff3df",
    "nose":  "#ff6f9c",
    "blush": "#ff9cb8",
    "eye":   "#1d120b",
    "shine": "#ffffff",
    "mouth": "#4a2414",
    "leaf":  "#74d63f",  # the sprout (accent colour)
    "stem":  "#3f9e2a",
    "scarf": "#4cc23a",  # Uncommon leaf scarf
    "crown": "#ffc423",  # Mythic / Secret crown
    "gem":   "#ff4f86",
}


def rot(deg):
    x, y, z = (math.radians(a) for a in deg)
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rx @ Ry @ Rz


def euler(R):
    y = math.asin(max(-1.0, min(1.0, R[0, 2])))
    x = math.atan2(-R[1, 2], R[2, 2])
    z = math.atan2(-R[0, 1], R[0, 0])
    return [round(math.degrees(a), 3) for a in (x, y, z)]


PARTS = []


def add(name, role, shape, size, pos, rotd=(0, 0, 0), group="base"):
    PARTS.append({"name": name, "role": role, "shape": shape,
                  "size": [round(float(v), 4) for v in size],
                  "pos": [round(float(v), 4) for v in pos],
                  "rot": [round(float(v), 3) for v in rotd], "group": group})


def child(ppos, prot, lpos, lrot=(0, 0, 0)):
    R = rot(prot)
    return np.array(ppos) + R @ np.array(lpos), euler(R @ rot(lrot))


# ---- body and head (oversized chibi head) --------------------------------------------
add("Body", "fur", "sphere", (2.1, 1.65, 1.9), (0, 0.85, 0))
add("Belly", "face", "sphere", (1.25, 1.0, 0.5), (0, 0.75, -0.78))
add("Tail", "shade", "sphere", (0.32, 0.32, 0.42), (0, 0.62, 0.95), (-20, 0, 0))
add("Head", "fur", "sphere", (2.75, 2.35, 2.4), (0, 2.15, -0.05))
add("Muzzle", "face", "sphere", (1.45, 0.92, 0.9), (0, 1.78, -0.98))
add("Nose", "nose", "sphere", (0.54, 0.4, 0.4), (0, 2.02, -1.33))
nose_shine, _ = child((0, 2.02, -1.33), (0, 0, 0), (0.1, 0.09, -0.15))
add("NoseShine", "shine", "sphere", (0.16, 0.09, 0.08), nose_shine)
add("MouthL", "mouth", "sphere", (0.25, 0.07, 0.07), (0.095, 1.585, -1.385), (0, 0, 28))
add("MouthR", "mouth", "sphere", (0.25, 0.07, 0.07), (-0.095, 1.585, -1.385), (0, 0, -28))

# eyes: big, glossy, two highlights each (both highlights on the same side = one light)
for side, sx in (("L", 1), ("R", -1)):
    epos, erot = (sx * 0.58, 2.42, -1.06), (10, -sx * 22, 0)
    add("Eye" + side, "eye", "sphere", (0.46, 0.6, 0.24), epos, erot)
    p, r = child(epos, erot, (0.085, 0.13, -0.1))
    add("EyeShine" + side, "shine", "sphere", (0.18, 0.18, 0.08), p, r)
    p, r = child(epos, erot, (-0.08, -0.14, -0.1))
    add("EyeSpark" + side, "shine", "sphere", (0.08, 0.08, 0.05), p, r)
    add("Cheek" + side, "blush", "sphere", (0.42, 0.22, 0.12), (sx * 0.98, 1.95, -0.8), (0, -sx * 42, 0))

# big digging paws held up at the sides, three claws each
for side, sx in (("L", 1), ("R", -1)):
    ppos, prot = (sx * 1.08, 1.1, -0.55), (0, sx * 10, -sx * 30)
    add("Paw" + side, "paw", "sphere", (0.8, 0.64, 0.56), ppos, prot)
    for i, (lx, lz) in enumerate(((-0.25, 18), (0.0, 0), (0.25, -18))):
        p, r = child(ppos, prot, (lx, 0.33 - abs(lx) * 0.2, -0.06), (0, 0, lz))
        add("Claw%s%d" % (side, i + 1), "claw", "sphere", (0.15, 0.3, 0.15), p, r)
    add("Foot" + side, "paw", "sphere", (0.64, 0.32, 0.82), (sx * 0.52, 0.16, -0.38))

# the sprout: tuft, stem, two leaves (the right one bigger)
add("Tuft", "shade", "sphere", (0.44, 0.16, 0.44), (0, 3.3, -0.05))
add("Stem", "stem", "cylinder", (0.16, 0.7, 0.16), (0, 3.62, -0.05), (0, 0, 4))
top = np.array([0.0, 3.93, -0.05])
for name, sx, size, ang in (("LeafL", 1, (1.1, 0.13, 0.66), 26), ("LeafR", -1, (1.3, 0.13, 0.76), 22)):
    lrot = (-38, 0, sx * ang)
    R = rot(lrot)
    centre = top + R @ np.array([sx * size[0] / 2 * 0.92, 0, 0])
    add(name, "leaf", "sphere", size, centre, lrot)
    vein = top + R @ np.array([sx * size[0] / 2 * 0.95, 0.058, 0])
    add(name + "Vein", "stem", "sphere", (size[0] * 0.78, 0.035, 0.06), vein, lrot)

# ---- accessories, shown by rarity -------------------------------------------------------
add("Scarf", "scarf", "sphere", (2.28, 0.38, 2.1), (0, 1.36, -0.02), group="scarf")
add("ScarfKnot", "scarf", "sphere", (0.3, 0.3, 0.2), (-0.6, 1.25, -0.93), (0, 25, 0), group="scarf")
add("ScarfTail", "scarf", "sphere", (0.24, 0.5, 0.1), (-0.7, 0.98, -0.93), (0, 25, -18), group="scarf")

crown_pos, crown_rot = (0.06, 3.36, -0.05), (0, 0, -8)
add("CrownBand", "crown", "cylinder", (0.92, 0.22, 0.92), crown_pos, crown_rot, group="crown")
for i in range(5):
    a = math.radians(i * 72 + 90 + 36)  # no spike straight in front, the gem sits there
    p, r = child(crown_pos, crown_rot, (0.38 * math.cos(a), 0.2, -0.38 * math.sin(a)))
    add("CrownSpike%d" % (i + 1), "crown", "sphere", (0.16, 0.36, 0.16), p, r, group="crown")
p, r = child(crown_pos, crown_rot, (0, 0.02, -0.47), (0, 0, 45))
add("CrownGem", "gem", "sphere", (0.17, 0.17, 0.08), p, r, group="crown")

# ---- rarity and mutation tables (shared by the viewer and Luau) ---------------------------
RARITIES = [
    {"id": "Common",    "color": "#b9b2a8", "groups": [],        "glowLeaves": False, "fx": None,       "scale": 1.0},
    {"id": "Uncommon",  "color": "#5ccf45", "groups": ["scarf"], "glowLeaves": False, "fx": "shine",    "scale": 1.0},
    {"id": "Rare",      "color": "#3fa9ff", "groups": [],        "glowLeaves": True,  "fx": "sparkle",  "scale": 1.0},
    {"id": "Epic",      "color": "#b670ff", "groups": [],        "glowLeaves": True,  "fx": "aura",     "scale": 1.0},
    {"id": "Legendary", "color": "#ffc423", "groups": [],        "glowLeaves": True,  "fx": "rays",     "scale": 1.05},
    {"id": "Mythic",    "color": "#ff4f86", "groups": ["crown"], "glowLeaves": True,  "fx": "particles", "scale": 1.05},
    {"id": "Secret",    "color": "#6ff2ff", "groups": ["crown"], "glowLeaves": True,  "fx": "cosmic",   "scale": 1.15},
]
ROLE_CLASS = {"fur": "main", "shade": "shade", "face": "light", "paw": "light", "claw": "light", "nose": "light",
              "blush": "light", "leaf": "accent", "stem": "accent", "scarf": "accent", "crown": "accent", "gem": "accent"}
# eye, shine and mouth never change, so the face still reads on every material
MUTATIONS = [
    {"id": "None",    "mult": 1},
    {"id": "Gold",    "mult": 2,  "material": "metal", "reflectance": 0.3,
     "palette": {"main": "#ffc436", "shade": "#c98a00", "light": "#ffe08a", "accent": "#e0a100"}},
    {"id": "Diamond", "mult": 3,  "material": "glass", "transparency": 0.2, "reflectance": 0.2,
     "palette": {"main": "#8fdfff", "shade": "#3aa6dc", "light": "#d2f5ff", "accent": "#5cc6f2"}},
    {"id": "Rainbow", "mult": 6,  "colors": ["#ff8a8a", "#ffc27a", "#fff27a", "#8cf08a", "#7ad7ff", "#b99bff"]},
    {"id": "Galaxy",  "mult": 15, "glow": "#b98cff",
     "palette": {"main": "#2d1458", "shade": "#1f0d40", "light": "#4b2a8a", "accent": "#8f5cff"}},
]

spec = {"name": "KrotikRostok", "title": "Кротик-Росток", "units": "studs", "up": "+Y", "front": "-Z",
        "palette": PALETTE, "roleClass": ROLE_CLASS, "parts": PARTS, "rarities": RARITIES, "mutations": MUTATIONS}
with open(os.path.join(OUT, "krotik-rostok.model.json"), "w", encoding="utf-8") as f:
    json.dump(spec, f, ensure_ascii=False, indent=1)


# ---- meshes ------------------------------------------------------------------------------
def sphere_mesh(size, seg):
    a, b, c = (s / 2 for s in size)
    rings = max(6, seg // 2)
    V, N, I = [], [], []
    for i in range(rings + 1):
        th = math.pi * i / rings
        for j in range(seg + 1):
            ph = 2 * math.pi * j / seg
            ux, uy, uz = math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph)
            V.append((a * ux, b * uy, c * uz))
            n = np.array((ux / a, uy / b, uz / c))
            N.append(tuple(n / np.linalg.norm(n)))
    for i in range(rings):
        for j in range(seg):
            p, q = i * (seg + 1) + j, (i + 1) * (seg + 1) + j
            if i != 0:
                I.append((p, p + 1, q))
            if i != rings - 1:
                I.append((p + 1, q + 1, q))
    return V, N, I


def cylinder_mesh(size, seg):
    r, h = size[0] / 2, size[1] / 2
    V, N, I = [], [], []
    for j in range(seg + 1):
        ph = 2 * math.pi * j / seg
        x, z = math.cos(ph), math.sin(ph)
        V += [(r * x, -h, r * z), (r * x, h, r * z)]
        N += [(x, 0, z), (x, 0, z)]
    for j in range(seg):
        a = 2 * j
        I += [(a, a + 1, a + 2), (a + 1, a + 3, a + 2)]
    for y, ny in ((h, 1), (-h, -1)):
        c0 = len(V)
        V.append((0, y, 0)); N.append((0, ny, 0))
        for j in range(seg + 1):
            ph = 2 * math.pi * j / seg
            V.append((r * math.cos(ph), y, r * math.sin(ph))); N.append((0, ny, 0))
        for j in range(seg):
            if ny > 0:
                I.append((c0, c0 + j + 2, c0 + j + 1))
            else:
                I.append((c0, c0 + j + 1, c0 + j + 2))
    return V, N, I


def part_mesh(p):
    big = max(p["size"])
    seg = 32 if big > 1.5 else 20 if big > 0.5 else 12
    V, N, I = (sphere_mesh if p["shape"] == "sphere" else cylinder_mesh)(p["size"], seg)
    R = rot(p["rot"])
    V = (np.array(V) @ R.T) + np.array(p["pos"])
    N = np.array(N) @ R.T
    return V, N, np.array(I, dtype=np.int64)


def fix_winding(V, N, I):
    # make every triangle wind counter-clockwise seen from outside (normal direction)
    out = []
    for t in I:
        a, b, c = V[t[0]], V[t[1]], V[t[2]]
        fn = np.cross(b - a, c - a)
        if np.dot(fn, N[t[0]] + N[t[1]] + N[t[2]]) < 0:
            t = (t[0], t[2], t[1])
        out.append(t)
    return np.array(out, dtype=np.int64)


def srgb_to_linear(h):
    v = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in v]


# merge parts by role so Roblox gets a few named MeshParts (Fur, Face, Paw, ...)
ROLE_ORDER = ["fur", "face", "shade", "paw", "claw", "nose", "blush", "eye", "shine", "mouth", "leaf", "stem", "scarf", "crown", "gem"]


def merged(parts, glb_space):
    groups = {}
    for p in parts:
        key = (p["role"], p["group"])
        V, N, I = part_mesh(p)
        I = fix_winding(V, N, I)
        if glb_space:  # glTF front is +Z: rotate 180 deg about Y. 1 unit = 1 stud (3D Importer "Scale Unit: Stud")
            V = V * np.array([-1, 1, -1])
            N = N * np.array([-1, 1, -1])
        g = groups.setdefault(key, [[], [], [], 0])
        g[0].append(V); g[1].append(N); g[2].append(I + g[3]); g[3] += len(V)
    res = []
    for (role, group), (Vs, Ns, Is, _) in sorted(groups.items(), key=lambda kv: (ROLE_ORDER.index(kv[0][0]), kv[0][1])):
        name = role.capitalize() if group == "base" or role in ("scarf", "crown", "gem") else role.capitalize() + group.capitalize()
        res.append((name, role, np.vstack(Vs), np.vstack(Ns), np.vstack(Is)))
    return res


def write_glb(path, meshes):
    bin_ = bytearray()
    views, accessors, gmeshes, nodes, materials, mat_index = [], [], [], [], [], {}

    def push(data, target):
        while len(bin_) % 4:
            bin_.append(0)
        off = len(bin_)
        bin_.extend(data)
        views.append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
        return len(views) - 1

    for name, role, V, N, I in meshes:
        if role not in mat_index:
            m = {"name": role, "pbrMetallicRoughness": {"baseColorFactor": srgb_to_linear(PALETTE[role]) + [1.0],
                                                        "metallicFactor": 0.0, "roughnessFactor": 0.45}}
            mat_index[role] = len(materials); materials.append(m)
        v = V.astype(np.float32); n = N.astype(np.float32)
        n /= np.linalg.norm(n, axis=1, keepdims=True)
        idx = I.astype(np.uint32).ravel()
        bv = push(v.tobytes(), 34962)
        accessors.append({"bufferView": bv, "componentType": 5126, "count": len(v), "type": "VEC3",
                          "min": v.min(axis=0).tolist(), "max": v.max(axis=0).tolist()})
        pa = len(accessors) - 1
        bn = push(n.tobytes(), 34962)
        accessors.append({"bufferView": bn, "componentType": 5126, "count": len(n), "type": "VEC3"})
        na = len(accessors) - 1
        bi = push(idx.tobytes(), 34963)
        accessors.append({"bufferView": bi, "componentType": 5125, "count": len(idx), "type": "SCALAR"})
        ia = len(accessors) - 1
        gmeshes.append({"name": name, "primitives": [{"attributes": {"POSITION": pa, "NORMAL": na}, "indices": ia,
                                                       "material": mat_index[role]}]})
        nodes.append({"name": name, "mesh": len(gmeshes) - 1})
    nodes.append({"name": "KrotikRostok", "children": list(range(len(nodes)))})
    gltf = {"asset": {"version": "2.0", "generator": "Dig an Egg pet builder"}, "scene": 0,
            "scenes": [{"name": "KrotikRostok", "nodes": [len(nodes) - 1]}], "nodes": nodes, "meshes": gmeshes,
            "materials": materials, "accessors": accessors, "bufferViews": views,
            "buffers": [{"byteLength": len(bin_)}]}
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    while len(bin_) % 4:
        bin_.append(0)
    total = 12 + 8 + len(js) + 8 + len(bin_)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(bin_), 0x004E4942)); f.write(bin_)


def write_obj(path, meshes):
    base = os.path.splitext(os.path.basename(path))[0]
    with open(path, "w") as f, open(path[:-4] + ".mtl", "w") as m:
        f.write("# Krotik-Rostok (Dig an Egg) - units: studs, Y up, faces -Z\nmtllib %s.mtl\n" % base)
        off = 1
        for name, role, V, N, I in meshes:
            f.write("o %s\nusemtl %s\n" % (name, role))
            for v in V: f.write("v %.5f %.5f %.5f\n" % tuple(v))
            for n in N: f.write("vn %.5f %.5f %.5f\n" % tuple(n / np.linalg.norm(n)))
            for t in I + off: f.write("f %d//%d %d//%d %d//%d\n" % (t[0], t[0], t[1], t[1], t[2], t[2]))
            off += len(V)
        for role in ROLE_ORDER:
            r, g, b = (int(PALETTE[role][i:i + 2], 16) / 255 for i in (1, 3, 5))
            m.write("newmtl %s\nKd %.4f %.4f %.4f\nKa 0 0 0\nKs 0.2 0.2 0.2\nNs 40\nd 1\nillum 2\n\n" % (role, r, g, b))


glb_meshes = merged(PARTS, glb_space=True)
write_glb(os.path.join(OUT, "KrotikRostok.glb"), glb_meshes)
write_glb(os.path.join(OUT, "KrotikRostok-Common.glb"), merged([p for p in PARTS if p["group"] == "base"], True))
write_obj(os.path.join(OUT, "KrotikRostok.obj"), merged(PARTS, glb_space=False))


# ---- Luau spec table ----------------------------------------------------------------------
def lua_c3(h):
    return "Color3.fromRGB(%d, %d, %d)" % tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


lines = ["-- BEGIN GENERATED (tools/build_model.py: do not edit by hand) --", "Krotik.Palette = {"]
for k, v in PALETTE.items():
    lines.append("\t%s = %s," % (k, lua_c3(v)))
lines.append("}")
lines.append("")
lines.append("-- name, role, shape, size, position, rotation (deg, XYZ), group")
lines.append("Krotik.Parts = {")
for p in PARTS:
    lines.append('\t{ "%s", "%s", "%s", Vector3.new(%s), Vector3.new(%s), Vector3.new(%s), "%s" },' % (
        p["name"], p["role"], p["shape"], ", ".join("%g" % (v + 0.0) for v in p["size"]),
        ", ".join("%g" % (v + 0.0) for v in p["pos"]), ", ".join("%g" % (v + 0.0) for v in p["rot"]), p["group"]))
lines.append("}")
lines.append("")
lines.append("Krotik.RoleClass = {")
for k, v in ROLE_CLASS.items():
    lines.append('\t%s = "%s",' % (k, v))
lines.append("}")
lines.append("")
lines.append("Krotik.Rarities = {")
for r in RARITIES:
    lines.append('\t%s = { color = %s, groups = { %s }, glowLeaves = %s, fx = "%s", scale = %g },' % (
        r["id"], lua_c3(r["color"]), ", ".join('"%s"' % g for g in r["groups"]), "true" if r["glowLeaves"] else "false",
        r["fx"] or "none", r["scale"]))
lines.append("}")
lines.append("")
lines.append("Krotik.Mutations = {")
for m in MUTATIONS:
    f = ["mult = %d" % m["mult"]]
    if "material" in m: f.append('material = "%s"' % m["material"])
    if "reflectance" in m: f.append("reflectance = %g" % m["reflectance"])
    if "transparency" in m: f.append("transparency = %g" % m["transparency"])
    if "glow" in m: f.append("glow = %s" % lua_c3(m["glow"]))
    if "palette" in m: f.append("palette = { %s }" % ", ".join("%s = %s" % (k, lua_c3(v)) for k, v in m["palette"].items()))
    if "colors" in m: f.append("colors = { %s }" % ", ".join(lua_c3(c) for c in m["colors"]))
    lines.append("\t%s = { %s }," % (m["id"], ", ".join(f)))
lines.append("}")
lines.append("-- END GENERATED --")
tpl = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "KrotikRostok.template.luau"), encoding="utf-8").read()
with open(os.path.join(OUT, "KrotikRostok.luau"), "w", encoding="utf-8") as f:
    f.write(tpl.replace("--@@GENERATED@@", "\n".join(lines)))

tri = sum(len(m[4]) for m in glb_meshes)
print("parts:", len(PARTS), "meshparts:", len(glb_meshes), "triangles:", tri)
