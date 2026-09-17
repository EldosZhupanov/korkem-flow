# HYPODIVE Builder → Freeze → Falsifier → Result

Builder optimizes coherence, correctness and evidence quality. Falsifier searches
for counterexamples, confounds, simpler explanations, prior art and stop decisions.
Both optimize truth. Neither is instructed to manufacture a preferred verdict.

## Freeze 1: algorithm and analysis before confirmatory access

Before accessing the holdout, record the exact claim/estimand, algorithm, DGP,
hyperparameters, stopping/budget rules, seeds/split provenance, primary/secondary
metrics, analysis, margins, multiplicity and exclusions. Run the necessary tests,
then commit the authorized code/config/analysis in a clean isolated state.
Record this evaluated commit. A hash made after looking at results does not prove
an earlier freeze; it must not be retroactively called preregistration.

Existing user edits must not be discarded or committed just to obtain a clean
tree. Isolate work when authorized or disclose the blocker. No simulation batch
before assumption/invariant/fairness checks pass. Start with a smoke check that
does not consume the confirmatory holdout.

## Freeze 2: results and handoff

Run frozen commands without modifying algorithm/config/analysis. Save all raw
outcomes and failures, then commit them and the generated analysis separately.
The results commit is allowed to differ from the evaluated commit; explicitly
record both, plus hashes of evaluated artifacts. Editorial changes must not
silently change the scientific objects or recompute metrics by hand.

The required package records:

```yaml
branch: <branch>
commit: <evaluated algorithm/analysis commit>
config: <paths and hashes>
seed_manifest: <path, seeds/split IDs, prior-access disclosure>
canonical_implementation: <files/classes/functions>
primary_claims: <claim IDs with scope>
raw_results: <immutable paths/IDs and hashes>
analysis_script: <path and command>
test_command: <command, environment, result>
known_weaknesses: <explicit list>
```

These angle-bracket fields are a template, not acceptable final evidence. Add
results_commit, environment, reproduction command and manifest path when available.
Represent missing evidence as missing, not an empty success. Use N/A with reasons
for product tasks without seeds/experiments. A newly committed report can refer
to a prior results commit; do not attempt a self-referential commit hash.

## Integrity helper (optional, standard library only)

Run from any directory. Supply explicit tracked files; folders and symlinks are
rejected to prevent accidental secret capture or ambiguous evidence boundaries.

```bash
python3 /path/to/hypodive-builder/scripts/evidence_manifest.py create \
  --repo /path/to/repo --output /path/to/repo/research/freeze.json \
  --files src/engine.py configs/eval.json experiments/run.py experiments/analyze.py
python3 /path/to/hypodive-builder/scripts/evidence_manifest.py verify \
  --repo /path/to/repo --manifest /path/to/repo/research/freeze.json
```

Creation requires a clean git tree and refuses overwrite. Commit the generated
manifest afterward. Verification permits later report commits but verifies the
selected file bytes against both the recorded commit and current files. It does
not execute any command stored in a document. It is **not** a test runner, a
complete transitive dependency audit, a signature, or evidence of preregistration.
Include every relevant local dependency in the explicit file set and record the
runtime environment separately. Restricted data should not be copied into git.

## Handoff and role boundary

Use the 12-section [handoff template](assets/HANDOFF_TEMPLATE.md). Pass the frozen
artifacts and this prompt:

> Treat the Builder's strongest claims as falsifiable hypotheses. Do not defend them. Find the cheapest decisive kill-test first.

Builder stops at handoff. A user or orchestrating workflow invokes the falsifier.
Use a separate context for stronger independence when available and authorized;
do not infer authorization to spawn agents from this document. In a single-context
workflow record the carryover and do not call the review independent. Neither
role may hide known defects to create a cleaner experiment.

## Outcomes and iterations

- GO: preserve evidence; proceed only within authorized productization/submission scope.
- NARROW: update claims to the supported scope; preserve evidence and disclose
  post-hoc narrowing. New empirical claims may require fresh evaluation.
- NO-GO: preserve rejected claim, evidence and reasons. Do not automatically rescue.

If a new hypothesis is explicitly adopted:

**NEW HYPOTHESIS → NEW BUILDER BRANCH → NEW FREEZE → NEW FALSIFIER PASS**

Use a new split for changes informed by holdout results. A transparent correction
of a deterministic analysis bug may use existing raw observations, but must retain
the old analysis/output and its disposition; it is not a fresh confirmatory test.
