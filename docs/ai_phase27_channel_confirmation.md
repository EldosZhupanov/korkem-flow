# Phase 27A — Confirming a write from a chat app

**Date:** 2026-08-11. Follows the channel gateway and the role policy layer.

## Goal

Approve a `Pending Action` from Telegram or WhatsApp, instead of being told to
open the app.

## What existed

`channels/gateway.py` ran the real assistant as the resolved user, and a tool
needing confirmation stopped the turn with *"Подтвердите его в приложении
KORKEM"* — a dead end for anybody who is on a shop floor with a phone.

`Pending Action` already did the hard part: it records the tool and arguments
when the model proposes them, re-checks the target still exists, claims itself
with a single conditional `UPDATE` so two confirmations cannot both win, and
refuses once it is no longer `Pending`.

## What changed

`channels/confirmation.py`. No new action model — the app and the chat apps
approve the same row by the same `approve()`.

What was missing was either side of it: turning *"подтверждаю"* into a specific
row, and refusing when it is not this person's row.

```
Telegram: «Останови производство…»
  → Pending Action written, tied to this conversation
  → "Остановить производство MFG-WO-… \n\nПодтвердить?
     Ответьте «подтверждаю» или «отмена», либо CONFIRM <id> / CANCEL <id>."
Telegram: «подтверждаю»
  → approved, executed once
Telegram: «подтверждаю»
  → "Это действие уже выполнено."
```

A confirmation reply is answered **without the model**. A message that decides
whether a write runs must not be re-interpreted by something that can be argued
with.

## Why a bare "да" is safe here

It is never read as approval of *something*. It resolves against the
conversation and only when exactly one action is waiting in it, owned by the
person who wrote it. Two waiting actions make it ambiguous and it is refused
with both named — guessing there executes a write nobody asked for. Expired
actions are excluded from that count, so a stale row cannot make a live one
ambiguous.

`CONFIRM <id>` carries its own answer and does not need the conversation to be
unambiguous, but still has to be that person's action.

## The reference is the row's own name

`Pending Action` is named by hash — short, opaque, non-sequential. Minting a
second identifier would mean keeping two in step for nothing. Ownership is what
protects it, not obscurity: a name belonging to somebody else is refused **in
the same words** as a name that does not exist, because confirming that another
person has an action pending is worth nothing to them and something to whoever
is asking.

## Defect found and fixed

**The audit could have recorded the wrong approver.** Ownership is checked
against the caller's `user` argument, while `Pending Action.claim` stamps
`resolved_by` from the session. The gateway sets the session first so they
agree — but nothing made them agree, and the independent ERPNext check caught it
red-handed: a probe that ran `handle(PLANNER, …)` as Administrator produced a row
saying Administrator had approved the planner's action. A false audit trail is
worse than none. `handle` now refuses outright when the two differ.

## Tests

**637** `korkem_ai` (+23), **13** `korkem_manufacturing`, **311** Flutter.

The twenty-three cover the brief's list: a proposal changes nothing; the person
is asked in words they can answer; the tool's internal name is not shown; a bare
yes approves the one waiting action; an explicit reference approves it;
cancelling runs nothing; an ordinary message is not a confirmation; nothing
waiting; **two waiting actions refuse and name both**; naming one resolves it;
another person's action cannot be confirmed and is refused in identical words;
a bare yes never reaches another person's action; **the second confirmation
executes nothing**; the work order is stopped once not twice (asserted on
`modified` and `resolved_at`); confirming after a cancel runs nothing; an
expired action is refused; an expired action does not make a bare yes ambiguous;
approving runs exactly the recorded tool and arguments; the audit records who
actually approved; handling as somebody else is refused; and the whole turn from
a channel — proposal attached to the conversation, then approved without the
model being called at all.

## Android

`stop_production_e2e_test.dart`, `emulator-5554`, `korkem.planner@example.com`:
**`00:59 +1: All tests passed!`** — the app's own confirmation flow, unchanged,
which is the regression §8 asks for.

The first run of this failed with no assistant reply; the second passed on the
same code, and the backend suite covers the same path. Recorded as a transient
queue or model delay rather than explained, because it was not reproduced.

**Channel confirmation itself is not verified on a device.** Telegram and
WhatsApp cannot reach `korkem.localhost` inside Docker, so the provider is
**MOCK VERIFIED — REAL PROVIDER NOT VERIFIED**, and the flow is proven at
backend and ERPNext level instead.

## ERPNext independent verification

Read directly from the database, not from any tool response:

```
1 PROPOSED   Work Order: In Process  ·  Pending Action: Pending
             reserved 164.8                              ← nothing changed
2 CONFIRMED  Work Order: Stopped     ·  Pending Action: Approved
             reserved 104.8                              ← changed once
3 AGAIN      already_resolved
             Work Order.modified identical · resolved_at identical
```

Sixty units of material released on the one execution, and the second
confirmation moved nothing — asserted on timestamps, not on a status string.

## Security

- Ownership checked before anything; another person's action refused with no
  mutation, in words that reveal nothing.
- Session and claimed owner forced to agree, so the audit cannot lie.
- Expiry, target re-validation and the atomic claim are `Pending Action`'s own
  and unchanged.
- The tool and arguments are read from the row, never re-proposed.
- Confirmation is answered without the model.

## Limitations

- Telegram inline buttons and WhatsApp interactive buttons are **not**
  implemented; both channels use the text protocol (`подтверждаю` / `отмена` /
  `CONFIRM <id>`). Rendering native buttons belongs in the adapters and is the
  obvious next increment.
- Not verified against a real provider.
- A customer still reaches no tools, so nothing they say can produce a
  `Pending Action` in the first place.

## Gates

analyze clean · format clean (204 files) · secret scan clean (incl. bot-token
and `EAA` patterns) · `git diff --check` clean · four vendored repos pristine.

## Commits

`korkem_ai`, root — listed in the final report.
