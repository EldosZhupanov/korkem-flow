# Prior-art and novelty audit

Decompose the proposed contribution into problem, mechanism, guarantee, decision
space and scope. Search concepts rather than only the project's name. Useful
translations:

| Project vocabulary | Adjacent vocabulary |
|---|---|
| abstain | reject option, selective prediction, agnostic testing, indecision |
| safe stopping | sequential testing, confidence sequences, anytime-valid inference |
| coverage | fill distance, covering radius, space-filling/maximin design |
| falsification | model criticism, goodness-of-fit, misspecification detection |
| safety wrapper | policy-agnostic risk control, sampling-independent stopping |

Browse current literature when available; follow promising results to primary
papers, official implementations and actual theorem statements/proofs. A title,
abstract, search snippet or secondary summary cannot establish exact equivalence.
Record search date, query trail, inspected sections, inaccessible sources and
uncertainty. No search access means UNKNOWN, not CLEAR.

Create `research/PRIOR_ART_MATRIX.md`:

`Proposed contribution | Closest prior work | Same problem? | Same mechanism? |
Same guarantee? | Same decision space? | Difference that remains`.

Add source URL, theorem/section, assumptions and reading depth for each decisive
entry. Distinguish a theorem printed by the source from your own corollary or
composition. A different name, API or packaging is not new mathematics. Nor is a
special case automatically new because a general theorem uses different notation.
An equivalent guarantee without the project's incidental confirmation mechanism
can count against novelty.

Statuses:

- CLEAR: a specific substantive distinction supported against the closest inspected
  prior art; never a claim of exhaustive priority worldwide.
- PLAUSIBLE: concrete candidate distinction, insufficient verification.
- NARROW: broad idea known; only a precisely scoped contribution remains.
- OVERLAPPING: substantial overlap whose remaining distinction is unresolved.
- NOT NOVEL: the proposed contribution is established or an elementary restatement.
- UNKNOWN: insufficient access/search/detail for a defensible classification.

If the requested exact-match kill criterion is met, close the research claim,
preserve the branch/evidence and explain equivalence. Closing a research direction
does not mean deleting a git branch or data. If no exact match is verified, say so;
do not convert an incomplete search into either priority or a false equivalence.
An elementary combination of known ingredients can still fail the significance
gate even without one paper containing the exact combination.

Product usefulness and scientific novelty are separate. A valuable integration
may deserve engineering investment while being unsuitable as a new-method paper.
