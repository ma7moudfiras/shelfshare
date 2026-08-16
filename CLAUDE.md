# shelfshare / Aystro Shelf Monitor

Flutter app + Roboflow computer-vision pipeline for automated retail shelf
auditing: a rep photographs a fridge/shelf, the pipeline detects and
classifies every product, the rep reviews/corrects, and the result is stored
for share-of-shelf reporting.

## Where things live

- **App code**: `lib/` (Flutter/Dart). `lib/services/` for Roboflow/Supabase
  API clients, `lib/models/` for data types, `lib/screens/` + `lib/widgets/`
  for UI, `api/` for the Vercel serverless proxy (`api/models.js` etc. — used
  so the browser build never needs the Roboflow key client-side).
- **Backend**: Supabase project `shelfshare` (id `dpviepymbxaibmeppylj`).
  Multi-tenant by design: every table carries `company_id` + RLS. Core
  tables: `companies`, `profiles` (role: `platform_admin`/`company_admin`/
  `sales_rep`/`pending`), `points_of_sale` ("markets" in the UI), `fridges`,
  `fridge_sections`, `visits`, `captures`, `detections`.
- **ML pipeline**: entirely on Roboflow (workspace `ma7mouds-workspace`), not
  in this repo. See naming convention below.
- **Report / research writeup**: `docs/report/` — `content_en.py` /
  `content_ar.py` hold the Field Training Report content (built via
  `build.py` into `docs/report/out/*.docx`/`.pdf`). **`docs/report/RESEARCH_NOTES.md`
  is a running log of findings/numbers to fold into the next report
  revision — update it whenever something report-worthy happens, so nothing
  is lost across context resets.**

## Roboflow project naming — read this before touching any project

- `aystro-project` — the **original**, brand-classed detector (6 classes:
  coca-cola, fanta, sprite, pepsi, cappy, xl_energy). Has many versions (20+);
  **v20 (1191 images, rfdetr-large) is the mature/representative one**, not
  v1/v2 (tiny early iterations from day one). Superseded but kept for the
  historical comparison.
- `aystro-project-v2` — the **current production** detector: class-agnostic,
  single "product" class. Only 226-227 raw images currently — a real gap,
  since `aystro-project` has ~1191 annotated images that were never migrated
  over. v2 is the trained/production version.
- `aystro-brand-classifier` — Stage 2, brand classification (all 6 brands),
  trained on crops from the detector's boxes.
- A project prefixed **`test-`** (`test-aystro-project-v2`,
  `test-aystro-brand-classifier`, `test-aystro-coca-classifier`,
  `test-aystro-packaging-classifier`) is a **working/experimental copy**,
  not automatically "the test environment" in the software sense — check
  what it actually contains before assuming. E.g. `test-aystro-brand-classifier`
  no longer holds all 6 brands; it was trimmed down to hold **only Fanta
  flavor classes** (fanta-orange/fanta-grape/fanta-redapple) and is Stage 3
  for Fanta specifically.
- The live workflow is `test-aystro-detect-classify-brand` (Roboflow
  Workflow id `eeUDKKw0KlOkitKXDmCX`) — hierarchical: class-agnostic detect →
  crop → brand classify (`aystro-brand-classifier`) → Fanta flavor classify
  in parallel (`test-aystro-brand-classifier`) → a custom Python block
  (`MergeBrandClasses`) picks the flavor label when the brand is Fanta, else
  the plain brand. **Gotcha already hit once**: custom Python blocks receive
  per-crop inputs as plain **scalars**, not lists — `list(some_string)`
  silently explodes a class name into characters. Never assume list-wrapping
  without checking live output first (`workflows_run` against a real photo).

## Established working patterns (reuse these, don't reinvent)

- **Bulk visual labeling of many crops**: build contact-sheet grid images
  (PIL, ~14 cols, index number under each thumbnail) sorted by a cheap
  pre-signal (box aspect ratio clusters material/shape; hue clusters flavor
  color) so a human/Claude can label by *range* instead of one image at a
  time. Then delegate the resulting `{image_id: label}` map to a
  **background general-purpose Agent** to actually make the ~hundreds of
  `annotations_save` calls — keeps the main conversation from drowning in
  tool-call noise. This pattern has been used for Fanta flavors, the
  Coca-Cola seed, and the packaging-material experiment.
- **Never invent numbers for anything investor/owner-facing.** If Roboflow
  hasn't recorded a metric (e.g. classifier `metrics: null` until an
  `Evaluate` step runs), say so explicitly and offer to generate it — don't
  estimate. Same for dollar costs: Roboflow's own guidance is to point to
  `roboflow.com/pricing` rather than guess; credit *counts* can be computed
  from real training timestamps × the published rate (1 credit = 30 min GPU
  training), which is fine to compute directly.
- **When a Roboflow project has no per-image delete API**, the workaround
  used so far is relabeling the bad image to a `review-<reason>` tag rather
  than leaving it wrongly classed. Any such tag must be filtered out of the
  app's class-list UI (see `model_catalog_service.dart` /
  `api/models.js` — both filter names starting with `review-`) since the
  app's "Products" filter reads the Roboflow project's full tag list, not
  the live model's actual predictable classes.

## Commands

```bash
export PATH="$PATH:/opt/flutter/bin"   # flutter isn't on PATH by default here
flutter analyze
flutter test
```

Dev branch: `claude/shelf-monitor-flutter-setup-cih1fb`, tracked by an open
PR. Push there; don't open a second PR for the same branch if one is already
open.

## Things intentionally suspended, not deleted

- `CanShapeRule` (`lib/models/can_shape_rule.dart`, the box-aspect-ratio
  slim/standard-can heuristic): disabled via `RoboflowService(shapeRule: null)`
  at its one construction site in `lib/main.dart` — not accurate enough yet.
  Re-enable by dropping that argument once the logic is improved. Do not
  change the default in `roboflow_service.dart` itself — some tests rely on
  the default firing.
