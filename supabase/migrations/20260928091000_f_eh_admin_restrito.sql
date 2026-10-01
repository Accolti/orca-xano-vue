-- =============================================================
-- Restrição das dev tools: f_eh_admin passa a exigir super_admin
-- ou admin_geral (não mais admin comum/legado).
-- =============================================================

create or replace function public.f_eh_admin(p_user_id bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from usuarios u
    where u.id = p_user_id
      and (u.super_admin = true or u.role = 'admin_geral')
  );
$$;
