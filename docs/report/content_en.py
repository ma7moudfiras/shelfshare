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

    "Every accuracy figure in this study is measured at a single fixed "
    "confidence threshold of 0.70 — not at each class's own optimal threshold, "
    "since one system cannot run a different threshold per class. The "
    "multi-stage approach outperformed the single-layer one on all six "
    "detection metrics: 93.33% mAP@50 against 88.62%, 76.49% mAP@50-95 against "
    "70.09%, and 80.7% recall against 74.0% — and it did so even though the "
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
        "independent of K, as Section 5.5 shows."),
  ("p", "Note that the axes are independent by design: packaging material does "
        "not depend on brand, whereas variant does. This independence is what "
        "permits the size axis to be added later as a fourth layer without "
        "disturbing anything before it."),
  ("fig", "fig_pipeline_v2", "The architecture as actually deployed, read from "
        "the live workflow specification. The essential difference from "
        "conventional staged architectures is the routing steps (in orange): "
        "they decouple the execution of the variant classifiers from the mere "
        "availability of their input, which is what Section 5.5 measures."),
 ]),

 ("5. Experimental results", [

  ("h2", "5.1 Detection: single-layer against multi-stage"),
  ("p", "The accuracy of any classification system is measured at a declared "
        "confidence threshold: the model emits a confidence score with every "
        "prediction, and the prediction counts only if that score exceeds an "
        "agreed threshold. This study adopts a single fixed threshold of 0.70 "
        "for every classification figure it reports — for both detectors and "
        "all six classifiers."),
  ("p", "This choice is methodological, not cosmetic. The evaluation tool "
        "computes for each class its own “optimal threshold”, the point "
        "at which that class performs best; here those range from zero to 0.91 "
        "depending on the class. Reporting each class at its own threshold "
        "yields high numbers but does not describe a single system, because a "
        "running system cannot apply a different threshold to each class "
        "simultaneously. A single fixed threshold describes what actually "
        "happens when the pipeline runs as one unit, and it is the stricter "
        "choice — the figures below are lower than their optimal-threshold "
        "counterparts, deliberately."),
  ("table", ["Metric", "v1 (single, 6 classes)", "v2 (multi, 1 class)",
             "Difference"], [
      ["mAP@50", "88.62%", "93.33%", "+4.71"],
      ["mAP@50-95", "70.09%", "76.49%", "+6.40"],
      ["mAP@75", "80.43%", "87.57%", "+7.14"],
      ["Precision", "91.6%", "92.0%", "+0.40"],
      ["Recall", "74.0%", "80.7%", "+6.70"],
      ["F1", "81.6%", "85.9%", "+4.30"],
   ], "Both detectors on a held-out test split, with the same evaluation tool "
      "and the same model architecture. Precision, recall and F1 at a 0.70 "
      "threshold for both; the mAP metrics are threshold-independent, being "
      "computed across all thresholds."),
  ("p", "The multi-stage approach leads on all six metrics, from the same "
        "source photographs, and despite the single-layer approach being "
        "evaluated on magnified tiles — the easier condition for detection "
        "(Section 3.1). The measured gap is therefore most likely a lower "
        "bound on the true gap rather than an exaggeration of it."),
  ("p", "The widest margin is in recall: 80.7% against 74.0%, a gap of 6.7 "
        "points. This is the more important metric in this domain, because a "
        "product that is never detected corrupts the inventory with no way to "
        "recover it later, whereas a spurious detection is corrected by the "
        "human reviewer. Precision is near-identical (92.0% against 91.6%), "
        "meaning the recall gain was not bought by conceding precision, as the "
        "usual trade would have it."),
  ("p", "As a characterisation of the current system alone — not a comparison, "
        "for the reason given in Section 3.1 — its performance across object "
        "sizes is 92.31% for small, 94.47% for medium, and 96.98% for large "
        "objects. It therefore sustains high performance across the whole size "
        "range, a practical requirement in shelf photography where product "
        "dimensions vary widely within a single frame."),

  ("h2", "5.2 Per-class signal starvation"),
  ("p", "The per-class breakdown of the single-layer approach exposes the "
        "mechanism of the statistical constraint the hypothesis predicted. It "
        "is presented here alongside the annotation distribution of the same "
        "project, so that the effect can be set against its direct cause."),
  ("fig", "fig_app_v1", "The single-layer approach on a real shelf: 75 "
        "detections, every label at brand level only — this approach's ceiling "
        "by construction, since its classes are the brands themselves. The "
        "share-of-shelf figures beneath are computed at the same level. The "
        "domain conditions described in Section 7 are also visible here: high "
        "display density, mutual occlusion, and reflections off the glass."),
  ("table", ["Class", "Annotations", "Share", "mAP@50", "Precision", "Recall"], [
      ["coca-cola", "2,079", "42.6%", "89.27%", "96.1%", "71.3%"],
      ["cappy", "948", "19.4%", "85.62%", "89.4%", "75.0%"],
      ["xl_energy", "661", "13.5%", "91.97%", "96.9%", "66.0%"],
      ["sprite", "651", "13.3%", "88.29%", "87.9%", "78.5%"],
      ["fanta", "409", "8.4%", "87.98%", "87.5%", "79.0%"],
      ["pepsi", "131", "2.7%", "—", "0%", "0%"],
   ], "Per-class performance of the single-layer detector (0.70 threshold) "
      "against each class's share of the annotation budget. Total: 4,879 "
      "annotations."),
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
  ("table", ["Classifier", "Precision", "Recall", "F1"], [
      ["Brand", "100%", "89.1%", "94.0%"],
      ["Fanta (flavour)", "100%", "88.9%", "93.3%"],
      ["Packaging", "95.9%", "74.4%", "79.6%"],
      ["XL Energy (variant)", "66.7%", "66.7%", "66.7%"],
      ["Coca-Cola (variant)", "66.7%", "55.6%", "60.0%"],
      ["Cappy (flavour)", "50.0%", "31.2%", "36.5%"],
   ], "Overall performance of the six classification layers at a 0.70 "
      "threshold, in descending order."),
  ("p", "The ordering reveals a regular gradient: the layers at the top are the "
        "oldest and best supplied with data, those at the bottom the newest and "
        "most starved. Nothing in this ordering departs from the ordering of "
        "data volume — which sets up the diagnosis in the section that "
        "follows."),
  ("table", ["Class", "Test instances", "Correct", "Recall"], [
      ["xl_energy", "20", "16", "80.0%"],
      ["cappy", "14", "12", "85.7%"],
      ["coca-cola", "10", "8", "80.0%"],
      ["fanta", "2", "2", "100%"],
      ["sprite", "1", "1", "100%"],
      ["pepsi", "0", "—", "—"],
   ], "The brand layer at a 0.70 threshold. Precision is 100% for every "
      "represented class. Total: 47 instances."),
  ("p", "Precision reached 100% for every brand with actual field photography "
        "behind it, even at the strict threshold. This is an architecturally "
        "decisive result: the decision on which everything downstream depends "
        "does not, in practice, err — when this classifier issues a verdict, it "
        "is correct. No error in the later layers can therefore be attributed "
        "to misrouting, which is a necessary condition for any conclusion about "
        "those layers' performance to be valid."),
  ("table", ["Classifier", "Classes (instances: correct)", "Test total"], [
      ["Fanta", "orange (12:12), redapple (3:3), grape (3:2)", "18"],
      ["Packaging", "plastic (88:84), can (70:66), glass (3:1)", "161"],
      ["XL Energy", "classic (24:24), red (4:4), sugarfree (1:0)", "29"],
      ["Coca-Cola", "classic (26:26), zero (3:2), diet (1:0)", "30"],
      ["Cappy", "orange (6:3), grape (4:3), lemon (4:1), mix (3:0), "
                "apple (2:0), mango (2:2), peach (1:0), strawberry (1:0)", "23"],
   ], "Variant and packaging layers at a 0.70 threshold. Classes with no test "
      "representation are omitted."),
  ("p", "The fixed threshold exposes a distinction invisible at optimal "
        "thresholds, and it is among the most useful things this analysis "
        "produced: some weak classes are not wrong but merely unconfident. The "
        "xl-sugarfree class scores 100% precision and 100% recall at a 0.40 "
        "threshold, then falls to zero at 0.70 — the model knows it and gets it "
        "right, but at a confidence lying between the two thresholds. The same "
        "holds for cappy-strawberry and cappy-apple, and partially for "
        "cappy-lemon (50% recall at 0.40 against 25% at 0.70)."),
  ("p", "This is fundamentally different from coca-diet and glass, which fail "
        "at every threshold without exception. The former case is “learned "
        "but not trustworthy for automatic decisions” and is addressed by "
        "more examples to consolidate confidence; the latter is “not "
        "learned at all” and needs data simply to exist. A single table at "
        "each class's own optimal threshold cannot separate the two — it shows "
        "both as succeeding or failing depending on the class — whereas reading "
        "performance across two thresholds can."),

  ("h2", "5.4 How statistically reliable these figures are"),
  ("p", "The figures above require an explicit caveat, and omitting it would "
        "make the report misleading however carefully each number was measured: "
        "the test splits are very small, and many of the 100% figures rest on "
        "single instances."),
  ("table", ["Class", "Correct/instances", "Recall", "95% interval"], [
      ["sprite (brand)", "1/1", "100%", "20.7% – 100%"],
      ["fanta (brand)", "2/2", "100%", "34.2% – 100%"],
      ["cappy-mango", "2/2", "100%", "34.2% – 100%"],
      ["fanta-redapple", "3/3", "100%", "43.8% – 100%"],
      ["xl-red", "4/4", "100%", "51.0% – 100%"],
      ["fanta-orange", "12/12", "100%", "75.7% – 100%"],
      ["xl-classic", "24/24", "100%", "86.2% – 100%"],
      ["coca-classic", "26/26", "100%", "87.1% – 100%"],
   ], "Wilson 95% confidence intervals for classes scoring 100%. The same "
      "number, carrying entirely different meanings."),
  ("p", "The sprite class scores 100% on a single test image, and the true "
        "interval for its performance runs from 20.7% to 100% — that is, the "
        "number carries almost no information. By contrast xl-classic, on 24 "
        "instances, has an interval of 86.2%–100%, which is a statement with "
        "content. The two figures are identical on the page and fundamentally "
        "different in substance, and nothing distinguishes them except the "
        "instance count — which is why it is stated in every table above."),
  ("p", "Small samples have a second effect, on the aggregate figures. The "
        "platform computes a per-class average, so a class with 24 instances "
        "counts equally with a class holding one. Weighting by instance count "
        "gives a markedly different picture."),
  ("table", ["Classifier", "Per-class average", "Per-instance average",
             "Difference"], [
      ["XL Energy", "66.7%", "96.6% (28/29)", "+29.9"],
      ["Coca-Cola", "55.6%", "93.3% (28/30)", "+37.7"],
      ["Packaging", "74.4%", "93.8% (151/161)", "+19.4"],
      ["Fanta", "88.9%", "94.4% (17/18)", "+5.5"],
      ["Cappy", "31.2%", "39.1% (9/23)", "+7.9"],
      ["Brand", "89.1%", "83.0% (39/47)", "−6.1"],
   ], "Recall computed both ways. The figures reported throughout this study "
      "are the per-class average, which is the more conservative of the two."),
  ("p", "XL's 66.7% is the clearest illustration of how fragile a per-class "
        "average can be: it means “two classes out of three”, and one of "
        "the three holds a single instance. Had that one image cleared the "
        "threshold, the figure would read 100%. A number that swings by a third "
        "on the strength of one image is volatility, not measurement. Set "
        "against that, 28 of the 29 actual products in the test set were "
        "classified correctly."),
  ("p", "Both averages are valid, but they answer different questions. The "
        "per-class average asks “how does the system handle the average "
        "class?”, exposing and penalising data gaps; the per-instance "
        "average asks “how does it handle the average product on a "
        "shelf?”, which is what a client actually experiences. This study "
        "reports the former because it is the more conservative, and states the "
        "latter here so the former is not misread."),
  ("p", "Inspecting the confusion matrices at this threshold reveals a striking "
        "property: across the brand, Fanta, XL, Coca and Cappy classifiers "
        "there is not a single confusion between one class and another in the "
        "entire test set. Every error is an abstention — the model failed to "
        "reach the threshold and stayed silent — rather than a misclassification. "
        "In the brand layer, for instance: 47 instances, 39 correct, 8 "
        "abstentions, zero confusions."),
  ("p", "This property has direct operational value: the system does not call a "
        "Coca-Cola a Sprite; it is either right or silent. An abstention is a "
        "tractable error, referred to human review and corrected there, whereas "
        "a confident misclassification propagates into the report without "
        "arousing suspicion. The sole exception is the packaging classifier, "
        "the only one that shows genuine confusion (can with plastic eight "
        "times, glass to plastic twice) and never abstains — and also the only "
        "one operating on a physical property rather than a commercial "
        "identity."),
  ("fig", "fig_app_v2_variants", "The multi-stage architecture on a real Cappy "
        "shelf: labels here are at flavour level (orange / mango / grape / "
        "lemon / strawberry) rather than brand level — this is what the routed "
        "variant layer produces, and it is directly comparable with the "
        "preceding figure. What matters most in it is that the confidences "
        "shown range from 19% to 67% — most of them below the 0.70 threshold "
        "this study adopts. This is exactly the case the section quantifies: "
        "the flavour is visually distinguished and usually correct, but below "
        "the confidence that would license an automatic decision — which is why "
        "the classifier scores 50% precision and 31.2% recall at that "
        "threshold, and why active learning was directed at it (Section 6)."),
  ("p", "The conclusion is that no measured weakness in the system is "
        "attributable to the architecture or the choice of model; all of them "
        "trace back to specific, measurable data scarcity. This is a decisive "
        "practical distinction: data scarcity is addressed by targeted "
        "collection of known cost, whereas an architectural deficiency requires "
        "redesign."),

  ("h2", "5.5 Computational complexity"),
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

  ("h2", "5.6 Training cost and the marginal cost of growth"),
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
        "5.5 measures."),
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
  ("p", "An operational decision follows from this third function: what is "
        "shown to the reviewer is not necessarily what is counted in the "
        "report. The 0.70 threshold used for measurement defines what qualifies "
        "as a trustworthy automatic verdict, but hiding everything below it "
        "from the reviewer's screen would deny them sight of precisely the "
        "cases they are meant to correct — the cases the system most needs "
        "(Section 5.3). Predictions below the threshold are therefore shown for "
        "review but not counted automatically, since what is never seen cannot "
        "be corrected."),
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
  ("b", "1. The test splits are improperly small — the gravest limitation in "
        "this study, and the one that precedes all others because it bears on "
        "the reliability of every figure in it."),
  ("table", ["Project", "Train", "Valid", "Test", "Test share"], [
      ["Brand classifier", "1,534", "105", "47", "2.8%"],
      ["Coca-Cola", "720", "30", "30", "3.8%"],
      ["XL Energy", "612", "58", "29", "4.1%"],
      ["Fanta", "238", "43", "18", "6.0%"],
      ["Detector v2", "316", "34", "34", "8.9%"],
      ["Cappy", "161", "46", "23", "10.0%"],
   ], "Actual split proportions. The conventional test share is around 20%."),
  ("p", "The consequence is that classes rich in data reached the test set with "
        "one or two instances. The clearest example is sprite: the project holds "
        "374 images of it, of which exactly one landed in the test split and 373 "
        "in training. Its “100%” is therefore not a performance "
        "certificate but an artefact of the split."),
  ("b", "2. From this follows an essential distinction between two kinds of "
        "weakness that had been conflated under the single description of "
        "“data scarcity”:"),
  ("p", "The first is a split deficiency rather than a data one: sprite, fanta "
        "at brand level, xl-red. The data exists in full within the project, but "
        "the split withheld it from the test set. The remedy needs no "
        "photography and no new data — only regenerating a version with a "
        "balanced split and retraining, a matter of minutes of computation, "
        "currently blocked solely on the availability of training credits."),
  ("p", "The second is genuine data scarcity: coca-diet (5 source images), glass "
        "(25 images in the whole corpus, 3 of them in test), the thin Cappy "
        "flavours, and pepsi (unrepresented in both the detector and the "
        "classifier). No split and no retraining produces these; only field "
        "photography does."),
  ("p", "Conflating the two inflates the apparent size of the work outstanding: "
        "a substantial part of what looks like a data gap is in fact a "
        "procedural one, closable by a single retraining run."),
  ("b", "3. The differing preprocessing pipelines of the two compared versions "
        "(Section 3.1). Its effect is mitigated by two things: the difference "
        "works against the stated conclusion, and the size-resolved comparison "
        "was dropped as invalid. Unifying the pipeline in a later evaluation "
        "would close this point definitively."),
  ("b", "4. Two independent splits. The projects generate their splits "
        "separately even though they share the source photographs, which "
        "weakens the comparison in principle."),
  ("b", "5. The system was not evaluated end to end — the most important "
        "missing measurement in the study."),
  ("p", "“End to end” means treating the whole system as a single black "
        "box: it is given a shelf photograph it has never seen, and its final "
        "output — the complete compound label for every product — is compared "
        "against a human labelling of that same photograph. What Section 5 "
        "measured is the performance of each layer in isolation, which is a "
        "different thing."),
  ("p", "The difference matters for two reasons. First, the accuracy of a chain "
        "is a product rather than an average: for a bottle to reach its correct "
        "label the detector must find it, then the brand layer must be right, "
        "then the variant classifier must be right — and three steps at 90% "
        "each yield roughly 73%, not 90%. Second, and more subtly, each layer "
        "was measured on clean, manually labelled input, whereas in production "
        "it receives the previous layer's output: a crop that may be shifted, "
        "clipped at the edge, or partly occluded. The brand layer's 100% "
        "answers the question “how often is it right on ideal crops?”, "
        "not “how often is it right on our detector's crops?”."),
  ("p", "The distinction is practical rather than theoretical: the only figure "
        "that may honestly be given to a client is the end-to-end one, and it "
        "will necessarily be lower than every figure in Section 5. The cost of "
        "closing this gap is not computational but human — fully labelling "
        "thirty to fifty shelf photographs by hand, with no training and no "
        "credits required."),
 ]),

 ("10. Future work and what is needed", [
  ("h2", "10.1 Requiring no external input"),
  ("p", "First, and cheapest for the return: regenerating the six classifier "
        "versions with a balanced split (70/20/10) and retraining them, closing "
        "Limitation 1. The brand classifier alone would move from 47 test "
        "instances to roughly 340, and sprite would gain dozens of instances "
        "instead of one — turning the figures in Section 5.3 from suggestive "
        "into statistically meaningful. The computational cost is about four "
        "minutes per classifier, under half an hour for the whole set; the only "
        "obstacle is the availability of training credits."),
  ("p", "Next, an end-to-end evaluation on a manually labelled test set, to "
        "measure error accumulation across the chain (Limitation 5) — "
        "scientifically the highest-priority item, and one that needs no credits "
        "at all. Then re-evaluating both detectors under a unified preprocessing "
        "pipeline, to close Limitation 3. Then harvesting the first batch of "
        "active-learning data, reviewing it, and retraining on it — the first "
        "practical test of whether the loop described in Section 6 closes."),
  ("p", "Throughout the above, a stratified split guaranteeing each class a "
        "minimum test share is preferable to the random splitting that produced "
        "the situation described in Limitation 1 — because randomness applied to "
        "an unbalanced set leaves small classes unrepresented by probability "
        "alone."),

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
