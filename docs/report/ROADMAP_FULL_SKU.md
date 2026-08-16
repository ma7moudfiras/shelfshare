# Roadmap: Full SKU-Level Classification

Target output format, one string per detection, e.g.:

```
coca-can-classic-slim330ml
coca-bottle-zero-1.25L
cappy-bottle-grape-1.5L
fanta-glass-orange-250ml
pepsi-can-classic-fat330ml
```

Pattern: `{brand}-{package}-{variant}-{size}` — `package` ∈ {can, bottle
(implicitly plastic), glass}; can sizes fold shape into the size token
(`slim330ml` / `fat330ml`); bottle sizes are plain volume.

This is a durable planning record — update statuses here as work lands, don't
let it go stale. See `RESEARCH_NOTES.md` for the evidence/findings feeding
the report, and `CLAUDE.md` for Roboflow project-naming conventions.

## Decisions already made (don't re-litigate)

- **Size estimation, phased approach** (user's call, 2026-08-15): try the
  reference-object geometric approach first (compare box dimensions against
  a known-size reference product in the same photo — extends the existing
  cross-detection height-comparison logic already in `CanShapeRule`). If
  measured accuracy is inadequate, fall back to a visual size classifier —
  but run a small feasibility pilot (~30 images) before committing to full
  data collection for that fallback, since it isn't yet established that
  size is even visually distinguishable from these crop resolutions.
- **Cappy flavor diversity confirmed real** (user's call, 2026-08-15): Cappy
  has genuine, visually-distinct flavor variants in market. Build its
  flavor classifier directly (Phase 1 below), unlike Pepsi/Sprite/XL Energy
  which are unconfirmed and need an audit first.
- **Every new classifier must be evaluated before being trusted or wired
  into production** — this was skipped for the brand and Fanta classifiers
  (both show `metrics: null`); don't repeat that omission going forward.

## Phase 0 — quick wins, no new data needed

- [ ] Run `Evaluate` on `aystro-brand-classifier` v1 and
  `test-aystro-brand-classifier` v4 — no recorded accuracy exists for
  either despite both serving live traffic.
- [ ] Finish `test-aystro-packaging-classifier`: resume paused labeling
  (136/1606 done as of 2026-08-15), generate version, train, evaluate.
- [ ] Audit existing Pepsi/Sprite/XL Energy captures for real flavor
  diversity (same method as the Coca-Cola audit) before deciding whether to
  build classifiers for them.

## Phase 1 — Cappy flavor classifier

- [ ] Visual audit of existing captured Cappy images: how much of the
  confirmed real-world diversity is actually present in current data.
- [ ] Contact-sheet label by flavor, create project, upload, train,
  evaluate.
- [ ] If existing data is too thin/undiverse: flag for targeted photography
  (folds into Phase 2).

## Phase 2 — field photography (owned by the user/field team; the real
## bottleneck — everything below depends on this, start it early)

- [ ] Real Coca-Cola flavor variants (Zero, Diet, Light, etc.) — current
  data audited and found almost entirely "classic," not usable to train a
  flavor classifier as-is.
- [ ] Glass-packaged products across brands — only 2 genuine examples exist
  in the entire 1,608-image labelled corpus today.
- [ ] Cappy flavors, if Phase 1's audit finds gaps.
- [ ] A 50–100 image **size reference validation set**: photos where the
  real-world size is known for certain (photographer records it, or shoots
  a known-size product alongside others as a scale reference). Required to
  validate *any* size-estimation approach (Phase 3) before trusting it —
  neither the geometric nor the classifier approach can be evaluated
  without this.

## Phase 3 — the size/volume axis (hardest, technically)

- [ ] **Step 0 (cheap, do first):** check whether size is even ambiguous
  per SKU in this market — if a given brand+flavor+package combination is
  only ever sold in one real size, size can be looked up from a small
  catalog table instead of detected visually at all. Could eliminate most
  of the hard cases below.
- [ ] Build the reference-object geometric estimator (extends
  `CanShapeRule`'s existing reference-height comparison pattern).
- [ ] **Validate its accuracy against the Phase 2 reference set before
  trusting it in production** — `CanShapeRule`'s own geometric rule already
  turned out unreliable in practice; do not repeat that mistake by skipping
  verification this time.
- [ ] If inadequate: run the ~30-image feasibility pilot, then (if
  feasible) audit/label/train/evaluate a visual size classifier. Can
  slim/fat shape folds into this same axis rather than staying a separate
  suspended rule.

## Phase 3.5 — fix unpruned branch execution before adding more flavor classifiers

**Finding (2026-08-15, confirmed by reading the live workflow spec, not
assumed):** the current `brand_fanta` step runs unconditionally on every
crop (`images: $steps.crop.crops`) regardless of what `brand_general`
predicted — the `MergeBrandClasses` step only *selects* which result to
keep, it does not prevent the Fanta classifier from running on non-Fanta
crops. This means classifier calls per photo currently scale as
`1 + N×(1+K)` where `K` = number of brand-specific flavor classifiers —
wastefully linear in `K`, since only 1-of-K calls is ever useful per crop.
`K` is about to grow from 1 (Fanta) to 3 (+Coca-Cola, +Cappy) per this
roadmap, so this should be fixed before that, not after.

Roboflow Workflows has a native `Switch Case` block
(`roboflow_core/switch_case@v1`) that routes execution to exactly one
branch by matching a value (e.g. `brand_general`'s output) against cases —
non-matching branches don't execute at all. This is confirmed available on
the platform (schema inspected), not assumed.

- [x] Prototype `Switch Case` routing on the existing Fanta branch first
  (low risk, already working, easy to compare against current behavior).
  **Done 2026-08-16**, tested safely via `workflow_specs_run` against an
  inline modified spec (live workflow never touched).
- [x] Verify via a real multi-product photo that it routes **per crop
  within the batch**, not per whole image. **Confirmed — this part works
  correctly.** Same test photo as the baseline run (60 crops: 8 cappy, 12
  sprite, 20 coca-cola, 12 fanta, plus a few `unclassified`): `brand_general`
  ran on the full batch as before, but `brand_fanta` — now gated behind
  `switch_case` on `extract_general.output == "fanta"` — only produced real
  output for the 12 crops actually classified `fanta`; all 48 non-Fanta
  crops came back with a null `fanta_debug` entry, meaning the classifier
  was not invoked on them. **This is a real, measured reduction: 12/60
  (20%) invocation rate for the Fanta classifier vs. 60/60 (100%) today.**
- [ ] **BLOCKER found, not yet fixed (2026-08-16): this insertion breaks
  correctness for every non-Fanta product.** `merge_brands` (the custom
  `MergeBrandClasses` block) takes two inputs: `general_classes` (from
  `extract_general`, unconditional/full batch) and `fanta_classes` (from
  `extract_fanta`, now downstream of the `switch_case`-gated `brand_fanta`,
  restricted to only the matched subset). In the live test, `merge_brands`'
  output (`brand_predictions`) came back **null for all 48 non-Fanta crops**
  — including cappy/sprite/coca-cola crops whose `general_classes` value was
  present and correct in `extract_general`'s own output. Only the 12 routed
  Fanta crops resolved correctly. The execution engine appears to restrict a
  step's whole batch scope to the narrowest scope of any of its inputs, so
  merging one gated branch with one ungated branch silently drops the
  ungated branch's values wherever the gated branch didn't run. **Do not
  wire this pattern into the live workflow as currently structured** — it
  would silently null out brand for every non-Fanta detection in production.
  Needs a real fix (e.g. mirroring `merge_brands`-equivalent logic *inside*
  each switch-case branch so nothing downstream depends on a mix of gated
  and ungated inputs, or finding a dedicated branch-merge/"first non-null"
  block) before this can be extended to Coca-Cola and Cappy. Re-verify live
  against a real photo again after any fix attempt — do not assume it's
  correct from the spec alone, per the same lesson that caught this bug.
- [ ] **Timing: inconclusive from this test, not a fair comparison.** The
  Switch Case version was run via `workflow_specs_run` (inline, ad-hoc,
  uncompiled spec) at ~80s wall time, vs. the baseline's ~51s via
  `workflows_run` on the already-saved/published workflow — slower, but this
  compares an ad-hoc spec's cold-start/compile overhead against a warm saved
  workflow, not the routing logic itself, so it says nothing reliable about
  the real latency effect. The one clean number from this test is the
  **call-count reduction (60→12 Fanta-classifier invocations, this photo)**,
  which is the real driver of both cost and latency at scale — once the
  correctness bug above is fixed, get a proper timing comparison by testing
  the *saved* draft workflow (still not the live one) so both runs pay the
  same warm-workflow overhead.
- [ ] Once fixed and confirmed correct AND cleanly timed, this converts the
  flavor-classification layer from `O(N×K)` to true `O(N)`, independent of
  how many brands get their own flavor classifier. Extend the routed pattern
  to Coca-Cola and Cappy instead of adding them as further unconditional
  parallel branches.
- [ ] The packaging-material and size axes are shared/brand-agnostic by
  design and already stay `O(N)` regardless of brand count — they don't
  need this fix, only the per-brand flavor layer does.

## Phase 4 — merge logic

- [ ] Extend the `MergeBrandClasses`-style custom Workflow block to
  assemble brand + flavor (where the brand has one) + package + size into
  one final label string.
- [ ] Document the exact naming convention precisely, including what
  happens when an axis doesn't yet exist for a given brand (e.g. Sprite has
  no flavor classifier yet — does the string omit that segment, or does it
  wait until one exists?).
- [ ] Test live via `workflows_run` against real photos. Watch for the same
  class of bug already hit once: custom blocks receive per-crop inputs as
  scalars, not lists.

## Phase 5 — app integration

- [ ] Confirm `BrandShareOfShelf`'s brand-root matching
  (`lib/models/brand_share_of_shelf.dart`) and any other className-parsing
  logic handle the longer compound SKU strings correctly.
- [ ] Regression test.

## Time shape (not a fixed date)

Everything engineering/training-side (Phase 0, Phase 1 training, Phase 4,
Phase 5) is on the order of hours to a few days each, consistent with how
long the Fanta flavor classifier actually took this engagement. The real
schedule driver is Phase 2 (field photography) — every later phase is
gated on it, so it should start as early as possible in parallel with
Phase 0/1.
