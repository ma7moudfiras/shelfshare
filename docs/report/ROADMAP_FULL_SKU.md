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
  either despite both serving live traffic. **Blocked (found 2026-08-17):**
  per Roboflow's own docs, auto-evaluation is a paid-plan feature that
  runs at training time only — there is no manual trigger for an
  already-finished training. Needs a plan upgrade + re-training to ever
  get real numbers here, not just an API call. See RESEARCH_NOTES.md §2.
- [x] Finish `test-aystro-packaging-classifier` labeling (done 2026-08-17:
  1,603/1,606 labeled, glass class preserved) **and train** (done
  2026-08-17: v2, `vit-base-patch16-224-in21k`, ~7 min). **Evaluate
  blocked** — same plan-tier gap as above. **Wired into the live Workflow
  2026-08-17** (`aystro-packaging-classifie`, renamed from
  `test-aystro-packaging-classifier`) — added as an unconditional parallel
  branch (material isn't brand-conditional, unlike the flavor classifiers),
  new `packaging_predictions` output field on `aystro-detect-classify`.
  Verified live. Not yet fused into the final compound label string — see
  Phase 4 below.
- [ ] Audit existing Pepsi/Sprite captures for real flavor diversity (same
  method as the Coca-Cola/XL Energy audits) before deciding whether to
  build classifiers for them.
- [x] Sprite can-vs-bottle training-data imbalance found and fixed
  2026-08-17 (user-reported: real cans sometimes undetected, sometimes
  classified at confidence as low as ~20%). Root cause: `sprite` class in
  `aystro-brand-classifier` was ~90% bottle crops. Mined 77 genuine can
  crops from the older `aystro-project` detection dataset (never migrated
  over) instead of new photography, trained `aystro-brand-classifier` v3
  (1686 images, also carries the `chat` class v1 lacked), and **deployed
  it live** — `brand_general` now points at `aystro-brand-classifier/3`,
  re-verified via `workflows_run` with no regression on unaffected
  classes. See RESEARCH_NOTES.md for the full audit. Detector-side (not
  classifier-side) can recall not yet investigated — flagged as a possible
  follow-up if the problem persists after this fix.
- [x] XL Energy: audited, confirmed real variant diversity (unlike
  Coca-Cola) — 6 classes as of the final label set (`xl-classic`,
  `xl-red`/`xl-maxenergy`, `xl-mojito`, `xl-sugarfree`/`xl-strawberry`,
  `xl-doublekick`, `xl-sportsmaniac` — class list changed once mid-session,
  see RESEARCH_NOTES.md; check `projects_get` for the live set before
  assuming this list is still current). Labeled, split fixed proactively
  before version generation (unlike the packaging classifier's post-hoc
  fix), trained 2026-08-17 (`aystro-xl-classifier` v1,
  `vit-base-patch16-224-in21k`, `metrics: null` — same plan-tier gap as
  every other classifier here), retrained same day after a project rename
  orphaned the first model from serving (see RESEARCH_NOTES.md), and
  **wired into the live Workflow** (`aystro-detect-classify`) via the same
  `switch_case` + `first_non_empty_or_default` pattern used for Fanta —
  verified live via `workflows_run` against a real photo. Phase 3.5's
  routed-classifier pattern is now proven for two brands, not just one.
- [x] ~~Coca-Cola flavor diversity~~ re-audited 2026-08-17 (user asked to
  reconsider deleting/restarting `test-aystro-coca-classifier`) — same
  conclusion as before, now independently re-verified: ~286/301 classic,
  0 confirmed Zero, 1 plausible Diet/Light candidate that's almost
  certainly one physical can, not real diversity. Still a Phase 2 blocker,
  see RESEARCH_NOTES.md.

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
- [x] **BLOCKER found (2026-08-16) and FIXED (same day).** First attempt:
  `merge_brands` (the custom `MergeBrandClasses` block) took two inputs —
  `general_classes` (unconditional/full batch) and `fanta_classes` (now
  downstream of the gated `brand_fanta`, restricted to the matched subset).
  Live test showed `brand_predictions` came back **null for all 48
  non-Fanta crops**, even though `extract_general`'s own output was correct
  for every one of them — the execution engine appears to scope a step to
  the narrowest scope among its inputs, so mixing one gated and one ungated
  input silently drops the ungated branch's values outside the gated scope.
  A second attempt (adding `merge_brands` as the switch_case's
  `default_next_steps` target too) made it **worse** — everything came back
  null, including the Fanta crops. **The actual fix**: stop using the
  custom Python block to merge branches at all. Roboflow Workflows ships a
  purpose-built block for exactly this — `roboflow_core/first_non_empty_or_default@v1`
  ("First Non Empty Or Default"), explicitly documented for "merging
  alternative execution branches." Replaced `merge_brands` with:
  `{"type": "roboflow_core/first_non_empty_or_default@v1", "data":
  ["$steps.extract_fanta.output", "$steps.extract_general.output"],
  "default": "unclassified"}` — picks the Fanta flavor when present, else
  falls back to the general brand, else `"unclassified"`. Re-ran live
  against the same 60-crop photo: **every crop now resolves correctly** —
  cappy/sprite/coca-cola crops keep their plain brand label, and all 12
  Fanta crops resolve to their flavor (11× `fanta-orange`, 1×
  `fanta-redapple`), an exact match to the pre-fix
  baseline's brand assignments plus flavor resolution on top, with the
  Fanta classifier invoked on only 12/60 crops instead of 60/60. The
  `MergeBrandClasses` custom Python block and its `dynamic_blocks_definitions`
  entry are no longer needed for this merge — `first_non_empty_or_default@v1`
  replaces it. Confirmed live, not assumed — this is the pattern to extend
  to Coca-Cola and Cappy (each becomes one more item in the `data` priority
  list, ordered most-specific-first, general last).
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
- [x] Correctness confirmed. **Cleanly timed, 2026-08-16.** Saved the fixed
  spec as its own workflow (`Test - switch-case-fanta-timing`, id
  `wcAqN3tElm50N91hhxWg`) — separate from the live workflow — so both sides
  of the comparison could run through the identical `workflows_run` call
  path on a saved/warm workflow (removing the earlier ad-hoc-spec
  confound). Ran back-to-back against the same 60-crop test photo:
  **baseline (live, unconditional) 40.32s → Switch Case 14.20s — 65%
  faster, 26.1s saved**, with identical final `brand_predictions` in both
  runs (same 60 labels, byte-for-byte). This is a real, apples-to-apples
  measurement, not an estimate — reported as such.
- [ ] This converts the flavor-classification layer from
  `O(N×K)` to true `O(N)`, independent of how many brands get their own
  flavor classifier. Extend the routed pattern to Coca-Cola and Cappy
  (each brand becomes one more `switch_case` case and one more entry,
  most-specific-first, in the `first_non_empty_or_default` priority list)
  instead of adding them as further unconditional parallel branches.
- [x] **Applied to the live workflow, 2026-08-16.** `workflows_update` on
  `test-aystro-detect-classify-brand` (id `eeUDKKw0KlOkitKXDmCX`) — the
  custom `MergeBrandClasses` block and its `dynamic_blocks_definitions`
  entry are gone; the Fanta branch is now gated by `route_fanta`
  (`switch_case`) and merged via `first_non_empty_or_default`. Re-verified
  live immediately after via `workflows_run` against the same test photo:
  output identical to the pre-change baseline (same 60 brand/flavor labels),
  confirming the fix is live and correct, not just validated in a copy.
  Phase 3.5 is done for Fanta. The scratch timing workflow
  (`Test - switch-case-fanta-timing`, id `wcAqN3tElm50N91hhxWg`) is no
  longer needed and can be deleted.
- [x] **Extended to XL Energy, 2026-08-17.** Same pattern: `route_xlenergy`
  (`switch_case` on `extract_general.output == "xl_energy"`) gates
  `brand_xlenergy`, merged via a 3-way `first_non_empty_or_default`
  (`[extract_fanta, extract_xlenergy, extract_general]`, most-specific
  first). Verified live via `workflows_run` against the same real test
  photo — output identical to the pre-change baseline for every non-XL
  crop, confirming the second branch didn't disturb the first. Still open:
  Coca-Cola and Cappy once those flavor classifiers exist (Phase 1 for
  Cappy is still pending; Coca-Cola's classifier project exists but is
  waiting on real flavor-diverse data per Phase 2).
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
