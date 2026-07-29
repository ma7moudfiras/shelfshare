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
# gets a placeholder with no secret in it: the proxy supplies the real key, and
# the client only needs to know it should use the proxy.
echo "==> Writing placeholder .env (no secrets; web uses /api/detect)"
cat > .env <<'ENVEOF'
ROBOFLOW_WORKSPACE=ma7mouds-workspace
ROBOFLOW_WORKFLOW_ID=aystro-project
ROBOFLOW_BASE_URL=https://serverless.roboflow.com
ENVEOF

echo "==> Building web bundle"
flutter pub get
flutter build web --release

# Belt and braces: refuse to publish a bundle containing a key.
"$(dirname "$0")/check-web-bundle.sh" build/web

echo "==> Build complete: build/web"
