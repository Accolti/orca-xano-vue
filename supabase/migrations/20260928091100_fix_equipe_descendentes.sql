-- =============================================================
-- Corrige a lista da equipe: admin/master passam a ver TODA a
-- árvore de descendentes (não só os filhos diretos).
--
-- Antes: `u.vendedor_pai_id = p_user_id` → só filhos diretos, então o
-- admin (ex.: id 10) via o master (id 11) mas não o vendedor (id 12).
-- Agora usa f_descendentes (CTE recursiva), já usada pela comissoes.
-- =============================================================

create or replace function public.equipe(p_user_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_me record;
  v_lista jsonb;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;

  select id, role into v_me from usuarios where id = p_user_id;
  if v_me.role <> 'admin_geral' and not f_tem_comissoes(p_user_id) then
    raise exception 'Sem acesso a esta funcionalidade.' using errcode = 'P0001';
  end if;

  if v_me.role = 'admin_geral' then
    select coalesce(jsonb_agg(
      to_jsonb(u) - 'password' - 'auth_id' - 'google_oauth'
      || jsonb_build_object('ativo_efetivo', f_ativo_efetivo(u.id))
      order by u.created_at desc
    ), '[]'::jsonb)
    into v_lista
    from usuarios u where u.id <> p_user_id;
  else
    select coalesce(jsonb_agg(
      to_jsonb(u) - 'password' - 'auth_id' - 'google_oauth'
      || jsonb_build_object('ativo_efetivo', f_ativo_efetivo(u.id))
      order by u.created_at desc
    ), '[]'::jsonb)
    into v_lista
    from usuarios u where u.id in (select f_descendentes(p_user_id));
  end if;

  return v_lista;
end;
$$;
