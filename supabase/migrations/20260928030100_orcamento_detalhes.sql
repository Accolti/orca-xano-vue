-- =============================================================
-- Fase 2D — Leitura/detalhes do orçamento (orca_detalhes + orca_por_id)
-- =============================================================

-- Monta { ORCA_1, itemS } para uma orca (com _cliente + telefones + enderecos e
-- as FKs do produto no itemS para a restauração na edição). Read-only.
create or replace function public.f_orca_detalhes(p_orca_id bigint)
returns jsonb language plpgsql as $$
declare
  v_orca jsonb;
  v_itemS jsonb;
begin
  select to_jsonb(o)
    || jsonb_build_object(
      'frtB2B', o.frt_b2b,
      'frtB2C', o.frt_b2c,
      'vnd_B2B_tot', o.vnd_b2b_tot,
      'vnd_B2B_B2C_tot', o.vnd_b2b_b2c_tot,
      '_cliente', (
        select case when c.id is null then null
          else to_jsonb(c)
            || jsonb_build_object(
                'e-mail', c.email,
                '_telefone_cliente_of_cliente', coalesce((
                  select jsonb_agg(to_jsonb(t) order by t.id)
                  from telefone_cliente t where t.cliente_id = c.id
                ), '[]'::jsonb),
                '_enderecos', coalesce((
                  select jsonb_agg(
                    to_jsonb(e) || jsonb_build_object('Tipo', e.tipo::text)
                    order by e.id
                  )
                  from endereco_cliente e where e.cliente_id = c.id
                ), '[]'::jsonb)
              )
        end
        from cliente c where c.id = o.cliente_id
      )
    )
  into v_orca
  from orca o where o.id = p_orca_id;

  if v_orca is null then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;

  select coalesce(jsonb_agg(
    to_jsonb(i) || jsonb_build_object(
      'Descricao', concat_ws(' ', m.nome, l.nome, t.nome, n.nome, b.nome),
      'material_id', p.material_id,
      'linha_id', p.linha_id,
      'tipo_id', p.tipo_id,
      'nivel_id', p.nivel_id
    )
    order by i.id
  ), '[]'::jsonb)
  into v_itemS
  from item i
  join produto p on p.id = i.produto_id
  join material m on m.id = p.material_id
  left join linha l on l.id = p.linha_id
  left join tipo t on t.id = p.tipo_id
  left join nivel n on n.id = p.nivel_id
  left join borda b on b.id = i.borda_id
  where i.orca_id = p_orca_id;

  return jsonb_build_object('ORCA_1', v_orca, 'itemS', v_itemS);
end;
$$;

-- Por cod_orca (sempre do próprio usuário).
create or replace function public.orca_detalhes(p_user_id bigint, p_cod_orca text)
returns jsonb language plpgsql as $$
declare
  v_orca_id bigint;
begin
  select id into v_orca_id from orca where cod_orca = p_cod_orca and user_id = p_user_id;
  if v_orca_id is null then
    raise exception 'Orçamento não encontrado para o seu usuário.' using errcode = 'P0001';
  end if;
  return f_orca_detalhes(v_orca_id);
end;
$$;

-- Por id, com permissão (dono, ancestrais ou admin_geral).
create or replace function public.orca_por_id(p_user_id bigint, p_orca_id bigint)
returns jsonb language plpgsql as $$
declare
  v_viewer record;
  v_owner record;
  v_pai record;
  v_permitido boolean := false;
begin
  select id, role, vendedor_pai_id into v_viewer from usuarios where id = p_user_id;
  select user_id into v_owner from orca where id = p_orca_id;
  if v_owner.user_id is null then
    raise exception 'Orçamento não encontrado.' using errcode = 'P0001';
  end if;
  select id, role, vendedor_pai_id into v_owner from usuarios where id = v_owner.user_id;

  if v_viewer.role = 'admin_geral' or v_owner.id = p_user_id then
    v_permitido := true;
  elsif coalesce(v_owner.vendedor_pai_id, 0) > 0 then
    if v_owner.vendedor_pai_id = p_user_id then
      v_permitido := true;
    else
      select role, vendedor_pai_id into v_pai from usuarios where id = v_owner.vendedor_pai_id;
      if v_pai.role = 'vendedor_master' and v_pai.vendedor_pai_id = p_user_id then
        v_permitido := true;
      end if;
    end if;
  end if;

  if not v_permitido then
    raise exception 'Você não tem acesso a este orçamento.' using errcode = 'P0001';
  end if;

  return f_orca_detalhes(p_orca_id);
end;
$$;
