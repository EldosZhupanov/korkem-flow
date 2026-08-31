---
name: korkem-docs
description: Where KORKEM documentation lives, which files are authoritative, and the rules that stop documentation sprawl. Load before writing any .md file in this repository, before starting work (to find the current truth), and whenever a document and the code disagree.
---

# KORKEM documentation — what is true, and where

This repository once accumulated 45 markdown files, 29 of them phase reports
describing work that had since been superseded. An agent reading them in the
wrong order would build against a state of the world that no longer existed.
The layout below exists to prevent that recurring.

## The five files that are authoritative

Read them in this order. Nothing else overrides them.

| file | answers | changes |
|---|---|---|
| `PROJECT.md` | what the product is and is not | rarely — a product decision |
| `PLAN.md` | the target architecture and its invariants | when architecture changes |
| `ROADMAP.md` | what gets built, in what order, why | per horizon |
| `NOW.md` | what is being worked on **this week**, and the exact next step | continuously |
| `CLAUDE.md` | how an agent works in this repo | when conventions change |

If a document in `docs/` disagrees with one of these five, the five win.
If code disagrees with all six, **the code wins** and the document is wrong —
say so, and fix the document in the same change.

## Everything else

```
docs/
├── architecture/   ADRs, domain model, gateway and workspace design
├── operations/     deployment, backup/restore, release, privacy
├── product/        the client's own specification, verbatim
└── archive/        history. NOT current truth. Never build from it.
```

`docs/archive/` holds phase reports, superseded audits and completed sprint
checklists. They are kept because they record *why* a thing is the way it is —
the reasoning that would otherwise be lost. They are **not** a description of
the system today, and every file in there carries a banner saying so.

**Do not read `docs/archive/` to find out how the system works.** Read it only
when you need the reason behind a specific decision, and you already know from
the authoritative five that the decision still stands.

## Rules for writing

**One fact, one place.** If two files would state the same thing, one of them
links to the other. A duplicated fact becomes two facts as soon as one is
edited.

**Nothing is "verified" unless it was measured.** Write what was run and what
it printed. `LIVE VERIFIED`, `NOT VERIFIED` and `NOT IMPLEMENTED` are the
project's existing vocabulary — keep using them, and never upgrade a claim you
did not personally re-run.

**Say what is missing, in the same document.** Every phase report in the
archive has a Limitations section, and that is why they are still trustworthy
years later. A document that only describes success is a document nobody can
plan against.

**Absolute dates, never relative.** "Last week" is unreadable in six months.

**No new top-level markdown file** without deleting or archiving one. The
five above plus `README.md` is the whole root inventory. A sixth needs a
reason stated in the commit.

**Finishing a phase means updating `NOW.md` and `ROADMAP.md`,** not writing a
new phase report. Write the report only when the reasoning is worth keeping —
then put it straight into `docs/archive/` with its banner, and link it from the
roadmap item it belongs to.

## Language

Russian and English both appear and that is fine. Use **one language per
document**, and keep domain terms in the language the shop floor uses: Раскрой,
Кромление, ЧПУ, Сверление, Покраска, Сборка, ОТК. Translating those into
English in code or documents has already caused confusion once.

## Before you start any task

```
NOW.md      →  what is in flight, and what not to touch
ROADMAP.md  →  which horizon this belongs to
PLAN.md     →  which invariant it must not break
```

If the task does not map to a roadmap item, that is worth saying out loud
before writing code — it is either a missing roadmap item or work that should
not happen yet.
