# FieldWork iOS — Install Visit Screen Spec

**FabricateOS · Version 1.0 · March 2026 · Claude Code handoff**

---

## Overview

The Install Visit is the second field visit type in FieldWork after the Template Visit. It is used by the install crew lead to document arrival, capture installation status per surface, log issues, and collect customer sign-off on completed work.

The install visit follows the same tab-based navigation pattern as the Template Visit (`Measure / Site / Photos / Check`) but replaces measurement capture with installation status capture. The crew lead is the only person expected to use the app — they act on behalf of the full crew.

---

## Navigation Structure

Same top-level shell as the Template Visit:

- **Close button** (top left) — returns to job detail screen with confirmation if visit is in progress
- **Title bar** — "Install Visit"
- **4-tab segmented control** — `Areas · Site · Photos · Sign`
- **Progress bar** (bottom) — X/Y surfaces confirmed
- **Primary CTA button** (bottom) — state-dependent label (see Tab: Areas)

> **Note:** Tab names differ from Template Visit. Template uses `Measure / Site / Photos / Check`. Install uses `Areas / Site / Photos / Sign`. Same shell, different content.

---

## Screen 1 — Job Detail (Pre-Visit)

Identical structure to the Template Visit job detail screen. Accessed by tapping a scheduled install visit card on the schedule list, expanding it, then tapping **View Job**.

### Header card
| Field | Value |
|---|---|
| Status pill | Scheduled / In Progress |
| Visit type label | Install (right-aligned, bold) |
| Time | Scheduled start time |
| Construction type | e.g. New Construction / Remodel |

### Salesperson card
| Field | Value |
|---|---|
| Name | Full name |
| Phone | Blue, tappable `tel:` link |

### Customer card
| Field | Value |
|---|---|
| Name | Customer or account name |
| Phone | Tappable `tel:` link |

### Job Site card
| Field | Value |
|---|---|
| Address | Full address, tappable to open Maps |
| Site contact | Name + tappable phone if different from customer |

### Scope card
| Field | Value |
|---|---|
| Rooms | Count |
| Surfaces | Count |
| Sq footage | Total quoted sqft |

**Primary CTA:** `Start Visit` (blue, full-width rounded button)

**Secondary:** `Can't complete this visit` (red/pink) — shown if blockers exist (e.g. payment not cleared for retail job)

> Tapping Start Visit triggers the Start Visit bottom sheet — same pattern as Template Visit.

---

## Screen 2 — Start Visit Bottom Sheet

Sheet slides up from bottom on tap of Start Visit. Identical pattern to Template Visit bottom sheet.

- Header: `Cancel` (left) · `Start Visit` (center title)
- Destination summary card: customer name, full address, salesperson + site contact with phones
- **Starting From** label + address text input (pre-populated with shop address if first visit of day, or previous job site if mid-day)
- **Start Visit** button (blue, full-width, car icon) — captures GPS departure coordinates + timestamp, begins travel time tracking, pushes to visit flow

> `departed_at`, `departure_lat`, `departure_lng` written to `field_service_visit` on tap.

---

## Tab 1 — Areas

The core of the install visit. The crew lead works through each surface in the job scope one by one, marking status and capturing photos.

### Surface List

Surfaces are pulled from the job scope (same rooms and surfaces established at template). Each surface renders as a card:

- Surface name (e.g. "Master Bath — Vanity")
- Room label (subdued, smaller)
- Status indicator — `pending / installed / partial / not installed`
- Camera icon shortcut (same blue circle pattern as Template Visit)
- Chevron to expand

> Surfaces are pre-populated from the job record. The crew lead cannot add or remove surfaces here — scope changes go through the office via change order flow.

### Surface Card — Expanded

#### Status Selection

A segmented or button-group control with 3 options:

- ✅ **Installed** — complete, no issues
- ⚠️ **Partial** — installed but needs follow-up
- ❌ **Not Installed** — could not complete

> Selecting Partial or Not Installed reveals the Issue section below. Selecting Installed hides it.

#### Issue Section (shown when Partial or Not Installed)

**Responsibility selector** — two tappable pills:
- `Our Issue` (fabricator responsibility)
- `Customer Issue` (customer / site responsibility)

**Reason code picker** — scrollable list filtered by selected responsibility. Populated from org's configured reason codes (see Settings section).

Our Issue reasons (seed data):
- Piece not loaded / forgotten at shop
- Piece damaged in transport
- Piece cut incorrectly
- Wrong material or color
- Edge profile incorrect
- Piece too short / doesn't fit

Customer Issue reasons (seed data):
- Cabinets not installed / not ready
- Cabinets not level
- Tearout not complete
- Appliances not removed
- Plumbing not capped
- Electrical in the way
- Site not accessible

**Notes field** — free text, optional for Partial, required for Not Installed

**Photo required indicator** — if org config requires photo on flagged surfaces, shows prompt

> Responsibility + reason code drive downstream follow-up automatically. Our Issue → internal service queue + shop notification. Customer Issue → customer/site contact outreach, return visit holds until site confirms ready.

#### Photos (per surface)

Same camera icon shortcut as Template Visit. Opens inline camera / library picker. Photos tagged to this surface automatically. Mark Up Photo screen fires after every capture (see Photo Markup section).

### Progress Bar + CTA

Bottom of screen:

- Progress bar — X/Y surfaces confirmed (any status set counts as confirmed)
- CTA label changes based on state:
  - All surfaces installed, no flags → **Complete Visit**
  - Some surfaces flagged → **Complete Visit with Issues (X flagged)**
  - No surfaces confirmed yet → **Complete as Partial (0/Y)**

> A visit can always be closed regardless of surface status. Flagged surfaces do not block completion — they generate follow-up records automatically on close.

---

## Tab 2 — Site

Site-level observations that apply to the whole visit, not a specific surface. Same structure as Template Visit Site tab.

- Site condition notes — free text field
- Access issues toggle — yes / no, with notes if yes
- Tearout status — complete / incomplete / not applicable
- General site photos — captured here or in Photos tab

> Tearout incomplete here is a site-level flag, separate from a per-surface "cabinets not ready" reason code. Both can be true simultaneously.

---

## Tab 3 — Photos

Identical pattern to Template Visit Photos tab.

- Filter chips: `All · Site · [Surface name]` per surface
- Grid view of all captured photos for this visit
- Camera button + Library button at bottom
- Photo type picker (chevron/dropdown): `Site Photo · [Surface name]`

> Photos taken within a surface card (Areas tab) are automatically tagged to that surface. Photos taken from the Photos tab require manual surface tag selection.

---

## Tab 4 — Sign

The completion and sign-off step. This tab is the final action before closing the visit. It is only fully active after the crew lead has set a status on all surfaces.

### Completion Summary

Before the signature section, show a summary card:

- X of Y surfaces fully installed
- X surfaces flagged (if any) — listed by name with status pill

### Signature — Two Paths (org-configured)

The org admin configures signature behavior in Settings. Two modes:

#### Path A — In-Person Signature

Default for retail jobs where customer is present.

- Instruction text: "Hand device to customer to sign below"
- Drawn signature pad — full width, clear white area
- Clear button — resets signature
- Customer name text field — typed by crew lead or customer
- **Confirm & Complete** button — captures signature image, timestamps, closes visit

#### Path B — Remote Signature Link

For jobs where customer is not on site (builder accounts, big box, or org preference).

- Customer email display (from job record)
- Customer phone display (from job record)
- **Send Link** button — fires tokenized signature request via Resend (email) and/or Twilio (SMS)
- Sent confirmation state — shows timestamp, recipient, send status
- **Complete Without Signature** button — available after link is sent, closes visit with pending signature status

Remote signature flow (customer-side):
- Customer receives email/SMS with link
- Link opens web view showing installation summary + photo thumbnails
- Customer signs on their own device
- Customer can Accept (signs) or Reject (must select reason + note)
- Rejection fires notification to office immediately
- Job record updated with signature status automatically

> Signature requirement (required vs optional) and default path (in-person vs remote) are both org-level settings configurable per job type (retail vs account). See Settings section.

### Post-Completion

On tap of Confirm & Complete or Complete Without Signature:

- Visit record closed — `completed_at` timestamp + completion GPS captured
- Any flagged surfaces → service call records auto-generated, linked to original visit
- Our Issue flags → internal notification to office / shop queue
- Customer Issue flags → outreach task created, customer/site contact notified
- Retail job → status advances to `Complete` (all installed) or `Pending Service` (flags exist)
- Account job → invoice data push to accounting system trigger fires
- Visit summary screen shown — recap of what was completed, what was flagged, confirmation that follow-ups were created

---

## Photo Markup — Platform Feature

Photo markup is a platform-level capability in FieldWork, not specific to any visit type. It fires automatically after every photo capture across template, install, and audit visits. No new work is required to support markup in the install visit — the existing markup screen is reused as-is.

### Current Implementation (from Template Visit)

After every photo is captured, the **Mark Up Photo** screen is presented full-screen before the photo is saved:

- Black full-screen canvas with photo centered
- **Skip** button (top left) — saves photo without markup
- **Green checkmark** confirm button (top right) — saves photo with markup applied
- Bottom toolbar:
  - 4 color swatches — red, yellow, white, blue
  - Arrow tool
  - Pen / freehand tool
  - Undo button
  - Delete / clear all button

> Markup is baked into the saved image on confirm. It is not stored as a separate overlay layer. The marked-up image is what gets stored and displayed everywhere in the app and back office.

### Install Visit — Same Behavior

The markup screen fires identically for all photos taken during the install visit — surface photos, site photos, and issue photos. No changes to the markup component are needed.

### Issue Photo Importance

Markup is especially meaningful when a surface is flagged as Partial or Not Installed. A marked-up photo showing a chip, seam gap, incorrect cut, or site obstruction becomes part of the service call record — the primary evidence for responsibility determination (Our Issue vs Customer Issue).

- Flagged surface photos should be surfaced prominently in the generated service call record on the back office side — not buried in a generic job photos list
- The service call record should display the markup photo, the responsibility assignment, and the reason code together as a unit

> Back office photo display spec (service call record) is out of scope for this document but flagged as a requirement when the service call UI is designed.

---

## Settings — Install Visit Configuration

Managed in FabricateOS web admin under **Settings → Field Visits → Install**.

### Signature Settings

| Setting | Description |
|---|---|
| Require signature | Toggle per job type (Retail / Builder Account / Big Box) |
| Default signature path | In-Person or Remote Link per job type |
| Allow crew lead to switch path | Toggle — if on, crew lead can override default on the day |
| Signature document label | Text shown on customer-facing signature screen |

### Issue Reason Codes

Managed under **Settings → Field Visits → Issue Reasons**. Separate lists for Our Issue and Customer Issue.

- Add custom reason code — label + responsibility assignment
- Toggle active / inactive (inactive codes hidden in FieldWork)
- Reorder display order
- **Requires photo** toggle — photo required when this reason is selected
- **Requires reschedule** toggle — return visit automatically flagged as needed

> Seed data loaded on org creation. Orgs can trim, rename, or extend without affecting other orgs. Demo org gets the full curated list.

### Completion Rules

| Setting | Default |
|---|---|
| Allow partial close | Always on — visit can close with flagged surfaces |
| Photo required on flag | Toggle — off by default |
| Notes required on Not Installed | Toggle — on by default |
| Auto-generate service call on flag | Toggle — on by default |
| Notify office on Our Issue flag | Toggle — on by default, fires to salesperson + ops |

---

## Schema Reference

The install visit maps to the existing `field_service_visit` table. No new tables required for the visit record itself.

### field_service_visit (existing)

Key fields used by install visit:

| Field | Notes |
|---|---|
| `visit_type` | `'install'` |
| `departed_at`, `departure_lat`, `departure_lng` | Captured on Start Visit |
| `arrived_at`, `arrival_lat`, `arrival_lng` | Captured on Arrived tap |
| `completed_at`, `completion_lat`, `completion_lng` | Captured on Confirm & Complete |
| `signature_required` | From org config |
| `signature_captured` | `true` when in-person signature collected |
| `signed_by_name` | Customer name field |
| `signed_at` | Timestamp of signature |
| `outcome` | `installed / partial / not_installed` (overall visit outcome) |
| `field_notes` | Site-level notes (Site tab) |

### visit_surface_status (new extension table)

One row per surface per visit:

| Field | Notes |
|---|---|
| `visit_id` | FK to `field_service_visit` |
| `surface_id` | FK to surface/scope record |
| `status` | `installed / partial / not_installed` |
| `responsibility` | `fabricator / customer` — nullable, only set when status ≠ installed |
| `reason_code_id` | FK to `issue_reason_code` |
| `notes` | Free text |

Photos linked via `visit_photo` table with `surface_id` tag.

> Service call records generated on completion link back to `visit_id` and `surface_id` so the full history is traceable from the job record.

---

## Open Questions

- Should the progress bar count surfaces with any status set (current assumption) or only fully-installed surfaces?
- On the Sign tab, if path is Remote and link is sent but customer hasn't signed yet — can the crew lead re-send or does it lock?
- Does the visit summary screen after completion need to be shareable / printable, or is it informational only?
- For builder / big box jobs where signature is not required, does the Sign tab still appear (grayed) or is it hidden entirely?

---

*End of spec — FabricateOS FieldWork Install Visit v1.0*
