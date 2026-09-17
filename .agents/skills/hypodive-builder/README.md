# HYPODIVE Builder Skill

The constructive half of the HYPODIVE workflow. Build a coherent implementation,
test the relevant invariants, preserve reproducible evidence and expose weaknesses
before hostile falsification. READY FOR FALSIFICATION is not a scientific GO.

Recommended invocation:

```text
Use $hypodive-builder. Build the strongest coherent version of this project within
the requested scope. Do not optimize the narrative. Establish one canonical
implementation, encode invariants, produce reproducible evidence, freeze the
result, and create research/HYPODIVE_BUILDER_HANDOFF.md.
```

Start with [SKILL.md](SKILL.md). The four modes are Foundation, Capability,
Research Evidence and Productization; choose one per iteration unless required.
Use [HANDOFF_PROTOCOL.md](HANDOFF_PROTOCOL.md) before holdout or handoff.
Portable folder layout:

```text
hypodive-builder/
  SKILL.md
  HANDOFF_PROTOCOL.md
  agents/openai.yaml
  references/
  assets/
  scripts/evidence_manifest.py
```

For hosts without native skill discovery, reference SKILL.md from the repository's
agent instructions. The companion falsifier is a separate invocation; Builder
does not silently turn its own handoff into an independent review.
