# Review: the Codex changes found uncommitted in the working tree

**Date:** 2026-08-31. **Reviewer:** a later agent, not the author.
**Rule applied:** another agent's work is not ours by default. Nothing was
committed before this review.

Four changes were in the tree, made by a Codex session whose task was
"исправить установку custom field и подготовку fixtures". Its own run still
ended with three errors, so the work was unfinished as well as unreviewed.

---

## 1. `korkem_ai/install.py` + enabling `before_tests` in `hooks.py` → **KEEP**

`install.py` is new; `hooks.py` uncomments one line to point at it. It runs
`setup.provision()`, creates four narrow CRM records, then `seed_demo.seed()`.

| question | answer |
|---|---|
| What problem does it solve? | The `korkem_ai` suite reads a seeded factory. Without one it does not fail — it **skips**. |
| Reproducible failure without it? | Worse than a failure. `tools/test_production.py:_ProductionTestCase.setUp` ends with `self.skipTest("seed_demo has not been run on this site")`, so ~130 production tests vanish silently and the run reports OK. |
| Duplicates our fixture fix? | No. Ours (`IGNORE_TEST_RECORD_DEPENDENCIES`) stops `setUpClass` walking into ERPNext's test bootstrap. This one supplies data. Different defects; Codex's own run proves it, because those three suites were still erroring after this change. |
| Changes production behaviour? | No. `before_tests` runs only under the test runner, and `install.py` is reachable from nothing else. |
| Test bootstrap only? | Yes. |
| Could it hide non-idempotent fixtures? | **No, and this was the question worth asking.** It runs **once per run**, not per test — it is not a per-test state reset. `provision()` and `seed()` are idempotent by construction and refuse on a production site; `_prepare_crm_records` guards every insert with `db.exists`. |
| Narrower solution? | Each test creating its own factory would be slower and duplicated in five modules. `before_tests` is Frappe's own hook for exactly this. |
| Still needed after our H0 fix? | Yes. Ours makes three suites run; this one makes ~130 more run at all. |

**One correction made on adoption.** `_prepare_crm_records`'s docstring says it
exists because `make_test_records` "recursively imports the ERPNext test
bootstrap". That was true when written and is now only half the story: the real
fix for that import is `IGNORE_TEST_RECORD_DEPENDENCIES`, and this function's
justification is narrowness and speed. Left as-is rather than edited, because
editing another agent's reasoning in the same commit that adopts it makes the
adoption unreviewable — raised here instead.

## 2. `tools/test_timeline.py` → **KEEP**

Changes an assertion from `count("CRM Deal") > 100` to `> 0`, and drops a
docstring claiming "there are 2094 CRM deals on this bench".

The original test asserted a fact about **one developer's machine** — a CRM
demo import nobody else has. On any freshly seeded site it fails, for a reason
that has nothing to do with what it tests. The test's actual subject is "there
exist unrelated deals, so a name-similarity join would invent a relationship";
`> 0` is the weakest assertion that still expresses it, and the only one that
is portable.

Weaker than ideal, and correct. A test coupled to one machine is not a stronger
test, it is a test that can only ever be run in one place.

## 3. `tools/test_write_tools.py` → **KEEP**

`setUp` now sets `AI Settings` to Anthropic / `test-model` and creates the CRM
Lead Source and Status if absent; `tearDown` restores and removes what it
created. The assertion `action.provider == "Google Gemini"` becomes
`"Anthropic"`.

Same class of defect as (2): the old assertion depended on whatever provider
that bench happened to have configured. A test that sets its own configuration
is the fix.

**Two things checked before accepting, because both looked wrong at first:**

- `frappe.db.commit()` in `tearDown` appeared to defeat `IntegrationTestCase`'s
  rollback. It is **the established convention here** — ten other test modules
  in this app do it (`test_onboarding`, `test_chat`, `test_channels_api`,
  `test_launch_readiness`, …). Consistent, not anomalous.
- `frappe.delete_doc(..., force=True)` on shared CRM records could strand a
  later test. It is guarded by `if self.created_*`, and `install.py` creates
  those records first, so the flag is false and nothing is deleted. Self-
  cleaning when `before_tests` is absent, inert when it is present.

**Accepted duplication.** The CRM records are created both here and in
`install.py`. That is duplication, and it is the kind that makes a module
runnable on its own. Noted rather than removed.

## 4. `korkem_manufacturing/install.py` + two hooks → **KEEP**

Found late, after the first three had already been reviewed — which is worth
recording, because it means the first pass of this review was incomplete and
called the work "test bootstrap only" when part of it is not.

`hooks.py` enables both `after_install` and `before_tests`. The second is the
same pattern as (1). **The first changes production behaviour**, and correctly.

`after_install` calls the `add_originating_deal_to_work_order` patch's own
`execute()`. Frappe does not replay `patches.txt` while an app is being
installed for the first time, so without this a *fresh* site never gets
`Work Order.originating_deal` — the Link back to the CRM Deal that the whole
customer-timeline slice reads. That is the "исправить установку custom field"
half of the Codex task, and it was a real defect: the field existed on this
developer's bench only because a migration had run there.

Idempotent by construction — the patch early-returns when the field exists — so
all three paths agree: fresh install creates it, an upgrade's patch finds it
present, a re-run does nothing.


---

## Verdict

**KEEP all four, committed separately from our own work and attributed.**
Nothing was REWORK or DROP.

The judgement that decided it: this is not a workaround that clears state
before each test. It is a bootstrap that makes ~130 silently-skipped tests
actually run — the opposite failure mode, and the one this project cares about
most.

## What this review did not do

- Did not run the suite **without** `before_tests` to measure the skip count
  directly. The code path is unambiguous (`skipTest` on missing seed data) and
  a counterfactual run costs 25 minutes; the claim rests on reading, and says so.
- Did not verify Codex's changes on a clean volume separately from ours.
