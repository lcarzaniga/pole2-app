# Project Kobe — Domain Model & Persistence Schema

*Status: Frozen proposal — pending final acknowledgement. Companion to `BRAND_UX_MANIFESTO.md` and `DESIGN_SYSTEM.md`. Defines Kobe's core domain: principles, concepts, then the Drift schema. No CRUD, no repository layer, no Flutter here.*

*Approved decisions carried in: Evidence↔Possession is many-to-many; Events are one unified, extensible model; identity is a first-class **Identifier**; descriptive facts are a first-class **Attribute**; and — new — protected facts are a first-class **Secret**, deliberately not persisted until it can be protected.*

---

## 1. Domain Principles

*Read these five minutes first. They are what Kobe fundamentally is — before any table or widget.*

1. **Kobe preserves the record *about* a thing, not the thing.** The record is the product, and it deliberately **outlives the object**.
2. **The Possession is a thin anchor; the story around it is the value.** Only a `title` is ever required. Everything else is added over time, never demanded.
3. **Never block preserving anything.** Emotionally Kobe is about *the things worth being ready about*; technically it must hold *anything* a person cares about.
4. **Three questions describe a thing:** *What identifies it?* (**Identifier**) · *What do I want to remember?* (**Attribute**) · *What must stay hidden but safe?* (**Secret**). Same subject, three different intents.
5. **Evidence proves, Events narrate, Parties connect.** Documents are proof; the timeline is the story; people and organisations are shared across things.
6. **Losing the object is a lifecycle state, not a deletion.** We archive, transfer, or dispose — the record persists. We almost never destroy it.
7. **Retrieval is the whole point.** Every concept exists so the user can *act with confidence at the moment of need*. If it doesn't help someone find or prove something later, question it.
8. **Protection is structural, never a checkbox.** Secrets are hidden by default and impossible to leak by accident; everything else is visible by default.
9. **Model reality, not the convenient lie.** Receipts belong to many things, objects have many identifiers, records outlive objects — the model tells the truth even when a flatter shape would be easier.

---

## 2. The governing constraint

Emotionally, Kobe is about **the things worth being ready about**. Technically, it must **never prevent** a user from preserving anything.

- **A Possession requires only a `title`.** Everything else is optional.
- Nothing forces a category, purchase, date, party, identifier, or document.
- The model is **additive** (progressive enrichment), never gated.

---

## 3. Concepts (technology-independent)

### 3.1 Possession — the anchor
**The record of a thing the user chose to remember** — the tab on the dossier. Not the physical object; the record *about* it, which outlives it. Thin identity (`title`; optional `category`, `notes`, cover, `status`). A **lens, not a container**. Mutable and long-lived. Price/supplier/warranty/service do **not** live here (→ Events/Evidence); nor do identifiers, facts, or secrets (→ their own concepts).

### 3.2 Evidence — proof & knowledge artifacts
**A captured artifact that proves or informs:** receipt, invoice, manual, warranty certificate, photo, label. Backed by a **File** (§3.9); content is **immutable**. Has a `kind` and optional `label`. **Belongs to one *or many* Possessions** (§3.10).

### 3.3 Event — the timeline
**Something that happened, or will happen, anchored in time:** acquired, serviced, repaired, note, reminder, warranty period, transfer, disposal, lost, custom. Carries `at` and optional `endsAt` (so one Event expresses an **interval**, e.g. a warranty). Optional `amount`/`currency`, `party`, `evidence`, and `status` for actionable events. **Extensible:** `kind` is stored by name and includes `custom`, so user-defined types need no schema change.

### 3.4 Party — people & organisations
Reusable **person or organization** (retailer, manufacturer, repairer, insurer, person). Referenced *by Events*, not owned by a Possession.

### 3.5 Identifier — *"What uniquely identifies this?"*
A **typed value that names the physical unit:** Serial, IMEI, VIN, MAC, Asset Tag, Registration, … It has *identity behaviour* — you search by it, prove ownership, quote it in claims and theft reports. A Possession has **zero-or-more** (a car has VIN *and* plate). `kind` is extensible with `other` + free `label`. **Never secret** — identifiers *name* the object (semi-public, often printed on it).

### 3.6 Attribute — *"What do I want to remember?"*
A **named, visible, descriptive fact:** colour, dimensions, room, material, capacity, number of keys. `label` + `value` + optional `valueType` (text / number / date / dimension). Zero-or-more per Possession. Retrieving these instantly *is* anxiety reduction — the mission in miniature. **Descriptive only** — visible by default. Anything that must be hidden is a Secret, not an Attribute.

### 3.7 Secret — *"What must stay hidden but kept safe?"* (first-class; not yet persisted)
A **protected fact whose resting state is hidden:** Wi-Fi password, lock combination, safe PIN, product key, alarm code. A first-class concept — **not** an Attribute with a flag — because its default is inverted (hide-by-default) and its invariants are safety-critical.

**Behaviour contract (the reason it's its own concept):**
- Hidden by default; revealed only by a **deliberate, authenticated** action (biometric / passcode).
- **Masked** display; **copy** with an **auto-clearing clipboard** timeout.
- **Encrypted at rest**; value **never logged**.
- **Excluded** from list previews, search snippets, exports, backups, and (future) screenshots.
- In code, a distinct type with **no plaintext accessor by default** — leaking one should be a *type error*, not a missed check.

**Why it is deliberately absent from the MVP schema — structural safety by omission:** because these invariants can't yet be honoured (no encryption layer), Kobe provides **no place to store a secret at all**. If no column can hold a secret, none can be leaked in plaintext. Secret's persistence (OS secure storage or an encrypted table) is designed **with** the encryption milestone, never before. Until then the concept is documented and the UI offers descriptive Attributes only.

*(This replaces the earlier `sensitive` flag on Attribute, which was a boolean trap: it required every render/export/log path to remember to protect the value. Removed.)*

### 3.8 Evidence ↔ Possession is many-to-many — **approved.**
One receipt covers five items; one manual a matched set. Each Possession still gets its own "Acquired" Event, all pointing at the same shared receipt — so "one purchase, many things" needs no many-to-many Events.

### 3.9 File — the on-disk asset (supporting concept)
Bytes never enter the database. A **File** is metadata: portable relative path, mime, size, `sha256` (integrity / dedup / sync). Immutable content; garbage-collected when unreferenced (§5).

### 3.10 What survives after the object is gone? — **Almost everything.** The object leaving is a **status change, not a deletion.** The dossier persists, because its value is proof and history *after the fact*.

### 3.11 Grouping — deferred. Sets / rooms / house — a soft many-to-many lens, not in MVP. ("Room" can start as an Attribute.)

---

## 4. Lifecycle: archive / transfer / disposal are first-class — **Yes.**

| Status | Meaning |
|---|---|
| `active` | Owned, in use. Default. |
| `archived` | Kept but set aside — retained on purpose. |
| `transferred` | Sold/gifted — ownership left, record retained and handover-able. |
| `lost` | Lost/stolen — record retained (insurance/police proof). |
| `disposed` | Discarded/destroyed — record retained as history/proof. |

Status is *current state*; a matching **Event** records *when & why*. **`status` ≠ deletion** (real deletion is soft delete, §5).

---

## 5. Persistence principles → requirements

- **Offline-first / no lock-in:** local SQLite via Drift; portable data.
- **Cloud sync without redesign:** every domain row has a **client-generated UUID primary key** (makes offline merge possible), `createdAt`, `updatedAt`, and soft-delete tombstones. Dates as **ISO-8601 UTC text**. Files carry `sha256`. A sync layer is an *additive* later step.
- **Migrations from day one:** `schemaVersion` 1 → 2; explicit `onUpgrade`; `PRAGMA foreign_keys = ON`; tested schema snapshots.
- **Soft delete only where it makes sense:** on **Possession, Evidence, Event, Party, Identifier, Attribute**. **Files: hard delete via GC** when unreferenced. **Link table: hard delete** (link tombstones noted as future sync work).
- **Files outside SQLite:** only metadata stored; bytes under the app documents dir via **relative** path.
- **Secrets:** no plaintext store exists; Secret persistence is designed with the encryption milestone (§3.7).
- **Reactive by default:** DAOs expose Drift `Stream`s. **No repository layer.**
- **Feature-first architecture unchanged:** tables in `core/database`; features go through DAOs.

---

## 6. Drift schema (frozen proposal — 8 tables)

Enums (stored by **name** via `textEnum`; additively extensible):

```dart
enum PossessionStatus { active, archived, transferred, lost, disposed }
enum EvidenceKind { receipt, invoice, manual, warrantyCard, photo, label, other }
enum EventKind { acquired, note, service, repair, reminder, warranty, transfer, disposal, lost, custom }
enum EventStatus { pending, done, dismissed } // actionable events only
enum PartyKind { retailer, manufacturer, repairer, insurer, person, other }
enum IdentifierKind { serialNumber, imei, vin, macAddress, assetTag, registration, other }
enum AttributeValueType { text, number, date, dimension }
// NOTE: no Secret table/enum yet — Secret is first-class but unpersisted until encryption (§3.7).
```

Tables (UUID text PKs; dates as UTC text; nullable = optional):

```dart
// On-disk asset registry. Bytes live under the app documents dir.
class Files extends Table {
  TextColumn get id => text()();
  TextColumn get relativePath => text()();
  TextColumn get mimeType => text()();
  IntColumn  get byteSize => integer()();
  TextColumn get sha256 => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column> get primaryKey => {id};   // no soft delete: GC when unreferenced
}

// The anchor. Only `title` is required.
class Possessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status =>
      textEnum<PossessionStatus>().withDefault(const Constant('active'))();
  TextColumn get coverFileId => text().nullable().references(Files, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override Set<Column> get primaryKey => {id};
}

// "What uniquely identifies this?" — serial, VIN, IMEI, MAC, …
class Identifiers extends Table {
  TextColumn get id => text()();
  TextColumn get possessionId => text().references(Possessions, #id)();
  TextColumn get kind => textEnum<IdentifierKind>()();
  TextColumn get label => text().nullable()();     // custom type name when kind == other
  TextColumn get value => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override Set<Column> get primaryKey => {id};
}

// "What do I want to remember?" — descriptive, visible facts only. No secrets.
class Attributes extends Table {
  TextColumn get id => text()();
  TextColumn get possessionId => text().references(Possessions, #id)();
  TextColumn get label => text()();                 // "Colour", "Room", "Dimensions"
  TextColumn get value => text()();
  TextColumn get valueType => textEnum<AttributeValueType>().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override Set<Column> get primaryKey => {id};
}

// A captured artifact, backed by a File.
class EvidenceItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<EvidenceKind>()();
  TextColumn get label => text().nullable()();
  TextColumn get fileId => text().nullable().references(Files, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override Set<Column> get primaryKey => {id};
}

// M:N link — one receipt can belong to many possessions.
class PossessionEvidence extends Table {
  TextColumn get possessionId => text().references(Possessions, #id)();
  TextColumn get evidenceId => text().references(EvidenceItems, #id)();
  DateTimeColumn get addedAt => dateTime()();
  @override Set<Column> get primaryKey => {possessionId, evidenceId};
}

// The timeline atom: past events, reminders, and intervals (warranty).
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get possessionId => text().references(Possessions, #id)();
  TextColumn get kind => textEnum<EventKind>()();
  DateTimeColumn get at => dateTime()();
  DateTimeColumn get endsAt => dateTime().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn  get amountMinor => integer().nullable()();
  TextColumn get currency => text().nullable()();
  TextColumn get partyId => text().nullable().references(Parties, #id)();
  TextColumn get evidenceId => text().nullable().references(EvidenceItems, #id)();
  TextColumn get status => textEnum<EventStatus>().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override Set<Column> get primaryKey => {id};
}

// People/orgs, reusable across events.
class Parties extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => textEnum<PartyKind>().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override Set<Column> get primaryKey => {id};
}
```

Supporting details:
- **DB option:** `storeDateTimeAsText: true` (ISO-8601 UTC).
- **Indexes:** `identifiers.possessionId`, `attributes.possessionId`, `events.possessionId`, `events.partyId`, `events.at`, `evidenceItems.fileId`, `possessions.coverFileId`, `possessions.status`.
- **Migration:** `schemaVersion` 1 → 2; `onUpgrade` creates all eight tables; keep a v1→v2 snapshot test.

**Maps cleanly to the five quick-actions:** New Possession → `Possession`; Add Document / Scan → `Evidence` (+`File`); Reminder → `Event(reminder, pending)`; Note → `Event(note)`. Identifiers/Attributes are progressive enrichment on the detail screen.

---

## 7. Challenging my own model

**• Most likely wrong in two years → the unified `Events` table.** It will strain (recurring reminders, structured warranty terms/claims, maintenance schedules); expect **Reminder** and **Warranty/Coverage** promoted later — additive, not a redesign. Secondary risk: the Identifier / Attribute / Secret trio could blur at the edges (is a Wi-Fi password ever "just a note"? is an asset tag an identifier or an attribute?).

**• Deliberate MVP simplifications.** **Secret is designed but unpersisted** (gated on encryption); Grouping deferred; UI may expose one Identifier though the model stores many; Attribute `valueType` is a light hint; no ordering on Identifier/Attribute; one File per Evidence; no reminder recurrence; Event→Evidence is a single optional link.

**• What a senior peer would dispute.** "Just keep a sensitive Attribute flag — a separate Secret concept is over-thought" (I rejected this: boolean trap + inverted default). "Ship a Secret store now, don't defer" (needs the encryption story first). "Merge Identifier and Attribute" (I split for clarity). "Evidence M:N is premature." "Make Warranty/Reminder first-class now." "UUID PKs hurt local perf." "Go full event-sourcing."

---

*Next step after final acknowledgement: encode the eight tables + enums under `core/database/tables/`, bump the schema to v2 with a tested migration, and wire reactive DAOs — no repository layer, no feature CRUD. Secret persistence is explicitly out of scope until the encryption milestone.*
