#!/usr/bin/env bash

set -euo pipefail

KTLINT_VERSION="$(
  set -euo pipefail
  awk -F "[:']" '/ktlint/ {print $4}' "ktlint/build.gradle"
)"
echo "Installing Ktlint: ${KTLINT_VERSION}"

url=$(
  set -euo pipefail
  # --retry/--retry-all-errors: this API call previously had NO retry, and a
  # transient DNS/proxy failure (curl exit 5) failed the whole docker build
  # (observed on the Build and Test workflow, runs 44133889720 et al.).
  curl --retry 5 --retry-delay 5 --retry-all-errors -s \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $(cat /run/secrets/GITHUB_TOKEN)" \
    "https://api.github.com/repos/pinterest/ktlint/releases/tags/${KTLINT_VERSION}" |
    jq -r '.assets | .[] | select(.name=="ktlint") | .url'
)
curl --retry 5 --retry-delay 5 --retry-all-errors -sL -o "/usr/bin/ktlint" \
  -H "Accept: application/octet-stream" \
  -H "Authorization: Bearer $(cat /run/secrets/GITHUB_TOKEN)" \
  "${url}"
chmod a+x /usr/bin/ktlint
