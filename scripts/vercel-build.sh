#!/usr/bin/env bash
#
# Vercel build for the Flutter web app.
#
# Vercel's build image has no Flutter SDK, so this fetches a pinned version,
# then builds the web bundle into build/web (the configured outputDirectory).
#
# The Roboflow API key is deliberately NOT read here. On web the app talks to
# /api/detect, which holds the key server-side -- baking it into the bundle
# would publish it to every visitor.

set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.8}"
FLUTTER_DIR="${PWD}/.flutter-sdk"

echo "==> Installing Flutter ${FLUTTER_VERSION}"
if [ ! -d "${FLUTTER_DIR}" ]; then
  git clone --depth 1 --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git "${FLUTTER_DIR}"
fi
export PATH="${FLUTTER_DIR}/bin:${PATH}"

git config --global --add safe.directory "${FLUTTER_DIR}" || true
flutter --version

# flutter_dotenv requires the .env asset to exist at build time. The web build
# gets no Roboflow secret: the proxy supplies the key, and the client only needs
# to know it should use the proxy.
#
# The Supabase values ARE written, and must be. Without them the app has no auth
# service at all, and it used to fall back to an open capture screen -- a public
# URL anyone could use to burn Roboflow credits, with no sign-in. main.dart now
# refuses to run in that state, so a build missing these produces a visible
# configuration error rather than an unprotected app.
#
# Neither Supabase value is a secret. The publishable key grants nothing on its
# own: every table is protected by Row Level Security, and this is not the
# service_role key. Both are compiled into the client bundle and readable by any
# visitor no matter where the build reads them from, so defaulting them here
# costs nothing and removes a manual dashboard step. Set the environment
# variables in Vercel to point a deployment at a different project.
SUPABASE_URL="${SUPABASE_URL:-https://dpviepymbxaibmeppylj.supabase.co}"
SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-sb_publishable_vwWcjHFmfZV40IQa5b7Smg_8YEFAyl2}"

echo "==> Writing .env (no Roboflow secret; web uses /api/detect)"
cat > .env <<ENVEOF
ROBOFLOW_WORKSPACE=ma7mouds-workspace
ROBOFLOW_WORKFLOW_ID=aystro-project
ROBOFLOW_BASE_URL=https://serverless.roboflow.com
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_PUBLISHABLE_KEY=${SUPABASE_PUBLISHABLE_KEY}
ENVEOF

# Fail here rather than shipping a bundle that cannot sign anyone in.
for required in SUPABASE_URL SUPABASE_PUBLISHABLE_KEY; do
  # `[^[:space:]]` rather than `.`: a value of only spaces is empty as far as
  # AppConfig is concerned, since it trims before deciding.
  if ! grep -qE "^${required}=[^[:space:]]" .env; then
    echo "ERROR: ${required} is empty. The web build would have no auth."
    exit 1
  fi
done

echo "==> Building web bundle"
flutter pub get
flutter build web --release

# Belt and braces: refuse to publish a bundle containing a key.
"$(dirname "$0")/check-web-bundle.sh" build/web

echo "==> Build complete: build/web"
