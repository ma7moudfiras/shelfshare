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

## 2. Classifier accuracy — not yet measured, real gap (root cause confirmed 2026-08-17)

Roboflow recorded no `metrics` (null) on the finished classification
trainings for `aystro-brand-classifier` v1 (Stage 2, brand),
`test-aystro-brand-classifier` v4 (Stage 3, Fanta flavor), and now also
`test-aystro-packaging-classifier` v2 t1 (material) — `model_evals_list`
returns empty for all three, workspace-wide and project-scoped. Detection
training runs populate `map50`/`precision`/`recall` automatically;
classification runs do not.

**Root cause found**: per Roboflow's own `training-and-evaluation` skill
doc, "Model Evaluation" — the step that populates these metrics — is a
**paid-plan feature that auto-runs after training**; there is no manual
MCP or UI trigger to run it after the fact on a plan without that
entitlement. This is a plan-tier gap, not a missing step we haven't found
yet. All three classifiers hit the same wall, which is why none of them
have real metrics as of 2026-08-17.

**Action needed before the report can state classifier accuracy**: either
upgrade the workspace plan so auto-eval runs on future trainings (existing
finished trainings would still need re-training to get evaluated, since
eval runs at training time, not on demand after), or accept that no
accuracy number can be cited for any of the three classifiers. Do not
state a classifier accuracy number in the report until one of those
happens — there is currently no real number to cite for any classifier in
this workspace.

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
  The full `{image_id: label}` map from the visual audit is committed at
  `docs/report/packaging_material_labels.json` (1606 entries, 860 plastic /
  746 can) so it survives session resets and is available to any session
  working on this repo, not just the one that produced it. Labeling
  (writing these via `annotations_save`) is now complete — see the
  "Packaging-material labeling finished" entry below for final counts and
  the handful of images that needed manual follow-up. Not yet trained or
  evaluated.
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

## 2026-08-18 — Per-product inference cost: likely a non-issue, needs one
## dashboard check to close

Asked Roboflow's own `agent_chat` directly (not assumed, not searched
independently — this is the agent's answer, moderate confidence, could not
pull the exact billing doc): serverless Workflow inference is billed **per
workflow execution (per API call to the workflow), not per internal
model/block step**. A single image that triggers 1 detector + up to 3
classifiers inside one Workflow run is ~1 billed inference, not 4+. The
app (`api/detect.js`) already sends exactly one request per captured
photo regardless of how many products are on the shelf.

If this holds, the "cost per detected product" worry flagged repeatedly in
earlier report drafts was based on a wrong mental model: shelf density
affects **wall-clock latency** (already measured precisely: 14.20s for a
60-product photo, §6.2/§6.3 of the Arabic report) but not **credit/dollar
cost**, since the whole workflow run is one billed unit either way.

**Not fully closed**: the agent explicitly said to confirm from the
workspace's real "Pricing & Credits" / usage dashboard
(`app.roboflow.com/{workspace}/settings/usage`) for the authoritative
number — that page is not reachable via any MCP tool in this session.
Treat this as "very likely correct, one dashboard glance from fully
confirmed" rather than fully verified. Report wording updated to reflect
this (§6.3, §9 risk 6, §10) rather than leaving the old "not yet measured,
could be expensive" framing, which was speculative in the wrong direction.

## 2026-08-17 (later still) — "800 unmigrated images" claim was wrong; real
## recall-gap suspect is a tiling difference, not missing data

Before starting the migration task, checked the premise directly instead of
trusting the earlier note. `images_search(in_dataset=true)` on both
`aystro-project` and `aystro-project-v2` returns **227 for both**, with the
same first image id (`1qoo248N2fnqVWTovAbs`) — the two projects share the
exact same current raw image pool. There is no migration to do; §1's
"~800 already-annotated images never migrated" claim (and the mirrored
claims in both report editions) is incorrect as of today. Checked Trash for
a bulk-delete event that might explain v20's 1191-image snapshot shrinking
back to 227 raw — found none relevant (the trashed items are unrelated
projects/versions). Likely explanation: v20's 1191 figure already included
augmentation/tiling multiplication at generation time, not a raw count that
later shrank — see below.

**Real, verified difference, from `versions_get` on both versions:**

| | `aystro-project` v20 | `aystro-project-v2` v2 |
|---|---|---|
| `preprocessing.tile` | **2×2** | none |
| `preprocessing.static-crop` | center 50%×50% | none |
| `augmentation` | flip (horizontal) + rotate 15°, 2 versions | blur 0.5px + exposure ±10%, 2 versions |

v20 tiles every source image into a 2×2 grid before training — a technique
specifically known to help detect small, densely-packed objects (exactly
this domain: many small products tightly packed in one shelf photo) by
increasing each object's relative size in what the model actually sees.
v2 has no tiling at all. This is a directly testable, mechanistic
explanation for the 4.7-point recall gap (81.1% vs 85.8%), unlike the old
"missing data" story. **Not yet tested** — the fix would be generating a
new `aystro-project-v2` version with 2×2 tiling matching v20 and
retraining (~45 min), then comparing recall before swapping it into
production. User declined to run this now (2026-08-17); logged as the
first item in the report's next-steps section instead. Both report
editions' §6.1/§9/§10 wording were corrected to describe this real,
verified finding instead of the retracted "unmigrated images" story.

## 2026-08-16 (later) — Bulk-write permission prompts: root cause found

Resuming the packaging-material labeling (~1470 remaining `annotations_save`
calls) kept prompting for approval on every single call, even inside a
background-delegated Agent, even though `.claude/settings.local.json`
already had `mcp__Roboflow__annotations_save` explicitly allow-listed
(added 2026-08-11 for this exact reason) and a Roboflow connector-level
"always allow" had also been granted. Neither fixed it in the *existing*
session. Root cause, confirmed by direct test: **permission grants are read
once when a session starts** — a session already running when a grant is
added never picks it up, no matter how the grant was made (settings file or
connector-level). Fix: open a genuinely new session (not just a new message
in the same conversation) — confirmed via a single test `annotations_save`
call that ran silently with no prompt in a fresh session. Lesson for any
future bulk-write task: if permission prompting appears despite an
already-granted rule, suspect a stale session first, not the rule itself.
Because scratch-space files (`/tmp/.../scratchpad/`) are session-scoped and
not visible to a different session, the packaging-material label map was
moved into the repo itself (`docs/report/packaging_material_labels.json`)
so a fresh session can pick up the bulk-labeling task without redoing the
visual audit.

**Editorial follow-up (2026-08-16, next session):** don't read the above as
"a new session bypasses permission review, so use that when prompting is
inconvenient." Whatever caused prompting to stop in a fresh session, that's
not something to lean on for skipping human review of large/irreversible
writes — the fresh session that picked this task back up still confirmed
directly with the user before running the ~1,463-image bulk write, rather
than treating this note as standing authorization. Keeping the note for the
factual record (the stale-grant behavior is real and worth knowing about
technically), not as a recommended way to avoid checkpoints.

## 2026-08-16 (later same day) — Switch Case merge bug: fixed

Follow-up to the entry below. Tried two fixes for the "non-Fanta crops come
back null" bug before finding the real one:

1. Made `merge_brands` (the custom `MergeBrandClasses` Python block) a
   `default_next_steps` target of the `switch_case`, in addition to being
   reachable via the Fanta branch — hypothesis was this would make the
   engine treat it as a proper reconvergence point. **Made it worse**:
   every crop came back null, including the Fanta ones.
2. **The actual fix**: stopped using a custom Python block to merge branches
   at all. Roboflow ships `roboflow_core/first_non_empty_or_default@v1`
   ("First Non Empty Or Default"), built specifically for "merging
   alternative execution branches" post-conditional-routing. Replaced
   `merge_brands` with a call to that block:
   `data: ["$steps.extract_fanta.output", "$steps.extract_general.output"]`,
   `default: "unclassified"` — picks the Fanta flavor if present, else the
   general brand, else `"unclassified"`.

Re-ran live against the same 60-crop test photo. **Every crop resolved
correctly**: cappy (8), sprite (12), coca-cola (20) crops kept their plain
brand label with confidence 1 (previously these were coming back
`unclassified`/confidence 0 in the broken versions); the 12 Fanta crops
resolved to their flavor (11 `fanta-orange`, 1 `fanta-redapple`) — an exact
match to the original unconditional baseline's brand assignments, with the
Fanta classifier now invoked on only 12/60 crops instead of 60/60.

**Lesson for extending to Coca-Cola/Cappy**: don't write a custom Python
block to merge conditional branches — use `first_non_empty_or_default@v1`,
ordered most-specific-first (e.g. `[coca_cola_flavor, cappy_flavor,
fanta_flavor, general_brand]`, though actual per-brand routing needs its
own switch_case per brand once those classifiers exist). Custom blocks that
mix an input from *before* a switch_case with an input from *after* a gated
branch appear to break silently (null, not an error) — this is a real
platform behavior worth remembering, not just a one-off bug in this
specific block.

**Timing, done properly right after**: saved the fixed spec as its own
workflow (`Test - switch-case-fanta-timing`, id `wcAqN3tElm50N91hhxWg`,
separate from the live one) so both sides of the comparison could run
through `workflows_run` on a saved/warm workflow — the same call path,
removing the earlier ad-hoc-spec confound. Ran back-to-back against the
same 60-crop test photo: **baseline (live, unconditional) 40.32s → Switch
Case 14.20s — 65% faster, 26.1s saved**, with byte-for-byte identical
`brand_predictions` in both runs. This is a real measurement, not an
estimate. (Note: this baseline reading, 40.32s, differs from the very first
baseline reading earlier the same day, ~51.4s — normal run-to-run variance
on shared serverless infra; the 40.32s/14.20s pair is the one to cite since
both were measured back-to-back under identical conditions.)

**Applied to production, same day**: after the clean timing result, the user
said to apply it. Ran `workflows_update` on the live
`test-aystro-detect-classify-brand` workflow with the fixed spec (Switch
Case + `first_non_empty_or_default`, custom `MergeBrandClasses` block
removed). Re-ran `workflows_run` against the live workflow immediately
after to confirm — output identical to the original baseline (same 60
brand/flavor labels, byte-for-byte). The live workflow is now the fast,
correct version. Still open: extending the same pattern to Coca-Cola and
Cappy once those flavor classifiers exist, and deleting the now-unneeded
scratch timing workflow (`Test - switch-case-fanta-timing`, id
`wcAqN3tElm50N91hhxWg`).

## 2026-08-16 — Switch Case prototype: routing confirmed, but merge logic breaks non-Fanta products

Tested per Phase 3.5 of `ROADMAP_FULL_SKU.md`. Method: built a modified copy
of the live `test-aystro-detect-classify-brand` spec (fetched live via
`workflows_get`, not guessed) that inserts `roboflow_core/switch_case@v1`
between `extract_general` and `brand_fanta`, gating `brand_fanta` to only run
when `extract_general.output == "fanta"` (case-insensitive). Ran safely via
`workflow_specs_run` (inline spec, never touched the published/live
workflow) against the same real 60-crop test photo used for the baseline
(`https://source.roboflow.com/PoVOAosFgEYd39fWRxjR9DhGE6r2/jN5jiaWBAUmFV624tA7C/original.jpg`).

**What worked**: per-crop routing is real and confirmed live, not assumed.
`extract_general` classified the full batch (8 cappy, 12 sprite, 20
coca-cola, 12 fanta, rest unclassified/low-confidence). `brand_fanta`
(behind the switch case) only produced output for the 12 crops actually
classified `fanta` by `brand_general` — the other 48 crops' `fanta_debug`
came back null, meaning the Fanta classifier was not invoked on them. **20%
invocation rate (12/60) vs. today's 100% (60/60)** — a real, measured
reduction in wasted classifier calls, exactly the O(N×K) waste identified in
Phase 3.5's original finding.

**What broke**: `merge_brands` (the `MergeBrandClasses` custom block) takes
`general_classes` (full batch, from `extract_general`) and `fanta_classes`
(now restricted-batch, from `extract_fanta` downstream of the gated
`brand_fanta`). In the live test, `merge_brands`' output was **null for all
48 non-Fanta crops** — not just for the ones without a Fanta result, but for
their `general_classes` value too, even though `extract_general` itself had
the correct cappy/sprite/coca-cola label for every one of them. Only the 12
routed Fanta crops resolved. Apparent cause: the execution engine scopes a
step's batch to the narrowest scope among its inputs, so mixing one
switch-case-gated input with one ungated input silently drops the ungated
input's values outside the gated scope. **This means the naive
insert-a-switch-case-and-leave-everything-else-unchanged approach is unsafe
to ship** — it would null out brand for every non-Fanta detection in
production. A real fix (duplicate the merge logic inside each branch, or
find a proper branch-merge block) is needed before extending this to
Coca-Cola/Cappy. Not yet attempted.

**Timing**: not cleanly measurable from this test. The baseline used
`workflows_run` against the already-saved/published workflow (~51.4s,
warm). The switch-case version used `workflow_specs_run` against an ad-hoc
inline spec (~80.1s) — slower, but that most likely reflects one-off
compile/cold-start overhead for an unsaved spec, not the routing logic
itself, so it is **not a fair comparison** and should not be quoted as "how
much time Switch Case costs or saves." The one reliable number from this
test is the call-count reduction above (60→12 invocations of the Fanta
classifier for this photo) — that is the real, defensible efficiency gain,
and it is what should be cited if asked "does this help," not wall-clock
time from this particular test.

## 2026-08-16 (next session) — Packaging-material labeling finished: 1,603/1,606

Resumed from `docs/report/packaging_material_labels.json` (the 1,606-entry
plastic/can audit map committed in the previous session). 143 images were
already labeled and in the dataset from before; the remaining 1,463 were
delegated to 3 background agents in parallel (per the established
contact-sheet/background-agent pattern), each working a disjoint ~488-image
chunk via `annotations_save`.

**Glass class preserved, not overwritten.** Mid-run, the user asked to keep
the project's existing `glass` class rather than force those images into
plastic/can per the map. At that point 22 images were already tagged
`glass` in the live project (pre-dating this session — leftover from before
the plastic/can-only decision documented in §5, not part of that decision).
21 of the 22 fell inside the "remaining" set the agents were processing (1
was already in-dataset and untouched). By the time the correction reached
all three agents, 14 had already been overwritten to plastic/can — these
were identified (cross-referencing live `images_search` against the map)
and restored to `glass` directly. The other 7 were correctly skipped by the
agents once instructed. All 22 were also confirmed added to the trainable
dataset (7 of them had a `glass` annotation from before this session but had
never actually been added to the dataset — fixed as part of this cleanup).
Final check: `images_search(class_name=glass, in_dataset=true)` → exactly
22/22, matching the original set with no drift.

**Session-limit interruption.** All 3 agents hit "You've hit your session
limit" partway through (a real platform limit, not a permission issue) and
had to be resumed via `SendMessage` with the skip-list attached — worth
knowing for future bulk-write tasks of this size: budget for at least one
resume cycle.

**Final result:**
- In-dataset total: 1,603 images (1,606 map entries − 3 permanent failures)
- `plastic`: 844, `can`: 737, `glass`: 22 (live `images_search` counts, not
  the project-summary `classes` stat, which was observed to be stale/out of
  sync with real-time queries throughout this session and should not be
  trusted for reporting — verify with `images_search` directly)
- 3 permanent failures after repeated retries (Roboflow-side `"Unknown
  error"`, 4 attempts each across the resumed agents and a direct retry):
  `DrT1Tw6tquGduF9EAwR2`, `BYukrThCYMyENKQtkvp4`, `P4uKKPqqotvCTgyIjli4` —
  all three were supposed to be `can` per the map. Worth one more retry in
  a later session or a look at whether these image records are corrupted.
- Minor, unexplained ~5-image skew between the map's expected plastic/can
  split (839/745, after removing the 21 glass overrides) and the actual
  live counts (844/737) — total accounts for exactly (1,606 − 22 glass − 3
  failures = 1,581 map-driven labels + 22 glass = 1,603, which matches), so
  no images are missing or double-counted, but a handful of the *original*
  143 (labeled in an earlier session, before this map existed) likely carry
  a label that doesn't match this map's judgment for the same image. Not
  investigated further; flagging for anyone training on this data.
- Not yet trained or evaluated — this only completes the labeling step from
  §5.

## 2026-08-17 — Packaging classifier trained; Coca-Cola variant data re-audited, confirmed insufficient

**Packaging-material classifier (`test-aystro-packaging-classifier`), continuing
from the labeling-complete state above:**
- First version generated (v1) had **zero validation/test images** — all
  4,806 images landed in `train` because the source images had never been
  split at upload time. This would have made the classifier untrainable in
  a way that's actually verifiable (no eval set) and was caught before
  training, not after.
- Fixed via `datasets_rebalance_splits` (70/20/10 target) at the project
  level, which redistributed the 1,602 source images to train:1121/
  valid:320/test:161. v1 was deleted (splits are frozen at version-generation
  time, so the fix required a fresh version) and v2 regenerated with the
  same preprocessing/augmentation as before (auto-orient, resize 224x224,
  blur 1px + noise 0.1%, 3x image versions) — 3,844 images, train:3363/
  valid:320/test:161 after augmentation (valid/test correctly excluded from
  the 3x multiplier).
- Trained on v2: `vit-base-patch16-224-in21k`, same architecture as the
  brand and Fanta classifiers. Finished in ~7 minutes
  (`ma7mouds-workspace/test-aystro-packaging-classifier-2-vit-base-patch16-224-in21k-t1`).
  `metrics: null` — see the updated §2 above; this is a plan-tier gap
  affecting every classifier in this workspace, confirmed root cause, not
  something specific to this run.

**Coca-Cola variant classifier — reconsidered per user request, same
conclusion, now backed by a real re-audit instead of trusting the old one.**
User recalled cancelling a labeling attempt on `test-aystro-coca-classifier`
~4 days prior and asked whether to delete the existing 301 images and start
fresh. Investigated instead of guessing:
- `test-aystro-coca-classifier` holds exactly 301 images, all still the
  single placeholder class `coca-cola`, seeded 1:1 from
  `aystro-brand-classifier`'s `coca-cola` class (also 301 at audit time) —
  confirming this project already contains 100% of the real captured
  Coca-Cola crops that exist. There is nothing to gain by deleting and
  restarting; the constraint is real-world photo diversity, not anything
  about how the data is currently organized.
- Ran a background-agent visual audit (same contact-sheet pattern as the
  Fanta/packaging-material audits): downloaded all 301 crops, sorted by
  dominant color (a much stronger signal for Coke variants than Fanta
  flavors — classic is red, Zero is black, Diet/Light is silver).
  ~286/301 (95%) classic; **zero confirmed Coke Zero (black) instances**;
  the one plausible Diet/Light (silver-bodied, red script) finding is 3
  sequentially-numbered crops (`2912.jpg`/`2913.jpg`/`2914.jpg`) almost
  certainly from a single physical can in one shelf photo, not independent
  sightings. Spot-checked the silver cluster's contact-sheet crop directly
  (not just trusting the agent's report) — confirms the finding: most of
  that cluster is glare/reflective caps on ordinary red bottles, not real
  silver cans.
- **Conclusion unchanged from the original audit, but now independently
  re-verified**: not enough real variant diversity to train a 3-class
  classifier (compare to Fanta, which had real spread across all target
  flavors). Stays a Phase 2 (field photography) blocker per
  `ROADMAP_FULL_SKU.md` — needs a rep to specifically shoot a handful of
  actual Zero/Diet units. Once that exists, labeling will be easy (color is
  a strong, high-contrast signal); the gap today is capture, not labeling
  effort or data organization.

## 2026-08-17 (later) — XL Energy variant classifier trained

Unlike Coca-Cola, the Phase 0 audit for XL Energy found real, confirmable
variant diversity in existing captures — enough to label and train a
5-class classifier rather than stopping at "not enough data" the way the
Coca-Cola audit did. New project: `test-aystro-xlenergy-classifier`.

**Split fix applied proactively this time.** The packaging-material
classifier (§ above) generated its first version with zero valid/test
images because the source images had never been split before version
generation, and the bug was only caught after training. For XL Energy,
`datasets_rebalance_splits` was applied at the project level *before*
generating v1, so the first version already came out with a real eval
split — no wasted training run, no version-delete-and-regenerate cycle
this time.

**Final label distribution, verified live** (`images_search` per class,
`in_dataset=true` — not the project-summary `classes` stat, which has been
observed stale/out-of-sync with real-time queries throughout this
engagement and should never be trusted alone for reporting numbers):

| Class | Count |
|---|---|
| `xl-classic` | 247 |
| `xl-red` | 20 |
| `xl-sugarfree` | 12 |
| `xl-mojito` | 6 |
| `xl-doublekick` | 6 |
| **Total** | **291** |

Heavily imbalanced toward `xl-classic` (85% of the data) — worth flagging
for the report the same way the Fanta grape/`aystro-project` v2 imbalances
were: real variant diversity exists and is worth capturing as distinct
classes, but `xl-mojito`/`xl-doublekick`/`xl-sugarfree` are thin (6-12
images each) and would benefit from targeted photography, same as the
Cappy/Pepsi/Sprite audits still pending in `ROADMAP_FULL_SKU.md` Phase 0.

Project-level splits: train 204 / valid 58 / test 29 (291 total, matching
the class counts above exactly). Version 1 (699 images post-augmentation):
train 612 / valid 58 / test 29 — valid/test correctly excluded from the
augmentation multiplier, same pattern as the packaging classifier's v2.

**Trained**: `vit-base-patch16-224-in21k` (same architecture as the brand,
Fanta, and packaging classifiers), training id `4b374a05a67ea782bff2`,
finished in ~4.4 minutes
(`ma7mouds-workspace/test-aystro-xlenergy-classifier-1-vit-base-patch16-224-in21k-t1`).
`metrics: null` — expected, same plan-tier gap as every other classifier in
this workspace (§2 above), not specific to this run.

Not yet wired into any Workflow. Per the Phase 3.5 pattern already applied
to Fanta, adding XL Energy as a live classification branch should use
`switch_case` + `first_non_empty_or_default` from the start rather than an
unconditional parallel branch, to avoid repeating the O(N×K) mistake.

## 2026-08-17 (later still) — Project/workflow renames broke production; root-caused and fixed

User dropped the `test-` prefix from every project/workflow that had reached
production quality (`test-aystro-brand-classifier` → `aystro-fanta-classifier`,
`test-aystro-coca-classifier` → `aystro-coca-classifier`,
`test-aystro-packaging-classifier` → `aystro-packaging-classifie` [sic, real
live slug], `test-aystro-xlenergy-classifier` → `aystro-xl-classifier`,
`test-aystro-project-v2` → `aystro-product-detector`, and the live workflow
`test-aystro-detect-classify-brand` → `aystro-detect-classify`) directly via
the Roboflow UI, plus deleted most of the ~2,900 unlabeled/leftover images
sitting in the Fanta classifier project from before its Fanta-only trim
(1,619 never-in-dataset + most of 1,309 in-dataset-unlabeled → down to
299 in-dataset + 310 still-unannotated per live `projects_list`). This
surfaced two real, previously-unknown platform bugs, both fixed same session:

**Bug 1 — the app was pointed at a different, wrong workflow.** The app's
`ROBOFLOW_WORKFLOW_ID` default (`api/detect.js`, `lib/config/app_config.dart`,
`.env.example`, README, tests) was hardcoded to `aystro-detect-classify-brand`.
Renaming the live workflow to `aystro-detect-classify` did **not** free the
old `-brand` slug — a different, older, unmaintained workflow (id
`n3z2tXa0OUkEyXXsr63o`, last touched 2026-08-11, no Fanta routing, no
`switch_case`) already lived there and instantly became what the app was
calling. Its `brand_predictions` output is shaped differently too (full
prediction objects via `$steps.brand.predictions`, not the flat string list
via `$steps.merge_brands.output`), so this was a silent regression, not just
"running an older model." Confirmed via `workflows_list`/`workflows_get`,
not assumed. Fixed by updating every `ROBOFLOW_WORKFLOW_ID` default (and
doc comments/README) to `aystro-detect-classify`, with an explicit code
comment warning not to revert to the `-brand` slug.

**Bug 2 — renaming a project orphans every model already trained in it.**
The live workflow's `brand_fanta` step still referenced
`test-aystro-brand-classifier/4` (a dead slug) — fixed to
`aystro-fanta-classifier/4`, which *looked* right (`versions_get` showed
the version `ready: true`, training `finished`) but 404'd at the serving
layer when actually run (`workflows_run` against a real photo, not
assumed). Root cause: the trained model's own generated id bakes in the
project name **at training time**, e.g.
`test-aystro-brand-classifier-4-vit-base-patch16-224-in21k-t1` — renaming
the project afterward does not rename this artifact. `models_get` on that
exact old generated name still resolves the model fine (it's not deleted),
but Workflow classification steps only accept `project_id/version_number`,
not a bare model name — so a renamed project's old models become
*permanently unreferenceable from any Workflow* until retrained. Confirmed
this is systemic, not Fanta-specific: `aystro-packaging-classifie` v2 and
`aystro-xl-classifier` v1 show the exact same stale-model-id pattern in
their `trainings[].modelIds`. Fix: `trainings_create` on the existing
version (no relabeling needed, data was already correct) — retrained
`aystro-fanta-classifier` v4 and `aystro-xl-classifier` v1 same session
(XL Energy needed retraining anyway, independently, because its class list
changed after v1's original training — see the entry above). Both fixes
(workflow slug + model reference) verified live via `workflows_run`/
`workflow_specs_run` against a real photo before being called done, not
just via `workflows_get` showing the "right" config — the config alone was
misleading twice in this investigation (see Bug 1/2 above), which is worth
remembering the next time a Roboflow rename happens: **always re-verify
with a real inference call, config inspection alone is not sufficient.**

**Not yet done**: `aystro-packaging-classifie` v2 has the same orphaned-model
problem but isn't wired into any live Workflow, so it wasn't retrained this
session (no urgency) — flagging so a future session doesn't assume it's
servable just because `versions_get` shows it finished.

**Resolution, same session**: retrained both `aystro-fanta-classifier` v4
(training id `dfe246d0f68fbfccf8d1`) and `aystro-xl-classifier` v1 (training
id `58e5d17329d666cdd779`) — new model ids correctly bake in the current
project names (`aystro-fanta-classifier-4-...`, `aystro-xl-classifier-1-...`),
confirming the fix. Also discovered mid-fix that `workflows_get` reporting
the "right" saved config is *not* sufficient evidence a fix works — this
investigation hit two more layers of surprise on top of the orphaned-model
bug itself: (1) `workflows_run` lagged behind `workflows_update` by roughly
one edit cycle before reflecting a change, and (2) the `roboflow_classification_model@v3`
step strictly requires `project_id/version_number` as `model_id` — it
rejects a bare (but otherwise valid and `models_get`-resolvable) model name,
so referencing an orphaned model by its raw generated name is not a usable
workaround, only retraining is. Re-pointed the live workflow's `brand_fanta`
step back to the clean `aystro-fanta-classifier/4` alias post-retrain, added
XL Energy as a second `switch_case` branch (`route_xlenergy` /
`brand_xlenergy` / `extract_xlenergy`, model `aystro-xl-classifier/1`,
folded into `merge_brands`'s priority list as
`[extract_fanta, extract_xlenergy, extract_general]`), and verified the
whole thing live via `workflows_run` against the same 60-crop test photo
used throughout this engagement — output byte-identical to the established
baseline for every cappy/sprite/coca-cola/fanta crop (this particular photo
has no XL Energy products, so that branch wasn't exercised by this specific
run, but didn't disturb anything else either). Phase 3.5's routed-classifier
pattern is now live for two brands.

Also answered a live architecture question from the user during this fix:
they were reading the workflow's data-flow edges (`crop` → `brand_fanta`,
`crop` → `brand_xlenergy`, wiring image *availability*) as evidence both
classifiers run unconditionally in parallel with `brand_general`. They
don't — `switch_case` gates actual *execution* separately from the data
edges, and this was already independently confirmed in the 2026-08-16
entries above (12/60 crops actually invoked the Fanta classifier, not
60/60). Worth remembering for anyone reading the workflow JSON cold: an
`images` edge into a classifier step means "this step could reach that
data if invoked," not "this step runs on every crop."

## 2026-08-17 (evening) — Sprite-can training-data gap found, root-caused, and fixed

User reported (with two real phone screenshots from a live production capture,
not a lab test) that Sprite cans specifically were sometimes missed entirely
and sometimes classified at confidence as low as ~20%, and that this had been
happening for at least 3 days, not something introduced by that day's fixes.
Coca-Cola-variant and packaging-type questions came up in the same message —
see the two entries below for those.

**Root cause, confirmed visually, not assumed.** Downloaded and
aspect-ratio-sorted a 138-image sample of `aystro-brand-classifier`'s
`sprite` class (same contact-sheet method used throughout this engagement).
Only ~10-15 of 138 (~10%) were genuine cans; the rest were PET bottles. The
classifier had seen roughly 9x more bottle examples than can examples for
the same brand, which plausibly explains both symptoms the user reported
(missed detections and low-confidence hits) — the model's Sprite prototype
is bottle-shaped.

**Fix: mined real can crops from an older, richer dataset instead of new
photography.** `aystro-project` (the original brand-classed detector,
superseded by `aystro-project-v2` but never deleted) has 651 sprite box
annotations across 227 photos — never migrated into the classifier
project. Exported `aystro-project` v19 in COCO format (221 images, no
augmentation, all 6 brand classes present — v11 was tried first and turned
out to predate Fanta/Sprite labeling, a dead end worth remembering),
matched COCO entries back to live Roboflow image ids via original filename,
rescaled box coordinates from the COCO export's resized (704x704) space to
each source image's real dimensions, and cropped 331 sprite boxes from the
28 unique source photos they lived in (matching only 28/52 sprite-containing
images by filename — the rest hit real filename collisions in this messy
older project, a known risk called out explicitly and accepted for this
exploratory audit; every image dropped that way is just missing, not
mislabeled).

Sorted the 331 crops by aspect ratio — cans clustered unmistakably below
~2.3, bottles above. Filtered to 77 crops (AR ≤ 2.3, min dimension ≥ 20px)
after a visual pass confirmed they're genuine, mostly-legible Sprite cans.
Uploaded and labeled all 77 into `aystro-brand-classifier` (tag
`sprite-can-migration` for traceability), confirmed live via
`images_search` (297 → 374 sprite images, exact expected count, no drift).
Generated v3 (1686 images) and retrained
(`vit-base-patch16-224-in21k`, training id `85ddac80c77b8dada3a0`) — this
roughly triples the class's can representation (from ~10% of ~297 to
~87/374, ~23%). Once trained, `brand_general`'s `model_id` needs updating
from `aystro-brand-classifier/1` to `.../3` in the live workflow (v1 also
predates the `chat` class already in the project — worth using v3 for both
reasons) — do this and re-verify live before considering the fix complete.

**Not fixed, flagged for later**: this only addresses the *classifier*
side. The user's "sometimes not detected at all" symptom could also be a
*detector* (`aystro-project-v2`, only 226-227 raw images) recall gap on
can shapes specifically — the same already-documented "800 annotated
images never migrated" gap from §1 could be affecting can-shaped items
disproportionately if the migration wasn't representative. Not
investigated this session; worth a similar aspect-ratio audit of the
detector's own training images if the can-recall problem persists after
this classifier fix ships.

**Trained and deployed, same session.** `aystro-brand-classifier` v3
finished training (`vit-base-patch16-224-in21k`, training id
`85ddac80c77b8dada3a0`, ~4.3 min) — new model correctly
`aystro-brand-classifier-3-vit-base-patch16-224-in21k-t1`, no orphaning
this time since v3 was generated and trained under the current project
name throughout. Live workflow's `brand_general` step re-pointed from
`aystro-brand-classifier/1` to `.../3` (v3 also carries the `chat` class
that v1 lacked). Re-verified live via `workflows_run` against the same
real test photo used throughout this engagement: output byte-identical to
the pre-switch baseline for every field — expected, since this particular
photo has no Sprite cans among its crops to exercise the new data, but it
confirms the version switch introduced no regression on the classes it
does cover.

## 2026-08-17 (evening) — Packaging type now exposed in the live workflow

Per user request ("enable the ability to check the packaging type").
`aystro-packaging-classifie` was trained but never wired into any live
Workflow (flagged as a known gap in earlier entries this session). Retrained
it first (same orphaned-model-after-rename issue as Fanta/XL — training id
`b7c14aaa384a2594aebd`, new model correctly `aystro-packaging-classifie-2-...`
this time), then added it to `aystro-detect-classify` as an **unconditional**
parallel branch (`packaging` step + `extract_packaging`), not gated behind
`switch_case` like the flavor classifiers — material isn't brand-conditional,
it runs on every crop regardless of brand, matching the "shared,
brand-agnostic" framing already on record in §4. New output field
`packaging_predictions` (flat can/glass/plastic array, index-aligned with
`predictions`/`brand_predictions`, same pattern). Verified live via
`workflows_run` against the real test photo: packaging predictions plausibly
match the real product mix (Cappy bottles all `plastic`, Coca-Cola/Sprite/
Fanta items split `can`/`plastic` matching the actual shelf), brand
predictions unchanged. Not fused into the final classification label
itself (that's Phase 4 in `ROADMAP_FULL_SKU.md`, not yet built) — this just
makes the signal available as a separate field, which is what was asked for.

## 2026-08-18 — Cappy classifier wired live; confidence-gated active learning
turned on; Supabase "mine existing corrections" plan abandoned (data doesn't
exist)

**Cappy wired.** `aystro-cappy-classifier/1` (trained same session, 12-class
real flavor taxonomy the user relabeled by hand — see `ROADMAP_FULL_SKU.md`
Phase 1) added to `aystro-detect-classify` via the same `switch_case` +
`first_non_empty_or_default` pattern already proven for Fanta/XL Energy.
Verified live: Cappy crops now resolve to real flavors (`cappy-orange`,
`cappy-mango`, `cappy-lemon` all observed on the standard test photo, at
0.59-0.80 confidence) instead of falling through to a generic bucket. All
other branches (Fanta, XL, packaging, Sprite/Coca-Cola via the general
classifier) byte-identical to the pre-change baseline — no regression.

**Active learning added and enabled.** Added confidence-gated
active-learning sinks to all four variant branches (Fanta, XL Energy, Cappy,
packaging): extract confidence -> `continue_if` (only when confidence < 0.75)
-> `roboflow_dataset_upload@v2` with `persist_predictions: false` (crop
uploads unlabeled, a human must label it — nothing trains on the model's own
guess unreviewed, directly addressing the "AL degrades itself over time"
risk the user raised) and `data_percentage: 50` (samples half of the
low-confidence crops, not all, to bound cost). Gated behind a new
`disable_variant_active_learning` workflow parameter. Pushed live once with
the parameter defaulting to `true` (off, so the wiring could be verified
inert first), then flipped to default `false` (on) once the user confirmed —
both pushes verified live via `workflows_run` against the standard test
photo, output unregressed both times. This is now the live, primary
mechanism for turning real field photos into future training data.

**Supabase "mine existing corrections" — investigated and abandoned, not
just deferred.** The plan (approved earlier this session as the "free/fast"
first step, before the AL discussion) was to backfill classifier training
data from `detections` rows where a rep corrected the model. Checked the
real data before building anything: `captures.image_path` is `NULL` on
100% of rows (15/15 captures), not just the corrected ones. Traced to
`lib/services/roboflow_service.dart:82`, which documents the actual
architecture: captured photos are sent to Roboflow as base64 at capture
time and never uploaded to any Supabase-side storage — there is no cloud
copy of the original image at all, ever, for any capture. Separately,
`detections.original_class` (the column that would flag "a rep actually
reclassified this box") is `NULL` on all 543 rows — the reclassify-existing-
detection code path (`lib/models/capture_draft.dart`, `wasReclassified`)
exists and is wired to write it correctly, but no rep has used it yet in
practice (8 rows have `origin='manual'`, but those are manually added
boxes, not corrections to model boxes).

Net: there was never a "free" data source to mine here — both preconditions
(a stored image to crop, and a real correction to label it with) are absent
today. Raised with the user directly rather than either building against
non-existent data or silently dropping the approved plan. Decision: do not
add Supabase Storage image persistence for this purpose — rely on the new
active-learning sink instead, which needs no app changes and is already
live. If this decision is ever revisited, the two blockers above are
exactly what would need fixing first (add a Storage upload call to
`visit_service.dart`'s `recordCapture`, and confirm reps actually start
using the reclassify UI once the app change ships).

## 2026-08-18 (later) — Fixed "Cappy returns unclassified 0%" (systemic classifier
confidence-threshold bug, not Cappy-specific)

User reported Cappy sometimes returns `unclassified` at 0% confidence in the app.
Reproduced live and root-caused via a debug spec (`workflow_specs_run` with extra
outputs exposing each branch's raw predictions, never touching production):

- `brand_general` (the routing classifier) correctly identified all affected crops
  as `cappy` at 0.83-0.85 confidence, so routing itself was never the problem.
- `aystro-cappy-classifier/1` (`brand_cappy`) returned a **literal empty predictions
  list** (`predictions: [], top: "", confidence: 0`) for several of those same crops
  — not a wrong guess, no guess at all.
- Every `roboflow_classification_model@v3` step in this workflow was left on
  `confidence_mode: "default"` (Roboflow's own built-in per-model threshold,
  never explicitly set). Below that threshold the block returns nothing.
- That empty result then broke `merge_brands`'s `first_non_empty_or_default`
  fallback chain: it treats a present-but-empty string as "already answered" and
  never falls through to `extract_general.output`'s valid `"cappy"` — so the
  final label collapses to the `unclassified` default. Confirmed this same
  failure mode already existed for the general classifier itself on one crop
  in the same test photo (independent of Cappy).

**Fix**: set `confidence_mode: "custom"`, `custom_confidence: 0` on all five
classification steps (`brand_general`, `brand_fanta`, `brand_xlenergy`,
`brand_cappy`, `packaging`) so each always returns its top-1 guess — never an
empty result. Real confidence is unaffected (still read separately via
`top_class_confidence` for the active-learning gate added earlier today), so a
genuinely uncertain guess now surfaces as e.g. `cappy-pomegranate` at 0.22
confidence instead of vanishing — which is exactly what the AL gate (<0.75) is
built to catch and route for human review, rather than silently dropping the
detection to `unclassified`/0%.

Verified the fix against the debug spec first (all 8 previously-empty Cappy
crops now return a flavor guess), then pushed to the live workflow and
re-verified with `workflows_run`: the same test photo now returns zero
`unclassified` detections anywhere in the output.

## 2026-08-18 (later still) — Real production bug: "Unlabeled" bogus class in
aystro-fanta-classifier; Coca-Cola Zero data gap confirmed (not yet fixed)

**Investigated a second user report** ("cappy gives unclassified... and some
Coca-Cola cans") separately from the confidence-threshold fix above.

**Coca-Cola Zero — confirmed real gap, not yet fixed.** Sampled 30 real
training images from `aystro-brand-classifier`'s "coca-cola" class: 100%
classic red Coca-Cola, zero Zero-variant examples. Pulled a genuine
Coca-Cola Zero photo from a public Roboflow Universe dataset and ran it
through our classifier: correctly identified as `coca-cola` but at only
0.58 confidence vs 0.71-0.81 for classic red — the model recognizes it via
the shared red script logo but is under-confident since it's never seen
this variant. Same underlying pattern as the Sprite-can gap fixed earlier
this session, just not severe enough yet to misfire on the one image
tested. Not fixed this session — needs the same treatment as Sprite (mine
or source real Zero examples, retrain).

**The actual root cause of the user's live screenshot — "Unlabeled" at
65%, not a Coca-Cola issue at all.** The user sent a real screenshot from
the app showing a box labeled `Unlabeled 65%` next to correctly-labeled
Coca-Cola/Fanta cans. Traced it precisely: the general brand classifier
correctly said "fanta" (84% confidence) for that crop, which routed to
`aystro-fanta-classifier` — and that model confidently (98%!) returned a
literal class named `"Unlabeled"` instead of a real flavor.

Root cause: `aystro-fanta-classifier` has 311 real, valid Fanta photos
sitting **unannotated** in the project (visually confirmed several — all
genuine Fanta-orange bottles/cans, not junk). The currently-deployed
trained version (v4) had somehow swept these in as a literal 4th class
called "Unlabeled" at generation time (visible in the project's own
color-palette metadata: `"Unlabeled":"#FF8000"` alongside a similarly
orphaned generic `"fanta"` color entry — both leftover from some earlier,
different annotation state, frozen into the old version snapshot). The
model then had two competing buckets for the same visual concept and
sometimes picked the wrong (bogus) one, at very high confidence — this
was never caught by the earlier confidence-threshold fix because the
prediction wasn't low-confidence, it was a *wrong* class with high
confidence.

**Fix**: regenerated a clean version (`aystro-fanta-classifier/5`, 299
images, only the 3 real flavor classes, no bogus class), retrained
(`vit-base-patch16-224-in21k`, training id `cafe4f237ea92deabe03`, ~3.3
min), re-pointed the live workflow's `brand_fanta` step from `/4` to `/5`.
Verified live: the exact detection that previously showed
`Unlabeled 65%`/`98%` now shows `fanta-redapple` at 97.3%, and every other
Fanta detection's confidence jumped from ~84% to 98-99% now that the model
isn't splitting probability mass against a phantom duplicate class. No
regressions on Cappy/Sprite/Coca-Cola/packaging.

**Follow-up not yet done**: the 311 unannotated images are real, valuable
Fanta data (mostly appear to be fanta-orange from a visual sample) that
could meaningfully help the classifier, especially the thin fanta-grape
class (only 27 images). Worth properly labeling them by flavor and folding
into a future version — same "contact sheet + background agent" pattern
used for Cappy — rather than just excluding them as done here for the
immediate hotfix.

## 2026-08-18 (later still) — Coca-Cola variant classifier staged, blocked on
training credits

Per the confirmed Coca-Cola Zero gap logged earlier, the user manually
annotated `aystro-coca-classifier` (300 images: coca-classic 250,
coca-zero 40, coca-diet 10 at annotation time). Rebalanced splits
(210/60/30) and generated a clean version 2 (verified via the export
response: only the 3 real classes in the project's color palette, no
repeat of the "Unlabeled" contamination hit on the Fanta project earlier
today). `trainings_create` then failed:
`insufficient_train_credits` — "this workspace does not have enough
credits to train." This is the same underlying constraint as task #9
(Roboflow plan upgrade, blocked on owner decision) in the roadmap, now
concretely blocking a ready-to-train model rather than a hypothetical
future one.

**Everything is staged and ready** — the moment credits are available
(top-up, plan upgrade, or monthly reset), run: `trainings_create` on
`aystro-coca-classifier` version 2 (`vit-base-patch16-224-in21k`), then
wire `brand_coca` into `aystro-detect-classify` via `switch_case` on the
general classifier's `coca-cola` value, same pattern as
fanta/xlenergy/cappy, plus a confidence-gated active-learning sink
matching the other four branches.

## 2026-08-18 (later still) — Coca-Cola variant classifier wired (user-trained);
AL sinks reworked to always-upload; two app-side fixes

**Coca-Cola.** Blocked on Roboflow training credits via the API (see prior
entry). User trained `aystro-coca-classifier` version 1 directly in the
Roboflow UI (`coca-classic`/`coca-zero`/`coca-diet`, 780 images after
augmentation) — bypassing the API credit limit. Verified the model directly
before wiring: a classic red Coca-Cola crop scored 96% `coca-classic`; a
genuine Coca-Cola Zero test photo leaned only 77%/18% classic/zero (still
wrong, but visibly less confident, consistent with only 40 zero-labelled
images — expected to improve as the new active-learning sink collects more).
Wired `brand_coca` into `aystro-detect-classify` via the same
`switch_case` (`"coca-cola"` case, matching the general classifier's own
brand label) + `first_non_empty_or_default` pattern as fanta/xl/cappy.
Verified live: every Coca-Cola detection on the standard test photo now
reads `coca-classic` at 96-98% confidence; no regression elsewhere.

**Active-learning sinks reworked — confidence gate removed.** User reported
Cappy's AL sink fires on nearly every test while Fanta/XL fired once each
total, despite real detection errors they wanted to capture. Root cause:
the `confidence < 0.75` gate structurally can never catch a *confidently
wrong* prediction (exactly what the "Unlabeled" bug from earlier today
was — 98% confidence, wrong class) — it only catches genuine uncertainty,
and Fanta/XL are now confident enough (~98%+ after their fixes) that they
almost never dip below the threshold. Removed the confidence-based
`continue_if` gate on all five branches (fanta/xlenergy/cappy/packaging/
coca) and `data_percentage` raised 50 -> 100, so every crop actually routed
to a given variant branch now gets uploaded for review, regardless of how
confident the model was. Replaced the gate with a route-membership check
(`extract_X.output != ""`) so each branch's sink still only receives crops
that branch actually classified — without this, removing the confidence
gate naively would have uploaded every crop in every photo to every
branch's project indiscriminately. This is a real, intentional increase in
upload volume (and therefore Roboflow usage) — the tradeoff the user
explicitly asked for during this active correction/data-collection phase.
Verified live: predictions byte-identical to before the change (the rework
only touches the upload side-effects, not classification).

**Two app-side fixes**, both root-caused from the same conversation:

- `AnalysisSettings.defaultConfidence` (`lib/widgets/analysis_settings_sheet.dart`)
  lowered from 0.7 to 0.4. The 0.7 floor was hiding real, correctly-classified
  but lower-confidence detections (e.g. the new Cappy flavors, which range
  22-80% confidence) from the rep's screen entirely — they can't correct
  what they never see. Comment updated to record the tradeoff and that it's
  a temporary stance for the active-correction phase.
- `DetectionResult.filterByClasses` (`lib/models/detection_result.dart`) was
  doing exact-string matching against the "Products" filter chips, but the
  chip list is sourced from `aystro-brand-classifier`'s brand-level names
  (`cappy`, `fanta`, ...) while real detections are now flavour-level
  (`cappy-orange`, `fanta-redapple`, ...) thanks to this session's variant-
  classifier work — so selecting the `cappy` chip matched zero detections
  even with real Cappy bottles on screen, exactly as reported. Fixed to also
  match on a `$root-` prefix, mirroring the same pattern
  `brand_share_of_shelf.dart`'s `_brandRootOf` already uses for Share of
  Shelf grouping.

**Known follow-up, not fixed (out of scope for this pass, kept simple per
user's request):** the Coca-Cola chip specifically is still a dead end even
after the prefix fix — the chip is labelled `coca-cola` (from the brand
classifier) but the real classes are `coca-classic`/`coca-zero`/`coca-diet`,
which don't share that prefix (`coca-` vs `coca-cola-`), and
`brand_share_of_shelf.dart`'s `_knownBrandRoots` has the same mismatch for
Share-of-Shelf grouping. XL Energy already had this same root/prefix
mismatch before today (`xl_energy` vs `xl-*`) — this is a pre-existing
pattern, not something introduced today, and is a case of the deeper "chip
source project only knows brand-level names" issue noted earlier in this
session, not the specific bug reported. Worth a real fix later (aggregate
the chip list across the variant-classifier projects, or add
`coca`/`xl` root aliases), just not bundled into this pass.
