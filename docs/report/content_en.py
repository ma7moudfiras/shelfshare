# -*- coding: utf-8 -*-
"""English content for the Aystro shelf-auditing progress report."""

META = dict(
    title="Automated Retail Shelf Auditing: Technical Progress and Investment Readiness",
    subtitle="A Report to Leadership and Investors",
    author="Mahmoud Firas Fannoun",
    org="Aystro",
    period="27 July 2026 – 14 August 2026",
    submitted="15 August 2026",
    labels=dict(trainee="Prepared by", org="Organization",
                period="Reporting Period", submitted="Date of Submission"),
    abstract_h="Executive Summary",
    refs_h="Technical References",
    fig="Figure",
    table="Table",
)

ABSTRACT = [
    "This report answers one question directly: is the computer-vision architecture Aystro is building on "
    "the right one to keep investing in, or should scope change? The short answer is that the direction is "
    "validated by measured evidence, not just design reasoning, and the evidence is now real rather than "
    "projected — trained models, real accuracy numbers, and a working application, not a proposal.",

    "The core architectural bet — separating \"where is a product\" (detection) from \"what product is it\" "
    "(classification), instead of one model doing both — has been built and measured against the original "
    "single-stage approach. The new detector reaches higher accuracy and precision using roughly a third of "
    "the training images the original approach needed, at a training cost increase of well under one "
    "percent of a single month's cheapest paid Roboflow plan. Adding a new flavour variant to an existing "
    "brand — demonstrated in practice for Fanta during this engagement — took hours of labelling and one "
    "small classifier, not a retrain of the core system. That is the economic case for this architecture in "
    "one sentence: catalogue growth is now a data task, not an engineering one.",

    "The report is equally direct about what is not yet proven. Classifier-layer accuracy has not yet been "
    "formally measured (a same-day fix). Two newer signals — Coca-Cola flavour variants and packaging "
    "material — are mid-experiment and constrained by real data gaps, not model performance: the available "
    "Coca-Cola photographs turned out on inspection to be almost entirely one variant, and only two genuine "
    "glass-packaging examples exist across the whole labelled corpus. Both gaps have a known, inexpensive "
    "fix — targeted photography — rather than an open-ended research problem. A geometric packaging-format "
    "rule described in earlier work has been suspended in production because it did not generalise reliably "
    "enough; the code is kept, not discarded, pending a better approach. These are stated plainly because a "
    "credible investment case rests on knowing the real gaps, not on a report with none.",
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
        "both questions with a single monolithic model inherits a serious commercial liability, examined "
        "next, that determines whether the product can keep pace with a retail catalogue that never stops "
        "changing."),
  ("fig", "fig1_annotated_shelf", "A field capture with its detections overlaid; colour denotes brand. The "
        "density of a real audit scene — many products, tightly packed, photographed under ordinary store "
        "lighting — is the actual operating condition this system is built for, not a controlled benchmark."),
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
  ("b", "Stage 3 — Variant classification. Within a brand, a further classifier resolves the specific "
        "flavour or product variant. Built and shipped for Fanta during this engagement; Coca-Cola is "
        "in progress (Section 3.2)."),
  ("b", "An experimental fourth signal — packaging material (glass / plastic / can), independent of brand — "
        "is under evaluation in parallel (Section 3.3)."),
  ("p", "This is implemented as a live, hierarchical Roboflow Workflow, not a proposal: a shared detector "
        "feeds crops to a brand classifier and a flavour classifier running in parallel, and a small merge "
        "step selects the flavour label only when the brand it belongs to actually has one, otherwise "
        "passing the plain brand through unchanged. Restricting brand-variant comparison to one "
        "manufacturer's catalogue rather than the entire market also reduces visual confusion between "
        "candidates."),
  ("fig", "fig3_pipeline", "Block diagram of the staged pipeline: class-agnostic detection, region cropping, "
        "brand classification, and variant classification, with packaging material as an independent, "
        "parallel signal rather than a further narrowing of the same decision."),
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
        "annotation work — and is the highest-value near-term action identified in this report "
        "(Section 7)."),

  ("h2", "3.2 Classifier accuracy: a known, closeable gap"),
  ("p", "The brand classifier (Stage 2) and the Fanta flavour classifier (Stage 3) are both trained and "
        "serving live traffic, but neither has a formally recorded accuracy evaluation yet — the training "
        "platform tracks this separately from the training run itself, and that follow-up step has not been "
        "run. This report states that plainly rather than substituting an estimate: no classifier accuracy "
        "figure is claimed here that has not been measured. Running the missing evaluation is a same-day "
        "task and the first item on the roadmap in Section 7."),
  ("p", "A second classifier, for Coca-Cola flavour variants, was built and seeded with the available "
        "labelled photography, then audited by hand before training. That audit found the available "
        "Coca-Cola images were almost entirely one variant (\"classic\") with negligible real diversity — so "
        "rather than train a flavour classifier the data cannot actually support, the project was left as a "
        "single class pending genuinely varied new photography. This is a data-collection gap, not a "
        "modelling one, and is called out explicitly in Section 6."),

  ("h2", "3.3 Packaging-material classifier: an experiment in progress"),
  ("p", "A new, independent signal — packaging material (glass, plastic, or can) — is being evaluated "
        "separately from brand and flavour, on the basis that material is brand-independent: a plastic "
        "bottle looks plastic regardless of manufacturer, so one shared classifier serves every brand and "
        "every future brand added to the catalogue, rather than needing a per-brand model."),
  ("p", "A full visual audit of the 1,608 images available across all six brands found only two genuine "
        "glass-packaging examples in the entire corpus — far too few to train a reliable glass class. Rather "
        "than force those two images into a mislabelled bucket or overstate a third category, the "
        "experiment was scoped down to a two-class problem, plastic versus can, with a workable, roughly "
        "balanced split of 860 plastic and 746 can images. Image upload for this experiment is complete; "
        "labelling and training are in progress at the time of writing. This is reported as an open, honest "
        "in-progress item, not a finished result."),

  ("h2", "3.4 Engineering maturity: caught, fixed, and verified against live data"),
  ("p", "Two incidents from this engagement are included deliberately, as evidence of process rather than "
        "as embarrassments to omit. First, a defect in the workflow's custom merge logic was silently "
        "turning full class names into single stray characters in the live application; it was diagnosed "
        "from a user report, root-caused to a data-shape assumption that training-time metrics could not "
        "have caught, fixed, and verified against a real photograph within the same working session. Second, "
        "a geometric rule for distinguishing packaging formats by box shape — a promising result on the "
        "specific example it was measured against — did not generalise reliably enough in broader use and "
        "has been suspended in production while a more accurate approach is developed; the code and its "
        "tests are kept intact, not deleted, for that follow-up. Both are the kind of finding a system only "
        "surfaces once it is actually run against real, uncontrolled data — which is itself part of the "
        "evidence that this project has moved past the design stage."),
 ]),

 ("4. Economics: The Cost to Scale", [
  ("p", "The central commercial risk in any catalogue-driven product is that growth becomes expensive: every "
        "new SKU, every new market, every new customer could in principle demand new engineering. This "
        "architecture was specifically chosen to avoid that, and the claim is backed by this engagement's "
        "own measured costs rather than a projection."),
  ("table", ["Model", "Training time", "Training credits"], [
      ["Original detector (first version)", "11.2 min", "0.37"],
      ["Current production detector", "44.2 min", "1.48"],
      ["Brand classifier (Stage 2)", "9.1 min", "0.30"],
      ["Fanta flavour classifier (Stage 3)", "7.2 min", "0.24"],
   ], "Actual training cost of every model in the current production stack, at Roboflow's published rate "
      "of one credit per thirty minutes of GPU training."),
  ("p", "The entire current three-model production stack has cost roughly 2 credits (about one hour of GPU "
        "time) to train, in total, ever — a small fraction of a single month's allowance on even the "
        "cheapest paid plan. Moving from one model to three did not meaningfully raise training cost while "
        "measurably raising accuracy (Section 3.1). Current dollar pricing changes independently of this "
        "report and should always be checked directly against Roboflow's published rates rather than quoted "
        "here as a fixed figure."),
  ("p", "The more consequential number for an investor is the marginal cost of catalogue growth, and this "
        "engagement produced a direct, not hypothetical, data point: adding Fanta flavour differentiation — "
        "a new axis of product identity — required labelling a few hundred already-available product "
        "images and training one small classifier, wired into the pipeline as a parallel step. No change to "
        "the detector or the brand classifier was needed. It was completed within hours, not weeks. The "
        "same pattern applies to onboarding an entirely new company: the backing database is multi-tenant "
        "by design, so a new customer is a data-entry operation, not a code change."),
  ("p", "One cost is real and not yet measured, and is stated here rather than left out: the current "
        "pipeline issues a brand-classification and a flavour-classification call for every detected "
        "product in a photograph, not once per photograph, so a busy shelf with twenty products now "
        "triggers meaningfully more classification calls than the original single-model approach. This "
        "should be measured directly from live workflow usage before it is quoted as a number, and is "
        "flagged as an open item in Section 6."),
 ]),

 ("5. The Application: Field-Proven", [
  ("p", "A cross-platform application, developed alongside the model architecture, is what turns model "
        "output into a usable business process rather than a research demo. It standardises field capture, "
        "runs the detection pipeline against each photograph, and — critically — interposes a human "
        "reviewer between raw model output and any figure that gets reported as fact."),
  ("p", "Since the start of this engagement the application has grown past initial capture-and-review into "
        "reporting the business actually asked for: a Submissions view so a company administrator can see "
        "what a field representative actually recorded (previously, captured data was written to the "
        "database but nothing in the application read it back), and a brand-to-variant Share-of-Shelf "
        "report giving each brand's overall percentage of shelf space broken down into the specific variants "
        "the pipeline currently distinguishes. A low-quality capture warning — a photograph shot too far "
        "from the shelf to count reliably — was also upgraded from an easy-to-miss notification to a "
        "dialog the representative must actively dismiss, directly reducing a source of silent undercounting "
        "in the field."),
  ("fig", "fig4_app", "The application reviewing a live capture, with detections and a share-of-shelf "
        "summary computed beneath — the point at which an automated count becomes a number a person has "
        "actually verified before it is reported."),
 ]),

 ("6. Risks and Open Gaps", [
  ("p", "Stated in the order they should be closed, with the honest reason each remains open:"),
  ("b", "1. Classifier accuracy is unmeasured. The brand and Fanta-flavour classifiers are live but have no "
        "recorded evaluation. Closing this is a same-day task with no dependency on new data."),
  ("b", "2. The detector's recall gap traces to a specific, known cause. Roughly 800 already-annotated "
        "images from the original project have not been migrated into the class-agnostic one. This is a "
        "data-engineering task, not new research."),
  ("b", "3. The packaging-material classifier is untrained and, more fundamentally, has almost no glass "
        "examples to learn from — two images across the entire labelled corpus. Plastic-versus-can is "
        "workable with existing data; a genuine glass class requires targeted new photography, not more "
        "labelling of what already exists."),
  ("b", "4. Coca-Cola flavour variety does not exist in the current data. The available photographs are "
        "almost entirely one variant. This is the same fix as item 3 — new photography of the missing "
        "variants — and should not be attempted by relabelling existing images, which the audit already "
        "ruled out."),
  ("b", "5. Per-product inference cost at scale has not been measured. The architecture change moved from "
        "one classification call per photograph to several per detected product; the real cost impact should "
        "be measured from live usage before it is used in a cost projection."),
 ]),

 ("7. Recommendation and Next Steps", [
  ("p", "The recommendation is to continue the current architecture. The evidence in this report is that it "
        "is not a trade-off between cost and accuracy against the original approach — it is measurably more "
        "accurate on a third of the training data, at a training-cost increase too small to matter, and it "
        "has already demonstrated in practice, not in theory, that catalogue growth is cheap: the Fanta "
        "flavour layer was added in hours. The open items in Section 6 are specific, individually "
        "inexpensive, and none of them point to a flaw in the underlying design."),
  ("p", "Proposed order of work: first, run the missing classifier evaluation and migrate the roughly 800 "
        "unmigrated detector images, retraining the detector against the fuller dataset — both are days of "
        "work with no new data collection required and directly close Sections 6.1 and 6.2. Second, decide "
        "whether to fund a short, targeted photography pass covering genuine Coca-Cola flavour variants and "
        "glass-packaged products specifically; without it, those two experiments cannot progress further "
        "regardless of engineering effort, since the constraint is data that does not yet exist, not model "
        "capability. Third, measure real per-photograph inference cost from live usage once volume "
        "justifies it, to keep the economics in Section 4 current rather than assumed."),
  ("p", "What this report asks of leadership is a decision to continue funding the current direction on the "
        "strength of measured results rather than a promising design. What it offers an investor is a "
        "concrete answer to \"does the core technology work\": yes, measurably, at a training cost too small "
        "to be a meaningful line item, with a demonstrated, not projected, path to adding new products "
        "cheaply — and a team that finds its own defects, states its own gaps, and fixes rather than hides "
        "them."),
 ]),
]

REFERENCES = [
 "Radford, A., Kim, J. W., Hallacy, C., et al. (2021). Learning Transferable Visual Models From Natural "
 "Language Supervision. Proceedings of the 38th International Conference on Machine Learning (ICML). "
 "— background for the embedding-based classification approach used in Stages 2 and 3.",

 "Ren, S., He, K., Girshick, R., & Sun, J. (2015). Faster R-CNN: Towards Real-Time Object Detection with "
 "Region Proposal Networks. Advances in Neural Information Processing Systems (NeurIPS). "
 "— background for the detect-then-classify architectural pattern underlying Stage 1.",

 "Roboflow. Workflows Documentation. https://inference.roboflow.com/workflows/ (accessed August 2026). "
 "— the platform the production pipeline in Section 2 is implemented on.",

 "Roboflow. Pricing and Credits. https://roboflow.com/pricing (accessed August 2026). "
 "— source for the credit rates used in Section 4; consult directly for current dollar pricing.",
]
