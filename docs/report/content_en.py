# -*- coding: utf-8 -*-
"""English content for the Aystro field training report."""

META = dict(
    title="Applied Computer Vision for Automated Retail Shelf Auditing",
    subtitle="A Field Training Report",
    author="Mahmoud Firas Fannoun",
    org="Aystro",
    period="27 July 2026 – 6 August 2026",
    submitted="8 August 2026",
    labels=dict(trainee="Trainee", org="Host Organization",
                period="Training Period", submitted="Date of Submission"),
    abstract_h="Abstract",
    refs_h="References",
    fig="Figure",
    table="Table",
)

ABSTRACT = [
    "This report documents the technical concepts acquired and the work undertaken during a two-week "
    "field training period at Aystro, focused on computer vision systems for automated retail shelf "
    "auditing. The work comprised two complementary strands: an analytical strand, in which an existing "
    "object detection dataset of 213 shelf photographs containing 4,641 manually annotated bounding boxes "
    "was audited and a revised system architecture derived; and an implementation strand, in which a "
    "cross-platform data collection application was developed to support field capture, automated "
    "analysis, and human verification of model output.",

    "The report examines the detect-then-recognize architectural pattern, in which spatial localization is "
    "deliberately decoupled from identity classification, and documents a structural limitation of "
    "similarity-based visual classification: because the embedding model resizes every crop to a fixed "
    "square before encoding it, aspect ratio is discarded and containers of identical labelling but "
    "differing physical proportion become indistinguishable. This limitation was resolved by fusing "
    "bounding-box geometry, already produced by the detection stage, with the visual signal — an approach "
    "implemented and verified in the delivered application.",
]

SECTIONS = [

 ("1. Introduction and Problem Context", [
  ("p", "Object detection is a foundational task in computer vision that answers two coupled questions "
        "about an image: where an object is located (localization) and what that object is "
        "(classification). In retail shelf auditing, the practical objective is to convert a photograph of "
        "a store shelf into structured commercial data — how many units of each product are present, how "
        "they are arranged, and what share of the visible shelf each brand occupies. This requires both "
        "answers simultaneously, since a count without positions cannot describe shelf layout, and "
        "positions without identities cannot describe inventory."),
  ("p", "The dataset examined at the outset of the training had been annotated according to manufacturer "
        "brand, assigning each bounding box a class such as coca-cola or pepsi. This labelling scheme, "
        "while intuitive, exposed a set of structural problems that formed the analytical core of the "
        "training period and are examined in the sections that follow."),
  ("fig", "fig1_placeholder", "A representative shelf photograph from the dataset with its annotated "
        "bounding boxes overlaid, illustrating object density and the packaging formats under study."),
 ]),

 ("2. Methodology and Scope of Work", [
  ("p", "The training followed an investigative rather than a purely implementational approach. An "
        "existing annotated dataset was audited, its limitations diagnosed, a revised architecture derived "
        "and validated for feasibility against the production platform, and a supporting field application "
        "developed and tested."),

  ("h2", "2.1 Dataset Audit"),
  ("p", "The existing project export was analysed programmatically. It comprised 213 shelf photographs "
        "partitioned into training (173), validation (24), and test (16) splits, containing 4,641 manually "
        "drawn bounding boxes across six manufacturer classes: coca-cola, cappy, xl_energy, sprite, fanta, "
        "and pepsi. The project had grown incrementally, beginning with coca-cola and xl_energy before the "
        "remaining four brands were introduced — an expansion pattern that itself exemplifies the "
        "catalogue growth problem examined in Section 3."),
  ("p", "Class distribution analysis revealed pronounced imbalance: the largest class accounted for 42.2% "
        "of all annotations while the smallest accounted for 2.8%, a ratio of approximately 15:1. This "
        "concentration provides a direct statistical account of the low recall observed on sparsely "
        "represented brands."),

  ("h2", "2.2 Geometric Relabelling"),
  ("p", "A relabelling scheme based on physical packaging format rather than brand was derived. For each "
        "annotation, the aspect ratio was computed from the stored box coordinates and mapped to one of "
        "four format classes — can-std-330, can-slim, bottle-pet, and unknown-package — using empirically "
        "determined ratio bands. Annotations were regenerated programmatically in Pascal VOC XML format "
        "and migrated to a separate project."),

  ("h2", "2.3 Ambiguity Flagging"),
  ("p", "Rather than assuming that every box admits a confident format assignment, each annotation was "
        "assessed for evidential reliability during relabelling and flagged where compromised. Of the "
        "4,641 annotations, 194 (4.2%) were flagged as truncated — the object intersecting the frame "
        "boundary or extending beyond a close-up view — and 1,954 (42.1%) were flagged as difficult, "
        "denoting occlusion, oblique perspective, or specular interference sufficient to render the "
        "derived geometry unreliable."),
  ("p", "That over two-fifths of the corpus required an ambiguity flag is itself a principal empirical "
        "finding of the training. It establishes that ambiguity in field imagery is structural rather than "
        "exceptional, and consequently that a deployed system must incorporate a verification mechanism by "
        "design rather than treat correction as an exceptional recovery path."),

  ("h2", "2.4 Platform Feasibility Assessment"),
  ("p", "The proposed architecture was evaluated block-by-block against the component catalogue of "
        "Roboflow Workflows to confirm that each stage could be realised natively within the platform. "
        "The findings are reported in Section 9."),

  ("h2", "2.5 Application Development"),
  ("p", "A cross-platform data collection application was implemented in Flutter to support structured "
        "field capture, automated analysis, and human verification. Its architecture and the reasoning "
        "behind it are described in Section 10."),
 ]),

 ("3. The Catalogue Expansion Problem", [
  ("p", "A single-stage detector that classifies each product directly by its identity inherits a serious "
        "maintenance liability: the retail catalogue is not static. New stock-keeping units (SKUs) enter "
        "the market continuously, and under a monolithic design each addition requires retraining the "
        "entire detection model — expensive in computation, in annotation effort, and in time, and "
        "degrading a system that was previously working correctly for all existing products."),
  ("p", "A second, statistical problem was observed in the dataset directly. When a fixed corpus of 213 "
        "images is partitioned across many brand classes, each class receives only a small share of the "
        "available examples. The model consequently learns well on densely represented classes and "
        "performs poorly on the remainder, producing the low recall — products present on the shelf but "
        "never detected — observed in the existing model."),
  ("p", "The project's own history illustrates the mechanism directly: the earliest trained model version "
        "was fitted on 27 images, before most classes existed, and remained the workflow default long "
        "after the catalogue had grown beyond it. Coverage of the newer brands was therefore governed not "
        "by any deficiency of the detection method but by which model version the pipeline happened to "
        "invoke."),
  ("fig", "fig5_distribution", "Annotation distribution before and after geometric relabelling. The same "
        "4,641 boxes are partitioned by manufacturer brand (left) and by physical packaging format "
        "(right)."),
 ]),

 ("4. Class-Agnostic Detection", [
  ("p", "The response to both problems is to strip the detection stage of identity information entirely. "
        "In a class-agnostic detector, every product is assigned a single generic class — product — "
        "regardless of brand, flavour, or packaging, and the model is trained to answer only the question "
        "of whether a product is present at a given location."),
  ("p", "This yields two distinct benefits. Statistically, the entire corpus contributes to a single class "
        "rather than being fragmented, substantially increasing the effective training signal without "
        "collecting a single additional image. Architecturally, the detection layer becomes stable: "
        "holding no knowledge of product identity, it is not invalidated by the introduction of a new SKU "
        "and need not be retrained."),
  ("p", "An important practical qualification was established during the training: relabelling existing "
        "annotations to a generic class corrects mislabelled boxes, but cannot recover products that were "
        "never annotated at all. Missing annotations remain a separate data-completeness task, and no "
        "reorganisation of the label space substitutes for them."),
 ]),

 ("5. Recognition by Embedding Similarity", [
  ("p", "Once localization is decoupled, identity must be resolved separately. The approach studied "
        "replaces conventional supervised classification with embedding-based retrieval: each detected "
        "region is cropped and passed through a vision-language model — CLIP — which maps the image into a "
        "high-dimensional numerical vector. Classification is performed by finding the nearest neighbour "
        "among a reference gallery of clean, known product images."),
  ("p", "The decisive property of this approach is that adding a new product requires only adding its "
        "reference image to the gallery; no retraining occurs. This transforms catalogue maintenance from "
        "a model-training operation into a data-entry operation, which is the central reason the pattern "
        "is favoured in production retail systems."),
 ]),

 ("6. The Geometric Limitation of Visual Similarity", [
  ("p", "A significant limitation of embedding-based recognition was identified during the training, and "
        "its mechanism established precisely. CLIP resizes every crop to a fixed square input — 224 by 224 "
        "pixels — before encoding it. This operation discards aspect ratio by construction: a tall narrow "
        "container and a shorter wider one arrive at the encoder having been stretched to the same shape. "
        "The model is therefore not merely insensitive to physical proportion; the information has been "
        "removed before inference begins."),
  ("p", "The consequence is acute for products that differ only in packaging format. A standard 330 ml can "
        "measures approximately 66 mm in diameter by 115 mm in height, a ratio of about 1.74; a sleek "
        "330 ml can measures approximately 53 mm by 145 mm, a ratio of about 2.7. The two hold identical "
        "contents and carry identical branding, so proportion is the only reliable distinguishing signal — "
        "and it is precisely the signal the embedding cannot see."),
  ("p", "This was confirmed empirically. On a shelf photograph holding both formats side by side, the "
        "visual classifier assigned all ten cans to a single class, while the detector's own bounding "
        "boxes separated the two clusters cleanly: standard cans measured between 1.72 and 1.82, and sleek "
        "cans between 2.30 and 2.58, with an empty band between them. A decision threshold of 2.05 sits "
        "within that empty band, so neither cluster lies near it."),
  ("p", "The resolution adopted recognises that the required discriminating information has already been "
        "produced by the detection stage. The aspect ratio of the bounding box is a direct geometric "
        "consequence of the container's physical form, and is approximately invariant to camera distance, "
        "since zooming scales both dimensions proportionally and leaves their ratio unchanged. Neither "
        "signal suffices alone: the visual embedding determines which product the object is, while "
        "bounding-box geometry determines which physical format it takes."),
  ("fig", "fig2_aspect_ratio", "Geometric discrimination of packaging format. Left: two containers of "
        "identical labelling and equal volume but differing proportion. Right: the observed aspect-ratio "
        "distribution across all 4,641 annotations, showing contiguous non-overlapping bands."),
 ]),

 ("7. Data Quality Factors in Uncontrolled Imagery", [
  ("p", "Because the aspect-ratio signal derives from the geometry of the annotated box, its reliability "
        "depends directly on the fidelity of that box to the real object. Several failure modes were "
        "catalogued during the training, each degrading this fidelity in a distinct way."),
  ("b", "Truncation. Objects intersecting the frame boundary, and close-up photographs in which the "
        "container extends beyond the visible area, produce partial boxes. The measured height is then a "
        "lower bound rather than a measurement, and a sleek can may read as standard. This mode is not "
        "merely theoretical: it accounted for 4.2% of the corpus and required an explicit guard in the "
        "implemented decision rule."),
  ("b", "Perspective distortion. A container photographed from an oblique angle or from above projects "
        "onto the image plane with altered proportions, so the same physical product can yield materially "
        "different aspect ratios across viewpoints."),
  ("b", "Occlusion and dense packing. Products arranged in tight rows partially obscure one another, "
        "making boundaries ambiguous and occasionally causing a single box to enclose portions of two "
        "adjacent units."),
  ("b", "Specular reflection. The reflective metal surfaces of beverage cans scatter light and blur "
        "perceived edges, reducing the precision with which boundaries can be placed."),
  ("b", "Inherited annotation error. Where an original box was drawn loosely or tightly relative to the "
        "true product outline, any geometric quantity derived from it inherits that error unchanged."),
  ("p", "A methodological principle follows directly: when geometric evidence is compromised, the correct "
        "outcome is an explicit deferral rather than a low-confidence guess, since a wrong label "
        "propagates silently into downstream commercial reporting. This principle was implemented "
        "literally — the geometric rule declines to judge any box touching the frame edge, leaving the "
        "classifier's original label in place — and it motivated the human verification interface "
        "described in Section 10."),
 ]),

 ("8. Hierarchical Pipeline Architecture", [
  ("p", "The concepts above compose into a three-stage architecture in which each stage narrows the "
        "decision space presented to the next."),
  ("p", "Stage One, class-agnostic detection, locates every product on the shelf under a single generic "
        "class, producing bounding boxes, unit counts, spatial positions, and the geometric measurements "
        "required later. Stage Two, manufacturer classification, matches each cropped region to a "
        "manufacturer by embedding similarity; this layer is small and stable, since the set of "
        "manufacturers in a market changes far more slowly than the set of products, making it well suited "
        "to a training-free approach. Stage Three, product and format classification, operates within the "
        "narrowed candidate set established by Stage Two: a trained classifier resolves the specific brand "
        "variant while bounding-box geometry resolves the packaging format."),
  ("p", "Restricting comparison to one manufacturer's catalogue rather than the entire market materially "
        "reduces visual confusion between candidates. It should be noted that all stages after the first "
        "are classification operations: the pipeline is detect, then classify, then classify — not "
        "repeated detection. Localization is computed once and reused, since spatial coordinates do not "
        "change between stages."),
  ("p", "A representative class hierarchy illustrates the separation of concerns. Stage One assigns "
        "product; Stage Two assigns coca-cola; Stage Three assigns the full SKU identifier, where the "
        "visual classifier supplies the brand variant and the geometric rule supplies the format "
        "distinction."),
  ("fig", "fig3_pipeline", "Block diagram of the three-stage pipeline, showing the flow from raw shelf "
        "image through class-agnostic detection, region cropping, manufacturer classification, and the "
        "fusion of visual and geometric evidence at SKU level."),
 ]),

 ("9. Platform Implementation", [
  ("p", "The proposed architecture was mapped onto Roboflow Workflows, the platform in operational use. "
        "Verification against the platform documentation confirmed that every required component exists "
        "natively, with a single exception."),
  ("table", ["Pipeline function", "Platform component", "Training required"], [
      ["Class-agnostic detection", "Object Detection Model", "Yes"],
      ["Region extraction", "Dynamic Crop", "No"],
      ["Manufacturer classification", "CLIP Comparison", "No (zero-shot)"],
      ["Product / variant classification", "Single-Label Classification Model", "Yes"],
      ["Format discrimination by geometry", "Dynamic Python Block", "No (rule-based)"],
   ], "Mapping of pipeline stages onto native platform components."),
  ("p", "The geometric decision rule is the only component without a ready-made equivalent. It is "
        "implemented through a Dynamic Python Block, which permits custom logic to consume the outputs of "
        "preceding blocks — reading bounding-box dimensions and applying the aspect-ratio threshold "
        "separating packaging formats. This represents a small quantity of code rather than an additional "
        "trained model. In the delivered application the same rule is implemented client-side, "
        "demonstrating that the fusion step is portable across execution contexts."),
  ("p", "The workflow additionally exposes runtime parameters — confidence threshold, intersection-over-"
        "union threshold, class-agnostic non-maximum suppression, maximum detection count, and model "
        "version — which the application surfaces to the operator, so that detection behaviour can be "
        "tuned in the field without redeployment."),
 ]),

 ("10. Field Data Collection Application", [
  ("p", "A recurring theme of the analysis is that model output on uncontrolled imagery cannot be treated "
        "as final: ambiguous cases arise structurally, not incidentally. A cross-platform application was "
        "therefore developed in Flutter to serve three roles — standardising field capture at the point of "
        "collection, running the analysis pipeline against the captured image, and interposing human "
        "verification between model inference and committed data."),
  ("p", "The delivered application comprises 60 Dart source files totalling approximately 10,800 lines, "
        "organised into six layers, and is accompanied by 20 test files totalling approximately 4,100 "
        "lines."),
  ("table", ["Layer", "Modules", "Responsibility"], [
      ["Screens", "12", "Authentication, capture, review, administration, visit flow"],
      ["Services", "14", "Detection, camera, authentication, market and visit persistence"],
      ["Models", "13", "Detections, bounding boxes, shape rules, share-of-shelf, user profiles"],
      ["Widgets", "17", "Detection overlays, editors, adaptive layout, result panels"],
      ["Config / Theme", "4", "Runtime configuration and presentation tokens"],
   ], "Composition of the delivered application by architectural layer."),

  ("h2", "10.1 Structured Capture"),
  ("p", "The application implements a role-differentiated flow. Company administrators define and manage "
        "the set of markets under audit and review team access requests; field representatives select a "
        "market, capture shelf imagery through a dedicated camera interface with selectable aspect ratio, "
        "and persist the result against that market as part of a recorded visit. Binding every image to a "
        "known market at capture time ensures that collected data carries the contextual metadata required "
        "for downstream commercial analysis, rather than arriving as unattributed photographs."),

  ("h2", "10.2 Human-in-the-Loop Verification"),
  ("p", "A detection editor allows the operator to review model-produced detections and correct them "
        "before submission. This component addresses the failure modes of Section 7 operationally: where "
        "truncation, occlusion, or perspective renders an automatic classification unreliable, the "
        "operator resolves it rather than allowing a low-confidence label to propagate. The corrections "
        "additionally constitute a supervised signal suitable for subsequent retraining, so routine field "
        "use generates training data as a by-product of normal operation."),

  ("h2", "10.3 Commercial Measurement"),
  ("p", "The application converts verified detections into a share-of-shelf measure: for each class, the "
        "bounding-box areas are summed and divided by the total detected area across all classes. The "
        "measure is deliberately simple and is documented as a relative facing-space proxy rather than a "
        "true occupancy measurement, since overlapping boxes are not de-duplicated. Stating that "
        "limitation explicitly, rather than presenting the figure as exact, is itself part of the design."),

  ("h2", "10.4 Cross-Platform Delivery"),
  ("p", "The interface was implemented responsively for both mobile and desktop viewports, with attention "
        "to theme contrast and legibility, reflecting the operational reality that capture occurs on "
        "handheld devices in variable store lighting while review and administration occur on desktop."),
  ("fig", "fig4_placeholder", "Screenshots of the application: the market selection and capture screens, "
        "and the detection editor showing a model prediction under operator review."),
 ]),

 ("11. Results and Outcomes", [
  ("table", ["Measure", "Before", "After"], [
      ["Shelf images", "213", "213"],
      ["Bounding boxes", "4,641", "4,641"],
      ["Classification classes", "6 (brand)", "4 (format)"],
      ["Detection classes", "6", "1 (product)"],
      ["Largest : smallest class", "15 : 1", "12 : 1"],
      ["Annotations per detection class", "774 (mean)", "4,641"],
   ], "Effect of the relabelling and class-collapse on the training corpus."),
  ("p", "The most consequential quantitative outcome is the sixfold increase in the number of annotations "
        "contributing to a single detection class, achieved without collecting additional imagery. Under "
        "the original scheme the detector received a mean of 774 examples per class, with the sparsest "
        "brand supported by only 131; under the class-agnostic scheme the full corpus of 4,641 boxes "
        "supports the single detection objective."),
  ("p", "Aspect-ratio analysis further established that the four packaging formats occupy contiguous, "
        "non-overlapping ratio bands — unknown-package below 1.0, can-std-330 between 1.0 and 2.1, "
        "can-slim between 2.1 and 2.9, and bottle-pet above 2.9 — with class medians of 0.54, 1.73, 2.57, "
        "and 3.26 respectively. This separation is the empirical basis for treating box geometry as a "
        "usable discriminative signal."),
  ("p", "The tangible deliverables of the training period were: a geometrically relabelled annotation set "
        "derived programmatically from the original brand-labelled corpus; a documented three-stage system "
        "architecture with a verified component-level mapping onto the production platform; and a "
        "functioning cross-platform field application supporting structured capture, automated analysis, "
        "human verification, and share-of-shelf reporting."),
 ]),

 ("12. Reflection on Learning Outcomes", [
  ("p", "The most consequential lesson of the training was that the decisive question in an applied vision "
        "system is frequently not which model performs best, but how responsibility should be divided "
        "between components. Considerable time was initially directed toward improving classification "
        "accuracy within a single-stage design before it became apparent that the accuracy ceiling was "
        "imposed by the architecture rather than by the model."),
  ("p", "A second lesson concerned the value of identifying a model's representational boundary rather "
        "than attempting to overcome it by training. Establishing not merely that CLIP failed to "
        "distinguish the two can formats, but why — that the square resize discards aspect ratio before "
        "encoding — converted an apparently stubborn accuracy problem into a solved one, and did so with a "
        "rule of a few lines rather than additional data collection."),
  ("p", "A third lesson emerged from the annotation work: the effort required to produce reliable "
        "annotations at scale is routinely underestimated, and design decisions that reduce annotation "
        "burden — such as collapsing many classes into one — can improve system outcomes more than "
        "algorithmic refinements. Relatedly, discovering that a stale default model version was governing "
        "live behaviour was a reminder that in deployed systems, configuration is as consequential as "
        "modelling, and considerably easier to overlook."),
 ]),

 ("13. Conclusions", [
  ("p", "The principal insight of the training period is architectural rather than algorithmic: "
        "maintainability in a domain with a continuously expanding catalogue is determined less by the "
        "accuracy of any single model than by how responsibilities are partitioned between components. "
        "Isolating the volatile part of the problem — product identity — from the stable part — object "
        "presence — allows the system to absorb catalogue growth through data updates rather than model "
        "retraining."),
  ("p", "A second conclusion concerns the complementarity of evidence types. Learned visual "
        "representations and explicit geometric measurements fail and succeed under different conditions; "
        "a system fusing both is materially more robust than one relying on either alone. Recognising the "
        "boundary of what a learned representation can encode, and supplying the missing information by "
        "other means, proved more productive than attempting to train the limitation away."),
  ("p", "Finally, the training demonstrated that data quality constrains the achievable ceiling of any "
        "architecture, and that an operational system should therefore be designed to expect ambiguity "
        "rather than to assume its absence. That over two-fifths of the annotations required an ambiguity "
        "flag makes the case quantitatively. The verification interface developed during the period "
        "embodies the resulting principle: rather than treating human correction as a fallback for model "
        "failure, it treats it as a permanent component of the data pipeline and a continuing source of "
        "supervised training signal."),
 ]),
]

REFERENCES = [
 "Radford, A., Kim, J. W., Hallacy, C., et al. (2021). Learning Transferable Visual Models From Natural "
 "Language Supervision. Proceedings of the 38th International Conference on Machine Learning (ICML).",

 "Goldman, E., Herzig, R., Eisenschtat, A., Goldberger, J., & Hassner, T. (2019). Precise Detection in "
 "Densely Packed Scenes. IEEE Conference on Computer Vision and Pattern Recognition (CVPR).",

 "Ren, S., He, K., Girshick, R., & Sun, J. (2015). Faster R-CNN: Towards Real-Time Object Detection with "
 "Region Proposal Networks. Advances in Neural Information Processing Systems (NeurIPS).",

 "Redmon, J., Divvala, S., Girshick, R., & Farhadi, A. (2016). You Only Look Once: Unified, Real-Time "
 "Object Detection. IEEE Conference on Computer Vision and Pattern Recognition (CVPR).",

 "Schroff, F., Kalenichenko, D., & Philbin, J. (2015). FaceNet: A Unified Embedding for Face Recognition "
 "and Clustering. IEEE Conference on Computer Vision and Pattern Recognition (CVPR).",

 "Deng, J., Guo, J., Xue, N., & Zafeiriou, S. (2019). ArcFace: Additive Angular Margin Loss for Deep Face "
 "Recognition. IEEE Conference on Computer Vision and Pattern Recognition (CVPR).",

 "Everingham, M., Van Gool, L., Williams, C. K. I., Winn, J., & Zisserman, A. (2010). The PASCAL Visual "
 "Object Classes (VOC) Challenge. International Journal of Computer Vision, 88(2), 303–338.",

 "Lin, T.-Y., Maire, M., Belongie, S., et al. (2014). Microsoft COCO: Common Objects in Context. European "
 "Conference on Computer Vision (ECCV).",

 "Oquab, M., Darcet, T., Moutakanni, T., et al. (2023). DINOv2: Learning Robust Visual Features without "
 "Supervision. Transactions on Machine Learning Research (TMLR).",

 "Roboflow. Workflows Documentation. https://inference.roboflow.com/workflows/ (accessed August 2026).",
]
