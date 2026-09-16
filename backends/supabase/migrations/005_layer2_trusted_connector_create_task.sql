-- Deployed on CylonRelay as migration 20260916005000
-- name: cylon_skill_v01_layer2_trusted_connector_create_task

-- Phase 1: Security Model
-- Trusted connector create task function
-- Preserves current role semantics:
--   - connector identity must be registered
--   - connector must have active project membership
--   - membership role = coordinator or owner-equivalent coordination role
--   - project is active
--   - directive is active
--   - idempotency key is valid
--
-- Do NOT allow:
--   - reviewer-only connector → create_task
--   - worker → create_task
--   - observer → create_task

-- Phase 2: Implement RPC
-- cylon_trusted_connector_create_task(
--   p_agent_key text,
--   p_project_id uuid,
--   p_directive_id uuid,
--   p_title text,
--   p_spec jsonb,
--   p_parent_task_id uuid,
--   p_idempotency_key text
-- )

create or replace function public.cylon_trusted_connector_create_task(
    p_agent_key text,
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
    v_directive public.cylon_directives;
    v_existing jsonb;
    v_trusted_connector_id uuid;
    v_auth_user_id uuid;
begin
    -- Validate agent key matches trusted_connector
    SELECT id, auth_user_id INTO v_trusted_connector_id, v_auth_user_id
    FROM public.cylon_agents
    WHERE agent_key = p_agent_key
    AND identity_type = 'trusted_connector'
    AND is_active = true;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'UNAUTHORIZED_TRUSTED_CONNECTOR';
    END IF;
    
    -- Verify connector has coordinator or owner role in project
    IF NOT EXISTS (
        SELECT 1 FROM public.cylon_memberships
        WHERE agent_id = v_trusted_connector_id
        AND project_id = p_project_id
        AND role IN ('coordinator', 'owner')
        AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'TRUSTED_CONNECTOR_NOT_AUTHORIZED_FOR_TASK_CREATION';
    END IF;
    
    -- Validate project exists and directive is active
    SELECT * INTO v_directive
    FROM public.cylon_directives
    WHERE id = p_directive_id
    AND project_id = p_project_id
    AND status = 'active';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'DIRECTIVE_NOT_FOUND_OR_INACTIVE';
    END IF;
    
    -- Validate idempotency key
    IF p_idempotency_key IS NULL THEN
        RAISE EXCEPTION 'IDEMPOTENCY_KEY_REQUIRED';
    END IF;
    
    -- Check idempotency
    SELECT result INTO v_existing 
    FROM public.cylon_idempotency
    WHERE auth_user_id = v_auth_user_id
    AND operation = 'trusted_connector_create_task'
    AND idempotency_key = p_idempotency_key;
    
    IF v_existing IS NOT NULL THEN
        RETURN v_existing;
    END IF;
    
    -- Create task using existing task creation logic
    INSERT INTO public.cylon_tasks(
        project_id,
        directive_id,
        parent_task_id,
        title,
        spec,
        status,
        spec_version,
        created_at,
        updated_at
    ) VALUES (
        p_project_id,
        p_directive_id,
        p_parent_task_id,
        p_title,
        COALESCE(p_spec, '{}'::jsonb),
        'READY',
        1,
        now(),
        now()
    ) RETURNING * INTO v_task;
    
    -- Create idempotency record
    INSERT INTO public.cylon_idempotency(
        auth_user_id,
        operation,
        idempotency_key,
        result
    ) VALUES (
        v_auth_user_id,
        'trusted_connector_create_task',
        p_idempotency_key,
        to_jsonb(v_task.*)
    ) ON CONFLICT DO NOTHING;
    
    RETURN to_jsonb(v_task.*);
END;
$$;

-- Grant execute permissions for trusted connector create task
grant execute on function public.cylon_trusted_connector_create_task to authenticated;