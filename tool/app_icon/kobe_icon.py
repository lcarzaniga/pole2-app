#!/usr/bin/env python3
"""Pole² · Kobe — LOCKED canonical app-icon source (M8.3B).

This is the single production source of truth for the **Android launcher** icon.
It reproduces the visually approved **Option C at its original base scale**
(design/icon-concepts/m8.3/revision-2, variant C, TARGET_R = 35.2) exactly — same
canonical shell, seven scutes, oversized head + four partially-retracted chunky
legs, no face, no tail, approved colours/shading, base scale and optical centre.
The larger "C-max" scale was rejected on real Samsung One UI hardware (filled the
mask too aggressively), so the base-scale C — with visible breathing room around
the head and legs — is the definitive icon.

It reuses the CANONICAL shell geometry from lib/shared/brand/turtle_mascot.dart
(read-only — KobePainter is never modified or imported). Deterministic: no AI, no
randomness; two runs are byte-identical.

Usage:
  python3 kobe_icon.py            # write locked SVGs + render all PNG resources
  python3 kobe_icon.py --check    # verify a second render is byte-identical
Renders via headless google-chrome (documented in README.md).
"""
import math
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
WEB = os.path.join(ROOT, "web")

# ---- Canonical shell constants (turtle_mascot.dart, 200-unit space) ---------
CX, CY, SCg = 100.0, 104.0, 0.9
RX, RY = 57 * SCg, 66 * SCg          # 51.30 x 59.40
HEXR = 0.70 * RX                     # 35.91
BW = 6.8 * SCg                       # 6.12
ANGS = [0, 60, 120, 180, 240, 300]
RXI, RYI = RX - BW, RY - BW
GROUT_K = 0.90

# ---- Approved palette -------------------------------------------------------
SHELL, BODY = "#BFDACD", "#1F4638"
LIMB_HI, SHELL_HI, GROOVE = "#3C7A63", "#D7EAE0", "#E7F4EE"
SEED, IVORY, MONO = "#2E6B5E", "#F6F1E7", "#101613"

# Launcher background — the approved clean, uniform warm lemon-yellow (variant A).
# Recognition contrast is carried by Kobe's dark rim/grout/head/legs, which sit at
# 5.81:1 against this yellow (AA); no pattern, gradient or decoration.
ICON_BG = "#EBB94C"

# ---- Adaptive framing + approved Option C base scale ------------------------
ICON = 108.0
ICX = ICY = 54.0
TARGET_R = 35.2                      # approved Option C, original base scale
CFG = dict(head=0.46, head_pos=0.90, leg=0.35, leg_pos=0.96, eyes=False)
LEG_ANGLES = [40, 140, 220, 320]


def ell_pt(a, rx, ry, cx=CX, cy=CY):
    t = math.radians(a); c, s = math.cos(t), math.sin(t)
    r = 1.0 / math.sqrt((c / rx) ** 2 + (s / ry) ** 2)
    return (cx + r * c, cy + r * s)


def vertex(d):
    t = math.radians(d)
    return (CX + HEXR * math.cos(t), CY + HEXR * math.sin(t))


def inset(pts, k):
    cx = sum(p[0] for p in pts) / len(pts); cy = sum(p[1] for p in pts) / len(pts)
    return [(cx + k * (x - cx), cy + k * (y - cy)) for x, y in pts]


def scutes():
    out = [inset([vertex(a) for a in ANGS], GROUT_K)]
    for i, a in enumerate(ANGS):
        a2 = ANGS[(i + 1) % 6]; span = (a2 - a) % 360
        pts = [vertex(a), ell_pt(a, RXI, RYI)]
        for s in range(1, 8):
            pts.append(ell_pt(a + span * s / 8, RXI, RYI))
        pts += [ell_pt(a2, RXI, RYI), vertex(a2)]
        out.append(inset(pts, GROUT_K))
    return out


def build():
    head_r = RY * CFG["head"]; head_c = (CX, CY - RY * CFG["head_pos"])
    leg_r = RY * CFG["leg"]; legs = []
    for ang in LEG_ANGLES:
        ex, ey = ell_pt(ang, RX, RY)
        legs.append((CX + (ex - CX) * CFG["leg_pos"], CY + (ey - CY) * CFG["leg_pos"], leg_r))
    return dict(head=(head_c[0], head_c[1], head_r), legs=legs, scutes=scutes())


def sil_pts(g):
    pts = []
    for (cx, cy, r) in [g["head"]] + g["legs"]:
        pts += [(cx + r * math.cos(2 * math.pi * i / 48), cy + r * math.sin(2 * math.pi * i / 48)) for i in range(48)]
    pts += [(CX + RX * math.cos(2 * math.pi * i / 72), CY + RY * math.sin(2 * math.pi * i / 72)) for i in range(72)]
    return pts


def transform(g):
    pts = sil_pts(g)
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    R = max(math.hypot(px - cx, py - cy) for px, py in pts)
    return (TARGET_R / R, cx, cy)


def T(pt, tr):
    s, cx, cy = tr
    return (ICX + s * (pt[0] - cx), ICY + s * (pt[1] - cy))


def poly_d(pts):
    return "M " + " L ".join(f"{x:.3f},{y:.3f}" for x, y in pts) + " Z"


def circ(cx, cy, r, fill, cls=""):
    c = f' class="{cls}"' if cls else ""
    return f'<circle{c} cx="{cx:.3f}" cy="{cy:.3f}" r="{r:.3f}" fill="{fill}"/>'


def limb(cxy_r, tr, base, hi):
    cx, cy, r = cxy_r
    icx, icy = T((cx, cy), tr); ir = r * tr[0]
    return circ(icx, icy, ir, base) + circ(icx - ir * 0.30, icy - ir * 0.34, ir * 0.60, hi)


def parts(mono=False):
    g = build(); tr = transform(g); out = []
    if mono:
        for L in g["legs"]:
            icx, icy = T((L[0], L[1]), tr); out.append(circ(icx, icy, L[2] * tr[0], MONO))
        hx, hy = T((g["head"][0], g["head"][1]), tr); out.append(circ(hx, hy, g["head"][2] * tr[0], MONO))
        e = T((CX, CY), tr); erx, ery = RX * tr[0], RY * tr[0]; irx, iry = RXI * tr[0], RYI * tr[0]
        out.append(f'<path fill-rule="evenodd" fill="{MONO}" d="'
                   f'M {e[0]-erx:.2f},{e[1]:.2f} a {erx:.2f},{ery:.2f} 0 1,0 {2*erx:.2f},0 a {erx:.2f},{ery:.2f} 0 1,0 {-2*erx:.2f},0 Z '
                   f'M {e[0]-irx:.2f},{e[1]:.2f} a {irx:.2f},{iry:.2f} 0 1,1 {2*irx:.2f},0 a {irx:.2f},{iry:.2f} 0 1,1 {-2*irx:.2f},0 Z"/>')
        for sc in g["scutes"]:
            out.append(f'<path class="scute" fill="{MONO}" d="{poly_d([T(p,tr) for p in sc])}"/>')
        return out
    for L in g["legs"]:
        out.append(limb(L, tr, BODY, LIMB_HI))
    out.append(limb(g["head"], tr, BODY, LIMB_HI))
    e = T((CX, CY), tr)
    out.append(f'<ellipse cx="{e[0]:.2f}" cy="{e[1]:.2f}" rx="{RX*tr[0]:.2f}" ry="{RY*tr[0]:.2f}" fill="{BODY}"/>')
    for sc in g["scutes"]:
        out.append(f'<path class="scute" fill="{SHELL}" d="{poly_d([T(p,tr) for p in sc])}"/>')
    out.append(f'<clipPath id="sh"><ellipse cx="{e[0]:.2f}" cy="{e[1]:.2f}" rx="{RXI*tr[0]:.2f}" ry="{RYI*tr[0]:.2f}"/></clipPath>')
    out.append(f'<ellipse clip-path="url(#sh)" cx="{e[0]:.2f}" cy="{e[1]-RYI*tr[0]*0.62:.2f}" rx="{RXI*tr[0]*0.72:.2f}" ry="{RYI*tr[0]*0.34:.2f}" fill="{SHELL_HI}" opacity="0.55"/>')
    return out


def svg(px, mono=False, bg=None, round_clip=False):
    body = "\n  ".join(parts(mono=mono))
    pre = ""
    if round_clip:
        pre += '<defs><clipPath id="rc"><circle cx="54" cy="54" r="54"/></clipPath></defs>'
    open_g = '<g clip-path="url(#rc)">' if round_clip else "<g>"
    bgrect = f'<rect width="108" height="108" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 108 108">\n'
            f'{pre}{open_g}{bgrect}\n  {body}\n</g>\n</svg>\n')


# ---- Deterministic raster export via headless Chrome ------------------------
def chrome(svg_path, png_path, px, transparent):
    args = ["google-chrome", "--headless=new", "--disable-gpu", "--no-sandbox",
            "--hide-scrollbars", "--force-device-scale-factor=1",
            f"--screenshot={png_path}", f"--window-size={px},{px}"]
    if transparent:
        args.append("--default-background-color=00000000")
    args.append("file://" + svg_path)
    subprocess.run(args, capture_output=True)


def emit(rel, text):
    path = os.path.join(HERE, rel)
    with open(path, "w") as f:
        f.write(text)
    return path


def render(svg_text, out_path, px, transparent):
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    tmp = os.path.join(HERE, "_tmp.svg")
    with open(tmp, "w") as f:
        f.write(svg_text)
    chrome(tmp, out_path, px, transparent)
    os.remove(tmp)


DENS = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def main():
    # 1) Locked canonical sources
    emit("foreground.svg", svg(432))
    emit("monochrome.svg", svg(432, mono=True))

    # 2) Android adaptive foreground + monochrome (transparent), per density (108dp)
    for d, m in DENS.items():
        render(svg(round(108 * m)), os.path.join(RES, f"drawable-{d}", "ic_launcher_foreground.png"), round(108 * m), True)
        render(svg(round(108 * m), mono=True), os.path.join(RES, f"drawable-{d}", "ic_launcher_monochrome.png"), round(108 * m), True)
    # 3) Android legacy square + round mipmaps (48dp), per density
    for d, m in DENS.items():
        render(svg(round(48 * m), bg=ICON_BG), os.path.join(RES, f"mipmap-{d}", "ic_launcher.png"), round(48 * m), False)
        render(svg(round(48 * m), bg=ICON_BG, round_clip=True), os.path.join(RES, f"mipmap-{d}", "ic_launcher_round.png"), round(48 * m), True)
    # 4) Store master 512
    render(svg(512, bg=ICON_BG), os.path.join(ROOT, "android", "app", "src", "main", "ic_launcher-playstore.png"), 512, False)
    # Android launcher only — Flutter web icons and landing assets are NOT
    # touched here (web/landing icon sync is a separate follow-up).
    print("android launcher icons generated")


def check():
    import hashlib
    a = svg(432); b = svg(432)
    assert a == b, "SVG generation not deterministic"
    render(svg(216, bg=ICON_BG), os.path.join(HERE, "_det1.png"), 216, False)
    render(svg(216, bg=ICON_BG), os.path.join(HERE, "_det2.png"), 216, False)
    h1 = hashlib.sha256(open(os.path.join(HERE, "_det1.png"), "rb").read()).hexdigest()
    h2 = hashlib.sha256(open(os.path.join(HERE, "_det2.png"), "rb").read()).hexdigest()
    for f in ("_det1.png", "_det2.png"):
        os.remove(os.path.join(HERE, f))
    print("SVG deterministic: True")
    print(f"PNG double-render identical: {h1 == h2}  ({h1[:16]}…)")
    assert h1 == h2


if __name__ == "__main__":
    if "--check" in sys.argv:
        check()
    else:
        main()
