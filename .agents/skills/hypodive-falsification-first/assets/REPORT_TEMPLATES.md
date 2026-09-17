# Audit artifact templates

Use only artifacts required by the selected mode and task. Reuse existing reports
with iteration IDs; do not overwrite previous verdicts or populate fake evidence.

## research/HYPODIVE_TRIAGE.md

- Scope, branch/commit, mode, budget and audit date.
- Strongest claim, supporting artifact and falsifying observation.
- Top three material risks with evidence or explicit uncertainty.
- Strongest simple baseline; paired/fair comparison status.
- Actual canonical code path and relevant theorem/DGP assumptions.
- Independence/leakage/duplicate findings and abstention explanation.
- Closest prior concept if novelty is claimed.
- Cheapest decisive kill-test: command/setup, result, inference, limits.
- GO / NARROW / NO-GO, scope, next action and stop condition.

## research/CLAIM_LEDGER.md

| ID | Claim | Type | Scope | Evidence | Assumptions | Strongest alternative explanation | Kill-test | Status |
|---|---|---|---|---|---|---|---|---|

Types: THEORY / EMPIRICAL / NOVELTY / ENGINEERING / PRODUCT / PERFORMANCE / SAFETY.
Statuses: UNSUPPORTED / PLAUSIBLE / SUPPORTED / REJECTED / NARROWED / OBSOLETE.
Preserve the original claim and add a revised scoped claim with provenance.

## research/CLAIM_EVIDENCE_MAP.md

| Claim ID | Theorem/proposition | Canonical code | Experiment/test | Frozen config | Raw evidence | Analysis | Table/figure | Missing required link |
|---|---|---|---|---|---|---|---|---|

N/A is appropriate for irrelevant links, not missing required evidence.

## research/REPOSITORY_REALITY_CHECK.md

- State: status, branches, evaluated commit, working changes, relevant history.
- Actual execution graph: entrypoint → library → observation/data source → analysis.
- Duplicates: copied algorithms/constants, scratch-only scripts, old callers.
- Confounds: schedules, decision asymmetry, budgets, fallbacks, paper/code mismatch.
- Data: raw availability, seed/trajectory checks, generator assertions, exclusions.
- Verification: exact commands, results and unresolved limitations.

## research/PRIOR_ART_MATRIX.md

| Proposed contribution | Closest prior work | Same problem? | Same mechanism? | Same guarantee? | Same decision space? | Difference that remains |
|---|---|---|---|---|---|---|

For decisive rows attach URL, theorem/section, assumptions and reading depth.
State novelty status and limits of the search. No novelty from absence of a hit.

## research/HYPODIVE_FALSIFICATION_REPORT.md

Use the 10 standard output sections in SKILL.md. Include claim IDs, exact
counterexamples/baselines, raw artifacts, tested versus proposed checks, scoped
verdict and criterion for reopening. Record evaluated and report commits without
requiring a self-referential hash of the report's own commit.
