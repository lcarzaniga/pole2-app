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

## 10a. Kobe Canonical Geometry

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

**Head — a rounded bullet.**
- Slightly **taller than wide**, **domed** (semicircular) top, **softly rounded**
  base. **Never circular, never sharply pointed, no angular tip.**

**Limbs & tail.**
- **Four limbs** as soft ovals peeking at the diagonals (front pair upper, back
  pair lower), tucked partly under the shell.
- A **small rounded tail nub** at the bottom — rounded, never an angular triangle.

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
pointed head; an angular triangular tail; white outlines, drop shadows, neon
glow, or spotlight; a cartoon face or expression.

**Cross-product (current discrepancy).** As of M14 the **Flutter app**
(`lib/shared/brand/turtle_mascot.dart`) and the **old landing turtle** shared the
*same non-canonical* geometry: a **circular** shell with a **many-cell** clipped
honeycomb, a **circular** head, and a **triangular** tail. The landing is now the
first corrected implementation of the canonical geometry above; the app is to be
updated to match in a future milestone. Two different Kobes must not persist.

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
  cells; **Kobe's shell is a tessellated hex field clipped by its ellipse, with
  a recognizable 7-cell core** (see §10a). Never conflate.

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

**Trigger.** After a **random period of inactivity (~25–50 s)**, play the gesture
**once**. Reset the timer on genuine user activity, so it only stirs when things
are truly calm.

**The gesture — a quiet posture adjustment.** The **shell is the fixed point**;
the body subtly rebalances around the **shell centre**:
1. head and tail **rotate together a few degrees to one side** (~3–4°);
2. the four limbs **rotate slightly in the opposite direction** (~2°);
3. a **brief pause**;
4. the **same movement toward the opposite side**;
5. a smooth **return to the resting pose**.

It should resemble a real turtle quietly shifting its posture.

**Timing.** Total **~700–900 ms**, **smooth ease-in-out**, no abrupt
acceleration.

**Hard rules.** **Rotation only.** **Never** translate, scale, bounce, wave,
speak, or loop continuously. The shell never moves. **Pauses while the tab/app is
inactive.** **Off entirely under Reduce Motion.** It supports **presence**, not
engagement.

*(Supersedes the earlier M14 “satin shimmer” idle exploration. The static satin
sheen on the shell remains — that is figure-ground depth, §13, not motion.)*

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
