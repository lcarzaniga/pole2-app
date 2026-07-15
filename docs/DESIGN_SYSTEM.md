# Project Kobe — Design System

> **Naming note (post-M8/M11):** the product is **Pole²**; **Kobe** is only the
> turtle. Read product-level “Kobe” below as **“Pole²”**.
> **Typography note:** §4’s “sole type family” now means Inter is the sole **UI**
> typeface; **Work Sans** is added strictly for the **Pole² wordmark** and brand
> surfaces. See `BRAND_BIBLE.md` §8 and §15.

*Status: Draft — pending approval. Companion to `BRAND_UX_MANIFESTO.md`. Where the manifesto defines the felt experience, this document defines the concrete tokens that produce it. No feature may hardcode a color, size, duration, or radius — everything comes from here.*

---

## 0. Foundational rules

1. **Tokens are the single source of truth.** Features reference semantic tokens (`surface`, `space.lg`, `motion.gentle`), never raw values. Raw hex/px/ms live only in the theme layer.
2. **Semantic, not literal.** We name tokens by *role* (`attention`, `kept`), not appearance (`amber`, `green`). Roles can be re-tuned without renaming.
3. **Material 3 is the substrate, restraint is the style.** We adopt M3's systematic color/type/elevation model, then *subtract* — fewer borders, softer elevation, more space — until it feels like Kobe, not like a stock Material app.
4. **Offline & privacy apply to design too.** Fonts and icons are **bundled in the app**, never fetched at runtime. No design asset makes a network call. (This rules out runtime Google Fonts.)
5. **Everything degrades gracefully.** Every token has a defined behavior under dynamic type, high contrast, and reduce-motion.

---

## 1. Color

### 1.1 Strategy
The entire palette derives from **one seed** — `#2E6B5E` (calm teal-green: trust, safety, stability) — via Material 3's `ColorScheme.fromSeed`, generating full tonal palettes for **light and dark**. We do **not** hand-pick the systematic roles; we let the algorithm keep them harmonious and accessible, then add a small set of **brand-semantic tokens** we control explicitly.

> Engineering stance: generated role values (`primary`, `surface`, etc.) are **produced at build from the seed and never hardcoded**. Only the seed and the custom brand tokens below carry literal hex.

### 1.2 Systematic roles (generated from seed)
Standard M3 roles, used for their intended purpose:

| Role | Use |
|---|---|
| `primary` / `onPrimary` | The turtle/shell action, primary emphasis. Used sparingly. |
| `primaryContainer` | Calm filled surfaces for primary affordances. |
| `secondary` / `tertiary` | Supporting accents — rare, low-frequency. |
| `surface` / `surfaceContainer*` | The shelves and cards. Warm-tinted neutrals (the seed tints surfaces slightly green — cozy, not cold grey). |
| `onSurface` / `onSurfaceVariant` | Primary and secondary text/icons. |
| `outline` / `outlineVariant` | Hairlines — used minimally. |
| `error` / `onError` | **Reserved for genuine, rare failure only.** Never for warnings. |

### 1.3 Brand-semantic tokens (explicit, controlled by us)
These encode manifesto emotions the M3 defaults don't capture. Values are calm and low-saturation by intent.

| Token | Light | Dark | Meaning |
|---|---|---|---|
| `kept` | `#2F6E5C` | `#7FD6BE` | The "it's safe now" confirmation. A calm green settle, not a celebratory pop. |
| `onKept` | `#FFFFFF` | `#06251C` | Content on `kept` surfaces. |
| `attention` | `#8A6D2F` | `#E4C079` | Calm heads-up (e.g. warranty approaching). **Muted amber — never alarm red.** |
| `onAttention` | `#FFFFFF` | `#241B06` | Content on `attention`. |
| `shellTint` | `#E7F1EC` | `#16221D` | The subtle hexagon-shell background texture; barely-there brand presence. |

**Rules:**
- **`error` (red) is quarantined.** Warranty-expiring, low-confidence, "heads-up" states use `attention`, never `error`. Red appears only when something genuinely failed — and per the manifesto, even then the copy reassures first.
- **Color never shouts.** Emphasis comes from type weight, space, and hierarchy — not saturated fills. Large saturated areas are prohibited.
- **Dark mode is calm, not black.** Surfaces are dark warm-neutral with tonal elevation, never pure `#000`. Elevation is expressed by lighter surface tone, not heavy shadow.

### 1.4 Contrast
All text/background pairs meet **WCAG AA** (4.5:1 body, 3:1 large). Brand tokens above are chosen to pass on their paired surfaces. A high-contrast mode maps `outlineVariant`→`outline` and increases text weight one step.

### 1.5 Tanzania-inspired secondary accents (proposal + what is adopted)

Pole² takes its name from Swahili "pole pole" and its calm from Zanzibar. A very
restrained secondary palette is *defined as tokens* (in `AppColors`) so it can be
used with discipline — **petrol `#2E6B5E` remains the primary identity and is
never replaced.** No flag stripes; the app is never themed around tourism.

| Token | Value | Role | Status |
|---|---|---|---|
| `oceanBlue` | `#1C6E8C` | Deep Indian-Ocean blue — a *rare* secondary brand surface only | **Reserved** (defined, not on ordinary screens) |
| `sunGold` | `#E0A83D` | Warm sun-gold — a *very small, transient* guardian/shell detail | **Adopted**: the idle-cue gloss only |
| `charcoal` | `#20211F` | Very dark charcoal — future dark brand surfaces | **Reserved** |
| `warmIvory` | `#F6F1E7` | Warm ivory — the P² on the icon and the wordmark on petrol | **Adopted** (since M11) |

Rules: never several accents on one ordinary screen; `error` stays reserved for
genuine failure; `attention` amber stays calm. Gold appears only as a brief,
low-alpha additive gloss on the turtle shell (not text, not chrome), so it never
needs to meet text-contrast ratios; ivory-on-petrol and P² already pass. Ocean
blue and charcoal are held in reserve until a use genuinely improves the app —
restraint wins.

---

## 2. Typography

### 2.1 Strategy
**One bundled humanist sans-serif does the vast majority of the work.** Humanist (not geometric) because it reads warm, calm, and adult — matching "trusted keeper," not "tech startup." Bundled as a variable font so we ship one file and get all weights.

**Primary family (approved): `Inter`** (SIL OFL, open-source → no lock-in, exceptional screen legibility, quiet personality). Bundled as a variable font. This is the sole type family; brand character is carried by color, motion, and the turtle — not by the typeface.

**Serif accent — parked, not adopted.** A calm serif for rare "permanence/archive" moments was considered and deliberately declined for now, in favor of sans-only restraint. If a future emotional moment clearly demands it, it returns as its own small proposal — never sprinkled in ad hoc.

### 2.2 Weights (constrained on purpose)
Only three: **Regular 400**, **Medium 500**, **SemiBold 600.** No Bold/Black — loud weights break the calm. Emphasis = one step up in weight or size, never all-caps shouting.

### 2.3 Type scale (mapped to M3 roles)
Sizes in logical px; line-heights tuned slightly generous for calm reading. Letter-spacing near-neutral (humanist faces don't want tight tracking).

| Role | Size / Line-height | Weight | Use |
|---|---|---|---|
| `displaySmall` | 32 / 40 | 400 | Rare hero moment (empty-state welcome). |
| `headlineSmall` | 24 / 32 | 500 | Screen titles, section heroes. |
| `titleLarge` | 20 / 28 | 500 | Card/possession titles. |
| `titleMedium` | 16 / 24 | 500 | Sub-headers, list leading text. |
| `bodyLarge` | 16 / 24 | 400 | Primary reading text. |
| `bodyMedium` | 14 / 20 | 400 | Secondary text, descriptions. |
| `labelLarge` | 14 / 20 | 500 | Buttons, actions. |
| `labelSmall` | 12 / 16 | 500 | Metadata, timestamps, quiet captions. |

**Rules:**
- **Dynamic Type respected fully** — the scale flexes with the OS text-size setting; layouts must not break at large sizes.
- **Two type sizes per view, ideally.** Restraint applies to typography: a screen crowded with sizes feels anxious.
- Line length capped (~60–70 chars) on wide screens for readability.

---

## 3. Spacing & layout

### 3.1 Base unit: 4dp. Everything is a multiple.

| Token | Value | Typical use |
|---|---|---|
| `space.xs` | 4 | Icon-to-label, tight pairs. |
| `space.sm` | 8 | Inside compact components. |
| `space.md` | 12 | Default intra-component gap. |
| `space.lg` | 16 | **Default screen margin**, card padding. |
| `space.xl` | 24 | Section separation. |
| `space.2xl` | 32 | Major section breaks, breathing room. |
| `space.3xl` | 48 | Empty-state generosity. |
| `space.4xl` | 64 | Hero vertical rhythm. |

### 3.2 Space is a feature
Kobe is **generous with whitespace** — it's how "calm, uncrowded, safe" is expressed physically. When in doubt, add space, remove a divider. Density is the enemy of calm.

### 3.3 Corner radius

| Token | Value | Use |
|---|---|---|
| `radius.sm` | 8 | Chips, small controls. |
| `radius.md` | 12 | Default cards, inputs. |
| `radius.lg` | 16 | Prominent cards, sheets. |
| `radius.xl` | 24 | Bottom sheets, large surfaces. |
| `radius.full` | pill | Buttons, the turtle action. |

Soft, rounded — never sharp corners (sharp reads as clinical/alarming).

### 3.4 The hexagon is a motif, not a layout straitjacket
The shell/hexagon is **texture and signature**, not the shape of every card. **We do not force hexagonal cards** — hex shapes hurt legibility, density, and text layout. The hexagon lives in: the signature turtle menu, subtle background texture (`shellTint`), brand marks, and empty-state art. Content containers stay rounded rectangles. *State this plainly so no one over-applies the motif.*

**Decorative honeycomb vs Kobe's shell.** The background texture may contain
*many* faint cells. **Kobe's shell is different: it is always exactly 7 hexagons**
(1 central + 6 surrounding). Never conflate the two.

### 3.4a Kobe geometry (invariants — canonical spec in `BRAND_BIBLE.md §10a`)
Kobe is drawn from one canonical geometry (first corrected on the landing, M14;
the Flutter `turtle_mascot.dart` follows in a later milestone):

- **Shell:** an ellipse, horizontal/vertical axis ratio **0.90** (taller than
  wide) — **current approved direction**, never a perfect circle.
- **Shell scutes:** **exactly 7 hexagons** (1 + 6), edge-sharing, clipped to the
  ellipse. Never more, never fewer.
- **Head:** a rounded **bullet** — taller than wide, domed top, softly rounded
  base. Never circular, never pointed, no angular tip.
- **Limbs/tail:** four soft ovals at the diagonals; a small rounded tail nub
  (never a triangle).
- **Separation:** lift Kobe from a similar-toned background with a **soft warm
  halo**, a lighter background centre, a **satin sheen**, and/or a small tonal
  lift — **never** outlines, heavy shadows, neon glow, or spotlight.
- **Idle motion:** one **infrequent**, restrained shell shimmer; not continuous;
  pauses on inactive tab/app; **off under Reduce Motion**. Presence, not
  engagement.

### 3.5 Elevation
Minimal. Prefer **tonal elevation** (slightly lighter/darker surface) over drop shadows. Shadows, if used, are soft and shallow. A flat, papery calm beats floating cards.

---

## 4. Iconography

- **Base set: Material Symbols, Outlined, Rounded** — bundled, not fetched. Rounded terminals match our soft radii; outlined (not filled) matches restraint.
- **Filled variants reserved for active/selected state only** — the fill *is* the state change.
- **Consistent metrics:** 24dp grid, single optical weight (~300–400), uniform stroke. No mixing icon styles.
- **Quiet and functional.** No multicolor, no playful/novelty icons. Icons inherit `onSurfaceVariant` by default; `primary` only when they *are* the primary action.
- **Brand marks are separate from UI icons:** the hexagon shell (brand/structure) and the turtle character (rare, guardian) are illustration assets, governed by the manifesto's scarcity rules — never sprinkled as decorative UI icons.
- **Touch target ≥ 48dp** regardless of icon size.

---

## 5. Motion

### 5.1 Principle: motion is reassurance, not spectacle
Movement is **slow, deliberate, and natural** — the unhurried turtle. Nothing snaps, nothing bounces hard, nothing overshoots aggressively. Motion communicates *"kept safely,"* *"opening a safe place,"* *"still here."*

### 5.2 Duration tokens

| Token | Value | Use |
|---|---|---|
| `motion.micro` | 120ms | State tints, ripple, tiny feedback. |
| `motion.short` | 220ms | Small transitions, fades. |
| `motion.medium` | 320ms | Screen/element transitions. |
| `motion.signature` | 560ms | The turtle shell unfold — **interruptible & skippable**. |

### 5.3 Easing tokens
- `ease.gentle` — soft decelerate (emphasized-decelerate style) for entrances: things *arrive and settle*.
- `ease.standard` — symmetric ease for reversible transitions.
- `ease.settle` — a barely-there settle for "kept" confirmation. **No spring overshoot.**

### 5.4 Signature interaction (motion spec)
The turtle **calmly activates its shell**: the shell unfolds into its hexagonal structure while the turtle remains present and confident — *"opening a safe place for something new,"* never *"hiding."* Hexagons stagger outward on `ease.gentle`. **Core action hexagons are in fixed positions; only one or two secondary hexagons adapt to habit.** The whole thing is **fast, interruptible, skippable**, and used **only for creating a new possession**. (See manifesto §Signature interaction.)

### 5.5 Reduce-motion (mandatory)
When the OS requests reduced motion: replace movement/scale with **simple opacity fades ≤ 120ms**, or nothing. The shell unfold collapses to an instant, calm reveal of the menu. No parallax, no large translations. This is a hard requirement, not an afterthought.

### 5.6 Feedback & haptics
Success feedback is **tactile and definitive** — a soft settle (`ease.settle`) plus, optionally, a single gentle haptic for "kept." Haptics are rare and meaningful; never chatter.

---

## 6. Component philosophy

### 6.1 Compose and theme; don't reinvent
Prefer **standard Material 3 components themed globally** through our tokens. A bespoke widget must justify itself against maintainability + simplicity. The **turtle shell menu is the sanctioned exception** — a brand-critical custom interaction. Almost nothing else should be.

### 6.2 Every component defines its calm states
No component ships without deciding its **empty, loading, and error** presentation, each obeying the manifesto:
- **Empty:** calm potential, an open door — never an accusation.
- **Loading:** quiet and brief; prefer subtle placeholders over spinners where possible.
- **Error:** reassures first ("nothing was lost"), never alarms, never uses raw `error` red gratuitously, never exposes technical detail.

### 6.3 Restraint defaults
- Fewer borders and dividers — use **space** to separate, not lines.
- Low elevation, soft or no shadow.
- One primary action per screen; secondary actions recede.
- Buttons: filled/tonal for the single primary action; text/outline for the rest.

### 6.4 Feedback is definitive, never celebratory
Saves feel like a drawer closing softly (`kept` token + `ease.settle` + optional haptic). No confetti, no toast spam. Confirmation is quiet and unmistakable.

### 6.5 Accessibility is a component requirement
- Touch targets ≥ 48dp.
- Full dynamic-type support; no truncation of essential text.
- AA contrast on every state.
- Every interactive element has a semantic label for screen readers.
- Any signature/animated interaction has a **calm linear fallback** (accessible list of the same actions).

---

## Design System Principles (summary)

1. **One seed, one type family, one spacing unit** — systematic and calm by construction.
2. **Semantic tokens only in features; raw values only in the theme layer.**
3. **Adopt Material 3, then subtract** toward restraint.
4. **Space is the primary tool for calm** — more whitespace, fewer lines.
5. **Color never shouts; red is quarantined for genuine failure.**
6. **The hexagon is a motif, not a mandatory shape.**
7. **Motion is slow, natural reassurance — always interruptible, always reduce-motion-safe.**
8. **Feedback is tactile and definitive, never celebratory.**
9. **Bundled, offline, private** — no design asset touches the network.
10. **Every token degrades gracefully** under dynamic type, high contrast, and reduced motion.

---

*Next step after approval: encode these tokens into the Flutter theme (`ThemeData` + a `ThemeExtension` for the brand-semantic tokens) as a small, self-contained milestone — no product features attached.*
