# Experimental kill-tests

## Establish the unit and the estimand

Define independent world/campaign/subject/cluster, terminal outcome, evaluation
window and cost. Separate world randomness, policy randomness and measurement
noise. Record whether the estimand is population risk, stratified risk, conditional
performance after acceptance, or cost per successful decision. Do not substitute
one for another after seeing outcomes.

## Fairness contract

For a component claim share candidate/model access, observations, budget, stopping,
screening, confirmation, alpha spending, terminal actions, abstention, retry rules,
post-processing and metrics. Only the component under test changes.

Prefer one shared wrapper/engine. All candidates must have symmetric opportunities
to ACCEPT each model, reject the family or abstain when those decisions define
the metric. If resources cannot be equalized, report a risk/cost frontier rather
than an unqualified winner. Full-system comparisons may differ by design, but
cannot identify which component caused a gain.

Use the same worlds and a declared common-random-number scheme across methods.
With adaptive locations, physical-index tapes and per-location replicate tapes
encode different couplings; choose and document one before results. Pairing does
not mean forcing different requests to share an inappropriate observed response.

## Integrity and independence

Audit generator parameters actually used, reused seeds, repeated labels, duplicated
trajectories, train/test leakage and mutable shared state. Hash trajectories with
the correct fields; identical paired policies can legitimately follow the same
path and do not constitute extra independent worlds. Quantization can also create
legitimate duplicates. Investigate rather than deleting inconvenient rows.

Assert world assumptions and stop on invalid generation. Record failed runs and
exclusion reasons; analyze denominator changes. Check budget accounting directly
from raw observations. Reproduce headline aggregations from raw IDs, not a copied
summary table or manually edited CSV.

## Statistical decisions

- Report success, error, abstention, physical cost, steps/time and uncertainty.
- Use exact McNemar for paired binary terminal outcomes when its setup applies.
- Use paired bootstrap of independent worlds/clusters for cost differences;
  resample all methods for a selected unit together and respect stratification.
- Specify multiplicity control or label exploratory comparisons accordingly.
- Nonsignificance is not equivalence/noninferiority. Use a prespecified practical
  margin and appropriate interval; do not pick the margin after seeing the gap.
- Give an interval/upper bound for 0/n. Avoid comparisons hiding errors through
  near-total abstention. Report unconditional counts alongside selective metrics.
- Do not assume independent samples when methods share worlds or repeated subjects.

The test follows the estimand and sampling design, not a fixed checklist of names.
For a fair-baseline kill criterion state before evaluation exactly what would
defeat the advantage and how uncertainty affects the decision.

## Freeze and holdout access

Require a code/config/seeds/analysis freeze before confirmatory access, plus a
separate results commit/hash afterward. A timestamp/hash alone does not establish
that nobody saw the holdout. Record pilot/partial-run access and provenance.
Do not run a large batch until invariant, generator and fairness checks pass.

If a result fails, preserve it. New algorithm/DGP/metric/hyperparameter choices
require a new hypothesis and evaluation split. An analysis correction that uses
existing raw observations must disclose the bug, preserve prior outputs and avoid
claiming independent confirmation. Do not rerun simulation just to recompute a
CDF or derived statistic if raw data suffice.

## Robustness and real data

Use the actual distribution's CDF/likelihood for distribution-specific bounds.
Gaussian calibration is not automatically valid for variance-normalized t noise.
OOD tests are empirical robustness unless a corresponding theorem is proved.

Unknown clinical/real-world truth cannot be replaced by a preferred reference
model and labeled absolute scientific error. Report reference-model disagreement,
held-out predictive likelihood/error, or an illustrative replay. Audit hard-coded
schedules mislabeled as optimization algorithms and asymmetric decision spaces.
