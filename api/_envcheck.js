/**
 * TEMPORARY diagnostic endpoint. Delete once the Roboflow key is confirmed.
 *
 * Reports whether the serverless runtime can see ROBOFLOW_* configuration, so a
 * missing/misnamed/empty variable can be told apart from a scoping problem.
 *
 * Deliberately leaks nothing sensitive:
 *   - Never returns a variable's VALUE, only its name and length.
 *   - Only lists names matching /robo/i, so unrelated platform variables and
 *     any other secrets in the environment are not enumerated.
 *
 * The variable name itself is already public in this repo, so exposing which
 * ROBOFLOW_* names exist reveals nothing that reading the source would not.
 */
export default function handler(req, res) {
  const key = process.env.ROBOFLOW_API_KEY;

  // Names only -- values are never read into the response.
  const roboflowNames = Object.keys(process.env)
    .filter((name) => /robo/i.test(name))
    .sort();

  res.setHeader('Cache-Control', 'no-store');
  return res.status(200).json({
    note: 'Temporary diagnostic. No secret values are returned.',
    hasRoboflowApiKey: typeof key === 'string' && key.length > 0,
    // Length distinguishes "set but empty/whitespace" from "genuinely absent".
    roboflowApiKeyLength: typeof key === 'string' ? key.length : null,
    roboflowApiKeyIsBlank: typeof key === 'string' && key.trim().length === 0,
    roboflowNamesPresent: roboflowNames,
    vercelEnv: process.env.VERCEL_ENV ?? null,
    vercelBranch: process.env.VERCEL_GIT_COMMIT_REF ?? null,
    totalEnvVarCount: Object.keys(process.env).length,
  });
}
