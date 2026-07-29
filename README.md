# Shelf Monitor

A Flutter app that photographs a retail shelf, runs it through a Roboflow
object-detection workflow, and reports **Share of Shelf** — how much of the
detected shelf space each brand occupies.

---

## Requirements

- Flutter **3.44+** (Dart 3.12+)
- An Android or iOS device — the primary flow uses the live camera, so an
  emulator without a camera falls back to picking a photo from the gallery
- A Roboflow account with access to the `ma7mouds-workspace` workspace

---

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Create your `.env`

The app reads its Roboflow credentials from a `.env` file that is **git-ignored**
and never committed. Copy the template and fill in your key:

```bash
cp .env.example .env
```

Then edit `.env` and set `ROBOFLOW_API_KEY` to your **private** API key from
[app.roboflow.com/settings/api](https://app.roboflow.com/settings/api):

```ini
ROBOFLOW_API_KEY=your_real_key_here
ROBOFLOW_WORKSPACE=ma7mouds-workspace
ROBOFLOW_WORKFLOW_ID=aystro-project
ROBOFLOW_BASE_URL=https://serverless.roboflow.com
```

> **`.env` is required to build.** It is declared as a Flutter asset in
> `pubspec.yaml`, so the build fails with `asset not found` until the file
> exists. Creating it from `.env.example` is enough to compile; a real key is
> only needed to actually run detection.
>
> Without a valid key the app still launches and captures photos — the results
> area simply stays on its placeholder rather than crashing.

### 3. Run

```bash
flutter run
```

Grant the camera permission when prompted. Point at a shelf, tap the shutter,
and the capture is analysed automatically.

---

## Project structure

Separation of concerns is enforced by layer — widgets never touch HTTP, and the
UI has no knowledge of Roboflow's response format.

```
lib/
├── config/
│   └── app_config.dart               # Typed access to .env; the only reader of secrets
├── models/                           # Roboflow-agnostic types the UI consumes
│   ├── bounding_box.dart             # Centre+size box, area, display projection
│   ├── detection.dart                # One detected product
│   ├── detection_result.dart         # Result of analysing one image
│   └── share_of_shelf.dart           # Share-of-Shelf calculation
├── screens/
│   └── capture_screen.dart           # Camera → capture → analyse → display
├── services/
│   ├── camera_service.dart           # Camera lifecycle, gallery fallback
│   ├── detection_service.dart        # Interface the UI depends on
│   ├── detection_exception.dart      # Typed error hierarchy
│   ├── roboflow_service.dart         # REST client: auth, retries, timeouts
│   └── workflow_response_parser.dart # Raw JSON → DetectionResult
└── widgets/
    ├── capture_controls.dart         # Shutter / retake / gallery
    ├── detection_overlay.dart        # CustomPainter drawing boxes + labels
    ├── results_panel.dart            # Idle / loading / error / results states
    └── share_of_shelf_panel.dart     # Proportional bar + legend
```

The key seam is `DetectionService`. `CaptureScreen` depends on that interface,
not on `RoboflowService`, so the backend can be swapped or faked in tests
without touching a widget.

---

## The Roboflow integration

### The workflow

The app calls the saved workflow **`aystro-project — Base Workflow`**. Its real
definition (read from the Roboflow API, not assumed) is:

| | |
|---|---|
| **Workspace** | `ma7mouds-workspace` |
| **Workflow** | `aystro-project` |
| **Endpoint** | `POST https://serverless.roboflow.com/ma7mouds-workspace/workflows/aystro-project` |
| **Model** | `roboflow_core/roboflow_object_detection_model@v3` |
| **Classes** | `coca-cola`, `cappy`, `xl_energy` |
| **Output** | one `JsonField` named `predictions` |

Declared runtime parameters, mirrored exactly in `RoboflowParameters`:

| Parameter | Type | Default |
|---|---|---|
| `confidence` | double | `0.4` |
| `iou_threshold` | double | `0.3` |
| `class_agnostic_nms` | bool | `false` |
| `max_detections` | int | `1000` |
| `model_id` | string | `aystro-project/1` |

### The request

There is no official Dart SDK, so `RoboflowService` posts to the REST endpoint
directly via `package:http`, mirroring the JS/Python SDKs. Captured photos are
local files rather than hosted URLs, so the image is sent base64-encoded:

```jsonc
POST /ma7mouds-workspace/workflows/aystro-project
Content-Type: application/json

{
  "api_key": "<from .env>",
  "inputs": { "image": { "type": "base64", "value": "<jpeg bytes>" } },
  "parameters": { "confidence": 0.4, "iou_threshold": 0.3, ... }
}
```

Each call has a **45s timeout** and **up to 3 attempts** with exponential
backoff (500ms, 1s). Only retryable failures are repeated — a `401` from a bad
API key fails immediately rather than burning all three attempts. Every failure
surfaces as a typed `DetectionException`:

| Exception | Meaning | Retryable |
|---|---|---|
| `DetectionConfigException` | `.env` missing or key unset | no |
| `DetectionNetworkException` | timeout, DNS, socket failure | yes |
| `DetectionApiException` | non-200 from Roboflow | 5xx / 429 only |
| `DetectionParseException` | body not valid or not detection-shaped | no |

### The response

A real response, recorded from the deployed workflow and checked in as
`test/fixtures/workflow_response.json`:

```json
{ "result": [ { "predictions": {
    "image": { "width": 720, "height": 540 },
    "predictions": [
      { "x": 624, "y": 70, "width": 48, "height": 140,
        "confidence": 0.448, "class": "coca-cola", "class_id": 0 }
    ] } } ] }
```

Note the envelope key is `result`, not `outputs`, and boxes are **centre-based**
(`x`/`y` are the centre, not the corner).

`WorkflowResponseParser` parses this **defensively**, and deliberately does not
hard-code the output name:

- It **discovers** which output holds the detections by probing each one for a
  recognisable shape, so renaming `predictions` in the Roboflow editor — or
  adding a visualisation output — will not break the app.
- It accepts both `result` and `outputs` envelopes (serverless vs. self-hosted).
- It reads **only the fields the UI uses**. Segmentation `points` are dropped at
  parse time and never retained — polygon arrays dwarf the rest of the payload.
- Image-shaped outputs are decoded to bytes and held in memory for
  `Image.memory`, never written to logs. This workflow has no visualisation
  block, so none come back today; the path exists for when one is added.
- An empty prediction list is a valid result, not an error.

### ⚠️ Inference is not side-effect free

The published workflow includes a `roboflow_core/roboflow_dataset_upload` step.
**Every successful detection call also uploads the photo into the
`aystro-project` dataset** under an `active_learning` batch, consuming upload
quota. That is the workflow's own behaviour, not this client's — remove that
step in the Roboflow editor if you don't want captures retained.

---

## Share of Shelf

Computed in `ShareOfShelf.fromDetections`, entirely client-side:

1. For each detection, take its bounding-box area (`width × height`).
2. Sum areas per class.
3. Divide each class total by the total detected area across **all** classes.

Rendered as a proportional bar, a per-brand legend, and the single-line summary:

```
coca-cola: 65% | pepsi: 35%
```

Boxes with zero or negative dimensions are ignored rather than skewing the
totals, and shares are sorted largest-first with alphabetical tie-breaking so
ordering is stable across runs.

**What this measures:** relative facing space among *detected* products.
Overlapping boxes are **not** de-duplicated, and empty shelf space is not
counted, so this is a proxy for brand prominence rather than a true occupancy
measurement. Two boxes covering the same bottle count twice.

---

## Testing

```bash
flutter analyze
flutter test
```

23 tests, no network and no API key required. The suite covers:

- **Smoke test** (`test/services/roboflow_service_test.dart`) — runs
  `RoboflowService.detectProducts()` over a sample image with the HTTP layer
  stubbed to replay the *real* recorded workflow response, asserting the
  expected output key (`predictions`) and detection fields are present and
  parsed correctly.
- **Request shape** — asserts the outgoing body carries `api_key`, a base64
  `inputs.image`, and parameter names matching the workflow's declared inputs.
- **Failure handling** — 401 fails fast, 503 retries to the attempt limit,
  malformed output raises a parse error, missing key raises a config error.
- **Share of Shelf** — area weighting, ordering, degenerate boxes, fractions
  summing to 1.
- **Widgets** — each results-panel state and the capture screen.

---

## Notes and limitations

- **Single images only.** This uses the standard HTTP inference path. Live video
  (webcam / RTSP / file streaming) requires Roboflow's WebRTC path, which is not
  implemented here.
- **Mobile targets only.** The project is configured for Android and iOS. A web
  build would ship the private API key to the browser, so it would need the
  Roboflow call moved behind a server-side proxy first.
- Detection accuracy is bounded by the `aystro-project/1` model, which currently
  knows three classes.
- Captured images are resized by the camera preset (`ResolutionPreset.high`) and
  gallery picks are capped at 2048px to keep base64 payloads reasonable.
