# Pole² — Brand Bible

*Status: Approved (Milestone 11). This is the single source of truth for what
Pole² **is** and how it must **look, sound, and feel**. It consolidates the
brand layer that sits above — and stays consistent with — three core documents:*

- **`BRAND_UX_MANIFESTO.md`** — the emotional/UX law (why we exist, how we behave).
- **`DESIGN_SYSTEM.md`** — the concrete token system (color, type, spacing, motion).
- **`DOMAIN_MODEL.md`** — the domain (Possession, Evidence, Event, …).

Where this document repeats those, it is to state a *brand rule*, not to
re-specify tokens. For exact values (hex, durations, spacing) defer to
`DESIGN_SYSTEM.md`. If ever in conflict, see **§15 Conflicts** below.

---

## 1. Name & origin

The product is **Pole²**.

The name comes from the Swahili expression **“pole pole”** — *slowly, calmly,
without rushing*. The superscript **²** is a quiet visual wordplay:

> **Pole² = Pole Pole.**

Users are **not** required to understand this immediately. It is part of the
brand story they may discover later. We never explain the pun in the UI.

- Always written **Pole²** — capital `P`, lowercase `ole`, superscript `²`.
- Never `POLE²`, never `Pole 2`, never `Pole squared`, never `Pole²·Pole²`.
- The `²` is never detached from the word (see §7 Wordmark).

## 2. Pole² and Kobe

**Pole²** is the product. **Kobe** is the turtle guardian who lives inside it.

| | Pole² | Kobe |
|---|---|---|
| Is | the app, the brand, the name users say | a character — the turtle |
| Role | the calm home for your things | quietly keeps things safe |
| Voice | none — it is a place, not a speaker | none — Kobe does **not** talk |
| Visibility | everywhere (wordmark, icon) | **rare and intentional** |

Kobe is **not** the product name, **not** an assistant, **not** a chatbot, and
**does not speak continuously** (or, ideally, at all). Kobe is presence and
protection, not personality-as-chatter. If Kobe starts narrating, we have built
the wrong product. (See Manifesto §1.)

## 3. Brand promise

> **Pole² is the digital equivalent of the trusted drawer at home** — the place
> people keep the things they always want to know where to find.

It communicates, in order of weight: **calm · order · safety · permanence ·
privacy · readiness.**

**Pole² is not a productivity app. It is a peace-of-mind app.** Productivity
apps sell *doing more*; Pole² sells *worrying less*. The governing acceptance
test for every feature remains: **“Does this reduce the user’s future anxiety?”**
If not, it does not ship.

## 4. Motto

**Primary (Italian):**

> **Custodisci ciò che conta.
> Conta ciò che custodisci.**

*(“Keep what matters. What you keep, matters.”)*

Rules:
- The motto belongs to **brand, launch and communication surfaces** — store
  listings, the web landing page, an about screen — **not** scattered through
  the working UI.
- Do **not** overuse it in-app. At most it may appear once, quietly, on a
  dedicated brand/about surface. It must never nag from a working screen.

## 5. Personality

Pole² is the **trusted keeper**: a calm, competent adult who looks after
important things without fuss. Warm, not cute. Confident, not loud. Present,
not needy.

- **Is:** calm, orderly, reassuring, permanent, discreet, quietly premium.
- **Is not:** playful-childish, gamified, urgent, chatty, salesy, clinical.

Whitespace, restraint, and stillness *are* the personality made physical. When
in doubt: add space, remove a divider, say less.

## 6. Tone of voice

Human, calm, adult, concise. Italian is the current voice (see the i18n note in
§13). Never technical, bureaucratic, or marketing-shouty.

**Say it like a trusted person would, plainly.**

| Do | Don’t |
|---|---|
| “Tutto resta su questo dispositivo.” | “I tuoi dati sono criptati end-to-end.” |
| “Conserva qualcosa.” | “Crea il tuo primo Possession.” |
| “Custodito.” / “Al sicuro.” | “Record salvato con successo ✅” |
| “Niente è andato perso.” | “Errore 500: operazione fallita.” |
| “Tra 12 giorni.” | “Scadenza: 26/07/2026 (T-12)” |

Principles:
- **No domain jargon in the UI.** Users never see *Possession, Evidence, Event,
  Party, Attribute, Identifier* — those are internal. (Manifesto + Domain Model.)
- **No manufactured urgency.** No streaks, badges, counts of zero, “complete
  your profile”, engagement nudges.
- **Errors protect the user, never blame them.** Our one promise is safety; an
  error is the moment it is tested. Reassure first (“niente è andato perso”),
  then explain calmly.
- **Kobe stays quiet.** No first-person chatter, no “Hi! I’m Kobe 🐢”.

## 7. Logo & wordmark

The **wordmark** is the only place the product name is typeset as a logo. It is
drawn in **Work Sans SemiBold** (see §8) and implemented once, centrally, as
`PoleWordmark` (`lib/shared/brand/pole_wordmark.dart`). Never hand-typeset it.

Wordmark rules:
- **“Pole”** with only the `P` capitalized — never all caps.
- Compact optical kerning; **slightly negative tracking (~ −2.5%)** so it reads
  as one tight visual unit.
- The **`²` is ~65–70% of the cap height** (we use 68%), sits **close to the
  final `e`**, and is raised as a superscript.
- The `²` must **never** be visually separated from the word, and must never be
  a different color or weight from `Pole`.
- Rendered as a raised, down-scaled `2` (not the Unicode superscript glyph) so
  size and position are exact and identical across platforms.
- The wordmark takes its color from context (adapts to light/dark). On brand
  surfaces it is warm ivory `#F6F1E7` on petrol, or petrol on light.

Where it appears in-app: the **top app bar on the home surface**. Elsewhere the
app bar shows the plain name of the thing being viewed, not the wordmark.

## 8. Typography roles

Two bundled, open-source, variable sans faces. **Both bundled, never fetched at
runtime** (offline/privacy applies to design too — Manifesto).

| Role | Face | Where |
|---|---|---|
| **UI text** (everything) | **Inter** | all screens, all body/label/title text |
| **Brand wordmark** | **Work Sans SemiBold** (`wght` 600) | the `Pole²` wordmark and selected brand surfaces only |

**Inter is the sole *UI* typeface.** Work Sans is **reserved exclusively** for
the wordmark and deliberate brand moments. It must **never** be used for UI
labels, body copy, buttons, or headings. Mixing Work Sans into the UI is a bug.

*(This refines — and is the current authority over — the older “sole type
family” line in `DESIGN_SYSTEM.md §4`; see §15.)*

## 9. Color

Single seed, calm restraint. Full tokens in `DESIGN_SYSTEM.md`; the brand-level
rules are:

- **Primary seed — petrol green `#2E6B5E`.** Dark petrol green with restrained
  teal accents. The brand’s anchor color.
- **Warm light surfaces.** The everyday UI is calm and light, not dark-moody.
- **Calm amber for attention** (`BrandColors.attention`) — upcoming deadlines,
  gentle “worth a glance” states. Amber is *attention*, never alarm.
- **Red is reserved for genuine failure only.** Never decorative, never for
  “attention”, never for delete-affordances that aren’t destructive-final.
- **Ivory `#F6F1E7`** is the warm near-white used for the wordmark/`P²` on petrol.

### Secondary accents (Tanzania-inspired)

Pole² draws its name and calm from Swahili "pole pole" and from Zanzibar. A very
restrained secondary palette exists as tokens (`AppColors`, see
`DESIGN_SYSTEM.md §1.5`) — used with discipline, **never** replacing petrol and
**never** as flag stripes or tourism theming.

- **Adopted:** `warmIvory #F6F1E7` (the P² / wordmark on petrol) and `sunGold
  #E0A83D` used *only* as a brief, low-alpha gloss sweeping the turtle shell
  during the idle discoverability cue — a small glimmer of life on the guardian,
  never chrome or text.
- **Held in reserve** (defined, not on ordinary screens): `oceanBlue #1C6E8C`
  (a rare secondary brand surface) and `charcoal #20211F` (future dark brand
  surfaces).
- Never several accents on one ordinary screen. `error` red stays reserved for
  genuine failure; `attention` amber stays calm. Restraint wins.

## 10. The turtle (Kobe)

- The turtle is **rare and intentional** — a hero moment, not a mascot stamped
  on every screen. Today it appears as the resting launcher on the home empty
  state and blooms its shell for the signature “keep something” interaction.
- Kobe is a **guardian, not a guide**: calm, present, protective. It **activates
  its shell** to open a safe place — it never “retracts” or “hides”.
- Kobe never speaks. No speech bubbles, no tips, no personality dialog.
- The turtle stays **inside the product experience** — deliberately **not** on
  the launcher icon (see §12).

## 10a. Kobe Canonical Geometry (M14 — superseded by §10c)

> **Superseded.** The flat "tessellated ellipse" shell below was the M14 working
> geometry. The **permanent identity is now §10c "Canonical Kobe"** (frozen from
> the published landing): a **flat top-down ellipse engraved with exactly 7
> scutes** (1 central true-hexagon + 6 surrounding), separated by grout joints.
> §10a is kept for history; where it conflicts with §10c, **§10c wins**.

*The single source of truth for how Kobe is drawn. One Kobe, everywhere —
landing, app, icon, social images, future assets. First corrected implementation:
the landing (`pole2-landing/src/components/Kobe.astro`, M14). The Flutter app
still uses the older geometry and will be brought to this spec in a future
milestone (see “Cross-product” below).*

**Shell — an ellipse, not a circle.**
- Horizontal axis / vertical axis = **0.90** (slightly taller than wide). Current
  approved direction; may be re-tuned later, but never a perfect circle.
- The shell is a domed ellipse with a calm rim.

**The shell tessellation rule.**
- **Kobe's shell is fully tessellated with regular hexagons. Its canonical
  visual core is formed by 7 complete central cells: 1 central + 6 surrounding.
  Additional cells continue toward the edge and are naturally clipped by the
  shell boundary.**
- One regular hex grid is centred on a cell at the shell centre, so the central
  hexagon and its 6 complete edge-sharing neighbours (the recognizable core) are
  always present; the *same* grid continues outward and is **clipped by the
  ellipse**. The result reads as a **continuous structured shell**, never a
  seven-cell flower placed inside an ellipse.
- This is **distinct from the decorative background honeycomb** (`HexBackground`
  / `HexTexture`): there the cells are faint texture; here the cells **are** the
  shell's structure. Never conflate the two.

**Head — a rounded, elongated bullet.**
- Slightly **taller than wide**, **domed** (semicircular) top, **softly rounded**
  base. **Never circular, never pointed.** The head is *rounded*; the **tail is
  the only pointed body element**.

**Limbs & tail.**
- **Four limbs** as soft ovals peeking at the diagonals (front pair upper, back
  pair lower), tucked partly under the shell.
- The **tail** is **short, triangular, and clearly pointed**, **centred on the
  vertical axis** of the shell and **visually distinct from the rear limbs**.
  **Never rounded, never leaf-shaped, never bullet-shaped.** It is the sole
  pointed element (the head stays rounded).

**Visual invariants.**
- Geometric, calm, adult, recognizable — **never cartoonish**.
- Colours unchanged: mint shell (`#a7ded0`), deep-teal body (`#123f34` on the
  landing), hex lines a translucent body tone. Petrol identity untouched.
- A subtle **satin sheen** on the shell (upper-left) for depth/figure-ground; no
  outlines, heavy shadows, or spotlight.

**Acceptable variations.** Size; overall colour theming for light/dark surfaces;
presence/absence of the warm separation halo (context-dependent); the canonical
idle animation (§13a) on/off.

**Unacceptable variations.** A circular shell; a shell that stops at the 7 core
(a lone "flower" with empty space to the rim) instead of tessellating to the
clipped edge; a **missing or incomplete** central 7-cell core; a circular or
pointed head; a **rounded, leaf-, or bullet-shaped tail** (the tail must be a
short pointed triangle) or a tail confusable with the rear limbs; white outlines,
drop shadows, neon glow, or spotlight; a cartoon face or expression.

**Cross-product (current discrepancy).** As of M14 the **Flutter app**
(`lib/shared/brand/turtle_mascot.dart`) and the **old landing turtle** shared the
*same non-canonical* geometry: a **circular** shell with a **many-cell** clipped
honeycomb, a **circular** head, and a **triangular** tail. The landing is now the
first corrected implementation of the canonical geometry above; the app is to be
updated to match in a future milestone. Two different Kobes must not persist.

## 10c. Canonical Kobe (permanent identity — matches the published landing)

*The single source of truth for Kobe across app, landing, icon, splash, docs and
marketing. **Frozen from the geometry published live at pole2.it** (landing
component `src/components/Kobe.astro`). Implemented identically in the Flutter app
at `lib/shared/brand/turtle_mascot.dart` (R1.0). The **shell is the
symbol of Pole²** — the goal is that Kobe is recognizable from the shell alone.
This supersedes the earlier domed-panel description of §10c; where they conflict,
this section wins.*

### Construction (build the shell in this order)

The shell is a **flat, top-down tortoise carapace** — one continuous surface,
engraved with seven scutes. It is **not** a domed/foreshortened shell and **not** a
honeycomb field.

1. **Ellipse.** A clearly **vertical ellipse** is the outer silhouette:
   width / height ≈ **0.86** (compact, calm, slightly chubby; never a circle,
   never horizontal). The silhouette is a **pure ellipse** (no taper) — its
   identity comes from the engraving, not the outline.
2. **Central hexagon.** A **true regular flat-top hexagon**, centred on the shell,
   circumradius **R = 0.70 × (shell half-width `rx`)**. Undistorted — exactly six
   equal sides, never rounded into an octagon.
3. **Six radial joints.** One straight joint through **each** of the six hexagon
   vertices, continued outward to the ellipse edge (only the portion outside the
   hexagon is drawn).
4. This yields **exactly 7 scutes: 1 central + 6 surrounding** — **front, rear,
   front-left, front-right, rear-left, rear-right.** The **front and rear scutes
   are single** (no vertical spine groove, never split). Bilaterally symmetric
   about the vertical axis.

Golden rule: hide the joints and the silhouette still reads as a tortoise shell;
hide the outline and the joints still describe exactly seven scutes. Laser-cut
test: engraved into one ceramic disc, the joint network makes sense.

### The grout joint (how scutes are separated)

Scutes are **never filled as separate colours** — the shell is one continuous
light surface. Separation comes **only** from the engraved joint, built as
**dark edge · light groove · dark edge** (a wider dark band with a narrow
light-groove band centred on it). The **outer border is one thick dark ellipse**
(≈2× the grout) — the frame that defines Kobe, so the shell is the strongest
element. Visual hierarchy: **outer border > grout joints > body**. Grooves
**taper**: narrowest at the centre, imperceptibly wider toward the rim (a subtle
dome cue, never decorative). Never rely on the background colour for the groove.

### Proportions (canonical, as published)

| Element | Canonical | Notes |
|---|---|---|
| Shell ratio (w/h) | **≈ 0.86** | vertical ellipse; never a circle |
| Central hexagon | **R = 0.70 × shell half-width**, flat-top, centred | dominant; leaves room for a possible future small mark (`²`, `P²`) — none added now |
| Surrounding scutes | **6** (front, rear, four corners) | front & rear single; all joints reach the edge |
| Head | **elongated teardrop**, enlarged to read clearly as the head | rounded nose, narrows at the neck; never circular, never pointed |
| Tail | short **pointed triangle**, on the vertical axis, under the rear | the **only** pointed element; separate from the shell outline |
| Legs | **front pair + rear pair**, equal size | front pulled toward the head, rear toward the tail |

### Colours (two colourways — exact published values)

- **Illustrated Kobe** (character, with head/tail/legs): shell fill **`#bfdacd`**;
  body + all dark joint edges + border **`#1f4638`**; grout light groove
  **`#e7f4ee`**. Nearly flat; a very restrained rim shadow only — no gloss, no
  highlight, no drop shadow, no body outline.
- **Monochrome shell mark** (icon/emblem, shell only, no body): shell fill
  **`#f2ecdf`** (warm ivory, not beige); grout **`#fbf8f1`**; edges **`#234a40`**.
  The shell *is* the icon.
- **Contrast:** Kobe must stay legible on light *and* dark surfaces on its own. On
  a true near-black surface the dark body may pass a lighter `body` value; the
  geometry never changes.

### Movement (animation groups)

- **The shell is the fixed anchor — it never moves.** Only **head, tail, front
  legs, rear legs** move, as independent groups: `kobe-shell` (anchor) +
  `kobe-head`, `kobe-tail`, `kobe-front-legs`, `kobe-rear-legs`.
- Directions: head **tip** and tail **tip** go to the **same** side (they
  counter-rotate about the shell centre); the **front and rear leg pairs** go to
  the **opposite** side; then mirror; then settle. Rotation only — no
  translate/scale/bounce/loop.
- A slow **idle** after ~25–50 s of inactivity (reset only by a direct shell
  click); a larger, clearly-visible **reaction** on a direct shell click/tap.
  Suspended on a hidden tab. **Reduce-Motion:** rotation is replaced by a brief
  shell highlight. (See §13a for exact timing/degrees.)

### The icon

Recommended long-term icon direction: the **pure ivory shell mark** (shell only,
no body, colours above) — the shell is strong enough to *be* the icon. The current
launcher icon (§12, "Plain P²") may continue; moving the app icon to the shell is
an implementation decision.

### Invariants (always true)

1. Shell = a **vertical ellipse** (w/h ≈ 0.86) engraved with **exactly 7 scutes**
   (1 central + 6); the central a **true regular flat-top hexagon** at **0.70**.
2. **One continuous surface** — no per-scute fills; separation only via the
   **grout joint** (dark · light · dark); the **outer border is a single thick
   dark ellipse** (the frame — hierarchy: border > grout > body).
3. Front & rear scutes are **single**; **no spine groove**; six joints reach the
   edge; bilaterally symmetric.
4. Head = **elongated teardrop** (clearly larger than the legs); tail = short
   **pointed triangle** (the only pointed element); legs = **front + rear** equal
   pairs.
5. **The shell never moves**; only head/tail/legs do (directions above).
6. Two colourways only: illustrated mint (character) and monochrome ivory (mark).
7. The **shell alone** must work as the brand mark.

### Prohibited variations

- A **domed / foreshortened** shell, folded panels, or perspective wedges (the
  M15 iteration-1 dome — retired); a **circular** or horizontal shell.
- A **honeycomb / tessellated** shell field (the M14 tessellation — retired).
- **Any** scute count other than 7 (1 + 6); a **split** front or rear scute, or a
  continuous **spine** groove.
- A hexagon that is distorted, rounded into an octagon, or off-centre.
- **Per-scute colour fills**, or a single-line joint (the joint is always
  dark · light · dark); relying on the background colour for the groove.
- A circular or pointed **head**; a rounded/leaf **tail** or one confusable with
  the legs.
- Gloss, 3D shading, highlights, drop shadows, neon, or a body outline — Kobe is
  calm, flat, geometric.
- A cartoon face, eyes, or expression.
- A moving shell; legs or head/tail moving the wrong way.

## 11. The hexagon

The regular hexagon (the turtle’s shell) is the **primary visual motif** — used
with restraint.

- Hexagons are a **motif, not the shape of every component.**
- **Normal content cards remain readable rounded rectangles.** Do not hexagon-
  shape cards, buttons, avatars, or containers.
- **Do not decorate every screen with hexagons.** A faint honeycomb texture and
  the shell menu are the sanctioned uses; anything else must justify itself.
- The hexagon belongs to Kobe. Overusing it cheapens both.
- **Decorative honeycomb ≠ Kobe's shell.** Background texture is faint, free
  cells; **Kobe's shell is a vertical ellipse engraved with exactly 7 scutes**
  (1 central hexagon + 6), separated by grout joints (see §10c). Never conflate.

## 12. App icon

**Chosen direction: Candidate 1 — “Plain P²”.** Warm-ivory `P²` centered on a
dark-petrol field. No turtle, no gradient, no thin lines.

**Why:** most legible at launcher size, adult and professional, and it keeps the
turtle/hexagon motifs *inside* the product rather than on the home screen. It
scales cleanly to 48 px and reads under any launcher mask (circle, squircle,
rounded square).

Icon rules:
- Dark petrol background `#2E6B5E`; `P²` in white / warm ivory.
- Simple, compact, readable at small size. No text other than `P²`.
- No detailed turtle illustration. No thin lines that vanish at launcher size.
- No gradient unless *extremely* subtle. (Chosen icon uses none.)
- `²` never clipped; foreground kept inside the adaptive safe zone.

**Android** ships a full adaptive icon: solid petrol background layer, `P²`
foreground layer, and a **monochrome** layer for Android 13+ themed icons, at
all launcher densities (mdpi→xxxhdpi) plus the legacy square/round icon. The
**web favicon** and PWA icons use the same mark. Source PNGs are painted from
the bundled Work Sans font, so the icon and the in-app wordmark are one identity.

### Candidate concepts (preserved)

Three candidates were rendered and compared (`assets/branding/`):

1. **Plain P²** — *chosen.* Maximum legibility; adult and calm.
2. **P² in a subtle hexagon** — ties to the shell motif; the hexagon competes
   with the `P²` at small sizes. **Kept as the alternate for splash / marketing
   surfaces**, where size is generous.
3. **P² with a shell reference in the P** (a small hexagon nested in the P’s
   counter) — the shell integrated into the letter. Rendered as clutter at icon
   scale and hurt legibility; **kept as a concept only**, not for production.

> Principle applied: *do not choose complexity over legibility.*

## 13. Motion principles

(Full spec in `DESIGN_SYSTEM.md §5` and Manifesto “Signature interaction”.)

- **Calm, brief, interruptible.** Nothing blocks the user; every animation can
  be skipped and honors **reduce-motion** (collapses to instant).
- **The shell unfold is the signature** (~560 ms) — “opening a safe place for
  something new,” used **only** for creating a new thing. Kobe stays present and
  confident; the shell opens, never hides.
- Motion **reassures**, never entertains or demands. No bouncy, attention-
  seeking, or looping-forever animation.
- On startup, the launch surface is a **calm petrol field with the P²** — it
  flows from the tapped icon into the app with no white flash.
- **Kobe idle animation (canonical).** See the dedicated spec in **§13a** — one
  calm posture adjustment after a period of inactivity. Presence, not engagement.
- **Figure-ground (separation), not decoration.** Kobe may be lifted from a
  similar-toned background with restrained means — a **soft warm halo**, a
  slightly lighter background centre, a **satin sheen** on the shell, a small
  tonal lift on limbs. **Never** white outlines, heavy shadows, neon glow, or an
  obvious spotlight. Kobe should *emerge naturally*.

## 13a. Kobe idle animation (canonical)

*The one canonical idle behaviour. Kobe should occasionally look **alive**, not
**animated**. Every implementation — Flutter, website, marketing — reuses this
same movement vocabulary. First implemented on the landing
(`pole2-landing/src/components/Kobe.astro`, M14).*

**Trigger & timer (exact).** A single random idle delay (~25–50 s), then the
gesture plays **once**, then a **new** random delay — repeating.
- The timer is **NOT reset by general page/app interaction** — not by scrolling,
  keyboard use, pointer movement, or clicks/taps on other elements.
- It **resets only** on a **direct click/tap on Kobe's shell** (which cancels the
  timer, plays the reaction, then starts a fresh delay).
- **Never** run **more than one** timer at a time.
- **Suspend** the timer while the page/app is **hidden**; reschedule when visible.

**Canonical movement directions.** The **shell is the fixed point**; the body
rebalances around the **shell centre** (rotation only). The **tips** move, not a
rigid block: because head and tail sit on opposite sides of the centre, they
**counter-rotate** so both **tips travel to the same side**; likewise the upper
and lower leg pairs counter-rotate so **all four legs travel to the opposite
side**. So when Kobe sways **right**:
- the **head tip and the tail tip both move right**;
- **all four legs (upper and lower) move left**;

then it **mirrors** (head+tail tips left, all legs right), and finally **returns
to neutral**. It should resemble a real turtle quietly shifting its posture — a
sway to one side, brief pause, mirror to the other, settle. (Implementation: four
groups — `kobe-head`, `kobe-tail`, `kobe-legs-upper`, `kobe-legs-lower` — head +φ
/ tail −φ; upper-legs −ψ / lower-legs +ψ, and mirrored.)

**Timing.** Total **~700–900 ms**, **smooth ease-in-out**, no abrupt
acceleration.

**Hard rules.** **Rotation only.** **Never** translate, scale, bounce, wave,
speak, or loop continuously. The shell never moves. **Pauses while the tab/app is
inactive.** **Off entirely under Reduce Motion.** It supports **presence**, not
engagement.

*(Supersedes the earlier M14 “satin shimmer” idle exploration. The static satin
sheen on the shell remains — that is figure-ground depth, §13, not motion.)*

**Reaction (click / tap).** Where Kobe is interactive, a **direct click/tap**
plays a **clearly-visible** version of the same gesture — the emotional read is
*“the visitor gently disturbed Kobe.”* **Never** frightened, hurt, or angry.

- **Same vocabulary, larger than idle:** shell fixed; head tip & tail tip move
  to one side (we use head **+6.6°** / tail **−6.6°**), the four legs to the
  opposite side (**−4.2°**); a **brief reverse** (head **−4.2°** / tail **+4.2°**
  / legs **+2.7°**); then a smooth settle to rest.
  (Idle uses the smaller head/tail **±3.6°** / legs **∓2.4°**.)
- **Timing ~650–850 ms** (we use **780 ms**), **smooth springless** easing — no
  bounce, no translation, no scale, no sound, no looping.
- Triggered **only by a direct click/tap on the shell** (the head, tail, limbs
  and the empty bounding box are **not** hit targets) or by **keyboard**
  (Enter/Space on the focused guardian). It **cancels/stops the idle timer** while
  running and **ignores repeated input until it finishes** (no stacked/broken
  animations); afterwards a fresh idle delay begins.
- **Interactivity is signalled** by a pointer cursor + an accessible label
  (role=button, name) — **no instructional text and no visible button** around
  Kobe.
- **Reduce Motion:** the rotation is replaced by a **brief, subtle shell
  highlight** (a short satin/gold flash), not movement.

## 14. Things the brand must never become

- A **productivity / gamified** app: streaks, badges, XP, completion %, nudges.
- A **chatbot / assistant** with a talking Kobe or an AI persona.
- A **surveillance** app: no account, no cloud, no analytics, no ads, no
  tracking, no lock-in. Data stays on the device; the user owns it always.
- A **cluttered** app: hexagons everywhere, dense lists, decorative noise.
- A **loud/urgent** app: red everywhere, alarms, countdowns that stress.
- A **jargon** app: exposing Possession/Evidence/Event to users.
- A **lock-in** app: proprietary export, fetched fonts, hidden data.

If a proposal moves Pole² toward any of these, it is wrong regardless of how
“standard” it is.

## 15. Conflicts identified & resolved

Per the milestone brief, conflicts between this Bible and the older approved
docs are surfaced, not silently overridden:

1. **Product name.** `BRAND_UX_MANIFESTO.md` and `DESIGN_SYSTEM.md` predate the
   M8 rename and use **“Kobe” to mean the product** (“Kobe sells worrying less”,
   “feels like Kobe”). **Resolution:** the product is **Pole²**; **Kobe is only
   the turtle.** Read every product-level “Kobe” in those documents as “Pole²”.
   Their emotional/design content remains fully valid. A one-line banner has
   been added to the top of each pointing here for naming.
2. **“Sole type family.”** `DESIGN_SYSTEM.md §4` says Inter is the *sole* type
   family and “brand character is … not [carried by] the typeface.”
   **Resolution:** Inter remains the **sole UI typeface**; **Work Sans is added
   strictly for the wordmark and brand surfaces** (§8). This is a scoped brand
   exception, not a general second UI font. This Bible is the current authority
   on the point.

No other conflicts were found. Color (`#2E6B5E`), the hexagon-as-motif rule,
sans-only restraint, bundled-not-fetched assets, and “peace-of-mind not
productivity” are consistent across all documents.
