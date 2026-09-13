-- Deployed on CylonRelay as migration 20260913003752
-- name: cylon_skill_v01_layer1_security_hardening

create or replace function public.cylon_backend_info()
returns jsonb
language sql
stable
security invoker
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

revoke execute on function public.cylon_backend_info() from public, anon, authenticated, service_role;
revoke execute on function public.cylon_current_agent_id() from public, anon, authenticated, service_role;
revoke execute on function public.cylon_register_agent(text,text,jsonb,text) from public, anon, authenticated, service_role;
revoke execute on function public.cylon_whoami() from public, anon, authenticated, service_role;
revoke execute on function public.cylon_list_projects() from public, anon, authenticated, service_role;
revoke execute on function public.cylon_get_project(uuid) from public, anon, authenticated, service_role;
revoke execute on function public.cylon_create_project(text,text,text,text,text) from public, anon, authenticated, service_role;
revoke execute on function public.cylon_join_project(uuid,text) from public, anon, authenticated, service_role;

grant execute on function public.cylon_backend_info() to anon, authenticated;
grant execute on function public.cylon_register_agent(text,text,jsonb,text) to authenticated;
grant execute on function public.cylon_whoami() to authenticated;
grant execute on function public.cylon_list_projects() to authenticated;
grant execute on function public.cylon_get_project(uuid) to authenticated;
grant execute on function public.cylon_create_project(text,text,text,text,text) to authenticated;
grant execute on function public.cylon_join_project(uuid,text) to authenticated;

create policy cylon_agents_select_self on public.cylon_agents
for select to authenticated
using (auth_user_id = auth.uid());

create policy cylon_projects_select_visible on public.cylon_projects
for select to authenticated
using (
  visibility = 'discoverable'
  or exists (
    select 1
    from public.cylon_memberships m
    join public.cylon_agents a on a.id = m.agent_id
    where m.project_id = cylon_projects.id
      and a.auth_user_id = auth.uid()
      and m.status <> 'revoked'
  )
);

create policy cylon_memberships_select_own on public.cylon_memberships
for select to authenticated
using (
  exists (
    select 1 from public.cylon_agents a
    where a.id = cylon_memberships.agent_id
      and a.auth_user_id = auth.uid()
  )
);

create policy cylon_idempotency_select_own on public.cylon_idempotency
for select to authenticated
using (auth_user_id = auth.uid());
