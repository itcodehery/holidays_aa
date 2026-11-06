# Employee Leave Management System: Flutter Architecture

A responsive Flutter app where employees submit leave requests (with supporting documents) and managers/HR approve or reject them with comments. Requests longer than 3 working days require two-stage approval: Manager, then HR/Admin.

**Scope of this document:** requirements, workflow, data model, app architecture, screens, responsive design, validation, attachments, logging, tests, and the execution plan. Extra feature ideas are intentionally excluded and will live in a separate document.

---

## Table of Contents

1. [Backend decision: is Supabase overkill?](#1-backend-decision-is-supabase-overkill)
2. [Requirements and assumptions](#2-requirements-and-assumptions)
3. [Approval workflow](#3-approval-workflow)
4. [Data model](#4-data-model-postgressupabase)
5. [Attachments (proof documents)](#5-attachments-proof-documents)
6. [App architecture](#6-app-architecture)
7. [Screens and flows](#7-screens-and-flows)
8. [Responsive design](#8-responsive-design)
9. [Validation matrix](#9-validation-matrix)
10. [Logging](#10-logging)
11. [Testing](#11-testing)
12. [UX and robustness checklist](#12-ux-and-robustness-checklist)
13. [Packages](#13-packages)
14. [Three-hour execution plan](#14-three-hour-execution-plan)
15. [README and interview talking points](#15-readme-and-interview-talking-points)

---

## 1. Backend decision: is Supabase overkill?

**Not if you have used it before. Yes if you would be learning it during the interview.**

| | Supabase | In-memory + repository pattern |
|---|---|---|
| Setup cost | ~20-30 min (project, tables, auth, RLS, storage, keys) | ~5 min |
| Impresses reviewers | Real auth, roles, RLS, atomic approvals | Clean architecture, but "it's fake data" |
| Risk | Reviewer must configure your keys, network flakiness, debugging time | Almost none |
| Fit for the problem | Very good: relational data, roles, approval trail, file storage | Adequate |

**Recommendation (decided):** put every data call behind a `LeaveRepository` interface.

1. Build against `InMemoryLeaveRepository` first, so a working app exists within the first hour.
2. Add `SupabaseLeaveRepository` afterwards and swap it in with a single Riverpod override.

- **If you know Supabase:** it wins. Postgres with RLS, a private storage bucket, and RPC functions for approvals show real backend maturity.
- **If you don't:** ship the in-memory version and describe the Supabase swap in the README. That is a perfectly good interview answer.
- **Avoid Firestore.** The approval trail is relational, and security rules plus queries are more painful for this shape of data.

---

## 2. Requirements and assumptions

### Functional requirements

**Employees can:**
- Submit leave requests (with supporting documents where required)
- View their submitted requests
- Check request status and the approval timeline

**Managers can:**
- View all pending requests from their direct reports
- Approve requests
- Reject requests
- Add comments while approving or rejecting

**HR/Admin can:**
- Do everything a manager can, for requests at the HR stage
- View all requests for history

**Additional validation:**
- If consecutive leave exceeds 3 days, the system prompts the employee and follows a **multi-level approval process: one approval from the Manager and one from HR/Admin.**
- Employees must be able to upload a **document attachment as proof** (for example medical bills or a wedding invitation).

### Assumptions to state explicitly (also put in the README)

- **Second approver is HR/Admin** (confirmed).
- **Consecutive leave days** are counted as **working days (Mon-Fri)** between start and end, inclusive. The constant `kMultiApprovalThreshold = 3` makes this easy to change. More than 3 working days triggers two-stage approval.
- **Roles:** `employee`, `manager`, `hr`. HR is only involved in long leaves (or when a manager applies for their own leave).
- Each employee has one `manager_id`. A manager only sees their direct reports' requests.
- An employee can cancel only while the request is still pending.
- Attachments can only be added at submission time and are immutable afterwards.

---

## 3. Approval workflow

```
 Employee submits
        │
        ▼
 days <= 3 ? ──yes──► PENDING_MANAGER ──approve──► APPROVED
        │                    │
        no                   └──reject──► REJECTED
        ▼
 PENDING_MANAGER ──approve──► PENDING_HR ──approve──► APPROVED
        │                         │
        └──reject──► REJECTED     └──reject──► REJECTED

 Employee may CANCEL while in any PENDING_* state.
```

Status enum: `pendingManager`, `pendingHr`, `approved`, `rejected`, `cancelled`.

**Rules**

- A rejection at any stage is final. A comment is **mandatory on rejection** and optional on approval.
- Every decision is stored as a row in the approvals table. This drives the UI timeline and acts as the audit trail.
- A manager cannot approve their own request. If a manager applies for leave, it routes straight to HR.
- Finalised requests (`approved`, `rejected`, `cancelled`) cannot be decided again.
- The workflow is a small state machine, so adding a third approval level is a configuration change rather than a rewrite.

---

## 4. Data model (Postgres/Supabase)

```sql
create type user_role as enum ('employee', 'manager', 'hr');
create type leave_status as enum
  ('pending_manager', 'pending_hr', 'approved', 'rejected', 'cancelled');
create type leave_type as enum
  ('annual', 'sick', 'casual', 'unpaid', 'marriage', 'bereavement');

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null,
  role user_role not null default 'employee',
  manager_id uuid references profiles(id)
);

create table leave_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references profiles(id),
  leave_type leave_type not null,
  start_date date not null,
  end_date date not null,
  total_days int not null,
  reason text not null,
  status leave_status not null,
  requires_second_approval boolean not null default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  check (end_date >= start_date)
);

create table leave_approvals (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references leave_requests(id) on delete cascade,
  approver_id uuid not null references profiles(id),
  stage smallint not null,            -- 1 = manager, 2 = HR
  decision text not null check (decision in ('approved','rejected')),
  comment text,
  decided_at timestamptz default now(),
  unique (request_id, stage)          -- prevents double-deciding a stage
);

create table leave_attachments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references leave_requests(id) on delete cascade,
  file_name text not null,
  storage_path text not null,
  mime_type text not null,
  size_bytes int not null check (size_bytes <= 5242880),
  uploaded_at timestamptz default now()
);
```

### Atomic RPC functions

Business-critical transitions run server-side in a single transaction, which avoids race conditions and keeps rules out of the client.

**`decide_leave(request_id, decision, comment)`**
1. Verify the caller's role matches the current stage (manager for `pending_manager`, HR for `pending_hr`).
2. Verify the caller is not the request's owner.
3. Verify the request is not finalised.
4. Require a comment when rejecting.
5. Insert the approval row.
6. Advance or finalise the status.

**`submit_leave(...)`**
1. Compute and verify working days, initial status, and overlap with existing pending/approved requests.
2. Verify required proof is present (count of attachments).
3. Insert the request and its `leave_attachments` rows together.

### RLS summary

- Employees `select` and `insert` only their own requests.
- Managers `select` requests where the employee's `manager_id = auth.uid()`.
- HR `select`s requests in `pending_hr`, plus all requests for history.
- **No direct `update` on `leave_requests` from the client.** Status changes go only through the RPC.
- No `update` or `delete` on `leave_attachments` (immutable after submit).

---

## 5. Attachments (proof documents)

### Rules

- Allowed types: `pdf`, `jpg`, `jpeg`, `png`.
- Max **5 MB per file**, max **5 files per request**.
- Attachments are added only at submission and are frozen afterwards, so evidence cannot be swapped after approval.
- Use `FilePicker` with `withData: true` and hold **bytes, not file paths**, so it works on Flutter web.

**Proof requirement depends on leave type and duration:**

| Leave type | Proof |
|---|---|
| Sick, ≤ 2 days | Optional |
| Sick, > 2 days | **Required** (medical certificate or bills) |
| Marriage / Bereavement | **Required** (invitation or death certificate) |
| Annual / Casual / Unpaid | None |

### Domain models

```dart
enum ProofRequirement { none, optional, required }

class PickedAttachment {
  final String name;
  final Uint8List bytes;
  final String mimeType;
  int get sizeBytes => bytes.lengthInBytes;
  const PickedAttachment(this.name, this.bytes, this.mimeType);
}

class Attachment {            // already-uploaded metadata
  final String id, requestId, fileName, storagePath, mimeType;
  final int sizeBytes;
  // constructor, fromJson, toJson omitted
}
```

### Pure validator (testable, no Flutter dependency)

```dart
class AttachmentPolicy {
  static const maxFiles = 5;
  static const maxBytes = 5 * 1024 * 1024;
  static const allowedExt = {'pdf', 'jpg', 'jpeg', 'png'};

  static ProofRequirement proofRequirement(LeaveType type, int workingDays) {
    switch (type) {
      case LeaveType.marriage:
      case LeaveType.bereavement:
        return ProofRequirement.required;
      case LeaveType.sick:
        return workingDays > 2 ? ProofRequirement.required : ProofRequirement.optional;
      default:
        return ProofRequirement.none;
    }
  }

  /// Returns null if OK, otherwise a user-facing error.
  static String? validateFile(PickedAttachment f) {
    final ext = f.name.split('.').last.toLowerCase();
    if (!allowedExt.contains(ext)) return 'Only PDF, JPG or PNG files are allowed.';
    if (f.sizeBytes > maxBytes) return '${f.name} is larger than 5 MB.';
    return null;
  }

  static String? validateSet(List<PickedAttachment> files, ProofRequirement req) {
    if (files.length > maxFiles) return 'You can attach up to $maxFiles files.';
    if (req == ProofRequirement.required && files.isEmpty) {
      return 'Supporting documents are required for this leave.';
    }
    for (final f in files) {
      final err = validateFile(f);
      if (err != null) return err;
    }
    return null;
  }
}
```

### Repository interface

```dart
abstract class LeaveRepository {
  Future<List<LeaveRequest>> getMyRequests(String userId);
  Future<List<LeaveRequest>> getPendingFor(AppUser approver);
  Future<LeaveRequest> submit(NewLeaveRequest req, List<PickedAttachment> files);
  Future<LeaveRequest> decide(String id, Decision d, String? comment);
  Future<void> cancel(String id);
  Future<Uri> getAttachmentUrl(Attachment a);   // short-lived signed URL
}
```

The UI never knows about storage. `submit` receives the files and the repository handles the upload.

### Submit sequence (Supabase)

1. The client generates the request `id` (UUID).
2. It uploads each file to `leave-attachments/{employeeId}/{requestId}/{uuid}_{name}`.
3. It inserts the request, then the `leave_attachments` rows, ideally in one RPC (`submit_leave`).
4. **If an upload fails, nothing is inserted.** The user sees "Upload failed, retry", and no half-submitted request exists. Orphaned files are acceptable and can be mentioned in the README, with a cleanup job as a next step.

`InMemoryLeaveRepository` keeps a `Map<String, Uint8List>` and follows the same sequence, so behavior matches.

### Storage SQL

```sql
insert into storage.buckets (id, name, public)
values ('leave-attachments', 'leave-attachments', false);

-- Owner can upload/read inside their own folder
create policy "owner upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'leave-attachments'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy "owner read" on storage.objects for select to authenticated
  using (bucket_id = 'leave-attachments'
         and (storage.foldername(name))[1] = auth.uid()::text);

-- Approvers: the employee's manager, or any HR user
create policy "approver read" on storage.objects for select to authenticated
  using (bucket_id = 'leave-attachments' and exists (
    select 1 from profiles emp
    where emp.id::text = (storage.foldername(name))[1]
      and (emp.manager_id = auth.uid()
           or exists (select 1 from profiles me where me.id = auth.uid() and me.role = 'hr'))
  ));
```

### Attachment UX

- **Apply form:** an "Attach documents" section with a dynamic helper line from `proofRequirement` (*"Required: attach a medical certificate"* or *"Optional: attach proof"*). Each picked file shows as a removable chip with name, size, and type icon. A file that fails validation is rejected immediately with a SnackBar.
- **Submit button:** disabled with a progress indicator while uploading ("Uploading 2/3…").
- **Detail and review screens:** an attachment list. Images open in an in-app preview using the signed URL. PDFs open via `url_launcher`.
- **Privacy:** medical documents are sensitive. Use a private bucket and signed URLs that expire in about 60 seconds, and never log file names. A good README note: *"Option: restrict sick-leave attachments to HR only."*

---

## 6. App architecture

**Feature-first, three layers per feature:** presentation → domain → data.
State management: **Riverpod** (`AsyncNotifier`). Navigation: **go_router**.

```
lib/
├─ main.dart
├─ app.dart                      # MaterialApp.router, theme
├─ core/
│  ├─ config/                    # env, constants (kMultiApprovalThreshold)
│  ├─ router/                    # go_router + role-based redirect
│  ├─ theme/                     # Material 3 theme, status colors
│  ├─ utils/                     # date/working-day helpers, validators
│  ├─ logging/                   # setup_logging.dart, log_buffer.dart, logging_observer.dart
│  ├─ widgets/                   # StatusChip, EmptyState, ErrorView, AdaptiveScaffold
│  └─ errors/                    # AppException, Failure mapping
├─ features/
│  ├─ auth/
│  │  ├─ data/ (auth_repository, supabase impl + fake)
│  │  ├─ domain/ (app_user.dart, role enum)
│  │  └─ presentation/ (login_screen, auth_controller)
│  └─ leave/
│     ├─ domain/
│     │  ├─ leave_request.dart
│     │  ├─ leave_approval.dart
│     │  ├─ leave_status.dart
│     │  ├─ attachment.dart
│     │  ├─ attachment_policy.dart   # PURE: file + proof validation
│     │  └─ leave_policy.dart        # PURE: day count, approval rule, overlap, state machine
│     ├─ data/
│     │  ├─ leave_repository.dart               # abstract interface
│     │  ├─ in_memory_leave_repository.dart
│     │  ├─ supabase_leave_repository.dart
│     │  └─ logging_leave_repository.dart       # decorator
│     └─ presentation/
│        ├─ employee/ (my_requests_screen, apply_leave_screen, request_detail_screen)
│        ├─ manager/  (pending_requests_screen, review_sheet)
│        └─ widgets/  (leave_card, approval_timeline, date_range_field,
│                      attachment_picker, attachment_tile, attachment_viewer)
test/
├─ domain/   leave_policy_test.dart, attachment_policy_test.dart
├─ data/     in_memory_repository_test.dart, logging_repository_test.dart
├─ state/    leave_actions_controller_test.dart
└─ widget/   apply_leave_screen_test.dart, status_chip_test.dart
```

### Key design decisions

- **`LeavePolicy` and `AttachmentPolicy` are pure Dart.** `LeavePolicy` contains `countWorkingDays`, `requiresSecondApproval`, `initialStatus`, `nextStatus`, and `hasOverlap`. They are trivial to unit test, and you can say "all business rules are isolated from Flutter and the DB."
- **Repository pattern.** The UI depends only on `LeaveRepository`. The concrete implementation (in-memory or Supabase, wrapped in the logging decorator) is chosen in one provider.
- **Models:** plain immutable Dart classes with `fromJson` / `copyWith`. Skip `freezed` and `build_runner`, since codegen overhead is not worth it in 3 hours.
- **Providers:** `authControllerProvider`, `leaveRepositoryProvider`, `myRequestsProvider`, `pendingRequestsProvider`, `leaveActionsProvider` (submit / decide / cancel). Invalidate list providers after each mutation.
- **Error handling:** repository exceptions map to a small `AppException` hierarchy with user-friendly messages. The UI never shows raw Postgres errors.

---

## 7. Screens and flows

### Auth
Email and password login. For the demo, add **three seeded demo accounts** (employee, manager, HR) with "Quick login" buttons. This helps the reviewer a lot.

### Employee

1. **My Requests:** list with filter chips (All / Pending / Approved / Rejected), status chip, date range, day count, pull-to-refresh.
2. **Apply Leave:**
   - leave type dropdown
   - date range picker with a live "Working days: N" indicator
   - reason field
   - attachment picker with the dynamic proof requirement helper
   - info banner when N > 3: *"This request needs approval from your manager and HR."*
3. **Request Detail:** all fields, attachments, and an **approval timeline** (Submitted → Manager ✓ "Enjoy!" → HR pending). A Cancel button is shown while pending.

### Manager and HR

1. **Pending Requests:** the queue, with a badge showing which stage you are approving (Stage 1 or Stage 2).
2. **Review sheet / dialog:** request details, employee name, attachments, a comment field, and Approve / Reject buttons. Reject requires a comment. Include a confirmation step and a loading state to prevent double-taps.
3. **History tab (stretch):** requests this approver has already decided.

### Navigation

After login, go_router redirects by role. Employees get "My Requests" and "Apply". Managers and HR get "Pending" and "History". The router redirect guard also blocks cross-role URLs.

---

## 8. Responsive design

Use one `AdaptiveScaffold` with breakpoints:

| Width | Layout |
|---|---|
| < 600 | `NavigationBar` (bottom), single-column cards, full-screen forms, bottom sheets for review |
| 600-1024 | `NavigationRail`, 2-column card grid, dialogs instead of bottom sheets |
| > 1024 | Rail + **master-detail** (list left, details/review right), max content width ~1100 |

Implementation notes:

- Use `LayoutBuilder` or `MediaQuery.sizeOf`, not device checks.
- Wrap form pages in `ConstrainedBox(maxWidth: 560)` and center them.
- Test in Chrome at three widths. Flutter web is the easiest way to demo responsiveness to a reviewer.

---

## 9. Validation matrix

Implement in `LeavePolicy` / `AttachmentPolicy` and the form, and enforce critical rules in the DB or RPC as well.

| Rule | Where |
|---|---|
| Start and end dates required, end ≥ start | Form + DB check |
| Start date not in the past (allow today) | Form |
| Reason required, 10+ chars | Form |
| Count working days only; 0 working days (weekend only) is rejected | Policy |
| **> 3 working days → two-stage approval** | Policy (initial status) + RPC (progression) |
| No overlap with the employee's own pending/approved requests | Policy + RPC |
| Rejection requires a comment | UI + RPC |
| Only the correct role/stage can decide | RPC + RLS |
| Can't decide an already-finalised request | RPC (status guard) |
| Can't approve your own request | RPC |
| Proof required by leave type/duration | `AttachmentPolicy` + form + RPC (attachment count) |
| File type (pdf/jpg/png), size ≤ 5 MB, ≤ 5 files | `AttachmentPolicy` + DB check + bucket policy |
| Attachments immutable after submit | RLS (no update/delete on `leave_attachments`) |
| Only owner, manager, or HR can read a file | Storage RLS + signed URLs |

---

## 10. Logging

Use the `logging` package. Three small layers.

### a) Setup in `main.dart`

```dart
void setupLogging() {
  Logger.root.level = kReleaseMode ? Level.INFO : Level.ALL;
  Logger.root.onRecord.listen((r) {
    final line = '${r.time.toIso8601String()} [${r.level.name}] ${r.loggerName}: ${r.message}'
        '${r.error != null ? ' | ${r.error}' : ''}';
    debugPrint(line);
    LogBuffer.instance.add(line);          // ring buffer, last 200 lines
  });
}

void main() {
  setupLogging();
  FlutterError.onError = (d) =>
      Logger('Flutter').severe('Framework error', d.exception, d.stack);
  PlatformDispatcher.instance.onError = (e, s) {
    Logger('Platform').severe('Uncaught error', e, s);
    return true;
  };
  runApp(const ProviderScope(observers: [LoggingObserver()], child: App()));
}
```

### b) Repository decorator: logs every call without touching implementations

```dart
class LoggingLeaveRepository implements LeaveRepository {
  LoggingLeaveRepository(this._inner);
  final LeaveRepository _inner;
  final _log = Logger('LeaveRepository');

  Future<T> _run<T>(String op, Future<T> Function() fn) async {
    final sw = Stopwatch()..start();
    _log.fine('$op started');
    try {
      final r = await fn();
      _log.info('$op ok (${sw.elapsedMilliseconds}ms)');
      return r;
    } catch (e, s) {
      _log.severe('$op failed (${sw.elapsedMilliseconds}ms)', e, s);
      rethrow;
    }
  }

  @override
  Future<LeaveRequest> decide(String id, Decision d, String? c) =>
      _run('decide(id=$id, ${d.name})', () => _inner.decide(id, d, c));
  // ...same one-liner for the other methods
}
```

Wire it in the provider as `LoggingLeaveRepository(InMemoryLeaveRepository())`. Swapping in Supabase later is still one line.

### c) Riverpod observer

```dart
class LoggingObserver extends ProviderObserver {
  const LoggingObserver();
  @override
  void providerDidFail(ProviderBase p, Object e, StackTrace s, ProviderContainer c) =>
      Logger('Provider').warning('${p.name ?? p.runtimeType} failed', e, s);
}
```

### Logging rules

- **Log IDs and actions, never content.** No reason text, comments, file names, emails, or tokens.
- **Levels:** `FINE` for lifecycle and navigation, `INFO` for business events (submitted, approved, rejected, cancelled), `WARNING` for validation or recoverable failures, `SEVERE` for unexpected exceptions.
- **App log vs audit log:** the `leave_approvals` table is the persisted audit trail (who decided what and when). Client logs are for debugging only.
- **Stretch:** a hidden "Debug logs" screen showing `LogBuffer` with a copy button.
- **Production path:** forward `SEVERE` records to Sentry or Crashlytics.

---

## 11. Testing

**Pyramid:** many fast pure-Dart tests (policies), a medium number of repository and controller tests, and a few widget tests. Aim for roughly 30-40 meaningful cases.

Test dates below assume Monday 9 Nov 2026.

### `LeavePolicy` (the most important file)

```dart
void main() {
  group('countWorkingDays', () {
    test('single weekday = 1', () {
      expect(LeavePolicy.countWorkingDays(DateTime(2026, 11, 9), DateTime(2026, 11, 9)), 1);
    });
    test('Mon-Fri = 5', () {
      expect(LeavePolicy.countWorkingDays(DateTime(2026, 11, 9), DateTime(2026, 11, 13)), 5);
    });
    test('weekend only = 0', () {
      expect(LeavePolicy.countWorkingDays(DateTime(2026, 11, 7), DateTime(2026, 11, 8)), 0);
    });
    test('Fri to Mon skips the weekend = 2', () {
      expect(LeavePolicy.countWorkingDays(DateTime(2026, 11, 6), DateTime(2026, 11, 9)), 2);
    });
    test('holidays are excluded', () {
      final h = {DateTime(2026, 11, 10)};
      expect(LeavePolicy.countWorkingDays(DateTime(2026, 11, 9), DateTime(2026, 11, 11), holidays: h), 2);
    });
  });

  group('approval rule (boundary)', () {
    test('3 days -> single approval', () => expect(LeavePolicy.requiresSecondApproval(3), false));
    test('4 days -> two-stage',       () => expect(LeavePolicy.requiresSecondApproval(4), true));
  });

  group('initialStatus', () {
    test('employee short leave -> pendingManager', () {
      expect(LeavePolicy.initialStatus(Role.employee, 2), LeaveStatus.pendingManager);
    });
    test('manager own leave routes straight to HR', () {
      expect(LeavePolicy.initialStatus(Role.manager, 2), LeaveStatus.pendingHr);
    });
  });

  group('nextStatus (state machine)', () {
    test('manager approves long leave -> pendingHr', () {
      expect(LeavePolicy.nextStatus(LeaveStatus.pendingManager, Decision.approve, true),
          LeaveStatus.pendingHr);
    });
    test('manager approves short leave -> approved', () {
      expect(LeavePolicy.nextStatus(LeaveStatus.pendingManager, Decision.approve, false),
          LeaveStatus.approved);
    });
    test('HR approves -> approved', () {
      expect(LeavePolicy.nextStatus(LeaveStatus.pendingHr, Decision.approve, true),
          LeaveStatus.approved);
    });
    test('reject at any stage -> rejected', () {
      for (final s in [LeaveStatus.pendingManager, LeaveStatus.pendingHr]) {
        expect(LeavePolicy.nextStatus(s, Decision.reject, true), LeaveStatus.rejected);
      }
    });
    test('finalised requests cannot be decided', () {
      for (final s in [LeaveStatus.approved, LeaveStatus.rejected, LeaveStatus.cancelled]) {
        expect(() => LeavePolicy.nextStatus(s, Decision.approve, false), throwsStateError);
      }
    });
  });

  group('overlap', () {
    final existing = [req(DateTime(2026, 11, 10), DateTime(2026, 11, 12), LeaveStatus.approved)];
    test('overlapping range detected', () {
      expect(LeavePolicy.hasOverlap(DateTime(2026, 11, 12), DateTime(2026, 11, 14), existing), true);
    });
    test('adjacent range is fine', () {
      expect(LeavePolicy.hasOverlap(DateTime(2026, 11, 13), DateTime(2026, 11, 14), existing), false);
    });
    test('rejected/cancelled requests are ignored', () {
      final dead = [req(DateTime(2026, 11, 10), DateTime(2026, 11, 12), LeaveStatus.rejected)];
      expect(LeavePolicy.hasOverlap(DateTime(2026, 11, 10), DateTime(2026, 11, 11), dead), false);
    });
  });
}
```

### `AttachmentPolicy`

```dart
group('proofRequirement', () {
  test('sick 2 days optional', () => expect(AttachmentPolicy.proofRequirement(LeaveType.sick, 2), ProofRequirement.optional));
  test('sick 3 days required', () => expect(AttachmentPolicy.proofRequirement(LeaveType.sick, 3), ProofRequirement.required));
  test('marriage always required', () => expect(AttachmentPolicy.proofRequirement(LeaveType.marriage, 1), ProofRequirement.required));
});
group('validateFile', () {
  test('rejects .exe', () => expect(AttachmentPolicy.validateFile(file('a.exe', 10)), isNotNull));
  test('rejects > 5MB', () => expect(AttachmentPolicy.validateFile(file('a.pdf', 5 * 1024 * 1024 + 1)), isNotNull));
  test('accepts 1MB pdf', () => expect(AttachmentPolicy.validateFile(file('a.pdf', 1024 * 1024)), isNull));
  test('required proof with zero files fails', () =>
      expect(AttachmentPolicy.validateSet([], ProofRequirement.required), isNotNull));
  test('more than 5 files fails', () =>
      expect(AttachmentPolicy.validateSet(List.generate(6, (_) => file('a.pdf', 10)), ProofRequirement.optional), isNotNull));
});
```

### Repository tests (full workflow without any UI)

```dart
test('long leave goes manager -> HR -> approved, and records both approvals', () async {
  final repo = InMemoryLeaveRepository.seeded();
  final r = await repo.submit(newRequest(days: 5), []);
  expect(r.status, LeaveStatus.pendingManager);

  final afterMgr = await repo.decide(r.id, Decision.approve, 'Enjoy');   // acting as manager
  expect(afterMgr.status, LeaveStatus.pendingHr);

  repo.actAs(hrUser);
  final done = await repo.decide(r.id, Decision.approve, null);
  expect(done.status, LeaveStatus.approved);
  expect(done.approvals.length, 2);
});

test('rejecting without a comment throws', () async { /* expect throwsA(isA<ValidationException>()) */ });
test('manager cannot approve own request', () async { /* ... */ });
test('submit fails when proof is required and missing', () async { /* ... */ });
test('cancel only allowed while pending', () async { /* ... */ });
```

### Controller test with overrides (mocktail)

```dart
test('submit failure surfaces AsyncError and does not invalidate list', () async {
  final mock = MockLeaveRepository();
  when(() => mock.submit(any(), any())).thenThrow(AppException('Upload failed'));
  final c = ProviderContainer(overrides: [leaveRepositoryProvider.overrideWithValue(mock)]);
  addTearDown(c.dispose);

  await c.read(leaveActionsProvider.notifier).submit(newRequest(days: 1), []);
  expect(c.read(leaveActionsProvider).hasError, true);
});
```

### Logging decorator test

```dart
test('logs severe on failure and rethrows', () async {
  final records = <LogRecord>[];
  Logger.root.level = Level.ALL;
  final sub = Logger.root.onRecord.listen(records.add);
  addTearDown(sub.cancel);

  final repo = LoggingLeaveRepository(FailingRepository());
  await expectLater(repo.cancel('x'), throwsException);
  expect(records.any((r) => r.level == Level.SEVERE), true);
});
```

### Widget tests (2-3 only)

- The Apply screen shows the "needs manager and HR approval" banner when the picked range is more than 3 working days.
- The Submit button is disabled and a validation message appears when proof is required and no file is attached.
- `StatusChip` renders an icon and a label for every status (accessibility).

---

## 12. UX and robustness checklist

- **Every async screen** handles loading (skeleton/spinner), error (retry button), and empty states.
- **No optimistic UI needed.** Disable buttons while submitting and show a SnackBar on success or failure.
- **Dates** formatted with `intl` (`dd MMM yyyy`) and stored as date-only values to avoid timezone bugs.
- **Status colors** centralised in the theme (amber pending-manager, blue pending-HR, green approved, red rejected, grey cancelled). Never rely on color alone: always pair with an icon and a label.
- **Error mapping:** Supabase/Postgres exceptions map to friendly `AppException` messages.
- **Secrets:** Supabase URL and anon key via `--dart-define` or a `.env` file. Never commit a service key.
- **Accessibility:** semantic labels on chips and buttons, 48px tap targets, light and dark theme via Material 3 `ColorScheme.fromSeed`.
- **Double-submit protection** on submit, approve, and reject actions.

---

## 13. Packages

Keep the list lean (8 total):

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management and dependency injection |
| `go_router` | Navigation and role-based redirects |
| `intl` | Date formatting |
| `file_picker` | Attachment selection (bytes, web-compatible) |
| `url_launcher` | Opening PDF attachments |
| `logging` | Structured logging |
| `supabase_flutter` | Backend (only if used) |
| `mocktail` (+ `flutter_test`) | Testing |

---

## 14. Three-hour execution plan

| Time | Goal |
|---|---|
| 0:00-0:15 | Setup, folders, theme, router skeleton, models, enums, `setupLogging()` |
| 0:15-0:45 | `LeavePolicy` + `AttachmentPolicy` + unit tests, in-memory repo, `LoggingLeaveRepository`, seed data |
| 0:45-1:15 | Fake auth + role-based routing |
| 1:15-2:05 | Employee flow: list, apply form with live validation, attachment picker, detail + timeline |
| 2:05-2:40 | Manager/HR flow: pending queue, review sheet with attachments and comments, two-stage progression, repository/controller tests |
| 2:40-2:52 | Responsive pass, empty/error states, 2 widget tests |
| 2:52-3:00 | README (assumptions, architecture, logging policy, how to run) |

If you are doing Supabase, carve out **30 minutes** for schema, RLS, storage policies, RPCs, and the repository. Start the in-memory version first so you always have something working.

**Cut order if time runs short:** History tab → master-detail layout → Supabase (stay in-memory) → extra leave types → cancel.

**Never cut:** the >3-day two-stage logic, comments, attachments with validation, logging setup, and the `LeavePolicy` / `AttachmentPolicy` tests.

---

## 15. README and interview talking points

- Business rules are isolated in pure, tested policies (`LeavePolicy`, `AttachmentPolicy`).
- The repository pattern makes the backend swappable with one provider override.
- Approval transitions are atomic and server-enforced (if Supabase), with the client never updating status directly.
- The workflow is a small state machine, so a third approval level is a config change.
- The `leave_approvals` table is the audit trail; client logs are for debugging and never contain personal content.
- Proof documents live in a private bucket with signed, short-lived URLs and are immutable after submission.
- Assumptions are stated explicitly (HR as second approver, working-day counting, 3-day threshold constant).
- Known limitation: orphaned uploads after a failed submit; a cleanup job is the natural fix.
