/**
 * Server-side proxy for Roboflow workflow inference.
 *
 * Exists so the web build never carries the Roboflow API key. Anything bundled
 * into a browser app is readable by anyone who opens developer tools, so the
 * key is held here as a Vercel environment variable and attached server-side.
 *
 * The client posts the same body it would send to Roboflow, minus `api_key`;
 * this function injects the key and forwards the request. The response is
 * relayed unchanged, so the Dart parser is identical in both modes.
 *
 * Required environment variable (set in the Vercel dashboard, never committed):
 *   ROBOFLOW_API_KEY      -- private key from app.roboflow.com/settings/api
 *
 * Optional:
 *   ROBOFLOW_WORKSPACE    -- defaults to "ma7mouds-workspace"
 *   ROBOFLOW_WORKFLOW_ID  -- defaults to "aystro-project"
 *   ROBOFLOW_BASE_URL     -- defaults to "https://serverless.roboflow.com"
 *   ALLOWED_ORIGIN        -- CORS origin; defaults to same-origin only
 */

const DEFAULTS = {
  workspace: 'ma7mouds-workspace',
  workflowId: 'aystro-project',
  baseUrl: 'https://serverless.roboflow.com',
};

/** Upper bound on the request body. Base64 inflates bytes by ~33%. */
const MAX_BODY_BYTES = 12 * 1024 * 1024;

/** Roboflow cold starts can be slow; keep this under Vercel's function limit. */
const UPSTREAM_TIMEOUT_MS = 45_000;

function applyCors(res) {
  // Same-origin by default: the Flutter app is served from this deployment.
  // Set ALLOWED_ORIGIN only if the app is hosted elsewhere.
  const origin = process.env.ALLOWED_ORIGIN;
  if (origin) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

export default async function handler(req, res) {
  applyCors(res);

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ message: 'Method not allowed. Use POST.' });
  }

  const apiKey = process.env.ROBOFLOW_API_KEY;
  if (!apiKey) {
    // Deliberately vague to the client; the detail goes to the server log.
    console.error('ROBOFLOW_API_KEY is not set in the environment.');
    return res.status(500).json({ message: 'Detection is not configured.' });
  }

  const body = req.body;
  if (!body || typeof body !== 'object') {
    return res.status(400).json({ message: 'Expected a JSON body.' });
  }

  const image = body.inputs && body.inputs.image;
  if (!image || image.type !== 'base64' || typeof image.value !== 'string') {
    return res.status(400).json({
      message: 'Expected inputs.image to be {type: "base64", value: "..."}.',
    });
  }

  if (image.value.length > MAX_BODY_BYTES) {
    return res.status(413).json({ message: 'Image too large.' });
  }

  const workspace = process.env.ROBOFLOW_WORKSPACE || DEFAULTS.workspace;
  const workflowId = process.env.ROBOFLOW_WORKFLOW_ID || DEFAULTS.workflowId;
  const baseUrl = process.env.ROBOFLOW_BASE_URL || DEFAULTS.baseUrl;
  const url = `${baseUrl}/${workspace}/workflows/${workflowId}`;

  // Rebuild the payload rather than spreading the client's: this way an
  // `api_key` sent by a client can never override the server's.
  const payload = {
    api_key: apiKey,
    inputs: { image: { type: 'base64', value: image.value } },
  };
  if (body.parameters && typeof body.parameters === 'object') {
    payload.parameters = body.parameters;
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

  try {
    const upstream = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    const text = await upstream.text();

    // Relay the response unchanged so the client parser is mode-agnostic.
    res.status(upstream.status);
    res.setHeader('Content-Type', 'application/json');
    return res.send(text);
  } catch (error) {
    if (error.name === 'AbortError') {
      return res.status(504).json({ message: 'Roboflow timed out.' });
    }
    // Log server-side; never echo internals (or the payload) to the client.
    console.error('Roboflow proxy request failed:', error.message);
    return res.status(502).json({ message: 'Could not reach Roboflow.' });
  } finally {
    clearTimeout(timer);
  }
}

export const config = {
  api: {
    // Base64 images exceed Vercel's 1mb default.
    bodyParser: { sizeLimit: '12mb' },
  },
};
