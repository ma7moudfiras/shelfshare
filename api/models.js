/**
 * Lists the project's trained model versions and its class names.
 *
 * Exists so the app can offer a model picker without shipping a Roboflow key
 * to the browser: the key stays here, same as in api/detect.js. The response
 * carries no credentials.
 *
 * GET /api/models
 *   -> { models: [{ modelId, version, name, map50, recall, images }], classes: [...] }
 *
 * Environment variables are the same ones api/detect.js uses; see that file.
 */

const DEFAULTS = {
  workspace: 'ma7mouds-workspace',
  project: 'aystro-project',
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

/**
 * Normalises one entry from the Roboflow versions array.
 *
 * Returns null for versions with no trained model -- those cannot be run, so
 * offering them in a picker would only produce failures.
 */
function toModel(version, project) {
  // Version ids look like "workspace/project/11"; the trailing segment is the
  // version number, which is what model_id needs.
  const id = String(version?.id ?? '');
  const number = toNumber(id.split('/').pop());
  if (number === null) return null;

  // A version is runnable once it has a trained model attached. The field has
  // varied across API revisions, so accept any of the known spellings.
  const model = version?.model ?? version?.models ?? null;
  const hasModel =
    model != null && (Array.isArray(model) ? model.length > 0 : true);
  if (!hasModel) return null;

  const metrics = Array.isArray(model) ? (model[0] ?? {}) : model;

  return {
    modelId: `${project}/${number}`,
    version: number,
    name: version?.name ?? `Version ${number}`,
    images: toNumber(version?.images),
    map50: toNumber(metrics?.map ?? metrics?.map50),
    precision: toNumber(metrics?.precision),
    recall: toNumber(metrics?.recall),
  };
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
  const project = process.env.ROBOFLOW_WORKFLOW_ID || DEFAULTS.project;
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

    const models = (data?.versions ?? [])
      .map((v) => toModel(v, project))
      .filter(Boolean)
      // Newest first: the most recently trained model is the usual choice.
      .sort((a, b) => b.version - a.version);

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
