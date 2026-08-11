# Stage 3 — geometric format refinement, for a Roboflow Dynamic Python Block.
#
# Port of lib/models/can_shape_rule.dart so the rule runs server-side in the
# workflow as well as client-side in the app. Keep the two in sync: if the
# threshold changes here, change it there too.
#
# WHY THIS BLOCK EXISTS
# ---------------------
# Stage 2 tells us which brand a detection is. It cannot tell us which physical
# format, because CLIP-style encoders resize every crop to a fixed square before
# embedding it, which throws the aspect ratio away — a tall slim can and a short
# standard can arrive at the encoder looking identical. The detector's own box
# still carries that information, so the format is read straight off the box.
#
# Measured on a shelf holding both formats side by side:
#   standard 330 ml   h/w  1.72 – 1.82
#   slim     330 ml   h/w  2.30 – 2.58
# The threshold sits in the empty band between the two clusters.
#
# WIRING IN THE WORKFLOW
# ----------------------
# Input `detections` should be the output of the block that has already merged
# the Stage 2 brand labels back onto the Stage 1 boxes (Detections Classes
# Replacement), so `class_name` holds the brand by the time this block runs.
#
# The parameter name below must match the input name you declare in the block's
# UI, and the returned key must match the declared output. Adjust both to
# whatever the block editor shows — the logic in between is what matters.

SLIM_ASPECT_RATIO = 2.05

# Brands sold in both a standard and a slim 330 ml can. A brand that is not in
# this map is passed through untouched: format only means something where two
# formats actually exist, and inventing a suffix elsewhere would be a lie.
DUAL_FORMAT_BRANDS = {
    "coca-cola": ("coca-cola-can-slim", "coca-cola-can-std"),
    "xl_energy": ("xl_energy-can-slim", "xl_energy-can-std"),
}

EDGE_TOLERANCE = 2.0


def run(self, detections, image):
    """Relabel dual-format detections from the shape of their box.

    Returns the same detection set with `class_name` rewritten where — and only
    where — the geometry is trustworthy enough to carry the decision.
    """
    if detections is None or len(detections) == 0:
        return {"detections": detections}

    height, width = image.numpy_image.shape[:2]
    names = list(detections.data.get("class_name", []))

    for i in range(len(detections)):
        brand = names[i]
        if brand not in DUAL_FORMAT_BRANDS:
            continue

        x1, y1, x2, y2 = (float(v) for v in detections.xyxy[i])
        box_w, box_h = x2 - x1, y2 - y1
        if box_w <= 0 or box_h <= 0:
            continue

        # A box running into the edge of the frame measures the visible part of
        # the object, not the object. Its height understates the real one, so a
        # slim can would read as standard — decline rather than guess.
        touches_frame = (
            x1 <= EDGE_TOLERANCE
            or y1 <= EDGE_TOLERANCE
            or x2 >= width - EDGE_TOLERANCE
            or y2 >= height - EDGE_TOLERANCE
        )
        if touches_frame:
            continue

        slim_class, std_class = DUAL_FORMAT_BRANDS[brand]
        names[i] = slim_class if box_h / box_w >= SLIM_ASPECT_RATIO else std_class

    detections.data["class_name"] = names
    return {"detections": detections}
