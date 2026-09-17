# Build research evidence

## Specify the mathematical and computational object

Write model/truth classes, observation law, fitted vs fixed parameters,
acquisition, stopping, terminal decisions, physical budget, thresholds,
randomness, estimand and metrics. State the quantifiers and excluded cases.
Keep data-dependent choices out of fixed-object guarantees unless proved valid.

One canonical engine must own protocol/state transitions. Experiments vary
explicit inputs or components, not copied implementations. Trace paper pseudocode
to actual functions and identify legacy/demo code with weaker semantics.

## Baselines and worlds

Include a strong simple baseline and the closest feasible faithful baseline.
Document deviations from published implementations as adaptations. Equalize
information, model access, safety/stopping, abstention, retries, budget and
post-processing for a component claim. Compare complete systems separately when
that is the actual question; disclose the differences.

Construct worlds satisfying theorem assumptions algebraically where possible;
assert them programmatically as well. A dense grid alone does not prove a
continuous-domain property without a regularity bound. Invalid worlds must fail,
not disappear silently from aggregates.

Specify independent campaigns, paired methods, seed namespaces, noise coupling,
training/tuning/holdout split, and duplicate-detection unit. Common random numbers
create paired methods, not extra independent observations. Report success, error,
abstention, physical cost and wall time with appropriate intervals.

## Analysis before holdout

Freeze primary estimand, metrics, stratification, effect direction, practical
margins, uncertainty intervals, paired tests and multiplicity handling. Specify
exclusions and failed-run handling. Use exact McNemar for appropriate paired
binary outcomes; bootstrap independent worlds/clusters, preserving the pairing,
for costs. Choose methods to fit the actual design, not this example list.

Nonsignificance does not establish equivalence; zero failures do not establish
zero risk. Predeclare any noninferiority margin. Include all outcomes rather than
conditioning cost only on successes without naming that estimand. An empirical
stress test outside assumptions does not validate the theorem.

## Freeze package

Use tracked `experiments/`, `configs/`, `tests/`, `research/` or established
equivalents. Keep raw observations/run IDs where permitted, config/seeds,
environment/dependency versions, evaluated commit, commands, analysis and generated
tables. For restricted/large data preserve immutable IDs/checksums and access
instructions; label any resulting reproducibility limitation.

Read [HANDOFF_PROTOCOL.md](../HANDOFF_PROTOCOL.md) for the two freezes.
Do not report a locally frozen protocol as externally preregistered.
Holdout access, including preliminary plots or partial failed runs, must be
disclosed. A bug found after access means preserved old artifacts and a new
iteration, not a quiet rerun under the same confirmatory label.

## Stop before narrative

Tests and reproduction support scoped claims; they do not prove theory or
novelty. State unresolved assumptions and the simplest competing explanation in
the handoff. Leave the independent hostile judgment to the falsifier. A discovered
contradiction must be reported immediately, never deferred merely to preserve roles.
