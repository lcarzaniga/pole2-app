# Pole² · Kobe — production Android launcher-icon source (M8.3B)

Locked, deterministic source of truth for the **Android launcher** icon. It
reproduces the visually approved **Option C at its original base scale**
(`design/icon-concepts/m8.3/revision-2/`, variant C, `TARGET_R = 35.2`) exactly —
verified byte-identical geometry — and generates every Android launcher raster
from it. **`KobePainter` / `TurtleMascot` / Kobe inside the app are never
modified.** Flutter web icons and the landing assets are **not** touched by this
tool (web/landing icon sync is a separate follow-up).

> The larger "C-max" scale (TARGET_R = 42) was **rejected on real Samsung One UI
> hardware** — it filled the mask too aggressively and the head/legs sat too
> close to the edge. The base-scale C keeps visible breathing room around the
> head and legs while staying comparable in weight to neighbouring icons.

## Canonical source

- Generator: `tool/app_icon/kobe_icon.py` (self-contained; reuses only the
  canonical shell constants from `lib/shared/brand/turtle_mascot.dart`, read-only).
- Locked SVGs: `tool/app_icon/foreground.svg` (transparent), `monochrome.svg`
  (single-colour, transparent).
- No AI, no randomness — two runs are byte-identical.

## Approved design (locked)

- Canonical shell + **seven scutes**; oversized head + four **partially
  retracted** chunky legs; **no face**, **no tail**.
- Palette: shell `#BFDACD`, body/rim/grout `#1F4638`, limb highlight `#3C7A63`,
  shell sheen `#D7EAE0`, full-bleed clean warm lemon-yellow background `#EBB94C`, monochrome
  `#101613`.
- **Scale**: original Option C base scale — whole turtle uniformly fit to
  `TARGET_R = 35.2` in the 108-unit adaptive canvas.
- **Optical centre**: the silhouette bounding-box centre is placed at (54, 54).
- **Foreground bounds**: max geometry radius **35.2** from centre.
- **Breathing room / safe margins**: 66 dp safe circle = r33; base-scale C
  (r35.2) sits just outside the 66 dp safe circle and keeps **+0.8** to a 72 dp
  circle (r36), **+8.8** to an 88 dp circle (r44); squircle and rounded-square
  expose the corners and leave even more room. **No mask is baked** into the
  foreground — the launcher applies the device mask.

## Deterministic export

```
cd tool/app_icon
python3 kobe_icon.py           # write locked SVGs + all Android launcher PNGs
python3 kobe_icon.py --check   # assert SVG + double PNG render are byte-identical
```

Rendering uses headless `google-chrome` at `--force-device-scale-factor=1`
(transparent output via `--default-background-color=00000000`). No
`flutter_launcher_icons` or other dependency.

## Resource mapping (Android launcher only)

| Purpose | Path(s) | Size(s) |
|---|---|---|
| Adaptive foreground | `android/.../res/drawable-{mdpi..xxxhdpi}/ic_launcher_foreground.png` | 108/162/216/324/432, transparent |
| Adaptive monochrome (API 33+) | `android/.../res/drawable-{…}/ic_launcher_monochrome.png` | same, single-colour transparent |
| Adaptive XML (API 26+) | `android/.../res/mipmap-anydpi-v26/ic_launcher.xml`, `ic_launcher_round.xml` | background colour + foreground + monochrome, **no inset** |
| Background colour | `android/.../res/values/colors.xml` → `ic_launcher_background` | `#EBB94C` (clean lemon-yellow) |
| Legacy square (API 24/25) | `android/.../res/mipmap-{…}/ic_launcher.png` | 48/72/96/144/192, lemon-yellow background |
| Legacy round | `android/.../res/mipmap-{…}/ic_launcher_round.png` | same, circle-masked |
| Store master | `android/app/src/main/ic_launcher-playstore.png` | 512 |

Manifest: `android:icon="@mipmap/ic_launcher"`,
`android:roundIcon="@mipmap/ic_launcher_round"`.

Flutter web favicon/PWA icons and the landing assets are intentionally **out of
scope** and left unchanged.

## Review concepts

All exploration / rejected concepts live under `design/icon-concepts/m8.3/`
(including `rejected/` and the rejected C-max scale in `revision-2/c-size/`). That
tree is **not bundled** (not in `pubspec.yaml` assets) and **not referenced** by
any Android production resource.
