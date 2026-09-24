-- Deployed on CylonRelay as migration 20260913003643
-- name: cylon_skill_v01_layer1_registry

create extension if not exists pgcrypto;

create table if not exists public.cylon_agents (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  agent_key text not null unique check (agent_key ~ '^[a-z0-9][a-z0-9_-]{1,63}$'),
  display_name text,
  host_id text not null,
  capabilities jsonb not null default '{}'::jsonb,
  protocol_version text not null default '0.1',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.cylon_projects (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9_-]{1,63}$'),
  name text not null check (length(name) between 1 and 120),
  status text not null default 'active' check (status in ('active','archived')),
  visibility text not null default 'discoverable' check (visibility in ('hidden','discoverable')),
  join_policy text not null default 'approval_required' check (join_policy in ('closed','invite_only','approval_required','auto_join')),
  protocol_version text not null default '0.1',
  created_by_agent uuid not null references public.cylon_agents(id),
  created_at timestamptz not null default now(),
  archived_at timestamptz
);

create table if not exists public.cylon_memberships (
  project_id uuid not null references public.cylon_projects(id) on delete cascade,
  agent_id uuid not null references public.cylon_agents(id) on delete cascade,
  role text not null check (role in ('owner','coordinator','worker','reviewer','observer')),
  status text not null default 'active' check (status in ('pending','active','revoked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (project_id, agent_id)
);

create table if not exists public.cylon_idempotency (
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  operation text not null,
  idempotency_key text not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key (auth_user_id, operation, idempotency_key)
);

alter table public.cylon_agents enable row level security;
alter table public.cylon_projects enable row level security;
alter table public.cylon_memberships enable row level security;
alter table public.cylon_idempotency enable row level security;

revoke all on public.cylon_agents, public.cylon_projects, public.cylon_memberships, public.cylon_idempotency from anon, authenticated;

create or replace function public.cylon_current_agent_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.cylon_agents where auth_user_id = auth.uid();
$$;

create or replace function public.cylon_backend_info()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'backend', 'supabase',
    'protocol_version', '0.1',
    'implementation_version', '0.1-layer1',
    'canonical_state', 'postgres',
    'realtime_is_advisory', true,
    'operations', jsonb_build_array(
      'backend_info','register_agent','whoami','list_projects','get_project','create_project','join_project'
    )
  );
$$;

create or replace function public.cylon_register_agent(
  p_agent_key text,
  p_host_id text,
  p_capabilities jsonb default '{}'::jsonb,
  p_display_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_agent public.cylon_agents;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if p_agent_key is null or p_agent_key !~ '^[a-z0-9][a-z0-9_-]{1,63}$' then
    raise exception 'INVALID_AGENT_KEY';
  end if;
  if p_host_id is null or length(trim(p_host_id)) = 0 then
    raise exception 'INVALID_HOST_ID';
  end if;

  insert into public.cylon_agents(auth_user_id, agent_key, host_id, capabilities, display_name)
  values (v_uid, p_agent_key, p_host_id, coalesce(p_capabilities, '{}'::jsonb), p_display_name)
  on conflict (auth_user_id) do update
    set host_id = excluded.host_id,
        capabilities = excluded.capabilities,
        display_name = coalesce(excluded.display_name, public.cylon_agents.display_name),
        updated_at = now()
  returning * into v_agent;

  return jsonb_build_object(
    'agent_id', v_agent.id,
    'agent_key', v_agent.agent_key,
    'host_id', v_agent.host_id,
    'protocol_version', v_agent.protocol_version,
    'capabilities', v_agent.capabilities
  );
exception
  when unique_violation then
    raise exception 'AGENT_KEY_ALREADY_BOUND';
end;
$$;

create or replace function public.cylon_whoami()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_agent public.cylon_agents;
begin
  if v_uid is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  select * into v_agent from public.cylon_agents where auth_user_id = v_uid;
  if not found then
    return jsonb_build_object('registered', false, 'auth_user_id', v_uid);
  end if;
  return jsonb_build_object(
    'registered', true,
    'auth_user_id', v_uid,
    'agent_id', v_agent.id,
    'agent_key', v_agent.agent_key,
    'host_id', v_agent.host_id,
    'protocol_version', v_agent.protocol_version,
    'capabilities', v_agent.capabilities
  );
end;
$$;

create or replace function public.cylon_list_projects()
returns table (
  project_id uuid,
  slug text,
  name text,
  status text,
  visibility text,
  join_policy text,
  protocol_version text,
  membership_status text,
  role text
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select public.cylon_current_agent_id() as agent_id
  )
  select p.id, p.slug, p.name, p.status, p.visibility, p.join_policy, p.protocol_version,
         m.status, m.role
  from public.cylon_projects p
  left join me on true
  left join public.cylon_memberships m on m.project_id = p.id and m.agent_id = me.agent_id
  where p.visibility = 'discoverable'
     or (m.agent_id is not null and m.status <> 'revoked')
  order by p.created_at asc;
$$;

create or replace function public.cylon_get_project(p_project_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_agent uuid := public.cylon_current_agent_id();
  v_project public.cylon_projects;
  v_member public.cylon_memberships;
begin
  select * into v_project from public.cylon_projects where id = p_project_id;
  if not found then raise exception 'PROJECT_NOT_FOUND'; end if;

  if v_agent is not null then
    select * into v_member from public.cylon_memberships where project_id = p_project_id and agent_id = v_agent;
  end if;

  if v_project.visibility <> 'discoverable' and (v_member.agent_id is null or v_member.status = 'revoked') then
    raise exception 'PROJECT_NOT_VISIBLE';
  end if;

  return jsonb_build_object(
    'project_id', v_project.id,
    'slug', v_project.slug,
    'name', v_project.name,
    'status', v_project.status,
    'visibility', v_project.visibility,
    'join_policy', v_project.join_policy,
    'protocol_version', v_project.protocol_version,
    'membership_status', v_member.status,
    'role', v_member.role
  );
end;
$$;

create or replace function public.cylon_create_project(
  p_name text,
  p_slug text,
  p_visibility text default 'discoverable',
  p_join_policy text default 'approval_required',
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_agent uuid := public.cylon_current_agent_id();
  v_existing jsonb;
  v_project public.cylon_projects;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_agent is null then raise exception 'AGENT_NOT_REGISTERED'; end if;
  if p_idempotency_key is null or length(trim(p_idempotency_key)) < 8 then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select result into v_existing
    from public.cylon_idempotency
   where auth_user_id = v_uid and operation = 'create_project' and idempotency_key = p_idempotency_key;
  if found then return v_existing; end if;

  if p_slug is null or p_slug !~ '^[a-z0-9][a-z0-9_-]{1,63}$' then raise exception 'INVALID_PROJECT_SLUG'; end if;
  if p_visibility not in ('hidden','discoverable') then raise exception 'INVALID_VISIBILITY'; end if;
  if p_join_policy not in ('closed','invite_only','approval_required','auto_join') then raise exception 'INVALID_JOIN_POLICY'; end if;

  insert into public.cylon_projects(name, slug, visibility, join_policy, created_by_agent)
  values (p_name, p_slug, p_visibility, p_join_policy, v_agent)
  returning * into v_project;

  insert into public.cylon_memberships(project_id, agent_id, role, status)
  values (v_project.id, v_agent, 'owner', 'active');

  v_existing := jsonb_build_object(
    'project_id', v_project.id,
    'slug', v_project.slug,
    'name', v_project.name,
    'role', 'owner',
    'membership_status', 'active',
    'protocol_version', v_project.protocol_version
  );

  insert into public.cylon_idempotency(auth_user_id, operation, idempotency_key, result)
  values (v_uid, 'create_project', p_idempotency_key, v_existing);

  return v_existing;
exception
  when unique_violation then
    if exists (
      select 1 from public.cylon_idempotency
      where auth_user_id = v_uid and operation = 'create_project' and idempotency_key = p_idempotency_key
    ) then
      select result into v_existing from public.cylon_idempotency
       where auth_user_id = v_uid and operation = 'create_project' and idempotency_key = p_idempotency_key;
      return v_existing;
    end if;
    raise;
end;
$$;

create or replace function public.cylon_join_project(
  p_project_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_agent uuid := public.cylon_current_agent_id();
  v_project public.cylon_projects;
  v_member public.cylon_memberships;
  v_existing jsonb;
  v_status text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if v_agent is null then raise exception 'AGENT_NOT_REGISTERED'; end if;
  if p_idempotency_key is null or length(trim(p_idempotency_key)) < 8 then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select result into v_existing from public.cylon_idempotency
   where auth_user_id = v_uid and operation = 'join_project:' || p_project_id::text and idempotency_key = p_idempotency_key;
  if found then return v_existing; end if;

  select * into v_project from public.cylon_projects where id = p_project_id;
  if not found or v_project.status <> 'active' then raise exception 'PROJECT_NOT_JOINABLE'; end if;
  if v_project.visibility <> 'discoverable' then raise exception 'PROJECT_NOT_VISIBLE'; end if;
  if v_project.join_policy in ('closed','invite_only') then raise exception 'JOIN_NOT_ALLOWED'; end if;

  v_status := case when v_project.join_policy = 'auto_join' then 'active' else 'pending' end;

  insert into public.cylon_memberships(project_id, agent_id, role, status)
  values (p_project_id, v_agent, 'worker', v_status)
  on conflict (project_id, agent_id) do update
    set updated_at = now()
  returning * into v_member;

  v_existing := jsonb_build_object(
    'project_id', p_project_id,
    'membership_status', v_member.status,
    'role', v_member.role
  );

  insert into public.cylon_idempotency(auth_user_id, operation, idempotency_key, result)
  values (v_uid, 'join_project:' || p_project_id::text, p_idempotency_key, v_existing)
  on conflict do nothing;

  return v_existing;
end;
$$;

revoke all on function public.cylon_current_agent_id() from public;
revoke all on function public.cylon_backend_info() from public;
revoke all on function public.cylon_register_agent(text,text,jsonb,text) from public;
revoke all on function public.cylon_whoami() from public;
revoke all on function public.cylon_list_projects() from public;
revoke all on function public.cylon_get_project(uuid) from public;
revoke all on function public.cylon_create_project(text,text,text,text,text) from public;
revoke all on function public.cylon_join_project(uuid,text) from public;

grant execute on function public.cylon_backend_info() to anon, authenticated;
grant execute on function public.cylon_register_agent(text,text,jsonb,text) to authenticated;
grant execute on function public.cylon_whoami() to authenticated;
grant execute on function public.cylon_list_projects() to authenticated;
grant execute on function public.cylon_get_project(uuid) to authenticated;
grant execute on function public.cylon_create_project(text,text,text,text,text) to authenticated;
grant execute on function public.cylon_join_project(uuid,text) to authenticated;
