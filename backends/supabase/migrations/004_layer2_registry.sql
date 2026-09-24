-- Deployed on CylonRelay as migration 20260913003900
-- name: cylon_skill_v01_layer2_directives_table

-- Layer 2: Directives Table
create table if not exists public.cylon_directives (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.cylon_projects(id) on delete cascade,
  objective text not null,
  spec jsonb not null default '{}'::jsonb,
  version integer not null default 1,
  status text not null default 'active' check (status in ('active','completed','cancelled','archived')),
  created_by_agent uuid not null references public.cylon_agents(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Layer 2: Tasks Table
create table if not exists public.cylon_tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.cylon_projects(id) on delete cascade,
  directive_id uuid references public.cylon_directives(id) on delete set null,
  parent_task_id uuid references public.cylon_tasks(id) on delete set null,
  title text not null,
  spec jsonb not null default '{}'::jsonb,
  status text not null default 'READY' check (status in ('READY','CLAIMED','RUNNING','RESULT_READY','REVIEW','COMPLETE','CANCELLED','REJECTED')),
  spec_version integer not null default 1,
  assigned_agent_id uuid references public.cylon_agents(id),
  coordinator_agent_id uuid references public.cylon_agents(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Layer 2: Task Attempts Table
create table if not exists public.cylon_task_attempts (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.cylon_tasks(id) on delete cascade,
  worker_agent_id uuid not null references public.cylon_agents(id),
  attempt_status text not null default 'PENDING' check (attempt_status in ('PENDING','CLAIMED','RUNNING','RESULT_READY','REJECTED','COMPLETE')),
  result jsonb,
  result_digest text,
  result_version integer,
  attempt_number integer not null default 1,
  coordinator_agent_id uuid references public.cylon_agents(id),
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  unique(task_id, attempt_number)
);

-- Layer 2: Reviews Table
create table if not exists public.cylon_reviews (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.cylon_tasks(id) on delete cascade,
  attempt_id uuid not null references public.cylon_task_attempts(id) on delete cascade,
  reviewer_agent_id uuid not null references public.cylon_agents(id),
  decision text not null check (decision in ('APPROVE','REJECT')),
  result_version integer,
  result_digest text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Layer 2: Events Table (for audit trail)
create table if not exists public.cylon_events (
  id uuid primary key default gen_random_uuid(),
  project_id uuid references public.cylon_projects(id) on delete set null,
  task_id uuid references public.cylon_tasks(id) on delete set null,
  agent_id uuid references public.cylon_agents(id) on delete set null,
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Enable RLS on all Layer 2 tables
alter table public.cylon_directives enable row level security;
alter table public.cylon_tasks enable row level security;
alter table public.cylon_task_attempts enable row level security;
alter table public.cylon_reviews enable row level security;
alter table public.cylon_events enable row level security;

-- Revoke all from anon and authenticated
revoke all on public.cylon_directives, public.cylon_tasks, public.cylon_task_attempts, public.cylon_reviews, public.cylon_events from anon, authenticated;

-- Create functions: create_directive
create or replace function public.cylon_create_directive(
  p_project_id uuid,
  p_objective text,
  p_spec jsonb default '{}'::jsonb,
  p_created_by_agent uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_directive public.cylon_directives;
  v_existing jsonb;
begin
  if p_project_id is null then raise exception 'PROJECT_ID_REQUIRED'; end if;
  if p_objective is null then raise exception 'OBJECTIVE_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  insert into public.cylon_idempotency(auth_user_id, operation, idempotency_key, result)
  values (auth.uid(), 'create_directive', p_idempotency_key, jsonb_build_object('project_id', p_project_id))
  on conflict (auth_user_id, operation, idempotency_key) do nothing
  returning result into v_existing;

  if v_existing is not null then
    return v_existing;
  end if;

  insert into public.cylon_directives(project_id, objective, spec, created_by_agent)
  values (p_project_id, p_objective, coalesce(p_spec, '{}'::jsonb), p_created_by_agent)
  returning * into v_directive;

  insert into public.cylon_idempotency(auth_user_id, operation, idempotency_key, result)
  values (auth.uid(), 'create_directive', p_idempotency_key, to_jsonb(v_directive.*))
  on conflict do nothing;

  return to_jsonb(v_directive.*);
end;
$$;

-- Create functions: list_directives
create or replace function public.cylon_list_directives(
  p_project_id uuid
)
returns table (
  directive_id uuid,
  project_id uuid,
  objective text,
  spec jsonb,
  version integer,
  status text,
  created_by_agent uuid,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select d.id, d.project_id, d.objective, d.spec, d.version, d.status, d.created_by_agent, d.created_at
  from public.cylon_directives d
  where d.project_id = p_project_id;
$$;

-- Create functions: create_task
create or replace function public.cylon_create_task(
  p_project_id uuid,
  p_directive_id uuid,
  p_title text,
  p_spec jsonb,
  p_parent_task_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task public.cylon_tasks;
  v_existing jsonb;
  v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_project_id is null then raise exception 'PROJECT_ID_REQUIRED'; end if;
  if p_title is null then raise exception 'TITLE_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  -- Check for idempotency
  select result into v_existing from public.cylon_idempotency
  where auth_user_id = v_uid and operation = 'create_task' and idempotency_key = p_idempotency_key;
  if v_existing is not null then
    return v_existing;
  end if;

  insert into public.cylon_tasks(project_id, directive_id, parent_task_id, title, spec)
  values (p_project_id, p_directive_id, p_parent_task_id, p_title, coalesce(p_spec, '{}'::jsonb))
  returning * into v_task;

  insert into public.cylon_idempotency(auth_user_id, operation, idempotency_key, result)
  values (v_uid, 'create_task', p_idempotency_key, to_jsonb(v_task.*))
  on conflict do nothing;

  return to_jsonb(v_task.*);
end;
$$;

-- Create functions: list_tasks
create or replace function public.cylon_list_tasks(
  p_project_id uuid
)
returns table (
  task_id uuid,
  directive_id uuid,
  parent_task_id uuid,
  title text,
  spec jsonb,
  spec_version integer,
  status text,
  current_attempt_no integer,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select t.id, t.directive_id, t.parent_task_id, t.title, t.spec, t.spec_version, t.status,
         coalesce(attempt.current_attempt_no, 0) as current_attempt_no, t.created_at
  from public.cylon_tasks t
  left join (
    select task_id, max(attempt_number) as current_attempt_no
    from public.cylon_task_attempts
    group by task_id
  ) attempt on attempt.task_id = t.id
  where t.project_id = p_project_id;
$$;

-- Create functions: get_task
create or replace function public.cylon_get_task(
  p_task_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with task_data as (
    select t.*, coalesce(attempt.*, '{}'::jsonb) as attempt
    from public.cylon_tasks t
    left join public.cylon_task_attempts attempt on attempt.id = (
      select id from public.cylon_task_attempts ta 
      where ta.task_id = t.id order by ta.attempt_number desc limit 1
    )
    where t.id = p_task_id
  )
  select jsonb_build_object(
    'task_id', td.id,
    'directive_id', td.directive_id,
    'parent_task_id', td.parent_task_id,
    'title', td.title,
    'spec', td.spec,
    'spec_version', td.spec_version,
    'status', td.status,
    'attempt_id', td.attempt->>'id',
    'attempt_status', td.attempt->>'attempt_status',
    'result_digest', td.attempt->>'result_digest',
    'result_version', td.attempt->>'result_version',
    'worker_agent_id', td.attempt->>'worker_agent_id',
    'current_attempt_no', coalesce((td.attempt->>'attempt_number')::integer, 0),
    'created_at', td.created_at,
    'updated_at', td.updated_at
  ) from task_data td;
$$;

-- Create functions: claim_task
create or replace function public.cylon_claim_task(
  p_task_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_agent uuid := public.cylon_current_agent_id();
  v_task public.cylon_tasks;
  v_attempt public.cylon_task_attempts;
  v_existing jsonb;
begin
  if v_agent is null then raise exception 'AGENT_NOT_REGISTERED'; end if;
  if p_task_id is null then raise exception 'TASK_ID_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  -- Check idempotency
  select result into v_existing from public.cylon_idempotency
  where auth.uid() = (select auth_user_id from public.cylon_agents where id = v_agent)
    and operation = 'claim_task' and idempotency_key = p_idempotency_key;
  if v_existing is not null then
    return v_existing;
  end if;

  -- Get current task state
  select * into v_task from public.cylon_tasks where id = p_task_id;
  if not found then raise exception 'TASK_NOT_FOUND'; end if;
  if v_task.status != 'READY' then raise exception 'TASK_NOT_READY'; end if;

  -- Create the attempt record
  insert into public.cylon_task_attempts(task_id, worker_agent_id, attempt_number)
  values (p_task_id, v_agent, 1)
  returning * into v_attempt;

  -- Update task status
  update public.cylon_tasks 
  set status = 'CLAIMED', assigned_agent_id = v_agent, updated_at = now()
  where id = p_task_id;

  -- Create idempotency record
  insert into public.cylon_idempotency(auth_user_id, operation, idempotency_key, result)
  values ((select auth_user_id from public.cylon_agents where id = v_agent), 'claim_task', p_idempotency_key, to_jsonb(v_attempt.*))
  on conflict do nothing;

  return to_jsonb(v_attempt.*) || jsonb_build_object('task_status', 'CLAIMED');
end;
$$;

-- Create functions: start_attempt
create or replace function public.cylon_start_attempt(
  p_task_id uuid,
  p_attempt_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_agent uuid := public.cylon_current_agent_id();
  v_attempt public.cylon_task_attempts;
  v_task public.cylon_tasks;
  v_existing jsonb;
begin
  if v_agent is null then raise exception 'AGENT_NOT_REGISTERED'; end if;
  if p_task_id is null then raise exception 'TASK_ID_REQUIRED'; end if;
  if p_attempt_id is null then raise exception 'ATTEMPT_ID_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  -- Check idempotency
  select result into v_existing from public.cylon_idempotency
  where auth.uid() = (select auth_user_id from public.cylon_agents where id = v_agent)
    and operation = ('start_attempt:' || p_task_id) and idempotency_key = p_idempotency_key;
  if v_existing is not null then
    return v_existing;
  end if;

  -- Verify attempt belongs to this task and belongs to this agent
  select * into v_attempt from public.cylon_task_attempts 
  where id = p_attempt_id and worker_agent_id = v_agent;
  if not found then raise exception 'ATTEMPT_NOT_FOUND'; end if;

  -- Get task
  select * into v_task from public.cylon_tasks where id = p_task_id;
  if not found then raise exception 'TASK_NOT_FOUND'; end if;

  if v_attempt.attempt_status != 'CLAIMED' then raise exception 'TASK_NOT_CLAIMED'; end if;

  -- Start the attempt
  update public.cylon_task_attempts
  set attempt_status = 'RUNNING', started_at = now(), updated_at = now()
  where id = p_attempt_id
  returning * into v_attempt;

  -- Update task status
  update public.cylon_tasks
  set status = 'RUNNING', updated_at = now()
  where id = p_task_id;

  -- Record idempotency
  insert into public.cylon_idempotency(auth_user_id, operation, idempotency_key, result)
  values ((select auth_user_id from public.cylon_agents where id = v_agent), 'start_attempt', p_idempotency_key, to_jsonb(v_attempt.*))
  on conflict do nothing;

  return to_jsonb(v_attempt.*) || jsonb_build_object('task_status', 'RUNNING');
end;
$$;

-- Create functions: submit_result
create or replace function public.cylon_submit_result(
  p_task_id uuid,
  p_attempt_id uuid,
  p_result jsonb,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_agent uuid := public.cylon_current_agent_id();
  v_attempt public.cylon_task_attempts;
  v_task public.cylon_tasks;
  v_result_digest text;
  v_existing jsonb;
begin
  if v_agent is null then raise exception 'AGENT_NOT_REGISTERED'; end if;
  if p_task_id is null then raise exception 'TASK_ID_REQUIRED'; end if;
  if p_attempt_id is null then raise exception 'ATTEMPT_ID_REQUIRED'; end if;
  if p_result is null then raise exception 'RESULT_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  -- Check idempotency
  select result into v_existing from public.cylon_idempotency
  where auth.uid() = (select auth_user_id from public.cylon_agents where id = v_agent)
    and operation = 'submit_result' and idempotency_key = p_idempotency_key;
  if v_existing is not null then
    return v_existing;
  end if;

  -- Verify attempt
  select * into v_attempt from public.cylon_task_attempts
  where id = p_attempt_id and worker_agent_id = v_agent and task_id = p_task_id;
  if not found then raise exception 'ATTEMPT_NOT_FOUND_OR_UNAUTHORIZED'; end if;

  -- Compute result digest
  v_result_digest := encode(digest(p_result::text, 'sha256'), 'hex');

  -- Update attempt
  update public.cylon_task_attempts
  set result = p_result, result_digest = v_result_digest, result_version = coalesce(result_version, 0) + 1,
      attempt_status = 'RESULT_READY', completed_at = now(), updated_at = now()
  where id = p_attempt_id
  returning * into v_attempt;

  -- Update task
  update public.cylon_tasks
  set status = 'RESULT_READY', updated_at = now()
  where id = p_task_id;

  -- Record idempotency
  insert into public.cylon_idempotency(auth_user_id, operation, idempotency_key, result)
  values ((select auth_user_id from public.cylon_agents where id = v_agent), 'submit_result', p_idempotency_key,
    jsonb_build_object('task_id', p_task_id, 'attempt_id', p_attempt_id, 'result_digest', v_result_digest, 'result_version', coalesce(v_attempt.result_version, 1)))
  on conflict do nothing;

  return jsonb_build_object(
    'task_id', p_task_id,
    'attempt_id', p_attempt_id,
    'status', 'RESULT_READY',
    'result_digest', v_result_digest,
    'result_version', coalesce(v_attempt.result_version, 1)
  );
end;
$$;

-- Create functions: request_review
create or replace function public.cylon_request_review(
  p_task_id uuid,
  p_attempt_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_agent uuid := public.cylon_current_agent_id();
  v_task public.cylon_tasks;
  v_attempt public.cylon_task_attempts;
  v_member public.cylon_memberships;
  v_review uuid;
  v_existing jsonb;
begin
  if v_agent is null then raise exception 'AGENT_NOT_REGISTERED'; end if;
  if p_task_id is null then raise exception 'TASK_ID_REQUIRED'; end if;
  if p_attempt_id is null then raise exception 'ATTEMPT_ID_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  -- Check idempotency
  select result into v_existing from public.cylon_idempotency
  where auth.uid() = (select auth_user_id from public.cylon_agents where id = v_agent)
    and operation = 'request_review' and idempotency_key = p_idempotency_key;
  if v_existing is not null then
    return v_existing;
  end if;

  -- Get task and verify worker can request review
  select * into v_task from public.cylon_tasks where id = p_task_id;
  if not found then raise exception 'TASK_NOT_FOUND'; end if;
  if v_task.worker_agent_id != v_agent then raise exception 'NOT_TASK_OWNER'; end if;

  -- Get attempt
  select * into v_attempt from public.cylon_task_attempts where id = p_attempt_id;
  if not found then raise exception 'ATTEMPT_NOT_FOUND'; end if;

  -- Check can review (must have reviewer role or be owner/coordinator)
  select role into v_member from public.cylon_memberships
  where project_id = v_task.project_id and agent_id = v_agent;
  if v_member is null then raise exception 'NOT_PROJECT_MEMBER'; end if;

  -- Update task/review status
  update public.cylon_tasks set status = 'REVIEW' where id = p_task_id;

  -- Record idempotency
  insert into public.cylon_idempotency(auth_user_id, operation, idempotency_key, result)
  values ((select auth_user_id from public.cylon_agents where id = v_agent), 'request_review', p_idempotency_key,
    jsonb_build_object('task_id', p_task_id, 'attempt_id', p_attempt_id, 'status', 'REVIEW_REQUESTED'))
  on conflict do nothing;

  return jsonb_build_object('task_id', p_task_id, 'attempt_id', p_attempt_id, 'status', 'REVIEW_REQUESTED');
end;
$$;

-- Create functions: review_result
create or replace function public.cylon_review_result(
  p_task_id uuid,
  p_attempt_id uuid,
  p_result_version integer,
  p_result_digest text,
  p_decision text,
  p_notes text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reviewer uuid := public.cylon_current_agent_id();
  v_task public.cylon_tasks;
  v_attempt public.cylon_task_attempts;
  v_member public.cylon_memberships;
  v_review public.cylon_reviews;
  v_existing jsonb;
begin
  if v_reviewer is null then raise exception 'AGENT_NOT_REGISTERED'; end if;
  if p_task_id is null then raise exception 'TASK_ID_REQUIRED'; end if;
  if p_attempt_id is null then raise exception 'ATTEMPT_ID_REQUIRED'; end if;
  if p_decision is null then raise exception 'DECISION_REQUIRED'; end if;
  if p_idempotency_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  -- Check idempotency
  select result into v_existing from public.cylon_idempotency
  where auth.uid() = (select auth_user_id from public.cylon_agents where id = v_reviewer)
    and operation = 'review_result' and idempotency_key = p_idempotency_key;
  if v_existing is not null then
    return v_existing;
  end if;

  -- Verify reviewer has reviewer role
  select * into v_task from public.cylon_tasks where id = p_task_id;
  if not found then raise exception 'TASK_NOT_FOUND'; end if;
  select role into v_member from public.cylon_memberships
  where project_id = v_task.project_id and agent_id = v_reviewer;
  if v_member != 'reviewer' then raise exception 'REVIEWER_REQUIRED'; end if;

  -- Get attempt and verify state
  select * into v_attempt from public.cylon_task_attempts
  where id = p_attempt_id and task_id = p_task_id;
  if not found then raise exception 'ATTEMPT_NOT_FOUND'; end if;
  if v_attempt.result_digest != p_result_digest then raise exception 'RESULT_MISMATCH'; end if;
  if v_attempt.result_version != p_result_version then raise exception 'VERSION_MISMATCH'; end if;

  -- Check self-review
  if v_attempt.worker_agent_id = v_reviewer then raise exception 'SELF_REVIEW_FORBIDDEN'; end if;

  -- Create review record
  insert into public.cylon_reviews(
    task_id, attempt_id, reviewer_agent_id, decision, notes, result_version, result_digest
  ) values (p_task_id, p_attempt_id, v_reviewer, p_decision, p_notes, p_result_version, p_result_digest)
  returning * into v_review;

  -- Update task status
  if p_decision = 'APPROVE' then
      update public.cylon_tasks set status = 'COMPLETE' where id = p_task_id;
      update public.cylon_task_attempts set attempt_status = 'COMPLETE' where id = p_attempt_id;
  elsif p_decision = 'REJECT' then
      update public.cylon_tasks set status = 'REJECTED' where id = p_task_id;
      update public.cylon_task_attempts set attempt_status = 'REJECTED' where id = p_attempt_id;
  end if;

  -- Record idempotency
  insert into public.cylon_idempotency(auth_user_id, operation, idempotency_key, result)
  values ((select auth_user_id from public.cylon_agents where id = v_reviewer), 'review_result', p_idempotency_key,
    jsonb_build_object('review_id', v_review.id, 'decision', p_decision))
  on conflict do nothing;

  return jsonb_build_object('review_id', v_review.id, 'decision', p_decision, 'status', 'COMPLETE');
end;
$$;

-- Grant execute permissions
grant execute on function public.cylon_create_directive to authenticated;
grant execute on function public.cylon_list_directives to authenticated;
grant execute on function public.cylon_create_task to authenticated;
grant execute on function public.cylon_list_tasks to authenticated;
grant execute on function public.cylon_get_task to authenticated;
grant execute on function public.cylon_claim_task to authenticated;
grant execute on function public.cylon_start_attempt to authenticated;
grant execute on function public.cylon_submit_result to authenticated;
grant execute on function public.cylon_request_review to authenticated;
grant execute on function public.cylon_review_result to authenticated;