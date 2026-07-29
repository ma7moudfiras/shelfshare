#!/usr/bin/env bash
#
# Fails the build if a Roboflow API key made it into the web bundle.
#
# flutter_dotenv loads `.env` as a Flutter *asset*, which means `flutter build
# web` copies it verbatim to build/web/assets/.env -- a path any visitor can
# fetch. On mobile that is merely inside the app package; on web it is published
# to the world.
#
# Web builds are meant to carry no key at all and call /api/detect instead, so
# finding one here is a genuine leak. Run this after any web build:
#
#   ./scripts/check-web-bundle.sh
#
# It is also invoked automatically by scripts/vercel-build.sh.

set -euo pipefail

BUNDLE_DIR="${1:-build/web}"

if [ ! -d "${BUNDLE_DIR}" ]; then
  echo "No web bundle at ${BUNDLE_DIR}; nothing to check."
  exit 0
fi

echo "==> Scanning ${BUNDLE_DIR} for leaked credentials"

fail=0

# A real Roboflow key is a longish alphanumeric string. The placeholder from
# .env.example and any empty value are fine.
if grep -rIoE 'ROBOFLOW_API_KEY=[A-Za-z0-9_-]+' "${BUNDLE_DIR}" 2>/dev/null \
  | grep -vE 'ROBOFLOW_API_KEY=(your_[A-Za-z0-9_]*|changeme|)$' \
  | grep -qE 'ROBOFLOW_API_KEY=[A-Za-z0-9_-]{12,}'; then
  echo "ERROR: a Roboflow API key is present in the web bundle."
  echo "       Web builds must not carry the key -- they call /api/detect,"
  echo "       which holds it server-side."
  echo
  echo "Offending file(s):"
  grep -rIlE 'ROBOFLOW_API_KEY=[A-Za-z0-9_-]{12,}' "${BUNDLE_DIR}" 2>/dev/null \
    | grep -v 'your_roboflow' || true
  fail=1
fi

# Workspace publishable keys look like rf_<id>. Not a hard secret, but it has no
# business being in a bundle that is supposed to be credential-free.
if grep -rIqE 'rf_[A-Za-z0-9]{20,}' "${BUNDLE_DIR}" 2>/dev/null; then
  echo "WARNING: a Roboflow publishable key (rf_...) appears in the bundle."
fi

if [ "${fail}" -ne 0 ]; then
  exit 1
fi

echo "OK: no Roboflow API key found in the web bundle."
