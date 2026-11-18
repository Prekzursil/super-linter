#!/usr/bin/env bash

set -euo pipefail

KTLINT_VERSION="$(
  set -euo pipefail
  awk -F "[:']" '/ktlint/ {print $4}' "ktlint/build.gradle"
)"
echo "Installing Ktlint: ${KTLINT_VERSION}"

# FIX 2026-11-17: this used to resolve the asset URL via
# api.github.com/repos/pinterest/ktlint/releases/tags/... with the build
# GITHUB_TOKEN. On GitHub-hosted runners that API call intermittently fails
# (rate-limited shared runner IPs / transient auth), the response then has no
# .assets, jq dies with "Cannot iterate over null", url ends up empty, and
# the download curl exits 5 — failing the whole docker build (observed on
# Build and Test runs 44133889720, 44153526283: base_image + both matrix
# legs, three separate times). The release asset is PUBLIC: download it
# directly from the release URL — no API call, no token, no jq, with
# retries for transient network errors.
url="https://github.com/pinterest/ktlint/releases/download/${KTLINT_VERSION}/ktlint"
curl --retry 5 --retry-delay 5 --retry-all-errors -fsSL -o "/usr/bin/ktlint" "${url}"
chmod a+x /usr/bin/ktlint
