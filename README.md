# Shelf Monitor

A Flutter app that photographs a retail shelf, runs it through a Roboflow
object-detection workflow, and reports **Share of Shelf** — how much of the
detected shelf space each brand occupies.

---

Runs on **Android, iOS, and web** (deployable to Vercel).

## Requirements

- Flutter **3.44+** (Dart 3.12+)
- An Android or iOS device — the primary flow uses the live camera, so an
  emulator or browser without a camera falls back to picking a photo
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

## Deploying to Vercel

The app builds to static web and deploys to Vercel, with one important
difference from the mobile build.

### Why web needs a proxy

`flutter_dotenv` loads `.env` as a Flutter **asset**. On web that means
`flutter build web` copies it verbatim to `build/web/assets/.env` — a URL any
visitor can open. **A private Roboflow key in a web build is a published key.**

So the web build ships no key at all. Instead it posts to a same-origin
serverless function, `api/detect.js`, which holds `ROBOFLOW_API_KEY` as a Vercel
environment variable and forwards the request to Roboflow. The response is
relayed unchanged, so the Dart parser is identical in both modes.

```
mobile   Flutter ──[api_key + image]──────────────► Roboflow
web      Flutter ──[image only]──► /api/detect ──[+ api_key]──► Roboflow
```

`AppConfig.usesProxy` picks the mode: always true on web (`kIsWeb`), or whenever
`ROBOFLOW_PROXY_URL` is set. In proxy mode `RoboflowService` omits `api_key`
from the body entirely — there is a test asserting exactly that.

### Deploy steps

1. Import the repo at [vercel.com/new](https://vercel.com/new). `vercel.json`
   supplies the build command and output directory, so no framework preset is
   needed.
2. Add the environment variable **`ROBOFLOW_API_KEY`** in
   *Project → Settings → Environment Variables*. This is the only place the key
   lives for web. Optionally override `ROBOFLOW_WORKSPACE`,
   `ROBOFLOW_WORKFLOW_ID`, `ROBOFLOW_BASE_URL`, and `ALLOWED_ORIGIN`.

   > **Check the variable's name character by character.** A typo here produces
   > `500 {"message": "Detection is not configured."}` — the same error as a
   > missing key, with nothing to distinguish them. This deployment was broken
   > for a while by `ROBOFLOW_API_KE` (missing the trailing `Y`).
   >
   > `api/detect.js` resolves the key from `API_KEY_NAMES`, which currently
   > carries that misspelling as a compatibility alias. Once the variable is
   > renamed to the canonical spelling, drop the alias.

   > **Environment variables are snapshotted when a deployment is created.**
   > Adding or changing one does not affect deployments that already exist —
   > redeploy afterwards, or the running function keeps the old (or absent)
   > value.
3. Deploy. `scripts/vercel-build.sh` fetches the pinned Flutter SDK, writes a
   **keyless** `.env` placeholder, builds `build/web`, and then runs the leak
   check below.

### Diagnosing a 500 from `/api/detect`

The function checks the key *before* validating the body, so a request with an
empty JSON body separates the two failure modes without running inference or
touching your dataset:

```bash
curl -sS -X POST https://<your-deployment>/api/detect \
  -H 'Content-Type: application/json' -d '{}'
```

- `500 {"message":"Detection is not configured."}` → the key is not reaching the
  function: wrong name, empty value, or a deployment created before it was added.
- `400 {"message":"Expected inputs.image ..."}` → the key resolved fine; the
  problem is elsewhere.

### Verifying no key leaked

```bash
flutter build web --release
./scripts/check-web-bundle.sh
```

Fails the build if a Roboflow key is present anywhere in `build/web`. It runs
automatically as part of the Vercel build. Run it locally too — if your `.env`
has a real key, a local `flutter build web` **will** bake it into the bundle.

### Camera on web

Browsers expose the camera through `getUserMedia`, which requires **HTTPS**
(Vercel provides this) and an explicit user permission grant. The
`Permissions-Policy` header in `vercel.json` allows `camera=(self)`. Where the
live camera is unavailable — or the user declines — the screen falls back to the
photo picker, which works in every browser.

---

## Project structure

Separation of concerns is enforced by layer — widgets never touch HTTP, and the
UI has no knowledge of Roboflow's response format.

```
api/
└── detect.js                         # Vercel serverless proxy; holds the key server-side
scripts/
├── vercel-build.sh                   # Flutter web build for Vercel
└── check-web-bundle.sh               # Fails if a key leaked into build/web
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

A real response, recorded from the live serverless endpoint and checked in as
`test/fixtures/workflow_response.json`:

```json
{ "outputs": [ { "predictions": {
    "image": { "width": 720, "height": 540 },
    "predictions": [
      { "x": 624, "y": 70, "width": 48, "height": 140,
        "confidence": 0.448, "class": "coca-cola", "class_id": 0,
        "detection_id": "...", "parent_id": "image" }
    ] } } ],
  "profiler_trace": [] }
```

Three things worth knowing, all verified against the live endpoint:

- The envelope key is **`outputs`**. Some tooling (the Roboflow MCP server among
  it) normalises the same payload to `result`, so the parser accepts both.
- Boxes are **centre-based** — `x`/`y` are the centre, not the top-left corner.
- `image.width`/`height` come back **`null` when nothing is detected**. Since
  boxes cannot be projected without dimensions, `RoboflowService` decodes them
  from the captured bytes and passes them as a fallback.

`WorkflowResponseParser` parses this **defensively**, and deliberately does not
hard-code the output name:

- It **discovers** which output holds the detections by probing each one for a
  recognisable shape, so renaming `predictions` in the Roboflow editor — or
  adding a visualisation output — will not break the app.
- It accepts both `outputs` (the REST endpoint) and `result` (normalised by some
  tooling) envelopes.
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

30 tests, no network and no API key required. The suite covers:

- **Smoke test** (`test/services/roboflow_service_test.dart`) — runs
  `RoboflowService.detectProducts()` over a sample image with the HTTP layer
  stubbed to replay the *real* recorded workflow response, asserting the
  expected output key (`predictions`) and detection fields are present and
  parsed correctly.
- **Request shape** — asserts the outgoing body carries `api_key`, a base64
  `inputs.image`, and parameter names matching the workflow's declared inputs.
- **Response envelopes** — both `outputs` and `result` parse identically, and a
  response with null image dimensions falls back to the source image's own size.
- **Proxy mode** — asserts the request body contains **no** `api_key` and no
  trace of the key when proxied, and that a proxied response parses identically.
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
- **Never put a real key in `.env` for a web build.** It becomes a public URL.
  Web deployments rely on the `/api/detect` proxy; `scripts/check-web-bundle.sh`
  enforces this.
- Detection accuracy is bounded by the `aystro-project/1` model, which currently
  knows three classes.
- Captured images are resized by the camera preset (`ResolutionPreset.high`) and
  gallery picks are capped at 2048px to keep base64 payloads reasonable.
