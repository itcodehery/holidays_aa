# Leave Management App: Creative Features and Enhancements

A companion to `leave_management_architecture.md`. The core document covers what must be built for the assignment. This one collects optional features that make the app more useful and more impressive, grouped by who benefits.

**How to read the tags**

- ⭐ **Demo-friendly:** cheap to build and visibly impressive in a short demo
- **Effort:** S (under 30 min), M (30-60 min), L (over 1 hour) for a developer who already has the core app working
- **Needs:** the part of the existing architecture the feature builds on or changes

---

## 1. Recommended "wow" set for the interview

If there are about 45 spare minutes after the core app works, pick three or four of these. They all reuse `LeavePolicy` and add visible polish without touching the approval workflow.

| Feature | Audience | Effort |
|---|---|---|
| Live balance preview | Employee | M |
| Smart date picker with working-day explanation | Employee | M |
| Team conflict warning in the review sheet | Manager | S-M |
| Quick-reply comment chips | Manager | S |

Describe everything else under "Next steps" in the README instead of building it.

---

## 2. For employees

### ⭐ Live balance preview
**What:** On the apply form, show a ring or bar such as *"Annual leave: 12 left → 8 after this request."*
**Why:** People always want to know the impact before submitting. It also prevents requests that would exceed the balance.
**How:** Add a `leave_balances` table (employee, leave type, year, allocated, used). `LeavePolicy` gets one function that computes the remaining balance. The form calls it with the live working-day count.
**Needs:** New table, new domain model, one policy function. Effort: M.

### ⭐ Smart date picker
**What:** Weekends and public holidays are greyed out, with a live counter: *"4 working days (2 weekend days skipped)."*
**Why:** It explains the count so the number never feels like a surprise, and it makes the >3 day rule obvious.
**How:** Custom range picker that reads a holiday set. `countWorkingDays` already accepts a `holidays` parameter.
**Needs:** Holiday list (a constant for the demo, a table later). Effort: M.

### ⭐ Proof checklist per leave type
**What:** A contextual message on the form, for example *"Marriage leave: attach an invitation or marriage certificate."*
**Why:** Employees know exactly what to upload and avoid rejected requests.
**How:** A lookup of text per leave type, shown next to the helper line already driven by `AttachmentPolicy.proofRequirement`.
**Needs:** Nothing new. Effort: S.

### Bridge-day suggestion
**What:** *"Take Friday off and get 4 days away for 1 day of leave."*
**Why:** A fun, genuinely useful nudge around holidays.
**How:** Scan the holiday list for holidays adjacent to a weekend and suggest the gap day.
**Needs:** Holiday list. Effort: M.

### Draft autosave
**What:** An unfinished apply form survives an app restart.
**How:** Persist the form fields (not attachments) with `shared_preferences` on change, and restore on open. Clear on successful submit.
**Needs:** `shared_preferences`. Effort: S-M.

### Nudge button
**What:** If a request has been pending for more than 2 days, the employee can send a reminder to the current approver, limited to once per 24 hours.
**How:** A `last_nudged_at` column on the request and a server-side rate limit in an RPC.
**Needs:** One column, one RPC, a notification channel to be useful. Effort: M.

### Add to calendar
**What:** Export an approved leave as an `.ics` file.
**How:** Generate the iCalendar text in Dart and share or download it.
**Needs:** Small utility, possibly `share_plus`. Effort: S-M.

### Half-day and hourly leave
**What:** Allow 0.5-day requests (morning or afternoon) and optionally hours.
**How:** `total_days` becomes a decimal, the policy handles 0.5 increments, and the date picker gets a half-day toggle for the first and last day.
**Needs:** Schema change (`numeric` instead of `int`), policy and test updates. Effort: M-L.

### Cancellation of approved future leave
**What:** An employee can ask to cancel leave that is already approved and in the future.
**Why:** A realistic second path through the state machine.
**How:** New status `cancellation_requested`, which needs approver sign-off before moving to `cancelled`.
**Needs:** New status, new transitions in `nextStatus`, RPC update. Effort: L.

---

## 3. For managers

### ⭐ Team conflict warning
**What:** In the review sheet: *"2 of 5 teammates are already off on these dates."*
**Why:** It lets managers decide with context instead of approving blindly.
**How:** One overlap query across the manager's direct reports for the requested dates. In the in-memory repo it is a filter over the existing list.
**Needs:** One repository method such as `getTeamLeaveOverlap`. Effort: S-M.

### ⭐ Quick-reply comment chips
**What:** Tappable canned comments: "Approved, enjoy!", "Please reassign your tasks first", "Dates clash with release."
**Why:** Commenting becomes one tap, so managers actually leave comments.
**How:** A row of `ActionChip`s that fill the comment field.
**Needs:** Nothing new. Effort: S.

### Team calendar view
**What:** A month grid with coloured bars per person showing who is off when.
**How:** Build from the same data as the conflict warning. Keep it read-only.
**Needs:** A calendar widget (custom or a package). Effort: L.

### Swipe to approve or reject, with Undo
**What:** Swipe a card to decide, with a 5-second Undo before the decision commits.
**Why:** Fast on mobile and safer against accidental taps.
**How:** `Dismissible` plus a delayed commit that is cancelled by Undo. Rejection still needs a comment, so swipe-to-reject opens the comment prompt first.
**Needs:** UI only. Effort: M.

### Request more information
**What:** A new status `needs_info`. The manager asks a question, the employee replies or adds a document, and the request returns to `pending_manager`.
**Why:** It is the natural follow-up to attachments, and it avoids rejecting requests that only lack detail.
**How:** New status, a small `leave_messages` table for the exchange, and new transitions. Note that attachments are otherwise immutable, so decide whether follow-up uploads are allowed in this state only.
**Needs:** State machine change, new table, RPC update. Effort: L.

### Delegation
**What:** When a manager is out, a delegate can approve in their place.
**How:** A `delegations` table (manager, delegate, date range). The RPC accepts the delegate and records both the delegate and the original approver in the audit row.
**Needs:** New table, RPC and RLS changes. Effort: L.

### Auto-escalation
**What:** If no action happens within N days, the request escalates to HR or the manager's manager.
**How:** A scheduled job (Supabase cron or Edge Function) that moves overdue requests and writes an audit entry.
**Needs:** Backend scheduling. Effort: M-L.

---

## 4. For HR / Admin

### Policy as data
**What:** Move `kMultiApprovalThreshold` and the proof rules out of code into a `leave_policies` table that HR can edit.
**Why:** Rules change without a deploy.
**How:** Load policies at startup into a provider and pass them into the pure policy functions as parameters, which keeps the policies testable.
**Needs:** New table, policy functions that accept configuration. Effort: M-L.

### Holiday calendar management
**What:** HR maintains the public holiday list per year or region.
**Needs:** `holidays` table, an admin screen, and the date picker and working-day counter reading from it. Effort: M.

### Balance adjustments
**What:** HR can grant, deduct, or carry over leave balances with a reason.
**Needs:** Builds on `leave_balances`, plus an adjustments log for auditability. Effort: M.

### Reports
**What:** Leave per month, sick-leave hot spots, and CSV export.
**How:** SQL views or RPCs for aggregates, with simple charts in the app.
**Needs:** Aggregation queries, export utility. Effort: L.

### Audit view
**What:** A searchable log of every decision (who, what, when, comment).
**How:** A read-only screen over `leave_approvals` joined with requests and profiles.
**Needs:** One query and one screen. Effort: M.

---

## 5. System-level

### ⭐ Realtime updates
**What:** A live badge on the manager's Pending tab, and an instant status change on the employee's screen without refreshing.
**How:** Supabase realtime streams feeding the Riverpod providers (`StreamProvider` or a notifier that subscribes). The in-memory repository can emulate this with a `StreamController`.
**Needs:** Stream method on the repository interface. Effort: M.

### Notifications
**What:** Email or push on submitted, approved, rejected, and needs-info.
**How:** Database webhooks or Edge Functions for email, FCM for push.
**Needs:** External service setup. Effort: L.

### Localization and dark mode
**What:** Multiple languages, plus light and dark themes.
**How:** Dark mode is nearly free with Material 3 `ColorScheme.fromSeed`. Localization uses `flutter_localizations` and ARB files.
**Needs:** Moving all strings out of widgets for localization. Effort: S (dark mode) / M-L (localization).

### Offline-tolerant drafts and optimistic UI with rollback
**What:** The app remains usable with a poor connection. Actions appear instantly and roll back with a message if the server rejects them.
**How:** Local queue of pending actions plus reconciliation on reconnect.
**Needs:** Local storage layer and conflict handling. Effort: L.

---

## 6. Effort and impact overview

| Feature | Audience | Effort | Impact in a demo |
|---|---|---|---|
| Quick-reply comment chips | Manager | S | High |
| Proof checklist per leave type | Employee | S | Medium |
| Team conflict warning | Manager | S-M | High |
| Live balance preview | Employee | M | High |
| Smart date picker | Employee | M | High |
| Realtime updates | System | M | High |
| Draft autosave | Employee | S-M | Medium |
| Add to calendar | Employee | S-M | Medium |
| Swipe with Undo | Manager | M | Medium |
| Audit view | HR | M | Medium |
| Request more information | Manager | L | High |
| Team calendar view | Manager | L | High |
| Cancellation of approved leave | Employee | L | Medium |
| Delegation / auto-escalation | Manager | L | Medium |
| Policy as data, reports, notifications | HR / System | L | Medium |

---

## 7. Suggested build order after the core app

1. Quick-reply chips (quickest win)
2. Smart date picker and working-day explanation
3. Live balance preview
4. Team conflict warning
5. Realtime updates (especially if using Supabase)
6. Anything else goes into the README as "Next steps"

Each of these features should keep the existing principles: business rules in pure, tested policy classes, data access behind the repository interface, and no personal content in logs.
