-- =============================================================================
-- Employee Leave Management System (Holidays)
-- Initial Schema, RLS Policies, Atomic RPCs, and Private Storage Bucket
-- Deployed automatically via Supabase GitHub Integration
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Enums
-- -----------------------------------------------------------------------------
do $$ begin
  create type public.user_role as enum ('employee', 'manager', 'hr');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type public.leave_status as enum (
    'pending_manager',
    'pending_hr',
    'approved',
    'rejected',
    'cancelled'
  );
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type public.leave_type as enum (
    'annual',
    'sick',
    'casual',
    'unpaid',
    'marriage',
    'bereavement'
  );
exception
  when duplicate_object then null;
end $$;

-- -----------------------------------------------------------------------------
-- 2. Tables
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role public.user_role not null default 'employee',
  manager_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.leave_requests (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles(id) on delete cascade,
  leave_type public.leave_type not null,
  start_date date not null,
  end_date date not null,
  total_days int not null check (total_days > 0),
  reason text not null check (char_length(btrim(reason)) >= 10),
  status public.leave_status not null default 'pending_manager',
  requires_second_approval boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint leave_requests_dates_check check (end_date >= start_date)
);

create index if not exists idx_leave_requests_employee_id
  on public.leave_requests(employee_id);
create index if not exists idx_leave_requests_status
  on public.leave_requests(status);

create table if not exists public.leave_approvals (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.leave_requests(id) on delete cascade,
  approver_id uuid not null references public.profiles(id) on delete restrict,
  stage smallint not null check (stage in (1, 2)), -- 1 = Manager, 2 = HR
  decision text not null check (decision in ('approved', 'rejected')),
  comment text,
  decided_at timestamptz not null default now(),
  unique (request_id, stage)
);

create index if not exists idx_leave_approvals_request_id
  on public.leave_approvals(request_id);

create table if not exists public.leave_attachments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.leave_requests(id) on delete cascade,
  file_name text not null,
  storage_path text not null,
  mime_type text not null,
  size_bytes int not null check (size_bytes > 0 and size_bytes <= 5242880),
  uploaded_at timestamptz not null default now()
);

create index if not exists idx_leave_attachments_request_id
  on public.leave_attachments(request_id);

-- -----------------------------------------------------------------------------
-- 3. Automatic Profile Provisioning Trigger on Auth Signup
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    'employee'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- -----------------------------------------------------------------------------
-- 4. Row-Level Security (RLS)
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.leave_requests enable row level security;
alter table public.leave_approvals enable row level security;
alter table public.leave_attachments enable row level security;

-- Profiles: authenticated users can read profiles to resolve names/hierarchy,
-- and update only their own profile name.
drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Leave Requests:
-- 1. Employees select their own requests
drop policy if exists "leave_requests_select_own" on public.leave_requests;
create policy "leave_requests_select_own"
  on public.leave_requests for select
  to authenticated
  using ((select auth.uid()) = employee_id);

-- 2. Managers select requests belonging to their direct reports
drop policy if exists "leave_requests_select_manager" on public.leave_requests;
create policy "leave_requests_select_manager"
  on public.leave_requests for select
  to authenticated
  using (
    exists (
      select 1 from public.profiles emp
      where emp.id = leave_requests.employee_id
        and emp.manager_id = (select auth.uid())
    )
  );

-- 3. HR selects all requests (pending_hr + full organization history)
drop policy if exists "leave_requests_select_hr" on public.leave_requests;
create policy "leave_requests_select_hr"
  on public.leave_requests for select
  to authenticated
  using (
    exists (
      select 1 from public.profiles me
      where me.id = (select auth.uid())
        and me.role = 'hr'
    )
  );

-- 4. Employees insert only their own requests (prefer RPC `submit_leave`)
drop policy if exists "leave_requests_insert_own" on public.leave_requests;
create policy "leave_requests_insert_own"
  on public.leave_requests for insert
  to authenticated
  with check ((select auth.uid()) = employee_id);

-- Note: No UPDATE or DELETE policy on `leave_requests` for clients.
-- All state transitions must go through `decide_leave` and `cancel_leave` RPCs.

-- Leave Approvals: readable by anyone who can read the parent leave_request
drop policy if exists "leave_approvals_select_visible" on public.leave_approvals;
create policy "leave_approvals_select_visible"
  on public.leave_approvals for select
  to authenticated
  using (
    exists (
      select 1 from public.leave_requests lr
      where lr.id = leave_approvals.request_id
    )
  );

-- Leave Attachments: readable by anyone who can read the parent leave_request,
-- immutable after insertion (no UPDATE or DELETE policy).
drop policy if exists "leave_attachments_select_visible" on public.leave_attachments;
create policy "leave_attachments_select_visible"
  on public.leave_attachments for select
  to authenticated
  using (
    exists (
      select 1 from public.leave_requests lr
      where lr.id = leave_attachments.request_id
    )
  );

drop policy if exists "leave_attachments_insert_owner" on public.leave_attachments;
create policy "leave_attachments_insert_owner"
  on public.leave_attachments for insert
  to authenticated
  with check (
    exists (
      select 1 from public.leave_requests lr
      where lr.id = leave_attachments.request_id
        and lr.employee_id = (select auth.uid())
    )
  );

-- -----------------------------------------------------------------------------
-- 5. Helper: Working Days Counter & JSON Serializer
-- -----------------------------------------------------------------------------
create or replace function public.count_working_days(
  p_start date,
  p_end date
)
returns int
language sql
immutable
as $$
  select count(*)::int
  from generate_series(p_start, p_end, interval '1 day') as d
  where extract(isodow from d) < 6;
$$;

create or replace function public.serialize_leave_request(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  select jsonb_build_object(
    'id', lr.id,
    'employee_id', lr.employee_id,
    'employee_name', emp.full_name,
    'manager_id', emp.manager_id,
    'leave_type', lr.leave_type,
    'start_date', lr.start_date,
    'end_date', lr.end_date,
    'total_days', lr.total_days,
    'reason', lr.reason,
    'status', lr.status,
    'requires_second_approval', lr.requires_second_approval,
    'created_at', lr.created_at,
    'updated_at', lr.updated_at,
    'leave_approvals', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', la.id,
          'request_id', la.request_id,
          'approver_id', la.approver_id,
          'approver_name', ap.full_name,
          'stage', la.stage,
          'decision', la.decision,
          'comment', la.comment,
          'decided_at', la.decided_at
        ) order by la.stage asc
      )
      from public.leave_approvals la
      left join public.profiles ap on ap.id = la.approver_id
      where la.request_id = lr.id
    ), '[]'::jsonb),
    'leave_attachments', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', att.id,
          'request_id', att.request_id,
          'file_name', att.file_name,
          'storage_path', att.storage_path,
          'mime_type', att.mime_type,
          'size_bytes', att.size_bytes,
          'uploaded_at', att.uploaded_at
        ) order by att.uploaded_at asc
      )
      from public.leave_attachments att
      where att.request_id = lr.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.leave_requests lr
  join public.profiles emp on emp.id = lr.employee_id
  where lr.id = p_request_id;

  return v_result;
end;
$$;

-- -----------------------------------------------------------------------------
-- 6. Atomic Business RPCs (`submit_leave`, `decide_leave`, `cancel_leave`)
-- -----------------------------------------------------------------------------
create or replace function public.submit_leave(
  p_id uuid default gen_random_uuid(),
  p_leave_type public.leave_type default 'annual',
  p_start_date date default current_date,
  p_end_date date default current_date,
  p_reason text default '',
  p_attachments jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_role public.user_role;
  v_working_days int;
  v_requires_second boolean;
  v_initial_status public.leave_status;
  v_att_count int := coalesce(jsonb_array_length(p_attachments), 0);
  v_att jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if v_role is null then
    raise exception 'User profile not found';
  end if;

  if p_end_date < p_start_date then
    raise exception 'End date cannot be before start date';
  end if;

  if char_length(btrim(p_reason)) < 10 then
    raise exception 'Reason must be at least 10 characters long';
  end if;

  v_working_days := public.count_working_days(p_start_date, p_end_date);
  if v_working_days <= 0 then
    raise exception 'Selected date range has 0 working days';
  end if;

  -- Check overlap with existing pending/approved requests
  if exists (
    select 1 from public.leave_requests lr
    where lr.employee_id = v_uid
      and lr.status in ('pending_manager', 'pending_hr', 'approved')
      and p_start_date <= lr.end_date
      and p_end_date >= lr.start_date
  ) then
    raise exception 'Leave dates overlap with an existing pending or approved request';
  end if;

  -- Proof validation
  if v_att_count > 5 then
    raise exception 'You can attach up to 5 files per request';
  end if;

  if (v_working_days > 3 or p_leave_type in ('marriage', 'bereavement') or (p_leave_type = 'sick' and v_working_days > 2))
     and v_att_count = 0 then
    raise exception 'Supporting documents are required for this leave';
  end if;

  v_requires_second := (v_working_days > 3);
  v_initial_status := case
    when v_role in ('manager', 'hr') then 'pending_hr'::public.leave_status
    else 'pending_manager'::public.leave_status
  end;

  insert into public.leave_requests (
    id,
    employee_id,
    leave_type,
    start_date,
    end_date,
    total_days,
    reason,
    status,
    requires_second_approval
  ) values (
    coalesce(p_id, gen_random_uuid()),
    v_uid,
    p_leave_type,
    p_start_date,
    p_end_date,
    v_working_days,
    btrim(p_reason),
    v_initial_status,
    v_requires_second
  )
  returning id into p_id;

  for v_att in select * from jsonb_array_elements(p_attachments)
  loop
    insert into public.leave_attachments (
      request_id,
      file_name,
      storage_path,
      mime_type,
      size_bytes
    ) values (
      p_id,
      v_att ->> 'file_name',
      v_att ->> 'storage_path',
      v_att ->> 'mime_type',
      (v_att ->> 'size_bytes')::int
    );
  end loop;

  return public.serialize_leave_request(p_id);
end;
$$;

create or replace function public.decide_leave(
  request_id uuid,
  decision text,
  comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_actor_role public.user_role;
  v_req public.leave_requests%rowtype;
  v_emp_manager_id uuid;
  v_stage smallint;
  v_next_status public.leave_status;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select role into v_actor_role from public.profiles where id = v_uid;

  select * into v_req
  from public.leave_requests
  where id = request_id
  for update;

  if not found then
    raise exception 'Leave request not found';
  end if;

  if v_req.employee_id = v_uid then
    raise exception 'You cannot approve or reject your own leave request';
  end if;

  if v_req.status not in ('pending_manager', 'pending_hr') then
    raise exception 'Finalised leave requests cannot be decided again';
  end if;

  if decision not in ('approved', 'rejected') then
    raise exception 'Invalid decision value';
  end if;

  if decision = 'rejected' and (comment is null or char_length(btrim(comment)) = 0) then
    raise exception 'A comment is required when rejecting a leave request';
  end if;

  select manager_id into v_emp_manager_id
  from public.profiles
  where id = v_req.employee_id;

  if v_req.status = 'pending_manager' then
    if v_actor_role != 'manager' or (v_emp_manager_id is not null and v_emp_manager_id != v_uid) then
      raise exception 'Only the employee''s direct manager can decide Stage 1';
    end if;
    v_stage := 1;
    v_next_status := case
      when decision = 'rejected' then 'rejected'::public.leave_status
      when v_req.requires_second_approval then 'pending_hr'::public.leave_status
      else 'approved'::public.leave_status
    end;
  elsif v_req.status = 'pending_hr' then
    if v_actor_role != 'hr' then
      raise exception 'Only HR/Admin can decide Stage 2 requests';
    end if;
    v_stage := 2;
    v_next_status := case
      when decision = 'rejected' then 'rejected'::public.leave_status
      else 'approved'::public.leave_status
    end;
  end if;

  insert into public.leave_approvals (
    request_id,
    approver_id,
    stage,
    decision,
    comment
  ) values (
    request_id,
    v_uid,
    v_stage,
    decision,
    nullif(btrim(coalesce(comment, '')), '')
  );

  update public.leave_requests
  set status = v_next_status,
      updated_at = now()
  where id = request_id;

  return public.serialize_leave_request(request_id);
end;
$$;

create or replace function public.cancel_leave(request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := (select auth.uid());
  v_req public.leave_requests%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select * into v_req
  from public.leave_requests
  where id = request_id
  for update;

  if not found then
    raise exception 'Leave request not found';
  end if;

  if v_req.employee_id != v_uid then
    raise exception 'Only the request owner can cancel a leave request';
  end if;

  if v_req.status not in ('pending_manager', 'pending_hr') then
    raise exception 'Only pending leave requests can be cancelled';
  end if;

  update public.leave_requests
  set status = 'cancelled',
      updated_at = now()
  where id = request_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- 7. Explicit Grants for Data API compatibility (when auto-expose is disabled)
-- -----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert on public.leave_requests to authenticated;
grant select on public.leave_approvals to authenticated;
grant select, insert on public.leave_attachments to authenticated;

revoke execute on function public.submit_leave(uuid, public.leave_type, date, date, text, jsonb) from public, anon;
grant execute on function public.submit_leave(uuid, public.leave_type, date, date, text, jsonb) to authenticated;

revoke execute on function public.decide_leave(uuid, text, text) from public, anon;
grant execute on function public.decide_leave(uuid, text, text) to authenticated;

revoke execute on function public.cancel_leave(uuid) from public, anon;
grant execute on function public.cancel_leave(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 8. Private Storage Bucket & Storage RLS (`leave-attachments`)
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'leave-attachments',
  'leave-attachments',
  false,
  5242880,
  array['application/pdf', 'image/jpeg', 'image/png']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "owner upload" on storage.objects;
create policy "owner upload"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'leave-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "owner read" on storage.objects;
create policy "owner read"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'leave-attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "approver read" on storage.objects;
create policy "approver read"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'leave-attachments'
    and exists (
      select 1 from public.profiles emp
      where emp.id::text = (storage.foldername(name))[1]
        and (
          emp.manager_id = (select auth.uid())
          or exists (
            select 1 from public.profiles me
            where me.id = (select auth.uid())
              and me.role = 'hr'
          )
        )
    )
  );
-- =============================================================================
-- Seed Demo Accounts, Hierarchy, and Initial Leave Requests for Holiday
-- =============================================================================
-- Creates the 4 demo personas in `auth.users` / `auth.identities` (password:
-- `demo1234`), configures their roles and reporting hierarchy in
-- `public.profiles`, and seeds realistic initial leave requests.
-- =============================================================================

create extension if not exists pgcrypto with schema extensions;

-- Helper RPC allowing demo personas to self-configure their role & manager
-- if signed up dynamically from the client.
create or replace function public.ensure_demo_profile(
  p_role public.user_role,
  p_full_name text,
  p_manager_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_uid uuid := (select auth.uid());
  v_mgr_id uuid;
  v_profile public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if p_manager_email is not null then
    select u.id into v_mgr_id
    from auth.users u
    where lower(u.email) = lower(p_manager_email)
    limit 1;
  end if;

  insert into public.profiles (id, full_name, role, manager_id)
  values (v_uid, p_full_name, p_role, v_mgr_id)
  on conflict (id) do update
    set full_name = excluded.full_name,
        role = excluded.role,
        manager_id = coalesce(excluded.manager_id, public.profiles.manager_id)
  returning * into v_profile;

  return jsonb_build_object(
    'id', v_profile.id,
    'full_name', v_profile.full_name,
    'role', v_profile.role,
    'manager_id', v_profile.manager_id
  );
end;
$$;

revoke execute on function public.ensure_demo_profile(public.user_role, text, text) from public, anon;
grant execute on function public.ensure_demo_profile(public.user_role, text, text) to authenticated;

do $$
declare
  v_mgr_id uuid := '00000000-0000-0000-0000-000000000001';
  v_hr_id  uuid := '00000000-0000-0000-0000-000000000002';
  v_emp1_id uuid := '00000000-0000-0000-0000-000000000003';
  v_emp2_id uuid := '00000000-0000-0000-0000-000000000004';
  v_pw_hash text := extensions.crypt('demo1234', extensions.gen_salt('bf'));
begin
  -- 1. Seed auth.users if not already present
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, confirmation_token, email_change,
    email_change_token_new, recovery_token
  )
  values
    (
      '00000000-0000-0000-0000-000000000000', v_mgr_id, 'authenticated', 'authenticated',
      'manager@company.com', v_pw_hash, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Priya Sharma (Manager)"}'::jsonb,
      now(), now(), '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000', v_hr_id, 'authenticated', 'authenticated',
      'hr@company.com', v_pw_hash, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Marcus Vance (HR Admin)"}'::jsonb,
      now(), now(), '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000', v_emp1_id, 'authenticated', 'authenticated',
      'alex@company.com', v_pw_hash, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Alex Rivera"}'::jsonb,
      now(), now(), '', '', '', ''
    ),
    (
      '00000000-0000-0000-0000-000000000000', v_emp2_id, 'authenticated', 'authenticated',
      'samira@company.com', v_pw_hash, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"Samira Patel"}'::jsonb,
      now(), now(), '', '', '', ''
    )
  on conflict (id) do nothing;

  -- 2. Seed auth.identities so email/password sign-in works across GoTrue versions
  insert into auth.identities (
    id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  )
  values
    (
      gen_random_uuid(), v_mgr_id, v_mgr_id::text,
      jsonb_build_object('sub', v_mgr_id::text, 'email', 'manager@company.com', 'email_verified', true),
      'email', now(), now(), now()
    ),
    (
      gen_random_uuid(), v_hr_id, v_hr_id::text,
      jsonb_build_object('sub', v_hr_id::text, 'email', 'hr@company.com', 'email_verified', true),
      'email', now(), now(), now()
    ),
    (
      gen_random_uuid(), v_emp1_id, v_emp1_id::text,
      jsonb_build_object('sub', v_emp1_id::text, 'email', 'alex@company.com', 'email_verified', true),
      'email', now(), now(), now()
    ),
    (
      gen_random_uuid(), v_emp2_id, v_emp2_id::text,
      jsonb_build_object('sub', v_emp2_id::text, 'email', 'samira@company.com', 'email_verified', true),
      'email', now(), now(), now()
    )
  on conflict do nothing;

  -- 3. Ensure public.profiles roles and manager_id hierarchy
  insert into public.profiles (id, full_name, role, manager_id)
  values
    (v_mgr_id,  'Priya Sharma (Manager)',  'manager',  null),
    (v_hr_id,   'Marcus Vance (HR Admin)', 'hr',       null),
    (v_emp1_id, 'Alex Rivera',             'employee', v_mgr_id),
    (v_emp2_id, 'Samira Patel',            'employee', v_mgr_id)
  on conflict (id) do update
    set full_name = excluded.full_name,
        role = excluded.role,
        manager_id = excluded.manager_id;

  -- 4. Seed sample leave requests if table is empty
  if not exists (select 1 from public.leave_requests limit 1) then
    -- Request 1: Short casual leave (2 days) - Pending Manager
    insert into public.leave_requests (
      id, employee_id, leave_type, start_date, end_date, total_days,
      reason, status, requires_second_approval, created_at, updated_at
    ) values (
      '10000000-0000-0000-0000-000000000001',
      v_emp1_id, 'casual', '2026-12-14', '2026-12-15', 2,
      'Attending a family event out of town for two days.',
      'pending_manager', false, now() - interval '2 days', now() - interval '2 days'
    );

    -- Request 2: Long sick leave (5 working days) - Approved by Manager, Pending HR
    insert into public.leave_requests (
      id, employee_id, leave_type, start_date, end_date, total_days,
      reason, status, requires_second_approval, created_at, updated_at
    ) values (
      '10000000-0000-0000-0000-000000000002',
      v_emp1_id, 'sick', '2026-10-19', '2026-10-23', 5,
      'Post-procedure recovery advised by physician for a full work week.',
      'pending_hr', true, now() - interval '10 days', now() - interval '9 days'
    );

    insert into public.leave_approvals (
      request_id, approver_id, stage, decision, comment, decided_at
    ) values (
      '10000000-0000-0000-0000-000000000002',
      v_mgr_id, 1, 'approved',
      'Wishing you a speedy recovery. Forwarding to HR.',
      now() - interval '9 days'
    );

    -- Request 3: Short annual leave (2 days) - Approved
    insert into public.leave_requests (
      id, employee_id, leave_type, start_date, end_date, total_days,
      reason, status, requires_second_approval, created_at, updated_at
    ) values (
      '10000000-0000-0000-0000-000000000003',
      v_emp1_id, 'annual', '2026-10-05', '2026-10-06', 2,
      'Taking a short autumn break with family.',
      'approved', false, now() - interval '20 days', now() - interval '19 days'
    );

    insert into public.leave_approvals (
      request_id, approver_id, stage, decision, comment, decided_at
    ) values (
      '10000000-0000-0000-0000-000000000003',
      v_mgr_id, 1, 'approved',
      'Enjoy your time off!',
      now() - interval '19 days'
    );

    -- Request 4: Samira marriage leave (5 working days) - Pending Manager
    insert into public.leave_requests (
      id, employee_id, leave_type, start_date, end_date, total_days,
      reason, status, requires_second_approval, created_at, updated_at
    ) values (
      '10000000-0000-0000-0000-000000000004',
      v_emp2_id, 'marriage', '2026-12-07', '2026-12-11', 5,
      'Marriage ceremony and family celebrations in Jaipur.',
      'pending_manager', true, now() - interval '4 days', now() - interval '4 days'
    );
  end if;
end $$;
