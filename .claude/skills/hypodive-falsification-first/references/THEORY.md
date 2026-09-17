# Theory audit

## Normalize before attacking

For each theorem record assumptions, truth/population class, fixed/fitted model,
noise law, algorithm, decision space, budget clock, exact conclusion, quantifiers
and constants. Separate within-model selection error from accepting an entirely
misspecified family. Identify whether error is unconditional, conditional on
selection, uniform in time, uniform over truths, or averaged over worlds.

## Cheapest attacks

- T=0/1, smallest sample, empty design, one or identical hypotheses, ties,
  boundary thresholds, zero signal, arbitrarily small separation.
- Last-slot discovery with no budget for independent confirmation.
- A policy that never explores the discrepancy region; truths indistinguishable
  on all queried locations. Safe abstention may be unavoidable.
- A grid that misses a continuous-domain anomaly or a false coverage certificate.
- Estimated noise, refitted means, nuisance parameters, growing hypotheses or
  correlated responses excluded by the claimed theorem.
- A permanent veto on individual residuals whose false alarms accumulate with
  required coverage size; safety can destroy useful acceptance.

Write a minimal executable witness under `tests/theory_counterexamples/` or the
existing test layout. The proof establishes the general failure; the test protects
the concrete witness. A few simulated trajectories do not establish an impossibility.

## Adaptivity and sequential evidence

Define the filtration. Locations, bets, thresholds and modes needing predictability
must be chosen before their current noise. Trace likelihood-ratio conditional
expectations; posterior odds with arbitrary priors are not automatically the
required e-process. Composite nulls, nuisance fitting and optional continuation
need their own valid construction. Distinguish an e-value at one time from an
e-process valid at stopping times.

Use the first predictable hit, not a retrospectively selected “good point” from
accepted histories. Conditioning on future coverage or a successful run can
invalidate a noise calculation. Fresh record IDs do not establish physical
independence; verify the acquisition/executor contract.

Count all physical measurements: exploration, replication, screening/confirmation
if separate, retries and failures when they consume the constrained resource.
Distinguish that clock from exploratory ordinal count and wall time. Finite-budget
power needs a confirmable-hit probability or a proved deterministic condition.
Do not silently set the probability to one. Confirmation can delay coverage.

## Geometry and DGP

Distinguish fill distance, probability coverage, and selective prediction coverage.
If a property is required on every point in a ball, a peak amplitude is not enough.
Check separation from **all** candidates. Prefer a constructive core plus an
analytic argument; dense-grid assertions detect bugs but do not prove a continuous
property without a regularity certificate.

## Repair versus retirement

Classify: false theorem; correct theorem with violated implementation assumptions;
valid but vacuous bound; insufficient proof; or empirical contradiction needing
analysis. Give a minimal repair and its cost. Do not implement/tune a new method
on the observed holdout during the audit. A counterexample outside assumptions
limits applicability; it does not refute the scoped theorem.
