/**
 * Lists the detector project's trained model versions and its class names.
 *
 * Exists so the app can offer a model picker without shipping a Roboflow key
 * to the browser: the key stays here, same as in api/detect.js. The response
 * carries no credentials.
 *
 * GET /api/models
 *   -> { models: [{ modelId, version, name, map50, recall, images }], classes: [...] }
 *
 * Deliberately reads ROBOFLOW_DETECT_PROJECT, not ROBOFLOW_WORKFLOW_ID: since
 * aystro-detect-classify-brand runs two models (a detector and a brand
 * classifier), the workflow id is no longer a project slug you can query
 * Roboflow's `/{workspace}/{project}` versions endpoint with. The picker
 * lists the detector's versions specifically -- the brand classifier has no
 * per-call override to pick a version for.
 *
 * Other environment variables are the same ones api/detect.js uses; see that
 * file.
 */

const DEFAULTS = {
  workspace: 'ma7mouds-workspace',
  project: 'aystro-project-v2',
  apiBase: 'https://api.roboflow.com',
};

const API_KEY_NAMES = ['ROBOFLOW_API_KEY', 'ROBOFLOW_API_KE'];

const UPSTREAM_TIMEOUT_MS = 15_000;

function readApiKey() {
  for (const name of API_KEY_NAMES) {
    const value = process.env[name];
    if (typeof value === 'string' && value.trim().length > 0) return value.trim();
  }
  return null;
}

function toNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

/** Extracts the trailing version number from a "workspace/project/11" id. */
function versionNumberOf(version) {
  return toNumber(String(version?.id ?? '').split('/').pop());
}

/**
 * Normalises one version into a picker entry.
 *
 * [detail] is the per-version document, which is where `model` actually lives.
 * The project-level listing omits it, so trained-ness cannot be determined
 * from the summary alone.
 */
function toModel(version, detail, project) {
  const number = versionNumberOf(version);
  if (number === null) return null;

  const model = detail?.version?.model ?? detail?.model ?? null;
  const metrics = Array.isArray(model) ? (model[0] ?? {}) : model;

  return {
    modelId: `${project}/${number}`,
    version: number,
    name: version?.name ?? `Version ${number}`,
    images: toNumber(version?.images),
    // Roboflow nests headline metrics under `model.map` / `model.recall`.
    map50: toNumber(metrics?.map ?? metrics?.map50),
    precision: toNumber(metrics?.precision),
    recall: toNumber(metrics?.recall),
    trained: model != null,
  };
}

/**
 * Fetches one version's document, returning null on any failure.
 *
 * Failures are per-version and non-fatal: one unreachable version should
 * degrade that entry, not empty the whole picker.
 */
async function fetchVersionDetail(apiBase, workspace, project, number, apiKey, signal) {
  try {
    const url =
      `${apiBase}/${workspace}/${project}/${number}` +
      `?api_key=${encodeURIComponent(apiKey)}`;
    const res = await fetch(url, { signal });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

export default async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');

  if (req.method !== 'GET') {
    return res.status(405).json({ message: 'Method not allowed. Use GET.' });
  }

  const apiKey = readApiKey();
  if (!apiKey) {
    console.error(`No Roboflow key. Looked for: ${API_KEY_NAMES.join(', ')}`);
    return res.status(500).json({ message: 'Detection is not configured.' });
  }

  const workspace = process.env.ROBOFLOW_WORKSPACE || DEFAULTS.workspace;
  const project = process.env.ROBOFLOW_DETECT_PROJECT || DEFAULTS.project;
  const apiBase = process.env.ROBOFLOW_API_BASE || DEFAULTS.apiBase;

  const url =
    `${apiBase}/${workspace}/${project}?api_key=${encodeURIComponent(apiKey)}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

  try {
    const upstream = await fetch(url, { signal: controller.signal });
    const text = await upstream.text();

    if (!upstream.ok) {
      // Never echo the body: the request URL carried the API key and Roboflow
      // sometimes reflects it back in error payloads.
      console.error(`Roboflow project lookup failed: ${upstream.status}`);
      return res
        .status(upstream.status === 401 ? 500 : 502)
        .json({ message: 'Could not list models.' });
    }

    const data = JSON.parse(text);
    const versions = Array.isArray(data?.versions) ? data.versions : [];

    // Trained-ness and metrics only appear on the per-version document, so
    // fetch them in parallel. These are small requests and the list is short.
    const details = await Promise.all(
      versions.map((v) => {
        const number = versionNumberOf(v);
        return number === null
          ? Promise.resolve(null)
          : fetchVersionDetail(
              apiBase,
              workspace,
              project,
              number,
              apiKey,
              controller.signal,
            );
      }),
    );

    const all = versions
      .map((v, i) => toModel(v, details[i], project))
      .filter(Boolean)
      // Newest first: the most recently trained model is the usual choice.
      .sort((a, b) => b.version - a.version);

    // Prefer versions with a trained model. If enrichment failed wholesale --
    // an API change, or every detail request timing out -- fall back to
    // offering every version rather than an empty picker.
    const trained = all.filter((m) => m.trained);
    const models = trained.length > 0 ? trained : all;

    // `classes` is a map of name -> annotation count.
    const classCounts = data?.project?.classes ?? {};
    const classes = Object.keys(classCounts).sort();

    return res.status(200).json({ models, classes, classCounts });
  } catch (error) {
    if (error.name === 'AbortError') {
      return res.status(504).json({ message: 'Roboflow timed out.' });
    }
    console.error('Model listing failed:', error.message);
    return res.status(502).json({ message: 'Could not list models.' });
  } finally {
    clearTimeout(timer);
  }
}
