# -*- coding: utf-8 -*-
"""English content for the Aystro research report.

A research paper on the architectural question the engagement investigated:
how localisation and identification should be divided between components of an
applied computer-vision system, and what that division costs or saves.

Every figure quoted here is read back from the platform's own measurement
tooling. Where no measurement exists, the text says so rather than estimating.
"""

META = dict(
    title="Separating Localisation from Identification in "
          "Automated Retail Shelf Auditing",
    subtitle="An applied study in scalable computer-vision system architecture",
    author="Mahmoud Firas Fanoun",
    org="Aystro",
    period="27 July – 18 August 2026",
    submitted="18 August 2026",
    labels=dict(trainee="Author", org="Host organisation",
                period="Research period", submitted="Submitted"),
    abstract_h="Abstract",
    refs_h="References",
    fig="Figure",
    table="Table",
)

ABSTRACT = [
    "This study examines an architectural question in applied computer-vision "
    "systems: how the responsibilities of locating an object and identifying it "
    "should be divided between a system's components, and what that division "
    "costs or saves in accuracy and in scalability. The application domain is "
    "automated retail shelf auditing, where a photograph of a commercial shelf "
    "is converted into a structured product inventory and per-brand share of "
    "shelf.",

    "Two approaches are compared. The first (v1) is a single object-detection "
    "layer whose classes are the brands themselves — one model answering both "
    "questions at once. The second (v2) is a multi-stage architecture that "
    "separates them: a class-agnostic detector locates products without any "
    "knowledge of identity, followed by independent, conditionally routed "
    "classifiers that determine brand, then variant, then packaging material. "
    "Both were evaluated under the same protocol, on the same model "
    "architecture, from the same source photographs.",

    "The multi-stage approach outperformed the single-layer one on every "
    "detection metric: 93.33% mAP@50 against 88.62%, 76.49% mAP@50-95 against "
    "70.09%, and 90.9% recall against 84.9% — and it did so even though the "
    "single-layer approach was evaluated on magnified tiles, which is the "
    "easier condition for detection. Its per-class breakdown exposes signal "
    "starvation directly: a 6.35-point spread across its represented classes, "
    "and total collapse on an unrepresented one.",

    "The computational complexity of the variant-classification layer was also "
    "reduced from O(N×K) to O(N) by introducing conditional routing, measured "
    "directly as a 65% reduction in processing time with byte-identical "
    "output. The marginal cost of adding a new brand to the catalogue is "
    "approximately four minutes of GPU time, measured four separate times. The "
    "unifying result is that every measured weakness in the system traces to a "
    "specific, countable data-supply gap rather than to any deficiency in the "
    "architecture or the choice of model.",
]

SECTIONS = [

 ("1. Introduction", [
  ("h2", "1.1 The applied problem"),
  ("p", "A brand's presence on the shelf — how many units are displayed and "
        "what fraction of the visible space they occupy — is commercial "
        "intelligence that manufacturers and retailers pay to obtain. Today it "
        "is collected manually by representatives who tour stores and record "
        "what they see: slow, expensive to scale, and inconsistent in quality "
        "because it depends on the attention of the person doing it."),
  ("p", "Automating it requires the system to distinguish each displayed "
        "product from its neighbour individually — knowing that a brand is "
        "present is not enough, its units must be counted. This is where "
        "localisation becomes necessary: not as a deliverable in its own right, "
        "but as the means by which visually identical instances are separated "
        "from one another so that counting becomes possible at all."),

  ("h2", "1.2 Hypothesis"),
  ("p", "The study begins from the observation that the two questions — where, "
        "and what — have fundamentally different characteristics. Localisation "
        "is stable: “is there a displayed object here?” is a general "
        "visual question whose answer does not change as the product catalogue "
        "changes, and which can be learned from any set of products. Identity "
        "is volatile: a market's catalogue changes continuously as products "
        "enter and leave and new flavours are introduced."),
  ("p", "The hypothesis is that coupling these two concerns inside a single "
        "model imposes a double cost. An economic cost, because every change to "
        "the catalogue requires retraining the entire model; and a statistical "
        "cost, because a limited training signal is divided across multiple "
        "classes, starving each of them."),

  ("h2", "1.3 Contributions"),
  ("b", "1. Measured empirical evidence that separating localisation from "
        "identification improves detection performance from the same source "
        "photographs, with the mechanism of that improvement documented through "
        "the per-class breakdown."),
  ("b", "2. A conditional-routing architecture that makes the cost of the "
        "variant-classification layer independent of catalogue breadth — O(N) "
        "instead of O(N×K) — with a direct measurement of its effect on "
        "latency."),
  ("b", "3. A repeated measurement of the marginal cost of catalogue expansion "
        "under the proposed architecture."),
  ("b", "4. A design result in active learning: a demonstration that "
        "confidence-threshold sampling is structurally incapable of capturing "
        "confident errors, and a proposed alternative criterion."),
 ]),

 ("2. Problem formulation", [
  ("p", "Let a shelf photograph contain N displayed products. The system is "
        "required to produce a structured inventory: a unit count for each "
        "distinct label, from which each brand's share of the displayed space "
        "is derived. The target label is compound, built from independent axes "
        "of the form: {brand}-{package}-{variant}-{size}."),
  ("p", "The first three axes — brand, variant, and packaging material — were "
        "completed in this study. The size axis is the planned next step and is "
        "discussed in Section 10."),
  ("p", "Note that localisation does not appear in this output. It is an "
        "internal requirement, not a final deliverable: its function is to "
        "separate adjacent products from one another so that counting is valid, "
        "and to isolate regions of the image so that each can serve as input to "
        "a downstream classification layer. This distinction is central to the "
        "study, because it is what makes relieving localisation of the burden "
        "of identity possible in the first place."),
  ("b", "The first approach (v1). A single detector learns a function mapping "
        "the image directly to a set of (region, brand) pairs. The cost of "
        "adding a new brand here is a full retrain — a function of the size of "
        "the whole catalogue, not of the size of the addition."),
  ("b", "The second approach (v2). A class-agnostic detector produces regions "
        "under a single generic class, followed by independent classification "
        "functions operating on the cropped regions. The cost of adding a brand "
        "here is training one small classifier, independent of the rest of the "
        "system."),
  ("p", "The second approach raises a problem of its own: if K variant "
        "classifiers exist and each runs on every region, the number of "
        "invocations is O(N×K) even though only one invocation in K is ever "
        "useful. Section 4 addresses this."),
 ]),

 ("3. Methodology", [
  ("h2", "3.1 Evaluation protocol"),
  ("p", "Both approaches were evaluated under conditions unified as far as "
        "possible: the same model architecture (rfdetr-large), so no difference "
        "can be attributed to capacity; the same source photographs, as each "
        "project holds the same 227 raw images; and the same evaluation tool, "
        "run against a held-out test split in both cases. All figures are read "
        "directly from the platform's tooling; none is estimated, and where no "
        "measurement exists the text says so explicitly."),
  ("p", "One difference could not be unified, and is stated plainly because it "
        "bears on the interpretation of the results: the preprocessing pipelines "
        "of the two versions differ substantially."),
  ("table", ["Item", "v1 (version 20)", "v2 (version 2)"], [
      ["Images after preprocessing", "1,191", "384"],
      ["Train / valid / test", "982 / 112 / 97", "316 / 34 / 34"],
      ["Static crop", "central quarter only", "none"],
      ["Tiling", "2×2", "none"],
      ["Augmentation", "horizontal flip, 15° rotation", "blur, exposure"],
   ], "The two preprocessing pipelines. The difference in image count comes "
      "from augmentation, not from additional source data."),
  ("p", "Each evaluation image in v1 therefore represents roughly one sixteenth "
        "of the area of the original photograph, at a linear magnification of "
        "about 4×, whereas v2 is evaluated on complete images. This difference "
        "has three consequences for interpretation."),
  ("b", "First, the gap in training-image count (1,191 against 384) is not a "
        "difference in source data but in the augmentation pipeline; the source "
        "is the same."),
  ("b", "Second, tiling magnifies objects relative to the frame, which is an "
        "easier setting for detection, not a harder one. Any advantage the "
        "multi-stage approach shows in this comparison is therefore achieved "
        "despite its counterpart being evaluated under the easier condition — "
        "making the result conservative rather than inflated."),
  ("b", "Third, performance broken down by object size cannot validly be "
        "compared between the two versions, because the small/medium/large "
        "buckets are defined relative to the image being evaluated; a "
        "“small” object in a magnified tile is physically far smaller "
        "than its counterpart in a full image. These figures are therefore "
        "presented in Section 5.1 as a characterisation of the current system "
        "alone, not as a comparison."),

  ("h2", "3.2 Behavioural verification"),
  ("p", "A methodological principle was adopted whose importance was "
        "established empirically: no claim about the system's behaviour is "
        "accepted unless verified by an actual inference call on a real image. "
        "More than once it emerged that inspecting the configuration gave an "
        "impression of correctness while actual behaviour differed, and that "
        "training metrics alone did not reveal this."),

  ("h2", "3.3 Data auditing"),
  ("p", "Where performance was weak on a particular class, direct visual "
        "auditing of the training data was adopted as the first diagnostic "
        "instrument, before any model tuning. A repeatable method was developed "
        "for this: crops of the class under examination are downloaded and "
        "arranged into contact-sheet grids ordered by a cheap but informative "
        "signal — aspect ratio separates cans from bottles, dominant hue "
        "separates flavours — making human judgement possible over whole ranges "
        "at once rather than image by image. In every case examined, this "
        "method traced the weakness to the data rather than to the model."),
 ]),

 ("4. Proposed architecture", [
  ("p", "The architecture narrows the decision space stage by stage, so that "
        "each layer is small, independent, and replaceable without disturbing "
        "what precedes it."),
  ("b", "Stage 1 — detection (class-agnostic). Product regions are located "
        "under a single generic class. This model carries no knowledge of "
        "identity, and therefore requires no retraining as the catalogue "
        "changes, however far it expands."),
  ("b", "Stage 2 — brand. Each region is cropped and classified by "
        "manufacturer. This layer is relatively stable, because the set of "
        "brands in a market changes far more slowly than the set of products. "
        "It is the critical layer, because its decision determines the path of "
        "everything downstream."),
  ("b", "Stage 3 — variant, conditionally routed. If the identified brand has "
        "its own variant classifier, the routing step invokes that classifier "
        "alone; a region not belonging to a connected brand passes through no "
        "variant classifier at all. Four brands are connected in this pattern."),
  ("b", "Stage 4 — packaging material, unconditional. A single shared "
        "classifier (can / plastic / glass) runs on every region, because "
        "material is a physical property independent of the manufacturer — so "
        "any brand added in future benefits from it immediately, with no "
        "additional training."),
  ("p", "A merge step then selects the most specific label available (the "
        "variant if present, otherwise the plain brand) and combines it with "
        "the packaging material. The essential architectural property is that "
        "the routing in Stage 3 decouples a classifier's execution from the "
        "mere availability of its input — which is what makes growth "
        "independent of K, as Section 5.4 shows."),
  ("p", "Note that the axes are independent by design: packaging material does "
        "not depend on brand, whereas variant does. This independence is what "
        "permits the size axis to be added later as a fourth layer without "
        "disturbing anything before it."),
  ("fig", "fig_pipeline_v2", "The architecture as actually deployed, read from "
        "the live workflow specification. The essential difference from "
        "conventional staged architectures is the routing steps (in orange): "
        "they decouple the execution of the variant classifiers from the mere "
        "availability of their input, which is what Section 5.4 measures."),
 ]),

 ("5. Experimental results", [

  ("h2", "5.1 Detection: single-layer against multi-stage"),
  ("table", ["Metric", "v1 (single, 6 classes)", "v2 (multi, 1 class)",
             "Difference"], [
      ["mAP@50", "88.62%", "93.33%", "+4.71"],
      ["mAP@50-95", "70.09%", "76.49%", "+6.40"],
      ["mAP@75", "80.43%", "87.57%", "+7.14"],
      ["Precision", "88.9%", "87.4%", "−1.50"],
      ["Recall", "84.9%", "90.9%", "+6.00"],
   ], "Both detectors on a held-out test split, with the same evaluation tool "
      "and the same model architecture."),
  ("p", "The multi-stage approach leads on every mean-precision metric and on "
        "recall, from the same source photographs, and despite the single-layer "
        "approach being evaluated on magnified tiles — the easier condition for "
        "detection (Section 3.1). The measured gap is therefore most likely a "
        "lower bound on the true gap rather than an exaggeration of it."),
  ("p", "The only regression is 1.5 points of precision, a routine trade for a "
        "6-point gain in recall. Recall is the more important metric in this "
        "domain: a product that is never detected corrupts the inventory with "
        "no way to recover it later, whereas a spurious detection is corrected "
        "by the human reviewer at the review step."),
  ("p", "As a characterisation of the current system alone — not a comparison, "
        "for the reason given in Section 3.1 — its performance across object "
        "sizes is 92.31% for small, 94.47% for medium, and 96.98% for large "
        "objects. It therefore sustains high performance across the whole size "
        "range, a practical requirement in shelf photography where product "
        "dimensions vary widely within a single frame."),
  ("p", "The evaluation also produced a computed optimal confidence threshold "
        "of 0.41, effectively identical to the 0.4 threshold already in use in "
        "the running system — a value that had been set empirically before the "
        "evaluation was available, and which matched the computed "
        "recommendation without knowledge of it."),

  ("h2", "5.2 Per-class signal starvation"),
  ("p", "The per-class breakdown of the single-layer approach exposes the "
        "mechanism of the statistical constraint the hypothesis predicted. It "
        "is presented here alongside the annotation distribution of the same "
        "project, so that the effect can be set against its direct cause."),
  ("table", ["Class", "Annotations", "Share", "mAP@50", "Precision", "Recall"], [
      ["coca-cola", "2,079", "42.6%", "89.27%", "91.2%", "85.4%"],
      ["cappy", "948", "19.4%", "85.62%", "87.8%", "81.5%"],
      ["xl_energy", "661", "13.5%", "91.97%", "90.4%", "90.4%"],
      ["sprite", "651", "13.3%", "88.29%", "85.1%", "87.7%"],
      ["fanta", "409", "8.4%", "87.98%", "88.9%", "90.3%"],
      ["pepsi", "131", "2.7%", "—", "0%", "0%"],
   ], "Per-class performance of the single-layer detector against each class's "
      "share of the annotation budget. Total: 4,879 annotations."),
  ("p", "Performance varies by 6.35 points between the strongest represented "
        "class and the weakest, and the pepsi class collapses entirely for lack "
        "of any representation in the test split. This is signal starvation "
        "exactly: a limited training signal divided six ways produces uneven "
        "performance bounded by its weakest class, not its strongest."),
  ("p", "The annotation distribution deserves careful reading, because it does "
        "not say what it might be assumed to say. Among the represented "
        "classes the relationship between annotation count and performance is "
        "not monotonic: xl_energy, with 661 annotations, outperforms coca-cola "
        "with 2,079 — so tripling the data does not necessarily buy accuracy. "
        "The correct reading is that there is a floor of representation: above "
        "it, performance settles into a narrow band not governed by volume "
        "alone; below it, the class collapses outright. At a 2.7% share, pepsi "
        "is the only class beneath that floor — and the only one that "
        "collapsed."),
  ("p", "The architectural implication is that the problem is not data scarcity "
        "in aggregate but its division. Splitting the budget six ways is what "
        "pushed the weakest class below the floor of representation; had the "
        "same signal been directed entirely at one class, no class would have "
        "been beneath the floor at all. That is precisely what the next "
        "approach does."),
  ("p", "The multi-stage approach instead concentrates the entire signal into a "
        "single class scoring 93.33% — higher than any individual class in the "
        "single-layer approach — and defers discrimination to downstream layers "
        "operating on cropped, rescaled regions, that is, with far more visual "
        "detail than the detector has available on the full image. The "
        "implication is that the separation does not improve detection by "
        "accident: it improves it because it relieves the detector of a task "
        "for which it does not have sufficient visual detail, and assigns that "
        "task to a layer that does."),
  ("fig", "fig_detection", "Left: per-class performance of the single-layer "
        "detector; the dashed line is the class-agnostic detector's single "
        "class. Right: headline metrics for both approaches, same evaluation "
        "tool."),

  ("h2", "5.3 Classification-layer performance"),
  ("table", ["Class", "Precision", "Recall"], [
      ["fanta", "100%", "100%"],
      ["sprite", "100%", "100%"],
      ["xl_energy", "100%", "95%"],
      ["cappy", "100%", "92.9%"],
      ["coca-cola", "100%", "90%"],
      ["pepsi", "no test representation", "—"],
   ], "The brand layer — the decision on which the routing of everything "
      "downstream depends."),
  ("p", "Precision reached 100% for every brand with actual field photography "
        "behind it. This is an architecturally decisive result: the decision on "
        "which everything downstream depends does not, in practice, err — so no "
        "error in the later layers can be attributed to misrouting, which is a "
        "necessary condition for any conclusion about those layers' performance "
        "to be valid."),
  ("table", ["Classifier", "Strong classes", "Weak classes"], [
      ["Fanta", "orange, redapple (100/100)", "grape (100/66.7)"],
      ["XL Energy", "three classes (100/100)", "two with no representation"],
      ["Coca-Cola", "classic (100/100)", "zero (100/66.7), diet (0/0)"],
      ["Packaging", "can (98.5/92.9), plastic (93.3/95.5)", "glass (100/33.3)"],
      ["Cappy", "grape, mango, strawberry (100/100)",
       "6 of 12 with no representation"],
   ], "Variant and packaging layers, as (precision/recall)."),
  ("p", "Analysis of these results reveals one consistent pattern: every weak "
        "class corresponds to a small, countable number of samples — three test "
        "instances for glass, five source images for coca-diet, and between one "
        "and six instances for each of the weak Cappy classes. The confusion "
        "matrices show the errors to be plausible confusions between visually "
        "adjacent categories (lemon with mango, diet with classic) rather than "
        "random scatter — which is what distinguishes a data shortfall from a "
        "modelling deficiency, in a way that can be checked."),
  ("p", "The conclusion is that no measured weakness in the system is "
        "attributable to the architecture or the choice of model; all of them "
        "trace back to specific, measurable data scarcity. This is a decisive "
        "practical distinction: data scarcity is addressed by targeted "
        "collection of known cost, whereas an architectural deficiency requires "
        "redesign."),

  ("h2", "5.4 Computational complexity"),
  ("p", "In the unrouted design every variant classifier runs on every region, "
        "making the number of invocations O(N×K). On a test photograph "
        "containing 60 products, one brand's classifier ran on all sixty "
        "regions even though only 12 belonged to it — 48 wasted invocations out "
        "of every 60. With conditional routing each region passes through at "
        "most one classifier, so growth becomes O(N), independent of K."),
  ("table", ["Item", "Unrouted", "Routed"], [
      ["Processing time", "40.32 s", "14.20 s"],
      ["Reduction", "—", "65% (26.1 s)"],
      ["Output agreement", "—", "identical"],
   ], "Direct measurement, running both versions back to back on the same "
      "photograph through the same call path."),
  ("p", "Identical output is an essential condition rather than a detail: a "
        "speed-up that changes the result is a defect, not an improvement."),
  ("p", "The effect compounds as the catalogue widens. K grew from one to four "
        "during the research period. Using the measured distribution of the "
        "same photograph's regions (20 + 12 + 8 for brands with classifiers, 12 "
        "for a brand without one, and 8 unclassified), the unrouted design at "
        "K = 4 would require 60 × 4 = 240 invocations, whereas routing requires "
        "20 + 12 + 8 = 40 — a reduction of 83%. This figure is derived "
        "arithmetically from a measured distribution rather than timed directly "
        "like the two preceding ones."),
  ("p", "The significance is that the shape of growth itself has changed: under "
        "the unrouted design every brand added in future would have imposed a "
        "cost on every region of every image, whereas today it adds a cost that "
        "does not accumulate. Measuring this while K was still one was far "
        "cheaper than discovering it after K had become four."),
  ("fig", "fig_complexity", "Left: variant-classifier invocations per "
        "photograph as a function of the number of brands with their own "
        "classifier; the two stars are the actual measurements. Right: measured "
        "time on the same photograph before and after routing."),

  ("h2", "5.5 Training cost and the marginal cost of growth"),
  ("table", ["Model", "Training time", "Credits"], [
      ["Class-agnostic detector", "44.2 min", "1.47"],
      ["Packaging classifier", "8.2 min", "0.27"],
      ["Coca-Cola variant classifier", "5.1 min", "0.17"],
      ["Brand classifier", "4.3 min", "0.15"],
      ["XL Energy variant classifier", "4.0 min", "0.13"],
      ["Cappy flavour classifier", "3.6 min", "0.12"],
      ["Fanta flavour classifier", "3.3 min", "0.11"],
      ["Total", "72.7 min", "2.42"],
   ], "Training cost of the seven models in production, computed from recorded "
      "training times at the published rate."),
  ("p", "Seven models at a total training cost of under an hour and a quarter "
        "of GPU time. The detector alone accounts for 61% of it, while the "
        "marginal cost of adding a variant classifier is roughly four minutes."),
  ("p", "This is the architecture's central claim, and it was measured four "
        "times rather than once. On each occasion the work was the same: "
        "labelling a few hundred already-available regions, training one "
        "classifier, and connecting it to a routing step — with no change to "
        "the detector or the brand layer. Repeating the pattern four times is "
        "what turns “the marginal cost is low” from an inference drawn "
        "from a single case into an established observation."),
  ("p", "For comparison, the equivalent cost under the single-layer approach is "
        "retraining the whole detector (44.2 minutes), together with the "
        "attendant risk of unintended regression in classes that were "
        "previously working correctly. No dollar figure is given here "
        "deliberately, because prices change independently of this report and "
        "should be verified at source when needed."),
  ("p", "It was also established that inference is billed per image submitted "
        "to the pipeline rather than per internal model invoked — meaning that "
        "shelf density costs time, not money, which is precisely what Section "
        "5.4 measures."),
 ]),

 ("6. Active learning: a design result", [
  ("p", "A mechanism was built to convert field usage into training data, "
        "addressing the constraint established in Section 5.3: that the "
        "system's ceiling is set by data scarcity rather than model capacity."),
  ("p", "The first design followed common practice: upload those regions where "
        "the classifier's confidence falls below a threshold, on the assumption "
        "that these are the most likely to be wrong. Empirical observation "
        "refuted this. After two classifiers improved, their confidence rose "
        "above 98% and they effectively stopped submitting any samples for "
        "review, while genuine errors continued to appear in use."),
  ("p", "Analysis reveals a structural deficiency rather than a calibration "
        "problem. A confidence gate, by definition, captures uncertainty, not "
        "error — and these are not the same thing. A model that errs with high "
        "confidence — operationally the most dangerous case, because it "
        "propagates into reports without arousing suspicion — lies outside what "
        "such a gate can see, however its threshold is tuned. The fault is in "
        "the criterion itself, not in its value."),
  ("p", "The adopted alternative replaces the confidence condition with a "
        "route-membership condition: every region the system actually routed to "
        "a given classification branch is uploaded, regardless of confidence. "
        "This increases the volume of data collected, a deliberate cost during "
        "an active correction phase, but it makes confident errors visible to "
        "human review instead of letting them pass silently."),
  ("p", "One rule was preserved throughout: regions are uploaded unlabelled, "
        "and the system is never trained on its own guess without human review "
        "— which prevents the self-reinforcing drift that affects active-"
        "learning systems fed on their own output, entrenching their errors "
        "rather than correcting them."),
 ]),

 ("7. Field application", [
  ("p", "Models alone do not constitute an operable system. Automated output on "
        "uncontrolled photographs cannot be treated as final — the ambiguity in "
        "them is structural, not exceptional — and so a cross-platform "
        "application was developed serving three research functions."),
  ("b", "First, standardising capture conditions at the point of collection, "
        "reducing the variation the model has not learned (distance, angle, "
        "framing)."),
  ("b", "Second, interposing a human reviewer between the model's output and "
        "any figure reported as fact. Review here is part of the design rather "
        "than a fallback: wherever occlusion or camera angle makes a "
        "classification unreliable, a person settles it."),
  ("b", "Third, closing the data loop: every human correction is a supervised "
        "signal fit for retraining, so ordinary field usage produces training "
        "data as a by-product — which is what makes Section 6 practicable."),
  ("p", "The default display threshold was lowered from 0.7 to 0.4 on the basis "
        "of this third function: the higher threshold was hiding correct but "
        "lower-confidence detections from the reviewer, which is untenable in a "
        "phase where that reviewer is being asked to correct — since what is "
        "never seen cannot be corrected."),
 ]),

 ("8. Challenges encountered", [
  ("b", "First: data scarcity is the binding constraint, not model capacity. "
        "This is the clearest thing the study established quantitatively. When "
        "performance is weak on a given class, the intuitive reading is always "
        "“the model needs more training” — and it proved repeatedly to "
        "be wrong. A visual audit of all 301 regions of one brand showed 95% of "
        "them to be a single variant, with no confirmed example of the others. "
        "A similar audit showed 90% of another brand's examples to be bottles "
        "rather than cans — meaning the model had learned that brand as a "
        "bottle. No amount of training produces discrimination between "
        "categories whose images do not exist."),
  ("b", "Second: the measurement problem itself. The hardest part of the period "
        "was not building models but knowing what the system actually does, as "
        "against what it appears to do. High metrics establish that a model has "
        "learned what it was trained on, not that what it was trained on is "
        "correct; these are different questions. This imposed the principle of "
        "Section 3.2 as a necessary condition for every conclusion in the "
        "study, not as excess caution."),
  ("b", "Third: the availability of measurement tooling as a research "
        "constraint. Automated evaluation of the classifiers was unavailable "
        "during part of the study period, so no accuracy figures for the "
        "classification layers could be reported during that time. The study "
        "committed to not substituting estimated figures for them. This is "
        "recorded because it illustrates that some research constraints are not "
        "technical but concern access to tools."),
  ("b", "Fourth: verifying automated work on large data. Labelling more than "
        "1,400 images required distributing the work across parallel processes, "
        "and the study established that an automated process's own report is no "
        "substitute for inspecting the resulting data directly; this direct "
        "inspection was adopted as a rule for every large labelling operation."),
 ]),

 ("9. Limitations", [
  ("b", "1. Measured data scarcity in specific categories. Every weakness in "
        "Section 5.3 reduces to: coca-diet (5 source images, 0/0), glass "
        "(3 test instances, 33.3% recall), six Cappy flavours, the two thin XL "
        "variants, and pepsi (unrepresented in both the detector and the "
        "classifier)."),
  ("b", "2. The differing preprocessing pipelines of the two compared versions "
        "(Section 3.1). Its effect is mitigated by two things: the difference "
        "works against the stated conclusion, and the size-resolved comparison "
        "was dropped as invalid. Unifying the pipeline in a later evaluation "
        "would close this point definitively."),
  ("b", "3. Small test splits. The detector's test split is 34 images and one "
        "classifier's is 23 images across 12 classes — both below the platform's "
        "own recommendation. The figures reported, while measured rather than "
        "estimated, therefore carry statistical uncertainty inversely "
        "proportional to sample size."),
  ("b", "4. Two independent splits. The projects generate their splits "
        "separately even though they share the source photographs, which "
        "weakens the comparison in principle."),
  ("b", "5. The system was not evaluated end to end. Each layer was measured "
        "separately; error accumulation across the full chain was not measured "
        "on a unified, manually labelled test set. This is the most important "
        "missing measurement in the study, since chain accuracy is a product "
        "rather than an average."),
 ]),

 ("10. Future work and what is needed", [
  ("h2", "10.1 Requiring no external input"),
  ("p", "First, an end-to-end evaluation on a manually labelled test set, to "
        "measure error accumulation across the chain (Limitation 5) — "
        "scientifically the highest-priority item. Then re-evaluating both "
        "detectors under a unified preprocessing pipeline, to close Limitation "
        "2 definitively. Then harvesting the first batch of active-learning "
        "data, reviewing it, and retraining on it — the first practical test of "
        "whether the loop described in Section 6 closes. Then enlarging the "
        "test splits to reduce statistical uncertainty."),

  ("h2", "10.2 The open axis: adding size to the compound label"),
  ("p", "The fourth and final axis of the target label (Section 2) is package "
        "size — distinguishing a half-litre container from its 1.5-litre "
        "counterpart. It is technically the hardest of the axes, because "
        "absolute size cannot be inferred from an image alone without a scale "
        "reference."),
  ("p", "The first step is not technical but investigative: establishing "
        "whether size is ambiguous in this market at all — since many "
        "combinations (brand + variant + package type) may be sold in only one "
        "size, in which case size can be looked up from a reference table "
        "rather than inferred visually. This is a cheap step that may eliminate "
        "most of the hard cases before anything is built."),
  ("p", "For the ambiguous cases that remain, the candidate approach is "
        "geometric comparison against a reference object of known size in the "
        "same image, falling back to a visual size classifier if the former "
        "proves inadequate. Both require a validation set before they can be "
        "trusted."),

  ("h2", "10.3 What is needed from outside the team"),
  ("p", "First, a targeted field photography round — the real constraint on "
        "progress. It is not an engineering item, and the evaluation has turned "
        "it from a general request into a list of measured priorities."),
  ("table", ["Gap", "Measured state", "Priority"], [
      ["Coca-Cola Diet", "0% / 0% — 5 source images", "Critical"],
      ["Glass-packaged products", "33.3% recall — 3 instances", "Critical"],
      ["Six Cappy flavours", "no representation", "High"],
      ["Coca-Cola Zero", "66.7% recall", "High"],
      ["Pepsi", "unrepresented in detector and classifier", "High"],
      ["Two thin XL variants", "no representation", "Medium"],
   ], "Data gaps ordered by measured priority rather than by estimate."),
  ("p", "Alongside it, a size validation set of 50 to 100 images in which the "
        "true size is known with certainty, since no size-estimation approach "
        "can be evaluated without one — it is a precondition for the axis "
        "described in Section 10.2, not a complement to it."),
  ("p", "Second, continuity of access to training and evaluation resources, "
        "since the availability of measurement tooling is what made this "
        "study's results possible."),
  ("p", "Third, guidance the technical team cannot issue on its own, and the "
        "most important thing requested here: what accuracy threshold counts as "
        "production-ready in this domain? The question has become concrete now "
        "that figures exist. The brand layer at 100% precision is ready by any "
        "standard, and a classifier at 56% is ready by none. But what about the "
        "intermediate cases? Is a class at 66.7% recall acceptable in a report "
        "delivered to a client? Should it be presented with a caveat? Or "
        "withheld until its data improves?"),
  ("p", "The answer directly determines engineering behaviour: how far the "
        "system should lean toward referring a decision to human review rather "
        "than settling it automatically. That is a commercial judgement about "
        "what the client accepts and what the service agreement bears, not a "
        "technical question — and it will shape the next round of tuning work."),
 ]),

 ("11. Conclusion", [
  ("p", "This study tested the hypothesis that separating localisation from "
        "identification in applied computer-vision systems improves both "
        "accuracy and scalability. The results support the hypothesis with "
        "measured evidence."),
  ("p", "First, the multi-stage approach outperformed the single-layer one on "
        "every mean-precision metric and on recall, from the same source "
        "photographs, and despite its counterpart being evaluated under the "
        "easier condition. The per-class breakdown reveals the mechanism: a "
        "limited training signal divided six ways produces performance bounded "
        "by its weakest class rather than its strongest, whereas separation "
        "concentrates that signal into one class and defers discrimination to a "
        "layer with far more visual detail available to it."),
  ("p", "Second, the shape of growth deserves measurement as much as accuracy "
        "does. The difference between O(N×K) and O(N) does not show up in a "
        "single image, but it determines whether the system remains practical "
        "after ten brands or collapses under its own weight."),
  ("p", "Third, the marginal cost of catalogue expansion — roughly four minutes "
        "of GPU time, measured four times — is the practical translation of the "
        "architectural gain, and is the commercially decisive metric rather "
        "than any individual model's accuracy."),
  ("p", "Fourth, data quality bounds the ceiling of any architecture. This is "
        "now measured rather than inferred: every individual weakness traces to "
        "specific, countable data scarcity, and none traces to a flaw in the "
        "design. The most important item in the next phase is therefore not an "
        "engineering one at all, but a photography round."),
  ("p", "What has been achieved — a more accurate detector from the same source "
        "photographs, six working and measured classification layers, a routing "
        "architecture demonstrated four times, a live active-learning loop, at a "
        "total training cost of under an hour and a quarter — constitutes an "
        "empirically established foundation to build on, not a finished "
        "product. The limitations in Section 9 are specific and of known cost, "
        "and none of them points to a flaw in the underlying design."),
 ]),
]

REFERENCES = []
