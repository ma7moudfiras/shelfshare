# -*- coding: utf-8 -*-
"""English content for the Aystro shelf-auditing progress report."""

META = dict(
    title="Automated Retail Shelf Auditing: Technical Progress Update",
    subtitle="An R&D Progress Report",
    author="Mahmoud Firas Fannoun",
    org="Aystro",
    period="27 July 2026 – 17 August 2026",
    submitted="17 August 2026",
    labels=dict(trainee="Prepared by", org="Organization",
                period="Reporting Period", submitted="Date of Submission"),
    abstract_h="Executive Summary",
    refs_h="Technical References",
    fig="Figure",
    table="Table",
)

ABSTRACT = [
    "This report updates Aystro's field-training engagement on automated shelf auditing: what has been "
    "built, what has been measured, and what remains open. Since the previous revision, the staged "
    "detect-then-classify architecture has moved from a single working example (Fanta) to a repeated, "
    "proven pattern — a second brand-variant classifier (XL Energy) and a new packaging-material signal "
    "have both been trained and wired into the live pipeline the same way, and packaging material is now "
    "merged into the result the application reports, alongside brand and variant, rather than sitting in a "
    "field nobody reads.",

    "The central architectural claim — that separating \"where is a product\" from \"what product is it\" "
    "keeps catalogue growth cheap — is now supported by complexity evidence, not only cost figures. Gating "
    "variant classifiers behind a routing step cut classifier calls per photograph from growing with both "
    "product count and variant-classifier count (O(N×K)) to growing with product count alone (O(N)), "
    "measured as a 65% reduction in classification time (40.3s to 14.2s) and now holding with two "
    "independent variant classifiers, not one. Separately, adding each new variant classifier has cost "
    "hours of labelling and one small model, not a retrain of the detector or brand classifier — repeated "
    "twice, which is why the marginal cost of catalogue growth is called small and roughly constant rather "
    "than assumed from a single example.",

    "The report is equally direct about what remains open. No classifier in the current stack has a "
    "formally recorded accuracy number yet, for a specific, understood reason (Section 3), and Coca-Cola "
    "flavour variants remain blocked by a genuine data gap, re-confirmed by a second independent audit this "
    "period.",
]

SECTIONS = [

 ("1. The Business Problem", [
  ("p", "A retail brand's on-shelf presence — how many units are stocked, how they are arranged, and what "
        "share of a shelf each competitor occupies — is commercial information manufacturers and retailers "
        "pay to know, and today that information is gathered by a person walking the aisle with a clipboard "
        "or a phone. The opportunity is converting an ordinary shelf photograph into structured, trustworthy "
        "inventory data automatically, at a volume and speed manual auditing cannot reach."),
  ("p", "The technical challenge is that this is really two questions asked of every object in the "
        "photograph at once: where is it, and what is it. A system that answers both with one monolithic "
        "model must be retrained on the whole catalogue every time one product changes — that liability is "
        "what Section 2's architecture avoids, and Section 3 measures whether it actually delivers."),
 ]),

 ("2. What Was Built: The Architecture", [
  ("p", "A single model that classifies each product directly by identity must be retrained every time a "
        "new stock-keeping unit (SKU) enters the catalogue, and suffers statistically besides: a fixed pool "
        "of training images split across many brand classes starves the rarer classes (Section 3.1). The "
        "system built during this engagement instead separates the volatile part of the problem (product "
        "identity) from the stable part (object presence), narrowing the decision space one stage at a "
        "time:"),
  ("b", "Stage 1 — Detection. A class-agnostic detector locates every product under a single generic "
        "\"product\" class, regardless of brand, so it never needs retraining when a new SKU appears."),
  ("b", "Stage 2 — Brand classification. Each detected region is cropped and classified by manufacturer "
        "brand — a small, stable layer, since the set of brands changes far more slowly than the set of "
        "products."),
  ("b", "Stage 3 — Variant classification, gated. When Stage 2 identifies a brand with its own variant "
        "classifier, a routing step invokes that one classifier only — not every variant classifier on "
        "every crop. Two brands are wired this way today: Fanta (flavour) and XL Energy (flavour/format)."),
  ("b", "Stage 4 — Packaging material, unconditional. A brand-independent classifier (can / plastic / "
        "glass) runs on every crop and its result is merged into the same detection the app displays, "
        "alongside brand and variant."),
  ("p", "This is a live, hierarchical Roboflow Workflow, not a proposal. The gating in Stage 3 is the "
        "architectural change measured in Section 3.3: it keeps classifier calls from scaling with the "
        "number of variant classifiers deployed, which matters more as more brands get one."),
 ]),

 ("3. Evidence: Does It Work?", [
  ("h2", "3.1 Detector accuracy: architecture change, measured"),
  ("p", "The original brand-classed detector and the current class-agnostic detector were compared at "
        "their most mature, most fairly matched versions, both on RF-DETR-large."),
  ("table", ["Measure", "Original (brand-classed, 6 classes)", "Current (class-agnostic)"], [
      ["Training images", "1,191", "384"],
      ["mAP50", "86.92%", "89.3%"],
      ["Precision", "82.7%", "90.5%"],
      ["Recall", "85.8%", "81.1%"],
   ], "Detector accuracy, original brand-classed architecture versus the current class-agnostic "
      "architecture, both on the RF-DETR-large model."),
  ("p", "The current architecture reaches higher precision and overall accuracy on roughly a third of the "
        "training images the original approach needed. Recall is slightly lower for a known reason, not an "
        "architectural one: roughly 800 already-labelled images from the original project have not yet been "
        "migrated over. Migrating them is a programmatic relabel, not new annotation work, and remains the "
        "highest-value near-term action in this report (Section 8)."),

  ("h2", "3.2 Classifier accuracy: not yet measured, for a known reason"),
  ("p", "None of the four classifiers now live — brand, Fanta, XL Energy, packaging — has a formally "
        "recorded accuracy evaluation. The reason is a plan-tier gap: automatic model evaluation on the "
        "training platform is a paid-plan feature that runs at training time only, with no way to trigger it "
        "retroactively, and every classifier trained so far predates that entitlement. No accuracy figure is "
        "claimed anywhere in this report that has not actually been measured; closing this is the first item "
        "in Section 8."),
  ("p", "Coca-Cola flavour variants were re-examined this period by a second, independent audit — sorting "
        "all 301 available crops by dominant colour — and returned the same result as before: about 95% "
        "classic, no confirmed Zero examples. This is a photography gap, not a modelling one."),

  ("h2", "3.3 Complexity: what the routing change bought"),
  ("p", "Before this period, every classifier that could apply to a brand ran on every crop of that brand "
        "unconditionally: N detected products and K brand-specific variant classifiers meant up to N×K "
        "classifier calls. Measured on a real 60-crop photograph, the Fanta classifier ran on all 60 crops "
        "though only 12 were actually Fanta."),
  ("p", "Gating each variant classifier behind a routing step, so it only runs for crops the brand "
        "classifier has already matched to it, changes that to growth with N alone, independent of K. On the "
        "same photograph this measured a 65% reduction in classification time (40.3s to 14.2s) with "
        "identical output. The pattern was applied a second time this period, adding XL Energy alongside "
        "Fanta, and the gain holds with two variant classifiers active rather than one."),
 ]),

 ("4. Economics: The Cost to Scale", [
  ("p", "The central commercial risk in any catalogue-driven product is that growth becomes expensive. This "
        "architecture was chosen to avoid that, backed by this engagement's own measured costs, now covering "
        "five trained models."),
  ("table", ["Model", "Training time", "Training credits"], [
      ["Original detector (first version)", "11.2 min", "0.37"],
      ["Current production detector", "44.2 min", "1.48"],
      ["Brand classifier (current version)", "9.1 min", "0.30"],
      ["Fanta flavour classifier", "7.2 min", "0.24"],
      ["XL Energy variant classifier", "4.4 min", "0.15"],
      ["Packaging-material classifier", "7.0 min", "0.23"],
   ], "Actual training cost of every model in the current production stack, at Roboflow's published rate "
      "of one credit per thirty minutes of GPU training."),
  ("p", "The full five-model stack has cost roughly 2.8 credits (under ninety minutes of GPU time) to "
        "train, ever — a small fraction of a single month's allowance on the cheapest paid plan. Current "
        "dollar pricing should always be checked directly against Roboflow's published rates rather than "
        "quoted here as fixed."),
  ("p", "The more consequential number is the marginal cost of catalogue growth. Adding XL Energy variant "
        "differentiation cost the same shape of work Fanta did previously — labelling a few hundred "
        "already-available crops and training one small, routed classifier, with no change to the detector "
        "or brand classifier — completed within hours, not weeks. The same pattern applies to onboarding a "
        "new company: the database is multi-tenant by design, so a new customer is a data-entry operation, "
        "not a code change."),
  ("p", "One cost is real and not yet measured: the pipeline now issues a brand call and an unconditional "
        "packaging call for every detected product, plus a variant call when routing fires. This should be "
        "measured from live usage before it is quoted as a number (Section 6)."),
 ]),

 ("5. The Application: Field-Proven", [
  ("p", "A cross-platform application, developed alongside the model architecture, turns model output into "
        "a usable business process rather than a research demo: it standardises field capture, runs the "
        "detection pipeline against each photograph, and interposes a human reviewer between raw model "
        "output and any figure reported as fact."),
  ("p", "Since the previous revision the application has grown past initial capture-and-review into "
        "reporting the business actually asked for — a Submissions view so a company administrator can see "
        "what a field representative recorded, and a brand-to-variant Share-of-Shelf report — and packaging "
        "material now travels with the same detection the app displays and reports on, rather than sitting "
        "unused in a separate field. A low-quality capture warning was also upgraded from an easy-to-miss "
        "notification to a dialog the representative must actively dismiss."),
  ("fig", "fig4_app", "The application reviewing a live capture — 75 detections returned for one cooler, "
        "with brand-confidence shares computed beneath. The label crowding visible here is itself evidence "
        "for why a human-reviewed editor, not fully automated acceptance, is the right design for dense "
        "shelf scenes."),
 ]),

 ("6. Risks and Open Gaps", [
  ("b", "1. Classifier accuracy is unmeasured, for a known reason. All four classifiers are live with no "
        "recorded evaluation because automatic evaluation is gated behind a plan tier this workspace does "
        "not have. Closing this needs a plan upgrade."),
  ("b", "2. The detector's recall gap traces to a known cause: roughly 800 already-annotated images from "
        "the original project have not been migrated. Data-engineering work, not new research."),
  ("b", "3. Coca-Cola flavour variety does not exist in the current data, confirmed twice, months apart. "
        "The fix is targeted new photography, not relabelling — already ruled out."),
  ("b", "4. The XL Energy classifier is trained but heavily imbalanced: one class holds 85% of examples, "
        "three of five classes have under a dozen each. Live and usable, but would benefit from targeted "
        "photography of the underrepresented variants."),
  ("b", "5. Per-product inference cost at scale has not been measured. The real cost impact should come "
        "from live usage before it is used in a projection."),
 ]),

 ("7. Challenges Encountered", [
  ("p", "The hardest problem this period was diagnosing failures whose visible symptom pointed away from "
        "the real cause. The Coca-Cola flavour question looked, on the surface, like the classifier needed "
        "more training; the actual constraint was that the underlying photography does not contain the "
        "variants being asked for — visible only by auditing the training images directly, not by tuning "
        "the model."),
  ("p", "The second was a genuine platform constraint rather than a bug in this project's own work: the "
        "training platform's per-classifier accuracy evaluation runs automatically at training time only, "
        "gated behind a paid plan tier this workspace does not hold, with no way to trigger it retroactively "
        "on a finished training. That is now a known, named constraint rather than an open question, but it "
        "directly limits what can be claimed about classifier accuracy in this report."),
 ]),

 ("8. Recommendation, Next Steps, and What We Need", [
  ("p", "The recommendation is to continue the current architecture. It is measurably more accurate on a "
        "third of the training data, at a training-cost increase too small to matter across five models, "
        "and the routed-classifier pattern that keeps classifier calls from multiplying with catalogue size "
        "has now been proven twice. The open items below are specific and individually inexpensive; none "
        "point to a flaw in the underlying design."),
  ("p", "Proposed order of work: first, run the missing classifier evaluations and migrate the roughly 800 "
        "unmigrated detector images, retraining the detector against the fuller dataset — days of work, no "
        "new data collection required, closing items 1 and 2 in Section 6. Second, measure real "
        "per-photograph inference cost from live usage once volume justifies it, to keep Section 4 current "
        "rather than assumed."),
  ("p", "What would materially help: a decision on whether to fund a short, targeted photography pass — "
        "genuine Coca-Cola flavour variants and the underrepresented XL Energy variants — since both gaps "
        "are blocked by data that does not yet exist, not by engineering effort. Separately, a decision on "
        "upgrading the Roboflow plan tier that gates automatic classifier evaluation would let every "
        "classifier trained from that point forward carry a real accuracy number instead of an unmeasured "
        "one, which is currently the largest gap between what this system does and what can be formally "
        "reported about how well it does it. Guidance on what accuracy bar should count as production-ready "
        "would also directly shape the next round of tuning work."),
 ]),
]

REFERENCES = []
