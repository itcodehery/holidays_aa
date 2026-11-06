# Interlude — Employee Leave Management System

A responsive Flutter application (**Interlude**, styled with Google Fonts' **BBH Sans Bogle** and **Plus Jakarta Sans**) where employees submit leave requests (with supporting proof documents) and managers/HR approve or reject them with comments. Consecutive leave requests exceeding **3 working days** automatically follow a two-stage approval workflow (**Manager → HR/Admin**).

For the complete technical specification, database schema, and execution plan, refer to [architecture.md](./architecture.md).

---

## Key Features

- **Role-Based Workflows (`employee`, `manager`, `hr`)**
  - **Employees:** Submit leave requests, attach supporting documents, track status & multi-stage approval timelines, and cancel pending requests.
  - **Managers:** View pending leave requests for direct reports, review proof attachments, and approve or reject with comments.
  - **HR / Admin:** Perform Stage 2 approvals for long leaves (> 3 working days) or manager self-leaves, and inspect full organization history.
- **Multi-Stage State Machine**
  - Short leaves (`≤ 3` working days): `pendingManager` → `approved` / `rejected`
  - Long leaves (`> 3` working days): `pendingManager` → `pendingHr` → `approved` / `rejected`
  - Manager self-requests bypass Stage 1 and route directly to `pendingHr`.
- **Proof Document Attachments**
  - Dynamic proof requirements based on leave type and duration (e.g., required for Marriage, Bereavement, and Sick leave > 2 working days).
  - Strict validation: `pdf`, `jpg`, `jpeg`, `png` only; max **5 MB** per file; max **5 files** per request.
  - Byte-based picking (`Uint8List`) for full Flutter Web & desktop/mobile compatibility.
- **Intentional Editorial Design System & Responsive UI**
  - Warm editorial aesthetic pairing deep obsidian summary headers (`#16171B`) and terracotta dotted-underline highlights (`#D95D39`) with a warm alabaster sheet canvas (`#EFECE4`), ivory cards (`#FAF8F3`), squircle icon containers, and accessible status badges.
  - `< 600px`: Bottom `NavigationBar`, single-column cards, full-screen forms, modal bottom sheets.
  - `600px – 1024px`: `NavigationRail`, 2-column card grid, modal dialogs.
  - `> 1024px`: Extended `NavigationRail` + master-detail split view.

---

## Explicit Assumptions

1. **Second Approver:** HR/Admin acts as the second-stage approver for multi-level approvals.
2. **Consecutive Leave Days:** Counted as **working days (Monday–Friday)** between start and end dates, inclusive (excluding configured public holidays). Controlled via `kMultiApprovalThreshold = 3`.
3. **Reporting Hierarchy:** Each employee has a single `manager_id`. Managers can only view and decide requests from their direct reports and cannot approve their own requests.
4. **Cancellations:** Employees can cancel a request only while it is still in a `pending_*` state.
5. **Immutable Attachments:** Supporting documents are attached at submission time and are immutable afterwards so evidence cannot be altered post-submission.
6. **Rejection Comments:** A comment is **mandatory** when rejecting a request and optional when approving.

---

## Architecture & Repository Layout

The project follows a **feature-first, 3-layer clean architecture** (`presentation → domain → data`) powered by **Riverpod** (`AsyncNotifier`) and **go_router**, alongside a GitHub-ready `supabase/` directory for automated schema deployment.

```text
├─ supabase/
│  ├─ config.toml                                         # Supabase CLI & GitHub integration config
│  ├─ seed.sql                                            # Local / branch seed script
│  └─ migrations/
│     └─ 20261106080000_initial_leave_schema.sql          # Tables, RLS, Atomic RPCs, Storage Bucket
├─ lib/
│  ├─ main.dart
│  ├─ app.dart                                            # MaterialApp.router, Material 3 theme
│  ├─ core/
│  │  ├─ config/                                          # AppConfig & kMultiApprovalThreshold = 3
│  │  ├─ router/                                          # go_router + role-based redirect guards
│  │  ├─ theme/                                           # Editorial palette & accessible status tokens
│  │  ├─ utils/                                           # Date/working-day helpers, byte formatters
│  │  ├─ logging/                                         # setup_logging.dart, log_buffer.dart, observer
│  │  ├─ widgets/                                         # StatusChip, EditorialSummaryHeader, AdaptiveScaffold
│  │  └─ errors/                                          # AppException hierarchy & Failure mapping
│  └─ features/
│     ├─ auth/
│     │  ├─ data/                                         # AuthRepository (in-memory seeded + Supabase impl)
│     │  ├─ domain/                                       # AppUser model, Role enum
│     │  └─ presentation/                                 # LoginScreen (with Quick Demo Login), AuthController
│     └─ leave/
│        ├─ domain/                                       # LeaveRequest, LeaveApproval, Attachment,
│        │                                                # LeavePolicy (PURE), AttachmentPolicy (PURE)
│        ├─ data/                                         # LeaveRepository, InMemoryLeaveRepository,
│        │                                                # SupabaseLeaveRepository, LoggingLeaveRepository
│        └─ presentation/                                 # Employee & Manager/HR screens, timeline, widgets
└─ test/
   ├─ domain/                                             # leave_policy_test.dart, attachment_policy_test.dart
   ├─ data/                                               # in_memory_repository_test.dart, logging_repository_test.dart
   ├─ state/                                              # leave_actions_controller_test.dart
   └─ widget/                                             # apply_leave_screen_test.dart, status_chip_test.dart
```

### Core Architectural Decisions

- **Pure Domain Policies (`LeavePolicy` & `AttachmentPolicy`):** All business rules—working-day calculation, 3-day threshold check, state machine transitions, date overlap detection, and attachment validation—are pure Dart classes with zero Flutter or database dependencies.
- **Swappable Repository Pattern:** The UI and controllers depend strictly on `LeaveRepository`. By default, the app runs out-of-the-box with a seeded `InMemoryLeaveRepository` wrapped in `LoggingLeaveRepository`. Passing `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` automatically switches the providers to `SupabaseAuthRepository` and `SupabaseLeaveRepository`.
- **Supabase GitHub Integration & Server-Enforced Integrity:** Pushing changes in `supabase/migrations/` to GitHub automatically deploys the database schema, Row-Level Security (RLS) policies, private storage bucket (`leave-attachments`), explicit Data API `GRANT`s, and atomic Postgres RPCs (`submit_leave`, `decide_leave`, `cancel_leave`). Direct client `UPDATE`s on `leave_requests` and `leave_attachments` are blocked by RLS.
- **Privacy-First Structured Logging:** Uses the `logging` package across three layers (`main.dart` global error hooks + 200-line `LogBuffer`, `LoggingLeaveRepository` decorator with stopwatch timings, and Riverpod `LoggingObserver`). Logs record IDs, operations, and durations—**never** personal content, reasons, comments, filenames, or emails. The `leave_approvals` table serves as the persistent business audit trail.
- **Known Limitation & Next Step:** If a file upload succeeds in Supabase mode but the subsequent RPC transaction fails, orphaned files may remain in the storage bucket; a scheduled storage cleanup job is the intended production mitigation.

---

## Getting Started

### 1. Run in Seeded In-Memory Mode (Zero Config)
```bash
flutter pub get
flutter run
```
Use the **Quick Demo Accounts** on the login screen (or the top-right persona switcher in the app bar) to switch instantaneously between **Employee**, **Manager**, and **HR / Admin**.

### 2. Run with Supabase (GitHub Schema Sync)
1. Link this repository in your Supabase project under **GitHub Integration** (Supabase automatically applies `supabase/migrations/20261106080000_initial_leave_schema.sql`).
2. Launch Flutter with your project's URL and publishable/anon key:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

### 3. Run Tests & Static Analysis
```bash
flutter analyze
flutter test
```
