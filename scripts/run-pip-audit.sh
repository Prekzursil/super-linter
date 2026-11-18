#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

pip install pip-audit

# DOCUMENTED UNFIXABLE EXCEPTIONS (fleet security standard: a CVE with no
# fixed release is documented precisely as residual risk, never silently
# dismissed). Same policy as scripts/npm-audit-exceptions.py.
#
#   PYSEC-2026-3807 / GHSA-9w56-46f6-3qhx (asteval <= 1.0.6, fixed 1.0.9):
#     Every checkov release up to and including the latest 3.4.5 hard-pins
#     asteval==1.0.6 (verified 2026-11-17 via PyPI requires_dist), and this
#     image installs checkov into /venvs/checkov. No checkov release carries
#     the fixed asteval; overriding the pin is a ResolutionImpossible pip
#     error (verified in build run 44201512707). asteval only evaluates
#     checkov's own expressions on first-party IaC templates inside this
#     container. RE-CHECK: when checkov ships asteval>=1.0.9, DELETE these
#     two --ignore-vuln flags and bump checkov.
for venv_path in /venvs/*; do
  pushd "${venv_path}"
  echo "Checking for known vulnerabilities in ${venv_path}"
  # shellcheck disable=SC1091
  source bin/activate
  pip-audit --requirement "${venv_path}/requirements.txt" \
    --ignore-vuln PYSEC-2026-3807 \
    --ignore-vuln GHSA-9w56-46f6-3qhx
  deactivate
  popd
done
