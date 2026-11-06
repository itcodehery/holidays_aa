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
