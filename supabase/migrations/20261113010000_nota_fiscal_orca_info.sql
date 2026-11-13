-- Expõe o código do pedido (cod_orca) nas respostas de nota_fiscal_listar e
-- nota_fiscal_por_orca, para a listagem/consulta mostrar a qual pedido a NF está vinculada.

create or replace function public.nota_fiscal_listar(p_user_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_role text;
  v_empresa bigint;
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_eh_admin_empresa(p_user_id) then
    raise exception 'Apenas administradores.' using errcode = 'P0001';
  end if;

  select role into v_role from usuarios where id = p_user_id;

  if v_role = 'admin_geral' then
    return coalesce((
      select jsonb_agg(
        to_jsonb(n) || jsonb_build_object('cod_orca', o.cod_orca)
        order by n.created_at desc, n.id desc
      )
      from nota_fiscal n
      left join orca o on o.id = n.orca_id
    ), '[]'::jsonb);
  end if;

  v_empresa := f_empresa_id(p_user_id);
  return coalesce((
    select jsonb_agg(
      to_jsonb(n) || jsonb_build_object('cod_orca', o.cod_orca)
      order by n.created_at desc, n.id desc
    )
    from nota_fiscal n
    left join orca o on o.id = n.orca_id
    where n.user_id = v_empresa
  ), '[]'::jsonb);
end;
$$;

create or replace function public.nota_fiscal_por_orca(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth_user_id() is null or auth_user_id() <> p_user_id then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  if not f_pode_ver_orca(p_user_id, p_orca_id) then
    raise exception 'Acesso negado.' using errcode = 'P0001';
  end if;
  return coalesce((
    select jsonb_agg(
      to_jsonb(n) || jsonb_build_object('cod_orca', o.cod_orca)
      order by n.created_at asc, n.id asc
    )
    from nota_fiscal n
    left join orca o on o.id = n.orca_id
    where n.orca_id = p_orca_id
  ), '[]'::jsonb);
end;
$$;
