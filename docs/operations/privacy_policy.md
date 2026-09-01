# Privacy Policy — KORKEM Flow

> **Draft for KORKEM to review, adapt and host at a public URL.** Google Play
> requires the policy to be reachable without logging in, and rejects listings
> whose Data Safety form contradicts it. The statements below were written
> against what the app's code actually does, not against what a template
> assumes — if the app changes, this changes with it.
>
> Replace the bracketed placeholders before publishing. Have a lawyer read it:
> Kazakhstan's Law on Personal Data and its Protection (No. 94-V) applies here,
> and this draft is an engineering description, not legal advice.

---

**Last updated:** [DATE]
**Applies to:** KORKEM Flow for Android (`kz.korkem.korkem_flow`)
**Operator:** [KORKEM legal entity, address]
**Contact:** [privacy@korkem.kz]

## What this app is

KORKEM Flow is an internal tool for employees of [KORKEM legal entity]. It is a
client for the company's own ERPNext system: it displays and edits business
records — deals, leads, customers, quotes, production orders, stock and tasks —
that already live on the company's server. It is not a consumer service and it
creates no account of its own.

## What we collect

The app collects only what is needed to connect you to your employer's server.

| Data | Why | Where it goes |
|---|---|---|
| Work email address | Identifies you to the ERPNext server | Sent to your employer's server to sign in |
| Password | Signing in | Sent **once**, to your employer's server only. Never stored on the device. |
| Server address | Which installation to connect to | Stored on the device |
| Access credential (API key or session id) | Staying signed in between launches | Stored on the device in Android's encrypted keystore |

The app does **not** collect location, contacts, photos, calendar, microphone,
camera, advertising identifiers, or usage analytics. It contains no advertising
and no third-party trackers.

<!--
MAINTAINER NOTE — not part of the published text, and it must be acted on
before the cloud relay ships.

The paragraph below promises "no other destination and no third party". That is
true today, when the app dials the client's own server directly. It stops being
true the moment `ADR-0026`'s relay exists: the app will then send its traffic to
a KORKEM-operated relay that forwards it to the node.

The relay cannot read the content — that is the whole design — but "cannot read
it" and "does not receive it" are different statements, and a privacy policy
must make the difference. The Play Console Data Safety answers below are binding
declarations, so they have to be revised in the same change.

Do not ship the relay before this section and the Data Safety table describe it.
-->

## Where the data goes

Only to the ERPNext server whose address you enter at sign-in — an installation
operated by [KORKEM legal entity]. The app sends data to no other destination
and shares it with no third party.

Business records shown in the app are stored on that server and governed by
your employer's own retention and access policies, not by this app.

## How credentials are stored

After sign-in, the app keeps one credential on the device so you do not have to
sign in on every launch. It is held in Android's `EncryptedSharedPreferences`,
backed by the system keystore, and is readable only by this app.

Your password is never written to storage. It is sent once, at sign-in, and
discarded from memory afterwards.

Signing out deletes the stored credential from the device immediately —
including when the device is offline and the server cannot be told.

## Network security

All traffic goes to the server address you provide. The app requires HTTPS: an
address entered without a scheme is treated as `https://`. Android additionally
blocks unencrypted HTTP by default.

## Permissions

The app requests two Android permissions:

- **`INTERNET`** — to reach your employer's server.
- **`RECORD_AUDIO`** — only to dictate a message to the assistant, and only
  while you hold the microphone button. It is requested the first time you use
  it, and declining leaves the button hidden rather than broken.

### What happens to what you dictate

Dictation uses **Android's own speech recognition**, not ours. We do not record,
store or transmit audio, and there is no server of ours involved — but Android
may send the audio to Google to transcribe it, exactly as it does for voice
typing in any other app. That is between your device and Google, and it is
governed by Google's privacy policy and by your device's own settings for
speech recognition.

If you would rather nothing left the device, type instead: the assistant does
not treat dictated and typed messages differently.

It also declares that it may open your phone, email and WhatsApp apps when you
tap a customer's phone number or email address. Those actions hand the number
or address to the app you have installed; KORKEM Flow does not send it anywhere
itself, and nothing is sent unless you tap.

## Your rights

Because the records live on your employer's ERPNext system, requests to access,
correct or delete them are handled by [KORKEM legal entity] as the data
controller: [privacy@korkem.kz].

To remove everything this app holds on your device, sign out or uninstall it.

## Children

KORKEM Flow is a workplace tool and is not directed at children.

## Changes

Material changes will be published here with a new "last updated" date.

---

## Data Safety answers for Play Console

Play's form must match the policy above. The truthful answers:

| Question | Answer |
|---|---|
| Does your app collect or share user data? | **Yes** |
| Is data encrypted in transit? | **Yes** — HTTPS |
| Can users request data deletion? | **Yes** — via the contact address |
| **Personal info → Email address** | Collected, **not** shared. Purpose: *App functionality, Account management*. Required. |
| **Personal info → User IDs** | Collected, **not** shared. Purpose: *App functionality*. Required. |
| **Audio → Voice or sound recordings** | **Not collected.** Dictation is handled by Android's recogniser; the app receives text, never audio, and stores neither. |
| Location, Financial info, Health, Messages, Photos, Contacts, Calendar, App activity, Device IDs | **Not collected** |
| Third-party advertising / analytics | **None** |

A password submitted only to authenticate and never stored is not declared as
collected data under Play's definitions; the email and user id are, because the
app retains an identifier tied to them on the device.

The audio row is worth stating explicitly rather than leaving to the catch-all:
the app declares `RECORD_AUDIO`, and a reviewer who sees that permission with no
matching disclosure has to guess. The honest disclosure is that the permission
exists, the recording does not reach us, and Android's own recogniser is what
the user is really trusting.

**If Sentry crash reporting is added later**, this table changes: crash reports
count as *App activity → Diagnostics*, shared with a third-party processor. Both
this policy and the form must be updated in the same change.
