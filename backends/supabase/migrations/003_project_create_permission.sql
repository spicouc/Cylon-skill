-- Deployed on CylonRelay as migration 20260913003819
-- name: cylon_skill_v01_project_create_permission

alter table public.cylon_agents add column if not exists can_create_projects boolean not null default false;

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
  v_agent_row public.cylon_agents;
  v_existing jsonb;
  v_project public.cylon_projects;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;

  select * into v_agent_row from public.cylon_agents where auth_user_id = v_uid;
  if not found then raise exception 'AGENT_NOT_REGISTERED'; end if;
  if not v_agent_row.can_create_projects then raise exception 'PROJECT_CREATE_NOT_AUTHORIZED'; end if;
  if p_idempotency_key is null or length(trim(p_idempotency_key)) < 8 then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;

  select result into v_existing
    from public.cylon_idempotency
   where auth_user_id = v_uid and operation = 'create_project' and idempotency_key = p_idempotency_key;
  if found then return v_existing; end if;

  if p_slug is null or p_slug !~ '^[a-z0-9][a-z0-9_-]{1,63}$' then raise exception 'INVALID_PROJECT_SLUG'; end if;
  if p_visibility not in ('hidden','discoverable') then raise exception 'INVALID_VISIBILITY'; end if;
  if p_join_policy not in ('closed','invite_only','approval_required','auto_join') then raise exception 'INVALID_JOIN_POLICY'; end if;

  insert into public.cylon_projects(name, slug, visibility, join_policy, created_by_agent)
  values (p_name, p_slug, p_visibility, p_join_policy, v_agent_row.id)
  returning * into v_project;

  insert into public.cylon_memberships(project_id, agent_id, role, status)
  values (v_project.id, v_agent_row.id, 'owner', 'active');

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

revoke execute on function public.cylon_create_project(text,text,text,text,text) from public, anon, service_role;
grant execute on function public.cylon_create_project(text,text,text,text,text) to authenticated;
