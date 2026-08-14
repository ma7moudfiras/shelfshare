# Research Notes — Inputs for the Next Report Revision

Working notes accumulated after the original Field Training Report
(`content_en.py` / `content_ar.py`) was written. Purpose: durable storage for
anything worth folding into a report/paper revision, so nothing is lost when
this conversation's context is summarized or ends. Not polished prose — raw
findings, numbers, and decisions, dated, to be written up properly later.

Update this file whenever a new report-relevant finding, number, or decision
comes up. Keep entries factual and sourced (which Roboflow project/version/
training id, which commit) so they can be verified again later.

---

## 1. Corrected architecture comparison: brand-classed vs. class-agnostic detector

**Do not use `aystro-project` v1/v2 for this comparison** — those are tiny
early iterations (27 and 49 images) from the first day of the project.
`aystro-project` actually has **20 versions**; v20 (1191 images, trained
2026-08-10) is the mature, representative state of the original brand-classed
approach, and — importantly — uses the same `rfdetr-large` architecture as
the current production detector, making it the fair comparison point.

| | `aystro-project` v20 (brand-classed, 6 classes) | `aystro-project-v2` v2 (class-agnostic, "product") |
|---|---|---|
| Images | 1191 | 384 (augmented; 226 raw images in the project) |
| Architecture | rfdetr-large | rfdetr-large |
| mAP50 | 86.92% | **89.3%** |
| Precision | 82.7% | **90.5%** |
| Recall | **85.8%** | 81.1% |
| Training | `f740b2bbd9a2408bb723`, finished 2026-08-10 | `1dd65f92c4474729e244`, finished 2026-08-11 |

**Honest framing**: the class-agnostic architecture reaches higher mAP50 and
precision with roughly **a third of the training data** — a real
data-efficiency argument. Recall is slightly *lower* (81.1% vs 85.8%),
which should not be hidden. Likely explanation: `aystro-project-v2` (the
class-agnostic project) currently holds only 226-227 raw images total, while
the original `aystro-project` had grown to 1191 annotated images by v20 —
**roughly 800 already-annotated images were never migrated/relabeled into the
class-agnostic project.** This is a concrete, actionable follow-up: migrating
the remaining images would very plausibly close or reverse the recall gap,
and is cheap (programmatic relabel to a single "product" class, no new
annotation work) compared to collecting new imagery.

For context, also on record (both brand-classed, both superseded, kept for
the historical progression narrative only — not the comparison to lead with):
- `aystro-project` v1 (27 images, rfdetr-small): mAP50 77.95%, precision
  96.2%, recall 73.5%.
- `aystro-project` v2 (49 images, rfdetr-small): mAP50 57.78%, precision 80%,
  recall 50% — *worse* than v1 despite more data, an early real illustration
  of the per-class data starvation problem the report argues from statistics
  alone.

## 2. Classifier accuracy — not yet measured, real gap

Roboflow recorded no `metrics` (null) on the finished classification
trainings for either `aystro-brand-classifier` v1 (Stage 2, brand) or
`test-aystro-brand-classifier` v4 (Stage 3, Fanta flavor) — `model_evals_list`
returns empty for both, workspace-wide and project-scoped. Detection training
runs populate `map50`/`precision`/`recall` automatically; classification runs
apparently need an explicit "Evaluate" step that hasn't been run yet (either
via the Roboflow UI or an MCP eval-trigger path not yet identified).

**Action needed before the report can state classifier accuracy**: run that
evaluation for both classifiers (and later the packaging-material classifier
once trained). Do not state a classifier accuracy number in the report until
this is done — there is currently no real number to cite.

## 3. Training / compute cost ("hardware cost") — real numbers, from Roboflow's own rate card

Rate (roboflow.com/credits, confirmed via the `plans-and-pricing` skill,
not guessed): **1 credit = 30 minutes of GPU training**. Computed from actual
training start/end timestamps:

| Model | Training time | Credits |
|---|---|---|
| `aystro-project` v1 (original, first-ever model) | 11.2 min | 0.37 |
| `aystro-project` v2 | 10.2 min | 0.34 |
| `aystro-project-v2` v2 (current production detector) | 44.2 min | 1.48 |
| `aystro-brand-classifier` v1 (Stage 2) | 9.1 min | 0.30 |
| `test-aystro-brand-classifier` v4 (Stage 3, Fanta) | 7.2 min | 0.24 |

Current active 3-model production stack (detector + brand classifier + Fanta
flavor classifier): **~2.0 credits (~60 minutes) total training cost**, ever.
All-time total across every training run including obsolete iterations: ~2.7
credits (~82 minutes). Both are a small fraction of even the cheapest paid
plan's monthly allowance (Core: 50 credits/month) — **the multi-layer
architecture has not introduced a meaningful training/compute cost increase**
over the original single-model approach, while accuracy improved
substantially. Do not state a dollar figure — Roboflow's own guidance is to
always point to `roboflow.com/pricing` / `app.roboflow.com/{workspace}/settings/usage`
for current dollar pricing rather than guess.

**Ongoing inference cost — flagged but not yet measured**: the current
pipeline runs 1 detection call + up to 2 classification calls *per detected
product*, not per photo (a photo with 20 products triggers up to 40
classification calls it previously didn't). This is a real scaling-cost
consideration for the investor-facing framing and should be measured (actual
credit consumption per live workflow run) before being stated quantitatively.

## 4. Marginal cost of scaling — qualitative, evidence-backed from this project's own history

- **New company/tenant**: zero code/model change. The Supabase schema is
  multi-tenant by design (`company_id` + RLS on every table) — adding a
  company is a data operation, not an engineering one.
- **New SKU/flavor within an existing brand**: demonstrated directly by the
  Fanta flavor classifier build (Stage 3) — no detector or Stage-2
  brand-classifier retraining required; just label a few hundred existing
  crops by flavor and train one small classifier, wired in as a parallel
  workflow step. Took hours, not weeks.
- **New packaging type**: the packaging-material experiment (glass/plastic/can,
  in progress — see §5) is built as ONE shared classifier across all brands,
  specifically because material is brand-independent — a new brand
  automatically benefits from the existing packaging classifier with no
  retraining.
- **Entirely new product category**: the class-agnostic Stage-1 detector
  would still find it (generic "product" detection), but a new classifier
  would be needed to identify it specifically.

## 5. Packaging-material classifier experiment (glass/plastic/can) — in progress

New signal, not present in the original report at all (the report only ever
covered packaging *format* via box-aspect-ratio geometry, never packaging
*material* via a trained classifier).

- Visual audit of all ~1608 existing brand-classifier crops (contact-sheet
  method, sorted by aspect ratio per brand) found **only 2 genuine glass
  examples** (both Coca-Cola) out of 1608 — far too few to be a trainable
  class. **Decision: shipped as a 2-class experiment (plastic vs. can)**,
  the 2 glass images set aside, not force-labeled into either bucket.
- Final label distribution: 860 plastic / 746 can (1606 total) — reasonably
  balanced.
- New project: `test-aystro-packaging-classifier`. Upload done (1606 images).
  Labeling in progress (paused mid-way by request; ~136/1606 labeled as of
  last check). Not yet trained or evaluated.
- Per-brand material observations from the audit (useful color for the
  report's discussion of packaging diversity): Cappy is uniformly plastic;
  XL Energy is uniformly can; Sprite and Pepsi split cleanly into a
  low-aspect-ratio plastic-bottle cluster and a high-aspect-ratio can cluster;
  Fanta and Coca-Cola have messier, less clean-cut plastic/can boundaries in
  the aspect-ratio sort (more manual judgment calls needed there).

## 6. Real engineering incidents since the original report — worth citing as evidence of rigor

- **Production bug found and fixed**: a custom Roboflow Workflow Python block
  (`MergeBrandClasses`) called `list(some_string)` on what turned out to be a
  per-crop *scalar* string (not a list), silently exploding class names into
  individual characters — the live app displayed single letters ("c", "f",
  "s") instead of full class names. Diagnosed from a user-supplied screenshot,
  root-caused, fixed, and verified live against a real shelf photo within the
  same session. A concrete illustration of "verify against real data, not
  just training-time metrics" — the training metrics for that pipeline were
  fine; the bug was purely in a downstream data-merging step no offline
  evaluation would have caught.
- **Geometric packaging-format rule (`CanShapeRule`, the aspect-ratio
  slim/standard heuristic central to Sections 6-7 of the original report)
  proved unreliable enough in practice that it has been suspended in
  production** (as of this session) pending a more accurate approach — the
  code, tests, and class are intentionally left intact for later refinement,
  not deleted. This is a direct, honest update to the original report's
  framing of that rule as a validated, resolved solution: it worked on the
  specific measured example in Section 6, but did not generalize reliably
  enough for production use. Worth stating plainly in the revision rather
  than quietly dropping.
- **Data-quality findings from direct audit, more granular than the
  original report's aggregate "42.1% flagged difficult" statistic**:
  - One image mislabeled as `coca-cola` was actually a different, unrelated
    product ("Chat Cola") — no direct per-image delete API existed on the
    platform, so it was relabeled to a flagged tag `review-not-coca-cola`
    as a workaround. This tag then leaked into the app's product filter UI
    (it read every tag ever applied to any project image, not just real
    predictable classes) and has since been fixed with a client/server-side
    filter (`review-` prefix excluded).
  - Fanta flavor data is real but imbalanced: fanta-orange 212, fanta-grape
    27, fanta-redapple 60 (out of ~300) — grape is thin.
  - Coca-Cola flavor data, on direct visual audit, turned out to be almost
    entirely homogeneous "classic" — essentially no real flavor diversity
    (Zero/Diet/etc.) currently exists in the captured data, so the
    Coca-Cola flavor classifier project was seeded but left as a single
    class pending genuinely diverse new photos, rather than forcing a
    flavor split the data doesn't support.

## 7. App scope has grown well beyond the original report's Section 10 description

Since the report was written: a Submissions history section and a
brand → variant Share-of-Shelf percentage report were added to the Market
Detail admin screen (previously captured data was written to Supabase but
never read back anywhere in the app); a "shot from too far away" capture
warning was upgraded from an easy-to-miss SnackBar to a blocking popup
dialog. These are real, shipped deliverables beyond what Section 10
describes and should be reflected in an updated "Field Data Collection
Application" section.

---

*Log new findings below this line, newest first, with a date and enough
context to write up later.*
