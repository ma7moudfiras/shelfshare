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
    "This report updates Aystro's field-training engagement on automated shelf auditing: what has been built, "
    "what has been measured, and what remains open. Since the previous revision, the staged detect-then-"
    "classify architecture has moved from a single working example (Fanta) to a repeated, proven pattern — a "
    "second brand-variant classifier (XL Energy) and a new packaging-material signal have both been trained "
    "and wired into the live pipeline the same way, and a real production accuracy bug reported directly by a "
    "field user has been root-caused and fixed.",

    "The central architectural claim — that separating \"where is a product\" from \"what product is it\" "
    "keeps catalogue growth cheap — is now supported by complexity evidence, not only cost figures. Gating "
    "variant classifiers behind a routing step cut the number of classifier calls per photograph from "
    "growing with both product count and variant-classifier count (O(N×K)) to growing with product count "
    "alone (O(N)), independent of how many brands have their own flavour classifier. Measured on the same "
    "test photograph under identical conditions, this cut wall-clock classification time by 65% (40.3s to "
    "14.2s) and now holds with two independent variant classifiers, not one. Separately, adding each new "
    "variant classifier has cost hours of labelling and one small model, not a retrain of the detector or "
    "brand classifier — repeated twice, which is the basis for calling the marginal cost of catalogue growth "
    "small and roughly constant rather than assuming it from a single example.",

    "The report is equally direct about what remains open. No classifier in the current stack has a formally "
    "recorded accuracy number yet — the root cause is now understood precisely (Section 3) and the fix is "
    "known, not undiscovered. Coca-Cola flavour variants remain blocked by a genuine data gap, re-confirmed "
    "by a second independent audit this period, not a modelling limitation. And a real user-reported quality "
    "issue — Sprite cans going undetected or classified at very low confidence — was traced to a 9-to-1 "
    "imbalance between bottle and can training examples for that brand and corrected by mining real, "
    "previously unused historical data rather than commissioning new photography, which is the kind of fix "
    "this report treats as the more interesting result: not that a bug existed, but that the data pipeline "
    "built during this engagement made it diagnosable and fixable within one working session.",
]

SECTIONS = [

 ("1. The Business Problem", [
  ("p", "A retail brand's on-shelf presence — how many units are stocked, how they are arranged, and what "
        "share of a shelf each competitor occupies — is commercial information manufacturers and retailers "
        "pay to know, and today that information is gathered by a person walking the aisle with a clipboard "
        "or a phone. Manual audits are slow, expensive to scale across many stores, and only as consistent "
        "as the person performing them. The commercial opportunity is converting an ordinary shelf photograph "
        "into structured, trustworthy inventory data automatically, at the volume and speed manual auditing "
        "cannot reach."),
  ("p", "The technical challenge is that this is not one problem but two, asked of every object in the "
        "photograph at once: where is it (localisation), and what is it (identity). A system that answers "
        "both questions with a single monolithic model inherits a serious liability — it must be retrained "
        "on the whole catalogue every time one product changes — that determines whether the system can keep "
        "pace with a retail catalogue that never stops changing. Section 2 describes the architecture built "
        "to avoid that liability; Section 3 measures whether it actually delivers the intended benefit."),
 ]),

 ("2. What Was Built: The Architecture", [
  ("p", "A single model that classifies each product directly by identity must be retrained every time a "
        "new stock-keeping unit (SKU) enters the catalogue — expensive in annotation effort and compute, and "
        "risking regressions on products that were previously working. It also suffers statistically: a "
        "fixed pool of training images split across many brand classes starves the rarer classes, which is "
        "exactly the low-recall failure mode observed in this project's own early data (Section 3.1)."),
  ("p", "The system built during this engagement separates the volatile part of the problem (product "
        "identity, which changes constantly) from the stable part (object presence, which does not), and "
        "narrows the decision space one stage at a time:"),
  ("b", "Stage 1 — Detection. A class-agnostic detector locates every product on the shelf under a single "
        "generic \"product\" class, regardless of brand. It never needs retraining when a new SKU appears, "
        "because it holds no knowledge of identity to begin with."),
  ("b", "Stage 2 — Brand classification. Each detected region is cropped and classified by manufacturer "
        "brand. This layer is small and stable, since the set of brands in a market changes far more slowly "
        "than the set of products."),
  ("b", "Stage 3 — Variant classification, gated. When Stage 2 identifies a brand that has its own variant "
        "classifier, a routing step invokes that one classifier only — not every variant classifier on every "
        "crop. Two brands are wired this way today: Fanta (flavour) and XL Energy (flavour/format). A merge "
        "step then selects the variant label when one was produced, and passes the plain brand through "
        "unchanged otherwise."),
  ("b", "Stage 4 — Packaging material, unconditional. A brand-independent classifier (can / plastic / glass) "
        "runs on every crop regardless of brand, since packaging material does not depend on which brand a "
        "product belongs to. Trained and live this period; not yet fused into the reported label, only "
        "exposed as a separate field (Section 3.4)."),
  ("p", "This is implemented as a live, hierarchical Roboflow Workflow, not a proposal. The gating in Stage "
        "3 is the architectural change measured in Section 3.5: it is what keeps the number of classifier "
        "calls from scaling with the number of variant classifiers deployed, which matters increasingly as "
        "more brands get their own flavour classifier."),
 ]),

 ("3. Evidence: Does It Work?", [
  ("h2", "3.1 Detector accuracy: architecture change, measured"),
  ("p", "The original brand-classed detector and the current class-agnostic detector were compared at "
        "their most mature, most fairly matched versions — both trained on the same model architecture "
        "(RF-DETR-large) — rather than against an early, undertrained snapshot of either."),
  ("table", ["Measure", "Original (brand-classed, 6 classes)", "Current (class-agnostic)"], [
      ["Training images", "1,191", "384"],
      ["mAP50", "86.92%", "89.3%"],
      ["Precision", "82.7%", "90.5%"],
      ["Recall", "85.8%", "81.1%"],
   ], "Detector accuracy, original brand-classed architecture versus the current class-agnostic "
      "architecture, both on the RF-DETR-large model."),
  ("p", "The current architecture reaches higher precision and overall accuracy using roughly a third of "
        "the training images the original approach needed — a genuine data-efficiency result, not merely a "
        "design argument. Recall is slightly lower, and the honest explanation is a data-migration gap "
        "rather than an architectural weakness: the class-agnostic project currently holds only "
        "226 raw images, while the original brand-classed project had grown to 1,191 annotated images by "
        "its most mature version. Roughly 800 already-labelled images have not yet been carried over. "
        "Migrating them is inexpensive — a programmatic relabel to a single \"product\" class, not new "
        "annotation work — and remains the highest-value near-term action identified in this report "
        "(Section 8)."),

  ("h2", "3.2 Classifier accuracy: root cause identified, fix known"),
  ("p", "Every classifier in the current stack — brand, Fanta flavour, XL Energy flavour, packaging "
        "material — is trained and serving live traffic, but none has a formally recorded accuracy "
        "evaluation. This was investigated properly this period rather than left as an open question: the "
        "training platform's automatic model-evaluation step, which is what populates accuracy metrics for a "
        "classifier, is a paid-plan feature that runs automatically at training time and has no manual "
        "trigger to run afterward. Every classifier trained so far predates that entitlement, so none were "
        "evaluated when they were trained. This is a plan-tier gap, not a missing engineering step, and it "
        "affects all four classifiers identically, not one in isolation. No classifier accuracy figure is "
        "claimed anywhere in this report that has not actually been measured; closing this is the first item "
        "in Section 8."),
  ("p", "A separate classifier, for Coca-Cola flavour variants, was built and re-examined this period "
        "specifically because the question was asked again: is there real variant diversity in the data, or "
        "was the earlier finding premature? A second, independent visual audit — sorting all 301 available "
        "Coca-Cola crops by dominant colour, the strongest available signal for this distinction (classic is "
        "red, Zero is black, Diet/Light is silver) — found the same result as before: about 95% classic, "
        "zero confirmed Zero examples, and the one plausible silver cluster turned out on direct inspection "
        "to be glare on ordinary red bottles, not real cans. The conclusion is unchanged, but it is now "
        "independently re-verified rather than resting on a single earlier pass: this is a photography gap, "
        "not a labelling or modelling one."),

  ("h2", "3.3 Sprite-can detection: a real user-reported bug, root-caused and fixed"),
  ("p", "A field user reported, with real production screenshots, that Sprite cans specifically were "
        "sometimes missed entirely and sometimes classified at confidence as low as 20%, and that this had "
        "been happening for at least several days rather than being new. This is the kind of failure that "
        "only shows up against real, uncontrolled field data — training-time metrics for the classifier gave "
        "no indication of it."),
  ("p", "The cause was found by the same visual-audit method used elsewhere in this engagement: sorting a "
        "sample of the brand classifier's Sprite training images by aspect ratio. Only about 10% were "
        "genuine cans; the rest were bottles. The classifier's internal notion of \"Sprite\" was effectively "
        "bottle-shaped, which explains both symptoms the user reported. Rather than commission new can "
        "photography, the fix mined 77 real Sprite-can crops out of an older, richer dataset from the "
        "original brand-classed detector — never migrated into the classifier project — matching, rescaling, "
        "and re-cropping them at their correct coordinates before adding them to the training set. This "
        "nearly tripled the class's can representation (from roughly 10% to roughly 23% of Sprite images) "
        "without a single new photograph. The retrained classifier is live and was re-verified against a "
        "real test photograph before being considered complete."),
  ("p", "This is included as the clearest evidence in this report that fixing a real production issue does "
        "not always mean gathering new data: it can mean finding data that already exists but was never "
        "connected to where it was needed."),

  ("h2", "3.4 Packaging-material classifier: trained and live"),
  ("p", "The packaging-material signal (can, plastic, or glass), reported last time as an in-progress "
        "experiment, is now trained and wired into the live pipeline as an unconditional, brand-independent "
        "branch, since packaging material does not depend on brand. A full visual audit of the available "
        "brand-classifier crops found only two genuine glass examples across the entire corpus — far too few "
        "to train a reliable glass class — so the classifier was scoped to a two-class plastic-versus-can "
        "problem with a workable, balanced split (844 plastic, 737 can in the final trained dataset; 22 "
        "pre-existing glass-labelled images were preserved separately rather than forced into either class). "
        "Verified live against a real shelf photograph, the packaging predictions plausibly match the actual "
        "product mix on the shelf. The signal is exposed as its own field in the pipeline output; it is not "
        "yet fused into a single reported label, which is the next integration step (Section 8)."),

  ("h2", "3.5 Complexity: what the routing change actually bought"),
  ("p", "Before this period, every classifier that could apply to a brand ran on every crop of that brand, "
        "unconditionally — a photograph with N detected products and K brand-specific variant classifiers "
        "issued up to N×K classifier calls, growing in both dimensions at once. This was measured directly, "
        "not assumed: on a real 60-crop test photograph, the Fanta flavour classifier ran on all 60 crops "
        "even though only 12 were actually Fanta."),
  ("p", "Gating each variant classifier behind a routing step, so it only executes for crops the brand "
        "classifier has already identified as belonging to it, changes the call count to grow with N alone — "
        "independent of K, the number of variant classifiers deployed. On the same 60-crop test photograph "
        "under identical conditions, this measured a 65% reduction in wall-clock classification time (40.3s "
        "to 14.2s) with byte-identical output to the unconditional baseline. The result was not a one-off: "
        "the same routing pattern was applied a second time this period to add the XL Energy classifier "
        "alongside Fanta, and the gain holds with two variant classifiers active rather than one. Every "
        "further brand-variant classifier added to the pipeline is now expected to cost roughly the same "
        "fixed overhead rather than adding to every other classifier's workload."),
 ]),

 ("4. Economics: The Cost to Scale", [
  ("p", "The central commercial risk in any catalogue-driven product is that growth becomes expensive: every "
        "new SKU, every new market, every new customer could in principle demand new engineering. This "
        "architecture was specifically chosen to avoid that, and the claim is backed by this engagement's "
        "own measured costs, now covering five trained models rather than three."),
  ("table", ["Model", "Training time", "Training credits"], [
      ["Original detector (first version)", "11.2 min", "0.37"],
      ["Current production detector", "44.2 min", "1.48"],
      ["Brand classifier (current version)", "9.1 min", "0.30"],
      ["Fanta flavour classifier", "7.2 min", "0.24"],
      ["XL Energy variant classifier", "4.4 min", "0.15"],
      ["Packaging-material classifier", "7.0 min", "0.23"],
   ], "Actual training cost of every model in the current production stack, at Roboflow's published rate "
      "of one credit per thirty minutes of GPU training."),
  ("p", "The full five-model production stack has cost roughly 2.8 credits (under an hour and a half of GPU "
        "time) to train, in total, ever — a small fraction of a single month's allowance on even the "
        "cheapest paid plan. Growing from one model to five did not meaningfully raise training cost while "
        "measurably raising both accuracy and product coverage. Current dollar pricing changes independently "
        "of this report and should always be checked directly against Roboflow's published rates rather than "
        "quoted here as a fixed figure."),
  ("p", "The more consequential number is the marginal cost of catalogue growth, and this period turned a "
        "single data point into a repeated pattern: adding XL Energy variant differentiation cost the same "
        "shape of work as Fanta did previously — labelling a few hundred already-available crops and "
        "training one small classifier, wired in as a routed step, with no change to the detector or brand "
        "classifier. Both were completed within hours, not weeks, and the fixed per-addition overhead is now "
        "the complexity result in Section 3.5, not only an economic observation. The same pattern applies to "
        "onboarding an entirely new company: the backing database is multi-tenant by design, so a new "
        "customer is a data-entry operation, not a code change."),
  ("p", "One cost is real and not yet measured, and is stated here rather than left out: the pipeline now "
        "issues a brand-classification call and, unconditionally, a packaging-classification call for every "
        "detected product in a photograph, plus a variant-classification call when the routing step fires. A "
        "busy shelf with twenty products triggers meaningfully more classification calls than the original "
        "single-model approach. This should be measured directly from live workflow usage before it is "
        "quoted as a number, and remains an open item (Section 6)."),
 ]),

 ("5. The Application: Field-Proven", [
  ("p", "A cross-platform application, developed alongside the model architecture, is what turns model "
        "output into a usable business process rather than a research demo. It standardises field capture, "
        "runs the detection pipeline against each photograph, and — critically — interposes a human "
        "reviewer between raw model output and any figure that gets reported as fact."),
  ("p", "Since the previous revision the application has grown past initial capture-and-review into "
        "reporting the business actually asked for: a Submissions view so a company administrator can see "
        "what a field representative actually recorded (previously, captured data was written to the "
        "database but nothing in the application read it back), and a brand-to-variant Share-of-Shelf "
        "report giving each brand's overall percentage of shelf space broken down into the specific variants "
        "the pipeline currently distinguishes. A low-quality capture warning — a photograph shot too far "
        "from the shelf to count reliably — was also upgraded from an easy-to-miss notification to a dialog "
        "the representative must actively dismiss, directly reducing a source of silent undercounting in the "
        "field."),
  ("fig", "fig4_app", "The application reviewing a live capture — 75 detections returned for one cooler, "
        "with brand-confidence shares computed beneath. The label crowding visible here is itself real "
        "evidence for why a human-reviewed editor, not fully automated acceptance, is the right design for "
        "dense shelf scenes."),
 ]),

 ("6. Risks and Open Gaps", [
  ("p", "Stated in the order they should be closed, with the honest reason each remains open:"),
  ("b", "1. Classifier accuracy is unmeasured, for a known and specific reason. All four classifiers in the "
        "current stack are live with no recorded evaluation, because automatic evaluation is gated behind a "
        "plan tier this workspace does not currently have. Closing this requires either a plan upgrade or "
        "accepting no accuracy figure can be cited for now — it is not an open research question."),
  ("b", "2. The detector's recall gap traces to a specific, known cause. Roughly 800 already-annotated "
        "images from the original project have not been migrated into the class-agnostic one. This is a "
        "data-engineering task, not new research."),
  ("b", "3. Coca-Cola flavour variety does not exist in the current data, confirmed twice. Two independent "
        "audits, months apart, found the same result: the available photographs are almost entirely one "
        "variant. The fix is targeted new photography of the missing variants, not relabelling existing "
        "images, which has already been ruled out."),
  ("b", "4. The XL Energy variant classifier is trained but heavily imbalanced. One class (xl-classic) holds "
        "85% of the labelled examples; three of the five classes have fewer than a dozen examples each. It "
        "is live and usable but would benefit from targeted photography of the underrepresented variants, "
        "the same category of gap as item 3."),
  ("b", "5. Per-product inference cost at scale has not been measured. The pipeline now issues a brand call, "
        "an unconditional packaging call, and sometimes a variant call for every detected product; the real "
        "cost impact should be measured from live usage before it is used in a cost projection."),
  ("b", "6. Packaging material is measured but not yet fused into the reported label. The field exists in "
        "the pipeline output and has been verified live, but the application does not yet combine it with "
        "brand and variant into one final classification — that integration work is not started."),
 ]),

 ("7. Challenges Encountered", [
  ("p", "The two hardest problems this period were not algorithmic; they were about figuring out what the "
        "data and the platform were actually doing, as opposed to what they were assumed to be doing."),
  ("p", "The first was diagnosing failures whose visible symptom pointed away from the real cause. The "
        "Sprite-can issue looked, from the user's report alone, like it could be a detector problem, a "
        "confidence-threshold problem, or a labelling error — it took an aspect-ratio audit of the actual "
        "training images to find that it was a class-composition imbalance (roughly nine bottle examples for "
        "every can example), which is not visible from looking at the model's predictions or its training "
        "metrics, only from looking directly at what the model was shown during training. The same pattern "
        "held for the Coca-Cola flavour question: the intuitive read was \"the classifier needs more "
        "training,\" but the actual constraint was that the underlying photography does not contain the "
        "variants being asked for. Both cases point to the same lesson — when a model underperforms on a "
        "specific class, auditing that class's training data directly is more informative than tuning the "
        "model."),
  ("p", "The second was a genuine platform constraint rather than a bug in this project's own work: the "
        "training platform's per-classifier accuracy evaluation only runs automatically at training time and "
        "only on a paid plan tier this workspace does not currently hold, with no way to trigger it "
        "retroactively on an already-finished training. This means every classifier trained to date — brand, "
        "Fanta, XL Energy, packaging — has zero measured accuracy, not because evaluation was skipped, but "
        "because the platform never ran it. Discovering this took ruling out several more likely-looking "
        "explanations first (a missing manual step, a tool limitation) before confirming it against the "
        "platform's own documented feature tiers. This is now a known, named constraint rather than an open "
        "question, but it directly limits what can be claimed about classifier accuracy in this report."),
  ("p", "A third, smaller challenge was working within a hosted platform's real limits during large data "
        "operations — for example, bulk-relabelling over a thousand images for the packaging-material "
        "classifier surfaced session- and permission-scoping behaviour that was not obvious in advance and "
        "had to be worked around mid-task. None of these were architecturally significant, but they were a "
        "reminder that a meaningful share of this kind of engineering work is discovering how the underlying "
        "platform actually behaves, not only writing the pipeline logic on top of it."),
 ]),

 ("8. Recommendation, Next Steps, and What We Need", [
  ("p", "The recommendation is to continue the current architecture. The evidence in this report is that it "
        "is not a trade-off between cost and accuracy against the original approach — it is measurably more "
        "accurate on a third of the training data, at a training-cost increase too small to matter across "
        "five models, and the routed-classifier pattern that keeps classifier calls from multiplying with "
        "catalogue size has now been proven twice, not once. The open items below are specific and "
        "individually inexpensive; none of them point to a flaw in the underlying design."),
  ("p", "Proposed order of work: first, run the missing classifier evaluations and migrate the roughly 800 "
        "unmigrated detector images, retraining the detector against the fuller dataset — both are days of "
        "work with no new data collection required and directly close items 1 and 2 in Section 6. Second, "
        "fuse the packaging-material signal into the single reported classification alongside brand and "
        "variant, since the signal itself is already live and verified — this is engineering, not research. "
        "Third, measure real per-photograph inference cost from live usage once volume justifies it, to keep "
        "the economics in Section 4 current rather than assumed."),
  ("p", "What would materially help over the next stretch: a decision on whether to fund a short, targeted "
        "photography pass — specifically genuine Coca-Cola flavour variants, glass-packaged products, and "
        "the underrepresented XL Energy variants (mojito, double-kick, sugar-free) — since all three gaps are "
        "blocked by data that does not yet exist, not by engineering effort, and no amount of further "
        "modelling work will close them. Separately, a call on whether to upgrade the Roboflow plan tier that "
        "gates automatic classifier evaluation would let every classifier trained from that point forward "
        "carry a real accuracy number instead of an unmeasured one, which is currently the single largest gap "
        "between what this system does and what can be formally reported about how well it does it. Guidance "
        "on what accuracy bar should count as production-ready — since the right operating point for shelf "
        "auditing, and therefore how often the system should defer to human review, is a commercial judgement "
        "as much as a technical one — would also directly shape the next round of tuning work."),
 ]),
]

REFERENCES = [
 "Dosovitskiy, A., Beyer, L., Kolesnikov, A., et al. (2021). An Image is Worth 16x16 Words: Transformers "
 "for Image Recognition at Scale. International Conference on Learning Representations (ICLR). "
 "— architecture family (ViT) underlying the brand and variant classifiers in Stages 2–4.",

 "Ren, S., He, K., Girshick, R., & Sun, J. (2015). Faster R-CNN: Towards Real-Time Object Detection with "
 "Region Proposal Networks. Advances in Neural Information Processing Systems (NeurIPS). "
 "— background for the detect-then-classify architectural pattern underlying Stage 1.",

 "Roboflow. Workflows Documentation. https://inference.roboflow.com/workflows/ (accessed August 2026). "
 "— the platform the production pipeline in Section 2 is implemented on, including the routing "
 "(\"switch case\") and branch-merge blocks used in Section 3.5.",

 "Roboflow. Pricing and Credits. https://roboflow.com/pricing (accessed August 2026). "
 "— source for the credit rates used in Section 4; consult directly for current dollar pricing.",
]
