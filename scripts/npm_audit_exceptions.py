#!/usr/bin/env python3
"""npm audit gate with DOCUMENTED unfixable exceptions.

Reads `npm audit --json` on stdin; exits 1 on any vulnerability EXCEPT those
whose every advisory source is in the documented-unfixable set below.

POLICY (fleet security standard): alert counts are driven to zero by REAL
fixes; a CVE with NO fixed release is documented precisely as residual risk
instead of dismissed. Same mechanism as the osv-scanner.toml policy in the
momentstudio repo (entries with reason + dated re-check).

Current exceptions:

  GHSA-fc5q-39xc-vjpf (picomatch, high, ReDoS via single-branch processing)
    * Affected range: <= 4.0.7. The latest release on npm (any tag) IS
      4.0.7 (verified 2026-11-17: `npm view picomatch versions` tops out at
      4.0.7; dist-tags latest=4.0.7; no prerelease carries a fix). There is
      nothing to upgrade to — every published version is in the affected
      range.
    * Scope in this image: dev-time glob matching inside bundled linters;
      no attacker-controlled patterns reach picomatch in the super-linter
      container workflow.
    * RE-CHECK: when picomatch publishes > 4.0.7, DELETE this entry and
      bump the copies.
"""

import json
import sys

DOCUMENTED_UNFIXABLE = {
    "GHSA-fc5q-39xc-vjpf": "no fixed release exists (<=4.0.7 affected; 4.0.7 is latest)",
}


# too-many-locals is intentional: a one-pass filter keeps the audit logic
# linear and greppable.
# pylint: disable=too-many-locals,too-many-branches
def main() -> int:
    """Filter a piped npm-audit JSON report; 0 = clean, 1 = actionable, 2 = bad input."""
    try:
        audit = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        print(
            f"npm-audit-exceptions: could not parse npm audit JSON: {exc}",
            file=sys.stderr,
        )
        return 2

    vulnerabilities = audit.get("vulnerabilities", {}) or {}
    failures: list[tuple[str, list[str]]] = []
    residual: list[tuple[str, list[str]]] = []
    for name, info in vulnerabilities.items():
        if not isinstance(info, dict):
            continue
        via = [v for v in (info.get("via") or []) if isinstance(v, dict)]
        if not via:
            continue  # indirect entries without their own advisories
        # npm puts the GHSA in via[].url (https://github.com/advisories/GHSA-...)
        # and a numeric DB id in via[].source. A via entry is EXCUSED when any
        # of its identifiers names a documented-unfixable advisory; a package
        # is residual only when EVERY advisory against it is excused.
        sources = set()
        excused_all = True
        for v in via:
            ids = {str(v.get(k)) for k in ("url", "source", "name") if v.get(k)}
            sources |= ids
            if not any(g in i for g in DOCUMENTED_UNFIXABLE for i in ids):
                excused_all = False
        if via and excused_all:
            residual.append((name, sorted(sources)))
        else:
            failures.append((name, sorted(sources)))

    for r_name, r_sources in residual:
        ghsa = None
        for g in DOCUMENTED_UNFIXABLE:
            if any(g in s for s in r_sources):
                ghsa = g
                break
        if ghsa:
            why = DOCUMENTED_UNFIXABLE[ghsa]
            print(f"npm-audit-exceptions: DOCUMENTED RESIDUAL {r_name}: {ghsa} — {why}")
    if failures:
        for f_name, f_sources in failures:
            bad = ", ".join(f_sources) or "unknown advisory"
            print(f"npm-audit-exceptions: FAIL {f_name}: {bad}")
        n = len(failures)
        print(f"npm-audit-exceptions: {n} package(s) with actionable vulns — fix them.")
        return 1
    msg = "no actionable vulnerabilities (documented residuals listed above)."
    print(f"npm-audit-exceptions: {msg}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
