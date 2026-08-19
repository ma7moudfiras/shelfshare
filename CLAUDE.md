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

As of 2026-08-17 the `test-` prefix was dropped from every project/workflow
that reached production quality. **Old names below are historical** —
useful for reading old commits/docs, not for new work.

- `aystro-project` — the **original**, brand-classed detector (6 classes:
  coca-cola, fanta, sprite, pepsi, cappy, xl_energy). Has many versions (20+);
  **v20 (1191 images, rfdetr-large) is the mature/representative one**, not
  v1/v2 (tiny early iterations from day one). Superseded but kept for the
  historical comparison. Never had a `test-` prefix.
- `aystro-project-v2` — the **current production** detector: class-agnostic,
  single "product" class. Only 226-227 raw images currently — a real gap,
  since `aystro-project` has ~1191 annotated images that were never migrated
  over. v2 is the trained/production version. Never had a `test-` prefix,
  and was **not** renamed on 2026-08-17 — don't confuse it with the next one.
- `aystro-product-detector` (renamed from `test-aystro-project-v2`) — a
  **separate experimental copy** of the detector, similar but not identical
  data (228 images vs. `aystro-project-v2`'s 227). Confusingly close in name
  to the actual production detector above; it is **not** used by the live
  workflow. Check which one you mean before touching either.
- `aystro-brand-classifier` — Stage 2, brand classification (all 6 brands +
  a small `chat` class for a previously-mislabeled product). Never had a
  `test-` prefix.
- `aystro-fanta-classifier` (renamed from `test-aystro-brand-classifier`) —
  Stage 3, Fanta-flavor-only (fanta-orange/fanta-grape/fanta-redapple). The
  old name was misleading (sounds like a general brand classifier; it never
  was one) — that's *why* it got renamed. **Live model is version 5**, not 4:
  v4 had a bogus `"Unlabeled"` class baked in (311 real, unannotated Fanta
  photos swept into training as a fake class at some earlier version
  generation), which the eval data shows scored a clean 100%/100% at a 0.91
  threshold — i.e. it was a coherent, confidently-learned wrong pattern, not
  noise, which is exactly why it silently misclassified real Fanta crops at
  ~98% confidence in production instead of failing loud. Fixed 2026-08-18 by
  regenerating a clean version (`versions_generate`) and retraining — no
  relabeling needed, the underlying 299 annotated images were already
  correct. If a project's `versions_export` ever shows a `colors`/class
  entry you don't recognize, check whether it's genuinely orphaned
  unannotated data before trusting the version.
- `aystro-coca-classifier` (renamed from `test-aystro-coca-classifier`) —
  Coca-Cola variant classifier (coca-classic/coca-zero/coca-diet). Was an
  untrained single-class placeholder for most of this project's history and
  blocked on training credits when API-driven training was tried; the user
  trained it directly in the Roboflow UI as version 1 (780 images after
  augmentation, from 300 annotated: classic 250 / zero 40 / diet 10) and it
  was wired into the live workflow 2026-08-18. Real eval (see
  `docs/report/RESEARCH_NOTES.md`, "Real Roboflow evaluations" entry):
  classic 100%/100%, zero 100%/67%, diet a clean 0%/0% — diet's 10-image
  seed just isn't enough data yet; tracked as a live, quantified data gap,
  not a wiring or credits problem anymore.
- `aystro-cappy-classifier` — Cappy flavor classifier (12 flavor classes —
  apple/cherry/grape/grapefruit/lemon/mango/mix/orange/peach/pomegranate/
  strawberry/tamarind; check `projects_get` for the live set). Trained and
  wired into the live workflow. Real eval: overall precision 56% / recall
  52%, the weakest classifier in the pipeline — six of the twelve flavors
  have only 0-4 ground-truth instances in the whole dataset. Reads as a
  data-scarcity problem, not a modeling one (see RESEARCH_NOTES.md).
- `aystro-packaging-classifie` (renamed from `test-aystro-packaging-classifier`
  — **note the missing trailing "r", that's the actual live slug, not a typo
  to "fix"**) — material classifier (can/glass/plastic). Trained **and
  wired into the live workflow** as the unconditional `packaging` step
  (every crop, not `switch_case`-gated like the brand/variant classifiers,
  since packaging material doesn't depend on brand). Real eval: can/plastic
  strong (~93-98%), glass 100% precision but only 33% recall off just 3
  ground-truth test instances — a real, quantified data gap.
- `aystro-xl-classifier` (renamed from `test-aystro-xlenergy-classifier`) —
  XL Energy variant classifier. Live class set as of the 2026-08-18 eval:
  xl-classic/xl-red/xl-sugarfree/xl-mojito/xl-doublekick — the class list
  has changed more than once before this; check `projects_get` for the live
  set before assuming, not this file. Trained and wired into the live
  workflow; xl-classic/xl-red/xl-sugarfree score perfectly, xl-doublekick/
  xl-mojito have zero ground-truth test support (thin classes, blocked on
  field photography, see `docs/report/ROADMAP_FULL_SKU.md`).

**Gotcha confirmed 2026-08-17, costly to rediscover**: renaming a Roboflow
project does **not** carry the rename through to any model already trained
in it. The model artifact's own id is generated at training time from the
project name *then*, e.g. `test-aystro-brand-classifier-4-vit-base-patch16-
224-in21k-t1` — after the project became `aystro-fanta-classifier`, calling
that model as `aystro-fanta-classifier/4` (the natural post-rename
reference) 404s at the serving layer, even though `projects_get`/
`versions_get` show the version as `ready: true` with a `finished` training.
The model is not deleted or corrupted — `models_get` on its exact old
generated name still resolves it — but Workflow classification steps only
accept the `project_id/version_number` shape, not a bare model name, so
there is no way to reference the orphaned model from a Workflow at all.
**The only fix is retraining** (`trainings_create` on the existing version —
no relabeling needed if the version's data is already correct). Any project
renamed here needs its trained versions re-trained before they're usable
again; check this before wiring a "should already be trained" model into a
Workflow.

- The live workflow is `aystro-detect-classify` (renamed from
  `test-aystro-detect-classify-brand`; Roboflow Workflow id
  `eeUDKKw0KlOkitKXDmCX`) — class-agnostic detect (`aystro-project-v2`) →
  crop → brand classify (`aystro-brand-classifier`) → four
  **`switch_case`-gated** variant branches, one per brand with a trained
  variant classifier: `fanta` → `aystro-fanta-classifier`, `xl_energy` →
  `aystro-xl-classifier`, `cappy` → `aystro-cappy-classifier`, `coca-cola` →
  `aystro-coca-classifier` (added 2026-08-18) → all four plus the plain
  brand prediction feed `roboflow_core/first_non_empty_or_default@v1`
  (first non-empty wins, so a variant overrides its brand-level guess, and
  the plain brand is the fallback when no variant classifier fired) → write
  back onto the detection. The old custom `MergeBrandClasses` Python-block
  architecture (mentioned in old commits) was replaced by this `switch_case`
  + `first_non_empty_or_default` pattern on 2026-08-16 — see
  `docs/report/ROADMAP_FULL_SKU.md` Phase 3.5 for why (it turns O(N×K)
  classifier calls into true O(N)). After the class is finalized, an
  unconditional `packaging` step (`aystro-packaging-classifie`) runs on
  every crop regardless of brand and its result is exposed as a separate
  `packaging_predictions` output, merged onto each `Detection.packaging` in
  the app rather than into the class name.
  Every classifier step in this workflow (brand, all four variants,
  packaging) is called with `confidence_mode: "custom", custom_confidence:
  0` — without this, Roboflow's own default confidence threshold silently
  drops a classifier's prediction entirely (empty string) whenever it's
  below that threshold, which is a *worse* failure mode than a low-confidence
  guess: the app has no confidence number to show or gate on. Forcing
  `custom_confidence: 0` makes every classifier always return its top-1
  guess, however weak, and lets the app's own (lower) confidence threshold
  decide what to show.
  Active-learning upload sinks exist for all four variant branches plus
  packaging, and as of 2026-08-18 gate on **route membership**
  (`extract_X.output != ""`), not classifier confidence, sampling 100% of
  every crop that reaches that branch. The earlier design gated on
  `top_class_confidence < 0.75`, which structurally can never catch a
  *confidently wrong* prediction — exactly the failure mode of the
  "Unlabeled" bug in the Fanta bullet above — so it was dropped in favor of
  unconditional upload-when-routed.
  **Real, non-invented eval numbers exist for every model in this pipeline**
  as of 2026-08-18 (Roboflow's Evaluate feature, run once a free-trial top-up
  restored inference/training credits) — see the "Real Roboflow evaluations"
  entry in `docs/report/RESEARCH_NOTES.md` before quoting any accuracy
  number in the report; don't estimate, it's all there now.
  **Second gotcha, also costly**: the *old* slug
  `test-aystro-detect-classify-brand` was **not freed by the rename** — a
  different, older, unmaintained workflow already occupied it and still
  does. It has no Fanta routing and returns a differently-shaped
  `brand_predictions` (full prediction objects, not a flat string list). Any
  code/docs/env var pointing at `...-brand` (with `-brand`) is pointing at
  the wrong, stale pipeline — always use `aystro-detect-classify` (no
  `-brand`) for the real one. This exact confusion broke the app's
  `ROBOFLOW_WORKFLOW_ID` default in production until caught and fixed
  2026-08-17 — see `docs/report/RESEARCH_NOTES.md`.
- **Gotcha from before the rename, still true**: custom Python blocks
  receive per-crop inputs as plain **scalars**, not lists — `list(some_string)`
  silently explodes a class name into characters. Never assume list-wrapping
  without checking live output first (`workflows_run` against a real photo).
  No longer hit in the live workflow (no custom blocks remain in it after
  the Phase 3.5 rework above), but still a real platform behavior to watch
  for in any future custom block.

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
