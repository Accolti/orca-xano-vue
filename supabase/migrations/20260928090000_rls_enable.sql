-- =============================================================
-- Fase 3 — Segurança: habilita RLS em todas as tabelas + helpers de auth
-- =============================================================
--
-- Motivo: as tabelas estavam sem RLS (acesso irrestrito via anon key). Agora o
-- acesso a dados passa a ser feito SOMENTE através dos RPCs (que serão security
-- definer), com validação de identidade via auth.uid().
--
--   auth_user_id()   -> resolve o usuarios.id do usuário logado (auth.uid())
--   f_pode_ver_orca() -> permissão de VISUALIZAÇÃO de uma orca (dono/ancestral/admin_geral)
--

-- Resolve o id do usuário de negócio a partir do Supabase Auth (auth.uid()).
create or replace function public.auth_user_id()
returns bigint language sql stable security definer set search_path = public as $$
  select id from usuarios where auth_id = auth.uid()
$$;

-- Permissão de visualização de uma orca (mesma regra de orca_por_id):
-- admin_geral, dono, pai direto ou admin ancestral de um vendedor_master.
create or replace function public.f_pode_ver_orca(p_user_id bigint, p_orca_id bigint)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare
  v_viewer record;
  v_owner record;
  v_pai record;
begin
  select id, role, vendedor_pai_id into v_viewer from usuarios where id = p_user_id;
  if v_viewer.id is null then
    return false;
  end if;

  select user_id into v_owner from orca where id = p_orca_id;
  if v_owner.user_id is null then
    return false;
  end if;

  select id, role, vendedor_pai_id into v_owner from usuarios where id = v_owner.user_id;

  if v_viewer.role = 'admin_geral' or v_owner.id = p_user_id then
    return true;
  elsif coalesce(v_owner.vendedor_pai_id, 0) > 0 then
    if v_owner.vendedor_pai_id = p_user_id then
      return true;
    else
      select role, vendedor_pai_id into v_pai from usuarios where id = v_owner.vendedor_pai_id;
      if v_pai.role = 'vendedor_master' and v_pai.vendedor_pai_id = p_user_id then
        return true;
      end if;
    end if;
  end if;

  return false;
end;
$$;

-- Habilita RLS em TODAS as tabelas do schema public (sem políticas => acesso direto negado).
do $$
declare
  t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;
